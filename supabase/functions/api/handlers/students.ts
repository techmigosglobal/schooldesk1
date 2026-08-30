// handlers/students.ts — CRUD, photo, documents, enrollments
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";
import {
  canManageGuardians,
  canManageStudents,
  guardianSelectFor,
  isFinanceLeader,
  roleName,
  studentAccess,
  visibleStudentIds,
} from "./authorization.ts";
import {
  PRIVATE_FILES_BUCKET,
  privateFileReference,
  signedPrivateFileUrl,
} from "../storage_helpers.ts";

const studentDirectorySelect =
  "*, section:sections(*), guardians(*), student_guardians(guardian:guardians(*)), parent_student_links(parent_user_id)";

// Restricted readers never receive financial totals, parent account details,
// medical records, or permanent/signed document references through the student
// directory. Teacher guardian data is reduced further by guardianSelectFor().
const restrictedStudentDirectorySelect =
  "id, first_name, last_name, admission_number, current_section_id, status, photo_url, section:sections(id, section_name, grade:grades(id, grade_name)), guardians(id, student_id, full_name, relationship, phone, is_primary), student_guardians(guardian:guardians(id, student_id, full_name, relationship, phone, is_primary))";

function sid(user: User) {
  return (user.app_metadata?.school_id as string) ?? "";
}
function parseId(path: string, prefix: string) {
  return path.slice(prefix.length).split("/").filter(Boolean)[0] ?? null;
}
function subPath(path: string, prefix: string) {
  return path.slice(prefix.length).split("/").filter(Boolean).slice(1).join(
    "/",
  );
}
function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}
function nullableText(value: unknown): string | null {
  const clean = text(value);
  return clean.length > 0 ? clean : null;
}
// Normalise status to the values shared by Flutter, the website, and the
// database workflows. Older clients used the longer display labels, so keep
// those aliases compatible at the API boundary.
const VALID_STATUSES = new Set(["active", "inactive", "transfer", "pending"]);
function normaliseStatus(raw: unknown): string {
  const s = text(raw).toLowerCase();
  const canonical = new Map([
    ["transferred", "transfer"],
    ["withdrawn", "inactive"],
    ["acive", "active"],
  ]).get(s) ?? s;
  return VALID_STATUSES.has(canonical) ? canonical : "active";
}

function studentPayload(body: Record<string, unknown>, school: string) {
  const payload: Record<string, unknown> = {
    ...body,
    school_id: school,
  };
  if ("current_section_id" in payload) {
    payload.current_section_id = nullableText(payload.current_section_id);
  }
  if ("date_of_birth" in payload) {
    payload.date_of_birth = nullableText(payload.date_of_birth);
  }
  if ("admission_date" in payload) {
    payload.admission_date = nullableText(payload.admission_date);
  }
  if ("status" in payload) {
    payload.status = normaliseStatus(payload.status);
  }
  return payload;
}
function studentPatch(body: Record<string, unknown>) {
  const payload: Record<string, unknown> = {
    ...body,
    updated_at: new Date().toISOString(),
  };
  delete payload.school_id;
  if ("current_section_id" in payload) {
    payload.current_section_id = nullableText(payload.current_section_id);
  }
  if ("date_of_birth" in payload) {
    payload.date_of_birth = nullableText(payload.date_of_birth);
  }
  if ("admission_date" in payload) {
    payload.admission_date = nullableText(payload.admission_date);
  }
  if ("status" in payload) {
    payload.status = normaliseStatus(payload.status);
  }
  return payload;
}
function guardianPayload(body: Record<string, unknown>, school: string) {
  return {
    school_id: school,
    student_id: nullableText(body.student_id),
    full_name: text(body.full_name || body.name),
    relationship: text(body.relationship) || "parent",
    phone: text(body.phone) || null,
    email: text(body.email) || null,
    occupation: text(body.occupation) || null,
    is_primary: body.is_primary ?? true,
  };
}

async function validateStudentSection(
  svc: SupabaseClient,
  school: string,
  sectionId: string,
) {
  if (!sectionId) return null;
  const { data, error } = await svc.from("sections").select(
    "id, school_id, academic_year_id",
  ).eq("id", sectionId).eq("school_id", school).maybeSingle();
  if (error) throw error;
  return data as Record<string, unknown> | null;
}

async function validateParentAccount(
  svc: SupabaseClient,
  school: string,
  parentUserId: string,
) {
  if (!parentUserId) return null;
  const { data, error } = await svc.from("users").select(
    "id, school_id, role_name, is_active",
  ).eq("id", parentUserId).eq("school_id", school).ilike(
    "role_name",
    "parent",
  ).eq("is_active", true).maybeSingle();
  if (error) throw error;
  return data as Record<string, unknown> | null;
}

async function studentHasValidParentLink(
  svc: SupabaseClient,
  school: string,
  studentId: string,
) {
  const links = await svc.from("parent_student_links").select(
    "parent_user_id",
  ).eq("school_id", school).eq("student_id", studentId);
  if (links.error) throw links.error;
  const parentIds = (links.data ?? []).map((row) => text(row.parent_user_id))
    .filter(
      Boolean,
    );
  if (parentIds.length === 0) return false;
  const parents = await svc.from("users").select("id").eq(
    "school_id",
    school,
  ).in("id", parentIds).ilike("role_name", "parent").eq("is_active", true);
  if (parents.error) throw parents.error;
  return (parents.data ?? []).length > 0;
}

async function ensureStudentIdentifiersAvailable(
  svc: SupabaseClient,
  school: string,
  body: Record<string, unknown>,
  excludeId = "",
) {
  const admissionNumber = text(body.admission_number);
  const studentIdNumber = text(body.student_id_number || body.student_code);
  const checks = [
    admissionNumber
      ? svc.from("students").select("id").eq("school_id", school).eq(
        "admission_number",
        admissionNumber,
      )
      : null,
    studentIdNumber
      ? svc.from("students").select("id").eq("school_id", school).eq(
        "student_id_number",
        studentIdNumber,
      )
      : null,
  ];
  const results = await Promise.all(
    checks.filter(Boolean).map((query) =>
      excludeId ? query!.neq("id", excludeId) : query!
    ),
  );
  for (const result of results) {
    if (result.error) throw result.error;
    if ((result.data ?? []).length > 0) {
      throw new Error(
        "admission number and student ID must be unique within this school",
      );
    }
  }
}

async function replaceStudentParentLink(
  svc: SupabaseClient,
  school: string,
  studentId: string,
  parentUserId: string,
) {
  const parent = await validateParentAccount(svc, school, parentUserId);
  if (!parent) throw new Error("active parent account is required");
  // A student has exactly one parent login association. Replacing the link is
  // intentionally safe for a parent shared by multiple students.
  const { error: clearError } = await svc.from("parent_student_links").delete()
    .eq("school_id", school).eq("student_id", studentId).neq(
      "parent_user_id",
      parentUserId,
    );
  if (clearError) throw clearError;
  const { error: insertError } = await svc.from("parent_student_links").upsert({
    school_id: school,
    parent_user_id: parentUserId,
    student_id: studentId,
  }, { onConflict: "student_id" });
  if (insertError) throw insertError;
}

function photoUploadError(file: File) {
  const allowedTypes = new Set([
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
  ]);
  if (!allowedTypes.has(file.type.toLowerCase())) {
    return "Student photo must be a JPEG, PNG, WebP, HEIC, or HEIF image";
  }
  if (file.size > 5 * 1024 * 1024) {
    return "Student photo must be 5 MB or smaller";
  }
  return "";
}

async function attachParentAccounts(
  svc: SupabaseClient,
  school: string,
  students: Record<string, unknown>[],
) {
  const parentIds = [
    ...new Set(
      students.flatMap((student) => {
        const links = Array.isArray(student.parent_student_links)
          ? student.parent_student_links as Record<string, unknown>[]
          : [];
        return links.map((link) => text(link.parent_user_id)).filter(Boolean);
      }),
    ),
  ];
  if (parentIds.length === 0) return { data: students, error: null };

  const { data: parents, error } = await svc.from("users").select(
    "id, name, username, email, phone",
  ).eq("school_id", school).in("id", parentIds);
  if (error) return { data: students, error };

  const parentById = new Map(
    (parents ?? []).map((parent) => [text(parent.id), parent]),
  );
  return {
    data: students.map((student) => {
      const links = Array.isArray(student.parent_student_links)
        ? student.parent_student_links as Record<string, unknown>[]
        : [];
      const hydratedLinks = links.map((link) => ({
        ...link,
        parent: parentById.get(text(link.parent_user_id)) ?? null,
      }));
      const parentAccounts = hydratedLinks
        .map((link) => link.parent)
        .filter((parent) =>
          Boolean(parent && typeof parent === "object")
        ) as Record<string, unknown>[];
      return {
        ...student,
        parent_user_id: text(links[0]?.parent_user_id) || null,
        parent_accounts: parentAccounts,
        parent_student_links: hydratedLinks,
      };
    }),
    error: null,
  };
}

async function attachClassDetails(
  svc: SupabaseClient,
  school: string,
  students: Record<string, unknown>[],
) {
  const sectionIds = [
    ...new Set(
      students.map((student) => text(student.current_section_id)).filter(
        Boolean,
      ),
    ),
  ];
  if (sectionIds.length === 0) return { data: students, error: null };

  const { data: sections, error: sectionError } = await svc.from("sections")
    .select("*").eq("school_id", school).in("id", sectionIds);
  if (sectionError) return { data: students, error: sectionError };
  const gradeIds = [
    ...new Set(
      (sections ?? []).map((section) => text(section.grade_id)).filter(Boolean),
    ),
  ];
  const { data: grades, error: gradeError } = gradeIds.length > 0
    ? await svc.from("grades").select("*").eq("school_id", school).in(
      "id",
      gradeIds,
    )
    : { data: [], error: null };
  if (gradeError) return { data: students, error: gradeError };

  const gradeById = new Map(
    (grades ?? []).map((grade) => [text(grade.id), grade]),
  );
  const sectionById = new Map(
    (sections ?? []).map((section) => [
      text(section.id),
      { ...section, grade: gradeById.get(text(section.grade_id)) ?? null },
    ]),
  );
  return {
    data: students.map((student) => ({
      ...student,
      section: sectionById.get(text(student.current_section_id)) ??
        student.section ?? null,
    })),
    error: null,
  };
}

async function attachFeeSummaries(
  svc: SupabaseClient,
  school: string,
  students: Record<string, unknown>[],
) {
  const studentIds = students.map((s) => text(s.id)).filter(Boolean);
  if (studentIds.length === 0) return { data: students, error: null };

  const { data: invoices, error } = await svc.from("fee_invoices").select(
    "student_id, total_amount, discount_amount, paid_amount, balance, net_amount, status",
  ).eq("school_id", school).in("student_id", studentIds).not(
    "status",
    "in",
    "(cancelled,void,voided)",
  );
  if (error) return { data: students, error };

  const summaryById = new Map<string, Record<string, unknown>>();
  for (const inv of invoices ?? []) {
    const sid = text(inv.student_id);
    if (!sid) continue;
    const prev = summaryById.get(sid) ?? {
      total_amount: 0,
      discount_amount: 0,
      paid_amount: 0,
      balance: 0,
      pending_invoices: 0,
      overdue_invoices: 0,
    };
    const totalAmount = Number(prev.total_amount) +
      Number(inv.total_amount ?? 0);
    const discountAmount = Number(prev.discount_amount) +
      Number(inv.discount_amount ?? 0);
    const paidAmount = Number(prev.paid_amount) + Number(inv.paid_amount ?? 0);
    const balance = Number(prev.balance) +
      Math.max(
        0,
        Number(inv.balance ?? 0) ||
          (Number(inv.net_amount ?? 0) - Number(inv.paid_amount ?? 0)),
      );
    const pending = Number(prev.pending_invoices) +
      (inv.status !== "paid" ? 1 : 0);
    const overdue = Number(prev.overdue_invoices) +
      (inv.status === "overdue" ? 1 : 0);
    summaryById.set(sid, {
      total_amount: totalAmount,
      discount_amount: discountAmount,
      paid_amount: paidAmount,
      balance,
      pending_invoices: pending,
      overdue_invoices: overdue,
      status: balance > 0 ? "due" : "clear",
    });
  }

  return {
    data: students.map((student) => {
      const sid = text(student.id);
      const summary = summaryById.get(sid) ?? {
        total_amount: 0,
        discount_amount: 0,
        paid_amount: 0,
        balance: 0,
        pending_invoices: 0,
        overdue_invoices: 0,
        status: "clear",
      };
      return { ...student, fee_summary: summary };
    }),
    error: null,
  };
}

async function hydrateStudentDirectory(
  svc: SupabaseClient,
  school: string,
  students: Record<string, unknown>[],
  includeFeeSummaries = true,
) {
  const classDetails = await attachClassDetails(svc, school, students);
  if (classDetails.error) return classDetails;
  // Parent and fee hydration are independent once section details are known.
  // Running them together removes two avoidable sequential database waits from
  // the directory endpoint without changing the response contract.
  const [withParents, withFees] = await Promise.all([
    attachParentAccounts(svc, school, classDetails.data),
    includeFeeSummaries
      ? attachFeeSummaries(svc, school, classDetails.data)
      : Promise.resolve({ data: classDetails.data, error: null }),
  ]);
  if (withParents.error) return withParents;
  if (withFees.error) return withFees;
  if (!includeFeeSummaries) return withParents;
  const feeByStudentId = new Map<string, unknown>(
    withFees.data.map(
      (student) => [text(student.id), student.fee_summary] as [string, unknown],
    ),
  );
  return {
    data: withParents.data.map((student) => ({
      ...student,
      fee_summary: feeByStudentId.get(text(student.id)) ?? {
        total_amount: 0,
        discount_amount: 0,
        paid_amount: 0,
        balance: 0,
        pending_invoices: 0,
        overdue_invoices: 0,
        status: "clear",
      },
    })),
    error: null,
  };
}

export async function handleGuardians(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const id = parseId(path, "/guardians");
  const managesGuardians = canManageGuardians(user);

  if (method !== "GET" && !managesGuardians) {
    return fail("forbidden", 403);
  }

  if (!id && method === "GET") {
    let allowedStudentIds: Set<string> | null = null;
    try {
      allowedStudentIds = await visibleStudentIds(svc, school, user);
    } catch (error) {
      return fail(error instanceof Error ? error.message : "failed to resolve guardian scope");
    }
    if (allowedStudentIds && allowedStudentIds.size === 0) return ok([]);
    let query = svc.from("guardians").select(guardianSelectFor(user)).eq(
      "school_id",
      school,
    );
    if (allowedStudentIds) query = query.in("student_id", [...allowedStudentIds]);
    const { data, error } = await query.order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  if (!id && method === "POST") {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const studentId = text(body.student_id);
    if (!studentId) return fail("student_id required");
    const student = await svc.from("students").select("id").eq("id", studentId)
      .eq("school_id", school).maybeSingle();
    if (student.error) return fail(student.error.message);
    if (!student.data) return fail("student not found", 404);
    const { data, error } = await svc.from("guardians").insert(
      guardianPayload(body, school),
    ).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  if (id && (method === "PATCH" || method === "PUT")) {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    if (text(body.student_id)) {
      const student = await svc.from("students").select("id").eq(
        "id",
        text(body.student_id),
      ).eq("school_id", school).maybeSingle();
      if (student.error) return fail(student.error.message);
      if (!student.data) return fail("student not found", 404);
    }
    const payload = {
      ...guardianPayload(body, school),
      updated_at: new Date().toISOString(),
    };
    delete payload.school_id;
    if (!text(body.student_id)) delete payload.student_id;
    const { data, error } = await svc.from("guardians").update(payload).eq(
      "id",
      id,
    ).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  if (id && method === "DELETE") {
    const { error } = await svc.from("guardians").delete().eq("id", id).eq(
      "school_id",
      school,
    );
    if (error) return fail(error.message);
    return ok({ success: true });
  }

  return fail("not found", 404);
}

export async function handleStudents(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const managesStudents = canManageStudents(user);

  if (
    ["POST", "PUT", "PATCH", "DELETE"].includes(method) &&
    !managesStudents
  ) {
    return fail("forbidden", 403);
  }

  // Enrollments
  if (path === "/students/enrollments" && method === "POST") {
    const body = await req.json().catch(() => ({}));
    const { data, error } = await svc.from("enrollments").insert({
      ...body,
      school_id: school,
    }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  const id = parseId(path, "/students");
  const sub = id ? subPath(path, "/students") : "";

  if (path === "/students/integrity" && method === "GET") {
    if (!managesStudents) return fail("forbidden", 403);
    const [studentsResult, linksResult, usersResult] = await Promise.all([
      svc.from("students").select(
        "id, first_name, last_name, current_section_id",
      )
        .eq("school_id", school).eq("status", "active").eq(
          "is_test_account",
          false,
        ),
      svc.from("parent_student_links").select("student_id, parent_user_id")
        .eq("school_id", school),
      svc.from("users").select("id, is_active, role_name").eq(
        "school_id",
        school,
      )
        .ilike("role_name", "parent").eq("is_active", true),
    ]);
    if (studentsResult.error) return fail(studentsResult.error.message);
    if (linksResult.error) return fail(linksResult.error.message);
    if (usersResult.error) return fail(usersResult.error.message);
    const validParents = new Set(
      (usersResult.data ?? []).map((row) => text(row.id)),
    );
    const validStudentLinks = new Set(
      (linksResult.data ?? [])
        .filter((row) => validParents.has(text(row.parent_user_id)))
        .map((row) => text(row.student_id)),
    );
    const unlinked = (studentsResult.data ?? []).filter(
      (student) => !validStudentLinks.has(text(student.id)),
    );
    return ok({
      active_student_count: studentsResult.data?.length ?? 0,
      valid_linked_student_count: validStudentLinks.size,
      unlinked_active_students: unlinked,
      unlinked_active_student_count: unlinked.length,
    });
  }

  if (path === "/students/summary" && method === "GET") {
    if (!managesStudents) return fail("forbidden", 403);
    const [sectionsResult, studentsResult] = await Promise.all([
      svc.from("sections").select(
        "id, grade_id, section_name, grade:grades(grade_name)",
      )
        .eq("school_id", school),
      svc.from("students").select("id, current_section_id").eq(
        "school_id",
        school,
      ).eq("status", "active").eq("is_test_account", false),
    ]);
    if (sectionsResult.error) return fail(sectionsResult.error.message);
    if (studentsResult.error) return fail(studentsResult.error.message);
    const counts = new Map<string, number>();
    for (const student of studentsResult.data ?? []) {
      const sectionId = text(student.current_section_id);
      if (sectionId) counts.set(sectionId, (counts.get(sectionId) ?? 0) + 1);
    }
    return ok({
      active_student_count: studentsResult.data?.length ?? 0,
      active_students_by_section: Object.fromEntries(counts),
    });
  }

  // Every student subresource and detail read must first prove the caller owns
  // the record, teaches its assigned section, or has school-admin authority.
  // An unknown or out-of-scope ID intentionally looks absent.
  let access: "all" | "scoped" | null = null;
  if (id && method === "GET") {
    try {
      access = await studentAccess(svc, school, user, id);
    } catch (error) {
      return fail(error instanceof Error ? error.message : "failed to resolve student scope");
    }
    if (!access) return fail("student not found", 404);
  }

  if (id && sub === "photo" && method === "POST") {
    const form = await req.formData();
    const file = form.get("photo") as File;
    if (!file) return fail("photo required");
    const validationError = photoUploadError(file);
    if (validationError) return fail(validationError);
    const { data: student, error: studentError } = await svc.from("students")
      .select("id").eq("id", id).eq("school_id", school).maybeSingle();
    if (studentError) return fail(studentError.message);
    if (!student) return fail("student not found", 404);
    const filename = file.name.replaceAll(/[^a-zA-Z0-9._-]/g, "_");
    const p = `students/${school}/${id}/${Date.now()}-${filename || "photo"}`;
    const { error: uploadError } = await svc.storage.from("school-assets")
      .upload(
        p,
        file,
        {
          upsert: true,
          contentType: file.type || "application/octet-stream",
          cacheControl: "31536000",
        },
      );
    if (uploadError) return fail(uploadError.message);
    const { data: { publicUrl } } = svc.storage.from("school-assets")
      .getPublicUrl(p);
    const { error: updateError } = await svc.from("students").update({
      photo_url: publicUrl,
      updated_at: new Date().toISOString(),
    }).eq("id", id).eq("school_id", school);
    if (updateError) return fail(updateError.message);
    return ok({ photo_url: publicUrl });
  }

  if (id && sub === "documents" && method === "POST") {
    const form = await req.formData();
    const file = form.get("document") as File;
    if (!file) return fail("document required");
    const p = `${school}/student-documents/${id}/${Date.now()}-${file.name}`;
    const { error: uploadError } = await svc.storage.from(PRIVATE_FILES_BUCKET)
      .upload(p, file, {
        upsert: true,
        contentType: file.type || "application/octet-stream",
        cacheControl: "3600",
      });
    if (uploadError) return fail(uploadError.message);
    const doc_type = form.get("doc_type") as string ?? "other";
    const { data, error } = await svc.from("student_documents").insert({
      student_id: id,
      school_id: school,
      doc_type,
      file_url: privateFileReference(p),
      title: form.get("title") as string ?? "",
    }).select().single();
    if (error) return fail(error.message);
    return ok({
      ...data,
      file_url: await signedPrivateFileUrl(svc, data.file_url),
    });
  }

  if (id && sub === "attendance" && method === "GET") {
    let q = svc.from("student_attendances").select(
      "*, session:attendance_sessions!inner(*)",
    ).eq("student_id", id).eq("session.school_id", school);
    const year = url.searchParams.get("year");
    const month = url.searchParams.get("month");
    if (year && month) {
      const from = `${year}-${month}-01`;
      const to = `${year}-${month}-31`;
      q = q.gte("created_at", from).lte("created_at", to);
    }
    const { data, error } = await q.order("created_at", { ascending: false });
    if (error) return fail(error.message);
    const mapped = (data ?? []).map((row: any) => ({
      ...row,
      marked_at: row.created_at || row.updated_at,
    }));
    return ok(mapped);
  }

  if (id && sub === "parent" && method === "PUT") {
    const body = await req.json().catch(() => ({}));
    const parentUserId = `${body.parent_user_id ?? ""}`.trim();
    const student = await svc.from("students").select("id, status").eq(
      "id",
      id,
    ).eq("school_id", school).maybeSingle();
    if (student.error) return fail(student.error.message);
    if (!student.data) return fail("student not found", 404);
    if (!parentUserId && `${student.data.status ?? "active"}` === "active") {
      return fail("active students must have an active parent login", 422);
    }
    if (parentUserId) {
      try {
        await replaceStudentParentLink(svc, school, id, parentUserId);
      } catch (error) {
        return fail(
          error instanceof Error ? error.message : "invalid parent account",
          422,
        );
      }
    } else {
      const { error } = await svc.from("parent_student_links").delete().eq(
        "school_id",
        school,
      ).eq("student_id", id);
      if (error) return fail(error.message);
    }
    return ok({ success: true, parent_user_id: parentUserId });
  }

  if (id && sub === "guardians" && method === "POST") {
    const body = await req.json().catch(() => ({}));
    const guardianId = `${body.guardian_id ?? ""}`.trim();
    if (guardianId.length === 0) return fail("guardian_id required");
    const student = await svc.from("students").select("id").eq("id", id).eq(
      "school_id",
      school,
    ).maybeSingle();
    if (student.error) return fail(student.error.message);
    if (!student.data) return fail("student not found", 404);
    const guardian = await svc.from("guardians").select("id, student_id")
      .eq("id", guardianId).eq("school_id", school).maybeSingle();
    if (guardian.error) return fail(guardian.error.message);
    if (!guardian.data || text(guardian.data.student_id) !== id) {
      return fail("guardian is not linked to this student", 422);
    }
    const existing = await svc.from("student_guardians").select("*").eq(
      "student_id",
      id,
    ).eq("guardian_id", guardianId).maybeSingle();
    if (existing.error) return fail(existing.error.message);
    const write = existing.data
      ? svc.from("student_guardians").update({
        guardian_id: guardianId,
      }).eq("id", existing.data.id).select().single()
      : svc.from("student_guardians").insert({
        student_id: id,
        guardian_id: guardianId,
      }).select().single();
    const { data, error } = await write;
    if (error) return fail(error.message);
    return ok({
      ...data,
      is_primary: body.is_primary ?? false,
      can_pickup: body.can_pickup ?? false,
    });
  }

  if (id && sub === "enrollments" && method === "GET") {
    const { data, error } = await svc.from("enrollments").select(
      "*, section:sections(*), academic_year:academic_years(*)",
    ).eq("school_id", school).eq("student_id", id).order(
      "created_at",
      { ascending: false },
    );
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  if (id && sub === "fees" && method === "GET") {
    if (!isFinanceLeader(user) && roleName(user) !== "parent") {
      return fail("forbidden", 403);
    }
    const { data, error } = await svc.from("fee_invoices").select(
      "*, fee_invoice_items(*)",
    ).eq("school_id", school).eq("student_id", id).not(
      "status",
      "in",
      "(cancelled,void,voided)",
    ).order("invoice_date", { ascending: false });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  if (!id && method === "GET") {
    // Kiosk and generic staff identities are limited to their dedicated
    // attendance/operations endpoints; an empty directory is not a valid
    // substitute for denying the capability.
    if (!managesStudents && !["teacher", "parent"].includes(roleName(user))) {
      return fail("forbidden", 403);
    }
    const page = parseInt(url.searchParams.get("page") ?? "1");
    const requestedSize = parseInt(url.searchParams.get("page_size") ?? "50");
    const size = Math.min(
      Math.max(Number.isFinite(requestedSize) ? requestedSize : 50, 1),
      200,
    );
    const search = url.searchParams.get("search") ?? "";
    let allowedStudentIds: Set<string> | null = null;
    try {
      allowedStudentIds = await visibleStudentIds(svc, school, user);
    } catch (error) {
      return fail(error instanceof Error ? error.message : "failed to resolve student scope");
    }
    if (allowedStudentIds && allowedStudentIds.size === 0) {
      return cors({ success: true, data: [], total: 0, page, page_size: size });
    }
    let q = svc.from("students").select(
      managesStudents ? studentDirectorySelect : restrictedStudentDirectorySelect,
      {
      count: "exact",
      },
    ).eq("school_id", school).range((page - 1) * size, page * size - 1);
    if (!managesStudents || url.searchParams.get("include_test_accounts") !== "true") {
      q = q.eq("is_test_account", false);
    }
    if (allowedStudentIds) q = q.in("id", [...allowedStudentIds]);
    if (url.searchParams.get("section_id")) {
      q = q.eq("current_section_id", url.searchParams.get("section_id")!);
    }
    if (url.searchParams.get("status")) {
      q = q.eq("status", url.searchParams.get("status")!);
    }
    if (search) {
      q = q.or(
        `first_name.ilike.%${search}%,last_name.ilike.%${search}%,admission_number.ilike.%${search}%`,
      );
    }
    const { data, error, count } = await q;
    if (error) return fail(error.message);
    const directory = managesStudents
      ? await hydrateStudentDirectory(
        svc,
        school,
        (data ?? []) as unknown as Record<string, unknown>[],
        isFinanceLeader(user),
      )
      : { data: (data ?? []) as unknown as Record<string, unknown>[], error: null };
    if (directory.error) return fail(directory.error.message);
    return cors({
      success: true,
      data: directory.data,
      total: count ?? 0,
      page,
      page_size: size,
    });
  }

  if (!id && method === "POST") {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const parentUserId = text(body.parent_user_id);
    const requireParentLink = body.require_parent_link === true;
    const status = normaliseStatus(body.status);
    const sectionId = text(body.current_section_id);
    if (status === "active" && !sectionId) {
      return fail("active students must be assigned to a class section", 422);
    }
    if (sectionId && !await validateStudentSection(svc, school, sectionId)) {
      return fail(
        "selected class section is not available in this school",
        422,
      );
    }
    if (requireParentLink && !parentUserId) {
      return fail("an active parent login is required", 422);
    }
    if (status === "active" && !parentUserId) {
      return fail("active students must have an active parent login", 422);
    }
    if (
      parentUserId && !await validateParentAccount(svc, school, parentUserId)
    ) {
      return fail(
        "parent account must be active and belong to this school",
        422,
      );
    }
    try {
      await ensureStudentIdentifiersAvailable(svc, school, body);
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "student identifiers must be unique",
        409,
      );
    }
    const payload = studentPayload(body, school);
    delete payload.parent_user_id;
    delete payload.require_parent_link;
    const { data, error } = await svc.from("students").insert(payload)
      .select().single();
    if (error) return fail(error.message);
    if (parentUserId) {
      try {
        await replaceStudentParentLink(
          svc,
          school,
          text(data.id),
          parentUserId,
        );
      } catch (linkError) {
        await svc.from("students").delete().eq("id", data.id).eq(
          "school_id",
          school,
        );
        return fail(
          linkError instanceof Error
            ? linkError.message
            : "failed to link parent",
          422,
        );
      }
    }
    return ok(data);
  }

  if (id && method === "GET") {
    const detailedSelect = access === "all"
      ? `${studentDirectorySelect}, medical_records(*), student_documents(*), enrollments(*, section:sections(*), academic_year:academic_years(*))`
      : restrictedStudentDirectorySelect;
    const { data, error } = await svc.from("students").select(detailedSelect)
      .eq("id", id).eq("school_id", school).single();
    if (error) return fail(error.message);
    if (access !== "all") return ok(data);
    const detail = await hydrateStudentDirectory(svc, school, [
      data as unknown as Record<string, unknown>,
    ], isFinanceLeader(user));
    if (detail.error) return fail(detail.error.message);
    const student = detail.data[0] as Record<string, unknown>;
    return ok({
      ...student,
      student_documents: await Promise.all(
        (Array.isArray(student.student_documents)
          ? student.student_documents
          : []).map(async (document) => ({
            ...document,
            file_url: await signedPrivateFileUrl(svc, document.file_url),
          })),
      ),
    });
  }

  if (id && (method === "PATCH" || method === "PUT")) {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const existing = await svc.from("students").select(
      "id, status, current_section_id",
    ).eq("id", id).eq("school_id", school).maybeSingle();
    if (existing.error) return fail(existing.error.message);
    if (!existing.data) return fail("student not found", 404);
    const parentUserId = body.parent_user_id === null
      ? ""
      : text(body.parent_user_id);
    const requireParentLink = body.require_parent_link === true;
    const status = "status" in body
      ? normaliseStatus(body.status)
      : normaliseStatus(existing.data.status);
    const sectionId = "current_section_id" in body
      ? text(body.current_section_id)
      : text(existing.data.current_section_id);
    if (status === "active" && !sectionId) {
      return fail("active students must be assigned to a class section", 422);
    }
    if (sectionId && !await validateStudentSection(svc, school, sectionId)) {
      return fail(
        "selected class section is not available in this school",
        422,
      );
    }
    if (
      parentUserId && !await validateParentAccount(svc, school, parentUserId)
    ) {
      return fail(
        "parent account must be active and belong to this school",
        422,
      );
    }
    if (requireParentLink && !parentUserId) {
      return fail("an active parent login is required", 422);
    }
    if (status === "active" && !parentUserId) {
      try {
        if (!await studentHasValidParentLink(svc, school, id)) {
          return fail("active students must have an active parent login", 422);
        }
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to validate parent link",
        );
      }
    }
    try {
      await ensureStudentIdentifiersAvailable(svc, school, body, id);
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "student identifiers must be unique",
        409,
      );
    }
    const payload = studentPatch(body);
    delete payload.parent_user_id;
    delete payload.require_parent_link;
    const { data, error } = await svc.from("students").update(payload).eq(
      "id",
      id,
    ).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    if (parentUserId) {
      try {
        await replaceStudentParentLink(svc, school, id, parentUserId);
      } catch (linkError) {
        return fail(
          linkError instanceof Error
            ? linkError.message
            : "failed to link parent",
          422,
        );
      }
    }
    return ok(data);
  }

  if (id && method === "DELETE") {
    const { error } = await svc.from("students").delete().eq("id", id).eq(
      "school_id",
      school,
    );
    if (error) return fail(error.message);
    return ok({ success: true });
  }

  return fail("not found", 404);
}

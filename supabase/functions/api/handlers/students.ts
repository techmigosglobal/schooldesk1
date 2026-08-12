// handlers/students.ts — CRUD, photo, documents, enrollments
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";
import { isSchoolLeader } from "./authorization.ts";
import {
  PRIVATE_FILES_BUCKET,
  privateFileReference,
  signedPrivateFileUrl,
} from "../storage_helpers.ts";

const studentDirectorySelect =
  "*, section:sections(*), guardians(*), student_guardians(guardian:guardians(*)), parent_student_links(parent_user_id)";

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

function canManageStudents(user: User) {
  return isSchoolLeader(user);
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
        .filter((parent) => Boolean(parent && typeof parent === "object")) as
        Record<string, unknown>[];
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
    ...new Set(students.map((student) => text(student.current_section_id)).filter(Boolean)),
  ];
  if (sectionIds.length === 0) return { data: students, error: null };

  const { data: sections, error: sectionError } = await svc.from("sections")
    .select("*").eq("school_id", school).in("id", sectionIds);
  if (sectionError) return { data: students, error: sectionError };
  const gradeIds = [
    ...new Set((sections ?? []).map((section) => text(section.grade_id)).filter(Boolean)),
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
    const totalAmount = Number(prev.total_amount) + Number(inv.total_amount ?? 0);
    const discountAmount = Number(prev.discount_amount) + Number(inv.discount_amount ?? 0);
    const paidAmount = Number(prev.paid_amount) + Number(inv.paid_amount ?? 0);
    const balance = Number(prev.balance) + Math.max(0, Number(inv.balance ?? 0) || (Number(inv.net_amount ?? 0) - Number(inv.paid_amount ?? 0)));
    const pending = Number(prev.pending_invoices) + (inv.status !== "paid" ? 1 : 0);
    const overdue = Number(prev.overdue_invoices) + (inv.status === "overdue" ? 1 : 0);
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
) {
  const classDetails = await attachClassDetails(svc, school, students);
  if (classDetails.error) return classDetails;
  const withParents = await attachParentAccounts(svc, school, classDetails.data);
  if (withParents.error) return withParents;
  return await attachFeeSummaries(svc, school, withParents.data);
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

  if (!id && method === "GET") {
    const { data, error } = await svc.from("guardians").select("*").eq(
      "school_id",
      school,
    ).order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  if (!id && method === "POST") {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    if (!text(body.student_id)) return fail("student_id required");
    const { data, error } = await svc.from("guardians").insert(
      guardianPayload(body, school),
    ).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  if (id && (method === "PATCH" || method === "PUT")) {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
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

  if (
    ["POST", "PUT", "PATCH", "DELETE"].includes(method) &&
    !canManageStudents(user)
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
    const { error: uploadError } = await svc.storage.from("school-assets").upload(
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
    const { error: deleteError } = await svc.from("parent_student_links")
      .delete().eq("school_id", school).eq("student_id", id);
    if (deleteError) return fail(deleteError.message);
    if (parentUserId.length > 0) {
      const { error: insertError } = await svc.from("parent_student_links")
        .insert({
          school_id: school,
          parent_user_id: parentUserId,
          student_id: id,
        });
      if (insertError) return fail(insertError.message);
    }
    return ok({ success: true, parent_user_id: parentUserId });
  }

  if (id && sub === "guardians" && method === "POST") {
    const body = await req.json().catch(() => ({}));
    const guardianId = `${body.guardian_id ?? ""}`.trim();
    if (guardianId.length === 0) return fail("guardian_id required");
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
    const page = parseInt(url.searchParams.get("page") ?? "1");
    const size = parseInt(url.searchParams.get("page_size") ?? "50");
    const search = url.searchParams.get("search") ?? "";
    let q = svc.from("students").select(studentDirectorySelect, {
      count: "exact",
    }).eq("school_id", school).range((page - 1) * size, page * size - 1);
    if (url.searchParams.get("include_test_accounts") !== "true") {
      q = q.eq("is_test_account", false);
    }
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
    const directory = await hydrateStudentDirectory(
      svc,
      school,
      (data ?? []) as Record<string, unknown>[],
    );
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
    const { data, error } = await svc.from("students").insert(
      studentPayload(body, school),
    ).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  if (id && method === "GET") {
    const { data, error } = await svc.from("students").select(
      `${studentDirectorySelect}, medical_records(*), student_documents(*), enrollments(*, section:sections(*), academic_year:academic_years(*))`,
    ).eq("id", id).eq("school_id", school).single();
    if (error) return fail(error.message);
    const detail = await hydrateStudentDirectory(svc, school, [
      data as Record<string, unknown>,
    ]);
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
    const { data, error } = await svc.from("students").update(
      studentPatch(body),
    ).eq("id", id).eq("school_id", school).select().single();
    if (error) return fail(error.message);
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

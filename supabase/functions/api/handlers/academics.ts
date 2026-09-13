// handlers/academics.ts
// academic-years, grades, sections, departments, subjects, grade-subjects, rooms
// grade-subjects: NO max_marks / pass_marks

import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";
import {
  canManageAcademics,
  isFinanceLeader,
  linkedStaffId,
  roleName,
} from "./authorization.ts";
import { resolveActiveTeacherScope } from "./teacher_scope.ts";

function schoolId(user: User): string {
  return (user.app_metadata?.school_id as string) ?? "";
}

function parseId(path: string, prefix: string): string | null {
  const rest = path.slice(prefix.length);
  const seg = rest.split("/").filter(Boolean)[0];
  return seg && seg !== "" ? seg : null;
}

function qp(url: URL, key: string): string | null {
  return url.searchParams.get(key);
}

function _paginate(url: URL) {
  const page = Math.max(parseInt(qp(url, "page") ?? "1") || 1, 1);
  const size = Math.min(
    Math.max(parseInt(qp(url, "page_size") ?? "20") || 20, 1),
    100,
  );
  return { page, size, from: (page - 1) * size, to: page * size - 1 };
}

function pagedResponse<T>(
  data: T[],
  count: number | null,
  page: number,
  pageSize: number,
) {
  const total = count ?? data.length;
  return {
    data,
    total,
    page,
    page_size: pageSize,
    has_more: page * pageSize < total,
  };
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

async function deleteInvoiceWorkflowRows(
  svc: SupabaseClient,
  school: string,
  invoiceIds: string[],
  userId: string,
) {
  const ids = [...new Set(invoiceIds.map(text).filter(Boolean))];
  if (ids.length === 0) {
    return {
      retained_invoices: 0,
      cancelled_invoices: 0,
      reversed_requests: 0,
    };
  }

  const nowIso = new Date().toISOString();
  const reason = "Academic year archived; financial history retained";

  const requestUpdate = await svc.from("parent_payment_requests").update({
    status: "reversed",
    admin_remarks: reason,
    updated_at: nowIso,
  }).eq(
    "school_id",
    school,
  ).in("invoice_id", ids).in("status", [
    "initiated",
    "pending",
    "pending_verification",
    "submitted",
    "clarification_required",
    "resubmitted",
  ]).select("id");
  if (requestUpdate.error) throw new Error(requestUpdate.error.message);

  const invoiceUpdate = await svc.from("fee_invoices").update({
    status: "cancelled",
    voided_at: nowIso,
    voided_by: userId,
    updated_at: nowIso,
  }).eq(
    "school_id",
    school,
  ).in("id", ids).eq("paid_amount", 0).not(
    "status",
    "in",
    "(paid,settled,void,voided,cancelled)",
  ).select("id");
  if (invoiceUpdate.error) throw new Error(invoiceUpdate.error.message);

  return {
    retained_invoices: ids.length,
    cancelled_invoices: (invoiceUpdate.data ?? []).length,
    reversed_requests: (requestUpdate.data ?? []).length,
  };
}

async function deleteAcademicYearWorkflowRows(
  svc: SupabaseClient,
  school: string,
  academicYearId: string,
  userId: string,
) {
  const invoices = await svc.from("fee_invoices").select("id").eq(
    "school_id",
    school,
  ).eq("academic_year_id", academicYearId);
  if (invoices.error) throw new Error(invoices.error.message);
  const cleanup = await deleteInvoiceWorkflowRows(
    svc,
    school,
    (invoices.data ?? []).map((row) => text(row.id)),
    userId,
  );

  return {
    ...cleanup,
    archived_academic_year: cleanup.retained_invoices > 0,
  };
}

async function staffSubjectPayloadWithGrade(
  svc: SupabaseClient,
  schoolId: string,
  payload: Record<string, unknown>,
) {
  const gradeId = text(payload["grade_id"]);
  if (gradeId) return payload;

  const sectionId = text(payload["section_id"]);
  if (!sectionId) return payload;

  const { data, error } = await svc.from("sections").select("grade_id").eq(
    "id",
    sectionId,
  ).eq("school_id", schoolId).maybeSingle();
  if (error) throw new Error(error.message);
  const resolvedGradeId = text(
    (data as Record<string, unknown> | null)?.[
      "grade_id"
    ],
  );
  return resolvedGradeId ? { ...payload, grade_id: resolvedGradeId } : payload;
}

function subjectPayload(payload: Record<string, unknown>, includeName = true) {
  const clean: Record<string, unknown> = {
    subject_name: text(payload["subject_name"]),
    subject_code: text(payload["subject_code"]) || null,
    subject_color: text(payload["subject_color"]) || null,
  };
  if (!includeName && !clean.subject_name) delete clean.subject_name;
  return clean;
}

async function sectionPayload(
  svc: SupabaseClient,
  school: string,
  body: Record<string, unknown>,
) {
  const payload: Record<string, unknown> = { ...body };
  const classTeacherId = "class_teacher_id" in payload
    ? text(payload.class_teacher_id) || null
    : undefined;
  const coTeacherId = "co_teacher_id" in payload
    ? text(payload.co_teacher_id) || null
    : undefined;
  if (classTeacherId !== undefined) payload.class_teacher_id = classTeacherId;
  if (coTeacherId !== undefined) payload.co_teacher_id = coTeacherId;
  if (classTeacherId && coTeacherId && classTeacherId === coTeacherId) {
    throw new Error(
      "class teacher and co-teacher must be different staff members",
    );
  }
  const teacherIds = [classTeacherId, coTeacherId].filter(
    (value): value is string => Boolean(value),
  );
  if (teacherIds.length > 0) {
    const result = await svc.from("staff").select("id").eq("school_id", school)
      .eq("is_active", true).in("id", teacherIds);
    if (result.error) throw new Error(result.error.message);
    if ((result.data ?? []).length !== new Set(teacherIds).size) {
      throw new Error(
        "class teacher and co-teacher must be active staff in this school",
      );
    }
  }
  return payload;
}

export async function handleAcademics(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const sid = schoolId(user);
  if (method !== "GET" && !canManageAcademics(user)) {
    return fail("school administration access required", 403);
  }
  const role = roleName(user);
  let teacherSectionIds: string[] = [];
  let teacherGradeIds: string[] = [];
  let teacherYearIds: string[] = [];
  let teacherSubjectIds: string[] = [];
  if (!canManageAcademics(user)) {
    // Teachers may read only the canonical assignments resolved from staff,
    // sections, and staff_subjects. Parents, kiosk, and generic staff do not
    // receive school-wide academic metadata through this administrative API.
    if (role !== "teacher") return fail("forbidden", 403);
    try {
      const scope = await resolveActiveTeacherScope(svc, sid, linkedStaffId(user));
      teacherSectionIds = [...scope.sections.keys()];
      teacherGradeIds = [...new Set([...scope.sections.values()].map((row) => row.gradeId).filter(Boolean))];
      teacherYearIds = [...new Set([...scope.sections.values()].map((row) => row.academicYearId).filter(Boolean))];
      teacherSubjectIds = [...new Set([...scope.sections.values()].flatMap((row) => [...row.subjectIds]))];
    } catch (error) {
      return fail(error instanceof Error ? error.message : "failed to resolve teacher scope");
    }
  }
  const body = method !== "GET"
    ? await req.json().catch(() => ({})) as Record<string, unknown>
    : {};

  // ── Academic Years ─────────────────────────────────────────
  if (path.startsWith("/academic-years")) {
    const id = parseId(path, "/academic-years");
    if (id && path.endsWith("/summary") && method === "GET") {
      const yearId = id;
      if (role === "teacher" && !teacherYearIds.includes(yearId)) {
        return fail("academic year not found", 404);
      }
      const year = await svc.from("academic_years").select(
        "id, school_id, year_label",
      )
        .eq("id", yearId).eq("school_id", sid).maybeSingle();
      if (year.error) return fail(year.error.message);
      if (!year.data) return fail("academic year not found", 404);

      const includeFinance = isFinanceLeader(user);
      const [sectionsResult, subjectLinksResult, feeStructuresResult] =
        await Promise.all([
          (() => {
            let query = svc.from("sections").select(
            "id, grade_id, section_name, grade:grades(grade_name)",
            ).eq("school_id", sid).eq("academic_year_id", yearId);
            if (role === "teacher") query = query.in("id", teacherSectionIds);
            return query.order("section_name");
          })(),
          (() => {
            let query = svc.from("grade_subjects").select(
            "subject_id, subject:subjects(id, subject_name, is_active)",
            ).eq("school_id", sid).eq("academic_year_id", yearId);
            if (role === "teacher") query = query.in("section_id", teacherSectionIds);
            return query;
          })(),
          includeFinance
            ? svc.from("fee_structures").select(
              "id, grade_id, section_id, category_id, amount, frequency, fee_categories(name)",
            ).eq("school_id", sid).eq("academic_year_id", yearId).eq(
              "is_active",
              true,
            )
            : Promise.resolve({ data: [], error: null }),
        ]);
      if (sectionsResult.error) return fail(sectionsResult.error.message);
      if (subjectLinksResult.error) {
        return fail(subjectLinksResult.error.message);
      }
      if (feeStructuresResult.error) {
        return fail(feeStructuresResult.error.message);
      }

      const sections = (sectionsResult.data ?? []) as Array<
        Record<string, unknown>
      >;
      const sectionIds = sections.map((row) => text(row.id)).filter(Boolean);
      let students: Array<Record<string, unknown>> = [];
      if (sectionIds.length > 0) {
        const result = await svc.from("students").select(
          "id, current_section_id, status, is_test_account",
        ).eq("school_id", sid).eq("status", "active").eq(
          "is_test_account",
          false,
        ).in("current_section_id", sectionIds);
        if (result.error) return fail(result.error.message);
        students = (result.data ?? []) as Array<Record<string, unknown>>;
      }

      const studentCountBySection = new Map<string, number>();
      for (const student of students) {
        const sectionId = text(student.current_section_id);
        if (!sectionId) continue;
        studentCountBySection.set(
          sectionId,
          (studentCountBySection.get(sectionId) ?? 0) + 1,
        );
      }

      const classRows = sections.map((section) => {
        const grade = section.grade && typeof section.grade === "object"
          ? section.grade as Record<string, unknown>
          : {};
        return {
          section_id: text(section.id),
          grade_id: text(section.grade_id),
          grade_name: text(grade.grade_name),
          section_name: text(section.section_name),
          student_count: studentCountBySection.get(text(section.id)) ?? 0,
        };
      });

      const subjects = new Map<string, string>();
      for (
        const link of (subjectLinksResult.data ?? []) as Array<
          Record<string, unknown>
        >
      ) {
        const subject = link.subject && typeof link.subject === "object"
          ? link.subject as Record<string, unknown>
          : {};
        if (subject.is_active === false) continue;
        const subjectId = text(link.subject_id || subject.id);
        const subjectName = text(subject.subject_name);
        if (subjectId && subjectName) subjects.set(subjectId, subjectName);
      }

      const feeStructures = (feeStructuresResult.data ?? []) as Array<
        Record<string, unknown>
      >;
      const feeNames = feeStructures.map((row) => {
        const category =
          row.fee_categories && typeof row.fee_categories === "object"
            ? row.fee_categories as Record<string, unknown>
            : {};
        const name = text(category.name);
        return name || `${text(row.frequency) || "Fee"} · ${row.amount ?? 0}`;
      });

      const summary = {
        academic_year_id: yearId,
        year_label: text(year.data.year_label),
        active_student_count: students.length,
        class_count: classRows.length,
        classes: classRows,
        subject_count: subjects.size,
        subject_names: [...subjects.values()].sort(),
        ...(includeFinance
          ? {
            fee_structure_count: feeStructures.length,
            fee_structure_names: feeNames,
          }
          : {}),
      };
      return ok(summary);
    }
    if (path.endsWith("/terms") && id) {
      if (role === "teacher" && !teacherYearIds.includes(id)) {
        return fail("academic year not found", 404);
      }
      const { data, error } = await svc.from("terms").select("*").eq(
        "academic_year_id",
        id,
      );
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "GET") {
      let query = svc.from("academic_years").select(
        "*, terms(*), holidays(*)",
      ).eq("school_id", sid);
      if (role === "teacher") {
        if (teacherYearIds.length === 0) return ok([]);
        query = query.in("id", teacherYearIds);
      }
      const { data, error } = await query;
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "POST") {
      const yearLabel = text(body.year_label || body.year);
      if (!yearLabel) return fail("year_label required", 422);
      const duplicate = await svc.from("academic_years").select("id").eq(
        "school_id",
        sid,
      ).ilike("year_label", yearLabel).limit(1);
      if (duplicate.error) return fail(duplicate.error.message);
      if ((duplicate.data ?? []).length > 0) {
        return fail("academic year label already exists for this school", 409);
      }
      if (body.is_current === true) {
        const clearCurrent = await svc.from("academic_years").update({
          is_current: false,
          updated_at: new Date().toISOString(),
        }).eq("school_id", sid).eq("is_current", true);
        if (clearCurrent.error) return fail(clearCurrent.error.message);
      }
      const { data, error } = await svc.from("academic_years").insert({
        ...body,
        year_label: yearLabel,
        school_id: sid,
      }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && method === "GET") {
      if (role === "teacher" && !teacherYearIds.includes(id)) {
        return fail("academic year not found", 404);
      }
      const { data, error } = await svc.from("academic_years").select(
        "*, terms(*), holidays(*)",
      ).eq("id", id).eq("school_id", sid).single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && (method === "PATCH" || method === "PUT")) {
      const yearLabel = text(body.year_label || body.year);
      if (!yearLabel) return fail("year_label required", 422);
      const existingYear = await svc.from("academic_years").select(
        "id, year_label",
      ).eq("id", id).eq("school_id", sid).maybeSingle();
      if (existingYear.error) return fail(existingYear.error.message);
      if (!existingYear.data) return fail("academic year not found", 404);
      if (
        text(existingYear.data.year_label).toLowerCase() !==
          yearLabel.toLowerCase()
      ) {
        const duplicate = await svc.from("academic_years").select("id").eq(
          "school_id",
          sid,
        ).ilike("year_label", yearLabel).neq("id", id).limit(1);
        if (duplicate.error) return fail(duplicate.error.message);
        if ((duplicate.data ?? []).length > 0) {
          return fail(
            "academic year label already exists for this school",
            409,
          );
        }
      }
      if (body.is_current === true) {
        const clearCurrent = await svc.from("academic_years").update({
          is_current: false,
          updated_at: new Date().toISOString(),
        }).eq("school_id", sid).eq("is_current", true).neq("id", id);
        if (clearCurrent.error) return fail(clearCurrent.error.message);
      }
      const { data, error } = await svc.from("academic_years").update({
        ...body,
        year_label: yearLabel,
        updated_at: new Date().toISOString(),
      }).eq("id", id).eq("school_id", sid).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && method === "DELETE") {
      let cleanup = {
        retained_invoices: 0,
        cancelled_invoices: 0,
        reversed_requests: 0,
        archived_academic_year: false,
      };
      try {
        cleanup = await deleteAcademicYearWorkflowRows(svc, sid, id, user.id);
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to clear academic year finance rows",
        );
      }
      if (cleanup.archived_academic_year) {
        const { data, error } = await svc.from("academic_years").update({
          status: "archived",
          is_current: false,
          updated_at: new Date().toISOString(),
        }).eq("id", id).eq("school_id", sid).select().single();
        if (error) return fail(error.message);
        return ok({
          success: true,
          archived: true,
          academic_year: data,
          ...cleanup,
        });
      }
      const { error } = await svc.from("academic_years").delete().eq("id", id)
        .eq("school_id", sid);
      if (error) return fail(error.message);
      return ok({ success: true, ...cleanup });
    }
  }

  // ── Grades ─────────────────────────────────────────────────
  if (path.startsWith("/grades")) {
    const id = parseId(path, "/grades");
    if (!id && method === "GET") {
      let query = svc.from("grades").select("*").eq(
        "school_id",
        sid,
      );
      if (role === "teacher") {
        if (teacherGradeIds.length === 0) return ok([]);
        query = query.in("id", teacherGradeIds);
      }
      const { data, error } = await query.order("grade_number");
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "POST") {
      const { data, error } = await svc.from("grades").insert({
        ...body,
        school_id: sid,
      }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && (method === "PATCH" || method === "PUT")) {
      const { data, error } = await svc.from("grades").update(body).eq("id", id)
        .eq("school_id", sid).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  // ── Sections ───────────────────────────────────────────────
  if (path.startsWith("/sections")) {
    const id = parseId(path, "/sections");
    if (!id && method === "GET") {
      let q = svc.from("sections").select(
        "*, grade:grades(*), academic_year:academic_years(*)",
      ).eq("school_id", sid);
      if (role === "teacher") {
        if (teacherSectionIds.length === 0) return ok([]);
        q = q.in("id", teacherSectionIds);
      }
      if (qp(url, "grade_id")) q = q.eq("grade_id", qp(url, "grade_id")!);
      if (qp(url, "academic_year_id")) {
        q = q.eq("academic_year_id", qp(url, "academic_year_id")!);
      }
      const { data, error } = await q;
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "POST") {
      let payload: Record<string, unknown>;
      try {
        payload = await sectionPayload(svc, sid, body);
      } catch (error) {
        return fail(
          error instanceof Error ? error.message : "invalid teacher assignment",
          422,
        );
      }
      const { data, error } = await svc.from("sections").insert({
        ...payload,
        school_id: sid,
      }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && (method === "PATCH" || method === "PUT")) {
      let payload: Record<string, unknown>;
      try {
        payload = await sectionPayload(svc, sid, body);
      } catch (error) {
        return fail(
          error instanceof Error ? error.message : "invalid teacher assignment",
          422,
        );
      }
      const { data, error } = await svc.from("sections").update({
        ...payload,
        updated_at: new Date().toISOString(),
      }).eq("id", id).eq("school_id", sid).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  // ── Departments ────────────────────────────────────────────
  if (path.startsWith("/departments")) {
    if (role === "teacher") return fail("forbidden", 403);
    const id = parseId(path, "/departments");
    if (!id && method === "GET") {
      const { data, error } = await svc.from("departments").select("*").eq(
        "school_id",
        sid,
      );
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "POST") {
      const { data, error } = await svc.from("departments").insert({
        ...body,
        school_id: sid,
      }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  // ── Subjects ───────────────────────────────────────────────
  if (path.startsWith("/subjects")) {
    const id = parseId(path, "/subjects");
    if (!id && method === "GET") {
      let q = svc.from("subjects").select("*", { count: "exact" }).eq(
        "school_id",
        sid,
      );
      if (role === "teacher") {
        if (teacherSubjectIds.length === 0) return ok([]);
        q = q.in("id", teacherSubjectIds);
      }
      if (qp(url, "subject_type")) {
        q = q.eq("subject_type", qp(url, "subject_type")!);
      }
      const { data, error, count } = await q.order("subject_name", {
        ascending: true,
      }).range(_paginate(url).from, _paginate(url).to);
      if (error) return fail(error.message);
      const pagination = _paginate(url);
      return ok(pagedResponse(
        data ?? [],
        count,
        pagination.page,
        pagination.size,
      ));
    }
    if (!id && method === "POST") {
      const { data, error } = await svc.from("subjects").insert({
        ...subjectPayload(body),
        school_id: sid,
      }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && (method === "PATCH" || method === "PUT")) {
      const { data, error } = await svc.from("subjects").update({
        ...subjectPayload(body, false),
        updated_at: new Date().toISOString(),
      }).eq("id", id).eq("school_id", sid).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  // ── Grade Subjects (NO max_marks / pass_marks) ─────────────
  if (path.startsWith("/grade-subjects")) {
    const id = parseId(path, "/grade-subjects");
    if (!id && method === "GET") {
      let q = svc.from("grade_subjects").select(
        "*, subject:subjects(*), grade:grades(*), section:sections(*)",
        { count: "exact" },
      ).eq("school_id", sid);
      if (role === "teacher") {
        if (teacherSectionIds.length === 0) return ok([]);
        q = q.in("section_id", teacherSectionIds);
      }
      if (qp(url, "academic_year_id")) {
        q = q.eq("academic_year_id", qp(url, "academic_year_id")!);
      }
      if (qp(url, "grade_id")) q = q.eq("grade_id", qp(url, "grade_id")!);
      if (qp(url, "section_id")) q = q.eq("section_id", qp(url, "section_id")!);
      const pagination = _paginate(url);
      const { data, error, count } = await q.order("created_at", {
        ascending: false,
      }).range(pagination.from, pagination.to);
      if (error) return fail(error.message);
      return ok(pagedResponse(
        data ?? [],
        count,
        pagination.page,
        pagination.size,
      ));
    }
    if (!id && method === "POST") {
      // Strip marks fields even if old client sends them
      const { max_marks: _m, pass_marks: _p, ...safe } = body;
      const { data, error } = await svc.from("grade_subjects").insert({
        ...safe,
        school_id: sid,
      }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && method === "PATCH") {
      const { max_marks: _m, pass_marks: _p, ...safe } = body;
      const { data, error } = await svc.from("grade_subjects").update({
        ...safe,
        updated_at: new Date().toISOString(),
      }).eq("id", id).eq("school_id", sid).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  // ── Staff Subjects ─────────────────────────────────────────
  if (path.startsWith("/staff-subjects")) {
    const id = parseId(path, "/staff-subjects");
    if (!id && method === "GET") {
      let q = svc.from("staff_subjects").select(
        "*, staff:staff(*), subject:subjects(*), grade:grades(*), section:sections(*)",
        { count: "exact" },
      ).eq("school_id", sid);
      if (role === "teacher") {
        const staffId = linkedStaffId(user);
        if (!staffId) return ok([]);
        q = q.eq("staff_id", staffId);
      }
      if (qp(url, "staff_id")) q = q.eq("staff_id", qp(url, "staff_id")!);
      if (qp(url, "grade_id")) q = q.eq("grade_id", qp(url, "grade_id")!);
      if (qp(url, "section_id")) {
        q = q.eq("section_id", qp(url, "section_id")!);
      }
      const pagination = _paginate(url);
      const { data, error, count } = await q.order("created_at", {
        ascending: false,
      }).range(pagination.from, pagination.to);
      if (error) return fail(error.message);
      return ok(pagedResponse(
        data ?? [],
        count,
        pagination.page,
        pagination.size,
      ));
    }
    if (!id && method === "POST") {
      const payload = await staffSubjectPayloadWithGrade(svc, sid, {
        ...body,
        school_id: sid,
      });
      const { data, error } = await svc.from("staff_subjects").insert(payload)
        .select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && (method === "PATCH" || method === "PUT")) {
      const payload = await staffSubjectPayloadWithGrade(svc, sid, {
        ...body,
        updated_at: new Date().toISOString(),
      });
      const { data, error } = await svc.from("staff_subjects").update(payload)
        .eq("id", id).eq("school_id", sid).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && method === "DELETE") {
      const { error } = await svc.from("staff_subjects").delete().eq("id", id)
        .eq("school_id", sid);
      if (error) return fail(error.message);
      return ok({ success: true });
    }
  }

  // ── Rooms ──────────────────────────────────────────────────
  if (path.startsWith("/rooms")) {
    if (role === "teacher") return fail("forbidden", 403);
    const id = parseId(path, "/rooms");
    if (!id && method === "GET") {
      let q = svc.from("rooms").select("*").eq("school_id", sid);
      if (qp(url, "room_type")) q = q.eq("room_type", qp(url, "room_type")!);
      const { data, error } = await q;
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "POST") {
      const { data, error } = await svc.from("rooms").insert({
        ...body,
        school_id: sid,
      }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  return fail("not found", 404);
}

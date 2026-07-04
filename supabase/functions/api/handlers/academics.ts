// handlers/academics.ts
// academic-years, grades, sections, departments, subjects, grade-subjects, rooms
// grade-subjects: NO max_marks / pass_marks

import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { ok, fail } from "../index.ts";

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
  const page = parseInt(qp(url, "page") ?? "1");
  const size = parseInt(qp(url, "page_size") ?? "50");
  return { from: (page - 1) * size, to: page * size - 1 };
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

async function deleteInvoiceWorkflowRows(
  svc: SupabaseClient,
  school: string,
  invoiceIds: string[],
) {
  const ids = [...new Set(invoiceIds.map(text).filter(Boolean))];
  if (ids.length === 0) return 0;

  const receiptDelete = await svc.from("fee_receipts").delete().eq(
    "school_id",
    school,
  ).in("invoice_id", ids);
  if (receiptDelete.error) throw new Error(receiptDelete.error.message);

  const requestDelete = await svc.from("parent_payment_requests").delete().eq(
    "school_id",
    school,
  ).in("invoice_id", ids);
  if (requestDelete.error) throw new Error(requestDelete.error.message);

  const paymentDelete = await svc.from("payments").delete().eq(
    "school_id",
    school,
  ).in("invoice_id", ids);
  if (paymentDelete.error) throw new Error(paymentDelete.error.message);

  const invoiceDelete = await svc.from("fee_invoices").delete().eq(
    "school_id",
    school,
  ).in("id", ids);
  if (invoiceDelete.error) throw new Error(invoiceDelete.error.message);
  return ids.length;
}

async function deleteAcademicYearWorkflowRows(
  svc: SupabaseClient,
  school: string,
  academicYearId: string,
) {
  const invoices = await svc.from("fee_invoices").select("id").eq(
    "school_id",
    school,
  ).eq("academic_year_id", academicYearId);
  if (invoices.error) throw new Error(invoices.error.message);
  const deletedInvoices = await deleteInvoiceWorkflowRows(
    svc,
    school,
    (invoices.data ?? []).map((row) => text(row.id)),
  );

  const structures = await svc.from("fee_structures").select("id").eq(
    "school_id",
    school,
  ).eq("academic_year_id", academicYearId);
  if (structures.error) throw new Error(structures.error.message);
  const structureIds = (structures.data ?? []).map((row) => text(row.id))
    .filter(Boolean);
  if (structureIds.length > 0) {
    const concessionDelete = await svc.from("fee_concessions").delete().eq(
      "school_id",
      school,
    ).in("fee_structure_id", structureIds);
    if (concessionDelete.error) {
      throw new Error(concessionDelete.error.message);
    }
  }

  return { deleted_invoices: deletedInvoices };
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
  const resolvedGradeId = text((data as Record<string, unknown> | null)?.[
    "grade_id"
  ]);
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
  const body = method !== "GET"
    ? await req.json().catch(() => ({})) as Record<string, unknown>
    : {};

  // ── Academic Years ─────────────────────────────────────────
  if (path.startsWith("/academic-years")) {
    const id = parseId(path, "/academic-years");
    if (path.endsWith("/terms") && id) {
      const { data, error } = await svc.from("terms").select("*").eq("academic_year_id", id);
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "GET") {
      const { data, error } = await svc.from("academic_years").select("*, terms(*), holidays(*)").eq("school_id", sid);
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "POST") {
      const { data, error } = await svc.from("academic_years").insert({ ...body, school_id: sid }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && method === "GET") {
      const { data, error } = await svc.from("academic_years").select("*, terms(*), holidays(*)").eq("id", id).eq("school_id", sid).single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && (method === "PATCH" || method === "PUT")) {
      const { data, error } = await svc.from("academic_years").update({ ...body, updated_at: new Date().toISOString() }).eq("id", id).eq("school_id", sid).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && method === "DELETE") {
      let cleanup = { deleted_invoices: 0 };
      try {
        cleanup = await deleteAcademicYearWorkflowRows(svc, sid, id);
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to clear academic year finance rows",
        );
      }
      const { error } = await svc.from("academic_years").delete().eq("id", id).eq("school_id", sid);
      if (error) return fail(error.message);
      return ok({ success: true, ...cleanup });
    }
  }

  // ── Grades ─────────────────────────────────────────────────
  if (path.startsWith("/grades")) {
    const id = parseId(path, "/grades");
    if (!id && method === "GET") {
      const { data, error } = await svc.from("grades").select("*").eq("school_id", sid).order("grade_number");
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "POST") {
      const { data, error } = await svc.from("grades").insert({ ...body, school_id: sid }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && (method === "PATCH" || method === "PUT")) {
      const { data, error } = await svc.from("grades").update(body).eq("id", id).eq("school_id", sid).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  // ── Sections ───────────────────────────────────────────────
  if (path.startsWith("/sections")) {
    const id = parseId(path, "/sections");
    if (!id && method === "GET") {
      let q = svc.from("sections").select("*, grade:grades(*), academic_year:academic_years(*)").eq("school_id", sid);
      if (qp(url, "grade_id")) q = q.eq("grade_id", qp(url, "grade_id")!);
      if (qp(url, "academic_year_id")) q = q.eq("academic_year_id", qp(url, "academic_year_id")!);
      const { data, error } = await q;
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "POST") {
      const { data, error } = await svc.from("sections").insert({ ...body, school_id: sid }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && method === "PATCH") {
      const { data, error } = await svc.from("sections").update({ ...body, updated_at: new Date().toISOString() }).eq("id", id).eq("school_id", sid).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  // ── Departments ────────────────────────────────────────────
  if (path.startsWith("/departments")) {
    const id = parseId(path, "/departments");
    if (!id && method === "GET") {
      const { data, error } = await svc.from("departments").select("*").eq("school_id", sid);
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "POST") {
      const { data, error } = await svc.from("departments").insert({ ...body, school_id: sid }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  // ── Subjects ───────────────────────────────────────────────
  if (path.startsWith("/subjects")) {
    const id = parseId(path, "/subjects");
    if (!id && method === "GET") {
      let q = svc.from("subjects").select("*").eq("school_id", sid);
      if (qp(url, "subject_type")) q = q.eq("subject_type", qp(url, "subject_type")!);
      const { data, error } = await q;
      if (error) return fail(error.message);
      return ok(data);
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
      let q = svc.from("grade_subjects").select("*, subject:subjects(*), grade:grades(*), section:sections(*)").eq("school_id", sid);
      if (qp(url, "academic_year_id")) q = q.eq("academic_year_id", qp(url, "academic_year_id")!);
      if (qp(url, "grade_id")) q = q.eq("grade_id", qp(url, "grade_id")!);
      if (qp(url, "section_id")) q = q.eq("section_id", qp(url, "section_id")!);
      const { data, error } = await q;
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "POST") {
      // Strip marks fields even if old client sends them
      const { max_marks: _m, pass_marks: _p, ...safe } = body;
      const { data, error } = await svc.from("grade_subjects").insert({ ...safe, school_id: sid }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && method === "PATCH") {
      const { max_marks: _m, pass_marks: _p, ...safe } = body;
      const { data, error } = await svc.from("grade_subjects").update({ ...safe, updated_at: new Date().toISOString() }).eq("id", id).eq("school_id", sid).select().single();
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
      ).eq("school_id", sid);
      if (qp(url, "staff_id")) q = q.eq("staff_id", qp(url, "staff_id")!);
      if (qp(url, "grade_id")) q = q.eq("grade_id", qp(url, "grade_id")!);
      if (qp(url, "section_id")) {
        q = q.eq("section_id", qp(url, "section_id")!);
      }
      const { data, error } = await q;
      if (error) return fail(error.message);
      return ok(data);
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
    const id = parseId(path, "/rooms");
    if (!id && method === "GET") {
      let q = svc.from("rooms").select("*").eq("school_id", sid);
      if (qp(url, "room_type")) q = q.eq("room_type", qp(url, "room_type")!);
      const { data, error } = await q;
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!id && method === "POST") {
      const { data, error } = await svc.from("rooms").insert({ ...body, school_id: sid }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  return fail("not found", 404);
}

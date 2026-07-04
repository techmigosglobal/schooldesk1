// handlers/students.ts — CRUD, photo, documents, enrollments
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";

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
    const p = `students/${school}/${id}/${Date.now()}-${file.name}`;
    await svc.storage.from("school-assets").upload(p, file, { upsert: true });
    const { data: { publicUrl } } = svc.storage.from("school-assets")
      .getPublicUrl(p);
    await svc.from("students").update({ photo_url: publicUrl }).eq("id", id);
    return ok({ photo_url: publicUrl });
  }

  if (id && sub === "documents" && method === "POST") {
    const form = await req.formData();
    const file = form.get("document") as File;
    if (!file) return fail("document required");
    const p = `documents/students/${id}/${Date.now()}-${file.name}`;
    await svc.storage.from("school-assets").upload(p, file, { upsert: true });
    const { data: { publicUrl } } = svc.storage.from("school-assets")
      .getPublicUrl(p);
    const doc_type = form.get("doc_type") as string ?? "other";
    const { data, error } = await svc.from("student_documents").insert({
      student_id: id,
      school_id: school,
      doc_type,
      file_url: publicUrl,
      title: form.get("title") as string ?? "",
    }).select().single();
    if (error) return fail(error.message);
    return ok(data);
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
    ).eq("school_id", school).eq("student_id", id).order(
      "invoice_date",
      { ascending: false },
    );
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  if (!id && method === "GET") {
    const page = parseInt(url.searchParams.get("page") ?? "1");
    const size = parseInt(url.searchParams.get("page_size") ?? "50");
    const search = url.searchParams.get("search") ?? "";
    let q = svc.from("students").select(
      "*, section:sections(*), guardians(*), student_guardians(guardian:guardians(*)), enrollments(*)",
      { count: "exact" },
    ).eq("school_id", school).range((page - 1) * size, page * size - 1);
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
    return cors({
      success: true,
      data: data ?? [],
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
      "*, section:sections(*), guardians(*), student_guardians(guardian:guardians(*)), medical_records(*), student_documents(*), enrollments(*, section:sections(*), academic_year:academic_years(*))",
    ).eq("id", id).eq("school_id", school).single();
    if (error) return fail(error.message);
    return ok(data);
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

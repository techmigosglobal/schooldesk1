// handlers/uploads.ts — multipart file upload → Supabase Storage
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";
function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}

function textValue(value: unknown, fallback = ""): string {
  const text = `${value ?? ""}`.trim();
  return text || fallback;
}

function roleValue(user: User): string {
  return `${user.app_metadata?.role_name ?? ""}`.trim().toLowerCase();
}

async function parentCanAccessStudent(
  svc: SupabaseClient,
  user: User,
  studentId: string,
) {
  if (roleValue(user) !== "parent") return true;
  if (!studentId) return false;
  const { data, error } = await svc.from("parent_student_links").select(
    "student_id",
  ).eq("parent_user_id", user.id).eq("student_id", studentId).maybeSingle();
  if (error) throw error;
  return Boolean(data);
}

function documentRow(row: Record<string, unknown>) {
  const payload = typeof row.data === "object" && row.data !== null
    ? row.data as Record<string, unknown>
    : row;
  return {
    ...payload,
    id: payload.id ?? row.id ?? row.record_id,
  };
}

async function queueReportExport(
  svc: SupabaseClient,
  school: string,
  user: User,
  tableName: string,
  body: Record<string, unknown>,
) {
  const id = crypto.randomUUID();
  const payload = {
    id,
    report_title: textValue(body.report_title ?? body.report, "Report export"),
    report_type: textValue(body.report_type, "generic"),
    format: textValue(body.format, "pdf").toLowerCase(),
    scope: textValue(body.scope, "school"),
    parameters: body.parameters ?? body,
    status: "queued",
    requested_by: user.id,
    created_at: new Date().toISOString(),
    download_url: "",
  };
  const { data, error } = await svc.from("frontend_records").insert({
    school_id: school,
    table_name: tableName,
    record_id: id,
    data: payload,
  }).select().single();
  if (error) throw error;
  return data?.data ?? payload;
}

export async function handleUploads(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  if (method !== "POST") return fail("method not allowed", 405);

  const form = await req.formData().catch(() => null);
  if (!form) return fail("multipart form required");

  const file = form.get("file") as File;
  if (!file) return fail("file field required");

  const folder = form.get("folder") as string ?? "uploads";
  const entityType = form.get("entity_type") as string ?? "";
  const entityId = form.get("entity_id") as string ?? "";
  const filePath =
    `${folder}/${school}/${entityType}/${entityId}/${Date.now()}-${file.name}`;

  const { error: uploadErr } = await svc.storage.from("school-assets").upload(
    filePath,
    file,
    { upsert: true },
  );
  if (uploadErr) return fail(uploadErr.message);

  const { data: { publicUrl } } = svc.storage.from("school-assets")
    .getPublicUrl(filePath);

  const { data } = await svc.from("uploaded_files").insert({
    school_id: school,
    uploader_id: user.id,
    url: publicUrl,
    path: filePath,
    folder,
    entity_type: entityType,
    entity_id: entityId,
    file_name: file.name,
    file_size: file.size,
    mime_type: file.type,
  }).select().single();

  return ok({ url: publicUrl, file: data });
}

// handlers/events.ts
export async function handleEvents(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};
  const parts = path.slice("/event-posts".length).split("/").filter(Boolean);
  const seg = parts[0];

  if (path === "/event-posts/pending" && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "school_id",
      school,
    ).in("status", ["pending", "submitted"]).order("created_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }
  if (path === "/event-posts/gallery" && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "school_id",
      school,
    ).in("status", ["approved", "published"]).order("created_at", {
      ascending: false,
    }).limit(50);
    if (error) return fail(error.message);
    return ok(data ?? []);
  }
  if (path === "/event-posts/home-feed" && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "school_id",
      school,
    ).in("status", ["approved", "published"]).order("created_at", {
      ascending: false,
    }).limit(20);
    if (error) return fail(error.message);
    return ok(data ?? []);
  }
  if (path === "/event-posts/teacher" && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "school_id",
      school,
    ).eq("created_by", user.id).order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }
  if (!seg && method === "GET") {
    let q = svc.from("event_posts").select("*, created_by:users(name)").eq(
      "school_id",
      school,
    );
    if (url.searchParams.get("status")) {
      q = q.eq("status", url.searchParams.get("status")!);
    }
    const { data, error } = await q.order("created_at", { ascending: false })
      .limit(50);
    if (error) return fail(error.message);
    return ok(data);
  }
  if (!seg && method === "POST") {
    const payload = {
      school_id: school,
      title: body.title,
      body: body.description ?? body.body ?? "",
      media_urls: body.media ?? body.media_urls ?? [],
      visibility: textValue(body.visibility, "school"),
      status: body.is_submit === true ? "pending" : "draft",
      created_by: user.id,
      event_id: body.event_id ?? null,
    };
    const { data, error } = await svc.from("event_posts").insert(payload)
      .select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  if (seg && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "id",
      seg,
    ).eq("school_id", school).maybeSingle();
    if (error) return fail(error.message);
    if (!data) return fail("not found", 404);
    return ok(data);
  }
  if (seg && method === "PUT") {
    const payload = {
      title: body.title,
      body: body.description ?? body.body ?? "",
      media_urls: body.media ?? body.media_urls ?? [],
      visibility: textValue(body.visibility, "school"),
      status: body.is_submit === true
        ? "pending"
        : textValue(body.status, "draft"),
      updated_at: new Date().toISOString(),
      event_id: body.event_id ?? null,
    };
    const { data, error } = await svc.from("event_posts").update(payload).eq(
      "id",
      seg,
    ).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  if (seg && parts[1] === "approve" && method === "POST") {
    const { data, error } = await svc.from("event_posts").update({
      status: "approved",
      updated_at: new Date().toISOString(),
    }).eq("id", seg).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  if (seg && parts[1] === "reject" && method === "POST") {
    const { data, error } = await svc.from("event_posts").update({
      status: "rejected",
      updated_at: new Date().toISOString(),
    }).eq("id", seg).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  if (seg && method === "DELETE") {
    await svc.from("event_posts").delete().eq("id", seg).eq(
      "school_id",
      school,
    );
    return ok({ success: true });
  }
  return fail("not found", 404);
}

export async function handleDocuments(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};
  const url = new URL(req.url);
  if (path === "/student-documents" && method === "GET") {
    const studentId = textValue(url.searchParams.get("student_id"));
    if (studentId && !(await parentCanAccessStudent(svc, user, studentId))) {
      return fail("student not linked to parent", 403);
    }
    let query = svc.from("student_documents").select(
      "*, student:students(id, school_id, first_name, last_name)",
    ).eq("school_id", school);
    if (studentId) query = query.eq("student_id", studentId);
    const { data, error } = await query.order("created_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }
  if (path === "/documents/requests" && method === "GET") {
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "document_requests").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    return ok((data ?? []).map((row) => documentRow(row)));
  }
  if (path === "/documents/requests" && method === "POST") {
    const payload = {
      id: crypto.randomUUID(),
      student_name: textValue(body.student_name, "Student"),
      type: textValue(body.type ?? body.document_type, "Document"),
      status: textValue(body.status, "pending"),
      requested_by: user.id,
      created_at: new Date().toISOString(),
      print_count: 0,
    };
    const { data, error } = await svc.from("frontend_records").insert({
      school_id: school,
      table_name: "document_requests",
      record_id: payload.id,
      data: payload,
    }).select().single();
    if (error) return fail(error.message);
    return ok(documentRow(data));
  }
  const printMatch = path.match(/^\/documents\/requests\/([^/]+)\/prints$/);
  if (printMatch && method === "POST") {
    const { data: existing, error: loadError } = await svc.from(
      "frontend_records",
    ).select("*").eq("school_id", school).eq("table_name", "document_requests")
      .eq("record_id", printMatch[1]).maybeSingle();
    if (loadError) return fail(loadError.message);
    if (!existing) return fail("not found", 404);
    const current = (existing.data as Record<string, unknown> | null) ?? {};
    const next = {
      ...current,
      status: "issued",
      print_count: Number(current.print_count ?? 0) + 1,
      last_print_requested_at: new Date().toISOString(),
    };
    const { data, error } = await svc.from("frontend_records").update({
      data: next,
      updated_at: new Date().toISOString(),
    }).eq("id", existing.id).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(documentRow(data));
  }
  if (path === "/documents/templates" && method === "GET") {
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "document_templates").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    return ok((data ?? []).map((row) => documentRow(row)));
  }
  if (path === "/documents/templates" && method === "POST") {
    const payload = {
      id: crypto.randomUUID(),
      name: textValue(body.name, "Template"),
      document_type: textValue(body.document_type, "Document"),
      body: textValue(body.body),
      status: textValue(body.status, "active"),
      created_by: user.id,
      created_at: new Date().toISOString(),
    };
    const { data, error } = await svc.from("frontend_records").insert({
      school_id: school,
      table_name: "document_templates",
      record_id: payload.id,
      data: payload,
    }).select().single();
    if (error) return fail(error.message);
    return ok(documentRow(data));
  }
  return fail("not found", 404);
}

// handlers/parent.ts — parent access to their children
export async function handleParent(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  if (path === "/me/students" && method === "GET") {
    const { data, error } = await svc.from("parent_student_links").select(
      "student:students(*, section:sections(*, grade:grades(*)), enrollments(*))",
    ).eq("parent_user_id", user.id);
    if (error) return fail(error.message);
    return ok((data ?? []).map((l: Record<string, unknown>) => l.student));
  }
  const parentMatch = path.match(/^\/parents\/([^/]+)\/students$/);
  if (parentMatch && method === "GET") {
    const { data, error } = await svc.from("parent_student_links").select(
      "student:students(*)",
    ).eq("parent_user_id", parentMatch[1]);
    if (error) return fail(error.message);
    return ok((data ?? []).map((l: Record<string, unknown>) => l.student));
  }
  if (parentMatch && method === "POST") {
    const body = await req.json().catch(() => ({}));
    const studentIds = Array.isArray(body.student_ids)
      ? body.student_ids.map((value: unknown) => `${value ?? ""}`.trim())
        .filter(Boolean)
      : [];
    const admissionNumbers = Array.isArray(body.admission_numbers)
      ? body.admission_numbers.map((value: unknown) => `${value ?? ""}`.trim())
        .filter(Boolean)
      : [];

    let resolvedStudentIds = [...studentIds];
    if (admissionNumbers.length > 0) {
      const { data: studentsByAdmission, error } = await svc.from("students")
        .select("id, admission_number").eq("school_id", school).in(
          "admission_number",
          admissionNumbers,
        );
      if (error) return fail(error.message);
      resolvedStudentIds.push(
        ...((studentsByAdmission ?? []).map((row: Record<string, unknown>) =>
          `${row.id ?? ""}`.trim()
        ).filter(Boolean)),
      );
    }

    resolvedStudentIds = [...new Set(resolvedStudentIds)];
    if (resolvedStudentIds.length === 0) {
      return fail("student_ids or admission_numbers required");
    }

    const rows = resolvedStudentIds.map((studentId) => ({
      school_id: school,
      parent_user_id: parentMatch[1],
      student_id: studentId,
    }));
    const { data, error } = await svc.from("parent_student_links").upsert(
      rows,
      {
        onConflict: "parent_user_id,student_id",
      },
    ).select();
    if (error) return fail(error.message);
    return ok({ links: data ?? [], student_ids: resolvedStudentIds });
  }
  return fail("not found", 404);
}

// handlers/reports.ts — non-exam reports
export async function handleReports(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  if (path === "/reports/exports" && method === "POST") {
    try {
      const body = await req.json().catch(() => ({}));
      const data = await queueReportExport(
        svc,
        school,
        user,
        "report_exports",
        body,
      );
      return ok(data);
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "failed to queue report export",
      );
    }
  }
  if (path === "/reports/exports" && method === "GET") {
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "report_exports").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    return ok((data ?? []).map((row) => documentRow(row)));
  }
  if (path === "/reports/attendance" && method === "GET") {
    const { data, error } = await svc.from("attendance_summaries").select(
      "*, student:students(first_name, last_name, admission_number, current_section_id)",
    ).eq("school_id", school);
    if (error) return fail(error.message);
    return ok(data);
  }
  if (path === "/reports/fees" && method === "GET") {
    const { data, error } = await svc.from("fee_invoices").select(
      "*, student:students(first_name, last_name, admission_number)",
    ).eq("school_id", school).order("invoice_date", { ascending: false });
    if (error) return fail(error.message);
    return ok(data);
  }
  if (path === "/reports/staff" && method === "GET") {
    const { data, error } = await svc.from("staff").select(
      "*, department:departments(department_name), staff_subjects(*, subject:subjects(*))",
    ).eq("school_id", school);
    if (error) return fail(error.message);
    return ok(data);
  }
  return fail("not found", 404);
}

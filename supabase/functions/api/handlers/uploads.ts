// handlers/uploads.ts — multipart file upload → Supabase Storage
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, runDbStatements } from "../index.ts";
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

function asStringArray(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.map((item) => `${item ?? ""}`.trim()).filter(Boolean);
  }
  if (typeof value === "string") {
    const text = value.trim();
    if (text.startsWith("[") && text.endsWith("]")) {
      try {
        return asStringArray(JSON.parse(text));
      } catch {
        // Fall back to comma-separated parsing below.
      }
    }
    return text.split(",").map((item) => item.trim()).filter(Boolean);
  }
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    return Object.values(record).map((item) => `${item ?? ""}`.trim()).filter(
      Boolean,
    );
  }
  return [];
}

function normalizeDestinations(value: unknown, visibility: unknown): string[] {
  const destinations = asStringArray(value);
  if (destinations.length > 0) return [...new Set(destinations)];
  const normalizedVisibility = `${visibility ?? ""}`.trim().toLowerCase();
  if (normalizedVisibility === "public") return ["SCHOOL_LANDING"];
  if (normalizedVisibility === "gallery") return ["SCHOOL_GALLERY"];
  return ["PARENTS_HOME"];
}

function approvedEventDestinations(value: unknown, visibility: unknown): string[] {
  return [
    ...new Set([
      ...normalizeDestinations(value, visibility),
      "PARENTS_HOME",
      "SCHOOL_GALLERY",
    ]),
  ];
}

function eventPostRow(row: Record<string, unknown>) {
  const description = `${row.description ?? row.body ?? ""}`;
  const approvalStatus = `${row.approval_status ?? row.status ?? "draft"}`;
  const destinations = normalizeDestinations(row.destinations, row.visibility);
  return {
    ...row,
    description,
    body: description,
    approval_status: approvalStatus,
    status: approvalStatus,
    destinations,
    visibility: `${row.visibility ?? "school"}`,
    event_date: row.event_date ?? row.created_at ?? null,
    rejection_reason: row.rejection_reason ?? "",
  };
}

async function notifyUsersByRole(
  svc: SupabaseClient,
  school: string,
  roleName: string,
  payload: {
    title: string;
    body: string;
    type: string;
    referenceType: string;
    referenceId: string;
  },
) {
  const { data: users, error } = await svc.from("users").select("id").eq(
    "school_id",
    school,
  ).eq("role_name", roleName);
  if (error) throw error;
  const userIds = (users ?? []).map((row: Record<string, unknown>) =>
    `${row.id ?? ""}`.trim()
  ).filter(Boolean);
  if (userIds.length === 0) return;
  const rows = userIds.map((userId) => ({
    school_id: school,
    user_id: userId,
    target_role: roleName,
    title: payload.title,
    body: payload.body,
    type: payload.type,
    entity_type: payload.referenceType,
    entity_id: payload.referenceId,
  }));
  const { error: insertError } = await svc.from("notification_logs").insert(rows);
  if (insertError) throw insertError;
}

async function notifyUser(
  svc: SupabaseClient,
  school: string,
  userId: string,
  payload: {
    title: string;
    body: string;
    type: string;
    referenceType: string;
    referenceId: string;
  },
) {
  if (!userId.trim()) return;
  const { error } = await svc.from("notification_logs").insert({
    school_id: school,
    user_id: userId,
    target_role: "teacher",
    title: payload.title,
    body: payload.body,
    type: payload.type,
    entity_type: payload.referenceType,
    entity_id: payload.referenceId,
  });
  if (error) throw error;
}

let eventPostSchemaReady = false;
let eventPostSchemaPromise: Promise<void> | null = null;

async function ensureEventPostSchema() {
  if (eventPostSchemaReady) return;
  if (eventPostSchemaPromise) return eventPostSchemaPromise;
  eventPostSchemaPromise = (async () => {
    try {
      await runDbStatements([
        `alter table public.notification_logs
          add column if not exists target_role text`,
        `create index if not exists idx_notification_logs_target_role
          on public.notification_logs(target_role, created_at desc)`,
        `alter table public.event_posts
          add column if not exists event_date timestamptz`,
        `alter table public.event_posts
          add column if not exists destinations jsonb not null default '[]'::jsonb`,
        `alter table public.event_posts
          add column if not exists rejection_reason text`,
        `alter table public.event_posts
          add column if not exists approved_by uuid references public.users(id) on delete set null`,
        `alter table public.event_posts
          add column if not exists approved_at timestamptz`,
        `update public.event_posts
          set destinations = case
            when visibility = 'public' then '["SCHOOL_LANDING"]'::jsonb
            when visibility = 'gallery' then '["SCHOOL_GALLERY"]'::jsonb
            else '["PARENTS_HOME"]'::jsonb
          end
          where destinations is null
             or jsonb_typeof(destinations) is distinct from 'array'
             or destinations = '[]'::jsonb`,
        `update public.event_posts
          set event_date = coalesce(event_date, created_at)
          where event_date is null`,
        `update public.event_posts
          set destinations = '["PARENTS_HOME","SCHOOL_GALLERY"]'::jsonb
          where status in ('approved', 'published')
            and (
              destinations is null
              or jsonb_typeof(destinations) is distinct from 'array'
              or not (destinations @> '["PARENTS_HOME"]'::jsonb)
              or not (destinations @> '["SCHOOL_GALLERY"]'::jsonb)
            )`,
        `create index if not exists idx_event_posts_school_status
          on public.event_posts(school_id, status, created_at desc)`,
      ]);
    } catch {
      // Best-effort: if the schema is already current or direct SQL is unavailable,
      // the handler still proceeds and PostgREST responses remain the source of truth.
    } finally {
      eventPostSchemaReady = true;
      eventPostSchemaPromise = null;
    }
  })();
  return eventPostSchemaPromise;
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
  await ensureEventPostSchema();
  const school = sid(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};
  const parts = path.slice("/event-posts".length).split("/").filter(Boolean);
  const seg = parts[0];

  if (path === "/event-posts/pending" && method === "GET") {
    if (roleValue(user) !== "principal") return fail("forbidden", 403);
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "school_id",
      school,
    ).in("status", ["pending", "submitted"]).order("created_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    return ok((data ?? []).map((row) => eventPostRow(row as Record<string, unknown>)));
  }
  if (path === "/event-posts/gallery" && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "school_id",
      school,
    ).in("status", ["approved", "published"]).order("created_at", {
      ascending: false,
    }).limit(50);
    if (error) return fail(error.message);
    return ok((data ?? []).map((row) => eventPostRow(row as Record<string, unknown>))
      .filter((row) => row.destinations.includes("SCHOOL_GALLERY")));
  }
  if (path === "/event-posts/home-feed" && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "school_id",
      school,
    ).in("status", ["approved", "published"]).order("created_at", {
      ascending: false,
    }).limit(20);
    if (error) return fail(error.message);
    return ok((data ?? []).map((row) => eventPostRow(row as Record<string, unknown>))
      .filter((row) => row.destinations.includes("PARENTS_HOME")));
  }
  if (path === "/event-posts/teacher" && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "school_id",
      school,
    ).eq("created_by", user.id).order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok((data ?? []).map((row) => eventPostRow(row as Record<string, unknown>)));
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
    return ok((data ?? []).map((row) => eventPostRow(row as Record<string, unknown>)));
  }
  if (!seg && method === "POST") {
    const description = textValue(body.description ?? body.body);
    const destinations = normalizeDestinations(
      body.destinations,
      body.visibility,
    );
    const payload = {
      school_id: school,
      title: textValue(body.title, "Untitled event post"),
      body: description,
      media_urls: body.media ?? body.media_urls ?? [],
      visibility: textValue(body.visibility, "school"),
      destinations,
      event_date: body.event_date ?? new Date().toISOString(),
      status: body.is_submit === true ? "pending" : "draft",
      created_by: user.id,
      event_id: body.event_id ?? null,
      rejection_reason: null,
    };
    const { data, error } = await svc.from("event_posts").insert(payload)
      .select().single();
    if (error) return fail(error.message);
    if (body.is_submit === true) {
      try {
        await notifyUsersByRole(svc, school, "principal", {
          title: "Event post pending approval",
          body: `${payload.title} was submitted for review.`,
          type: "pending_approval",
          referenceType: "event_post",
          referenceId: `${data.id ?? ""}`,
        });
      } catch {
        // Keep the event post creation successful even if notification fan-out fails.
      }
    }
    return ok(eventPostRow(data as Record<string, unknown>));
  }
  if (seg && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "id",
      seg,
    ).eq("school_id", school).maybeSingle();
    if (error) return fail(error.message);
    if (!data) return fail("not found", 404);
    return ok(eventPostRow(data as Record<string, unknown>));
  }
  if (seg && method === "PUT") {
    const { data: existing, error: existingError } = await svc.from("event_posts")
      .select("*").eq("id", seg).eq("school_id", school).maybeSingle();
    if (existingError) return fail(existingError.message);
    if (!existing) return fail("not found", 404);
    const userRole = roleValue(user);
    if (userRole !== "principal" && `${existing.created_by ?? ""}` !== user.id) {
      return fail("forbidden", 403);
    }
    const currentStatus = `${existing.status ?? "draft"}`.trim().toLowerCase();
    const description = textValue(body.description ?? body.body);
    const destinations = normalizeDestinations(
      body.destinations ?? existing.destinations,
      body.visibility ?? existing.visibility,
    );
    const payload = {
      title: textValue(body.title, `${existing.title ?? "Untitled event post"}`),
      body: description,
      media_urls: body.media ?? body.media_urls ?? [],
      visibility: textValue(body.visibility, "school"),
      destinations,
      event_date: body.event_date ?? existing.event_date ?? new Date().toISOString(),
      status: body.is_submit === true
        ? "pending"
        : textValue(body.status, currentStatus),
      updated_at: new Date().toISOString(),
      event_id: body.event_id ?? null,
      rejection_reason: body.is_submit === true
        ? null
        : body.rejection_reason ?? existing.rejection_reason ?? null,
    };
    const { data, error } = await svc.from("event_posts").update(payload).eq(
      "id",
      seg,
    ).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(eventPostRow(data as Record<string, unknown>));
  }
  if (seg && parts[1] === "approve" && method === "POST") {
    if (roleValue(user) !== "principal") return fail("forbidden", 403);
    const { data: existing, error: existingError } = await svc.from("event_posts")
      .select("*").eq("id", seg).eq("school_id", school).maybeSingle();
    if (existingError) return fail(existingError.message);
    if (!existing) return fail("not found", 404);
    const { data, error } = await svc.from("event_posts").update({
      status: "approved",
      destinations: approvedEventDestinations(
        existing.destinations,
        existing.visibility,
      ),
      approved_by: user.id,
      approved_at: new Date().toISOString(),
      rejection_reason: null,
      updated_at: new Date().toISOString(),
    }).eq("id", seg).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    try {
      await notifyUser(svc, school, `${existing.created_by ?? ""}`, {
        title: "Event post approved",
        body: `${existing.title ?? "Your event post"} was approved by the principal.`,
        type: "pending_approval",
        referenceType: "event_post",
        referenceId: seg,
      });
    } catch {
      // Approval itself is the source of truth; notification failures should not block it.
    }
    return ok(eventPostRow(data as Record<string, unknown>));
  }
  if (seg && parts[1] === "reject" && method === "POST") {
    if (roleValue(user) !== "principal") return fail("forbidden", 403);
    const { data: existing, error: existingError } = await svc.from("event_posts")
      .select("*").eq("id", seg).eq("school_id", school).maybeSingle();
    if (existingError) return fail(existingError.message);
    if (!existing) return fail("not found", 404);
    const { data, error } = await svc.from("event_posts").update({
      status: "rejected",
      rejection_reason: textValue(body.reason, "Principal requested changes."),
      updated_at: new Date().toISOString(),
    }).eq("id", seg).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    try {
      await notifyUser(svc, school, `${existing.created_by ?? ""}`, {
        title: "Event post rejected",
        body: textValue(body.reason, "Principal requested changes."),
        type: "pending_approval",
        referenceType: "event_post",
        referenceId: seg,
      });
    } catch {
      // Keep the rejection successful even if the notification insert fails.
    }
    return ok(eventPostRow(data as Record<string, unknown>));
  }
  if (seg && method === "DELETE") {
    const userRole = roleValue(user);
    if (!["principal", "teacher"].includes(userRole)) {
      return fail("forbidden", 403);
    }
    let deleteQuery = svc.from("event_posts").delete().eq("id", seg).eq(
      "school_id",
      school,
    );
    if (userRole !== "principal") {
      deleteQuery = deleteQuery.eq("created_by", user.id);
    }
    const { error } = await deleteQuery;
    if (error) return fail(error.message);
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

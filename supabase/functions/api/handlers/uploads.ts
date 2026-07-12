// handlers/uploads.ts — multipart file upload → Supabase Storage
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, runDbStatements, triggerPushProcessing } from "../index.ts";
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

function approvedEventDestinations(
  value: unknown,
  visibility: unknown,
): string[] {
  // Approval must preserve the teacher's selected audiences. In particular, a
  // SCHOOL_LANDING-only post is an image carousel item and must not leak into
  // the parent home feed or gallery.
  return normalizeDestinations(value, visibility);
}

function eventMediaItems(value: unknown): Array<Record<string, unknown>> {
  if (!Array.isArray(value)) return [];
  return value.map((item) => {
    if (item && typeof item === "object") {
      return item as Record<string, unknown>;
    }
    return { url: textValue(item) };
  });
}

function isImageEventMedia(item: Record<string, unknown>): boolean {
  const kind = textValue(item.kind ?? item.type).toLowerCase();
  const mime = textValue(item.mime_type ?? item.mimeType ?? item.content_type)
    .toLowerCase();
  const url = textValue(item.url ?? item.media_url ?? item.mediaUrl)
    .toLowerCase().split("?")[0];
  return kind === "image" || kind === "photo" || mime.startsWith("image/") ||
    /\.(jpe?g|png|webp|gif|heic)$/.test(url);
}

function validateEventMedia(
  rawMedia: unknown,
  destinations: string[],
): string | null {
  const media = eventMediaItems(rawMedia);
  if (media.length > 0 && media.some((item) => !isImageEventMedia(item))) {
    return "Event posts accept images only";
  }
  if (destinations.includes("SCHOOL_LANDING") && media.length === 0) {
    return "Landing page posts require at least one image";
  }
  return null;
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
  const { error: insertError } = await svc.from("notification_logs").insert(
    rows,
  );
  if (insertError) throw insertError;
  const { data: events, error: eventError } = await svc.from(
    "notification_events",
  )
    .insert(
      rows.map((row) => ({
        school_id: row.school_id,
        user_id: row.user_id,
        event_type: row.entity_type,
        event_data: {
          title: row.title,
          message: row.body,
          reference_type: row.entity_type,
          reference_id: row.entity_id,
        },
      })),
    )
    .select("id");
  if (eventError) throw eventError;
  const eventIds = (events ?? []).map((row) => textValue(row.id)).filter(
    Boolean,
  );
  if (eventIds.length > 0) triggerPushProcessing(eventIds);
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
  const { data: eventRow, error: eventError } = await svc.from(
    "notification_events",
  )
    .insert({
      school_id: school,
      user_id: userId,
      event_type: payload.referenceType,
      event_data: {
        title: payload.title,
        message: payload.body,
        reference_type: payload.referenceType,
        reference_id: payload.referenceId,
      },
    })
    .select("id")
    .maybeSingle();
  if (eventError) throw eventError;
  if (eventRow?.id) triggerPushProcessing(eventRow.id);
}

let eventPostSchemaReady = false;
let eventPostSchemaPromise: Promise<void> | null = null;

// deno-lint-ignore require-await
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

async function performReportExport(
  svc: SupabaseClient,
  school: string,
  tableName: string,
  reportType: string,
  parameters: Record<string, any>,
): Promise<string> {
  const escape = (value: unknown) => {
    const text = `${value ?? ""}`.replace(/"/g, '""');
    return /[",\n]/.test(text) ? `"${text}"` : text;
  };

  const toCsv = (headers: string[], rows: unknown[][]) => {
    const headerLine = headers.join(",");
    const lines = rows.map((row) => row.map(escape).join(","));
    return [headerLine, ...lines].join("\n");
  };

  let headers: string[] = ["Report Export"];
  let rows: unknown[][] = [["No data generated"]];

  if (tableName === "report_exports") {
    if (reportType === "users_wise_export") {
      let query = svc.from("users").select(
        "name, email, role_name, is_active, created_at",
      ).eq("school_id", school);
      if (
        parameters.roles && Array.isArray(parameters.roles) &&
        parameters.roles.length > 0
      ) {
        query = query.in("role_name", parameters.roles);
      }
      if (parameters.status && parameters.status !== "all") {
        query = query.eq("is_active", parameters.status === "active");
      }
      const { data } = await query;
      headers = ["Name", "Email", "Role", "Status", "Created At"];
      rows = (data ?? []).map((u: any) => [
        u.name,
        u.email,
        u.role_name,
        u.is_active ? "Active" : "Inactive",
        u.created_at,
      ]);
    } else if (reportType === "students_list") {
      let query = svc.from("students").select(
        "first_name, last_name, admission_number, status, gender, date_of_birth, section:sections(section_name, grade:grades(grade_name))",
      ).eq("school_id", school);
      if (parameters.section_id) {
        query = query.eq("current_section_id", parameters.section_id);
      } else if (parameters.grade_id) {
        const { data: sections } = await svc.from("sections").select("id").eq(
          "grade_id",
          parameters.grade_id,
        );
        const secIds = (sections ?? []).map((s: any) => s.id);
        if (secIds.length > 0) {
          query = query.in("current_section_id", secIds);
        }
      }
      const { data } = await query;
      headers = [
        "Admission Number",
        "First Name",
        "Last Name",
        "Gender",
        "Date of Birth",
        "Grade",
        "Section",
        "Status",
      ];
      rows = (data ?? []).map((s: any) => [
        s.admission_number,
        s.first_name,
        s.last_name,
        s.gender,
        s.date_of_birth,
        s.section?.grade?.grade_name,
        s.section?.section_name,
        s.status,
      ]);
    } else if (
      reportType === "class_summary" || reportType === "complete_classwise_data"
    ) {
      const { data } = await svc.from("sections").select(
        "*, grade:grades(grade_name), class_teacher:staff!sections_class_teacher_id_fkey(first_name, last_name)",
      ).eq("school_id", school);
      headers = ["Grade", "Section", "Capacity", "Class Teacher"];
      rows = (data ?? []).map((s: any) => [
        s.grade?.grade_name,
        s.section_name,
        s.capacity,
        s.class_teacher
          ? `${s.class_teacher.first_name} ${s.class_teacher.last_name}`.trim()
          : "Pending",
      ]);
    } else if (reportType === "teacher_mapping") {
      const { data } = await svc.from("sections").select(
        "*, grade:grades(grade_name), class_teacher:staff!sections_class_teacher_id_fkey(first_name, last_name), co_teacher:staff!sections_co_teacher_id_fkey(first_name, last_name)",
      ).eq("school_id", school);
      headers = ["Grade", "Section", "Class Teacher", "Co-Teacher"];
      rows = (data ?? []).map((s: any) => [
        s.grade?.grade_name,
        s.section_name,
        s.class_teacher
          ? `${s.class_teacher.first_name} ${s.class_teacher.last_name}`.trim()
          : "Pending",
        s.co_teacher
          ? `${s.co_teacher.first_name} ${s.co_teacher.last_name}`.trim()
          : "Pending",
      ]);
    } else if (
      reportType === "subjects_mapping" || reportType === "timetable_summary"
    ) {
      const { data } = await svc.from("timetable_slots").select(
        "*, section:sections(section_name, grade:grades(grade_name)), subject:subjects(subject_name), staff:staff(first_name, last_name)",
      ).eq("school_id", school);
      headers = [
        "Grade",
        "Section",
        "Subject",
        "Teacher",
        "Day of Week",
        "Start Time",
        "End Time",
      ];
      rows = (data ?? []).map((sl: any) => [
        sl.section?.grade?.grade_name,
        sl.section?.section_name,
        sl.subject?.subject_name,
        sl.staff ? `${sl.staff.first_name} ${sl.staff.last_name}`.trim() : "",
        sl.day_of_week,
        sl.start_time,
        sl.end_time,
      ]);
    } else {
      const { data } = await svc.from("sections").select(
        "*, grade:grades(grade_name)",
      ).eq("school_id", school);
      headers = ["Grade", "Section", "Capacity"];
      rows = (data ?? []).map((s: any) => [
        s.grade?.grade_name,
        s.section_name,
        s.capacity,
      ]);
    }
  } else if (tableName === "fee_report_exports") {
    if (reportType === "receipt_export") {
      const txId = parameters.transaction_id ||
        parameters.parameters?.transaction_id || parameters.receipt_number;
      let query = svc.from("payments").select(
        "*, invoice:fee_invoices(*, student:students(first_name, last_name, admission_number))",
      ).eq("school_id", school);
      const isUuid =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          `${txId}`,
        );
      if (isUuid) {
        query = query.eq("id", txId);
      } else {
        query = query.eq("reference_number", txId);
      }
      const { data } = await query.maybeSingle();
      headers = ["Transaction Attribute", "Value"];
      if (data) {
        rows = [
          ["Transaction ID", data.id],
          [
            "Student Name",
            data.invoice?.student
              ? `${data.invoice.student.first_name} ${data.invoice.student.last_name}`
                .trim()
              : "",
          ],
          ["Admission Number", data.invoice?.student?.admission_number],
          ["Invoice", data.invoice?.title],
          ["Amount Paid", data.amount],
          ["Payment Date", data.paid_at],
          ["Payment Mode", data.payment_method],
          ["Status", data.status],
        ];
      } else {
        rows = [["Receipt not found", txId]];
      }
    } else if (
      reportType === "fee_outstanding_report" ||
      reportType === "outstanding_report"
    ) {
      const { data } = await svc.from("fee_invoices").select(
        "*, student:students(first_name, last_name, admission_number)",
      ).eq("school_id", school).gt("balance", 0);
      headers = [
        "Student Name",
        "Admission Number",
        "Invoice Title",
        "Due Date",
        "Amount",
        "Balance",
      ];
      rows = (data ?? []).map((i: any) => [
        i.student
          ? `${i.student.first_name} ${i.student.last_name}`.trim()
          : "",
        i.student?.admission_number,
        i.title,
        i.due_date,
        i.amount,
        i.balance,
      ]);
    } else {
      const { data } = await svc.from("payments").select(
        "*, invoice:fee_invoices(*, student:students(first_name, last_name, admission_number))",
      ).eq("school_id", school);
      headers = [
        "Transaction ID",
        "Student Name",
        "Admission Number",
        "Invoice",
        "Amount Paid",
        "Payment Date",
        "Payment Mode",
        "Status",
      ];
      rows = (data ?? []).map((p: any) => [
        p.id,
        p.invoice?.student
          ? `${p.invoice.student.first_name} ${p.invoice.student.last_name}`
            .trim()
          : "",
        p.invoice?.student?.admission_number,
        p.invoice?.title,
        p.amount,
        p.paid_at,
        p.payment_method,
        p.status,
      ]);
    }
  } else if (tableName === "attendance_report_exports") {
    const { data } = await svc.from("attendance_summaries").select(
      "*, student:students(first_name, last_name, admission_number)",
    ).eq("school_id", school);
    headers = [
      "Student Name",
      "Admission Number",
      "Total Days",
      "Present Days",
      "Absent Days",
      "Attendance %",
    ];
    rows = (data ?? []).map((a: any) => [
      a.student ? `${a.student.first_name} ${a.student.last_name}`.trim() : "",
      a.student?.admission_number,
      a.total_days,
      a.present_days,
      a.absent_days,
      a.percentage,
    ]);
  }

  const csvContent = toCsv(headers, rows);
  const fileId = crypto.randomUUID();
  const filePath = `exports/${school}/${fileId}.csv`;

  const { error: uploadError } = await svc.storage.from("school-assets").upload(
    filePath,
    new TextEncoder().encode(csvContent),
    { contentType: "text/csv", upsert: true },
  );
  if (uploadError) {
    console.error("Failed to upload report to storage:", uploadError);
    throw uploadError;
  }

  const publicUrl =
    svc.storage.from("school-assets").getPublicUrl(filePath).data.publicUrl;
  return publicUrl;
}

export async function queueReportExport(
  svc: SupabaseClient,
  school: string,
  user: User,
  tableName: string,
  body: Record<string, unknown>,
) {
  const id = crypto.randomUUID();
  const report_type = textValue(body.report_type, "generic");
  const parameters = body.parameters ?? body;

  let status = "queued";
  let downloadUrl = "";

  try {
    downloadUrl = await performReportExport(
      svc,
      school,
      tableName,
      report_type,
      parameters,
    );
    status = "completed";
  } catch (err) {
    console.error(
      "Synchronous report generation failed, fallback to queued:",
      err,
    );
  }

  const payload = {
    id,
    report_title: textValue(body.report_title ?? body.report, "Report export"),
    report_type,
    format: textValue(body.format, "pdf").toLowerCase(),
    scope: textValue(body.scope, "school"),
    parameters,
    status,
    requested_by: user.id,
    created_at: new Date().toISOString(),
    download_url: downloadUrl,
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
    return ok(
      (data ?? []).map((row) => eventPostRow(row as Record<string, unknown>)),
    );
  }
  if (path === "/event-posts/gallery" && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "school_id",
      school,
    ).in("status", ["approved", "published"]).order("created_at", {
      ascending: false,
    }).limit(50);
    if (error) return fail(error.message);
    return ok(
      (data ?? []).map((row) => eventPostRow(row as Record<string, unknown>))
        .filter((row) => row.destinations.includes("SCHOOL_GALLERY")),
    );
  }
  if (path === "/event-posts/home-feed" && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "school_id",
      school,
    ).in("status", ["approved", "published"]).order("created_at", {
      ascending: false,
    }).limit(20);
    if (error) return fail(error.message);
    return ok(
      (data ?? []).map((row) => eventPostRow(row as Record<string, unknown>))
        .filter((row) => row.destinations.includes("PARENTS_HOME")),
    );
  }
  if (path === "/event-posts/teacher" && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "school_id",
      school,
    ).eq("created_by", user.id).order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok(
      (data ?? []).map((row) => eventPostRow(row as Record<string, unknown>)),
    );
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
    return ok(
      (data ?? []).map((row) => eventPostRow(row as Record<string, unknown>)),
    );
  }
  if (!seg && method === "POST") {
    const description = textValue(body.description ?? body.body);
    const destinations = normalizeDestinations(
      body.destinations,
      body.visibility,
    );
    const media = body.media ?? body.media_urls ?? [];
    const mediaError = validateEventMedia(media, destinations);
    if (mediaError) return fail(mediaError, 420);
    const payload = {
      school_id: school,
      title: textValue(body.title, "Untitled event post"),
      body: description,
      media_urls: media,
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
    const { data: existing, error: existingError } = await svc.from(
      "event_posts",
    )
      .select("*").eq("id", seg).eq("school_id", school).maybeSingle();
    if (existingError) return fail(existingError.message);
    if (!existing) return fail("not found", 404);
    const userRole = roleValue(user);
    if (
      userRole !== "principal" && `${existing.created_by ?? ""}` !== user.id
    ) {
      return fail("forbidden", 403);
    }
    const currentStatus = `${existing.status ?? "draft"}`.trim().toLowerCase();
    const description = textValue(body.description ?? body.body);
    const destinations = normalizeDestinations(
      body.destinations ?? existing.destinations,
      body.visibility ?? existing.visibility,
    );
    const media = body.media ?? body.media_urls ?? existing.media_urls ?? [];
    const mediaError = validateEventMedia(media, destinations);
    if (mediaError) return fail(mediaError, 420);
    const payload = {
      title: textValue(
        body.title,
        `${existing.title ?? "Untitled event post"}`,
      ),
      body: description,
      media_urls: media,
      visibility: textValue(body.visibility, "school"),
      destinations,
      event_date: body.event_date ?? existing.event_date ??
        new Date().toISOString(),
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
    const { data: existing, error: existingError } = await svc.from(
      "event_posts",
    )
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
        body: `${
          existing.title ?? "Your event post"
        } was approved by the principal.`,
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
    const { data: existing, error: existingError } = await svc.from(
      "event_posts",
    )
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
    const userRole = roleValue(user);
    let query = svc.from("student_documents").select(
      "*, student:students(id, school_id, first_name, last_name, current_section_id)",
    ).eq("school_id", school);

    if (userRole === "parent") {
      const { data: links, error: linkErr } = await svc.from(
        "parent_student_links",
      ).select("student_id").eq("parent_user_id", user.id);
      if (linkErr) return fail(linkErr.message);
      const parentStudentIds = (links ?? []).map((l) => l.student_id);
      if (studentId) {
        if (!parentStudentIds.includes(studentId)) {
          return fail("student not linked to parent", 403);
        }
        query = query.eq("student_id", studentId);
      } else {
        query = query.in("student_id", parentStudentIds);
      }
    } else {
      if (studentId) {
        query = query.eq("student_id", studentId);
      }
      const sectionId = textValue(url.searchParams.get("section_id"));
      if (sectionId) {
        const { data: students, error: studErr } = await svc.from("students")
          .select("id").eq("current_section_id", sectionId);
        if (studErr) return fail(studErr.message);
        const ids = (students ?? []).map((s) => s.id);
        query = query.in("student_id", ids);
      }
    }

    const { data, error } = await query.order("created_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  if (path === "/student-documents" && method === "POST") {
    const studentId = textValue(body.student_id);
    if (!studentId) return fail("student_id required");
    const userRole = roleValue(user);
    if (
      userRole === "parent" &&
      !(await parentCanAccessStudent(svc, user, studentId))
    ) {
      return fail("student not linked to parent", 403);
    }
    const docType = textValue(body.doc_type || body.type, "other");
    const fileUrl = textValue(body.file_url);
    const title = textValue(body.title);
    if (!fileUrl) return fail("file_url required");

    const { data, error } = await svc.from("student_documents").insert({
      student_id: studentId,
      school_id: school,
      doc_type: docType,
      file_url: fileUrl,
      title: title,
    }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  const studentDocMatch = path.match(/^\/student-documents\/([^/]+)$/);
  if (studentDocMatch && method === "DELETE") {
    const docId = studentDocMatch[1];
    const userRole = roleValue(user);
    if (userRole === "principal") {
      const { error } = await svc.from("student_documents").delete().eq(
        "id",
        docId,
      ).eq("school_id", school);
      if (error) return fail(error.message);
      return ok({ success: true });
    } else if (userRole === "parent") {
      const { data: doc, error: getErr } = await svc.from("student_documents")
        .select("student_id").eq("id", docId).maybeSingle();
      if (getErr) return fail(getErr.message);
      if (!doc) return fail("not found", 404);
      if (!(await parentCanAccessStudent(svc, user, doc.student_id))) {
        return fail("unauthorized", 403);
      }
      const { error } = await svc.from("student_documents").delete().eq(
        "id",
        docId,
      ).eq("school_id", school);
      if (error) return fail(error.message);
      return ok({ success: true });
    } else {
      return fail("unauthorized", 403);
    }
  }

  if (path === "/staff-documents" && method === "GET") {
    const userRole = roleValue(user);
    const staffId = textValue(url.searchParams.get("staff_id"));
    if (userRole === "teacher") {
      const myStaffId = (user.app_metadata?.linked_id as string | undefined) ??
        "";
      if (!myStaffId) return fail("user not linked to staff", 400);
      const { data, error } = await svc.from("staff_documents").select(
        "*, staff:staff(id, school_id, first_name, last_name)",
      ).eq("school_id", school).eq("staff_id", myStaffId).order("created_at", {
        ascending: false,
      });
      if (error) return fail(error.message);
      return ok(data ?? []);
    } else if (userRole === "principal") {
      let query = svc.from("staff_documents").select(
        "*, staff:staff(id, school_id, first_name, last_name)",
      ).eq("school_id", school);
      if (staffId) {
        query = query.eq("staff_id", staffId);
      }
      const { data, error } = await query.order("created_at", {
        ascending: false,
      });
      if (error) return fail(error.message);
      return ok(data ?? []);
    } else {
      return fail("unauthorized", 403);
    }
  }

  if (path === "/staff-documents" && method === "POST") {
    const userRole = roleValue(user);
    let staffId = textValue(body.staff_id);
    if (userRole === "teacher") {
      const myStaffId = (user.app_metadata?.linked_id as string | undefined) ??
        "";
      if (!myStaffId) return fail("user not linked to staff", 400);
      staffId = myStaffId;
    } else if (userRole !== "principal") {
      return fail("unauthorized", 403);
    }
    if (!staffId) return fail("staff_id required");
    const docType = textValue(body.doc_type || body.type, "other");
    const fileUrl = textValue(body.file_url);
    const title = textValue(body.title);
    if (!fileUrl) return fail("file_url required");

    const { data, error } = await svc.from("staff_documents").insert({
      staff_id: staffId,
      school_id: school,
      doc_type: docType,
      file_url: fileUrl,
      title: title,
    }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  const staffDocMatch = path.match(/^\/staff-documents\/([^/]+)$/);
  if (staffDocMatch && method === "DELETE") {
    const docId = staffDocMatch[1];
    const userRole = roleValue(user);
    if (userRole === "principal") {
      const { error } = await svc.from("staff_documents").delete().eq(
        "id",
        docId,
      ).eq("school_id", school);
      if (error) return fail(error.message);
      return ok({ success: true });
    } else if (userRole === "teacher") {
      const myStaffId = (user.app_metadata?.linked_id as string | undefined) ??
        "";
      if (!myStaffId) return fail("user not linked to staff", 400);
      const { data: doc, error: getErr } = await svc.from("staff_documents")
        .select("staff_id").eq("id", docId).maybeSingle();
      if (getErr) return fail(getErr.message);
      if (!doc) return fail("not found", 404);
      if (doc.staff_id !== myStaffId) {
        return fail("unauthorized", 403);
      }
      const { error } = await svc.from("staff_documents").delete().eq(
        "id",
        docId,
      ).eq("school_id", school);
      if (error) return fail(error.message);
      return ok({ success: true });
    } else {
      return fail("unauthorized", 403);
    }
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
  _url: URL,
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

// Public (no-auth) endpoint — serves approved SCHOOL_LANDING posts for the
// pre-login carousel.  Requires ?school_id=<uuid> query param.
export async function handleLandingFeed(
  _req: Request,
  url: URL,
  svc: SupabaseClient,
): Promise<Response> {
  const schoolId = url.searchParams.get("school_id")?.trim() ?? "";
  if (!schoolId) return fail("school_id is required", 400);

  const { data, error } = await svc.from("event_posts")
    .select(
      "id, title, body, description, media_urls, event_date, created_at, destinations, visibility",
    )
    .eq("school_id", schoolId)
    .in("status", ["approved", "published"])
    .order("created_at", { ascending: false })
    .limit(10);

  if (error) return fail(error.message);

  const rows = (data ?? [])
    .map((row) => eventPostRow(row as Record<string, unknown>))
    .filter((row) => row.destinations.includes("SCHOOL_LANDING"));

  return ok(rows);
}

// handlers/health_reminders.ts - day-specific parent health reminders.
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, triggerPushProcessing } from "../index.ts";

function sid(user: User) {
  return (user.app_metadata?.school_id as string) ?? "";
}

function role(user: User) {
  return `${user.app_metadata?.role_name ?? ""}`.trim().toLowerCase();
}

function text(value: unknown, fallback = "") {
  const clean = `${value ?? ""}`.trim();
  return clean || fallback;
}

function todayIso() {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const value = (type: string) =>
    parts.find((part) => part.type === type)?.value ?? "";
  return `${value("year")}-${value("month")}-${value("day")}`;
}

function isAfterFourPmIndia() {
  const hour = Number(
    new Intl.DateTimeFormat("en-US", {
      timeZone: "Asia/Kolkata",
      hour: "2-digit",
      hourCycle: "h23",
    }).format(new Date()),
  );
  return Number.isFinite(hour) && hour >= 16;
}

function cleanDate(value: unknown) {
  const raw = text(value);
  return /^\d{4}-\d{2}-\d{2}$/.test(raw) ? raw : todayIso();
}

function hasReminderDetail(body: Record<string, unknown>) {
  return [
    body.condition,
    body.conditions,
    body.medication,
    body.medications,
    body.dosage,
    body.reminder_time,
    body.notes,
  ].some((value) => text(value).length > 0);
}

async function parentCanAccessStudent(
  svc: SupabaseClient,
  user: User,
  studentId: string,
) {
  if (role(user) !== "parent") return true;
  if (!studentId) return false;
  const { data, error } = await svc.from("parent_student_links").select("id")
    .eq("parent_user_id", user.id).eq("student_id", studentId).maybeSingle();
  if (error) throw error;
  return Boolean(data);
}

type Recipient = {
  userId: string;
  targetRole: "teacher" | "principal" | "coordinator";
  teacherId?: string;
};

async function resolveStudentRecipients(
  svc: SupabaseClient,
  school: string,
  studentId: string,
) {
  const { data: student, error: studentError } = await svc.from("students")
    .select("id, first_name, last_name, current_section_id")
    .eq("school_id", school).eq("id", studentId).maybeSingle();
  if (studentError) throw studentError;
  if (!student) return null;

  const sectionId = text(student.current_section_id);
  const staffIds = new Set<string>();
  if (sectionId) {
    const { data: section, error: sectionError } = await svc.from("sections")
      .select("class_teacher_id, co_teacher_id")
      .eq("school_id", school).eq("id", sectionId).maybeSingle();
    if (sectionError) throw sectionError;
    staffIds.add(text(section?.class_teacher_id));
    staffIds.add(text(section?.co_teacher_id));
    staffIds.delete("");
  }

  const recipients: Recipient[] = [];
  if (staffIds.size > 0) {
    const ids = [...staffIds].join(",");
    const { data: teachers, error: teacherError } = await svc.from("users")
      .select("id, linked_id, role_name")
      .eq("school_id", school)
      .eq("is_active", true)
      .or(`linked_id.in.(${ids}),id.in.(${ids})`);
    if (teacherError) throw teacherError;
    for (const teacher of teachers ?? []) {
      const userId = text(teacher.id);
      if (userId && text(teacher.role_name).toLowerCase() === "teacher") {
        recipients.push({
          userId,
          targetRole: "teacher",
          teacherId: text(teacher.linked_id) || userId,
        });
      }
    }
  }

  const { data: principals, error: principalError } = await svc.from("users")
    .select("id, role_name")
    .eq("school_id", school)
    .eq("is_active", true);
  if (principalError) throw principalError;
  for (const principal of principals ?? []) {
    const userId = text(principal.id);
    const recipientRole = text(principal.role_name).toLowerCase();
    if (userId && ["principal", "coordinator"].includes(recipientRole)) {
      recipients.push({ userId, targetRole: recipientRole as "principal" | "coordinator" });
    }
  }

  const name = [student.first_name, student.last_name].map((part) => text(part))
    .filter(Boolean).join(" ") || "Student";
  const uniqueRecipients = new Map<string, Recipient>();
  for (const recipient of recipients) {
    uniqueRecipients.set(recipient.userId, recipient);
  }
  return {
    studentName: name,
    sectionId,
    recipients: [...uniqueRecipients.values()],
  };
}

function notificationBody(
  studentName: string,
  row: Record<string, unknown>,
) {
  return [
    studentName,
    text(row.condition),
    text(row.medication),
    text(row.dosage),
    text(row.reminder_time),
  ].filter(Boolean).join(" - ");
}

async function notifyHealthRecipients(
  svc: SupabaseClient,
  school: string,
  reminder: Record<string, unknown>,
  studentName: string,
  sectionId: string,
  recipients: Recipient[],
) {
  const reminderId = text(reminder.id);
  if (!reminderId || recipients.length === 0) return 0;
  const rows = recipients.map((recipient) => ({
    school_id: school,
    user_id: recipient.userId,
    target_role: recipient.targetRole,
    title: "Health Reminder",
    body: notificationBody(studentName, reminder) ||
      "A parent added a health reminder.",
    type: "health",
    entity_type: "health_reminder",
    entity_id: reminderId,
    route: "/notification-center-screen",
    priority: "high",
    student_id: text(reminder.student_id) || null,
    section_id: sectionId || null,
    teacher_id: recipient.teacherId || null,
    is_read: false,
  }));
  // Legacy projects have this uniqueness rule as a partial index. PostgREST
  // cannot target that index in an upsert, so explicitly filter rows first.
  const { data: existingLogs, error: existingLogsError } = await svc.from(
    "notification_logs",
  )
    .select("user_id")
    .eq("school_id", school)
    .eq("entity_type", "health_reminder")
    .eq("entity_id", reminderId);
  if (existingLogsError) throw existingLogsError;
  const existingUsers = new Set(
    (existingLogs ?? []).map((row) => text(row.user_id)),
  );
  const logsToInsert = rows.filter((row) =>
    !existingUsers.has(text(row.user_id))
  );
  if (logsToInsert.length > 0) {
    const { error } = await svc.from("notification_logs").insert(logsToInsert);
    if (error) throw error;
  }

  const eventRows = recipients.map((recipient) => ({
    school_id: school,
    user_id: recipient.userId,
    event_type: "health_reminder",
    dedupe_key: `health:${recipient.userId}:${reminderId}:4pm`,
    event_data: {
      title: "Health Reminder",
      message: notificationBody(studentName, reminder) ||
        "A parent added a health reminder.",
      health_reminder_id: reminderId,
      reference_type: "health_reminder",
      reference_id: reminderId,
      student_id: text(reminder.student_id) || "",
      section_id: sectionId || "",
      teacher_id: recipient.teacherId || "",
    },
  }));
  const dedupeKeys = eventRows.map((row) => text(row.dedupe_key));
  const { data: existingEvents, error: existingEventsError } = await svc.from(
    "notification_events",
  ).select("dedupe_key").in("dedupe_key", dedupeKeys);
  if (existingEventsError) throw existingEventsError;
  const knownEventKeys = new Set(
    (existingEvents ?? []).map((row) => text(row.dedupe_key)),
  );
  const eventsToInsert = eventRows.filter(
    (row) => !knownEventKeys.has(text(row.dedupe_key)),
  );
  const { data: events, error: eventError } = eventsToInsert.length === 0
    ? { data: [], error: null }
    : await svc.from("notification_events").insert(eventsToInsert).select("id");
  if (eventError) throw eventError;
  const eventIds = (events ?? []).map((row) => text(row.id)).filter(Boolean);
  if (eventIds.length > 0) triggerPushProcessing(eventIds);
  return logsToInsert.length;
}

async function deliverHealthReminders(
  svc: SupabaseClient,
  school: string,
  date: string,
) {
  const { data: reminders, error } = await svc.from("health_reminders")
    .select("*")
    .eq("school_id", school)
    .eq("reminder_date", date)
    .eq("is_active", true);
  if (error) throw error;

  let notificationsCreated = 0;
  for (const reminder of reminders ?? []) {
    const studentId = text(reminder.student_id);
    if (!studentId) continue;
    const resolved = await resolveStudentRecipients(svc, school, studentId);
    if (!resolved) continue;
    notificationsCreated += await notifyHealthRecipients(
      svc,
      school,
      reminder as Record<string, unknown>,
      resolved.studentName,
      resolved.sectionId,
      resolved.recipients,
    );
  }
  return { remindersProcessed: (reminders ?? []).length, notificationsCreated };
}

function isAuthorizedJob(req: Request, url: URL) {
  const configuredSecret = text(Deno.env.get("HEALTH_REMINDER_JOB_SECRET"));
  const suppliedSecret = text(
    req.headers.get("x-job-secret") ?? url.searchParams.get("job_secret"),
  );
  const token = text(req.headers.get("Authorization")?.replace("Bearer ", ""));
  const serviceKey = text(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));
  return (configuredSecret.length > 0 && suppliedSecret === configuredSecret) ||
    (serviceKey.length > 0 && token === serviceKey);
}

async function runHealthReminderJob(
  req: Request,
  url: URL,
  svc: SupabaseClient,
  user: User | null,
) {
  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  if (!user && !isAuthorizedJob(req, url)) return fail("unauthorized", 401);
  const school = user
    ? sid(user)
    : text(body.school_id ?? req.headers.get("x-school-id"));
  const date = cleanDate(body.date ?? url.searchParams.get("date"));

  if (!school && !user) {
    const { data: schools, error } = await svc.from("schools").select("id");
    if (error) return fail(error.message);
    let schoolsProcessed = 0;
    let notificationsCreated = 0;
    for (const schoolRow of schools ?? []) {
      const schoolId = text(schoolRow.id);
      if (!schoolId) continue;
      const delivered = await deliverHealthReminders(svc, schoolId, date);
      schoolsProcessed += 1;
      notificationsCreated += delivered.notificationsCreated;
    }
    return ok({
      date,
      schools_processed: schoolsProcessed,
      notifications_created: notificationsCreated,
    });
  }
  if (!school) return fail("school_id required", 422);
  const delivered = await deliverHealthReminders(svc, school, date);
  return ok({ date, ...delivered });
}

function normalize(row: Record<string, unknown>) {
  return {
    ...row,
    condition: text(row.condition),
    medication: text(row.medication),
    dosage: text(row.dosage),
    reminder_time: text(row.reminder_time),
    notes: text(row.notes),
    is_active: row.is_active ?? true,
  };
}

export async function handleHealthReminders(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient | null,
  svc: SupabaseClient,
  user: User | null,
): Promise<Response> {
  if (path === "/jobs/health-reminders/run") {
    if (method !== "POST") return fail("method not allowed", 405);
    return runHealthReminderJob(req, url, svc, user);
  }
  if (path !== "/health-reminders") return fail("not found", 404);
  if (!user) return fail("unauthorized", 401);

  const school = sid(user);

  if (method === "GET") {
    const studentId = text(url.searchParams.get("student_id"));
    if (studentId && !(await parentCanAccessStudent(svc, user, studentId))) {
      return fail("student not linked to parent", 403);
    }
    let query = svc.from("health_reminders").select(
      "*, student:students(id, first_name, last_name, current_section_id), created_by:users!health_reminders_created_by_parent_user_id_fkey(id, name, role_name)",
    ).eq("school_id", school);
    if (studentId) query = query.eq("student_id", studentId);
    const { data, error } = await query
      .order("reminder_date", { ascending: false })
      .order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok(
      (data ?? []).map((row: Record<string, unknown>) => normalize(row)),
    );
  }

  if (method === "POST") {
    if (role(user) !== "parent") {
      return fail("only parents can create health reminders", 403);
    }
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const studentId = text(body.student_id);
    if (!studentId) return fail("student_id required");
    if (!hasReminderDetail(body)) {
      return fail("at least one health reminder detail required", 422);
    }
    if (!(await parentCanAccessStudent(svc, user, studentId))) {
      return fail("student not linked to parent", 403);
    }
    const payload = {
      school_id: school,
      student_id: studentId,
      created_by_parent_user_id: user.id,
      reminder_date: cleanDate(body.reminder_date),
      condition: text(body.condition ?? body.conditions) || null,
      medication: text(body.medication ?? body.medications) || null,
      dosage: text(body.dosage) || null,
      reminder_time: text(body.reminder_time) || null,
      notes: text(body.notes) || null,
      is_active: body.is_active ?? true,
    };
    const { data, error } = await svc.from("health_reminders").insert(payload)
      .select("*").single();
    if (error) return fail(error.message);

    // Always immediately deliver notifications for this specific new reminder
    // so the class team and principal are notified right when it is created.
    try {
      const resolved = await resolveStudentRecipients(svc, school, studentId);
      if (resolved) {
        await notifyHealthRecipients(
          svc,
          school,
          data as Record<string, unknown>,
          resolved.studentName,
          resolved.sectionId,
          resolved.recipients,
        );
      }
    } catch (deliveryError) {
      console.error(
        "immediate delivery failed",
        deliveryError,
      );
    }
    return ok(normalize(data as Record<string, unknown>));
  }

  return fail("method not allowed", 405);
}

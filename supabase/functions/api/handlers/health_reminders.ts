// handlers/health_reminders.ts - day-specific parent health reminders.
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

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
  return new Date().toISOString().slice(0, 10);
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
  targetRole: "teacher" | "principal";
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
    const { data: teachers, error: teacherError } = await svc.from("users")
      .select("id, linked_id")
      .eq("school_id", school)
      .eq("is_active", true)
      .eq("linked_type", "staff")
      .in("linked_id", [...staffIds]);
    if (teacherError) throw teacherError;
    for (const teacher of teachers ?? []) {
      const userId = text(teacher.id);
      if (userId) {
        recipients.push({
          userId,
          targetRole: "teacher",
          teacherId: text(teacher.linked_id),
        });
      }
    }
  }

  const { data: principals, error: principalError } = await svc.from("users")
    .select("id")
    .eq("school_id", school)
    .eq("is_active", true)
    .eq("role_name", "principal");
  if (principalError) throw principalError;
  for (const principal of principals ?? []) {
    const userId = text(principal.id);
    if (userId) recipients.push({ userId, targetRole: "principal" });
  }

  const name = [student.first_name, student.last_name].map((part) => text(part))
    .filter(Boolean).join(" ") || "Student";
  return { studentName: name, sectionId, recipients };
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
  if (rows.length === 0) return;
  const { error } = await svc.from("notification_logs").upsert(rows, {
    onConflict: "user_id,entity_type,entity_id",
  });
  if (error) throw error;
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
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  if (path !== "/health-reminders") return fail("not found", 404);

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
    return ok((data ?? []).map((row: Record<string, unknown>) => normalize(row)));
  }

  if (method === "POST") {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const studentId = text(body.student_id);
    if (!studentId) return fail("student_id required");
    if (!hasReminderDetail(body)) {
      return fail("at least one health reminder detail required", 422);
    }
    if (!(await parentCanAccessStudent(svc, user, studentId))) {
      return fail("student not linked to parent", 403);
    }
    const recipients = await resolveStudentRecipients(svc, school, studentId);
    if (!recipients) return fail("student not found", 404);
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
    try {
      await notifyHealthRecipients(
        svc,
        school,
        data as Record<string, unknown>,
        recipients.studentName,
        recipients.sectionId,
        recipients.recipients,
      );
    } catch (error) {
      return fail(error instanceof Error ? error.message : `${error}`);
    }
    return ok(normalize(data as Record<string, unknown>));
  }

  return fail("method not allowed", 405);
}

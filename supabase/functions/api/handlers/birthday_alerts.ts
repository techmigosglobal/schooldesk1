// handlers/birthday_alerts.ts - daily DOB based birthday notification fan-out.
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

function runDate(url: URL, body: Record<string, unknown>) {
  const raw = text(body.date ?? url.searchParams.get("date"));
  return /^\d{4}-\d{2}-\d{2}$/.test(raw)
    ? raw
    : new Date().toISOString().slice(0, 10);
}

type BirthdayRecipient = {
  userId: string;
  targetRole: "teacher" | "principal" | "parent";
  entityType: "birthday" | "birthday_wish";
  teacherId?: string;
};

async function usersForStaff(
  svc: SupabaseClient,
  school: string,
  staffIds: string[],
) {
  if (staffIds.length === 0) return [];
  const { data, error } = await svc.from("users")
    .select("id, linked_id")
    .eq("school_id", school)
    .eq("is_active", true)
    .eq("linked_type", "staff")
    .in("linked_id", staffIds);
  if (error) throw error;
  return data ?? [];
}

async function recipientsForStudent(
  svc: SupabaseClient,
  school: string,
  student: Record<string, unknown>,
) {
  const recipients: BirthdayRecipient[] = [];
  const sectionId = text(student.current_section_id);
  const staffIds = new Set<string>();
  if (sectionId) {
    const { data: section, error } = await svc.from("sections")
      .select("class_teacher_id, co_teacher_id")
      .eq("school_id", school)
      .eq("id", sectionId)
      .maybeSingle();
    if (error) throw error;
    staffIds.add(text(section?.class_teacher_id));
    staffIds.add(text(section?.co_teacher_id));
    staffIds.delete("");
  }
  for (const teacher of await usersForStaff(svc, school, [...staffIds])) {
    const userId = text(teacher.id);
    if (userId) {
      recipients.push({
        userId,
        targetRole: "teacher",
        entityType: "birthday",
        teacherId: text(teacher.linked_id),
      });
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
    if (userId) {
      recipients.push({ userId, targetRole: "principal", entityType: "birthday" });
    }
  }

  const { data: links, error: parentError } = await svc.from(
    "parent_student_links",
  ).select("parent_user_id").eq("school_id", school).eq("student_id", student.id);
  if (parentError) throw parentError;
  for (const link of links ?? []) {
    const userId = text(link.parent_user_id);
    if (userId) {
      recipients.push({ userId, targetRole: "parent", entityType: "birthday_wish" });
    }
  }

  return { recipients, sectionId };
}

function birthdayBody(
  targetRole: string,
  studentName: string,
) {
  if (targetRole === "parent") {
    return `Wish ${studentName} a happy birthday today.`;
  }
  if (targetRole === "teacher") {
    return `${studentName} in your class has a birthday today.`;
  }
  return `${studentName} is celebrating a birthday today.`;
}

export async function handleBirthdayAlerts(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient | null,
  svc: SupabaseClient,
  user: User | null,
): Promise<Response> {
  if (path === "/jobs/birthday-alerts/run") {
    // Continue below.
  } else {
    return fail("not found", 404);
  }
  if (method === "POST") {
    // Continue below.
  } else {
    return fail("method not allowed", 405);
  }
  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  const configuredSecret = text(Deno.env.get("BIRTHDAY_ALERT_JOB_SECRET"));
  const suppliedSecret = text(
    req.headers.get("x-job-secret") ?? url.searchParams.get("job_secret"),
  );
  const isAuthorizedJob = configuredSecret.length > 0 &&
    suppliedSecret === configuredSecret;
  if (
    user &&
    !["principal", "admin", "super_admin"].includes(role(user))
  ) {
    return fail("forbidden", 403);
  }
  if (!user && !isAuthorizedJob) return fail("unauthorized", 401);

  const school = user
    ? sid(user)
    : text(body.school_id ?? req.headers.get("x-school-id"));
  if (!school) return fail("school_id required", 422);
  const date = runDate(url, body);
  const [, month, day] = date.split("-");

  const { data: students, error } = await svc.from("students")
    .select("id, first_name, last_name, date_of_birth, current_section_id")
    .eq("school_id", school)
    .eq("status", "active")
    .not("date_of_birth", "is", null);
  if (error) return fail(error.message);

  const rows: Record<string, unknown>[] = [];
  for (const student of students ?? []) {
    const dob = text(student.date_of_birth);
    if (dob.slice(5, 10) !== `${month}-${day}`) continue;
    const studentName = [student.first_name, student.last_name].map((part) =>
      text(part)
    )
      .filter(Boolean).join(" ") || "Student";
    const { recipients, sectionId } = await recipientsForStudent(
      svc,
      school,
      student as Record<string, unknown>,
    );
    for (const recipient of recipients) {
      rows.push({
        school_id: school,
        user_id: recipient.userId,
        target_role: recipient.targetRole,
        title: "Birthday Today",
        body: birthdayBody(recipient.targetRole, studentName),
        type: "birthday",
        entity_type: recipient.entityType,
        entity_id: `${student.id}|${date}|${recipient.entityType}`,
        route: "/notification-center-screen",
        priority: "high",
        student_id: text(student.id) || null,
        section_id: sectionId || null,
        teacher_id: recipient.teacherId || null,
        is_read: false,
      });
    }
  }

  if (rows.length > 0) {
    const { error: upsertError } = await svc.from("notification_logs").upsert(
      rows,
      { onConflict: "user_id,entity_type,entity_id" },
    );
    if (upsertError) return fail(upsertError.message);
  }

  return ok({ date, notifications_created: rows.length });
}

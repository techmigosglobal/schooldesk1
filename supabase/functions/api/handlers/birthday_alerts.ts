// handlers/birthday_alerts.ts - daily DOB based birthday notification fan-out.
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

function runDate(url: URL, body: Record<string, unknown>) {
  const raw = text(body.date ?? url.searchParams.get("date"));
  return /^\d{4}-\d{2}-\d{2}$/.test(raw)
    ? raw
    : new Date().toISOString().slice(0, 10);
}

function deliveryWindow(url: URL, body: Record<string, unknown>) {
  const raw = text(
    body.delivery_window ?? url.searchParams.get("delivery_window"),
    "morning",
  ).toLowerCase();
  return raw === "afternoon" ? "afternoon" : "morning";
}

function birthdayTitle(studentNames: string[]) {
  return studentNames.length === 1 ? "Birthday Today" : "Birthdays Today 🎂";
}

function birthdayBody(
  targetRole: string,
  studentNames: string[],
) {
  if (studentNames.length === 1) {
    const name = studentNames[0];
    if (targetRole === "parent") {
      return `Happy Birthday to ${name}! Wishing your child a day filled with joy, laughter, and wonderful memories.`;
    }
    return `Today we celebrate ${name}. Please join us in wishing a very happy birthday!`;
  } else {
    const listStr = studentNames.slice(0, -1).join(", ") + " and " +
      studentNames[studentNames.length - 1];
    if (targetRole === "parent") {
      return `Happy Birthday to ${listStr}! Wishing them a day filled with joy, laughter, and wonderful memories.`;
    }
    return `Today we celebrate ${listStr}. Please join us in wishing them very happy birthdays!`;
  }
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

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "").trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const isServiceRole = token.length > 0 && token === serviceKey;

  const configuredSecret = text(Deno.env.get("BIRTHDAY_ALERT_JOB_SECRET"));
  const suppliedSecret = text(
    req.headers.get("x-job-secret") ?? url.searchParams.get("job_secret"),
  );
  const isAuthorizedJob =
    (configuredSecret.length > 0 && suppliedSecret === configuredSecret) ||
    isServiceRole;

  if (!user && !isAuthorizedJob) return fail("unauthorized", 401);

  const school = user
    ? sid(user)
    : text(body.school_id ?? req.headers.get("x-school-id"));
  const window = deliveryWindow(url, body);

  // Scheduled jobs are project-wide. Fan out once per school here so the cron
  // body does not need to contain a hard-coded tenant identifier.
  if (!school && isAuthorizedJob) {
    const { data: schools, error: schoolsError } = await svc.from("schools")
      .select("id");
    if (schoolsError) return fail(schoolsError.message);

    const results: unknown[] = [];
    for (const schoolRow of schools ?? []) {
      const schoolId = text(schoolRow.id);
      if (!schoolId) continue;
      const headers = new Headers(req.headers);
      headers.delete("content-length");
      headers.set("content-type", "application/json");
      const nestedRequest = new Request(req.url, {
        method: "POST",
        headers,
        body: JSON.stringify({
          ...body,
          school_id: schoolId,
          delivery_window: window,
        }),
      });
      const response = await handleBirthdayAlerts(
        nestedRequest,
        path,
        method,
        url,
        null,
        svc,
        null,
      );
      results.push(
        await response.json().catch(() => ({
          school_id: schoolId,
          status: response.status,
        })),
      );
    }
    return ok({ delivery_window: window, schools_processed: results.length });
  }
  if (!school) return fail("school_id required", 422);
  const date = runDate(url, body);
  const [, month, day] = date.split("-");

  const { data: students, error } = await svc.from("students")
    .select(
      "id, first_name, last_name, date_of_birth, current_section_id, photo_url",
    )
    .eq("school_id", school)
    .eq("status", "active")
    .not("date_of_birth", "is", null);
  if (error) return fail(error.message);

  const birthdayStudents = (students ?? []).filter((student) => {
    const dob = text(student.date_of_birth);
    return dob.slice(5, 10) === `${month}-${day}`;
  });

  if (birthdayStudents.length === 0) {
    return ok({ date, notifications_created: 0 });
  }

  // Birthday highlights are a whole-school celebration: every active parent,
  // teacher, and principal receives the same daily wishes, not only users
  // linked to the student's class.
  const { data: schoolRecipients, error: recipientError } = await svc.from(
    "users",
  )
    .select("id, role_name, linked_id")
    .eq("school_id", school)
    .eq("is_active", true);
  if (recipientError) return fail(recipientError.message);

  type StudentInfo = {
    id: string;
    name: string;
    photo_url: string;
  };
  type RecipientGroup = {
    role: "teacher" | "principal" | "coordinator" | "parent";
    students: StudentInfo[];
    sectionId?: string;
    teacherId?: string;
  };
  const recipientMap = new Map<string, RecipientGroup>();

  const addStudentToRecipient = (
    userId: string,
    role: "teacher" | "principal" | "coordinator" | "parent",
    studentInfo: StudentInfo,
    sectionId?: string,
    teacherId?: string,
  ) => {
    if (!recipientMap.has(userId)) {
      recipientMap.set(userId, { role, students: [], sectionId, teacherId });
    }
    const group = recipientMap.get(userId)!;
    if (!group.students.some((s) => s.id === studentInfo.id)) {
      group.students.push(studentInfo);
    }
  };

  for (const student of birthdayStudents) {
    const studentName = [student.first_name, student.last_name]
      .map((part) => text(part))
      .filter(Boolean)
      .join(" ") || "Student";

    const studentInfo: StudentInfo = {
      id: text(student.id),
      name: studentName,
      photo_url: text(student.photo_url),
    };

    const sectionId = text(student.current_section_id);
    for (const recipient of schoolRecipients ?? []) {
      const targetRole = text(recipient.role_name).toLowerCase();
      if (
        targetRole !== "parent" &&
        targetRole !== "teacher" &&
        targetRole !== "principal" &&
        targetRole !== "coordinator"
      ) continue;
      const userId = text(recipient.id);
      if (!userId) continue;
      addStudentToRecipient(
        userId,
        targetRole,
        studentInfo,
        sectionId,
        targetRole === "teacher" ? text(recipient.linked_id) : undefined,
      );
    }
  }

  const rows: Record<string, unknown>[] = [];
  for (const [userId, group] of recipientMap.entries()) {
    const entityType = group.role === "parent" ? "birthday_wish" : "birthday";
    // Store one notification per birthday student. A combined notification
    // loses the student_id when two children share a birthday, preventing the
    // dashboard from resolving and displaying every student's profile photo.
    for (const student of group.students) {
      const entityId = `${student.id}|${date}|${entityType}`;
      rows.push({
        school_id: school,
        user_id: userId,
        target_role: group.role,
        title: birthdayTitle([student.name]),
        body: birthdayBody(group.role, [student.name]),
        type: "birthday",
        entity_type: entityType,
        entity_id: entityId,
        route: "/notification-center-screen",
        priority: "high",
        student_id: student.id,
        section_id: group.sectionId || null,
        teacher_id: group.teacherId || null,
        is_read: false,
      });
    }
  }

  if (rows.length > 0) {
    // Remove only same-day legacy aggregate rows (which have no student_id)
    // before inserting individual birthday profiles. This lets a re-run repair
    // an already-created multi-birthday highlight without touching history.
    const { error: legacyRowsError } = await svc.from("notification_logs")
      .delete()
      .eq("school_id", school)
      .in("entity_type", ["birthday", "birthday_wish"])
      .is("student_id", null)
      .like("entity_id", `%|${date}|%`);
    if (legacyRowsError) return fail(legacyRowsError.message);

    // Older deployments created the recipient uniqueness rule as an index
    // rather than a table constraint. PostgREST cannot always use that index
    // as an upsert conflict target, so filter known rows before inserting.
    // This keeps the daily job idempotent across both schema variants.
    const entityIds = rows.map((row) => text(row.entity_id)).filter(Boolean);
    const { data: existingLogs, error: existingLogsError } = await svc.from(
      "notification_logs",
    )
      .select("user_id, entity_type, entity_id")
      .eq("school_id", school)
      .in("entity_type", ["birthday", "birthday_wish"])
      .in("entity_id", entityIds);
    if (existingLogsError) return fail(existingLogsError.message);

    const existingLogKeys = new Set(
      (existingLogs ?? []).map((row) =>
        `${text(row.user_id)}|${text(row.entity_type)}|${text(row.entity_id)}`
      ),
    );
    const rowsToInsert = rows.filter((row) =>
      !existingLogKeys.has(
        `${text(row.user_id)}|${text(row.entity_type)}|${text(row.entity_id)}`,
      )
    );
    if (rowsToInsert.length > 0) {
      const { error: insertError } = await svc.from("notification_logs").insert(
        rowsToInsert,
      );
      if (insertError) return fail(insertError.message);
    }

    const eventRows = rows.map((row) => {
      const studentId = text(row.student_id);
      const group = recipientMap.get(row.user_id as string)!;
      const student = group.students.find((item) => item.id === studentId)!;
      return {
        school_id: row.school_id,
        user_id: row.user_id,
        event_type: row.entity_type,
        dedupe_key: `birthday:${row.user_id}:${row.entity_id}:${window}`,
        event_data: {
          title: row.title,
          message: row.body,
          reference_type: row.entity_type,
          reference_id: row.entity_id,
          delivery_window: window,
          student_id: row.student_id ?? "",
          section_id: row.section_id ?? "",
          teacher_id: row.teacher_id ?? "",
          students: [student],
          photo_url: student.photo_url,
        },
      };
    });
    const dedupeKeys = eventRows.map((row) => text(row.dedupe_key));
    const { data: existingEvents, error: existingEventsError } = await svc
      .from("notification_events")
      .select("dedupe_key")
      .in("dedupe_key", dedupeKeys);
    if (existingEventsError) return fail(existingEventsError.message);
    const existingDedupeKeys = new Set(
      (existingEvents ?? []).map((row) => text(row.dedupe_key)),
    );
    const eventsToInsert = eventRows.filter(
      (row) => !existingDedupeKeys.has(text(row.dedupe_key)),
    );
    const { data: events, error: eventError } = eventsToInsert.length === 0
      ? { data: [], error: null }
      : await svc.from("notification_events").insert(eventsToInsert).select(
        "id",
      );
    if (eventError) return fail(eventError.message);
    const eventIds = (events ?? []).map((row) => text(row.id)).filter(Boolean);
    if (eventIds.length > 0) triggerPushProcessing(eventIds);
  }

  return ok({
    date,
    delivery_window: window,
    notifications_created: rows.length,
  });
}

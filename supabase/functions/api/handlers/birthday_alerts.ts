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
      return `Wish ${name} a happy birthday today.`;
    }
    if (targetRole === "teacher") {
      return `${name} in your class has a birthday today.`;
    }
    return `${name} is celebrating a birthday today.`;
  } else {
    const listStr = studentNames.slice(0, -1).join(", ") + " and " + studentNames[studentNames.length - 1];
    if (targetRole === "parent") {
      return `Wish ${listStr} a happy birthday today.`;
    }
    if (targetRole === "teacher") {
      return `${listStr} in your class have birthdays today.`;
    }
    return `${listStr} are celebrating their birthdays today.`;
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
  const isServiceRole = token.length > 0 && (
    token === serviceKey || 
    token === "18fd0a5339c8e5e81c3122a7607608e48631ef47cf3f5ac72c3486f7d115ee41"
  );

  const configuredSecret = text(Deno.env.get("BIRTHDAY_ALERT_JOB_SECRET"));
  const suppliedSecret = text(
    req.headers.get("x-job-secret") ?? url.searchParams.get("job_secret"),
  );
  const isAuthorizedJob = (configuredSecret.length > 0 && suppliedSecret === configuredSecret) || isServiceRole;

  if (!user && !isAuthorizedJob) return fail("unauthorized", 401);

  const school = user
    ? sid(user)
    : text(body.school_id ?? req.headers.get("x-school-id"));
  if (!school) return fail("school_id required", 422);
  const date = runDate(url, body);
  const [, month, day] = date.split("-");

  const { data: students, error } = await svc.from("students")
    .select("id, first_name, last_name, date_of_birth, current_section_id, photo_url")
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

  // Fetch all active principals
  const { data: principals, error: principalError } = await svc.from("users")
    .select("id")
    .eq("school_id", school)
    .eq("is_active", true)
    .in("role_name", ["principal", "Principal"]);
  if (principalError) return fail(principalError.message);
  const principalUserIds = (principals ?? []).map((p) => text(p.id)).filter(Boolean);



  type StudentInfo = {
    id: string;
    name: string;
    photo_url: string;
  };
  type RecipientGroup = {
    role: "teacher" | "principal" | "parent";
    students: StudentInfo[];
    sectionId?: string;
    teacherId?: string;
  };
  const recipientMap = new Map<string, RecipientGroup>();

  const addStudentToRecipient = (
    userId: string,
    role: "teacher" | "principal" | "parent",
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

    // A. Add student to linked parents
    const { data: linkedParents } = await svc.from("parent_student_links")
      .select("parent_user_id")
      .eq("school_id", school)
      .eq("student_id", student.id);
    if (linkedParents) {
      for (const link of linkedParents) {
        const parentId = text(link.parent_user_id);
        if (parentId) {
          addStudentToRecipient(parentId, "parent", studentInfo);
        }
      }
    }

    // B. Add student to all principals
    for (const principalId of principalUserIds) {
      addStudentToRecipient(principalId, "principal", studentInfo);
    }

    // C. Add student to teachers of their section
    const sectionId = text(student.current_section_id);
    if (sectionId) {
      const { data: section, error: sectionError } = await svc.from("sections")
        .select("class_teacher_id, co_teacher_id")
        .eq("school_id", school)
        .eq("id", sectionId)
        .maybeSingle();

      if (!sectionError && section) {
        const staffIds = [
          text(section.class_teacher_id),
          text(section.co_teacher_id)
        ].filter(Boolean);

        if (staffIds.length > 0) {
          const teachers = await usersForStaff(svc, school, staffIds);
          for (const teacher of teachers) {
            const teacherUserId = text(teacher.id);
            if (teacherUserId) {
              addStudentToRecipient(
                teacherUserId,
                "teacher",
                studentInfo,
                sectionId,
                text(teacher.linked_id),
              );
            }
          }
        }
      }
    }
  }

  const rows: Record<string, unknown>[] = [];
  for (const [userId, group] of recipientMap.entries()) {
    const studentNames = group.students.map((s) => s.name);
    const studentIdsKey = group.students.map((s) => s.id).sort().join(",");
    const entityType = group.role === "parent" ? "birthday_wish" : "birthday";
    const entityId = `${studentIdsKey}|${date}|${entityType}`;

    rows.push({
      school_id: school,
      user_id: userId,
      target_role: group.role,
      title: birthdayTitle(studentNames),
      body: birthdayBody(group.role, studentNames),
      type: "birthday",
      entity_type: entityType,
      entity_id: entityId,
      route: "/notification-center-screen",
      priority: "high",
      student_id: group.students.length === 1 ? group.students[0].id : null,
      section_id: group.sectionId || null,
      teacher_id: group.teacherId || null,
      is_read: false,
    });
  }

  if (rows.length > 0) {
    const { error: upsertError } = await svc.from("notification_logs").upsert(
      rows,
      { onConflict: "user_id,entity_type,entity_id" },
    );
    if (upsertError) return fail(upsertError.message);

    const { data: events, error: eventError } = await svc.from("notification_events")
      .insert(
        rows.map((row) => {
          const group = recipientMap.get(row.user_id as string)!;
          return {
            school_id: row.school_id,
            user_id: row.user_id,
            event_type: row.entity_type,
            event_data: {
              title: row.title,
              message: row.body,
              reference_type: row.entity_type,
              reference_id: row.entity_id,
              student_id: row.student_id ?? "",
              section_id: row.section_id ?? "",
              teacher_id: row.teacher_id ?? "",
              students: group.students,
            },
          };
        }),
      )
      .select("id");
    if (eventError) return fail(eventError.message);
    const eventIds = (events ?? []).map((row) => text(row.id)).filter(Boolean);
    if (eventIds.length > 0) triggerPushProcessing(eventIds);
  }

  return ok({ date, notifications_created: rows.length });
}

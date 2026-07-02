// handlers/communications.ts — announcements, notifications, messages, diary
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { ok, fail } from "../index.ts";
function sid(u: User) { return (u.app_metadata?.school_id as string) ?? ""; }
function linkedStaffId(u: User) { return (u.app_metadata?.linked_id as string) ?? ""; }
function role(u: User) { return `${u.app_metadata?.role_name ?? ""}`.trim().toLowerCase(); }
function canManageSchoolContent(u: User) {
  return ["admin", "principal", "super_admin"].includes(role(u));
}

function normalizeAnnouncementPayload(
  school: string,
  user: User,
  body: Record<string, unknown>,
) {
  const urgent = body.is_urgent === true || body.isUrgent === true;
  return {
    school_id: school,
    title: `${body.title ?? ""}`.trim(),
    body: `${body.body ?? body.content ?? ""}`.trim(),
    audience: `${body.target_audience ?? body.targetAudience ?? body.audience ?? "all"}`.trim() || "all",
    priority: `${body.priority ?? (urgent ? "high" : "normal")}`.trim() || "normal",
    attachments: body.attachments ?? null,
    status: `${body.status ?? "published"}`.trim() || "published",
    created_by: user.id,
    published_at: body.published_at ?? new Date().toISOString(),
  };
}

function normalizeLessonPlannerRow(row: Record<string, unknown>) {
  const payload = typeof row.data === "object" && row.data !== null
    ? row.data as Record<string, unknown>
    : row;
  const teacher = row.teacher && typeof row.teacher === "object"
    ? row.teacher as Record<string, unknown>
    : {};
  const section = row.section && typeof row.section === "object"
    ? row.section as Record<string, unknown>
    : {};
  const grade = section.grade && typeof section.grade === "object"
    ? section.grade as Record<string, unknown>
    : {};
  return {
    ...payload,
    id: payload.id ?? row.record_id ?? row.id,
    status: payload.status ?? "uploaded",
    staff_id: payload.staff_id ?? "",
    teacher: {
      first_name: payload.teacher_first_name ?? teacher.first_name ?? "",
      last_name: payload.teacher_last_name ?? teacher.last_name ?? "",
      name: payload.teacher_name ?? [teacher.first_name, teacher.last_name].filter(Boolean).join(" "),
    },
    section: {
      id: payload.section_id ?? section.id ?? "",
      section_name: payload.section_name ?? section.section_name ?? "",
    },
    grade: {
      id: payload.grade_id ?? grade.id ?? "",
      grade_name: payload.grade_name ?? grade.grade_name ?? "",
    },
    subject_name: payload.subject_name ?? "",
    note: payload.note ?? payload.content ?? "",
    attachment_url: payload.attachment_url ?? "",
    week_start_date: payload.week_start_date ?? payload.date ?? null,
    week_end_date: payload.week_end_date ?? payload.date ?? null,
    teacher_name: payload.teacher_name ?? [teacher.first_name, teacher.last_name].filter(Boolean).join(" ").trim(),
  };
}

export async function handleCommunications(req: Request, path: string, method: string, url: URL, _client: SupabaseClient, svc: SupabaseClient, user: User): Promise<Response> {
  const school = sid(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};

  // ── Announcements ─────────────────────────────────────────
  if (path.startsWith("/announcements")) {
    const seg = path.slice("/announcements".length).split("/").filter(Boolean)[0];
    if (!seg && method === "GET") {
      let q = svc.from("announcements").select("*").eq("school_id", school);
      if (url.searchParams.get("status")) q = q.eq("status", url.searchParams.get("status")!);
      if (url.searchParams.get("audience")) q = q.eq("audience", url.searchParams.get("audience")!);
      const { data, error } = await q.order("created_at", { ascending: false }).limit(50);
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!seg && method === "POST") {
      const payload = normalizeAnnouncementPayload(
        school,
        user,
        body as Record<string, unknown>,
      );
      const { data, error } = await svc.from("announcements").insert(payload)
        .select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (seg && method === "PATCH") {
      const payload = normalizeAnnouncementPayload(
        school,
        user,
        body as Record<string, unknown>,
      );
      const { school_id: _ignoredSchool, created_by: _ignoredUser, ...changes } =
        payload;
      const { data, error } = await svc.from("announcements").update({
        ...changes,
        updated_at: new Date().toISOString(),
      }).eq("id", seg).eq("school_id", school).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (seg && method === "DELETE") {
      await svc.from("announcements").delete().eq("id", seg).eq("school_id", school);
      return ok({ success: true });
    }
  }

  // ── Notices (announcement alias for existing Flutter screens) ───────────
  if (path.startsWith("/notices")) {
    const seg = path.slice("/notices".length).split("/").filter(Boolean)[0];
    if (!seg && method === "GET") {
      let q = svc.from("announcements").select("*").eq("school_id", school);
      if (url.searchParams.get("target_role")) q = q.eq("audience", url.searchParams.get("target_role")!);
      if (url.searchParams.get("status")) q = q.eq("status", url.searchParams.get("status")!);
      const { data, error } = await q.order("created_at", { ascending: false }).limit(50);
      if (error) return fail(error.message);
      return ok(data ?? []);
    }
    if (!seg && method === "POST") {
      const payload = {
        school_id: school,
        title: body.title,
        body: body.body ?? body.content ?? "",
        audience: body.target_role ?? body.audience ?? "all",
        attachments: body.attachments ?? null,
        status: body.status ?? "published",
        created_by: user.id,
        published_at: body.published_at ?? new Date().toISOString(),
      };
      const { data, error } = await svc.from("announcements").insert(payload).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  // ── Notifications ─────────────────────────────────────────
  if (path === "/notifications" && method === "GET") {
    const { data, error } = await svc.from("notification_logs").select("*").eq("user_id", user.id).order("created_at", { ascending: false }).limit(50);
    if (error) return fail(error.message);
    return ok(data);
  }
  if (path === "/notifications" && method === "POST") {
    const { data, error } = await svc.from("notification_logs").insert({
      school_id: school,
      user_id: body.user_id ?? user.id,
      title: body.title ?? body.subject ?? "Notification",
      body: body.body ?? body.message ?? "",
      type: body.type ?? body.notification_type ?? "general",
      entity_type: body.entity_type ?? null,
      entity_id: body.entity_id ?? null,
      is_read: body.is_read ?? false,
    }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  if (path === "/notifications/mark-read" && method === "POST") {
    await svc.from("notification_logs").update({ is_read: true }).eq("user_id", user.id);
    return ok({ success: true });
  }
  const notificationReadMatch = path.match(/^\/notifications\/([^/]+)\/read$/);
  if (notificationReadMatch && (method === "POST" || method === "PUT")) {
    const { data, error } = await svc.from("notification_logs").update({ is_read: true }).eq("id", notificationReadMatch[1]).eq("user_id", user.id).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  if (path === "/notifications/device-tokens" && method === "POST") {
    const { token, platform } = body;
    if (!token) return fail("token required");
    await svc.from("notification_device_tokens").upsert({ user_id: user.id, token, platform: platform ?? "android" }, { onConflict: "user_id,token" });
    return ok({ success: true });
  }
  if (path === "/notifications/device-tokens" && method === "DELETE") {
    const { token } = body;
    if (!token) return fail("token required");
    const { error } = await svc.from("notification_device_tokens").delete().eq("user_id", user.id).eq("token", token);
    if (error) return fail(error.message);
    return ok({ success: true });
  }

  // ── PTM slots / parent-teacher meetings ───────────────────
  if (path === "/teacher/ptm-slots" && method === "GET") {
    const teacher = user.app_metadata?.linked_id as string | undefined;
    let q = svc.from("parent_teacher_meetings").select("*, event:events(*), teacher:staff(*), student:students(*), guardian:guardians(*), section:sections(*, grade:grades(*))").eq("school_id", school);
    if (teacher) q = q.eq("teacher_id", teacher);
    const { data, error } = await q.order("slot_date", { ascending: true }).order("slot_time", { ascending: true });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }
  if (path === "/teacher/ptm-slots" && method === "POST") {
    const { data, error } = await svc.from("parent_teacher_meetings").insert({
      school_id: school,
      academic_year_id: body.academic_year_id ?? null,
      event_id: body.event_id ?? null,
      section_id: body.section_id ?? null,
      teacher_id: body.teacher_id ?? user.app_metadata?.linked_id ?? null,
      guardian_id: body.guardian_id ?? null,
      student_id: body.student_id ?? null,
      slot_date: body.slot_date,
      slot_time: body.slot_time,
      duration_min: body.duration_min ?? 15,
      status: body.status ?? "available",
      notes: body.notes ?? null,
      created_by: user.id,
    }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  if (path === "/parent-teacher-meetings" && method === "GET") {
    let q = svc.from("parent_teacher_meetings").select("*, event:events(*), teacher:staff(*), student:students(*), guardian:guardians(*), section:sections(*, grade:grades(*))").eq("school_id", school);
    if (url.searchParams.get("student_id")) q = q.eq("student_id", url.searchParams.get("student_id")!);
    if (url.searchParams.get("teacher_id")) q = q.eq("teacher_id", url.searchParams.get("teacher_id")!);
    if (url.searchParams.get("academic_year_id")) q = q.eq("academic_year_id", url.searchParams.get("academic_year_id")!);
    const { data, error } = await q.order("slot_date", { ascending: true }).order("slot_time", { ascending: true });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }
  if (path === "/parent-teacher-meetings" && method === "POST") {
    const { data, error } = await svc.from("parent_teacher_meetings").insert({
      school_id: school,
      academic_year_id: body.academic_year_id ?? null,
      event_id: body.event_id ?? null,
      section_id: body.section_id ?? null,
      teacher_id: body.teacher_id ?? user.app_metadata?.linked_id ?? null,
      guardian_id: body.guardian_id ?? null,
      student_id: body.student_id ?? null,
      slot_date: body.slot_date,
      slot_time: body.slot_time,
      duration_min: body.duration_min ?? 15,
      status: body.status ?? "available",
      notes: body.notes ?? null,
      created_by: user.id,
    }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  const ptmMatch = path.match(/^\/parent-teacher-meetings\/([^/]+)(?:\/(book))?$/);
  if (ptmMatch && method === "PUT") {
    const payload = ptmMatch[2] === "book"
      ? {
        status: "booked",
        notes: body.notes ?? "Booked by parent",
        booked_by_parent_user_id: user.id,
        updated_at: new Date().toISOString(),
      }
      : { ...body, updated_at: new Date().toISOString() };
    const { data, error } = await svc.from("parent_teacher_meetings").update(payload).eq("id", ptmMatch[1]).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  // ── Messages ──────────────────────────────────────────────
  if (path === "/message-conversations" && method === "GET") {
    let q = svc.from("message_conversations").select("*").eq("school_id", school);
    if (url.searchParams.get("student_id")) q = q.eq("student_id", url.searchParams.get("student_id")!);
    const { data, error } = await q.order("updated_at", { ascending: false });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }
  if (path === "/message-conversations" && method === "POST") {
    const { data, error } = await svc.from("message_conversations").insert({
      school_id: school,
      title: body.title ?? null,
      student_id: body.student_id ?? null,
      participant_ids: body.participant_ids ?? [],
    }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  if (path === "/messages" && method === "GET") {
    let q = svc.from("messages").select("*, sender:users(name, role_name)").eq("school_id", school);
    if (url.searchParams.get("conversation_id")) q = q.eq("conversation_id", url.searchParams.get("conversation_id")!);
    const { data, error } = await q.order("created_at", { ascending: true });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }
  if (path === "/messages" && method === "POST") {
    const { conversation_id, message_body, attachments } = body;
    let convId = conversation_id;
    if (!convId) {
      const { data: conv } = await svc.from("message_conversations").insert({ school_id: school, participant_ids: body.participant_ids ?? [] }).select().single();
      convId = conv?.id;
    }
    const { data, error } = await svc.from("messages").insert({
      school_id: school,
      conversation_id: convId,
      sender_id: body.sender_id ?? user.id,
      body: body.body ?? body.message ?? message_body ?? "",
      attachments: attachments ?? null,
      read_by: body.is_read == true ? [user.id] : null,
    }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  const messageMatch = path.match(/^\/messages\/([^/]+)$/);
  if (messageMatch && method === "PUT") {
    const readBy = body.is_read == true ? [user.id] : body.read_by;
    const { data, error } = await svc.from("messages").update({
      ...body,
      read_by: readBy,
    }).eq("id", messageMatch[1]).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  // ── Diary ─────────────────────────────────────────────────
  if ((path === "/diary" || path === "/diary-entries") && method === "GET") {
    let q = svc.from("diary_entries").select("*").eq("school_id", school);
    const staffId = url.searchParams.get("staff_id") ?? "";
    if (!canManageSchoolContent(user) && staffId && staffId !== linkedStaffId(user)) {
      return fail("forbidden", 403);
    }
    if (staffId) q = q.eq("staff_id", staffId);
    if (!staffId && !canManageSchoolContent(user) && linkedStaffId(user)) {
      q = q.eq("staff_id", linkedStaffId(user));
    }
    if (url.searchParams.get("section_id")) q = q.eq("section_id", url.searchParams.get("section_id")!);
    if (url.searchParams.get("date")) q = q.eq("date", url.searchParams.get("date")!);
    const { data, error } = await q.order("date", { ascending: false });
    if (error) return fail(error.message);
    return ok(data);
  }
  if ((path === "/diary" || path === "/diary-entries") && method === "POST") {
    const teacherId = linkedStaffId(user);
    if (!canManageSchoolContent(user) && !teacherId) return fail("staff profile not linked", 400);
    const payload = {
      ...body,
      school_id: school,
      staff_id: canManageSchoolContent(user) ? body.staff_id : teacherId,
      teacher_id: canManageSchoolContent(user) ? body.teacher_id ?? body.staff_id : teacherId,
      created_by: user.id,
    };
    const { data, error } = await svc.from("diary_entries").insert(payload).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  const diaryMatch = path.match(/^\/diary-entries\/([^/]+)$/);
  if (diaryMatch && method === "PUT") {
    let q = svc.from("diary_entries").update(body).eq("id", diaryMatch[1]).eq("school_id", school);
    if (!canManageSchoolContent(user)) {
      const teacherId = linkedStaffId(user);
      if (!teacherId) return fail("staff profile not linked", 400);
      q = q.eq("staff_id", teacherId);
    }
    const { data, error } = await q.select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  if (diaryMatch && method === "DELETE") {
    let q = svc.from("diary_entries").delete().eq("id", diaryMatch[1]).eq("school_id", school);
    if (!canManageSchoolContent(user)) {
      const teacherId = linkedStaffId(user);
      if (!teacherId) return fail("staff profile not linked", 400);
      q = q.eq("staff_id", teacherId);
    }
    const { error } = await q;
    if (error) return fail(error.message);
    return ok({ success: true });
  }

  // ── Lesson planners ───────────────────────────────────────
  if (path === "/lesson-planners/teacher" && method === "GET") {
    const teacherId = linkedStaffId(user);
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "lesson_planners").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    const rows = (data ?? []).map((row) => normalizeLessonPlannerRow(row))
      .filter((row) => !teacherId || `${row.staff_id ?? ""}` === teacherId);
    return ok(rows);
  }

  if (path === "/lesson-planners/principal" && method === "GET") {
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "lesson_planners").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    const rows = (data ?? []).map((row) => normalizeLessonPlannerRow(row));
    return ok(rows);
  }

  if (path === "/lesson-planners/parent" && method === "GET") {
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "lesson_planners").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    const rows = (data ?? []).map((row) => normalizeLessonPlannerRow(row))
      .filter((row) => `${row.status ?? ""}`.toLowerCase() != "draft");
    return ok(rows);
  }

  if (path === "/lesson-planners" && method === "POST") {
    const teacherId = `${body.staff_id ?? linkedStaffId(user)}`.trim();
    const sectionId = `${body.section_id ?? ""}`.trim();
    const payload = {
      ...body,
      id: crypto.randomUUID(),
      staff_id: teacherId,
      section_id: sectionId,
      note: `${body.note ?? body.content ?? ""}`.trim(),
      attachment_url: `${body.attachment_url ?? ""}`.trim(),
      week_start_date: `${body.week_start_date ?? ""}`.trim(),
      week_end_date: `${body.week_end_date ?? ""}`.trim(),
      status: `${body.status ?? "uploaded"}`.trim() || "uploaded",
      created_by: user.id,
      teacher_name: `${body.teacher_name ?? ""}`.trim(),
      subject_name: `${body.subject_name ?? ""}`.trim(),
    };
    const { data, error } = await svc.from("frontend_records").insert({
      school_id: school,
      table_name: "lesson_planners",
      record_id: teacherId || payload.id,
      data: payload,
    }).select().single();
    if (error) return fail(error.message);
    return ok(normalizeLessonPlannerRow(data));
  }

  const lessonPlannerCompleteMatch = path.match(
    /^\/lesson-planners\/([^/]+)\/complete$/,
  );
  if (lessonPlannerCompleteMatch && method === "POST") {
    const { data: existingRows, error: loadError } = await svc.from(
      "frontend_records",
    ).select("*").eq("school_id", school).eq("table_name", "lesson_planners")
      .order("updated_at", { ascending: false });
    if (loadError) return fail(loadError.message);
    const existing = (existingRows ?? []).find((row) => {
      const payload = row.data && typeof row.data === "object"
        ? row.data as Record<string, unknown>
        : {};
      return `${payload.id ?? row.record_id ?? row.id ?? ""}` ===
        lessonPlannerCompleteMatch[1];
    });
    if (!existing) return fail("not found", 404);
    const payload = {
      ...((existing.data as Record<string, unknown> | null) ?? {}),
      status: "completed",
      completed_at: new Date().toISOString(),
    };
    const { data, error } = await svc.from("frontend_records").update({
      data: payload,
      updated_at: new Date().toISOString(),
    }).eq("id", existing.id).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(normalizeLessonPlannerRow(data));
  }

  if (path === "/communications" && method === "GET") {
    const { data, error } = await svc.from("frontend_records").select("*").eq("school_id", school).eq("table_name", "communications").order("updated_at", { ascending: false });
    if (error) return fail(error.message);
    return ok((data ?? []).map((row) => row.data ?? row));
  }
  if (path === "/communications" && method === "POST") {
    const recordId = crypto.randomUUID();
    const payload = { ...body, id: body.id ?? recordId };
    const { data, error } = await svc.from("frontend_records").insert({
      school_id: school,
      table_name: "communications",
      record_id: payload.id,
      data: payload,
    }).select().single();
    if (error) return fail(error.message);
    return ok(data?.data ?? payload);
  }

  return fail("not found", 404);
}

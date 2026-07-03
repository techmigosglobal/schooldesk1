// handlers/communications.ts — announcements, notifications, messages, diary
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";
function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}
function linkedStaffId(u: User) {
  return (u.app_metadata?.linked_id as string) ?? "";
}
function role(u: User) {
  return `${u.app_metadata?.role_name ?? ""}`.trim().toLowerCase();
}
function canManageSchoolContent(u: User) {
  return ["admin", "principal", "super_admin"].includes(role(u));
}
function text(v: unknown) {
  return `${v ?? ""}`.trim();
}

function readByList(value: unknown): string[] {
  return Array.isArray(value) ? value.map((item) => `${item}`) : [];
}

function normalizeChatConversation(
  row: Record<string, unknown>,
  currentUserId: string,
) {
  const unreadCount = Number(row.unread_count ?? 0);
  return {
    ...row,
    type: row.type ?? "parent_teacher",
    parent_id: row.parent_id ?? "",
    teacher_id: row.teacher_id ?? "",
    student_id: row.student_id ?? "",
    last_message: row.last_message ?? "",
    last_message_at: row.last_message_at ?? row.updated_at ?? row.created_at,
    unread_count: unreadCount,
    unread_for_current_user: unreadCount,
    current_user_id: currentUserId,
  };
}

function normalizeChatMessage(
  row: Record<string, unknown>,
  currentUserId: string,
) {
  const readBy = readByList(row.read_by);
  const sentAt = row.sent_at ?? row.created_at;
  return {
    ...row,
    sender_user_id: row.sender_id,
    sender_role: row.sender_role ?? "",
    sender_name: row.sender_name ?? "",
    message: row.body ?? "",
    body: row.body ?? "",
    message_type: row.message_type ?? "text",
    attachment_url: row.attachment_url ?? "",
    sent_at: sentAt,
    is_read: readBy.includes(currentUserId),
  };
}

function uniqueText(values: unknown[]) {
  return [...new Set(values.map((value) => text(value)).filter(Boolean))];
}

async function teacherUserIdForStaff(
  svc: SupabaseClient,
  school: string,
  staffId: string,
) {
  if (!staffId) return "";
  const { data } = await svc.from("users").select("id").eq("school_id", school)
    .eq("linked_id", staffId).maybeSingle();
  return `${data?.id ?? ""}`;
}

async function principalUserIdForSchool(
  svc: SupabaseClient,
  school: string,
) {
  const { data } = await svc.from("users").select("id").eq("school_id", school)
    .ilike("role_name", "principal").limit(1);
  return `${data?.[0]?.id ?? ""}`;
}

function canReadChatConversation(
  conversation: Record<string, unknown>,
  user: User,
) {
  if (canManageSchoolContent(user)) return true;
  const userRole = role(user);
  if (userRole === "parent") {
    return text(conversation.parent_id) === user.id;
  }
  if (userRole === "teacher") {
    return text(conversation.teacher_id) === linkedStaffId(user);
  }
  return false;
}

function canSendChatMessage(
  conversation: Record<string, unknown>,
  user: User,
) {
  const userRole = role(user);
  const type = text(conversation.type) || "parent_teacher";
  if (type === "parent_teacher") {
    return canReadChatConversation(conversation, user) && userRole !== "principal";
  }
  if (canManageSchoolContent(user)) return true;
  if (type === "principal_parent") {
    return userRole === "parent" && text(conversation.parent_id) === user.id;
  }
  if (type === "principal_teacher") {
    return userRole === "teacher" &&
      text(conversation.teacher_id) === linkedStaffId(user);
  }
  return false;
}

async function resolveChatNotificationTarget(
  svc: SupabaseClient,
  school: string,
  conversation: Record<string, unknown>,
  user: User,
) {
  const type = text(conversation.type) || "parent_teacher";
  const parentId = text(conversation.parent_id);
  const teacherId = text(conversation.teacher_id);
  const createdBy = text(conversation.created_by);
  const teacherUserId = await teacherUserIdForStaff(svc, school, teacherId);

  if (type === "parent_teacher") {
    if (parentId && parentId !== user.id) return parentId;
    if (teacherUserId && teacherUserId !== user.id) return teacherUserId;
    return "";
  }

  if (createdBy && createdBy !== user.id) {
    return createdBy;
  }

  if (type === "principal_parent") {
    if (canManageSchoolContent(user)) {
      return parentId && parentId !== user.id ? parentId : "";
    }
    const principalUserId = await principalUserIdForSchool(svc, school);
    if (principalUserId && principalUserId !== user.id) return principalUserId;
    return parentId && parentId !== user.id ? parentId : "";
  }

  if (type === "principal_teacher") {
    if (canManageSchoolContent(user)) {
      return teacherUserId && teacherUserId !== user.id ? teacherUserId : "";
    }
    const principalUserId = await principalUserIdForSchool(svc, school);
    if (principalUserId && principalUserId !== user.id) return principalUserId;
    return teacherUserId && teacherUserId !== user.id ? teacherUserId : "";
  }

  return "";
}

async function enrichChatConversations(
  svc: SupabaseClient,
  school: string,
  rows: Record<string, unknown>[],
) {
  const teacherIds = uniqueText(rows.map((row) => row.teacher_id));
  const parentIds = uniqueText(rows.map((row) => row.parent_id));
  const studentIds = uniqueText(rows.map((row) => row.student_id));
  const teachersById = new Map<string, Record<string, unknown>>();
  const parentsById = new Map<string, Record<string, unknown>>();
  const studentsById = new Map<string, Record<string, unknown>>();

  if (teacherIds.length) {
    const { data } = await svc.from("staff").select("*").eq("school_id", school)
      .in("id", teacherIds);
    for (const row of data ?? []) teachersById.set(`${row.id}`, row);
  }
  if (parentIds.length) {
    const { data } = await svc.from("users").select("*").eq("school_id", school)
      .in("id", parentIds);
    for (const row of data ?? []) parentsById.set(`${row.id}`, row);
  }
  if (studentIds.length) {
    const { data } = await svc.from("students").select("*").eq(
      "school_id",
      school,
    ).in("id", studentIds);
    for (const row of data ?? []) studentsById.set(`${row.id}`, row);
  }

  return rows.map((row) => ({
    ...row,
    teacher: teachersById.get(`${row.teacher_id ?? ""}`) ?? null,
    parent: parentsById.get(`${row.parent_id ?? ""}`) ?? null,
    student: studentsById.get(`${row.student_id ?? ""}`) ?? null,
  }));
}

async function appendNotification(
  svc: SupabaseClient,
  school: string,
  userId: string,
  title: string,
  body: string,
  entityId: string,
) {
  if (!userId) return;
  await svc.from("notification_logs").insert({
    school_id: school,
    user_id: userId,
    title,
    body,
    type: "message",
    entity_type: "message",
    entity_id: entityId,
    is_read: false,
  });
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
    audience:
      `${body.target_audience ?? body.targetAudience ?? body.audience ?? "all"}`
        .trim() || "all",
    priority: `${body.priority ?? (urgent ? "high" : "normal")}`.trim() ||
      "normal",
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
      name: payload.teacher_name ??
        [teacher.first_name, teacher.last_name].filter(Boolean).join(" "),
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
    teacher_name: payload.teacher_name ??
      [teacher.first_name, teacher.last_name].filter(Boolean).join(" ").trim(),
  };
}

export async function handleCommunications(
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

  // ── Unified WhatsApp-style chat ────────────────────────────
  if (path === "/chat/conversations" && method === "GET") {
    let q = svc.from("message_conversations").select("*").eq(
      "school_id",
      school,
    );
    const type = text(url.searchParams.get("type"));
    const teacherId = text(url.searchParams.get("teacher_id"));
    const parentId = text(url.searchParams.get("parent_id"));
    const studentId = text(url.searchParams.get("student_id"));
    const requestedMonitor = text(url.searchParams.get("monitor")) == "true";
    const userRole = role(user);
    if (type) q = q.eq("type", type);
    if (teacherId) q = q.eq("teacher_id", teacherId);
    if (parentId) q = q.eq("parent_id", parentId);
    if (studentId) q = q.eq("student_id", studentId);
    if (!canManageSchoolContent(user) || !requestedMonitor) {
      if (userRole == "teacher") {
        const teacher = linkedStaffId(user);
        if (!teacher) return ok([]);
        q = q.eq("teacher_id", teacher);
      } else if (userRole == "parent") {
        q = q.eq("parent_id", user.id);
      }
    }
    const { data, error } = await q.order("updated_at", { ascending: false });
    if (error) return fail(error.message);
    const rows = await enrichChatConversations(svc, school, data ?? []);
    const ids = rows.map((row) => text(row["id"])).filter(Boolean);
    let unreadByConversation = new Map<string, number>();
    if (ids.length) {
      const { data: messages, error: unreadError } = await svc.from("messages")
        .select("conversation_id,sender_id,read_by").eq("school_id", school)
        .in("conversation_id", ids);
      if (unreadError) return fail(unreadError.message);
      unreadByConversation = new Map<string, number>();
      for (const message of messages ?? []) {
        if (`${message.sender_id ?? ""}` == user.id) continue;
        if (readByList(message.read_by).includes(user.id)) continue;
        const convId = `${message.conversation_id ?? ""}`;
        unreadByConversation.set(
          convId,
          (unreadByConversation.get(convId) ?? 0) + 1,
        );
      }
    }
    return ok(rows.map((row) =>
      normalizeChatConversation({
        ...row,
        unread_count: unreadByConversation.get(text(row["id"])) ?? 0,
      }, user.id)
    ));
  }

  if (path === "/chat/conversations" && method === "POST") {
    const conversationType = text(body.type) || "parent_teacher";
    const teacherId = text(body.teacher_id);
    const parentId = text(body.parent_id) ||
      (role(user) == "parent" ? user.id : "");
    const studentId = text(body.student_id);
    if (conversationType == "parent_teacher" && (!teacherId || !parentId)) {
      return fail("teacher_id and parent_id are required");
    }
    let existing = svc.from("message_conversations").select("*")
      .eq("school_id", school)
      .eq("type", conversationType);
    if (teacherId) existing = existing.eq("teacher_id", teacherId);
    if (parentId) existing = existing.eq("parent_id", parentId);
    if (studentId) existing = existing.eq("student_id", studentId);
    const { data: found, error: findError } = await existing.maybeSingle();
    if (findError) return fail(findError.message);
    if (found) return ok(normalizeChatConversation(found, user.id));

    const { data, error } = await svc.from("message_conversations").insert({
      school_id: school,
      type: conversationType,
      title: text(body.title) || null,
      teacher_id: teacherId || null,
      parent_id: parentId || null,
      student_id: studentId || null,
      participant_ids: [teacherId, parentId].filter(Boolean),
      created_by: user.id,
      last_message_at: new Date().toISOString(),
    }).select("*").single();
    if (error) return fail(error.message);
    return ok(normalizeChatConversation(data, user.id));
  }

  const chatMessagesMatch = path.match(
    /^\/chat\/conversations\/([^/]+)\/messages$/,
  );
  if (chatMessagesMatch && method === "GET") {
    const conversationId = chatMessagesMatch[1];
    const { data: conversation, error: conversationError } = await svc.from(
      "message_conversations",
    ).select("*").eq("school_id", school).eq("id", conversationId)
      .maybeSingle();
    if (conversationError) return fail(conversationError.message);
    if (!conversation) return fail("conversation not found", 404);
    if (!canReadChatConversation(conversation, user)) {
      return fail("forbidden", 403);
    }
    const pageSize = Math.min(
      Number(url.searchParams.get("page_size") ?? 80),
      200,
    );
    let q = svc.from("messages").select("*").eq("school_id", school)
      .eq("conversation_id", conversationId);
    const sentAfter = text(url.searchParams.get("sent_after"));
    if (sentAfter) q = q.gt("sent_at", sentAfter);
    const { data, error } = await q.order("sent_at", { ascending: true }).limit(
      pageSize,
    );
    if (error) return fail(error.message);
    return ok((data ?? []).map((row) => normalizeChatMessage(row, user.id)));
  }

  if (chatMessagesMatch && method === "POST") {
    const conversationId = chatMessagesMatch[1];
    const { data: conversation, error: conversationError } = await svc.from(
      "message_conversations",
    ).select("*").eq("id", conversationId).eq("school_id", school)
      .maybeSingle();
    if (conversationError) return fail(conversationError.message);
    if (!conversation) return fail("conversation not found", 404);
    if (!canSendChatMessage(conversation, user)) return fail("forbidden", 403);
    const messageText = text(body.body ?? body.message ?? body.message_body);
    if (!messageText && !text(body.attachment_url)) {
      return fail("message body required");
    }
    const senderRole = role(user) || text(body.sender_role) || "user";
    const senderName = text(
      user.user_metadata?.name ?? user.email ?? body.sender_name,
    );
    const now = new Date().toISOString();
    const { data: message, error } = await svc.from("messages").insert({
      school_id: school,
      conversation_id: conversationId,
      sender_id: user.id,
      sender_role: senderRole,
      sender_name: senderName,
      body: messageText,
      message_type: text(body.message_type) || "text",
      attachment_url: text(body.attachment_url) || null,
      attachments: body.attachments ?? null,
      read_by: [user.id],
      sent_at: now,
      delivered_at: now,
    }).select("*").single();
    if (error) return fail(error.message);
    await svc.from("message_conversations").update({
      last_message: messageText,
      last_message_at: now,
      last_sender_id: user.id,
      updated_at: now,
    }).eq("id", conversationId).eq("school_id", school);
    if (conversation) {
      const type = `${conversation.type ?? "parent_teacher"}`;
      const targetUserId = await resolveChatNotificationTarget(
        svc,
        school,
        conversation,
        user,
      );
      if (targetUserId && targetUserId != user.id) {
        await appendNotification(
          svc,
          school,
          targetUserId,
          type == "parent_teacher"
            ? "New parent-teacher message"
            : "New message",
          messageText,
          conversationId,
        );
      }
    }
    return ok(normalizeChatMessage(message, user.id));
  }

  const chatReadMatch = path.match(/^\/chat\/conversations\/([^/]+)\/read$/);
  if (chatReadMatch && method === "POST") {
    const conversationId = chatReadMatch[1];
    const { data: conversation, error: conversationError } = await svc.from(
      "message_conversations",
    ).select("*").eq("school_id", school).eq("id", conversationId)
      .maybeSingle();
    if (conversationError) return fail(conversationError.message);
    if (!conversation) return fail("conversation not found", 404);
    if (!canReadChatConversation(conversation, user)) {
      return fail("forbidden", 403);
    }
    const { data, error } = await svc.from("messages").select("*")
      .eq("school_id", school).eq("conversation_id", conversationId);
    if (error) return fail(error.message);
    for (const message of data ?? []) {
      const readBy = readByList(message.read_by);
      if (!readBy.includes(user.id)) {
        await svc.from("messages").update({ read_by: [...readBy, user.id] })
          .eq("id", message.id).eq("school_id", school);
      }
    }
    return ok({ success: true });
  }

  if (path === "/chat/monitor" && method === "GET") {
    if (!canManageSchoolContent(user)) return fail("forbidden", 403);
    const monitorUrl = new URL(url);
    monitorUrl.searchParams.set("monitor", "true");
    return handleCommunications(
      req,
      "/chat/conversations",
      "GET",
      monitorUrl,
      _client,
      svc,
      user,
    );
  }

  // ── Announcements ─────────────────────────────────────────
  if (path.startsWith("/announcements")) {
    const seg =
      path.slice("/announcements".length).split("/").filter(Boolean)[0];
    if (!seg && method === "GET") {
      let q = svc.from("announcements").select("*").eq("school_id", school);
      if (url.searchParams.get("status")) {
        q = q.eq("status", url.searchParams.get("status")!);
      }
      if (url.searchParams.get("audience")) {
        q = q.eq("audience", url.searchParams.get("audience")!);
      }
      const { data, error } = await q.order("created_at", { ascending: false })
        .limit(50);
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
      const {
        school_id: _ignoredSchool,
        created_by: _ignoredUser,
        ...changes
      } = payload;
      const { data, error } = await svc.from("announcements").update({
        ...changes,
        updated_at: new Date().toISOString(),
      }).eq("id", seg).eq("school_id", school).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (seg && method === "DELETE") {
      await svc.from("announcements").delete().eq("id", seg).eq(
        "school_id",
        school,
      );
      return ok({ success: true });
    }
  }

  // ── Notices (announcement alias for existing Flutter screens) ───────────
  if (path.startsWith("/notices")) {
    const seg = path.slice("/notices".length).split("/").filter(Boolean)[0];
    if (!seg && method === "GET") {
      let q = svc.from("announcements").select("*").eq("school_id", school);
      if (url.searchParams.get("target_role")) {
        q = q.eq("audience", url.searchParams.get("target_role")!);
      }
      if (url.searchParams.get("status")) {
        q = q.eq("status", url.searchParams.get("status")!);
      }
      const { data, error } = await q.order("created_at", { ascending: false })
        .limit(50);
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
      const { data, error } = await svc.from("announcements").insert(payload)
        .select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  // ── Notifications ─────────────────────────────────────────
  if (path === "/notifications" && method === "GET") {
    const { data, error } = await svc.from("notification_logs").select("*").eq(
      "user_id",
      user.id,
    ).order("created_at", { ascending: false }).limit(50);
    if (error) return fail(error.message);
    return ok((data ?? []).map((row: Record<string, unknown>) => ({
      ...row,
      notification_type: row.type ?? "general",
      reference_type: row.entity_type ?? "",
      reference_id: row.entity_id ?? "",
      target_role: row.target_role ?? "all",
      target_user_id: row.user_id ?? "",
      sent_at: row.created_at ?? null,
    })));
  }
  if (path === "/notifications" && method === "POST") {
    const { data, error } = await svc.from("notification_logs").insert({
      school_id: school,
      user_id: body.user_id ?? user.id,
      title: body.title ?? body.subject ?? "Notification",
      body: body.body ?? body.message ?? "",
      type: body.type ?? body.notification_type ?? "general",
      entity_type: body.entity_type ?? body.reference_type ?? null,
      entity_id: body.entity_id ?? body.reference_id ?? null,
      is_read: body.is_read ?? false,
    }).select().single();
    if (error) return fail(error.message);
    return ok({
      ...data,
      notification_type: data?.type ?? "general",
      reference_type: data?.entity_type ?? "",
      reference_id: data?.entity_id ?? "",
      target_role: data?.target_role ?? "all",
      target_user_id: data?.user_id ?? "",
      sent_at: data?.created_at ?? null,
    });
  }
  if (path === "/notifications/mark-read" && method === "POST") {
    await svc.from("notification_logs").update({ is_read: true }).eq(
      "user_id",
      user.id,
    );
    return ok({ success: true });
  }
  const notificationReadMatch = path.match(/^\/notifications\/([^/]+)\/read$/);
  if (notificationReadMatch && (method === "POST" || method === "PUT")) {
    const { data, error } = await svc.from("notification_logs").update({
      is_read: true,
    }).eq("id", notificationReadMatch[1]).eq("user_id", user.id).select()
      .single();
    if (error) return fail(error.message);
    return ok({
      ...data,
      notification_type: data?.type ?? "general",
      reference_type: data?.entity_type ?? "",
      reference_id: data?.entity_id ?? "",
      target_role: data?.target_role ?? "all",
      target_user_id: data?.user_id ?? "",
      sent_at: data?.created_at ?? null,
    });
  }
  if (path === "/notifications/device-tokens" && method === "POST") {
    const { token, platform } = body;
    if (!token) return fail("token required");
    await svc.from("notification_device_tokens").upsert({
      user_id: user.id,
      token,
      platform: platform ?? "android",
    }, { onConflict: "user_id,token" });
    return ok({ success: true });
  }
  if (path === "/notifications/device-tokens" && method === "DELETE") {
    const { token } = body;
    if (!token) return fail("token required");
    const { error } = await svc.from("notification_device_tokens").delete().eq(
      "user_id",
      user.id,
    ).eq("token", token);
    if (error) return fail(error.message);
    return ok({ success: true });
  }

  // ── PTM slots / parent-teacher meetings ───────────────────
  if (path === "/teacher/ptm-slots" && method === "GET") {
    const teacher = user.app_metadata?.linked_id as string | undefined;
    let q = svc.from("parent_teacher_meetings").select(
      "*, event:events(*), teacher:staff(*), student:students(*), guardian:guardians(*), section:sections(*, grade:grades(*))",
    ).eq("school_id", school);
    if (teacher) q = q.eq("teacher_id", teacher);
    const { data, error } = await q.order("slot_date", { ascending: true })
      .order("slot_time", { ascending: true });
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
    let q = svc.from("parent_teacher_meetings").select(
      "*, event:events(*), teacher:staff(*), student:students(*), guardian:guardians(*), section:sections(*, grade:grades(*))",
    ).eq("school_id", school);
    if (url.searchParams.get("student_id")) {
      q = q.eq("student_id", url.searchParams.get("student_id")!);
    }
    if (url.searchParams.get("teacher_id")) {
      q = q.eq("teacher_id", url.searchParams.get("teacher_id")!);
    }
    if (url.searchParams.get("academic_year_id")) {
      q = q.eq("academic_year_id", url.searchParams.get("academic_year_id")!);
    }
    const { data, error } = await q.order("slot_date", { ascending: true })
      .order("slot_time", { ascending: true });
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
  const ptmMatch = path.match(
    /^\/parent-teacher-meetings\/([^/]+)(?:\/(book))?$/,
  );
  if (ptmMatch && method === "PUT") {
    const payload = ptmMatch[2] === "book"
      ? {
        status: "booked",
        notes: body.notes ?? "Booked by parent",
        booked_by_parent_user_id: user.id,
        updated_at: new Date().toISOString(),
      }
      : { ...body, updated_at: new Date().toISOString() };
    const { data, error } = await svc.from("parent_teacher_meetings").update(
      payload,
    ).eq("id", ptmMatch[1]).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  // ── Messages ──────────────────────────────────────────────
  if (path === "/message-conversations" && method === "GET") {
    let q = svc.from("message_conversations").select("*").eq(
      "school_id",
      school,
    );
    if (url.searchParams.get("student_id")) {
      q = q.eq("student_id", url.searchParams.get("student_id")!);
    }
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
    let q = svc.from("messages").select("*, sender:users(name, role_name)").eq(
      "school_id",
      school,
    );
    if (url.searchParams.get("conversation_id")) {
      q = q.eq("conversation_id", url.searchParams.get("conversation_id")!);
    }
    const { data, error } = await q.order("created_at", { ascending: true });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }
  if (path === "/messages" && method === "POST") {
    const { conversation_id, message_body, attachments } = body;
    let convId = conversation_id;
    if (!convId) {
      const { data: conv } = await svc.from("message_conversations").insert({
        school_id: school,
        participant_ids: body.participant_ids ?? [],
      }).select().single();
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
    if (
      !canManageSchoolContent(user) && staffId &&
      staffId !== linkedStaffId(user)
    ) {
      return fail("forbidden", 403);
    }
    if (staffId) q = q.eq("staff_id", staffId);
    if (!staffId && !canManageSchoolContent(user) && linkedStaffId(user)) {
      q = q.eq("staff_id", linkedStaffId(user));
    }
    if (url.searchParams.get("section_id")) {
      q = q.eq("section_id", url.searchParams.get("section_id")!);
    }
    if (url.searchParams.get("date")) {
      q = q.eq("date", url.searchParams.get("date")!);
    }
    const { data, error } = await q.order("date", { ascending: false });
    if (error) return fail(error.message);
    return ok(data);
  }
  if ((path === "/diary" || path === "/diary-entries") && method === "POST") {
    const teacherId = linkedStaffId(user);
    if (!canManageSchoolContent(user) && !teacherId) {
      return fail("staff profile not linked", 400);
    }
    const payload = {
      ...body,
      school_id: school,
      staff_id: canManageSchoolContent(user) ? body.staff_id : teacherId,
      teacher_id: canManageSchoolContent(user)
        ? body.teacher_id ?? body.staff_id
        : teacherId,
      created_by: user.id,
    };
    const { data, error } = await svc.from("diary_entries").insert(payload)
      .select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  const diaryMatch = path.match(/^\/diary-entries\/([^/]+)$/);
  if (diaryMatch && method === "PUT") {
    let q = svc.from("diary_entries").update(body).eq("id", diaryMatch[1]).eq(
      "school_id",
      school,
    );
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
    let q = svc.from("diary_entries").delete().eq("id", diaryMatch[1]).eq(
      "school_id",
      school,
    );
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
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "communications").order("updated_at", {
      ascending: false,
    });
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

// handlers/communications.ts — announcements, notifications, messages, diary
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import {
  fail,
  invokeNotificationProcessor,
  ok,
  triggerPushProcessing,
} from "../index.ts";
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
function text(v: unknown, fallback = "") {
  const value = `${v ?? ""}`.trim();
  return value || fallback;
}

function maskToken(value: unknown) {
  const token = text(value);
  if (!token) return "";
  if (token.length <= 10) return "***";
  return `${token.slice(0, 6)}...${token.slice(-4)}`;
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

async function principalUserIdsForSchool(
  svc: SupabaseClient,
  school: string,
) {
  const { data } = await svc.from("users").select("id").eq("school_id", school)
    .ilike("role_name", "principal");
  return uniqueText((data ?? []).map((row) => row.id));
}

function canRunPushDiagnostics(user: User) {
  return ["principal", "admin", "super_admin"].includes(role(user));
}

async function runPushDiagnostics(
  svc: SupabaseClient,
  user: User,
  school: string,
) {
  const currentRole = role(user);
  if (!canRunPushDiagnostics(user)) {
    return fail("forbidden", 403);
  }

  const [{ data: currentDevices, error: currentDeviceError }, {
    data: legacyDevices,
    error: legacyDeviceError,
  }, {
    data: preferences,
    error: preferencesError,
  }] = await Promise.all([
    svc.from("notification_devices").select(
      "id, fcm_token, device_type, is_active, last_registered_at, created_at",
    ).eq("school_id", school).eq("user_id", user.id).order(
      "last_registered_at",
      { ascending: false },
    ),
    svc.from("notification_device_tokens").select(
      "id, token, platform, created_at",
    ).eq("user_id", user.id).order("created_at", { ascending: false }),
    svc.from("notification_preferences").select(
      "enable_push, updated_at",
    ).eq("school_id", school).eq("user_id", user.id).maybeSingle(),
  ]);

  if (currentDeviceError) return fail(currentDeviceError.message, 500);
  if (legacyDeviceError) return fail(legacyDeviceError.message, 500);
  if (preferencesError && preferencesError.code !== "PGRST116") {
    return fail(preferencesError.message, 500);
  }

  const processorHealth = await invokeNotificationProcessor({ healthcheck: true });

  const canonicalDevices = (currentDevices ?? []).map((device) => ({
    id: device.id,
    token_preview: maskToken(device.fcm_token),
    device_type: device.device_type ?? "unknown",
    is_active: device.is_active ?? false,
    last_registered_at: device.last_registered_at ?? null,
    created_at: device.created_at ?? null,
  }));
  const legacyTokenRows = (legacyDevices ?? []).map((device) => ({
    id: device.id,
    token_preview: maskToken(device.token),
    platform: device.platform ?? "unknown",
    created_at: device.created_at ?? null,
  }));

  const logTitle = `Push diagnostic test (${currentRole})`;
  const logBody =
    "Principal-triggered push test routed through notification_events and notification-processor.";
  const diagnosticReferenceId = `push-diagnostic-${Date.now()}`;

  const { data: logRow, error: logError } = await svc.from("notification_logs")
    .insert({
      school_id: school,
      user_id: user.id,
      target_role: currentRole,
      title: logTitle,
      body: logBody,
      type: "general",
      entity_type: "notification_test",
      entity_id: diagnosticReferenceId,
      route: "/notification-center-screen",
      priority: "high",
      is_read: false,
    }).select("id, created_at").single();
  if (logError) return fail(logError.message, 500);

  const { data: eventRow, error: eventError } = await svc.from(
    "notification_events",
  ).insert({
    school_id: school,
    user_id: user.id,
    event_type: "push_diagnostic_test",
    event_data: {
      message:
        "This test push was triggered from the principal notification center.",
      title: logTitle,
      reference_type: "notification_test",
      reference_id: logRow.id,
    },
  }).select("id, created_at, processed, sent_at").single();
  if (eventError) return fail(eventError.message, 500);

  const processorResult = await invokeNotificationProcessor({
    event_ids: [eventRow.id],
    source: "push_diagnostics",
  });

  const [{ data: processedEvent, error: processedEventError }, {
    data: devicesAfter,
    error: devicesAfterError,
  }] = await Promise.all([
    svc.from("notification_events").select(
      "id, processed, sent_at, created_at, event_type, event_data",
    ).eq("id", eventRow.id).maybeSingle(),
    svc.from("notification_devices").select(
      "id, fcm_token, device_type, is_active, last_registered_at",
    ).eq("school_id", school).eq("user_id", user.id).order(
      "last_registered_at",
      { ascending: false },
    ),
  ]);

  if (processedEventError) return fail(processedEventError.message, 500);
  if (devicesAfterError) return fail(devicesAfterError.message, 500);

  const summary = {
    has_canonical_device: canonicalDevices.length > 0,
    canonical_device_count: canonicalDevices.length,
    active_canonical_device_count: canonicalDevices.filter((device) =>
      device.is_active
    ).length,
    legacy_device_count: legacyTokenRows.length,
    push_enabled: preferences?.enable_push ?? true,
    processor_health_ok: processorHealth.ok,
    processor_run_ok: processorResult.ok,
    event_processed: processedEvent?.processed ?? false,
  };

  return ok({
    requested_at: new Date().toISOString(),
    actor: {
      user_id: user.id,
      school_id: school,
      role: currentRole,
    },
    preference: {
      enable_push: preferences?.enable_push ?? true,
      updated_at: preferences?.updated_at ?? null,
    },
    canonical_devices: canonicalDevices,
    legacy_devices: legacyTokenRows,
    processor_health: processorHealth,
    notification_log: logRow,
    notification_event_before: eventRow,
    processor_run: processorResult,
    notification_event_after: processedEvent,
    canonical_devices_after: (devicesAfter ?? []).map((device) => ({
      id: device.id,
      token_preview: maskToken(device.fcm_token),
      device_type: device.device_type ?? "unknown",
      is_active: device.is_active ?? false,
      last_registered_at: device.last_registered_at ?? null,
    })),
    summary,
  });
}

async function validateChatConversationScope(
  svc: SupabaseClient,
  school: string,
  type: string,
  teacherId: string,
  parentId: string,
  studentId: string,
): Promise<string | null> {
  if (type === "parent_teacher") {
    if (!studentId) {
      return "parent_teacher scope requires a linked student";
    }
    if (!parentId || !teacherId) {
      return "parent_teacher scope requires a parent and teacher participant";
    }

    // Check linked student
    const { data: link, error: linkError } = await svc.from(
      "parent_student_links",
    )
      .select("id")
      .eq("parent_user_id", parentId)
      .eq("student_id", studentId)
      .eq("school_id", school)
      .maybeSingle();

    if (linkError || !link) {
      return "parent_teacher scope requires a linked student";
    }

    // Check teacher is class teacher or co-teacher of student's section
    const { data: student, error: studentError } = await svc.from("students")
      .select("current_section_id")
      .eq("id", studentId)
      .eq("school_id", school)
      .maybeSingle();

    if (studentError || !student || !student.current_section_id) {
      return "student does not have a current section";
    }

    const { data: section, error: sectionError } = await svc.from("sections")
      .select("class_teacher_id, co_teacher_id")
      .eq("id", student.current_section_id)
      .eq("school_id", school)
      .maybeSingle();

    if (sectionError || !section) {
      return "section not found";
    }

    if (
      section.class_teacher_id !== teacherId &&
      section.co_teacher_id !== teacherId
    ) {
      return "teacher must be class teacher or co-teacher";
    }
  } else if (type === "principal_parent") {
    if (!parentId) {
      return "principal_parent scope requires a parent participant";
    }
    const { data: parentUser, error: pError } = await svc.from("users")
      .select("role_name")
      .eq("id", parentId)
      .eq("school_id", school)
      .maybeSingle();

    if (
      pError || !parentUser ||
      `${parentUser.role_name}`.trim().toLowerCase() !== "parent"
    ) {
      return "principal_parent scope requires a parent participant";
    }
  } else if (type === "principal_teacher") {
    if (!teacherId) {
      return "principal_teacher scope requires a teacher participant";
    }
    const { data: staffMember, error: sError } = await svc.from("staff")
      .select("id")
      .eq("id", teacherId)
      .eq("school_id", school)
      .maybeSingle();

    if (sError || !staffMember) {
      return "principal_teacher scope requires a teacher participant";
    }
  }
  return null;
}

async function parentChatContacts(
  svc: SupabaseClient,
  school: string,
  user: User,
  studentId?: string,
) {
  let studentQuery = svc.from("parent_student_links")
    .select(
      "student_id, students(id, first_name, last_name, current_section_id)",
    )
    .eq("parent_user_id", user.id)
    .eq("school_id", school);

  if (studentId) {
    studentQuery = studentQuery.eq("student_id", studentId);
  }

  const { data: links } = await studentQuery;
  const contacts: any[] = [];
  const addedKeys = new Set<string>();

  for (const link of links ?? []) {
    const student = (link as any).students;
    if (!student) continue;
    const studentName = [student.first_name, student.last_name].filter(Boolean)
      .join(" ");
    const sectionId = student.current_section_id;
    if (!sectionId) continue;

    const { data: section } = await svc.from("sections")
      .select(
        "id, class_teacher:staff!sections_class_teacher_id_fkey(*), co_teacher:staff!sections_co_teacher_id_fkey(*)",
      )
      .eq("id", sectionId)
      .eq("school_id", school)
      .maybeSingle();

    if (section) {
      const ct = (section as any).class_teacher;
      if (ct) {
        const key = `teacher:${ct.id}:${student.id}`;
        if (!addedKeys.has(key)) {
          addedKeys.add(key);
          contacts.push({
            id: ct.id,
            name: [ct.first_name, ct.last_name].filter(Boolean).join(" "),
            role: "teacher",
            contact_role: "class_teacher",
            student_id: student.id,
            student_name: studentName,
            type: "parent_teacher",
          });
        }
      }
      const co = (section as any).co_teacher;
      if (co) {
        const key = `teacher:${co.id}:${student.id}`;
        if (!addedKeys.has(key)) {
          addedKeys.add(key);
          contacts.push({
            id: co.id,
            name: [co.first_name, co.last_name].filter(Boolean).join(" "),
            role: "teacher",
            contact_role: "co_teacher",
            student_id: student.id,
            student_name: studentName,
            type: "parent_teacher",
          });
        }
      }
    }
  }

  // Add principals
  const { data: principals } = await svc.from("users")
    .select("id, name, username")
    .eq("school_id", school)
    .ilike("role_name", "principal");

  for (const p of principals ?? []) {
    const key = `principal:${p.id}`;
    if (!addedKeys.has(key)) {
      addedKeys.add(key);
      contacts.push({
        id: p.id,
        name: p.name || p.username || "Principal",
        role: "principal",
        type: "principal_parent",
      });
    }
  }

  return contacts;
}

async function teacherChatContacts(
  svc: SupabaseClient,
  school: string,
  user: User,
) {
  const staffId = linkedStaffId(user);
  if (!staffId) return [];

  const { data: sections } = await svc.from("sections")
    .select(
      "id, class_teacher:staff!sections_class_teacher_id_fkey(*), co_teacher:staff!sections_co_teacher_id_fkey(*)",
    )
    .eq("school_id", school)
    .or(`class_teacher_id.eq.${staffId},co_teacher_id.eq.${staffId}`);

  const contacts: any[] = [];
  const addedKeys = new Set<string>();

  for (const section of sections ?? []) {
    const { data: students } = await svc.from("students")
      .select("id, first_name, last_name")
      .eq("current_section_id", section.id)
      .eq("school_id", school);

    for (const student of students ?? []) {
      const studentName = [student.first_name, student.last_name].filter(
        Boolean,
      ).join(" ");
      const { data: links } = await svc.from("parent_student_links")
        .select(
          "parent_user_id, parent:users!parent_student_links_parent_user_id_fkey(*)",
        )
        .eq("student_id", student.id)
        .eq("school_id", school);

      for (const link of links ?? []) {
        const p = (link as any).parent;
        if (!p) continue;
        const key = `parent:${p.id}:${student.id}`;
        if (!addedKeys.has(key)) {
          addedKeys.add(key);
          contacts.push({
            id: p.id,
            name: p.name || p.username || "Parent",
            role: "parent",
            student_id: student.id,
            student_name: studentName,
            contact_role: "student_parent",
            type: "parent_teacher",
          });
        }
      }
    }
  }

  // Add principals
  const { data: principals } = await svc.from("users")
    .select("id, name, username")
    .eq("school_id", school)
    .ilike("role_name", "principal");

  for (const p of principals ?? []) {
    const key = `principal:${p.id}`;
    if (!addedKeys.has(key)) {
      addedKeys.add(key);
      contacts.push({
        id: p.id,
        name: p.name || p.username || "Principal",
        role: "principal",
        type: "principal_teacher",
      });
    }
  }

  return contacts;
}

async function principalChatContacts(
  svc: SupabaseClient,
  school: string,
) {
  const contacts: any[] = [];
  const addedKeys = new Set<string>();

  const { data: staff } = await svc.from("staff")
    .select("*")
    .eq("school_id", school)
    .eq("is_active", true);

  for (const s of staff ?? []) {
    const key = `teacher:${s.id}`;
    if (!addedKeys.has(key)) {
      addedKeys.add(key);
      contacts.push({
        id: s.id,
        name: [s.first_name, s.last_name].filter(Boolean).join(" "),
        role: "teacher",
        type: "principal_teacher",
      });
    }
  }

  const { data: parents } = await svc.from("users")
    .select("*")
    .eq("school_id", school)
    .ilike("role_name", "parent");

  for (const p of parents ?? []) {
    const key = `parent:${p.id}`;
    if (!addedKeys.has(key)) {
      addedKeys.add(key);
      contacts.push({
        id: p.id,
        name: p.name || p.username || "Parent",
        role: "parent",
        type: "principal_parent",
      });
    }
  }

  return contacts;
}

async function getTeacherAllowedConversationsStaffIds(
  svc: SupabaseClient,
  school: string,
  staffId: string,
): Promise<string[]> {
  const { data: sections } = await svc.from("sections")
    .select("class_teacher_id, co_teacher_id")
    .eq("school_id", school)
    .or(`class_teacher_id.eq.${staffId},co_teacher_id.eq.${staffId}`);

  const ids = new Set<string>([staffId]);
  for (const s of sections ?? []) {
    if (s.class_teacher_id) ids.add(s.class_teacher_id);
    if (s.co_teacher_id) ids.add(s.co_teacher_id);
  }
  return [...ids];
}

async function canReadChatConversation(
  svc: SupabaseClient,
  school: string,
  conversation: Record<string, unknown>,
  user: User,
): Promise<boolean> {
  if (canManageSchoolContent(user)) return true;
  const userRole = role(user);
  if (userRole === "parent") {
    return text(conversation.parent_id) === user.id;
  }
  if (userRole === "teacher") {
    const staffId = linkedStaffId(user);
    if (!staffId) return false;
    const convTeacherId = text(conversation.teacher_id);
    if (convTeacherId === staffId) return true;

    // Check if user is counterpart teacher for the student's class
    const studentId = text(conversation.student_id);
    if (!studentId) return false;

    const { data: student } = await svc.from("students")
      .select("current_section_id")
      .eq("id", studentId)
      .eq("school_id", school)
      .maybeSingle();
    if (!student || !student.current_section_id) return false;

    const { data: section } = await svc.from("sections")
      .select("class_teacher_id, co_teacher_id")
      .eq("id", student.current_section_id)
      .eq("school_id", school)
      .maybeSingle();
    if (!section) return false;

    const isUserTeacher = section.class_teacher_id === staffId ||
      section.co_teacher_id === staffId;
    const isConvTeacher = section.class_teacher_id === convTeacherId ||
      section.co_teacher_id === convTeacherId;

    return isUserTeacher && isConvTeacher;
  }
  return false;
}

async function canSendChatMessage(
  svc: SupabaseClient,
  school: string,
  conversation: Record<string, unknown>,
  user: User,
): Promise<boolean> {
  const userRole = role(user);
  const type = text(conversation.type) || "parent_teacher";
  if (type === "parent_teacher") {
    return await canReadChatConversation(svc, school, conversation, user) &&
      userRole !== "principal";
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
  targetRole = "all",
) {
  if (!userId) return;
  await svc.from("notification_logs").insert({
    school_id: school,
    user_id: userId,
    target_role: targetRole,
    title,
    body,
    type: "message",
    entity_type: "message",
    entity_id: entityId,
    route: "/communication-center-screen",
    priority: "medium",
    is_read: false,
  });
  // Also create a push notification event so the processor sends an FCM message
  try {
    const { data } = await svc.from("notification_events").insert({
      school_id: school,
      user_id: userId,
      event_type: "announcement",
      event_data: {
        title,
        message: body,
        announcement_id: entityId,
        reference_type: "message",
        reference_id: entityId,
      },
    }).select("id").maybeSingle();
    if (data?.id) triggerPushProcessing(data.id);
  } catch (_) { /* best-effort */ }
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

function normalizeLessonPlannerAttachments(source: Record<string, unknown>) {
  const rawAttachments = Array.isArray(source.attachments)
    ? source.attachments
    : [];
  const attachments = rawAttachments
    .filter((item) => item && typeof item === "object")
    .map((item) => {
      const row = item as Record<string, unknown>;
      const url = text(row.url ?? row.attachment_url);
      if (!url) return null;
      return {
        url,
        name: text(row.name ?? row.file_name, "Open attachment"),
        mime_type: text(row.mime_type ?? row.mimeType),
        size: Number(row.size ?? 0),
      };
    })
    .filter((item) => item !== null);

  if (attachments.length > 0) return attachments;

  const fallbackUrl = text(source.attachment_url);
  if (!fallbackUrl) return [];
  return [{
    url: fallbackUrl,
    name: text(source.attachment_name, "Open attachment"),
    mime_type: text(source.mime_type ?? source.mimeType),
    size: Number(source.size ?? 0),
  }];
}

function firstLessonPlannerAttachmentUrl(
  attachments: Array<Record<string, unknown>>,
) {
  return text(attachments[0]?.url);
}

function lessonPlannerPayload(row: Record<string, unknown>) {
  return typeof row.data === "object" && row.data !== null
    ? row.data as Record<string, unknown>
    : row;
}

function lessonPlannerDisplayText(...values: unknown[]) {
  for (const value of values) {
    const display = text(value);
    if (display && !lessonPlannerIsUuidLike(display)) return display;
  }
  return "";
}

function lessonPlannerIsUuidLike(value: string) {
  return /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/
    .test(value.trim());
}

function lessonPlannerStaffName(staff: Record<string, unknown>) {
  return lessonPlannerDisplayText(
    [text(staff.first_name), text(staff.last_name)].filter(Boolean).join(" "),
    staff.full_name,
    staff.name,
    staff.staff_code,
    staff.email,
  );
}

function normalizeLessonPlannerRow(row: Record<string, unknown>) {
  const payload = lessonPlannerPayload(row);
  const attachments = normalizeLessonPlannerAttachments(payload);
  const teacher = row.teacher && typeof row.teacher === "object"
    ? row.teacher as Record<string, unknown>
    : {};
  const section = row.section && typeof row.section === "object"
    ? row.section as Record<string, unknown>
    : {};
  const grade = section.grade && typeof section.grade === "object"
    ? section.grade as Record<string, unknown>
    : {};
  const gradeName = lessonPlannerDisplayText(
    payload.grade_name,
    grade.grade_name,
    grade.name,
  );
  const sectionName = lessonPlannerDisplayText(
    payload.section_name,
    section.section_name,
    section.name,
  );
  const className = lessonPlannerDisplayText(
    payload.class_name,
    [gradeName, sectionName].filter(Boolean).join(" - "),
    gradeName,
  );
  const teacherName = lessonPlannerDisplayText(
    payload.teacher_name,
    [text(payload.teacher_first_name), text(payload.teacher_last_name)]
      .filter(Boolean).join(" "),
    lessonPlannerStaffName(teacher),
  );
  return {
    ...payload,
    id: payload.id ?? row.record_id ?? row.id,
    status: payload.status ?? "uploaded",
    staff_id: payload.staff_id ?? "",
    section_id: payload.section_id ?? section.id ?? "",
    grade_id: payload.grade_id ?? grade.id ?? "",
    teacher: {
      first_name: payload.teacher_first_name ?? teacher.first_name ?? "",
      last_name: payload.teacher_last_name ?? teacher.last_name ?? "",
      name: teacherName,
    },
    section: {
      id: payload.section_id ?? section.id ?? "",
      section_name: sectionName,
    },
    grade: {
      id: payload.grade_id ?? grade.id ?? "",
      grade_name: gradeName,
    },
    class_name: className,
    grade_name: gradeName,
    section_name: sectionName,
    subject_name: payload.subject_name ?? "",
    note: payload.note ?? payload.content ?? "",
    attachments: normalizeLessonPlannerAttachments(payload),
    attachment_url: firstLessonPlannerAttachmentUrl(attachments),
    week_start_date: payload.week_start_date ?? payload.date ?? null,
    week_end_date: payload.week_end_date ?? payload.date ?? null,
    teacher_name: teacherName,
  };
}

async function enrichLessonPlannerRows(
  svc: SupabaseClient,
  school: string,
  rows: Array<Record<string, unknown>>,
) {
  const sectionIds = uniqueText(
    rows.map((row) => lessonPlannerPayload(row).section_id ?? row.section_id),
  );
  const staffIds = uniqueText(
    rows.map((row) => lessonPlannerPayload(row).staff_id ?? row.staff_id),
  );

  const sectionsById = new Map<string, Record<string, unknown>>();
  if (sectionIds.length > 0) {
    const { data: sections } = await svc.from("sections")
      .select("id, section_name, grade_id, grade:grades(*)")
      .eq("school_id", school)
      .in("id", sectionIds);
    for (const section of sections ?? []) {
      const sectionRow = section as Record<string, unknown>;
      const id = text(sectionRow.id);
      if (id) sectionsById.set(id, sectionRow);
    }
  }

  const staffById = new Map<string, Record<string, unknown>>();
  if (staffIds.length > 0) {
    const { data: staffRows } = await svc.from("staff")
      .select("*")
      .eq("school_id", school)
      .in("id", staffIds);
    for (const staff of staffRows ?? []) {
      const staffRow = staff as Record<string, unknown>;
      const id = text(staffRow.id);
      if (id) staffById.set(id, staffRow);
    }
  }

  return rows.map((row) => {
    const payload = lessonPlannerPayload(row);
    const section = sectionsById.get(
      text(payload.section_id ?? row.section_id),
    );
    const teacher = staffById.get(text(payload.staff_id ?? row.staff_id));
    return normalizeLessonPlannerRow({
      ...row,
      ...(section ? { section } : {}),
      ...(teacher ? { teacher } : {}),
    });
  });
}

async function lessonPlannerAssignedSectionIds(
  svc: SupabaseClient,
  school: string,
  teacherId: string,
) {
  const sectionIds = new Set<string>();
  if (!teacherId) return sectionIds;

  const { data: classSections } = await svc.from("sections")
    .select("id, class_teacher_id, co_teacher_id")
    .eq("school_id", school)
    .or(`class_teacher_id.eq.${teacherId},co_teacher_id.eq.${teacherId}`);

  for (const section of classSections ?? []) {
    const id = text((section as Record<string, unknown>).id);
    if (id) sectionIds.add(id);
  }

  const { data: subjectSections } = await svc.from("staff_subjects")
    .select("section_id")
    .eq("school_id", school)
    .eq("staff_id", teacherId);

  for (const section of subjectSections ?? []) {
    const id = text((section as Record<string, unknown>).section_id);
    if (id) sectionIds.add(id);
  }

  return sectionIds;
}

async function lessonPlannerParentSectionIds(
  svc: SupabaseClient,
  school: string,
  user: User,
) {
  const sectionIds = new Set<string>();
  const { data: links } = await svc.from("parent_student_links")
    .select("student_id")
    .eq("parent_user_id", user.id)
    .eq("school_id", school);

  const studentIds = (links ?? []).map((l: any) => l.student_id).filter(Boolean);
  
  if (studentIds.length > 0) {
    const { data: students } = await svc.from("students")
      .select("current_section_id")
      .eq("school_id", school)
      .in("id", studentIds);
      
    for (const student of students ?? []) {
      const sectionId = text(student.current_section_id);
      if (sectionId) sectionIds.add(sectionId);
    }
  }

  return sectionIds;
}

async function ensureLessonPlannerTeacherCanPost(
  svc: SupabaseClient,
  school: string,
  teacherId: string,
  sectionId: string,
) {
  if (!teacherId) return "teacher profile is not linked";
  if (!sectionId) return "section is required";
  const sectionIds = await lessonPlannerAssignedSectionIds(
    svc,
    school,
    teacherId,
  );
  if (!sectionIds.has(sectionId)) {
    return "teacher is not assigned to this class section";
  }
  return null;
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
  if (path === "/chat/contacts" && method === "GET") {
    const roleParam = text(url.searchParams.get("role")).toLowerCase();
    const studentId = text(url.searchParams.get("student_id"));
    if (roleParam === "parent") {
      const contacts = await parentChatContacts(svc, school, user, studentId);
      return ok(contacts);
    } else if (roleParam === "teacher") {
      const contacts = await teacherChatContacts(svc, school, user);
      return ok(contacts);
    } else if (roleParam === "principal") {
      const contacts = await principalChatContacts(svc, school);
      return ok(contacts);
    }
    return fail("invalid role param");
  }

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
        const allowedTeacherIds = await getTeacherAllowedConversationsStaffIds(
          svc,
          school,
          teacher,
        );
        q = q.in("teacher_id", allowedTeacherIds);
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

    const validationError = await validateChatConversationScope(
      svc,
      school,
      conversationType,
      teacherId,
      parentId,
      studentId,
    );
    if (validationError) {
      return fail(validationError, 403);
    }

    if (conversationType == "parent_teacher" && (!teacherId || !parentId)) {
      return fail("teacher_id and parent_id are required");
    }
    let existing = svc.from("message_conversations").select("*")
      .eq("school_id", school)
      .eq("type", conversationType);
    if (teacherId) existing = existing.eq("teacher_id", teacherId);
    if (parentId) existing = existing.eq("parent_id", parentId);
    if (conversationType === "parent_teacher" && studentId) {
      existing = existing.eq("student_id", studentId);
    }
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
    if (!await canReadChatConversation(svc, school, conversation, user)) {
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
    if (!await canSendChatMessage(svc, school, conversation, user)) {
      return fail("forbidden", 403);
    }
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
        const conversationParentId = text(conversation.parent_id);
        const targetRole = type == "principal_parent"
          ? "parent"
          : type == "principal_teacher"
          ? "teacher"
          : targetUserId == conversationParentId
          ? "parent"
          : "teacher";
        await appendNotification(
          svc,
          school,
          targetUserId,
          type == "parent_teacher"
            ? "New parent-teacher message"
            : "New message",
          messageText,
          conversationId,
          targetRole,
        );
      }
      if (type == "parent_teacher") {
        const principalIds = await principalUserIdsForSchool(svc, school);
        for (const principalId of principalIds) {
          if (principalId == user.id || principalId == targetUserId) continue;
          await appendNotification(
            svc,
            school,
            principalId,
            "Parent-teacher chat updated",
            messageText,
            conversationId,
            "principal",
          );
        }
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
    if (!await canReadChatConversation(svc, school, conversation, user)) {
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
      route: row.route ?? "",
      priority: row.priority ?? "medium",
      student_id: row.student_id ?? "",
      section_id: row.section_id ?? "",
      teacher_id: row.teacher_id ?? "",
      sent_at: row.created_at ?? null,
    })));
  }
  if (path === "/notifications/push-diagnostics" && method === "POST") {
    return runPushDiagnostics(svc, user, school);
  }
  if (path === "/notifications" && method === "POST") {
    const { data, error } = await svc.from("notification_logs").insert({
      school_id: school,
      user_id: body.user_id ?? user.id,
      target_role: body.target_role ?? body.role ?? null,
      title: body.title ?? body.subject ?? "Notification",
      body: body.body ?? body.message ?? "",
      type: body.type ?? body.notification_type ?? "general",
      entity_type: body.entity_type ?? body.reference_type ?? null,
      entity_id: body.entity_id ?? body.reference_id ?? null,
      route: body.route ?? null,
      priority: body.priority ?? "medium",
      student_id: body.student_id ?? null,
      section_id: body.section_id ?? null,
      teacher_id: body.teacher_id ?? null,
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
      route: data?.route ?? "",
      priority: data?.priority ?? "medium",
      student_id: data?.student_id ?? "",
      section_id: data?.section_id ?? "",
      teacher_id: data?.teacher_id ?? "",
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
      route: data?.route ?? "",
      priority: data?.priority ?? "medium",
      student_id: data?.student_id ?? "",
      section_id: data?.section_id ?? "",
      teacher_id: data?.teacher_id ?? "",
      sent_at: data?.created_at ?? null,
    });
  }
  if (path === "/notifications/device-tokens" && method === "POST") {
    const { token, platform } = body;
    if (!token) return fail("token required");
    const schoolId = `${user.app_metadata?.school_id ?? ""}`.trim();
    if (!schoolId) return fail("school_id missing", 400);
    const normalizedPlatform = `${platform ?? "android"}`.trim() || "android";

    // Deactivate this token for ALL other users first — a physical device
    // can only belong to one user at a time.
    await svc.from("notification_devices")
      .update({ is_active: false })
      .eq("school_id", schoolId)
      .eq("fcm_token", token)
      .neq("user_id", user.id);
    await svc.from("notification_device_tokens")
      .delete()
      .eq("token", token)
      .neq("user_id", user.id);

    await svc.from("notification_devices").upsert({
      school_id: schoolId,
      user_id: user.id,
      fcm_token: token,
      device_type: normalizedPlatform,
      last_registered_at: new Date().toISOString(),
      is_active: true,
    }, { onConflict: "school_id,user_id,fcm_token" });
    return ok({ success: true });
  }
  if (path === "/notifications/device-tokens" && method === "DELETE") {
    const { token } = body;
    if (!token) return fail("token required");
    const schoolId = `${user.app_metadata?.school_id ?? ""}`.trim();
    if (schoolId) {
      await svc.from("notification_devices").update({ is_active: false }).eq(
        "school_id",
        schoolId,
      ).eq("user_id", user.id).eq("fcm_token", token);
    }
    // Legacy cleanup only: keep removing matching rows so older dual-written
    // tokens do not remain active while the processor still reads the table.
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
    const isBookAction = ptmMatch[2] === "book";
    const payload = isBookAction
      ? {
        status: "booked",
        notes: body.notes ?? "Booked by parent",
        booked_by_parent_user_id: user.id,
        updated_at: new Date().toISOString(),
      }
      : { ...body, updated_at: new Date().toISOString() };
    const { data, error } = await svc.from("parent_teacher_meetings").update(
      payload,
    ).eq("id", ptmMatch[1]).eq("school_id", school).select(
      "*, teacher:staff(first_name, last_name), student:students(first_name, last_name)",
    ).single();
    if (error) return fail(error.message);

    // ── Notify the relevant party based on the action ──────────────────
    try {
      const meetingId = `${data.id ?? ""}`;
      const slotDate = `${data.slot_date ?? ""}`.split("T")[0];
      const slotTime = `${data.slot_time ?? ""}`.substring(0, 5); // HH:MM

      if (isBookAction) {
        // Parent booked a slot → notify the teacher
        const staffId = `${data.teacher_id ?? ""}`.trim();
        if (staffId) {
          const { data: teacherUserRow } = await svc.from("users")
            .select("id")
            .eq("school_id", school)
            .eq("linked_type", "staff")
            .eq("linked_id", staffId)
            .limit(1)
            .maybeSingle();
          if (teacherUserRow?.id) {
            const teacher = data.teacher as Record<string, unknown> | null;
            const student = data.student as Record<string, unknown> | null;
            const studentName = student
              ? `${student.first_name ?? ""} ${student.last_name ?? ""}`.trim()
              : "a student";
            const notifBody = `A parent booked a PTM slot on ${slotDate} at ${slotTime} regarding ${studentName}.`;
            const { data: ptmEvent } = await svc.from("notification_events").insert({
              school_id: school,
              user_id: teacherUserRow.id,
              event_type: "ptm_booked",
              event_data: {
                ptm_id: meetingId,
                message: notifBody,
                reference_type: "ptm",
                slot_date: slotDate,
                slot_time: slotTime,
              },
            }).select("id").maybeSingle();
            if (ptmEvent?.id) triggerPushProcessing(ptmEvent.id);
          }
        }
      } else {
        // Teacher/principal changed status → notify the parent
        const newStatus = `${payload.status ?? data.status ?? ""}`.toLowerCase();
        if (["confirmed", "cancelled", "rescheduled"].includes(newStatus)) {
          const parentUserId = `${data.booked_by_parent_user_id ?? ""}`.trim();
          if (parentUserId) {
            const teacher = data.teacher as Record<string, unknown> | null;
            const teacherName = teacher
              ? `${teacher.first_name ?? ""} ${teacher.last_name ?? ""}`.trim()
              : "your child's teacher";
            const statusMessages: Record<string, string> = {
              confirmed: `Your PTM meeting with ${teacherName} on ${slotDate} at ${slotTime} has been confirmed.`,
              cancelled: `Your PTM meeting with ${teacherName} on ${slotDate} at ${slotTime} has been cancelled.`,
              rescheduled: `Your PTM meeting with ${teacherName} has been rescheduled. Please check new details.`,
            };
            const notifBody = statusMessages[newStatus] ?? `Your PTM meeting status has been updated to ${newStatus}.`;
            const { data: ptmStatusEvent } = await svc.from("notification_events").insert({
              school_id: school,
              user_id: parentUserId,
              event_type: "ptm_status_updated",
              event_data: {
                ptm_id: meetingId,
                status: newStatus,
                message: notifBody,
                reference_type: "ptm",
                slot_date: slotDate,
                slot_time: slotTime,
              },
            }).select("id").maybeSingle();
            if (ptmStatusEvent?.id) triggerPushProcessing(ptmStatusEvent.id);
          }
        }
      }
    } catch (_) { /* best-effort notifications — PTM update was already saved */ }

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
    const sectionIds = await lessonPlannerAssignedSectionIds(
      svc,
      school,
      teacherId,
    );
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "lesson_planners").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    const rows = (await enrichLessonPlannerRows(svc, school, data ?? []))
      .filter((row) =>
        `${row.staff_id ?? ""}` === teacherId ||
        sectionIds.has(`${row.section_id ?? ""}`)
      );
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
    const rows = await enrichLessonPlannerRows(svc, school, data ?? []);
    return ok(rows);
  }

  if (path === "/lesson-planners/parent" && method === "GET") {
    const sectionIds = await lessonPlannerParentSectionIds(svc, school, user);
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "lesson_planners").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    const rows = (await enrichLessonPlannerRows(svc, school, data ?? []))
      .filter((row) => {
        const status = `${row.status ?? ""}`.toLowerCase();
        return status !== "draft" &&
          sectionIds.has(`${row.section_id ?? ""}`);
      });
    return ok(rows);
  }

  if (path === "/lesson-planners" && method === "POST") {
    const teacherId = linkedStaffId(user);
    const sectionId = `${body.section_id ?? ""}`.trim();
    const scopeError = await ensureLessonPlannerTeacherCanPost(
      svc,
      school,
      teacherId,
      sectionId,
    );
    if (scopeError) return fail(scopeError, 403);
    const attachments = normalizeLessonPlannerAttachments(body);
    if (attachments.length === 0) {
      return fail("at least one lesson plan attachment is required", 422);
    }
    const payload = {
      ...body,
      id: crypto.randomUUID(),
      staff_id: teacherId,
      section_id: sectionId,
      note: `${body.note ?? body.content ?? ""}`.trim(),
      attachments,
      attachment_url: firstLessonPlannerAttachmentUrl(attachments),
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
      record_id: payload.id,
      data: payload,
    }).select().single();
    if (error) return fail(error.message);

    // Trigger push and in-app notifications asynchronously
    const promise = notifyLessonPlannerUploaded(
      svc,
      school,
      payload.id,
      payload.teacher_name,
      payload.subject_name,
      payload.section_id,
    );
    const runtime = (globalThis as any).EdgeRuntime;
    if (runtime?.waitUntil) {
      runtime.waitUntil(promise);
    }

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

async function notifyLessonPlannerUploaded(
  svc: SupabaseClient,
  school: string,
  lessonPlannerId: string,
  teacherName: string,
  subjectName: string,
  sectionId: string,
) {
  try {
    // 1. Get class/section name
    const { data } = await svc
      .from("sections")
      .select("section_name, grade:grades(grade_name)")
      .eq("id", sectionId)
      .eq("school_id", school)
      .maybeSingle();
    const sectionData = data as any;
    const className = sectionData
      ? `${sectionData.grade?.grade_name ?? ""} - ${sectionData.section_name ?? ""}`
      : "Assigned Class";

    const eventIds: string[] = [];

    // 2. Notify principal(s)
    const { data: principalUsers } = await svc
      .from("users")
      .select("id")
      .eq("school_id", school)
      .eq("role_name", "principal");

    if (principalUsers && principalUsers.length > 0) {
      for (const p of principalUsers) {
        await svc.from("notification_logs").insert({
          school_id: school,
          user_id: p.id,
          target_role: "principal",
          title: "New Lesson Planner",
          body: `Teacher ${teacherName} uploaded a lesson planner for ${subjectName} in Class ${className}.`,
          type: "lesson_planner",
          entity_type: "lesson_planner",
          entity_id: lessonPlannerId,
          route: "/principal-lesson-planner-screen",
          priority: "medium",
          is_read: false,
        });

        const { data: evData } = await svc.from("notification_events").insert({
          school_id: school,
          user_id: p.id,
          event_type: "lesson_planner",
          event_data: {
            title: "New Lesson Planner",
            message: `Teacher ${teacherName} uploaded a lesson planner for ${subjectName} in Class ${className}.`,
            reference_type: "lesson_planner",
            reference_id: lessonPlannerId,
            route: "/principal-lesson-planner-screen",
          },
        }).select("id").maybeSingle();
        if (evData?.id) {
          eventIds.push(evData.id);
        }
      }
    }

    // 3. Notify parents of student(s) in this class section
    const { data: students } = await svc
      .from("students")
      .select("id")
      .eq("school_id", school)
      .eq("current_section_id", sectionId);

    const studentIds = (students ?? []).map((s: any) => s.id);
    if (studentIds.length > 0) {
      const { data: links } = await svc
        .from("parent_student_links")
        .select("parent_user_id")
        .eq("school_id", school)
        .in("student_id", studentIds);

      const parentUserIds = Array.from(
        new Set((links ?? []).map((l: any) => l.parent_user_id).filter(Boolean)),
      );

      for (const pid of parentUserIds) {
        await svc.from("notification_logs").insert({
          school_id: school,
          user_id: pid,
          target_role: "parent",
          title: "New Lesson Planner",
          body: `A new lesson planner has been uploaded for Class ${className} for this week.`,
          type: "lesson_planner",
          entity_type: "lesson_planner",
          entity_id: lessonPlannerId,
          route: "/parent-lesson-planner-screen",
          priority: "medium",
          is_read: false,
        });

        const { data: evData } = await svc.from("notification_events").insert({
          school_id: school,
          user_id: pid,
          event_type: "lesson_planner",
          event_data: {
            title: "New Lesson Planner",
            message: `A new lesson planner has been uploaded for Class ${className} for this week.`,
            reference_type: "lesson_planner",
            reference_id: lessonPlannerId,
            route: "/parent-lesson-planner-screen",
          },
        }).select("id").maybeSingle();
        if (evData?.id) {
          eventIds.push(evData.id);
        }
      }
    }

    if (eventIds.length > 0) {
      triggerPushProcessing(eventIds);
    }
  } catch (err) {
    console.error("Failed to trigger lesson planner notifications:", err);
  }
}

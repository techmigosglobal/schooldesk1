// handlers/communications.ts — announcements, notifications, messages, diary
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import {
  fail,
  invokeNotificationProcessor,
  ok,
  triggerPushProcessing,
} from "../index.ts";
import {
  resolveActiveTeacherScope,
  teacherCanAccessStudent,
} from "./teacher_scope.ts";
import { signedPrivateFileUrl, stableStorageReference } from "../storage_helpers.ts";
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
  return ["admin", "principal", "coordinator", "super_admin"].includes(role(u));
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
    section_id: row.section_id ?? "",
    student_name: row.student_name ?? "",
    class_label: row.class_label ?? "",
    contact_role: row.contact_role ?? "",
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

function classLabel(section: Record<string, unknown> | null | undefined) {
  if (!section) return "";
  const grade = section.grade as Record<string, unknown> | undefined;
  return [text(grade?.grade_name), text(section.section_name)]
    .filter(Boolean)
    .join(" - ");
}

function chatContext(
  student: Record<string, unknown> | null | undefined,
  section: Record<string, unknown> | null | undefined,
) {
  return {
    student_id: text(student?.id),
    student_name: [text(student?.first_name), text(student?.last_name)]
      .filter(Boolean)
      .join(" "),
    section_id: text(section?.id ?? student?.current_section_id),
    class_label: classLabel(section),
  };
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
    .in("role_name", ["principal", "coordinator"]);
  return uniqueText((data ?? []).map((row) => row.id));
}

async function isSchoolLeaderId(
  svc: SupabaseClient,
  school: string,
  userId: string,
) {
  if (!userId) return false;
  const { data } = await svc.from("users").select("id").eq("school_id", school)
    .eq("id", userId).in("role_name", ["principal", "coordinator"])
    .maybeSingle();
  return Boolean(data?.id);
}

function canRunPushDiagnostics(user: User) {
  return ["principal", "coordinator", "admin", "super_admin"].includes(
    role(user),
  );
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

  const processorHealth = await invokeNotificationProcessor({
    healthcheck: true,
  });

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
    active_canonical_device_count:
      canonicalDevices.filter((device) => device.is_active).length,
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

    // Teachers may message families for any section assigned through class,
    // co-teacher, or subject-teacher mapping.
    const { data: student, error: studentError } = await svc.from("students")
      .select("current_section_id")
      .eq("id", studentId)
      .eq("school_id", school)
      .maybeSingle();

    if (studentError || !student || !student.current_section_id) {
      return "student does not have a current section";
    }

    const assignedSections = await lessonPlannerAssignedSectionIds(
      svc,
      school,
      teacherId,
    );
    if (!assignedSections.has(`${student.current_section_id}`)) {
      return "teacher is not assigned to this class section";
    }
  } else if (type === "principal_parent") {
    if (!parentId || !studentId) {
      return "principal_parent scope requires a parent and linked student";
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
    const { data: link } = await svc.from("parent_student_links")
      .select("student_id")
      .eq("school_id", school)
      .eq("parent_user_id", parentId)
      .eq("student_id", studentId)
      .maybeSingle();
    if (!link) return "parent is not linked to this student";
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
  const leaderContexts: Record<string, unknown>[] = [];
  const { data: subjectAssignments, error: subjectAssignmentError } = await svc
    .from("staff_subjects")
    .select(
      "staff_id, section_id, grade_id, academic_year_id, subject:subjects(subject_name), teacher:staff!staff_subjects_staff_id_fkey(id, first_name, last_name, is_active)",
    )
    .eq("school_id", school);
  if (subjectAssignmentError) throw new Error(subjectAssignmentError.message);

  for (const link of links ?? []) {
    const student = (link as any).students;
    if (!student) continue;
    const studentName = [student.first_name, student.last_name].filter(Boolean)
      .join(" ");
    const sectionId = student.current_section_id;
    if (!sectionId) continue;

    const { data: section } = await svc.from("sections")
      .select(
        "id, grade_id, academic_year_id, section_name, grade:grades(grade_name), class_teacher:staff!sections_class_teacher_id_fkey(*), co_teacher:staff!sections_co_teacher_id_fkey(*)",
      )
      .eq("id", sectionId)
      .eq("school_id", school)
      .maybeSingle();

    if (section) {
      const context = chatContext(student, section as Record<string, unknown>);
      leaderContexts.push(context);
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
            ...context,
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
            ...context,
            type: "parent_teacher",
          });
        }
      }
      for (const assignment of subjectAssignments ?? []) {
        const matchesSection = text(assignment.section_id) === text(section.id);
        const matchesGrade = !text(assignment.section_id) &&
          text(assignment.grade_id) === text(section.grade_id);
        const matchesYear = !text(assignment.academic_year_id) ||
          text(assignment.academic_year_id) === text(section.academic_year_id);
        if (!matchesYear || (!matchesSection && !matchesGrade)) continue;
        const subjectTeacher = assignment.teacher as unknown as Record<
          string,
          unknown
        > | null;
        const staffId = text(assignment.staff_id ?? subjectTeacher?.id);
        if (!staffId || subjectTeacher?.is_active === false) continue;
        const key = `teacher:${staffId}:${student.id}`;
        if (addedKeys.has(key)) continue;
        addedKeys.add(key);
        const subject = assignment.subject as unknown as Record<
          string,
          unknown
        > | null;
        contacts.push({
          id: staffId,
          name: [text(subjectTeacher?.first_name), text(subjectTeacher?.last_name)]
            .filter(Boolean)
            .join(" ") || "Teacher",
          role: "teacher",
          contact_role: "subject_teacher",
          subject_name: text(subject?.subject_name),
          ...context,
          type: "parent_teacher",
        });
      }
    }
  }

  // Add every school leader so families can reach both Principals and Coordinators.
  const { data: principals } = await svc.from("users")
    .select("id, name, username, role_name")
    .eq("school_id", school)
    .in("role_name", ["principal", "coordinator"]);

  for (const context of leaderContexts) {
    for (const p of principals ?? []) {
      const leaderRole = text(p.role_name, "principal").toLowerCase();
      const key = `${leaderRole}:${p.id}:${text(context.student_id)}`;
      if (!addedKeys.has(key)) {
        addedKeys.add(key);
        contacts.push({
          id: p.id,
          name: p.name || p.username ||
            (leaderRole === "coordinator" ? "Coordinator" : "Principal"),
          role: leaderRole,
          ...context,
          type: "principal_parent",
        });
      }
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

  const assignedSectionIds = await lessonPlannerAssignedSectionIds(
    svc,
    school,
    staffId,
  );
  const sectionsQuery = svc.from("sections")
    .select(
      "id, section_name, grade:grades(grade_name), class_teacher:staff!sections_class_teacher_id_fkey(*), co_teacher:staff!sections_co_teacher_id_fkey(*)",
    )
    .eq("school_id", school);
  const { data: sections } = assignedSectionIds.size
    ? await sectionsQuery.in("id", [...assignedSectionIds])
    : { data: [] };

  const contacts: any[] = [];
  const addedKeys = new Set<string>();

  for (const section of sections ?? []) {
    const { data: students } = await svc.from("students")
      .select("id, first_name, last_name, current_section_id")
      .eq("current_section_id", section.id)
      .eq("school_id", school);

    for (const student of students ?? []) {
      const studentName = [student.first_name, student.last_name].filter(
        Boolean,
      ).join(" ");
      const context = chatContext(
        student as Record<string, unknown>,
        section as Record<string, unknown>,
      );
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
            ...context,
            contact_role: "student_parent",
            type: "parent_teacher",
          });
        }
      }
    }
  }

  // Add every school leader so teachers can reach both Principals and Coordinators.
  const { data: principals } = await svc.from("users")
    .select("id, name, username, role_name")
    .eq("school_id", school)
    .in("role_name", ["principal", "coordinator"]);

  for (const p of principals ?? []) {
    const leaderRole = text(p.role_name, "principal").toLowerCase();
    const key = `${leaderRole}:${p.id}`;
    if (!addedKeys.has(key)) {
      addedKeys.add(key);
      contacts.push({
        id: p.id,
        name: p.name || p.username ||
          (leaderRole === "coordinator" ? "Coordinator" : "Principal"),
        role: leaderRole,
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

  const { data: sections } = await svc.from("sections").select(
    "id, section_name, grade:grades(grade_name), class_teacher_id, co_teacher_id",
  ).eq("school_id", school);
  const labelsBySection = new Map<string, string>();
  const labelsByStaff = new Map<string, string[]>();
  for (const section of sections ?? []) {
    const label = [
      text((section as any).grade?.grade_name),
      text(section.section_name),
    ]
      .filter(Boolean).join(" - ");
    labelsBySection.set(text(section.id), label);
    for (const staffId of [section.class_teacher_id, section.co_teacher_id]) {
      const id = text(staffId);
      if (id && label) {
        labelsByStaff.set(id, [...(labelsByStaff.get(id) ?? []), label]);
      }
    }
  }
  const { data: staffSubjects } = await svc.from("staff_subjects")
    .select("staff_id, section_id").eq("school_id", school);
  for (const assignment of staffSubjects ?? []) {
    const staffId = text(assignment.staff_id);
    const label = labelsBySection.get(text(assignment.section_id)) ?? "";
    if (staffId && label) {
      labelsByStaff.set(
        staffId,
        [...(labelsByStaff.get(staffId) ?? []), label],
      );
    }
  }

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
        class_sections: uniqueText(labelsByStaff.get(text(s.id)) ?? []),
      });
    }
  }

  const { data: parents } = await svc.from("users")
    .select("id, name, username")
    .eq("school_id", school)
    .ilike("role_name", "parent");

  const { data: links } = await svc.from("parent_student_links").select(
    "parent_user_id, student:students(id, first_name, last_name, current_section_id)",
  ).eq("school_id", school);
  const parentIds = new Set((parents ?? []).map((parent) => text(parent.id)));
  const studentsBySection = new Map<string, Record<string, unknown>>();
  const sectionIds = uniqueText((links ?? []).map((link: any) =>
    link.student?.current_section_id
  ));
  if (sectionIds.length > 0) {
    const { data: linkedSections } = await svc.from("sections")
      .select("id, section_name, grade:grades(grade_name)")
      .eq("school_id", school)
      .in("id", sectionIds);
    for (const section of linkedSections ?? []) {
      const sectionId = text(section.id);
      if (sectionId) studentsBySection.set(sectionId, section);
    }
  }

  for (const link of links ?? []) {
    const parentId = text(link.parent_user_id);
    const student = (link as any).student as Record<string, unknown> | null;
    const studentId = text(student?.id);
    if (!parentId || !studentId || !parentIds.has(parentId)) continue;
    const section = studentsBySection.get(text(student?.current_section_id));
    const parent = (parents ?? []).find((row) => text(row.id) === parentId);
    const context = chatContext(student, section);
    contacts.push({
      id: parentId,
      name: parent?.name || parent?.username || "Parent",
      role: "parent",
      type: "principal_parent",
      contact_role: "student_parent",
      ...context,
      class_sections: context.class_label ? [context.class_label] : [],
    });
  }

  return contacts;
}

async function getTeacherAllowedConversationsStaffIds(
  _svc: SupabaseClient,
  _school: string,
  staffId: string,
): Promise<string[]> {
  return staffId ? [staffId] : [];
}

async function parentIsLinkedToStudent(
  svc: SupabaseClient,
  school: string,
  parentId: string,
  studentId: string,
) {
  if (!parentId || !studentId) return false;
  const { data } = await svc.from("parent_student_links").select("id")
    .eq("school_id", school)
    .eq("parent_user_id", parentId)
    .eq("student_id", studentId)
    .maybeSingle();
  return Boolean(data?.id);
}

async function teacherIsAssignedToStudent(
  svc: SupabaseClient,
  school: string,
  staffId: string,
  studentId: string,
) {
  return teacherCanAccessStudent(svc, school, staffId, studentId);
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
    return text(conversation.parent_id) === user.id &&
      await parentIsLinkedToStudent(
        svc,
        school,
        user.id,
        text(conversation.student_id),
      );
  }
  if (userRole === "teacher") {
    const staffId = linkedStaffId(user);
    if (!staffId) return false;
    const convTeacherId = text(conversation.teacher_id);
    if (convTeacherId !== staffId) return false;
    const studentId = text(conversation.student_id);
    return !studentId || await teacherIsAssignedToStudent(
      svc,
      school,
      staffId,
      studentId,
    );
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
    return await canReadChatConversation(svc, school, conversation, user);
  }
  if (canManageSchoolContent(user)) {
    return text(conversation.leader_id ?? conversation.created_by) === user.id;
  }
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
  const createdBy = text(conversation.leader_id ?? conversation.created_by);
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
  const leaderIds = uniqueText(rows.map((row) => row.leader_id));
  const teachersById = new Map<string, Record<string, unknown>>();
  const parentsById = new Map<string, Record<string, unknown>>();
  const studentsById = new Map<string, Record<string, unknown>>();
  const leadersById = new Map<string, Record<string, unknown>>();
  const sectionsById = new Map<string, Record<string, unknown>>();

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
  const sectionIds = uniqueText([
    ...rows.map((row) => row.section_id),
    ...[...studentsById.values()].map((student) => student.current_section_id),
  ]);
  if (sectionIds.length) {
    const { data } = await svc.from("sections")
      .select("id, section_name, grade:grades(grade_name)")
      .eq("school_id", school)
      .in("id", sectionIds);
    for (const row of data ?? []) sectionsById.set(`${row.id}`, row);
  }
  if (leaderIds.length) {
    const { data } = await svc.from("users")
      .select("id, name, username, role_name")
      .eq("school_id", school)
      .in("id", leaderIds);
    for (const row of data ?? []) leadersById.set(`${row.id}`, row);
  }

  return rows.map((row) => {
    const student = studentsById.get(`${row.student_id ?? ""}`) ?? null;
    const section = sectionsById.get(
      `${row.section_id ?? student?.current_section_id ?? ""}`,
    ) ?? null;
    const context = chatContext(student, section);
    return {
      ...row,
      ...context,
      teacher: teachersById.get(`${row.teacher_id ?? ""}`) ?? null,
      parent: parentsById.get(`${row.parent_id ?? ""}`) ?? null,
      student,
      leader: leadersById.get(`${row.leader_id ?? ""}`) ?? null,
    };
  });
}

async function appendNotification(
  svc: SupabaseClient,
  school: string,
  userId: string,
  title: string,
  body: string,
  entityId: string,
  targetRole = "all",
  route = "/communication-center-screen",
  context: Record<string, string> = {},
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
    route,
    priority: "medium",
    is_read: false,
  });
  // Also create a push notification event so the processor sends an FCM message
  try {
    const { data } = await svc.from("notification_events").insert({
      school_id: school,
      user_id: userId,
      event_type: "message",
      event_data: {
        title,
        message: body,
        reference_type: "message",
        reference_id: entityId,
        route,
        ...context,
      },
    }).select("id").maybeSingle();
    if (data?.id) triggerPushProcessing(data.id);
  } catch (_) { /* best-effort */ }
}

function chatRouteForRole(targetRole: string) {
  return targetRole === "parent"
    ? "/parent-teacher-chat-screen"
    : targetRole === "teacher"
    ? "/teacher-communication-screen"
    : "/communication-center-screen";
}

async function chatConversationContext(
  svc: SupabaseClient,
  school: string,
  conversation: Record<string, unknown>,
) {
  const studentId = text(conversation.student_id);
  if (!studentId) {
    return { student_id: "", section_id: "", student_name: "", class_label: "" };
  }
  const { data: student } = await svc.from("students")
    .select("id, first_name, last_name, current_section_id")
    .eq("id", studentId)
    .eq("school_id", school)
    .maybeSingle();
  if (!student) {
    return { student_id: studentId, section_id: "", student_name: "", class_label: "" };
  }
  const { data: section } = await svc.from("sections")
    .select("id, section_name, grade:grades(grade_name)")
    .eq("id", student.current_section_id)
    .eq("school_id", school)
    .maybeSingle();
  const context = chatContext(
    student as Record<string, unknown>,
    section as Record<string, unknown> | null,
  );
  return context;
}

async function chatNotificationTargets(
  svc: SupabaseClient,
  school: string,
  conversation: Record<string, unknown>,
  user: User,
) {
  const type = text(conversation.type) || "parent_teacher";
  if (type !== "parent_teacher") {
    const target = await resolveChatNotificationTarget(
      svc,
      school,
      conversation,
      user,
    );
    if (!target) return [];
    const teacherUserId = await teacherUserIdForStaff(
      svc,
      school,
      text(conversation.teacher_id),
    );
    const targetRole = target === text(conversation.parent_id)
      ? "parent"
      : target === teacherUserId
      ? "teacher"
      : "all";
    return [{ id: target, role: targetRole }];
  }

  const parentId = text(conversation.parent_id);
  const teacherUserId = await teacherUserIdForStaff(
    svc,
    school,
    text(conversation.teacher_id),
  );
  const targets: { id: string; role: string }[] = [];
  if (canManageSchoolContent(user)) {
    if (parentId && parentId !== user.id) {
      targets.push({ id: parentId, role: "parent" });
    }
    if (teacherUserId && teacherUserId !== user.id) {
      targets.push({ id: teacherUserId, role: "teacher" });
    }
    return targets;
  }
  if (parentId && parentId !== user.id) {
    targets.push({ id: parentId, role: "parent" });
  } else if (teacherUserId && teacherUserId !== user.id) {
    targets.push({ id: teacherUserId, role: "teacher" });
  }
  return targets;
}

/**
 * Fan out a push + in-app notification to every active user in a school
 * whose role matches `audience` (or everyone, when audience is "all").
 * Best-effort: the announcement itself is already persisted by the caller,
 * so a notification failure here must never fail the request.
 */
async function notifyAnnouncementAudience(
  svc: SupabaseClient,
  school: string,
  audience: string,
  title: string,
  message: string,
  announcementId: string,
): Promise<void> {
  try {
    const normalized = `${audience || "all"}`.trim().toLowerCase();
    let query = svc.from("users").select("id").eq("school_id", school).eq(
      "is_active",
      true,
    );
    if (normalized && normalized !== "all" && normalized !== "everyone") {
      query = query.eq("role_name", normalized);
    }
    const { data: recipients, error } = await query;
    if (error || !recipients || recipients.length === 0) return;
    const rows = recipients
      .map((row: Record<string, unknown>) => `${row.id ?? ""}`.trim())
      .filter(Boolean)
      .map((userId) => ({
        school_id: school,
        user_id: userId,
        target_role: normalized,
        title,
        body: message,
        type: "announcement",
        entity_type: "announcement",
        entity_id: announcementId,
        route: "/notification-center-screen",
        priority: "medium",
        is_read: false,
      }));
    if (rows.length === 0) return;
    await svc.from("notification_logs").insert(rows);
    const { data: events, error: eventError } = await svc
      .from("notification_events")
      .insert(
        rows.map((row) => ({
          school_id: row.school_id,
          user_id: row.user_id,
          event_type: "announcement",
          event_data: {
            title: row.title,
            message: row.body,
            announcement_id: announcementId,
            reference_type: "announcement",
          },
        })),
      )
      .select("id");
    if (eventError) return;
    const eventIds = (events ?? [])
      .map((row: { id: string }) => `${row.id ?? ""}`.trim())
      .filter(Boolean);
    if (eventIds.length > 0) triggerPushProcessing(eventIds);
  } catch (_) {
    // Best-effort: announcement is already saved even if notification fan-out fails.
  }
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

function canonicalLessonPlannerAttachments(
  attachments: Array<Record<string, unknown>>,
) {
  return attachments.map((attachment) => ({
    ...attachment,
    url: stableStorageReference(attachment.url),
  }));
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

async function materializeLessonPlannerRow(
  svc: SupabaseClient,
  row: Record<string, unknown>,
) {
  const normalized = normalizeLessonPlannerRow(row);
  const attachments = await Promise.all(
    (normalized.attachments as Array<Record<string, unknown>>).map(
      async (attachment) => ({
        ...attachment,
        url: await signedPrivateFileUrl(svc, attachment.url) ||
          text(attachment.url),
      }),
    ),
  );
  return {
    ...normalized,
    attachments,
    attachment_url: firstLessonPlannerAttachmentUrl(attachments),
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

  return await Promise.all(rows.map(async (row) => {
    const payload = lessonPlannerPayload(row);
    const section = sectionsById.get(
      text(payload.section_id ?? row.section_id),
    );
    const teacher = staffById.get(text(payload.staff_id ?? row.staff_id));
    return await materializeLessonPlannerRow(svc, {
      ...row,
      ...(section ? { section } : {}),
      ...(teacher ? { teacher } : {}),
    });
  }));
}

async function autoCompleteEndedLessonPlanners(
  svc: SupabaseClient,
  school: string,
  rows: Array<Record<string, unknown>>,
) {
  const today = new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Kolkata",
  });
  for (const row of rows) {
    const payload = lessonPlannerPayload(row);
    const status = text(payload.status, "uploaded").toLowerCase();
    const weekEnd = text(payload.week_end_date).slice(0, 10);
    if (status !== "uploaded" || !weekEnd || weekEnd >= today) continue;
    const completedAt = new Date().toISOString();
    const next = { ...payload, status: "completed", completed_at: completedAt };
    const { error } = await svc.from("frontend_records").update({
      data: next,
      updated_at: completedAt,
    }).eq("id", row.id).eq("school_id", school);
    if (error) throw new Error(error.message);
    row.data = next;
    row.updated_at = completedAt;
  }
  return rows;
}

async function lessonPlannerAssignedSectionIds(
  svc: SupabaseClient,
  school: string,
  teacherId: string,
) {
  const scope = await resolveActiveTeacherScope(svc, school, teacherId);
  return new Set(scope.sections.keys());
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

  const studentIds = (links ?? []).map((l: any) => l.student_id).filter(
    Boolean,
  );

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

  // The old generic communications and message endpoints were only used by a
  // disconnected Flutter screen.  Keep a clear failure here so an outdated
  // client cannot silently create a second chat system alongside /chat.
  if (
    path === "/communications" || path === "/message-conversations" ||
    path === "/messages" || path.startsWith("/messages/")
  ) {
    return fail("legacy communication endpoint retired; use /chat", 410);
  }

  // ── Unified WhatsApp-style chat ────────────────────────────
  if (path === "/chat/contacts" && method === "GET") {
    const roleParam = text(url.searchParams.get("role")).toLowerCase();
    const studentId = text(url.searchParams.get("student_id"));
    if (roleParam !== role(user)) {
      return fail("role does not match session", 403);
    }
    if (roleParam === "parent") {
      const contacts = await parentChatContacts(svc, school, user, studentId);
      return ok(contacts);
    } else if (roleParam === "teacher") {
      const contacts = await teacherChatContacts(svc, school, user);
      return ok(contacts);
    } else if (
      ["principal", "coordinator"].includes(roleParam) &&
      canManageSchoolContent(user) && roleParam === role(user)
    ) {
      const contacts = await principalChatContacts(svc, school);
      return ok(contacts);
    }
    return fail("invalid role param");
  }

  if (path === "/chat/conversations" && method === "GET") {
    const page = Math.max(parseInt(url.searchParams.get("page") ?? "1") || 1, 1);
    const pageSize = Math.min(
      Math.max(parseInt(url.searchParams.get("page_size") ?? "20") || 20, 1),
      100,
    );
    let q = svc.from("message_conversations").select("*", { count: "exact" }).eq(
      "school_id",
      school,
    );
    const type = text(url.searchParams.get("type"));
    const teacherId = text(url.searchParams.get("teacher_id"));
    const parentId = text(url.searchParams.get("parent_id"));
    const studentId = text(url.searchParams.get("student_id"));
    const search = text(url.searchParams.get("search"));
    const requestedMonitor = text(url.searchParams.get("monitor")) == "true";
    const userRole = role(user);
    if (type) q = q.eq("type", type);
    if (teacherId) q = q.eq("teacher_id", teacherId);
    if (parentId) q = q.eq("parent_id", parentId);
    if (studentId) q = q.eq("student_id", studentId);
    if (search) {
      const escaped = search.replace(/[%(),]/g, " ").trim();
      if (escaped) {
        q = q.or(
          `title.ilike.%${escaped}%,last_message.ilike.%${escaped}%,class_label.ilike.%${escaped}%`,
        );
      }
    }
    if (!canManageSchoolContent(user) || !requestedMonitor) {
      if (userRole == "teacher") {
        const teacher = linkedStaffId(user);
        if (!teacher) return ok([]);
        q = q.eq("teacher_id", teacher);
      } else if (userRole == "parent") {
        q = q.eq("parent_id", user.id);
      } else {
        return fail("forbidden", 403);
      }
    }
    const { data, error, count } = await q.order("updated_at", {
      ascending: false,
    }).order("id", { ascending: false }).range(
      (page - 1) * pageSize,
      page * pageSize - 1,
    );
    if (error) return fail(error.message);
    let visible = data ?? [];
    if (userRole === "teacher" && !canManageSchoolContent(user)) {
      const scope = await resolveActiveTeacherScope(
        svc,
        school,
        linkedStaffId(user),
      );
      if (!scope.isActive) return ok([]);
      const studentIds = uniqueText(visible.map((row) => row.student_id));
      const { data: students, error: studentError } = studentIds.length
        ? await svc.from("students").select("id, current_section_id").eq(
          "school_id",
          school,
        ).in("id", studentIds)
        : { data: [], error: null };
      if (studentError) return fail(studentError.message);
      const sectionByStudent = new Map(
        (students ?? []).map((student) => [
          text(student.id),
          text(student.current_section_id),
        ]),
      );
      visible = visible.filter((conversation) => {
        const studentId = text(conversation.student_id);
        return !studentId || scope.sections.has(
          sectionByStudent.get(studentId) ?? "",
        );
      });
    } else if (userRole === "parent" && !canManageSchoolContent(user)) {
      const { data: links, error: linkError } = await svc.from(
        "parent_student_links",
      ).select("student_id").eq("school_id", school).eq(
        "parent_user_id",
        user.id,
      );
      if (linkError) return fail(linkError.message);
      const linkedStudents = new Set(uniqueText((links ?? []).map((link) => link.student_id)));
      visible = visible.filter((conversation) =>
        linkedStudents.has(text(conversation.student_id))
      );
    }
    const rows = await enrichChatConversations(svc, school, visible) as Record<string, unknown>[];
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
    const normalizedRows = rows.map((row) =>
      normalizeChatConversation({
        ...row,
        unread_count: unreadByConversation.get(text(row["id"])) ?? 0,
      }, user.id)
    );
    const total = count ?? normalizedRows.length;
    return ok({
      data: normalizedRows,
      total,
      page,
      page_size: pageSize,
      has_more: page * pageSize < total,
    });
  }

  if (path === "/chat/conversations" && method === "POST") {
    const conversationType = text(body.type) || "parent_teacher";
    const sessionRole = role(user);
    let teacherId = text(body.teacher_id);
    let parentId = text(body.parent_id);
    if (sessionRole === "teacher") {
      teacherId = linkedStaffId(user);
      if (!teacherId) return fail("staff profile not linked", 403);
    }
    if (sessionRole === "parent") parentId = user.id;
    const studentId = text(body.student_id);
    const requestedLeaderId = text(body.leader_id);
    const isLeadershipUser = canManageSchoolContent(user);

    if (
      conversationType !== "parent_teacher" && !isLeadershipUser &&
      !(
        conversationType === "principal_parent" &&
        role(user) === "parent" && parentId === user.id
      ) &&
      !(
        conversationType === "principal_teacher" &&
        role(user) === "teacher" && teacherId === linkedStaffId(user)
      )
    ) {
      return fail("school leadership access required", 403);
    }

    let conversationLeaderId = "";
    if (conversationType !== "parent_teacher") {
      conversationLeaderId = isLeadershipUser ? user.id : requestedLeaderId;
      if (!await isSchoolLeaderId(svc, school, conversationLeaderId)) {
        return fail("a principal or coordinator leader is required", 403);
      }
    }

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
    const context = await chatConversationContext(svc, school, {
      student_id: studentId,
    });
    let existing = svc.from("message_conversations").select("*")
      .eq("school_id", school)
      .eq("type", conversationType);
    if (teacherId) existing = existing.eq("teacher_id", teacherId);
    if (parentId) existing = existing.eq("parent_id", parentId);
    if (studentId) {
      existing = existing.eq("student_id", studentId);
    }
    if (conversationType !== "parent_teacher") {
      existing = existing.eq("leader_id", conversationLeaderId);
    }
    if (conversationType === "principal_parent" && studentId) {
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
      section_id: text(context.section_id) || null,
      class_label: text(context.class_label) || null,
      participant_ids: [teacherId, parentId].filter(Boolean),
      leader_id: conversationType === "parent_teacher"
        ? null
        : conversationLeaderId,
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
    const page = Math.max(parseInt(url.searchParams.get("page") ?? "1") || 1, 1);
    const pageSize = Math.min(
      Math.max(parseInt(url.searchParams.get("page_size") ?? "20") || 20, 1),
      100,
    );
    let q = svc.from("messages").select("*", { count: "exact" }).eq("school_id", school)
      .eq("conversation_id", conversationId);
    const sentAfter = text(url.searchParams.get("sent_after"));
    if (sentAfter) q = q.gt("sent_at", sentAfter);
    const { data, error, count } = await q.order("sent_at", {
      ascending: true,
    }).order("id", { ascending: true }).range(
      (page - 1) * pageSize,
      page * pageSize - 1,
    );
    if (error) return fail(error.message);
    const rows = (data ?? []).map((row) => normalizeChatMessage({
      ...row,
      student_id: conversation.student_id ?? "",
      student_name: conversation.student_name ?? "",
      class_label: conversation.class_label ?? "",
    }, user.id));
    const total = count ?? rows.length;
    return ok({
      data: rows,
      total,
      page,
      page_size: pageSize,
      has_more: page * pageSize < total,
    });
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
    const { data: senderProfile } = await svc.from("users")
      .select("name, username, email")
      .eq("school_id", school)
      .eq("id", user.id)
      .maybeSingle();
    const senderName = text(
      senderProfile?.name ?? senderProfile?.username ??
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
      const context = await chatConversationContext(svc, school, conversation);
      const contextPrefix = [context.class_label, context.student_name]
        .filter(Boolean)
        .join(" - ");
      const notificationBody = contextPrefix
        ? `${contextPrefix}: ${messageText}`
        : messageText;
      const targets = await chatNotificationTargets(
        svc,
        school,
        conversation,
        user,
      );
      for (const target of targets) {
        if (!target.id || target.id === user.id) continue;
        await appendNotification(
          svc,
          school,
          target.id,
          type == "parent_teacher"
            ? canManageSchoolContent(user)
              ? "School leader replied"
              : "New parent-teacher message"
            : "New message",
          notificationBody,
          conversationId,
          target.role,
          chatRouteForRole(target.role),
          {
            student_id: text(context.student_id),
            section_id: text(context.section_id),
            student_name: text(context.student_name),
            class_label: text(context.class_label),
          },
        );
      }
      if (type == "parent_teacher" && !canManageSchoolContent(user)) {
        const principalIds = await principalUserIdsForSchool(svc, school);
        for (const principalId of principalIds) {
          if (principalId == user.id || targets.some((target) => target.id === principalId)) continue;
          await appendNotification(
            svc,
            school,
            principalId,
            "Parent-teacher chat updated",
            notificationBody,
            conversationId,
            "all",
            chatRouteForRole("all"),
            {
              student_id: text(context.student_id),
              section_id: text(context.section_id),
              student_name: text(context.student_name),
              class_label: text(context.class_label),
            },
          );
        }
      }
    }
    const responseContext = await chatConversationContext(
      svc,
      school,
      conversation,
    );
    return ok(normalizeChatMessage({
      ...message,
      ...responseContext,
    }, user.id));
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
    // Single bulk UPDATE instead of an N+1 per-message loop.
    const { error } = await svc.rpc("mark_conversation_read", {
      p_conversation_id: conversationId,
      p_school_id: school,
      p_user_id: user.id,
    });
    if (error) return fail(error.message);
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
      const page = Math.max(parseInt(url.searchParams.get("page") ?? "1") || 1, 1);
      const pageSize = Math.min(
        Math.max(parseInt(url.searchParams.get("page_size") ?? "20") || 20, 1),
        100,
      );
      let q = svc.from("announcements").select("*", { count: "exact" }).eq(
        "school_id",
        school,
      );
      if (!canManageSchoolContent(user)) {
        const audience = role(user);
        if (!audience) return fail("forbidden", 403);
        q = q.in("audience", ["all", "everyone", audience]).eq(
          "status",
          "published",
        );
      }
      if (url.searchParams.get("status")) {
        q = q.eq("status", url.searchParams.get("status")!);
      }
      if (url.searchParams.get("audience")) {
        q = q.eq("audience", url.searchParams.get("audience")!);
      }
      const search = text(url.searchParams.get("search"));
      if (search) {
        const escaped = search.replace(/[%(),]/g, " ").trim();
        if (escaped) q = q.or(`title.ilike.%${escaped}%,body.ilike.%${escaped}%`);
      }
      const { data, error, count } = await q.order("created_at", {
        ascending: false,
      }).order("id", { ascending: false }).range(
        (page - 1) * pageSize,
        page * pageSize - 1,
      );
      if (error) return fail(error.message);
      return ok({
        data: data ?? [],
        total: count ?? data?.length ?? 0,
        page,
        page_size: pageSize,
        has_more: page * pageSize < (count ?? 0),
      });
    }
    if (!seg && method === "POST") {
      if (!canManageSchoolContent(user)) return fail("forbidden", 403);
      const payload = normalizeAnnouncementPayload(
        school,
        user,
        body as Record<string, unknown>,
      );
      const { data, error } = await svc.from("announcements").insert(payload)
        .select().single();
      if (error) return fail(error.message);
      if (payload.status === "published") {
        await notifyAnnouncementAudience(
          svc,
          school,
          payload.audience,
          payload.title || "New Announcement",
          payload.body,
          `${data?.id ?? ""}`,
        );
      }
      return ok(data);
    }
    if (seg && method === "PATCH") {
      if (!canManageSchoolContent(user)) return fail("forbidden", 403);
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
      if (!canManageSchoolContent(user)) return fail("forbidden", 403);
      const { error } = await svc.from("announcements").delete().eq("id", seg).eq(
        "school_id",
        school,
      );
      if (error) return fail(error.message);
      return ok({ success: true });
    }
  }

  // ── Notices (announcement alias for existing Flutter screens) ───────────
  if (path.startsWith("/notices")) {
    const seg = path.slice("/notices".length).split("/").filter(Boolean)[0];
    if (!seg && method === "GET") {
      const page = Math.max(parseInt(url.searchParams.get("page") ?? "1") || 1, 1);
      const pageSize = Math.min(
        Math.max(parseInt(url.searchParams.get("page_size") ?? "20") || 20, 1),
        100,
      );
      let q = svc.from("announcements").select("*", { count: "exact" }).eq(
        "school_id",
        school,
      );
      if (!canManageSchoolContent(user)) {
        const audience = role(user);
        if (!audience) return fail("forbidden", 403);
        q = q.in("audience", ["all", "everyone", audience]).eq(
          "status",
          "published",
        );
      }
      if (url.searchParams.get("target_role")) {
        q = q.eq("audience", url.searchParams.get("target_role")!);
      }
      if (url.searchParams.get("status")) {
        q = q.eq("status", url.searchParams.get("status")!);
      }
      const search = text(url.searchParams.get("search"));
      if (search) {
        const escaped = search.replace(/[%(),]/g, " ").trim();
        if (escaped) q = q.or(`title.ilike.%${escaped}%,body.ilike.%${escaped}%`);
      }
      const { data, error, count } = await q.order("created_at", {
        ascending: false,
      }).order("id", { ascending: false }).range(
        (page - 1) * pageSize,
        page * pageSize - 1,
      );
      if (error) return fail(error.message);
      return ok({
        data: data ?? [],
        total: count ?? data?.length ?? 0,
        page,
        page_size: pageSize,
        has_more: page * pageSize < (count ?? 0),
      });
    }
    if (!seg && method === "POST") {
      if (!canManageSchoolContent(user)) return fail("forbidden", 403);
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
      if (payload.status === "published") {
        await notifyAnnouncementAudience(
          svc,
          school,
          `${payload.audience}`,
          `${payload.title || "New Announcement"}`,
          `${payload.body}`,
          `${data?.id ?? ""}`,
        );
      }
      return ok(data);
    }
  }

  // ── Notifications ─────────────────────────────────────────
  if (path === "/notifications" && method === "GET") {
    const page = Math.max(parseInt(url.searchParams.get("page") ?? "1") || 1, 1);
    const pageSize = Math.min(
      Math.max(parseInt(url.searchParams.get("page_size") ?? "20") || 20, 1),
      100,
    );
    const from = (page - 1) * pageSize;
    // Read one extra row so an exact page multiple does not create a phantom
    // empty page at the end of the notification history.
    const to = from + pageSize;
    let notificationQuery = svc.from("notification_logs")
      .select("*, student:students(photo_url)", { count: "exact" })
      .eq("school_id", school)
      .eq("user_id", user.id)
      .is("deleted_at", null)
      .order("created_at", { ascending: false });
    if (role(user) === "parent") {
      const { data: links, error: linksError } = await svc
        .from("parent_student_links")
        .select("student_id")
        .eq("school_id", school)
        .eq("parent_user_id", user.id);
      if (linksError) return fail(linksError.message);
      const linkedStudentIds = (links ?? []).map((link) => text(link.student_id))
        .filter(Boolean);
      notificationQuery = linkedStudentIds.length === 0
        ? notificationQuery.is("student_id", null)
        : notificationQuery.or(
          `student_id.is.null,student_id.in.(${linkedStudentIds.join(",")})`,
        );
    }
    const { data, error, count } = await notificationQuery.range(from, to);
    if (error) return fail(error.message);
    const rows = (data ?? []).slice(0, pageSize);
    const items = rows.map((row: Record<string, unknown>) => ({
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
      student_photo_url: (row.student as Record<string, unknown> | null)
        ?.photo_url ?? "",
      sent_at: row.created_at ?? null,
    }));
    return ok({
      items,
      total: count ?? 0,
      page,
      page_size: pageSize,
      has_more: page * pageSize < (count ?? 0),
    });
  }
  if (path === "/notifications/push-diagnostics" && method === "POST") {
    return runPushDiagnostics(svc, user, school);
  }
  if (path === "/notifications" && method === "POST") {
    const { data, error } = await svc.from("notification_logs").insert({
      school_id: school,
      // A signed-in client may create a local log entry for itself, never for
      // another user. Server-side fanout handlers write recipient rows with
      // the service client instead.
      user_id: user.id,
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
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const requestedRole = `${body.target_role ?? ""}`.trim().toLowerCase();
    const targetRole = [
      "principal",
      "coordinator",
      "teacher",
      "parent",
      "student",
      "admin",
      "super_admin",
    ].includes(requestedRole)
      ? requestedRole
      : "";
    let update = svc.from("notification_logs").update({ is_read: true })
      .eq("user_id", user.id)
      .is("deleted_at", null);
    if (targetRole) {
      update = update.or(
        `target_role.is.null,target_role.eq.all,target_role.eq.${targetRole}`,
      );
    }
    const { error } = await update;
    if (error) return fail(error.message);
    return ok({ success: true });
  }
  const notificationReadMatch = path.match(/^\/notifications\/([^/]+)\/read$/);
  if (notificationReadMatch && (method === "POST" || method === "PUT")) {
    const { data, error } = await svc.from("notification_logs").update({
      is_read: true,
    }).eq("id", notificationReadMatch[1]).eq("user_id", user.id)
      .is("deleted_at", null).select()
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
  const notificationDeleteMatch = path.match(/^\/notifications\/([^/]+)$/);
  if (notificationDeleteMatch && method === "DELETE") {
    const { data, error } = await svc.from("notification_logs").update({
      deleted_at: new Date().toISOString(),
    }).eq("id", notificationDeleteMatch[1]).eq("user_id", user.id)
      .is("deleted_at", null).select("id").maybeSingle();
    if (error) return fail(error.message);
    if (!data) return fail("notification not found", 404);
    return ok({ deleted: true, id: data.id });
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
    const visible = [];
    for (const row of data ?? []) {
      if (await canReadChatConversation(svc, school, row, user)) {
        visible.push(row);
      }
    }
    return ok(await enrichChatConversations(svc, school, visible));
  }
  if (path === "/message-conversations" && method === "POST") {
    const conversationType = text(body.type) || "parent_teacher";
    let teacherId = text(body.teacher_id);
    let parentId = text(body.parent_id);
    const currentRole = role(user);
    if (currentRole === "teacher") teacherId = linkedStaffId(user);
    if (currentRole === "parent") parentId = user.id;
    const studentId = text(body.student_id);
    const isLeader = canManageSchoolContent(user);
    if (conversationType !== "parent_teacher" && !isLeader) {
      return fail("school leadership access required", 403);
    }
    if (conversationType !== "parent_teacher" && isLeader) {
      body.leader_id = user.id;
    }
    const scopeError = await validateChatConversationScope(
      svc,
      school,
      conversationType,
      teacherId,
      parentId,
      studentId,
    );
    if (scopeError) return fail(scopeError, 403);
    const context = await chatConversationContext(svc, school, {
      student_id: studentId,
    });
    const { data, error } = await svc.from("message_conversations").insert({
      school_id: school,
      title: body.title ?? null,
      student_id: studentId || null,
      section_id: text(context.section_id) || null,
      class_label: text(context.class_label) || null,
      participant_ids: body.participant_ids ?? [],
      type: conversationType,
      teacher_id: teacherId || null,
      parent_id: parentId || null,
      leader_id: conversationType === "parent_teacher" ? null : user.id,
      created_by: user.id,
      last_message: body.last_message ?? "",
      last_message_at: body.last_message_time ?? new Date().toISOString(),
    }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  if (path === "/messages" && method === "GET") {
    const conversationId = text(url.searchParams.get("conversation_id"));
    if (!conversationId) return fail("conversation_id is required", 400);
    const { data: conversation, error: conversationError } = await svc.from(
      "message_conversations",
    ).select("*").eq("school_id", school).eq("id", conversationId)
      .maybeSingle();
    if (conversationError) return fail(conversationError.message);
    if (!conversation) return fail("conversation not found", 404);
    if (!await canReadChatConversation(svc, school, conversation, user)) {
      return fail("forbidden", 403);
    }
    let q = svc.from("messages").select("*, sender:users(name, role_name)").eq(
      "school_id",
      school,
    ).eq("conversation_id", conversationId);
    const { data, error } = await q.order("created_at", { ascending: true });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }
  if (path === "/messages" && method === "POST") {
    const { conversation_id, message_body, attachments } = body;
    let convId = conversation_id;
    if (!convId) return fail("conversation_id is required", 400);
    const { data: conversation, error: conversationError } = await svc.from(
      "message_conversations",
    ).select("*").eq("school_id", school).eq("id", convId).maybeSingle();
    if (conversationError) return fail(conversationError.message);
    if (!conversation) return fail("conversation not found", 404);
    if (!await canSendChatMessage(svc, school, conversation, user)) {
      return fail("forbidden", 403);
    }
    const sentAt = text(body.sent_at) || new Date().toISOString();
    const messageText = text(body.body ?? body.message ?? message_body);
    const { data, error } = await svc.from("messages").insert({
      school_id: school,
      conversation_id: convId,
      sender_id: body.sender_id ?? user.id,
      sender_role: role(user) || text(body.sender_role) || "user",
      sender_name: body.sender_name ?? user.user_metadata?.name ?? user.email,
      body: messageText,
      attachments: attachments ?? null,
      read_by: body.is_read == true ? [user.id] : null,
      sent_at: sentAt,
      delivered_at: sentAt,
    }).select().single();
    if (error) return fail(error.message);
    await svc.from("message_conversations").update({
      last_message: messageText,
      last_message_at: sentAt,
      last_sender_id: user.id,
      updated_at: sentAt,
    }).eq("id", convId).eq("school_id", school);
    const context = await chatConversationContext(svc, school, conversation);
    const notificationBody = [context.class_label, context.student_name]
      .filter(Boolean).join(" - ");
    const targetUserId = await resolveChatNotificationTarget(
      svc,
      school,
      conversation,
      user,
    );
    if (targetUserId && targetUserId !== user.id) {
      const targetRole = targetUserId === text(conversation.parent_id)
        ? "parent"
        : "teacher";
      const notificationTitle = conversation.type === "homework"
        ? "New homework message"
        : "New chat message";
      await appendNotification(
        svc,
        school,
        targetUserId,
        notificationTitle,
        notificationBody ? `${notificationBody}: ${messageText}` : messageText,
        text(convId),
        targetRole,
        chatRouteForRole(targetRole),
        {
          student_id: text(context.student_id),
          section_id: text(context.section_id),
          student_name: text(context.student_name),
          class_label: text(context.class_label),
        },
      );
    }
    return ok(data);
  }
  const messageMatch = path.match(/^\/messages\/([^/]+)$/);
  if (messageMatch && method === "PUT") {
    const { data: existingMessage, error: existingError } = await svc.from(
      "messages",
    ).select("id, conversation_id, read_by").eq("id", messageMatch[1])
      .eq("school_id", school).maybeSingle();
    if (existingError) return fail(existingError.message);
    if (!existingMessage) return fail("message not found", 404);
    const { data: conversation } = await svc.from("message_conversations")
      .select("*").eq("id", existingMessage.conversation_id)
      .eq("school_id", school).maybeSingle();
    if (!conversation || !await canReadChatConversation(svc, school, conversation, user)) {
      return fail("forbidden", 403);
    }
    const readBy = readByList(existingMessage.read_by);
    if (body.is_read == true && !readBy.includes(user.id)) {
      readBy.push(user.id);
    }
    const { data, error } = await svc.from("messages").update({
      read_by: readBy,
    }).eq("id", messageMatch[1]).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  // ── Diary ─────────────────────────────────────────────────
  if ((path === "/diary" || path === "/diary-entries") && method === "GET") {
    const page = Math.max(parseInt(url.searchParams.get("page") ?? "1") || 1, 1);
    const pageSize = Math.min(
      Math.max(parseInt(url.searchParams.get("page_size") ?? "20") || 20, 1),
      100,
    );
    let q = svc.from("diary_entries").select("*", { count: "exact" }).eq(
      "school_id",
      school,
    );
    const staffId = url.searchParams.get("staff_id");
    const requestedStaffId = text(staffId);
    const requestedSectionId = text(url.searchParams.get("section_id"));
    const userRole = role(user);
    if (userRole === "teacher") {
      const scope = await resolveActiveTeacherScope(
        svc,
        school,
        linkedStaffId(user),
      );
      if (!scope.isActive) return fail("staff profile not linked", 403);
      if (staffId && staffId !== linkedStaffId(user)) {
        return fail("forbidden", 403);
      }
      if (requestedSectionId && !scope.sections.has(requestedSectionId)) {
        return fail("forbidden", 403);
      }
      const sectionIds = [...scope.sections.keys()];
      if (sectionIds.length === 0) return ok([]);
      q = q.eq("staff_id", scope.staffId).in("section_id", sectionIds);
    } else if (userRole === "parent") {
      if (requestedStaffId) return fail("forbidden", 403);
      const sectionIds = [...await lessonPlannerParentSectionIds(svc, school, user)];
      if (requestedSectionId && !sectionIds.includes(requestedSectionId)) {
        return fail("forbidden", 403);
      }
      if (sectionIds.length === 0) return ok([]);
      q = q.in("section_id", sectionIds);
    } else if (!canManageSchoolContent(user)) {
      return fail("forbidden", 403);
    } else if (requestedStaffId) {
      q = q.eq("staff_id", requestedStaffId);
    }
    if (requestedSectionId) {
      q = q.eq("section_id", requestedSectionId);
    }
    if (url.searchParams.get("date")) {
      q = q.eq("date", url.searchParams.get("date")!);
    }
    const { data, error, count } = await q.order("date", {
      ascending: false,
    }).order("id", { ascending: false }).range(
      (page - 1) * pageSize,
      page * pageSize - 1,
    );
    if (error) return fail(error.message);
    return ok({
      data: data ?? [],
      total: count ?? data?.length ?? 0,
      page,
      page_size: pageSize,
      has_more: page * pageSize < (count ?? 0),
    });
  }
  if ((path === "/diary" || path === "/diary-entries") && method === "POST") {
    const userRole = role(user);
    const sectionId = text(body.section_id);
    let staffId = text(body.staff_id);
    if (userRole === "teacher") {
      const scope = await resolveActiveTeacherScope(
        svc,
        school,
        linkedStaffId(user),
      );
      if (!scope.isActive) return fail("staff profile not linked", 403);
      if (!sectionId || !scope.sections.has(sectionId)) {
        return fail("teacher is not assigned to this class section", 403);
      }
      staffId = scope.staffId;
    } else if (!canManageSchoolContent(user)) {
      return fail("forbidden", 403);
    }
    const payload = {
      ...body,
      school_id: school,
      section_id: sectionId || null,
      staff_id: canManageSchoolContent(user) ? staffId : linkedStaffId(user),
      teacher_id: staffId || null,
      attachments: Array.isArray(body.attachments) ? body.attachments : [],
      created_by: user.id,
    };
    const { data, error } = await svc.from("diary_entries").insert(payload)
      .select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  const diaryMatch = path.match(/^\/diary-entries\/([^/]+)$/);
  if (diaryMatch && method === "PUT") {
    const { data: existing, error: existingError } = await svc.from(
      "diary_entries",
    ).select("id, staff_id, section_id").eq("id", diaryMatch[1]).eq(
      "school_id",
      school,
    ).maybeSingle();
    if (existingError) return fail(existingError.message);
    if (!existing) return fail("diary entry not found", 404);
    const isLeader = canManageSchoolContent(user);
    let changes: Record<string, unknown> = body;
    if (!isLeader) {
      if (role(user) !== "teacher") return fail("forbidden", 403);
      const scope = await resolveActiveTeacherScope(
        svc,
        school,
        linkedStaffId(user),
      );
      const nextSectionId = text(body.section_id) || text(existing.section_id);
      if (!scope.isActive || text(existing.staff_id) !== scope.staffId ||
        !scope.sections.has(nextSectionId)) {
        return fail("forbidden", 403);
      }
      const allowed = ["title", "content", "date", "section_id", "attachments"];
      changes = Object.fromEntries(
        Object.entries(body).filter(([key]) => allowed.includes(key)),
      );
    }
    if ("attachments" in changes) {
      changes = {
        ...changes,
        attachments: Array.isArray(changes.attachments)
          ? changes.attachments
          : [],
      };
    }
    const { data, error } = await svc.from("diary_entries").update(changes).eq(
      "id",
      diaryMatch[1],
    ).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  if (diaryMatch && method === "DELETE") {
    const { data: existing, error: existingError } = await svc.from(
      "diary_entries",
    ).select("id, staff_id, section_id").eq("id", diaryMatch[1]).eq(
      "school_id",
      school,
    ).maybeSingle();
    if (existingError) return fail(existingError.message);
    if (!existing) return fail("diary entry not found", 404);
    if (!canManageSchoolContent(user)) {
      if (role(user) !== "teacher") return fail("forbidden", 403);
      const scope = await resolveActiveTeacherScope(
        svc,
        school,
        linkedStaffId(user),
      );
      if (!scope.isActive || text(existing.staff_id) !== scope.staffId ||
        !scope.sections.has(text(existing.section_id))) {
        return fail("forbidden", 403);
      }
    }
    const { error } = await svc.from("diary_entries").delete().eq(
      "id",
      diaryMatch[1],
    ).eq("school_id", school);
    if (error) return fail(error.message);
    return ok({ success: true });
  }

  // ── Lesson planners ───────────────────────────────────────
  if (path === "/lesson-planners/teacher" && method === "GET") {
    if (role(user) !== "teacher") return fail("forbidden", 403);
    const teacherId = linkedStaffId(user);
    const scope = await resolveActiveTeacherScope(
      svc,
      school,
      teacherId,
    );
    if (!scope.isActive) return fail("staff profile not linked", 403);
    const sectionIds = new Set(scope.sections.keys());
    if (sectionIds.size === 0) return ok([]);
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "lesson_planners").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    const currentRows = await autoCompleteEndedLessonPlanners(
      svc,
      school,
      data ?? [],
    );
    const rows = (await enrichLessonPlannerRows(svc, school, currentRows))
      .filter((row) => sectionIds.has(`${row.section_id ?? ""}`));
    return ok(rows);
  }

  if (path === "/lesson-planners/principal" && method === "GET") {
    if (!canManageSchoolContent(user)) return fail("forbidden", 403);
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "lesson_planners").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    const currentRows = await autoCompleteEndedLessonPlanners(
      svc,
      school,
      data ?? [],
    );
    const rows = await enrichLessonPlannerRows(svc, school, currentRows);
    return ok(rows);
  }

  if (path === "/lesson-planners/parent" && method === "GET") {
    if (role(user) !== "parent") return fail("forbidden", 403);
    const sectionIds = await lessonPlannerParentSectionIds(svc, school, user);
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "lesson_planners").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    const currentRows = await autoCompleteEndedLessonPlanners(
      svc,
      school,
      data ?? [],
    );
    const rows = (await enrichLessonPlannerRows(svc, school, currentRows))
      .filter((row) => {
        const status = `${row.status ?? ""}`.toLowerCase();
        return status !== "draft" &&
          sectionIds.has(`${row.section_id ?? ""}`);
      });
    return ok(rows);
  }

  if (path === "/lesson-planners" && method === "POST") {
    if (role(user) !== "teacher") return fail("forbidden", 403);
    const teacherId = linkedStaffId(user);
    const sectionId = `${body.section_id ?? ""}`.trim();
    const scopeError = await ensureLessonPlannerTeacherCanPost(
      svc,
      school,
      teacherId,
      sectionId,
    );
    if (scopeError) return fail(scopeError, 403);
    const attachments = canonicalLessonPlannerAttachments(
      normalizeLessonPlannerAttachments(body),
    );
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

    // Persist notification rows before returning success. This keeps a lesson
    // plan from silently losing its principal notification if an edge runtime
    // finishes the request before a background promise completes.
    await notifyLessonPlannerUploaded(
      svc,
      school,
      payload.id,
      payload.teacher_name,
      teacherId,
      payload.section_id,
    );

    return ok(await materializeLessonPlannerRow(svc, data));
  }

  const lessonPlannerCompleteMatch = path.match(
    /^\/lesson-planners\/([^/]+)\/complete$/,
  );
  if (lessonPlannerCompleteMatch && method === "POST") {
    if (!canManageSchoolContent(user)) return fail("forbidden", 403);
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
    const existingPayload = (existing.data as Record<string, unknown> | null) ??
      {};
    const today = new Date().toLocaleDateString("en-CA", {
      timeZone: "Asia/Kolkata",
    });
    if (text(existingPayload.week_end_date).slice(0, 10) >= today) {
      return fail(
        "lesson planners complete automatically after their week ends",
        400,
      );
    }
    const payload = {
      ...existingPayload,
      status: "completed",
      completed_at: new Date().toISOString(),
    };
    const { data, error } = await svc.from("frontend_records").update({
      data: payload,
      updated_at: new Date().toISOString(),
    }).eq("id", existing.id).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(await materializeLessonPlannerRow(svc, data));
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
  teacherId: string,
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
      ? `${sectionData.grade?.grade_name ?? ""} - ${
        sectionData.section_name ?? ""
      }`
      : "Assigned Class";
    const { data: teacher } = await svc
      .from("staff")
      .select("first_name, last_name, full_name, name, staff_code, email")
      .eq("school_id", school)
      .eq("id", teacherId)
      .maybeSingle();
    const resolvedTeacherName = lessonPlannerDisplayText(
      teacherName,
      teacher && typeof teacher === "object"
        ? lessonPlannerStaffName(teacher as Record<string, unknown>)
        : "",
      "A teacher",
    );

    const eventIds: string[] = [];

    // 2. Notify all school leaders who can review the planner.
    const { data: principalUsers } = await svc
      .from("users")
      .select("id")
      .eq("school_id", school)
      .in("role_name", ["principal", "coordinator"]);

    if (principalUsers && principalUsers.length > 0) {
      for (const p of principalUsers) {
        await svc.from("notification_logs").insert({
          school_id: school,
          user_id: p.id,
          target_role: "all",
          title: "New Lesson Planner",
          body:
            `${resolvedTeacherName} uploaded a weekly lesson plan for Class ${className}.`,
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
            message:
              `${resolvedTeacherName} uploaded a weekly lesson plan for Class ${className}.`,
            reference_type: "lesson_planner",
            reference_id: lessonPlannerId,
            route: "/principal-lesson-planner-screen",
            section_id: sectionId,
            teacher_id: teacherId,
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
        new Set(
          (links ?? []).map((l: any) => l.parent_user_id).filter(Boolean),
        ),
      );

      for (const pid of parentUserIds) {
        await svc.from("notification_logs").insert({
          school_id: school,
          user_id: pid,
          target_role: "parent",
          title: "New Lesson Planner",
          body:
            `A new lesson planner has been uploaded for Class ${className} for this week.`,
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
            message:
              `A new lesson planner has been uploaded for Class ${className} for this week.`,
            reference_type: "lesson_planner",
            reference_id: lessonPlannerId,
            route: "/parent-lesson-planner-screen",
            section_id: sectionId,
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

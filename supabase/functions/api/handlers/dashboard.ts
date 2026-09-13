// handlers/dashboard.ts — admin, principal, teacher, parent dashboards
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";
import {
  coordinatorDashboardDto,
  financeDashboardDto,
} from "../lib/dashboard_dto.ts";
import {
  isFinanceLeader,
  isSchoolLeader,
  roleName,
} from "./authorization.ts";

function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function number(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value)
    ? value
    : Number.parseFloat(text(value)) || 0;
}

function homeworkRow(row: Record<string, unknown>): Record<string, unknown> {
  const data = asRecord(row.data) ?? row;
  return {
    ...data,
    homework_id: text(data.homework_id ?? data.id ?? row.record_id ?? row.id),
  };
}

function studentName(student: Record<string, unknown>) {
  const direct = text(
    student.name ?? student.full_name ?? student.student_name,
  );
  if (direct) return direct;
  return [text(student.first_name), text(student.last_name)].filter(Boolean)
    .join(" ");
}

function buildTeacherAssignments(
  subjectRows: Array<Record<string, unknown>>,
  classTeacherSections: Array<Record<string, unknown>>,
  coTeacherSections: Array<Record<string, unknown>>,
  schoolSections: Array<Record<string, unknown>>,
  gradeSubjects: Array<Record<string, unknown>>,
) {
  const assignments = new Map<string, Record<string, unknown>>();

  const ensureSection = (
    section: Record<string, unknown> | null,
    role: "subject_teacher" | "class_teacher" | "co_teacher",
    fallback: Record<string, unknown> = {},
  ) => {
    const sectionId = text(section?.id ?? fallback.section_id);
    if (!sectionId) return null;
    const grade = asRecord(section?.grade) ?? asRecord(fallback.grade);
    let existing = assignments.get(sectionId);
    if (!existing) {
      existing = {
        id: sectionId,
        section_id: sectionId,
        grade_id: text(section?.grade_id ?? fallback.grade_id),
        grade_name: text(grade?.grade_name ?? fallback.grade_name),
        section_name: text(section?.section_name ?? fallback.section_name),
        academic_year_id: text(
          section?.academic_year_id ?? fallback.academic_year_id,
        ),
        subject_id: "",
        subject_name: "",
        teacher_role: role,
        is_class_teacher: false,
        is_co_teacher: false,
        subjects: [] as Array<Record<string, unknown>>,
      };
      assignments.set(sectionId, existing);
    } else {
      if (!text(existing.grade_name)) {
        existing.grade_name = text(grade?.grade_name ?? fallback.grade_name);
      }
      if (!text(existing.section_name)) {
        existing.section_name = text(
          section?.section_name ?? fallback.section_name,
        );
      }
      if (!text(existing.academic_year_id)) {
        existing.academic_year_id = text(
          section?.academic_year_id ?? fallback.academic_year_id,
        );
      }
    }
    return existing;
  };

  for (const row of subjectRows) {
    const section = asRecord(row.section);
    const subject = asRecord(row.subject);
    const subjectId = text(subject?.id ?? row.subject_id);
    const subjectName = text(subject?.subject_name ?? row.subject_name);
    const directSectionId = text(row.section_id);
    const assignmentGradeId = text(row.grade_id);
    const assignmentYearId = text(row.academic_year_id);
    const directSection = directSectionId
      ? schoolSections.find((candidate) => text(candidate.id) === directSectionId)
      : null;
    const matchingSections = section
      ? [section]
      : directSection
      ? [directSection]
      : schoolSections.filter((candidate) =>
          text(candidate.grade_id) === assignmentGradeId &&
          (!assignmentYearId ||
            text(candidate.academic_year_id) === assignmentYearId)
        );
    for (const matchingSection of matchingSections) {
      const entry = ensureSection(matchingSection, "subject_teacher", row);
      if (!entry) continue;
      const subjects = entry.subjects as Array<Record<string, unknown>>;
      if (
        subjectId &&
        !subjects.some((item) => text(item.id ?? item.subject_id) === subjectId)
      ) {
        subjects.push({
          id: subjectId,
          subject_id: subjectId,
          subject_name: subjectName,
        });
      }
      if (!text(entry.subject_id) && subjectId) {
        entry.subject_id = subjectId;
      }
      if (!text(entry.subject_name) && subjectName) {
        entry.subject_name = subjectName;
      }
      if (!text(entry.assignment_id)) {
        entry.assignment_id = text(row.id);
      }
    }
  }

  for (const section of classTeacherSections) {
    const entry = ensureSection(section, "class_teacher");
    if (!entry) continue;
    entry.is_class_teacher = true;
    entry.teacher_role = "class_teacher";
    if (!text(entry.subject_name)) {
      entry.subject_name = "Class Teacher";
    }
  }

  for (const section of coTeacherSections) {
    const entry = ensureSection(section, "co_teacher");
    if (!entry) continue;
    entry.is_co_teacher = true;
    if (!text(entry.teacher_role)) {
      entry.teacher_role = "co_teacher";
    }
    if (!text(entry.subject_name)) {
      entry.subject_name = "Co-Teacher";
    }
  }

    // Class and co-teachers receive the class hub's subject list. A
    // subject-only teacher retains only their explicit subject assignments.
    for (const entry of assignments.values()) {
    const sectionId = text(entry.section_id);
    const gradeId = text(entry.grade_id);
    const sectionYear = text(entry.academic_year_id);
    const subjects = entry.subjects as Array<Record<string, unknown>>;
    if (!entry.is_class_teacher && !entry.is_co_teacher) continue;
    subjects.length = 0;
    // Match by section or grade, always within the section's academic year.
    const matchingGradeSubjects = gradeSubjects.filter((gs) => {
      const gsSectionId = text(gs.section_id);
      const gsGradeId = text(gs.grade_id);
      const gsYear = text(gs.academic_year_id);
      return (gsSectionId === sectionId ||
        (gradeId !== "" && gsGradeId === gradeId)) &&
        (!gsYear || gsYear === sectionYear);
    });

    for (const gs of matchingGradeSubjects) {
      const subject = asRecord(gs.subject);
      const subjectId = text(subject?.id ?? gs.subject_id);
      const subjectName = text(subject?.subject_name ?? gs.subject_name);
      if (
        subjectId &&
        !subjects.some((item) => text(item.id ?? item.subject_id) === subjectId)
      ) {
        subjects.push({
          id: subjectId,
          subject_id: subjectId,
          subject_name: subjectName,
        });
      }
    }
  }

  return [...assignments.values()];
}

async function teacherDashboardResponse(
  svc: SupabaseClient,
  school: string,
  user: User,
): Promise<Response> {
  const { data: userRow, error: userError } = await svc.from("users").select(
    "linked_id",
  ).eq("school_id", school).eq("id", user.id).maybeSingle();
  if (userError) return fail(userError.message);
  const staffId = text(userRow?.linked_id);
  if (!staffId) {
    return ok({
      staff_id: "",
      assigned_classes: [],
      total_students: 0,
      total_sections: 0,
      recent_announcements: [],
      metrics: {
        total_students: 0,
        total_classes: 0,
        homework_due: 0,
        unread_messages: 0,
      },
    });
  }

  const [
    staffResult,
    staffSubjectsResult,
    classTeacherSectionsResult,
    coTeacherSectionsResult,
    schoolSectionsResult,
    gradeSubjectsResult,
    announcementsResult,
  ] = await Promise.all([
    svc.from("staff").select("id").eq("school_id", school).eq(
      "id",
      staffId,
    ).eq("is_active", true).maybeSingle(),
    svc.from("staff_subjects").select(
      "*, section:sections(*, grade:grades(*)), subject:subjects(*), grade:grades(*)",
    ).eq("staff_id", staffId).eq("school_id", school),
    svc.from("sections").select("*, grade:grades(*)").eq(
      "class_teacher_id",
      staffId,
    ).eq("school_id", school),
    svc.from("sections").select("*, grade:grades(*)").eq(
      "co_teacher_id",
      staffId,
    ).eq("school_id", school),
    svc.from("sections").select("*, grade:grades(*)").eq(
      "school_id",
      school,
    ),
    svc.from("grade_subjects").select("*, subject:subjects(*)").eq(
      "school_id",
      school,
    ),
    svc.from("announcements").select("id, title, published_at, priority")
      .eq("school_id", school).eq("status", "published").in(
        "audience",
        ["all", "everyone", "teacher"],
      ).order("published_at", { ascending: false }).limit(5),
  ]);
  for (
    const result of [
      staffResult,
      staffSubjectsResult,
      classTeacherSectionsResult,
      coTeacherSectionsResult,
      schoolSectionsResult,
      gradeSubjectsResult,
      announcementsResult,
    ]
  ) {
    if (result.error) return fail(result.error.message);
  }
  if (!staffResult.data) return fail("staff profile is not active", 403);

  const assigned = buildTeacherAssignments(
    (staffSubjectsResult.data ?? []) as Array<Record<string, unknown>>,
    (classTeacherSectionsResult.data ?? []) as Array<Record<string, unknown>>,
    (coTeacherSectionsResult.data ?? []) as Array<Record<string, unknown>>,
    (schoolSectionsResult.data ?? []) as Array<Record<string, unknown>>,
    (gradeSubjectsResult.data ?? []) as Array<Record<string, unknown>>,
  );
  const sectionIds = assigned.map((section) => text(section.section_id)).filter(
    Boolean,
  );
  const studentsResult = sectionIds.length === 0
    ? { count: 0, error: null }
    : await svc.from("students").select("id", { count: "exact", head: true })
      .eq("school_id", school).eq("status", "active").in(
        "current_section_id",
        sectionIds,
      );
  if (studentsResult.error) return fail(studentsResult.error.message);
  const studentCount = studentsResult.count ?? 0;

  return ok({
    staff_id: staffId,
    assigned_classes: assigned,
    total_students: studentCount,
    total_sections: sectionIds.length,
    recent_announcements: announcementsResult.data ?? [],
    metrics: {
      total_students: studentCount,
      total_classes: sectionIds.length,
      homework_due: 0,
      unread_messages: 0,
    },
  });
}

async function parentDashboardResponse(
  svc: SupabaseClient,
  school: string,
  user: User,
): Promise<Response> {
  const { data: links, error: linksError } = await svc
    .from("parent_student_links")
    .select("student_id, student:students(*, section:sections(*, grade:grades(*)))")
    .eq("school_id", school)
    .eq("parent_user_id", user.id);
  if (linksError) return fail(linksError.message);

  const linkedStudents = (links ?? []).map((link: Record<string, unknown>) =>
    asRecord(link.student)
  ).filter((student): student is Record<string, unknown> =>
    student !== null && text(student.school_id) === school &&
      text(student.status).toLowerCase() === "active"
  );
  const studentIds = linkedStudents.map((student) => text(student.id)).filter(
    Boolean,
  );
  if (studentIds.length === 0) {
    return ok({
      children: [],
      metrics: { total_children: 0, unread_messages: 0 },
      recent_announcements: [],
    });
  }

  const [
    attendanceResult,
    invoiceResult,
    homeworkResult,
    submissionResult,
    conversationResult,
    announcementsResult,
  ] = await Promise.all([
    svc.from("attendance_summaries").select("student_id, percentage, updated_at")
      .eq("school_id", school).in("student_id", studentIds)
      .order("updated_at", { ascending: false }),
    svc.from("fee_invoices").select(
      "student_id, balance, net_amount, paid_amount, status",
    ).eq("school_id", school).in("student_id", studentIds),
    svc.from("frontend_records").select("id, record_id, data")
      .eq("school_id", school).eq("table_name", "homework"),
    svc.from("homework_submissions").select(
      "homework_id, student_id, status, updated_at",
    ).eq("school_id", school).in("student_id", studentIds)
      .order("updated_at", { ascending: false }),
    svc.from("message_conversations").select("id, student_id")
      .eq("school_id", school).eq("parent_id", user.id),
    svc.from("announcements").select("id, title, published_at, priority")
      .eq("school_id", school).eq("status", "published")
      .in("audience", ["all", "everyone", "parent", "parents"])
      .order("published_at", { ascending: false }).limit(5),
  ]);
  for (
    const result of [
      attendanceResult,
      invoiceResult,
      homeworkResult,
      submissionResult,
      conversationResult,
      announcementsResult,
    ]
  ) {
    if (result.error) return fail(result.error.message);
  }

  const conversationStudentIds = new Map<string, string>();
  for (const row of conversationResult.data ?? []) {
    const conversationId = text(row.id);
    const studentId = text(row.student_id);
    if (conversationId && studentIds.includes(studentId)) {
      conversationStudentIds.set(conversationId, studentId);
    }
  }
  const conversationIds = [...conversationStudentIds.keys()];
  const messageResult = conversationIds.length === 0
    ? { data: [], error: null }
    : await svc.from("messages").select("conversation_id, sender_id, read_by")
      .eq("school_id", school).in("conversation_id", conversationIds);
  if (messageResult.error) return fail(messageResult.error.message);

  const attendanceByStudent = new Map<string, number>();
  for (const row of attendanceResult.data ?? []) {
    const studentId = text(row.student_id);
    if (studentId && !attendanceByStudent.has(studentId)) {
      attendanceByStudent.set(studentId, number(row.percentage));
    }
  }
  const feeBalanceByStudent = new Map<string, number>();
  for (const row of invoiceResult.data ?? []) {
    if (["cancelled", "canceled", "void"].includes(text(row.status).toLowerCase())) {
      continue;
    }
    const studentId = text(row.student_id);
    const balance = Math.max(
      0,
      number(row.balance) || (number(row.net_amount) - number(row.paid_amount)),
    );
    feeBalanceByStudent.set(
      studentId,
      (feeBalanceByStudent.get(studentId) ?? 0) + balance,
    );
  }
  const newestSubmissionByHomeworkAndStudent = new Map<string, string>();
  for (const row of submissionResult.data ?? []) {
    const key = `${text(row.homework_id)}:${text(row.student_id)}`;
    if (key !== ":" && !newestSubmissionByHomeworkAndStudent.has(key)) {
      newestSubmissionByHomeworkAndStudent.set(key, text(row.status));
    }
  }
  const homeworkDueByStudent = new Map<string, number>();
  for (const rawRow of homeworkResult.data ?? []) {
    const row = homeworkRow(rawRow as Record<string, unknown>);
    const homeworkId = text(row.homework_id);
    const targetStudentId = text(row.student_id);
    const targetSectionId = text(row.section_id);
    for (const student of linkedStudents) {
      const studentId = text(student.id);
      const sectionId = text(
        student.current_section_id ?? asRecord(student.section)?.id,
      );
      if (
        !studentId || (targetStudentId !== studentId &&
          (targetStudentId || !targetSectionId || targetSectionId !== sectionId))
      ) continue;
      const submissionStatus = newestSubmissionByHomeworkAndStudent.get(
        `${homeworkId}:${studentId}`,
      );
      if (submissionStatus !== "submitted" && submissionStatus !== "reviewed") {
        homeworkDueByStudent.set(
          studentId,
          (homeworkDueByStudent.get(studentId) ?? 0) + 1,
        );
      }
    }
  }
  const unreadMessagesByStudent = new Map<string, number>();
  for (const row of messageResult.data ?? []) {
    if (text(row.sender_id) === user.id) continue;
    const readBy = Array.isArray(row.read_by) ? row.read_by : [];
    if (readBy.map((value) => text(value)).includes(user.id)) continue;
    const studentId = conversationStudentIds.get(text(row.conversation_id));
    if (studentId) {
      unreadMessagesByStudent.set(
        studentId,
        (unreadMessagesByStudent.get(studentId) ?? 0) + 1,
      );
    }
  }
  const unreadMessages = [...unreadMessagesByStudent.values()].reduce(
    (total, count) => total + count,
    0,
  );
  const parentChildOverview = ({
    attendancePct,
    homeworkDueByStudent,
    feeBalanceByStudent,
    unreadMessages,
  }: {
    attendancePct: number | null;
    homeworkDueByStudent: number;
    feeBalanceByStudent: number;
    unreadMessages: number;
  }) => ({
    // Child notification counts originate from unread_messages: unreadMessagesByStudent.
    attendance_pct: attendancePct ?? null,
    homework_due: homeworkDueByStudent,
    pending_fee_balance: feeBalanceByStudent,
    unread_messages: unreadMessages,
  });
  const base = { metrics: { total_children: linkedStudents.length } };

  return ok({
    children: linkedStudents.map((student) => {
      const section = asRecord(student.section);
      const grade = asRecord(section?.grade);
      const studentId = text(student.id);
      const attendancePct = attendanceByStudent.get(studentId) ?? null;
      const homeworkDue = homeworkDueByStudent.get(studentId) ?? 0;
      const feeBalance = feeBalanceByStudent.get(studentId) ?? 0;
      return {
        ...student,
        name: studentName(student),
        class: text(grade?.grade_name),
        section: text(section?.section_name),
        photo_url: text(student.photo_url ?? student.photo ?? student.avatar),
        ...parentChildOverview({
          attendancePct,
          homeworkDueByStudent: homeworkDue,
          feeBalanceByStudent: feeBalance,
          unreadMessages: unreadMessagesByStudent.get(studentId) ?? 0,
        }),
      };
    }),
    metrics: { ...base.metrics, unread_messages: unreadMessages },
    recent_announcements: announcementsResult.data ?? [],
  });
}

export async function handleDashboard(
  _req: Request,
  path: string,
  _method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const role = roleName(user);
  const requestedRole = text(
    url.searchParams.get("role") ?? path.split("/").filter(Boolean)[1],
  ).toLowerCase();
  if (requestedRole && requestedRole !== role) {
    return fail("dashboard role does not match session", 403);
  }
  const dashRole = role;

  if (path === "/dashboard" || path.startsWith("/dashboard")) {
    if (dashRole === "teacher") {
      return teacherDashboardResponse(svc, school, user);
    }
    if (dashRole === "parent") {
      return parentDashboardResponse(svc, school, user);
    }
    if (!isSchoolLeader(user)) {
      return fail("forbidden", 403);
    }

    const today = new Date();
    const todayStart = new Date(
      today.getFullYear(),
      today.getMonth(),
      today.getDate(),
    ).toISOString();
    const financeAuthorized = isFinanceLeader(user);
    let approvalRequestsQuery = svc.from("approval_requests").select(
      "id, status",
    ).eq("school_id", school).eq("status", "pending");
    if (!financeAuthorized) {
      // A coordinator's operations count must not disclose pending fee work.
      approvalRequestsQuery = approvalRequestsQuery.not(
        "module",
        "in",
        '("fee","fees","finance","payment")',
      );
    }

    const [
      assignedStudents,
      unassignedStudents,
      staff,
      announcements,
      sections,
      pendingLeave,
      attendanceSessions,
      todayAttendanceRows,
      todayPresentRows,
      approvalRequests,
    ] = await Promise.all([
      svc.from("students").select("id", { count: "exact", head: true })
        .eq("school_id", school).eq("is_test_account", false)
        .eq("status", "active").not("current_section_id", "is", null),
      svc.from("students").select("id", { count: "exact", head: true })
        .eq("school_id", school).eq("is_test_account", false)
        .eq("status", "active").is("current_section_id", null),
      svc.from("staff").select("id", { count: "exact", head: true }).eq(
        "school_id",
        school,
      ),
      svc.from("announcements").select("id, title, published_at, priority")
        .eq("school_id", school).order("published_at", { ascending: false })
        .limit(5),
      svc.from("sections").select("id", { count: "exact", head: true }).eq(
        "school_id",
        school,
      ),
      svc.from("leave_applications").select("id", {
        count: "exact",
        head: true,
      }).eq("school_id", school).eq("status", "pending"),
      svc.from("student_attendances").select("id, status", {
        count: "exact",
        head: true,
      }).eq("school_id", school),
      svc.from("student_attendances").select("id", {
        count: "exact",
        head: true,
      }).eq(
        "school_id",
        school,
      ).gte("created_at", todayStart),
      svc.from("student_attendances").select("id", {
        count: "exact",
        head: true,
      }).eq("school_id", school).eq("status", "present").gte(
        "created_at",
        todayStart,
      ),
      approvalRequestsQuery,
    ]);

    // Calculate today's attendance percentage from bounded head-count queries.
    const todayMarked = todayAttendanceRows.count ?? 0;
    const todayPresent = todayPresentRows.count ?? 0;
    const attendancePct = todayMarked > 0
      ? Math.round((todayPresent / todayMarked) * 100)
      : 0;

    const operations = {
      activeAssignedStudents: assignedStudents.count ?? 0,
      activeUnassignedStudents: unassignedStudents.count ?? 0,
      staffCount: staff.count ?? 0,
      sectionCount: sections.count ?? 0,
      pendingLeaveCount: pendingLeave.count ?? 0,
      recentAnnouncements: (announcements.data ?? []) as Array<
        Record<string, unknown>
      >,
      pendingEventApprovals: approvalRequests.data?.length ?? 0,
      pendingAccessApprovals: approvalRequests.data?.length ?? 0,
      attendanceToday: attendanceSessions.data?.length ?? 0,
      attendancePercentage: attendancePct,
      attendancePresent: todayPresent,
      attendanceMarked: todayMarked,
    };

    if (!financeAuthorized) {
      return ok(coordinatorDashboardDto(operations));
    }

    const { data: feeSummary, error: feeSummaryError } = await svc.rpc(
      "fee_dashboard_summary",
      { p_school_id: school },
    );
    if (feeSummaryError) return fail(feeSummaryError.message);
    const summary = (feeSummary && typeof feeSummary === "object")
      ? feeSummary as Record<string, unknown>
      : {};
    const totalOutstanding = number(summary.outstanding);
    const totalPaid = number(summary.collected);
    const totalDue = totalOutstanding;
    const collectionPct = totalDue > 0
      ? Math.round((totalPaid / (totalPaid + totalDue)) * 100)
      : 100;
    const base = financeDashboardDto(operations, {
      pendingFeeBalance: totalOutstanding,
      pendingFeeRequests: number(summary.pending_request_count),
      collectionPercentage: collectionPct,
      totalPaid,
      totalDue,
    });

    if (dashRole === "super_admin") {
      // Super admin dashboard: system-level metrics + base school data.
      const [errorEvents, auditLogs] = await Promise.all([
        svc.from("error_events").select("id", { count: "exact", head: true })
          .eq("school_id", school).contains("context", { status: "open" }),
        svc.from("audit_logs").select("id", { count: "exact", head: true })
          .eq("school_id", school),
      ]);
      return ok({
        ...base,
        system_metrics: {
          open_errors: errorEvents.count ?? 0,
          total_audit_entries: auditLogs.count ?? 0,
          total_students: base.total_students,
          total_staff: base.total_staff,
          total_classes: base.total_sections,
          pending_fee_balance: base.pending_fee_balance,
          attendance_today: base.metrics.attendance_today,
        },
      });
    }

    return ok(base);
  }

  return fail("not found", 404);
}

// handlers/dashboard.ts — admin, principal, teacher, parent dashboards
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

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

function buildTeacherAssignments(
  subjectRows: Array<Record<string, unknown>>,
  classTeacherSections: Array<Record<string, unknown>>,
  coTeacherSections: Array<Record<string, unknown>>,
  gradeSubjects: Array<Record<string, unknown>>,
  staffSubjects: Array<Record<string, unknown>>,
  timetableSlots: Array<Record<string, unknown>>,
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
        academic_year_id: text(section?.academic_year_id ?? fallback.academic_year_id),
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
        existing.section_name = text(section?.section_name ?? fallback.section_name);
      }
      if (!text(existing.academic_year_id)) {
        existing.academic_year_id = text(section?.academic_year_id ?? fallback.academic_year_id);
      }
    }
    return existing;
  };

  for (const row of subjectRows) {
    const section = asRecord(row.section);
    const subject = asRecord(row.subject);
    const entry = ensureSection(section, "subject_teacher", row);
    if (!entry) continue;
    const subjectId = text(subject?.id ?? row.subject_id);
    const subjectName = text(subject?.subject_name ?? row.subject_name);
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

  // Populate all matching subjects from grade_subjects, staff_subjects, and timetable_slots tables
  for (const entry of assignments.values()) {
    const sectionId = text(entry.section_id);
    const gradeId = text(entry.grade_id);
    const sectionYear = text(entry.academic_year_id);
    const subjects = entry.subjects as Array<Record<string, unknown>>;
    // Clear out any subjects assigned directly to the teacher so we ONLY show Class Hub subjects
    subjects.length = 0;
    // 1. Match from grade_subjects — match by section_id OR grade_id
    const matchingGradeSubjects = gradeSubjects.filter((gs) => {
      const gsSectionId = text(gs.section_id);
      const gsGradeId = text(gs.grade_id);
      return gsSectionId === sectionId || (gradeId !== "" && gsGradeId === gradeId);
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

    // The class hub (grade_subjects) is the single source of truth for the subjects available to a class.
    // Removed legacy merging from other teachers (staff_subjects) and timetable slots (timetable_slots).
  }

  return [...assignments.values()];
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
  const role = (user.app_metadata?.role_name as string ?? "").toLowerCase();
  const dashRole = url.searchParams.get("role") ?? role;

  if (path === "/dashboard" || path.startsWith("/dashboard")) {
    const today = new Date();
    const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate()).toISOString();

    const [students, staff, invoices, paidInvoices, announcements, sections, pendingLeave, attendanceSessions, todayAttendances, parentPaymentRequests, approvalRequests] =
      await Promise.all([
        svc.from("students").select("id, status", {
          count: "exact",
          head: true,
        }).eq("school_id", school),
        svc.from("staff").select("id", { count: "exact", head: true }).eq(
          "school_id",
          school,
        ),
        svc.from("fee_invoices").select("balance, status").eq(
          "school_id",
          school,
        ).eq("status", "pending"),
        svc.from("fee_invoices").select("paid_amount").eq(
          "school_id",
          school,
        ).eq("status", "paid"),
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
        svc.from("student_attendances").select("id, status").eq(
          "school_id",
          school,
        ).gte("created_at", todayStart),
        svc.from("parent_payment_requests").select("id, status").eq(
          "school_id",
          school,
        ).eq("status", "pending"),
        svc.from("approval_requests").select("id, status").eq(
          "school_id",
          school,
        ).eq("status", "pending"),
      ]);

    const totalOutstanding = (invoices.data ?? []).reduce(
      (s: number, i: Record<string, number>) => s + (i.balance ?? 0),
      0,
    );
    const totalPaid = (paidInvoices.data ?? []).reduce(
      (s: number, i: Record<string, number>) => s + (i.paid_amount ?? 0),
      0,
    );
    const totalDue = totalOutstanding;
    const collectionPct = totalDue > 0 ? Math.round((totalPaid / (totalPaid + totalDue)) * 100) : 100;

    // Calculate today's attendance percentage
    const todayRows = todayAttendances.data ?? [];
    const todayMarked = todayRows.length;
    const todayPresent = todayRows.filter((r: Record<string, unknown>) => r.status === "present").length;
    const attendancePct = todayMarked > 0 ? Math.round((todayPresent / todayMarked) * 100) : 0;

    const base = {
      total_students: students.count ?? 0,
      total_staff: staff.count ?? 0,
      total_sections: sections.count ?? 0,
      pending_fee_balance: totalOutstanding,
      pending_leave_requests: pendingLeave.count ?? 0,
      recent_announcements: announcements.data ?? [],
      metrics: {
        total_students: students.count ?? 0,
        total_staff: staff.count ?? 0,
        total_classes: sections.count ?? 0,
        pending_event_approvals: approvalRequests.data?.length ?? 0,
        pending_fee_requests: parentPaymentRequests.data?.length ?? 0,
        pending_access_approvals: approvalRequests.data?.length ?? 0,
        attendance_today: attendanceSessions.data?.length ?? 0,
      },
      today_attendance: {
        attendance_pct: attendancePct,
        present: todayPresent,
        marked: todayMarked,
      },
      fees: {
        collection_pct: collectionPct,
        total_paid: totalPaid,
        total_due: totalDue,
      },
    };

    if (dashRole === "teacher") {
      const { data: userRow } = await svc.from("users").select("linked_id").eq(
        "id",
        user.id,
      ).single();
      const staffId = userRow?.linked_id;
      let assigned: unknown[] = [];
      if (staffId) {
        const [
          staffSubjectsResult,
          classTeacherSectionsResult,
          coTeacherSectionsResult,
          gradeSubjectsResult,
          allStaffSubjectsResult,
          timetableSlotsResult,
        ] = await Promise.all([
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
          svc.from("grade_subjects").select(
            "*, subject:subjects(*)",
          ).eq("school_id", school),
          svc.from("staff_subjects").select(
            "*, subject:subjects(*)",
          ).eq("school_id", school),
          svc.from("timetable_slots").select(
            "*, subject:subjects(*)",
          ).eq("school_id", school),
        ]);
        assigned = buildTeacherAssignments(
          (staffSubjectsResult.data ?? []) as Array<Record<string, unknown>>,
          (classTeacherSectionsResult.data ?? []) as Array<
            Record<string, unknown>
          >,
          (coTeacherSectionsResult.data ?? []) as Array<
            Record<string, unknown>
          >,
          (gradeSubjectsResult.data ?? []) as Array<
            Record<string, unknown>
          >,
          (allStaffSubjectsResult.data ?? []) as Array<
            Record<string, unknown>
          >,
          (timetableSlotsResult.data ?? []) as Array<
            Record<string, unknown>
          >,
        );
      }
      return ok({ ...base, assigned_classes: assigned, staff_id: staffId });
    }

    if (dashRole === "parent") {
      const { data: links } = await svc.from("parent_student_links").select(
        "student:students(*, section:sections(*, grade:grades(*)))",
      ).eq("parent_user_id", user.id);
      return ok({
        ...base,
        children: (links ?? []).map((l: Record<string, unknown>) => l.student),
      });
    }

    if (dashRole === "super_admin") {
      // Super admin dashboard: system-level metrics + base school data.
      const [errorEvents, auditLogs] = await Promise.all([
        svc.from("error_events").select("id", { count: "exact", head: true })
          .eq("school_id", school).eq("status", "open"),
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

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
    const existing = assignments.get(sectionId) ?? {
      id: sectionId,
      section_id: sectionId,
      grade_id: text(section?.grade_id ?? fallback.grade_id),
      grade_name: text(grade?.grade_name ?? fallback.grade_name),
      section_name: text(section?.section_name ?? fallback.section_name),
      subject_id: "",
      subject_name: "",
      teacher_role: role,
      is_class_teacher: false,
      is_co_teacher: false,
      subjects: [] as Array<Record<string, unknown>>,
    };
    assignments.set(sectionId, existing);
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

  return [...assignments.values()];
}

export async function handleDashboard(
  req: Request,
  path: string,
  method: string,
  url: URL,
  client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const role = (user.app_metadata?.role_name as string ?? "").toLowerCase();
  const dashRole = url.searchParams.get("role") ?? role;

  if (path === "/dashboard" || path.startsWith("/dashboard")) {
    const [students, staff, invoices, announcements, sections, pendingLeave] =
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
      ]);

    const totalOutstanding = (invoices.data ?? []).reduce(
      (s: number, i: Record<string, number>) => s + (i.balance ?? 0),
      0,
    );

    const base = {
      total_students: students.count ?? 0,
      total_staff: staff.count ?? 0,
      total_sections: sections.count ?? 0,
      pending_fee_balance: totalOutstanding,
      pending_leave_requests: pendingLeave.count ?? 0,
      recent_announcements: announcements.data ?? [],
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
        ]);
        assigned = buildTeacherAssignments(
          (staffSubjectsResult.data ?? []) as Array<Record<string, unknown>>,
          (classTeacherSectionsResult.data ?? []) as Array<
            Record<string, unknown>
          >,
          (coTeacherSectionsResult.data ?? []) as Array<
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

    return ok(base);
  }

  return fail("not found", 404);
}

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export type TeacherSectionScope = {
  id: string;
  gradeId: string;
  academicYearId: string;
  isClassTeacher: boolean;
  isCoTeacher: boolean;
  subjectIds: Set<string>;
};

export type TeacherScope = {
  staffId: string;
  isActive: boolean;
  sections: Map<string, TeacherSectionScope>;
};

function text(value: unknown): string {
  return `${value ?? ""}`.trim();
}

/**
 * Resolves the active teacher's complete operational scope from the canonical
 * section assignments and staff-subject mappings.  This deliberately does not
 * trust a client-supplied section, subject, or staff identifier.
 */
export async function resolveActiveTeacherScope(
  svc: SupabaseClient,
  school: string,
  staffId: string,
): Promise<TeacherScope> {
  const normalizedStaffId = text(staffId);
  const empty = (): TeacherScope => ({
    staffId: normalizedStaffId,
    isActive: false,
    sections: new Map(),
  });
  if (!school || !normalizedStaffId) return empty();

  const [staffResult, sectionsResult, subjectResult] = await Promise.all([
    svc.from("staff").select("id").eq("school_id", school).eq(
      "id",
      normalizedStaffId,
    ).eq("is_active", true).maybeSingle(),
    svc.from("sections").select(
      "id, grade_id, academic_year_id, class_teacher_id, co_teacher_id",
    ).eq("school_id", school),
    svc.from("staff_subjects").select(
      "section_id, grade_id, academic_year_id, subject_id",
    ).eq("school_id", school).eq("staff_id", normalizedStaffId),
  ]);
  if (staffResult.error) throw new Error(staffResult.error.message);
  if (sectionsResult.error) throw new Error(sectionsResult.error.message);
  if (subjectResult.error) throw new Error(subjectResult.error.message);
  if (!staffResult.data) return empty();

  const sections = (sectionsResult.data ?? []).map((row) => ({
    id: text(row.id),
    gradeId: text(row.grade_id),
    academicYearId: text(row.academic_year_id),
    isClassTeacher: text(row.class_teacher_id) === normalizedStaffId,
    isCoTeacher: text(row.co_teacher_id) === normalizedStaffId,
  })).filter((section) => section.id);
  const scoped = new Map<string, TeacherSectionScope>();
  const ensure = (section: typeof sections[number]) => {
    const existing = scoped.get(section.id);
    if (existing) return existing;
    const next: TeacherSectionScope = {
      id: section.id,
      gradeId: section.gradeId,
      academicYearId: section.academicYearId,
      isClassTeacher: section.isClassTeacher,
      isCoTeacher: section.isCoTeacher,
      subjectIds: new Set(),
    };
    scoped.set(section.id, next);
    return next;
  };

  for (const section of sections) {
    if (section.isClassTeacher || section.isCoTeacher) ensure(section);
  }

  for (const assignment of subjectResult.data ?? []) {
    const assignmentSectionId = text(assignment.section_id);
    const assignmentGradeId = text(assignment.grade_id);
    const assignmentYearId = text(assignment.academic_year_id);
    const subjectId = text(assignment.subject_id);
    if (!subjectId) continue;
    for (const section of sections) {
      const directMatch = assignmentSectionId === section.id;
      const gradeMatch = !assignmentSectionId && assignmentGradeId &&
        assignmentGradeId === section.gradeId;
      if (!directMatch && !gradeMatch) continue;
      if (assignmentYearId && assignmentYearId !== section.academicYearId) {
        continue;
      }
      ensure(section).subjectIds.add(subjectId);
    }
  }

  return { staffId: normalizedStaffId, isActive: true, sections: scoped };
}

export async function teacherCanUseSection(
  svc: SupabaseClient,
  school: string,
  staffId: string,
  sectionId: string,
): Promise<boolean> {
  const scope = await resolveActiveTeacherScope(svc, school, staffId);
  return scope.sections.has(text(sectionId));
}

/**
 * Class and co-teachers may use every mapped subject in their section. A
 * subject-only teacher must be assigned to the requested subject.
 */
export async function teacherCanUseSubject(
  svc: SupabaseClient,
  school: string,
  staffId: string,
  sectionId: string,
  subjectId: string,
): Promise<boolean> {
  const scope = await resolveActiveTeacherScope(svc, school, staffId);
  const section = scope.sections.get(text(sectionId));
  if (!section) return false;
  if (section.isClassTeacher || section.isCoTeacher) return true;
  return section.subjectIds.has(text(subjectId));
}

export async function teacherCanAccessStudent(
  svc: SupabaseClient,
  school: string,
  staffId: string,
  studentId: string,
): Promise<boolean> {
  const id = text(studentId);
  if (!id) return false;
  const { data, error } = await svc.from("students").select(
    "current_section_id",
  ).eq("school_id", school).eq("id", id).maybeSingle();
  if (error) throw new Error(error.message);
  return teacherCanUseSection(svc, school, staffId, text(data?.current_section_id));
}

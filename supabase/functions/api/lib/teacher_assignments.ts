/**
 * Pure assignment projection shared by web contract tests and teacher-facing
 * consumers.  The source rows are already school-scoped by the caller; this
 * helper only merges subject, class-teacher, and co-teacher relationships.
 */
export function buildTeacherAssignments(
  subjectRows: Array<Record<string, any>>,
  classTeacherSections: Array<Record<string, any>>,
  coTeacherSections: Array<Record<string, any>>,
  gradeSubjects: Array<Record<string, any>>,
): Array<Record<string, any>> {
  const assignments = new Map<string, Record<string, any>>();
  const text = (value: unknown): string => `${value ?? ""}`.trim();
  const sectionValue = (row: Record<string, any>) =>
    (row.section && typeof row.section === "object" ? row.section : row);

  const ensure = (row: Record<string, any>, role: string) => {
    const section = sectionValue(row);
    const id = text(section.id ?? row.section_id);
    if (!id) return null;
    let entry = assignments.get(id);
    if (!entry) {
      const grade = section.grade && typeof section.grade === "object"
        ? section.grade
        : row.grade;
      entry = {
        id,
        section_id: id,
        grade_id: text(section.grade_id ?? row.grade_id),
        grade_name: text(grade?.grade_name),
        section_name: text(section.section_name),
        subject_id: "",
        subject_name: "",
        teacher_role: role,
        is_class_teacher: false,
        is_co_teacher: false,
        subjects: [],
      };
      assignments.set(id, entry);
    }
    return entry;
  };

  for (const row of subjectRows) {
    const entry = ensure(row, "subject_teacher");
    if (!entry) continue;
    const subject = row.subject && typeof row.subject === "object"
      ? row.subject
      : row;
    const id = text(subject.id ?? row.subject_id);
    const name = text(subject.subject_name ?? row.subject_name);
    if (id && !(entry.subjects as any[]).some((item) => text(item.id) === id)) {
      (entry.subjects as any[]).push({ id, subject_id: id, subject_name: name });
    }
    if (id && !text(entry.subject_id)) entry.subject_id = id;
    if (name && !text(entry.subject_name)) entry.subject_name = name;
  }

  for (const section of classTeacherSections) {
    const entry = ensure(section, "class_teacher");
    if (!entry) continue;
    entry.is_class_teacher = true;
    entry.teacher_role = "class_teacher";
    if (!text(entry.subject_name)) entry.subject_name = "Class Teacher";
  }
  for (const section of coTeacherSections) {
    const entry = ensure(section, "co_teacher");
    if (!entry) continue;
    entry.is_co_teacher = true;
    if (!entry.is_class_teacher) entry.teacher_role = "co_teacher";
    if (!text(entry.subject_name)) entry.subject_name = "Co-Teacher";
  }

  for (const entry of assignments.values()) {
    if (!entry.is_class_teacher && !entry.is_co_teacher) continue;
    const subjects = entry.subjects as any[];
    subjects.length = 0;
    for (const row of gradeSubjects) {
      const rowSection = text(row.section_id);
      const rowGrade = text(row.grade_id);
      if (rowSection && rowSection !== text(entry.section_id)) continue;
      if (!rowSection && rowGrade && rowGrade !== text(entry.grade_id)) continue;
      const subject = row.subject && typeof row.subject === "object"
        ? row.subject
        : row;
      const id = text(subject.id ?? row.subject_id);
      if (!id || subjects.some((item) => text(item.id) === id)) continue;
      subjects.push({
        id,
        subject_id: id,
        subject_name: text(subject.subject_name ?? row.subject_name),
      });
    }
  }
  return [...assignments.values()];
}

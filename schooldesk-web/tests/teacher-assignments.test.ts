import { expect, test } from "bun:test";
import { buildTeacherAssignments } from "../../supabase/functions/api/lib/teacher_assignments";

test("teacher scope keeps class teacher, co-teacher, and mixed section roles", () => {
  const rows = buildTeacherAssignments(
    [
      {
        id: "subject-row-1",
        section_id: "section-mixed",
        section: {
          id: "section-mixed",
          section_name: "A",
          grade_id: "grade-1",
          grade: { grade_name: "Play Group" },
        },
        subject_id: "subject-1",
        subject: { id: "subject-1", subject_name: "Language" },
      },
    ],
    [
      {
        id: "section-class",
        grade_id: "grade-1",
        section_name: "A",
        grade: { grade_name: "Nursery" },
      },
      {
        id: "section-mixed",
        grade_id: "grade-1",
        section_name: "A",
        grade: { grade_name: "Play Group" },
      },
    ],
    [
      {
        id: "section-co",
        grade_id: "grade-2",
        section_name: "B",
        grade: { grade_name: "LKG" },
      },
      {
        id: "section-mixed",
        grade_id: "grade-1",
        section_name: "A",
        grade: { grade_name: "Play Group" },
      },
    ],
    [
      {
        section_id: "section-mixed",
        grade_id: "grade-1",
        subject_id: "subject-1",
        subject: { id: "subject-1", subject_name: "Language" },
      },
    ],
  );

  expect(rows).toHaveLength(3);
  expect(rows.map((row) => row.section_id)).toEqual([
    "section-mixed",
    "section-class",
    "section-co",
  ]);

  const mixed = rows.find((row) => row.section_id === "section-mixed");
  expect(mixed?.is_class_teacher).toBe(true);
  expect(mixed?.is_co_teacher).toBe(true);
  expect(mixed?.teacher_role).toBe("class_teacher");

  const classOnly = rows.find((row) => row.section_id === "section-class");
  expect(classOnly?.is_class_teacher).toBe(true);
  expect(classOnly?.is_co_teacher).toBe(false);

  const coOnly = rows.find((row) => row.section_id === "section-co");
  expect(coOnly?.is_class_teacher).toBe(false);
  expect(coOnly?.is_co_teacher).toBe(true);
  expect(coOnly?.teacher_role).toBe("co_teacher");
});

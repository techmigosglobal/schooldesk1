"use client";

import { useEffect, useMemo, useState } from "react";
import { teacherSchema } from "@/lib/schemas";
import type { Row } from "./types";
import { api, stringValue, splitName, displayName, nested } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

type AssignmentRole = "" | "class_teacher" | "co_teacher";

function sectionId(row: Row) {
  return stringValue(row.section_id ?? row.id);
}

function sectionLabel(row: Row) {
  const grade = nested(row, "grade");
  const gradeName = stringValue(row.grade_name ?? grade.grade_name ?? grade.name);
  const name = stringValue(row.section_name ?? row.name);
  return [gradeName, name].filter(Boolean).join(" - ") || "Class section";
}

function assignedStaffId(row: Row, key: "class_teacher" | "co_teacher") {
  const directKey = `${key}_id`;
  return stringValue(row[directKey] ?? nested(row, key).id ?? nested(row, key).staff_code);
}

function matchesStaff(value: string, row?: Row, savedId = "") {
  return [savedId, stringValue(row?.id), stringValue(row?.staff_code)]
    .filter(Boolean)
    .includes(value);
}

function initialRole(row: Row, teacher?: Row): AssignmentRole {
  const teacherId = stringValue(teacher?.id);
  const staffCode = stringValue(teacher?.staff_code);
  const classTeacher = assignedStaffId(row, "class_teacher");
  const coTeacher = assignedStaffId(row, "co_teacher");
  if (classTeacher && [teacherId, staffCode].filter(Boolean).includes(classTeacher)) {
    return "class_teacher";
  }
  if (coTeacher && [teacherId, staffCode].filter(Boolean).includes(coTeacher)) {
    return "co_teacher";
  }
  return "";
}

function classUpdatePayload(
  row: Row,
  classTeacherId: string | null,
  coTeacherId: string | null,
) {
  const grade = nested(row, "grade");
  const academicYear = nested(row, "academic_year");
  const room = nested(row, "room");
  return {
    academic_year_id: stringValue(row.academic_year_id ?? academicYear.id) || undefined,
    grade_name: stringValue(row.grade_name ?? grade.grade_name ?? grade.name),
    grade_number: Number(row.grade_number ?? grade.grade_number ?? 1),
    section_name: stringValue(row.section_name ?? row.name),
    capacity: Number(row.capacity || 30),
    room_number: stringValue(row.room_number ?? room.room_number) || null,
    class_teacher_id: classTeacherId,
    co_teacher_id: coTeacherId,
  };
}

export function TeacherDialog({
  row,
  classes = [],
  readOnly,
  onClose,
  onSaved,
}: {
  row?: Row;
  classes?: Row[];
  readOnly?: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [designation, setDesignation] = useState(
    stringValue(row?.designation) || "Teacher"
  );
  const initialAssignments = useMemo(
    () => Object.fromEntries(
      classes
        .map((item) => [sectionId(item), initialRole(item, row)] as const)
        .filter(([id]) => Boolean(id)),
    ) as Record<string, AssignmentRole>,
    [classes, row],
  );
  const [classAssignments, setClassAssignments] = useState<Record<string, AssignmentRole>>(
    initialAssignments,
  );

  useEffect(() => {
    setClassAssignments(initialAssignments);
  }, [initialAssignments]);

  async function submit(form: FormData) {
    if (readOnly || saving) return;
    setSaving(true);
    setError("");
    try {
      const parsed = teacherSchema.safeParse({
        full_name: stringValue(form.get("full_name")),
        username: stringValue(form.get("username")),
        designation:
          designation === "Custom"
            ? stringValue(form.get("custom_designation"))
            : designation,
        staff_code: stringValue(form.get("staff_code")),
        phone: stringValue(form.get("phone")),
        email: stringValue(form.get("email")),
        password: stringValue(form.get("password")),
        account_role: stringValue(form.get("account_role")) || "Teacher",
      });
      if (!parsed.success) {
        throw new Error(
          parsed.error.issues[0]?.message || "Please complete the staff form."
        );
      }

      const payload: Row = {
        ...splitName(parsed.data.full_name),
        staff_code: parsed.data.staff_code,
        username: parsed.data.username,
        email: parsed.data.email,
        phone: parsed.data.phone,
        designation: parsed.data.designation,
        account_role: parsed.data.account_role || "Teacher",
        gender: "unspecified",
        request_principal_approval: false,
      };

      if (parsed.data.password) payload.password = parsed.data.password;

      const saved = (await api(row ? `staff/${row.id}` : "staff", {
        method: row ? "PUT" : "POST",
        body: JSON.stringify(payload),
      })) as Row;

      const savedId = stringValue(saved.id ?? row?.id);
      if (savedId) {
        await Promise.all(
          classes.flatMap((item) => {
            const id = sectionId(item);
            if (!id) return [];

            const currentClassTeacherId = assignedStaffId(item, "class_teacher");
            const currentCoTeacherId = assignedStaffId(item, "co_teacher");
            const currentClassIsThis = matchesStaff(currentClassTeacherId, row, savedId);
            const currentCoIsThis = matchesStaff(currentCoTeacherId, row, savedId);
            const selectedRole = classAssignments[id] || "";
            let nextClassTeacherId = currentClassTeacherId;
            let nextCoTeacherId = currentCoTeacherId;

            if (selectedRole === "class_teacher") {
              nextClassTeacherId = savedId;
              if (currentCoIsThis) nextCoTeacherId = "";
            } else if (selectedRole === "co_teacher") {
              nextCoTeacherId = savedId;
              if (currentClassIsThis) nextClassTeacherId = "";
            } else {
              if (currentClassIsThis) nextClassTeacherId = "";
              if (currentCoIsThis) nextCoTeacherId = "";
            }

            if (
              nextClassTeacherId === currentClassTeacherId &&
              nextCoTeacherId === currentCoTeacherId
            ) {
              return [];
            }

            return [api(`principal/classes/${id}`, {
              method: "PUT",
              body: JSON.stringify(
                classUpdatePayload(
                  item,
                  nextClassTeacherId || null,
                  nextCoTeacherId || null,
                ),
              ),
            })];
          }),
        );
      }

      onSaved();
      onClose();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to save teacher");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Dialog
      kicker="Staff account"
      title={
        readOnly
          ? "Staff details"
          : row
            ? "Update staff member"
            : "Add teacher or coordinator"
      }
      onClose={onClose}
    >
      <form
        className="ops-detail-form"
        aria-busy={saving}
        onSubmit={(event) => {
          event.preventDefault();
          if (saving) return;
          void submit(new FormData(event.currentTarget));
        }}
      >
        <div className="form-grid">
          <label className="field">
            Full name
            <input
              name="full_name"
              required
              readOnly={readOnly}
              defaultValue={row ? displayName(row) : ""}
            />
          </label>
          <label className="field">
            Employee ID <small>(optional)</small>
            <input
              name="staff_code"
              readOnly={readOnly}
              defaultValue={stringValue(row?.staff_code)}
            />
          </label>
          <label className="field">
            Designation
            <select
              disabled={readOnly}
              value={designation}
              onChange={(e) => setDesignation(e.target.value)}
            >
              <option>Teacher</option>
              <option>Co Teacher</option>
              <option>Coordinator</option>
              <option>Custom</option>
            </select>
          </label>
          {designation === "Custom" && (
            <label className="field">
              Custom designation
              <input
                name="custom_designation"
                required
                readOnly={readOnly}
                defaultValue={stringValue(row?.designation)}
              />
            </label>
          )}
          <label className="field">
            Phone <small>(optional)</small>
            <input
              name="phone"
              readOnly={readOnly}
              defaultValue={stringValue(row?.phone)}
            />
          </label>
          <label className="field">
            Email <small>(optional)</small>
            <input
              name="email"
              type="email"
              readOnly={readOnly}
              defaultValue={stringValue(row?.email)}
            />
          </label>
          <label className="field">
            Login username
            <input
              name="username"
              required
              readOnly={readOnly}
              defaultValue={stringValue(row?.username)}
            />
          </label>
          {!row && (
            <label className="field">
              Login role
              <select name="account_role" disabled={readOnly} defaultValue="Teacher">
                <option value="Teacher">Teacher</option>
                <option value="Coordinator">Coordinator</option>
              </select>
            </label>
          )}
          {!readOnly && (
            <label className="field">
              {row ? "New password (optional)" : "Temporary password"}
              <input
                name="password"
                type="password"
                minLength={8}
                required={!row}
              />
            </label>
          )}
        </div>

        <fieldset className="staff-class-assignment" disabled={readOnly}>
          <legend>Class / section assignments</legend>
          <p>
            Each row is one available section, not a duplicate teacher record.
            Every section supports one class teacher and one different
            co-teacher. Select only the section(s) this educator should access;
            leave all other rows as No assignment.
          </p>
          {classes.length ? (
            <div className="staff-class-assignment-list">
              {classes.map((item) => {
                const id = sectionId(item);
                return (
                  <label className="staff-class-assignment-row" key={id}>
                    <span>{sectionLabel(item)}</span>
                    <select
                      aria-label={`Assignment for ${sectionLabel(item)}`}
                      value={classAssignments[id] || ""}
                      onChange={(event) => {
                        const value = event.target.value as AssignmentRole;
                        setClassAssignments((current) => ({ ...current, [id]: value }));
                      }}
                    >
                      <option value="">No assignment</option>
                      <option value="class_teacher">Class teacher</option>
                      <option value="co_teacher">Co-teacher</option>
                    </select>
                  </label>
                );
              })}
            </div>
          ) : (
            <span className="staff-class-assignment-empty">Create a class section first to assign this educator.</span>
          )}
        </fieldset>

        {error && <p className="form-error">{error}</p>}

        {readOnly ? (
          <div className="dialog-footer">
            <button className="secondary-button" type="button" onClick={onClose}>
              Close
            </button>
          </div>
        ) : (
          <FormActions
            saving={saving}
            onClose={onClose}
            label={row ? "Update staff" : "Create staff account"}
          />
        )}
      </form>
    </Dialog>
  );
}

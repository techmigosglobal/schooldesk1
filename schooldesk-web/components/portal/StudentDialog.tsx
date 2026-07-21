"use client";

import { useEffect, useState } from "react";
import { studentSchema } from "@/lib/schemas";
import type { Row } from "./types";
import { api, rowsFrom, rowText, stringValue, splitName, displayName } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

export function StudentDialog({
  row,
  readOnly,
  onClose,
  onSaved,
}: {
  row?: Row;
  readOnly?: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [refs, setRefs] = useState<{ sections: Row[]; parents: Row[] }>({
    sections: [],
    parents: [],
  });
  const [createParent, setCreateParent] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    void Promise.all([
      api("sections?page=1&page_size=100"),
      api("users?role=parent&page=1&page_size=100"),
    ])
      .then(([sections, parents]) =>
        setRefs({ sections: rowsFrom(sections), parents: rowsFrom(parents) })
      )
      .catch((event) =>
        setError(
          event instanceof Error ? event.message : "Unable to load classes and parents"
        )
      );
  }, []);

  async function submit(form: FormData) {
    if (readOnly) return;
    setSaving(true);
    setError("");
    try {
      const fullName = stringValue(form.get("student_name"));
      const validated = studentSchema.safeParse({
        student_name: fullName,
        current_section_id: stringValue(form.get("current_section_id")),
        student_id_number: stringValue(form.get("student_id_number")),
        date_of_birth: stringValue(form.get("date_of_birth")),
        gender: stringValue(form.get("gender")),
        admission_number: stringValue(form.get("admission_number")),
        admission_date:
          stringValue(form.get("admission_date")) ||
          new Date().toISOString().slice(0, 10),
        parent_user_id: stringValue(form.get("parent_user_id")),
      });

      if (!validated.success) {
        throw new Error(
          validated.error.issues[0]?.message || "Please complete the student form."
        );
      }

      const payload: Row = {
        ...splitName(validated.data.student_name),
        date_of_birth: validated.data.date_of_birth,
        gender: validated.data.gender,
        student_id_number: validated.data.student_id_number,
        current_section_id: validated.data.current_section_id,
        admission_number: validated.data.admission_number,
        admission_date: validated.data.admission_date,
        status: "active",
      };

      const saved = (await api(row ? `students/${row.id}` : "students", {
        method: row ? "PUT" : "POST",
        body: JSON.stringify(payload),
      })) as Row;

      const studentId = stringValue(saved.id || row?.id);
      let parentId = stringValue(form.get("parent_user_id"));

      if (createParent) {
        const password = stringValue(form.get("parent_password"));
        if (password.length < 8) {
          throw new Error("Parent login password must be at least 8 characters.");
        }
        const parent = (await api("users", {
          method: "POST",
          body: JSON.stringify({
            name: stringValue(form.get("parent_name")),
            username: stringValue(form.get("parent_username")),
            password,
            role: "Parent",
            email: stringValue(form.get("parent_email")),
            phone: stringValue(form.get("parent_phone")),
            is_active: true,
          }),
        })) as Row;
        parentId = stringValue(parent.id);
      }

      if (studentId && parentId) {
        await api(`students/${studentId}/parent`, {
          method: "PUT",
          body: JSON.stringify({ parent_user_id: parentId }),
        });
      }

      onSaved();
      onClose();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to save student");
    } finally {
      setSaving(false);
    }
  }

  const initialName = row ? displayName(row) : "";

  return (
    <Dialog
      kicker="Student record"
      title={readOnly ? "Student details" : row ? "Update student" : "Add student"}
      onClose={onClose}
    >
      <form action={submit} className="ops-detail-form">
        <div className="form-grid">
          <label className="field">
            Student name
            <input
              name="student_name"
              required
              readOnly={readOnly}
              defaultValue={initialName}
            />
          </label>
          <label className="field">
            Class / section
            <select
              name="current_section_id"
              disabled={readOnly}
              defaultValue={stringValue(row?.current_section_id)}
              required
            >
              <option value="">Select section</option>
              {refs.sections.map((item) => (
                <option key={stringValue(item.id)} value={stringValue(item.id)}>
                  {rowText(item, "grade_name")} · {stringValue(item.section_name ?? item.name)}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            Student ID
            <input
              name="student_id_number"
              required
              readOnly={readOnly}
              defaultValue={stringValue(row?.student_id_number)}
            />
          </label>
          <label className="field">
            Date of birth
            <input
              name="date_of_birth"
              type="date"
              required
              readOnly={readOnly}
              defaultValue={stringValue(row?.date_of_birth).slice(0, 10)}
            />
          </label>
          <label className="field">
            Gender
            <select
              name="gender"
              disabled={readOnly}
              defaultValue={stringValue(row?.gender) || "male"}
            >
              <option value="male">Male</option>
              <option value="female">Female</option>
              <option value="other">Other</option>
            </select>
          </label>
          <label className="field">
            Admission number <small>(optional)</small>
            <input
              name="admission_number"
              readOnly={readOnly}
              defaultValue={stringValue(row?.admission_number)}
            />
          </label>
          <label className="field">
            Admission date
            <input
              name="admission_date"
              type="date"
              readOnly={readOnly}
              defaultValue={stringValue(row?.admission_date).slice(0, 10)}
            />
          </label>
          <label className="field">
            Linked parent account
            <select
              name="parent_user_id"
              disabled={readOnly || createParent}
              defaultValue={stringValue(row?.parent_user_id)}
            >
              <option value="">Link later</option>
              {refs.parents.map((item) => (
                <option key={stringValue(item.id)} value={stringValue(item.id)}>
                  {stringValue(item.name) || stringValue(item.username)}
                  {item.username ? ` · ${item.username}` : ""}
                </option>
              ))}
            </select>
          </label>
        </div>

        {!readOnly && !row && (
          <label className="check-field">
            <input
              checked={createParent}
              onChange={(e) => setCreateParent(e.target.checked)}
              type="checkbox"
            />
            Create parent login with password
          </label>
        )}

        {createParent && !readOnly && (
          <div className="parent-login-box">
            <b>Parent portal account</b>
            <div className="form-grid">
              <label className="field">
                Parent name
                <input name="parent_name" required />
              </label>
              <label className="field">
                Parent login username
                <input name="parent_username" required />
              </label>
              <label className="field">
                Parent login password
                <input name="parent_password" type="password" minLength={8} required />
              </label>
              <label className="field">
                Parent email <small>(optional)</small>
                <input name="parent_email" type="email" />
              </label>
              <label className="field">
                Parent phone <small>(optional)</small>
                <input name="parent_phone" />
              </label>
            </div>
          </div>
        )}

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
            label={row ? "Update student" : "Create student"}
          />
        )}
      </form>
    </Dialog>
  );
}

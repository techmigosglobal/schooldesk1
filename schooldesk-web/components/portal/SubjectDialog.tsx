"use client";

import { useState } from "react";
import type { Row } from "./types";
import { api, stringValue } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

export function SubjectDialog({
  row,
  onClose,
  onSaved,
}: {
  row?: Row;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function submit(form: FormData) {
    if (saving) return;
    setSaving(true);
    setError("");
    try {
      const subjectName = stringValue(form.get("subject_name"));
      const subjectCode = stringValue(form.get("subject_code")).toUpperCase();
      const departmentName = stringValue(form.get("department_name"));
      const subjectType = stringValue(form.get("subject_type")) || "core";

      if (!subjectName) throw new Error("Subject name is required.");

      const payload = {
        subject_name: subjectName,
        subject_code: subjectCode || null,
        department_name: departmentName || null,
        subject_type: subjectType,
      };

      if (row?.id) {
        await api(`subjects/${stringValue(row.id)}`, { method: "PUT", body: JSON.stringify(payload) });
      } else {
        await api("subjects", { method: "POST", body: JSON.stringify(payload) });
      }

      onSaved();
      onClose();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to save subject");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Dialog kicker="Curriculum" title={row ? "Edit subject" : "Add new subject"} onClose={onClose}>
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
            Subject name
            <input name="subject_name" required defaultValue={stringValue(row?.subject_name)} placeholder="e.g. Mathematics" />
          </label>
          <label className="field">
            Subject code <small>(optional)</small>
            <input name="subject_code" defaultValue={stringValue(row?.subject_code)} placeholder="e.g. MATH" />
          </label>
          <label className="field">
            Department <small>(optional)</small>
            <input name="department_name" defaultValue={stringValue(row?.department_name)} placeholder="e.g. Academics" />
          </label>
          <label className="field">
            Subject type
            <select name="subject_type" defaultValue={stringValue(row?.subject_type) || "core"}>
              <option value="core">Core Subject</option>
              <option value="elective">Elective</option>
              <option value="activity">Activity / Co-Curricular</option>
            </select>
          </label>
        </div>

        {error && <p className="form-error">{error}</p>}

        <FormActions saving={saving} onClose={onClose} label={row ? "Update subject" : "Create subject"} />
      </form>
    </Dialog>
  );
}

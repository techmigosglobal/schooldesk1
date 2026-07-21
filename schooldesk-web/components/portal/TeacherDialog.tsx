"use client";

import { useState } from "react";
import { teacherSchema } from "@/lib/schemas";
import type { Row } from "./types";
import { api, stringValue, splitName, displayName } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

export function TeacherDialog({
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
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [designation, setDesignation] = useState(
    stringValue(row?.designation) || "Teacher"
  );

  async function submit(form: FormData) {
    if (readOnly) return;
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

      await api(row ? `staff/${row.id}` : "staff", {
        method: row ? "PUT" : "POST",
        body: JSON.stringify(payload),
      });

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
      <form action={submit} className="ops-detail-form">
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

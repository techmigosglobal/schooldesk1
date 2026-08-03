"use client";

import { useEffect, useState } from "react";
import type { Row } from "./types";
import { api, rowsFrom, rowText, stringValue, displayName, nested } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

export function ParentDialog({
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
  const [students, setStudents] = useState<Row[]>([]);
  const [linkedStudents, setLinkedStudents] = useState<Row[]>([]);

  useEffect(() => {
    void api("students?page=1&page_size=100")
      .then((res) => {
        const list = rowsFrom(res);
        setStudents(list);
        if (row?.id) {
          const parentId = stringValue(row.id);
          const matched = list.filter((st) => {
            if (stringValue(st.parent_user_id) === parentId) return true;
            const links = Array.isArray(st.parent_student_links)
              ? (st.parent_student_links as Row[])
              : [];
            return links.some((lnk) => {
              const pId = stringValue(lnk?.parent_user_id ?? nested(lnk ?? {}, "parent").id);
              return pId === parentId;
            });
          });
          setLinkedStudents(matched);
        }
      })
      .catch(() => setStudents([]));
  }, [row]);

  async function submit(form: FormData) {
    if (readOnly || saving) return;
    setSaving(true);
    setError("");
    try {
      const name = stringValue(form.get("name"));
      const username = stringValue(form.get("username")).toLowerCase();
      const email = stringValue(form.get("email"));
      const phone = stringValue(form.get("phone"));
      const password = stringValue(form.get("password"));
      const isActive = form.get("is_active") === "true";

      if (!name) throw new Error("Parent name is required.");
      if (!username) throw new Error("Parent username is required.");
      if (!row && password.length < 8) {
        throw new Error("Password must be at least 8 characters.");
      }

      if (row) {
        const patch: Row = {
          name,
          username,
          email: email || null,
          phone: phone || null,
          is_active: isActive,
        };
        if (password) patch.password = password;

        await api(`users/${row.id}`, {
          method: "PATCH",
          body: JSON.stringify(patch),
        });
      } else {
        await api("users", {
          method: "POST",
          body: JSON.stringify({
            name,
            username,
            password,
            role: "Parent",
            email: email || null,
            phone: phone || null,
            is_active: isActive,
          }),
        });
      }

      onSaved();
      onClose();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to save parent record");
    } finally {
      setSaving(false);
    }
  }

  const initialName = stringValue(row?.name || row?.username || "");
  const initialUsername = stringValue(row?.username);

  return (
    <Dialog
      kicker="Parent account"
      title={readOnly ? "Parent profile details" : row ? "Update parent account" : "Register parent account"}
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
            Parent name
            <input
              name="name"
              required
              readOnly={readOnly}
              defaultValue={initialName}
              placeholder="e.g. Rajesh Sharma"
            />
          </label>
          <label className="field">
            Username
            <input
              name="username"
              required
              readOnly={readOnly}
              defaultValue={initialUsername}
              placeholder="e.g. rajesh_sharma"
            />
          </label>
          <label className="field">
            Phone contact
            <input
              name="phone"
              readOnly={readOnly}
              defaultValue={stringValue(row?.phone)}
              placeholder="e.g. +91 9876543210"
            />
          </label>
          <label className="field">
            Email address
            <input
              name="email"
              type="email"
              readOnly={readOnly}
              defaultValue={stringValue(row?.email)}
              placeholder="e.g. parent@example.com"
            />
          </label>
          <label className="field">
            Account status
            <select
              name="is_active"
              disabled={readOnly}
              defaultValue={row?.is_active === false ? "false" : "true"}
            >
              <option value="true">Active account</option>
              <option value="false">Inactive account</option>
            </select>
          </label>
          {!readOnly && (
            <label className="field">
              {row ? "New password (optional)" : "Temporary login password"}
              <input
                name="password"
                type="password"
                minLength={8}
                required={!row}
                placeholder={row ? "Leave blank to keep current" : "Min 8 characters"}
              />
            </label>
          )}
        </div>

        {linkedStudents.length > 0 && (
          <div className="parent-linked-students-box" style={{ padding: "0.85rem", background: "#f5fbf6", border: "1px solid #d4ebda", borderRadius: "12px", marginTop: "0.5rem" }}>
            <b style={{ display: "block", color: "#1f522e", marginBottom: "0.4rem", fontSize: "0.82rem" }}>
              Linked Children ({linkedStudents.length})
            </b>
            <div style={{ display: "flex", flexWrap: "wrap", gap: "0.5rem" }}>
              {linkedStudents.map((st) => (
                <span
                  key={stringValue(st.id)}
                  style={{
                    display: "inline-flex",
                    alignItems: "center",
                    gap: "0.4rem",
                    padding: "0.3rem 0.65rem",
                    background: "#fff",
                    border: "1px solid #b8dec0",
                    borderRadius: "20px",
                    fontSize: "0.78rem",
                    fontWeight: 650,
                    color: "#184224",
                  }}
                >
                  <span style={{ width: "8px", height: "8px", borderRadius: "50%", background: "#259a47" }} />
                  {displayName(st)} (ID: {stringValue(st.student_id_number || st.id)})
                </span>
              ))}
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
            label={row ? "Update parent" : "Create parent account"}
          />
        )}
      </form>
    </Dialog>
  );
}

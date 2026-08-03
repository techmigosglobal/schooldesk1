"use client";

import { useState } from "react";
import type { Module, Row } from "./types";
import { api, stringValue } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

export function GenericDialog({
  module,
  row,
  readOnly,
  onClose,
  onSaved,
}: {
  module: Module;
  row?: Row;
  readOnly?: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function submit(form: FormData) {
    if (readOnly || saving) return;
    setSaving(true);
    setError("");
    const payload: Row = {};
    module.fields.forEach((field) => {
      const raw = form.get(field.key);
      payload[field.key] = field.type === "number" ? Number(raw || 0) : raw;
    });

    if (module.id === "parents") {
      payload.role = "Parent";
      payload.is_active = true;
    }

    try {
      await api(row ? `${module.create}/${row.id}` : module.create, {
        method: row ? "PUT" : "POST",
        body: JSON.stringify(payload),
      });
      onSaved();
      onClose();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Save failed");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Dialog
      kicker={module.label}
      title={
        readOnly
          ? "Record details"
          : row
            ? "Update record"
            : `Add ${module.label.toLowerCase()}`
      }
      onClose={onClose}
    >
      <form
        aria-busy={saving}
        onSubmit={(event) => {
          event.preventDefault();
          if (saving) return;
          void submit(new FormData(event.currentTarget));
        }}
      >
        {module.fields.map((field) => (
          <label className="field" key={field.key}>
            {field.label}
            {field.type === "textarea" ? (
              <textarea
                name={field.key}
                readOnly={readOnly}
                defaultValue={stringValue(row?.[field.key])}
              />
            ) : (
              <input
                required={
                  !readOnly &&
                  !["phone", "email", "password"].includes(field.key)
                }
                name={field.key}
                readOnly={readOnly}
                type={
                  field.type === "number"
                    ? "number"
                    : field.key === "password"
                      ? "password"
                      : "text"
                }
                defaultValue={stringValue(row?.[field.key])}
              />
            )}
          </label>
        ))}

        {error && <p className="form-error">{error}</p>}

        {readOnly ? (
          <div className="dialog-footer">
            <button className="secondary-button" type="button" onClick={onClose}>
              Close
            </button>
          </div>
        ) : (
          <FormActions saving={saving} onClose={onClose} />
        )}
      </form>
    </Dialog>
  );
}

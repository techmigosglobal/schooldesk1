"use client";

import { useState } from "react";
import { feeStructureSchema } from "@/lib/schemas";
import type { FeeState, Row } from "./types";
import { api, stringValue, rowText } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

export function FeeStructureDialog({
  refs,
  onClose,
  onSaved,
}: {
  refs: FeeState;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function submit(form: FormData) {
    setSaving(true);
    setError("");
    try {
      const payload = {
        academic_year_id: stringValue(form.get("academic_year_id")),
        grade_id: stringValue(form.get("grade_id")),
        section_id: stringValue(form.get("section_id")) || undefined,
        fee_category_id: stringValue(form.get("fee_category_id")),
        amount: Number(form.get("amount") || 0),
        frequency: stringValue(form.get("frequency")),
        due_day: Number(form.get("due_day") || 10),
        late_fine_per_day: Number(form.get("late_fine_per_day") || 0),
        replace_existing: Boolean(form.get("replace_existing")),
      };
      const parsed = feeStructureSchema.safeParse(payload);
      if (!parsed.success) {
        throw new Error(
          parsed.error.issues[0]?.message ||
            "Academic year, class, category, and a positive amount are required."
        );
      }

      const created = (await api("fees/structures", {
        method: "POST",
        body: JSON.stringify(parsed.data),
      })) as Row;

      if (created.id) {
        await api(`fees/structures/${created.id}/invoice-sync/apply`, {
          method: "POST",
        });
      }

      onSaved();
      onClose();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to save fee structure");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Dialog kicker="Fee structure" title="Configure fee structure" onClose={onClose}>
      <form action={submit} className="ops-detail-form">
        <div className="form-grid">
          <label className="field">
            Academic year
            <select name="academic_year_id" required>
              <option value="">Select academic year</option>
              {refs.years.map((item) => (
                <option key={stringValue(item.id)} value={stringValue(item.id)}>
                  {stringValue(item.name || item.year_name || item.id)}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            Class
            <select name="grade_id" required>
              <option value="">Select class</option>
              {refs.grades.map((item) => (
                <option key={stringValue(item.id)} value={stringValue(item.id)}>
                  {stringValue(item.grade_name || item.name)}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            Section <small>(optional — applies to all if blank)</small>
            <select name="section_id">
              <option value="">All sections</option>
              {refs.sections.map((item) => (
                <option key={stringValue(item.id)} value={stringValue(item.id)}>
                  {rowText(item, "grade_name")} · {stringValue(item.section_name || item.name)}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            Fee category
            <select name="fee_category_id" required>
              <option value="">Select category</option>
              {refs.categories.map((item) => (
                <option key={stringValue(item.id)} value={stringValue(item.id)}>
                  {stringValue(item.name)}
                </option>
              ))}
            </select>
          </label>
          <label className="field">
            Frequency
            <select name="frequency" defaultValue="monthly">
              <option value="one_time">One-time</option>
              <option value="yearly">Yearly</option>
              <option value="monthly">Monthly</option>
              <option value="term">Per term</option>
            </select>
          </label>
          <label className="field">
            Amount (₹)
            <input name="amount" type="number" min={1} required />
          </label>
          <label className="field">
            Due day of month
            <input name="due_day" type="number" min={1} max={31} defaultValue={10} required />
          </label>
          <label className="field">
            Late fine per day (₹)
            <input name="late_fine_per_day" type="number" min={0} defaultValue={0} />
          </label>
        </div>
        <label className="check-field">
          <input name="replace_existing" type="checkbox" /> Replace existing structures for this class and category
        </label>
        {error && <p className="form-error">{error}</p>}
        <FormActions saving={saving} onClose={onClose} label="Save & generate invoices" />
      </form>
    </Dialog>
  );
}

"use client";

import { useState } from "react";
import type { Row } from "./types";
import { api, stringValue, money, displayName, nested } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

export function ConcessionDialog({
  invoices,
  onClose,
  onSaved,
}: {
  invoices: Row[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [kind, setKind] = useState<"amount" | "percentage">("amount");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const pendingInvoices = invoices.filter(
    (row) => Number(row.balance ?? row.net_amount ?? 0) > 0
  );

  async function submit(form: FormData) {
    setSaving(true);
    setError("");
    try {
      const val = Number(form.get("value") || 0);
      const payload: Row = {
        invoice_id: stringValue(form.get("invoice_id")),
        reason: stringValue(form.get("reason")),
        [kind]: val,
      };

      if (!payload.invoice_id || !payload.reason || val <= 0) {
        throw new Error("Invoice, reason, and positive value are required.");
      }

      await api("fees/concessions", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      onSaved();
      onClose();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to grant concession");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Dialog kicker="Concession" title="Grant fee concession" onClose={onClose}>
      <form action={submit} className="ops-detail-form">
        <div className="form-grid">
          <label className="field">
            Select student invoice
            <select name="invoice_id" required defaultValue="">
              <option value="" disabled>
                Choose invoice
              </option>
              {pendingInvoices.map((item) => {
                const student = nested(item, "student");
                const bal = item.balance ?? item.net_amount;
                return (
                  <option key={stringValue(item.id)} value={stringValue(item.id)}>
                    {displayName(student)} · {stringValue(item.invoice_number)} · Due: {money(bal)}
                  </option>
                );
              })}
            </select>
          </label>
          <label className="field">
            Concession type
            <select
              value={kind}
              onChange={(e) => setKind(e.target.value as "amount" | "percentage")}
            >
              <option value="amount">Fixed Amount (₹)</option>
              <option value="percentage">Percentage (%)</option>
            </select>
          </label>
          <label className="field">
            {kind === "amount" ? "Discount amount (₹)" : "Discount percentage (%)"}
            <input
              name="value"
              type="number"
              min={1}
              max={kind === "percentage" ? 100 : undefined}
              required
            />
          </label>
          <label className="field">
            Reason / Category
            <input
              name="reason"
              placeholder="e.g. Sibling discount, Staff child, Merit"
              required
            />
          </label>
        </div>
        {error && <p className="form-error">{error}</p>}
        <FormActions saving={saving} onClose={onClose} label="Apply concession" />
      </form>
    </Dialog>
  );
}

"use client";

import { useState } from "react";
import { concessionSchema } from "@/lib/schemas";
import type { Row } from "./types";
import { api, stringValue, money, displayName, nested } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

export function ConcessionDialog({
  invoices,
  onClose,
  onSaved,
  preselectedInvoiceId,
}: {
  invoices: Row[];
  onClose: () => void;
  onSaved: () => void;
  preselectedInvoiceId?: string;
}) {
  const [kind, setKind] = useState<"amount" | "percentage">("amount");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const pendingInvoices = invoices.filter(
    (row) => Number(row.balance ?? row.net_amount ?? 0) > 0
  );

  async function submit(form: FormData) {
    if (saving) return;
    setSaving(true);
    setError("");
    try {
      const payload = {
        invoice_id: stringValue(form.get("invoice_id")),
        reason: stringValue(form.get("reason")),
        kind,
        value: Number(form.get("value") || 0),
      };
      const parsed = concessionSchema.safeParse(payload);
      if (!parsed.success) {
        throw new Error(
          parsed.error.issues[0]?.message || "Invoice, reason, and positive value are required."
        );
      }

      await api("fees/concessions", {
        method: "POST",
        body: JSON.stringify({
          invoice_id: parsed.data.invoice_id,
          reason: parsed.data.reason,
          [parsed.data.kind]: parsed.data.value,
        }),
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
          {preselectedInvoiceId ? (() => {
            const pre = invoices.find((i) => stringValue(i.id) === preselectedInvoiceId);
            return (
              <>
                <input type="hidden" name="invoice_id" value={preselectedInvoiceId} />
                <div className="field">
                  <span style={{ fontWeight: 650 }}>Student</span>
                  <span className="ops-chip">
                    {displayName(nested(pre ?? {}, "student"))} · {stringValue(pre?.invoice_number)} · Due: {money(pre?.balance ?? pre?.net_amount)}
                  </span>
                </div>
              </>
            );
          })() : (
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
          )}
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

"use client";

import { useState } from "react";
import type { Row } from "./types";
import { api, stringValue, money, displayName, nested } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

export function PaymentDialog({
  invoices,
  onClose,
  onSaved,
}: {
  invoices: Row[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const pendingInvoices = invoices.filter(
    (row) => Number(row.balance ?? row.net_amount ?? 0) > 0
  );

  async function submit(form: FormData) {
    setSaving(true);
    setError("");
    try {
      const payload = {
        invoice_id: stringValue(form.get("invoice_id")),
        receipt_number:
          stringValue(form.get("receipt_number")) || `RCP${Date.now()}`,
        amount_paid: Number(form.get("amount_paid") || 0),
        payment_date:
          stringValue(form.get("payment_date")) ||
          new Date().toISOString().slice(0, 10),
        payment_mode: stringValue(form.get("payment_mode")),
        transaction_id: stringValue(form.get("transaction_id")) || undefined,
      };

      if (!payload.invoice_id || payload.amount_paid <= 0) {
        throw new Error("Invoice and amount paid are required.");
      }

      await api("fees/payments", {
        method: "POST",
        body: JSON.stringify(payload),
      });

      onSaved();
      onClose();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to record payment");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Dialog kicker="Payment" title="Record fee payment" onClose={onClose}>
      <form action={submit} className="ops-detail-form">
        <div className="form-grid">
          <label className="field">
            Select pending invoice
            <select name="invoice_id" required defaultValue="">
              <option value="" disabled>
                Choose student invoice
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
            Receipt number
            <input
              name="receipt_number"
              defaultValue={`RCP${Date.now().toString().slice(-6)}`}
              required
            />
          </label>
          <label className="field">
            Amount paid (₹)
            <input name="amount_paid" type="number" min={1} required />
          </label>
          <label className="field">
            Payment date
            <input
              name="payment_date"
              type="date"
              defaultValue={new Date().toISOString().slice(0, 10)}
              required
            />
          </label>
          <label className="field">
            Payment mode
            <select name="payment_mode" defaultValue="cash">
              <option value="cash">Cash</option>
              <option value="online">Online / UPI</option>
              <option value="cheque">Cheque</option>
              <option value="dd">Demand Draft</option>
            </select>
          </label>
          <label className="field">
            Reference / Transaction ID <small>(optional)</small>
            <input name="transaction_id" />
          </label>
        </div>
        {error && <p className="form-error">{error}</p>}
        <FormActions saving={saving} onClose={onClose} label="Record payment" />
      </form>
    </Dialog>
  );
}

"use client";

import { useState } from "react";
import { paymentSchema } from "@/lib/schemas";
import type { Row } from "./types";
import { api, stringValue, money, displayName, nested } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

export function PaymentDialog({
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
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const pendingInvoices = invoices.filter(
    (row) => Number(row.balance ?? row.net_amount ?? 0) > 0
  );

  async function submit(form: FormData) {
    setSaving(true);
    setError("");
    try {
      const receiptNum = stringValue(form.get("receipt_number")) || `RCP${Date.now()}`;
      const txnId = stringValue(form.get("transaction_id")) || undefined;
      const payload = {
        invoice_id: stringValue(form.get("invoice_id")),
        receipt_number: receiptNum,
        // backend resolves reference_number first in the chain, so the receipt
        // number is always stored regardless of whether transaction_id is set
        reference_number: receiptNum,
        amount_paid: Number(form.get("amount_paid") || 0),
        payment_date:
          stringValue(form.get("payment_date")) ||
          new Date().toISOString().slice(0, 10),
        payment_mode: stringValue(form.get("payment_mode")),
        transaction_id: txnId,
        transaction_ref: txnId,
      };
      const parsed = paymentSchema.safeParse(payload);
      if (!parsed.success) {
        throw new Error(
          parsed.error.issues[0]?.message || "Invoice and amount paid are required."
        );
      }

      await api("fees/payments", {
        method: "POST",
        body: JSON.stringify({ ...parsed.data, reference_number: payload.reference_number, transaction_ref: payload.transaction_ref }),
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
          )}
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

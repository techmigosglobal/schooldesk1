type Row = Record<string, unknown>;

export function receiptRegisterRows(payments: Row[]) {
  return payments.map((payment) => ({
    receipt_number: payment.receipt_number ?? payment.reference_number ?? "",
    invoice_id: payment.invoice_id ?? "",
    amount_paid: payment.amount_paid ?? payment.amount ?? 0,
    payment_mode: payment.payment_mode ?? payment.payment_method ?? "",
    payment_date: payment.payment_date ?? payment.paid_at ?? "",
    transaction_id: payment.transaction_id ?? payment.transaction_ref ?? payment.reference_number ?? "",
  }));
}

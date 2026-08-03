import type { Row } from "./types";

function text(value: unknown, fallback = "") {
  const result = String(value ?? "").trim();
  return result && result !== "null" && result !== "undefined" ? result : fallback;
}

function amount(value: unknown) {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function escapeHtml(value: unknown) {
  return text(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function dateLabel(value: unknown) {
  const raw = text(value);
  if (!raw) return "—";
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) return raw.slice(0, 10);
  return new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(parsed);
}

function inr(value: unknown) {
  return `₹${new Intl.NumberFormat("en-IN", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount(value))}`;
}

function belowThousand(value: number) {
  const ones = [
    "",
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
    "ten",
    "eleven",
    "twelve",
    "thirteen",
    "fourteen",
    "fifteen",
    "sixteen",
    "seventeen",
    "eighteen",
    "nineteen",
  ];
  const tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"];
  const parts: string[] = [];
  if (value >= 100) {
    parts.push(`${ones[Math.floor(value / 100)]} hundred`);
    value %= 100;
  }
  if (value >= 20) {
    parts.push(tens[Math.floor(value / 10)]);
    value %= 10;
  }
  if (value > 0) parts.push(ones[value]);
  return parts.join(" ");
}

function amountInWords(value: unknown) {
  let remaining = Math.round(amount(value));
  if (remaining === 0) return "Zero rupees";
  const parts: string[] = [];
  if (remaining >= 10_000_000) {
    parts.push(`${belowThousand(Math.floor(remaining / 10_000_000))} crore`);
    remaining %= 10_000_000;
  }
  if (remaining >= 100_000) {
    parts.push(`${belowThousand(Math.floor(remaining / 100_000))} lakh`);
    remaining %= 100_000;
  }
  if (remaining >= 1_000) {
    parts.push(`${belowThousand(Math.floor(remaining / 1_000))} thousand`);
    remaining %= 1_000;
  }
  if (remaining > 0) parts.push(belowThousand(remaining));
  const result = parts.join(" ");
  return `${result.charAt(0).toUpperCase()}${result.slice(1)} rupees`;
}

function nested(row: Row, key: string): Row {
  return row[key] && typeof row[key] === "object" && !Array.isArray(row[key])
    ? row[key] as Row
    : {};
}

function addressFor(school: Row) {
  const parts = [
    school.address,
    school.address_line1,
    school.address_line2,
    school.city,
    school.state,
    school.postal_code,
  ].map((value) => text(value)).filter(Boolean);
  return [...new Set(parts)].join(", ");
}

function isCash(mode: string) {
  return mode.toLowerCase().replace(/[^a-z]/g, "").includes("cash");
}

export function buildFeeReceiptHtml({
  payment,
  studentName,
  invoice,
  school,
}: {
  payment: Row;
  studentName: string;
  invoice?: Row;
  school?: Row;
}) {
  const currentSchool = school ?? {};
  const currentInvoice = invoice ?? nested(payment, "invoice");
  const student = nested(payment, "student");
  const invoiceStudent = nested(currentInvoice, "student");
  const sourceStudent = Object.keys(student).length ? student : invoiceStudent;
  const section = nested(sourceStudent, "current_section");
  const grade = nested(section, "grade");
  const className = text(
    payment.class_name ?? payment.class ??
      (text(grade.grade_name) && text(section.section_name)
        ? `${text(grade.grade_name)} - ${text(section.section_name)}`
        : text(grade.grade_name ?? section.section_name)),
    "—",
  );
  const receipts = Array.isArray(payment.fee_receipts) ? payment.fee_receipts as Row[] : [];
  const receipt = receipts[0] ?? nested(payment, "receipt");
  const receiptNo = text(receipt.receipt_number ?? payment.receipt_number, "RECEIPT");
  const paymentDate = payment.paid_at ?? payment.payment_date ?? payment.created_at;
  const mode = text(payment.payment_method ?? payment.payment_mode ?? payment.mode, "—");
  const cashPayment = isCash(mode);
  const transactionReference = text(
    payment.reference_number ?? payment.transaction_id ?? receipt.transaction_ref,
  );
  const bankName = text(payment.bank_name ?? receipt.bank_name);
  const paidAmount = amount(payment.amount_paid ?? payment.amount);
  const totalAmount = amount(currentInvoice.net_amount ?? currentInvoice.total_amount ?? paidAmount);
  const balanceDue = Math.max(0, amount(currentInvoice.balance ?? totalAmount - paidAmount));
  const items = Array.isArray(currentInvoice.fee_invoice_items)
    ? currentInvoice.fee_invoice_items as Row[]
    : [{
      description: text(currentInvoice.fee_item_name ?? currentInvoice.category_name, "Fee payment"),
      amount: paidAmount,
    }];
  const academicYear = text(
    payment.academic_year_label ?? payment.academic_year_name ?? currentInvoice.academic_year_label ?? currentInvoice.academic_year_name ?? currentInvoice.academic_year,
  );
  const feePeriod = text(
    payment.fee_period ?? payment.billing_period ?? payment.installment ?? currentInvoice.fee_period ?? currentInvoice.billing_period ?? currentInvoice.installment ?? currentInvoice.term,
  );
  const admissionNo = text(
    payment.admission_number ?? sourceStudent.admission_number ?? sourceStudent.student_id_number,
    "—",
  );
  const counterNo = text(payment.counter_no ?? receipt.counter_no);
  const concession = amount(currentInvoice.concession_amount ?? currentInvoice.discount_amount);
  const schoolName = text(currentSchool.name, "School");
  const schoolAddress = addressFor(currentSchool);
  const logoUrl = text(currentSchool.logo_url);
  const signatureUrl = text(currentSchool.authorized_signature_url);
  const principalName = text(currentSchool.principal_name);

  const metadata = [
    ["Receipt No.", receiptNo, "Date", dateLabel(paymentDate)],
    ["Admission No.", admissionNo, "Academic Year", academicYear || "—"],
    ["Student Name", studentName || "Student", "Class / Section", className],
    ...(feePeriod || counterNo ? [["Fee Period", feePeriod || "—", "Counter No.", counterNo || "—"] as string[]] : []),
  ];
  const metadataHtml = metadata.map((row) => `
    <tr><th>${escapeHtml(row[0])}</th><td>${escapeHtml(row[1])}</td><th>${escapeHtml(row[2])}</th><td>${escapeHtml(row[3])}</td></tr>
  `).join("");
  const itemRows = items.map((item, index) => `
    <tr><td>${index + 1}</td><td>${escapeHtml(text(item.description ?? item.fee_item_name ?? item.category_name, "Fee payment"))}</td><td class="right">${inr(item.paid_amount ?? item.amount ?? item.total)}</td></tr>
  `).join("");
  const paymentRows = `
    <tr><th>Pay Mode</th><td>${escapeHtml(mode)}</td><th>Date</th><td>${dateLabel(paymentDate)}</td></tr>
    <tr><th>Amount Received</th><td>${inr(paidAmount)}</td><th>Balance Due</th><td>${inr(balanceDue)}</td></tr>
    ${!cashPayment && (bankName || transactionReference) ? `<tr><th>Bank Name</th><td>${escapeHtml(bankName || "—")}</td><th>Reference / Cheque No.</th><td>${escapeHtml(transactionReference || "—")}</td></tr>` : ""}
  `;

  return `<!DOCTYPE html><html><head><meta charset="UTF-8">
<title>Receipt ${escapeHtml(receiptNo)}</title>
<style>
  @page { size: A4; margin: 10mm; }
  * { box-sizing: border-box; }
  body { margin: 0; color: #18212b; font-family: Arial, Helvetica, sans-serif; font-size: 11px; background: #fff; }
  .receipt { width: 100%; max-width: 190mm; margin: 0 auto; border: 1px solid #42484f; padding: 8mm; }
  .school-header { text-align: center; min-height: 25mm; }
  .school-logo { width: 18mm; height: 18mm; object-fit: contain; display: block; margin: 0 auto 2mm; }
  .school-name { font-size: 17px; font-weight: 700; }
  .school-address { margin-top: 1mm; color: #4f5963; font-size: 9px; }
  .receipt-band { margin: 5mm 0 2mm; padding: 2.5mm; background: #d9dadd; text-align: center; font-size: 12px; font-weight: 700; letter-spacing: .4px; }
  table { width: 100%; border-collapse: collapse; }
  th, td { border: 1px solid #8d949a; padding: 2.2mm 2.5mm; vertical-align: middle; }
  th { background: #eceeef; text-align: left; font-weight: 700; white-space: nowrap; }
  .meta th { width: 18%; font-size: 9px; }
  .meta td { width: 32%; }
  .items { margin-top: 4mm; }
  .items thead th { text-align: center; }
  .items th:last-child, .items td:last-child { width: 25%; }
  .right { text-align: right; }
  .total-row td { background: #eceeef; font-weight: 700; }
  .concession { text-align: right; color: #59636d; font-size: 9px; margin-top: 1mm; }
  .payment-title { margin: 4mm 0 1.5mm; font-size: 10px; font-weight: 700; }
  .words { margin-top: 3mm; font-weight: 700; font-size: 10px; }
  .footer { display: flex; justify-content: space-between; align-items: flex-end; margin-top: 14mm; color: #59636d; font-size: 9px; }
  .signature { text-align: center; min-width: 35mm; color: #18212b; }
  .signature img { display: block; width: 30mm; height: 12mm; object-fit: contain; margin: 0 auto 1mm; }
  .signature-line { width: 35mm; border-top: 1px solid #59636d; margin: 10mm auto 1mm; }
  .signature-name { font-size: 8px; }
  @media print { body { background: #fff; } .receipt { border-color: #42484f; } }
</style></head><body>
<main class="receipt">
  <header class="school-header">
    ${logoUrl ? `<img class="school-logo" src="${escapeHtml(logoUrl)}" alt="${escapeHtml(schoolName)} logo">` : ""}
    <div class="school-name">${escapeHtml(schoolName)}</div>
    ${schoolAddress ? `<div class="school-address">${escapeHtml(schoolAddress)}</div>` : ""}
  </header>
  <div class="receipt-band">FEE RECEIPT</div>
  <table class="meta"><tbody>${metadataHtml}</tbody></table>
  <table class="items"><thead><tr><th>S.No.</th><th>Description</th><th class="right">Amount (₹)</th></tr></thead>
    <tbody>${itemRows}<tr class="total-row"><td></td><td class="right">Total</td><td class="right">${inr(totalAmount)}</td></tr></tbody>
  </table>
  ${concession > 0 ? `<div class="concession">Concession: ${inr(concession)}</div>` : ""}
  <div class="payment-title">PAYMENT INFORMATION</div>
  <table><tbody>${paymentRows}</tbody></table>
  <div class="words">Amount in words: ${escapeHtml(amountInWords(paidAmount))} only.</div>
  <footer class="footer">
    <div>Parent Copy</div>
    <div class="signature">
      ${signatureUrl ? `<img src="${escapeHtml(signatureUrl)}" alt="Authorised signatory">` : `<div class="signature-line"></div>`}
      ${principalName ? `<div class="signature-name">${escapeHtml(principalName)}</div>` : ""}
      <div>Authorised Signatory</div>
    </div>
  </footer>
</main></body></html>`;
}

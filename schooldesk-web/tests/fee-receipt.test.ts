import { expect, test } from "bun:test";
import { buildFeeReceiptHtml } from "../components/portal/fee-receipt";

test("website receipt uses active branch branding and omits bank fields for cash", () => {
  const html = buildFeeReceiptHtml({
    payment: {
      receipt_number: "RCP-001",
      amount: 1250,
      payment_method: "Cash",
      paid_at: "2026-08-02T19:00:00Z",
      student: { admission_number: "ADM-7" },
      fee_receipts: [{ receipt_number: "RCP-001" }],
    },
    studentName: "Aarav <Sharma>",
    invoice: {
      total_amount: 1250,
      fee_invoice_items: [{ description: "Tuition", amount: 1250 }],
      academic_year_label: "2026-2027",
    },
    school: {
      name: "Arish Ville Preschool - Miyapur",
      address: "Branch address",
      logo_url: "https://example.test/logo.png",
    },
  });

  expect(html).toContain("Arish Ville Preschool - Miyapur");
  expect(html).toContain("https://example.test/logo.png");
  expect(html).toContain("FEE RECEIPT");
  expect(html).toContain("Admission No.");
  expect(html).toContain("Aarav &lt;Sharma&gt;");
  expect(html).not.toContain("Reference / Cheque No.");
});

test("website receipt includes bank/reference fields for non-cash payments", () => {
  const html = buildFeeReceiptHtml({
    payment: {
      amount: 800,
      payment_method: "UPI",
      reference_number: "UTR-8",
      bank_name: "ICICI Bank",
      paid_at: "2026-08-02",
    },
    studentName: "Student",
    school: { name: "Branch" },
  });

  expect(html).toContain("ICICI Bank");
  expect(html).toContain("Reference / Cheque No.");
  expect(html).toContain("UTR-8");
});

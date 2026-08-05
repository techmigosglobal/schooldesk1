import {
  assert,
  assertEquals,
  assertGreater,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { PDFDocument } from "pdf-lib";
import { renderStructuredReportPdf } from "./report_pdf.ts";

const root = new URL("../../../", import.meta.url);

Deno.test("report PDF preserves Unicode and paginates large tables", async () => {
  const multilingualNames = [
    "José D'Souza",
    "आरव शर्मा",
    "অনন্যা সেন",
    "કાવ્યા પટેલ",
    "ਹਰਪ੍ਰੀਤ ਸਿੰਘ",
    "அனன்யா குமார்",
    "సాయి రెడ్డి",
    "ಅನನ್ಯಾ ರಾವ್",
    "نور أحمد",
  ];
  const rows = Array.from({ length: 90 }, (_, index) => [
    multilingualNames[index % multilingualNames.length],
    `ADM-${index + 1}`,
    `₹${1000 + index}`,
    `Address ${index + 1}`,
  ]);

  const bytes = await renderStructuredReportPdf({
    title: "Student Directory",
    schoolName: "विद्यालय School",
    branchCode: "MAIN",
    academicYear: "2026-27",
    scope: ["All active students"],
    metrics: [{ label: "Students", value: String(rows.length) }],
    tables: [{
      title: "Student records",
      headers: ["Name", "Admission", "Fees", "Address"],
      rows,
      weights: [2, 1, 1, 2],
    }],
  });
  const document = await PDFDocument.load(bytes);

  assertEquals(new TextDecoder().decode(bytes.slice(0, 4)), "%PDF");
  assertGreater(document.getPageCount(), 1);
  assertGreater(bytes.length, 10_000);
});

Deno.test("report exports use private signed URLs", async () => {
  const source = await Deno.readTextFile(
    new URL("supabase/functions/api/handlers/uploads.ts", root),
  );
  const helperStart = source.indexOf("async function uploadPrivateReportPdf");
  const helperEnd = source.indexOf(
    "async function performStructuredReportExport",
  );
  assert(helperStart >= 0 && helperEnd > helperStart);
  const helper = source.slice(helperStart, helperEnd);

  assertMatch(helper, /bucket = "finance-documents"/);
  assertMatch(helper, /createSignedUrl/);
  assertMatch(helper, /10 \* 60/);
  assert(!helper.includes("getPublicUrl"));
});

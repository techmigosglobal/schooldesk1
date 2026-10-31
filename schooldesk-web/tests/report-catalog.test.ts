import { expect, test } from "bun:test";
import { isFinanceReport, reportDefinitionForHistory, reportsForRole } from "../components/portal/report-catalog";
test("current report groups remain eight academic and six finance", () => {
  expect(reportsForRole("principal").filter(isFinanceReport)).toHaveLength(6);
  expect(reportsForRole("principal").filter((report) => !isFinanceReport(report))).toHaveLength(8);
  expect(reportsForRole("coordinator")).toHaveLength(8);
  expect(reportsForRole("coordinator").some(isFinanceReport)).toBe(false);
});
test("legacy outstanding report has a Principal-only current regeneration path", () => {
  expect(reportDefinitionForHistory("principal", "fee_outstanding_report")?.endpoint).toBe("fees/reports/exports");
  expect(reportDefinitionForHistory("coordinator", "fee_outstanding_report")).toBeUndefined();
  expect(reportDefinitionForHistory("coordinator", "paid_fees")).toBeUndefined();
});

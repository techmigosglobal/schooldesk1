import { expect, test } from "bun:test";
import { selectReportHistory } from "../lib/report-history";
const rows = Array.from({ length: 25 }, (_, i) => ({ id: `export-${String(i).padStart(2, "0")}`, created_at: "2026-10-16T01:00:00Z", finance: false }));
test("all 25 exports are reachable once with stable timestamp ties", () => {
  const pages = [1, 2, 3].map((page) => selectReportHistory(rows.slice().reverse(), "principal", page));
  expect(pages.map((p) => p.items.length)).toEqual([12, 12, 1]);
  expect(pages.flatMap((p) => p.items.map((r) => r.id))).toEqual(rows.map((r) => r.id));
});
test("Coordinator history excludes explicit and known finance records before paging", () => {
  const result = selectReportHistory([...rows, { id: "finance", created_at: "2026-10-17", finance: true }, { id: "legacy-finance", created_at: "2026-10-17", finance: false, report_type: "paid_fees" }], "coordinator", 3);
  expect(result.total).toBe(25);
  expect(result.items.map((r) => r.id)).toEqual(["export-24"]);
});
test("history clamps after a result shrinks and orders actual instants", () => {
  expect(selectReportHistory([], "principal", 99).page).toBe(1);
  expect(selectReportHistory([{ id: "older", created_at: "2026-10-16T12:00:00+05:30" }, { id: "newer", created_at: "2026-10-16T09:00:00Z" }], "principal", 1).items[0]?.id).toBe("newer");
});

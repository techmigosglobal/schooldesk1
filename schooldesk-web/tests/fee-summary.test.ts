import { expect, test } from "bun:test";
import { readFeeSummary } from "../lib/fee-summary";
const fixture = { billed: 3349000, collected: 1566000, outstanding: 1783000, overdue: 0, invoice_count: 127, overdue_count: 0, pending_request_count: 1 };
test("invoice summary keeps authoritative collection instead of raw receipt totals", () => {
  const summary = readFeeSummary(fixture);
  expect(summary.collected).toBe(1566000);
  expect(summary.collectionPercent).toBe(47);
  expect(summary.pendingRequestCount).toBe(1);
  expect(summary.collected).not.toBe(1606000);
});
test("empty collection target has no invented percentage", () => expect(readFeeSummary({ ...fixture, collected: 0, outstanding: 0 }).collectionPercent).toBeNull());
test("invalid or missing totals cannot appear as zero", () => {
  for (const bad of [undefined, null, "0", NaN, Infinity]) expect(() => readFeeSummary({ ...fixture, collected: bad })).toThrow();
  expect(() => readFeeSummary({})).toThrow();
  expect(() => readFeeSummary({ ...fixture, pending_request_count: -1 })).toThrow();
});
test("credits are not silently clamped and denominator matches the ledger", () => {
  expect(readFeeSummary({ ...fixture, collected: 120, outstanding: -20 }).collectionPercent).toBe(120);
  expect(readFeeSummary({ ...fixture, collected: -20, outstanding: 120 }).collectionPercent).toBe(-20);
});

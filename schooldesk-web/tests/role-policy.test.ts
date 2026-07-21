import { expect, test } from "bun:test";
import { isFinancePath, visibleModules } from "../lib/roles";
test("coordinator navigation never includes fees", () => expect(visibleModules("coordinator")).not.toContain("fees"));
test("leadership navigation includes attendance and reports", () => {
  expect(visibleModules("principal")).toContain("attendance");
  expect(visibleModules("principal")).toContain("reports");
  expect(visibleModules("coordinator")).toContain("communications");
});
test("finance paths are identified before proxying", () => { expect(isFinancePath("fees/structures")).toBe(true); expect(isFinancePath("principal/classes")).toBe(false); });

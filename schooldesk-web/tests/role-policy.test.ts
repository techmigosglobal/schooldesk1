import { expect, test } from "bun:test";
import { isFinancePath, portalRoleFromPath, visibleModules } from "../lib/roles";
test("coordinator navigation never includes fees", () => expect(visibleModules("coordinator")).not.toContain("fees"));
test("leadership navigation includes attendance and reports", () => {
  expect(visibleModules("principal")).toContain("attendance");
  expect(visibleModules("principal")).toContain("reports");
  expect(visibleModules("coordinator")).toContain("communications");
});
test("finance paths are identified before proxying", () => { expect(isFinancePath("fees/structures")).toBe(true); expect(isFinancePath("principal/classes")).toBe(false); });
test("portal redirects preserve the requested role", () => {
  expect(portalRoleFromPath("/portal/principal")).toBe("principal");
  expect(portalRoleFromPath("/portal/coordinator")).toBe("coordinator");
  expect(portalRoleFromPath("/portal/unknown")).toBeNull();
});

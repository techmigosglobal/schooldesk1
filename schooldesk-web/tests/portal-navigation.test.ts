import { expect, test } from "bun:test";
import { parsePortalTarget, serializePortalTarget } from "../lib/portal-navigation";
import { canManageFinance, visibleModules } from "../lib/roles";
test("leadership feature parity excludes only finance", () => {
 expect(visibleModules("principal").filter(id => id !== "fees")).toEqual(visibleModules("coordinator"));
 expect(canManageFinance("coordinator")).toBe(false); expect(canManageFinance("principal")).toBe(true);
});
test("bookmarks restore permitted module and tab", () => {
 expect(parsePortalTarget("?module=fees&tab=requests", "principal")).toEqual({module:"fees",tab:"requests"});
 expect(parsePortalTarget("?module=website&tab=unknown", "coordinator")).toEqual({module:"website",tab:"gallery"});
 expect(parsePortalTarget("?module=fees&tab=requests", "coordinator")).toEqual({module:"overview"});
 expect(parsePortalTarget("?module=not-a-page", "principal")).toEqual({module:"overview"});
});
test("URL round trips preserve only supported non-personal navigation fields", () => {
 const url=serializePortalTarget({module:"timetable",sectionId:"b3409710-78ac-446d-b8f5-45c58d72a004"},"principal");
 expect(parsePortalTarget(url,"principal")).toEqual({module:"timetable",sectionId:"b3409710-78ac-446d-b8f5-45c58d72a004"});
 expect(serializePortalTarget({module:"fees"},"coordinator")).toBe("?module=overview");
 expect(parsePortalTarget("?module=students&section=javascript:bad&search=child-name", "principal")).toEqual({module:"students"});
});

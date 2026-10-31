import { visibleModules, type PortalRole } from "./roles";

export type PortalTarget = { module: string; tab?: string; sectionId?: string };
const tabs: Record<string, readonly string[]> = {
  fees: ["main", "collections", "requests", "structures", "concessions", "reports"],
  website: ["gallery", "copy", "ticker"],
  classes: ["classes", "subjects"],
  reports: ["academic", "finance"],
};
export function parsePortalTarget(search: string, role: PortalRole): PortalTarget {
  const params = new URLSearchParams(search);
  const module = params.get("module") ?? "overview";
  if (!(visibleModules(role) as readonly string[]).includes(module)) return { module: "overview" };
  const target: PortalTarget = { module };
  const allowedTabs = (tabs[module] ?? []).filter(tab => role === "principal" || module !== "reports" || tab !== "finance");
  if (allowedTabs.length) target.tab = allowedTabs.includes(params.get("tab") ?? "") ? params.get("tab")! : allowedTabs[0];
  const section = params.get("section");
  if ((module === "timetable" || module === "fees") && section && /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(section)) target.sectionId = section;
  return target;
}
export function serializePortalTarget(target: PortalTarget, role: PortalRole): string {
  const params = new URLSearchParams({ module: target.module });
  if (target.tab) params.set("tab", target.tab);
  if (target.sectionId) params.set("section", target.sectionId);
  const valid = parsePortalTarget(params.toString(), role);
  const result = new URLSearchParams({ module: valid.module });
  if (valid.tab) result.set("tab", valid.tab);
  if (valid.sectionId) result.set("section", valid.sectionId);
  return `?${result}`;
}

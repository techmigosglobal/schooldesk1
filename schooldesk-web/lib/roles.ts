export const portalRoles = ["principal", "coordinator"] as const;
export type PortalRole = (typeof portalRoles)[number];

export function isPortalRole(value: string): value is PortalRole {
  return portalRoles.includes(value as PortalRole);
}

export function isFinancePath(path: string) {
  const normalized = path.replace(/^\/+/, "").toLowerCase();
  return normalized.startsWith("fees") || normalized.startsWith("fee-") ||
    normalized.startsWith("reports/fees") || normalized.startsWith("principal/fees");
}

export function visibleModules(role: PortalRole) {
  const base = ["overview", "students", "parents", "teachers", "classes", "timetable"] as const;
  return role === "principal" ? [...base, "fees", "website"] : base;
}

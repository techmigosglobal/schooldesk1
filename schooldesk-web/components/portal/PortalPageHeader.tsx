import type { PortalRole } from "@/lib/roles";
export function PortalPageHeader({ role, title }: { role: PortalRole; title: string }) {
  return <div className="portal-page-heading"><p>{role === "principal" ? "Principal Portal" : "Coordinator Portal"}</p><h1>{title}</h1></div>;
}

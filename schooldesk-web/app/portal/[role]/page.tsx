import { notFound, redirect } from "next/navigation";
import { PortalClient } from "@/components/portal-client";
import { getSession } from "@/lib/session";
import { isPortalRole } from "@/lib/roles";
import { backendFetch, unwrap } from "@/lib/backend";

export default async function PortalPage({ params }: { params: Promise<{ role: string }> }) {
  const { role } = await params;
  if (!isPortalRole(role)) notFound();
  const session = await getSession();
  if (!session) redirect(`/login/${role}`);
  if (session.role !== role) redirect(`/portal/${session.role}`);
  let school: { id?: string; name?: string } = {};
  if (role === "coordinator") {
    try {
      const response = await backendFetch("schools/current", { headers: { Authorization: `Bearer ${session.accessToken}` } });
      if (response.ok) school = unwrap(await response.json());
    } catch { /* The portal shows its existing authenticated API errors. */ }
  }
  return <PortalClient role={role} initialBranchId={session.branchId} sessionScope={session.uiScope} initialSchoolId={school.id ?? ""} initialSchoolName={school.name ?? "Assigned branch"} />;
}

import { notFound, redirect } from "next/navigation";
import { PortalClient } from "@/components/portal-client";
import { getSession } from "@/lib/session";
import { isPortalRole } from "@/lib/roles";

export default async function PortalPage({ params }: { params: Promise<{ role: string }> }) {
  const { role } = await params; if (!isPortalRole(role)) notFound(); const session = await getSession(); if (!session) redirect(`/login/${role}`); if (session.role !== role) redirect(`/portal/${session.role}`); return <PortalClient role={role} initialBranchId={session.branchId} />;
}

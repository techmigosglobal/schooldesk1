import { notFound } from "next/navigation";
import { LoginForm } from "@/components/login-form";
import { isPortalRole, portalRoles } from "@/lib/roles";

export function generateStaticParams() {
  return portalRoles.map((role) => ({ role }));
}

export default async function LoginPage({ params }: { params: Promise<{ role: string }> }) {
  const { role } = await params;
  if (!isPortalRole(role)) notFound();
  return <LoginForm role={role} />;
}

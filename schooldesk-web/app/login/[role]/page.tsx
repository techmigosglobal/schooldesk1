import { notFound } from "next/navigation";
import { LoginForm } from "@/components/login-form";
import { isPortalRole } from "@/lib/roles";

export default async function LoginPage({ params }: { params: Promise<{ role: string }> }) {
  const { role } = await params; if (!isPortalRole(role)) notFound(); return <LoginForm role={role} />;
}

"use client";
import { useState } from "react";
import Image from "next/image";
import { useRouter, useSearchParams } from "next/navigation";
import type { PortalRole } from "@/lib/roles";

export function LoginForm({ role }: { role: PortalRole }) {
  const router = useRouter(); const search = useSearchParams();
  const [error, setError] = useState(""); const [loading, setLoading] = useState(false);
  async function submit(formData: FormData) {
    setLoading(true); setError("");
    const response = await fetch("/api/auth/login", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ username: formData.get("identity"), password: formData.get("password"), expectedRole: role }) });
    const body = await response.json().catch(() => ({})); setLoading(false);
    if (!response.ok) return setError(body.error || "Unable to sign in.");
    const next = search.get("next"); router.replace(next?.startsWith(`/portal/${role}`) ? next : `/portal/${role}`); router.refresh();
  }
  return <main className="login-page"><section className="login-card"><a className="login-brand" href="/"><Image src="/branding/arishville-logo.png" alt="ArishVille Preschool" width={66} height={66}/><span>ArishVille Preschool</span></a><h1>{role === "principal" ? "Principal Portal" : "Coordinator Portal"}</h1><p>Use your SchoolDesk username or email and password.</p><form action={submit}><label className="field">Username or email<input required name="identity" autoComplete="username" /></label><label className="field">Password<input required type="password" name="password" autoComplete="current-password" /></label>{error && <p className="form-error">{error}</p>}<button className="primary-button full" disabled={loading}>{loading ? "Signing in…" : "Sign in securely"}</button></form></section></main>;
}

"use client";
import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { LoaderCircle } from "@/lib/lucide-react";
import type { PortalRole } from "@/lib/roles";
import { loginSchema } from "@/lib/schemas";

export function LoginForm({ role }: { role: PortalRole }) {
  const router = useRouter();
  const search = useSearchParams();

  const [fieldErrors, setFieldErrors] = useState<{ identity?: string; password?: string }>({});
  const [apiError, setApiError] = useState("");
  const [loading, setLoading] = useState(false);

  async function submit(formData: FormData) {
    setApiError("");

    // Client-side Zod validation
    const result = loginSchema.safeParse({
      identity: formData.get("identity"),
      password: formData.get("password"),
    });

    if (!result.success) {
      const errors: { identity?: string; password?: string } = {};
      for (const issue of result.error.issues) {
        const field = issue.path[0] as "identity" | "password";
        errors[field] = issue.message;
      }
      setFieldErrors(errors);
      return;
    }

    setFieldErrors({});
    setLoading(true);

    try {
      const response = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          username: result.data.identity,
          password: result.data.password,
          expectedRole: role,
        }),
      });

      const body = await response.json().catch(() => ({}));

      if (!response.ok) {
        setApiError(body.error || "Unable to sign in. Please check your credentials.");
        return;
      }

      const next = search.get("next");
      router.replace(next?.startsWith(`/portal/${role}`) ? next : `/portal/${role}`);
      router.refresh();
    } catch {
      setApiError("Network error — please check your connection and try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="login-page">
      <section className="login-card">
        <Link className="login-brand" href="/" aria-label="Back to Arish Ville Preschool website">
          <Image
            src="/branding/arishville-logo.png"
            alt="Arish Ville Preschool"
            width={66}
            height={66}
          />
          <span>Arish Ville Preschool</span>
        </Link>

        <h1>{role === "principal" ? "Principal Portal" : "Coordinator Portal"}</h1>
        <p>Use your SchoolDesk username or email and password.</p>

        <form
          action={submit}
          noValidate
          aria-busy={loading}
          style={loading ? { opacity: 0.65, pointerEvents: "none" } : undefined}
        >
          {loading && (
            <div className="login-auth-progress" role="status" aria-live="polite">
              <span>Verifying your account and preparing the portal&hellip;</span>
              <div className="skeleton skeleton-text wide" />
              <div className="skeleton skeleton-text narrow" />
            </div>
          )}

          <div className="field">
            <label htmlFor="login-identity">Username or email</label>
            <input
              id="login-identity"
              name="identity"
              autoComplete="username"
              aria-describedby={fieldErrors.identity ? "identity-error" : undefined}
              aria-invalid={!!fieldErrors.identity}
              placeholder=" "
              disabled={loading}
            />
            {fieldErrors.identity && (
              <p id="identity-error" className="form-error" role="alert">
                {fieldErrors.identity}
              </p>
            )}
          </div>

          <div className="field">
            <label htmlFor="login-password">Password</label>
            <input
              id="login-password"
              type="password"
              name="password"
              autoComplete="current-password"
              aria-describedby={fieldErrors.password ? "password-error" : undefined}
              aria-invalid={!!fieldErrors.password}
              placeholder=" "
              disabled={loading}
            />
            {fieldErrors.password && (
              <p id="password-error" className="form-error" role="alert">
                {fieldErrors.password}
              </p>
            )}
          </div>

          {apiError && (
            <p className="form-error" role="alert">
              {apiError}
            </p>
          )}

          <button
            className="primary-button full"
            disabled={loading}
            aria-busy={loading}
            style={{ marginTop: "0.5rem" }}
          >
            {loading ? (
              <>
                <LoaderCircle className="spin" size={17} /> Signing in&hellip;
              </>
            ) : (
              "Sign in securely"
            )}
          </button>
        </form>
        <div className="login-return"><Link href="/login">← Choose another portal</Link><Link href="/">Back to school website</Link></div>
      </section>
    </main>
  );
}

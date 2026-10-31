import { createHash } from "node:crypto";
import { cookies } from "next/headers";
import type { PortalRole } from "@/lib/roles";

export const cookieNames = { access: "schooldesk.access", refresh: "schooldesk.refresh", role: "schooldesk.role", branch: "schooldesk.branch", ui: "schooldesk.ui" } as const;
export type Session = { accessToken: string; refreshToken: string; role: PortalRole; branchId: string; uiScope: string };

export async function getSession(): Promise<Session | null> {
  const jar = await cookies();
  const accessToken = jar.get(cookieNames.access)?.value ?? "";
  const refreshToken = jar.get(cookieNames.refresh)?.value ?? "";
  const role = jar.get(cookieNames.role)?.value;
  if (!accessToken || !refreshToken || (role !== "principal" && role !== "coordinator")) return null;
  return { accessToken, refreshToken, role, branchId: jar.get(cookieNames.branch)?.value ?? "", uiScope: jar.get(cookieNames.ui)?.value || createHash("sha256").update(refreshToken).digest("hex").slice(0, 24) };
}

export const secureCookie = { httpOnly: true, sameSite: "lax" as const, secure: process.env.NODE_ENV === "production", path: "/" };

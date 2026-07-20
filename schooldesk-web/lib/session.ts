import { cookies } from "next/headers";
import type { PortalRole } from "@/lib/roles";

export const cookieNames = { access: "schooldesk.access", refresh: "schooldesk.refresh", role: "schooldesk.role" } as const;
export type Session = { accessToken: string; refreshToken: string; role: PortalRole };

export async function getSession(): Promise<Session | null> {
  const jar = await cookies();
  const accessToken = jar.get(cookieNames.access)?.value ?? "";
  const refreshToken = jar.get(cookieNames.refresh)?.value ?? "";
  const role = jar.get(cookieNames.role)?.value;
  if (!accessToken || !refreshToken || (role !== "principal" && role !== "coordinator")) return null;
  return { accessToken, refreshToken, role };
}

export const secureCookie = { httpOnly: true, sameSite: "lax" as const, secure: process.env.NODE_ENV === "production", path: "/" };

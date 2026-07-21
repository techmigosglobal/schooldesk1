import { env } from "@/lib/env";

const baseUrl = () => env.SCHOOLDESK_API_BASE_URL.replace(/\/$/, "");

export function configuredBackend() { return baseUrl(); }

export async function backendFetch(path: string, init: RequestInit = {}) {
  const base = baseUrl();
  if (!base) throw new Error("SCHOOLDESK_API_BASE_URL is not configured");
  const response = await fetch(`${base}/${path.replace(/^\//, "")}`, { ...init, cache: "no-store" });
  return response;
}

export function unwrap<T>(payload: unknown): T {
  const data = payload as { success?: boolean; data?: T; error?: string };
  if (data.success !== true) throw new Error(data.error || "The SchoolDesk API request failed");
  return data.data as T;
}

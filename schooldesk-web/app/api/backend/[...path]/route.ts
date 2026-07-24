import { NextRequest, NextResponse } from "next/server";
import { revalidateTag } from "next/cache";
import { backendFetch, unwrap } from "@/lib/backend";
import { cookieNames, secureCookie } from "@/lib/session";
import { isFinancePath } from "@/lib/roles";

async function proxy(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params; const joined = path.join("/"); const role = request.cookies.get(cookieNames.role)?.value;
  if (!request.cookies.get(cookieNames.access)?.value) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  if (role === "coordinator" && isFinancePath(joined)) return NextResponse.json({ error: "principal access required" }, { status: 403 });
  const requestBody = ["GET", "HEAD"].includes(request.method) ? undefined : await request.arrayBuffer();
  const branch = request.cookies.get(cookieNames.branch)?.value;
  // Never silently fall back to a Principal's home branch. The user must make
  // the branch choice explicitly before any scoped portal data can load.
  if (role === "principal" && !branch && !joined.startsWith("branches")) {
    return NextResponse.json({ error: "Select a branch before viewing school data." }, { status: 409 });
  }
  const forward = async (token: string) => backendFetch(`${joined}${request.nextUrl.search}`, { method: request.method, headers: { Authorization: `Bearer ${token}`, ...(branch ? { "x-schooldesk-branch-id": branch } : {}), ...(request.headers.get("content-type") ? { "Content-Type": request.headers.get("content-type")! } : {}) }, body: requestBody });
  let token = request.cookies.get(cookieNames.access)!.value; let upstream = await forward(token);
  if (upstream.ok && joined.startsWith("website/")) revalidateTag("school-public-website", "max");
  const response = new NextResponse(upstream.body, { status: upstream.status, headers: { "Content-Type": upstream.headers.get("content-type") || "application/json", "Cache-Control": "no-store" } });
  if (upstream.status !== 401) return response;
  const refresh = request.cookies.get(cookieNames.refresh)?.value;
  if (!refresh) return response;
  const refreshResponse = await backendFetch("auth/refresh", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ refresh_token: refresh }) });
  if (!refreshResponse.ok) return response;
  const refreshed = unwrap<{ access_token: string; refresh_token: string }>(await refreshResponse.json()); token = refreshed.access_token;
  upstream = await forward(token); if (upstream.ok && joined.startsWith("website/")) revalidateTag("school-public-website", "max"); const retried = new NextResponse(upstream.body, { status: upstream.status, headers: { "Content-Type": upstream.headers.get("content-type") || "application/json", "Cache-Control": "no-store" } });
  retried.cookies.set(cookieNames.access, refreshed.access_token, { ...secureCookie, maxAge: 60 * 55 }); retried.cookies.set(cookieNames.refresh, refreshed.refresh_token, { ...secureCookie, maxAge: 60 * 60 * 24 * 14 }); return retried;
}
export const GET = proxy; export const POST = proxy; export const PUT = proxy; export const PATCH = proxy; export const DELETE = proxy;

import { NextRequest, NextResponse } from "next/server";
import { revalidateTag } from "next/cache";
import { backendFetch, configuredBackend } from "@/lib/backend";
import { normalizeMediaUrls } from "@/lib/media-urls";
import { cookieNames, secureCookie } from "@/lib/session";
import { isFinancePath } from "@/lib/roles";

import { refreshSession, type RefreshedSession } from "@/lib/refresh-session";

function copyUpstream(upstream: Response) {
  const headers = new Headers();
  for (const name of [
    "content-type", "cache-control", "retry-after", "request-id",
    "x-request-id", "content-disposition",
  ]) {
    const value = upstream.headers.get(name);
    if (value) headers.set(name, value);
  }
  return headers;
}

async function proxy(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params;
  const joined = path.join("/");
  const role = request.cookies.get(cookieNames.role)?.value;
  const branch = request.cookies.get(cookieNames.branch)?.value;
  const refresh = request.cookies.get(cookieNames.refresh)?.value;
  const access = request.cookies.get(cookieNames.access)?.value;

  if (role === "coordinator" && isFinancePath(joined)) {
    return NextResponse.json({ error: "principal access required" }, { status: 403 });
  }
  if (role === "principal" && !branch && !joined.startsWith("branches")) {
    return NextResponse.json({ error: "Select a branch before viewing school data." }, { status: 409 });
  }

  const requestBody = ["GET", "HEAD"].includes(request.method)
    ? undefined
    : await request.arrayBuffer();
  const idempotencyKey = request.headers.get("idempotency-key");
  const forward = (token: string) => backendFetch(
    `${joined}${request.nextUrl.search}`,
    {
      method: request.method,
      headers: {
        Authorization: `Bearer ${token}`,
        ...(branch ? { "x-schooldesk-branch-id": branch } : {}),
        ...(request.headers.get("content-type")
          ? { "Content-Type": request.headers.get("content-type")! }
          : {}),
        ...(idempotencyKey ? { "Idempotency-Key": idempotencyKey } : {}),
      },
      body: requestBody,
    },
  );

  let token = access;
  let refreshedSession: RefreshedSession | null = null;
  if (!token && refresh) {
    refreshedSession = await refreshSession(refresh);
    if (refreshedSession) {
      token = refreshedSession.access_token;
    }
  }
  if (!token) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  let upstream = await forward(token);
  if (upstream.status === 401 && refresh && !refreshedSession) {
    refreshedSession = await refreshSession(refresh);
    if (refreshedSession) {
      token = refreshedSession.access_token;
      upstream = await forward(token);
    }
  }

  if (upstream.ok && request.method !== "GET" && joined.startsWith("website/")) {
    revalidateTag("school-public-website", "max");
  }
  const contentType = upstream.headers.get("content-type") ?? "";
  const responseBody = contentType.includes("application/json")
    ? JSON.stringify(normalizeMediaUrls(await upstream.json(), new URL(configuredBackend()).origin))
    : upstream.body;
  const response = new NextResponse(responseBody, {
    status: upstream.status,
    headers: copyUpstream(upstream),
  });
  if (refreshedSession) {
    response.cookies.set(cookieNames.access, refreshedSession.access_token, {
      ...secureCookie, maxAge: 60 * 55,
    });
    response.cookies.set(cookieNames.refresh, refreshedSession.refresh_token, {
      ...secureCookie, maxAge: 60 * 60 * 24 * 14,
    });
  }
  return response;
}

export const GET = proxy;
export const POST = proxy;
export const PUT = proxy;
export const PATCH = proxy;
export const DELETE = proxy;

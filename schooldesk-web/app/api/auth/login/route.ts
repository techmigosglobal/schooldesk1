import { NextRequest, NextResponse } from "next/server";
import { backendFetch, unwrap } from "@/lib/backend";
import { cookieNames, secureCookie } from "@/lib/session";
import { isPortalRole } from "@/lib/roles";

export async function POST(request: NextRequest) {
  const body = await request.json().catch(() => ({}));
  const identity = `${body.username ?? ""}`.trim(); const password = `${body.password ?? ""}`;
  if (!identity || !password || !isPortalRole(body.expectedRole)) return NextResponse.json({ error: "Username, password, and portal are required." }, { status: 400 });
  try {
    const upstream = await backendFetch("auth/login", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ username: identity, password }) });
    const payload = await upstream.json(); const data = unwrap<{ access_token: string; refresh_token: string; user: { role_name: string } }>(payload);
    const role = data.user.role_name.toLowerCase();
    if (role !== body.expectedRole) return NextResponse.json({ error: `This account belongs to the ${role || "assigned"} portal.` }, { status: 403 });
    const response = NextResponse.json({ success: true });
    response.cookies.set(cookieNames.access, data.access_token, { ...secureCookie, maxAge: 60 * 55 });
    response.cookies.set(cookieNames.refresh, data.refresh_token, { ...secureCookie, maxAge: 60 * 60 * 24 * 14 });
    response.cookies.set(cookieNames.role, role, { ...secureCookie, maxAge: 60 * 60 * 24 * 14 });
    return response;
  } catch (error) { return NextResponse.json({ error: error instanceof Error ? error.message : "Unable to sign in." }, { status: 401 }); }
}

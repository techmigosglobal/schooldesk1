import { NextRequest, NextResponse } from "next/server";
import { backendFetch, unwrap } from "@/lib/backend";
import { INVALID_CREDENTIALS_MESSAGE, loginErrorMessage } from "@/lib/login-errors";
import { cookieNames, secureCookie } from "@/lib/session";
import { isPortalRole } from "@/lib/roles";
import { checkRateLimit, retryAfterSeconds } from "@/lib/rate-limit";

export async function POST(request: NextRequest) {
  // Rate limiting: 10 attempts per IP per minute
  const ip =
    request.headers.get("x-forwarded-for")?.split(",")[0].trim() ??
    request.headers.get("x-real-ip") ??
    "unknown";

  if (!checkRateLimit(ip, 10, 60_000)) {
    const retryAfter = retryAfterSeconds(ip, 60_000);
    return NextResponse.json(
      { error: "Too many login attempts. Please wait a minute and try again." },
      {
        status: 429,
        headers: { "Retry-After": String(retryAfter) },
      },
    );
  }

  const body = await request.json().catch(() => ({}));
  const identity = `${body.username ?? ""}`.trim();
  const password = `${body.password ?? ""}`;

  if (!identity || !password || !isPortalRole(body.expectedRole)) {
    return NextResponse.json(
      { error: "Username, password, and portal are required." },
      { status: 400 },
    );
  }

  try {
    const upstream = await backendFetch("auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username: identity, password }),
    });
    const payload = await upstream.json().catch(() => ({}));

    if (!upstream.ok) {
      return NextResponse.json(
        {
          error: loginErrorMessage(
            (payload as { error?: unknown }).error,
            upstream.status === 401 ? INVALID_CREDENTIALS_MESSAGE : undefined,
          ),
        },
        { status: upstream.status },
      );
    }

    const data = unwrap<{
      access_token: string;
      refresh_token: string;
      user: { role_name: string };
    }>(payload);

    const role = data.user.role_name.toLowerCase();
    if (role !== body.expectedRole) {
      return NextResponse.json(
        { error: `This account belongs to the ${role || "assigned"} portal.` },
        { status: 403 },
      );
    }

    const response = NextResponse.json({ success: true });
    response.cookies.set(cookieNames.access, data.access_token, {
      ...secureCookie,
      maxAge: 60 * 55,
    });
    response.cookies.set(cookieNames.refresh, data.refresh_token, {
      ...secureCookie,
      maxAge: 60 * 60 * 24 * 14,
    });
    response.cookies.set(cookieNames.role, role, {
      ...secureCookie,
      maxAge: 60 * 60 * 24 * 14,
    });
    return response;
  } catch (error) {
    return NextResponse.json(
      { error: loginErrorMessage(error) },
      { status: 502 },
    );
  }
}

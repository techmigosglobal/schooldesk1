import { NextRequest, NextResponse } from "next/server";
import { portalRoleFromPath } from "@/lib/roles";
import { cookieNames, secureCookie } from "@/lib/session";
import { refreshSession } from "@/lib/refresh-session";

export async function proxy(request: NextRequest) {
  if (!request.nextUrl.pathname.startsWith("/portal")) return NextResponse.next();
  if (!request.cookies.get("schooldesk.access")?.value) {
    const refresh = request.cookies.get(cookieNames.refresh)?.value;
    const session = refresh ? await refreshSession(refresh) : null;
    if (session) {
      request.cookies.set(cookieNames.access, session.access_token);
      request.cookies.set(cookieNames.refresh, session.refresh_token);
      const response = NextResponse.next({ request: { headers: request.headers } });
      response.cookies.set(cookieNames.access, session.access_token, { ...secureCookie, maxAge: 60 * 55 });
      response.cookies.set(cookieNames.refresh, session.refresh_token, { ...secureCookie, maxAge: 60 * 60 * 24 * 14 });
      return response;
    }
    const role = portalRoleFromPath(request.nextUrl.pathname) ?? "principal";
    const login = new URL(`/login/${role}`, request.url);
    login.searchParams.set("next", request.nextUrl.pathname);
    const response = NextResponse.redirect(login);
    Object.values(cookieNames).forEach((name) => response.cookies.set(name, "", { ...secureCookie, maxAge: 0 }));
    return response;
  }
  return NextResponse.next();
}

export const config = { matcher: ["/portal/:path*"] };

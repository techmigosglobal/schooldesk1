import { NextRequest, NextResponse } from "next/server";
import { portalRoleFromPath } from "@/lib/roles";

export function proxy(request: NextRequest) {
  if (!request.nextUrl.pathname.startsWith("/portal")) return NextResponse.next();
  if (!request.cookies.get("schooldesk.access")?.value) {
    const role = portalRoleFromPath(request.nextUrl.pathname) ?? "principal";
    const login = new URL(`/login/${role}`, request.url);
    login.searchParams.set("next", request.nextUrl.pathname);
    return NextResponse.redirect(login);
  }
  return NextResponse.next();
}

export const config = { matcher: ["/portal/:path*"] };

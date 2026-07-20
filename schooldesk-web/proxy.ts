import { NextRequest, NextResponse } from "next/server";

export function proxy(request: NextRequest) {
  if (!request.nextUrl.pathname.startsWith("/portal")) return NextResponse.next();
  if (!request.cookies.get("schooldesk.access")?.value) {
    const login = new URL("/login/principal", request.url);
    login.searchParams.set("next", request.nextUrl.pathname);
    return NextResponse.redirect(login);
  }
  return NextResponse.next();
}

export const config = { matcher: ["/portal/:path*"] };

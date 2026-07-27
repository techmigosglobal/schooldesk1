import { NextRequest, NextResponse } from "next/server";

/** Keep legacy browser favicon requests from producing a 404. */
export function GET(request: NextRequest) {
  return NextResponse.redirect(new URL("/icon.svg", request.url), 307);
}

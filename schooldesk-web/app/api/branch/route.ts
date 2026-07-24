import { NextRequest, NextResponse } from "next/server";
import { cookieNames, secureCookie } from "@/lib/session";

const uuid = /^[0-9a-f-]{36}$/i;

export async function POST(request: NextRequest) {
  const { branchId } = await request.json().catch(() => ({}));
  if (typeof branchId !== "string" || !uuid.test(branchId)) {
    return NextResponse.json({ error: "A valid branch is required." }, { status: 422 });
  }
  const response = NextResponse.json({ success: true });
  response.cookies.set(cookieNames.branch, branchId, { ...secureCookie, maxAge: 60 * 60 * 24 * 14 });
  return response;
}

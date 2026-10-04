import { NextRequest, NextResponse } from "next/server";
import { backendFetch } from "@/lib/backend";
import { cookieNames, secureCookie } from "@/lib/session";

export async function POST(request: NextRequest) {
  const access = request.cookies.get(cookieNames.access)?.value;
  const refresh = request.cookies.get(cookieNames.refresh)?.value;
  if (access) {
    await backendFetch("auth/logout", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${access}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ refresh_token: refresh ?? "" }),
    }).catch(() => undefined);
  }
  const response = NextResponse.json({ success: true });
  Object.values(cookieNames).forEach((name) =>
    response.cookies.set(name, "", { ...secureCookie, maxAge: 0 }),
  );
  return response;
}

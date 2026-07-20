import { NextResponse } from "next/server";
import { cookieNames, secureCookie } from "@/lib/session";
export async function POST() { const response = NextResponse.json({ success: true }); Object.values(cookieNames).forEach((name) => response.cookies.set(name, "", { ...secureCookie, maxAge: 0 })); return response; }

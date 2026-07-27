import { NextRequest, NextResponse } from "next/server";
import { backendFetch, unwrap } from "@/lib/backend";
import { env } from "@/lib/env";
import { checkRateLimit, retryAfterSeconds } from "@/lib/rate-limit";

export async function POST(request: NextRequest) {
  const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  const ip = forwarded || "unknown";
  if (!checkRateLimit(`admission-inquiry:${ip}`, 5, 60_000)) {
    return NextResponse.json({ error: "Please wait before sending another enquiry." }, {
      status: 429, headers: { "Retry-After": String(retryAfterSeconds(`admission-inquiry:${ip}`)) },
    });
  }
  if (!env.SCHOOLDESK_PUBLIC_SCHOOL_ID) {
    return NextResponse.json({ error: "Admissions are not configured yet." }, { status: 503 });
  }
  try {
    const payload = await request.json();
    const upstream = await backendFetch(`website/enquiries?school_id=${encodeURIComponent(env.SCHOOLDESK_PUBLIC_SCHOOL_ID)}`, {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload),
    });
    const body = await upstream.json();
    if (!upstream.ok) return NextResponse.json(body, { status: upstream.status });
    return NextResponse.json(unwrap(body));
  } catch {
    return NextResponse.json({ error: "We could not send your enquiry. Please try again." }, { status: 502 });
  }
}

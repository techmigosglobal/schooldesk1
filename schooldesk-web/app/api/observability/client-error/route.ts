import { NextRequest, NextResponse } from "next/server";

type ErrorPayload = {
  source?: string;
  message?: string;
  stack?: string;
  componentStack?: string;
  route?: string;
};

const recent = new Map<string, { window: number; count: number }>();
const WINDOW_MS = 60_000;
const MAX_PER_WINDOW = 20;

function requestIp(request: NextRequest): string {
  return request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    request.headers.get("x-real-ip")?.trim() || "unknown";
}

function bounded(value: unknown, max: number): string {
  return typeof value === "string" ? value.slice(0, max) : "";
}

export async function POST(request: NextRequest) {
  const ip = requestIp(request);
  const now = Date.now();
  const currentWindow = Math.floor(now / WINDOW_MS);
  const bucket = recent.get(ip);
  if (bucket?.window === currentWindow && bucket.count >= MAX_PER_WINDOW) {
    return NextResponse.json({ accepted: false }, { status: 429 });
  }
  recent.set(ip, {
    window: currentWindow,
    count: bucket?.window === currentWindow ? bucket.count + 1 : 1,
  });
  if (recent.size > 10_000) {
    for (const [key, value] of recent) {
      if (value.window < currentWindow - 1) recent.delete(key);
    }
  }

  const parsed = await request.json().catch(() => ({}));
  const body: ErrorPayload = parsed && typeof parsed === "object"
    ? parsed as ErrorPayload
    : {};
  const requestId = crypto.randomUUID();
  // Structured logs are consumed by the hosting provider's log pipeline.
  // Never accept cookies, authorization headers, or arbitrary request bodies.
  console.error(JSON.stringify({
    event: "schooldesk.client_error",
    request_id: requestId,
    source: bounded(body.source, 32),
    message: bounded(body.message, 2048),
    stack: bounded(body.stack, 12000),
    component_stack: bounded(body.componentStack, 12000),
    route: bounded(body.route, 512),
    user_agent: bounded(request.headers.get("user-agent"), 256),
  }));
  return NextResponse.json(
    { accepted: true, request_id: requestId },
    { status: 202, headers: { "x-request-id": requestId } },
  );
}

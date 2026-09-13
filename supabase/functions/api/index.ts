// ============================================================
// Supabase Edge Function: api/index.ts
// SchoolDesk API Gateway — preserves /api/v1/* contract
// Exams, exam-schedules, results, assistant → 404
// ============================================================

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleAuth } from "./handlers/auth.ts";
import { handleHealth } from "./handlers/health.ts";
import { handleSchools } from "./handlers/schools.ts";
import { handleBranches } from "./handlers/branches.ts";
import { handleDashboard } from "./handlers/dashboard.ts";
import { handleAcademics } from "./handlers/academics.ts";
import { handleCalendar } from "./handlers/calendar.ts";
import { handlePrincipal } from "./handlers/principal.ts";
import { handleStaff } from "./handlers/staff.ts";
import { handleDailyClaims } from "./handlers/daily_claims.ts";
import { handleGuardians, handleStudents } from "./handlers/students.ts";
import { handleUsers } from "./handlers/users.ts";
import { handleApprovals } from "./handlers/approvals.ts";
import { handleAttendance } from "./handlers/attendance.ts";
import { handleFees } from "./handlers/fees.ts";
import { handleLeave } from "./handlers/leave.ts";
import { handleTimetable } from "./handlers/timetable.ts";
import { handleCommunications } from "./handlers/communications.ts";
import {
  handleDocuments,
  handleLandingFeed,
  handleUploads,
} from "./handlers/uploads.ts";
import { handleEvents } from "./handlers/events.ts";
import { handleParent } from "./handlers/parent.ts";
import { handleReports } from "./handlers/reports.ts";
import { handleMonitoring } from "./handlers/monitoring.ts";
import { handleHomework } from "./handlers/homework.ts";
import { handleMedical } from "./handlers/medical.ts";
import { handleHealthReminders } from "./handlers/health_reminders.ts";
import { handleBirthdayAlerts } from "./handlers/birthday_alerts.ts";
import { handleNotifications } from "./handlers/notifications.ts";
import {
  handleSheetsSyncStudent,
  handleSheetsSyncTimetable,
} from "./handlers/sheets_sync.ts";
import {
  handleSheetsPullAll,
  handleSheetsPullStudents,
  handleSheetsPullTimetable,
} from "./handlers/sheets_pull.ts";
import { handleHelp } from "./handlers/help.ts";
import { handleAccess } from "./handlers/access.ts";
import { handleIssues } from "./handlers/issues.ts";
import {
  handleAdmissionInquiries,
  handleWebsite,
  handleWebsiteEnquiry,
  handleWebsitePublic,
} from "./handlers/website.ts";
import { handleDemo } from "./handlers/demo.ts";
import {
  handleActivity,
  recordActivity,
  recordHttpActivity,
} from "./handlers/activity.ts";
import {
  consumeRateLimit,
  RateLimitBackendError,
  rateLimitHeaders,
  RateLimitPolicy,
} from "./lib/rate_limit.ts";

let schemaReloadPromise: Promise<void> | null = null;

type DirectSql = {
  (strings: TemplateStringsArray, ...values: unknown[]): Promise<unknown[]>;
  unsafe: (query: string) => Promise<unknown[]>;
  end: (options?: { timeout?: number }) => Promise<void>;
};

// The API currently has no generated Database type.  Explicitly keeping the
// service client on Supabase's generic schema prevents an untyped
// `createClient()` return from inferring table builders as `never` during Deno
// checks, while leaving the runtime query behavior unchanged.  Replace this
// with the generated schema type when the migration type pipeline is added.
type ServiceClient = SupabaseClient<any>;
let sharedServiceClient: ServiceClient | null = null;
type QueryResult<T> = {
  data: T | null;
  error: { message?: string } | null;
};
type UserProfileRow = { id: string; is_active: boolean; school_id: string };
type MembershipRow = { id: string };

async function withDirectSql<T>(
  callback: (sql: DirectSql) => Promise<T>,
): Promise<T | null> {
  const dbUrl = Deno.env.get("SUPABASE_DB_URL");
  if (!dbUrl) return null;

  let sql: DirectSql | null = null;
  try {
    const postgresModule = await import("postgres");
    sql = postgresModule.default(dbUrl, {
      prepare: false,
      max: 1,
      idle_timeout: 1,
      connect_timeout: 5,
    }) as DirectSql;
    return await callback(sql);
  } finally {
    if (sql) {
      await sql.end({ timeout: 1 }).catch(() => undefined);
    }
  }
}

// ── CORS ──────────────────────────────────────────────────────
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, idempotency-key, x-school-id, x-schooldesk-branch-id, x-job-secret",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
};

export function cors(
  body: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}

export function ok(data: unknown): Response {
  return cors({ success: true, data });
}

export function fail(message: string, status = 400): Response {
  return cors({ success: false, error: message }, status);
}

export function notFound(path: string): Response {
  return cors({ success: false, error: "not_found", path }, 404);
}

type IdempotencyRow = {
  id: string;
  method: string;
  path: string;
  request_hash: string;
  state: "processing" | "completed";
  response_status: number | null;
  response_body: string | null;
  response_content_type: string | null;
};

function isIdempotentMutation(method: string): boolean {
  return method === "POST" || method === "PUT" || method === "PATCH" ||
    method === "DELETE";
}

async function sha256Hex(input: BufferSource): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", input);
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

async function requestHash(req: Request): Promise<string> {
  const contentType = req.headers.get("content-type")?.toLowerCase() ?? "";
  const requestUrl = new URL(req.url);
  const requestScope = [
    requestUrl.pathname,
    requestUrl.search,
    (req.headers.get("x-schooldesk-branch-id") ?? "").trim(),
  ].join("\u0000");
  let bodyHash: string;
  if (contentType.startsWith("multipart/form-data")) {
    try {
      // Multipart boundaries are generated per request, so hash the logical
      // fields and file content instead of the wire encoding.
      const form = await req.clone().formData();
      const parts: string[] = [];
      // `FormData.entries()` is not present in the Edge runtime's bundled
      // TypeScript lib. `forEach` is supported by both Deno and the browser,
      // while collecting promises preserves async file hashing correctly.
      const partHashes: Promise<void>[] = [];
      form.forEach((value, name) => {
        partHashes.push((async () => {
          if (typeof value === "string") {
            parts.push(`${name}\u0000text\u0000${value}`);
            return;
          }
          const fileHash = await sha256Hex(await value.arrayBuffer());
          parts.push(
            `${name}\u0000file\u0000${value.name}\u0000${value.type}\u0000${fileHash}`,
          );
        })());
      });
      await Promise.all(partHashes);
      parts.sort();
      bodyHash = await sha256Hex(new TextEncoder().encode(parts.join("\n")));
    } catch (_error) {
      // Fall back to the raw body if a platform cannot parse FormData.
      bodyHash = await sha256Hex(await req.clone().arrayBuffer());
    }
  } else {
    bodyHash = await sha256Hex(await req.clone().arrayBuffer());
  }
  return sha256Hex(
    new TextEncoder().encode(`${requestScope}\u0000${bodyHash}`),
  );
}

function replayIdempotentResponse(row: IdempotencyRow): Response {
  return new Response(row.response_body ?? "", {
    status: row.response_status ?? 200,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": row.response_content_type ?? "application/json",
      "Idempotency-Replayed": "true",
    },
  });
}

/**
 * Reserve and complete a mutation replay key around the existing handler
 * router. The service-role ledger is deliberately not exposed through RLS;
 * callers can only influence it by presenting a valid authenticated request.
 */
async function withIdempotency(
  req: Request,
  handler: () => Promise<Response>,
): Promise<Response> {
  const method = req.method.toUpperCase();
  const key = (req.headers.get("Idempotency-Key") ?? "").trim();
  if (!isIdempotentMutation(method) || !key) return await handler();

  const { user, client, svc } = await authedClient(req);
  if (!user || !client) return await handler();
  const schoolId = `${user.app_metadata?.school_id ?? ""}`.trim();
  if (!schoolId) return await handler();

  const path = new URL(req.url).pathname
    .replace(/^\/functions\/v1\/api/, "")
    .replace(/^\/api\/v1/, "") || "/";
  const hash = await requestHash(req);
  const baseQuery = svc.from("api_idempotency_keys")
    .select(
      "id, method, path, request_hash, state, response_status, response_body, response_content_type",
    )
    .eq("user_id", user.id)
    .eq("school_id", schoolId)
    .eq("idempotency_key", key)
    .maybeSingle();
  const existingResult = await baseQuery;
  if (existingResult.error) {
    console.error("Idempotency ledger read failed", existingResult.error);
    return fail("idempotency store unavailable", 503);
  }
  const existing = existingResult.data as IdempotencyRow | null;
  if (existing) {
    if (
      existing.method !== method || existing.path !== path ||
      existing.request_hash !== hash
    ) {
      return fail("idempotency key was reused for a different request", 409);
    }
    if (existing.state === "completed") {
      return replayIdempotentResponse(existing);
    }
    return fail("request with this idempotency key is still processing", 409);
  }

  const inserted = await svc.from("api_idempotency_keys").insert({
    user_id: user.id,
    school_id: schoolId,
    idempotency_key: key,
    method,
    path,
    request_hash: hash,
  });
  if (inserted.error) {
    // A concurrent retry may win the unique insert. Re-read it and let the
    // normal replay/conflict path decide what the caller should receive.
    if (`${inserted.error.code ?? ""}` === "23505") {
      const raced = await svc.from("api_idempotency_keys")
        .select(
          "id, method, path, request_hash, state, response_status, response_body, response_content_type",
        )
        .eq("user_id", user.id)
        .eq("school_id", schoolId)
        .eq("idempotency_key", key)
        .maybeSingle();
      if (!raced.error && raced.data) {
        const row = raced.data as IdempotencyRow;
        if (
          row.method !== method || row.path !== path ||
          row.request_hash !== hash
        ) return fail("idempotency key was reused for a different request", 409);
        if (row.state === "completed") return replayIdempotentResponse(row);
        return fail("request with this idempotency key is still processing", 409);
      }
    }
    console.error("Idempotency ledger reservation failed", inserted.error);
    return fail("idempotency store unavailable", 503);
  }

  let response: Response;
  try {
    response = await handler();
  } catch (error) {
    // No handler response means no committed API result to replay. Releasing
    // the reservation allows a retry to make progress after a transient
    // server exception.
    await svc.from("api_idempotency_keys").delete()
      .eq("user_id", user.id).eq("school_id", schoolId)
      .eq("idempotency_key", key);
    throw error;
  }

  const responseBody = await response.clone().text();
  if (response.status >= 500) {
    // A server failure did not produce a replayable business result. Release
    // the reservation so the outbox can retry the same key after backoff.
    await svc.from("api_idempotency_keys").delete()
      .eq("user_id", user.id).eq("school_id", schoolId)
      .eq("idempotency_key", key);
    return response;
  }
  const completed = await svc.from("api_idempotency_keys").update({
    state: "completed",
    response_status: response.status,
    response_body: responseBody,
    response_content_type: response.headers.get("content-type") ??
      "application/json",
    completed_at: new Date().toISOString(),
  }).eq("user_id", user.id).eq("school_id", schoolId)
    .eq("idempotency_key", key);
  if (completed.error) {
    // Preserve the original result. The request itself succeeded, while the
    // log failure is observable and the next retry will safely fail closed.
    console.error("Idempotency ledger completion failed", completed.error);
  }
  return response;
}

function requestIp(req: Request): string {
  // The local CLI and the production ingress both provide one of these
  // headers. The ingress must overwrite forwarded values before this boundary;
  // an absent address is intentionally placed in one shared fail-closed
  // bucket instead of disabling abuse protection.
  const forwarded = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  // Kong's local gateway may add a constant loopback address to every
  // request. Prefer the caller-supplied forwarding value in that isolated
  // environment so deterministic local abuse tests can use separate buckets;
  // production ingress headers remain authoritative outside loopback.
  const hostname = new URL(req.url).hostname;
  if (hostname === "127.0.0.1" || hostname === "localhost" || hostname === "::1") {
    return (forwarded ?? req.headers.get("x-real-ip") ?? "unknown").trim() || "unknown";
  }
  return (req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-real-ip") ?? forwarded ?? "unknown").trim() || "unknown";
}

async function enforceRateLimit(
  req: Request,
  policy: RateLimitPolicy,
  userId?: string,
): Promise<Response | null> {
  try {
    const decision = await consumeRateLimit(
      serviceClient(),
      policy,
      policy === "login" || policy === "public"
        ? { ip: requestIp(req) }
        : { userId },
    );
    if (!decision.allowed) {
      return cors(
        { success: false, error: "rate_limited", code: policy },
        429,
        rateLimitHeaders(decision),
      );
    }
    return null;
  } catch (error) {
    // A missing/unavailable counter store must not silently turn into an
    // unbounded API. The service-role RPC itself is the only permitted writer.
    if (error instanceof RateLimitBackendError) {
      console.error(`Rate-limit backend unavailable (${policy})`);
    } else {
      console.error(`Rate-limit enforcement failed (${policy})`, error);
    }
    return fail("rate limiter unavailable", 503);
  }
}

function isSensitiveAccountPath(path: string, method: string): boolean {
  if (method === "GET" || method === "HEAD") return false;
  return path.startsWith("/staff") || path.startsWith("/users") ||
    path.startsWith("/account-approvals") || path.startsWith("/approvals") ||
    path.startsWith("/access") || path.startsWith("/parents/");
}

async function auditedResponse(
  response: Promise<Response>,
  svc: ReturnType<typeof serviceClient>,
  user: NonNullable<Awaited<ReturnType<typeof authedClient>>["user"]>,
  path: string,
  method: string,
  requestPayload: Record<string, unknown> = {},
) {
  const resolved = await response;
  if (resolved.status === 403) {
    // Keep denial telemetry deliberately metadata-only: no request body,
    // credentials, PII, or resource contents are copied into the audit trail.
    const denial = recordActivity(svc, {
      schoolId: `${user.app_metadata?.school_id ?? ""}`,
      userId: user.id,
      actorRole: `${user.app_metadata?.role_name ?? ""}`.toLowerCase(),
      action: "authorization.denied",
      module: path.split("/").filter(Boolean).at(0) || "system",
      eventType: "authorization_denied",
      summary: "Authorization denied",
      entityType: "http_route",
      entityId: undefined,
      actorName: undefined,
      details: { path, method, status: resolved.status },
    }).catch(() => undefined);
    if (!scheduleAfterResponse(denial)) await denial;
  }
  if (resolved.ok) {
    const activity = (async () => {
      const payload = await resolved.clone().json().catch(() => null);
      if (payload?.success === true || path.endsWith("/export")) {
        await recordHttpActivity(
          svc,
          user,
          path,
          method,
          payload,
          requestPayload,
        ).catch(() => undefined);
      }
    })();
    // Audit persistence is important, but it should not add database latency
    // to every successful API response when EdgeRuntime can finish the work
    // after the response has been handed to the client. Local/CLI runtimes do
    // not provide waitUntil, so they retain the synchronous fallback.
    if (!scheduleAfterResponse(activity)) await activity;
  }
  return resolved;
}

function scheduleAfterResponse(task: Promise<void>): boolean {
  const runtime = (globalThis as unknown as {
    EdgeRuntime?: { waitUntil?: (promise: Promise<unknown>) => void };
  }).EdgeRuntime;
  if (!runtime?.waitUntil) return false;
  runtime.waitUntil(task);
  return true;
}

// ── Supabase clients ──────────────────────────────────────────
export function serviceClient(): ServiceClient {
  if (sharedServiceClient) return sharedServiceClient;
  sharedServiceClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  return sharedServiceClient;
}

// deno-lint-ignore require-await
async function ensureSchemaCacheReady() {
  if (schemaReloadPromise) {
    return schemaReloadPromise;
  }

  schemaReloadPromise = (async () => {
    try {
      await withDirectSql(async (sql) => {
        await sql`NOTIFY pgrst, 'reload schema'`;
        await sql`NOTIFY pgrst, 'reload config'`;
      });
    } catch (_error) {
      // Best-effort: the API can still proceed, and health/ready will expose issues.
    }
  })();

  return schemaReloadPromise;
}

export async function runDbStatements(statements: string[]) {
  if (statements.length === 0) return false;
  const result = await withDirectSql(async (sql) => {
    for (const statement of statements) {
      await sql.unsafe(statement);
    }
    await sql`NOTIFY pgrst, 'reload schema'`;
    await sql`NOTIFY pgrst, 'reload config'`;
    return true;
  });
  return result === true;
}

export async function authedClient(req: Request) {
  const token = req.headers.get("Authorization")?.replace("Bearer ", "");
  const client = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: `Bearer ${token}` } } },
  );
  const { data: { user }, error } = await client.auth.getUser();
  const svc = serviceClient();
  if (error || !user) return { user: null, client: null, svc };

  const requestedBranch = (req.headers.get("x-schooldesk-branch-id") ?? "")
    .trim();
  const requestedIdIsUuid = !requestedBranch ||
    /^[0-9a-f-]{36}$/i.test(requestedBranch);
  if (!requestedIdIsUuid) return { user: null, client: null, svc };
  const currentRole = `${user.app_metadata?.role_name ?? ""}`.toLowerCase();

  // Auth user deletion does not instantly invalidate an already-issued JWT.
  // Require the active application profile on every protected request so a
  // school wipe immediately blocks deleted accounts from using stale tokens.
  // Branch membership is independent of the profile lookup for ordinary
  // roles, so start both queries together after JWT validation.
  const profilePromise: Promise<QueryResult<UserProfileRow>> = svc.from("users")
    .select("id, is_active, school_id").eq("id", user.id)
    .maybeSingle() as unknown as Promise<QueryResult<UserProfileRow>>;
  const membershipPromise: Promise<QueryResult<MembershipRow>> =
    requestedBranch && currentRole !== "super_admin"
      ? svc.from("branch_memberships").select("id")
        .eq("user_id", user.id).eq("school_id", requestedBranch)
        .eq("is_active", true).maybeSingle() as unknown as Promise<
          QueryResult<MembershipRow>
        >
      : Promise.resolve({ data: null, error: null });
  const [{ data: profile, error: profileError }, membershipResult] =
    await Promise.all([profilePromise, membershipPromise]);
  if (profileError || !profile || profile.is_active !== true) {
    return { user: null, client: null, svc };
  }
  if (!requestedBranch) return { user, client, svc };
  let permitted = false;
  if (currentRole === "super_admin") {
    const { data: schools } = await svc.from("schools")
      .select("id, organization_id")
      .in("id", [profile.school_id, requestedBranch]);
    const home = (schools as Record<string, unknown>[] | null | undefined)?.find(
      (school: Record<string, unknown>) => school.id === profile.school_id,
    );
    const requested = (schools as Record<string, unknown>[] | null | undefined)?.find(
      (school: Record<string, unknown>) => school.id === requestedBranch,
    );
    permitted = Boolean(
      home?.organization_id &&
        requested?.organization_id &&
        home.organization_id === requested.organization_id,
    );
  } else if (currentRole === "coordinator") {
    permitted = Boolean(
      requestedBranch === profile.school_id &&
        membershipResult.data,
    );
  } else {
    permitted = Boolean(membershipResult.data);
  }
  if (!permitted) return { user: null, client: null, svc };
  // Existing handlers already derive their scope from app_metadata.school_id.
  // Supply an authenticated, membership-validated branch context without
  // trusting an arbitrary query parameter in every individual handler.
  return {
    user: {
      ...user,
      app_metadata: { ...user.app_metadata, school_id: requestedBranch },
    },
    client,
    svc,
  };
}

export function triggerPushProcessing(eventIds: string | string[]) {
  const ids = (Array.isArray(eventIds) ? eventIds : [eventIds]).filter(Boolean);
  if (ids.length === 0) return;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!supabaseUrl) return;

  const serviceRoleKey = Deno.env.get("NOTIFICATION_PROCESSOR_SECRET") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const promise = fetch(`${supabaseUrl}/functions/v1/notification-processor`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(serviceRoleKey ? { Authorization: `Bearer ${serviceRoleKey}` } : {}),
    },
    body: JSON.stringify({ event_ids: ids, source: "api" }),
  }).then(async (response) => {
    if (!response.ok) {
      console.error(
        `Immediate push processing failed (${response.status}): ${await response
          .text()}`,
      );
    }
  }).catch((error) => {
    console.error(`Immediate push processing failed: ${error}`);
  });

  const runtime = (globalThis as unknown as {
    EdgeRuntime?: { waitUntil?: (promise: Promise<unknown>) => void };
  }).EdgeRuntime;
  if (runtime?.waitUntil) {
    runtime.waitUntil(promise);
  }
}

export async function invokeNotificationProcessor(
  payload: Record<string, unknown>,
) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  if (!supabaseUrl) {
    return {
      ok: false,
      status: 500,
      body: { error: "SUPABASE_URL is not configured" },
    };
  }

  const serviceRoleKey = Deno.env.get("NOTIFICATION_PROCESSOR_SECRET") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  try {
    const response = await fetch(
      `${supabaseUrl}/functions/v1/notification-processor`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(serviceRoleKey
            ? { Authorization: `Bearer ${serviceRoleKey}` }
            : {}),
        },
        body: JSON.stringify(payload),
      },
    );
    const rawText = await response.text();
    let body: unknown = { raw: rawText };
    try {
      body = rawText ? JSON.parse(rawText) : {};
    } catch {
      body = { raw: rawText };
    }
    return {
      ok: response.ok,
      status: response.status,
      body,
    };
  } catch (error) {
    return {
      ok: false,
      status: 500,
      body: { error: String(error) },
    };
  }
}

// ── Router ────────────────────────────────────────────────────
export async function handleApiRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  const url = new URL(req.url);
  const rawPath = url.pathname;
  if (rawPath.endsWith("/health") || rawPath.endsWith("/ready")) {
    return handleHealth(
      req,
      rawPath.endsWith("/health") ? "/health" : "/ready",
      serviceClient(),
    );
  }
  const removedRawPrefixes = [
    "/exams",
    "/exam-schedules",
    "/results",
    "/assistant",
  ];
  if (
    removedRawPrefixes.some((prefix) =>
      rawPath.endsWith(prefix) || rawPath.includes(`${prefix}/`)
    )
  ) {
    return cors(
      { success: false, error: "not_found", code: "endpoint_removed" },
      404,
    );
  }
  // Normalize: strip /functions/v1/api prefix → get /api/v1/... or /health
  let path = url.pathname
    .replace(/^\/functions\/v1\/api/, "")
    .replace(/^\/api\/v1/, "")
    .replace(/^\/api/, "");
  if (!path) {
    path = "/";
  } else if (!path.startsWith("/")) {
    path = `/${path}`;
  }

  const method = req.method.toUpperCase();

  // ── Health (no auth required) ─────────────────────────────
  if (path === "/health" || path === "/ready") {
    return handleHealth(req, path, serviceClient());
  }

  // School creation is a reset-only/local fixture concern. There is no public
  // onboarding endpoint in this build, including for unauthenticated callers.
  if (path === "/schools/setup") {
    return notFound(path);
  }

  // ── Google Sheets real-time synchronization webhooks ──────
  if (path.startsWith("/sheets/")) {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "").trim();
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    // Use environment-based fallback token if configured
    const fallbackToken = Deno.env.get("SHEETS_WEBHOOK_TOKEN") || "";
    const isServiceRole = token.length > 0 && (
      token === serviceKey ||
      (fallbackToken && token === fallbackToken)
    );
    if (!isServiceRole) {
      return cors({ success: false, error: "unauthorized" }, 401);
    }
    const svc = serviceClient();
    if (path === "/sheets/sync-student" && method === "POST") {
      return handleSheetsSyncStudent(req, svc);
    }
    if (path === "/sheets/sync-timetable" && method === "POST") {
      return handleSheetsSyncTimetable(req, svc);
    }
    if (path === "/sheets/pull-students" && method === "POST") {
      return handleSheetsPullStudents(req, svc);
    }
    if (path === "/sheets/pull-timetable" && method === "POST") {
      return handleSheetsPullTimetable(req, svc);
    }
    if (path === "/sheets/pull-all" && method === "POST") {
      return handleSheetsPullAll(req, svc);
    }
    return cors({ success: false, error: "not_found" }, 404);
  }

  // ── Auth routes (no prior auth required for login) ────────
  if (path.startsWith("/auth")) {
    if (path === "/auth/login" && method === "POST") {
      const limited = await enforceRateLimit(req, "login");
      if (limited) return limited;
    } else if (
      path === "/auth/password" || path.startsWith("/auth/profile")
    ) {
      const authContext = await authedClient(req);
      const limited = await enforceRateLimit(
        req,
        authContext.user ? "sensitiveAccount" : "public",
        authContext.user?.id,
      );
      if (limited) return limited;
    } else {
      const limited = await enforceRateLimit(req, "public");
      if (limited) return limited;
    }
    return handleAuth(req, path, method, url);
  }

  // ── Public landing feed (no auth — serves pre-login carousel) ─
  if (path === "/event-posts/landing" && method === "GET") {
    const limited = await enforceRateLimit(req, "public");
    if (limited) return limited;
    return handleLandingFeed(req, url, serviceClient());
  }
  if (path === "/website/public" && method === "GET") {
    const limited = await enforceRateLimit(req, "public");
    if (limited) return limited;
    return handleWebsitePublic(url, serviceClient());
  }
  if (path === "/website/enquiries" && method === "POST") {
    const limited = await enforceRateLimit(req, "public");
    if (limited) return limited;
    return handleWebsiteEnquiry(req, url, serviceClient());
  }
  if (path === "/demo/login" || path === "/jobs/demo-credential-rotation") {
    const limited = await enforceRateLimit(req, "public");
    if (limited) return limited;
    return handleDemo(req, path, method, serviceClient(), null);
  }

  // ── REMOVED: return 404 for exam / assistant routes ───────
  const removedPrefixes = [
    "/exams",
    "/exam-schedules",
    "/results",
    "/assistant",
  ];
  if (removedPrefixes.some((p) => path.startsWith(p))) {
    return cors(
      { success: false, error: "not_found", code: "endpoint_removed" },
      404,
    );
  }

  // ── Birthday alerts (job secret or authenticated user) ──
  if (path.startsWith("/jobs/birthday-alerts")) {
    const { user, client, svc } = await authedClient(req);
    return handleBirthdayAlerts(
      req,
      path,
      method,
      url,
      client,
      svc,
      user,
    );
  }

  // ── Health reminder delivery (4 PM IST scheduled job) ────
  if (path.startsWith("/jobs/health-reminders")) {
    const { user, client, svc } = await authedClient(req);
    return handleHealthReminders(req, path, method, url, client, svc, user);
  }

  // ── All other routes require authentication ────────────────
  const { user, client, svc } = await authedClient(req);
  if (!user || !client) {
    return cors({ success: false, error: "unauthorized" }, 401);
  }

  const ratePolicy: RateLimitPolicy = isSensitiveAccountPath(path, method)
    ? "sensitiveAccount"
    : method === "GET" || method === "HEAD"
    ? "authenticatedRead"
    : "authenticatedWrite";
  const limited = await enforceRateLimit(req, ratePolicy, user.id);
  if (limited) return limited;

  if (path.startsWith("/demo/admin")) {
    return handleDemo(req, path, method, svc, user);
  }

  // Route dispatch
  if (path.startsWith("/branches")) {
    return auditedResponse(
      handleBranches(req, path, method, url, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/schools")) {
    return auditedResponse(
      handleSchools(req, path, method, url, client, svc),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/dashboard")) {
    return auditedResponse(
      handleDashboard(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/class-daily-claims")) {
    return auditedResponse(
      handleDailyClaims(req, path, method, url, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path === "/admission-inquiries" && method === "GET") {
    return handleAdmissionInquiries(svc, user, url);
  }
  if (
    path.startsWith("/academic-years") || path.startsWith("/grades") ||
    path.startsWith("/sections") || path.startsWith("/departments") ||
    path.startsWith("/subjects") || path.startsWith("/grade-subjects") ||
    path.startsWith("/staff-subjects") ||
    path.startsWith("/rooms")
  ) {
    return auditedResponse(
      handleAcademics(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/events") || path.startsWith("/holidays")) {
    return auditedResponse(
      handleCalendar(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (
    path.startsWith("/documents") ||
    path.startsWith("/student-documents") ||
    path.startsWith("/staff-documents")
  ) {
    return auditedResponse(
      handleDocuments(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/principal")) {
    return auditedResponse(
      handlePrincipal(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/website")) {
    return auditedResponse(
      handleWebsite(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/staff")) {
    return auditedResponse(
      handleStaff(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/students")) {
    return auditedResponse(
      handleStudents(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/guardians")) {
    return auditedResponse(
      handleGuardians(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/users")) {
    return auditedResponse(
      handleUsers(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/account-approvals") || path.startsWith("/approvals")) {
    return auditedResponse(
      handleApprovals(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/attendance")) {
    return auditedResponse(
      handleAttendance(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (
    path.startsWith("/fee") || path.startsWith("/fees") ||
    path.startsWith("/parent/students/")
  ) {
    const feeRequestPayload = method === "GET"
      ? {}
      : await req.clone().json().catch(() => ({})) as Record<string, unknown>;
    return auditedResponse(
      handleFees(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
      feeRequestPayload,
    );
  }
  if (path.startsWith("/leave") || path.startsWith("/student-leave")) {
    return auditedResponse(
      handleLeave(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/homework")) {
    return auditedResponse(
      handleHomework(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/medical-records")) {
    return auditedResponse(
      handleMedical(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/health-reminders")) {
    return handleHealthReminders(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/timetable")) {
    return auditedResponse(
      handleTimetable(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (
    path.startsWith("/notifications/register-token") ||
    path.startsWith("/notifications/revoke-token") ||
    path.startsWith("/notifications/device-tokens") ||
    path.startsWith("/notifications/unread-count") ||
    path.startsWith("/notifications/preferences") ||
    path.startsWith("/notifications/subscribe") ||
    path.startsWith("/notifications/unsubscribe")
  ) {
    return auditedResponse(
      handleNotifications(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (
    path.startsWith("/chat") ||
    path.startsWith("/announcements") || path.startsWith("/notices") ||
    path.startsWith("/message") ||
    path.startsWith("/communications") ||
    path.startsWith("/lesson-planners") ||
    path.startsWith("/diary-entries") ||
    path === "/notifications" ||
    path.startsWith("/notifications/")
  ) {
    return auditedResponse(
      handleCommunications(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/uploads")) {
    return auditedResponse(
      handleUploads(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/event-posts")) {
    return auditedResponse(
      handleEvents(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/me/students") || path.startsWith("/parents")) {
    return auditedResponse(
      handleParent(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/help")) {
    return handleHelp(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/access")) {
    return auditedResponse(
      handleAccess(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/issues")) {
    return auditedResponse(
      handleIssues(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }
  if (path.startsWith("/audit-logs")) {
    return handleActivity(path, method, url, svc, user);
  }
  if (path.startsWith("/monitoring")) {
    return handleMonitoring(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/reports")) {
    return auditedResponse(
      handleReports(req, path, method, url, client, svc, user),
      svc,
      user,
      path,
      method,
    );
  }

  return notFound(path);
}

// Keep imports side-effect free for contract/unit tests. Supabase/Deno runs
// this module as the entrypoint, where import.meta.main is true.
if (import.meta.main) {
  Deno.serve((req: Request) => withIdempotency(req, () => handleApiRequest(req)));
}

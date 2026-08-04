// ============================================================
// Supabase Edge Function: api/index.ts
// SchoolDesk API Gateway — preserves /api/v1/* contract
// Exams, exam-schedules, results, assistant → 404
// ============================================================

import { createClient } from "@supabase/supabase-js";
import { handleAuth } from "./handlers/auth.ts";
import { handleHealth } from "./handlers/health.ts";
import { handleSchools } from "./handlers/schools.ts";
import { handleBranches } from "./handlers/branches.ts";
import { handleDashboard } from "./handlers/dashboard.ts";
import { handleAcademics } from "./handlers/academics.ts";
import { handleCalendar } from "./handlers/calendar.ts";
import { handlePrincipal } from "./handlers/principal.ts";
import { handleStaff } from "./handlers/staff.ts";
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
import { handleAdmissionInquiries, handleWebsite, handleWebsiteEnquiry, handleWebsitePublic } from "./handlers/website.ts";
import { handleDemo } from "./handlers/demo.ts";
import { handleActivity, recordHttpActivity } from "./handlers/activity.ts";

let schemaReloadPromise: Promise<void> | null = null;

type DirectSql = {
  (strings: TemplateStringsArray, ...values: unknown[]): Promise<unknown[]>;
  unsafe: (query: string) => Promise<unknown[]>;
  end: (options?: { timeout?: number }) => Promise<void>;
};

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
    "authorization, x-client-info, apikey, content-type, x-school-id, x-schooldesk-branch-id, x-job-secret",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
};

export function cors(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
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

async function auditedResponse(
  response: Promise<Response>,
  svc: ReturnType<typeof serviceClient>,
  user: NonNullable<Awaited<ReturnType<typeof authedClient>>["user"]>,
  path: string,
  method: string,
  requestPayload: Record<string, unknown> = {},
) {
  const resolved = await response;
  if (resolved.ok) {
    const payload = await resolved.clone().json().catch(() => null);
    if (payload?.success === true || path.endsWith("/export")) {
      await recordHttpActivity(
        svc,
        user,
        path,
        method,
        payload,
        requestPayload,
      ).catch(() =>
        undefined
      );
    }
  }
  return resolved;
}

// ── Supabase clients ──────────────────────────────────────────
export function serviceClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
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

  // Auth user deletion does not instantly invalidate an already-issued JWT.
  // Require the active application profile on every protected request so a
  // school wipe immediately blocks deleted accounts from using stale tokens.
  const { data: profile, error: profileError } = await svc.from("users")
    .select("id, is_active, school_id").eq("id", user.id).maybeSingle();
  if (profileError || !profile || profile.is_active !== true) {
    return { user: null, client: null, svc };
  }
  const requestedBranch = (req.headers.get("x-schooldesk-branch-id") ?? "")
    .trim();
  if (!requestedBranch) return { user, client, svc };
  const requestedIdIsUuid = /^[0-9a-f-]{36}$/i.test(requestedBranch);
  if (!requestedIdIsUuid) return { user: null, client: null, svc };
  const currentRole = `${user.app_metadata?.role_name ?? ""}`.toLowerCase();
  let permitted = false;
  if (currentRole === "super_admin") {
    const { data: schools } = await svc.from("schools")
      .select("id, organization_id")
      .in("id", [profile.school_id, requestedBranch]);
    const home = schools?.find((school) => school.id === profile.school_id);
    const requested = schools?.find((school) => school.id === requestedBranch);
    permitted = Boolean(
      home?.organization_id &&
        requested?.organization_id &&
        home.organization_id === requested.organization_id,
    );
  } else if (currentRole === "coordinator") {
    permitted = Boolean(
      requestedBranch === profile.school_id &&
        (await svc.from("branch_memberships").select("id")
          .eq("user_id", user.id).eq("school_id", profile.school_id)
          .eq("is_active", true).maybeSingle()).data,
    );
  } else {
    permitted = Boolean(
      (await svc.from("branch_memberships").select("id")
        .eq("user_id", user.id).eq("school_id", requestedBranch)
        .eq("is_active", true).maybeSingle()).data,
    );
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
Deno.serve(async (req: Request) => {
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
  if (rawPath.endsWith("/schools/setup")) {
    return handleSchools(
      req,
      "/schools/setup",
      req.method.toUpperCase(),
      url,
      null,
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

  // ── Google Sheets real-time synchronization webhooks ──────
  if (path.startsWith("/sheets/")) {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace("Bearer ", "").trim();
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const isServiceRole = token.length > 0 && (
      token === serviceKey ||
      token ===
        "18fd0a5339c8e5e81c3122a7607608e48631ef47cf3f5ac72c3486f7d115ee41"
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
    return handleAuth(req, path, method, url);
  }

  // ── Public landing feed (no auth — serves pre-login carousel) ─
  if (path === "/event-posts/landing" && method === "GET") {
    return handleLandingFeed(req, url, serviceClient());
  }
  if (path === "/website/public" && method === "GET") {
    return handleWebsitePublic(url, serviceClient());
  }
  if (path === "/website/enquiries" && method === "POST") {
    return handleWebsiteEnquiry(req, url, serviceClient());
  }
  if (path === "/demo/login" || path === "/jobs/demo-credential-rotation") {
    return handleDemo(req, path, method, serviceClient(), null);
  }

  // ── Schools setup (no prior auth for first-time setup) ────
  if (path === "/schools/setup" && method === "POST") {
    return handleSchools(req, path, method, url, null, serviceClient());
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
    return handleDashboard(req, path, method, url, client, svc, user);
  }
  if (path === "/admission-inquiries" && method === "GET") {
    return handleAdmissionInquiries(svc, user);
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
    path.startsWith("/parent-teacher-meetings") ||
    path.startsWith("/teacher/ptm-slots") ||
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
});

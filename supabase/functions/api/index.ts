// ============================================================
// Supabase Edge Function: api/index.ts
// SchoolDesk API Gateway — preserves /api/v1/* contract
// Exams, exam-schedules, results, assistant → 404
// ============================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleAuth } from "./handlers/auth.ts";
import { handleHealth } from "./handlers/health.ts";
import { handleSchools } from "./handlers/schools.ts";
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
import { handleDocuments, handleUploads } from "./handlers/uploads.ts";
import { handleEvents } from "./handlers/events.ts";
import { handleParent } from "./handlers/parent.ts";
import { handleReports } from "./handlers/reports.ts";
import { handleMonitoring } from "./handlers/monitoring.ts";
import { handleHomework } from "./handlers/homework.ts";
import { handleMedical } from "./handlers/medical.ts";

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
    const postgresModule = await import("npm:postgres@3.4.5");
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
    "authorization, x-client-info, apikey, content-type, x-school-id",
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

// ── Supabase clients ──────────────────────────────────────────
export function serviceClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

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
  if (error || !user) return { user: null, client: null, svc: serviceClient() };
  return { user, client, svc: serviceClient() };
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
  await ensureSchemaCacheReady();
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

  // ── Auth routes (no prior auth required for login) ────────
  if (path.startsWith("/auth")) {
    return handleAuth(req, path, method, url);
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

  // ── All other routes require authentication ────────────────
  const { user, client, svc } = await authedClient(req);
  if (!user || !client) {
    return cors({ success: false, error: "unauthorized" }, 401);
  }

  // Route dispatch
  if (path.startsWith("/schools")) {
    return handleSchools(req, path, method, url, client, svc);
  }
  if (path.startsWith("/dashboard")) {
    return handleDashboard(req, path, method, url, client, svc, user);
  }
  if (
    path.startsWith("/academic-years") || path.startsWith("/grades") ||
    path.startsWith("/sections") || path.startsWith("/departments") ||
    path.startsWith("/subjects") || path.startsWith("/grade-subjects") ||
    path.startsWith("/staff-subjects") ||
    path.startsWith("/rooms")
  ) {
    return handleAcademics(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/events") || path.startsWith("/holidays")) {
    return handleCalendar(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/principal")) {
    return handlePrincipal(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/staff")) {
    return handleStaff(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/students")) {
    return handleStudents(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/guardians")) {
    return handleGuardians(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/users")) {
    return handleUsers(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/account-approvals") || path.startsWith("/approvals")) {
    return handleApprovals(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/attendance")) {
    return handleAttendance(req, path, method, url, client, svc, user);
  }
  if (
    path.startsWith("/fee") || path.startsWith("/fees") ||
    path.startsWith("/parent/students/")
  ) {
    return handleFees(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/leave")) {
    return handleLeave(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/homework")) {
    return handleHomework(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/medical-records")) {
    return handleMedical(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/timetable")) {
    return handleTimetable(req, path, method, url, client, svc, user);
  }
  if (
    path.startsWith("/chat") ||
    path.startsWith("/announcements") || path.startsWith("/notices") ||
    path.startsWith("/notifications") || path.startsWith("/message") ||
    path.startsWith("/communications") ||
    path.startsWith("/parent-teacher-meetings") ||
    path.startsWith("/teacher/ptm-slots") ||
    path.startsWith("/lesson-planners") ||
    path.startsWith("/diary-entries")
  ) {
    return handleCommunications(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/uploads")) {
    return handleUploads(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/event-posts")) {
    return handleEvents(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/documents") || path.startsWith("/student-documents")) {
    return handleDocuments(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/me/students") || path.startsWith("/parents")) {
    return handleParent(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/monitoring")) {
    return handleMonitoring(req, path, method, url, client, svc, user);
  }
  if (path.startsWith("/reports")) {
    return handleReports(req, path, method, url, client, svc, user);
  }

  return notFound(path);
});

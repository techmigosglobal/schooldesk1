import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

function text(value: unknown, fallback = ""): string {
  const result = `${value ?? ""}`.trim();
  return result || fallback;
}

export function activityRole(user: User): string {
  return text(user.app_metadata?.role_name).toLowerCase();
}

function isSchoolLeader(user: User) {
  return ["principal", "coordinator", "admin", "super_admin"].includes(
    activityRole(user),
  );
}

export async function recordActivity(
  svc: SupabaseClient,
  input: {
    schoolId: string;
    userId: string;
    actorRole: string;
    action: string;
    module: string;
    eventType: string;
    summary: string;
    entityType?: string;
    entityId?: string;
    actorName?: string;
    details?: Record<string, unknown>;
  },
) {
  if (!input.schoolId || !input.userId) return;
  await svc.from("audit_logs").insert({
    school_id: input.schoolId,
    user_id: input.userId,
    action: input.action,
    module: input.module,
    event_type: input.eventType,
    summary: input.summary,
    entity_type: input.entityType ?? null,
    entity_id: input.entityId ?? null,
    actor_role: input.actorRole,
    actor_name: input.actorName ?? null,
    details: input.details ?? {},
  });
}

export async function recordHttpActivity(
  svc: SupabaseClient,
  user: User,
  path: string,
  method: string,
  payload: unknown,
) {
  if (
    (method === "GET" && !path.endsWith("/export")) ||
    method === "OPTIONS" ||
    path === "/auth/profile"
  ) {
    return;
  }
  const schoolId = text(user.app_metadata?.school_id);
  const role = activityRole(user);
  const data = payload && typeof payload === "object"
    ? (payload as Record<string, unknown>)
    : {};
  const record = data.data && typeof data.data === "object"
    ? data.data as Record<string, unknown>
    : data;
  const module = path.split("/").filter(Boolean).at(0) || "system";
  const isAttendancePunch = path === "/attendance/staff/qr-scan" ||
    path === "/attendance/staff/me/punch-out";
  const punchAction = text(record.punch_action);
  const action = path.endsWith("/export")
    ? `${module}.export`
    : isAttendancePunch
    ? `attendance.${punchAction || "updated"}`
    : `${module}.${method.toLowerCase()}`;
  const summary = path.endsWith("/export")
    ? `${role || "User"} exported ${module} data`
    : isAttendancePunch
    ? `Teacher ${
      punchAction === "check_out" ? "checked out" : "checked in"
    } using ${punchAction === "check_out" ? "staff attendance" : "staff QR"}`
    : `${role || "User"} performed ${method} in ${module}`;
  await recordActivity(svc, {
    schoolId,
    userId: user.id,
    actorRole: role,
    action,
    module,
    eventType: action,
    summary,
    entityType: isAttendancePunch ? "staff_attendance" : module,
    entityId: text(record.id),
    details: isAttendancePunch
      ? { punch_action: punchAction, source: text(record.source) }
      : { path, method },
  });
}

function csvCell(value: unknown) {
  return `"${text(value).replaceAll('"', '""')}"`;
}

export async function handleActivity(
  path: string,
  method: string,
  url: URL,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  if (!isSchoolLeader(user)) return fail("forbidden", 403);
  if (path !== "/audit-logs" && path !== "/audit-logs/export") {
    return fail("not found", 404);
  }
  if (method !== "GET") return fail("method not allowed", 405);
  let query = svc.from("audit_logs").select("*").eq(
    "school_id",
    text(user.app_metadata?.school_id),
  );
  const startDate = text(url.searchParams.get("start_date"));
  const endDate = text(url.searchParams.get("end_date"));
  const module = text(url.searchParams.get("module"));
  const eventType = text(url.searchParams.get("event_type"));
  const actorRole = text(url.searchParams.get("actor_role"));
  const actorId = text(url.searchParams.get("user_id"));
  const search = text(url.searchParams.get("search"));
  if (startDate) query = query.gte("created_at", `${startDate}T00:00:00.000Z`);
  if (endDate) query = query.lt("created_at", `${endDate}T23:59:59.999Z`);
  if (module) query = query.eq("module", module);
  if (eventType) query = query.eq("event_type", eventType);
  if (actorRole) query = query.eq("actor_role", actorRole);
  if (actorId) query = query.eq("user_id", actorId);
  if (search) query = query.ilike("summary", `%${search.replaceAll("%", "")}%`);
  const pageSize = Math.min(
    Math.max(Number(url.searchParams.get("page_size") || 50), 1),
    500,
  );
  const page = Math.max(Number(url.searchParams.get("page") || 1), 1);
  const exportLimit = 5000;
  const limit = path.endsWith("/export") ? exportLimit : pageSize;
  const from = path.endsWith("/export") ? 0 : (page - 1) * pageSize;
  const { data, error } = await query.order("created_at", { ascending: false })
    .range(from, from + limit - 1);
  if (error) return fail(error.message);
  if (path === "/audit-logs/export") {
    const lines = [
      "timestamp,actor,role,module,event,summary,entity_type,entity_id",
      ...(data ?? []).map((row) =>
        [
          row.created_at,
          row.actor_name,
          row.actor_role,
          row.module,
          row.event_type,
          row.summary,
          row.entity_type,
          row.entity_id,
        ].map(csvCell).join(",")
      ),
    ];
    return new Response(lines.join("\n"), {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": "attachment; filename=school_activity_log.csv",
      },
    });
  }
  return ok(data ?? []);
}

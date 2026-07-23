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

function titleCase(value: string): string {
  return value.split(/[_\s-]+/).filter(Boolean).map((part) =>
    part.charAt(0).toUpperCase() + part.slice(1).toLowerCase()
  ).join(" ");
}

function activityTarget(module: string, path: string): string {
  const normalizedPath = path.toLowerCase();
  if (normalizedPath.includes("concession")) return "fee concession";
  if (normalizedPath.includes("receipt")) return "fee receipt";
  if (normalizedPath.includes("payment")) return "fee payment";
  const targets: Record<string, string> = {
    "academic-years": "academic year",
    attendance: "attendance record",
    branches: "school branch",
    communications: "communication",
    "event-posts": "school post",
    events: "school event",
    fees: "fee information",
    guardians: "parent or guardian",
    homework: "homework",
    notifications: "notification settings",
    principal: "school settings",
    staff: "staff record",
    students: "student record",
    users: "user account",
  };
  return targets[module] ?? `${titleCase(module)} record`;
}

function activityVerb(method: string): string {
  switch (method) {
    case "POST":
      return "added";
    case "DELETE":
      return "deleted";
    case "PATCH":
    case "PUT":
      return "updated";
    default:
      return "updated";
  }
}

function activityDescription(
  module: string,
  path: string,
  record: Record<string, unknown>,
): string {
  const normalizedPath = path.toLowerCase();
  const quoted = (value: unknown) => {
    const label = text(value);
    return label ? ` “${label}”` : "";
  };
  if (module === "fees") {
    if (normalizedPath.includes("categories")) {
      return `fee category${quoted(record.name)}`;
    }
    if (normalizedPath.includes("structures")) {
      const feeName = record.name ?? record.title ?? record.category_name ??
        record.fee_category_name;
      const className = text(record.class_name ?? record.grade_name);
      const sectionName = text(record.section_name);
      const scope = [className, sectionName].filter(Boolean).join(" · ");
      return `fee structure${quoted(feeName)}${scope ? ` for ${scope}` : ""}`;
    }
    if (normalizedPath.includes("concession")) {
      return `fee concession${quoted(record.student_name ?? record.invoice_number)}`;
    }
    if (normalizedPath.includes("payment")) {
      return `fee payment${quoted(record.receipt_number ?? record.payment_reference)}`;
    }
    if (normalizedPath.includes("invoice")) {
      return `fee invoice${quoted(record.invoice_number)}`;
    }
  }
  if (module === "students") {
    return `student${quoted(record.name ?? record.student_name ?? record.full_name)}`;
  }
  if (module === "staff") {
    const fullName = [text(record.first_name), text(record.last_name)]
      .filter(Boolean).join(" ");
    return `staff member${quoted(fullName || record.name || record.staff_code)}`;
  }
  if (module === "users") {
    return `user account${quoted(record.name ?? record.username)}`;
  }
  if (module === "events" || module === "event-posts") {
    return `${module === "events" ? "event" : "school post"}${quoted(record.title ?? record.name)}`;
  }
  if (module === "homework") {
    return `homework${quoted(record.title ?? record.subject_name)}`;
  }
  if (module === "attendance") {
    return `attendance${quoted(record.date ?? record.student_name ?? record.staff_name)}`;
  }
  if (module === "academic-years") {
    return `academic year${quoted(record.name ?? record.year_name)}`;
  }
  if (module === "grades" || module === "sections" || module === "subjects") {
    return `${activityTarget(module, path)}${quoted(record.name ?? record.grade_name ?? record.section_name ?? record.subject_name)}`;
  }
  if (module === "communications" || module === "announcements" || module === "notices") {
    return `communication${quoted(record.title ?? record.subject)}`;
  }
  const name = text(
    record.name ?? record.title ?? record.display_name ??
      record.invoice_number ?? record.receipt_number,
  );
  return `${activityTarget(module, path)}${name ? ` “${name}”` : ""}`;
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
  requestPayload: Record<string, unknown> = {},
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
  const auditRecord = { ...requestPayload, ...record };
  const module = path.split("/").filter(Boolean).at(0) || "system";
  const isAttendancePunch = path === "/attendance/staff/qr-scan" ||
    path === "/attendance/staff/me/punch-out";
  const punchAction = text(record.punch_action);
  let actor = titleCase(role || "User");
  try {
    const { data: actorProfile } = await svc.from("users").select(
      "name, username",
    ).eq("id", user.id).maybeSingle();
    actor = text(actorProfile?.name) || text(actorProfile?.username) || actor;
  } catch (_) {
    // Auditing must never turn a completed school action into a failure.
  }
  const target = activityDescription(module, path, auditRecord);
  const action = path.endsWith("/export")
    ? `${module}.export`
    : isAttendancePunch
    ? `attendance.${punchAction || "updated"}`
    : `${module}.${method.toLowerCase()}`;
  const summary = path.endsWith("/export")
    ? `${actor} exported ${titleCase(module)} data`
    : isAttendancePunch
    ? `Teacher ${
      punchAction === "check_out" ? "checked out" : "checked in"
    } using ${punchAction === "check_out" ? "staff attendance" : "staff QR"}`
    : `${actor} ${activityVerb(method)} ${target}`;
  await recordActivity(svc, {
    schoolId,
    userId: user.id,
    actorRole: role,
    action,
    module,
    eventType: action,
    summary,
    entityType: isAttendancePunch ? "staff_attendance" : activityTarget(module, path),
    entityId: text(record.id),
    actorName: actor,
    details: isAttendancePunch
      ? { punch_action: punchAction, source: text(record.source) }
      : { path, method, description: target },
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
  const actor = text(url.searchParams.get("actor"));
  const search = text(url.searchParams.get("search"));
  if (startDate) query = query.gte("created_at", `${startDate}T00:00:00.000Z`);
  if (endDate) query = query.lt("created_at", `${endDate}T23:59:59.999Z`);
  if (module) query = query.eq("module", module);
  if (eventType) query = query.eq("event_type", eventType);
  if (actorRole) query = query.eq("actor_role", actorRole);
  if (actorId) query = query.eq("user_id", actorId);
  if (activityRole(user) === "principal") {
    // A principal can audit activity in their branch, but super-admin work is
    // organization-level administration and is intentionally kept separate.
    query = query.neq("actor_role", "super_admin");
  }
  if (actor) {
    const pattern = `%${actor.replaceAll("%", "").replaceAll("_", "")}%`;
    const [byName, byUsername] = await Promise.all([
      svc.from("users").select("id").eq("school_id", text(user.app_metadata?.school_id))
        .ilike("name", pattern),
      svc.from("users").select("id").eq("school_id", text(user.app_metadata?.school_id))
        .ilike("username", pattern),
    ]);
    if (byName.error || byUsername.error) {
      return fail(byName.error?.message ?? byUsername.error?.message ?? "Unable to search users");
    }
    const ids = [...(byName.data ?? []), ...(byUsername.data ?? [])]
      .map((row) => text(row.id)).filter(Boolean);
    if (ids.length === 0) return ok([]);
    query = query.in("user_id", [...new Set(ids)]);
  }
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

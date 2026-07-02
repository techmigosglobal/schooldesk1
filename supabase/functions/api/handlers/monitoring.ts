import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";

function schoolId(user: User): string {
  return (user.app_metadata?.school_id as string) ?? "";
}

function parseEventId(path: string): string | null {
  const match = path.match(/^\/monitoring\/error-events\/([^/]+)$/);
  return match?.[1] ?? null;
}

function parseResolveId(path: string): string | null {
  const match = path.match(/^\/monitoring\/error-events\/([^/]+)\/resolve$/);
  return match?.[1] ?? null;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function integer(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function mapContext(row: Record<string, unknown>): Record<string, unknown> {
  const context = row["context"];
  if (context && typeof context === "object" && !Array.isArray(context)) {
    return { ...(context as Record<string, unknown>) };
  }
  return {};
}

function metadataRole(value: unknown): string {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return text((value as Record<string, unknown>)["role"]);
  }
  return "";
}

function responseRow(row: Record<string, unknown>) {
  const context = mapContext(row);
  return {
    id: text(row["id"]),
    school_id: text(row["school_id"]),
    user_id: text(row["user_id"]),
    role: text(context["role"]),
    source: text(context["source"]),
    severity: text(context["severity"]) || "error",
    status: text(context["status"]) || "open",
    request_id: text(context["request_id"]),
    error_id: text(context["error_id"]),
    method: text(context["method"]),
    path: text(context["path"]),
    route_name: text(context["route_name"]),
    screen: text(context["screen"]),
    message: text(row["message"]),
    error_type: text(row["error_type"]),
    stack_trace: text(row["stack_trace"]),
    status_code: integer(context["status_code"]) ?? 0,
    metadata: context["metadata"] ?? {},
    app_version: text(context["app_version"]),
    device_info: text(context["device_info"]),
    occurred_at: text(context["occurred_at"]) || text(row["created_at"]),
    resolved_at: text(context["resolved_at"]),
    resolved_by: text(context["resolved_by"]),
    resolution_note: text(context["resolution_note"]),
    created_at: text(row["created_at"]),
  };
}

export async function handleMonitoring(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = schoolId(user);

  if (path === "/monitoring/error-events" && method === "POST") {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const context = {
      source: text(body["source"]),
      severity: text(body["severity"]) || "error",
      status: "open",
      role: metadataRole(body["metadata"]),
      request_id: text(body["request_id"]),
      error_id: text(body["error_id"]),
      method: text(body["method"]),
      path: text(body["path"]),
      route_name: text(body["route_name"]),
      screen: text(body["screen"]),
      status_code: integer(body["status_code"]) ?? 0,
      metadata: body["metadata"] ?? {},
      app_version: text(body["app_version"]),
      device_info: text(body["device_info"]),
      occurred_at: text(body["occurred_at"]),
    };

    const insertPayload = {
      school_id: school,
      user_id: user.id,
      message: text(body["message"]),
      error_type: text(body["error_type"]),
      stack_trace: text(body["stack_trace"]),
      context,
    };
    const { data, error } = await svc.from("error_events").insert(insertPayload)
      .select()
      .single();
    if (error) return fail(error.message);
    return ok(responseRow(data as Record<string, unknown>));
  }

  if (path === "/monitoring/error-events" && method === "GET") {
    const page = parseInt(url.searchParams.get("page") ?? "1");
    const size = parseInt(url.searchParams.get("page_size") ?? "20");
    const { data, error } = await svc.from("error_events").select("*").eq(
      "school_id",
      school,
    ).order("created_at", { ascending: false });
    if (error) return fail(error.message);

    const requestId = text(url.searchParams.get("request_id"));
    const status = text(url.searchParams.get("status"));
    const severity = text(url.searchParams.get("severity"));
    const source = text(url.searchParams.get("source"));

    const filtered = (data ?? []).map((row) =>
      responseRow(row as Record<string, unknown>)
    ).filter((row) => {
      if (requestId.length > 0 && row.request_id != requestId) return false;
      if (status.length > 0 && row.status != status) return false;
      if (severity.length > 0 && row.severity != severity) return false;
      if (source.length > 0 && row.source != source) return false;
      return true;
    });
    const start = Math.max((page - 1) * size, 0);
    const paged = filtered.slice(start, start + size);
    return cors({
      success: true,
      data: paged,
      total: filtered.length,
      page,
      page_size: size,
    });
  }

  const eventId = parseEventId(path);
  if (eventId && method === "GET") {
    const { data, error } = await svc.from("error_events").select("*").eq(
      "school_id",
      school,
    ).eq("id", eventId).maybeSingle();
    if (error) return fail(error.message);
    if (!data) return fail("Error event not found", 404);
    return ok(responseRow(data as Record<string, unknown>));
  }

  const resolveId = parseResolveId(path);
  if (resolveId && method === "PATCH") {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const { data, error } = await svc.from("error_events").select("*").eq(
      "school_id",
      school,
    ).eq("id", resolveId).maybeSingle();
    if (error) return fail(error.message);
    if (!data) return fail("Error event not found", 404);

    const existing = data as Record<string, unknown>;
    const context = mapContext(existing);
    const updatedContext = {
      ...context,
      status: "resolved",
      resolved_at: new Date().toISOString(),
      resolved_by: user.id,
      resolution_note: text(body["resolution_note"]),
    };

    const updated = await svc.from("error_events").update({
      context: updatedContext,
    }).eq("school_id", school).eq("id", resolveId).select().single();
    if (updated.error) return fail(updated.error.message);
    return ok(responseRow(updated.data as Record<string, unknown>));
  }

  return fail("not found", 404);
}

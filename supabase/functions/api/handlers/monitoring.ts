import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok, triggerPushProcessing } from "../index.ts";
import { recordActivity } from "./activity.ts";
import {
  deleteR2File,
  r2FileReference,
  r2KeyFromValue,
  r2Reference,
  r2ReferenceInfo,
} from "../lib/r2_storage.ts";

function schoolId(user: User): string {
  return (user.app_metadata?.school_id as string) ?? "";
}

function isSuperAdmin(user: User): boolean {
  return user.app_metadata?.role_name === "super_admin";
}

async function alertSuperAdminsOfNewError(
  svc: SupabaseClient,
  school: string,
  errorId: string,
  approvalAuditFailure: boolean,
) {
  const { data: admins, error: adminError } = await svc.from("users")
    .select("id")
    .eq("school_id", school)
    .eq("role_name", "super_admin");
  if (adminError) throw adminError;
  const userIds = (admins ?? []).map((row) => text(row.id)).filter(Boolean);
  if (userIds.length === 0) return;

  const title = approvalAuditFailure
    ? "Approval audit failure detected"
    : "New SchoolDesk server error";
  const message =
    "A new server error was recorded. Open System Monitor to review it.";
  const since = new Date(Date.now() - 5 * 60 * 1000).toISOString();
  const { count, error: rateLimitError } = await svc.from("notification_logs")
    .select("id", { count: "exact", head: true })
    .eq("school_id", school)
    .eq("type", "system_alert")
    .gte("created_at", since);
  if (rateLimitError) throw rateLimitError;
  if ((count ?? 0) >= 5 * userIds.length) {
    console.error("error_event_alert_rate_limited", { school_id: school });
    return;
  }
  const notifications = userIds.map((userId) => ({
    school_id: school,
    user_id: userId,
    target_role: "super_admin",
    title,
    body: message,
    type: "system_alert",
    entity_type: "error_event",
    entity_id: errorId,
  }));
  const { error: notificationError } = await svc.from("notification_logs")
    .insert(notifications);
  if (notificationError) throw notificationError;

  const { data: events, error: eventError } = await svc.from(
    "notification_events",
  ).insert(userIds.map((userId) => ({
    school_id: school,
    user_id: userId,
    event_type: "system_alert",
    event_data: {
      title,
      message,
      reference_type: "error_event",
      reference_id: errorId,
      route: "/system-monitor-screen",
    },
  }))).select("id");
  if (eventError) throw eventError;
  const eventIds = (events ?? []).map((row) => text(row.id)).filter(Boolean);
  if (eventIds.length > 0) triggerPushProcessing(eventIds);
}

type StorageObject = { bucket_id: string; name: string };

const wipeStorageBuckets = [
  "school-assets",
  "payment-proofs",
  "issue-attachments",
];

function storagePathFromUrl(value: unknown, bucket: string): string {
  const raw = text(value);
  if (!raw) return "";
  const directPrefix = `${bucket}/`;
  if (raw.startsWith(directPrefix)) return raw.substring(directPrefix.length);
  const marker = `/object/public/${bucket}/`;
  const markerIndex = raw.indexOf(marker);
  if (markerIndex < 0) return "";
  return decodeURIComponent(raw.substring(markerIndex + marker.length));
}

function addStoragePath(
  targets: Map<string, Set<string>>,
  bucket: string,
  value: unknown,
  r2Targets: Set<string>,
) {
  const r2Key = r2KeyFromValue(value);
  if (r2Key) {
    const info = r2ReferenceInfo(value);
    r2Targets.add(info ? r2Reference(info.key, info.visibility) : r2FileReference(r2Key));
    return;
  }
  const path = storagePathFromUrl(value, bucket);
  if (path) (targets.get(bucket) ?? new Set<string>()).add(path);
  if (path && !targets.has(bucket)) targets.set(bucket, new Set([path]));
}

type SchoolWipeAccounts = {
  retainedAccountIds: string[];
  accountIdsToDelete: string[];
};

function isRetainedWipeRole(value: unknown): boolean {
  const role = text(value).toLowerCase();
  return role === "principal" || role === "coordinator" || role === "super_admin";
}

async function collectSchoolWipeAccounts(
  svc: SupabaseClient,
  school: string,
): Promise<SchoolWipeAccounts> {
  const { data: publicAccounts, error: publicAccountsError } = await svc.from(
    "users",
  ).select("id, role_name").eq("school_id", school);
  if (publicAccountsError) throw new Error(publicAccountsError.message);

  const retainedAccountIds = new Set<string>();
  const accountIdsToDelete = new Set<string>();
  let hasPrincipal = false;
  for (const account of publicAccounts ?? []) {
    const id = text(account.id);
    if (!id) continue;
    if (text(account.role_name).toLowerCase() === "principal") {
      hasPrincipal = true;
    }
    if (isRetainedWipeRole(account.role_name)) retainedAccountIds.add(id);
    else accountIdsToDelete.add(id);
  }

  // Auth is not exposed through PostgREST.  Discover every Auth account
  // belonging to this school so orphaned Auth users are removed too.
  for (let page = 1;; page++) {
    const { data, error } = await svc.auth.admin.listUsers({
      page,
      perPage: 1000,
    });
    if (error) throw new Error(error.message);
    const users = data.users ?? [];
    for (const account of users) {
      if (text(account.app_metadata?.school_id) !== school) continue;
      if (text(account.app_metadata?.role_name).toLowerCase() === "principal") {
        hasPrincipal = true;
      }
      if (isRetainedWipeRole(account.app_metadata?.role_name)) {
        retainedAccountIds.add(account.id);
      } else {
        accountIdsToDelete.add(account.id);
      }
    }
    if (users.length < 1000) break;
  }

  // Metadata and the public profile can drift.  Never delete a principal or
  // Super Admin account when either source of truth identifies it as retained.
  for (const id of retainedAccountIds) accountIdsToDelete.delete(id);
  if (!hasPrincipal) {
    // The caller is a Super Admin, but a principal is still required as the
    // school owner's recovery account after a destructive reset.
    throw new Error("Wipe blocked: this school has no principal login to preserve");
  }
  return {
    retainedAccountIds: [...retainedAccountIds],
    accountIdsToDelete: [...accountIdsToDelete],
  };
}

async function deleteSchoolAuthAccounts(
  svc: SupabaseClient,
  accountIds: readonly string[],
) {
  let deletedCount = 0;
  for (const accountId of accountIds) {
    try {
      const { error } = await svc.auth.admin.deleteUser(accountId);
      if (error) {
        // If the user does not exist in Auth, we can ignore the error
        const msg = error.message?.toLowerCase() || "";
        if (error.status === 404 || msg.includes("not found")) {
          console.warn(`Auth user ${accountId} not found for deletion, skipping`);
          continue;
        }
        throw new Error(error.message);
      }
      deletedCount++;
    } catch (err) {
      // Log exception but do not abort the entire wipe process
      console.error(`Exception while deleting auth user ${accountId}:`, err);
    }
  }
  return deletedCount;
}

async function wipeSchoolStorage(
  svc: SupabaseClient,
  school: string,
  retainedAccountIds: readonly string[],
) {
  const targets = new Map<string, Set<string>>();
  const r2Targets = new Set<string>();
  for (const bucket of wipeStorageBuckets) targets.set(bucket, new Set());

  const [
    objectsResult,
    issueResult,
    paymentResult,
    studentDocumentResult,
    staffDocumentResult,
    uploadResult,
    studentResult,
    staffResult,
  ] = await Promise.all([
    svc.schema("storage").from("objects").select("bucket_id, name")
      .in("bucket_id", wipeStorageBuckets)
      .like("name", `%${school}%`),
    svc.from("issue_attachments").select("storage_path").eq("school_id", school),
    svc.from("parent_payment_requests").select("proof_url").eq("school_id", school),
    svc.from("student_documents").select("file_url").eq("school_id", school),
    svc.from("staff_documents").select("file_url").eq("school_id", school),
    svc.from("uploaded_files").select("path").eq("school_id", school),
    svc.from("students").select("photo_url").eq("school_id", school),
    svc.from("staff").select("photo_url").eq("school_id", school),
  ]);
  const results = [
    objectsResult,
    issueResult,
    paymentResult,
    studentDocumentResult,
    staffDocumentResult,
    uploadResult,
    studentResult,
    staffResult,
  ];
  const failed = results.find((result) => result.error);
  if (failed?.error) throw failed.error;

  for (const object of (objectsResult.data ?? []) as StorageObject[]) {
    // The school's branding and retained account avatars survive.
    if (
      object.name.startsWith(`logos/${school}/`) ||
      retainedAccountIds.some((id) =>
        object.name.startsWith(`avatars/${school}/${id}/`)
      )
    ) continue;
    targets.get(object.bucket_id)?.add(object.name);
  }
  for (const row of issueResult.data ?? []) {
    const path = text(row.storage_path);
    const r2Key = r2KeyFromValue(path);
    if (r2Key) {
      const info = r2ReferenceInfo(path);
      r2Targets.add(info ? r2Reference(info.key, info.visibility) : r2FileReference(r2Key));
    }
    else if (path) targets.get("issue-attachments")?.add(path);
  }
  for (const row of paymentResult.data ?? []) {
    addStoragePath(targets, "payment-proofs", row.proof_url, r2Targets);
  }
  for (const row of studentDocumentResult.data ?? []) {
    addStoragePath(targets, "school-assets", row.file_url, r2Targets);
  }
  for (const row of staffDocumentResult.data ?? []) {
    addStoragePath(targets, "school-assets", row.file_url, r2Targets);
  }
  for (const row of uploadResult.data ?? []) {
    addStoragePath(targets, "school-assets", row.path, r2Targets);
  }
  for (const row of studentResult.data ?? []) {
    addStoragePath(targets, "school-assets", row.photo_url, r2Targets);
  }
  for (const row of staffResult.data ?? []) {
    addStoragePath(targets, "school-assets", row.photo_url, r2Targets);
  }

  let removed = 0;
  for (const [bucket, paths] of targets.entries()) {
    if (paths.size === 0) continue;
    for (const batch of Array.from(paths).reduce<string[][]>((all, path, index) => {
      const batchIndex = Math.floor(index / 100);
      (all[batchIndex] ??= []).push(path);
      return all;
    }, [])) {
      try {
        const { data, error } = await svc.storage.from(bucket).remove(batch);
        if (error) {
          console.error(`Failed to remove storage files in bucket ${bucket}:`, error.message);
        } else if (data) {
          removed += data.length;
        }
      } catch (err) {
        console.error(`Exception while removing storage files in bucket ${bucket}:`, err);
      }
    }
  }
  for (const key of r2Targets) {
    try {
      if (await deleteR2File(key)) removed++;
    } catch (error) {
      console.error(`Failed to remove R2 object ${key}:`, error);
    }
  }
  return removed;
}

function parseEventId(path: string): string | null {
  const match = path.match(/^\/monitoring\/error-events\/([^/]+)$/);
  return match?.[1] ?? null;
}

function parseResolveId(path: string): string | null {
  const match = path.match(/^\/monitoring\/error-events\/([^/]+)\/resolve$/);
  return match?.[1] ?? null;
}

function isErrorRetentionPath(path: string): boolean {
  return path === "/monitoring/error-events/retention";
}

function isErrorCleanupPath(path: string): boolean {
  return path === "/monitoring/error-events/cleanup";
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

function boundedText(value: unknown, max: number): string {
  return text(value).slice(0, max);
}

function validSeverity(value: string): value is "info" | "warning" | "error" | "fatal" {
  return ["info", "warning", "error", "fatal"].includes(value);
}

async function errorFingerprint(input: {
  errorType: string;
  message: string;
  source: string;
  path: string;
  stackTrace: string;
}): Promise<string> {
  // Dynamic values such as IDs and line numbers make duplicate errors look
  // unique.  Retain only the stable beginning of each field before hashing.
  const normalized = [
    input.errorType,
    input.source,
    input.path,
    input.message.replace(/[0-9a-f]{8}-[0-9a-f-]{27,}/gi, "<id>").slice(0, 320),
    input.stackTrace.replace(/:\d+(?::\d+)?/g, ":<line>").slice(0, 1200),
  ].join("|").toLowerCase();
  const bytes = new TextEncoder().encode(normalized);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((value) =>
    value.toString(16).padStart(2, "0")
  ).join("");
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
    severity: text(row["severity"]) || text(context["severity"]) || "error",
    status: text(row["status"]) || text(context["status"]) || "open",
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
    occurrence_count: integer(row["occurrence_count"]) ?? 1,
    first_seen_at: text(row["first_seen_at"]) || text(row["created_at"]),
    last_seen_at: text(row["last_seen_at"]) || text(row["created_at"]),
    fingerprint: text(row["fingerprint"]),
    resolved_at: text(row["resolved_at"]) || text(context["resolved_at"]),
    resolved_by: text(row["resolved_by"]) || text(context["resolved_by"]),
    resolution_note: text(row["resolution_note"]) || text(context["resolution_note"]),
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

  // ── Database Backup ───────────────────────────────────────
  if (path === "/monitoring/database/backup" && method === "GET") {
    if (user.app_metadata?.role_name !== "super_admin") {
      return fail("Unauthorized: SuperAdmin role required", 403);
    }
    try {
      const tables = [
        "academic_years", "terms", "grades", "rooms", "subjects", "staff",
        "staff_qualifications", "staff_subjects", "sections", "grade_subjects",
        "students", "guardians", "student_guardians", "medical_records",
        "student_documents", "attendance_sessions", "student_attendances",
        "attendance_summaries", "fee_categories", "fee_structures",
        "fee_invoices", "fee_invoice_items", "payments", "fee_receipts",
        "parent_payment_requests", "school_payment_settings", "leave_types",
        "leave_balances", "student_leave_applications", "announcements",
        "events", "parent_teacher_meetings", "timetable_slots", "frontend_records"
      ];
      const backup: Record<string, unknown[]> = {};
      for (const table of tables) {
        const { data, error } = await svc.from(table).select("*").eq("school_id", school);
        if (error) {
          if (error.message.includes("school_id") && error.message.includes("does not exist")) {
            const { data: allData, error: allErr } = await svc.from(table).select("*");
            if (allErr) return fail(`Backup failed on table ${table}: ${allErr.message}`);
            backup[table] = allData ?? [];
          } else {
            return fail(`Backup failed on table ${table}: ${error.message}`);
          }
        } else {
          backup[table] = data ?? [];
        }
      }
      return ok(backup);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return fail(msg);
    }
  }

  // ── Database Restore ──────────────────────────────────────
  if (path === "/monitoring/database/restore" && method === "POST") {
    if (user.app_metadata?.role_name !== "super_admin") {
      return fail("Unauthorized: SuperAdmin role required", 403);
    }
    try {
      const body = await req.json().catch(() => ({})) as Record<string, unknown[]>;
      const restoreOrder = [
        "academic_years", "terms", "grades", "rooms", "subjects", "staff",
        "staff_qualifications", "staff_subjects", "sections", "grade_subjects",
        "students", "guardians", "student_guardians", "medical_records",
        "student_documents", "attendance_sessions", "student_attendances",
        "attendance_summaries", "fee_categories", "fee_structures",
        "fee_invoices", "fee_invoice_items", "payments", "fee_receipts",
        "parent_payment_requests", "school_payment_settings", "leave_types",
        "leave_balances", "student_leave_applications", "announcements",
        "events", "parent_teacher_meetings", "timetable_slots", "frontend_records"
      ];
      for (const table of restoreOrder) {
        const rows = body[table];
        if (!Array.isArray(rows) || rows.length === 0) continue;
        const { error } = await svc.from(table).upsert(rows);
        if (error) {
          return fail(`Restore failed on table ${table}: ${error.message}`);
        }
      }
      return ok({ success: true, message: "Database restored successfully" });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return fail(msg);
    }
  }

  // ── Database Wipe ─────────────────────────────────────────
  if (path === "/monitoring/database/wipe" && method === "POST") {
    if (!isSuperAdmin(user)) {
      return fail("Unauthorized: SuperAdmin role required", 403);
    }
    if (!school) return fail("No school is associated with this account", 400);
    try {
      const accounts = await collectSchoolWipeAccounts(svc, school);
      const storageObjectsRemoved = await wipeSchoolStorage(
        svc,
        school,
        accounts.retainedAccountIds,
      ).catch((storageErr) => {
        // Fallback: log error but do not fail the entire database wipe
        console.error("Storage wipe failed, continuing with db wipe:", storageErr);
        return 0;
      });
      const { data, error } = await svc.rpc("wipe_school_data", {
        p_school_id: school,
        p_retained_user_ids: accounts.retainedAccountIds,
      });
      if (error) return fail(`Wipe failed: ${error.message}`);
      const authAccountsDeleted = await deleteSchoolAuthAccounts(
        svc,
        accounts.accountIdsToDelete,
      ).catch((authErr) => {
        console.error("Auth accounts deletion failed, continuing:", authErr);
        return 0;
      });
      return ok({
        ...(data as Record<string, unknown> ?? {}),
        auth_accounts_deleted: authAccountsDeleted,
        retained_login_accounts: accounts.retainedAccountIds.length,
        storage_objects_removed: storageObjectsRemoved,
        message: "School data wiped; only principal and Super Admin logins were preserved",
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return fail(msg);
    }
  }

  if (path === "/monitoring/error-events" && method === "POST") {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const severity = validSeverity(text(body["severity"]))
      ? text(body["severity"])
      : "error";
    const message = boundedText(body["message"], 2048);
    const errorType = boundedText(body["error_type"], 256);
    const stackTrace = boundedText(body["stack_trace"], 12288);
    const context = {
      source: boundedText(body["source"], 64),
      severity,
      status: "open",
      role: metadataRole(body["metadata"]),
      request_id: boundedText(body["request_id"], 128),
      error_id: boundedText(body["error_id"], 128),
      method: boundedText(body["method"], 12),
      path: boundedText(body["path"], 512),
      route_name: boundedText(body["route_name"], 256),
      screen: boundedText(body["screen"], 256),
      status_code: integer(body["status_code"]) ?? 0,
      metadata: body["metadata"] ?? {},
      app_version: boundedText(body["app_version"], 128),
      device_info: boundedText(body["device_info"], 256),
      occurred_at: boundedText(body["occurred_at"], 64),
    };
    const fingerprint = await errorFingerprint({
      errorType,
      message,
      source: context.source,
      path: context.path,
      stackTrace,
    });
    const { data, error } = await svc.rpc("record_error_event", {
      p_school_id: school,
      p_user_id: user.id,
      p_message: message,
      p_error_type: errorType,
      p_stack_trace: stackTrace,
      p_context: context,
      p_severity: severity,
      p_fingerprint: fingerprint,
    });
    if (error) return fail(error.message);
    const savedEvent = data as Record<string, unknown>;
    const metadata = context.metadata && typeof context.metadata === "object"
      ? context.metadata as Record<string, unknown>
      : {};
    const approvalAuditFailure = `${metadata.approval_audit_failure ?? ""}` ===
      "true" || message.includes("approval_audit_write_failed");
    const statusCode = integer(context.status_code) ?? 0;
    const isNewServerFailure = approvalAuditFailure || severity === "fatal" ||
      (severity === "error" && statusCode >= 500);
    if (isNewServerFailure && integer(savedEvent.occurrence_count) === 1) {
      try {
        await alertSuperAdminsOfNewError(
          svc,
          school,
          text(savedEvent.id),
          approvalAuditFailure,
        );
      } catch (alertError) {
        console.error("error_event_alert_failed", {
          error_id: text(savedEvent.id),
          message: alertError instanceof Error
            ? alertError.message
            : String(alertError),
        });
      }
    }
    return ok(responseRow(data as Record<string, unknown>));
  }

  if (isErrorRetentionPath(path) && method === "GET") {
    if (!isSuperAdmin(user)) return fail("forbidden: super_admin required", 403);
    const { data, error } = await svc.rpc("error_event_retention_metrics", {
      p_school_id: school,
    });
    if (error) return fail(error.message);
    return ok(data as Record<string, unknown>);
  }

  if (isErrorRetentionPath(path) && method === "PATCH") {
    if (!isSuperAdmin(user)) return fail("forbidden: super_admin required", 403);
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const warningDays = integer(body["warning_keep_days"]);
    const resolvedDays = integer(body["resolved_keep_days"]);
    const fatalDays = integer(body["resolved_fatal_keep_days"]);
    const maxRawEvents = integer(body["max_raw_events"]);
    if (
      warningDays == null || warningDays < 7 || warningDays > 30 ||
      resolvedDays == null || resolvedDays < 14 || resolvedDays > 180 ||
      fatalDays == null || fatalDays < 30 || fatalDays > 365 ||
      maxRawEvents == null || maxRawEvents < 1000 || maxRawEvents > 100000
    ) {
      return fail("Retention settings are outside the allowed safe range", 422);
    }
    const { data, error } = await svc.from("error_event_retention_settings")
      .upsert({
        school_id: school,
        warning_keep_days: warningDays,
        resolved_keep_days: resolvedDays,
        resolved_fatal_keep_days: fatalDays,
        max_raw_events: maxRawEvents,
        updated_by: user.id,
        updated_at: new Date().toISOString(),
      }, { onConflict: "school_id" }).select().single();
    if (error) return fail(error.message);
    await recordActivity(svc, {
      schoolId: school,
      userId: user.id,
      actorRole: "super_admin",
      action: "monitoring.error_retention_updated",
      module: "monitoring",
      eventType: "error_retention_updated",
      summary: "Super Admin updated error-event retention settings",
      entityType: "error_event_retention_settings",
      entityId: school,
      details: data as Record<string, unknown>,
    });
    return ok(data as Record<string, unknown>);
  }

  if (isErrorCleanupPath(path) && method === "POST") {
    if (!isSuperAdmin(user)) return fail("forbidden: super_admin required", 403);
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const preview = body["preview"] !== false;
    const confirmation = text(body["confirmation"]);
    if (!preview && confirmation !== "CLEAR RESOLVED ERROR EVENTS") {
      return fail("Type CLEAR RESOLVED ERROR EVENTS to confirm cleanup", 422);
    }
    const beforeRaw = text(body["before"]);
    const before = beforeRaw ? new Date(beforeRaw) : new Date();
    if (Number.isNaN(before.getTime())) return fail("Invalid cleanup date", 422);
    const severity = text(body["severity"]);
    if (severity && !validSeverity(severity)) return fail("Invalid severity", 422);
    const { data, error } = await svc.rpc("cleanup_resolved_error_events", {
      p_school_id: school,
      p_before: before.toISOString(),
      p_severity: severity || null,
      p_preview: preview,
    });
    if (error) return fail(error.message);
    if (!preview) {
      await recordActivity(svc, {
        schoolId: school,
        userId: user.id,
        actorRole: "super_admin",
        action: "monitoring.error_events_cleared",
        module: "monitoring",
        eventType: "error_events_cleared",
        summary: "Super Admin cleared resolved error events",
        entityType: "error_events",
        entityId: school,
        details: {
          before: before.toISOString(),
          severity: severity || "all",
          ...(data as Record<string, unknown>),
        },
      });
    }
    return ok({ ...(data as Record<string, unknown>), preview });
  }

  if (path === "/monitoring/error-events" && method === "GET") {
    if (!isSuperAdmin(user)) return fail("forbidden: super_admin required", 403);
    const page = Math.max(parseInt(url.searchParams.get("page") ?? "1") || 1, 1);
    const size = Math.min(Math.max(parseInt(url.searchParams.get("page_size") ?? "20") || 20, 1), 100);

    const requestId = text(url.searchParams.get("request_id"));
    const status = text(url.searchParams.get("status"));
    const severity = text(url.searchParams.get("severity"));
    const source = text(url.searchParams.get("source"));
    const from = text(url.searchParams.get("from"));
    const to = text(url.searchParams.get("to"));
    let query = svc.from("error_events").select("*", { count: "exact" })
      .eq("school_id", school);
    if (status) query = query.eq("status", status);
    if (severity) query = query.eq("severity", severity);
    if (source) query = query.contains("context", { source });
    if (requestId) query = query.contains("context", { request_id: requestId });
    if (from) query = query.gte("created_at", from);
    if (to) query = query.lte("created_at", to);
    const { data, error, count } = await query.order("last_seen_at", {
      ascending: false,
    }).range((page - 1) * size, page * size - 1);
    if (error) return fail(error.message);
    return cors({
      success: true,
      data: (data ?? []).map((row) => responseRow(row as Record<string, unknown>)),
      total: count ?? 0,
      page,
      page_size: size,
    });
  }

  const eventId = parseEventId(path);
  if (eventId && method === "GET") {
    if (!isSuperAdmin(user)) return fail("forbidden: super_admin required", 403);
    const { data, error } = await svc.from("error_events").select("*").eq(
      "school_id",
      school,
    ).eq("id", eventId).maybeSingle();
    if (error) return fail(error.message);
    if (!data) return fail("Error event not found", 404);
    return ok(responseRow(data as Record<string, unknown>));
  }

  if (eventId && method === "DELETE") {
    if (!isSuperAdmin(user)) return fail("forbidden: super_admin required", 403);
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    if (text(body["confirmation"]) !== "DELETE RESOLVED ERROR EVENT") {
      return fail("Type DELETE RESOLVED ERROR EVENT to confirm deletion", 422);
    }
    const { data: existing, error: readError } = await svc.from("error_events")
      .select("id, status, severity, message, occurrence_count")
      .eq("school_id", school).eq("id", eventId).maybeSingle();
    if (readError) return fail(readError.message);
    if (!existing) return fail("Error event not found", 404);
    if (existing.status !== "resolved") {
      return fail("Only resolved error events can be permanently deleted", 422);
    }
    const { error } = await svc.from("error_events").delete()
      .eq("school_id", school).eq("id", eventId);
    if (error) return fail(error.message);
    await recordActivity(svc, {
      schoolId: school,
      userId: user.id,
      actorRole: "super_admin",
      action: "monitoring.error_event_deleted",
      module: "monitoring",
      eventType: "error_event_deleted",
      summary: "Super Admin permanently deleted a resolved error event",
      entityType: "error_event",
      entityId: eventId,
      details: existing as Record<string, unknown>,
    });
    return ok({ id: eventId, deleted: true });
  }

  const resolveId = parseResolveId(path);
  if (resolveId && method === "PATCH") {
    if (!isSuperAdmin(user)) return fail("forbidden: super_admin required", 403);
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const { data, error } = await svc.from("error_events").select("*").eq(
      "school_id",
      school,
    ).eq("id", resolveId).maybeSingle();
    if (error) return fail(error.message);
    if (!data) return fail("Error event not found", 404);

    const existing = data as Record<string, unknown>;
    const context = mapContext(existing);
    const resolvedAt = new Date().toISOString();
    const resolutionNote = boundedText(body["resolution_note"], 2048);
    const updatedContext = { ...context, status: "resolved", resolved_at: resolvedAt, resolved_by: user.id, resolution_note: resolutionNote };

    const updated = await svc.from("error_events").update({
      context: updatedContext,
      status: "resolved",
      resolved_at: resolvedAt,
      resolved_by: user.id,
      resolution_note: resolutionNote,
    }).eq("school_id", school).eq("id", resolveId).select().single();
    if (updated.error) return fail(updated.error.message);
    return ok(responseRow(updated.data as Record<string, unknown>));
  }

  return fail("not found", 404);
}

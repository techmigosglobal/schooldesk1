import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";

function schoolId(user: User): string {
  return (user.app_metadata?.school_id as string) ?? "";
}

function isSuperAdmin(user: User): boolean {
  return user.app_metadata?.role_name === "super_admin";
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
) {
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
  return role === "principal" || role === "super_admin";
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
    if (path) targets.get("issue-attachments")?.add(path);
  }
  for (const row of paymentResult.data ?? []) {
    addStoragePath(targets, "payment-proofs", row.proof_url);
  }
  for (const row of studentDocumentResult.data ?? []) {
    addStoragePath(targets, "school-assets", row.file_url);
  }
  for (const row of staffDocumentResult.data ?? []) {
    addStoragePath(targets, "school-assets", row.file_url);
  }
  for (const row of uploadResult.data ?? []) {
    const path = text(row.path);
    if (path) targets.get("school-assets")?.add(path);
  }
  for (const row of studentResult.data ?? []) {
    addStoragePath(targets, "school-assets", row.photo_url);
  }
  for (const row of staffResult.data ?? []) {
    addStoragePath(targets, "school-assets", row.photo_url);
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
    if (status) query = query.contains("context", { status });
    if (severity) query = query.contains("context", { severity });
    if (source) query = query.contains("context", { source });
    if (requestId) query = query.contains("context", { request_id: requestId });
    if (from) query = query.gte("created_at", from);
    if (to) query = query.lte("created_at", to);
    const { data, error, count } = await query.order("created_at", {
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

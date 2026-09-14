// handlers/uploads.ts — multipart file upload → R2 or Supabase Storage
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, runDbStatements, triggerPushProcessing } from "../index.ts";
import {
  renderStructuredReportPdf,
  StructuredExportTable,
} from "../report_pdf.ts";
import {
  PRIVATE_FILES_BUCKET,
  privateFileReference,
  privateFileReferenceFromValue,
  signedPrivateFileUrl,
  storagePathFromValue,
} from "../storage_helpers.ts";
import {
  canManageStaff,
  canManageStudents,
  isFinanceLeader,
  linkedStaffId,
  roleName,
  studentAccess,
  visibleStudentIds,
} from "./authorization.ts";
import {
  copyR2File,
  deleteR2File,
  headR2File,
  legacyR2Reference,
  publicR2FileReference,
  publicR2FileUrl,
  legacyStorageWritesEnabled,
  r2FileReference,
  r2ReferenceInfo,
  r2VisibilityFromValue,
  uploadPublicToR2,
  uploadToR2,
} from "../lib/r2_storage.ts";
function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}

function textValue(value: unknown, fallback = ""): string {
  const text = `${value ?? ""}`.trim();
  return text || fallback;
}

function roleValue(user: User): string {
  return `${user.app_metadata?.role_name ?? ""}`.trim().toLowerCase();
}

const feedRoles = new Set([
  "principal",
  "coordinator",
  "admin",
  "teacher",
  "parent",
]);

function canViewSchoolFeed(user: User): boolean {
  // kiosk and student accounts must never inherit communication surfaces.
  return feedRoles.has(roleValue(user));
}

function listPaging(url: URL) {
  const page = Math.max(parseInt(url.searchParams.get("page") ?? "1") || 1, 1);
  const pageSize = Math.min(
    Math.max(parseInt(url.searchParams.get("page_size") ?? "20") || 20, 1),
    100,
  );
  return { page, pageSize, from: (page - 1) * pageSize, to: page * pageSize - 1 };
}

function listEnvelope<T>(
  data: T[],
  count: number | null,
  page: number,
  pageSize: number,
) {
  const total = count ?? data.length;
  return {
    data,
    total,
    page,
    page_size: pageSize,
    has_more: page * pageSize < total,
  };
}

function canUseOwnStaffDocuments(user: User): boolean {
  return ["teacher", "staff"].includes(roleName(user)) &&
    Boolean(linkedStaffId(user));
}

// Compatibility-named wrapper retained at the document boundary while the
// authorization implementation lives in the centralized student scope layer.
async function parentCanAccessStudent(
  svc: SupabaseClient,
  school: string,
  user: User,
  studentId: string,
): Promise<boolean> {
  return Boolean(await studentAccess(svc, school, user, studentId));
}

async function staffExistsInSchool(
  svc: SupabaseClient,
  school: string,
  staffId: string,
): Promise<boolean> {
  const { data, error } = await svc.from("staff").select("id")
    .eq("school_id", school).eq("id", staffId).maybeSingle();
  if (error) throw new Error(error.message);
  return Boolean(data);
}

function asStringArray(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.map((item) => `${item ?? ""}`.trim()).filter(Boolean);
  }
  if (typeof value === "string") {
    const text = value.trim();
    if (text.startsWith("[") && text.endsWith("]")) {
      try {
        return asStringArray(JSON.parse(text));
      } catch {
        // Fall back to comma-separated parsing below.
      }
    }
    return text.split(",").map((item) => item.trim()).filter(Boolean);
  }
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    return Object.values(record).map((item) => `${item ?? ""}`.trim()).filter(
      Boolean,
    );
  }
  return [];
}

function normalizeDestinations(value: unknown, visibility: unknown): string[] {
  const destinations = asStringArray(value);
  if (destinations.length > 0) return [...new Set(destinations)];
  const normalizedVisibility = `${visibility ?? ""}`.trim().toLowerCase();
  if (normalizedVisibility === "public") return ["SCHOOL_LANDING"];
  if (normalizedVisibility === "gallery") return ["SCHOOL_GALLERY"];
  return ["PARENTS_HOME"];
}

function approvedEventDestinations(
  value: unknown,
  visibility: unknown,
): string[] {
  // Approval must preserve the teacher's selected audiences. In particular, a
  // SCHOOL_LANDING-only post is an image carousel item and must not leak into
  // the parent home feed or gallery.
  return normalizeDestinations(value, visibility);
}

function requiresPublicEventMedia(
  destinations: string[],
  publicGalleryVisible: boolean,
): boolean {
  return destinations.includes("SCHOOL_LANDING") || publicGalleryVisible;
}

function _guessMimeFromName(name: string): string {
  const ext = name.split(".").pop()?.toLowerCase() ?? "";
  const map: Record<string, string> = {
    mp4: "video/mp4",
    mov: "video/quicktime",
    m4v: "video/x-m4v",
    webm: "video/webm",
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    png: "image/png",
    webp: "image/webp",
    gif: "image/gif",
    heic: "image/heic",
    pdf: "application/pdf",
  };
  return map[ext] ?? "application/octet-stream";
}

function eventMediaItems(value: unknown): Array<Record<string, unknown>> {
  if (!Array.isArray(value)) return [];
  return value.map((item) => {
    if (item && typeof item === "object") {
      return item as Record<string, unknown>;
    }
    return { url: textValue(item) };
  });
}

function isImageEventMedia(item: Record<string, unknown>): boolean {
  const kind = textValue(item.kind ?? item.type).toLowerCase();
  const mime = textValue(item.mime_type ?? item.mimeType ?? item.content_type)
    .toLowerCase();
  const url = textValue(item.url ?? item.media_url ?? item.mediaUrl)
    .toLowerCase().split("?")[0];
  return kind === "image" || kind === "photo" || mime.startsWith("image/") ||
    /\.(jpe?g|png|webp|gif|heic)$/.test(url);
}

function isVideoEventMedia(item: Record<string, unknown>): boolean {
  const kind = textValue(item.kind ?? item.type).toLowerCase();
  const mime = textValue(item.mime_type ?? item.mimeType ?? item.content_type)
    .toLowerCase();
  const url = textValue(item.url ?? item.media_url ?? item.mediaUrl)
    .toLowerCase().split("?")[0];
  return kind === "video" || mime.startsWith("video/") ||
    /\.(mp4|mov|m4v|webm)$/.test(url);
}

function validateEventMedia(
  rawMedia: unknown,
  destinations: string[],
): string | null {
  const media = eventMediaItems(rawMedia);
  if (
    media.length > 0 &&
    media.some((item) => !isImageEventMedia(item) && !isVideoEventMedia(item))
  ) {
    return "Event posts accept images and videos only";
  }
  if (destinations.includes("SCHOOL_LANDING") && media.length === 0) {
    return "Landing page posts require at least one image";
  }
  if (
    destinations.includes("SCHOOL_LANDING") &&
    media.some((item) => !isImageEventMedia(item))
  ) {
    return "Landing page posts accept images only";
  }
  return null;
}

function eventPostRow(row: Record<string, unknown>, author = "") {
  const description = `${row.description ?? row.body ?? ""}`;
  const approvalStatus = `${row.approval_status ?? row.status ?? "draft"}`;
  const destinations = normalizeDestinations(row.destinations, row.visibility);
  return {
    ...row,
    description,
    body: description,
    approval_status: approvalStatus,
    status: approvalStatus,
    destinations,
    visibility: `${row.visibility ?? "school"}`,
    event_date: row.event_date ?? row.created_at ?? null,
    public_gallery_visible: row.public_gallery_visible !== false,
    rejection_reason: row.rejection_reason ?? "",
    author: author || `${row.author ?? row.posted_by ?? ""}`.trim(),
  };
}

function eventMediaItemValue(item: unknown): string {
  if (item && typeof item === "object") {
    const value = item as Record<string, unknown>;
    return textValue(
      value.storage_ref ?? value.storageRef ?? value.url ?? value.media_url ??
        value.mediaUrl,
    );
  }
  return textValue(item);
}

async function materializeEventPostMedia(
  svc: SupabaseClient,
  row: Record<string, unknown>,
  publicOnly = false,
): Promise<unknown[]> {
  const destinations = normalizeDestinations(row.destinations, row.visibility);
  const postIsPublic = destinations.includes("SCHOOL_LANDING") ||
    row.public_gallery_visible === true;
  const media = Array.isArray(row.media_urls) ? row.media_urls : [];
  const resolved = await Promise.all(media.map(async (item) => {
    const stored = eventMediaItemValue(item);
    if (!stored) return null;
    const stableRef = r2ReferenceInfo(stored) ? stored : undefined;
    const migratedLegacyRef = stableRef ??
      legacyR2Reference(stored, "school-assets");
    let url = "";
    if (postIsPublic) {
      url = publicR2FileUrl(migratedLegacyRef ?? stored);
    }
    if (!url && (!publicOnly || postIsPublic)) {
      url = await signedPrivateFileUrl(svc, stored, undefined, "school-assets");
    }
    if (!url && publicOnly && postIsPublic) {
      // Preserve the legacy URL only when the R2 copy is unavailable. This
      // keeps rollback possible while allowing deleted Supabase objects to be
      // served from their deterministic R2 destination.
      url = stored;
    }
    if (!url && !publicOnly) {
      // Legacy Supabase URLs remain the final fallback during the staged
      // cutover when neither the R2 copy nor a signed legacy URL is usable.
      url = stored;
    }
    if (!url) return null;
    if (item && typeof item === "object") {
      return {
        ...(item as Record<string, unknown>),
        url,
        storage_ref: migratedLegacyRef ??
          (item as Record<string, unknown>).storage_ref,
      };
    }
    return {
      url,
      ...(migratedLegacyRef ? { storage_ref: migratedLegacyRef } : {}),
    };
  }));
  return resolved.filter(Boolean);
}

function eventMediaFileName(item: unknown, fallback: string): string {
  if (item && typeof item === "object") {
    const value = item as Record<string, unknown>;
    const name = textValue(value.name ?? value.filename ?? value.file_name);
    if (name) return name;
  }
  const raw = eventMediaItemValue(item).split("?")[0];
  return raw.split("/").pop() || fallback;
}

function eventMediaContentType(item: unknown): string {
  if (item && typeof item === "object") {
    const value = item as Record<string, unknown>;
    const mime = textValue(
      value.mime_type ?? value.mimeType ?? value.content_type ?? value.media_type,
    );
    if (mime) return mime;
  }
  return _guessMimeFromName(eventMediaFileName(item, "media.bin"));
}

async function downloadLegacyEventMedia(
  svc: SupabaseClient,
  value: string,
): Promise<Uint8Array | null> {
  for (const bucket of ["school-assets", "school-public-media"]) {
    const path = storagePathFromValue(value, bucket) ||
      (!value.startsWith("http://") && !value.startsWith("https://")
        ? value
        : "");
    if (!path) continue;
    const { data, error } = await svc.storage.from(bucket).download(path);
    if (!error && data) return new Uint8Array(await data.arrayBuffer());
  }
  return null;
}

/**
 * Promotes approved public SchoolPost media before the database row is made
 * public. The database stores the durable public R2 reference, never a
 * short-lived signed URL.
 */
async function promoteEventPostMedia(
  svc: SupabaseClient,
  school: string,
  postId: string,
  rawMedia: unknown,
): Promise<unknown[]> {
  const media = Array.isArray(rawMedia) ? rawMedia : [];
  const promoted: unknown[] = [];
  for (let index = 0; index < media.length; index++) {
    const item = media[index];
    const stored = eventMediaItemValue(item);
    if (!stored) continue;
    const existing = r2ReferenceInfo(stored);
    let destination: string;
    if (existing?.visibility === "public") {
      destination = stored;
    } else {
      const fileName = eventMediaFileName(item, `media-${index}.bin`)
        .replace(/[^a-zA-Z0-9._-]/g, "-");
      // The post id and media index make promotion safe to retry after a
      // database update failure. CopyObject overwrites the same destination
      // key instead of leaking a new public object on every retry.
      const destinationKey = `event-posts/${school}/${postId}/${index}-${fileName}`;
      if (existing?.visibility === "private") {
        const copied = await copyR2File(stored, destinationKey, "public");
        if (!copied) throw new Error("R2 is not configured for media promotion");
        destination = copied.reference;
      } else {
        const bytes = await downloadLegacyEventMedia(svc, stored);
        if (!bytes) throw new Error("Legacy event media could not be read");
        const uploaded = await uploadPublicToR2(
          destinationKey,
          bytes,
          eventMediaContentType(item),
        );
        if (!uploaded) throw new Error("R2 public media is not configured");
        destination = uploaded.reference;
      }
    }
    if (!publicR2FileUrl(destination)) {
      throw new Error("R2 public media domain is not configured");
    }
    if (!(await headR2File(destination))) {
      throw new Error("R2 media promotion verification failed");
    }
    if (item && typeof item === "object") {
      promoted.push({
        ...(item as Record<string, unknown>),
        url: destination,
        storage_ref: destination,
      });
    } else {
      promoted.push({ url: destination, storage_ref: destination });
    }
  }
  return promoted;
}

async function demoteEventPostMedia(
  svc: SupabaseClient,
  school: string,
  postId: string,
  rawMedia: unknown,
): Promise<{ media: unknown[]; cleanup: string[] }> {
  const media = Array.isArray(rawMedia) ? rawMedia : [];
  const demoted: unknown[] = [];
  const cleanup: string[] = [];
  for (let index = 0; index < media.length; index++) {
    const item = media[index];
    const stored = eventMediaItemValue(item);
    if (!stored) continue;
    const existing = r2ReferenceInfo(stored);
    if (existing?.visibility !== "public") {
      demoted.push(item);
      continue;
    }
    const fileName = eventMediaFileName(item, `media-${index}.bin`)
      .replace(/[^a-zA-Z0-9._-]/g, "-");
    const destinationKey = `event-posts-private/${school}/${postId}/${index}-${fileName}`;
    const copied = await copyR2File(stored, destinationKey, "private");
    if (!copied) throw new Error("R2 is not configured for media demotion");
    if (!(await headR2File(copied.reference))) {
      throw new Error("R2 private media demotion verification failed");
    }
    cleanup.push(stored);
    demoted.push(item && typeof item === "object"
      ? {
        ...(item as Record<string, unknown>),
        url: copied.reference,
        storage_ref: copied.reference,
      }
      : { url: copied.reference, storage_ref: copied.reference });
  }
  return { media: demoted, cleanup };
}

async function enqueueStorageCleanup(
  svc: SupabaseClient,
  refs: string[],
  reason: string,
) {
  const uniqueRefs = [...new Set(refs)].filter((reference) =>
    Boolean(r2ReferenceInfo(reference))
  );
  if (uniqueRefs.length === 0) return;
  const { error } = await svc.from("storage_cleanup_queue").upsert(
    uniqueRefs.map((storage_ref) => ({
      storage_ref,
      reason,
      status: "pending",
      attempts: 0,
      available_at: new Date().toISOString(),
      last_error: null,
      updated_at: new Date().toISOString(),
    })),
    { onConflict: "storage_ref" },
  );
  if (error) {
    console.error("Unable to enqueue R2 cleanup", {
      reason,
      refs: uniqueRefs,
      error: error.message,
    });
  }
}

async function cleanupR2References(
  svc: SupabaseClient,
  refs: string[],
  reason: string,
) {
  const uniqueRefs = [...new Set(refs)].filter((reference) =>
    Boolean(r2ReferenceInfo(reference))
  );
  if (uniqueRefs.length === 0) return;
  await enqueueStorageCleanup(svc, uniqueRefs, reason);
  await Promise.all(uniqueRefs.map(async (reference) => {
    try {
      const deleted = await deleteR2File(reference);
      if (!deleted) throw new Error("R2 is not configured");
      await svc.from("storage_cleanup_queue").update({
        status: "completed",
        updated_at: new Date().toISOString(),
      }).eq("storage_ref", reference);
    } catch (error) {
      console.error("R2 media cleanup failed", { reference, error });
      await svc.from("storage_cleanup_queue").update({
        status: "failed",
        last_error: `${error}`,
        available_at: new Date(Date.now() + 60_000).toISOString(),
        updated_at: new Date().toISOString(),
      }).eq("storage_ref", reference);
    }
  }));
}

function eventPostR2References(rawMedia: unknown): string[] {
  return [...new Set(
    eventMediaItems(rawMedia).map(eventMediaItemValue).filter((value) =>
      Boolean(r2ReferenceInfo(value))
    ),
  )];
}

async function eventPostResponse(
  svc: SupabaseClient,
  row: Record<string, unknown>,
  publicOnly = false,
) {
  const normalized = eventPostRow(row);
  return {
    ...normalized,
    media_urls: await materializeEventPostMedia(svc, row, publicOnly),
  };
}

/// `event_posts` has both `created_by` and `approved_by` foreign keys to
/// `users`. Do not use a PostgREST embedded relationship here: it becomes
/// ambiguous as soon as both keys exist. A small explicit author lookup keeps
/// every event-post surface working for teachers, principals, and parents.
async function eventPostRows(
  svc: SupabaseClient,
  rows: Record<string, unknown>[],
) {
  const authorIds = [
    ...new Set(
      rows.map((row) => textValue(row.created_by)).filter(Boolean),
    ),
  ];
  const authorNames = new Map<string, string>();
  if (authorIds.length > 0) {
    const { data, error } = await svc.from("users").select("id, name, username")
      .in("id", authorIds);
    if (!error) {
      for (const author of data ?? []) {
        authorNames.set(
          `${author.id ?? ""}`,
          textValue(author.name, textValue(author.username)),
        );
      }
    }
  }
  return await Promise.all(rows.map(async (row) => ({
    ...(await eventPostResponse(svc, row)),
    author: authorNames.get(textValue(row.created_by)) ?? "",
  })));
}

async function notifyUsersByRole(
  svc: SupabaseClient,
  school: string,
  roleName: string,
  payload: {
    title: string;
    body: string;
    type: string;
    referenceType: string;
    referenceId: string;
    excludeUserId?: string;
  },
) {
  let usersQuery = svc.from("users").select("id").eq(
    "school_id",
    school,
  ).ilike("role_name", roleName);
  if (payload.excludeUserId?.trim()) {
    usersQuery = usersQuery.neq("id", payload.excludeUserId.trim());
  }
  const { data: users, error } = await usersQuery;
  if (error) throw error;
  const userIds = (users ?? []).map((row: Record<string, unknown>) =>
    `${row.id ?? ""}`.trim()
  ).filter(Boolean);
  if (userIds.length === 0) return;
  const rows = userIds.map((userId) => ({
    school_id: school,
    user_id: userId,
    target_role: roleName,
    title: payload.title,
    body: payload.body,
    type: payload.type,
    entity_type: payload.referenceType,
    entity_id: payload.referenceId,
  }));
  const { error: insertError } = await svc.from("notification_logs").insert(
    rows,
  );
  if (insertError) throw insertError;
  const { data: events, error: eventError } = await svc.from(
    "notification_events",
  )
    .insert(
      rows.map((row) => ({
        school_id: row.school_id,
        user_id: row.user_id,
        event_type: row.entity_type,
        event_data: {
          title: row.title,
          message: row.body,
          reference_type: row.entity_type,
          reference_id: row.entity_id,
        },
      })),
    )
    .select("id");
  if (eventError) throw eventError;
  const eventIds = (events ?? []).map((row) => textValue(row.id)).filter(
    Boolean,
  );
  if (eventIds.length > 0) triggerPushProcessing(eventIds);
}

async function notifyUser(
  svc: SupabaseClient,
  school: string,
  userId: string,
  payload: {
    title: string;
    body: string;
    type: string;
    referenceType: string;
    referenceId: string;
  },
) {
  if (!userId.trim()) return;
  const { error } = await svc.from("notification_logs").insert({
    school_id: school,
    user_id: userId,
    target_role: "teacher",
    title: payload.title,
    body: payload.body,
    type: payload.type,
    entity_type: payload.referenceType,
    entity_id: payload.referenceId,
  });
  if (error) throw error;
  const { data: eventRow, error: eventError } = await svc.from(
    "notification_events",
  )
    .insert({
      school_id: school,
      user_id: userId,
      event_type: payload.referenceType,
      event_data: {
        title: payload.title,
        message: payload.body,
        reference_type: payload.referenceType,
        reference_id: payload.referenceId,
      },
    })
    .select("id")
    .maybeSingle();
  if (eventError) throw eventError;
  if (eventRow?.id) triggerPushProcessing(eventRow.id);
}

async function notifyStudentDocumentParents(
  svc: SupabaseClient,
  school: string,
  studentId: string,
  documentId: string,
  documentTitle: string,
) {
  const { data: links, error: linkError } = await svc.from(
    "parent_student_links",
  ).select("parent_user_id").eq("school_id", school).eq(
    "student_id",
    studentId,
  );
  if (linkError) throw linkError;
  const parentIds = [
    ...new Set(
      (links ?? []).map((row) => textValue(row.parent_user_id)).filter(Boolean),
    ),
  ];
  if (parentIds.length === 0) return;
  const title = "New student document";
  const body = `${documentTitle || "A document"} was added by the school.`;
  const logs = parentIds.map((parentId) => ({
    school_id: school,
    user_id: parentId,
    target_role: "parent",
    title,
    body,
    type: "document",
    entity_type: "student_document",
    entity_id: documentId,
    route: "/parent-documents-screen",
    student_id: studentId,
    is_read: false,
  }));
  const { error: logError } = await svc.from("notification_logs").insert(logs);
  if (logError) throw logError;
  const { data: events, error: eventError } = await svc.from(
    "notification_events",
  ).insert(logs.map((log) => ({
    school_id: log.school_id,
    user_id: log.user_id,
    event_type: "student_document_uploaded",
    event_data: {
      title: log.title,
      message: log.body,
      reference_type: log.entity_type,
      reference_id: log.entity_id,
      route: log.route,
      student_id: log.student_id,
    },
    processed: false,
  }))).select("id");
  if (eventError) throw eventError;
  const eventIds = (events ?? []).map((row) => textValue(row.id)).filter(
    Boolean,
  );
  if (eventIds.length > 0) triggerPushProcessing(eventIds);
}

let eventPostSchemaReady = false;
let eventPostSchemaPromise: Promise<void> | null = null;

// deno-lint-ignore require-await
async function ensureEventPostSchema() {
  if (eventPostSchemaReady) return;
  if (eventPostSchemaPromise) return eventPostSchemaPromise;
  eventPostSchemaPromise = (async () => {
    try {
      await runDbStatements([
        `alter table public.notification_logs
          add column if not exists target_role text`,
        `create index if not exists idx_notification_logs_target_role
          on public.notification_logs(target_role, created_at desc)`,
        `alter table public.event_posts
          add column if not exists event_date timestamptz`,
        `alter table public.event_posts
          add column if not exists destinations jsonb not null default '[]'::jsonb`,
        `alter table public.event_posts
          add column if not exists rejection_reason text`,
        `alter table public.event_posts
          add column if not exists approved_by uuid references public.users(id) on delete set null`,
        `alter table public.event_posts
          add column if not exists approved_at timestamptz`,
        `update public.event_posts
          set destinations = case
            when visibility = 'public' then '["SCHOOL_LANDING"]'::jsonb
            when visibility = 'gallery' then '["SCHOOL_GALLERY"]'::jsonb
            else '["PARENTS_HOME"]'::jsonb
          end
          where destinations is null
             or jsonb_typeof(destinations) is distinct from 'array'
             or destinations = '[]'::jsonb`,
        `update public.event_posts
          set event_date = coalesce(event_date, created_at)
          where event_date is null`,
        `create index if not exists idx_event_posts_school_status
          on public.event_posts(school_id, status, created_at desc)`,
      ]);
    } catch {
      // Best-effort: if the schema is already current or direct SQL is unavailable,
      // the handler still proceeds and PostgREST responses remain the source of truth.
    } finally {
      eventPostSchemaReady = true;
      eventPostSchemaPromise = null;
    }
  })();
  return eventPostSchemaPromise;
}

function documentRow(row: Record<string, unknown>) {
  const payload = typeof row.data === "object" && row.data !== null
    ? row.data as Record<string, unknown>
    : row;
  return {
    ...payload,
    id: payload.id ?? row.id ?? row.record_id,
  };
}

async function uploadPrivateReportPdf(
  svc: SupabaseClient,
  school: string,
  bytes: Uint8Array,
): Promise<string> {
  const filePath = `reports/${school}/${crypto.randomUUID()}.pdf`;
  const r2Upload = await uploadToR2(
    `private/${filePath}`,
    bytes,
    "application/pdf",
  );
  if (r2Upload) {
    const signedUrl = await signedPrivateFileUrl(
      svc,
      r2FileReference(r2Upload.key),
    );
    if (!signedUrl) throw new Error("Failed to create report download URL");
    return signedUrl;
  }
  if (!legacyStorageWritesEnabled()) {
    throw new Error("R2 storage is unavailable; legacy storage writes are disabled");
  }
  const bucket = "finance-documents";
  const { error: uploadError } = await svc.storage.from(bucket).upload(
    filePath,
    bytes,
    {
      contentType: "application/pdf",
      cacheControl: "3600",
      upsert: false,
    },
  );
  if (uploadError) throw uploadError;
  const { data, error } = await svc.storage.from(bucket).createSignedUrl(
    filePath,
    10 * 60,
    { download: true },
  );
  if (error) throw error;
  if (!data?.signedUrl) throw new Error("Failed to create report download URL");
  return data.signedUrl;
}

async function performStructuredReportExport(
  svc: SupabaseClient,
  school: string,
  tableName: string,
  reportType: string,
  parameters: Record<string, any>,
): Promise<string> {
  const value = (input: unknown, fallback = "") =>
    String(input ?? "").trim() || fallback;
  const amount = (input: unknown) => {
    const parsed = Number(input ?? 0);
    return Number.isFinite(parsed) ? parsed : 0;
  };
  const object = (input: unknown): Record<string, any> =>
    input && typeof input === "object" && !Array.isArray(input)
      ? input as Record<string, any>
      : {};
  const titleize = (input: string) =>
    input.replaceAll("_", " ").replace(
      /\b\w/g,
      (letter) => letter.toUpperCase(),
    );
  const person = (input: Record<string, unknown> | null | undefined) =>
    [value(input?.first_name), value(input?.last_name)].filter(Boolean).join(
      " ",
    ) || "Not assigned";
  const currency = (input: unknown) =>
    "INR " + amount(input).toLocaleString("en-IN", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
  const date = (input: unknown) => value(input).slice(0, 10) || "—";
  const academicYear = value(parameters.academic_year, "Academic year");
  const { data: schoolProfile, error: schoolError } = await svc
    .from("schools")
    .select("name, branch_code")
    .eq("id", school)
    .maybeSingle();
  if (schoolError) throw schoolError;
  const schoolName = value(schoolProfile?.name, "SchoolDesk");
  const branchCode = value(schoolProfile?.branch_code);

  let title = titleize(reportType || "Report export");
  let scope = ["School-wide scope"];
  let metrics: Array<{ label: string; value: string }> = [];
  let tables: StructuredExportTable[] = [];

  const loadSections = async () => {
    let query = svc.from("sections").select(
      "id, grade_id, academic_year_id, section_name, capacity, grade:grades(grade_name), class_teacher:staff!sections_class_teacher_id_fkey(first_name, last_name), co_teacher:staff!sections_co_teacher_id_fkey(first_name, last_name)",
    ).eq("school_id", school);
    if (value(parameters.academic_year_id)) {
      query = query.eq("academic_year_id", value(parameters.academic_year_id));
    }
    if (value(parameters.grade_id)) {
      query = query.eq("grade_id", value(parameters.grade_id));
    }
    if (value(parameters.section_id)) {
      query = query.eq("id", value(parameters.section_id));
    }
    const { data, error } = await query.order("section_name");
    if (error) throw error;
    return (data ?? []) as Record<string, any>[];
  };

  if (tableName === "report_exports" && reportType === "users_wise_export") {
    let query = svc.from("users").select(
      "name, email, role_name, is_active, created_at",
    ).eq("school_id", school);
    const roles = Array.isArray(parameters.roles)
      ? parameters.roles.map((item: unknown) => value(item)).filter(Boolean)
      : [];
    if (roles.length) query = query.in("role_name", roles);
    if (value(parameters.status) && value(parameters.status) !== "all") {
      query = query.eq("is_active", value(parameters.status) === "active");
    }
    const { data, error } = await query.order("name");
    if (error) throw error;
    const users = (data ?? []) as Record<string, any>[];
    title = "Users-wise Data Export";
    scope = [
      "Roles: " + (roles.length ? roles.map(titleize).join(", ") : "All users"),
      "Status: " + titleize(value(parameters.status, "all")),
    ];
    metrics = [
      { label: "Matched users", value: String(users.length) },
      {
        label: "Active",
        value: String(users.filter((row) => row.is_active).length),
      },
      {
        label: "Inactive",
        value: String(users.filter((row) => !row.is_active).length),
      },
    ];
    tables = [{
      title: "User accounts",
      headers: ["Name", "Email", "Role", "Status", "Created"],
      rows: users.map((row) => [
        value(row.name, "—"),
        value(row.email, "—"),
        titleize(value(row.role_name, "user")),
        row.is_active ? "Active" : "Inactive",
        date(row.created_at),
      ]),
      weights: [1.4, 2.4, 1.1, 0.9, 1.1],
    }];
  } else if (
    tableName === "report_exports" && reportType === "admission_inquiry_summary"
  ) {
    const { data, error } = await svc.from("admission_inquiries").select(
      "parent_name, phone, email, child_name, child_age, program, message, submitted_at",
    ).eq("school_id", school).order("submitted_at", { ascending: false });
    if (error) throw error;
    const inquiries = (data ?? []) as Record<string, any>[];
    const programCounts = new Map<string, number>();
    for (const inquiry of inquiries) {
      const program = value(inquiry.program, "Not specified");
      programCounts.set(program, (programCounts.get(program) ?? 0) + 1);
    }
    title = "Admission Inquiry Summary";
    scope = ["Public website admissions inbox", "School-wide scope"];
    metrics = [
      { label: "Inquiries", value: String(inquiries.length) },
      { label: "Programs", value: String(programCounts.size) },
      { label: "Latest enquiry", value: date(inquiries[0]?.submitted_at) },
    ];
    tables = [
      {
        title: "Inquiry overview by program",
        headers: ["Program", "Inquiries"],
        rows: [...programCounts.entries()].map((
          [program, count],
        ) => [program, count]),
        weights: [3, 1],
      },
      {
        title: "Recent family inquiries",
        headers: [
          "Submitted",
          "Parent",
          "Child",
          "Program",
          "Phone",
          "Email",
          "Message",
        ],
        rows: inquiries.map((inquiry) => [
          date(inquiry.submitted_at),
          value(inquiry.parent_name, "—"),
          value(inquiry.child_name, "—"),
          value(inquiry.program, "—"),
          value(inquiry.phone, "—"),
          value(inquiry.email, "—"),
          value(inquiry.message, "—"),
        ]),
        weights: [1, 1.3, 1.1, 1, 1.1, 1.7, 2.1],
      },
    ];
  } else if (tableName === "report_exports") {
    const sections = await loadSections();
    const sectionIds = sections.map((row) => value(row.id)).filter(Boolean);
    const sectionScope = Boolean(
      value(parameters.academic_year_id) || value(parameters.grade_id) ||
        value(parameters.section_id),
    );
    const emptyId = "00000000-0000-0000-0000-000000000000";
    let studentsQuery = svc.from("students").select(
      "first_name, last_name, admission_number, status, gender, date_of_birth, current_section_id",
    ).eq("school_id", school);
    if (sectionScope) {
      studentsQuery = sectionIds.length
        ? studentsQuery.in("current_section_id", sectionIds)
        : studentsQuery.in("id", [emptyId]);
    }
    let subjectsQuery = svc.from("grade_subjects").select(
      "grade_id, section_id, periods_per_week, subject:subjects(subject_name), section:sections(section_name, grade:grades(grade_name)), grade:grades(grade_name)",
    ).eq("school_id", school);
    if (value(parameters.academic_year_id)) {
      subjectsQuery = subjectsQuery.eq(
        "academic_year_id",
        value(parameters.academic_year_id),
      );
    }
    if (value(parameters.grade_id)) {
      subjectsQuery = subjectsQuery.eq("grade_id", value(parameters.grade_id));
    }
    if (value(parameters.section_id)) {
      subjectsQuery = subjectsQuery.eq(
        "section_id",
        value(parameters.section_id),
      );
    }
    let timetableQuery = svc.from("timetable_slots").select(
      "section_id, day_of_week, start_time, end_time, section:sections(section_name, grade:grades(grade_name)), subject:subjects(subject_name), staff:staff(first_name, last_name)",
    ).eq("school_id", school);
    if (value(parameters.academic_year_id)) {
      timetableQuery = timetableQuery.eq(
        "academic_year_id",
        value(parameters.academic_year_id),
      );
    }
    if (sectionScope) {
      timetableQuery = sectionIds.length
        ? timetableQuery.in("section_id", sectionIds)
        : timetableQuery.in("section_id", [emptyId]);
    }
    const [studentsResponse, subjectsResponse, timetableResponse] =
      await Promise.all([studentsQuery, subjectsQuery, timetableQuery]);
    if (studentsResponse.error) throw studentsResponse.error;
    if (subjectsResponse.error) throw subjectsResponse.error;
    if (timetableResponse.error) throw timetableResponse.error;
    const students = (studentsResponse.data ?? []) as Record<string, any>[];
    const subjects = (subjectsResponse.data ?? []) as Record<string, any>[];
    const timetable = (timetableResponse.data ?? []) as Record<string, any>[];
    const sectionsById = new Map(
      sections.map((row) => [value(row.id), row]),
    );
    const classSummary: StructuredExportTable = {
      title: "Class summary",
      headers: ["Class", "Section", "Capacity", "Class teacher", "Co-teacher"],
      rows: sections.map((row) => [
        value(row.grade?.grade_name, "—"),
        value(row.section_name, "—"),
        value(row.capacity, "—"),
        person(row.class_teacher),
        person(row.co_teacher),
      ]),
      weights: [1.2, 0.9, 0.8, 1.7, 1.7],
    };
    const studentList: StructuredExportTable = {
      title: "Student roster",
      headers: [
        "Admission no.",
        "Student",
        "Gender",
        "Date of birth",
        "Class / section",
        "Status",
      ],
      rows: students.map((row) => {
        const section = sectionsById.get(value(row.current_section_id));
        return [
          value(row.admission_number, "—"),
          [value(row.first_name), value(row.last_name)].filter(Boolean).join(
            " ",
          ) || "—",
          titleize(value(row.gender, "—")),
          date(row.date_of_birth),
          [value(section?.grade?.grade_name), value(section?.section_name)]
            .filter(Boolean)
            .join(" / ") || "—",
          titleize(value(row.status, "—")),
        ];
      }),
      weights: [1.2, 2, 0.8, 1.1, 1.6, 0.9],
    };
    const subjectsMap: StructuredExportTable = {
      title: "Subjects mapping",
      headers: ["Class", "Section", "Subject", "Periods / week"],
      rows: subjects.map((row) => [
        value(row.section?.grade?.grade_name ?? row.grade?.grade_name, "—"),
        value(row.section?.section_name, "All sections"),
        value(row.subject?.subject_name, "—"),
        value(row.periods_per_week, "—"),
      ]),
      weights: [1.2, 1.2, 2.5, 1.1],
    };
    const teacherMap: StructuredExportTable = {
      title: "Teacher mapping",
      headers: ["Class", "Section", "Class teacher", "Co-teacher"],
      rows: classSummary.rows.map((row) => [row[0], row[1], row[3], row[4]]),
      weights: [1.1, 1, 2.3, 2.3],
    };
    const timetableSummary: StructuredExportTable = {
      title: "Timetable summary",
      headers: ["Class", "Section", "Day", "Subject", "Teacher", "Time"],
      rows: timetable.map((row) => [
        value(row.section?.grade?.grade_name, "—"),
        value(row.section?.section_name, "—"),
        titleize(value(row.day_of_week, "—")),
        value(row.subject?.subject_name, "—"),
        person(row.staff),
        [value(row.start_time), value(row.end_time)].filter(Boolean).join(
          " – ",
        ) || "—",
      ]),
      weights: [1, 0.9, 1, 1.7, 1.7, 1.2],
    };
    const selectedSection = sections.find((row) =>
      value(row.id) === value(parameters.section_id)
    );
    const selectedGrade = selectedSection?.grade?.grade_name ||
      sections[0]?.grade?.grade_name;
    scope = value(parameters.section_id)
      ? [
        "Class: " + value(selectedGrade, "Selected class"),
        "Section: " + value(selectedSection?.section_name, "Selected section"),
      ]
      : value(parameters.grade_id)
      ? ["Class: " + value(selectedGrade, "Selected class")]
      : ["All classes"];
    metrics = [
      { label: "Classes", value: String(sections.length) },
      { label: "Students", value: String(students.length) },
      { label: "Subjects", value: String(subjects.length) },
      { label: "Timetable slots", value: String(timetable.length) },
    ];
    tables = reportType === "students_list"
      ? [studentList]
      : reportType === "subjects_mapping"
      ? [subjectsMap]
      : reportType === "teacher_mapping"
      ? [teacherMap]
      : reportType === "timetable_summary"
      ? [timetableSummary]
      : reportType === "complete_classwise_data"
      ? [classSummary, studentList, subjectsMap, teacherMap, timetableSummary]
      : [classSummary];
  } else if (tableName === "fee_report_exports") {
    const sections = await loadSections();
    const sectionIds = sections.map((row) => value(row.id)).filter(Boolean);
    const sectionScope = Boolean(
      value(parameters.grade_id) || value(parameters.section_id),
    );
    const emptyId = "00000000-0000-0000-0000-000000000000";
    let structuresQuery = svc.from("fee_structures").select(
      "*, grade:grades(grade_name), section:sections(section_name)",
    ).eq("school_id", school);
    if (value(parameters.academic_year_id)) {
      structuresQuery = structuresQuery.eq(
        "academic_year_id",
        value(parameters.academic_year_id),
      );
    }
    if (value(parameters.grade_id)) {
      structuresQuery = structuresQuery.eq(
        "grade_id",
        value(parameters.grade_id),
      );
    }
    if (value(parameters.section_id)) {
      structuresQuery = structuresQuery.eq(
        "section_id",
        value(parameters.section_id),
      );
    }
    let studentIdsQuery = svc.from("students").select(
      "id, current_section_id",
    ).eq("school_id", school);
    if (sectionScope) {
      studentIdsQuery = sectionIds.length
        ? studentIdsQuery.in("current_section_id", sectionIds)
        : studentIdsQuery.in("id", [emptyId]);
    }
    const [structuresResponse, studentIdsResponse, categoriesResponse] =
      await Promise.all([
        structuresQuery.order("created_at"),
        studentIdsQuery,
        svc.from("fee_categories").select("id, name").eq("school_id", school),
      ]);
    if (structuresResponse.error) throw structuresResponse.error;
    if (studentIdsResponse.error) throw studentIdsResponse.error;
    if (categoriesResponse.error) throw categoriesResponse.error;
    const structures = (structuresResponse.data ?? []) as Record<string, any>[];
    const studentIds = (studentIdsResponse.data ?? [])
      .map((row: Record<string, any>) => value(row.id))
      .filter(Boolean);
    const categoryNames = new Map(
      (categoriesResponse.data ?? []).map((row: Record<string, any>) => [
        value(row.id),
        value(row.name, "Fee"),
      ]),
    );
    const paymentStatus = value(parameters.payment_status, "all");
    const today = new Date().toISOString().slice(0, 10);
    let invoicesQuery = svc.from("fee_invoices").select(
      "*, student:students(first_name, last_name, admission_number, current_section_id)",
    ).eq("school_id", school);
    if (value(parameters.academic_year_id)) {
      invoicesQuery = invoicesQuery.eq(
        "academic_year_id",
        value(parameters.academic_year_id),
      );
    }
    if (sectionScope) {
      invoicesQuery = studentIds.length
        ? invoicesQuery.in("student_id", studentIds)
        : invoicesQuery.in("student_id", [emptyId]);
    }
    if (paymentStatus === "paid") {
      invoicesQuery = invoicesQuery.eq("status", "paid");
    } else if (paymentStatus === "partial") {
      invoicesQuery = invoicesQuery.eq("status", "partial");
    } else if (paymentStatus === "pending") {
      invoicesQuery = invoicesQuery.eq("status", "pending");
    } else if (paymentStatus === "overdue") {
      invoicesQuery = invoicesQuery.gt("balance", 0).lt("due_date", today);
    }
    const { data: invoiceData, error: invoiceError } = await invoicesQuery
      .order(
        "due_date",
      );
    if (invoiceError) throw invoiceError;
    const invoices = (invoiceData ?? []) as Record<string, any>[];
    const daycarePlanIds = [
      ...new Set(
        invoices.map((row) => value(row.daycare_plan_id)).filter(Boolean),
      ),
    ];
    const { data: daycarePlanRows, error: daycarePlanError } =
      daycarePlanIds.length
        ? await svc.from("daycare_fee_plans").select(
          "id, hourly_rate, contracted_hours_per_month, monthly_amount, fee_label",
        ).eq("school_id", school).in("id", daycarePlanIds)
        : { data: [], error: null };
    if (daycarePlanError) throw daycarePlanError;
    const daycarePlansById = new Map(
      (daycarePlanRows ?? []).map((row: Record<string, any>) => [
        value(row.id),
        row,
      ]),
    );
    const invoiceRows = (rows: Record<string, any>[]) =>
      rows.map((row) => {
        const student = row.student ?? {};
        const section = sections.find((item) =>
          value(item.id) === value(student.current_section_id)
        );
        return [
          value(row.invoice_number, "—"),
          [value(student.first_name), value(student.last_name)].filter(Boolean)
            .join(" ") || "—",
          value(student.admission_number, "—"),
          [value(section?.grade?.grade_name), value(section?.section_name)]
            .filter(Boolean)
            .join(" / ") || "—",
          date(row.due_date),
          currency(row.net_amount || row.total_amount),
          currency(row.paid_amount),
          currency(row.balance),
          titleize(value(row.status, "—")),
        ];
      });
    const daycareRows = invoices.filter((row) =>
      value(row.daycare_plan_id) ||
      value(row.fee_type).toLowerCase().includes("daycare")
    );
    const daycareFinanceTable: StructuredExportTable = {
      title: "Day Care Finance",
      headers: [
        "Student",
        "Month",
        "Hourly rate",
        "Hours",
        "Billed",
        "Paid",
        "Balance",
        "Due date",
        "Status",
      ],
      rows: daycareRows.map((row) => {
        const details = object(row.billing_details);
        const plan = daycarePlansById.get(value(row.daycare_plan_id)) ?? {};
        const student = row.student ?? {};
        return [
          person(student),
          date(row.billing_period || details.billing_period),
          amount(details.hourly_rate ?? plan.hourly_rate) > 0
            ? currency(details.hourly_rate ?? plan.hourly_rate)
            : "Legacy monthly",
          amount(
              details.contracted_hours_per_month ??
                plan.contracted_hours_per_month,
            ) > 0
            ? String(
              amount(
                details.contracted_hours_per_month ??
                  plan.contracted_hours_per_month,
              ),
            )
            : "—",
          currency(row.net_amount || row.total_amount),
          currency(row.paid_amount),
          currency(row.balance),
          date(row.due_date),
          titleize(value(row.status, "—")),
        ];
      }),
      weights: [1.7, 1, 1.1, 0.8, 1, 1, 1, 0.9, 0.8],
    };
    const paidRows = invoices.filter((row) => value(row.status) === "paid");
    const pendingRows = invoices.filter((row) =>
      ["pending", "partial"].includes(value(row.status))
    );
    const dueRows = invoices.filter((row) => amount(row.balance) > 0);
    const reportInvoices = reportType === "paid_fees"
      ? paidRows
      : reportType === "pending_fees"
      ? pendingRows
      : reportType === "due_fees"
      ? dueRows
      : invoices;
    const structuresForReport = paymentStatus === "all"
      ? structures
      : structures.filter((structure) =>
        invoices.some((invoice) =>
          value(invoice.fee_structure_id) === value(structure.id)
        )
      );
    const structureTable: StructuredExportTable = {
      title: "Fee structures",
      headers: ["Fee", "Class", "Section", "Frequency", "Due date", "Amount"],
      rows: structuresForReport.map((row) => [
        categoryNames.get(value(row.fee_category_id || row.category_id)) ||
        value(row.fee_type, "Fee"),
        value(row.grade?.grade_name, "All classes"),
        value(row.section?.section_name, "All sections"),
        titleize(value(row.billing_mode || row.frequency, "—")),
        date(row.due_date),
        currency(row.amount),
      ]),
      weights: [1.8, 1.2, 1.2, 1.2, 1.1, 1.2],
    };
    const invoiceTable: StructuredExportTable = {
      title: "Student fee invoices",
      headers: [
        "Invoice",
        "Student",
        "Admission no.",
        "Class / section",
        "Due",
        "Billed",
        "Paid",
        "Balance",
        "Status",
      ],
      rows: invoiceRows(reportInvoices),
      weights: [1.1, 1.6, 1.1, 1.35, 0.85, 1, 1, 1, 0.85],
    };
    const totalBilled = reportInvoices.reduce(
      (sum, row) => sum + amount(row.net_amount || row.total_amount),
      0,
    );
    const totalPaid = reportInvoices.reduce(
      (sum, row) => sum + amount(row.paid_amount),
      0,
    );
    const totalBalance = reportInvoices.reduce(
      (sum, row) => sum + amount(row.balance),
      0,
    );
    title = titleize(reportType);
    const selectedSection = sections.find((row) =>
      value(row.id) === value(parameters.section_id)
    );
    const selectedGrade = selectedSection?.grade?.grade_name ||
      sections[0]?.grade?.grade_name;
    scope = [
      ...(value(parameters.section_id)
        ? [
          "Class: " + value(selectedGrade, "Selected class"),
          "Section: " +
          value(selectedSection?.section_name, "Selected section"),
        ]
        : value(parameters.grade_id)
        ? ["Class: " + value(selectedGrade, "Selected class")]
        : ["All classes"]),
      "Payment status: " + titleize(paymentStatus),
    ];
    metrics = [
      { label: "Fee structures", value: String(structuresForReport.length) },
      { label: "Invoices", value: String(reportInvoices.length) },
      { label: "Billed", value: currency(totalBilled) },
      { label: "Collected", value: currency(totalPaid) },
      { label: "Outstanding", value: currency(totalBalance) },
    ];
    tables = reportType === "fee_structure"
      ? [structureTable]
      : reportType === "paid_fees"
      ? [{ ...invoiceTable, title: "Paid fees", rows: invoiceRows(paidRows) }]
      : reportType === "pending_fees"
      ? [{
        ...invoiceTable,
        title: "Pending fees",
        rows: invoiceRows(pendingRows),
      }]
      : reportType === "due_fees" ||
          reportType === "fee_outstanding_report" ||
          reportType === "outstanding_report"
      ? [{ ...invoiceTable, title: "Due fees", rows: invoiceRows(dueRows) }]
      : reportType === "complete_fees_report"
      ? [
        structureTable,
        ...(daycareRows.length > 0 ? [daycareFinanceTable] : []),
        invoiceTable,
      ]
      : [invoiceTable];
  } else if (tableName === "attendance_report_exports") {
    const { data, error } = await svc.from("attendance_summaries").select(
      "*, student:students(first_name, last_name, admission_number)",
    ).eq("school_id", school);
    if (error) throw error;
    const attendance = (data ?? []) as Record<string, any>[];
    title = "Attendance report";
    metrics = [{ label: "Students", value: String(attendance.length) }];
    tables = [{
      title: "Attendance summary",
      headers: [
        "Student",
        "Admission no.",
        "Total days",
        "Present",
        "Absent",
        "Attendance",
      ],
      rows: attendance.map((row) => [
        person(row.student),
        value(row.student?.admission_number, "—"),
        value(row.total_days, "0"),
        value(row.present_days, "0"),
        value(row.absent_days, "0"),
        value(row.percentage, "0") + "%",
      ]),
      weights: [2.2, 1.5, 1, 1, 1, 1.2],
    }];
  }

  const pdfEscape = (input: unknown) =>
    value(input)
      .replaceAll("\\", "\\\\")
      .replaceAll("(", "\\(")
      .replaceAll(")", "\\)")
      .replace(/[\r\n]+/g, " ")
      .replace(/\s+/g, " ")
      .trim()
      .replaceAll("—", "-")
      .replaceAll("–", "-")
      .replaceAll("•", "|")
      .normalize("NFC");
  const wrap = (input: unknown, limit: number) => {
    const source = pdfEscape(input) || "—";
    const lines: string[] = [];
    let line = "";
    for (const word of source.split(" ")) {
      const candidate = line ? line + " " + word : word;
      if (candidate.length <= limit || !line) {
        line = candidate;
      } else {
        lines.push(line);
        line = word;
      }
    }
    if (line) lines.push(line);
    return lines.length ? lines : ["—"];
  };
  const pageWidth = 842;
  const pageHeight = 595;
  const margin = 32;
  const usableWidth = pageWidth - margin * 2;
  const pages: string[][] = [];
  let commands: string[] = [];
  let cursorY = 0;
  const textAt = (
    target: string[],
    lines: string[],
    x: number,
    y: number,
    font: string,
    size: number,
    color: string,
  ) => {
    lines.forEach((line, index) => {
      target.push(
        "BT /" + font + " " + size + " Tf " + x.toFixed(2) + " " +
          (y - index * (size + 2)).toFixed(2) + " Td " + color + " rg (" +
          pdfEscape(line) + ") Tj ET",
      );
    });
  };
  const rect = (
    x: number,
    y: number,
    width: number,
    height: number,
    color: string,
    stroke = false,
  ) => {
    commands.push(
      color + (stroke ? " RG " : " rg ") + x.toFixed(2) + " " +
        y.toFixed(2) + " " + width.toFixed(2) + " " + height.toFixed(2) +
        " re " + (stroke ? "S" : "f"),
    );
  };
  const startPage = (continuation = false) => {
    commands = [];
    rect(0, pageHeight - 64, pageWidth, 64, "0.05 0.14 0.31");
    textAt(commands, [schoolName], margin, pageHeight - 31, "F2", 17, "1 1 1");
    textAt(
      commands,
      [branchCode ? "Branch: " + branchCode : "Academic data export"],
      margin,
      pageHeight - 47,
      "F1",
      8,
      "0.78 0.88 1",
    );
    textAt(
      commands,
      [continuation ? "Report continued" : title],
      pageWidth - 290,
      pageHeight - 34,
      "F2",
      11,
      "1 1 1",
    );
    textAt(
      commands,
      ["Academic year: " + academicYear],
      pageWidth - 290,
      pageHeight - 48,
      "F1",
      8,
      "0.78 0.88 1",
    );
    cursorY = pageHeight - 88;
    if (!continuation) {
      textAt(commands, [title], margin, cursorY, "F2", 16, "0.04 0.1 0.22");
      cursorY -= 17;
      textAt(
        commands,
        [scope.filter(Boolean).join("  •  ") || "School-wide scope"],
        margin,
        cursorY,
        "F1",
        8,
        "0.29 0.36 0.48",
      );
      cursorY -= 20;
      const metricWidth = usableWidth / Math.max(1, metrics.length);
      metrics.forEach((metric, index) => {
        const x = margin + index * metricWidth;
        rect(x, cursorY - 31, metricWidth - 7, 30, "0.93 0.96 1");
        textAt(
          commands,
          [metric.label],
          x + 7,
          cursorY - 10,
          "F1",
          7,
          "0.29 0.36 0.48",
        );
        textAt(
          commands,
          [metric.value],
          x + 7,
          cursorY - 23,
          "F2",
          9,
          "0.05 0.18 0.42",
        );
      });
      cursorY -= 45;
    }
    pages.push(commands);
  };
  const header = (table: StructuredExportTable, widths: number[]) => {
    rect(margin, cursorY - 18, usableWidth, 18, "0.1 0.31 0.66");
    let x = margin;
    table.headers.forEach((label, index) => {
      textAt(
        commands,
        wrap(label, Math.max(7, Math.floor(widths[index] / 4.7))),
        x + 4,
        cursorY - 7,
        "F2",
        7,
        "1 1 1",
      );
      x += widths[index];
    });
    cursorY -= 20;
  };
  const drawTable = (table: StructuredExportTable) => {
    const weights = table.weights?.length === table.headers.length
      ? table.weights
      : table.headers.map(() => 1);
    const totalWeight = weights.reduce((sum, item) => sum + item, 0);
    const widths = weights.map((item) => usableWidth * item / totalWeight);
    if (cursorY < 72) startPage(true);
    textAt(commands, [table.title], margin, cursorY, "F2", 11, "0.04 0.1 0.22");
    cursorY -= 15;
    header(table, widths);
    const rows = table.rows.length
      ? table.rows
      : [["No records match the selected report scope."]];
    rows.forEach((row, rowIndex) => {
      const linesByCell = table.headers.map((_, index) =>
        wrap(row[index] ?? "", Math.max(7, Math.floor(widths[index] / 4.6)))
      );
      const lineCount = Math.max(...linesByCell.map((lines) => lines.length));
      const rowHeight = Math.max(18, lineCount * 9 + 8);
      if (cursorY - rowHeight < 42) {
        startPage(true);
        textAt(
          commands,
          [table.title],
          margin,
          cursorY,
          "F2",
          11,
          "0.04 0.1 0.22",
        );
        cursorY -= 15;
        header(table, widths);
      }
      rect(
        margin,
        cursorY - rowHeight,
        usableWidth,
        rowHeight,
        rowIndex % 2 === 0 ? "0.97 0.98 1" : "1 1 1",
      );
      rect(
        margin,
        cursorY - rowHeight,
        usableWidth,
        rowHeight,
        "0.82 0.87 0.94",
        true,
      );
      let x = margin;
      linesByCell.forEach((lines, index) => {
        textAt(commands, lines, x + 4, cursorY - 10, "F1", 7, "0.08 0.13 0.22");
        x += widths[index];
      });
      cursorY -= rowHeight;
    });
    cursorY -= 16;
  };

  if (!tables.length) {
    tables = [{
      title: "Report data",
      headers: ["Status"],
      rows: [["No data generated"]],
    }];
  }
  startPage();
  tables.forEach(drawTable);
  pages.forEach((page, index) => {
    textAt(
      page,
      ["Confidential school record"],
      margin,
      22,
      "F1",
      8,
      "0.35 0.4 0.48",
    );
    textAt(
      page,
      ["Page " + (index + 1) + " of " + pages.length],
      pageWidth - 106,
      22,
      "F1",
      8,
      "0.35 0.4 0.48",
    );
  });
  const streams = pages.map((page) => page.join("\n"));
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [" +
    streams.map((_, index) => String(5 + index * 2) + " 0 R").join(" ") +
    "] /Count " + streams.length + " >>",
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>",
    ...streams.flatMap((stream, index) => [
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 842 595] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents " +
      (6 + index * 2) + " 0 R >>",
      "<< /Length " + new TextEncoder().encode(stream).length +
      " >>\nstream\n" + stream + "\nendstream",
    ]),
  ];
  let pdf = "%PDF-1.4\n";
  const offsets = [0];
  objects.forEach((object, index) => {
    offsets.push(new TextEncoder().encode(pdf).length);
    pdf += String(index + 1) + " 0 obj\n" + object + "\nendobj\n";
  });
  const xref = new TextEncoder().encode(pdf).length;
  pdf += "xref\n0 " + (objects.length + 1) + "\n0000000000 65535 f \n";
  offsets.slice(1).forEach((offset) => {
    pdf += offset.toString().padStart(10, "0") + " 00000 n \n";
  });
  pdf += "trailer\n<< /Size " + (objects.length + 1) +
    " /Root 1 0 R >>\nstartxref\n" + xref + "\n%%EOF";
  const reportBytes = await renderStructuredReportPdf({
    title,
    schoolName,
    branchCode,
    academicYear,
    scope,
    metrics,
    tables,
  });
  return await uploadPrivateReportPdf(svc, school, reportBytes);
}

async function performReportExport(
  svc: SupabaseClient,
  school: string,
  tableName: string,
  reportType: string,
  parameters: Record<string, any>,
): Promise<string> {
  let headers: string[] = ["Report Export"];
  let rows: unknown[][] = [["No data generated"]];

  if (tableName === "report_exports") {
    if (reportType === "users_wise_export") {
      let query = svc.from("users").select(
        "name, email, role_name, is_active, created_at",
      ).eq("school_id", school);
      if (
        parameters.roles && Array.isArray(parameters.roles) &&
        parameters.roles.length > 0
      ) {
        query = query.in("role_name", parameters.roles);
      }
      if (parameters.status && parameters.status !== "all") {
        query = query.eq("is_active", parameters.status === "active");
      }
      const { data } = await query;
      headers = ["Name", "Email", "Role", "Status", "Created At"];
      rows = (data ?? []).map((u: any) => [
        u.name,
        u.email,
        u.role_name,
        u.is_active ? "Active" : "Inactive",
        u.created_at,
      ]);
    } else if (reportType === "students_list") {
      let query = svc.from("students").select(
        "first_name, last_name, admission_number, status, gender, date_of_birth, section:sections(section_name, grade:grades(grade_name))",
      ).eq("school_id", school);
      if (parameters.section_id) {
        query = query.eq("current_section_id", parameters.section_id);
      } else if (parameters.grade_id) {
        const { data: sections } = await svc.from("sections").select("id").eq(
          "grade_id",
          parameters.grade_id,
        );
        const secIds = (sections ?? []).map((s: any) => s.id);
        if (secIds.length > 0) {
          query = query.in("current_section_id", secIds);
        }
      }
      const { data } = await query;
      headers = [
        "Admission Number",
        "First Name",
        "Last Name",
        "Gender",
        "Date of Birth",
        "Grade",
        "Section",
        "Status",
      ];
      rows = (data ?? []).map((s: any) => [
        s.admission_number,
        s.first_name,
        s.last_name,
        s.gender,
        s.date_of_birth,
        s.section?.grade?.grade_name,
        s.section?.section_name,
        s.status,
      ]);
    } else if (
      reportType === "class_summary" || reportType === "complete_classwise_data"
    ) {
      const { data } = await svc.from("sections").select(
        "*, grade:grades(grade_name), class_teacher:staff!sections_class_teacher_id_fkey(first_name, last_name)",
      ).eq("school_id", school);
      headers = ["Grade", "Section", "Capacity", "Class Teacher"];
      rows = (data ?? []).map((s: any) => [
        s.grade?.grade_name,
        s.section_name,
        s.capacity,
        s.class_teacher
          ? `${s.class_teacher.first_name} ${s.class_teacher.last_name}`.trim()
          : "Pending",
      ]);
    } else if (reportType === "teacher_mapping") {
      const { data } = await svc.from("sections").select(
        "*, grade:grades(grade_name), class_teacher:staff!sections_class_teacher_id_fkey(first_name, last_name), co_teacher:staff!sections_co_teacher_id_fkey(first_name, last_name)",
      ).eq("school_id", school);
      headers = ["Grade", "Section", "Class Teacher", "Co-Teacher"];
      rows = (data ?? []).map((s: any) => [
        s.grade?.grade_name,
        s.section_name,
        s.class_teacher
          ? `${s.class_teacher.first_name} ${s.class_teacher.last_name}`.trim()
          : "Pending",
        s.co_teacher
          ? `${s.co_teacher.first_name} ${s.co_teacher.last_name}`.trim()
          : "Pending",
      ]);
    } else if (
      reportType === "subjects_mapping" || reportType === "timetable_summary"
    ) {
      const { data } = await svc.from("timetable_slots").select(
        "*, section:sections(section_name, grade:grades(grade_name)), subject:subjects(subject_name), staff:staff(first_name, last_name)",
      ).eq("school_id", school);
      headers = [
        "Grade",
        "Section",
        "Subject",
        "Teacher",
        "Day of Week",
        "Start Time",
        "End Time",
      ];
      rows = (data ?? []).map((sl: any) => [
        sl.section?.grade?.grade_name,
        sl.section?.section_name,
        sl.subject?.subject_name,
        sl.staff ? `${sl.staff.first_name} ${sl.staff.last_name}`.trim() : "",
        sl.day_of_week,
        sl.start_time,
        sl.end_time,
      ]);
    } else {
      const { data } = await svc.from("sections").select(
        "*, grade:grades(grade_name)",
      ).eq("school_id", school);
      headers = ["Grade", "Section", "Capacity"];
      rows = (data ?? []).map((s: any) => [
        s.grade?.grade_name,
        s.section_name,
        s.capacity,
      ]);
    }
  } else if (tableName === "fee_report_exports") {
    if (reportType === "receipt_export") {
      const txId = parameters.transaction_id ||
        parameters.parameters?.transaction_id || parameters.receipt_number;
      let query = svc.from("payments").select(
        "*, invoice:fee_invoices(*, student:students(first_name, last_name, admission_number))",
      ).eq("school_id", school);
      const isUuid =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          `${txId}`,
        );
      if (isUuid) {
        query = query.eq("id", txId);
      } else {
        query = query.eq("reference_number", txId);
      }
      const { data } = await query.maybeSingle();
      headers = ["Transaction Attribute", "Value"];
      if (data) {
        rows = [
          ["Transaction ID", data.id],
          [
            "Student Name",
            data.invoice?.student
              ? `${data.invoice.student.first_name} ${data.invoice.student.last_name}`
                .trim()
              : "",
          ],
          ["Admission Number", data.invoice?.student?.admission_number],
          ["Invoice", data.invoice?.title],
          ["Amount Paid", data.amount],
          ["Payment Date", data.paid_at],
          ["Payment Mode", data.payment_method],
          ["Status", data.status],
        ];
      } else {
        rows = [["Receipt not found", txId]];
      }
    } else if (
      reportType === "fee_outstanding_report" ||
      reportType === "outstanding_report"
    ) {
      const { data } = await svc.from("fee_invoices").select(
        "*, student:students(first_name, last_name, admission_number)",
      ).eq("school_id", school).gt("balance", 0);
      headers = [
        "Student Name",
        "Admission Number",
        "Invoice Title",
        "Due Date",
        "Amount",
        "Balance",
      ];
      rows = (data ?? []).map((i: any) => [
        i.student
          ? `${i.student.first_name} ${i.student.last_name}`.trim()
          : "",
        i.student?.admission_number,
        i.title,
        i.due_date,
        i.amount,
        i.balance,
      ]);
    } else {
      const { data } = await svc.from("payments").select(
        "*, invoice:fee_invoices(*, student:students(first_name, last_name, admission_number))",
      ).eq("school_id", school);
      headers = [
        "Transaction ID",
        "Student Name",
        "Admission Number",
        "Invoice",
        "Amount Paid",
        "Payment Date",
        "Payment Mode",
        "Status",
      ];
      rows = (data ?? []).map((p: any) => [
        p.id,
        p.invoice?.student
          ? `${p.invoice.student.first_name} ${p.invoice.student.last_name}`
            .trim()
          : "",
        p.invoice?.student?.admission_number,
        p.invoice?.title,
        p.amount,
        p.paid_at,
        p.payment_method,
        p.status,
      ]);
    }
  } else if (tableName === "attendance_report_exports") {
    const { data } = await svc.from("attendance_summaries").select(
      "*, student:students(first_name, last_name, admission_number)",
    ).eq("school_id", school);
    headers = [
      "Student Name",
      "Admission Number",
      "Total Days",
      "Present Days",
      "Absent Days",
      "Attendance %",
    ];
    rows = (data ?? []).map((a: any) => [
      a.student ? `${a.student.first_name} ${a.student.last_name}`.trim() : "",
      a.student?.admission_number,
      a.total_days,
      a.present_days,
      a.absent_days,
      a.percentage,
    ]);
  }

  // A report export must be readable as a document, not a single text stream.
  // Keep the renderer dependency-free for Deno while producing paginated tables
  // with a branded header, metadata, repeated headers, and page numbers.
  const pdfEscape = (value: unknown) =>
    `${value ?? ""}`
      .replaceAll("\\", "\\\\")
      .replaceAll("(", "\\(")
      .replaceAll(")", "\\)")
      .replace(/[\r\n]+/g, " ");
  const truncate = (value: unknown, length: number) => {
    const text = pdfEscape(value).replace(/\s+/g, " ").trim();
    return text.length <= length
      ? text
      : `${text.slice(0, Math.max(1, length - 1))}…`;
  };
  const columnCount = Math.max(1, headers.length);
  const pageWidth = 792;
  const pageHeight = 612;
  const margin = 34;
  const usableWidth = pageWidth - margin * 2;
  const columnWidth = usableWidth / columnCount;
  const rowsPerPage = 20;
  const pages = Math.max(1, Math.ceil(Math.max(rows.length, 1) / rowsPerPage));
  const pageStreams = Array.from({ length: pages }, (_, pageIndex) => {
    const pageRows = rows.slice(
      pageIndex * rowsPerPage,
      (pageIndex + 1) * rowsPerPage,
    );
    const lines: string[] = [
      "0.05 0.12 0.28 rg",
      `0 ${pageHeight - 54} ${pageWidth} 54 re f`,
      "BT /F2 18 Tf 34 580 Td 1 1 1 rg (SchoolDesk) Tj ET",
      "BT /F1 10 Tf 144 581 Td 0.82 0.9 1 rg (Academic data export) Tj ET",
      `BT /F2 13 Tf ${margin} 540 Td 0.03 0.09 0.2 rg (${
        pdfEscape(
          reportType.replaceAll("_", " ").replace(
            /\b\w/g,
            (c) => c.toUpperCase(),
          ),
        )
      }) Tj ET`,
      `BT /F1 8 Tf ${margin} 524 Td 0.3 0.36 0.45 rg (Generated ${
        pdfEscape(new Date().toISOString().replace("T", " ").slice(0, 16))
      } UTC  |  ${rows.length} record(s)) Tj ET`,
      "0.09 0.36 0.75 rg",
      `${margin} 498 ${usableWidth} 20 re f`,
    ];
    headers.forEach((header, index) => {
      const x = margin + index * columnWidth + 4;
      lines.push(
        `BT /F2 7 Tf ${x.toFixed(2)} 505 Td 1 1 1 rg (${
          truncate(header, Math.floor(columnWidth / 4.3))
        }) Tj ET`,
      );
    });
    const renderRows = pageRows.length
      ? pageRows
      : [["No records match the selected report scope."]];
    renderRows.forEach((row, rowIndex) => {
      const y = 478 - rowIndex * 19;
      const shade = rowIndex % 2 === 0 ? "0.97 0.98 1 rg" : "1 1 1 rg";
      lines.push(
        shade,
        `${margin} ${y - 4} ${usableWidth} 19 re f`,
        "0.85 0.89 0.95 RG",
        `${margin} ${y - 4} ${usableWidth} 19 re S`,
      );
      for (let index = 0; index < columnCount; index++) {
        const x = margin + index * columnWidth + 4;
        const value = row[index] ?? "";
        lines.push(
          `BT /F1 7 Tf ${x.toFixed(2)} ${y + 2} Td 0.08 0.13 0.22 rg (${
            truncate(value, Math.floor(columnWidth / 4.3))
          }) Tj ET`,
        );
      }
    });
    lines.push(
      "0.35 0.4 0.48 rg",
      `BT /F1 8 Tf ${margin} 22 Td (Confidential school record) Tj ET`,
      `BT /F1 8 Tf ${pageWidth - 116} 22 Td (Page ${
        pageIndex + 1
      } of ${pages}) Tj ET`,
    );
    return lines.join("\n");
  });
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    `<< /Type /Pages /Kids [${
      pageStreams.map((_, index) => `${5 + index * 2} 0 R`).join(" ")
    }] /Count ${pages} >>`,
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>",
    ...pageStreams.flatMap((stream, index) => [
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 792 612] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents " +
      (6 + index * 2) + " 0 R >>",
      `<< /Length ${
        new TextEncoder().encode(stream).length
      } >>\nstream\n${stream}\nendstream`,
    ]),
  ];
  let pdf = "%PDF-1.4\n";
  const offsets = [0];
  objects.forEach((object, index) => {
    offsets.push(new TextEncoder().encode(pdf).length);
    pdf += `${index + 1} 0 obj\n${object}\nendobj\n`;
  });
  const xref = new TextEncoder().encode(pdf).length;
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  offsets.slice(1).forEach((offset) => {
    pdf += `${offset.toString().padStart(10, "0")} 00000 n \n`;
  });
  pdf += `trailer\n<< /Size ${
    objects.length + 1
  } /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  const reportTitle = reportType.replaceAll("_", " ").replace(
    /\b\w/g,
    (character) => character.toUpperCase(),
  );
  const reportBytes = await renderStructuredReportPdf({
    title: reportTitle,
    schoolName: "SchoolDesk",
    academicYear: textValue(parameters.academic_year, "Not specified"),
    scope: [textValue(parameters.scope, "School-wide scope")],
    metrics: [{ label: "Records", value: String(rows.length) }],
    tables: [{ title: "Report data", headers, rows }],
  });
  return await uploadPrivateReportPdf(svc, school, reportBytes);
}

export async function queueReportExport(
  svc: SupabaseClient,
  school: string,
  user: User,
  tableName: string,
  body: Record<string, unknown>,
) {
  const id = crypto.randomUUID();
  const report_type = textValue(body.report_type, "generic");
  const format = textValue(body.format, "pdf").toLowerCase();
  if (format !== "pdf") {
    throw new Error("Only PDF report exports are supported");
  }
  const parameters = body.parameters ?? body;

  let status = "queued";
  let downloadUrl = "";
  const structuredAcademicReports = new Set([
    "class_summary",
    "students_list",
    "subjects_mapping",
    "teacher_mapping",
    "timetable_summary",
    "complete_classwise_data",
    "users_wise_export",
    "admission_inquiry_summary",
  ]);
  const structuredFeeReports = new Set([
    "fee_structure",
    "student_fee_invoices",
    "paid_fees",
    "pending_fees",
    "due_fees",
    "complete_fees_report",
  ]);
  const usesStructuredAcademicExport = (tableName === "report_exports" &&
    structuredAcademicReports.has(report_type)) ||
    (tableName === "fee_report_exports" &&
      structuredFeeReports.has(report_type));

  try {
    downloadUrl = await (usesStructuredAcademicExport
      ? performStructuredReportExport
      : performReportExport)(
        svc,
        school,
        tableName,
        report_type,
        parameters,
      );
    status = "completed";
  } catch (err) {
    console.error(
      "Synchronous report generation failed, fallback to queued:",
      err,
    );
  }

  const payload = {
    id,
    report_title: textValue(body.report_title ?? body.report, "Report export"),
    report_type,
    format,
    scope: textValue(body.scope, "school"),
    parameters,
    status,
    requested_by: user.id,
    created_at: new Date().toISOString(),
    download_url: downloadUrl,
  };
  const { data, error } = await svc.from("frontend_records").insert({
    school_id: school,
    table_name: tableName,
    record_id: id,
    data: payload,
  }).select().single();
  if (error) throw error;
  return data?.data ?? payload;
}

export async function handleUploads(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  if (method !== "POST") return fail("method not allowed", 405);

  const form = await req.formData().catch(() => null);
  if (!form) return fail("multipart form required");

  const file = form.get("file") as File;
  if (!file) return fail("file field required");

  const folder = form.get("folder") as string ?? "uploads";
  const entityType = form.get("entity_type") as string ?? "";
  const entityId = form.get("entity_id") as string ?? "";
  const privateUpload = !["false", "0", "no"].includes(
    `${form.get("private") ?? "true"}`.trim().toLowerCase(),
  );
  const filePath = privateUpload
    ? `${school}/${folder}/${entityType}/${entityId}/${Date.now()}-${file.name}`
    : `${folder}/${school}/${entityType}/${entityId}/${Date.now()}-${file.name}`;
  const bucket = privateUpload ? PRIVATE_FILES_BUCKET : "school-assets";

  // Explicitly forward the content type so Supabase Storage never falls back
  // to application/octet-stream for MP4 and other video files.
  const contentType = file.type || _guessMimeFromName(file.name);
  let storedPath = filePath;
  let url = "";
  let privateReference = "";
  if (privateUpload) {
    const r2Upload = await uploadToR2(
      `private/${filePath}`,
      file,
      contentType,
    );
    if (r2Upload) {
      privateReference = r2FileReference(r2Upload.key);
      storedPath = privateReference;
      url = await signedPrivateFileUrl(svc, privateReference);
    }
  }
  if (!privateUpload) {
    const r2Upload = await uploadPublicToR2(filePath, file, contentType);
    if (r2Upload) {
      storedPath = publicR2FileReference(r2Upload.key);
      url = r2Upload.url;
    }
  }
  if (!url) {
    if (!legacyStorageWritesEnabled()) {
      return fail("R2 storage is unavailable; legacy storage writes are disabled", 503);
    }
    const { error: uploadErr } = await svc.storage.from(bucket).upload(
      filePath,
      file,
      {
        upsert: true,
        contentType,
        cacheControl: privateUpload ? "3600" : "31536000",
      },
    );
    if (uploadErr) return fail(uploadErr.message);
    url = privateUpload
      ? await signedPrivateFileUrl(svc, privateFileReference(filePath))
      : svc.storage.from(bucket).getPublicUrl(filePath).data.publicUrl;
  }
  if (!url) return fail("failed to create file URL");

  const persistedPrivateReference = privateReference ||
    privateFileReference(filePath);

  const { data } = await svc.from("uploaded_files").insert({
    school_id: school,
    uploader_id: user.id,
    url: privateUpload ? persistedPrivateReference : url,
    path: privateUpload ? persistedPrivateReference : storedPath,
    folder,
    entity_type: entityType,
    entity_id: entityId,
    file_name: file.name,
    file_size: file.size,
    mime_type: file.type,
  }).select().single();

  return ok({
    url,
    path: privateUpload ? persistedPrivateReference : storedPath,
    file: data,
  });
}

// handlers/events.ts
export async function handleEvents(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  await ensureEventPostSchema();
  const school = sid(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};
  const parts = path.slice("/event-posts".length).split("/").filter(Boolean);
  const seg = parts[0];

  if (path === "/event-posts/pending" && method === "GET") {
    if (!["principal", "coordinator"].includes(roleValue(user))) {
      return fail("forbidden", 403);
    }
    const paging = listPaging(url);
    const { data, error, count } = await svc.from("event_posts").select("*", {
      count: "exact",
    }).eq(
      "school_id",
      school,
    ).in("status", ["pending", "submitted"]).order("created_at", {
      ascending: false,
    }).range(paging.from, paging.to);
    if (error) return fail(error.message);
    const rows = await eventPostRows(
      svc,
      (data ?? []) as Record<string, unknown>[],
    );
    return ok(listEnvelope(rows, count, paging.page, paging.pageSize));
  }
  if (path === "/event-posts/gallery" && method === "GET") {
    if (!canViewSchoolFeed(user)) return fail("forbidden", 403);
    const paging = listPaging(url);
    const { data, error, count } = await svc.from("event_posts").select("*", {
      count: "exact",
    }).eq(
      "school_id",
      school,
    ).in("status", ["approved", "published"])
      // `destinations` is jsonb.  Passing a JavaScript array here serializes
      // to a Postgres-array literal (`{SCHOOL_GALLERY}`), which PostgREST then
      // rejects as invalid JSON. Keep the JSON array literal intact.
      .contains("destinations", JSON.stringify(["SCHOOL_GALLERY"]))
      .order("created_at", {
        ascending: false,
      }).order("id", {
        ascending: false,
      }).range(paging.from, paging.to);
    if (error) return fail(error.message);
    const rows = await eventPostRows(
      svc,
      (data ?? []) as Record<string, unknown>[],
    );
    return ok(listEnvelope(rows, count, paging.page, paging.pageSize));
  }
  if (path === "/event-posts/home-feed" && method === "GET") {
    if (!canViewSchoolFeed(user)) return fail("forbidden", 403);
    const paging = listPaging(url);
    const { data, error, count } = await svc.from("event_posts").select("*", {
      count: "exact",
    }).eq(
      "school_id",
      school,
    ).in("status", ["approved", "published"])
      .contains("destinations", JSON.stringify(["PARENTS_HOME"]))
      .order("created_at", {
        ascending: false,
      }).order("id", {
        ascending: false,
      }).range(paging.from, paging.to);
    if (error) return fail(error.message);
    const rows = await eventPostRows(
      svc,
      (data ?? []) as Record<string, unknown>[],
    );
    return ok(listEnvelope(rows, count, paging.page, paging.pageSize));
  }
  if (path === "/event-posts/teacher-feed" && method === "GET") {
    if (roleValue(user) !== "teacher") return fail("forbidden", 403);
    const paging = listPaging(url);
    // Teacher feed is a staff-facing surface. Existing parent-home posts are
    // school-wide updates, while TEACHERS_HOME is an explicit staff-only
    // destination. Gallery posts are included because they are approved
    // school activity updates, but landing-only posts remain public-site-only.
    const teacherDestinations = [
      `destinations.cs.${JSON.stringify(["TEACHERS_HOME"])}`,
      `destinations.cs.${JSON.stringify(["PARENTS_HOME"])}`,
      `destinations.cs.${JSON.stringify(["SCHOOL_GALLERY"])}`,
    ].join(",");
    const { data, error, count } = await svc.from("event_posts").select("*", {
      count: "exact",
    }).eq(
      "school_id",
      school,
    ).in("status", ["approved", "published"]).or(teacherDestinations)
      .order("created_at", {
        ascending: false,
      }).order("id", {
        ascending: false,
      }).range(paging.from, paging.to);
    if (error) return fail(error.message);
    const rows = await eventPostRows(
      svc,
      (data ?? []) as Record<string, unknown>[],
    );
    return ok(listEnvelope(rows, count, paging.page, paging.pageSize));
  }
  if (path === "/event-posts/teacher" && method === "GET") {
    const paging = listPaging(url);
    const { data, error, count } = await svc.from("event_posts").select("*", {
      count: "exact",
    }).eq(
      "school_id",
      school,
    ).eq("created_by", user.id).order("created_at", {
      ascending: false,
    }).range(paging.from, paging.to);
    if (error) return fail(error.message);
    const rows = await eventPostRows(
      svc,
      (data ?? []) as Record<string, unknown>[],
    );
    return ok(listEnvelope(rows, count, paging.page, paging.pageSize));
  }
  if (!seg && method === "GET") {
    if (
      !["principal", "coordinator", "admin", "super_admin"].includes(
        roleValue(user),
      )
    ) {
      return fail("forbidden", 403);
    }
    const paging = listPaging(url);
    let q = svc.from("event_posts").select("*", { count: "exact" }).eq(
      "school_id",
      school,
    );
    if (url.searchParams.get("status")) {
      q = q.eq("status", url.searchParams.get("status")!);
    }
    const { data, error, count } = await q.order("created_at", {
      ascending: false,
    }).range(paging.from, paging.to);
    if (error) return fail(error.message);
    const rows = await eventPostRows(
      svc,
      (data ?? []) as Record<string, unknown>[],
    );
    return ok(listEnvelope(rows, count, paging.page, paging.pageSize));
  }
  if (!seg && method === "POST") {
    const description = textValue(body.description ?? body.body);
    const destinations = normalizeDestinations(
      body.destinations,
      body.visibility,
    );
    let media = body.media ?? body.media_urls ?? [];
    const mediaError = validateEventMedia(media, destinations);
    if (mediaError) return fail(mediaError, 420);
    const isPrincipal = ["principal", "coordinator"].includes(roleValue(user));
    const directPublish = isPrincipal && body.is_submit === true;
    const publicGalleryVisible = body.public_gallery_visible === true;
    const promotionSeed = textValue(req.headers.get("Idempotency-Key"))
      .replace(/[^a-zA-Z0-9_-]/g, "-").slice(0, 80) || crypto.randomUUID();
    if (directPublish && requiresPublicEventMedia(destinations, publicGalleryVisible)) {
      try {
        media = await promoteEventPostMedia(
          svc,
          school,
          `direct-${promotionSeed}`,
          media,
        );
      } catch (error) {
        return fail(`public media promotion failed: ${error}`, 502);
      }
    }
    const payload = {
      school_id: school,
      title: textValue(body.title, "Untitled event post"),
      body: description,
      media_urls: media,
      visibility: textValue(body.visibility, "school"),
      destinations,
      event_date: body.event_date ?? new Date().toISOString(),
      // Website gallery inclusion is an explicit principal-side selection;
      // app destinations alone must never publish a post publicly.
      public_gallery_visible: publicGalleryVisible,
      // Principal posts are already approved by their publisher. Teacher
      // submissions remain pending so the existing review workflow is intact.
      status: directPublish
        ? "approved"
        : body.is_submit === true
        ? "pending"
        : "draft",
      created_by: user.id,
      ...(directPublish
        ? { approved_by: user.id, approved_at: new Date().toISOString() }
        : {}),
      event_id: body.event_id ?? null,
      rejection_reason: null,
    };
    const { data, error } = await svc.from("event_posts").insert(payload)
      .select().single();
    if (error) return fail(error.message);
    if (body.is_submit === true && !directPublish) {
      try {
        await notifyUsersByRole(svc, school, "principal", {
          title: "Event post pending approval",
          body: `${payload.title} was submitted for review.`,
          type: "pending_approval",
          referenceType: "event_post",
          referenceId: `${data.id ?? ""}`,
        });
        await notifyUsersByRole(svc, school, "coordinator", {
          title: "Event post pending approval",
          body: `${payload.title} was submitted for review.`,
          type: "pending_approval",
          referenceType: "event_post",
          referenceId: `${data.id ?? ""}`,
        });
      } catch {
        // Keep the event post creation successful even if notification fan-out fails.
      }
    }
    return ok((await eventPostRows(svc, [data as Record<string, unknown>]))[0]);
  }
  if (seg && method === "GET") {
    const { data, error } = await svc.from("event_posts").select("*").eq(
      "id",
      seg,
    ).eq("school_id", school).maybeSingle();
    if (error) return fail(error.message);
    if (!data) return fail("not found", 404);
    return ok((await eventPostRows(svc, [data as Record<string, unknown>]))[0]);
  }
  if (seg && method === "PUT") {
    const { data: existing, error: existingError } = await svc.from(
      "event_posts",
    )
      .select("*").eq("id", seg).eq("school_id", school).maybeSingle();
    if (existingError) return fail(existingError.message);
    if (!existing) return fail("not found", 404);
    const userRole = roleValue(user);
    if (
      !["principal", "coordinator"].includes(userRole) &&
      `${existing.created_by ?? ""}` !== user.id
    ) {
      return fail("forbidden", 403);
    }
    const currentStatus = `${existing.status ?? "draft"}`.trim().toLowerCase();
    const description = textValue(
      body.description ?? body.body,
      textValue(existing.description ?? existing.body),
    );
    const destinations = normalizeDestinations(
      body.destinations ?? existing.destinations,
      body.visibility ?? existing.visibility,
    );
    let media = body.media ?? body.media_urls ?? existing.media_urls ?? [];
    const mediaError = validateEventMedia(media, destinations);
    if (mediaError) return fail(mediaError, 420);
    const isPrincipal = ["principal", "coordinator"].includes(userRole);
    const directPublish = isPrincipal && body.is_submit === true;
    const publicGalleryVisible = typeof body.public_gallery_visible === "boolean"
      ? body.public_gallery_visible
      : existing.public_gallery_visible === true;
    let mediaCleanup: string[] = [];
    if (directPublish && requiresPublicEventMedia(destinations, publicGalleryVisible)) {
      try {
        media = await promoteEventPostMedia(svc, school, seg, media);
      } catch (error) {
        return fail(`public media promotion failed: ${error}`, 502);
      }
    } else if (!requiresPublicEventMedia(destinations, publicGalleryVisible)) {
      try {
        const demoted = await demoteEventPostMedia(svc, school, seg, media);
        media = demoted.media;
        mediaCleanup = demoted.cleanup;
      } catch (error) {
        return fail(`private media demotion failed: ${error}`, 502);
      }
    }
    const payload = {
      title: textValue(
        body.title,
        `${existing.title ?? "Untitled event post"}`,
      ),
      body: description,
      media_urls: media,
      visibility: textValue(
        body.visibility,
        textValue(existing.visibility, "school"),
      ),
      destinations,
      event_date: body.event_date ?? existing.event_date ??
        new Date().toISOString(),
      public_gallery_visible: publicGalleryVisible,
      status: directPublish
        ? "approved"
        : body.is_submit === true
        ? "pending"
        : textValue(body.status, currentStatus),
      updated_at: new Date().toISOString(),
      event_id: body.event_id ?? existing.event_id ?? null,
      rejection_reason: body.is_submit === true
        ? null
        : body.rejection_reason ?? existing.rejection_reason ?? null,
      ...(directPublish
        ? { approved_by: user.id, approved_at: new Date().toISOString() }
        : {}),
    };
    const { data, error } = await svc.from("event_posts").update(payload).eq(
      "id",
      seg,
    ).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    await cleanupR2References(svc, mediaCleanup, "event_post_media_demoted");
    if (body.is_submit === true && !directPublish) {
      try {
        await notifyUsersByRole(svc, school, "principal", {
          title: "Event post pending approval",
          body: `${payload.title} was updated and submitted for review.`,
          type: "pending_approval",
          referenceType: "event_post",
          referenceId: `${data.id ?? seg}`,
        });
        await notifyUsersByRole(svc, school, "coordinator", {
          title: "Event post pending approval",
          body: `${payload.title} was updated and submitted for review.`,
          type: "pending_approval",
          referenceType: "event_post",
          referenceId: `${data.id ?? seg}`,
        });
      } catch {
        // Saving the teacher's update remains successful even if the
        // notification fan-out is temporarily unavailable.
      }
    }
    return ok((await eventPostRows(svc, [data as Record<string, unknown>]))[0]);
  }
  if (seg && parts[1] === "approve" && method === "POST") {
    if (!["principal", "coordinator"].includes(roleValue(user))) {
      return fail("forbidden", 403);
    }
    const { data: existing, error: existingError } = await svc.from(
      "event_posts",
    )
      .select("*").eq("id", seg).eq("school_id", school).maybeSingle();
    if (existingError) return fail(existingError.message);
    if (!existing) return fail("not found", 404);
    const destinations = approvedEventDestinations(
      existing.destinations,
      existing.visibility,
    );
    let approvedMedia = existing.media_urls;
    if (requiresPublicEventMedia(
      destinations,
      existing.public_gallery_visible === true,
    )) {
      try {
        approvedMedia = await promoteEventPostMedia(svc, school, seg, approvedMedia);
      } catch (promotionError) {
        return fail(`public media promotion failed: ${promotionError}`, 502);
      }
    }
    const { data, error } = await svc.from("event_posts").update({
      status: "approved",
      destinations,
      media_urls: approvedMedia,
      approved_by: user.id,
      approved_at: new Date().toISOString(),
      rejection_reason: null,
      updated_at: new Date().toISOString(),
    }).eq("id", seg).eq("school_id", school)
      .in("status", ["pending", "submitted"]).select().single();
    if (error) return fail(error.message);
    try {
      await notifyUser(svc, school, `${existing.created_by ?? ""}`, {
        title: "Event post approved",
        body: `${
          existing.title ?? "Your event post"
        } was approved by the principal.`,
        type: "pending_approval",
        referenceType: "event_post",
        referenceId: seg,
      });
    } catch {
      // Approval itself is the source of truth; an individual notification
      // failure must not stop this post from being visible in the gallery.
    }
    // A gallery selection is school-wide. Once approved, alert the other
    // teachers and every parent whose gallery has just gained this post.
    // The post's teacher already receives the more specific approval alert
    // above, so exclude that user from the broad teacher notification.
    if (destinations.includes("SCHOOL_GALLERY")) {
      try {
        const galleryPayload = {
          title: "School gallery updated",
          body: `${
            existing.title ?? "A school event"
          } is now in the school gallery.`,
          type: "gallery_published",
          referenceType: "event_post",
          referenceId: seg,
        };
        await Promise.all([
          notifyUsersByRole(svc, school, "parent", galleryPayload),
          notifyUsersByRole(svc, school, "teacher", {
            ...galleryPayload,
            excludeUserId: `${existing.created_by ?? ""}`,
          }),
        ]);
      } catch {
        // Approval remains successful even if a broad gallery notification
        // fan-out has a transient failure.
      }
    }
    return ok((await eventPostRows(svc, [data as Record<string, unknown>]))[0]);
  }
  if (seg && parts[1] === "reject" && method === "POST") {
    if (!["principal", "coordinator"].includes(roleValue(user))) {
      return fail("forbidden", 403);
    }
    const { data: existing, error: existingError } = await svc.from(
      "event_posts",
    )
      .select("*").eq("id", seg).eq("school_id", school).maybeSingle();
    if (existingError) return fail(existingError.message);
    if (!existing) return fail("not found", 404);
    let rejectedMedia = existing.media_urls;
    let rejectedMediaCleanup: string[] = [];
    if (requiresPublicEventMedia(
      approvedEventDestinations(existing.destinations, existing.visibility),
      existing.public_gallery_visible === true,
    )) {
      try {
        const demoted = await demoteEventPostMedia(svc, school, seg, rejectedMedia);
        rejectedMedia = demoted.media;
        rejectedMediaCleanup = demoted.cleanup;
      } catch (error) {
        return fail(`private media demotion failed: ${error}`, 502);
      }
    }
    const { data, error } = await svc.from("event_posts").update({
      status: "rejected",
      media_urls: rejectedMedia,
      rejection_reason: textValue(body.reason, "Principal requested changes."),
      updated_at: new Date().toISOString(),
    }).eq("id", seg).eq("school_id", school)
      .in("status", ["pending", "submitted"]).select().single();
    if (error) return fail(error.message);
    await cleanupR2References(svc, rejectedMediaCleanup, "event_post_rejected");
    try {
      await notifyUser(svc, school, `${existing.created_by ?? ""}`, {
        title: "Event post rejected",
        body: textValue(body.reason, "Principal requested changes."),
        type: "pending_approval",
        referenceType: "event_post",
        referenceId: seg,
      });
    } catch {
      // Keep the rejection successful even if the notification insert fails.
    }
    return ok((await eventPostRows(svc, [data as Record<string, unknown>]))[0]);
  }
  if (seg && method === "DELETE") {
    const userRole = roleValue(user);
    if (!["principal", "coordinator", "teacher"].includes(userRole)) {
      return fail("forbidden", 403);
    }
    const { data: existing, error: lookupError } = await svc.from("event_posts")
      .select("media_urls, created_by").eq("id", seg).eq("school_id", school)
      .maybeSingle();
    if (lookupError) return fail(lookupError.message);
    if (!existing) return fail("not found", 404);
    if (
      !["principal", "coordinator"].includes(userRole) &&
      `${existing.created_by ?? ""}` !== user.id
    ) {
      return fail("not found", 404);
    }
    let deleteQuery = svc.from("event_posts").delete().eq("id", seg).eq(
      "school_id",
      school,
    );
    if (!["principal", "coordinator"].includes(userRole)) {
      deleteQuery = deleteQuery.eq("created_by", user.id);
    }
    const { error } = await deleteQuery;
    if (error) return fail(error.message);
    await cleanupR2References(
      svc,
      eventPostR2References(existing.media_urls),
      "event_post_deleted",
    );
    return ok({ success: true });
  }
  return fail("not found", 404);
}

export async function handleDocuments(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};
  const url = new URL(req.url);
  if (path === "/student-documents" && method === "GET") {
    const studentId = textValue(url.searchParams.get("student_id"));
    const userRole = roleName(user);
    const managesStudents = canManageStudents(user);
    if (!managesStudents && userRole !== "teacher" && userRole !== "parent") {
      return fail("forbidden", 403);
    }
    let query = svc.from("student_documents").select(
      "*, student:students(id, school_id, first_name, last_name, current_section_id)",
    ).eq("school_id", school);

    if (studentId) {
      if (!(await parentCanAccessStudent(svc, school, user, studentId))) {
        return fail("not found", 404);
      }
      query = query.eq("student_id", studentId);
    } else {
      // Teacher rows are derived from canonical assignments, never from a
      // client-provided section identifier.
      const teacherAssignedSectionIds = userRole === "teacher"
        ? await visibleStudentIds(svc, school, user)
        : null;
      const allowedStudentIds = teacherAssignedSectionIds ??
        await visibleStudentIds(svc, school, user);
      if (allowedStudentIds !== null) {
        if (allowedStudentIds.size === 0) return ok([]);
        query = query.in("student_id", [...allowedStudentIds]);
      }

      const sectionId = textValue(url.searchParams.get("section_id"));
      if (sectionId) {
        const { data: sectionStudents, error: sectionStudentsError } = await svc
          .from("students").select("id").eq("school_id", school).eq(
            "current_section_id",
            sectionId,
          );
        if (sectionStudentsError) return fail(sectionStudentsError.message);
        const sectionStudentIds = (sectionStudents ?? []).map((row) =>
          textValue(row.id)
        ).filter(Boolean);
        const scopedStudentIds = allowedStudentIds === null
          ? sectionStudentIds
          : sectionStudentIds.filter((id) => allowedStudentIds.has(id));
        if (scopedStudentIds.length === 0) return ok([]);
        query = query.in("student_id", scopedStudentIds);
      }
    }

    // Finance receipts are never a Coordinator/Teacher school-wide document
    // capability. Parents may retrieve their own family's receipts through
    // their already-scoped parent links.
    if (!isFinanceLeader(user) && userRole !== "parent") {
      query = query.neq("doc_type", "fee_receipt");
    }

    const { data, error } = await query.order("created_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    const rows = await Promise.all((data ?? []).map(async (row) => ({
      ...row,
      file_url: await signedPrivateFileUrl(svc, row.file_url),
    })));
    return ok(rows);
  }

  if (path === "/student-documents" && method === "POST") {
    const studentId = textValue(body.student_id);
    if (!studentId) return fail("student_id required");
    const userRole = roleName(user);
    const managesStudents = canManageStudents(user);
    if (!managesStudents && userRole !== "parent" && userRole !== "teacher") {
      return fail("forbidden", 403);
    }
    if (!(await parentCanAccessStudent(svc, school, user, studentId))) {
      return fail("not found", 404);
    }
    const docType = textValue(body.doc_type || body.type, "other");
    if (docType.toLowerCase() === "fee_receipt" && !isFinanceLeader(user)) {
      return fail("finance access required", 403);
    }
    const fileUrl = textValue(body.file_url);
    const title = textValue(body.title);
    if (!fileUrl) return fail("file_url required");

    const storedFileUrl = privateFileReferenceFromValue(fileUrl);
    const { data, error } = await svc.from("student_documents").insert({
      student_id: studentId,
      school_id: school,
      doc_type: docType,
      file_url: storedFileUrl,
      title: title,
    }).select().single();
    if (error) return fail(error.message);
    if (managesStudents) {
      try {
        await notifyStudentDocumentParents(
          svc,
          school,
          studentId,
          textValue(data.id),
          title || docType,
        );
      } catch (notificationError) {
        console.error(
          "Failed to notify parent about student document",
          notificationError,
        );
      }
    }
    return ok({
      ...data,
      file_url: await signedPrivateFileUrl(svc, data.file_url),
    });
  }

  const studentDocMatch = path.match(/^\/student-documents\/([^/]+)$/);
  if (studentDocMatch && method === "DELETE") {
    const docId = studentDocMatch[1];
    const userRole = roleName(user);
    const managesStudents = canManageStudents(user);
    if (!managesStudents && userRole !== "parent") {
      return fail("forbidden", 403);
    }
    const { data: doc, error: getErr } = await svc.from("student_documents")
      .select("student_id, doc_type").eq("id", docId).eq(
        "school_id",
        school,
      ).maybeSingle();
    if (getErr) return fail(getErr.message);
    if (!doc || !(await parentCanAccessStudent(svc, school, user, doc.student_id))) {
      return fail("not found", 404);
    }
    if (textValue(doc.doc_type).toLowerCase() === "fee_receipt" &&
      !isFinanceLeader(user)) {
      // fee receipts cannot be deleted by parents; only finance leaders may
      // remove a receipt document after the ownership check above.
      return fail("finance access required", 403);
    }
    const { error } = await svc.from("student_documents").delete().eq(
      "id",
      docId,
    ).eq("school_id", school);
    if (error) return fail(error.message);
    return ok({ success: true });
  }

  if (path === "/staff-documents" && method === "GET") {
    const staffId = textValue(url.searchParams.get("staff_id"));
    if (canUseOwnStaffDocuments(user)) {
      const myStaffId = linkedStaffId(user);
      if (!myStaffId) return fail("user not linked to staff", 400);
      if (staffId && staffId !== myStaffId) return fail("not found", 404);
      const { data, error } = await svc.from("staff_documents").select(
        "*, staff:staff(id, school_id, first_name, last_name)",
      ).eq("school_id", school).eq("staff_id", myStaffId).order("created_at", {
        ascending: false,
      });
      if (error) return fail(error.message);
      return ok(
        await Promise.all((data ?? []).map(async (row) => ({
          ...row,
          file_url: await signedPrivateFileUrl(svc, row.file_url),
        }))),
      );
    } else if (canManageStaff(user)) {
      let query = svc.from("staff_documents").select(
        "*, staff:staff(id, school_id, first_name, last_name)",
      ).eq("school_id", school);
      if (staffId) {
        query = query.eq("staff_id", staffId);
      }
      const { data, error } = await query.order("created_at", {
        ascending: false,
      });
      if (error) return fail(error.message);
      return ok(
        await Promise.all((data ?? []).map(async (row) => ({
          ...row,
          file_url: await signedPrivateFileUrl(svc, row.file_url),
        }))),
      );
    } else {
      return fail("unauthorized", 403);
    }
  }

  if (path === "/staff-documents" && method === "POST") {
    let staffId = textValue(body.staff_id);
    if (canUseOwnStaffDocuments(user)) {
      const myStaffId = linkedStaffId(user);
      if (!myStaffId) return fail("user not linked to staff", 400);
      staffId = myStaffId;
    } else if (!canManageStaff(user)) {
      return fail("forbidden", 403);
    }
    if (!staffId) return fail("staff_id required");
    if (!(await staffExistsInSchool(svc, school, staffId))) {
      return fail("not found", 404);
    }
    const docType = textValue(body.doc_type || body.type, "other");
    const fileUrl = textValue(body.file_url);
    const title = textValue(body.title);
    if (!fileUrl) return fail("file_url required");

    const storedFileUrl = privateFileReferenceFromValue(fileUrl);
    const { data, error } = await svc.from("staff_documents").insert({
      staff_id: staffId,
      school_id: school,
      doc_type: docType,
      file_url: storedFileUrl,
      title: title,
    }).select().single();
    if (error) return fail(error.message);
    return ok({
      ...data,
      file_url: await signedPrivateFileUrl(svc, data.file_url),
    });
  }

  const staffDocMatch = path.match(/^\/staff-documents\/([^/]+)$/);
  if (staffDocMatch && method === "DELETE") {
    const docId = staffDocMatch[1];
    if (!canManageStaff(user) && !canUseOwnStaffDocuments(user)) {
      return fail("forbidden", 403);
    }
    const { data: doc, error: getErr } = await svc.from("staff_documents")
      .select("staff_id").eq("id", docId).eq("school_id", school)
      .maybeSingle();
    if (getErr) return fail(getErr.message);
    if (!doc) return fail("not found", 404);
    if (!canManageStaff(user) && doc.staff_id !== linkedStaffId(user)) {
      return fail("not found", 404);
    }
    const { error } = await svc.from("staff_documents").delete().eq(
      "id",
      docId,
    ).eq("school_id", school);
    if (error) return fail(error.message);
    return ok({ success: true });
  }
  if (path === "/documents/requests" && method === "GET") {
    if (!canManageStudents(user)) return fail("forbidden", 403);
    const paging = listPaging(url);
    const { data, error, count } = await svc.from("frontend_records").select("*", {
      count: "exact",
    }).eq(
      "school_id",
      school,
    ).eq("table_name", "document_requests").order("updated_at", {
      ascending: false,
    }).range(paging.from, paging.to);
    if (error) return fail(error.message);
    return ok(listEnvelope(
      (data ?? []).map((row) => documentRow(row)),
      count,
      paging.page,
      paging.pageSize,
    ));
  }
  if (path === "/documents/requests" && method === "POST") {
    if (!canManageStudents(user)) return fail("forbidden", 403);
    const payload = {
      id: crypto.randomUUID(),
      student_name: textValue(body.student_name, "Student"),
      type: textValue(body.type ?? body.document_type, "Document"),
      status: textValue(body.status, "pending"),
      requested_by: user.id,
      created_at: new Date().toISOString(),
      print_count: 0,
    };
    const { data, error } = await svc.from("frontend_records").insert({
      school_id: school,
      table_name: "document_requests",
      record_id: payload.id,
      data: payload,
    }).select().single();
    if (error) return fail(error.message);
    return ok(documentRow(data));
  }
  const printMatch = path.match(/^\/documents\/requests\/([^/]+)\/prints$/);
  if (printMatch && method === "POST") {
    if (!canManageStudents(user)) return fail("forbidden", 403);
    const { data: existing, error: loadError } = await svc.from(
      "frontend_records",
    ).select("*").eq("school_id", school).eq("table_name", "document_requests")
      .eq("record_id", printMatch[1]).maybeSingle();
    if (loadError) return fail(loadError.message);
    if (!existing) return fail("not found", 404);
    const current = (existing.data as Record<string, unknown> | null) ?? {};
    const next = {
      ...current,
      status: "issued",
      print_count: Number(current.print_count ?? 0) + 1,
      last_print_requested_at: new Date().toISOString(),
    };
    const { data, error } = await svc.from("frontend_records").update({
      data: next,
      updated_at: new Date().toISOString(),
    }).eq("id", existing.id).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(documentRow(data));
  }
  if (path === "/documents/templates" && method === "GET") {
    if (!canManageStudents(user)) return fail("forbidden", 403);
    const paging = listPaging(url);
    const { data, error, count } = await svc.from("frontend_records").select("*", {
      count: "exact",
    }).eq(
      "school_id",
      school,
    ).eq("table_name", "document_templates").order("updated_at", {
      ascending: false,
    }).range(paging.from, paging.to);
    if (error) return fail(error.message);
    return ok(listEnvelope(
      (data ?? []).map((row) => documentRow(row)),
      count,
      paging.page,
      paging.pageSize,
    ));
  }
  if (path === "/documents/templates" && method === "POST") {
    if (!canManageStudents(user)) return fail("forbidden", 403);
    const payload = {
      id: crypto.randomUUID(),
      name: textValue(body.name, "Template"),
      document_type: textValue(body.document_type, "Document"),
      body: textValue(body.body),
      status: textValue(body.status, "active"),
      created_by: user.id,
      created_at: new Date().toISOString(),
    };
    const { data, error } = await svc.from("frontend_records").insert({
      school_id: school,
      table_name: "document_templates",
      record_id: payload.id,
      data: payload,
    }).select().single();
    if (error) return fail(error.message);
    return ok(documentRow(data));
  }
  return fail("not found", 404);
}

// handlers/parent.ts — parent access to their children
export async function handleParent(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  if (path === "/me/students" && method === "GET") {
    const { data, error } = await svc.from("parent_student_links").select(
      "student:students(*, section:sections(*, grade:grades(*)), enrollments(*))",
    ).eq("school_id", school).eq("parent_user_id", user.id);
    if (error) return fail(error.message);
    return ok((data ?? []).map((l: Record<string, unknown>) => l.student));
  }
  const parentMatch = path.match(/^\/parents\/([^/]+)\/students$/);
  if (parentMatch && method === "GET") {
    const parentUserId = parentMatch[1];
    const canManageParentLinks = [
      "principal",
      "coordinator",
      "admin",
      "super_admin",
    ].includes(
      roleValue(user),
    );
    if (!canManageParentLinks && parentUserId !== user.id) {
      return fail("forbidden", 403);
    }
    const { data, error } = await svc.from("parent_student_links").select(
      "student_id, student:students(id, admission_number, student_code:student_id_number, first_name, last_name)",
    ).eq("school_id", school).eq("parent_user_id", parentUserId);
    if (error) return fail(error.message);
    return ok(
      (data ?? []).map((link: Record<string, unknown>) => {
        const student = (link.student ?? {}) as Record<string, unknown>;
        return {
          ...student,
          student_id: textValue(link.student_id ?? student.id),
          student_admission_number: textValue(
            student.admission_number ?? student.student_code,
          ),
          student_first_name: textValue(student.first_name),
          student_last_name: textValue(student.last_name),
        };
      }).filter((student: Record<string, unknown>) =>
        textValue(student.student_id)
      ),
    );
  }
  if (parentMatch && method === "POST") {
    if (
      !["principal", "coordinator", "admin", "super_admin"].includes(
        roleValue(user),
      )
    ) {
      return fail("forbidden", 403);
    }
    const { data: parentAccount, error: parentError } = await svc.from("users")
      .select("id, role_name, school_id")
      .eq("id", parentMatch[1])
      .eq("school_id", school)
      .ilike("role_name", "parent")
      .eq("is_active", true)
      .maybeSingle();
    if (parentError) return fail(parentError.message);
    if (!parentAccount) return fail("parent account not found", 404);
    const body = await req.json().catch(() => ({}));
    const studentIds = Array.isArray(body.student_ids)
      ? body.student_ids.map((value: unknown) => `${value ?? ""}`.trim())
        .filter(Boolean)
      : [];
    const admissionNumbers = Array.isArray(body.admission_numbers)
      ? body.admission_numbers.map((value: unknown) => `${value ?? ""}`.trim())
        .filter(Boolean)
      : [];

    let resolvedStudentIds = [...studentIds];
    if (admissionNumbers.length > 0) {
      const { data: studentsByAdmission, error } = await svc.from("students")
        .select("id, admission_number").eq("school_id", school).in(
          "admission_number",
          admissionNumbers,
        );
      if (error) return fail(error.message);
      resolvedStudentIds.push(
        ...((studentsByAdmission ?? []).map((row: Record<string, unknown>) =>
          `${row.id ?? ""}`.trim()
        ).filter(Boolean)),
      );
    }

    resolvedStudentIds = [...new Set(resolvedStudentIds)];
    if (resolvedStudentIds.length === 0) {
      return fail("student_ids or admission_numbers required");
    }

    // Resolve every explicit ID inside this school before changing links. An
    // invalid or cross-tenant ID is never allowed to create a dangling link.
    const { data: ownedStudents, error: ownedStudentsError } = await svc.from(
      "students",
    ).select("id").eq("school_id", school).in("id", resolvedStudentIds);
    if (ownedStudentsError) return fail(ownedStudentsError.message);
    const ownedIds = new Set(
      (ownedStudents ?? []).map((row: Record<string, unknown>) =>
        textValue(row.id)
      ).filter(Boolean),
    );
    if (ownedIds.size !== resolvedStudentIds.length) {
      return fail("one or more students were not found", 404);
    }

    const { data: existingLinks, error: existingLinksError } = await svc.from(
      "parent_student_links",
    ).select("student_id, parent_user_id").eq("school_id", school).in(
      "student_id",
      resolvedStudentIds,
    );
    if (existingLinksError) return fail(existingLinksError.message);
    const conflictingStudent = (existingLinks ?? []).find(
      (link: Record<string, unknown>) =>
        textValue(link.parent_user_id) !== parentMatch[1],
    );
    if (conflictingStudent) {
      return fail(
        "one or more students are already linked to another parent",
        409,
      );
    }

    const rows = resolvedStudentIds.map((studentId) => ({
      school_id: school,
      parent_user_id: parentMatch[1],
      student_id: studentId,
    }));
    // A student can have only one parent login. Reassigning through this
    // endpoint replaces the old link, while the same parent may own many rows.
    const { error: clearError } = await svc.from("parent_student_links").delete()
      .eq("school_id", school).in("student_id", resolvedStudentIds);
    if (clearError) return fail(clearError.message);
    const { data, error } = await svc.from("parent_student_links").upsert(
      rows,
      {
        onConflict: "student_id",
      },
    ).select();
    if (error) return fail(error.message);
    return ok({ links: data ?? [], student_ids: resolvedStudentIds });
  }
  return fail("not found", 404);
}

// handlers/reports.ts — non-exam reports
export async function handleReports(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  if (path === "/reports/exports" && method === "POST") {
    if (!canManageStudents(user)) {
      return fail("leadership access required", 403);
    }
    try {
      const body = await req.json().catch(() => ({}));
      const data = await queueReportExport(
        svc,
        school,
        user,
        "report_exports",
        body,
      );
      return ok(data);
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "failed to queue report export",
      );
    }
  }
  if (path === "/reports/exports" && method === "GET") {
    if (!canManageStudents(user)) {
      return fail("leadership access required", 403);
    }
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "report_exports").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    return ok((data ?? []).map((row) => documentRow(row)));
  }
  if (path === "/reports/attendance" && method === "GET") {
    if (!canManageStudents(user)) {
      return fail("leadership access required", 403);
    }
    const { data, error } = await svc.from("attendance_summaries").select(
      "*, student:students(first_name, last_name, admission_number, current_section_id)",
    ).eq("school_id", school);
    if (error) return fail(error.message);
    return ok(data);
  }
  if (path === "/reports/fees" && method === "GET") {
    if (!isFinanceLeader(user)) {
      return fail("finance access required", 403);
    }
    const { data, error } = await svc.from("fee_invoices").select(
      "*, student:students(first_name, last_name, admission_number)",
    ).eq("school_id", school).order("invoice_date", { ascending: false });
    if (error) return fail(error.message);
    return ok(data);
  }
  if (path === "/reports/staff" && method === "GET") {
    if (!canManageStaff(user)) {
      return fail("leadership access required", 403);
    }
    const { data, error } = await svc.from("staff").select(
      "*, department:departments(department_name), staff_subjects(*, subject:subjects(*))",
    ).eq("school_id", school);
    if (error) return fail(error.message);
    return ok(data);
  }
  return fail("not found", 404);
}

// Public (no-auth) endpoint — serves approved SCHOOL_LANDING posts for the
// pre-login carousel.  Requires ?school_id=<uuid> query param.
export async function handleLandingFeed(
  _req: Request,
  url: URL,
  svc: SupabaseClient,
): Promise<Response> {
  const schoolId = url.searchParams.get("school_id")?.trim() ?? "";
  if (!schoolId) return fail("school_id is required", 400);

  const { data, error } = await svc.from("event_posts")
    .select(
      "id, title, body, media_urls, event_date, created_at, destinations, visibility",
    )
    .eq("school_id", schoolId)
    .in("status", ["approved", "published"])
    .contains("destinations", JSON.stringify(["SCHOOL_LANDING"]))
    .order("created_at", { ascending: false })
    .limit(10);

  if (error) return fail(error.message);

  const rows = await Promise.all((data ?? []).map((row) =>
    eventPostResponse(svc, row as Record<string, unknown>, true)
  ));

  return ok(rows);
}

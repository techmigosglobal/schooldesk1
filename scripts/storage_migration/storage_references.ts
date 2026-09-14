/**
 * Canonical legacy-storage reference handling shared by the rewrite and
 * cleanup commands. This module is intentionally pure so it can be tested
 * without production database or object-storage credentials.
 */

export type StorageLocation = {
  bucket: string;
  key: string;
};

export type MigrationMapEntry = {
  sourceBucket: string;
  sourceKey: string;
  destinationBucket: string;
  destinationKey: string;
  visibility: "private" | "public";
  status: string;
};

export type ReferenceTarget = {
  table: string;
  column: string;
  rowIdColumn: string;
  defaultBucket?: string;
  json: boolean;
};

export type RewriteChange = {
  path: string;
  source: string;
  target: string;
  location: StorageLocation;
};

export const REFERENCE_TARGETS: readonly ReferenceTarget[] = [
  { table: "announcements", column: "attachments", rowIdColumn: "id", defaultBucket: "school-assets", json: true },
  { table: "bulk_import_jobs", column: "file_url", rowIdColumn: "id", defaultBucket: "school-assets", json: false },
  { table: "event_posts", column: "media_urls", rowIdColumn: "id", defaultBucket: "school-assets", json: true },
  { table: "finance_document_snapshots", column: "storage_path", rowIdColumn: "id", defaultBucket: "finance-documents", json: false },
  { table: "finance_document_snapshots", column: "source_snapshot", rowIdColumn: "id", defaultBucket: "finance-documents", json: true },
  { table: "frontend_records", column: "data", rowIdColumn: "id", json: true },
  { table: "help_contents", column: "video_url", rowIdColumn: "id", defaultBucket: "help-tutorial-videos", json: false },
  { table: "help_contents", column: "video_path", rowIdColumn: "id", defaultBucket: "help-tutorial-videos", json: false },
  { table: "homework_submissions", column: "file_urls", rowIdColumn: "id", defaultBucket: "school-assets", json: true },
  { table: "issue_attachments", column: "storage_path", rowIdColumn: "id", defaultBucket: "issue-attachments", json: false },
  { table: "leave_applications", column: "attachment_urls", rowIdColumn: "id", defaultBucket: "school-assets", json: true },
  { table: "messages", column: "attachments", rowIdColumn: "id", defaultBucket: "school-assets", json: true },
  { table: "messages", column: "attachment_url", rowIdColumn: "id", defaultBucket: "school-assets", json: false },
  { table: "parent_payment_requests", column: "proof_url", rowIdColumn: "id", defaultBucket: "payment-proofs", json: false },
  { table: "school_finance_settings", column: "signature_path", rowIdColumn: "school_id", defaultBucket: "school-signatures", json: false },
  { table: "school_finance_settings", column: "seal_path", rowIdColumn: "school_id", defaultBucket: "school-signatures", json: false },
  { table: "school_website_entries", column: "image_url", rowIdColumn: "id", defaultBucket: "school-public-media", json: false },
  { table: "school_website_entries", column: "metadata", rowIdColumn: "id", defaultBucket: "school-public-media", json: true },
  { table: "school_website_gallery_items", column: "media_path", rowIdColumn: "id", defaultBucket: "school-public-media", json: false },
  { table: "school_website_sections", column: "image_url", rowIdColumn: "id", defaultBucket: "school-public-media", json: false },
  { table: "schools", column: "logo_url", rowIdColumn: "id", defaultBucket: "school-assets", json: false },
  { table: "schools", column: "authorized_signature_path", rowIdColumn: "id", defaultBucket: "school-signatures", json: false },
  { table: "staff", column: "photo_url", rowIdColumn: "id", defaultBucket: "school-assets", json: false },
  { table: "staff_documents", column: "file_url", rowIdColumn: "id", defaultBucket: "school-assets", json: false },
  { table: "student_documents", column: "file_url", rowIdColumn: "id", defaultBucket: "school-assets", json: false },
  { table: "students", column: "photo_url", rowIdColumn: "id", defaultBucket: "school-assets", json: false },
  { table: "uploaded_files", column: "url", rowIdColumn: "id", defaultBucket: "school-assets", json: false },
  { table: "uploaded_files", column: "path", rowIdColumn: "id", defaultBucket: "school-assets", json: false },
  { table: "users", column: "avatar", rowIdColumn: "id", defaultBucket: "school-assets", json: false },
];

const KNOWN_BUCKETS = new Set([
  "school-assets",
  "school-private-files",
  "finance-documents",
  "payment-proofs",
  "issue-attachments",
  "help-tutorial-videos",
  "school-signatures",
  "school-public-media",
]);

const MIME_TYPE_PREFIXES = new Set([
  "application",
  "audio",
  "font",
  "image",
  "message",
  "model",
  "multipart",
  "text",
  "video",
]);

const STORAGE_KEY_PREFIXES = new Set([
  "avatars",
  "documents",
  "exports",
  "gallery",
  "health",
  "homework",
  "issues",
  "logos",
  "payment-config",
  "payment-proofs",
  "reports",
  "signatures",
  "students",
  "uploads",
  "website",
]);

function decodePath(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

function cleanKey(value: string): string {
  // Older Supabase URLs can contain repeated separators before the filename,
  // while Storage metadata canonicalizes the object name to one separator.
  return decodePath(value).replace(/^\/+/, "").replace(/\/{2,}/g, "/").trim();
}

function isMimeType(value: string): boolean {
  const slash = value.indexOf("/");
  if (slash < 1 || slash === value.length - 1) return false;
  return MIME_TYPE_PREFIXES.has(value.slice(0, slash).toLowerCase()) &&
    !value.slice(slash + 1).includes("/");
}

function isLikelyStorageKey(value: string): boolean {
  const firstSegment = value.slice(0, value.indexOf("/")).toLowerCase();
  return STORAGE_KEY_PREFIXES.has(firstSegment);
}

function inferredBucketForJsonKey(key: string, fallback: string): string {
  const normalized = key.toLowerCase();
  if (normalized.includes("signature") || normalized.includes("seal")) {
    return "school-signatures";
  }
  if (normalized.includes("proof")) return "payment-proofs";
  if (normalized.includes("issue")) return "issue-attachments";
  if (normalized.includes("video")) return "help-tutorial-videos";
  if (normalized.includes("website") || normalized.includes("gallery")) {
    return "school-public-media";
  }
  return fallback;
}

/** Extracts a Supabase Storage bucket/key from a legacy URL or path. */
export function legacyStorageLocation(
  value: unknown,
  defaultBucket = "",
): StorageLocation | null {
  const raw = `${value ?? ""}`.trim();
  if (!raw || raw.startsWith("r2://")) return null;

  if (/^https?:\/\//i.test(raw)) {
    try {
      const url = new URL(raw);
      const marker = "/storage/v1/object/";
      const markerIndex = url.pathname.indexOf(marker);
      if (markerIndex < 0) return null;
      const rest = url.pathname.slice(markerIndex + marker.length)
        .replace(/^public\//, "")
        .replace(/^sign\//, "")
        .replace(/^authenticated\//, "");
      const slash = rest.indexOf("/");
      if (slash < 1) return null;
      const bucket = decodePath(rest.slice(0, slash));
      const key = cleanKey(rest.slice(slash + 1));
      return KNOWN_BUCKETS.has(bucket) && key ? { bucket, key } : null;
    } catch {
      return null;
    }
  }

  const withoutLeadingSlash = raw.replace(/^\/+/, "");
  const slash = withoutLeadingSlash.indexOf("/");
  if (slash > 0) {
    const prefix = withoutLeadingSlash.slice(0, slash);
    if (KNOWN_BUCKETS.has(prefix)) {
      const key = cleanKey(withoutLeadingSlash.slice(slash + 1));
      return key ? { bucket: prefix, key } : null;
    }
  }

  if (
    defaultBucket && KNOWN_BUCKETS.has(defaultBucket) &&
    !/^([a-z]+:)?\/\//i.test(withoutLeadingSlash) &&
    withoutLeadingSlash.includes("/") &&
    !isMimeType(withoutLeadingSlash) &&
    isLikelyStorageKey(withoutLeadingSlash)
  ) {
    const key = cleanKey(withoutLeadingSlash);
    return key ? { bucket: defaultBucket, key } : null;
  }
  return null;
}

export function r2ReferenceFor(
  location: StorageLocation,
  mapping: ReadonlyMap<string, MigrationMapEntry>,
): string | null {
  const item = mapping.get(`${location.bucket}\n${location.key}`);
  if (!item || item.status !== "verified") return null;
  return `r2://${item.visibility}/${item.destinationKey}`;
}

export function rewriteString(
  value: string,
  mapping: ReadonlyMap<string, MigrationMapEntry>,
  defaultBucket = "",
  path = "$",
): { value: string; changes: RewriteChange[]; unresolved: StorageLocation[] } {
  const rewriteSingle = (candidate: string, candidatePath: string) => {
    const location = legacyStorageLocation(candidate, defaultBucket);
    if (!location) {
      return { value: candidate, changes: [], unresolved: [] };
    }
    const target = r2ReferenceFor(location, mapping);
    if (!target) {
      return { value: candidate, changes: [], unresolved: [location] };
    }
    return {
      value: target,
      changes: [{ path: candidatePath, source: candidate, target, location }],
      unresolved: [],
    };
  };

  const direct = rewriteSingle(value, path);
  if (direct.changes.length || (!value.includes(",") && direct.unresolved.length) || !value.includes(",")) {
    return direct;
  }

  // A legacy frontend export stored several URLs in one comma-separated
  // string. Rewrite each member while preserving the original separators.
  const parts = value.split(",");
  const changes: RewriteChange[] = [];
  const unresolved: StorageLocation[] = [];
  const next = parts.map((part, index) => {
    const leading = part.match(/^\s*/)?.[0] ?? "";
    const trailing = part.match(/\s*$/)?.[0] ?? "";
    const trimmed = part.trim();
    const result = rewriteSingle(trimmed, `${path}[${index}]`);
    changes.push(...result.changes);
    unresolved.push(...result.unresolved);
    return `${leading}${result.value}${trailing}`;
  }).join(",");
  return { value: changes.length ? next : value, changes, unresolved };
}

export function rewriteJson(
  value: unknown,
  mapping: ReadonlyMap<string, MigrationMapEntry>,
  defaultBucket = "",
  path = "$",
): { value: unknown; changes: RewriteChange[]; unresolved: StorageLocation[] } {
  if (typeof value === "string") {
    return rewriteString(value, mapping, defaultBucket, path);
  }
  if (Array.isArray(value)) {
    const changes: RewriteChange[] = [];
    const unresolved: StorageLocation[] = [];
    const next = value.map((item, index) => {
      const result = rewriteJson(item, mapping, defaultBucket, `${path}[${index}]`);
      changes.push(...result.changes);
      unresolved.push(...result.unresolved);
      return result.value;
    });
    return { value: next, changes, unresolved };
  }
  if (value && typeof value === "object") {
    const changes: RewriteChange[] = [];
    const unresolved: StorageLocation[] = [];
    const next: Record<string, unknown> = {};
    for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
      const result = rewriteJson(
        item,
        mapping,
        inferredBucketForJsonKey(key, defaultBucket),
        `${path}.${key}`,
      );
      changes.push(...result.changes);
      unresolved.push(...result.unresolved);
      next[key] = result.value;
    }
    return { value: next, changes, unresolved };
  }
  return { value, changes: [], unresolved: [] };
}

export function referenceKey(location: StorageLocation): string {
  return `${location.bucket}\n${location.key}`;
}

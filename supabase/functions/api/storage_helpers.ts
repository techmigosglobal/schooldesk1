import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  r2FileReference,
  r2Reference,
  r2KeyFromValue,
  r2ReferenceInfo,
  r2VisibilityFromValue,
  headR2File,
  legacyR2Reference,
  legacyStorageReadsEnabled,
  storageReadOrder,
  signedR2FileUrl,
} from "./lib/r2_storage.ts";

export const PRIVATE_FILES_BUCKET = "school-private-files";
export const PRIVATE_FILE_URL_TTL_SECONDS = 10 * 60;

export function storagePathFromValue(value: unknown, bucket: string): string {
  const raw = `${value ?? ""}`.trim();
  if (!raw) return "";
  if (!raw.startsWith("http://") && !raw.startsWith("https://")) {
    return raw.startsWith(`${bucket}/`) ? raw.slice(bucket.length + 1) : raw;
  }
  try {
    const url = new URL(raw);
    const marker = "/storage/v1/object/";
    const markerIndex = url.pathname.indexOf(marker);
    if (markerIndex < 0) return "";
    const rest = url.pathname.slice(markerIndex + marker.length)
      .replace(/^public\//, "")
      .replace(/^sign\//, "")
      .replace(/^authenticated\//, "");
    const slash = rest.indexOf("/");
    if (slash < 1 || rest.slice(0, slash) !== bucket) return "";
    return decodeURIComponent(rest.slice(slash + 1));
  } catch {
    return "";
  }
}

type StorageLocation = {
  bucket: string;
  path: string;
};

const LEGACY_STORAGE_BUCKETS = new Set([
  "school-assets",
  "school-private-files",
  "finance-documents",
  "payment-proofs",
  "issue-attachments",
  "help-tutorial-videos",
  "school-signatures",
  "school-public-media",
]);

/**
 * Resolve a legacy Storage URL to its bucket and object path in the current
 * Supabase project. The hostname is deliberately ignored: restored rows can
 * still contain the source project URL, but the bucket/path remains the
 * durable identifier and is resolved through the target Storage API.
 */
function storageLocationFromValue(
  value: unknown,
  fallbackBucket: string,
): StorageLocation | null {
  const raw = `${value ?? ""}`.trim();
  if (!raw || raw.startsWith("r2://")) return null;

  if (/^https?:\/\//i.test(raw)) {
    try {
      const url = new URL(raw);
      const marker = "/storage/v1/object/";
      const markerIndex = url.pathname.indexOf(marker);
      if (markerIndex < 0) return null;
      const rest = decodeURIComponent(
        url.pathname.slice(markerIndex + marker.length)
          .replace(/^public\//, "")
          .replace(/^sign\//, "")
          .replace(/^authenticated\//, ""),
      );
      const slash = rest.indexOf("/");
      if (slash < 1) return null;
      const candidateBucket = rest.slice(0, slash);
      const path = rest.slice(slash + 1).replace(/\/{2,}/g, "/").trim();
      return LEGACY_STORAGE_BUCKETS.has(candidateBucket) && path
        ? { bucket: candidateBucket, path }
        : null;
    } catch {
      return null;
    }
  }

  const normalized = raw.replace(/^\/+/, "");
  const slash = normalized.indexOf("/");
  if (slash > 0) {
    const candidateBucket = normalized.slice(0, slash);
    const path = normalized.slice(slash + 1).replace(/\/{2,}/g, "/").trim();
    if (LEGACY_STORAGE_BUCKETS.has(candidateBucket) && path) {
      return { bucket: candidateBucket, path };
    }
  }

  return fallbackBucket && normalized
    ? { bucket: fallbackBucket, path: normalized }
    : null;
}

export function privateFileReference(path: string): string {
  return `${PRIVATE_FILES_BUCKET}/${path}`;
}

export function privateFileReferenceFromValue(value: unknown): string {
  const r2Key = r2KeyFromValue(value);
  if (r2Key && r2VisibilityFromValue(value) === "private") {
    return r2FileReference(r2Key);
  }
  const path = storagePathFromValue(value, PRIVATE_FILES_BUCKET);
  return path ? privateFileReference(path) : `${value ?? ""}`.trim();
}

/** Converts an R2 URL/signature back to the durable reference for DB writes. */
export function stableStorageReference(value: unknown): string {
  const info = r2ReferenceInfo(value);
  return info ? r2Reference(info.key, info.visibility) : `${value ?? ""}`.trim();
}

export async function signedPrivateFileUrl(
  svc: SupabaseClient,
  value: unknown,
  ttlSeconds = PRIVATE_FILE_URL_TTL_SECONDS,
  bucket = PRIVATE_FILES_BUCKET,
): Promise<string> {
  const explicitR2Reference = r2KeyFromValue(value) ? `${value}`.trim() : "";
  const legacyReference = explicitR2Reference
    ? ""
    : legacyR2Reference(value, bucket) ?? "";
  const r2Value = explicitR2Reference || legacyReference;
  const r2Key = r2KeyFromValue(r2Value);
  for (const provider of storageReadOrder()) {
    if (provider === "r2" && r2Key) {
      // A legacy URL can be deterministically mapped to R2, but the copy may
      // be missing. Probe only derived references so a missing copy can still
      // fall through to the legacy provider during the staged cutover.
      if (legacyReference) {
        try {
          if (!(await headR2File(r2Value))) continue;
        } catch {
          continue;
        }
      }
      const r2Url = await signedR2FileUrl(r2Value, ttlSeconds);
      if (r2Url) return r2Url;
      continue;
    }
    if (provider !== "supabase" || !legacyStorageReadsEnabled()) continue;
    const location = storageLocationFromValue(value, bucket);
    if (!location) {
      if (!r2Key) return `${value ?? ""}`.trim();
      continue;
    }
    const { data, error } = await svc.storage.from(location.bucket)
      .createSignedUrl(location.path, ttlSeconds);
    if (!error && data?.signedUrl) return data.signedUrl;
  }
  return "";
}

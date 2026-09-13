import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  r2FileReference,
  r2Reference,
  r2KeyFromValue,
  r2ReferenceInfo,
  r2VisibilityFromValue,
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
  const r2Key = r2KeyFromValue(value);
  for (const provider of storageReadOrder()) {
    if (provider === "r2" && r2Key) {
      const r2Url = await signedR2FileUrl(value, ttlSeconds);
      if (r2Url) return r2Url;
      continue;
    }
    if (provider !== "supabase" || !legacyStorageReadsEnabled()) continue;
    const path = storagePathFromValue(value, bucket);
    if (!path) {
      if (!r2Key) return `${value ?? ""}`.trim();
      continue;
    }
    const { data, error } = await svc.storage.from(bucket)
      .createSignedUrl(path, ttlSeconds);
    if (!error && data?.signedUrl) return data.signedUrl;
  }
  return "";
}

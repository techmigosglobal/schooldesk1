import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

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

export async function signedPrivateFileUrl(
  svc: SupabaseClient,
  value: unknown,
  ttlSeconds = PRIVATE_FILE_URL_TTL_SECONDS,
): Promise<string> {
  const path = storagePathFromValue(value, PRIVATE_FILES_BUCKET);
  if (!path) return `${value ?? ""}`.trim();
  const { data, error } = await svc.storage.from(PRIVATE_FILES_BUCKET)
    .createSignedUrl(path, ttlSeconds);
  if (error || !data?.signedUrl) return "";
  return data.signedUrl;
}

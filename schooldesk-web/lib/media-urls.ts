/** Only translate the deployment's Docker gateway; never rewrite arbitrary hosts. */
export function publicMediaUrl(value: string, publicApiOrigin: string): string {
  try {
    const url = new URL(value);
    if (url.hostname !== "supabase-kong" || url.port !== "8000") return value;
    const origin = new URL(publicApiOrigin);
    url.protocol = origin.protocol;
    url.host = origin.host;
    url.port = origin.port;
    return url.toString();
  } catch { return value; }
}

export function normalizeMediaUrls<T>(value: T, publicApiOrigin: string): T {
  if (typeof value === "string") return publicMediaUrl(value, publicApiOrigin) as T;
  if (Array.isArray(value)) return value.map((item) => normalizeMediaUrls(item, publicApiOrigin)) as T;
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, normalizeMediaUrls(item, publicApiOrigin)])) as T;
  }
  return value;
}

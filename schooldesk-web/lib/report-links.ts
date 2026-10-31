export type ReportLinkState = "ready" | "expired" | "legacy" | "missing";

export function reportLinkState(value: unknown, now = Date.now()): ReportLinkState {
  if (typeof value !== "string" || !value) return "missing";
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" && url.hostname !== "localhost" && url.hostname !== "127.0.0.1") return "missing";
    if (url.hostname.endsWith(".supabase.co")) return "legacy";
    const token = url.searchParams.get("token");
    if (token) {
      const encoded = token.split(".")[1]?.replaceAll("-", "+").replaceAll("_", "/");
      if (encoded) {
        const payload = JSON.parse(atob(encoded));
        if (typeof payload.exp === "number" && payload.exp * 1000 <= now + 30_000) return "expired";
      }
    }
    return "ready";
  } catch { return "missing"; }
}

export function reportDownloadPath(id: string, finance: boolean) {
  return `/api/reports/download?kind=${finance ? "finance" : "academic"}&id=${encodeURIComponent(id)}`;
}

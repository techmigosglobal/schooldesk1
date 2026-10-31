import { backendFetch, unwrap } from "@/lib/backend";

export type RefreshedSession = { access_token: string; refresh_token: string };
const refreshing = new Map<string, Promise<RefreshedSession | null>>();

/** Share refresh-token rotation across parallel web requests in this runtime. */
export function refreshSession(token: string): Promise<RefreshedSession | null> {
  const existing = refreshing.get(token);
  if (existing) return existing;
  const pending = (async () => {
    try {
      const response = await backendFetch("auth/refresh", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: token }),
      });
      if (!response.ok) return null;
      const session = unwrap<RefreshedSession>(await response.json());
      return session.access_token && session.refresh_token ? session : null;
    } catch { return null; }
  })();
  refreshing.set(token, pending);
  void pending.finally(() => {
    const timer = setTimeout(() => refreshing.delete(token), 5000);
    timer.unref?.();
  });
  return pending;
}

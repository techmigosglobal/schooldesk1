/**
 * In-memory sliding-window rate limiter, keyed by arbitrary string (e.g. IP).
 *
 * For single-process / single-instance deployments only.
 * Upgrade to Upstash Redis for edge or multi-instance production use.
 */

interface WindowEntry {
  count: number;
  windowStart: number;
}

const store = new Map<string, WindowEntry>();

/** Remove entries whose window has already expired to prevent unbounded growth. */
function pruneExpiredEntries(windowMs: number) {
  const now = Date.now();
  for (const [key, entry] of store) {
    if (now - entry.windowStart >= windowMs) {
      store.delete(key);
    }
  }
}

/**
 * Returns true if the request is within the allowed limit.
 * Returns false if the limit has been exceeded (should respond 429).
 *
 * @param key      Unique identifier for the requester, e.g. IP address.
 * @param limit    Maximum allowed requests per window (default: 10).
 * @param windowMs Window size in milliseconds (default: 60000 = 1 minute).
 */
export function checkRateLimit(
  key: string,
  limit = 10,
  windowMs = 60_000,
): boolean {
  if (Math.random() < 0.01) pruneExpiredEntries(windowMs);

  const now = Date.now();
  const entry = store.get(key);

  if (!entry || now - entry.windowStart >= windowMs) {
    store.set(key, { count: 1, windowStart: now });
    return true;
  }

  if (entry.count >= limit) {
    return false;
  }

  entry.count += 1;
  return true;
}

/**
 * Returns the number of seconds remaining in the current window for the given key.
 * Useful for setting a Retry-After header.
 */
export function retryAfterSeconds(key: string, windowMs = 60_000): number {
  const entry = store.get(key);
  if (!entry) return 0;
  const elapsed = Date.now() - entry.windowStart;
  return Math.max(0, Math.ceil((windowMs - elapsed) / 1000));
}

/** Named limits are the single integration surface for API routes. */
export const RATE_LIMIT_POLICIES = {
  login: { limit: 10, windowSeconds: 60, subject: "ip" },
  public: { limit: 10, windowSeconds: 60, subject: "ip" },
  authenticatedRead: { limit: 240, windowSeconds: 60, subject: "user" },
  authenticatedWrite: { limit: 60, windowSeconds: 60, subject: "user" },
  sensitiveAccount: { limit: 10, windowSeconds: 60, subject: "user" },
} as const;

export type RateLimitPolicy = keyof typeof RATE_LIMIT_POLICIES;
type RateLimitSubjectKind = "ip" | "user";

export type RateLimitSubject = {
  ip?: string | null;
  userId?: string | null;
};

export type RateLimitDecision = {
  allowed: boolean;
  policy: RateLimitPolicy;
  limit: number;
  remaining: number;
  resetAt: string;
  retryAfterSeconds: number;
};

export type RateLimitOptions = {
  /**
   * Optional only to make the helper testable. Production uses a dedicated
   * secret when present and otherwise salts identifiers with the service key.
   */
  keySecret?: string;
};

export type RateLimitRpcClient = {
  rpc: (
    functionName: string,
    args: Record<string, unknown>,
  ) => PromiseLike<{
    data: unknown;
    error: { message?: string } | null;
  }>;
};
type RpcRow = Record<string, unknown>;

export class RateLimitBackendError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RateLimitBackendError";
  }
}

function valueFor(
  kind: RateLimitSubjectKind,
  subject: RateLimitSubject,
): string {
  const value = kind === "ip" ? subject.ip : subject.userId;
  const normalized = `${value ?? ""}`.trim().toLowerCase();
  if (!normalized || normalized.length > 512) {
    // Do not include an identifier in an error: it could be an IP address.
    throw new RateLimitBackendError("missing or invalid rate limit subject");
  }
  return normalized;
}

function keySecret(options: RateLimitOptions): string {
  const secret = options.keySecret ??
    Deno.env.get("RATE_LIMIT_KEY_SECRET") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!secret) {
    throw new RateLimitBackendError("rate limit key secret is not configured");
  }
  return secret;
}

function hex(bytes: ArrayBuffer): string {
  return [...new Uint8Array(bytes)].map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}

/**
 * Creates a non-reversible database key. The database never stores raw user
 * IDs or client IP addresses in rate-limit counter rows.
 */
export async function rateLimitBucketKey(
  policy: RateLimitPolicy,
  subject: RateLimitSubject,
  options: RateLimitOptions = {},
): Promise<string> {
  const definition = RATE_LIMIT_POLICIES[policy];
  const value = valueFor(definition.subject, subject);
  const material = new TextEncoder().encode(
    `${keySecret(options)}\u0000${definition.subject}\u0000${value}`,
  );
  const digest = await crypto.subtle.digest("SHA-256", material);
  return `rl:${policy}:${hex(digest)}`;
}

function asRow(data: unknown): RpcRow {
  const row = Array.isArray(data) ? data[0] : data;
  if (!row || typeof row !== "object" || Array.isArray(row)) {
    throw new RateLimitBackendError("rate limit RPC returned no result");
  }
  return row as RpcRow;
}

function asInteger(value: unknown, name: string): number {
  const number = typeof value === "number" ? value : Number(value);
  if (!Number.isSafeInteger(number)) {
    throw new RateLimitBackendError(`rate limit RPC returned invalid ${name}`);
  }
  return number;
}

function asResetAt(value: unknown): string {
  if (typeof value !== "string" || Number.isNaN(Date.parse(value))) {
    throw new RateLimitBackendError("rate limit RPC returned invalid reset time");
  }
  return value;
}

/**
 * Atomically consumes a request from a named policy. Callers should fail
 * closed (503) if this throws, and return 429 plus rateLimitHeaders() when
 * the returned decision is not allowed.
 */
export async function consumeRateLimit(
  svc: RateLimitRpcClient,
  policy: RateLimitPolicy,
  subject: RateLimitSubject,
  options: RateLimitOptions = {},
): Promise<RateLimitDecision> {
  const definition = RATE_LIMIT_POLICIES[policy];
  const bucketKey = await rateLimitBucketKey(policy, subject, options);
  const { data, error } = await svc.rpc("consume_rate_limit", {
    p_bucket_key: bucketKey,
    p_limit: definition.limit,
    p_window_seconds: definition.windowSeconds,
  });

  if (error) {
    throw new RateLimitBackendError(
      error.message || "rate limit RPC failed",
    );
  }

  const row = asRow(data);
  if (typeof row.allowed !== "boolean") {
    throw new RateLimitBackendError("rate limit RPC returned invalid allowance");
  }

  const limit = asInteger(row.limit_value, "limit");
  const remaining = asInteger(row.remaining, "remaining");
  const retryAfterSeconds = asInteger(
    row.retry_after_seconds,
    "retry interval",
  );
  if (
    limit !== definition.limit || remaining < 0 || remaining > limit ||
    retryAfterSeconds < 0 || retryAfterSeconds > definition.windowSeconds ||
    (!row.allowed && retryAfterSeconds < 1)
  ) {
    throw new RateLimitBackendError("rate limit RPC returned unsafe metadata");
  }

  return {
    allowed: row.allowed,
    policy,
    limit,
    remaining,
    resetAt: asResetAt(row.reset_at),
    retryAfterSeconds,
  };
}

/** Standard response metadata; Retry-After is emitted only on a rejection. */
export function rateLimitHeaders(
  decision: RateLimitDecision,
): Record<string, string> {
  const headers: Record<string, string> = {
    "X-RateLimit-Limit": String(decision.limit),
    "X-RateLimit-Remaining": String(decision.remaining),
    "X-RateLimit-Reset": decision.resetAt,
  };
  if (!decision.allowed) {
    headers["Retry-After"] = String(decision.retryAfterSeconds);
  }
  return headers;
}

import { describe, test, expect } from "bun:test";

// ─── checkRateLimit ───────────────────────────────────────────────────────────

describe("checkRateLimit", () => {
  test("allows requests under the limit", async () => {
    const { checkRateLimit } = await import("../lib/rate-limit");
    for (let i = 0; i < 10; i++) {
      expect(checkRateLimit(`test-allow-${Date.now()}-${i}`, 10, 60_000)).toBe(true);
    }
  });

  test("returns true for first N requests and false for N+1", async () => {
    const { checkRateLimit } = await import("../lib/rate-limit");
    const key = `test-limit-${Date.now()}`;
    const limit = 3;

    expect(checkRateLimit(key, limit, 60_000)).toBe(true);  // 1
    expect(checkRateLimit(key, limit, 60_000)).toBe(true);  // 2
    expect(checkRateLimit(key, limit, 60_000)).toBe(true);  // 3
    expect(checkRateLimit(key, limit, 60_000)).toBe(false); // 4 — blocked
    expect(checkRateLimit(key, limit, 60_000)).toBe(false); // 5 — still blocked
  });

  test("resets after the window expires", async () => {
    const { checkRateLimit } = await import("../lib/rate-limit");
    const key = `test-reset-${Date.now()}`;
    const limit = 2;
    const windowMs = 60; // 60 ms window for fast testing

    expect(checkRateLimit(key, limit, windowMs)).toBe(true);
    expect(checkRateLimit(key, limit, windowMs)).toBe(true);
    expect(checkRateLimit(key, limit, windowMs)).toBe(false); // blocked

    // Wait for window to expire
    await new Promise<void>((resolve) => setTimeout(resolve, windowMs + 20));

    expect(checkRateLimit(key, limit, windowMs)).toBe(true); // window reset
  });

  test("different keys are tracked independently", async () => {
    const { checkRateLimit } = await import("../lib/rate-limit");
    const ts = Date.now();
    const key1 = `test-key1-${ts}`;
    const key2 = `test-key2-${ts}`;

    checkRateLimit(key1, 1, 60_000);
    checkRateLimit(key1, 1, 60_000); // key1 now blocked

    // key2 is unaffected
    expect(checkRateLimit(key2, 1, 60_000)).toBe(true);
    expect(checkRateLimit(key2, 1, 60_000)).toBe(false); // key2 now also blocked
  });
});

// ─── retryAfterSeconds ────────────────────────────────────────────────────────

describe("retryAfterSeconds", () => {
  test("returns 0 for unknown keys", async () => {
    const { retryAfterSeconds } = await import("../lib/rate-limit");
    expect(retryAfterSeconds("completely-unknown-key-xyz")).toBe(0);
  });

  test("returns positive seconds after limit exceeded", async () => {
    const { checkRateLimit, retryAfterSeconds } = await import("../lib/rate-limit");
    const key = `test-retry-${Date.now()}`;

    checkRateLimit(key, 1, 60_000); // first — allowed
    // key is now in the store; still under limit so no block yet
    const seconds = retryAfterSeconds(key, 60_000);
    expect(seconds).toBeGreaterThan(0);
    expect(seconds).toBeLessThanOrEqual(60);
  });

  test("retry-after is bounded by the window size", async () => {
    const { checkRateLimit, retryAfterSeconds } = await import("../lib/rate-limit");
    const key = `test-bounded-${Date.now()}`;
    const windowMs = 5_000;

    checkRateLimit(key, 1, windowMs);
    checkRateLimit(key, 1, windowMs); // blocked

    const seconds = retryAfterSeconds(key, windowMs);
    expect(seconds).toBeGreaterThan(0);
    expect(seconds).toBeLessThanOrEqual(5);
  });
});

import {
  assert,
  assertEquals,
  assertMatch,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  consumeRateLimit,
  rateLimitBucketKey,
  rateLimitHeaders,
} from "./rate_limit.ts";

const root = new URL("../../../../", import.meta.url);

Deno.test("rate limit keys are scoped and never contain raw subjects", async () => {
  const options = { keySecret: "test-rate-limit-secret" };
  const loginKey = await rateLimitBucketKey(
    "login",
    { ip: "203.0.113.7" },
    options,
  );
  const publicKey = await rateLimitBucketKey(
    "public",
    { ip: "203.0.113.7" },
    options,
  );

  assertMatch(loginKey, /^rl:login:[a-f0-9]{64}$/);
  assert(!loginKey.includes("203.0.113.7"));
  assert(loginKey !== publicKey);
});

Deno.test("login policy calls the atomic RPC and surfaces retry metadata", async () => {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const client = {
    rpc(name: string, args: Record<string, unknown>) {
      calls.push({ name, args });
      return Promise.resolve({
        data: [{
          allowed: false,
          limit_value: 10,
          remaining: 0,
          reset_at: "2026-08-29T00:01:00.000Z",
          retry_after_seconds: 17,
        }],
        error: null,
      });
    },
  } as any;

  const decision = await consumeRateLimit(
    client,
    "login",
    { ip: "203.0.113.7" },
    { keySecret: "test-rate-limit-secret" },
  );

  assertEquals(calls.length, 1);
  assertEquals(calls[0].name, "consume_rate_limit");
  assertEquals(calls[0].args.p_limit, 10);
  assertEquals(calls[0].args.p_window_seconds, 60);
  assertMatch(String(calls[0].args.p_bucket_key), /^rl:login:[a-f0-9]{64}$/);
  assertEquals(rateLimitHeaders(decision), {
    "X-RateLimit-Limit": "10",
    "X-RateLimit-Remaining": "0",
    "X-RateLimit-Reset": "2026-08-29T00:01:00.000Z",
    "Retry-After": "17",
  });
});

Deno.test("rate-limit migration keeps storage private and RPC service-only", async () => {
  const migration = await Deno.readTextFile(
    new URL("supabase/migrations/20260830134225_database_rate_limits.sql", root),
  );

  assertMatch(
    migration,
    /create table schooldesk_internal\.rate_limit_buckets/i,
  );
  assertMatch(
    migration,
    /security definer\s+set search_path = pg_catalog, pg_temp/i,
  );
  assertMatch(
    migration,
    /revoke all on table schooldesk_internal\.rate_limit_buckets\s+from public, anon, authenticated, service_role/i,
  );
  assertMatch(
    migration,
    /grant execute on function public\.consume_rate_limit\(text, integer, integer\)\s+to service_role/i,
  );
  assert(
    !/grant execute on function public\.consume_rate_limit\(text, integer, integer\)\s+to (anon|authenticated)/i.test(
      migration,
    ),
  );
});

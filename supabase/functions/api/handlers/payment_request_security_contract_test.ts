import { assert, assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts";

const root = new URL("../../../../", import.meta.url);
const read = (path: string) => Deno.readTextFile(new URL(path, root));

Deno.test("parent payment request JSON inserts cannot set approval metadata", async () => {
  const source = await read("supabase/functions/api/handlers/fees.ts");

  assertMatch(source, /function parentPaymentRequestPayload\(/);
  assertMatch(source, /parent_user_id: parentUserId/);
  assertMatch(source, /status: "pending_verification"/);
  assert(
    !/from\(\s*"parent_payment_requests"\s*\)\.insert\(\{\s*\.\.\.body/.test(
      source,
    ),
    "parent payment request inserts must not spread the raw request body",
  );

  const helper = source.match(
    /function parentPaymentRequestPayload\([\s\S]*?\n}\n\nfunction normalizeFrequency/,
  )?.[0] ?? "";
  assert(!helper.includes("reviewed_by"));
  assert(!helper.includes("payment_id"));
  assert(!helper.includes("receipt_id"));
});

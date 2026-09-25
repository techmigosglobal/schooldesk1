import { assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts";

const root = new URL("../../../../", import.meta.url);
const read = (path: string) => Deno.readTextFile(new URL(path, root));

Deno.test("Coordinator dashboard filters finance approval entity types", async () => {
  const source = await read("supabase/functions/api/handlers/dashboard.ts");
  assertMatch(source, /isFinanceApproval\(row\.module, row\.entity_type\)/);
  assertMatch(source, /"invoices"/);
  assertMatch(source, /"receipts"/);
  assertMatch(source, /"fee_concession"/);
  assertMatch(source, /"fee_payment_proof"/);
});

Deno.test("Coordinator cannot read school payment settings", async () => {
  const source = await read("supabase/functions/api/handlers/fees.ts");
  assertMatch(
    source,
    /feesPath === "\/payment-config" && method === "GET"\) \{\s+if \(!isParent && !isAdminOrPrincipal\(user\)\) \{\s+return fail\("finance access required", 403\);/,
  );
});

Deno.test("branch activity and complaint notifications handle Coordinator as leader", async () => {
  const activity = await read("supabase/functions/api/handlers/activity.ts");
  const issues = await read("supabase/functions/api/handlers/issues.ts");
  assertMatch(
    activity,
    /\["principal", "coordinator"\]\.includes\(activityRole\(user\)\)/,
  );
  assertMatch(issues, /\["principal", "coordinator"\]\.includes\(targetRole\)/);
});

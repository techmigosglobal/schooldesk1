import { assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts";

const root = new URL("../../../../", import.meta.url);
const read = (path: string) => Deno.readTextFile(new URL(path, root));

Deno.test("coordinator dashboard returns its operations-only DTO before fee reads", async () => {
  const source = await read("supabase/functions/api/handlers/dashboard.ts");

  assertMatch(source, /if \(!isSchoolLeader\(user\)\) \{\s+return fail\("forbidden", 403\)/);
  assertMatch(
    source,
    /if \(!financeAuthorized\) \{\s+return ok\(coordinatorDashboardDto\(operations\)\);\s+\}/,
  );
  assertMatch(
    source,
    /isFinanceApproval\(row\.module, row\.entity_type\)/,
  );
  assertMatch(
    source,
    /FINANCE_APPROVAL_MODULES = new Set\(\[[\s\S]*?"concession"[\s\S]*?"fee_payment_proof"/,
  );
  assertMatch(
    source,
    /const \{ data: feeSummary, error: feeSummaryError \} = await svc\.rpc\(\s+"fee_dashboard_summary",/,
  );
});

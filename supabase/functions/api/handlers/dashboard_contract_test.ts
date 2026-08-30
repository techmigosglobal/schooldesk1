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
    /approvalRequestsQuery\.not\(\s+"module",\s+"in",\s+'\("fee","fees","finance","payment"\)'/,
  );
  assertMatch(
    source,
    /const \[invoices, paidInvoices, parentPaymentRequests\] = await Promise\.all/,
  );
});

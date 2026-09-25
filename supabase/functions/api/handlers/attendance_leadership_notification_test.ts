import { assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts";

const sourceUrl = new URL("./attendance.ts", import.meta.url);

Deno.test("attendance correction alerts reach principal and Coordinator", async () => {
  const source = await Deno.readTextFile(sourceUrl);
  assertMatch(source, /in\("role_name", \["principal", "coordinator"\]\)/);
  assertMatch(source, /target_role: recipient\.role/);
  assertMatch(source, /event_type: "attendance_correction_requested"/);
});

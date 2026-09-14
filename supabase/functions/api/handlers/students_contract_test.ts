import { assert, assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts";

const root = new URL("../../../../", import.meta.url);
const read = (path: string) => Deno.readTextFile(new URL(path, root));

Deno.test("student list select only references columns that exist", async () => {
  const source = await read("supabase/functions/api/handlers/students.ts");
  const select = source.match(
    /const studentListSelect\s*=\s*"([^"]+)";/,
  )?.[1];

  assert(select, "studentListSelect must be declared as a string select");
  assert(!select.includes("academic_year_id"));
  assertMatch(
    source,
    /url\.searchParams\.get\("academic_year_id"\)/,
  );
});

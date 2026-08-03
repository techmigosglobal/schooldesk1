import { assert, assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts";

const root = new URL("../../../../", import.meta.url);
const read = (path: string) => Deno.readTextFile(new URL(path, root));

Deno.test("website public route is explicit and does not reuse operational event posts", async () => {
  const source = await read("supabase/functions/api/handlers/website.ts");
  assertMatch(source, /handleWebsitePublic/);
  assertMatch(source, /eq\("is_published", true\)/);
  assertMatch(source, /SCHOOL_GALLERY/);
  assertMatch(source, /school-public-media/);
  assert(!source.includes("school-assets"));
});

Deno.test("only the principal can mutate website content", async () => {
  const source = await read("supabase/functions/api/handlers/website.ts");
  assertMatch(source, /role_name\).*=== "principal"/);
  assertMatch(source, /principal access required/);
  const migration = await read("supabase/migrations/20260720090000_school_website_content.sql");
  assertMatch(migration, /website_content_principal_write/);
  assertMatch(migration, /school_website_gallery_items/);
});

Deno.test("website gallery management exposes only selected event-post media", async () => {
  const source = await read("supabase/functions/api/handlers/website.ts");
  assertMatch(source, /path === "\/website\/gallery" && method === "GET"/);
  assertMatch(source, /\.contains\("destinations", JSON\.stringify\(\["SCHOOL_GALLERY"\]\)\)/);
  assertMatch(source, /selectedEventMedia/);
  assertMatch(source, /source: "event_post"/);
});

import { assert, assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts";

const root = new URL("../../../../", import.meta.url);
const read = (path: string) => Deno.readTextFile(new URL(path, root));

Deno.test("website public route is explicit and uses the website selection flag", async () => {
  const source = await read("supabase/functions/api/handlers/website.ts");
  assertMatch(source, /handleWebsitePublic/);
  assertMatch(source, /eq\("is_published", true\)/);
  assertMatch(source, /eq\("public_gallery_visible", true\)/);
  assertMatch(source, /school-public-media/);
  assert(!source.includes("school-assets"));
});

Deno.test("school leaders can manage branch website content", async () => {
  const source = await read("supabase/functions/api/handlers/website.ts");
  assertMatch(source, /\["principal", "coordinator"\]/);
  assertMatch(source, /if \(!isLeader\(user\)\)/);
  const migration = await read("supabase/migrations/20260720090000_school_website_content.sql");
  assertMatch(migration, /website_content_principal_write/);
  assertMatch(migration, /school_website_gallery_items/);
});

Deno.test("website gallery management exposes only selected event-post media", async () => {
  const source = await read("supabase/functions/api/handlers/website.ts");
  assertMatch(source, /path === "\/website\/gallery" && method === "GET"/);
  assertMatch(source, /public_gallery_visible, status, destinations/);
  assertMatch(source, /selectedEventMedia/);
  assertMatch(source, /source: "event_post"/);
  assert(!source.includes('.contains("destinations", JSON.stringify(["SCHOOL_GALLERY"]))'));
});

Deno.test("website gallery normalizes legacy and structured event media", async () => {
  const source = await read("supabase/functions/api/handlers/website.ts");
  assertMatch(source, /function eventMediaItems/);
  assertMatch(source, /JSON\.parse\(source\)/);
  assertMatch(source, /object\.mediaUrl/);
  assertMatch(source, /object\.mime_type/);
});

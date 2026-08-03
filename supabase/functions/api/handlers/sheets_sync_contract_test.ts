import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { canonicalGradeKey } from "./sheets_sync.ts";

const root = new URL("../../../../", import.meta.url);
const read = (path: string) => Deno.readTextFile(new URL(path, root));

Deno.test("sheet class labels resolve to canonical grade keys", () => {
  assertEquals(canonicalGradeKey("PLAYGROUP"), "playgroup");
  assertEquals(canonicalGradeKey("Play Group"), "playgroup");
  assertEquals(canonicalGradeKey("NURSERY"), "nursery");
  assertEquals(canonicalGradeKey("NUESERY"), "nursery");
});

Deno.test("student Sheets sync preserves existing photo references", async () => {
  const source = await read("supabase/functions/api/handlers/sheets_sync.ts");
  if (!source.includes('select("id, photo_url")')) {
    throw new Error("student sync must load the existing photo_url");
  }
  if (!source.includes("photo_url: incomingPhotoUrl || existingPhotoUrl || null")) {
    throw new Error("student sync must preserve an existing photo when the sheet omits it");
  }
});

import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";

const source = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");

test("public gallery selection is separate from the in-app School Gallery", () => {
  const manager = source("../components/portal/WebsiteManager.tsx");
  const webEnv = source("../lib/env.ts");
  const webBackend = source("../lib/backend.ts");
  const websiteHandler = source("../../supabase/functions/api/handlers/website.ts");
  const eventHandler = source("../../supabase/functions/api/handlers/uploads.ts");
  const migration = source("../../supabase/migrations/20260803090000_public_website_gallery_event_post_selection.sql");

  expect(manager).toContain("public_gallery_visible");
  expect(manager).toContain("Display on the public website");
  expect(manager).toContain("These controls do not change in-app visibility.");
  expect(manager).toContain("media-visibility-summary");
  expect(manager).toContain("Displayed on website");
  expect(manager).toContain("Hidden from website");
  expect(manager).toContain('aria-pressed={filter === key}');
  expect(manager).toContain("media-visibility-badge");
  expect(manager).toContain("setGallery((current) => current.map");
  expect(manager).toContain("The previous value is restored on error.");
  expect(manager).toContain("event-posts/${stringValue(item.event_post_id)}");
  expect(websiteHandler).toContain('.eq("public_gallery_visible", true)');
  expect(websiteHandler).toContain("publicR2FileUrl");
  expect(websiteHandler).toContain('storedMedia.startsWith("r2://") ? "" : storedMedia');
  expect(webEnv).not.toMatch(/R2_|SOURCE_S3|AWS_ACCESS_KEY|AWS_SECRET/);
  expect(webBackend).toContain("SCHOOLDESK_API_BASE_URL");
  expect(webBackend).not.toMatch(/R2_|SOURCE_S3|AWS_ACCESS_KEY|AWS_SECRET/);
  expect(websiteHandler).toContain("public_gallery_visible: row.public_gallery_visible !== false");
  expect(websiteHandler).not.toContain('.contains("destinations", JSON.stringify(["SCHOOL_GALLERY"]))');
  expect(websiteHandler).toContain("function eventMediaItems");
  expect(eventHandler).toContain("typeof body.public_gallery_visible === \"boolean\"");
  expect(eventHandler).toContain("public_gallery_visible: publicGalleryVisible");
  expect(eventHandler).toContain("textValue(existing.visibility, \"school\")");
  expect(eventHandler).toContain("existing.event_id ?? null");
  expect(migration).toContain("add column if not exists public_gallery_visible boolean not null default false");
});

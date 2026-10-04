import {
  assert,
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  legacyR2Reference,
  publicR2FileReference,
  publicR2FileUrl,
  r2FileReference,
  r2KeyFromValue,
  r2ReferenceInfo,
  r2VisibilityFromValue,
  signedR2FileUrl,
} from "./r2_storage.ts";

const envNames = [
  "R2_ENDPOINT",
  "R2_BUCKET",
  "R2_PRIVATE_BUCKET",
  "R2_PUBLIC_BUCKET",
  "R2_ACCESS_KEY_ID",
  "R2_SECRET_ACCESS_KEY",
  "R2_PUBLIC_BASE_URL",
  "R2_REGION",
  "STORAGE_WRITE_PROVIDER",
  "SUPABASE_URL",
] as const;

function withR2Env(callback: () => void | Promise<void>) {
  const previous = new Map(
    envNames.map((name) => [name, Deno.env.get(name)]),
  );
  Deno.env.set("R2_ENDPOINT", "https://example.r2.cloudflarestorage.com");
  Deno.env.set("R2_PRIVATE_BUCKET", "schooldesk-private-files");
  Deno.env.set("R2_PUBLIC_BUCKET", "schooldesk-public-media");
  Deno.env.set("R2_ACCESS_KEY_ID", "test-access");
  Deno.env.set("R2_SECRET_ACCESS_KEY", "test-secret");
  Deno.env.set("R2_REGION", "auto");
  return Promise.resolve(callback()).finally(() => {
    for (const name of envNames) {
      const value = previous.get(name);
      if (value == null) Deno.env.delete(name);
      else Deno.env.set(name, value);
    }
  });
}

Deno.test("private references produce durable, scoped signed URLs", async () => {
  await withR2Env(async () => {
    Deno.env.delete("R2_PUBLIC_BASE_URL");
    const key = "private/docs/term report.pdf";
    const reference = r2FileReference(key);
    assertEquals(reference, "r2://private/docs/term report.pdf");
    assertEquals(r2KeyFromValue(reference), key.slice("private/".length));
    assertEquals(r2VisibilityFromValue(reference), "private");
    const signed = await signedR2FileUrl(reference, 60);
    assert(signed.includes("X-Amz-Signature="));
    assert(signed.includes("X-Amz-Expires=60"));
    assertEquals(r2KeyFromValue(signed), "docs/term report.pdf");
    assertFalse(publicR2FileUrl(reference).length > 0);
  });
});

Deno.test("public references require the public marker and custom domain", async () => {
  await withR2Env(async () => {
    Deno.env.set("R2_PUBLIC_BASE_URL", "https://cdn.example.test/assets");
    const reference = publicR2FileReference("gallery/photo.jpg");
    assertEquals(r2ReferenceInfo(reference), {
      key: "gallery/photo.jpg",
      visibility: "public",
    });
    assertEquals(
      publicR2FileUrl(reference),
      "https://cdn.example.test/assets/gallery/photo.jpg",
    );
    assertEquals(
      r2KeyFromValue("https://cdn.example.test/assets/gallery/photo.jpg"),
      "gallery/photo.jpg",
    );
    assertEquals(
      r2VisibilityFromValue(
        "https://cdn.example.test/assets/gallery/photo.jpg",
      ),
      "public",
    );
  });
});

Deno.test("legacy unscoped references infer private only for private keys", async () => {
  await withR2Env(async () => {
    assertEquals(r2VisibilityFromValue("r2://private/docs/a.pdf"), "private");
    assertEquals(r2VisibilityFromValue("r2://website-gallery/a.jpg"), "public");
  });
});

Deno.test("self-hosted mode resolves migrated public R2 refs to Supabase Storage", async () => {
  await withR2Env(async () => {
    Deno.env.delete("R2_ENDPOINT");
    Deno.env.delete("R2_PRIVATE_BUCKET");
    Deno.env.delete("R2_PUBLIC_BUCKET");
    Deno.env.delete("R2_ACCESS_KEY_ID");
    Deno.env.delete("R2_SECRET_ACCESS_KEY");
    Deno.env.delete("R2_BUCKET");
    Deno.env.set("STORAGE_WRITE_PROVIDER", "supabase");
    Deno.env.set("SUPABASE_URL", "https://api.example.test");
    assertEquals(
      publicR2FileUrl("r2://public/event-posts/school/photo one.jpg"),
      "https://api.example.test/storage/v1/object/public/schooldesk-public-media/event-posts/school/photo%20one.jpg",
    );
    assertEquals(
      r2FileReference("documents/proof.pdf"),
      "schooldesk-private-files/documents/proof.pdf",
    );
  });
});

Deno.test("legacy Supabase Storage references map to migrated R2 keys", () => {
  assertEquals(
    legacyR2Reference(
      "https://qzdhymlabzqjeocetqqv.supabase.co/storage/v1/object/public/" +
        "school-assets/uploads/school/post/video.mp4",
    ),
    "r2://private/legacy/school-assets/uploads/school/post/video.mp4",
  );
  assertEquals(
    legacyR2Reference(
      "https://qzdhymlabzqjeocetqqv.supabase.co/storage/v1/object/public/" +
        "school-public-media/gallery/photo.jpg",
    ),
    "r2://public/website/gallery/photo.jpg",
  );
  assertEquals(
    legacyR2Reference("uploads/school/post/photo.jpg", "school-assets"),
    "r2://private/legacy/school-assets/uploads/school/post/photo.jpg",
  );
  assertEquals(
    legacyR2Reference("https://example.test/not-storage/photo.jpg"),
    null,
  );
});

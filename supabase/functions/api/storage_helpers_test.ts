import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { signedPrivateFileUrl } from "./storage_helpers.ts";

const envNames = [
  "R2_ENDPOINT",
  "R2_PRIVATE_BUCKET",
  "R2_PUBLIC_BUCKET",
  "R2_ACCESS_KEY_ID",
  "R2_SECRET_ACCESS_KEY",
  "R2_REGION",
  "STORAGE_LEGACY_READ",
  "STORAGE_READ_ORDER",
] as const;

async function withStorageEnv(callback: () => Promise<void>) {
  const previous = new Map(envNames.map((name) => [name, Deno.env.get(name)]));
  const previousFetch = globalThis.fetch;
  Deno.env.set("R2_ENDPOINT", "https://example.r2.cloudflarestorage.com");
  Deno.env.set("R2_PRIVATE_BUCKET", "schooldesk-private-files");
  Deno.env.set("R2_PUBLIC_BUCKET", "schooldesk-public-media");
  Deno.env.set("R2_ACCESS_KEY_ID", "test-access");
  Deno.env.set("R2_SECRET_ACCESS_KEY", "test-secret");
  Deno.env.set("R2_REGION", "auto");
  Deno.env.set("STORAGE_LEGACY_READ", "true");
  Deno.env.set("STORAGE_READ_ORDER", "r2,supabase");
  try {
    await callback();
  } finally {
    globalThis.fetch = previousFetch;
    for (const name of envNames) {
      const value = previous.get(name);
      if (value == null) Deno.env.delete(name);
      else Deno.env.set(name, value);
    }
  }
}

const legacyUrl =
  "https://qzdhymlabzqjeocetqqv.supabase.co/storage/v1/object/public/" +
  "school-assets/uploads/school/post/photo.jpg";

Deno.test("legacy event media resolves from R2 before Supabase", async () => {
  await withStorageEnv(async () => {
    globalThis.fetch = async () => new Response(null, { status: 200 });
    const url = await signedPrivateFileUrl(
      {} as SupabaseClient,
      legacyUrl,
      60,
      "school-assets",
    );
    assert(url.includes("X-Amz-Signature="), url);
    assert(url.includes("legacy/school-assets/uploads"), url);
  });
});

Deno.test("missing R2 copy falls back to the legacy provider", async () => {
  await withStorageEnv(async () => {
    globalThis.fetch = async () => new Response(null, { status: 404 });
    const legacySignedUrl = "https://legacy.example.test/signed/photo.jpg";
    const svc = {
      storage: {
        from: (bucket: string) => ({
          createSignedUrl: async (path: string, ttl: number) => {
            assertEquals(bucket, "school-assets");
            assertEquals(path, "uploads/school/post/photo.jpg");
            assertEquals(ttl, 60);
            return { data: { signedUrl: legacySignedUrl }, error: null };
          },
        }),
      },
    } as unknown as SupabaseClient;
    assertEquals(
      await signedPrivateFileUrl(svc, legacyUrl, 60, "school-assets"),
      legacySignedUrl,
    );
  });
});

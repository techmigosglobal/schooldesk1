import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type {
  SupabaseClient,
  User,
} from "https://esm.sh/@supabase/supabase-js@2";
import { handleSchools } from "./schools.ts";

Deno.test("logo upload reports persistence errors and missing school rows instead of success", async () => {
  const flags = ["R2_ENDPOINT", "STORAGE_LEGACY_WRITE"];
  const previous = flags.map((name) => Deno.env.get(name));
  Deno.env.set("R2_ENDPOINT", "");
  Deno.env.set("STORAGE_LEGACY_WRITE", "true");
  const user = {
    id: "principal",
    app_metadata: { school_id: "school-a", role_name: "principal" },
  } as unknown as User;
  const client = {
    auth: { getUser: () => Promise.resolve({ data: { user } }) },
  } as unknown as SupabaseClient;
  try {
    for (const outcome of ["error", "missing", "saved"]) {
      const schools = {
        update: () => schools,
        eq: () => schools,
        select: () => schools,
        maybeSingle: () =>
          Promise.resolve({
            data: outcome === "saved"
              ? {
                id: "school-a",
                logo_url: "https://example.invalid/saved.png",
              }
              : null,
            error: outcome === "error"
              ? { message: "database unavailable" }
              : null,
          }),
      };
      const profiles = {
        select: () => profiles,
        eq: () => profiles,
        single: () => Promise.resolve({ data: { school_id: "school-a" } }),
      };
      const svc = {
        from: (table: string) => table === "users" ? profiles : schools,
        storage: {
          from: () => ({
            upload: () => Promise.resolve({ error: null }),
            getPublicUrl: () => ({
              data: { publicUrl: "https://example.invalid/uploaded.png" },
            }),
          }),
        },
      } as unknown as SupabaseClient;
      const form = new FormData();
      form.set(
        "logo",
        new File([new Uint8Array([1])], "logo.png", { type: "image/png" }),
      );
      const req = new Request("http://localhost/schools/current/logo", {
        method: "POST",
        body: form,
      });
      const result = await handleSchools(
        req,
        "/schools/current/logo",
        "POST",
        new URL(req.url),
        client,
        svc,
        user,
      );
      assertEquals(result.status, outcome === "saved" ? 200 : 500);
      const payload = await result.json();
      assertEquals(payload.success, outcome === "saved");
      if (outcome === "saved") {
        assertEquals(
          payload.data.logo_url,
          "https://example.invalid/saved.png",
        );
      }
    }
  } finally {
    flags.forEach((name, index) =>
      previous[index] === undefined
        ? Deno.env.delete(name)
        : Deno.env.set(name, previous[index]!)
    );
  }
});

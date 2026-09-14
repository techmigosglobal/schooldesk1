import {
  assertEquals,
  assertFalse,
  assert,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  legacyStorageLocation,
  referenceKey,
  rewriteJson,
  rewriteString,
  r2ReferenceFor,
  type MigrationMapEntry,
} from "./storage_references.ts";

const item: MigrationMapEntry = {
  sourceBucket: "school-assets",
  sourceKey: "uploads/school/a.mp4",
  destinationBucket: "schooldesk-private-files",
  destinationKey: "legacy/school-assets/uploads/school/a.mp4",
  visibility: "private",
  status: "verified",
};

const mapping = new Map([[
  referenceKey({ bucket: item.sourceBucket, key: item.sourceKey }),
  item,
]]);

const signatureMapping = new Map([[
  referenceKey({
    bucket: "school-signatures",
    key: "signatures/school/seal.png",
  }),
  {
    sourceBucket: "school-signatures",
    sourceKey: "signatures/school/seal.png",
    destinationBucket: "schooldesk-private-files",
    destinationKey: "legacy/school-signatures/signatures/school/seal.png",
    visibility: "private",
    status: "verified",
  } satisfies MigrationMapEntry,
]]);

Deno.test("legacy Supabase URLs and bucket paths normalize to a source key", () => {
  assertEquals(
    legacyStorageLocation(
      "https://example.supabase.co/storage/v1/object/public/school-assets/uploads/school/a.mp4",
    ),
    { bucket: "school-assets", key: "uploads/school/a.mp4" },
  );
  assertEquals(
    legacyStorageLocation("school-assets/uploads/school/a.mp4"),
    { bucket: "school-assets", key: "uploads/school/a.mp4" },
  );
  assertEquals(
    legacyStorageLocation("uploads/school/a.mp4", "school-assets"),
    { bucket: "school-assets", key: "uploads/school/a.mp4" },
  );
});

Deno.test("verified mappings produce durable private R2 references", () => {
  assertEquals(
    r2ReferenceFor({ bucket: "school-assets", key: "uploads/school/a.mp4" }, mapping),
    "r2://private/legacy/school-assets/uploads/school/a.mp4",
  );
  assertEquals(
    rewriteString(
      "https://example.supabase.co/storage/v1/object/sign/school-assets/uploads/school/a.mp4?token=test",
      mapping,
    ).value,
    "r2://private/legacy/school-assets/uploads/school/a.mp4",
  );
});

Deno.test("nested JSON rewrites every mapped value and preserves R2 values", () => {
  const result = rewriteJson({
    media: [
      { url: "school-assets/uploads/school/a.mp4" },
      { url: "r2://private/already-migrated.mp4" },
    ],
  }, mapping);
  assertEquals(result.unresolved, []);
  assertEquals(result.changes.length, 1);
  assertEquals(
    (result.value as { media: Array<{ url: string }> }).media[0].url,
    "r2://private/legacy/school-assets/uploads/school/a.mp4",
  );
  assertEquals(
    (result.value as { media: Array<{ url: string }> }).media[1].url,
    "r2://private/already-migrated.mp4",
  );
});

Deno.test("unmapped legacy objects are reported and never rewritten", () => {
  const result = rewriteString("school-assets/uploads/school/missing.mp4", mapping);
  assertEquals(result.changes, []);
  assertEquals(result.unresolved, [{ bucket: "school-assets", key: "uploads/school/missing.mp4" }]);
  assertFalse(result.value.startsWith("r2://"));
  assert(legacyStorageLocation(result.value) !== null);
});

Deno.test("canonicalizes repeated separators in legacy storage URLs", () => {
  const result = rewriteString(
    "https://example.supabase.co/storage/v1/object/public/school-assets/uploads/school///a.mp4",
    mapping,
  );
  assertEquals(result.unresolved, []);
  assertEquals(result.value, "r2://private/legacy/school-assets/uploads/school/a.mp4");
});

Deno.test("does not treat MIME values in media JSON as storage paths", () => {
  const result = rewriteJson({ mime_type: "image/jpeg", url: "school-assets/uploads/school/a.mp4" }, mapping, "school-assets");
  assertEquals(result.unresolved, []);
  assertEquals((result.value as { mime_type: string }).mime_type, "image/jpeg");
  assertEquals((result.value as { url: string }).url, "r2://private/legacy/school-assets/uploads/school/a.mp4");
});

Deno.test("infers signature bucket inside finance snapshots and ignores receipt numbers", () => {
  const result = rewriteJson({
    signature_path: "signatures/school/seal.png",
    receipt_number: "AVP/26-27/MIY/JUL/114",
  }, signatureMapping, "finance-documents");
  assertEquals(result.unresolved, []);
  assertEquals(
    (result.value as { signature_path: string }).signature_path,
    "r2://private/legacy/school-signatures/signatures/school/seal.png",
  );
  assertEquals(
    (result.value as { receipt_number: string }).receipt_number,
    "AVP/26-27/MIY/JUL/114",
  );
});

Deno.test("rewrites comma-separated legacy URL strings", () => {
  const result = rewriteString(
    "https://example.supabase.co/storage/v1/object/public/school-assets/uploads/school/a.mp4,https://example.supabase.co/storage/v1/object/public/school-assets/uploads/school/a.mp4",
    mapping,
  );
  assertEquals(result.unresolved, []);
  assertEquals(result.changes.length, 2);
  assertEquals(
    result.value,
    "r2://private/legacy/school-assets/uploads/school/a.mp4,r2://private/legacy/school-assets/uploads/school/a.mp4",
  );
});

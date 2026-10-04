#!/usr/bin/env -S deno run --allow-env --allow-net --allow-read --allow-write

/**
 * Import the dated Supabase/R2 object manifests into a self-hosted Supabase
 * Storage instance, verify bytes, and normalize known SchoolDesk references.
 * Storage metadata is always created/updated through the Storage API.
 */
import {
  REFERENCE_TARGETS,
  type RewriteChange,
  rewriteSelfHostedJson,
  rewriteSelfHostedString,
  type StorageLocation,
} from "./storage_references.ts";

type SourceItem = {
  source: "supabase" | "r2";
  bucket: string;
  key: string;
  size: number;
  sha256: string;
  contentType: string;
  relativePath: string;
  status?: "pending" | "verified" | "failed";
  targetSha256?: string;
  error?: string;
};

type State = {
  schemaVersion: 1;
  createdAt: string;
  sourceDir: string;
  items: SourceItem[];
};

type DatabaseClient =
  & ((
    strings: TemplateStringsArray,
    ...values: unknown[]
  ) => Promise<unknown[]>)
  & {
    unsafe: (query: string, parameters?: unknown[]) => Promise<unknown[]>;
    begin: <T>(
      callback: (transaction: DatabaseClient) => Promise<T>,
    ) => Promise<T>;
    end: (options?: { timeout?: number }) => Promise<void>;
    json: (value: unknown) => unknown;
  };

type TargetRow = { __row_id: string; __value: unknown };

type BucketConfig = {
  id: string;
  public: boolean;
  fileSizeLimit: number | null;
  allowedMimeTypes: string[] | null;
};

const CONSOLIDATED_BUCKETS: readonly BucketConfig[] = [
  {
    id: "schooldesk-private-files",
    public: false,
    fileSizeLimit: 262144000,
    allowedMimeTypes: null,
  },
  {
    id: "schooldesk-public-media",
    public: true,
    fileSizeLimit: 262144000,
    allowedMimeTypes: null,
  },
];

const args = Deno.args;
const command = args[0] ?? "";
const sourceDir = option("--source-dir") ??
  Deno.env.get("STORAGE_SOURCE_DIR") ?? "";
const statePath = option("--state") ?? ".local/self-hosted-storage/state.json";
const concurrency = Math.max(
  1,
  Math.min(4, Number(option("--jobs") ?? "2") || 2),
);
const baseUrl = (Deno.env.get("TARGET_SUPABASE_URL") ?? "").replace(/\/+$/, "");
const serviceKey = Deno.env.get("TARGET_SUPABASE_SERVICE_ROLE_KEY") ?? "";
const publicBaseUrl = Deno.env.get("R2_PUBLIC_BASE_URL") ?? "";

function option(name: string): string | undefined {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : undefined;
}

function hasFlag(name: string): boolean {
  return args.includes(name);
}

function fail(message: string): never {
  throw new Error(message);
}

function safeRelative(root: string, relative: string): string {
  const normalized = relative.replaceAll("\\", "/").replace(/^\/+/, "")
    .replace(/\/{2,}/g, "/");
  if (normalized.split("/").some((part) => part === ".." || part === "")) {
    fail(`Unsafe source path in manifest: ${relative}`);
  }
  return `${root.replace(/\/+$/, "")}/${normalized}`;
}

function extensionMime(key: string): string {
  const extension = key.split(".").pop()?.toLowerCase() ?? "";
  const known: Record<string, string> = {
    csv: "text/csv",
    doc: "application/msword",
    docx:
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    jpeg: "image/jpeg",
    jpg: "image/jpeg",
    json: "application/json",
    mp4: "video/mp4",
    pdf: "application/pdf",
    png: "image/png",
    svg: "image/svg+xml",
    webm: "video/webm",
    xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  };
  return known[extension] ?? "application/octet-stream";
}

async function digest(bytes: Uint8Array): Promise<string> {
  const hash = new Uint8Array(
    await crypto.subtle.digest("SHA-256", bytes.slice().buffer),
  );
  return [...hash].map((value) => value.toString(16).padStart(2, "0")).join("");
}

async function readJson(path: string): Promise<Record<string, unknown>> {
  return JSON.parse(await Deno.readTextFile(path)) as Record<string, unknown>;
}

async function createState(): Promise<State> {
  if (!sourceDir) {
    fail(
      "Set STORAGE_SOURCE_DIR or pass --source-dir to the extracted backup directory",
    );
  }
  const supabaseManifest = await readJson(
    `${sourceDir}/supabase-storage-manifest.json`,
  );
  const r2Manifest = await readJson(`${sourceDir}/r2-inventory.json`);
  const supabaseObjects = supabaseManifest.objects as Array<
    Record<string, unknown>
  >;
  const r2Items = r2Manifest.items as Array<Record<string, unknown>>;
  if (!Array.isArray(supabaseObjects) || !Array.isArray(r2Items)) {
    fail("Source manifests do not have the expected objects/items arrays");
  }

  const items: SourceItem[] = [
    ...supabaseObjects.map((item): SourceItem => ({
      source: "supabase",
      bucket: String(item.bucket ?? ""),
      key: String(item.name ?? "").replace(/^\/+/, "").replace(/\/{2,}/g, "/"),
      size: Number(item.bytes),
      sha256: String(item.sha256 ?? "").toLowerCase(),
      contentType: String(
        item.content_type ?? extensionMime(String(item.name ?? "")),
      ),
      relativePath: `supabase-storage/${item.bucket}/${item.name}`,
      status: "pending",
    })),
    ...r2Items.map((item): SourceItem => ({
      source: "r2",
      bucket: String(item.bucket ?? ""),
      key: String(item.key ?? "").replace(/^\/+/, "").replace(/\/{2,}/g, "/"),
      size: Number(item.size),
      sha256: String(item.sha256 ?? "").toLowerCase(),
      contentType: String(
        item.content_type ?? extensionMime(String(item.key ?? "")),
      ),
      relativePath: `r2-storage/${item.bucket}/${item.key}`,
      status: "pending",
    })),
  ];
  const unique = new Set<string>();
  for (const item of items) {
    if (
      !item.bucket || !item.key || !Number.isSafeInteger(item.size) ||
      item.size < 0 || !/^[a-f0-9]{64}$/.test(item.sha256)
    ) {
      fail(`Invalid object metadata in ${item.source} manifest`);
    }
    const location = `${item.bucket}\n${item.key}`;
    if (unique.has(location)) {
      fail(
        `Duplicate destination object in manifests: ${item.bucket}/${item.key}`,
      );
    }
    unique.add(location);
    const bytes = await Deno.readFile(
      safeRelative(sourceDir, item.relativePath),
    );
    if (bytes.byteLength !== item.size || await digest(bytes) !== item.sha256) {
      fail(`Source checksum mismatch: ${item.relativePath}`);
    }
  }
  return {
    schemaVersion: 1,
    createdAt: new Date().toISOString(),
    sourceDir,
    items,
  };
}

async function writeState(state: State): Promise<void> {
  const parent = statePath.replace(/\/[^/]*$/, "") || ".";
  await Deno.mkdir(parent, { recursive: true, mode: 0o700 });
  await Deno.writeTextFile(statePath, `${JSON.stringify(state, null, 2)}\n`, {
    mode: 0o600,
  });
  try {
    await Deno.chmod(statePath, 0o600);
  } catch {
    // Windows hosts do not support Unix file modes.
  }
}

async function readState(): Promise<State> {
  const state = JSON.parse(await Deno.readTextFile(statePath)) as State;
  if (state.schemaVersion !== 1 || !Array.isArray(state.items)) {
    fail("Unsupported or invalid migration state file");
  }
  return state;
}

function requiredTarget(): void {
  const isHttps = /^https:\/\//.test(baseUrl);
  const isCoolifyPreviewHttp =
    /^http:\/\/[^/]+\.sslip\.io(?::\d+)?$/i.test(baseUrl);
  if (!isHttps && !isCoolifyPreviewHttp) {
    fail(
      "Set TARGET_SUPABASE_URL to an HTTPS API origin (HTTP is allowed only for a Coolify sslip.io rehearsal URL)",
    );
  }
  if (!serviceKey) {
    fail("Set TARGET_SUPABASE_SERVICE_ROLE_KEY in a protected environment");
  }
}

function targetHeaders(extra: Record<string, string> = {}): Headers {
  return new Headers({
    apikey: serviceKey,
    authorization: `Bearer ${serviceKey}`,
    ...extra,
  });
}

function storageObjectUrl(bucket: string, key: string): string {
  return `${baseUrl}/storage/v1/object/${encodeURIComponent(bucket)}/${
    key.split("/").map(encodeURIComponent).join("/")
  }`;
}

function parsePgArray(value: string): string[] | null {
  if (value === "\\N") return null;
  if (!value.startsWith("{") || !value.endsWith("}")) {
    fail(`Unsupported PostgreSQL array value in storage-data.sql: ${value}`);
  }
  if (value === "{}") return [];
  return value.slice(1, -1).split(",").map((item) => item.trim()).map((item) => {
    if (item.startsWith('"') && item.endsWith('"')) {
      return item.slice(1, -1).replaceAll('\\"', '"');
    }
    return item;
  });
}

async function sourceBucketConfigs(sourceRoot: string): Promise<BucketConfig[]> {
  const dumpPath = `${sourceRoot}/storage-data.sql`;
  let dump: string;
  try {
    dump = await Deno.readTextFile(dumpPath);
  } catch {
    fail(`Missing storage bucket metadata dump: ${dumpPath}`);
  }
  const copyMarker = 'COPY "storage"."buckets"';
  const marker = dump.indexOf(copyMarker);
  if (marker < 0) fail(`Could not find storage bucket COPY data in ${dumpPath}`);
  const dataStart = dump.indexOf("\n", marker) + 1;
  const dataEnd = dump.indexOf("\n\\.\n", dataStart);
  if (dataStart <= 0 || dataEnd < dataStart) {
    fail(`Could not parse storage bucket COPY data in ${dumpPath}`);
  }
  const configs = dump.slice(dataStart, dataEnd).split("\n").filter(Boolean)
    .map((row): BucketConfig => {
      const fields = row.split("\t");
      if (fields.length < 9) {
        fail(`Malformed storage bucket row in ${dumpPath}`);
      }
      const fileSizeLimit = fields[7] === "\\N" || fields[7] === ""
        ? null
        : Number(fields[7]);
      if (fileSizeLimit !== null && !Number.isSafeInteger(fileSizeLimit)) {
        fail(`Invalid storage bucket file size limit in ${dumpPath}`);
      }
      return {
        id: fields[0],
        public: fields[5] === "t",
        fileSizeLimit,
        allowedMimeTypes: parsePgArray(fields[8]),
      };
    });
  if (!configs.length) fail(`No storage buckets found in ${dumpPath}`);
  return configs;
}

function sortedValues(value: string[] | null): string[] | null {
  return value === null ? null : [...value].sort();
}

function bucketPoliciesMatch(actual: {
  public?: boolean;
  file_size_limit?: number | null;
  allowed_mime_types?: string[] | null;
}, expected: BucketConfig): boolean {
  const actualLimit = actual.file_size_limit ?? null;
  const actualMimes = sortedValues(actual.allowed_mime_types ?? null);
  const expectedMimes = sortedValues(expected.allowedMimeTypes);
  return actual.public === expected.public &&
    (expected.fileSizeLimit === null || actualLimit === null ||
      actualLimit >= expected.fileSizeLimit) &&
    JSON.stringify(actualMimes) === JSON.stringify(expectedMimes);
}

async function ensureMigrationBuckets(sourceRoot: string): Promise<void> {
  const byId = new Map<string, BucketConfig>();
  for (const bucket of [
    ...await sourceBucketConfigs(sourceRoot),
    ...CONSOLIDATED_BUCKETS,
  ]) {
    const existing = byId.get(bucket.id);
    if (existing && JSON.stringify(existing) !== JSON.stringify(bucket)) {
      fail(`Conflicting target policy for storage bucket ${bucket.id}`);
    }
    byId.set(bucket.id, bucket);
  }
  const buckets = [...byId.values()];
  for (const bucket of buckets) {
    const get = await fetch(`${baseUrl}/storage/v1/bucket/${bucket.id}`, {
      headers: targetHeaders(),
    });
    const getBody = await get.text();
    if (get.ok) {
      const config = JSON.parse(getBody) as {
        public?: boolean;
        file_size_limit?: number | null;
        allowed_mime_types?: string[] | null;
      };
      if (!bucketPoliciesMatch(config, bucket)) {
        fail(
          `Target bucket ${bucket.id} has an incompatible visibility, size limit, or MIME policy`,
        );
      }
      continue;
    }
    const missingBucket = get.status === 404 ||
      (get.status === 400 &&
        /(?:Bucket not found|NoSuchBucket)/i.test(getBody));
    if (!missingBucket) {
      fail(`Could not inspect target bucket ${bucket.id} (HTTP ${get.status})`);
    }
    const create = await fetch(`${baseUrl}/storage/v1/bucket`, {
      method: "POST",
      headers: targetHeaders({ "content-type": "application/json" }),
      body: JSON.stringify({
        id: bucket.id,
        name: bucket.id,
        public: bucket.public,
        file_size_limit: bucket.fileSizeLimit,
        allowed_mime_types: bucket.allowedMimeTypes,
      }),
    });
    if (!create.ok) {
      fail(
        `Could not create target bucket ${bucket.id} (HTTP ${create.status})`,
      );
    }
  }
}

async function targetObjectHash(item: SourceItem): Promise<string | null> {
  const response = await fetch(storageObjectUrl(item.bucket, item.key), {
    headers: targetHeaders(),
  });
  if (response.status === 404) return null;
  if (!response.ok) {
    const body = await response.text();
    if (
      response.status === 400 &&
      /(?:Object not found|NoSuchKey|not_found)/i.test(body)
    ) return null;
    fail(
      `Target read failed for ${item.bucket}/${item.key} (HTTP ${response.status})`,
    );
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  return await digest(bytes);
}

async function importObjects(state: State): Promise<void> {
  if (!hasFlag("--execute")) {
    fail(
      "Import is dry-run by default; pass --execute to create buckets and upload objects",
    );
  }
  requiredTarget();
  await ensureMigrationBuckets(state.sourceDir);
  const queue = state.items.filter((item) => item.status !== "verified");
  let cursor = 0;
  let failed = 0;
  const worker = async () => {
    while (cursor < queue.length) {
      const item = queue[cursor++];
      try {
        const bytes = await Deno.readFile(
          safeRelative(state.sourceDir, item.relativePath),
        );
        if (
          bytes.byteLength !== item.size || await digest(bytes) !== item.sha256
        ) {
          fail(`Source checksum changed after inventory: ${item.relativePath}`);
        }
        const existingHash = await targetObjectHash(item);
        if (existingHash !== null && existingHash !== item.sha256) {
          fail(
            `Target object exists with different bytes; refusing overwrite: ${item.bucket}/${item.key}`,
          );
        }
        if (existingHash === null) {
          const response = await fetch(
            storageObjectUrl(item.bucket, item.key),
            {
              method: "POST",
              headers: targetHeaders({
                "content-type": item.contentType,
                "cache-control": "3600",
                "x-upsert": "false",
              }),
              body: bytes,
            },
          );
          if (!response.ok) {
            fail(
              `Target upload failed for ${item.bucket}/${item.key} (HTTP ${response.status})`,
            );
          }
        }
        item.targetSha256 = await targetObjectHash(item) ?? undefined;
        if (item.targetSha256 !== item.sha256) {
          fail(`Post-upload SHA-256 mismatch: ${item.bucket}/${item.key}`);
        }
        item.status = "verified";
        item.error = undefined;
      } catch (error) {
        item.status = "failed";
        item.error = error instanceof Error ? error.message : String(error);
        failed++;
      }
      await writeState(state);
      console.log(`${item.status}: ${item.bucket}/${item.key}`);
    }
  };
  await Promise.all(
    Array.from({ length: Math.min(concurrency, queue.length) }, worker),
  );
  console.log(
    JSON.stringify(
      {
        mode: "copy",
        objects: state.items.length,
        verified:
          state.items.filter((item) => item.status === "verified").length,
        failed,
      },
      null,
      2,
    ),
  );
  if (failed) Deno.exitCode = 1;
}

async function verifyObjects(state: State): Promise<void> {
  requiredTarget();
  let failed = 0;
  for (const item of state.items) {
    try {
      const targetHash = await targetObjectHash(item);
      item.targetSha256 = targetHash ?? undefined;
      if (targetHash !== item.sha256) {
        fail(
          `Target SHA-256 mismatch or missing object: ${item.bucket}/${item.key}`,
        );
      }
      item.status = "verified";
      item.error = undefined;
    } catch (error) {
      item.status = "failed";
      item.error = error instanceof Error ? error.message : String(error);
      failed++;
    }
    await writeState(state);
  }
  console.log(
    JSON.stringify(
      {
        mode: "verify",
        objects: state.items.length,
        verified:
          state.items.filter((item) => item.status === "verified").length,
        failed,
      },
      null,
      2,
    ),
  );
  if (failed) Deno.exitCode = 1;
}

function quoteIdentifier(value: string): string {
  if (!/^[a-z_][a-z0-9_]*$/i.test(value)) {
    fail(`Unsafe SQL identifier: ${value}`);
  }
  return `"${value}"`;
}

const LEGACY_REFERENCE_BUCKETS = new Set([
  "school-assets",
  "school-private-files",
  "finance-documents",
  "payment-proofs",
  "issue-attachments",
  "help-tutorial-videos",
  "school-signatures",
  "school-public-media",
]);

function locationKey(bucket: string, key: string): string {
  return `${bucket}\n${key}`;
}

function addStorageMapping(
  mapping: Map<string, StorageLocation>,
  sourceBucket: string,
  sourceKey: string,
  target: StorageLocation,
): void {
  const key = locationKey(sourceBucket, sourceKey);
  const existing = mapping.get(key);
  if (
    existing &&
    (existing.bucket !== target.bucket || existing.key !== target.key)
  ) {
    fail(`Conflicting verified Storage mapping for ${sourceBucket}/${sourceKey}`);
  }
  mapping.set(key, target);
}

function addStorageAlias(
  mapping: Map<string, StorageLocation>,
  sourceBucket: string,
  sourceKey: string,
  target: StorageLocation,
): void {
  const key = locationKey(sourceBucket, sourceKey);
  // Direct consolidated objects are canonical when the archive also contains
  // an R2 `legacy/` copy of the same logical path.
  if (!mapping.has(key)) mapping.set(key, target);
}

function selfHostedStorageMapping(state: State): Map<string, StorageLocation> {
  const mapping = new Map<string, StorageLocation>();

  // Register actual target locations first, so they take priority over aliases.
  for (const item of state.items) {
    if (item.status !== "verified") continue;
    const target = { bucket: item.bucket, key: item.key };
    addStorageMapping(mapping, item.bucket, item.key, target);
  }

  // Add compatibility aliases for legacy references. Duplicate legacy copies
  // are already byte-verified; preserve the first alias without replacing a
  // canonical direct mapping.
  for (const item of state.items) {
    if (item.status !== "verified" || item.source !== "r2") continue;
    const target = { bucket: item.bucket, key: item.key };

    if (item.key.startsWith("legacy/")) {
      const legacy = item.key.slice("legacy/".length);
      const slash = legacy.indexOf("/");
      if (slash > 0) {
        addStorageAlias(
          mapping,
          legacy.slice(0, slash),
          legacy.slice(slash + 1),
          target,
        );
      }
    }
    if (item.key.startsWith("website/")) {
      addStorageAlias(
        mapping,
        "school-public-media",
        item.key.slice("website/".length),
        target,
      );
    }
    const slash = item.key.indexOf("/");
    if (slash > 0 && LEGACY_REFERENCE_BUCKETS.has(item.key.slice(0, slash))) {
      addStorageAlias(
        mapping,
        item.key.slice(0, slash),
        item.key.slice(slash + 1),
        target,
      );
    }
  }
  return mapping;
}

async function withDatabase<T>(
  callback: (sql: DatabaseClient) => Promise<T>,
): Promise<T> {
  const databaseUrl = Deno.env.get("DATABASE_URL")?.trim();
  if (!databaseUrl) fail("Set DATABASE_URL in a protected environment");
  const postgres = (await import("npm:postgres@3.4.5")).default;
  const sql = postgres(databaseUrl, {
    max: 1,
    prepare: false,
    connect_timeout: 10,
  }) as DatabaseClient;
  try {
    return await callback(sql);
  } finally {
    await sql.end({ timeout: 5 }).catch(() => undefined);
  }
}

async function rewriteReferences(state: State): Promise<void> {
  if (state.items.some((item) => item.status !== "verified")) {
    fail(
      "Reference rewrite is blocked until every imported object is verified",
    );
  }
  const mapping = selfHostedStorageMapping(state);
  const verified = new Set(mapping.keys());
  const targets = new Set<string>();
  const plans: Array<
    {
      table: string;
      column: string;
      rowIdColumn: string;
      rowId: string;
      json: boolean;
      value: unknown;
      changes: RewriteChange[];
    }
  > = [];
  const unresolved: Array<
    { table: string; column: string; rowId: string; location: StorageLocation }
  > = [];
  const expectedBaseUrl = publicBaseUrl;

  await withDatabase(async (sql) => {
    const columns = await sql`
      select table_name, column_name
      from information_schema.columns
      where table_schema = 'public'
    ` as Array<{ table_name: string; column_name: string }>;
    const available = new Set(
      columns.map((item) => `${item.table_name}.${item.column_name}`),
    );
    for (const target of REFERENCE_TARGETS) {
      if (
        !available.has(`${target.table}.${target.column}`) ||
        !available.has(`${target.table}.${target.rowIdColumn}`)
      ) {
        fail(
          `Expected storage reference column is missing: ${target.table}.${target.column}`,
        );
      }
      const rows = await sql.unsafe(
        `select ${quoteIdentifier(target.rowIdColumn)}::text as "__row_id", ${
          quoteIdentifier(target.column)
        } as "__value" from public.${quoteIdentifier(target.table)} where ${
          quoteIdentifier(target.column)
        } is not null`,
      ) as TargetRow[];
      for (const row of rows) {
        const result = target.json
          ? rewriteSelfHostedJson(
            row.__value,
            target.defaultBucket,
            expectedBaseUrl,
            "$",
            mapping,
          )
          : typeof row.__value === "string"
          ? rewriteSelfHostedString(
            row.__value,
            target.defaultBucket,
            expectedBaseUrl,
            "$",
            mapping,
          )
          : { value: row.__value, changes: [], unresolved: [] };
        for (const location of result.unresolved) {
          unresolved.push({
            table: target.table,
            column: target.column,
            rowId: row.__row_id,
            location,
          });
        }
        for (const change of result.changes) {
          if (
            !verified.has(`${change.location.bucket}\n${change.location.key}`)
          ) {
            unresolved.push({
              table: target.table,
              column: target.column,
              rowId: row.__row_id,
              location: change.location,
            });
          }
        }
        if (result.changes.length) {
          targets.add(target.table);
          plans.push({
            table: target.table,
            column: target.column,
            rowIdColumn: target.rowIdColumn,
            rowId: row.__row_id,
            json: target.json,
            value: result.value,
            changes: result.changes,
          });
        }
      }
    }
  });

  if (unresolved.length) {
    const sample = unresolved.slice(0, 12).map((item) =>
      `${item.table}.${item.column}[${item.rowId}] -> ${item.location.bucket}/${item.location.key}`
    ).join("; ");
    fail(
      `Storage reference rewrite blocked by ${unresolved.length} unverified/unmapped references: ${sample}`,
    );
  }
  const summary = {
    mode: "rewrite",
    execute: hasFlag("--execute"),
    rows: plans.length,
    values: plans.reduce((count, plan) => count + plan.changes.length, 0),
    tables: [...targets].sort(),
  };
  console.log(JSON.stringify(summary, null, 2));
  if (!hasFlag("--execute")) return;
  if (
    Deno.env.get("SELF_HOSTED_STORAGE_REWRITE_CONFIRM") !==
      "schooldesk-self-hosted"
  ) {
    fail(
      "Set SELF_HOSTED_STORAGE_REWRITE_CONFIRM=schooldesk-self-hosted to authorize the database rewrite",
    );
  }

  await withDatabase((sql) =>
    sql.begin(async (transaction) => {
      for (const plan of plans) {
        const update = `update public.${quoteIdentifier(plan.table)} set ${
          quoteIdentifier(plan.column)
        } = $1${plan.json ? "::jsonb" : ""} where ${
          quoteIdentifier(plan.rowIdColumn)
        }::text = $2`;
        const value = plan.json
          ? JSON.stringify(plan.value)
          : String(plan.value ?? "");
        const rows = await transaction.unsafe(update, [value, plan.rowId]);
        if (rows.length !== 1) {
          fail(
            `Expected one row updated; got ${rows.length} for ${plan.table}.${plan.column}[${plan.rowId}]`,
          );
        }
      }
      return { changedRows: plans.length };
    })
  );
}

if (command === "inventory") {
  const state = await createState();
  await writeState(state);
  const bytes = state.items.reduce((sum, item) => sum + item.size, 0);
  console.log(JSON.stringify(
    {
      mode: "inventory",
      statePath,
      supabaseStorage: state.items.filter((item) =>
        item.source === "supabase"
      ).length,
      r2: state.items.filter((item) => item.source === "r2").length,
      objects: state.items.length,
      bytes,
    },
    null,
    2,
  ));
} else if (command === "copy") {
  if (!hasFlag("--execute")) {
    const state = await readState();
    console.log(JSON.stringify(
      {
        mode: "copy",
        execute: false,
        objects: state.items.length,
        bytes: state.items.reduce((sum, item) => sum + item.size, 0),
        note:
          "Pass --execute to create the two migration buckets and upload objects.",
      },
      null,
      2,
    ));
  } else {
    await importObjects(await readState());
  }
} else if (command === "verify") {
  await verifyObjects(await readState());
} else if (command === "rewrite") {
  await rewriteReferences(await readState());
} else if (command === "report") {
  const state = await readState();
  console.log(JSON.stringify(
    {
      mode: "report",
      objects: state.items.length,
      verified: state.items.filter((item) => item.status === "verified").length,
      failed: state.items.filter((item) => item.status === "failed").length,
      bytes: state.items.reduce((sum, item) => sum + item.size, 0),
    },
    null,
    2,
  ));
} else {
  fail(
    "Usage: self_hosted_storage.ts inventory|copy|verify|rewrite|report [--source-dir DIR] [--state FILE] [--execute]",
  );
}

/**
 * Resumable Supabase Storage -> Cloudflare R2 migration runner.
 *
 * Usage:
 *   npx -y deno run --allow-env --allow-net --allow-read --allow-write \
 *     scripts/storage_migration/r2_migrate.ts inventory --state ./storage-migration.json
 *   npx -y deno run --allow-env --allow-net --allow-read --allow-write \
 *     scripts/storage_migration/r2_migrate.ts copy --state ./storage-migration.json
 *   npx -y deno run --allow-env --allow-net --allow-read --allow-write \
 *     scripts/storage_migration/r2_migrate.ts verify --state ./storage-migration.json
 *
 * Required source variables:
 *   SOURCE_S3_ENDPOINT, SOURCE_S3_ACCESS_KEY_ID, SOURCE_S3_SECRET_ACCESS_KEY
 *   SOURCE_BUCKETS (bucket:private,bucket:public,...)
 *
 * Required R2 variables:
 *   R2_ENDPOINT, R2_PRIVATE_BUCKET, R2_PUBLIC_BUCKET
 *   R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY
 *
 * Optional:
 *   SOURCE_S3_REGION=auto, R2_REGION=auto, MIGRATION_CONCURRENCY=4
 *   DATABASE_URL (writes service-only migration tracking rows)
 */

import {
  REFERENCE_TARGETS,
  referenceKey,
  rewriteJson,
  rewriteString,
  r2ReferenceFor,
  type MigrationMapEntry,
  type ReferenceTarget,
  type StorageLocation,
} from "./storage_references.ts";

type Visibility = "private" | "public";

type S3Config = {
  endpoint: string;
  accessKeyId: string;
  secretAccessKey: string;
  region: string;
};

type MigrationItem = {
  sourceBucket: string;
  sourceKey: string;
  destinationBucket: string;
  destinationKey: string;
  visibility: Visibility;
  size: number;
  contentType: string;
  cacheControl: string;
  contentDisposition: string;
  metadata: Record<string, string>;
  status: "pending" | "copying" | "verified" | "failed";
  attempts: number;
  sourceSha256?: string;
  destinationSha256?: string;
  error?: string;
};

type MigrationState = {
  version: 1;
  createdAt: string;
  updatedAt: string;
  batchId?: string;
  items: MigrationItem[];
};

const MULTIPART_THRESHOLD_BYTES = 100 * 1024 * 1024;
const MULTIPART_PART_BYTES = 16 * 1024 * 1024;
const DEFAULT_TARGET_BYTES = 900_000_000;
const SOURCE_DELETE_GUARD = "ALLOW_SUPABASE_SOURCE_DELETE";

function required(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function numberEnv(name: string, fallback: number): number {
  const value = Number(Deno.env.get(name) ?? fallback);
  return Number.isFinite(value) && value > 0 ? Math.floor(value) : fallback;
}

function parseBuckets(): Array<{ name: string; visibility: Visibility }> {
  const raw = Deno.env.get("SOURCE_BUCKETS")?.trim() || [
    "school-assets:private",
    "school-private-files:private",
    "finance-documents:private",
    "payment-proofs:private",
    "issue-attachments:private",
    "help-tutorial-videos:private",
    "school-signatures:private",
    "school-public-media:public",
  ].join(",");
  return raw.split(",").map((entry) => {
    const [name, visibility] = entry.trim().split(":");
    if (!name || !["private", "public"].includes(visibility)) {
      throw new Error(`Invalid SOURCE_BUCKETS entry: ${entry}`);
    }
    return { name, visibility: visibility as Visibility };
  });
}

function endpointConfig(prefix: "SOURCE_S3" | "R2"): S3Config {
  return {
    endpoint: required(`${prefix}_ENDPOINT`).replace(/\/+$/, ""),
    accessKeyId: required(`${prefix}_ACCESS_KEY_ID`),
    secretAccessKey: required(`${prefix}_SECRET_ACCESS_KEY`),
    region: Deno.env.get(`${prefix}_REGION`)?.trim() || "auto",
  };
}

function destinationBucket(visibility: Visibility): string {
  return required(
    visibility === "public" ? "R2_PUBLIC_BUCKET" : "R2_PRIVATE_BUCKET",
  );
}

function objectVisibility(
  sourceBucket: string,
  sourceKey: string,
  fallback: Visibility,
): Visibility {
  // Legacy school-assets is mixed-use. Logos are explicitly public; profile
  // media, payment configuration, and generic objects remain private.
  if (sourceBucket === "school-assets" && /^logos\//i.test(sourceKey)) {
    return "public";
  }
  return fallback;
}

function destinationKey(
  sourceBucket: string,
  sourceKey: string,
  visibility: Visibility,
): string {
  const clean = sourceKey.replace(/^\/+/, "");
  if (visibility === "public" && sourceBucket === "school-public-media") {
    return `website/${clean}`;
  }
  return `legacy/${sourceBucket}/${clean}`;
}

function encodePath(value: string): string {
  return value.split("/").map((segment) => encodeURIComponent(segment)).join(
    "/",
  );
}

function awsEncode(value: string): string {
  return encodeURIComponent(value).replace(
    /[!'()*]/g,
    (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

function canonicalQuery(query: Record<string, string>): string {
  return Object.entries(query)
    .map(([name, value]) => [awsEncode(name), awsEncode(value)] as const)
    .sort(([leftName, leftValue], [rightName, rightValue]) =>
      leftName.localeCompare(rightName) || leftValue.localeCompare(rightValue)
    )
    .map(([name, value]) => `${name}=${value}`)
    .join("&");
}

function canonicalHeaders(headers: Record<string, string>) {
  const entries = Object.entries(headers)
    .map(([name, value]) =>
      [
        name.toLowerCase(),
        value.trim().replace(/\s+/g, " "),
      ] as const
    )
    .sort(([left], [right]) => left.localeCompare(right));
  return {
    signed: entries.map(([name]) => name).join(";"),
    value: entries.map(([name, value]) => `${name}:${value}\n`).join(""),
  };
}

function hex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join(
    "",
  );
}

function arrayBuffer(bytes: Uint8Array<ArrayBufferLike>): ArrayBuffer {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return copy.buffer;
}

async function sha256Async(bytes: Uint8Array): Promise<string> {
  return hex(
    new Uint8Array(await crypto.subtle.digest("SHA-256", arrayBuffer(bytes))),
  );
}

async function hmac(key: Uint8Array, value: string): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    arrayBuffer(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      cryptoKey,
      new TextEncoder().encode(value),
    ),
  );
}

function timestamp() {
  const value = new Date().toISOString().replace(/[-:]/g, "").replace(
    /\.\d{3}Z$/,
    "Z",
  );
  return { amzDate: value, dateStamp: value.slice(0, 8) };
}

async function signingKey(
  config: S3Config,
  dateStamp: string,
): Promise<Uint8Array> {
  const date = await hmac(
    new TextEncoder().encode(`AWS4${config.secretAccessKey}`),
    dateStamp,
  );
  const region = await hmac(date, config.region);
  const service = await hmac(region, "s3");
  return await hmac(service, "aws4_request");
}

class S3Client {
  constructor(private readonly config: S3Config) {}

  async request(
    method: string,
    bucket: string,
    key = "",
    query: Record<string, string> = {},
    extraHeaders: Record<string, string> = {},
    body: Uint8Array<ArrayBufferLike> = new Uint8Array(),
  ): Promise<Response> {
    const endpoint = new URL(this.config.endpoint);
    const base = endpoint.pathname.replace(/\/+$/, "");
    const path = `${base}/${encodeURIComponent(bucket)}${
      key ? `/${encodePath(key)}` : ""
    }`;
    const url = new URL(path, `${endpoint.protocol}//${endpoint.host}`);
    const { amzDate, dateStamp } = timestamp();
    const payloadHash = await sha256Async(body);
    const headers: Record<string, string> = {
      ...extraHeaders,
      host: url.host,
      "x-amz-content-sha256": payloadHash,
      "x-amz-date": amzDate,
    };
    const queryString = canonicalQuery(query);
    const canonical = canonicalHeaders(headers);
    const canonicalRequest = [
      method.toUpperCase(),
      url.pathname,
      queryString,
      canonical.value,
      canonical.signed,
      payloadHash,
    ].join("\n");
    const scope = `${dateStamp}/${this.config.region}/s3/aws4_request`;
    const stringToSign = [
      "AWS4-HMAC-SHA256",
      amzDate,
      scope,
      await sha256Async(new TextEncoder().encode(canonicalRequest)),
    ].join("\n");
    const signature = hex(
      await hmac(
        await signingKey(this.config, dateStamp),
        stringToSign,
      ),
    );
    const requestHeaders = new Headers();
    for (const [name, value] of Object.entries(headers)) {
      if (name !== "host") requestHeaders.set(name, value);
    }
    requestHeaders.set(
      "authorization",
      `AWS4-HMAC-SHA256 Credential=${this.config.accessKeyId}/${scope}, ` +
        `SignedHeaders=${canonical.signed}, Signature=${signature}`,
    );
    return await fetch(
      new URL(`${url.toString()}${queryString ? `?${queryString}` : ""}`),
      {
        method: method.toUpperCase(),
        headers: requestHeaders,
        body: ["GET", "HEAD"].includes(method.toUpperCase())
          ? undefined
          : arrayBuffer(body),
      },
    );
  }
}

function xmlValue(xml: string, tag: string): string {
  const match = xml.match(new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`));
  return match?.[1] ?? "";
}

function xmlBlocks(xml: string, tag: string): string[] {
  return [...xml.matchAll(new RegExp(`<${tag}>([\\s\\S]*?)</${tag}>`, "g"))]
    .map((match) => match[1]);
}

async function listObjects(
  client: S3Client,
  bucket: string,
): Promise<Array<{ key: string; size: number }>> {
  const objects: Array<{ key: string; size: number }> = [];
  let token = "";
  do {
    const response = await client.request(
      "GET",
      bucket,
      "",
      {
        "list-type": "2",
        "max-keys": "1000",
        ...(token ? { "continuation-token": token } : {}),
      },
    );
    if (!response.ok) {
      throw new Error(`List ${bucket} failed with HTTP ${response.status}`);
    }
    const xml = await response.text();
    for (const block of xmlBlocks(xml, "Contents")) {
      const key = xmlValue(block, "Key");
      if (key) {
        objects.push({ key, size: Number(xmlValue(block, "Size") || 0) });
      }
    }
    token = xmlValue(xml, "NextContinuationToken");
  } while (token);
  return objects;
}

async function objectMetadata(
  client: S3Client,
  bucket: string,
  key: string,
) {
  const response = await client.request("HEAD", bucket, key);
  if (!response.ok) {
    throw new Error(
      `HEAD ${bucket}/${key} failed with HTTP ${response.status}`,
    );
  }
  return {
    size: Number(response.headers.get("content-length") ?? 0),
    contentType: response.headers.get("content-type") ??
      "application/octet-stream",
    cacheControl: response.headers.get("cache-control") ?? "",
    contentDisposition: response.headers.get("content-disposition") ?? "",
    metadata: Object.fromEntries(
      [...response.headers.entries()].filter(([name]) =>
        name.toLowerCase().startsWith("x-amz-meta-")
      ),
    ),
  };
}

async function readState(path: string): Promise<MigrationState> {
  return JSON.parse(await Deno.readTextFile(path)) as MigrationState;
}

async function writeState(path: string, state: MigrationState) {
  state.updatedAt = new Date().toISOString();
  const temporary = `${path}.tmp`;
  await Deno.writeTextFile(temporary, JSON.stringify(state, null, 2));
  await Deno.rename(temporary, path);
}

/**
 * Copy workers share one resumable state file. Serialize persistence so two
 * workers cannot overwrite the same temporary file or race its rename.
 */
function createSerializedStateWriter() {
  let pending: Promise<void> = Promise.resolve();
  return async (path: string, state: MigrationState) => {
    const next = pending.then(() => writeState(path, state));
    pending = next.catch(() => undefined);
    await next;
  };
}

async function createDbBatch(
  mode: string,
  state: MigrationState,
): Promise<string | undefined> {
  const databaseUrl = Deno.env.get("DATABASE_URL")?.trim();
  if (!databaseUrl) return undefined;
  const postgres = (await import("npm:postgres@3.4.5")).default;
  const sql = postgres(databaseUrl, { max: 1 });
  const rows = await sql`
    insert into schooldesk_internal.storage_migration_batches (mode, status, started_at)
    values (${mode}, 'running', now())
    returning id
  `;
  await sql.end({ timeout: 1 });
  return rows[0]?.id as string | undefined;
}

async function syncDatabaseState(state: MigrationState, mode: string) {
  const databaseUrl = Deno.env.get("DATABASE_URL")?.trim();
  if (!databaseUrl || !state.batchId) return;
  const postgres = (await import("npm:postgres@3.4.5")).default;
  const sql = postgres(databaseUrl, { max: 1 });
  const items = state.items.map((item) => ({
    batch_id: state.batchId,
    source_bucket: item.sourceBucket,
    source_key: item.sourceKey,
    destination_bucket: item.destinationBucket,
    destination_key: item.destinationKey,
    visibility: item.visibility,
    status: item.status,
    attempts: item.attempts,
    source_size: item.size,
    destination_size: item.status === "verified" ? item.size : null,
    source_sha256: item.sourceSha256 ?? null,
    destination_sha256: item.destinationSha256 ?? null,
    metadata: JSON.stringify({
      content_type: item.contentType,
      cache_control: item.cacheControl,
      content_disposition: item.contentDisposition,
      ...item.metadata,
    }),
    error: item.error ?? null,
  }));
  const payload = JSON.stringify(items);
  const verified = state.items.filter((item) => item.status === "verified");
  const failed = state.items.filter((item) => item.status === "failed");
  try {
    await sql`
      insert into schooldesk_internal.storage_migration_items (
        batch_id, source_bucket, source_key, destination_bucket,
        destination_key, visibility, status, attempts, source_size,
        destination_size, source_sha256, destination_sha256, metadata,
        error, last_attempt_at, verified_at
      )
      select
        x.batch_id::uuid, x.source_bucket, x.source_key, x.destination_bucket,
        x.destination_key, x.visibility, x.status, x.attempts::integer,
        x.source_size::bigint, x.destination_size::bigint,
        x.source_sha256, x.destination_sha256, x.metadata::jsonb, x.error,
        case when x.attempts::integer > 0 then now() else null end,
        case when x.status = 'verified' then now() else null end
      from jsonb_to_recordset(${payload}::jsonb) as x(
        batch_id text, source_bucket text, source_key text,
        destination_bucket text, destination_key text, visibility text,
        status text, attempts text, source_size text, destination_size text,
        source_sha256 text, destination_sha256 text, metadata text, error text
      )
      on conflict (source_bucket, source_key) do update set
        batch_id = excluded.batch_id,
        destination_bucket = excluded.destination_bucket,
        destination_key = excluded.destination_key,
        visibility = excluded.visibility,
        status = excluded.status,
        attempts = excluded.attempts,
        source_size = excluded.source_size,
        destination_size = excluded.destination_size,
        source_sha256 = excluded.source_sha256,
        destination_sha256 = excluded.destination_sha256,
        metadata = excluded.metadata,
        error = excluded.error,
        updated_at = now(),
        last_attempt_at = excluded.last_attempt_at,
        verified_at = excluded.verified_at
    `;
    await sql`
      update schooldesk_internal.storage_migration_batches
      set status = ${failed.length > 0
        ? "failed"
        : verified.length === state.items.length
        ? "completed"
        : "running"},
        object_count = ${state.items.length},
        completed_count = ${verified.length},
        failed_count = ${failed.length},
        source_bytes = ${state.items.reduce((sum, item) => sum + item.size, 0)},
        destination_bytes = ${verified.reduce((sum, item) => sum + item.size, 0)},
        report = ${JSON.stringify({ mode, state_path: "external" })}::jsonb,
        completed_at = case when ${verified.length === state.items.length}
          then now() else null end,
        updated_at = now()
      where id = ${state.batchId}::uuid
    `;
  } finally {
    await sql.end({ timeout: 1 });
  }
}

type DatabaseClient = any;

type TargetRow = {
  __row_id: string;
  __value: unknown;
};

type PlannedRewrite = {
  target: ReferenceTarget;
  rowId: string;
  value: unknown;
  changes: Array<{
    path: string;
    source: string;
    target: string;
    location: StorageLocation;
  }>;
};

type SourceObject = {
  bucket: string;
  key: string;
  size: number;
};

function quoteIdentifier(value: string): string {
  if (!/^[a-z_][a-z0-9_]*$/i.test(value)) {
    throw new Error(`Unsafe SQL identifier: ${value}`);
  }
  return `"${value}"`;
}

async function withDatabase<T>(callback: (sql: DatabaseClient) => Promise<T>) {
  const databaseUrl = required("DATABASE_URL");
  const postgres = (await import("npm:postgres@3.4.5")).default;
  const sql = postgres(databaseUrl, {
    max: 1,
    prepare: false,
    idle_timeout: 0,
    connect_timeout: 10,
  });
  try {
    return await callback(sql);
  } finally {
    await sql.end({ timeout: 5 }).catch(() => undefined);
  }
}

async function availableReferenceTargets(sql: DatabaseClient) {
  const rows = await sql`
    select table_name, column_name
    from information_schema.columns
    where table_schema = 'public'
  ` as Array<{ table_name: string; column_name: string }>;
  const available = new Set(rows.map((row) => `${row.table_name}.${row.column_name}`));
  const missing = REFERENCE_TARGETS.filter((target) =>
    !available.has(`${target.table}.${target.column}`) ||
    !available.has(`${target.table}.${target.rowIdColumn}`)
  );
  if (missing.length > 0) {
    throw new Error(
      `Reference audit schema is incomplete; missing ${missing.map((target) =>
        `${target.table}.${target.column}/${target.rowIdColumn}`).join(", ")}`,
    );
  }
  return REFERENCE_TARGETS;
}

async function readReferenceRows(
  sql: DatabaseClient,
  target: ReferenceTarget,
): Promise<TargetRow[]> {
  const table = quoteIdentifier(target.table);
  const column = quoteIdentifier(target.column);
  const rowId = quoteIdentifier(target.rowIdColumn);
  const query = `select ${rowId}::text as "__row_id", ${column} as "__value"\n` +
    `from public.${table}\nwhere ${column} is not null`;
  return await sql.unsafe(query) as TargetRow[];
}

function migrationMap(
  state: MigrationState,
): ReadonlyMap<string, MigrationMapEntry> {
  const map = new Map<string, MigrationMapEntry>();
  for (const item of state.items) {
    map.set(referenceKey({ bucket: item.sourceBucket, key: item.sourceKey }), item);
  }
  return map;
}

function sourceLocationCount(
  value: unknown,
  target: ReferenceTarget,
  mapping: ReadonlyMap<string, MigrationMapEntry>,
) {
  const result = target.json
    ? rewriteJson(value, mapping, target.defaultBucket)
    : typeof value === "string"
    ? rewriteString(value, mapping, target.defaultBucket)
    : { changes: [], unresolved: [] };
  return result;
}

async function sha256Text(value: string): Promise<string> {
  return hex(
    new Uint8Array(
      await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(value),
      ),
    ),
  );
}

async function rewriteReferences(statePath: string, execute: boolean) {
  const state = await readState(statePath);
  const unverified = state.items.filter((item) => item.status !== "verified");
  if (unverified.length > 0) {
    throw new Error(
      `Reference rewrite blocked: ${unverified.length} migration objects are not verified`,
    );
  }
  const mapping = migrationMap(state);

  await withDatabase(async (sql) => {
    const targets = await availableReferenceTargets(sql);
    const plans: PlannedRewrite[] = [];
    const unresolved: Array<{ target: ReferenceTarget; rowId: string; location: StorageLocation }> = [];

    for (const target of targets) {
      for (const row of await readReferenceRows(sql, target)) {
        const result = sourceLocationCount(row.__value, target, mapping);
        if (result.unresolved.length > 0) {
          unresolved.push(...result.unresolved.map((location) => ({
            target,
            rowId: row.__row_id,
            location,
          })));
        }
        if (result.changes.length === 0) continue;
        const rewritten = target.json
          ? rewriteJson(row.__value, mapping, target.defaultBucket)
          : rewriteString(`${row.__value}`, mapping, target.defaultBucket);
        plans.push({
          target,
          rowId: row.__row_id,
          value: rewritten.value,
          changes: rewritten.changes,
        });
      }
    }

    if (unresolved.length > 0) {
      const sample = unresolved.slice(0, 10).map((item) =>
        `${item.target.table}.${item.target.column}[${item.rowId}] -> ${item.location.bucket}/${item.location.key}`
      ).join("; ");
      throw new Error(
        `Reference rewrite blocked: ${unresolved.length} legacy references have no verified R2 mapping. ${sample}`,
      );
    }

    const summary = {
      mode: "rewrite",
      execute,
      rows: plans.length,
      values: plans.reduce((count, plan) => count + plan.changes.length, 0),
      tables: [...new Set(plans.map((plan) => plan.target.table))].sort(),
    };
    console.log(JSON.stringify(summary, null, 2));
    if (!execute || plans.length === 0) return;

    const batchRows = await sql`
      insert into schooldesk_internal.storage_migration_batches
        (mode, status, started_at, object_count, report)
      values
        ('rewrite', 'running', now(), ${plans.length}, ${sql.json(summary)})
      returning id
    ` as Array<{ id: string }>;
    const batchId = batchRows[0]?.id;
    if (!batchId) throw new Error("Failed to create rewrite audit batch");

    try {
      for (const plan of plans) {
        const setColumn = quoteIdentifier(plan.target.column);
        const rowColumn = quoteIdentifier(plan.target.rowIdColumn);
        const update = `update public.${quoteIdentifier(plan.target.table)}\n` +
          `set ${setColumn} = $1${plan.target.json ? "::jsonb" : ""}\n` +
          `where ${rowColumn}::text = $2\nreturning ${rowColumn}`;
        const encodedValue = plan.target.json
          ? JSON.stringify(plan.value)
          : `${plan.value ?? ""}`;

        for (const change of plan.changes) {
          const rewriteKey = await sha256Text([
            plan.target.table,
            plan.rowId,
            plan.target.column,
            change.path,
            change.source,
          ].join("\n"));
          await sql`
            insert into schooldesk_internal.storage_migration_rewrites
              (batch_id, rewrite_key, table_name, row_id, column_name,
               json_path, source_value, target_value, status)
            values
              (${batchId}, ${rewriteKey}, ${plan.target.table}, ${plan.rowId},
               ${plan.target.column}, ${change.path}, ${change.source},
               ${change.target}, 'pending')
            on conflict (rewrite_key) do update set
              batch_id = excluded.batch_id,
              target_value = excluded.target_value,
              status = 'pending',
              error = null,
              updated_at = now(),
              applied_at = null,
              rolled_back_at = null
          `;
        }

        const updatedRows = await sql.unsafe(update, [encodedValue, plan.rowId]);
        if (updatedRows.length !== 1) {
          throw new Error(
            `Rewrite update affected ${updatedRows.length} rows for ${plan.target.table}.${plan.target.column}[${plan.rowId}]`,
          );
        }
        for (const change of plan.changes) {
          const rewriteKey = await sha256Text([
            plan.target.table,
            plan.rowId,
            plan.target.column,
            change.path,
            change.source,
          ].join("\n"));
          await sql`
            update schooldesk_internal.storage_migration_rewrites
            set status = 'applied', applied_at = now(), updated_at = now()
            where rewrite_key = ${rewriteKey}
          `;
        }
      }
      await sql`
        update schooldesk_internal.storage_migration_batches
        set status = 'completed', completed_at = now(), completed_count = ${plans.length},
            report = ${sql.json(summary)}, updated_at = now()
        where id = ${batchId}::uuid
      `;
      console.log(JSON.stringify({ rewriteBatchId: batchId, status: "completed" }));
    } catch (error) {
      await sql`
        update schooldesk_internal.storage_migration_batches
        set status = 'failed', report = ${sql.json({ ...summary, error: `${error}` })},
            updated_at = now()
        where id = ${batchId}::uuid
      `;
      throw error;
    }
  });
}

async function collectLiveLegacyReferences(sql: DatabaseClient) {
  const targets = await availableReferenceTargets(sql);
  const references = new Map<string, number>();
  for (const target of targets) {
    for (const row of await readReferenceRows(sql, target)) {
      const result = sourceLocationCount(row.__value, target, new Map());
      for (const location of result.unresolved) {
        const key = referenceKey(location);
        references.set(key, (references.get(key) ?? 0) + 1);
      }
    }
  }
  return references;
}

async function currentSourceInventory(source: S3Client): Promise<SourceObject[]> {
  const objects: SourceObject[] = [];
  for (const bucket of parseBuckets()) {
    for (const object of await listObjects(source, bucket.name)) {
      objects.push({ bucket: bucket.name, key: object.key, size: object.size });
    }
  }
  return objects;
}

function cleanupSelection(
  objects: SourceObject[],
  liveReferences: ReadonlyMap<string, number>,
  mapping: ReadonlyMap<string, MigrationMapEntry>,
  targetBytes: number,
  allowReferenced = false,
) {
  const sourceBytes = objects.reduce((sum, object) => sum + object.size, 0);
  const candidates = objects.flatMap((object) => {
    const location = { bucket: object.bucket, key: object.key };
    const map = mapping.get(referenceKey(location));
    const liveReferenceCount = liveReferences.get(referenceKey(location)) ?? 0;
    if (liveReferenceCount > 0 && !allowReferenced) return [];
    const r2Reference = r2ReferenceFor(location, mapping);
    if (!map || !r2Reference) return [];
    return [{
      ...object,
      r2Reference,
      liveReferenceCount,
    }];
  });
  const needed = Math.max(0, sourceBytes - targetBytes);
  let selectedBytes = 0;
  const selected = [...candidates].sort((left, right) => right.size - left.size)
    .filter((candidate) => {
      if (selectedBytes >= needed) return false;
      selectedBytes += candidate.size;
      return true;
    });
  return {
    sourceBytes,
    protectedBytes: objects.filter((object) =>
      (liveReferences.get(referenceKey({ bucket: object.bucket, key: object.key })) ?? 0) > 0
    ).reduce((sum, object) => sum + object.size, 0),
    unmappedBytes: objects.filter((object) =>
      !mapping.has(referenceKey({ bucket: object.bucket, key: object.key }))
    ).reduce((sum, object) => sum + object.size, 0),
    candidates,
    selected,
    targetBytes,
    projectedBytes: Math.max(0, sourceBytes - selectedBytes),
  };
}

async function cleanupDryRun(
  statePath: string,
  targetBytes: number,
  allowReferenced: boolean,
) {
  const state = await readState(statePath);
  const mapping = migrationMap(state);
  const source = new S3Client(endpointConfig("SOURCE_S3"));
  const objects = await currentSourceInventory(source);
  const selection = await withDatabase((sql) =>
    collectLiveLegacyReferences(sql).then((liveReferences) => ({
      liveReferences,
      ...cleanupSelection(
        objects,
        liveReferences,
        mapping,
        targetBytes,
        allowReferenced,
      ),
    }))
  );

  const batch = await withDatabase(async (sql) => {
    const rows = await sql`
      insert into schooldesk_internal.storage_source_cleanup_batches
        (status, target_bytes, source_bytes_before, candidate_bytes, report)
      values
        ('dry_run', ${targetBytes}, ${selection.sourceBytes},
         ${selection.selected.reduce((sum, item) => sum + item.size, 0)},
        ${sql.json({
           allowReferenced,
           policy: allowReferenced
             ? "largest_verified_r2_backed_objects_including_live_references"
             : "verified_r2_backed_orphans_only",
           selected: selection.selected.length,
           candidates: selection.candidates.length,
           protectedBytes: selection.protectedBytes,
           unmappedBytes: selection.unmappedBytes,
           projectedBytes: selection.projectedBytes,
         })})
      returning id
    ` as Array<{ id: string }>;
    const batchId = rows[0]?.id;
    if (!batchId) throw new Error("Failed to create cleanup dry-run batch");
    for (const item of selection.selected) {
      const reason = item.liveReferenceCount > 0
        ? "user_approved_referenced_delete_largest_first"
        : "orphaned_source_after_verified_r2_copy";
      await sql`
        insert into schooldesk_internal.storage_source_cleanup_items
      (batch_id, source_bucket, source_key, r2_reference, source_size,
           live_reference_count, reason, status)
        values
          (${batchId}, ${item.bucket}, ${item.key}, ${item.r2Reference}, ${item.size},
           ${item.liveReferenceCount ?? 0}, ${reason}, 'pending')
        on conflict (batch_id, source_bucket, source_key) do nothing
      `;
      const storageRef = `supabase://${item.bucket}/${item.key}`;
      await sql`
        insert into public.storage_cleanup_queue
          (storage_ref, provider, source_bucket, source_key, destination_ref,
           reason, status, attempts, available_at, updated_at)
        values
          (${storageRef}, 'supabase_storage', ${item.bucket}, ${item.key},
           ${item.r2Reference}, ${reason}, 'pending', 0, now(), now())
        on conflict (storage_ref) do nothing
      `;
    }
    return batchId;
  });

  console.log(JSON.stringify({
    mode: "cleanup",
    dryRun: true,
    batchId: batch,
    sourceBytes: selection.sourceBytes,
    sourceMegabytes: Number((selection.sourceBytes / 1_000_000).toFixed(2)),
    targetBytes,
    targetMegabytes: Number((targetBytes / 1_000_000).toFixed(2)),
    candidateObjects: selection.candidates.length,
    selectedObjects: selection.selected.length,
    selectedBytes: selection.selected.reduce((sum, item) => sum + item.size, 0),
    projectedBytes: selection.projectedBytes,
    protectedBytes: selection.protectedBytes,
    unmappedBytes: selection.unmappedBytes,
  }, null, 2));
}

async function cleanupExecute(batchId: string) {
  if (Deno.env.get(SOURCE_DELETE_GUARD) !== "1") {
    throw new Error(
      `Source deletion is blocked. Set ${SOURCE_DELETE_GUARD}=1 only for an approved dry-run batch.`,
    );
  }
  const source = new S3Client(endpointConfig("SOURCE_S3"));
  const destination = new S3Client(endpointConfig("R2"));
  await withDatabase(async (sql) => {
    const batches = await sql`
      select id, status, target_bytes, source_bytes_before, report
      from schooldesk_internal.storage_source_cleanup_batches
      where id = ${batchId}::uuid
    ` as Array<{
      id: string;
      status: string;
      target_bytes: number;
      source_bytes_before: number;
      report: { allowReferenced?: boolean };
    }>;
    const batch = batches[0];
    if (!batch) throw new Error(`Cleanup batch not found: ${batchId}`);
    if (batch.status !== "dry_run" && batch.status !== "approved") {
      throw new Error(`Cleanup batch ${batchId} is not executable: ${batch.status}`);
    }
    const allowReferenced = batch.report?.allowReferenced === true;
    if (
      allowReferenced &&
      Deno.env.get("ALLOW_SUPABASE_REFERENCED_SOURCE_DELETE") !== "1"
    ) {
      throw new Error(
        "Referenced-source deletion is blocked. Set ALLOW_SUPABASE_REFERENCED_SOURCE_DELETE=1 only for an approved batch.",
      );
    }
    const items = await sql`
      select id, source_bucket, source_key, r2_reference, source_size
      from schooldesk_internal.storage_source_cleanup_items
      where batch_id = ${batchId}::uuid and status = 'pending'
      order by source_size desc, id
    ` as Array<{
      id: string;
      source_bucket: string;
      source_key: string;
      r2_reference: string;
      source_size: number;
    }>;
    const liveReferences = await collectLiveLegacyReferences(sql);
    let deletedCount = 0;
    let deletedBytes = 0;
    let failedCount = 0;
    await sql`
      update schooldesk_internal.storage_source_cleanup_batches
      set status = 'running', updated_at = now()
      where id = ${batchId}::uuid
    `;

    for (const item of items) {
      const location = { bucket: item.source_bucket, key: item.source_key };
      const liveCount = liveReferences.get(referenceKey(location)) ?? 0;
      if (liveCount > 0 && !allowReferenced) {
        await sql`
          update schooldesk_internal.storage_source_cleanup_items
          set status = 'skipped', live_reference_count = ${liveCount},
              error = 'reference appeared after dry-run', updated_at = now()
          where id = ${item.id}::uuid
        `;
        await sql`
          update public.storage_cleanup_queue
          set status = 'failed', last_error = 'source cleanup skipped: live reference appeared', updated_at = now()
          where storage_ref = ${`supabase://${item.source_bucket}/${item.source_key}`}
        `;
        continue;
      }

      try {
        const [sourceResponse, destinationResponse] = await Promise.all([
          source.request("GET", item.source_bucket, item.source_key),
          destination.request(
            "GET",
            item.r2_reference.startsWith("r2://private/")
              ? required("R2_PRIVATE_BUCKET")
              : required("R2_PUBLIC_BUCKET"),
            item.r2_reference.replace(/^r2:\/\/(private|public)\//, ""),
          ),
        ]);
        if (!sourceResponse.ok || !destinationResponse.ok) {
          throw new Error(
            `integrity read failed source=${sourceResponse.status} r2=${destinationResponse.status}`,
          );
        }
        const [sourceBytes, destinationBytes] = await Promise.all([
          new Uint8Array(await sourceResponse.arrayBuffer()),
          new Uint8Array(await destinationResponse.arrayBuffer()),
        ]);
        const [sourceHash, destinationHash] = await Promise.all([
          sha256Async(sourceBytes),
          sha256Async(destinationBytes),
        ]);
        if (sourceHash !== destinationHash) {
          throw new Error("source/R2 SHA-256 mismatch; deletion blocked");
        }
        const deleted = await source.request("DELETE", item.source_bucket, item.source_key);
        if (!deleted.ok && deleted.status !== 404) {
          throw new Error(`source delete failed with HTTP ${deleted.status}`);
        }
        const afterDelete = await source.request(
          "HEAD",
          item.source_bucket,
          item.source_key,
        );
        if (afterDelete.status !== 404) {
          throw new Error(
            `source post-delete verification failed with HTTP ${afterDelete.status}`,
          );
        }
        await sql`
          update schooldesk_internal.storage_source_cleanup_items
          set status = 'deleted', source_sha256 = ${sourceHash},
              destination_sha256 = ${destinationHash}, deleted_at = now(), updated_at = now()
          where id = ${item.id}::uuid
        `;
        await sql`
          update public.storage_cleanup_queue
          set status = 'completed', updated_at = now()
          where storage_ref = ${`supabase://${item.source_bucket}/${item.source_key}`}
        `;
        deletedCount += 1;
        deletedBytes += item.source_size;
      } catch (error) {
        failedCount += 1;
        await sql`
          update schooldesk_internal.storage_source_cleanup_items
          set status = 'failed', error = ${`${error}`}, updated_at = now()
          where id = ${item.id}::uuid
        `;
        await sql`
          update public.storage_cleanup_queue
          set status = 'failed', last_error = ${`${error}`}, updated_at = now()
          where storage_ref = ${`supabase://${item.source_bucket}/${item.source_key}`}
        `;
      }
    }

    const remaining = await currentSourceInventory(source);
    const remainingBytes = remaining.reduce((sum, item) => sum + item.size, 0);
    await sql`
      update schooldesk_internal.storage_source_cleanup_batches
      set status = ${failedCount > 0 ? "failed" : "completed"},
          source_bytes_after = ${remainingBytes}, deleted_count = ${deletedCount},
          failed_count = ${failedCount}, completed_at = now(), updated_at = now(),
          report = ${sql.json({ deletedCount, deletedBytes, remainingBytes })}
      where id = ${batchId}::uuid
    `;
    console.log(JSON.stringify({
      mode: "cleanup",
      dryRun: false,
      batchId,
      deletedCount,
      deletedBytes,
      remainingBytes,
      targetBytes: batch.target_bytes,
      failedCount,
    }, null, 2));
    if (failedCount > 0) Deno.exitCode = 1;
  });
}

async function inventory(statePath: string) {
  const source = new S3Client(endpointConfig("SOURCE_S3"));
  const items: MigrationItem[] = [];
  for (const bucket of parseBuckets()) {
    const objects = await listObjects(source, bucket.name);
    for (const object of objects) {
      const visibility = objectVisibility(bucket.name, object.key, bucket.visibility);
      const metadata = await objectMetadata(source, bucket.name, object.key);
      items.push({
        sourceBucket: bucket.name,
        sourceKey: object.key,
        destinationBucket: destinationBucket(visibility),
        destinationKey: destinationKey(
          bucket.name,
          object.key,
          visibility,
        ),
        visibility,
        size: metadata.size || object.size,
        contentType: metadata.contentType,
        cacheControl: metadata.cacheControl,
        contentDisposition: metadata.contentDisposition,
        metadata: metadata.metadata,
        status: "pending",
        attempts: 0,
      });
    }
  }
  const state: MigrationState = {
    version: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    items,
  };
  state.batchId = await createDbBatch("inventory", state);
  await writeState(statePath, state);
  await syncDatabaseState(state, "inventory");
  console.log(
    JSON.stringify(
      {
        mode: "inventory",
        statePath,
        batchId: state.batchId,
        objects: items.length,
      },
      null,
      2,
    ),
  );
}

async function putObject(
  destination: S3Client,
  item: MigrationItem,
  bytes: Uint8Array,
  headers: Record<string, string>,
) {
  if (bytes.byteLength <= MULTIPART_THRESHOLD_BYTES) {
    const response = await destination.request(
      "PUT",
      item.destinationBucket,
      item.destinationKey,
      {},
      headers,
      bytes,
    );
    if (!response.ok) {
      throw new Error(`PUT destination failed with HTTP ${response.status}`);
    }
    return;
  }

  const initiate = await destination.request(
    "POST",
    item.destinationBucket,
    item.destinationKey,
    { uploads: "" },
    headers,
  );
  if (!initiate.ok) {
    throw new Error(
      `Create multipart upload failed with HTTP ${initiate.status}`,
    );
  }
  const uploadId = xmlValue(await initiate.text(), "UploadId");
  if (!uploadId) throw new Error("R2 did not return a multipart upload id");

  const parts: Array<{ number: number; etag: string }> = [];
  try {
    let number = 1;
    for (
      let offset = 0;
      offset < bytes.byteLength;
      offset += MULTIPART_PART_BYTES
    ) {
      const part = bytes.slice(
        offset,
        Math.min(offset + MULTIPART_PART_BYTES, bytes.byteLength),
      );
      const response = await destination.request(
        "PUT",
        item.destinationBucket,
        item.destinationKey,
        { partNumber: `${number}`, uploadId },
        headers,
        part,
      );
      if (!response.ok) {
        throw new Error(
          `Upload part ${number} failed with HTTP ${response.status}`,
        );
      }
      const etag = response.headers.get("etag")?.replace(/^"|"$/g, "") ?? "";
      if (!etag) {
        throw new Error(`Upload part ${number} did not return an ETag`);
      }
      parts.push({ number, etag });
      number += 1;
    }
    const completeXml = [
      "<CompleteMultipartUpload>",
      ...parts.map((part) =>
        `<Part><PartNumber>${part.number}</PartNumber><ETag>\"${part.etag}\"</ETag></Part>`
      ),
      "</CompleteMultipartUpload>",
    ].join("");
    const complete = await destination.request(
      "POST",
      item.destinationBucket,
      item.destinationKey,
      { uploadId },
      { "content-type": "application/xml" },
      new TextEncoder().encode(completeXml),
    );
    if (!complete.ok) {
      throw new Error(
        `Complete multipart upload failed with HTTP ${complete.status}`,
      );
    }
  } catch (error) {
    await destination.request(
      "DELETE",
      item.destinationBucket,
      item.destinationKey,
      { uploadId },
    ).catch(() => undefined);
    throw error;
  }
}

async function transferOne(
  source: S3Client,
  destination: S3Client,
  item: MigrationItem,
) {
  const sourceResponse = await source.request(
    "GET",
    item.sourceBucket,
    item.sourceKey,
  );
  if (!sourceResponse.ok) {
    throw new Error(`GET source failed with HTTP ${sourceResponse.status}`);
  }
  const bytes = new Uint8Array(
    await sourceResponse.arrayBuffer(),
  ) as Uint8Array<ArrayBuffer>;
  item.sourceSha256 = await sha256Async(bytes);
  const headers: Record<string, string> = {
    "content-type": item.contentType,
  };
  if (item.cacheControl) headers["cache-control"] = item.cacheControl;
  if (item.contentDisposition) {
    headers["content-disposition"] = item.contentDisposition;
  }
  for (const [name, value] of Object.entries(item.metadata)) {
    headers[name] = value;
  }
  await putObject(destination, item, bytes, headers);
  const destinationResponse = await destination.request(
    "GET",
    item.destinationBucket,
    item.destinationKey,
  );
  if (!destinationResponse.ok) {
    throw new Error("Destination verification download failed");
  }
  item.destinationSha256 = await sha256Async(
    new Uint8Array(await destinationResponse.arrayBuffer()),
  );
  if (item.sourceSha256 !== item.destinationSha256) {
    throw new Error("SHA-256 verification failed");
  }
  item.status = "verified";
  item.error = undefined;
}

async function copy(statePath: string) {
  const state = await readState(statePath);
  const source = new S3Client(endpointConfig("SOURCE_S3"));
  const destination = new S3Client(endpointConfig("R2"));
  const queue = state.items.filter((item) => item.status !== "verified");
  const concurrency = numberEnv("MIGRATION_CONCURRENCY", 4);
  let cursor = 0;
  const retries = numberEnv("MIGRATION_RETRIES", 3);
  const persistState = createSerializedStateWriter();
  const wait = (milliseconds: number) =>
    new Promise((resolve) => setTimeout(resolve, milliseconds));
  async function worker() {
    while (cursor < queue.length) {
      const item = queue[cursor++];
      for (let attempt = 1; attempt <= retries; attempt += 1) {
        item.status = "copying";
        item.attempts += 1;
        try {
          await transferOne(source, destination, item);
          break;
        } catch (error) {
          item.status = "failed";
          item.error = `${error}`;
          if (attempt < retries) await wait(Math.min(30_000, attempt * 1_000));
        }
      }
      await persistState(statePath, state);
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(concurrency, queue.length) }, worker),
  );
  await syncDatabaseState(state, "copy");
  const failed = state.items.filter((item) => item.status === "failed").length;
  console.log(
    JSON.stringify(
      { mode: "copy", statePath, objects: state.items.length, failed },
      null,
      2,
    ),
  );
  if (failed > 0) Deno.exitCode = 1;
}

async function verify(statePath: string) {
  const state = await readState(statePath);
  const source = new S3Client(endpointConfig("SOURCE_S3"));
  const destination = new S3Client(endpointConfig("R2"));
  const queue = state.items.filter((item) => item.status === "verified");
  for (const item of queue) {
    const [sourceResponse, destinationResponse] = await Promise.all([
      source.request("GET", item.sourceBucket, item.sourceKey),
      destination.request("GET", item.destinationBucket, item.destinationKey),
    ]);
    if (!sourceResponse.ok || !destinationResponse.ok) {
      item.status = "failed";
      item.error = "verify download failed";
      continue;
    }
    const [sourceHash, destinationHash] = await Promise.all([
      sha256Async(new Uint8Array(await sourceResponse.arrayBuffer())),
      sha256Async(new Uint8Array(await destinationResponse.arrayBuffer())),
    ]);
    item.sourceSha256 = sourceHash;
    item.destinationSha256 = destinationHash;
    if (sourceHash !== destinationHash) {
      item.status = "failed";
      item.error = "SHA-256 verification failed";
    }
  }
  await writeState(statePath, state);
  await syncDatabaseState(state, "verify");
  const failed = state.items.filter((item) => item.status === "failed").length;
  console.log(
    JSON.stringify(
      { mode: "verify", statePath, objects: state.items.length, failed },
      null,
      2,
    ),
  );
  if (failed > 0) Deno.exitCode = 1;
}

async function report(statePath: string) {
  const state = await readState(statePath);
  const report = state.items.reduce((summary, item) => {
    summary.objects += 1;
    summary.sourceBytes += item.size;
    if (item.status === "verified") summary.verified += 1;
    if (item.status === "failed") summary.failed += 1;
    if (
      item.sourceSha256 && item.destinationSha256 &&
      item.sourceSha256 !== item.destinationSha256
    ) {
      summary.hashMismatches += 1;
    }
    return summary;
  }, { objects: 0, sourceBytes: 0, verified: 0, failed: 0, hashMismatches: 0 });
  console.log(
    JSON.stringify({ ...report, statePath, batchId: state.batchId }, null, 2),
  );
}

const command = Deno.args[0] || "report";
const stateIndex = Deno.args.indexOf("--state");
const statePath = stateIndex >= 0
  ? Deno.args[stateIndex + 1]
  : "storage-migration.json";
if (!statePath) throw new Error("--state requires a file path");
const execute = Deno.args.includes("--execute");
const allowReferenced = Deno.args.includes("--include-referenced");
const batchIndex = Deno.args.indexOf("--batch");
const batchId = batchIndex >= 0 ? Deno.args[batchIndex + 1] : "";
const targetIndex = Deno.args.indexOf("--target-bytes");
const targetBytes = targetIndex >= 0
  ? Number(Deno.args[targetIndex + 1])
  : DEFAULT_TARGET_BYTES;
if (!Number.isSafeInteger(targetBytes) || targetBytes <= 0) {
  throw new Error("--target-bytes must be a positive safe integer");
}

switch (command) {
  case "inventory":
    await inventory(statePath);
    break;
  case "copy":
    await copy(statePath);
    break;
  case "verify":
    await verify(statePath);
    break;
  case "rewrite":
    await rewriteReferences(statePath, execute);
    break;
  case "cleanup":
    if (execute) {
      if (!batchId) throw new Error("cleanup --execute requires --batch <dry-run-id>");
      await cleanupExecute(batchId);
    } else {
      await cleanupDryRun(statePath, targetBytes, allowReferenced);
    }
    break;
  case "report":
    await report(statePath);
    break;
  default:
    throw new Error(
      `Unknown command ${command}; use inventory, copy, verify, rewrite, cleanup, or report`,
    );
}

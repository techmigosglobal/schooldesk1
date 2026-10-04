#!/usr/bin/env -S deno run --allow-env --allow-net --allow-read --allow-write

/**
 * Recover currently referenced R2 objects absent from a dated media archive.
 * This only downloads source bytes and appends pending items to the
 * self-hosted importer state. It never writes to or deletes the R2 source.
 */
import postgres from "npm:postgres@3.4.5";

type RecoveredItem = {
  source: "r2";
  bucket: string;
  key: string;
  size: number;
  sha256: string;
  contentType: string;
  relativePath: string;
  status: "pending";
};

type State = {
  schemaVersion: 1;
  createdAt: string;
  sourceDir: string;
  items: Array<Record<string, unknown>>;
};

type S3Config = {
  endpoint: string;
  accessKeyId: string;
  secretAccessKey: string;
  region: string;
};

const statePath = option("--state") ??
  ".local/self-hosted-storage/rehearsal-state.json";
const execute = Deno.args.includes("--execute");

function option(name: string): string | undefined {
  const index = Deno.args.indexOf(name);
  return index >= 0 ? Deno.args[index + 1] : undefined;
}

function required(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function config(): S3Config {
  return {
    endpoint: required("R2_ENDPOINT").replace(/\/+$/, ""),
    accessKeyId: required("R2_ACCESS_KEY_ID"),
    secretAccessKey: required("R2_SECRET_ACCESS_KEY"),
    region: Deno.env.get("R2_REGION")?.trim() || "auto",
  };
}

function encodePath(value: string): string {
  return value.split("/").map((part) => encodeURIComponent(part)).join("/");
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
    .map(([name, value]) => [
      name.toLowerCase(),
      value.trim().replace(/\s+/g, " "),
    ] as const)
    .sort(([left], [right]) => left.localeCompare(right));
  return {
    signed: entries.map(([name]) => name).join(";"),
    value: entries.map(([name, value]) => `${name}:${value}\n`).join(""),
  };
}

function hex(bytes: Uint8Array): string {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function buffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return copy.buffer;
}

async function sha256(bytes: Uint8Array): Promise<string> {
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", buffer(bytes))));
}

async function hmac(key: Uint8Array, value: string): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    buffer(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(
    await crypto.subtle.sign("HMAC", cryptoKey, new TextEncoder().encode(value)),
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
  source: S3Config,
  dateStamp: string,
): Promise<Uint8Array> {
  const date = await hmac(
    new TextEncoder().encode(`AWS4${source.secretAccessKey}`),
    dateStamp,
  );
  const region = await hmac(date, source.region);
  const service = await hmac(region, "s3");
  return await hmac(service, "aws4_request");
}

async function sourceGet(
  source: S3Config,
  bucket: string,
  key: string,
): Promise<Response> {
  const endpoint = new URL(source.endpoint);
  const base = endpoint.pathname.replace(/\/+$/, "");
  const path = `${base}/${encodeURIComponent(bucket)}/${encodePath(key)}`;
  const url = new URL(path, `${endpoint.protocol}//${endpoint.host}`);
  const { amzDate, dateStamp } = timestamp();
  const emptyHash = await sha256(new Uint8Array());
  const headers: Record<string, string> = {
    host: url.host,
    "x-amz-content-sha256": emptyHash,
    "x-amz-date": amzDate,
  };
  const canonical = canonicalHeaders(headers);
  const canonicalRequest = [
    "GET",
    url.pathname,
    "",
    canonical.value,
    canonical.signed,
    emptyHash,
  ].join("\n");
  const scope = `${dateStamp}/${source.region}/s3/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    scope,
    await sha256(new TextEncoder().encode(canonicalRequest)),
  ].join("\n");
  const signature = hex(await hmac(await signingKey(source, dateStamp), stringToSign));
  const requestHeaders = new Headers({
    "x-amz-content-sha256": emptyHash,
    "x-amz-date": amzDate,
    authorization:
      `AWS4-HMAC-SHA256 Credential=${source.accessKeyId}/${scope}, ` +
      `SignedHeaders=${canonical.signed}, Signature=${signature}`,
  });
  return await fetch(url, { headers: requestHeaders });
}

function extensionMime(key: string): string {
  const extension = key.split(".").pop()?.toLowerCase() ?? "";
  return {
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    png: "image/png",
    pdf: "application/pdf",
    mp4: "video/mp4",
    webm: "video/webm",
  }[extension] ?? "application/octet-stream";
}

function parseR2Reference(value: string): { bucket: string; key: string } | null {
  const match = value.match(/^r2:\/\/(private|public)\/(.+)$/);
  if (!match) return null;
  return {
    bucket: match[1] === "private"
      ? required("R2_PRIVATE_BUCKET")
      : required("R2_PUBLIC_BUCKET"),
    key: match[2],
  };
}

async function readState(): Promise<State> {
  return JSON.parse(await Deno.readTextFile(statePath)) as State;
}

async function writeState(state: State): Promise<void> {
  const temporary = `${statePath}.recover.tmp`;
  await Deno.writeTextFile(temporary, JSON.stringify(state, null, 2));
  await Deno.chmod(temporary, 0o600);
  await Deno.rename(temporary, statePath);
}

const state = await readState();
const databaseUrl = required("DATABASE_URL");
const sql = postgres(databaseUrl, { max: 1, prepare: false });
const rows = await sql`
  select url
  from public.uploaded_files
  where url like 'r2://%'
` as Array<{ url: string }>;
await sql.end({ timeout: 5 });

const existing = new Set(
  state.items
    .filter((item) => item.status === "verified")
    .map((item) => `${item.bucket}\n${item.key}`),
);
const references = new Map<string, { bucket: string; key: string }>();
for (const row of rows) {
  const location = parseR2Reference(row.url);
  if (location) references.set(`${location.bucket}\n${location.key}`, location);
}
const missing = [...references.values()].filter((item) =>
  !existing.has(`${item.bucket}\n${item.key}`)
);

console.log(JSON.stringify({ mode: "r2-recovery", execute, missing: missing.length }, null, 2));
if (!execute || missing.length === 0) Deno.exit(0);

const source = config();
const recovered: RecoveredItem[] = [];
const failures: string[] = [];
for (const location of missing) {
  try {
    const response = await sourceGet(source, location.bucket, location.key);
    if (!response.ok) {
      failures.push(
        `${location.bucket}/${location.key} (HTTP ${response.status})`,
      );
      continue;
    }
    const bytes = new Uint8Array(await response.arrayBuffer());
    const relativePath = `r2-recovery/${location.bucket}/${location.key}`;
    const absolutePath = `${state.sourceDir}/${relativePath}`;
    await Deno.mkdir(absolutePath.slice(0, absolutePath.lastIndexOf("/")), {
      recursive: true,
    });
    await Deno.writeFile(absolutePath, bytes);
    const item: RecoveredItem = {
      source: "r2",
      bucket: location.bucket,
      key: location.key,
      size: bytes.byteLength,
      sha256: await sha256(bytes),
      contentType: response.headers.get("content-type")?.split(";")[0] ||
        extensionMime(location.key),
      relativePath,
      status: "pending",
    };
    recovered.push(item);
    console.log(`recovered ${location.bucket}/${location.key}`);
  } catch (error) {
    failures.push(`${location.bucket}/${location.key} (${error})`);
  }
}
if (failures.length) {
  throw new Error(
    `R2 recovery could not fetch ${failures.length} of ${missing.length} objects: ${failures.join("; ")}`,
  );
}
state.items.push(...recovered);
await writeState(state);
console.log(JSON.stringify({ mode: "r2-recovery", recovered: recovered.length }, null, 2));

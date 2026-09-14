/**
 * Cloudflare R2 storage boundary.
 *
 * The Edge API is the only place that knows R2 credentials. References are
 * deliberately visibility-aware so a private object can never be turned into
 * a public custom-domain URL by accident.
 */

export type R2Visibility = "private" | "public";

export type R2Config = {
  endpoint: string;
  privateBucket: string;
  publicBucket: string;
  accessKeyId: string;
  secretAccessKey: string;
  publicBaseUrl: string;
  region: string;
};

export type R2ReferenceInfo = {
  key: string;
  visibility: R2Visibility;
};

export type R2Upload = {
  key: string;
  reference: string;
  url: string;
  visibility: R2Visibility;
};

const LEGACY_STORAGE_BUCKETS = new Set([
  "school-assets",
  "school-private-files",
  "finance-documents",
  "payment-proofs",
  "issue-attachments",
  "help-tutorial-videos",
  "school-signatures",
  "school-public-media",
]);

const LEGACY_STORAGE_KEY_PREFIXES = new Set([
  "avatars",
  "documents",
  "exports",
  "gallery",
  "health",
  "homework",
  "issues",
  "logos",
  "payment-config",
  "payment-proofs",
  "reports",
  "signatures",
  "students",
  "uploads",
  "website",
]);

type SignedRequest = {
  method: string;
  visibility: R2Visibility;
  key: string;
  query?: Record<string, string>;
  headers?: Record<string, string>;
  body?: Uint8Array;
};

function readFlag(name: string, fallback: boolean): boolean {
  const value = Deno.env.get(name)?.trim().toLowerCase();
  if (!value) return fallback;
  return ["1", "true", "yes", "on"].includes(value);
}

export function legacyStorageReadsEnabled(): boolean {
  return readFlag("STORAGE_LEGACY_READ", true);
}

export function storageReadOrder(): string[] {
  const configured = (Deno.env.get("STORAGE_READ_ORDER") ?? "r2,supabase")
    .split(",")
    .map((provider) => provider.trim().toLowerCase())
    .filter((provider) => provider === "r2" || provider === "supabase");
  const order = configured.length > 0 ? configured : ["r2", "supabase"];
  return legacyStorageReadsEnabled()
    ? order
    : order.filter((provider) => provider !== "supabase");
}

/**
 * Legacy writes are an explicit migration escape hatch. Once R2 is selected
 * as the write provider, a failed R2 write must not silently create a new
 * Supabase object that the cutover cannot account for.
 */
export function legacyStorageWritesEnabled(): boolean {
  const configured = Deno.env.get("STORAGE_LEGACY_WRITE")?.trim();
  if (configured) return readFlag("STORAGE_LEGACY_WRITE", false);
  return (Deno.env.get("STORAGE_WRITE_PROVIDER") ?? "").trim().toLowerCase() !==
    "r2";
}

export function r2Config(): R2Config | null {
  const endpoint = Deno.env.get("R2_ENDPOINT")?.trim() ?? "";
  const legacyBucket = Deno.env.get("R2_BUCKET")?.trim() ?? "";
  const privateBucket = Deno.env.get("R2_PRIVATE_BUCKET")?.trim() ||
    legacyBucket;
  const publicBucket = Deno.env.get("R2_PUBLIC_BUCKET")?.trim() ||
    legacyBucket;
  const accessKeyId = Deno.env.get("R2_ACCESS_KEY_ID")?.trim() ?? "";
  const secretAccessKey = Deno.env.get("R2_SECRET_ACCESS_KEY")?.trim() ?? "";
  if (
    !endpoint || !privateBucket || !publicBucket || !accessKeyId ||
    !secretAccessKey
  ) return null;
  return {
    endpoint: endpoint.replace(/\/+$/, ""),
    privateBucket,
    publicBucket,
    accessKeyId,
    secretAccessKey,
    publicBaseUrl: Deno.env.get("R2_PUBLIC_BASE_URL")?.trim() ?? "",
    region: Deno.env.get("R2_REGION")?.trim() || "auto",
  };
}

function bucketFor(settings: R2Config, visibility: R2Visibility): string {
  return visibility === "public"
    ? settings.publicBucket
    : settings.privateBucket;
}

function normalizeKey(key: string): string {
  return key.trim().replace(/^\/+/, "").replace(/^private\//, "");
}

function visibilityFromKey(key: string): R2Visibility {
  return key.startsWith("private/") ? "private" : "public";
}

function safeReferenceKey(key: string): string {
  return normalizeKey(key).replace(/^public\//, "");
}

export function r2Reference(
  key: string,
  visibility: R2Visibility = "private",
): string {
  return `r2://${visibility}/${safeReferenceKey(key)}`;
}

export function r2FileReference(key: string): string {
  return r2Reference(key, "private");
}

export function publicR2FileReference(key: string): string {
  return r2Reference(key, "public");
}

function decodeLegacyPath(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

function cleanLegacyKey(value: string): string {
  return decodeLegacyPath(value).replace(/^\/+/, "").replace(/\/{2,}/g, "/")
    .trim();
}

/** Extracts a known Supabase Storage bucket/key from a legacy reference. */
function legacyStorageLocation(
  value: unknown,
  defaultBucket = "",
): { bucket: string; key: string } | null {
  const raw = `${value ?? ""}`.trim();
  if (!raw || raw.startsWith("r2://")) return null;

  if (/^https?:\/\//i.test(raw)) {
    try {
      const url = new URL(raw);
      const marker = "/storage/v1/object/";
      const markerIndex = url.pathname.indexOf(marker);
      if (markerIndex < 0) return null;
      const rest = url.pathname.slice(markerIndex + marker.length)
        .replace(/^public\//, "")
        .replace(/^sign\//, "")
        .replace(/^authenticated\//, "");
      const slash = rest.indexOf("/");
      if (slash < 1) return null;
      const bucket = decodeLegacyPath(rest.slice(0, slash));
      const key = cleanLegacyKey(rest.slice(slash + 1));
      return LEGACY_STORAGE_BUCKETS.has(bucket) && key ? { bucket, key } : null;
    } catch {
      return null;
    }
  }

  const normalized = raw.replace(/^\/+/, "");
  const slash = normalized.indexOf("/");
  if (slash > 0) {
    const bucket = normalized.slice(0, slash);
    const key = cleanLegacyKey(normalized.slice(slash + 1));
    if (LEGACY_STORAGE_BUCKETS.has(bucket) && key) return { bucket, key };
  }

  if (
    defaultBucket && LEGACY_STORAGE_BUCKETS.has(defaultBucket) &&
    !/^([a-z]+:)?\/\//i.test(normalized) && slash > 0 &&
    LEGACY_STORAGE_KEY_PREFIXES.has(normalized.slice(0, slash).toLowerCase())
  ) {
    const key = cleanLegacyKey(normalized);
    return key ? { bucket: defaultBucket, key } : null;
  }
  return null;
}

/**
 * Derives the deterministic R2 reference used by the storage migration from
 * a legacy Supabase Storage URL. This lets reads recover objects before the
 * database rewrite has completed; the source URL is never persisted here.
 */
export function legacyR2Reference(
  value: unknown,
  defaultBucket = "",
): string | null {
  const location = legacyStorageLocation(value, defaultBucket);
  if (!location) return null;

  const isPublic = location.bucket === "school-public-media" ||
    (location.bucket === "school-assets" && /^logos\//i.test(location.key));
  const destinationKey = isPublic && location.bucket === "school-public-media"
    ? `website/${location.key}`
    : `legacy/${location.bucket}/${location.key}`;
  return r2Reference(destinationKey, isPublic ? "public" : "private");
}

function hex(value: ArrayBuffer | Uint8Array): string {
  return Array.from(
    new Uint8Array(value instanceof Uint8Array ? value : value),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}

function arrayBuffer(value: Uint8Array): ArrayBuffer {
  return value.buffer.slice(
    value.byteOffset,
    value.byteOffset + value.byteLength,
  ) as ArrayBuffer;
}

async function sha256(value: Uint8Array): Promise<string> {
  return hex(await crypto.subtle.digest("SHA-256", arrayBuffer(value)));
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
      arrayBuffer(new TextEncoder().encode(value)),
    ),
  );
}

function encodedPath(value: string): string {
  return value.split("/").map((segment) => encodeURIComponent(segment)).join(
    "/",
  );
}

// encodeURIComponent leaves a few characters unescaped that AWS canonical
// query strings require escaped.
function awsEncode(value: string): string {
  return encodeURIComponent(value).replace(
    /[!'()*]/g,
    (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`,
  );
}

function objectUrl(
  settings: R2Config,
  visibility: R2Visibility,
  key: string,
): URL {
  const endpoint = new URL(settings.endpoint);
  const basePath = endpoint.pathname.replace(/\/+$/, "");
  const bucket = encodeURIComponent(bucketFor(settings, visibility));
  const path = `${basePath}/${bucket}/${encodedPath(normalizeKey(key))}`;
  return new URL(path, `${endpoint.protocol}//${endpoint.host}`);
}

function publicUrl(settings: R2Config, key: string): string {
  if (!settings.publicBaseUrl) return "";
  return `${settings.publicBaseUrl.replace(/\/+$/, "")}/${
    encodedPath(
      safeReferenceKey(key),
    )
  }`;
}

function amzTimestamp(now = new Date()) {
  const amzDate = now.toISOString().replace(/[-:]/g, "").replace(
    /\.\d{3}Z$/,
    "Z",
  );
  return { amzDate, dateStamp: amzDate.slice(0, 8) };
}

async function signingKey(settings: R2Config, dateStamp: string) {
  const dateKey = await hmac(
    new TextEncoder().encode(`AWS4${settings.secretAccessKey}`),
    dateStamp,
  );
  const regionKey = await hmac(dateKey, settings.region);
  const serviceKey = await hmac(regionKey, "s3");
  return await hmac(serviceKey, "aws4_request");
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

async function signedRequest(
  settings: R2Config,
  input: SignedRequest,
): Promise<Response> {
  const body = input.body ?? new Uint8Array();
  const payloadHash = await sha256(body);
  const url = objectUrl(settings, input.visibility, input.key);
  const { amzDate, dateStamp } = amzTimestamp();
  const headers: Record<string, string> = {
    ...(input.headers ?? {}),
    host: url.host,
    "x-amz-content-sha256": payloadHash,
    "x-amz-date": amzDate,
  };
  const query = canonicalQuery(input.query ?? {});
  const canonical = canonicalHeaders(headers);
  const canonicalRequest = [
    input.method.toUpperCase(),
    url.pathname,
    query,
    canonical.value,
    canonical.signed,
    payloadHash,
  ].join("\n");
  const scope = `${dateStamp}/${settings.region}/s3/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    scope,
    await sha256(new TextEncoder().encode(canonicalRequest)),
  ].join("\n");
  const signature = hex(
    await hmac(await signingKey(settings, dateStamp), stringToSign),
  );
  const requestHeaders = new Headers();
  for (const [name, value] of Object.entries(headers)) {
    if (name !== "host") requestHeaders.set(name, value);
  }
  requestHeaders.set(
    "authorization",
    `AWS4-HMAC-SHA256 Credential=${settings.accessKeyId}/${scope}, ` +
      `SignedHeaders=${canonical.signed}, Signature=${signature}`,
  );
  const method = input.method.toUpperCase();
  return await fetch(new URL(`${url.toString()}${query ? `?${query}` : ""}`), {
    method,
    headers: requestHeaders,
    body: method === "GET" || method === "HEAD" ? undefined : arrayBuffer(body),
  });
}

function referenceFromRaw(raw: string): R2ReferenceInfo | null {
  if (raw.startsWith("r2://")) {
    const reference = raw.slice("r2://".length);
    const slash = reference.indexOf("/");
    if (slash > 0) {
      const prefix = reference.slice(0, slash).toLowerCase();
      if (prefix === "private" || prefix === "public") {
        const key = normalizeKey(reference.slice(slash + 1));
        return key ? { key, visibility: prefix } : null;
      }
    }
    const key = normalizeKey(reference);
    return key ? { key, visibility: visibilityFromKey(key) } : null;
  }
  return null;
}

/** Returns visibility and key for an internal R2 reference or R2 URL. */
export function r2ReferenceInfo(value: unknown): R2ReferenceInfo | null {
  const raw = `${value ?? ""}`.trim();
  const reference = referenceFromRaw(raw);
  if (reference) return reference;
  if (!/^https?:\/\//i.test(raw)) return null;
  const settings = r2Config();
  if (!settings) return null;
  try {
    const url = new URL(raw);
    const endpoint = new URL(settings.endpoint);
    if (url.host === endpoint.host) {
      const basePath = endpoint.pathname.replace(/\/+$/, "");
      for (const visibility of ["private", "public"] as R2Visibility[]) {
        const prefix = `${basePath}/${
          encodeURIComponent(
            bucketFor(settings, visibility),
          )
        }/`;
        if (url.pathname.startsWith(prefix)) {
          const key = decodeURIComponent(url.pathname.slice(prefix.length));
          return key ? { key, visibility } : null;
        }
      }
    }
    if (settings.publicBaseUrl) {
      const publicBase = new URL(settings.publicBaseUrl);
      if (url.host === publicBase.host) {
        const publicPath = publicBase.pathname.replace(/\/+$/, "");
        const prefix = `${publicPath}/`;
        if (url.pathname.startsWith(prefix)) {
          const key = decodeURIComponent(url.pathname.slice(prefix.length));
          return key ? { key, visibility: "public" } : null;
        }
      }
    }
  } catch {
    return null;
  }
  return null;
}

/** Returns the R2 object key for an internal reference or R2 URL. */
export function r2KeyFromValue(value: unknown): string {
  return r2ReferenceInfo(value)?.key ?? "";
}

export function r2VisibilityFromValue(value: unknown): R2Visibility | "" {
  return r2ReferenceInfo(value)?.visibility ?? "";
}

/** Returns a public URL only for references explicitly marked public. */
export function publicR2FileUrl(value: unknown): string {
  const settings = r2Config();
  const reference = r2ReferenceInfo(value);
  if (!settings || !reference || reference.visibility !== "public") return "";
  return publicUrl(settings, reference.key);
}

async function uploadObject(
  settings: R2Config,
  key: string,
  source: File | Uint8Array,
  contentType: string,
  visibility: R2Visibility,
): Promise<R2Upload> {
  const bytes = source instanceof Uint8Array
    ? source
    : new Uint8Array(await source.arrayBuffer());
  const response = await signedRequest(settings, {
    method: "PUT",
    visibility,
    key,
    headers: {
      "content-type": contentType || "application/octet-stream",
    },
    body: bytes,
  });
  if (!response.ok) {
    throw new Error(`R2 upload failed with HTTP ${response.status}`);
  }
  const reference = r2Reference(key, visibility);
  return {
    key,
    reference,
    visibility,
    url: visibility === "public" ? publicUrl(settings, key) : "",
  };
}

/** Uploads an object to the private R2 bucket. */
export async function uploadToR2(
  key: string,
  source: File | Uint8Array,
  contentType: string,
): Promise<R2Upload | null> {
  const settings = r2Config();
  if (!settings) return null;
  return await uploadObject(
    settings,
    normalizeKey(key),
    source,
    contentType,
    "private",
  );
}

/** Uploads an object to the public R2 bucket when its custom domain is ready. */
export async function uploadPublicToR2(
  key: string,
  source: File | Uint8Array,
  contentType: string,
): Promise<R2Upload | null> {
  const settings = r2Config();
  if (!settings?.publicBaseUrl) return null;
  return await uploadObject(
    settings,
    safeReferenceKey(key),
    source,
    contentType,
    "public",
  );
}

/** Creates a short-lived private download URL. Public refs use their CDN URL. */
export async function signedR2FileUrl(
  value: unknown,
  ttlSeconds = 10 * 60,
): Promise<string> {
  const settings = r2Config();
  const reference = r2ReferenceInfo(value);
  if (!settings || !reference) return "";
  if (reference.visibility === "public") {
    return publicUrl(settings, reference.key);
  }

  const expires = Math.max(1, Math.min(604800, Math.floor(ttlSeconds)));
  const url = objectUrl(settings, reference.visibility, reference.key);
  const { amzDate, dateStamp } = amzTimestamp();
  const scope = `${dateStamp}/${settings.region}/s3/aws4_request`;
  const query = canonicalQuery({
    "X-Amz-Algorithm": "AWS4-HMAC-SHA256",
    "X-Amz-Credential": `${settings.accessKeyId}/${scope}`,
    "X-Amz-Date": amzDate,
    "X-Amz-Expires": `${expires}`,
    "X-Amz-SignedHeaders": "host",
  });
  const canonicalRequest = [
    "GET",
    url.pathname,
    query,
    `host:${url.host}\n`,
    "host",
    "UNSIGNED-PAYLOAD",
  ].join("\n");
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    scope,
    await sha256(new TextEncoder().encode(canonicalRequest)),
  ].join("\n");
  const signature = hex(
    await hmac(await signingKey(settings, dateStamp), stringToSign),
  );
  return `${url.toString()}?${query}&X-Amz-Signature=${signature}`;
}

/** Returns whether an object exists without downloading its body. */
export async function headR2File(value: unknown): Promise<boolean> {
  const settings = r2Config();
  const reference = r2ReferenceInfo(value);
  if (!settings || !reference) return false;
  const response = await signedRequest(settings, {
    method: "HEAD",
    visibility: reference.visibility,
    key: reference.key,
  });
  if (response.status === 404) return false;
  if (!response.ok) {
    throw new Error(`R2 head failed with HTTP ${response.status}`);
  }
  return true;
}

/** Copies an object between the private and public buckets. */
export async function copyR2File(
  source: unknown,
  destinationKey: string,
  destinationVisibility: R2Visibility,
): Promise<R2Upload | null> {
  const settings = r2Config();
  const reference = r2ReferenceInfo(source);
  if (!settings || !reference) return null;
  const sourcePath = `/${
    encodeURIComponent(
      bucketFor(settings, reference.visibility),
    )
  }/${encodedPath(reference.key)}`;
  const destination = normalizeKey(destinationKey);
  const response = await signedRequest(settings, {
    method: "PUT",
    visibility: destinationVisibility,
    key: destination,
    headers: { "x-amz-copy-source": sourcePath },
  });
  if (!response.ok) {
    throw new Error(`R2 copy failed with HTTP ${response.status}`);
  }
  return {
    key: destination,
    reference: r2Reference(destination, destinationVisibility),
    visibility: destinationVisibility,
    url: destinationVisibility === "public"
      ? publicUrl(settings, destination)
      : "",
  };
}

/** Deletes an R2 object; missing objects are treated as already deleted. */
export async function deleteR2File(value: unknown): Promise<boolean> {
  const settings = r2Config();
  const reference = r2ReferenceInfo(value);
  if (!settings || !reference) return false;
  const response = await signedRequest(settings, {
    method: "DELETE",
    visibility: reference.visibility,
    key: reference.key,
  });
  if (!response.ok && response.status !== 404) {
    throw new Error(`R2 delete failed with HTTP ${response.status}`);
  }
  return true;
}

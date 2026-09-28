/** Downloads target Supabase Storage objects before replacement, never logs keys. */

const TARGET_URL = "https://qzdhymlabzqjeocetqqv.supabase.co";

function required(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function option(name: string): string {
  const index = Deno.args.indexOf(name);
  return index >= 0 ? Deno.args[index + 1] ?? "" : "";
}

function safePath(value: string): string {
  const segments = value.split("/");
  if (
    !value ||
    segments.some((segment) => !segment || segment === "." || segment === "..")
  ) {
    throw new Error("Storage object name is unsafe");
  }
  return value;
}

async function request(path: string, init: RequestInit = {}) {
  const key = required("TARGET_SERVICE_ROLE_KEY");
  const response = await fetch(`${TARGET_URL}${path}`, {
    ...init,
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      ...(init.headers ?? {}),
    },
  });
  if (!response.ok) {
    throw new Error(`Storage request failed with HTTP ${response.status}`);
  }
  return response;
}

async function list(
  bucket: string,
  prefix = "",
): Promise<Array<{ name: string; id?: string }>> {
  const response = await request(
    `/storage/v1/object/list/${encodeURIComponent(bucket)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        prefix,
        limit: 1000,
        offset: 0,
        sortBy: { column: "name", order: "asc" },
      }),
    },
  );
  return await response.json() as Array<{ name: string; id?: string }>;
}

async function listRecursive(
  bucket: string,
  prefix = "",
  seen = new Set<string>(),
): Promise<Array<{ name: string }>> {
  if (seen.has(prefix)) {
    throw new Error("Storage listing contains a recursive prefix");
  }
  seen.add(prefix);
  const result: Array<{ name: string }> = [];
  for (const entry of await list(bucket, prefix)) {
    const name = safePath(entry.name);
    const fullName = prefix ? `${prefix}${name}` : name;
    if (entry.id) {
      result.push({ name: fullName });
      continue;
    }
    result.push(...await listRecursive(bucket, `${fullName}/`, seen));
  }
  return result;
}

async function main() {
  const output = option("--output");
  if (!output.startsWith("/")) {
    throw new Error("--output must be an absolute path outside the repository");
  }
  if (output.startsWith(`${Deno.cwd().replace(/\/+$/, "")}/`)) {
    throw new Error("--output must be outside the repository");
  }
  await Deno.mkdir(output, { recursive: true, mode: 0o700 });
  const bucketsResponse = await request("/storage/v1/bucket");
  const buckets = await bucketsResponse.json() as Array<{ id: string }>;
  const manifest: Array<
    { bucket: string; name: string; bytes: number; sha256: string }
  > = [];
  for (const bucket of buckets) {
    for (const object of await listRecursive(bucket.id)) {
      const name = object.name;
      const response = await request(
        `/storage/v1/object/authenticated/${encodeURIComponent(bucket.id)}/${
          name.split("/").map(encodeURIComponent).join("/")
        }`,
      );
      const bytes = new Uint8Array(await response.arrayBuffer());
      const digest = await crypto.subtle.digest("SHA-256", bytes);
      const sha256 = Array.from(
        new Uint8Array(digest),
        (byte) => byte.toString(16).padStart(2, "0"),
      ).join("");
      const path = `${output}/${bucket.id}/${name}`;
      await Deno.mkdir(path.slice(0, path.lastIndexOf("/")), {
        recursive: true,
        mode: 0o700,
      });
      await Deno.writeFile(path, bytes, { mode: 0o600 });
      manifest.push({
        bucket: bucket.id,
        name,
        bytes: bytes.byteLength,
        sha256,
      });
    }
  }
  await Deno.writeTextFile(
    `${output}/manifest.json`,
    `${JSON.stringify(manifest, null, 2)}\n`,
    { mode: 0o600 },
  );
  console.log(
    JSON.stringify(
      {
        buckets: buckets.length,
        objects: manifest.length,
        bytes: manifest.reduce((sum, object) => sum + object.bytes, 0),
      },
      null,
      2,
    ),
  );
}

await main();

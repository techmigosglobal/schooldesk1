/** Creates a minimal, mode-0600 Edge Function secret file outside the repository. */

const NAMES = [
  "R2_ENDPOINT",
  "R2_PRIVATE_BUCKET",
  "R2_PUBLIC_BUCKET",
  "R2_ACCESS_KEY_ID",
  "R2_SECRET_ACCESS_KEY",
  "R2_REGION",
  "R2_PUBLIC_BASE_URL",
  "NOTIFICATION_PROCESSOR_SECRET",
  "BIRTHDAY_ALERT_JOB_SECRET",
  "HEALTH_REMINDER_JOB_SECRET",
];

function required(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value || value.includes("\n")) {
    throw new Error(`${name} is required and must be single-line`);
  }
  return value;
}

const outputIndex = Deno.args.indexOf("--output");
const output = outputIndex >= 0 ? Deno.args[outputIndex + 1] ?? "" : "";
if (!output.startsWith("/")) {
  throw new Error("--output must be an absolute path outside the repository");
}
if (output.startsWith(`${Deno.cwd().replace(/\/+$/, "")}/`)) {
  throw new Error("--output must be outside the repository");
}

const lines = [
  ...NAMES.map((name) => `${name}=${required(name)}`),
  "STORAGE_WRITE_PROVIDER=r2",
  "STORAGE_READ_ORDER=r2",
  "STORAGE_LEGACY_READ=false",
  "STORAGE_LEGACY_WRITE=false",
  "MAINTENANCE_MODE=true",
];
await Deno.mkdir(output.slice(0, output.lastIndexOf("/")), {
  recursive: true,
  mode: 0o700,
});
await Deno.writeTextFile(output, `${lines.join("\n")}\n`, { mode: 0o600 });
console.log(
  JSON.stringify(
    {
      output,
      secret_names: [
        ...NAMES,
        "STORAGE_WRITE_PROVIDER",
        "STORAGE_READ_ORDER",
        "STORAGE_LEGACY_READ",
        "STORAGE_LEGACY_WRITE",
        "MAINTENANCE_MODE",
      ],
    },
    null,
    2,
  ),
);

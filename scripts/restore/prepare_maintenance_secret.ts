/** Writes the temporary API maintenance-mode secret outside the repository. */

const enabled = Deno.args.includes("--enabled");
const disabled = Deno.args.includes("--disabled");
const index = Deno.args.indexOf("--output");
const output = index >= 0 ? Deno.args[index + 1] ?? "" : "";

if (enabled === disabled) {
  throw new Error("Use exactly one of --enabled or --disabled");
}
if (!output.startsWith("/") || output.startsWith(`${Deno.cwd()}/`)) {
  throw new Error("--output must be an absolute path outside the repository");
}

await Deno.mkdir(output.slice(0, output.lastIndexOf("/")), {
  recursive: true,
  mode: 0o700,
});
await Deno.writeTextFile(output, `MAINTENANCE_MODE=${enabled}\n`, {
  mode: 0o600,
});
console.log(JSON.stringify({ output, maintenance: enabled }, null, 2));

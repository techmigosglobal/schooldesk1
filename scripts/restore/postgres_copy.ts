/**
 * Minimal reader for the text COPY sections emitted by pg_dump.  It does not
 * execute SQL; callers decide which schemas/tables are safe to consume.
 */

export type CopySection = {
  schema: string;
  table: string;
  columns: string[];
  rows: string[];
};

export type CopyValue = string | null;

const COPY_HEADER =
  /^COPY ([a-z_][a-z0-9_]*)\.([a-z_][a-z0-9_]*) \(([^)]+)\) FROM stdin;$/i;

function validIdentifier(value: string): boolean {
  return /^[a-z_][a-z0-9_]*$/i.test(value);
}

async function* gzipLines(path: string): AsyncGenerator<string> {
  const command = new Deno.Command("gzip", {
    args: ["--decompress", "--stdout", path],
    stdout: "piped",
    stderr: "piped",
  });
  const child = command.spawn();
  const reader = child.stdout.pipeThrough(new TextDecoderStream()).getReader();
  let pending = "";
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      pending += value;
      let newline = pending.indexOf("\n");
      while (newline >= 0) {
        const line = pending.slice(0, newline).replace(/\r$/, "");
        pending = pending.slice(newline + 1);
        yield line;
        newline = pending.indexOf("\n");
      }
    }
    if (pending) yield pending.replace(/\r$/, "");
  } finally {
    reader.releaseLock();
  }
  const result = await child.status;
  if (!result.success) {
    const stderr = new TextDecoder().decode(
      await child.stderr.getReader().read().then((r) =>
        r.value ?? new Uint8Array()
      ),
    );
    throw new Error(
      `gzip failed while reading ${path}: ${stderr.trim() || result.code}`,
    );
  }
}

/** Reads complete, validated COPY sections from a gzip-compressed pg_dump. */
export async function readCopySections(path: string): Promise<CopySection[]> {
  const sections: CopySection[] = [];
  let active: CopySection | undefined;
  for await (const line of gzipLines(path)) {
    if (!active) {
      const match = line.match(COPY_HEADER);
      if (!match) continue;
      const columns = match[3].split(", ").map((column) => column.trim());
      if (
        !columns.length || columns.some((column) => !validIdentifier(column))
      ) {
        throw new Error(`Unsafe COPY column list for ${match[1]}.${match[2]}`);
      }
      active = { schema: match[1], table: match[2], columns, rows: [] };
      continue;
    }
    if (line === "\\.") {
      sections.push(active);
      active = undefined;
      continue;
    }
    active.rows.push(line);
  }
  if (active) {
    throw new Error(
      `Unterminated COPY section ${active.schema}.${active.table}`,
    );
  }
  return sections;
}

function decodeCopyField(value: string): CopyValue {
  if (value === "\\N") return null;
  let decoded = "";
  for (let index = 0; index < value.length; index += 1) {
    const character = value[index];
    if (character !== "\\") {
      decoded += character;
      continue;
    }
    const next = value[++index];
    if (next === undefined) throw new Error("Trailing backslash in COPY field");
    const escaped: Record<string, string> = {
      b: "\b",
      f: "\f",
      n: "\n",
      r: "\r",
      t: "\t",
      v: "\v",
    };
    if (escaped[next] !== undefined) {
      decoded += escaped[next];
      continue;
    }
    if (/[0-7]/.test(next)) {
      const octal =
        `${next}${value[index + 1] ?? ""}${value[index + 2] ?? ""}`.match(
          /^[0-7]{1,3}/,
        )?.[0] ?? next;
      decoded += String.fromCharCode(Number.parseInt(octal, 8));
      index += octal.length - 1;
      continue;
    }
    decoded += next;
  }
  return decoded;
}

/** Converts a pg_dump text-COPY row to values suitable for parameterized SQL. */
export function parseCopyRow(
  row: string,
  expectedColumns: number,
): CopyValue[] {
  const fields = row.split("\t");
  if (fields.length !== expectedColumns) {
    throw new Error(
      `COPY row has ${fields.length} fields; expected ${expectedColumns}`,
    );
  }
  return fields.map(decodeCopyField);
}

export function quoteIdentifier(value: string): string {
  if (!validIdentifier(value)) {
    throw new Error(`Unsafe SQL identifier: ${value}`);
  }
  return `"${value}"`;
}

export function sectionKey(
  section: Pick<CopySection, "schema" | "table">,
): string {
  return `${section.schema}.${section.table}`;
}

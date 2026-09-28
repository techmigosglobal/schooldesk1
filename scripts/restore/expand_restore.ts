/**
 * Generates a guarded SQL transaction for the previously excluded,
 * user-requested source rows. It intentionally does not touch Supabase-owned
 * schemas, roles, Realtime state, or migration history.
 */

import {
  parseCopyRow,
  quoteIdentifier,
  readCopySections,
  sectionKey,
  type CopySection,
} from "./postgres_copy.ts";

const PUBLIC_TABLES = [
  "demo_accounts",
  "api_idempotency_keys",
  "storage_cleanup_queue",
  "error_events",
  "error_event_daily_summaries",
] as const;

const AUTH_TABLES = [
  "sessions",
  "refresh_tokens",
  "mfa_amr_claims",
  "mfa_challenges",
  "mfa_factors",
  "mfa_recovery_code_sets",
  "mfa_recovery_codes",
  "flow_state",
  "one_time_tokens",
  "webauthn_challenges",
  "webauthn_credentials",
] as const;

function option(name: string): string {
  const index = Deno.args.indexOf(name);
  return index >= 0 ? Deno.args[index + 1] ?? "" : "";
}

function assertExternalPath(path: string) {
  const cwd = Deno.cwd().replace(/\/+$/, "");
  if (!path.startsWith("/") || path === cwd || path.startsWith(`${cwd}/`)) {
    throw new Error("output must be an absolute path outside the repository");
  }
}

function sqlLiteral(value: string | null): string {
  if (value === null) return "NULL";
  let escaped = "";
  for (const character of value) {
    if (character === "\\") escaped += "\\\\";
    else if (character === "'") escaped += "\\'";
    else if (character === "\b") escaped += "\\b";
    else if (character === "\f") escaped += "\\f";
    else if (character === "\n") escaped += "\\n";
    else if (character === "\r") escaped += "\\r";
    else if (character === "\t") escaped += "\\t";
    else if (character === "\v") escaped += "\\v";
    else escaped += character;
  }
  return `E'${escaped}'`;
}

function sqlTable(schema: string, table: string): string {
  return `${quoteIdentifier(schema)}.${quoteIdentifier(table)}`;
}

function valuesSql(section: CopySection): string[] {
  return section.rows.map((row) =>
    `(${parseCopyRow(row, section.columns.length).map(sqlLiteral).join(", ")})`
  );
}

function findSection(
  sections: CopySection[],
  schema: string,
  table: string,
): CopySection | undefined {
  return sections.find((section) =>
    section.schema === schema && section.table === table
  );
}

const COMPATIBILITY_SQL = String.raw`
do $$
declare
  issue text;
begin
  select format('%s.%s.%s is absent on target', source.schema_name, source.table_name, source.column_name)
    into issue
  from restore_expansion_source_columns source
  left join information_schema.columns target
    on target.table_schema = source.schema_name
   and target.table_name = source.table_name
   and target.column_name = source.column_name
  where target.column_name is null
  limit 1;
  if issue is not null then raise exception '%', issue; end if;

  select format('%s.%s.%s is required but absent from source', target.table_schema, target.table_name, target.column_name)
    into issue
  from information_schema.columns target
  join restore_expansion_expected expected
    on expected.schema_name = target.table_schema
   and expected.table_name = target.table_name
  left join restore_expansion_source_columns source
    on source.schema_name = target.table_schema
   and source.table_name = target.table_name
   and source.column_name = target.column_name
  where source.column_name is null
    and target.is_nullable = 'NO'
    and target.column_default is null
    and target.is_generated = 'NEVER'
    and target.is_identity = 'NO'
  limit 1;
  if issue is not null then raise exception '%', issue; end if;
end $$;
`;

async function main() {
  const dump = option("--dump");
  const output = option("--output");
  if (!dump || !output) {
    throw new Error("usage: expand_restore.ts --dump <dump.gz> --output <sql>");
  }
  assertExternalPath(output);

  const sections = await readCopySections(dump);
  const selected = [
    ...PUBLIC_TABLES.map((table) => findSection(sections, "public", table)),
    ...AUTH_TABLES.map((table) => findSection(sections, "auth", table)),
  ].filter((section): section is CopySection => Boolean(section));

  const missing = [
    ...PUBLIC_TABLES.map((table) => `public.${table}`),
    ...AUTH_TABLES.map((table) => `auth.${table}`),
  ].filter((key) => !selected.some((section) => sectionKey(section) === key));
  if (missing.length) {
    throw new Error(`Source dump is missing required sections: ${missing.join(", ")}`);
  }

  const lines: string[] = [
    "begin;",
    "set local session_replication_role = replica;",
    "create temporary table restore_expansion_source_columns (schema_name text, table_name text, column_name text);",
    "create temporary table restore_expansion_expected (schema_name text, table_name text, expected_count integer);",
  ];

  for (const section of selected) {
    for (const column of section.columns) {
      lines.push(
        `insert into restore_expansion_source_columns values (${sqlLiteral(section.schema)}, ${sqlLiteral(section.table)}, ${sqlLiteral(column)});`,
      );
    }
    lines.push(
      `insert into restore_expansion_expected values (${sqlLiteral(section.schema)}, ${sqlLiteral(section.table)}, ${section.rows.length});`,
    );
  }
  lines.push(COMPATIBILITY_SQL);

  // Clear dependent Auth state before replacing it. No auth.users rows are touched.
  for (const table of [...AUTH_TABLES].reverse()) {
    lines.push(`delete from ${sqlTable("auth", table)};`);
  }
  for (const table of PUBLIC_TABLES) {
    lines.push(`delete from ${sqlTable("public", table)};`);
  }

  for (const section of selected) {
    if (!section.rows.length) continue;
    const columns = section.columns.map(quoteIdentifier).join(", ");
    const table = sqlTable(section.schema, section.table);
    const values = valuesSql(section);
    for (let offset = 0; offset < values.length; offset += 100) {
      lines.push(
        `insert into ${table} (${columns}) values\n${values.slice(offset, offset + 100).join(",\n")};`,
      );
    }
  }

  lines.push(String.raw`
do $$
declare
  expected record;
  actual_count bigint;
begin
  for expected in select * from restore_expansion_expected loop
    execute format('select count(*) from %I.%I', expected.schema_name, expected.table_name) into actual_count;
    if actual_count <> expected.expected_count then
      raise exception 'Expansion count mismatch for %.%: expected %, found %', expected.schema_name, expected.table_name, expected.expected_count, actual_count;
    end if;
  end loop;
end $$;
`);
  lines.push("set local session_replication_role = origin;");
  lines.push("commit;");

  await Deno.mkdir(output.slice(0, output.lastIndexOf("/")), {
    recursive: true,
    mode: 0o700,
  });
  await Deno.writeTextFile(output, `${lines.join("\n")}\n`, { mode: 0o600 });
  console.log(JSON.stringify({
    mode: "generate-expansion-sql",
    output,
    rows: Object.fromEntries(selected.map((section) => [sectionKey(section), section.rows.length])),
  }, null, 2));
}

await main();

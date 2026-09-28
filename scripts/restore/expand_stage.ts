/** Generates resumable SQL chunks for the approved expansion restore. */

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
const STAGE = "schooldesk_expand_stage_qzdhymlabzqjeocetqqv";
const STAGE_COLUMNS = "schooldesk_expand_stage_columns_qzdhymlabzqjeocetqqv";
const STAGE_EXPECTED = "schooldesk_expand_stage_expected_qzdhymlabzqjeocetqqv";

function option(name: string): string {
  const index = Deno.args.indexOf(name);
  return index >= 0 ? Deno.args[index + 1] ?? "" : "";
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
function table(schema: string, name: string): string {
  return `${quoteIdentifier(schema)}.${quoteIdentifier(name)}`;
}
async function writeFile(path: string, body: string) {
  await Deno.writeTextFile(path, body, { mode: 0o600 });
}
function find(sections: CopySection[], schema: string, name: string) {
  return sections.find((section) =>
    section.schema === schema && section.table === name
  );
}
function selected(sections: CopySection[]): CopySection[] {
  const result = [
    ...PUBLIC_TABLES.map((name) => find(sections, "public", name)),
    ...AUTH_TABLES.map((name) => find(sections, "auth", name)),
  ].filter((section): section is CopySection => Boolean(section));
  if (result.length !== PUBLIC_TABLES.length + AUTH_TABLES.length) {
    throw new Error("Source dump is missing one or more expansion tables");
  }
  return result;
}

const FK_CHECK = String.raw`
do $$
declare fk record; orphaned bigint; predicate text; not_null_predicate text;
begin
  for fk in
    select c.oid constraint_oid, child_ns.nspname child_schema, child.relname child_table,
           parent_ns.nspname parent_schema, parent.relname parent_table
    from pg_constraint c
    join pg_class child on child.oid = c.conrelid
    join pg_namespace child_ns on child_ns.oid = child.relnamespace
    join pg_class parent on parent.oid = c.confrelid
    join pg_namespace parent_ns on parent_ns.oid = parent.relnamespace
    where c.contype = 'f' and child_ns.nspname in ('public','auth')
      and parent_ns.nspname in ('public','auth')
  loop
    select string_agg(format('parent.%I = child.%I', parent_attr.attname, child_attr.attname), ' and ' order by child_key.ordinality),
           string_agg(format('child.%I is not null', child_attr.attname), ' and ' order by child_key.ordinality)
      into predicate, not_null_predicate
    from pg_constraint c
    join lateral unnest(c.conkey) with ordinality child_key(attnum, ordinality) on true
    join lateral unnest(c.confkey) with ordinality parent_key(attnum, ordinality)
      on parent_key.ordinality = child_key.ordinality
    join pg_attribute child_attr on child_attr.attrelid = c.conrelid and child_attr.attnum = child_key.attnum
    join pg_attribute parent_attr on parent_attr.attrelid = c.confrelid and parent_attr.attnum = parent_key.attnum
    where c.oid = fk.constraint_oid;
    execute format('select count(*) from %I.%I child where (%s) and not exists (select 1 from %I.%I parent where %s)', fk.child_schema, fk.child_table, not_null_predicate, fk.parent_schema, fk.parent_table, predicate) into orphaned;
    if orphaned > 0 then raise exception 'Foreign-key validation failed for %: % orphaned row(s)', fk.constraint_oid, orphaned; end if;
  end loop;
end $$;
`;

async function main() {
  const dump = option("--dump");
  const out = option("--stage-dir");
  if (!dump || !out) throw new Error("usage: --dump <dump.gz> --stage-dir <dir>");
  if (!out.startsWith("/") || out.startsWith(`${Deno.cwd().replace(/\/+$/, "")}/`)) {
    throw new Error("stage directory must be outside the repository");
  }
  await Deno.mkdir(out, { recursive: true, mode: 0o700 });
  const sections = selected(await readCopySections(dump));

  const create = [
    "begin;",
    `do $$ begin if to_regclass('public.${STAGE}') is not null or to_regclass('public.${STAGE_COLUMNS}') is not null or to_regclass('public.${STAGE_EXPECTED}') is not null then raise exception 'expansion staging tables already exist'; end if; end $$;`,
    `create table public.${STAGE} (schema_name text not null, table_name text not null, ordinal integer not null, copy_values text[] not null, primary key(schema_name, table_name, ordinal));`,
    `create table public.${STAGE_COLUMNS} (schema_name text not null, table_name text not null, position integer not null, column_name text not null, primary key(schema_name, table_name, position));`,
    `create table public.${STAGE_EXPECTED} (schema_name text not null, table_name text not null, expected_count integer not null, primary key(schema_name, table_name));`,
    `revoke all on table public.${STAGE}, public.${STAGE_COLUMNS}, public.${STAGE_EXPECTED} from public, anon, authenticated;`,
    "commit;",
  ].join("\n") + "\n";
  await writeFile(`${out}/000-create.sql`, create);

  const metadata: string[] = [];
  for (const section of sections) {
    section.columns.forEach((column, index) => {
      metadata.push(`insert into public.${STAGE_COLUMNS} values (${sqlLiteral(section.schema)}, ${sqlLiteral(section.table)}, ${index + 1}, ${sqlLiteral(column)});`);
    });
    metadata.push(`insert into public.${STAGE_EXPECTED} values (${sqlLiteral(section.schema)}, ${sqlLiteral(section.table)}, ${section.rows.length});`);
  }
  for (let offset = 0, part = 0; offset < metadata.length; offset += 150, part++) {
    await writeFile(`${out}/100-meta-${String(part).padStart(3, "0")}.sql`, ["begin;", ...metadata.slice(offset, offset + 150), "commit;", ""].join("\n"));
  }

  const rows: string[] = [];
  for (const section of sections) {
    for (let index = 0; index < section.rows.length; index++) {
      const values = parseCopyRow(section.rows[index], section.columns.length).map(sqlLiteral).join(", ");
      rows.push(`(${sqlLiteral(section.schema)}, ${sqlLiteral(section.table)}, ${index + 1}, ARRAY[${values}]::text[])`);
    }
  }
  for (let offset = 0, part = 0; offset < rows.length; offset += 40, part++) {
    await writeFile(`${out}/200-data-${String(part).padStart(3, "0")}.sql`, ["begin;", `insert into public.${STAGE} (schema_name, table_name, ordinal, copy_values) values`, `${rows.slice(offset, offset + 40).join(",\n")};`, "commit;", ""].join("\n"));
  }

  const final: string[] = [
    "begin;",
    "set local session_replication_role = replica;",
    String.raw`
do $$
declare issue text;
begin
  select format('%s.%s.%s is absent on target', c.schema_name, c.table_name, c.column_name) into issue
  from public.schooldesk_expand_stage_columns_qzdhymlabzqjeocetqqv c
  left join information_schema.columns t on t.table_schema=c.schema_name and t.table_name=c.table_name and t.column_name=c.column_name
  where t.column_name is null limit 1;
  if issue is not null then raise exception '%', issue; end if;
  select format('%s.%s.%s is required but absent from source', t.table_schema, t.table_name, t.column_name) into issue
  from information_schema.columns t
  join public.schooldesk_expand_stage_expected_qzdhymlabzqjeocetqqv e on e.schema_name=t.table_schema and e.table_name=t.table_name
  left join public.schooldesk_expand_stage_columns_qzdhymlabzqjeocetqqv c on c.schema_name=t.table_schema and c.table_name=t.table_name and c.column_name=t.column_name
  where c.column_name is null and t.is_nullable='NO' and t.column_default is null and t.is_generated='NEVER' and t.is_identity='NO' limit 1;
  if issue is not null then raise exception '%', issue; end if;
end $$;
`,
    ...[...AUTH_TABLES].reverse().map((name) => `delete from ${table("auth", name)};`),
    ...PUBLIC_TABLES.map((name) => `delete from ${table("public", name)};`),
    String.raw`
do $$
declare item record; columns_sql text; values_sql text; actual_count bigint;
begin
  for item in select schema_name, table_name, expected_count from public.schooldesk_expand_stage_expected_qzdhymlabzqjeocetqqv loop
    select string_agg(format('%I', c.column_name), ', ' order by c.position), string_agg(format('(stage.copy_values[%s])::%s', c.position, format_type(a.atttypid, a.atttypmod)), ', ' order by c.position)
      into columns_sql, values_sql
    from public.schooldesk_expand_stage_columns_qzdhymlabzqjeocetqqv c
    join pg_class r on r.relname=item.table_name
    join pg_namespace n on n.oid=r.relnamespace and n.nspname=item.schema_name
    join pg_attribute a on a.attrelid=r.oid and a.attname=c.column_name and a.attnum>0 and not a.attisdropped
    where c.schema_name=item.schema_name and c.table_name=item.table_name;
    execute format('insert into %I.%I (%s) select %s from public.schooldesk_expand_stage_qzdhymlabzqjeocetqqv stage where stage.schema_name=%L and stage.table_name=%L order by stage.ordinal', item.schema_name, item.table_name, columns_sql, values_sql, item.schema_name, item.table_name);
    execute format('select count(*) from %I.%I', item.schema_name, item.table_name) into actual_count;
    if actual_count <> item.expected_count then raise exception 'Expansion count mismatch for %.%: expected %, found %', item.schema_name, item.table_name, item.expected_count, actual_count; end if;
  end loop;
end $$;
`,
    FK_CHECK,
    `drop table public.${STAGE}, public.${STAGE_COLUMNS}, public.${STAGE_EXPECTED};`,
    "set local session_replication_role = origin;",
    "commit;",
  ];
  await writeFile(`${out}/999-final.sql`, final.join("\n") + "\n");
  console.log(JSON.stringify({ mode: "expand-stage", output: out, rows: rows.length, chunks: Math.ceil(rows.length / 40) }, null, 2));
}

await main();

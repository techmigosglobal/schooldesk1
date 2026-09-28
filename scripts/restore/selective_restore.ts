/**
 * Fail-closed selective SchoolDesk restore.
 *
 * This runner only accepts the approved source dump and writes all generated
 * artifacts outside the repository.  `restore --execute` is the sole command
 * that mutates the target database.
 */

import {
  type CopySection,
  parseCopyRow,
  quoteIdentifier,
  readCopySections,
  sectionKey,
} from "./postgres_copy.ts";

const TARGET_REF = "qzdhymlabzqjeocetqqv";
const DEFAULT_DUMP =
  "/home/vinay/Documents/SchoolDesk-Backup/db_cluster-24-09-2026@08-24-07.backup.gz";
const SKIPPED_PUBLIC = new Set([
  "demo_accounts",
  "api_idempotency_keys",
  "storage_cleanup_queue",
  "error_events",
  "error_event_daily_summaries",
]);
const SELECTED_AUTH = new Set(["users", "identities"]);

type DatabaseClient = any;

type SelectedDump = {
  allPublicSections: CopySection[];
  publicSections: CopySection[];
  authSections: CopySection[];
  skippedPublic: CopySection[];
};

type Column = {
  schema: string;
  table: string;
  column: string;
  nullable: boolean;
  defaultValue: string | null;
  generated: string;
  identity: string;
};

function required(name: string): string {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) throw new Error(`${name} is required`);
  return value;
}

function option(name: string, fallback = ""): string {
  const index = Deno.args.indexOf(name);
  return index >= 0 ? Deno.args[index + 1] ?? "" : fallback;
}

function assertExternalPath(path: string, label: string) {
  const cwd = Deno.cwd().replace(/\/+$/, "");
  if (!path.startsWith("/")) {
    throw new Error(`${label} must be an absolute path`);
  }
  if (path === cwd || path.startsWith(`${cwd}/`)) {
    throw new Error(`${label} must be outside the repository`);
  }
}

function hash(value: string): Promise<string> {
  return crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)).then(
    (buffer) =>
      Array.from(
        new Uint8Array(buffer),
        (byte) => byte.toString(16).padStart(2, "0"),
      ).join(""),
  );
}

function selected(sections: CopySection[]): SelectedDump {
  const allPublicSections = sections.filter((section) =>
    section.schema === "public"
  );
  const publicSections = allPublicSections.filter((section) =>
    !SKIPPED_PUBLIC.has(section.table)
  );
  const skippedPublic = allPublicSections.filter((section) =>
    SKIPPED_PUBLIC.has(section.table)
  );
  const authSections = sections.filter((section) =>
    section.schema === "auth" && SELECTED_AUTH.has(section.table)
  );
  if (authSections.length !== SELECTED_AUTH.size) {
    throw new Error(
      "Source dump does not contain both auth.users and auth.identities",
    );
  }
  return { allPublicSections, publicSections, authSections, skippedPublic };
}

function sortedSections(input: SelectedDump): CopySection[] {
  return [
    ...input.authSections.sort((left, right) =>
      left.table === "users"
        ? -1
        : right.table === "users"
        ? 1
        : left.table.localeCompare(right.table)
    ),
    ...input.publicSections.sort((left, right) =>
      left.table.localeCompare(right.table)
    ),
  ];
}

async function loadSelected(dump: string): Promise<SelectedDump> {
  const source = await readCopySections(dump);
  const data = selected(source);
  if (data.publicSections.length !== 90) {
    throw new Error(
      `Expected 90 selected public tables, found ${data.publicSections.length}`,
    );
  }
  if (data.allPublicSections.length !== 95) {
    throw new Error(
      `Expected 95 source public tables, found ${data.allPublicSections.length}`,
    );
  }
  return data;
}

async function writeLedger(dump: string, output: string) {
  assertExternalPath(output, "--output");
  await Deno.mkdir(output, { recursive: true, mode: 0o700 });
  const data = await loadSelected(dump);
  const rows: string[] = [];
  const counts: Record<string, number> = {};
  for (const section of sortedSections(data)) {
    const key = sectionKey(section);
    counts[key] = section.rows.length;
    const idIndex = section.columns.indexOf("id");
    for (let index = 0; index < section.rows.length; index += 1) {
      const values = parseCopyRow(section.rows[index], section.columns.length);
      const primaryKey = idIndex >= 0 ? values[idIndex] : null;
      rows.push(JSON.stringify({
        table: key,
        ordinal: index + 1,
        primary_key: primaryKey,
        fingerprint: await hash(`${key}\n${section.rows[index]}`),
      }));
    }
  }
  const ledger = rows.join("\n") + (rows.length ? "\n" : "");
  const manifest = {
    target_ref: TARGET_REF,
    source_dump: dump,
    generated_at: new Date().toISOString(),
    selected_rows: rows.length,
    tables: counts,
    all_public_tables: data.allPublicSections.map((section) => section.table)
      .sort(),
    skipped_public: Object.fromEntries(
      data.skippedPublic.map((section) => [section.table, section.rows.length]),
    ),
    auth: Object.fromEntries(
      data.authSections.map((section) => [section.table, section.rows.length]),
    ),
    ledger_sha256: await hash(ledger),
  };
  await Deno.writeTextFile(`${output}/row-ledger.ndjson`, ledger, {
    mode: 0o600,
  });
  await Deno.writeTextFile(
    `${output}/restore-manifest.json`,
    `${JSON.stringify(manifest, null, 2)}\n`,
    { mode: 0o600 },
  );
  console.log(
    JSON.stringify(
      {
        mode: "ledger",
        output,
        selectedRows: rows.length,
        tables: Object.keys(counts).length,
      },
      null,
      2,
    ),
  );
}

async function withDatabase<T>(callback: (sql: DatabaseClient) => Promise<T>) {
  const postgres = (await import("npm:postgres@3.4.5")).default;
  const sql = postgres(required("TARGET_DB_URL"), {
    max: 1,
    prepare: false,
    idle_timeout: 0,
    connect_timeout: 15,
  });
  try {
    return await callback(sql);
  } finally {
    await sql.end({ timeout: 5 }).catch(() => undefined);
  }
}

async function targetColumns(sql: DatabaseClient): Promise<Column[]> {
  return await sql`
    select table_schema as schema, table_name as table, column_name as column,
      is_nullable = 'YES' as nullable, column_default as "defaultValue",
      is_generated as generated, is_identity as identity
    from information_schema.columns
    where table_schema in ('public', 'auth')
    order by table_schema, table_name, ordinal_position
  ` as Column[];
}

async function targetBaseTables(
  sql: DatabaseClient,
): Promise<Array<{ schema: string; table: string }>> {
  return await sql`
    select table_schema as schema, table_name as table
    from information_schema.tables
    where table_type = 'BASE TABLE' and table_schema in ('public', 'auth')
    order by table_schema, table_name
  ` as Array<{ schema: string; table: string }>;
}

function checkCompatibility(data: SelectedDump, columns: Column[]) {
  const target = new Map<string, Column[]>();
  for (const column of columns) {
    const key = `${column.schema}.${column.table}`;
    target.set(key, [...(target.get(key) ?? []), column]);
  }
  const failures: string[] = [];
  for (const section of sortedSections(data)) {
    const key = sectionKey(section);
    const actual = target.get(key);
    if (!actual) {
      failures.push(`${key} does not exist on target`);
      continue;
    }
    const actualByName = new Map(
      actual.map((column) => [column.column, column]),
    );
    for (const sourceColumn of section.columns) {
      const targetColumn = actualByName.get(sourceColumn);
      if (!targetColumn) {
        failures.push(`${key}.${sourceColumn} is absent on target`);
      } else if (targetColumn.generated !== "NEVER") {
        failures.push(`${key}.${sourceColumn} is generated on target`);
      }
    }
    for (const targetColumn of actual) {
      if (section.columns.includes(targetColumn.column)) continue;
      const needsValue = !targetColumn.nullable && !targetColumn.defaultValue &&
        targetColumn.generated === "NEVER" && targetColumn.identity === "NO";
      if (needsValue) {
        failures.push(
          `${key}.${targetColumn.column} is required but absent from source`,
        );
      }
    }
  }
  return failures;
}

async function preflight(dump: string, output: string) {
  assertExternalPath(output, "--output");
  const data = await loadSelected(dump);
  const result = await withDatabase(async (sql) => {
    const [columns, tables, project] = await Promise.all([
      targetColumns(sql),
      targetBaseTables(sql),
      sql`select current_database() as database, version() as version`,
    ]);
    const failures = checkCompatibility(data, columns);
    const targetPublic = new Set(
      tables.filter((table) => table.schema === "public").map((table) =>
        table.table
      ),
    );
    for (
      const table of data.allPublicSections.map((section) => section.table)
    ) {
      if (!targetPublic.has(table)) {
        failures.push(`public.${table} is absent on target`);
      }
    }
    return { project: project[0], failures };
  });
  const report = {
    target_ref: TARGET_REF,
    checked_at: new Date().toISOString(),
    selected_rows: sortedSections(data).reduce(
      (sum, section) => sum + section.rows.length,
      0,
    ),
    compatibility_failures: result.failures,
  };
  await Deno.mkdir(output, { recursive: true, mode: 0o700 });
  await Deno.writeTextFile(
    `${output}/preflight.json`,
    `${JSON.stringify(report, null, 2)}\n`,
    { mode: 0o600 },
  );
  if (result.failures.length) {
    throw new Error(
      `Target compatibility blocked: ${result.failures.join("; ")}`,
    );
  }
  await canonicalizeLedger(data, output);
  console.log(
    JSON.stringify(
      { mode: "preflight", target: TARGET_REF, compatibility: "passed" },
      null,
      2,
    ),
  );
}

function insertStatement(
  section: CopySection,
  values: Array<string | null>,
  offset: number,
) {
  const table = `${quoteIdentifier(section.schema)}.${
    quoteIdentifier(section.table)
  }`;
  const columns = section.columns.map(quoteIdentifier).join(", ");
  const placeholders = values.map((_, index) => `$${offset + index}`).join(
    ", ",
  );
  return `insert into ${table} (${columns}) values (${placeholders})`;
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

function sqlValues(values: Array<string | null>): string {
  return `(${values.map(sqlLiteral).join(", ")})`;
}

const FK_VALIDATION_SQL = String.raw`
do $$
declare
  fk record;
  non_null_predicate text;
  equality_predicate text;
  orphaned bigint;
begin
  for fk in
    select constraint_oid,
           child_schema,
           child_table,
           parent_schema,
           parent_table,
           match_type
    from (
      select c.oid as constraint_oid,
             child_ns.nspname as child_schema,
             child.relname as child_table,
             parent_ns.nspname as parent_schema,
             parent.relname as parent_table,
             c.confmatchtype as match_type
      from pg_constraint c
      join pg_class child on child.oid = c.conrelid
      join pg_namespace child_ns on child_ns.oid = child.relnamespace
      join pg_class parent on parent.oid = c.confrelid
      join pg_namespace parent_ns on parent_ns.oid = parent.relnamespace
      where c.contype = 'f'
        and child_ns.nspname in ('public', 'auth')
        and parent_ns.nspname in ('public', 'auth')
    ) constraints
  loop
    if fk.match_type <> 's' then
      raise exception 'Unsupported non-simple foreign-key match type for constraint %', fk.constraint_oid;
    end if;
    select string_agg(format('child.%I is not null', child_attr.attname), ' and ' order by child_key.ordinality),
           string_agg(format('parent.%I = child.%I', parent_attr.attname, child_attr.attname), ' and ' order by child_key.ordinality)
      into non_null_predicate, equality_predicate
    from pg_constraint c
    join lateral unnest(c.conkey) with ordinality as child_key(attnum, ordinality) on true
    join lateral unnest(c.confkey) with ordinality as parent_key(attnum, ordinality)
      on parent_key.ordinality = child_key.ordinality
    join pg_attribute child_attr
      on child_attr.attrelid = c.conrelid and child_attr.attnum = child_key.attnum
    join pg_attribute parent_attr
      on parent_attr.attrelid = c.confrelid and parent_attr.attnum = parent_key.attnum
    where c.oid = fk.constraint_oid;
    execute format(
      'select count(*) from %I.%I child where (%s) and not exists (select 1 from %I.%I parent where %s)',
      fk.child_schema, fk.child_table, non_null_predicate,
      fk.parent_schema, fk.parent_table, equality_predicate
    ) into orphaned;
    if orphaned > 0 then
      raise exception 'Foreign-key validation failed for constraint %: % orphaned row(s)', fk.constraint_oid, orphaned;
    end if;
  end loop;
end $$;
`;

const AUTH_STATE_DELETE_SQL = String.raw`
do $$
declare
  relation_to_delete record;
begin
  for relation_to_delete in
    with recursive descendants(schema_name, table_name) as (
      values ('auth'::name, 'users'::name)
      union
      select child_ns.nspname, child.relname
      from pg_constraint fk
      join pg_class child on child.oid = fk.conrelid
      join pg_namespace child_ns on child_ns.oid = child.relnamespace
      join pg_class parent on parent.oid = fk.confrelid
      join pg_namespace parent_ns on parent_ns.oid = parent.relnamespace
      join descendants parent_relation
        on parent_relation.schema_name = parent_ns.nspname
       and parent_relation.table_name = parent.relname
      where fk.contype = 'f' and child_ns.nspname = 'auth'
    )
    select schema_name, table_name from descendants order by schema_name, table_name desc
  loop
    execute format('delete from %I.%I', relation_to_delete.schema_name, relation_to_delete.table_name);
  end loop;
end $$;
`;

const STAGE_TABLE = "schooldesk_restore_stage_qzdhymlabzqjeocetqqv";
const STAGE_COLUMNS_TABLE =
  "schooldesk_restore_stage_columns_qzdhymlabzqjeocetqqv";
const STAGE_EXPECTED_TABLE =
  "schooldesk_restore_stage_expected_qzdhymlabzqjeocetqqv";

async function writeProtectedFile(path: string, contents: string) {
  await Deno.mkdir(path.slice(0, path.lastIndexOf("/")), {
    recursive: true,
    mode: 0o700,
  });
  await Deno.writeTextFile(path, contents, { mode: 0o600 });
}

async function writeCliStage(dump: string, output: string) {
  assertExternalPath(output, "--stage-dir");
  await Deno.mkdir(output, { recursive: true, mode: 0o700 });
  const data = await loadSelected(dump);
  const selectedSections = sortedSections(data);
  const create = [
    "begin;",
    String.raw`do $$ begin
  if to_regclass('public.${STAGE_TABLE}') is not null
     or to_regclass('public.${STAGE_COLUMNS_TABLE}') is not null
     or to_regclass('public.${STAGE_EXPECTED_TABLE}') is not null then
    raise exception 'restore staging tables already exist';
  end if;
end $$;`,
    `create table public.${STAGE_TABLE} (schema_name text not null, table_name text not null, ordinal integer not null, copy_values text[] not null, primary key (schema_name, table_name, ordinal));`,
    `create table public.${STAGE_COLUMNS_TABLE} (schema_name text not null, table_name text not null, position integer not null, column_name text not null, primary key (schema_name, table_name, position));`,
    `create table public.${STAGE_EXPECTED_TABLE} (schema_name text not null, table_name text not null, expected_count integer not null, primary key (schema_name, table_name));`,
    `revoke all on table public.${STAGE_TABLE}, public.${STAGE_COLUMNS_TABLE}, public.${STAGE_EXPECTED_TABLE} from public, anon, authenticated;`,
    "commit;",
  ].join("\n") + "\n";
  await writeProtectedFile(`${output}/000-create.sql`, create);

  const metadataLines: string[] = [];
  for (const section of selectedSections) {
    for (let index = 0; index < section.columns.length; index += 1) {
      metadataLines.push(
        `insert into public.${STAGE_COLUMNS_TABLE} values (${
          sqlLiteral(section.schema)
        }, ${sqlLiteral(section.table)}, ${index + 1}, ${
          sqlLiteral(section.columns[index])
        }) on conflict do nothing;`,
      );
    }
  }
  for (const section of selectedSections) {
    metadataLines.push(
      `insert into public.${STAGE_EXPECTED_TABLE} values (${
        sqlLiteral(section.schema)
      }, ${sqlLiteral(section.table)}, ${section.rows.length});`,
    );
  }
  for (
    let offset = 0, part = 0;
    offset < metadataLines.length;
    offset += 150, part += 1
  ) {
    const body =
      ["begin;", ...metadataLines.slice(offset, offset + 150), "commit;"].join(
        "\n",
      ) + "\n";
    await writeProtectedFile(
      `${output}/100-meta-${String(part).padStart(3, "0")}.sql`,
      body,
    );
  }

  const dataLines: string[] = [];
  for (const section of selectedSections) {
    for (let index = 0; index < section.rows.length; index += 1) {
      const values = parseCopyRow(section.rows[index], section.columns.length);
      dataLines.push(
        `(${sqlLiteral(section.schema)}, ${sqlLiteral(section.table)}, ${
          index + 1
        }, ARRAY[${values.map(sqlLiteral).join(", ")}]::text[])`,
      );
    }
  }
  for (
    let offset = 0, part = 0;
    offset < dataLines.length;
    offset += 100, part += 1
  ) {
    const body = [
      "begin;",
      `insert into public.${STAGE_TABLE} (schema_name, table_name, ordinal, copy_values) values`,
      `${dataLines.slice(offset, offset + 100).join(",\n")};`,
      "commit;",
    ].join("\n") + "\n";
    await writeProtectedFile(
      `${output}/200-data-${String(part).padStart(3, "0")}.sql`,
      body,
    );
  }

  const final = [
    "begin;",
    "set local session_replication_role = replica;",
    String.raw`
do $$
declare
  issue text;
begin
  select format('%s.%s is absent on target', e.schema_name, e.table_name)
    into issue
  from public.${STAGE_EXPECTED_TABLE} e
  left join information_schema.tables t on t.table_schema = e.schema_name and t.table_name = e.table_name and t.table_type = 'BASE TABLE'
  where t.table_name is null limit 1;
  if issue is not null then raise exception '%', issue; end if;
  select format('%s.%s.%s is absent on target', c.schema_name, c.table_name, c.column_name)
    into issue
  from public.${STAGE_COLUMNS_TABLE} c
  left join information_schema.columns t on t.table_schema = c.schema_name and t.table_name = c.table_name and t.column_name = c.column_name
  where t.column_name is null limit 1;
  if issue is not null then raise exception '%', issue; end if;
  select format('%s.%s.%s is required but absent from source', t.table_schema, t.table_name, t.column_name)
    into issue
  from information_schema.columns t
  join public.${STAGE_EXPECTED_TABLE} e on e.schema_name = t.table_schema and e.table_name = t.table_name
  left join public.${STAGE_COLUMNS_TABLE} c on c.schema_name = t.table_schema and c.table_name = t.table_name and c.column_name = t.column_name
  where c.column_name is null and t.is_nullable = 'NO' and t.column_default is null and t.is_generated = 'NEVER' and t.is_identity = 'NO'
  limit 1;
  if issue is not null then raise exception '%', issue; end if;
end $$;
`,
    AUTH_STATE_DELETE_SQL,
    ...data.allPublicSections.slice().sort((left, right) =>
      sectionKey(right).localeCompare(sectionKey(left))
    ).map((section) =>
      `delete from ${sqlTable(section.schema, section.table)};`
    ),
    String.raw`
do $$
declare
  selected record;
  columns_sql text;
  values_sql text;
begin
  for selected in select schema_name, table_name, expected_count from public.${STAGE_EXPECTED_TABLE} order by schema_name, table_name loop
    select string_agg(format('%I', c.column_name), ', ' order by c.position),
           string_agg(format('(stage.copy_values[%s])::%s', c.position, format_type(a.atttypid, a.atttypmod)), ', ' order by c.position)
      into columns_sql, values_sql
    from public.${STAGE_COLUMNS_TABLE} c
    join pg_class relation on relation.relname = selected.table_name
    join pg_namespace namespace on namespace.oid = relation.relnamespace and namespace.nspname = selected.schema_name
    join pg_attribute a on a.attrelid = relation.oid and a.attname = c.column_name and a.attnum > 0 and not a.attisdropped
    where c.schema_name = selected.schema_name and c.table_name = selected.table_name;
    execute format('insert into %I.%I (%s) select %s from public.${STAGE_TABLE} stage where stage.schema_name = %L and stage.table_name = %L order by stage.ordinal', selected.schema_name, selected.table_name, columns_sql, values_sql, selected.schema_name, selected.table_name);
  end loop;
end $$;
`,
    String.raw`
do $$
declare
  selected record;
  actual_count bigint;
begin
  for selected in select * from public.${STAGE_EXPECTED_TABLE} loop
    execute format('select count(*) from %I.%I', selected.schema_name, selected.table_name) into actual_count;
    if actual_count <> selected.expected_count then raise exception 'Restore count mismatch for %.%: expected %, found %', selected.schema_name, selected.table_name, selected.expected_count, actual_count; end if;
  end loop;
  if (select count(*) from auth.users) <> 93 then raise exception 'auth.users count mismatch'; end if;
  if (select count(*) from auth.identities) <> 93 then raise exception 'auth.identities count mismatch'; end if;
  if (select count(*) from auth.identities i join auth.users u on u.id = i.user_id) <> 93 then raise exception 'auth identity pairing mismatch'; end if;
end $$;
`,
    ...[...SKIPPED_PUBLIC].map((table) =>
      `do $$ begin if (select count(*) from ${
        sqlTable("public", table)
      }) <> 0 then raise exception 'Skipped table ${table} is not empty'; end if; end $$;`
    ),
    FK_VALIDATION_SQL,
    String.raw`
do $$
declare
  sequence_row record;
begin
  for sequence_row in select pg_get_serial_sequence(format('%I.%I', c.table_schema, c.table_name), c.column_name) as sequence_name, c.table_schema, c.table_name, c.column_name from information_schema.columns c join public.${STAGE_EXPECTED_TABLE} e on e.schema_name = c.table_schema and e.table_name = c.table_name where c.table_schema in ('public', 'auth') and pg_get_serial_sequence(format('%I.%I', c.table_schema, c.table_name), c.column_name) is not null loop
    execute format('select setval(%L::regclass, coalesce(max(%I), 1), count(*) > 0) from %I.%I', sequence_row.sequence_name, sequence_row.column_name, sequence_row.table_schema, sequence_row.table_name);
  end loop;
end $$;
`,
    `drop table public.${STAGE_TABLE}, public.${STAGE_COLUMNS_TABLE}, public.${STAGE_EXPECTED_TABLE};`,
    "set local session_replication_role = origin;",
    "commit;",
  ].join("\n") + "\n";
  await writeProtectedFile(`${output}/999-final.sql`, final);
  console.log(
    JSON.stringify(
      { mode: "cli-stage", output, dataChunks: Math.ceil(12_019 / 100) },
      null,
      2,
    ),
  );
}

async function writeCliReportSql(dump: string, output: string) {
  assertExternalPath(output, "--report-sql-output");
  const data = await loadSelected(dump);
  const selected = sortedSections(data);
  const tableEntries = selected.map((section) =>
    `(${sqlLiteral(sectionKey(section))}, (select count(*)::integer from ${
      sqlTable(section.schema, section.table)
    }))`
  );
  const skippedEntries = [...SKIPPED_PUBLIC].map((table) =>
    `(${sqlLiteral(`public.${table}`)}, (select count(*)::integer from ${
      sqlTable("public", table)
    }))`
  );
  const report = `select jsonb_build_object(
  'tables', (select jsonb_object_agg(table_name, row_count) from (values
    ${tableEntries.join(",\n    ")}
  ) as tables(table_name, row_count)),
  'skipped', (select jsonb_object_agg(table_name, row_count) from (values
    ${skippedEntries.join(",\n    ")}
  ) as skipped(table_name, row_count)),
  'auth', jsonb_build_object(
    'users', (select count(*)::integer from auth.users),
    'identities', (select count(*)::integer from auth.identities),
    'paired_identities', (select count(*)::integer from auth.identities i join auth.users u on u.id = i.user_id)
  ),
  'staging_tables', jsonb_build_object(
    'data', to_regclass('public.${STAGE_TABLE}') is not null,
    'columns', to_regclass('public.${STAGE_COLUMNS_TABLE}') is not null,
    'expected', to_regclass('public.${STAGE_EXPECTED_TABLE}') is not null
  )
) as restore_report;\n`;
  await writeProtectedFile(output, report);
  console.log(JSON.stringify({ mode: "cli-report-sql", output }, null, 2));
}

async function writeCliRestoreSql(dump: string, output: string) {
  assertExternalPath(output, "--sql-output");
  const data = await loadSelected(dump);
  const selectedSections = sortedSections(data);
  const lines: string[] = [
    "begin;",
    "set local session_replication_role = replica;",
    "create temporary table restore_source_columns (schema_name text, table_name text, column_name text) on commit drop;",
    "create temporary table restore_selected_counts (schema_name text, table_name text, expected_count integer) on commit drop;",
  ];
  const sourceColumns = data.allPublicSections.concat(data.authSections);
  for (const section of sourceColumns) {
    for (const column of section.columns) {
      lines.push(
        `insert into restore_source_columns values (${
          sqlLiteral(section.schema)
        }, ${sqlLiteral(section.table)}, ${sqlLiteral(column)});`,
      );
    }
  }
  for (const section of selectedSections) {
    lines.push(
      `insert into restore_selected_counts values (${
        sqlLiteral(section.schema)
      }, ${sqlLiteral(section.table)}, ${section.rows.length});`,
    );
  }
  lines.push(String.raw`
do $$
declare
  issue text;
begin
  select format('%s.%s.%s is absent on target', s.schema_name, s.table_name, s.column_name)
    into issue
  from restore_source_columns s
  left join information_schema.columns t
    on t.table_schema = s.schema_name
   and t.table_name = s.table_name
   and t.column_name = s.column_name
  where t.column_name is null
  limit 1;
  if issue is not null then raise exception '%', issue; end if;

  select format('%s.%s.%s is required but absent from source', t.table_schema, t.table_name, t.column_name)
    into issue
  from information_schema.columns t
  join restore_selected_counts selected
    on selected.schema_name = t.table_schema and selected.table_name = t.table_name
  left join restore_source_columns s
    on s.schema_name = t.table_schema and s.table_name = t.table_name and s.column_name = t.column_name
  where s.column_name is null
    and t.is_nullable = 'NO'
    and t.column_default is null
    and t.is_generated = 'NEVER'
    and t.is_identity = 'NO'
  limit 1;
  if issue is not null then raise exception '%', issue; end if;
end $$;
`);
  lines.push(AUTH_STATE_DELETE_SQL);
  for (
    const section of data.allPublicSections.slice().sort((left, right) =>
      sectionKey(right).localeCompare(sectionKey(left))
    )
  ) {
    lines.push(`delete from ${sqlTable(section.schema, section.table)};`);
  }
  for (const section of selectedSections) {
    if (!section.rows.length) continue;
    const columns = section.columns.map(quoteIdentifier).join(", ");
    const table = sqlTable(section.schema, section.table);
    for (let offset = 0; offset < section.rows.length; offset += 250) {
      const values = section.rows.slice(offset, offset + 250).map((row) =>
        sqlValues(parseCopyRow(row, section.columns.length))
      );
      lines.push(
        `insert into ${table} (${columns}) values\n${values.join(",\n")};`,
      );
    }
  }
  lines.push(String.raw`
do $$
declare
  selected record;
  actual_count bigint;
begin
  for selected in select * from restore_selected_counts loop
    execute format('select count(*) from %I.%I', selected.schema_name, selected.table_name) into actual_count;
    if actual_count <> selected.expected_count then
      raise exception 'Restore count mismatch for %.%: expected %, found %', selected.schema_name, selected.table_name, selected.expected_count, actual_count;
    end if;
  end loop;
  if (select count(*) from auth.users) <> 93 then raise exception 'auth.users count mismatch'; end if;
  if (select count(*) from auth.identities) <> 93 then raise exception 'auth.identities count mismatch'; end if;
  if (select count(*) from auth.identities i join auth.users u on u.id = i.user_id) <> 93 then raise exception 'auth identity pairing mismatch'; end if;
end $$;
`);
  for (const table of SKIPPED_PUBLIC) {
    lines.push(
      `do $$ begin if (select count(*) from ${
        sqlTable("public", table)
      }) <> 0 then raise exception 'Skipped table ${table} is not empty'; end if; end $$;`,
    );
  }
  lines.push(FK_VALIDATION_SQL);
  lines.push(String.raw`
do $$
declare
  sequence_row record;
begin
  for sequence_row in
    select pg_get_serial_sequence(format('%I.%I', c.table_schema, c.table_name), c.column_name) as sequence_name,
           c.table_schema, c.table_name, c.column_name
    from information_schema.columns c
    join restore_selected_counts selected
      on selected.schema_name = c.table_schema and selected.table_name = c.table_name
    where c.table_schema in ('public', 'auth')
      and pg_get_serial_sequence(format('%I.%I', c.table_schema, c.table_name), c.column_name) is not null
  loop
    execute format(
      'select setval(%L::regclass, coalesce(max(%I), 1), count(*) > 0) from %I.%I',
      sequence_row.sequence_name, sequence_row.column_name,
      sequence_row.table_schema, sequence_row.table_name
    );
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
  console.log(
    JSON.stringify({ mode: "cli-sql", output, selectedRows: 12_019 }, null, 2),
  );
}

type ForeignKey = { child: string; parent: string };

type ForeignKeyCheck = {
  name: string;
  childSchema: string;
  childTable: string;
  parentSchema: string;
  parentTable: string;
  childColumns: string[];
  parentColumns: string[];
  matchType: string;
};

async function foreignKeys(sql: DatabaseClient): Promise<ForeignKey[]> {
  const rows = await sql`
    select child_ns.nspname || '.' || child.relname as child,
           parent_ns.nspname || '.' || parent.relname as parent
    from pg_constraint fk
    join pg_class child on child.oid = fk.conrelid
    join pg_namespace child_ns on child_ns.oid = child.relnamespace
    join pg_class parent on parent.oid = fk.confrelid
    join pg_namespace parent_ns on parent_ns.oid = parent.relnamespace
    where fk.contype = 'f'
      and child_ns.nspname in ('public', 'auth')
      and parent_ns.nspname in ('public', 'auth')
  ` as ForeignKey[];
  return rows;
}

function authUserStateTables(relations: ForeignKey[]): string[] {
  // Only user-scoped Auth state is removed. Global Auth provider/configuration
  // rows are not descendants of auth.users and remain platform-managed.
  const tables = new Set(["auth.users"]);
  let changed = true;
  while (changed) {
    changed = false;
    for (const { child, parent } of relations) {
      if (
        !tables.has(parent) || !child.startsWith("auth.") || tables.has(child)
      ) {
        continue;
      }
      tables.add(child);
      changed = true;
    }
  }
  return [...tables].sort();
}

async function foreignKeyChecks(
  sql: DatabaseClient,
): Promise<ForeignKeyCheck[]> {
  return await sql`
    select fk.conname as name,
           child_ns.nspname as "childSchema",
           child.relname as "childTable",
           parent_ns.nspname as "parentSchema",
           parent.relname as "parentTable",
           array_agg(child_attr.attname order by child_key.ordinality) as "childColumns",
           array_agg(parent_attr.attname order by child_key.ordinality) as "parentColumns",
           fk.confmatchtype as "matchType"
    from pg_constraint fk
    join pg_class child on child.oid = fk.conrelid
    join pg_namespace child_ns on child_ns.oid = child.relnamespace
    join pg_class parent on parent.oid = fk.confrelid
    join pg_namespace parent_ns on parent_ns.oid = parent.relnamespace
    join lateral unnest(fk.conkey) with ordinality as child_key(attnum, ordinality) on true
    join lateral unnest(fk.confkey) with ordinality as parent_key(attnum, ordinality)
      on parent_key.ordinality = child_key.ordinality
    join pg_attribute child_attr
      on child_attr.attrelid = child.oid and child_attr.attnum = child_key.attnum
    join pg_attribute parent_attr
      on parent_attr.attrelid = parent.oid and parent_attr.attnum = parent_key.attnum
    where fk.contype = 'f'
      and child_ns.nspname in ('public', 'auth')
      and parent_ns.nspname in ('public', 'auth')
    group by fk.oid, fk.conname, child_ns.nspname, child.relname,
             parent_ns.nspname, parent.relname, fk.confmatchtype
    order by child_ns.nspname, child.relname, fk.conname
  ` as ForeignKeyCheck[];
}

async function validateForeignKeys(sql: DatabaseClient): Promise<string[]> {
  const checks = await foreignKeyChecks(sql);
  const failures: string[] = [];
  for (const fk of checks) {
    if (fk.matchType !== "s") {
      throw new Error(
        `Unsupported non-simple FK match type for ${fk.name}; restore is blocked`,
      );
    }
    const childTable = `${quoteIdentifier(fk.childSchema)}.${
      quoteIdentifier(fk.childTable)
    }`;
    const parentTable = `${quoteIdentifier(fk.parentSchema)}.${
      quoteIdentifier(fk.parentTable)
    }`;
    const nonNull = fk.childColumns.map((column) =>
      `child.${quoteIdentifier(column)} is not null`
    ).join(" and ");
    const equal = fk.childColumns.map((column, index) =>
      `parent.${quoteIdentifier(fk.parentColumns[index])} = child.${
        quoteIdentifier(column)
      }`
    ).join(" and ");
    const result = await sql.unsafe(
      `select count(*)::integer as count from ${childTable} child where (${nonNull}) and not exists (select 1 from ${parentTable} parent where ${equal})`,
    );
    const count = Number(result[0]?.count ?? 0);
    if (count) failures.push(`${fk.name}: ${count} orphaned row(s)`);
  }
  return failures;
}

async function repairSequences(
  sql: DatabaseClient,
  tables: string[],
) {
  for (const table of tables) {
    const [schema, name] = table.split(".");
    const columns = await sql`
      select column_name as column
      from information_schema.columns
      where table_schema = ${schema} and table_name = ${name}
    ` as Array<{ column: string }>;
    for (const { column } of columns) {
      const sequence = await sql`
        select pg_get_serial_sequence(${table}, ${column}) as sequence
      ` as Array<{ sequence: string | null }>;
      if (!sequence[0]?.sequence) continue;
      const target = `${quoteIdentifier(schema)}.${quoteIdentifier(name)}`;
      const maximum = await sql.unsafe(
        `select max(${
          quoteIdentifier(column)
        })::text as value, count(*)::integer as count from ${target}`,
      );
      const hasRows = Number(maximum[0]?.count ?? 0) > 0;
      await sql`
        select setval(${sequence[0].sequence}::regclass,
                      ${hasRows ? maximum[0].value : "1"}::bigint,
                      ${hasRows})
      `;
    }
  }
}

async function executeRestore(dump: string, output: string, ledgerDir: string) {
  if (!Deno.args.includes("--execute")) {
    throw new Error("restore requires --execute");
  }
  const data = await loadSelected(dump);
  const compatibility = await withDatabase(async (sql) =>
    checkCompatibility(data, await targetColumns(sql))
  );
  if (compatibility.length) {
    throw new Error(
      `Target compatibility blocked: ${compatibility.join("; ")}`,
    );
  }
  const allPublic = data.allPublicSections.map((section) =>
    `public.${section.table}`
  ).sort();
  const selectedSections = sortedSections(data);
  await withDatabase(async (sql) => {
    const relations = await foreignKeys(sql);
    const deleteOrder = [
      ...new Set([
        ...allPublic,
        ...authUserStateTables(relations),
      ]),
    ].sort().reverse();
    await sql.begin(async (tx: DatabaseClient) => {
      // The public organization/school cycle uses non-deferrable FKs. Replica
      // mode is scoped to this one transaction; it is never committed until
      // every target FK is explicitly revalidated below.
      await tx.unsafe("set local session_replication_role = replica");
      for (const key of deleteOrder) {
        const [schema, table] = key.split(".");
        await tx.unsafe(
          `delete from ${quoteIdentifier(schema)}.${quoteIdentifier(table)}`,
        );
      }

      for (const section of selectedSections) {
        for (const row of section.rows) {
          const values = parseCopyRow(row, section.columns.length);
          await tx.unsafe(insertStatement(section, values, 1), values);
        }
      }
      await repairSequences(tx, selectedSections.map(sectionKey));
      const foreignKeyFailures = await validateForeignKeys(tx);
      if (foreignKeyFailures.length) {
        throw new Error(
          `Foreign-key validation blocked commit: ${
            foreignKeyFailures.join("; ")
          }`,
        );
      }
      await tx.unsafe("set local session_replication_role = origin");
    });
  });
  await verifyRestore(dump, output, ledgerDir);
}

type LedgerRow = {
  table: string;
  ordinal: number;
  primary_key: string | null;
  fingerprint: string;
  canonical_fingerprint?: string;
};

async function readLedger(ledgerDir: string): Promise<LedgerRow[]> {
  assertExternalPath(ledgerDir, "--ledger-dir");
  const contents = await Deno.readTextFile(`${ledgerDir}/row-ledger.ndjson`);
  const rows = contents.trim().split("\n").filter(Boolean).map((line) =>
    JSON.parse(line) as LedgerRow
  );
  if (rows.length !== 12_019) {
    throw new Error(
      `Protected row ledger is incomplete: expected 12019, found ${rows.length}`,
    );
  }
  return rows;
}

type TargetColumnType = { column: string; type: string };

async function targetColumnTypes(
  sql: DatabaseClient,
  section: CopySection,
): Promise<TargetColumnType[]> {
  const rows = await sql`
    select attribute.attname as column,
           format_type(attribute.atttypid, attribute.atttypmod) as type
    from pg_attribute attribute
    join pg_class relation on relation.oid = attribute.attrelid
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = ${section.schema}
      and relation.relname = ${section.table}
      and attribute.attnum > 0
      and not attribute.attisdropped
    order by attribute.attnum
  ` as TargetColumnType[];
  const byName = new Map(rows.map((row) => [row.column, row.type]));
  return section.columns.map((column) => {
    const type = byName.get(column);
    if (!type) {
      throw new Error(
        `Target type is absent for ${sectionKey(section)}.${column}`,
      );
    }
    return { column, type };
  });
}

function copyTextExpression(value: string, isNull: string): string {
  return `case when ${isNull} then E'\\\\N' else replace(replace(replace(replace(replace(${value}, E'\\\\', E'\\\\\\\\'), E'\\t', E'\\\\t'), E'\\n', E'\\\\n'), E'\\r', E'\\\\r'), E'\\f', E'\\\\f') end`;
}

async function canonicalSourceRows(
  sql: DatabaseClient,
  section: CopySection,
): Promise<Array<{ ordinal: number; row: string }>> {
  const types = await targetColumnTypes(sql, section);
  const encoded = types.map(({ type }, index) =>
    copyTextExpression(
      `($${index + 1}::${type})::text`,
      `($${index + 1}::${type}) is null`,
    )
  );
  const statement = `select concat_ws(E'\\t', ${encoded.join(", ")}) as row`;
  const rows: Array<{ ordinal: number; row: string }> = [];
  for (let index = 0; index < section.rows.length; index += 1) {
    const result = await sql.unsafe(
      statement,
      parseCopyRow(section.rows[index], section.columns.length),
    );
    rows.push({ ordinal: index + 1, row: result[0].row });
  }
  return rows;
}

async function canonicalizeLedger(data: SelectedDump, ledgerDir: string) {
  const ledger = await readLedger(ledgerDir);
  const byTableOrdinal = new Map(
    ledger.map((row) => [`${row.table}:${row.ordinal}`, row]),
  );
  await withDatabase(async (sql) => {
    for (const section of sortedSections(data)) {
      const key = sectionKey(section);
      const rows = await canonicalSourceRows(sql, section);
      for (const canonical of rows) {
        const ledgerRow = byTableOrdinal.get(`${key}:${canonical.ordinal}`);
        if (!ledgerRow) {
          throw new Error(
            `Protected row ledger is missing ${key} ordinal ${canonical.ordinal}`,
          );
        }
        const sourceFingerprint = await hash(
          `${key}\n${section.rows[canonical.ordinal - 1]}`,
        );
        if (ledgerRow.fingerprint !== sourceFingerprint) {
          throw new Error(
            `Protected row ledger checksum mismatch at ${key} ordinal ${canonical.ordinal}`,
          );
        }
        ledgerRow.canonical_fingerprint = await hash(
          `${key}\n${canonical.row}`,
        );
      }
    }
  });
  if (ledger.some((row) => !row.canonical_fingerprint)) {
    throw new Error("Protected row ledger canonicalization is incomplete");
  }
  const serialized = ledger.map((row) => JSON.stringify(row)).join("\n") +
    "\n";
  const manifestPath = `${ledgerDir}/restore-manifest.json`;
  const manifest = JSON.parse(await Deno.readTextFile(manifestPath));
  manifest.ledger_sha256 = await hash(serialized);
  manifest.canonical_fingerprint_format = "postgres-copy-text-v1";
  manifest.canonicalized_at = new Date().toISOString();
  await Deno.writeTextFile(`${ledgerDir}/row-ledger.ndjson`, serialized, {
    mode: 0o600,
  });
  await Deno.writeTextFile(
    manifestPath,
    `${JSON.stringify(manifest, null, 2)}\n`,
    { mode: 0o600 },
  );
}

async function copyRows(
  sql: DatabaseClient,
  section: CopySection,
): Promise<string[]> {
  const table = `${quoteIdentifier(section.schema)}.${
    quoteIdentifier(section.table)
  }`;
  const escaped = section.columns.map((column) => {
    const value = `source.${quoteIdentifier(column)}::text`;
    const isNull = `source.${quoteIdentifier(column)} is null`;
    // This mirrors PostgreSQL COPY text encoding: null marker, delimiter,
    // backslash, tab, line feed, carriage return, and form feed.
    return copyTextExpression(value, isNull);
  });
  const rows = await sql.unsafe(
    `select concat_ws(E'\\t', ${
      escaped.join(", ")
    }) as row from ${table} source`,
  );
  return rows.map((row: { row: string }) => row.row);
}

async function fingerprintRows(
  table: string,
  rows: string[],
): Promise<string[]> {
  const fingerprints: string[] = [];
  for (const row of rows) fingerprints.push(await hash(`${table}\n${row}`));
  return fingerprints.sort();
}

async function verifyRestore(
  dump: string,
  output: string,
  ledgerDir: string,
) {
  assertExternalPath(output, "--output");
  const data = await loadSelected(dump);
  const sections = sortedSections(data);
  const ledger = await readLedger(ledgerDir);
  const expectedFingerprints = new Map<string, string[]>();
  for (const row of ledger) {
    if (!row.canonical_fingerprint) {
      throw new Error(
        "Protected row ledger has not passed canonical preflight",
      );
    }
    expectedFingerprints.set(row.table, [
      ...(expectedFingerprints.get(row.table) ?? []),
      row.canonical_fingerprint,
    ]);
  }
  const report = await withDatabase(async (sql) => {
    const counts: Record<string, { source: number; target: number }> = {};
    const fingerprintMismatches: Array<{
      table: string;
      expectedRows: number;
      actualRows: number;
    }> = [];
    for (const section of sections) {
      const key = sectionKey(section);
      const table = `${quoteIdentifier(section.schema)}.${
        quoteIdentifier(section.table)
      }`;
      const result = await sql.unsafe(
        `select count(*)::integer as count from ${table}`,
      );
      counts[key] = {
        source: section.rows.length,
        target: Number(result[0]?.count ?? 0),
      };
      const expected = (expectedFingerprints.get(key) ?? []).sort();
      const actual = await fingerprintRows(key, await copyRows(sql, section));
      if (
        expected.length !== actual.length ||
        expected.some((value, index) => value !== actual[index])
      ) {
        fingerprintMismatches.push({
          table: key,
          expectedRows: expected.length,
          actualRows: actual.length,
        });
      }
    }
    const skipped: Record<string, number> = {};
    for (const table of SKIPPED_PUBLIC) {
      const result = await sql.unsafe(
        `select count(*)::integer as count from "public".${
          quoteIdentifier(table)
        }`,
      );
      skipped[table] = Number(result[0]?.count ?? 0);
    }
    const auth = await sql`
      select (select count(*)::integer from auth.users) as users,
             (select count(*)::integer from auth.identities) as identities,
             (select count(*)::integer from auth.identities i join auth.users u on u.id = i.user_id) as paired_identities
    `;
    return { counts, skipped, auth: auth[0], fingerprintMismatches };
  });
  const mismatches = Object.entries(report.counts).filter(([, value]) =>
    value.source !== value.target
  );
  const skippedRows = Object.entries(report.skipped).filter(([, count]) =>
    count !== 0
  );
  const result = {
    target_ref: TARGET_REF,
    verified_at: new Date().toISOString(),
    ...report,
    passed: mismatches.length === 0 && skippedRows.length === 0 &&
      report.fingerprintMismatches.length === 0 &&
      Number(report.auth.users) === 93 &&
      Number(report.auth.identities) === 93 &&
      Number(report.auth.paired_identities) === 93,
    mismatches,
    skipped_rows_present: skippedRows,
    fingerprint_ledger_rows: ledger.length,
  };
  await Deno.mkdir(output, { recursive: true, mode: 0o700 });
  await Deno.writeTextFile(
    `${output}/database-restore-report.json`,
    `${JSON.stringify(result, null, 2)}\n`,
    { mode: 0o600 },
  );
  if (!result.passed) {
    throw new Error(
      "Database restore verification failed; inspect database-restore-report.json",
    );
  }
  console.log(
    JSON.stringify(
      { mode: "verify", passed: true, restoredTables: sections.length },
      null,
      2,
    ),
  );
}

const command = Deno.args[0] ?? "";
const dump = option("--dump", DEFAULT_DUMP);
const output = option(
  "--output",
  "/home/vinay/Documents/SchoolDesk-Backup/restore-output",
);
const ledgerDir = option("--ledger-dir", output);
if (!command || !dump) {
  throw new Error(
    "Use ledger, preflight, restore, or verify with --dump and --output",
  );
}
if (command === "ledger") await writeLedger(dump, output);
else if (command === "preflight") await preflight(dump, output);
else if (command === "restore") await executeRestore(dump, output, ledgerDir);
else if (command === "verify") await verifyRestore(dump, output, ledgerDir);
else if (command === "sql") {
  await writeCliRestoreSql(dump, option("--sql-output", output));
} else if (command === "stage") {
  await writeCliStage(dump, option("--stage-dir", output));
} else if (command === "report") {
  await writeCliReportSql(dump, option("--report-sql-output", output));
} else throw new Error(`Unknown command ${command}`);

// handlers/health.ts
import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ok } from "../index.ts";

async function checkDatabaseViaDirectConnection(): Promise<boolean> {
  const dbUrl = Deno.env.get("SUPABASE_DB_URL");
  if (!dbUrl) return false;

  let sql:
    | ((
      strings: TemplateStringsArray,
      ...values: unknown[]
    ) => Promise<unknown[]> & { end: (options?: { timeout?: number }) => Promise<void> })
    | null = null;

  try {
    const postgresModule = await import("npm:postgres@3.4.5");
    sql = postgresModule.default(dbUrl, {
      prepare: false,
      max: 1,
      idle_timeout: 1,
      connect_timeout: 5,
    });
    await sql`select 1 as ok`;
    return true;
  } catch (_error) {
    return false;
  } finally {
    if (sql) {
      await sql.end({ timeout: 1 }).catch(() => undefined);
    }
  }
}

export async function inspectDatabaseViaDirectConnection() {
  const dbUrl = Deno.env.get("SUPABASE_DB_URL");
  if (!dbUrl) {
    return { connected: false, reason: "missing_db_url" };
  }

  let sql:
    | ((
      strings: TemplateStringsArray,
      ...values: unknown[]
    ) => Promise<unknown[]> & { end: (options?: { timeout?: number }) => Promise<void> })
    | null = null;

  try {
    const postgresModule = await import("npm:postgres@3.4.5");
    sql = postgresModule.default(dbUrl, {
      prepare: false,
      max: 1,
      idle_timeout: 1,
      connect_timeout: 5,
    });
    const schools = await sql`
      select exists (
        select 1
        from information_schema.tables
        where table_schema = 'public' and table_name = 'schools'
      ) as exists
    `;
    const tables = await sql`
      select count(*)::int as total
      from information_schema.tables
      where table_schema = 'public'
    `;
    return {
      connected: true,
      schools_exists: schools[0]?.exists ?? false,
      public_table_count: tables[0]?.total ?? 0,
    };
  } catch (error) {
    return {
      connected: false,
      reason: error instanceof Error ? error.message : "unknown_error",
    };
  } finally {
    if (sql) {
      await sql.end({ timeout: 1 }).catch(() => undefined);
    }
  }
}

export async function handleHealth(
  _req: Request,
  path: string,
  svc: SupabaseClient,
): Promise<Response> {
  if (path === "/health") {
    return ok({
      status: "ok",
      timestamp: new Date().toISOString(),
      version: "2.0.0-supabase",
    });
  }

  // /ready — probe database
  let dbOk = await checkDatabaseViaDirectConnection();
  if (!dbOk) {
    try {
      const { error } = await svc.from("schools").select("id").limit(1);
      dbOk = !error;
    } catch (_) {
      dbOk = false;
    }
  }

  return ok({
    database: dbOk ? "ok" : "error",
    auth: "ok",
    storage: "ok",
    edge_function: "ok",
  });
}

// handlers/health.ts
import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ok } from "../index.ts";
import { r2Config } from "../lib/r2_storage.ts";

type DirectSql = {
  (strings: TemplateStringsArray, ...values: unknown[]): Promise<unknown[]>;
  end: (options?: { timeout?: number }) => Promise<void>;
};

async function checkDatabaseViaDirectConnection(): Promise<boolean> {
  const dbUrl = Deno.env.get("SUPABASE_DB_URL");
  if (!dbUrl) return false;

  let sql: DirectSql | null = null;

  try {
    const postgresModule = await import("npm:postgres@3.4.5");
    sql = postgresModule.default(dbUrl, {
      prepare: false,
      max: 1,
      idle_timeout: 1,
      connect_timeout: 5,
    }) as DirectSql;
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

  let sql: DirectSql | null = null;

  try {
    const postgresModule = await import("npm:postgres@3.4.5");
    sql = postgresModule.default(dbUrl, {
      prepare: false,
      max: 1,
      idle_timeout: 1,
      connect_timeout: 5,
    }) as DirectSql;
    const schools = await sql`
      select exists (
        select 1
        from information_schema.tables
        where table_schema = 'public' and table_name = 'schools'
      ) as exists
    ` as Array<{ exists?: boolean }>;
    const tables = await sql`
      select count(*)::int as total
      from information_schema.tables
      where table_schema = 'public'
    ` as Array<{ total?: number }>;
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
    const r2Configured = Boolean(r2Config());
    return ok({
      status: "ok",
      timestamp: new Date().toISOString(),
      version: "2.0.0-supabase-r2",
      storage: r2Configured ? "r2-configured" : "legacy-compatible",
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

  const r2Configured = Boolean(r2Config());
  const r2Required = (Deno.env.get("STORAGE_WRITE_PROVIDER") ?? "")
    .trim().toLowerCase() === "r2";
  return ok({
    database: dbOk ? "ok" : "error",
    auth: "ok",
    storage: r2Required && !r2Configured
      ? "error:r2_not_configured"
      : r2Configured
      ? "r2-configured"
      : "legacy-compatible",
    edge_function: "ok",
  });
}

declare namespace Deno {
  const env: {
    get(key: string): string | undefined;
  };

  function mkdir(path: string | URL, options?: { recursive?: boolean }): Promise<void>;
  function writeTextFile(path: string | URL, data: string): Promise<void>;
  function exit(code?: number): never;
}

declare module "https://esm.sh/@supabase/supabase-js@2" {
  export interface SupabaseClient {
    from<T>(table: string): {
      upsert(
        values: T[],
        options?: { onConflict?: string; ignoreDuplicates?: boolean },
      ): Promise<{ error: { message: string } | null }>;
    };
  }

  export function createClient(
    url: string,
    key: string,
    options?: { auth?: { persistSession: boolean } },
  ): SupabaseClient;
}

declare module "https://deno.land/x/postgres@v0.17.0/mod.ts" {
  export class Client {
    constructor(connectionString: string);
    connect(): Promise<void>;
    end(): Promise<void>;
    queryArray(query: string): Promise<{ rows: unknown[][] }>;
    queryObject(query: string): Promise<{ rows: unknown[] }>;
  }
}

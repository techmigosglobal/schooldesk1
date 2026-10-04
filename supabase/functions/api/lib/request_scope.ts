import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";

export type RequestScope = {
  readonly userId: string;
  readonly schoolId: string;
  readonly role: string;
};

/// Builds the only school/role scope handlers may use after authedClient has
/// validated the JWT and branch membership. Handlers must not read school_id
/// from an untrusted request body or query string.
export function requestScope(user: User): RequestScope {
  return {
    userId: user.id,
    schoolId: `${user.app_metadata?.school_id ?? ""}`.trim(),
    role: `${user.app_metadata?.role_name ?? ""}`.trim().toLowerCase(),
  };
}

export function sameSchool(scope: RequestScope, candidate: unknown): boolean {
  const value = `${candidate ?? ""}`.trim();
  return value.length === 0 ? false : value === scope.schoolId;
}

export function scopedSelect(
  svc: SupabaseClient,
  table: string,
  scope: RequestScope,
  columns = "*",
) {
  return svc.from(table).select(columns).eq("school_id", scope.schoolId);
}

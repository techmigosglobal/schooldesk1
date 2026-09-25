import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

function schoolId(user: User): string { return `${user.app_metadata?.school_id ?? ""}`; }
function isSuperAdmin(user: User): boolean { return user.app_metadata?.role_name === "super_admin"; }

export async function handleAccess(req: Request, path: string, method: string, _url: URL, _client: SupabaseClient, svc: SupabaseClient, user: User): Promise<Response> {
  if (!isSuperAdmin(user)) return fail("forbidden: super_admin required", 403);
  const school = schoolId(user);
  if (path === "/access/permissions" && method === "GET") {
    const { data: roles, error: roleError } = await svc.from("roles").select("id, role_name, description").eq("school_id", school).order("role_name");
    if (roleError) return fail(roleError.message);
    const ids = (roles ?? []).map((role: Record<string, unknown>) => role.id).filter(Boolean);
    const { data: permissions, error } = ids.length ? await svc.from("permissions").select("id, role_id, module, action").in("role_id", ids).order("module") : { data: [], error: null };
    if (error) return fail(error.message);
    return ok({ roles: roles ?? [], permissions: permissions ?? [] });
  }
  if (path === "/access/permissions" && method === "PUT") {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const roleId = `${body.role_id ?? ""}`.trim();
    const permissions = Array.isArray(body.permissions) ? body.permissions : null;
    if (!roleId || permissions === null) return fail("role_id and permissions are required", 420);
    const { data: role, error: roleError } = await svc.from("roles").select("id").eq("id", roleId).eq("school_id", school).maybeSingle();
    if (roleError || !role) return fail(roleError?.message ?? "Role not found", 404);
    const normalized = permissions.map((entry: unknown) => {
      const value = entry as Record<string, unknown>;
      return { school_id: school, role_id: roleId, module: `${value.module ?? ""}`.trim(), action: `${value.action ?? ""}`.trim() };
    }).filter((entry) => entry.module && entry.action);
    const { error: deleteError } = await svc.from("permissions").delete().eq("role_id", roleId);
    if (deleteError) return fail(deleteError.message);
    if (normalized.length > 0) {
      const { error } = await svc.from("permissions").insert(normalized);
      if (error) return fail(error.message);
    }
    return ok({ role_id: roleId, permissions: normalized });
  }
  return fail("not found", 404);
}

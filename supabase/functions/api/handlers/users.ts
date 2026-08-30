// handlers/users.ts — user account management
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";
import {
  canAssignAccountRole,
  canCreateParentAccount,
  canReadParentAccounts,
  canManageAccounts,
  normalizedRole as normalizeRole,
  roleName,
} from "./authorization.ts";
function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}
function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function temporaryPassword(): string {
  return `SD-${crypto.randomUUID().replaceAll("-", "").slice(0, 12)}!`;
}

function loginEmail(
  body: Record<string, unknown>,
  school: string,
): string {
  const email = text(body.email);
  if (email) return email;
  const username = text(body.username) || text(body.name) || "user";
  const slug = username.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(
    /^-|-$/g,
    "",
  ) || "user";
  return `${slug}.${school.slice(0, 8)}@schooldesk.local`;
}

function userInsertPayload(
  body: Record<string, unknown>,
  school: string,
  authUserId: string,
  normalizedRole: string,
) {
  return {
    id: authUserId,
    school_id: school,
    username: text(body.username) || null,
    name: text(body.name) || null,
    email: text(body.email) || null,
    phone: text(body.phone) || null,
    avatar: text(body.avatar) || null,
    role_name: normalizedRole,
    linked_type: text(body.linked_type) || null,
    linked_id: text(body.linked_id) || null,
    is_active: body.is_active ?? true,
    is_verified: true,
  };
}

async function syncUsernameAlias(
  svc: SupabaseClient,
  school: string,
  authUserId: string,
  username: string,
) {
  const { error: deleteError } = await svc.from("username_aliases").delete()
    .eq("auth_user_id", authUserId);
  if (deleteError) throw deleteError;
  if (!username) return;
  const { error } = await svc.from("username_aliases").upsert({
    username: username.toLowerCase(),
    auth_user_id: authUserId,
    school_id: school,
  }, { onConflict: "username" });
  if (error) throw error;
}

export async function handleUsers(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};
  const seg = path.slice("/users".length).split("/").filter(Boolean)[0];
  const isOwnRead = method === "GET" && Boolean(seg && seg === user.id);
  const isOwnAvatar = method === "POST" && path.endsWith("/avatar") &&
    Boolean(seg && seg === user.id);
  const requestedRole = method === "POST" && !seg
    ? normalizeRole((body as Record<string, unknown>).role_name ??
      (body as Record<string, unknown>).role)
    : null;
  const isCoordinatorParentCreate = method === "POST" && !seg &&
    canCreateParentAccount(user, requestedRole);
  const isParentDirectoryRead = method === "GET" && !seg &&
    canReadParentAccounts(user, url.searchParams.get("role"));
  // A Coordinator may update only an existing parent account. The target row
  // is checked again in the PATCH branch before any fields are changed.
  const isCoordinatorParentPatch = method === "PATCH" && Boolean(seg) &&
    roleName(user) === "coordinator";

  // Generic account management is more powerful than staff provisioning.
  // A Coordinator manages staff through /staff, but cannot use /users to mint
  // a parent, kiosk, admin, or platform identity.
  if (!canManageAccounts(user) && !isCoordinatorParentCreate &&
    !isParentDirectoryRead && !isCoordinatorParentPatch && !isOwnRead &&
    !isOwnAvatar) {
    return fail("forbidden", 403);
  }

  if (!seg && method === "GET") {
    const page = parseInt(url.searchParams.get("page") ?? "1");
    const size = parseInt(url.searchParams.get("page_size") ?? "100");
    let q = svc.from("users").select("*", { count: "exact" }).eq(
      "school_id",
      school,
    ).range((page - 1) * size, page * size - 1);
    const role = url.searchParams.get("role")?.trim();
    if (role) {
      // Published clients send display-cased roles (for example, "Parent"),
      // while account roles are stored normalized ("parent").
      q = q.ilike("role_name", role);
    }
    if (url.searchParams.get("status")) {
      q = q.eq("is_active", url.searchParams.get("status") === "active");
    }
    const { data, error, count } = await q;
    if (error) return fail(error.message);
    return cors({
      success: true,
      data: data ?? [],
      total: count ?? 0,
      page,
      page_size: size,
    });
  }

  if (!seg && method === "POST") {
    const { password, role, role_name, ...rest } = body;
    const roleName = `${role_name ?? role ?? ""}`.trim().toLowerCase() || "staff";
    const resolvedRole = normalizeRole(roleName);
    if (!resolvedRole) return fail("invalid account role", 422);
    if (!canAssignAccountRole(user, resolvedRole)) {
      return fail("forbidden account role assignment", 403);
    }
    const email = loginEmail(rest, school);
    // Create Supabase Auth user
    const { data: authUser, error: authErr } = await svc.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      app_metadata: { school_id: school, role_name: resolvedRole },
    });
    if (authErr) return fail(authErr.message);
    const { data, error } = await svc.from("users").insert(
      userInsertPayload(rest, school, authUser.user!.id, resolvedRole),
    ).select().single();
    if (error) return fail(error.message);
    try {
      await syncUsernameAlias(
        svc,
        school,
        authUser.user!.id,
        text(rest.username),
      );
    } catch (aliasError) {
      await svc.from("users").delete().eq("id", authUser.user!.id);
      await svc.auth.admin.deleteUser(authUser.user!.id);
      return fail(
        aliasError instanceof Error
          ? aliasError.message
          : "username unavailable",
      );
    }
    return ok(data);
  }

  if (seg && method === "GET") {
    const { data, error } = await svc.from("users").select("*").eq("id", seg)
      .eq("school_id", school).single();
    if (error) return fail(error.message);
    return ok(data);
  }

  if (seg && path.endsWith("/reset-credentials") && method === "POST") {
    const { data: target, error: targetError } = await svc.from("users")
      .select("id, username, school_id, role_name").eq("id", seg).eq(
        "school_id",
        school,
      )
      .maybeSingle();
    if (targetError) return fail(targetError.message);
    if (!target) return fail("user not found", 404);
    const password = temporaryPassword();
    const { error: authError } = await svc.auth.admin.updateUserById(seg, {
      password,
      app_metadata: {
        school_id: school,
        role_name: text(target.role_name),
        must_change_password: true,
      },
    });
    if (authError) return fail(authError.message);
    const { error: profileError } = await svc.from("users").update({
      must_change_password: true,
      password_reset_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }).eq("id", seg).eq("school_id", school);
    if (profileError) return fail(profileError.message);
    await svc.from("audit_logs").insert({
      school_id: school,
      user_id: user.id,
      action: "credentials.reset",
      entity_type: "user",
      entity_id: seg,
      details: { username: target.username, temporary_password_issued: true },
    });
    // This is intentionally the only response carrying the temporary secret.
    return ok({
      id: seg,
      username: target.username,
      temporary_password: password,
    });
  }

  if (seg && method === "PATCH") {
    const { password, role, role_name, ...patch } = body;
    const { data: target, error: targetError } = await svc.from("users").select(
      "id, school_id, role_name",
    ).eq("id", seg).eq("school_id", school).maybeSingle();
    if (targetError) return fail(targetError.message);
    if (!target) return fail("user not found", 404);
    const coordinatorParentTarget = roleName(user) === "coordinator" &&
      normalizeRole(target.role_name) === "parent";
    if (!canManageAccounts(user) && !coordinatorParentTarget) {
      return fail("forbidden", 403);
    }
    const resolvedRole = role_name ?? role;
    const resolvedNormalizedRole = resolvedRole === undefined
      ? null
      : normalizeRole(resolvedRole);
    if (resolvedRole !== undefined && !resolvedNormalizedRole) {
      return fail("invalid account role", 422);
    }
    if (resolvedNormalizedRole && !canAssignAccountRole(user, resolvedNormalizedRole)) {
      return fail("forbidden account role assignment", 403);
    }
    if (coordinatorParentTarget &&
      ((resolvedNormalizedRole && resolvedNormalizedRole !== "parent") ||
        patch.linked_type !== undefined || patch.linked_id !== undefined)) {
      return fail("Coordinator may update parent details only", 403);
    }
    const allowedKeys = coordinatorParentTarget
      ? ["username", "name", "email", "phone", "is_active"]
      : [
        "username",
        "name",
        "email",
        "phone",
        "avatar",
        "is_active",
        "linked_type",
        "linked_id",
      ];
    const allowedPatch = Object.fromEntries(
      allowedKeys
        .filter((key) => patch[key] !== undefined)
        .map((key) => [key, patch[key]]),
    );
    if (password || resolvedNormalizedRole || allowedPatch.email !== undefined) {
      const { error: authError } = await svc.auth.admin.updateUserById(seg, {
        ...(password ? { password } : {}),
        ...(allowedPatch.email ? { email: text(allowedPatch.email) } : {}),
        ...(resolvedNormalizedRole
          ? {
            app_metadata: {
              school_id: school,
              role_name: resolvedNormalizedRole,
            },
          }
          : {}),
      });
      if (authError) return fail(authError.message);
    }
    try {
      if (allowedPatch.username !== undefined) {
        await syncUsernameAlias(svc, school, seg, text(allowedPatch.username));
      }
    } catch (aliasError) {
      return fail(
        aliasError instanceof Error
          ? aliasError.message
          : "username unavailable",
        409,
      );
    }
    const { data, error } = await svc.from("users").update({
      ...allowedPatch,
      ...(resolvedNormalizedRole ? { role_name: resolvedNormalizedRole } : {}),
      updated_at: new Date().toISOString(),
    }).eq("id", seg).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  if (seg && path.endsWith("/avatar") && method === "POST") {
    const form = await req.formData().catch(() => null);
    const file = form?.get("avatar") as File | null;
    if (!file) return fail("avatar required");
    const filePath = `avatars/${school}/${seg}/${Date.now()}-${file.name}`;
    const { error: uploadError } = await svc.storage.from("school-assets")
      .upload(filePath, file, {
        upsert: true,
        contentType: file.type || "application/octet-stream",
        cacheControl: "31536000",
      });
    if (uploadError) return fail(uploadError.message);
    const { data: { publicUrl } } = svc.storage.from("school-assets")
      .getPublicUrl(filePath);
    const { error } = await svc.from("users").update({
      avatar: publicUrl,
      updated_at: new Date().toISOString(),
    }).eq("id", seg).eq("school_id", school);
    if (error) return fail(error.message);
    return ok({ avatar: publicUrl, avatar_url: publicUrl });
  }

  if (seg && method === "DELETE") {
    await svc.auth.admin.deleteUser(seg);
    await svc.from("users").delete().eq("id", seg).eq("school_id", school);
    return ok({ success: true });
  }

  // Toggle active
  if (path.endsWith("/activate") || path.endsWith("/deactivate")) {
    const uid = path.split("/")[2];
    const activate = path.endsWith("/activate");
    const { data, error } = await svc.from("users").update({
      is_active: activate,
    }).eq("id", uid).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  return fail("not found", 404);
}

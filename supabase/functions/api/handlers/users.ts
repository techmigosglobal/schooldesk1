// handlers/users.ts — user account management
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";
function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}
function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
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
  roleName: string,
) {
  return {
    id: authUserId,
    school_id: school,
    username: text(body.username) || null,
    name: text(body.name) || null,
    email: text(body.email) || null,
    phone: text(body.phone) || null,
    avatar: text(body.avatar) || null,
    role_name: roleName,
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
  await svc.from("username_aliases").delete().eq("auth_user_id", authUserId);
  if (!username) return;
  await svc.from("username_aliases").upsert({
    username: username.toLowerCase(),
    auth_user_id: authUserId,
    school_id: school,
  }, { onConflict: "username" });
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

  if (!seg && method === "GET") {
    const page = parseInt(url.searchParams.get("page") ?? "1");
    const size = parseInt(url.searchParams.get("page_size") ?? "100");
    let q = svc.from("users").select("*", { count: "exact" }).eq(
      "school_id",
      school,
    ).range((page - 1) * size, page * size - 1);
    if (url.searchParams.get("role")) {
      q = q.eq("role_name", url.searchParams.get("role")!);
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
    const resolvedRole = `${role_name ?? role ?? "staff"}`.trim() || "staff";
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
    await syncUsernameAlias(
      svc,
      school,
      authUser.user!.id,
      text(rest.username),
    );
    return ok(data);
  }

  if (seg && method === "GET") {
    const { data, error } = await svc.from("users").select("*").eq("id", seg)
      .eq("school_id", school).single();
    if (error) return fail(error.message);
    return ok(data);
  }

  if (seg && method === "PATCH") {
    const { password, role, role_name, ...patch } = body;
    const resolvedRole = role_name ?? role;
    if (password || resolvedRole) {
      await svc.auth.admin.updateUserById(seg, {
        ...(password ? { password } : {}),
        ...(resolvedRole
          ? { app_metadata: { school_id: school, role_name: resolvedRole } }
          : {}),
      });
    }
    const { data, error } = await svc.from("users").update({
      ...patch,
      ...(resolvedRole ? { role_name: resolvedRole } : {}),
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
      .upload(filePath, file, { upsert: true });
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

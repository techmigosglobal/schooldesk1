// handlers/auth.ts
// Login via username OR email → resolves to Supabase Auth
// Returns the legacy auth envelope: { token, refresh_token, expires_at, user }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { ok, fail, serviceClient } from "../index.ts";

function svc() {
  return serviceClient();
}

function profileText(value: unknown, fallback = ""): string {
  if (value === null || value === undefined) return fallback;
  const text = String(value).trim();
  return text.length ? text : fallback;
}

function normalizeProfileResponse(
  profile: Record<string, unknown> | null | undefined,
  authUser: { id?: string; email?: string | null },
): Record<string, unknown> {
  return {
    id: profileText(authUser.id ?? profile?.id),
    username: profileText(profile?.username),
    name: profileText(profile?.name, profileText(authUser.email)),
    email: profileText(authUser.email ?? profile?.email),
    phone: profileText(profile?.phone),
    avatar: profileText(profile?.avatar),
    school_id: profileText(profile?.school_id),
    role_id: profileText(profile?.role_id),
    role_name: profileText(profile?.role_name),
    linked_type: profileText(profile?.linked_type),
    linked_id: profileText(profile?.linked_id),
    is_active: profile?.is_active ?? true,
    is_verified: profile?.is_verified ?? false,
    roles: [],
    school: profile?.school ?? {},
  };
}

export async function handleAuth(
  req: Request,
  path: string,
  method: string,
  _url: URL,
): Promise<Response> {
  // ── POST /auth/login ────────────────────────────────────────
  if (path === "/auth/login" && method === "POST") {
    const body = await req.json().catch(() => ({}));
    const { username, email, password } = body as Record<string, string>;

    if (!password) return fail("password is required");

    let resolvedEmail = email?.trim() || "";

    // Resolve username → email via username_aliases, falling back to the users row.
    if (!resolvedEmail && username) {
      const cleanUsername = username.trim();
      const { data: alias } = await svc()
        .from("username_aliases")
        .select("auth_user_id, school_id")
        .eq("username", cleanUsername.toLowerCase())
        .maybeSingle();

      if (alias?.auth_user_id) {
        const { data: authUser, error: authErr } = await svc().auth.admin.getUserById(
          alias.auth_user_id,
        );
        if (authErr || !authUser?.user?.email) return fail("invalid username or password", 401);
        resolvedEmail = authUser.user.email;
      } else {
        const { data: userRow, error: userErr } = await svc()
          .from("users")
          .select("email")
          .ilike("username", cleanUsername)
          .maybeSingle();
        if (userErr) return fail("invalid username or password", 401);
        if (userRow?.email) {
          resolvedEmail = userRow.email;
        }
      }
    }

    if (!resolvedEmail) return fail("username or email is required");

    // Sign in with Supabase Auth
    const anonClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
    );
    const { data: session, error: signInError } = await anonClient.auth
      .signInWithPassword({ email: resolvedEmail, password });

    if (signInError || !session?.session) {
      return fail("invalid username or password", 401);
    }

    const { access_token, refresh_token, expires_at } = session.session;
    const authUser = session.user;

    // Fetch user profile row
    const { data: profile } = await svc()
      .from("users")
      .select("*, school:schools(id, name, school_type)")
      .eq("id", authUser.id)
      .maybeSingle();

    // Update last_login
    await svc().from("users").update({ last_login: new Date().toISOString() })
      .eq("id", authUser.id);

    return ok({
      // Flutter reads token OR access_token
      token: access_token,
      access_token,
      refresh_token,
      expires_at: expires_at ?? 0,
      user: {
        id: authUser.id,
        username: profile?.username ?? "",
        name: profile?.name ?? authUser.email,
        email: authUser.email,
        phone: profile?.phone ?? "",
        avatar: profile?.avatar ?? "",
        school_id: profile?.school_id ?? "",
        role_id: profile?.role_id ?? "",
        role_name: profile?.role_name ?? "",
        linked_type: profile?.linked_type ?? "",
        linked_id: profile?.linked_id ?? "",
        is_active: profile?.is_active ?? true,
        is_verified: profile?.is_verified ?? false,
      },
      profile: profile ?? {},
      school: profile?.school ?? {},
    });
  }

  // ── POST /auth/refresh ──────────────────────────────────────
  if (path === "/auth/refresh" && method === "POST") {
    const { refresh_token } = await req.json().catch(() => ({}));
    if (!refresh_token) return fail("refresh_token required");

    const anonClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
    );
    const { data, error } = await anonClient.auth.refreshSession({
      refresh_token,
    });
    if (error || !data.session) return fail("session expired", 401);

    return ok({
      token: data.session.access_token,
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
    });
  }

  // ── POST /auth/logout ───────────────────────────────────────
  if (path === "/auth/logout" && method === "POST") {
    const token = req.headers.get("Authorization")?.replace("Bearer ", "");
    if (token) {
      const userClient = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_ANON_KEY")!,
        { global: { headers: { Authorization: `Bearer ${token}` } } },
      );
      await userClient.auth.signOut();
    }
    return ok({ success: true });
  }

  // ── POST /auth/password ─────────────────────────────────────
  if (path === "/auth/password" && method === "POST") {
    const token = req.headers.get("Authorization")?.replace("Bearer ", "");
    const { new_password } = await req.json().catch(() => ({}));
    if (!new_password) return fail("new_password required");

    const { data: { user } } = await createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: `Bearer ${token}` } } },
    ).auth.getUser();
    if (!user) return fail("unauthorized", 401);

    const { error } = await svc().auth.admin.updateUserById(user.id, {
      password: new_password,
    });
    if (error) return fail(error.message);
    return ok({ success: true });
  }

  // ── GET /auth/profile ────────────────────────────────────────
  if (path === "/auth/profile" && method === "GET") {
    const token = req.headers.get("Authorization")?.replace("Bearer ", "");
    const { data: { user } } = await createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: `Bearer ${token}` } } },
    ).auth.getUser();
    if (!user) return fail("unauthorized", 401);

    const { data: profile } = await svc()
      .from("users")
      .select("*")
      .eq("id", user.id)
      .maybeSingle();

    return ok(normalizeProfileResponse(profile, user));
  }

  // ── PATCH /auth/profile ──────────────────────────────────────
  if (path === "/auth/profile" && method === "PATCH") {
    const token = req.headers.get("Authorization")?.replace("Bearer ", "");
    const { data: { user } } = await createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: `Bearer ${token}` } } },
    ).auth.getUser();
    if (!user) return fail("unauthorized", 401);

    const body = await req.json().catch(() => ({}));
    const allowed = ["name", "phone", "language", "notification_preferences"];
    const patch: Record<string, unknown> = {};
    for (const key of allowed) {
      if (body[key] !== undefined) patch[key] = body[key];
    }

    const { data: profile, error } = await svc()
      .from("users")
      .update({ ...patch, updated_at: new Date().toISOString() })
      .eq("id", user.id)
      .select()
      .single();

    if (error) return fail(error.message);
    return ok(normalizeProfileResponse(profile, user));
  }

  if (path === "/auth/profile/avatar" && method === "POST") {
    const token = req.headers.get("Authorization")?.replace("Bearer ", "");
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: `Bearer ${token}` } } },
    );
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return fail("unauthorized", 401);

    const form = await req.formData().catch(() => null);
    const file = form?.get("avatar") as File | null;
    if (!file) return fail("avatar required");

    const { data: profile } = await svc().from("users").select("school_id").eq(
      "id",
      user.id,
    ).maybeSingle();
    const filePath =
      `avatars/${profile?.school_id ?? "common"}/${user.id}/${Date.now()}-${file.name}`;
    const { error: uploadError } = await svc().storage.from("school-assets")
      .upload(filePath, file, { upsert: true });
    if (uploadError) return fail(uploadError.message);
    const { data: { publicUrl } } = svc().storage.from("school-assets")
      .getPublicUrl(filePath);

    const { error: updateError } = await svc().from("users").update({
      avatar: publicUrl,
      updated_at: new Date().toISOString(),
    }).eq("id", user.id);
    if (updateError) return fail(updateError.message);
    return ok({ avatar: publicUrl, avatar_url: publicUrl });
  }

  return fail("not found", 404);
}

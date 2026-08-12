// handlers/auth.ts
// Login via username OR email → resolves to Supabase Auth
// Returns the legacy auth envelope: { token, refresh_token, expires_at, user }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, serviceClient } from "../index.ts";
import { recordActivity } from "./activity.ts";

function svc() {
  return serviceClient();
}

function profileText(value: unknown, fallback = ""): string {
  if (value === null || value === undefined) return fallback;
  const text = String(value).trim();
  return text.length ? text : fallback;
}

function normalizedUsername(value: unknown): string {
  return profileText(value).toLowerCase();
}

async function updateOwnUsernameAlias(
  schoolId: string,
  authUserId: string,
  username: string,
): Promise<string | null> {
  const { data: existing, error: lookupError } = await svc()
    .from("username_aliases")
    .select("auth_user_id")
    .eq("username", username)
    .maybeSingle();
  if (lookupError) return lookupError.message;
  if (existing?.auth_user_id && existing.auth_user_id !== authUserId) {
    return "That username is already in use";
  }

  const { error: removeError } = await svc().from("username_aliases").delete()
    .eq("auth_user_id", authUserId).neq("username", username);
  if (removeError) return removeError.message;
  if (existing?.auth_user_id === authUserId) return null;

  const { error: insertError } = await svc().from("username_aliases").insert({
    username,
    auth_user_id: authUserId,
    school_id: schoolId,
  });
  return insertError?.message ?? null;
}

/**
 * Repairs a legacy parent import only when its guardian-phone match identifies
 * exactly one child. Existing parent links are never changed or augmented here:
 * ambiguous and already-linked accounts remain untouched for a school admin to
 * review.
 */
async function repairUnambiguousParentStudentLink(
  profile: Record<string, unknown>,
  authUserId: string,
  normalizedRole: string,
) {
  if (normalizedRole !== "parent") return;
  const schoolId = profileText(profile.school_id);
  const phone = profileText(profile.phone);
  if (!schoolId || !phone) return;

  const { data: existingLinks, error: existingError } = await svc().from(
    "parent_student_links",
  ).select("student_id").eq("school_id", schoolId).eq(
    "parent_user_id",
    authUserId,
  ).limit(1);
  if (existingError || (existingLinks?.length ?? 0) > 0) return;

  const { data: guardians, error: guardianError } = await svc().from(
    "guardians",
  ).select("student_id").eq("school_id", schoolId).eq("phone", phone);
  if (guardianError) return;
  const studentIds = [
    ...new Set(
      (guardians ?? []).map((guardian) => profileText(guardian.student_id))
        .filter(Boolean),
    ),
  ];
  if (studentIds.length !== 1) return;

  await svc().from("parent_student_links").upsert({
    school_id: schoolId,
    parent_user_id: authUserId,
    student_id: studentIds[0],
  }, { onConflict: "parent_user_id,student_id" });
}

function normalizeProfileResponse(
  profile: Record<string, unknown> | null | undefined,
  authUser: {
    id?: string;
    email?: string | null;
    app_metadata?: Record<string, unknown>;
  },
): Record<string, unknown> {
  // Prefer app_metadata.role_name (set at login, always authoritative) over
  // public.users.role_name which can be stale after role changes.
  const appMetaRole = profileText(authUser.app_metadata?.role_name);
  const publicRole = profileText(profile?.role_name);
  return {
    id: profileText(authUser.id ?? profile?.id),
    username: profileText(profile?.username),
    name: profileText(profile?.name, profileText(authUser.email)),
    email: profileText(authUser.email ?? profile?.email),
    phone: profileText(profile?.phone),
    avatar: profileText(profile?.avatar),
    school_id: profileText(profile?.school_id),
    role_id: profileText(profile?.role_id),
    role_name: (appMetaRole || publicRole).toLowerCase(),
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

    // Resolve username → Auth email.  Alias lookup is the normal path, but older
    // accounts can predate username_aliases or have a stale public profile email.
    // In that case, resolve through the user's immutable Auth id instead of
    // depending on a copy of the Auth email in public.users.
    if (!resolvedEmail && username) {
      const cleanUsername = username.trim();
      const { data: alias } = await svc()
        .from("username_aliases")
        .select("auth_user_id, school_id")
        .eq("username", cleanUsername.toLowerCase())
        .maybeSingle();

      if (alias?.auth_user_id) {
        const { data: authUser, error: authErr } = await svc().auth.admin
          .getUserById(
            alias.auth_user_id,
          );
        if (authErr || !authUser?.user?.email) {
          return fail("invalid username or password", 401);
        }
        resolvedEmail = authUser.user.email;
      } else {
        const { data: userRow, error: userErr } = await svc()
          .from("users")
          .select("id, email, school_id, username")
          .ilike("username", cleanUsername)
          .maybeSingle();
        if (userErr) return fail("invalid username or password", 401);
        if (userRow?.id) {
          const { data: authUser, error: authErr } = await svc().auth.admin
            .getUserById(userRow.id);
          if (authErr || !authUser?.user?.email) {
            return fail("invalid username or password", 401);
          }
          resolvedEmail = authUser.user.email;

          // Best-effort self-healing for a legacy account that has no alias.
          // A conflicting alias is never overwritten and a repair failure must
          // not prevent a valid password login.
          const storedUsername = normalizedUsername(userRow.username);
          if (
            storedUsername &&
            storedUsername === normalizedUsername(cleanUsername)
          ) {
            await updateOwnUsernameAlias(
              profileText(userRow.school_id),
              authUser.user.id,
              storedUsername,
            );
          }
        } else if (userRow?.email) {
          // Kept only as a defensive fallback for an account whose Auth record
          // was removed; the subsequent password grant will still reject it.
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

    // Safety check: if the login succeeded but the email we resolved belongs
    // to a different user than what the alias pointed at, abort.  This guards
    // against a stale / cross-school alias pointing to the wrong account.
    if (username?.trim() && session.user.email !== resolvedEmail) {
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

    if (!profile || profile.is_active !== true) {
      await anonClient.auth.signOut();
      return fail("account is no longer active", 401);
    }

    // Update last_login
    await svc().from("users").update({ last_login: new Date().toISOString() })
      .eq("id", authUser.id);

    // app_metadata.role_name is set by the admin at user-creation time and is
    // the authoritative source.  public.users.role_name can lag if the row was
    // created before the role was assigned, so we prefer app_metadata and fall
    // back to the profile row only when app_metadata has nothing.
    const appMetaRole = profileText(
      (authUser.app_metadata as Record<string, unknown> | undefined)?.role_name,
    );
    const resolvedRole = appMetaRole || profileText(profile?.role_name);
    const normalizedRole = resolvedRole.toLowerCase();
    await repairUnambiguousParentStudentLink(
      profile,
      authUser.id,
      normalizedRole,
    );
    const now = new Date().toISOString();
    await svc().from("user_sessions").insert({
      user_id: authUser.id,
      school_id: profile.school_id,
      role_name: normalizedRole,
      session_type: normalizedRole === "kiosk" ? "kiosk" : "app",
      last_active: now,
    });
    await recordActivity(svc(), {
      schoolId: profile.school_id,
      userId: authUser.id,
      actorRole: normalizedRole,
      action: "auth.login",
      module: "auth",
      eventType: "login",
      summary: normalizedRole === "kiosk"
        ? "Attendance kiosk signed in"
        : `${normalizedRole || "User"} signed in`,
      entityType: "user",
      entityId: authUser.id,
      actorName: profileText(profile.name, profileText(authUser.email)),
      details: { session_type: normalizedRole === "kiosk" ? "kiosk" : "app" },
    });

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
        role_name: normalizedRole,
        linked_type: profile?.linked_type ?? "",
        linked_id: profile?.linked_id ?? "",
        is_active: profile?.is_active ?? true,
        is_verified: profile?.is_verified ?? false,
      },
      profile: { ...(profile ?? {}), role_name: normalizedRole },
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

    const { data: profile } = await svc().from("users")
      .select("id, is_active").eq("id", data.session.user.id).maybeSingle();
    if (!profile || profile.is_active !== true) {
      await anonClient.auth.signOut();
      return fail("account is no longer active", 401);
    }

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
      const { data: { user } } = await userClient.auth.getUser();
      if (user) {
        const { data: profile } = await svc().from("users")
          .select("school_id, role_name, name, email")
          .eq("id", user.id)
          .maybeSingle();
        const role = profileText(
          user.app_metadata?.role_name,
          profileText(profile?.role_name),
        )
          .toLowerCase();
        const now = new Date().toISOString();
        await svc().from("user_sessions").update({
          signed_out_at: now,
          last_active: now,
        }).eq("user_id", user.id).is("signed_out_at", null);
        if (profile?.school_id) {
          await recordActivity(svc(), {
            schoolId: profile.school_id,
            userId: user.id,
            actorRole: role,
            action: "auth.logout",
            module: "auth",
            eventType: "logout",
            summary: role === "kiosk"
              ? "Attendance kiosk signed out"
              : `${role || "User"} signed out`,
            entityType: "user",
            entityId: user.id,
            actorName: profileText(profile.name, profileText(user.email)),
            details: { session_type: role === "kiosk" ? "kiosk" : "app" },
          });
        }
      }
      await userClient.auth.signOut();
    }
    return ok({ success: true });
  }

  // ── POST /auth/password ─────────────────────────────────────
  if (path === "/auth/password" && method === "POST") {
    const token = req.headers.get("Authorization")?.replace("Bearer ", "");
    const { current_password, new_password } = await req.json().catch(
      () => ({}),
    );
    if (!current_password) return fail("current_password required");
    if (!new_password || profileText(new_password).length < 8) {
      return fail("new_password must be at least 8 characters");
    }

    const { data: { user } } = await createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: `Bearer ${token}` } } },
    ).auth.getUser();
    if (!user) return fail("unauthorized", 401);

    const email = profileText(user.email);
    if (!email) return fail("account email is unavailable", 400);
    const verifier = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
    );
    const { error: verificationError } = await verifier.auth
      .signInWithPassword({ email, password: profileText(current_password) });
    if (verificationError) return fail("Current password is incorrect", 401);

    const { error } = await svc().auth.admin.updateUserById(user.id, {
      password: new_password,
      app_metadata: {
        ...user.app_metadata,
        must_change_password: false,
      },
    });
    if (error) return fail(error.message);
    const { error: profileError } = await svc()
      .from("users")
      .update({ must_change_password: false })
      .eq("id", user.id);
    if (profileError) return fail(profileError.message);
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
    const allowed = [
      "name",
      "phone",
      "language",
      "notification_preferences",
      "email",
    ];
    const patch: Record<string, unknown> = {};
    for (const key of allowed) {
      if (body[key] !== undefined) patch[key] = body[key];
    }
    if (body.username !== undefined) {
      const username = normalizedUsername(body.username);
      if (!/^[a-z0-9._-]{3,40}$/.test(username)) {
        return fail(
          "Username must be 3-40 characters and use only letters, numbers, dots, hyphens, or underscores",
        );
      }
      const aliasError = await updateOwnUsernameAlias(
        profileText(user.app_metadata?.school_id),
        user.id,
        username,
      );
      if (aliasError) return fail(aliasError, 409);
      patch.username = username;
    }
    if (patch.email !== undefined) {
      const email = profileText(patch.email).toLowerCase();
      if (!/^\S+@\S+\.\S+$/.test(email)) {
        return fail("valid email required", 422);
      }
      const { error: authError } = await svc().auth.admin.updateUserById(
        user.id,
        {
          email,
          email_confirm: true,
        },
      );
      if (authError) return fail(authError.message);
      patch.email = email;
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
    const filePath = `avatars/${
      profile?.school_id ?? "common"
    }/${user.id}/${Date.now()}-${file.name}`;
    const { error: uploadError } = await svc().storage.from("school-assets")
      .upload(filePath, file, {
        upsert: true,
        contentType: file.type || "application/octet-stream",
        cacheControl: "31536000",
      });
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

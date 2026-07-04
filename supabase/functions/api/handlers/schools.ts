// handlers/schools.ts
import { SupabaseClient, User as _User } from "https://esm.sh/@supabase/supabase-js@2";
import { ok, fail } from "../index.ts";

export async function handleSchools(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  client: SupabaseClient | null,
  svc: SupabaseClient,
): Promise<Response> {
  // POST /schools/setup — create school + admin user (no prior auth)
  if (path === "/schools/setup" && method === "POST") {
    const body = await req.json().catch(() => ({}));
    const { school_name, admin_email, admin_password, admin_name, admin_username } = body;
    if (!school_name || !admin_email || !admin_password) {
      return fail("school_name, admin_email, admin_password are required");
    }

    // 1. Create school
    const { data: school, error: schoolErr } = await svc
      .from("schools")
      .insert({
        name: school_name,
        school_type: body.school_type ?? "school",
        affiliation_board: body.affiliation_board ?? "",
        email: body.email ?? admin_email,
        phone: body.phone ?? "",
        city: body.city ?? "",
        state: body.state ?? "",
      })
      .select()
      .single();
    if (schoolErr) return fail(schoolErr.message);

    // 2. Create Supabase Auth user
    const { data: authUser, error: authErr } = await svc.auth.admin.createUser({
      email: admin_email,
      password: admin_password,
      email_confirm: true,
      app_metadata: {
        school_id: school.id,
        role_name: body.admin_role ?? "principal",
      },
    });
    if (authErr) return fail(authErr.message);

    // 3. Create internal user row
    const { data: userRow, error: userErr } = await svc
      .from("users")
      .insert({
        id: authUser.user!.id,
        school_id: school.id,
        username: admin_username ?? admin_email,
        name: admin_name,
        email: admin_email,
        phone: body.admin_phone ?? "",
        role_name: body.admin_role ?? "principal",
        is_active: true,
        is_verified: true,
      })
      .select()
      .single();
    if (userErr) return fail(userErr.message);

    // 4. Insert username alias
    if (admin_username) {
      await svc.from("username_aliases").insert({
        username: admin_username.toLowerCase(),
        auth_user_id: authUser.user!.id,
        school_id: school.id,
      });
    }

    // 5. Sign in to get tokens
    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    const anonClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
    );
    const { data: session } = await anonClient.auth.signInWithPassword({
      email: admin_email,
      password: admin_password,
    });

    return ok({
      school,
      admin_user: userRow,
      auth: {
        token: session?.session?.access_token ?? "",
        access_token: session?.session?.access_token ?? "",
        refresh_token: session?.session?.refresh_token ?? "",
        expires_at: session?.session?.expires_at ?? 0,
        user: userRow,
      },
    });
  }

  if (!client) return fail("unauthorized", 401);

  // GET /schools/current
  if ((path === "/schools/current" || path === "/schools") && method === "GET") {
    const { data: { user } } = await client.auth.getUser();
    if (!user) return fail("unauthorized", 401);
    const { data: profile } = await svc.from("users").select("school_id").eq("id", user.id).single();
    const { data: school, error } = await svc.from("schools").select("*").eq("id", profile?.school_id).single();
    if (error) return fail(error.message);
    return ok(school);
  }

  // PATCH /schools/current
  if (path === "/schools/current" && method === "PATCH") {
    const body = await req.json().catch(() => ({}));
    const { data: { user } } = await client.auth.getUser();
    const { data: profile } = await svc.from("users").select("school_id").eq("id", user!.id).single();
    const { data: school, error } = await svc
      .from("schools")
      .update({ ...body, updated_at: new Date().toISOString() })
      .eq("id", profile?.school_id)
      .select()
      .single();
    if (error) return fail(error.message);
    return ok(school);
  }

  // POST /schools/current/logo — multipart upload
  if (path === "/schools/current/logo" && method === "POST") {
    const form = await req.formData();
    const file = form.get("logo") as File;
    if (!file) return fail("logo file required");
    const { data: { user } } = await client.auth.getUser();
    const { data: profile } = await svc.from("users").select("school_id").eq("id", user!.id).single();
    const path2 = `logos/${profile?.school_id}/${Date.now()}-${file.name}`;
    const { error } = await svc.storage.from("school-assets").upload(path2, file, { upsert: true });
    if (error) return fail(error.message);
    const { data: { publicUrl } } = svc.storage.from("school-assets").getPublicUrl(path2);
    await svc.from("schools").update({ logo_url: publicUrl }).eq("id", profile?.school_id);
    return ok({ logo_url: publicUrl });
  }

  return fail("not found", 404);
}

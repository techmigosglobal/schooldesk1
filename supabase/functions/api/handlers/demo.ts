import { createClient, SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

const text = (value: unknown) => `${value ?? ""}`.trim();
const isSuperAdmin = (user: User) =>
  text(user.app_metadata?.role_name).toLowerCase() === "super_admin";
const encoder = new TextEncoder();
const decoder = new TextDecoder();

function temporaryPassword() {
  const bytes = crypto.getRandomValues(new Uint16Array(1));
  return `Demo@${100 + (bytes[0] % 900)}`;
}

async function nextDemoUsername(svc: SupabaseClient) {
  const { data } = await svc.from("demo_accounts").select("username");
  const used = new Set((data ?? []).map((row) => text(row.username).toLowerCase()));
  let suffix = 1;
  while (used.has(`demo${suffix}`)) suffix += 1;
  return `demo${suffix}`;
}

async function credentialKey() {
  const raw = Deno.env.get("DEMO_CREDENTIAL_WRAP_KEY") ?? "";
  if (raw.length < 32) throw new Error("DEMO_CREDENTIAL_WRAP_KEY must be at least 32 characters");
  return crypto.subtle.importKey("raw", encoder.encode(raw.slice(0, 32)), "AES-GCM", false, ["encrypt", "decrypt"]);
}

const b64 = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes));
const unb64 = (value: string) => Uint8Array.from(atob(value), (char) => char.charCodeAt(0));

async function seal(secret: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await credentialKey();
  const bytes = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, encoder.encode(secret)));
  return JSON.stringify({ iv: b64(iv), value: b64(bytes) });
}

async function openSecret(value: string) {
  const payload = JSON.parse(value) as { iv: string; value: string };
  const key = await credentialKey();
  const bytes = await crypto.subtle.decrypt({ name: "AES-GCM", iv: unb64(payload.iv) }, key, unb64(payload.value));
  return decoder.decode(bytes);
}

async function rotate(svc: SupabaseClient, account: Record<string, unknown>) {
  const authUserId = text(account.auth_user_id);
  if (!authUserId) throw new Error("demo account has no authentication user");
  const password = temporaryPassword();
  const now = new Date();
  const ciphertext = await seal(password);
  const { error } = await svc.auth.admin.updateUserById(authUserId, { password });
  if (error) throw error;
  const { error: updateError } = await svc.from("demo_accounts").update({
    password_secret_ciphertext: ciphertext,
    password_secret_expires_at: new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString(),
    password_revealed_at: null,
    password_rotated_at: now.toISOString(),
  }).eq("id", account.id);
  if (updateError) throw updateError;
  return password;
}

function safeAccount(account: Record<string, unknown>) {
  const { password_secret_ciphertext: _secret, ...safe } = account;
  return safe;
}

export async function handleDemo(
  req: Request,
  path: string,
  method: string,
  svc: SupabaseClient,
  user: User | null,
): Promise<Response> {
  if (path === "/demo/login" && method === "POST") {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const username = text(body.username).toLowerCase();
    const password = text(body.password);
    if (!username || !password) return fail("demo username and password are required", 422);
    const { data: account, error } = await svc.from("demo_accounts").select("*")
      .eq("username", username).eq("is_enabled", true).maybeSingle();
    if (error || !account) return fail("invalid demo credentials", 401);
    const { data: auth } = await svc.auth.admin.getUserById(account.auth_user_id);
    const email = auth.user?.email;
    if (!email) return fail("demo account is unavailable", 401);
    const client = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);
    const { error: signInError } = await client.auth.signInWithPassword({ email, password });
    if (signInError) return fail("invalid demo credentials", 401);
    return ok({
      mode: "local_sandbox",
      snapshot_version: account.snapshot_version,
      snapshot: account.snapshot,
      roles: ["principal", "teacher", "parent"],
    });
  }

  if (path === "/jobs/demo-credential-rotation" && method === "POST") {
    const jobSecret = Deno.env.get("DEMO_JOB_SECRET") ?? "";
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const hasJobSecret = jobSecret.length > 0 && req.headers.get("x-job-secret") === jobSecret;
    const hasServiceRole = serviceRole.length > 0 && req.headers.get("authorization") === `Bearer ${serviceRole}`;
    if (!hasJobSecret && !hasServiceRole) return fail("unauthorized", 401);
    const cutoff = new Date(Date.now() - 72 * 60 * 60 * 1000).toISOString();
    const { data: due, error } = await svc.from("demo_accounts").select("*")
      .eq("is_enabled", true).lte("password_rotated_at", cutoff);
    if (error) return fail(error.message);
    for (const account of due ?? []) await rotate(svc, account);
    return ok({ rotated: due?.length ?? 0 });
  }

  if (!user || !isSuperAdmin(user)) return fail("super_admin required", 403);
  if (path === "/demo/admin" && method === "GET") {
    const { data, error } = await svc.from("demo_accounts").select("*").order("created_at", { ascending: false }).limit(1).maybeSingle();
    return error ? fail(error.message) : ok(data ? safeAccount(data) : null);
  }

  if (path === "/demo/admin" && method === "POST") {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const requestedUsername = text(body.username).toLowerCase();
    const username = requestedUsername || await nextDemoUsername(svc);
    if (!/^demo\d+$/.test(username)) return fail("demo username must use the format demo1, demo2, or demo3", 422);
    const demoSchoolId = text(body.demo_school_id);
    if (!demoSchoolId) return fail("demo_school_id is required", 422);
    const { data: school } = await svc.from("schools").select("id").eq("id", demoSchoolId).maybeSingle();
    if (!school) return fail("demo school not found", 404);
    const email = `${username.replace(/[^a-z0-9.-]/g, "-")}@demo.schooldesk.local`;
    const password = temporaryPassword();
    const { data: auth, error: authError } = await svc.auth.admin.createUser({
      email, password, email_confirm: true,
      app_metadata: { school_id: demoSchoolId, role_name: "demo" },
    });
    if (authError || !auth.user) return fail(authError?.message ?? "unable to create demo account");
    const { error: profileError } = await svc.from("users").insert({
      id: auth.user.id, school_id: demoSchoolId, username, name: "SchoolDesk Demo",
      email, role_name: "demo", is_active: true, is_verified: true,
    });
    if (profileError) { await svc.auth.admin.deleteUser(auth.user.id); return fail(profileError.message); }
    const ciphertext = await seal(password);
    const { data, error } = await svc.from("demo_accounts").insert({
      auth_user_id: auth.user.id, demo_school_id: demoSchoolId, username,
      snapshot: body.snapshot && typeof body.snapshot === "object" ? body.snapshot : {},
      password_secret_ciphertext: ciphertext,
      password_secret_expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      created_by: user.id,
    }).select().single();
    if (error) return fail(error.message);
    return ok({ ...safeAccount(data), temporary_password: password });
  }

  const match = path.match(/^\/demo\/admin\/([^/]+)(?:\/(reveal|reset))?$/);
  if (match && !match[2] && method === "PATCH") {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const updates: Record<string, unknown> = {};
    if (typeof body.is_enabled === "boolean") updates.is_enabled = body.is_enabled;
    if (body.snapshot && typeof body.snapshot === "object") { updates.snapshot = body.snapshot; updates.snapshot_version = Number(body.snapshot_version ?? 1); }
    const { data, error } = await svc.from("demo_accounts").update(updates).eq("id", match[1]).select().single();
    return error ? fail(error.message) : ok(safeAccount(data));
  }
  if (match && match[2] === "reveal" && method === "POST") {
    const id = match[1];
    const { data: account, error } = await svc.from("demo_accounts").select("*").eq("id", id).maybeSingle();
    if (error || !account) return fail("demo account not found", 404);
    if (!account.password_secret_ciphertext || account.password_revealed_at || new Date(account.password_secret_expires_at ?? 0) < new Date()) return fail("no unrevealed temporary password is available", 410);
    const password = await openSecret(account.password_secret_ciphertext);
    // Consume the wrapped secret atomically. This prevents a double tap or
    // concurrent super-admin request from revealing the same password twice.
    const { data: consumed, error: consumeError } = await svc.from("demo_accounts")
      .update({ password_secret_ciphertext: null, password_revealed_at: new Date().toISOString() })
      .eq("id", id)
      .is("password_revealed_at", null)
      .select("id")
      .maybeSingle();
    if (consumeError) return fail(consumeError.message);
    if (!consumed) return fail("no unrevealed temporary password is available", 410);
    return ok({ username: account.username, temporary_password: password });
  }
  if (match && match[2] === "reset" && method === "POST") {
    const id = match[1];
    const { data: account, error } = await svc.from("demo_accounts").select("*").eq("id", id).maybeSingle();
    if (error || !account) return fail("demo account not found", 404);
    const password = await rotate(svc, account);
    return ok({ username: account.username, temporary_password: password });
  }
  return fail("not found", 404);
}

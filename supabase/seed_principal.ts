#!/usr/bin/env -S deno run --allow-net --allow-env

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  Deno.exit(1);
}

const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { persistSession: false },
});

const principalUsername = Deno.env.get("PRINCIPAL_USERNAME") || "principal";
const principalEmail = Deno.env.get("PRINCIPAL_EMAIL") ||
  "principal@schooldesk.local";
const principalPassword = Deno.env.get("PRINCIPAL_PASSWORD") ||
  "Principal@12345";
const schoolId = Deno.env.get("SEED_SCHOOL_ID") || "school-default";
const roleName = Deno.env.get("SEED_PRINCIPAL_ROLE_NAME") || "principal";
const kioskUsername = Deno.env.get("KIOSK_USERNAME") || "kiosk";
const kioskEmail = Deno.env.get("KIOSK_EMAIL") || "kiosk@schooldesk.local";
const kioskPassword = Deno.env.get("KIOSK_PASSWORD") || "Kiosk@12345";

async function upsertSchool() {
  const { error } = await svc.from("schools").upsert({
    id: schoolId,
    name: "SchoolDesk",
    school_type: "cbse",
    email: principalEmail,
    timezone: "Asia/Kolkata",
    currency: "INR",
  }, { onConflict: "id" });
  if (error) throw error;
}

async function upsertPrincipalUser() {
  const { data: existingUser, error: getErr } = await svc
    .from("users")
    .select("id")
    .eq("email", principalEmail)
    .maybeSingle();
  if (getErr) throw getErr;

  if (existingUser?.id) {
    const { error: updErr } = await svc.from("users").update({
      username: principalUsername,
      name: "School Principal",
      email: principalEmail,
      school_id: schoolId,
      role_name: roleName,
      is_active: true,
      is_verified: true,
    }).eq("id", existingUser.id);
    if (updErr) throw updErr;
    return existingUser.id as string;
  }

  const { data: newUser, error: insertErr } = await svc.from("users").insert({
    username: principalUsername,
    name: "School Principal",
    email: principalEmail,
    school_id: schoolId,
    role_name: roleName,
    is_active: true,
    is_verified: true,
  }).select().maybeSingle();
  if (insertErr) throw insertErr;
  return newUser.id as string;
}

async function createSupabaseAuthUser(userId: string) {
  const { data, error } = await svc.auth.admin.getUserById(userId);
  if (data?.user) {
    const currentEmail = data.user.email;
    if (currentEmail !== principalEmail) {
      const { error: updateErr } = await svc.auth.admin.updateUserById(userId, {
        email: principalEmail,
        password: principalPassword,
        email_confirm: true,
      });
      if (updateErr) throw updateErr;
    }
    return userId;
  }

  const { data: createData, error: createErr } = await svc.auth.admin
    .createUser({
      email: principalEmail,
      password: principalPassword,
      email_confirm: true,
      app_metadata: { school_id: schoolId, role_name: roleName },
    });
  if (createErr) throw createErr;
  return createData.user!.id;
}

async function upsertUsernameAlias(userId: string) {
  const { error } = await svc.from("username_aliases").upsert({
    username: principalUsername.toLowerCase(),
    auth_user_id: userId,
    school_id: schoolId,
  }, { onConflict: "username" });
  if (error) throw error;
}

async function seedKioskUser() {
  let authUserId = "";
  const { data: alias, error: aliasErr } = await svc
    .from("username_aliases")
    .select("auth_user_id")
    .eq("username", kioskUsername.toLowerCase())
    .maybeSingle();
  if (aliasErr) throw aliasErr;

  if (alias?.auth_user_id) {
    authUserId = alias.auth_user_id as string;
    const { error } = await svc.auth.admin.updateUserById(authUserId, {
      email: kioskEmail,
      password: kioskPassword,
      email_confirm: true,
      app_metadata: { school_id: schoolId, role_name: "kiosk" },
    });
    if (error) throw error;
  } else {
    const { data, error } = await svc.auth.admin.createUser({
      email: kioskEmail,
      password: kioskPassword,
      email_confirm: true,
      app_metadata: { school_id: schoolId, role_name: "kiosk" },
    });
    if (error) throw error;
    authUserId = data.user!.id;
  }

  const { error: userErr } = await svc.from("users").upsert({
    id: authUserId,
    username: kioskUsername,
    name: "Attendance Kiosk",
    email: kioskEmail,
    school_id: schoolId,
    role_name: "kiosk",
    is_active: true,
    is_verified: true,
  }, { onConflict: "id" });
  if (userErr) throw userErr;

  const { error: aliasUpsertErr } = await svc.from("username_aliases").upsert({
    username: kioskUsername.toLowerCase(),
    auth_user_id: authUserId,
    school_id: schoolId,
  }, { onConflict: "username" });
  if (aliasUpsertErr) throw aliasUpsertErr;

  return authUserId;
}

async function main() {
  try {
    await upsertSchool();
    const localUserId = await upsertPrincipalUser();
    const authUserId = await createSupabaseAuthUser(localUserId);
    await upsertUsernameAlias(authUserId);
    const kioskUserId = await seedKioskUser();
    console.log(JSON.stringify(
      {
        success: true,
        principal: {
          username: principalUsername,
          email: principalEmail,
          password: principalPassword,
          user_id: authUserId,
        },
        kiosk: {
          username: kioskUsername,
          email: kioskEmail,
          password: kioskPassword,
          user_id: kioskUserId,
        },
      },
      null,
      2,
    ));
  } catch (error) {
    console.error("Failed to seed principal:", error);
    Deno.exit(1);
  }
}

main();

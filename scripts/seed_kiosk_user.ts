#!/usr/bin/env -S deno run --allow-net --allow-env

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const required = [
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "KIOSK_SCHOOL_ID",
  "KIOSK_USERNAME",
  "KIOSK_EMAIL",
  "KIOSK_PASSWORD",
] as const;

const env = Object.fromEntries(
  required.map((key) => [key, (Deno.env.get(key) ?? "").trim()]),
) as Record<(typeof required)[number], string>;
const missing = required.filter((key) => !env[key]);
if (missing.length > 0) {
  console.error(
    `Missing required environment variables: ${missing.join(", ")}`,
  );
  Deno.exit(1);
}

const svc = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});
const username = env.KIOSK_USERNAME.toLowerCase();

async function main() {
  const { data: school, error: schoolError } = await svc.from("schools")
    .select("id")
    .eq("id", env.KIOSK_SCHOOL_ID)
    .maybeSingle();
  if (schoolError) throw schoolError;
  if (!school) throw new Error("KIOSK_SCHOOL_ID does not match a school");

  const { data: alias, error: aliasError } = await svc
    .from("username_aliases")
    .select("auth_user_id, school_id")
    .eq("username", username)
    .maybeSingle();
  if (aliasError) throw aliasError;
  if (alias?.school_id && alias.school_id !== env.KIOSK_SCHOOL_ID) {
    throw new Error("KIOSK_USERNAME is already assigned to another school");
  }

  let userId = `${alias?.auth_user_id ?? ""}`.trim();
  const authAttributes = {
    email: env.KIOSK_EMAIL,
    password: env.KIOSK_PASSWORD,
    email_confirm: true,
    app_metadata: {
      school_id: env.KIOSK_SCHOOL_ID,
      role_name: "kiosk",
    },
  };
  if (userId) {
    const { error } = await svc.auth.admin.updateUserById(
      userId,
      authAttributes,
    );
    if (error) throw error;
  } else {
    const { data, error } = await svc.auth.admin.createUser(authAttributes);
    if (error) throw error;
    userId = data.user?.id ?? "";
  }
  if (!userId) throw new Error("Kiosk authentication user was not created");

  const { error: userError } = await svc.from("users").upsert({
    id: userId,
    username: env.KIOSK_USERNAME,
    name: "Attendance Kiosk",
    email: env.KIOSK_EMAIL,
    school_id: env.KIOSK_SCHOOL_ID,
    role_name: "kiosk",
    is_active: true,
    is_verified: true,
  }, { onConflict: "id" });
  if (userError) throw userError;

  const { error: upsertAliasError } = await svc.from("username_aliases").upsert(
    {
      username,
      auth_user_id: userId,
      school_id: env.KIOSK_SCHOOL_ID,
    },
    { onConflict: "username" },
  );
  if (upsertAliasError) throw upsertAliasError;

  console.log(JSON.stringify({
    success: true,
    username: env.KIOSK_USERNAME,
    email: env.KIOSK_EMAIL,
    school_id: env.KIOSK_SCHOOL_ID,
    role_name: "kiosk",
  }));
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  Deno.exit(1);
});

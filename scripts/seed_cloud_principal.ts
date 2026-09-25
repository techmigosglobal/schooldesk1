#!/usr/bin/env -S deno run --allow-net --allow-env

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://qzdhymlabzqjeocetqqv.supabase.co";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

if (!SUPABASE_SERVICE_KEY) {
  console.error("Missing SUPABASE_SERVICE_ROLE_KEY");
  Deno.exit(1);
}

const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { persistSession: false },
});

const orgId = Deno.env.get("SEED_ORG_ID") || "00000000-0000-4000-8000-000000000000";
const schoolId = Deno.env.get("SEED_SCHOOL_ID") || "00000000-0000-4000-8000-000000000001";
const schoolName = Deno.env.get("SEED_SCHOOL_NAME") || "Arish Ville Academy";

const principalUsername = (Deno.env.get("PRINCIPAL_USERNAME") || "principal").trim().toLowerCase();
const principalEmail = (Deno.env.get("PRINCIPAL_EMAIL") || "principal@arishville.com").trim().toLowerCase();
const principalPassword = Deno.env.get("PRINCIPAL_PASSWORD") || "Principal@12345";
const principalName = Deno.env.get("PRINCIPAL_NAME") || "School Principal";

async function main() {
  console.log(`[seed-principal] Connecting to ${SUPABASE_URL}...`);

  // 1. Organization
  console.log("[seed-principal] Ensuring organization exists...");
  const { error: orgErr } = await svc.from("organizations").upsert({
    id: orgId,
    name: `${schoolName} Organization`,
    multi_branch_enabled: false,
  }, { onConflict: "id" });
  if (orgErr) throw new Error(`Organization upsert failed: ${orgErr.message}`);

  // 2. School
  console.log("[seed-principal] Ensuring school exists...");
  const { error: schoolErr } = await svc.from("schools").upsert({
    id: schoolId,
    organization_id: orgId,
    name: schoolName,
    school_type: "cbse",
    email: principalEmail,
    timezone: "Asia/Kolkata",
    currency: "INR",
    principal_name: principalName,
  }, { onConflict: "id" });
  if (schoolErr) throw new Error(`School upsert failed: ${schoolErr.message}`);

  // Update org seed_school_id
  await svc.from("organizations").update({ seed_school_id: schoolId }).eq("id", orgId);

  // 3. Academic Year & Term
  console.log("[seed-principal] Ensuring academic year & term exist...");
  const academicYearId = "00000000-0000-4000-8000-000000000010";
  const termId = "00000000-0000-4000-8000-000000000011";
  await svc.from("academic_years").upsert({
    id: academicYearId,
    school_id: schoolId,
    year_label: "2026-2027",
    year: "2026",
    start_date: "2026-04-01",
    end_date: "2027-03-31",
    is_current: true,
    status: "active",
  }, { onConflict: "id" });

  await svc.from("terms").upsert({
    id: termId,
    academic_year_id: academicYearId,
    term_number: 1,
    term_name: "Term 1",
    start_date: "2026-04-01",
    end_date: "2026-09-30",
    is_current: true,
  }, { onConflict: "id" });

  // 4. Role
  console.log("[seed-principal] Ensuring principal role exists...");
  const roleId = "00000000-0000-4000-8000-000000000120";
  await svc.from("roles").upsert({
    id: roleId,
    school_id: schoolId,
    role_name: "principal",
    description: "School Principal",
    is_system: true,
  }, { onConflict: "id" });

  // Permissions for principal
  const modules = ["students", "staff", "attendance", "academics", "fees", "communications", "timetable", "notices"];
  const permissionsToInsert = modules.map(m => ({
    school_id: schoolId,
    role_id: roleId,
    module: m,
    action: "manage",
  }));
  try {
    await svc.from("permissions").upsert(permissionsToInsert, { onConflict: "school_id,role_id,module,action" });
  } catch (_e) {
    // ignore
  }

  // 5. Auth User
  console.log(`[seed-principal] Provisioning Auth user: ${principalEmail}...`);
  let authUserId = "";

  // Check if alias or auth user already exists
  const { data: aliasData } = await svc
    .from("username_aliases")
    .select("auth_user_id")
    .eq("username", principalUsername)
    .maybeSingle();

  if (aliasData?.auth_user_id) {
    authUserId = aliasData.auth_user_id;
    console.log(`[seed-principal] Found existing auth user ID from alias: ${authUserId}`);
    const { error: updErr } = await svc.auth.admin.updateUserById(authUserId, {
      email: principalEmail,
      password: principalPassword,
      email_confirm: true,
      app_metadata: { school_id: schoolId, role_name: "principal" },
      user_metadata: { name: principalName, role: "principal" },
    });
    if (updErr) throw new Error(`Auth update failed: ${updErr.message}`);
  } else {
    // Check if user exists by email in auth.users
    const { data: userList } = await svc.auth.admin.listUsers();
    const existing = userList?.users?.find(u => u.email?.toLowerCase() === principalEmail);

    if (existing) {
      authUserId = existing.id;
      console.log(`[seed-principal] Found existing auth user by email: ${authUserId}`);
      const { error: updErr } = await svc.auth.admin.updateUserById(authUserId, {
        password: principalPassword,
        email_confirm: true,
        app_metadata: { school_id: schoolId, role_name: "principal" },
        user_metadata: { name: principalName, role: "principal" },
      });
      if (updErr) throw new Error(`Auth update failed: ${updErr.message}`);
    } else {
      console.log("[seed-principal] Creating new auth user...");
      const { data: created, error: createErr } = await svc.auth.admin.createUser({
        email: principalEmail,
        password: principalPassword,
        email_confirm: true,
        app_metadata: { school_id: schoolId, role_name: "principal" },
        user_metadata: { name: principalName, role: "principal" },
      });
      if (createErr) throw new Error(`Auth creation failed: ${createErr.message}`);
      authUserId = created.user!.id;
    }
  }

  // 6. Public User profile
  console.log("[seed-principal] Upserting public user profile...");
  const { error: userErr } = await svc.from("users").upsert({
    id: authUserId,
    school_id: schoolId,
    username: principalUsername,
    name: principalName,
    email: principalEmail,
    role_id: roleId,
    role_name: "principal",
    is_active: true,
    is_verified: true,
  }, { onConflict: "id" });
  if (userErr) throw new Error(`User profile upsert failed: ${userErr.message}`);

  // 7. Username Alias
  console.log("[seed-principal] Upserting username alias...");
  const { error: aliasErr } = await svc.from("username_aliases").upsert({
    username: principalUsername,
    auth_user_id: authUserId,
    school_id: schoolId,
  }, { onConflict: "username" });
  if (aliasErr) throw new Error(`Username alias upsert failed: ${aliasErr.message}`);

  // 8. Staff record
  console.log("[seed-principal] Upserting staff record...");
  const staffId = "00000000-0000-4000-8000-000000000043";
  await svc.from("staff").upsert({
    id: staffId,
    school_id: schoolId,
    first_name: "Principal",
    last_name: "",
    staff_code: "PRI-001",
    email: principalEmail,
    designation: "Principal",
    account_role: "principal",
    is_active: true,
  }, { onConflict: "id" });

  console.log("\n==================================================");
  console.log(" Principal Role Successfully Seeded to Supabase! ");
  console.log("==================================================");
  console.log(JSON.stringify({
    success: true,
    school: {
      id: schoolId,
      name: schoolName,
    },
    principal: {
      username: principalUsername,
      email: principalEmail,
      password: principalPassword,
      auth_user_id: authUserId,
      role: "principal",
    }
  }, null, 2));
}

main().catch(err => {
  console.error("[seed-principal][error]", err);
  Deno.exit(1);
});

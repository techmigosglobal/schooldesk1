import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

function text(value: unknown) {
  return `${value ?? ""}`.trim();
}

function role(user: User) {
  return text(user.app_metadata?.role_name).toLowerCase();
}

async function organizationForUser(svc: SupabaseClient, user: User) {
  const { data, error } = await svc.from("users")
    .select("school_id, school:schools!users_school_id_fkey(organization_id)")
    .eq("id", user.id).maybeSingle();
  if (error) throw error;
  const schoolValue = Array.isArray(data?.school)
    ? data.school[0]
    : data?.school;
  const school = schoolValue as Record<string, unknown> | null;
  return text(school?.organization_id);
}

export async function handleBranches(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const organizationId = await organizationForUser(svc, user).catch(() => "");
  if (!organizationId) return fail("organization unavailable", 422);

  if (path === "/branches" && method === "GET") {
    const currentRole = role(user);
    let query = svc.from("schools")
      .select(
        "id, name, branch_code, city, state, logo_url, multi_branch_enabled",
      )
      .eq("organization_id", organizationId)
      .order("name");
    if (currentRole === "coordinator") {
      const { data: assignedUser, error: assignedError } = await svc.from(
        "users",
      ).select("school_id").eq("id", user.id).maybeSingle();
      if (assignedError) return fail(assignedError.message);
      const assignedBranch = text(assignedUser?.school_id);
      if (!assignedBranch) return ok([]);
      query = query.eq("id", assignedBranch);
    } else if (currentRole !== "super_admin") {
      const { data: memberships, error } = await svc.from("branch_memberships")
        .select("school_id").eq("user_id", user.id).eq("is_active", true);
      if (error) return fail(error.message);
      const ids = (memberships ?? []).map((row) => text(row.school_id)).filter(
        Boolean,
      );
      if (ids.length === 0) return ok([]);
      query = query.in("id", ids);
    }
    const { data, error } = await query;
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  if (path === "/branches/overview" && method === "GET") {
    if (role(user) !== "super_admin") return fail("super_admin required", 403);
    const { data: branches, error } = await svc.from("schools")
      .select("id, name, branch_code, city, state")
      .eq("organization_id", organizationId).order("name");
    if (error) return fail(error.message);
    const result = await Promise.all((branches ?? []).map(async (branch) => {
      const schoolId = text(branch.id);
      const [students, staff, sections, openIssues] = await Promise.all([
        svc.from("students").select("id", { count: "exact", head: true }).eq(
          "school_id",
          schoolId,
        ).eq("is_test_account", false),
        svc.from("staff").select("id", { count: "exact", head: true }).eq(
          "school_id",
          schoolId,
        ),
        svc.from("sections").select("id", { count: "exact", head: true }).eq(
          "school_id",
          schoolId,
        ),
        svc.from("issues").select("id", { count: "exact", head: true }).eq(
          "school_id",
          schoolId,
        ).neq("status", "resolved"),
      ]);
      return {
        ...branch,
        students: students.count ?? 0,
        staff: staff.count ?? 0,
        classes: sections.count ?? 0,
        open_issues: openIssues.count ?? 0,
      };
    }));
    return ok(result);
  }

  if (path === "/branches" && method === "POST") {
    if (role(user) !== "super_admin") return fail("super_admin required", 403);
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const name = text(body.name);
    if (!name) return fail("branch name required", 422);
    const branchCode = text(body.branch_code);
    const { data: duplicate, error: duplicateError } = await svc
      .from("schools")
      .select("id")
      .eq("organization_id", organizationId)
      .ilike("name", name)
      .maybeSingle();
    if (duplicateError) return fail(duplicateError.message);
    if (duplicate) return fail("a branch with this name already exists", 409);
    const { data, error } = await svc.from("schools").insert({
      organization_id: organizationId,
      name,
      branch_code: branchCode || null,
      school_type: text(body.school_type) || "school",
      email: text(body.email) || null,
      phone: text(body.phone) || null,
      city: text(body.city) || null,
      state: text(body.state) || null,
      multi_branch_enabled: true,
    }).select().single();
    if (error) return fail(error.message);
    const [organizationUpdate, schoolsUpdate] = await Promise.all([
      svc.from("organizations").update({ multi_branch_enabled: true })
        .eq("id", organizationId),
      svc.from("schools").update({ multi_branch_enabled: true })
        .eq("organization_id", organizationId),
    ]);
    if (organizationUpdate.error || schoolsUpdate.error) {
      return fail(
        organizationUpdate.error?.message ?? schoolsUpdate.error?.message ??
          "unable to enable multi-branch mode",
      );
    }
    return ok(data);
  }

  const branchId = path.startsWith("/branches/")
    ? text(path.slice("/branches/".length).split("/")[0])
    : "";
  if (branchId && ["PATCH", "DELETE"].includes(method)) {
    if (role(user) !== "super_admin") return fail("super_admin required", 403);
    const { data: branch, error: branchError } = await svc.from("schools")
      .select("id, name, branch_code, city, state")
      .eq("id", branchId).eq("organization_id", organizationId).maybeSingle();
    if (branchError) return fail(branchError.message);
    if (!branch) return fail("branch not found", 404);

    if (method === "PATCH") {
      const body = await req.json().catch(() => ({})) as Record<string, unknown>;
      const name = text(body.name);
      if (!name) return fail("branch name required", 422);
      const updates = {
        name,
        branch_code: text(body.branch_code) || null,
        city: text(body.city) || null,
        state: text(body.state) || null,
      };
      const { data, error } = await svc.from("schools").update(updates)
        .eq("id", branchId).eq("organization_id", organizationId)
        .select("id, name, branch_code, city, state, logo_url, multi_branch_enabled")
        .single();
      if (error) return fail(error.message);
      return ok(data);
    }

    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const expectedConfirmation = `DELETE ${text(branch.name)}`;
    if (text(body.confirmation) !== expectedConfirmation) {
      return fail(`type ${expectedConfirmation} to delete this branch`, 422);
    }
    const { data: replacement, error: replacementError } = await svc
      .from("schools")
      .select("id, name")
      .eq("organization_id", organizationId)
      .neq("id", branchId)
      .order("created_at")
      .limit(1)
      .maybeSingle();
    if (replacementError) return fail(replacementError.message);
    if (!replacement) {
      return fail("the only branch in an organization cannot be deleted", 422);
    }

    // Leadership identities are organization-scoped. Move them to a remaining
    // branch first; all branch-only users and their data are then removed by
    // the existing ON DELETE CASCADE foreign keys on schools.
    const { error: leadershipError } = await svc.from("users")
      .update({ school_id: replacement.id })
      .eq("school_id", branchId)
      .in("role_name", ["principal", "super_admin"]);
    if (leadershipError) return fail(leadershipError.message);
    const { error: deleteError } = await svc.from("schools").delete()
      .eq("id", branchId).eq("organization_id", organizationId);
    if (deleteError) return fail(deleteError.message);
    return ok({
      deleted_branch_id: branchId,
      reassigned_to_branch_id: text(replacement.id),
      reassigned_to_branch_name: text(replacement.name),
    });
  }

  return fail("not found", 404);
}

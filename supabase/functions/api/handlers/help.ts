import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";

function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}

export async function handleHelp(
  req: Request,
  path: string,
  method: string,
  url: URL,
  client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);

  // Check if the user is a super admin
  const { data: profile } = await client
    .from("users")
    .select("role_name")
    .eq("id", user.id)
    .maybeSingle();
  const isSuperAdmin = profile?.role_name === "super_admin";

  if (method === "GET") {
    // Standard role users can request their own help contents.
    // If they ask for another role, and they are not super admin, we force their role.
    let targetRole = url.searchParams.get("role")?.trim().toLowerCase();
    if (!isSuperAdmin || !targetRole) {
      targetRole = profile?.role_name?.trim().toLowerCase() || "parent";
    }

    let query = svc
      .from("help_contents")
      .select("*")
      .eq("school_id", school)
      .order("created_at", { ascending: true });

    if (targetRole && targetRole !== "super_admin") {
      query = query.eq("role_name", targetRole);
    }

    const { data, error } = await query;
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  // Write operations (POST, PUT, DELETE) are restricted to super_admin
  if (!isSuperAdmin) {
    return fail("forbidden: only super_admin can modify help content", 403);
  }

  const body = req.method !== "DELETE" ? await req.json().catch(() => ({})) : {};

  if (method === "POST") {
    const roleName = `${body.role_name ?? ""}`.trim().toLowerCase();
    const question = `${body.question ?? ""}`.trim();
    const answer = `${body.answer ?? ""}`.trim();
    const videoUrl = body.video_url ? `${body.video_url}`.trim() : null;

    if (!roleName || !question || !answer) {
      return fail("role_name, question, and answer are required", 420);
    }

    const { data, error } = await svc.from("help_contents").insert({
      school_id: school,
      role_name: roleName,
      question,
      answer,
      video_url: videoUrl,
    }).select().single();

    if (error) return fail(error.message);
    return ok(data);
  }

  if (method === "PUT") {
    const id = body.id;
    if (!id) return fail("id is required to update help content", 420);

    const updates: Record<string, any> = {
      updated_at: new Date().toISOString(),
    };

    if (body.role_name !== undefined) {
      updates.role_name = `${body.role_name ?? ""}`.trim().toLowerCase();
    }
    if (body.question !== undefined) {
      updates.question = `${body.question ?? ""}`.trim();
    }
    if (body.answer !== undefined) {
      updates.answer = `${body.answer ?? ""}`.trim();
    }
    if (body.video_url !== undefined) {
      updates.video_url = body.video_url ? `${body.video_url}`.trim() : null;
    }

    const { data, error } = await svc
      .from("help_contents")
      .update(updates)
      .eq("id", id)
      .eq("school_id", school)
      .select()
      .single();

    if (error) return fail(error.message);
    return ok(data);
  }

  if (method === "DELETE") {
    const id = url.searchParams.get("id");
    if (!id) return fail("id is required to delete help content", 420);

    const { error } = await svc
      .from("help_contents")
      .delete()
      .eq("id", id)
      .eq("school_id", school);

    if (error) return fail(error.message);
    return ok({ deleted: true, id });
  }

  return fail("method not allowed", 405);
}

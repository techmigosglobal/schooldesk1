import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";
import {
  deleteR2File,
  legacyStorageWritesEnabled,
  r2FileReference,
  uploadToR2,
} from "../lib/r2_storage.ts";
import { signedPrivateFileUrl } from "../storage_helpers.ts";

function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}

const tutorialMimeTypes = new Set([
  "video/mp4",
  "video/webm",
  "video/quicktime",
]);
const maxTutorialBytes = 250 * 1024 * 1024;
const supportedHelpRoles = new Set([
  "principal",
  "coordinator",
  "teacher",
  "parent",
]);
const maxWorkflowSteps = 12;

function text(value: unknown, fallback = ""): string {
  const result = `${value ?? ""}`.trim();
  return result || fallback;
}

function optionalText(value: unknown, maxLength: number): string | null {
  const result = text(value);
  return result ? result.slice(0, maxLength) : null;
}

function workflowSteps(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((step) => text(step))
    .filter(Boolean)
    .slice(0, maxWorkflowSteps)
    .map((step) => step.slice(0, 500));
}

function roleOf(profile: Record<string, unknown> | null, user: User): string {
  return `${profile?.role_name ?? user.app_metadata?.role_name ?? ""}`.trim()
    .toLowerCase();
}

function safeFileName(name: string): string {
  return name.replace(/[^a-zA-Z0-9._-]/g, "_").slice(-120) || "tutorial.mp4";
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
  const currentRole = roleOf(profile as Record<string, unknown> | null, user);
  const isSuperAdmin = currentRole === "super_admin";

  if (path === "/help/videos" && method === "POST") {
    if (!isSuperAdmin) {
      return fail("forbidden: only super_admin can upload tutorials", 403);
    }
    const form = await req.formData().catch(() => null);
    const file = form?.get("file");
    const targetRole = `${form?.get("role_name") ?? ""}`.trim().toLowerCase();
    if (!(file instanceof File) || !supportedHelpRoles.has(targetRole)) {
      return fail("a video file and supported role_name are required", 420);
    }
    if (!tutorialMimeTypes.has(file.type) || file.size > maxTutorialBytes) {
      return fail(
        "Tutorial must be MP4, WebM, or MOV and no larger than 250 MB",
        420,
      );
    }
    const pathValue = `${school}/${targetRole}/${crypto.randomUUID()}-${
      safeFileName(file.name)
    }`;
    const r2Key = `private/help-tutorial-videos/${pathValue}`;
    const r2Upload = await uploadToR2(r2Key, file, file.type);
    const storedPath = r2Upload ? r2FileReference(r2Upload.key) : pathValue;
    if (!r2Upload) {
      if (!legacyStorageWritesEnabled()) {
        return fail("R2 storage is unavailable; legacy storage writes are disabled", 503);
      }
      const { error } = await svc.storage.from("help-tutorial-videos").upload(
        pathValue,
        file,
        { contentType: file.type, upsert: false },
      );
      if (error) return fail(error.message);
    }
    return ok({
      video_path: storedPath,
      video_file_name: file.name,
      video_mime_type: file.type,
      video_size: file.size,
    });
  }

  const videoMatch = path.match(/^\/help\/([^/]+)\/video$/);
  if (videoMatch && method === "GET") {
    const { data, error } = await svc.from("help_contents").select(
      "id, school_id, role_name, video_path, video_url",
    ).eq("id", videoMatch[1]).eq("school_id", school).maybeSingle();
    if (error) return fail(error.message);
    if (!data) return fail("Help tutorial not found", 404);
    if (!isSuperAdmin && data.role_name !== currentRole) {
      return fail("forbidden", 403);
    }
    if (data.video_path) {
      if (!`${data.video_path}`.startsWith("r2://")) {
        const { data: signed, error: signedError } = await svc.storage
          .from("help-tutorial-videos").createSignedUrl(
            `${data.video_path}`,
            60 * 10,
          );
        if (signedError || !signed?.signedUrl) {
          return fail(signedError?.message ?? "Unable to prepare video");
        }
        return ok({ url: signed.signedUrl, expires_in: 600 });
      }
      const signedUrl = await signedPrivateFileUrl(
        svc,
        data.video_path,
        60 * 10,
        "help-tutorial-videos",
      );
      if (!signedUrl) return fail("Unable to prepare video");
      return ok({ url: signedUrl, expires_in: 600 });
    }
    if (data.video_url) return ok({ url: data.video_url, legacy: true });
    return fail("No tutorial video is attached", 404);
  }

  if (method === "GET") {
    // Standard role users can request their own help contents.
    // If they ask for another role, and they are not super admin, we force their role.
    let targetRole = url.searchParams.get("role")?.trim().toLowerCase();
    if (!isSuperAdmin || !targetRole) {
      targetRole = currentRole || "parent";
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

  const body = req.method !== "DELETE"
    ? await req.json().catch(() => ({}))
    : {};

  if (method === "POST") {
    const roleName = text(body.role_name).toLowerCase();
    const question = text(body.question);
    const answer = text(body.answer);
    const videoUrl = body.video_url ? `${body.video_url}`.trim() : null;

    if (!supportedHelpRoles.has(roleName) || !question || !answer) {
      return fail(
        "a supported role_name, question, and answer are required",
        420,
      );
    }

    const { data, error } = await svc.from("help_contents").insert({
      school_id: school,
      role_name: roleName,
      question,
      answer,
      category: optionalText(body.category, 80) ?? "General",
      workflow_steps: workflowSteps(body.workflow_steps),
      action_route: optionalText(body.action_route, 160),
      video_url: videoUrl,
      video_path: body.video_path ? `${body.video_path}`.trim() : null,
      video_file_name: body.video_file_name
        ? `${body.video_file_name}`.trim()
        : null,
      video_mime_type: body.video_mime_type
        ? `${body.video_mime_type}`.trim()
        : null,
      video_size: body.video_size ?? null,
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
      const roleName = text(body.role_name).toLowerCase();
      if (!supportedHelpRoles.has(roleName)) {
        return fail("unsupported role_name", 420);
      }
      updates.role_name = roleName;
    }
    if (body.question !== undefined) {
      updates.question = `${body.question ?? ""}`.trim();
    }
    if (body.answer !== undefined) {
      updates.answer = `${body.answer ?? ""}`.trim();
    }
    if (body.category !== undefined) {
      updates.category = optionalText(body.category, 80) ?? "General";
    }
    if (body.workflow_steps !== undefined) {
      updates.workflow_steps = workflowSteps(body.workflow_steps);
    }
    if (body.action_route !== undefined) {
      updates.action_route = optionalText(body.action_route, 160);
    }
    if (body.video_url !== undefined) {
      updates.video_url = body.video_url ? `${body.video_url}`.trim() : null;
    }
    for (
      const key of [
        "video_path",
        "video_file_name",
        "video_mime_type",
        "video_size",
      ]
    ) {
      if (body[key] !== undefined) updates[key] = body[key] || null;
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

    const { data: existing, error: lookupError } = await svc
      .from("help_contents")
      .select("video_path")
      .eq("id", id)
      .eq("school_id", school)
      .maybeSingle();
    if (lookupError) return fail(lookupError.message);
    if (!existing) return fail("help content not found", 404);
    const { error } = await svc.from("help_contents").delete().eq("id", id)
      .eq("school_id", school);

    if (error) return fail(error.message);
    if (`${existing.video_path ?? ""}`.startsWith("r2://")) {
      await deleteR2File(existing.video_path);
    } else if (existing.video_path) {
      await svc.storage.from("help-tutorial-videos").remove([
        `${existing.video_path}`,
      ]);
    }
    return ok({ deleted: true, id });
  }

  return fail("method not allowed", 405);
}

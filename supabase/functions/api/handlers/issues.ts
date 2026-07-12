import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, triggerPushProcessing } from "../index.ts";

const allowedRoles = new Set(["principal", "teacher"]);
const allowedMimeTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
  "video/mp4",
  "video/webm",
  "video/quicktime",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
]);
const maxAttachmentBytes = 50 * 1024 * 1024;

function text(value: unknown): string {
  return `${value ?? ""}`.trim();
}
function schoolId(user: User): string {
  return text(user.app_metadata?.school_id);
}
function safeName(name: string): string {
  return name.replace(/[^a-zA-Z0-9._-]/g, "_").slice(-120) || "attachment";
}

async function roleOf(svc: SupabaseClient, user: User): Promise<string> {
  const { data } = await svc.from("users").select("role_name").eq("id", user.id)
    .maybeSingle();
  return text(data?.role_name || user.app_metadata?.role_name).toLowerCase();
}

async function notify(
  svc: SupabaseClient,
  school: string,
  recipients: string[],
  title: string,
  body: string,
  issueId: string,
  targetRole: string,
) {
  const ids = [...new Set(recipients.filter(Boolean))];
  if (ids.length === 0) return;
  const logs = ids.map((userId) => ({
    school_id: school,
    user_id: userId,
    target_role: targetRole,
    title,
    body,
    type: "issue",
    entity_type: "issue",
    entity_id: issueId,
    route: "/issues-screen",
    priority: "high",
    is_read: false,
  }));
  await svc.from("notification_logs").insert(logs);
  const { data } = await svc.from("notification_events").insert(
    logs.map((row) => ({
      school_id: row.school_id,
      user_id: row.user_id,
      event_type: "issue",
      event_data: {
        title: row.title,
        message: row.body,
        reference_type: "issue",
        reference_id: issueId,
      },
    })),
  ).select("id");
  const eventIds = (data ?? []).map((row: Record<string, unknown>) =>
    text(row.id)
  ).filter(Boolean);
  if (eventIds.length) triggerPushProcessing(eventIds);
}

async function issueForAccess(
  svc: SupabaseClient,
  school: string,
  issueId: string,
) {
  return await svc.from("issues").select("*, issue_attachments(*)").eq(
    "school_id",
    school,
  ).eq("id", issueId).maybeSingle();
}

export async function handleIssues(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = schoolId(user);
  const role = await roleOf(svc, user);
  const isSuperAdmin = role == "super_admin";
  const canRaise = allowedRoles.has(role);
  if (!school || (!isSuperAdmin && !canRaise)) return fail("forbidden", 403);

  if (path == "/issues" && method == "GET") {
    let query = svc.from("issues").select("*, issue_attachments(*)", {
      count: "exact",
    }).eq("school_id", school);
    if (!isSuperAdmin) query = query.eq("raised_by", user.id);
    const status = text(url.searchParams.get("status"));
    if (status) query = query.eq("status", status);
    const { data, error, count } = await query.order("created_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    return ok({ data: data ?? [], total: count ?? 0 });
  }

  if (path == "/issues" && method == "POST") {
    if (!canRaise) {
      return fail("only principals and teachers can raise issues", 403);
    }
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const title = text(body.title), description = text(body.description);
    if (!title || !description) {
      return fail("title and description are required", 420);
    }
    const { data, error } = await svc.from("issues").insert({
      school_id: school,
      raised_by: user.id,
      raised_by_role: role,
      title,
      description,
      category: text(body.category) || "other",
      priority: text(body.priority) || "medium",
    }).select("*, issue_attachments(*)").single();
    if (error) return fail(error.message);
    const { data: admins } = await svc.from("users").select("id").eq(
      "school_id",
      school,
    ).eq("role_name", "super_admin").eq("is_active", true);
    await notify(
      svc,
      school,
      (admins ?? []).map((row: Record<string, unknown>) => text(row.id)),
      "New issue raised",
      `${role == "principal" ? "Principal" : "Teacher"}: ${title}`,
      text(data.id),
      "super_admin",
    );
    return ok(data);
  }

  const attachmentMatch = path.match(/^\/issues\/([^/]+)\/attachments$/);
  if (attachmentMatch && method == "POST") {
    const { data: issue, error } = await issueForAccess(
      svc,
      school,
      attachmentMatch[1],
    );
    if (error || !issue) return fail(error?.message ?? "Issue not found", 404);
    if (!isSuperAdmin && issue.raised_by != user.id) {
      return fail("forbidden", 403);
    }
    const form = await req.formData().catch(() => null);
    const file = form?.get("file");
    if (
      !(file instanceof File) || !allowedMimeTypes.has(file.type) ||
      file.size > maxAttachmentBytes
    ) {
      return fail(
        "Allowed file types are images, PDF, Word Docs (DOC/DOCX), MP4, WebM, and MOV; total issue attachments must not exceed 50 MB",
        420,
      );
    }
    const existing =
      issue.issue_attachments as Array<Record<string, unknown>> ?? [];
    const existingSize = existing.reduce(
      (sum, row) => sum + Number(row.file_size ?? 0),
      0,
    );
    if (existing.length >= 5 || existingSize + file.size > maxAttachmentBytes) {
      return fail(
        "An issue may have at most five attachments totaling 50 MB",
        420,
      );
    }
    const storagePath = `${school}/${issue.id}/${crypto.randomUUID()}-${
      safeName(file.name)
    }`;
    const { error: uploadError } = await svc.storage.from("issue-attachments")
      .upload(storagePath, file, { contentType: file.type, upsert: false });
    if (uploadError) return fail(uploadError.message);
    const { data, error: insertError } = await svc.from("issue_attachments")
      .insert({
        issue_id: issue.id,
        school_id: school,
        storage_path: storagePath,
        file_name: file.name,
        mime_type: file.type,
        file_size: file.size,
      }).select().single();
    if (insertError) {
      await svc.storage.from("issue-attachments").remove([storagePath]);
      return fail(insertError.message);
    }
    return ok(data);
  }

  const signedMatch = path.match(
    /^\/issues\/([^/]+)\/attachments\/([^/]+)\/url$/,
  );
  if (signedMatch && method == "GET") {
    const { data: issue, error } = await issueForAccess(
      svc,
      school,
      signedMatch[1],
    );
    if (error || !issue) return fail(error?.message ?? "Issue not found", 404);
    if (!isSuperAdmin && issue.raised_by != user.id) {
      return fail("forbidden", 403);
    }
    const attachment =
      (issue.issue_attachments as Array<Record<string, unknown>> ?? []).find((
        row,
      ) => text(row.id) == signedMatch[2]);
    if (!attachment) return fail("Attachment not found", 404);
    const { data, error: signedError } = await svc.storage.from(
      "issue-attachments",
    ).createSignedUrl(text(attachment.storage_path), 600);
    if (signedError || !data?.signedUrl) {
      return fail(signedError?.message ?? "Unable to prepare attachment");
    }
    return ok({ url: data.signedUrl, expires_in: 600 });
  }

  const issueMatch = path.match(/^\/issues\/([^/]+)$/);
  if (issueMatch && method == "PATCH") {
    if (!isSuperAdmin) return fail("only super_admin can resolve issues", 403);
    const { data: issue, error } = await issueForAccess(
      svc,
      school,
      issueMatch[1],
    );
    if (error || !issue) return fail(error?.message ?? "Issue not found", 404);
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const status = text(body.status);
    if (!["pending", "in_progress", "resolved"].includes(status)) {
      return fail("invalid status", 420);
    }
    const resolution = text(body.resolution_note);
    if (status == "resolved" && !resolution) {
      return fail("resolution_note is required when resolving", 420);
    }
    const updates: Record<string, unknown> = {
      status,
      updated_at: new Date().toISOString(),
    };
    if (status == "resolved") {
      updates.resolution_note = resolution;
      updates.resolved_by = user.id;
      updates.resolved_at = new Date().toISOString();
    }
    const { data, error: updateError } = await svc.from("issues").update(
      updates,
    ).eq("id", issue.id).eq("school_id", school).select(
      "*, issue_attachments(*)",
    ).single();
    if (updateError) return fail(updateError.message);
    await notify(
      svc,
      school,
      [text(issue.raised_by)],
      `Issue ${status.replace("_", " ")}`,
      status == "resolved"
        ? resolution
        : `Your issue “${text(issue.title)}” is now in progress.`,
      text(issue.id),
      text(issue.raised_by_role),
    );
    return ok(data);
  }
  return fail("not found", 404);
}

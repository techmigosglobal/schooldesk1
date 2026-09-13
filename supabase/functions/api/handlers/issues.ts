import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, triggerPushProcessing } from "../index.ts";
import {
  deleteR2File,
  legacyStorageWritesEnabled,
  r2FileReference,
  uploadToR2,
} from "../lib/r2_storage.ts";
import { signedPrivateFileUrl } from "../storage_helpers.ts";

const allowedRoles = new Set(["principal", "coordinator", "teacher", "parent"]);
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

function attachmentMime(file: File): string {
  const provided = text(file.type).toLowerCase();
  if (provided && provided !== "application/octet-stream") return provided;
  const name = file.name.toLowerCase();
  if (/\.jpe?g$/.test(name)) return "image/jpeg";
  if (name.endsWith(".png")) return "image/png";
  if (name.endsWith(".webp")) return "image/webp";
  if (name.endsWith(".pdf")) return "application/pdf";
  if (name.endsWith(".doc")) return "application/msword";
  if (name.endsWith(".docx")) {
    return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
  }
  if (name.endsWith(".mp4")) return "video/mp4";
  if (name.endsWith(".webm")) return "video/webm";
  if (name.endsWith(".mov")) return "video/quicktime";
  return provided;
}

async function removeAttachment(
  svc: SupabaseClient,
  storagePath: string,
) {
  if (storagePath.startsWith("r2://")) {
    await deleteR2File(storagePath);
  } else {
    await svc.storage.from("issue-attachments").remove([storagePath]);
  }
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
    route: targetRole === "principal"
      ? "/complaint-management-screen"
      : targetRole === "teacher"
      ? "/teacher-complaints-screen"
      : targetRole === "super_admin"
      ? "/super-admin-issues-screen"
      : "/parent-complaints-screen",
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
        route: row.route,
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

async function notifySuperAdminsOfIssue(
  svc: SupabaseClient,
  school: string,
  role: string,
  issue: Record<string, unknown>,
) {
  const { data: admins } = await svc.from("users").select("id").eq(
    "school_id",
    school,
  ).eq("role_name", "super_admin").eq("is_active", true);
  const reporter = role === "coordinator"
    ? "Coordinator"
    : role === "principal"
    ? "Principal"
    : role === "teacher"
    ? "Teacher"
    : "Parent";
  await notify(
    svc,
    school,
    (admins ?? []).map((row: Record<string, unknown>) => text(row.id)),
    "New issue raised",
    `${reporter}: ${text(issue.title)}`,
    text(issue.id),
    "super_admin",
  );
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

  if (path == "/issues/with-attachments" && method == "POST") {
    if (!canRaise) return fail("this role cannot raise issues", 403);
    const form = await req.formData().catch(() => null);
    if (!form) return fail("multipart form required", 400);
    const title = text(form.get("title"));
    const description = text(form.get("description"));
    if (!title || !description) {
      return fail("title and description are required", 420);
    }
    const files = form.getAll("files").filter((value): value is File =>
      value instanceof File
    );
    const totalBytes = files.reduce((sum, file) => sum + file.size, 0);
    if (
      files.length > 5 || totalBytes > maxAttachmentBytes ||
      files.some((file) => !allowedMimeTypes.has(attachmentMime(file)))
    ) {
      return fail(
        "Choose up to five image, PDF, Word, or supported video files totaling 50 MB",
        420,
      );
    }
    const { data: issue, error: issueError } = await svc.from("issues").insert({
      school_id: school,
      raised_by: user.id,
      raised_by_role: role,
      title,
      description,
      category: text(form.get("category")) || "other",
      priority: text(form.get("priority")) || "medium",
    }).select("*, issue_attachments(*)").single();
    if (issueError) return fail(issueError.message);

    const uploadedPaths: string[] = [];
    try {
      for (const file of files) {
        const mime = attachmentMime(file);
        const storagePath = `${school}/${issue.id}/${crypto.randomUUID()}-${
          safeName(file.name)
        }`;
        const r2Upload = await uploadToR2(
          `private/issue-attachments/${storagePath}`,
          file,
          mime,
        );
        const storedPath = r2Upload
          ? r2FileReference(r2Upload.key)
          : storagePath;
        if (!r2Upload) {
          if (!legacyStorageWritesEnabled()) {
            throw new Error("R2 storage is unavailable; legacy storage writes are disabled");
          }
          const { error: uploadError } = await svc.storage.from(
            "issue-attachments",
          ).upload(storagePath, file, {
            contentType: mime,
            upsert: false,
          });
          if (uploadError) throw uploadError;
        }
        uploadedPaths.push(storedPath);
        const { error: attachmentError } = await svc.from("issue_attachments")
          .insert({
            issue_id: issue.id,
            school_id: school,
            storage_path: storedPath,
            file_name: file.name,
            mime_type: mime,
            file_size: file.size,
          });
        if (attachmentError) throw attachmentError;
      }
    } catch (attachmentError) {
      const legacyPaths = uploadedPaths.filter((path) => !path.startsWith("r2://"));
      if (legacyPaths.length === uploadedPaths.length && legacyPaths.length) {
        await svc.storage.from("issue-attachments").remove(uploadedPaths);
      } else {
        for (const path of uploadedPaths) await removeAttachment(svc, path);
      }
      await svc.from("issues").delete().eq("id", issue.id).eq(
        "school_id",
        school,
      );
      return fail(
        attachmentError instanceof Error
          ? attachmentError.message
          : "attachment upload failed; issue was not created",
      );
    }
    await notifySuperAdminsOfIssue(svc, school, role, issue);
    const { data: savedIssue } = await issueForAccess(
      svc,
      school,
      text(issue.id),
    );
    return ok(savedIssue ?? issue);
  }

  if (path == "/issues" && method == "GET") {
    const page = Math.max(parseInt(url.searchParams.get("page") ?? "1") || 1, 1);
    const pageSize = Math.min(
      Math.max(parseInt(url.searchParams.get("page_size") ?? "20") || 20, 1),
      100,
    );
    let query = svc.from("issues").select(
      "id,school_id,raised_by,raised_by_role,title,description,category,priority,status,resolution_note,resolved_by,resolved_at,created_at,updated_at",
      {
      count: "exact",
      },
    ).eq("school_id", school);
    if (!isSuperAdmin) query = query.eq("raised_by", user.id);
    const status = text(url.searchParams.get("status"));
    const statuses = status.split(",").map((value) => value.trim()).filter(Boolean);
    if (statuses.length === 1) query = query.eq("status", statuses[0]);
    if (statuses.length > 1) query = query.in("status", statuses);
    const search = text(url.searchParams.get("search"));
    if (search) {
      const escaped = search.replace(/[%(),]/g, " ").trim();
      if (escaped) {
        query = query.or(
          `title.ilike.%${escaped}%,description.ilike.%${escaped}%`,
        );
      }
    }
    const { data, error, count } = await query.order("created_at", {
      ascending: false,
    }).order("id", { ascending: false }).range(
      (page - 1) * pageSize,
      page * pageSize - 1,
    );
    if (error) return fail(error.message);
    return ok({
      data: data ?? [],
      total: count ?? data?.length ?? 0,
      page,
      page_size: pageSize,
      has_more: page * pageSize < (count ?? 0),
    });
  }

  if (path == "/issues" && method == "POST") {
    if (!canRaise) {
      return fail("principals, teachers, and parents can raise issues", 403);
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
    await notifySuperAdminsOfIssue(svc, school, role, data);
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
      !(file instanceof File) || !allowedMimeTypes.has(attachmentMime(file)) ||
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
    const mime = attachmentMime(file);
    const r2Upload = await uploadToR2(
      `private/issue-attachments/${storagePath}`,
      file,
      mime,
    );
    const storedPath = r2Upload ? r2FileReference(r2Upload.key) : storagePath;
    if (!r2Upload) {
      if (!legacyStorageWritesEnabled()) {
        return fail("R2 storage is unavailable; legacy storage writes are disabled", 503);
      }
      const { error: uploadError } = await svc.storage.from("issue-attachments")
        .upload(storagePath, file, {
          contentType: mime,
          upsert: false,
        });
      if (uploadError) return fail(uploadError.message);
    }
    const { data, error: insertError } = await svc.from("issue_attachments")
      .insert({
        issue_id: issue.id,
        school_id: school,
        storage_path: storedPath,
        file_name: file.name,
        mime_type: mime,
        file_size: file.size,
      }).select().single();
    if (insertError) {
      await removeAttachment(svc, storedPath);
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
    if (!text(attachment.storage_path).startsWith("r2://")) {
      const { data, error: signedError } = await svc.storage.from(
        "issue-attachments",
      ).createSignedUrl(text(attachment.storage_path), 600);
      if (signedError || !data?.signedUrl) {
        return fail(signedError?.message ?? "Unable to prepare attachment");
      }
      return ok({ url: data.signedUrl, expires_in: 600 });
    }
    const signedUrl = await signedPrivateFileUrl(
      svc,
      text(attachment.storage_path),
      600,
      "issue-attachments",
    );
    if (!signedUrl) return fail("Unable to prepare attachment");
    return ok({ url: signedUrl, expires_in: 600 });
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

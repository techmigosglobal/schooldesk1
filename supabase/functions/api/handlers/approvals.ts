// handlers/approvals.ts
// NOTE: 'exam' module is permanently excluded — no exam approval entries
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, triggerPushProcessing } from "../index.ts";
function sid(u: User) { return (u.app_metadata?.school_id as string) ?? ""; }

const REMOVED_MODULES = ["exam", "exams", "exam_schedule", "result", "results"];

/**
 * Notify a single user of an approval decision via the same
 * notification_events + notification_logs pipeline used by leave.ts.
 * Best-effort: never allow a notification failure to break the approval flow.
 */
async function notifyApprovalDecision(
  svc: SupabaseClient,
  school: string,
  targetUserId: string,
  eventType: string,
  title: string,
  message: string,
  entityType: string,
  entityId: string,
  targetRole: string | null,
): Promise<void> {
  if (!targetUserId) return;
  try {
    const { data: eventRow } = await svc.from("notification_events").insert({
      school_id: school,
      user_id: targetUserId,
      event_type: eventType,
      event_data: {
        message,
        reference_type: entityType,
      },
    }).select("id").maybeSingle();
    if (eventRow?.id) triggerPushProcessing(eventRow.id);
    await svc.from("notification_logs").insert({
      school_id: school,
      user_id: targetUserId,
      target_role: targetRole,
      title,
      body: message,
      type: entityType,
      entity_type: entityType,
      entity_id: entityId,
      is_read: false,
    });
  } catch (notifErr) {
    console.error(`Failed to create ${entityType} notification: ${notifErr}`);
  }
}

export async function handleApprovals(req: Request, path: string, method: string, url: URL, _client: SupabaseClient, svc: SupabaseClient, user: User): Promise<Response> {
  const school = sid(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};

  // Account approvals
  if (path.startsWith("/account-approvals")) {
    const seg = path.slice("/account-approvals".length).split("/").filter(Boolean)[0];
    if (!seg && method === "GET") {
      let q = svc.from("account_approvals").select("*, user:users(*)").eq("school_id", school);
      if (url.searchParams.get("status")) q = q.eq("status", url.searchParams.get("status")!);
      const { data, error } = await q;
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!seg && method === "POST") {
      const { data, error } = await svc.from("account_approvals").insert({ ...body, school_id: school }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    const actionMatch = path.match(/^\/account-approvals\/([^/]+)\/(approve|reject)$/);
    if (actionMatch && method === "POST") {
      const [, id, action] = actionMatch;
      const { data, error } = await svc.from("account_approvals").update({ status: action === "approve" ? "approved" : "rejected", reviewed_by: user.id, updated_at: new Date().toISOString() }).eq("id", id).eq("school_id", school).select().single();
      if (error) return fail(error.message);
      // Activate/deactivate user if account approval
      if (data?.user_id) await svc.from("users").update({ is_active: action === "approve" }).eq("id", data.user_id);
      if (data?.user_id) {
        const approved = action === "approve";
        await notifyApprovalDecision(
          svc,
          school,
          `${data.user_id}`,
          approved ? "account_approved" : "account_rejected",
          approved ? "Account Approved ✅" : "Account Rejected",
          approved
            ? "Your account has been approved. You can now sign in."
            : `Your account request was rejected.${body.reason ? ` Reason: ${body.reason}` : ""}`,
          "account_approval",
          id,
          data.role ? `${data.role}` : null,
        );
      }
      return ok(data);
    }
  }

  // General approvals (approval_requests table)
  if (path.startsWith("/approvals")) {
    const seg = path.slice("/approvals".length).split("/").filter(Boolean)[0];
    if (!seg && method === "GET") {
      let q = svc.from("approval_requests").select("*, requested_by:users!approval_requests_requested_by_fkey(name, role_name)").eq("school_id", school);
      if (url.searchParams.get("status")) q = q.eq("status", url.searchParams.get("status")!);
      if (url.searchParams.get("module")) {
        const mod = url.searchParams.get("module")!;
        if (REMOVED_MODULES.includes(mod.toLowerCase())) return ok([]);
        q = q.eq("module", mod);
      }
      const { data, error } = await q.order("created_at", { ascending: false });
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!seg && method === "POST") {
      if (REMOVED_MODULES.includes((body.module as string ?? "").toLowerCase())) {
        return fail("exam-related approvals are not supported in this version", 400);
      }
      const { data, error } = await svc.from("approval_requests").insert({ ...body, school_id: school, submitted_at: new Date().toISOString() }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (seg) {
      const actionMatch = path.match(/^\/approvals\/([^/]+)\/(approve|reject|review)$/);
      if (actionMatch) {
        const [, id, action] = actionMatch;
        const status = action === "approve" ? "approved" : action === "reject" ? "rejected" : "under_review";
        const { data, error } = await svc.from("approval_requests").update({ status, reviewed_by: user.id, review_note: body.note ?? null, reviewed_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq("id", id).eq("school_id", school).select().single();
        if (error) return fail(error.message);
        if (data?.requested_by && status !== "under_review") {
          const approved = status === "approved";
          const moduleLabel = `${data.module ?? "request"}`;
          await notifyApprovalDecision(
            svc,
            school,
            `${data.requested_by}`,
            approved ? "approval_request_approved" : "approval_request_rejected",
            approved ? "Request Approved ✅" : "Request Rejected",
            approved
              ? `Your ${moduleLabel} request has been approved.`
              : `Your ${moduleLabel} request has been rejected.${body.note ? ` Reason: ${body.note}` : ""}`,
            "approval_request",
            id,
            null,
          );
        }
        return ok(data);
      }
    }
  }

  return fail("not found", 404);
}

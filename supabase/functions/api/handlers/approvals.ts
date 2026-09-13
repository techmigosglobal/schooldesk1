// handlers/approvals.ts
// NOTE: 'exam' module is permanently excluded — no exam approval entries
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok, triggerPushProcessing } from "../index.ts";
function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}

const REMOVED_MODULES = ["exam", "exams", "exam_schedule", "result", "results"];

function text(value: unknown, fallback = "") {
  const result = `${value ?? ""}`.trim();
  return result && result !== "null" ? result : fallback;
}

function dateOnly(value: unknown) {
  return text(value).split("T")[0];
}

function approvalType(module: unknown, type: unknown) {
  const value = text(module || type).toLowerCase();
  if (value === "students") return "student";
  if (value === "staff" || value === "user_access") return "account";
  if (value === "fees" || value === "fee") return "fee";
  if (value === "timetable") return "timetable";
  if (value === "documents") return "document";
  if (value === "communication") return "communication";
  if (value === "academic_info" || value === "attendance_operations") return "class";
  return value || "leave";
}

function pendingStatus(value: unknown) {
  const normalized = text(value, "pending").toLowerCase();
  if (["submitted", "pending_verification", "resubmitted"].includes(normalized)) {
    return "pending";
  }
  if (normalized === "clarification_required") return "changes_requested";
  return normalized;
}

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

export async function handleApprovals(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};

  if (path === "/approvals/feed" && method === "GET") {
    const page = Math.max(1, Number.parseInt(url.searchParams.get("page") ?? "1"));
    const requestedSize = Number.parseInt(url.searchParams.get("page_size") ?? "20");
    const size = Math.min(Math.max(Number.isFinite(requestedSize) ? requestedSize : 20, 1), 100);
    const statusFilter = text(url.searchParams.get("status"), "pending").toLowerCase();
    const typeFilter = text(url.searchParams.get("type")).toLowerCase();
    const search = text(url.searchParams.get("search")).toLowerCase();

    const [accounts, generic, staffLeave, studentLeave, concessions, payments, events] =
      await Promise.all([
        svc.from("account_approvals").select(
          "id, user_id, role, status, created_at, updated_at, user:users(name, role_name)",
        ).eq("school_id", school).limit(100),
        svc.from("approval_requests").select(
          "id, module, operation_type, entity_type, entity_id, status, submitted_at, created_at, review_note, requested_by:users(name, role_name)",
        ).eq("school_id", school).limit(100),
        svc.from("leave_applications").select(
          "id, staff_id, status, from_date, to_date, reason, created_at, staff:staff(first_name, last_name, designation)",
        ).eq("school_id", school).limit(100),
        svc.from("student_leave_applications").select(
          "id, student_id, parent_user_id, status, start_date, end_date, reason, created_at, updated_at, student:students(first_name, last_name, current_section:sections(section_name, grade:grades(grade_name))), parent_user:users(name, role_name)",
        ).eq("school_id", school).limit(100),
        svc.from("fee_concessions").select(
          "id, student_id, status, amount, reason, created_at, updated_at, student:students(first_name, last_name, current_section:sections(section_name, grade:grades(grade_name)))",
        ).eq("school_id", school).limit(100),
        svc.from("parent_payment_requests").select(
          "id, student_id, parent_user_id, status, amount, payment_method, transaction_ref, remarks, admin_remarks, payment_date, created_at, updated_at, student:students(first_name, last_name), parent_user:users(name, email), invoice:fee_invoices(invoice_number)",
        ).eq("school_id", school).limit(100),
        svc.from("event_posts").select(
          "id, title, body, status, created_at, updated_at, created_by, section_id",
        ).eq("school_id", school).in("status", ["pending", "submitted"]).limit(100),
      ]);
    const results = [accounts, generic, staffLeave, studentLeave, concessions, payments, events];
    const queryError = results.find((result) => result.error);
    if (queryError?.error) return fail(queryError.error.message ?? "failed to load approval feed");

    const items: Record<string, unknown>[] = [];
    for (const row of accounts.data ?? []) {
      const userRow = (row.user ?? {}) as unknown as Record<string, unknown>;
      items.push({
        id: text(row.id), type: "account", source: "generic",
        requesterName: text(userRow.name, "Account request"),
        requesterRole: text(userRow.role_name, text(row.role)), requesterClass: "Account access",
        submittedDate: dateOnly(row.created_at), summary: "Account approval",
        details: `Role: ${text(row.role, "Account")}`, status: pendingStatus(row.status),
        remarks: null, actionDate: dateOnly(row.updated_at),
        decisionPath: `/account-approvals/${text(row.id)}/approve`,
      });
    }
    for (const row of generic.data ?? []) {
      const requestedBy = (row.requested_by ?? {}) as unknown as Record<string, unknown>;
      const type = approvalType(row.module, row.entity_type);
      items.push({
        id: text(row.id), type, source: "generic",
        requesterName: text(requestedBy.name, "Requester"),
        requesterRole: text(requestedBy.role_name), requesterClass: text(row.entity_type),
        submittedDate: dateOnly(row.submitted_at ?? row.created_at),
        summary: text(row.module, type), details: text(row.operation_type),
        status: pendingStatus(row.status), remarks: row.review_note,
        actionDate: dateOnly(row.created_at), decisionPath: `/approvals/${text(row.id)}`,
      });
    }
    for (const row of staffLeave.data ?? []) {
      const staff = (row.staff ?? {}) as unknown as Record<string, unknown>;
      items.push({
        id: text(row.id), type: "leave", source: "generic",
        requesterName: [text(staff.first_name), text(staff.last_name)].filter(Boolean).join(" ") || "Teacher",
        requesterRole: "Teacher", requesterClass: text(staff.designation, "Staff leave"),
        submittedDate: dateOnly(row.created_at), summary: "Staff leave request",
        details: `From: ${dateOnly(row.from_date)}\nTo: ${dateOnly(row.to_date)}\nReason: ${text(row.reason)}`,
        status: pendingStatus(row.status), remarks: null, actionDate: null,
        decisionPath: `/leave/applications/${text(row.id)}/approve`,
      });
    }
    for (const row of studentLeave.data ?? []) {
      const student = (row.student ?? {}) as unknown as Record<string, unknown>;
      const section = (student.current_section ?? {}) as Record<string, unknown>;
      const grade = (section.grade ?? {}) as Record<string, unknown>;
      items.push({
        id: text(row.id), type: "student_leave", source: "generic",
        requesterName: [text(student.first_name), text(student.last_name)].filter(Boolean).join(" ") || "Student",
        requesterRole: "Parent", requesterClass: [text(grade.grade_name), text(section.section_name)].filter(Boolean).join(" - "),
        submittedDate: dateOnly(row.created_at), summary: "Student leave request",
        details: `From: ${dateOnly(row.start_date)}\nTo: ${dateOnly(row.end_date)}\nReason: ${text(row.reason)}`,
        status: pendingStatus(row.status), remarks: null, actionDate: dateOnly(row.updated_at),
        decisionPath: `/student-leave/applications/${text(row.id)}/decision`,
      });
    }
    for (const row of concessions.data ?? []) {
      const student = (row.student ?? {}) as unknown as Record<string, unknown>;
      items.push({
        id: text(row.id), type: "fee_concession", source: "fee_concession",
        requesterName: [text(student.first_name), text(student.last_name)].filter(Boolean).join(" ") || "Student",
        requesterRole: "Finance", requesterClass: "Fee concession",
        submittedDate: dateOnly(row.created_at), summary: `Concession ₹${text(row.amount, "0")}`,
        details: text(row.reason), status: pendingStatus(row.status), remarks: null,
        actionDate: dateOnly(row.updated_at), decisionPath: `/fees/concessions/${text(row.id)}/decision`,
      });
    }
    for (const row of payments.data ?? []) {
      const student = (row.student ?? {}) as unknown as Record<string, unknown>;
      const parent = (row.parent_user ?? {}) as unknown as Record<string, unknown>;
      const invoice = (row.invoice ?? {}) as unknown as Record<string, unknown>;
      items.push({
        id: text(row.id), type: "fee", source: "fee_payment_proof",
        requesterName: [text(student.first_name), text(student.last_name)].filter(Boolean).join(" ") || "Student",
        requesterRole: `Parent: ${text(parent.name, text(parent.email, "Parent"))}`, requesterClass: "Payment proof",
        submittedDate: dateOnly(row.payment_date ?? row.created_at),
        summary: `Payment proof ₹${text(row.amount, "0")} · ${text(invoice.invoice_number, "Invoice")}`,
        details: `Method: ${text(row.payment_method, "UPI")}\nReference: ${text(row.transaction_ref)}\n${text(row.remarks)}`,
        status: pendingStatus(row.status), remarks: row.admin_remarks,
        actionDate: dateOnly(row.updated_at), decisionPath: `/fees/payment-requests/${text(row.id)}/decision`,
      });
    }
    for (const row of events.data ?? []) {
      items.push({
        id: text(row.id), type: "event", source: "generic", requesterName: "Teacher",
        requesterRole: "Teacher", requesterClass: "Event post", submittedDate: dateOnly(row.created_at),
        summary: text(row.title, "Event post"), details: text(row.body), status: pendingStatus(row.status),
        remarks: null, actionDate: dateOnly(row.updated_at), decisionPath: `/event-posts/${text(row.id)}`,
      });
    }
    const filtered = items.filter((item) => {
      if (statusFilter !== "all" && text(item.status).toLowerCase() !== statusFilter) return false;
      if (typeFilter && text(item.type).toLowerCase() !== typeFilter) return false;
      if (!search) return true;
      return [item.requesterName, item.requesterRole, item.requesterClass, item.summary, item.details]
        .some((value) => text(value).toLowerCase().includes(search));
    }).sort((a, b) => {
      const pendingA = text(a.status) == "pending" ? 0 : 1;
      const pendingB = text(b.status) == "pending" ? 0 : 1;
      if (pendingA != pendingB) return pendingA - pendingB;
      return text(b.submittedDate).localeCompare(text(a.submittedDate));
    });
    const start = (page - 1) * size;
    const pageItems = filtered.slice(start, start + size);
    const countsByType: Record<string, number> = {};
    for (const item of filtered) {
      const key = text(item.type, "other");
      countsByType[key] = (countsByType[key] ?? 0) + 1;
    }
    return cors({
      success: true, data: pageItems, total: filtered.length,
      pending_count: filtered.filter((item) => item.status == "pending").length,
      counts_by_type: countsByType, page, page_size: size,
      has_more: start + pageItems.length < filtered.length,
    });
  }

  // Account approvals
  if (path.startsWith("/account-approvals")) {
    const seg =
      path.slice("/account-approvals".length).split("/").filter(Boolean)[0];
    if (!seg && method === "GET") {
      let q = svc.from("account_approvals").select(
        "*, user:users!account_approvals_user_id_fkey(*)",
      ).eq("school_id", school);
      if (url.searchParams.get("status")) {
        q = q.eq("status", url.searchParams.get("status")!);
      }
      const { data, error } = await q;
      if (error) return fail(error.message);
      return ok(data);
    }
    if (!seg && method === "POST") {
      const { data, error } = await svc.from("account_approvals").insert({
        ...body,
        school_id: school,
      }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    const actionMatch = path.match(
      /^\/account-approvals\/([^/]+)\/(approve|reject)$/,
    );
    if (actionMatch && method === "POST") {
      const [, id, action] = actionMatch;
      const expectedStatus = text(body.expected_status, "pending");
      const { data, error } = await svc.from("account_approvals").update({
        status: action === "approve" ? "approved" : "rejected",
        reviewed_by: user.id,
        updated_at: new Date().toISOString(),
      }).eq("id", id).eq("school_id", school).eq("status", expectedStatus)
        .select().single();
      if (error) return fail(error.message);
      // Activate/deactivate user if account approval
      if (data?.user_id) {
        await svc.from("users").update({ is_active: action === "approve" }).eq(
          "id",
          data.user_id,
        );
      }
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
            : `Your account request was rejected.${
              body.reason ? ` Reason: ${body.reason}` : ""
            }`,
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
      let q = svc.from("approval_requests").select(
        "*, requested_by:users!approval_requests_requested_by_fkey(name, role_name)",
      ).eq("school_id", school);
      if (url.searchParams.get("status")) {
        q = q.eq("status", url.searchParams.get("status")!);
      }
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
      if (
        REMOVED_MODULES.includes((body.module as string ?? "").toLowerCase())
      ) {
        return fail(
          "exam-related approvals are not supported in this version",
          400,
        );
      }
      const { data, error } = await svc.from("approval_requests").insert({
        ...body,
        school_id: school,
        submitted_at: new Date().toISOString(),
      }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (seg) {
      const actionMatch = path.match(
        /^\/approvals\/([^/]+)\/(approve|reject|review)$/,
      );
      if (actionMatch) {
        const [, id, action] = actionMatch;
        const status = action === "approve"
          ? "approved"
          : action === "reject"
          ? "rejected"
          : "under_review";
        const expectedStatus = text(body.expected_status);
        let updateQuery = svc.from("approval_requests").update({
          status,
          reviewed_by: user.id,
          review_note: body.note ?? null,
          reviewed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        }).eq("id", id).eq("school_id", school);
        updateQuery = expectedStatus
          ? updateQuery.eq("status", expectedStatus)
          : updateQuery.in("status", ["pending", "submitted", "resubmitted", "under_review"]);
        const { data, error } = await updateQuery.select().single();
        if (error) return fail(error.message);
        if (data?.requested_by && status !== "under_review") {
          const approved = status === "approved";
          const moduleLabel = `${data.module ?? "request"}`;
          await notifyApprovalDecision(
            svc,
            school,
            `${data.requested_by}`,
            approved
              ? "approval_request_approved"
              : "approval_request_rejected",
            approved ? "Request Approved ✅" : "Request Rejected",
            approved
              ? `Your ${moduleLabel} request has been approved.`
              : `Your ${moduleLabel} request has been rejected.${
                body.note ? ` Reason: ${body.note}` : ""
              }`,
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

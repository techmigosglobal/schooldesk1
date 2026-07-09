// handlers/leave.ts
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, triggerPushProcessing } from "../index.ts";
function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}
function text(v: unknown, fb = ""): string {
  const t = `${v ?? ""}`.trim();
  return t || fb;
}

async function ensureDefaultLeaveTypes(
  svc: SupabaseClient,
  school: string,
): Promise<Array<Record<string, unknown>>> {
  const { data: existing, error: existingError } = await svc
    .from("leave_types")
    .select("*")
    .eq("school_id", school)
    .order("created_at", { ascending: true });
  if (existingError) throw existingError;
  if ((existing ?? []).length > 0) {
    return (existing ?? []).map((row) => ({ ...row }));
  }

  const defaults = [
    { school_id: school, name: "Casual Leave", max_days: 12, is_paid: true },
    { school_id: school, name: "Sick Leave", max_days: 10, is_paid: true },
    { school_id: school, name: "Earned Leave", max_days: 15, is_paid: true },
  ];
  const { data: inserted, error: insertError } = await svc
    .from("leave_types")
    .insert(defaults)
    .select("*");
  if (insertError) throw insertError;
  return (inserted ?? []).map((row) => ({ ...row }));
}

/** Resolve a staff record ID to the auth user_id for push notifications. */
async function resolveUserId(
  svc: SupabaseClient,
  school: string,
  staffId: string,
): Promise<string> {
  if (!staffId) return "";
  const { data } = await svc
    .from("users")
    .select("id")
    .eq("school_id", school)
    .eq("linked_type", "staff")
    .eq("linked_id", staffId)
    .limit(1)
    .maybeSingle();
  return data?.id ?? "";
}

/** Resolve the principal's auth user_id for push notifications. */
async function resolvePrincipalUserId(
  svc: SupabaseClient,
  school: string,
): Promise<string> {
  const { data } = await svc
    .from("users")
    .select("id")
    .eq("school_id", school)
    .eq("linked_type", "principal")
    .limit(1)
    .maybeSingle();
  if (data?.id) return data.id;
  // Fallback: look for role_name containing 'principal'
  const { data: roleUser } = await svc
    .from("users")
    .select("id")
    .eq("school_id", school)
    .ilike("role_name", "%principal%")
    .limit(1)
    .maybeSingle();
  return roleUser?.id ?? "";
}

/** Resolve a student_id to the parent/guardian auth user_id for push notifications. */
async function resolveStudentParentUserId(
  svc: SupabaseClient,
  school: string,
  studentId: string,
): Promise<string> {
  if (!studentId) return "";
  const { data } = await svc
    .from("parent_student_links")
    .select("parent_user_id")
    .eq("student_id", studentId)
    .limit(1)
    .maybeSingle();
  return data?.parent_user_id ?? "";
}

export async function handleLeave(
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

  if (path === "/leave/types" && method === "GET") {
    try {
      const rows = await ensureDefaultLeaveTypes(svc, school);
      return ok(rows);
    } catch (error) {
      return fail(error instanceof Error ? error.message : `${error}`);
    }
  }

  if (path === "/leave/balances" && method === "GET") {
    let q = svc.from("leave_balances").select("*").eq("school_id", school);
    if (url.searchParams.get("staff_id")) {
      q = q.eq("staff_id", url.searchParams.get("staff_id")!);
    }
    if (url.searchParams.get("academic_year_id")) {
      q = q.eq("academic_year_id", url.searchParams.get("academic_year_id")!);
    }
    const { data, error } = await q.order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  if (path === "/leave/applications" && method === "GET") {
    let q = svc.from("leave_applications").select(
      "*, staff:staff(first_name, last_name, staff_code)",
    ).eq("school_id", school);
    if (url.searchParams.get("status")) {
      q = q.eq("status", url.searchParams.get("status")!);
    }
    if (url.searchParams.get("staff_id")) {
      q = q.eq("staff_id", url.searchParams.get("staff_id")!);
    }
    const { data, error } = await q.order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok(data);
  }

  if (path === "/leave/applications" && method === "POST") {
    const staffId = text(body.staff_id);
    if (!staffId) return fail("staff_id required", 400);
    const leaveTypes = await ensureDefaultLeaveTypes(svc, school);
    const defaultLeaveTypeId = text(leaveTypes[0]?.id);
    const {
      from_date: _fromDate,
      to_date: _toDate,
      half_day: _halfDay,
      ...rest
    } = body as Record<string, unknown>;
    const payload = {
      ...rest,
      school_id: school,
      staff_id: staffId,
      status: "pending",
      leave_type_id: text(body.leave_type_id) || defaultLeaveTypeId || null,
      start_date: body.start_date ?? body.from_date,
      end_date: body.end_date ?? body.to_date,
    };
    const { data, error } = await svc.from("leave_applications").insert(payload)
      .select().single();
    if (error) return fail(error.message);
    // Notify the principal that a new leave request has been submitted
    try {
      const principalUserId = await resolvePrincipalUserId(svc, school);
      if (principalUserId) {
        const fromDate = text(data.start_date).split("T")[0] ?? "";
        const toDate = text(data.end_date).split("T")[0] ?? "";
        const dateRange = fromDate && toDate ? ` (${fromDate} to ${toDate})` : "";
        const staffUserId = await resolveUserId(svc, school, staffId);
        // Resolve staff name from staff table
        const { data: staffRow } = await svc.from("staff")
          .select("first_name, last_name")
          .eq("id", staffId)
          .eq("school_id", school)
          .maybeSingle();
        const staffName = staffRow
          ? `${text(staffRow.first_name)} ${text(staffRow.last_name)}`.trim()
          : text(staffUserId, "A teacher");
        const notifBody = `${staffName} has submitted a leave request${dateRange}. Please review.`;
        const { data: eventRow } = await svc.from("notification_events").insert({
          school_id: school,
          user_id: principalUserId,
          event_type: "leave_submitted",
          event_data: {
            leave_id: data.id,
            message: notifBody,
            reference_type: "leave",
          },
        }).select("id").maybeSingle();
        if (eventRow?.id) triggerPushProcessing(eventRow.id);
        await svc.from("notification_logs").insert({
          school_id: school,
          user_id: principalUserId,
          title: "New Leave Request",
          body: notifBody,
          type: "leave",
          entity_type: "leave",
          entity_id: data.id,
          target_role: "principal",
          is_read: false,
        });
      }
    } catch (notifErr) {
      console.error(`Failed to create leave submission notification: ${notifErr}`);
    }
    return ok(data);
  }

  const recallMatch = path.match(/^\/leave\/applications\/([^/]+)\/recall$/);
  if (recallMatch && method === "POST") {
    const { data, error } = await svc.from("leave_applications").update({
      status: "recalled",
      updated_at: new Date().toISOString(),
    }).eq("id", recallMatch[1]).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    // Notify the principal that a leave request was recalled
    try {
      const principalUserId = await resolvePrincipalUserId(svc, school);
      if (principalUserId) {
        const staffName = [
          text(data.staff?.first_name),
          text(data.staff?.last_name),
        ].filter(Boolean).join(" ") || text(data.staff_id, "A teacher");
        const fromDate = text(data.start_date).split("T")[0] ?? "";
        const toDate = text(data.end_date).split("T")[0] ?? "";
        const dateRange = fromDate && toDate
          ? ` (${fromDate} to ${toDate})`
          : "";
        const { data: eventRow } = await svc.from("notification_events").insert({
          school_id: school,
          user_id: principalUserId,
          event_type: "leave_recalled",
          event_data: {
            leave_id: recallMatch[1],
            message: `${staffName} has recalled their leave request${dateRange}.`,
            reference_type: "leave",
          },
        }).select("id").maybeSingle();
        if (eventRow?.id) triggerPushProcessing(eventRow.id);
        await svc.from("notification_logs").insert({
          school_id: school,
          user_id: principalUserId,
          title: "Leave Request Recalled",
          body: `${staffName} has recalled their leave request${dateRange}.`,
          type: "leave",
          entity_type: "leave",
          entity_id: recallMatch[1],
          target_role: "principal",
          is_read: false,
        });
      }
    } catch (notifErr) {
      console.error(`Failed to create recall notification: ${notifErr}`);
    }
    return ok(data);
  }

  const actionMatch = path.match(
    /^\/leave\/applications\/([^/]+)\/(approve|reject)$/,
  );
  if (actionMatch && method === "POST") {
    const [, leaveId, action] = actionMatch;
    const resolvedStatus = action === "approve" ? "approved" : "rejected";
    const { data, error } = await svc.from("leave_applications").update({
      status: resolvedStatus,
      reviewed_by: user.id,
      review_note: body.note ?? null,
      updated_at: new Date().toISOString(),
    }).eq("id", leaveId).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    // Create notification_events so the processor sends a push to the teacher
    try {
      const staffUserId = await resolveUserId(svc, school, text(data.staff_id));
      const targetUserId = staffUserId || text(data.staff_id);
      const eventType = resolvedStatus === "approved"
        ? "leave_approved"
        : "leave_rejected";
      if (targetUserId) {
        const { data: eventRow } = await svc.from("notification_events").insert(
          {
            school_id: school,
            user_id: targetUserId,
            event_type: eventType,
            event_data: {
              leave_id: leaveId,
              message: resolvedStatus === "approved"
                ? `Your leave request (${
                  data.start_date?.split("T")[0] ?? ""
                } to ${data.end_date?.split("T")[0] ?? ""}) has been approved.`
                : `Your leave request (${
                  data.start_date?.split("T")[0] ?? ""
                } to ${data.end_date?.split("T")[0] ?? ""}) has been rejected.${
                  body.note ? ` Reason: ${body.note}` : ""
                }`,
              reference_type: "leave",
            },
          },
        ).select("id").maybeSingle();
        if (eventRow?.id) triggerPushProcessing(eventRow.id);
        // Also create a notification_logs entry so it appears in the in-app notification center
        await svc.from("notification_logs").insert({
          school_id: school,
          user_id: targetUserId,
          title: resolvedStatus === "approved"
            ? "Leave Approved ✅"
            : "Leave Rejected",
          body: resolvedStatus === "approved"
            ? `Your leave request has been approved.`
            : `Your leave request has been rejected.${
              body.note ? ` Reason: ${body.note}` : ""
            }`,
          type: "leave",
          entity_type: "leave",
          entity_id: leaveId,
          target_role: "teacher",
          is_read: false,
        });
      }
    } catch (notifErr) {
      console.error(`Failed to create leave notification: ${notifErr}`);
    }
    return ok(data);
  }
  const approveAliasMatch = path.match(
    /^\/leave\/applications\/([^/]+)\/approve$/,
  );
  if (approveAliasMatch && method === "PUT") {
    const status = `${body.status ?? "approved"}`.trim().toLowerCase();
    const resolvedStatus = status == "rejected" ? "rejected" : "approved";
    const { data, error } = await svc.from("leave_applications").update({
      status: resolvedStatus,
      reviewed_by: user.id,
      review_note: body.reason ?? body.note ?? null,
      updated_at: new Date().toISOString(),
    }).eq("id", approveAliasMatch[1]).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    // Create notification_events so the processor sends a push to the teacher
    try {
      const staffUserId = await resolveUserId(svc, school, text(data.staff_id));
      const targetUserId = staffUserId || text(data.staff_id);
      const eventType = resolvedStatus === "approved"
        ? "leave_approved"
        : "leave_rejected";
      if (targetUserId) {
        const { data: eventRow } = await svc.from("notification_events").insert(
          {
            school_id: school,
            user_id: targetUserId,
            event_type: eventType,
            event_data: {
              leave_id: approveAliasMatch[1],
              message: resolvedStatus === "approved"
                ? `Your leave request (${
                  data.start_date?.split("T")[0] ?? ""
                } to ${data.end_date?.split("T")[0] ?? ""}) has been approved.`
                : `Your leave request (${
                  data.start_date?.split("T")[0] ?? ""
                } to ${data.end_date?.split("T")[0] ?? ""}) has been rejected.${
                  body.reason ? ` Reason: ${body.reason}` : ""
                }`,
              reference_type: "leave",
            },
          },
        ).select("id").maybeSingle();
        if (eventRow?.id) triggerPushProcessing(eventRow.id);
        await svc.from("notification_logs").insert({
          school_id: school,
          user_id: targetUserId,
          title: resolvedStatus === "approved"
            ? "Leave Approved ✅"
            : "Leave Rejected",
          body: resolvedStatus === "approved"
            ? `Your leave request has been approved.`
            : `Your leave request has been rejected.${
              body.reason ? ` Reason: ${body.reason}` : ""
            }`,
          type: "leave",
          entity_type: "leave",
          entity_id: approveAliasMatch[1],
          target_role: "teacher",
          is_read: false,
        });
      }
    } catch (notifErr) {
      console.error(`Failed to create leave notification: ${notifErr}`);
    }
    return ok(data);
  }

  // Student leave
  if (path === "/student-leave/applications" && method === "GET") {
    let q = svc.from("student_leave_applications").select(
      "*, student:students(first_name, last_name)",
    ).eq("school_id", school);
    if (url.searchParams.get("status")) {
      q = q.eq("status", url.searchParams.get("status")!);
    }
    if (url.searchParams.get("student_id")) {
      q = q.eq("student_id", url.searchParams.get("student_id")!);
    }
    const { data, error } = await q;
    if (error) return fail(error.message);
    return ok(data);
  }

  if (path === "/student-leave/applications" && method === "POST") {
    const {
      from_date: _fromDate,
      to_date: _toDate,
      half_day: _halfDay,
      ...rest
    } = body as Record<string, unknown>;
    const payload = {
      ...rest,
      school_id: school,
      status: "pending",
      start_date: body.start_date ?? body.from_date,
      end_date: body.end_date ?? body.to_date,
    };
    const { data, error } = await svc.from("student_leave_applications").insert(
      payload,
    ).select().single();
    if (error) return fail(error.message);
    // Notify the principal that a student leave request has been submitted
    try {
      const principalUserId = await resolvePrincipalUserId(svc, school);
      if (principalUserId) {
        const studentId = text(data.student_id);
        const fromDate = text(data.start_date).split("T")[0] ?? "";
        const toDate = text(data.end_date).split("T")[0] ?? "";
        const dateRange = fromDate && toDate ? ` (${fromDate} to ${toDate})` : "";
        // Resolve student name
        let studentLabel = "A student";
        if (studentId) {
          const { data: studentRow } = await svc.from("students")
            .select("first_name, last_name")
            .eq("id", studentId)
            .eq("school_id", school)
            .maybeSingle();
          if (studentRow) {
            const fn = text(studentRow.first_name);
            const ln = text(studentRow.last_name);
            studentLabel = fn && ln ? `${fn} ${ln}` : fn || ln || "A student";
          }
        }
        const notifBody = `A parent submitted a leave request for ${studentLabel}${dateRange}. Please review.`;
        const { data: eventRow } = await svc.from("notification_events").insert({
          school_id: school,
          user_id: principalUserId,
          event_type: "student_leave_submitted",
          event_data: {
            leave_id: data.id,
            message: notifBody,
            reference_type: "leave",
          },
        }).select("id").maybeSingle();
        if (eventRow?.id) triggerPushProcessing(eventRow.id);
        await svc.from("notification_logs").insert({
          school_id: school,
          user_id: principalUserId,
          title: "Student Leave Request",
          body: notifBody,
          type: "leave",
          entity_type: "student_leave",
          entity_id: data.id,
          target_role: "principal",
          is_read: false,
        });
      }
    } catch (notifErr) {
      console.error(`Failed to create student leave submission notification: ${notifErr}`);
    }
    return ok(data);
  }

  const studentDecisionMatch = path.match(
    /^\/student-leave\/applications\/([^/]+)\/decision$/,
  );
  if (studentDecisionMatch && method === "PUT") {
    const nextStatus = `${body.status ?? "pending"}`.trim().toLowerCase();
    const { data, error } = await svc.from("student_leave_applications").update(
      {
        status: nextStatus,
        rejection_reason: body.rejection_reason ?? null,
        reviewed_by: user.id,
        updated_at: new Date().toISOString(),
      },
    ).eq("id", studentDecisionMatch[1]).eq("school_id", school).select()
      .single();
    if (error) return fail(error.message);
    // Notify the parent about student leave decision
    try {
      const parentUserId = await resolveStudentParentUserId(
        svc,
        school,
        text(data.student_id),
      );
      const eventType = nextStatus === "approved"
        ? "student_leave_approved"
        : "student_leave_rejected";
      if (parentUserId) {
        const { data: eventRow } = await svc.from("notification_events").insert(
          {
            school_id: school,
            user_id: parentUserId,
            event_type: eventType,
            event_data: {
              leave_id: studentDecisionMatch[1],
              message: nextStatus === "approved"
                ? `Student leave request has been approved.`
                : `Student leave request has been rejected.${
                  body.rejection_reason
                    ? ` Reason: ${body.rejection_reason}`
                    : ""
                }`,
              reference_type: "leave",
            },
          },
        ).select("id").maybeSingle();
        if (eventRow?.id) triggerPushProcessing(eventRow.id);
        await svc.from("notification_logs").insert({
          school_id: school,
          user_id: parentUserId,
          title: nextStatus === "approved"
            ? "Student Leave Approved ✅"
            : "Student Leave Rejected",
          body: nextStatus === "approved"
            ? `Student leave request has been approved.`
            : `Student leave request has been rejected.${
              body.rejection_reason ? ` Reason: ${body.rejection_reason}` : ""
            }`,
          type: "leave",
          entity_type: "student_leave",
          entity_id: studentDecisionMatch[1],
          target_role: "parent",
          is_read: false,
        });
      }
    } catch (notifErr) {
      console.error(`Failed to create student leave notification: ${notifErr}`);
    }
    return ok(data);
  }

  return fail("not found", 404);
}

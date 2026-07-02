// handlers/leave.ts
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { ok, fail } from "../index.ts";
function sid(u: User) { return (u.app_metadata?.school_id as string) ?? ""; }

export async function handleLeave(req: Request, path: string, method: string, url: URL, _client: SupabaseClient, svc: SupabaseClient, user: User): Promise<Response> {
  const school = sid(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};

  if (path === "/leave/types" && method === "GET") {
    const { data, error } = await svc.from("leave_types").select("*").eq("school_id", school);
    if (error) return fail(error.message);
    return ok(data);
  }

  if (path === "/leave/balances" && method === "GET") {
    let q = svc.from("leave_balances").select("*").eq("school_id", school);
    if (url.searchParams.get("staff_id")) q = q.eq("staff_id", url.searchParams.get("staff_id")!);
    if (url.searchParams.get("academic_year_id")) q = q.eq("academic_year_id", url.searchParams.get("academic_year_id")!);
    const { data, error } = await q.order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  if (path === "/leave/applications" && method === "GET") {
    let q = svc.from("leave_applications").select("*, staff:staff(first_name, last_name, staff_code)").eq("school_id", school);
    if (url.searchParams.get("status")) q = q.eq("status", url.searchParams.get("status")!);
    if (url.searchParams.get("staff_id")) q = q.eq("staff_id", url.searchParams.get("staff_id")!);
    const { data, error } = await q.order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok(data);
  }

  if (path === "/leave/applications" && method === "POST") {
    const { from_date: _fromDate, to_date: _toDate, ...rest } =
      body as Record<string, unknown>;
    const payload = {
      ...rest,
      school_id: school,
      status: "pending",
      start_date: body.start_date ?? body.from_date,
      end_date: body.end_date ?? body.to_date,
    };
    const { data, error } = await svc.from("leave_applications").insert(payload).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  const recallMatch = path.match(/^\/leave\/applications\/([^/]+)\/recall$/);
  if (recallMatch && method === "POST") {
    const { data, error } = await svc.from("leave_applications").update({
      status: "recalled",
      updated_at: new Date().toISOString(),
    }).eq("id", recallMatch[1]).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  const actionMatch = path.match(/^\/leave\/applications\/([^/]+)\/(approve|reject)$/);
  if (actionMatch && method === "POST") {
    const [, leaveId, action] = actionMatch;
    const { data, error } = await svc.from("leave_applications").update({ status: action === "approve" ? "approved" : "rejected", reviewed_by: user.id, review_note: body.note ?? null, updated_at: new Date().toISOString() }).eq("id", leaveId).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }
  const approveAliasMatch = path.match(/^\/leave\/applications\/([^/]+)\/approve$/);
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
    return ok(data);
  }

  // Student leave
  if (path === "/student-leave/applications" && method === "GET") {
    let q = svc.from("student_leave_applications").select("*, student:students(first_name, last_name)").eq("school_id", school);
    if (url.searchParams.get("status")) q = q.eq("status", url.searchParams.get("status")!);
    if (url.searchParams.get("student_id")) q = q.eq("student_id", url.searchParams.get("student_id")!);
    const { data, error } = await q;
    if (error) return fail(error.message);
    return ok(data);
  }

  if (path === "/student-leave/applications" && method === "POST") {
    const { from_date: _fromDate, to_date: _toDate, ...rest } =
      body as Record<string, unknown>;
    const payload = {
      ...rest,
      school_id: school,
      status: "pending",
      start_date: body.start_date ?? body.from_date,
      end_date: body.end_date ?? body.to_date,
    };
    const { data, error } = await svc.from("student_leave_applications").insert(payload).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  const studentDecisionMatch = path.match(/^\/student-leave\/applications\/([^/]+)\/decision$/);
  if (studentDecisionMatch && method === "PUT") {
    const nextStatus = `${body.status ?? "pending"}`.trim().toLowerCase();
    const { data, error } = await svc.from("student_leave_applications").update({
      status: nextStatus,
      rejection_reason: body.rejection_reason ?? null,
      reviewed_by: user.id,
      updated_at: new Date().toISOString(),
    }).eq("id", studentDecisionMatch[1]).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  return fail("not found", 404);
}

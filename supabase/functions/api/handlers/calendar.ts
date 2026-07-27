import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, triggerPushProcessing } from "../index.ts";

function schoolId(user: User): string {
  return (user.app_metadata?.school_id as string) ?? "";
}

function roleName(user: User): string {
  return `${user.app_metadata?.role_name ?? ""}`.trim().toLowerCase();
}

function parseId(path: string, prefix: string): string | null {
  const rest = path.slice(prefix.length);
  const seg = rest.split("/").filter(Boolean)[0];
  return seg && seg !== "" ? seg : null;
}

function query(url: URL, key: string): string | null {
  return url.searchParams.get(key);
}

async function notifyEventAudience(
  svc: SupabaseClient,
  school: string,
  event: Record<string, unknown>,
) {
  const audience = `${event.audience_type ?? "all"}`.trim().toLowerCase();
  const roles = ["parents", "students"].includes(audience)
    ? ["parent"]
    : ["staff", "teachers"].includes(audience)
    ? ["teacher"]
    : ["parent", "teacher"];
  const { data: recipients, error } = await svc.from("users").select(
    "id, role_name",
  ).eq("school_id", school).eq("is_active", true).in("role_name", roles);
  if (error || !recipients?.length) return;
  const title = `${
    event.event_title ?? event.event_name ?? "New school event"
  }`;
  const start =
    `${event.start_datetime ?? event.start_date ?? event.event_date ?? ""}`
      .split("T")[0];
  const body = start
    ? `${title} is scheduled for ${start}. Open the school calendar for details.`
    : `${title} was added to the school calendar.`;
  const logs = recipients.map((recipient: Record<string, unknown>) => {
    const targetRole = `${recipient.role_name ?? ""}`.toLowerCase();
    return {
      school_id: school,
      user_id: recipient.id,
      target_role: targetRole,
      title: "New school event",
      body,
      type: "event",
      entity_type: "event",
      entity_id: event.id,
      route: targetRole === "parent"
        ? "/parent-calendar-screen"
        : "/teacher-calendar-screen",
      priority: "medium",
      is_read: false,
    };
  });
  const { error: logError } = await svc.from("notification_logs").insert(logs);
  if (logError) return;
  const { data: pushRows, error: pushError } = await svc.from(
    "notification_events",
  ).insert(logs.map((log) => ({
    school_id: log.school_id,
    user_id: log.user_id,
    event_type: "event_created",
    event_data: {
      title: log.title,
      message: log.body,
      reference_type: "event",
      reference_id: event.id,
      route: log.route,
    },
    processed: false,
  }))).select("id");
  if (pushError) return;
  const ids = (pushRows ?? []).map((row: Record<string, unknown>) =>
    `${row.id ?? ""}`.trim()
  ).filter(Boolean);
  if (ids.length) triggerPushProcessing(ids);
}

export async function handleCalendar(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const sid = schoolId(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};

  if (path === "/events/calendar-reset" && method === "POST") {
    if (!["principal"].includes(roleName(user))) return fail("forbidden", 403);
    if (`${body.confirmation ?? ""}`.trim().toUpperCase() !== "RESET") {
      return fail("type RESET to confirm calendar reset", 400);
    }
    const { count: ptmCount, error: ptmError } = await svc
      .from("parent_teacher_meetings")
      .delete({ count: "exact" })
      .eq("school_id", sid);
    if (ptmError) return fail(ptmError.message);
    const { count: eventCount, error: eventError } = await svc
      .from("events")
      .delete({ count: "exact" })
      .eq("school_id", sid);
    if (eventError) return fail(eventError.message);
    const { error: preferenceError } = await svc
      .from("school_calendar_preferences")
      .upsert({
        school_id: sid,
        hide_generated_holidays: true,
        updated_by: user.id,
        updated_at: new Date().toISOString(),
      }, { onConflict: "school_id" });
    if (preferenceError) return fail(preferenceError.message);
    const { error: auditError } = await svc.from("audit_logs").insert({
      school_id: sid,
      user_id: user.id,
      actor_role: roleName(user),
      action: "calendar_reset",
      module: "events",
      event_type: "calendar_reset",
      summary: `Reset calendar: removed ${eventCount ?? 0} events and ${
        ptmCount ?? 0
      } PTM entries; generated holidays hidden.`,
    });
    if (auditError) console.error("Calendar reset audit failed", auditError);
    return ok({
      events_deleted: eventCount ?? 0,
      ptms_deleted: ptmCount ?? 0,
      generated_holidays_hidden: true,
    });
  }

  if (path === "/events/calendar-preferences" && method === "GET") {
    const { data, error } = await svc
      .from("school_calendar_preferences")
      .select("hide_generated_holidays")
      .eq("school_id", sid)
      .maybeSingle();
    if (error) return fail(error.message);
    return ok({
      hide_generated_holidays: data?.hide_generated_holidays === true,
    });
  }

  if (path.startsWith("/holidays")) {
    if (method !== "GET") return fail("method not allowed", 405);
    let q = svc.from("holidays").select("*").eq("school_id", sid);
    if (query(url, "academic_year_id")) {
      q = q.eq("academic_year_id", query(url, "academic_year_id")!);
    }
    const { data, error } = await q.order("from_date", { ascending: true });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  if (path.startsWith("/events")) {
    const id = parseId(path, "/events");
    if (!id && method === "GET") {
      let q = svc.from("events").select("*").eq("school_id", sid);
      if (query(url, "academic_year_id")) {
        q = q.eq("academic_year_id", query(url, "academic_year_id")!);
      }
      const { data, error } = await q.order("start_datetime", {
        ascending: true,
      }).order("start_date", { ascending: true });
      if (error) return fail(error.message);
      return ok(data ?? []);
    }
    if (!id && method === "POST") {
      if (!["principal", "coordinator"].includes(roleName(user))) {
        return fail("forbidden", 403);
      }
      const payload = {
        ...body,
        school_id: sid,
        event_name: body.event_name ?? body.event_title,
        location: body.location ?? body.venue ?? "",
        venue: body.venue ?? body.location ?? "",
        created_by: user.id,
        updated_by: user.id,
      };
      const { data, error } = await svc.from("events").insert(payload).select()
        .single();
      if (error) return fail(error.message);
      try {
        await notifyEventAudience(svc, sid, data as Record<string, unknown>);
      } catch (notificationError) {
        console.error("Failed to notify event audience", notificationError);
      }
      return ok(data);
    }
    if (id && method === "PUT") {
      if (!["principal", "coordinator"].includes(roleName(user))) {
        return fail("forbidden", 403);
      }
      const payload = {
        ...body,
        event_name: body.event_name ?? body.event_title,
        location: body.location ?? body.venue,
        venue: body.venue ?? body.location,
        updated_by: user.id,
        updated_at: new Date().toISOString(),
      };
      const { data, error } = await svc.from("events").update(payload).eq(
        "id",
        id,
      ).eq("school_id", sid).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (id && method === "DELETE") {
      if (!["principal", "coordinator"].includes(roleName(user))) {
        return fail("forbidden", 403);
      }
      const { error } = await svc.from("events").delete().eq("id", id).eq(
        "school_id",
        sid,
      );
      if (error) return fail(error.message);
      return ok({ success: true });
    }
  }

  return fail("not found", 404);
}

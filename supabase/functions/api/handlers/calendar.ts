import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

function schoolId(user: User): string {
  return (user.app_metadata?.school_id as string) ?? "";
}

function parseId(path: string, prefix: string): string | null {
  const rest = path.slice(prefix.length);
  const seg = rest.split("/").filter(Boolean)[0];
  return seg && seg !== "" ? seg : null;
}

function query(url: URL, key: string): string | null {
  return url.searchParams.get(key);
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
      return ok(data);
    }
    if (id && method === "PUT") {
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

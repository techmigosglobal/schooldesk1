import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

const bucket = "school-public-media";
const text = (value: unknown) => typeof value === "string" ? value.trim() : "";
const schoolId = (user: User) => text(user.app_metadata?.school_id);
const isPrincipal = (user: User) =>
  text(user.app_metadata?.role_name).toLowerCase() === "principal";

function publicUrl(svc: SupabaseClient, path: string) {
  return svc.storage.from(bucket).getPublicUrl(path).data.publicUrl;
}

function galleryRow(svc: SupabaseClient, row: Record<string, unknown>) {
  return { ...row, media_url: publicUrl(svc, text(row.media_path)) };
}

function eventGalleryRows(row: Record<string, unknown>) {
  const media = Array.isArray(row.media_urls) ? row.media_urls : [];
  return media
    .map((item, index) => {
      const object = item !== null && typeof item === "object"
        ? item as Record<string, unknown>
        : {};
      const mediaUrl = typeof item === "string"
        ? item.trim()
        : text(object.url ?? object.media_url ?? object.secure_url);
      return {
        id: `event:${text(row.id)}:${index}`,
        source: "event_post",
        event_post_id: text(row.id),
        title: text(row.title) || "School moment",
        alt_text: text(object.alt_text ?? row.title) || "School gallery image",
        caption: text(row.body ?? row.description),
        media_url: mediaUrl,
        media_type: text(object.media_type ?? object.type) || "image",
        created_at: row.created_at,
      };
    })
    .filter((item) => item.media_url.length > 0);
}

export async function handleWebsitePublic(
  url: URL,
  svc: SupabaseClient,
): Promise<Response> {
  const school = text(url.searchParams.get("school_id"));
  if (!school) return fail("school_id is required", 400);
  const [
    { data: content, error: contentError },
    { data: gallery, error: galleryError },
    { data: eventPosts, error: eventPostsError },
    { data: sections, error: sectionsError },
    { data: entries, error: entriesError },
  ] = await Promise.all([
    svc.from("school_website_content").select(
      "hero_title, hero_body, mission_title, mission_body, updated_at",
    ).eq("school_id", school).maybeSingle(),
    svc.from("school_website_gallery_items").select(
      "id, title, alt_text, caption, media_path, sort_order, created_at",
    )
      .eq("school_id", school).eq("is_published", true).order("sort_order")
      .order("created_at", { ascending: false }),
    svc.from("event_posts").select(
      "id, title, body, description, media_urls, created_at",
    )
      .eq("school_id", school).in("status", ["approved", "published"])
      .contains("destinations", JSON.stringify(["SCHOOL_GALLERY"]))
      .order("created_at", { ascending: false }),
    svc.from("school_website_sections").select("section_key, title, body, image_url")
      .eq("status", "published").order("created_at"),
    svc.from("school_website_entries").select("id, entry_type, title, body, image_url, metadata, created_at")
      .eq("status", "published").in("entry_type", ["program", "news_event", "testimonial"])
      .order("created_at", { ascending: false }),
  ]);
  if (contentError) return fail(contentError.message);
  if (galleryError) return fail(galleryError.message);
  if (eventPostsError) return fail(eventPostsError.message);
  if (sectionsError) return fail(sectionsError.message);
  if (entriesError) return fail(entriesError.message);
  const publicGallery = (gallery ?? []).map((row) => galleryRow(svc, row));
  const mobileGallery = (eventPosts ?? []).flatMap((row) =>
    eventGalleryRows(row as Record<string, unknown>)
  );
  return ok({
    content: content ?? {},
    gallery: [...mobileGallery, ...publicGallery],
    sections: sections ?? [],
    entries: entries ?? [],
  });
}

export async function handleWebsiteEnquiry(req: Request, svc: SupabaseClient) {
  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  const name = text(body.name);
  const phone = text(body.phone);
  const email = text(body.email);
  if (!name || !phone || !email) return fail("name, phone, and email are required", 422);
  if (!/^\S+@\S+\.\S+$/.test(email)) return fail("valid email required", 422);
  const { data, error } = await svc.from("school_website_entries").insert({
    entry_type: "enquiry", title: name, body: text(body.message), status: "new",
    submitted_at: new Date().toISOString(),
    metadata: { phone, email, child_name: text(body.child_name), program: text(body.program) },
  }).select("id").single();
  return error ? fail(error.message) : ok({ id: data.id, message: "Thank you. Our admissions team will be in touch." });
}

export async function handleWebsite(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  if (!isPrincipal(user)) return fail("principal access required", 403);
  const school = schoolId(user);
  if (!school) return fail("school assignment is required", 403);
  const body = method === "GET" ||
      !req.headers.get("content-type")?.includes("application/json")
    ? {}
    : await req.json().catch(() => ({})) as Record<string, unknown>;

  if (path === "/website/content") {
    if (method === "GET") {
      const { data, error } = await svc.from("school_website_content").select(
        "*",
      ).eq("school_id", school).maybeSingle();
      return error ? fail(error.message) : ok(data ?? {});
    }
    if (method === "PUT") {
      const payload = {
        school_id: school,
        hero_title: text(body.hero_title),
        hero_body: text(body.hero_body),
        mission_title: text(body.mission_title),
        mission_body: text(body.mission_body),
        updated_by: user.id,
      };
      if (
        !payload.hero_title || !payload.hero_body || !payload.mission_title ||
        !payload.mission_body
      ) return fail("all website copy is required");
      const { data, error } = await svc.from("school_website_content").upsert(
        payload,
        { onConflict: "school_id" },
      ).select().single();
      return error ? fail(error.message) : ok(data);
    }
  }

  if (path === "/website/gallery" && method === "GET") {
    const { data, error } = await svc.from("school_website_gallery_items")
      .select("*").eq("school_id", school).order("sort_order").order(
        "created_at",
        { ascending: false },
      );
    return error
      ? fail(error.message)
      : ok((data ?? []).map((row) => galleryRow(svc, row)));
  }
  if (path === "/website/gallery/upload" && method === "POST") {
    const form = await req.formData().catch(() => null);
    const file = form?.get("file");
    if (!(file instanceof File) || !file.type.startsWith("image/")) {
      return fail("an image file is required");
    }
    if (file.size > 10 * 1024 * 1024) {
      return fail("images must be 10 MB or smaller");
    }
    const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "-");
    const mediaPath = `${school}/${crypto.randomUUID()}-${safeName}`;
    const { error: uploadError } = await svc.storage.from(bucket).upload(
      mediaPath,
      file,
      { contentType: file.type, upsert: false },
    );
    if (uploadError) return fail(uploadError.message);
    const { data, error } = await svc.from("school_website_gallery_items")
      .insert({
        school_id: school,
        media_path: mediaPath,
        title: text(form?.get("title")),
        alt_text: text(form?.get("alt_text")),
        caption: text(form?.get("caption")),
        sort_order: Number(form?.get("sort_order") ?? 0) || 0,
        is_published: form?.get("is_published") === "true",
        created_by: user.id,
      }).select().single();
    if (error) {
      await svc.storage.from(bucket).remove([mediaPath]);
      return fail(error.message);
    }
    return ok(galleryRow(svc, data));
  }

  const match = path.match(/^\/website\/gallery\/([^/]+)$/);
  if (match && method === "PUT") {
    const patch = {
      title: text(body.title),
      alt_text: text(body.alt_text),
      caption: text(body.caption),
      sort_order: Number(body.sort_order) || 0,
      is_published: Boolean(body.is_published),
    };
    const { data, error } = await svc.from("school_website_gallery_items")
      .update(patch).eq("id", match[1]).eq("school_id", school).select()
      .single();
    return error ? fail(error.message) : ok(galleryRow(svc, data));
  }
  if (match && method === "DELETE") {
    const { data: existing, error: lookupError } = await svc.from(
      "school_website_gallery_items",
    ).select("media_path").eq("id", match[1]).eq("school_id", school)
      .maybeSingle();
    if (lookupError || !existing) {
      return fail(lookupError?.message ?? "gallery item not found", 404);
    }
    const { error } = await svc.from("school_website_gallery_items").delete()
      .eq("id", match[1]).eq("school_id", school);
    if (error) return fail(error.message);
    await svc.storage.from(bucket).remove([existing.media_path]);
    return ok({ deleted: true });
  }
  return fail("not found", 404);
}

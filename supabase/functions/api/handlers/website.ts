import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, triggerPushProcessing } from "../index.ts";
import {
  deleteR2File,
  legacyStorageWritesEnabled,
  publicR2FileUrl,
  publicR2FileReference,
  uploadPublicToR2,
} from "../lib/r2_storage.ts";

const bucket = "school-public-media";
const text = (value: unknown) => typeof value === "string" ? value.trim() : "";
const schoolId = (user: User) => text(user.app_metadata?.school_id);
const isPrincipal = (user: User) =>
  text(user.app_metadata?.role_name).toLowerCase() === "principal";
const isLeader = (user: User) =>
  ["principal", "coordinator"].includes(text(user.app_metadata?.role_name).toLowerCase());
const programs = ["Daycare", "Playgroup", "Nursery", "PP1", "PP2"];

function publicUrl(svc: SupabaseClient, path: string) {
  const r2Url = publicR2FileUrl(path);
  if (r2Url) return r2Url;
  return svc.storage.from(bucket).getPublicUrl(path).data.publicUrl;
}

function galleryRow(svc: SupabaseClient, row: Record<string, unknown>) {
  return { ...row, media_url: publicUrl(svc, text(row.media_path)) };
}

function eventMediaItems(value: unknown): unknown[] {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object") return [value];
  if (typeof value !== "string") return [];
  const source = value.trim();
  if (!source) return [];
  if (source.startsWith("[") || source.startsWith("{")) {
    try {
      const decoded = JSON.parse(source);
      if (Array.isArray(decoded)) return decoded;
      if (decoded && typeof decoded === "object") return [decoded];
    } catch {
      // Continue with the legacy comma-separated URL format below.
    }
  }
  return source.split(/,(?=\s*(?:https?:\/\/|\/))/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function eventGalleryRows(row: Record<string, unknown>) {
  const media = eventMediaItems(row.media_urls);
  return media
    .map((item, index) => {
      const object = item !== null && typeof item === "object"
        ? item as Record<string, unknown>
        : {};
      const storedMedia = typeof item === "string"
        ? item.trim()
        : text(object.url ?? object.media_url ?? object.mediaUrl ?? object.secure_url);
      const mediaUrl = publicR2FileUrl(storedMedia) ||
        (storedMedia.startsWith("r2://") ? "" : storedMedia);
      return {
        id: `event:${text(row.id)}:${index}`,
        source: "event_post",
        event_post_id: text(row.id),
        title: text(row.title) || "School moment",
        alt_text: text(object.alt_text ?? row.title) || "School gallery image",
        caption: text(row.body ?? row.description),
        media_url: mediaUrl,
        media_type: text(
          object.media_type ?? object.mediaType ?? object.mime_type ??
            object.content_type ?? object.kind ?? object.type,
        ) || "image",
        public_gallery_visible: row.public_gallery_visible !== false,
        is_published: row.public_gallery_visible !== false,
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
      "hero_title, hero_body, mission_title, mission_body, breaking_news_text, breaking_news_enabled, updated_at",
    ).eq("school_id", school).maybeSingle(),
    svc.from("school_website_gallery_items").select(
      "id, title, alt_text, caption, media_path, media_type, sort_order, created_at",
    )
      .eq("school_id", school).eq("is_published", true).order("sort_order")
      .order("created_at", { ascending: false }),
    svc.from("event_posts").select(
      "id, title, body, media_urls, public_gallery_visible, created_at",
    )
      .eq("school_id", school).in("status", ["approved", "published"])
      .eq("public_gallery_visible", true)
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

export async function handleWebsiteEnquiry(req: Request, url: URL, svc: SupabaseClient) {
  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  const name = text(body.name);
  const phone = text(body.phone);
  const email = text(body.email);
  const school = text(url.searchParams.get("school_id"));
  const childAge = text(body.child_age);
  const program = text(body.program);
  if (!school) return fail("school_id is required", 422);
  if (!name || !phone || !email || !childAge || !program) return fail("name, phone, email, child age, and program are required", 422);
  if (!/^\S+@\S+\.\S+$/.test(email)) return fail("valid email required", 422);
  if (!programs.includes(program)) return fail("invalid program", 422);
  const { data, error } = await svc.from("admission_inquiries").insert({
    school_id: school, source: text(body.source) || "homepage", parent_name: name,
    phone, email, child_name: text(body.child_name), child_age: childAge, program,
    message: text(body.message),
  }).select("id").single();
  if (error) return fail(error.message);
  const { data: leaders } = await svc.from("users").select("id, role_name")
    .eq("school_id", school).eq("is_active", true).in("role_name", ["principal", "coordinator"]);
  for (const leader of leaders ?? []) {
    const title = "New admission inquiry";
    const message = `${name} enquired about ${program}.`;
    const { data: event } = await svc.from("notification_events").insert({
      school_id: school, user_id: leader.id, event_type: "admission_inquiry",
      event_data: { reference_type: "admission_inquiry", inquiry_id: data.id, message },
    }).select("id").maybeSingle();
    if (event?.id) triggerPushProcessing(event.id);
    await svc.from("notification_logs").insert({ school_id: school, user_id: leader.id,
      target_role: leader.role_name, title, body: message, type: "admission_inquiry",
      entity_type: "admission_inquiry", entity_id: data.id, is_read: false });
  }
  return ok({ id: data.id, message: "Thank you. Our admissions team will be in touch." });
}

export async function handleAdmissionInquiries(
  svc: SupabaseClient,
  user: User,
  url?: URL,
) {
  if (!isLeader(user)) return fail("leadership access required", 403);
  const school = schoolId(user);
  if (!school) return fail("school assignment is required", 403);
  const page = Math.max(parseInt(url?.searchParams.get("page") ?? "1") || 1, 1);
  const pageSize = Math.min(
    Math.max(parseInt(url?.searchParams.get("page_size") ?? "20") || 20, 1),
    100,
  );
  let query = svc.from("admission_inquiries").select("*", { count: "exact" })
    .eq("school_id", school);
  const search = `${url?.searchParams.get("search") ?? ""}`.trim();
  if (search) {
    const escaped = search.replace(/[%(),]/g, " ").trim();
    if (escaped) {
      query = query.or(
        `parent_name.ilike.%${escaped}%,child_name.ilike.%${escaped}%,phone.ilike.%${escaped}%,email.ilike.%${escaped}%`,
      );
    }
  }
  const { data, error, count } = await query.order("submitted_at", {
    ascending: false,
  }).order("id", { ascending: false }).range(
    (page - 1) * pageSize,
    page * pageSize - 1,
  );
  if (error) return fail(error.message);
  const total = count ?? data?.length ?? 0;
  return ok({
    data: data ?? [],
    total,
    page,
    page_size: pageSize,
    has_more: page * pageSize < total,
  });
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
  const school = schoolId(user);
  if (!school) return fail("school assignment is required", 403);
  const body = method === "GET" ||
      !req.headers.get("content-type")?.includes("application/json")
    ? {}
    : await req.json().catch(() => ({})) as Record<string, unknown>;

  // Coordinators may manage only the public ticker; homepage copy and gallery
  // remain principal-controlled.
  if (path === "/website/ticker") {
    if (!isLeader(user)) return fail("leadership access required", 403);
    if (method === "GET") {
      const { data, error } = await svc.from("school_website_content").select(
        "breaking_news_text, breaking_news_enabled, updated_at",
      ).eq("school_id", school).maybeSingle();
      return error ? fail(error.message) : ok(data ?? {});
    }
    if (method === "PUT") {
      const breakingNewsText = text(body.breaking_news_text);
      const breakingNewsEnabled = body.breaking_news_enabled === true;
      if (breakingNewsText.length > 240) return fail("breaking news text must be 240 characters or fewer", 422);
      if (breakingNewsEnabled && !breakingNewsText) return fail("breaking news text is required when the ticker is enabled", 422);
      const { data, error } = await svc.from("school_website_content").upsert({
        school_id: school,
        breaking_news_text: breakingNewsText,
        breaking_news_enabled: breakingNewsEnabled,
        updated_by: user.id,
      }, { onConflict: "school_id" }).select(
        "breaking_news_text, breaking_news_enabled, updated_at",
      ).single();
      return error ? fail(error.message) : ok(data);
    }
  }

  if (!isPrincipal(user)) return fail("principal access required", 403);

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
    const [galleryResult, eventResult] = await Promise.all([
      svc.from("school_website_gallery_items").select("*").eq(
        "school_id",
        school,
      ).order("sort_order").order("created_at", { ascending: false }),
      svc.from("event_posts").select(
        "id, title, body, media_urls, public_gallery_visible, status, destinations, created_at",
      ).eq("school_id", school).in("status", ["approved", "published"])
        .order("created_at", { ascending: false }),
    ]);
    if (galleryResult.error) return fail(galleryResult.error.message);
    if (eventResult.error) return fail(eventResult.error.message);
    const managedMedia = (galleryResult.data ?? []).map((row) =>
      galleryRow(svc, row)
    );
    const selectedEventMedia = (eventResult.data ?? []).flatMap((row) =>
      eventGalleryRows(row as Record<string, unknown>).map((media) => ({
        ...media,
        is_published: row.public_gallery_visible !== false,
        public_gallery_visible: row.public_gallery_visible !== false,
        status: text(row.status),
        destinations: row.destinations ?? [],
      }))
    );
    return ok([...selectedEventMedia, ...managedMedia]);
  }
  if (path === "/website/gallery/upload" && method === "POST") {
    const form = await req.formData().catch(() => null);
    const file = form?.get("file");
    const allowedMedia = file instanceof File && (
      file.type.startsWith("image/") || ["video/mp4", "video/webm", "video/quicktime"].includes(file.type)
    );
    if (!allowedMedia || !(file instanceof File)) {
      return fail("an image or MP4, WebM, or MOV video is required");
    }
    if (file.size > (file.type.startsWith("video/") ? 50 : 10) * 1024 * 1024) {
      return fail(file.type.startsWith("video/") ? "videos must be 50 MB or smaller" : "images must be 10 MB or smaller");
    }
    const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "-");
    const mediaKey = `website-gallery/${school}/${crypto.randomUUID()}-${safeName}`;
    const r2Upload = await uploadPublicToR2(mediaKey, file, file.type);
    const mediaPath = r2Upload
      ? publicR2FileReference(r2Upload.key)
      : `${school}/${crypto.randomUUID()}-${safeName}`;
    if (!r2Upload) {
      if (!legacyStorageWritesEnabled()) {
        return fail("R2 public storage is unavailable; legacy storage writes are disabled", 503);
      }
      const { error: uploadError } = await svc.storage.from(bucket).upload(
        mediaPath,
        file,
        {
          contentType: file.type,
          cacheControl: "31536000",
          upsert: false,
        },
      );
      if (uploadError) return fail(uploadError.message);
    }
    const { data, error } = await svc.from("school_website_gallery_items")
      .insert({
        school_id: school,
        media_path: mediaPath,
        title: text(form?.get("title")),
        alt_text: text(form?.get("alt_text")),
        caption: text(form?.get("caption")),
        media_type: file.type,
        sort_order: Number(form?.get("sort_order") ?? 0) || 0,
        is_published: form?.has("is_published")
          ? form.get("is_published") === "true"
          : true,
        created_by: user.id,
    }).select().single();
    if (error) {
      if (r2Upload) await deleteR2File(mediaPath);
      else await svc.storage.from(bucket).remove([mediaPath]);
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
    if (publicR2FileUrl(existing.media_path)) {
      await deleteR2File(existing.media_path);
    } else {
      await svc.storage.from(bucket).remove([existing.media_path]);
    }
    return ok({ deleted: true });
  }
  return fail("not found", 404);
}

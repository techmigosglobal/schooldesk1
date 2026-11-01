import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, triggerPushProcessing } from "../index.ts";
import {
  copyR2File,
  deleteR2File,
  legacyR2Reference,
  legacyStorageWritesEnabled,
  publicR2FileReference,
  publicR2FileUrl,
  r2ReferenceInfo,
  uploadPublicToR2,
} from "../lib/r2_storage.ts";
import {
  deleteStoredObject,
  storageLocationFromValue,
} from "../storage_helpers.ts";

const bucket = "school-public-media";
const text = (value: unknown) => typeof value === "string" ? value.trim() : "";
const schoolId = (user: User) => text(user.app_metadata?.school_id);
const isLeader = (user: User) =>
  ["principal", "coordinator", "super_admin"].includes(
    text(user.app_metadata?.role_name).toLowerCase(),
  );
const programs = ["Daycare", "Playgroup", "Nursery", "PP1", "PP2"];

function migratedPublicUrl(path: unknown): string {
  const direct = publicR2FileUrl(path);
  if (direct) return direct;

  const legacy = legacyR2Reference(path, bucket);
  const migratedLegacy = publicR2FileUrl(legacy);
  if (migratedLegacy) return migratedLegacy;

  // The restored website rows use a bare school-public-media path. The
  // migration maps that bucket to the public website/ prefix, so derive the
  // same reference before falling back to Supabase Storage.
  const raw = text(path).replace(/^\/+/, "");
  if (!raw || /^https?:\/\//i.test(raw) || raw.startsWith("r2://")) return "";
  const normalized = raw.replace(/^school-public-media\//i, "");
  if (!normalized || normalized.split("/").includes("..")) return "";
  return publicR2FileUrl(publicR2FileReference(`website/${normalized}`));
}

function publicUrl(svc: SupabaseClient, path: string) {
  const r2Url = migratedPublicUrl(path);
  if (r2Url) return r2Url;
  return svc.storage.from(bucket).getPublicUrl(path).data.publicUrl;
}

function eventMediaValue(item: unknown): string {
  if (item && typeof item === "object") {
    const value = item as Record<string, unknown>;
    return text(
      value.storage_ref ?? value.storageRef ?? value.url ?? value.media_url ??
        value.mediaUrl,
    );
  }
  return text(item);
}

function eventMediaFileName(item: unknown, fallback: string): string {
  if (item && typeof item === "object") {
    const value = item as Record<string, unknown>;
    const name = text(value.name ?? value.filename ?? value.file_name);
    if (name) return name;
  }
  const raw = eventMediaValue(item).split("?")[0];
  return raw.split("/").pop() || fallback;
}

function eventMediaContentType(item: unknown): string {
  if (item && typeof item === "object") {
    const value = item as Record<string, unknown>;
    const mime = text(
      value.mime_type ?? value.mimeType ?? value.content_type ??
        value.media_type,
    );
    if (mime) return mime;
  }
  const name = eventMediaFileName(item, "media.bin").toLowerCase();
  if (name.endsWith(".png")) return "image/png";
  if (name.endsWith(".webp")) return "image/webp";
  if (name.endsWith(".gif")) return "image/gif";
  if (name.endsWith(".mp4")) return "video/mp4";
  if (name.endsWith(".webm")) return "video/webm";
  if (name.endsWith(".mov")) return "video/quicktime";
  return "image/jpeg";
}

function isStableExternalMediaUrl(value: string): boolean {
  if (!/^https?:\/\//i.test(value)) return false;
  if (/\/storage\/v1\/object\/(?:sign|authenticated)\//i.test(value)) {
    return false;
  }
  return !/(?:school-assets|school-private-files)/i.test(value);
}

async function downloadLegacyEventMedia(
  svc: SupabaseClient,
  value: string,
): Promise<Uint8Array | null> {
  const location = storageLocationFromValue(value, "school-assets");
  if (location) {
    const { data, error } = await svc.storage.from(location.bucket).download(
      location.path,
    );
    if (!error && data) return new Uint8Array(await data.arrayBuffer());
  }
  return null;
}

/**
 * Existing approved posts can predate the public-media promotion workflow.
 * Repair them lazily and idempotently when the public website reads them.
 * The response never falls back to a short-lived private signed URL.
 */
async function promotePublicEventMedia(
  svc: SupabaseClient,
  school: string,
  postId: string,
  rawMedia: unknown,
): Promise<unknown[]> {
  const media = eventMediaItems(rawMedia);
  const promoted: unknown[] = [];
  for (let index = 0; index < media.length; index++) {
    const item = media[index];
    const stored = eventMediaValue(item);
    if (!stored) continue;
    if (isStableExternalMediaUrl(stored)) {
      promoted.push(item);
      continue;
    }

    const existing = r2ReferenceInfo(stored);
    const location = storageLocationFromValue(stored, "school-assets");
    let destination = "";
    if (
      existing?.visibility === "public" ||
      location?.bucket === "schooldesk-public-media" ||
      location?.bucket === "school-public-media"
    ) {
      destination = stored;
    } else {
      const fileName = eventMediaFileName(item, `media-${index}.bin`)
        .replace(/[^a-zA-Z0-9._-]/g, "-");
      const destinationKey =
        `event-posts/${school}/${postId}/${index}-${fileName}`;
      if (existing?.visibility === "private" && !location) {
        const copied = await copyR2File(stored, destinationKey, "public");
        if (copied) destination = copied.reference;
      }
      if (!destination) {
        const bytes = await downloadLegacyEventMedia(svc, stored);
        if (!bytes) continue;
        const uploaded = await uploadPublicToR2(
          destinationKey,
          bytes,
          eventMediaContentType(item),
        );
        if (uploaded) {
          destination = uploaded.reference;
        } else {
          const { error } = await svc.storage.from("schooldesk-public-media")
            .upload(destinationKey, bytes, {
              contentType: eventMediaContentType(item),
              cacheControl: "31536000",
              upsert: true,
            });
          if (!error) destination = `schooldesk-public-media/${destinationKey}`;
        }
      }
    }
    if (!destination) continue;
    if (item && typeof item === "object") {
      promoted.push({
        ...(item as Record<string, unknown>),
        url: destination,
        storage_ref: destination,
      });
    } else {
      promoted.push({ url: destination, storage_ref: destination });
    }
  }
  return promoted;
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

async function eventGalleryRows(
  svc: SupabaseClient,
  row: Record<string, unknown>,
) {
  const media = eventMediaItems(row.media_urls);
  const rows = await Promise.all(media.map(async (item, index) => {
    const object = item !== null && typeof item === "object"
      ? item as Record<string, unknown>
      : {};
    const storedMedia = typeof item === "string" ? item.trim() : text(
      object.url ?? object.media_url ?? object.mediaUrl ?? object.secure_url,
    );
    const mediaUrl = migratedPublicUrl(storedMedia) ||
      (isStableExternalMediaUrl(storedMedia) ? storedMedia : "");
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
  }));
  return rows.filter((item) => item.media_url.length > 0);
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
    svc.from("school_website_sections").select(
      "section_key, title, body, image_url",
    )
      .eq("status", "published").order("created_at"),
    svc.from("school_website_entries").select(
      "id, entry_type, title, body, image_url, metadata, created_at",
    )
      .eq("status", "published").in("entry_type", [
        "program",
        "news_event",
        "testimonial",
      ])
      .order("created_at", { ascending: false }),
  ]);
  if (contentError) return fail(contentError.message);
  if (galleryError) return fail(galleryError.message);
  if (eventPostsError) return fail(eventPostsError.message);
  if (sectionsError) return fail(sectionsError.message);
  if (entriesError) return fail(entriesError.message);
  const publicGallery = (gallery ?? []).map((row) => galleryRow(svc, row));
  const repairedEventPosts = await Promise.all(
    (eventPosts ?? []).map(async (row) => {
      const originalMedia = row.media_urls;
      let media: unknown[];
      try {
        media = await promotePublicEventMedia(
          svc,
          school,
          text(row.id),
          originalMedia,
        );
      } catch {
        // A single missing object must not take down the public website. Keep
        // the durable row untouched and omit its unusable media for this read.
        return { ...row, media_urls: [] };
      }
      if (JSON.stringify(media) !== JSON.stringify(originalMedia)) {
        // This is an idempotent repair for rows that were already marked
        // public before the promotion workflow existed. A failed update does
        // not make the public response unsafe; it simply remains repaired for
        // this request and will retry on the next read.
        await svc.from("event_posts").update({ media_urls: media })
          .eq("id", text(row.id)).eq("school_id", school);
      }
      return { ...row, media_urls: media };
    }),
  );
  const mobileGallery = (await Promise.all(
    repairedEventPosts.map((row) =>
      eventGalleryRows(svc, row as Record<string, unknown>)
    ),
  )).flat();
  return ok({
    content: content ?? {},
    gallery: [...mobileGallery, ...publicGallery],
    sections: (sections ?? []).map((row) => ({
      ...row,
      image_url: publicUrl(svc, text(row.image_url)),
    })),
    entries: (entries ?? []).map((row) => ({
      ...row,
      image_url: publicUrl(svc, text(row.image_url)),
    })),
  });
}

export async function handleWebsiteEnquiry(
  req: Request,
  url: URL,
  svc: SupabaseClient,
) {
  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  const name = text(body.name);
  const phone = text(body.phone);
  const email = text(body.email);
  const school = text(url.searchParams.get("school_id"));
  const childAge = text(body.child_age);
  const program = text(body.program);
  if (!school) return fail("school_id is required", 422);
  if (!name || !phone || !email || !childAge || !program) {
    return fail("name, phone, email, child age, and program are required", 422);
  }
  if (!/^\S+@\S+\.\S+$/.test(email)) return fail("valid email required", 422);
  if (!programs.includes(program)) return fail("invalid program", 422);
  const { data, error } = await svc.from("admission_inquiries").insert({
    school_id: school,
    source: text(body.source) || "homepage",
    parent_name: name,
    phone,
    email,
    child_name: text(body.child_name),
    child_age: childAge,
    program,
    message: text(body.message),
  }).select("id").single();
  if (error) return fail(error.message);
  const { data: leaders } = await svc.from("users").select("id, role_name")
    .eq("school_id", school).eq("is_active", true).in("role_name", [
      "principal",
      "coordinator",
    ]);
  for (const leader of leaders ?? []) {
    const title = "New admission inquiry";
    const message = `${name} enquired about ${program}.`;
    const { data: event } = await svc.from("notification_events").insert({
      school_id: school,
      user_id: leader.id,
      event_type: "admission_inquiry",
      event_data: {
        reference_type: "admission_inquiry",
        inquiry_id: data.id,
        message,
      },
    }).select("id").maybeSingle();
    if (event?.id) triggerPushProcessing(event.id);
    await svc.from("notification_logs").insert({
      school_id: school,
      user_id: leader.id,
      target_role: leader.role_name,
      title,
      body: message,
      type: "admission_inquiry",
      entity_type: "admission_inquiry",
      entity_id: data.id,
      is_read: false,
    });
  }
  return ok({
    id: data.id,
    message: "Thank you. Our admissions team will be in touch.",
  });
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
      if (breakingNewsText.length > 240) {
        return fail("breaking news text must be 240 characters or fewer", 422);
      }
      if (breakingNewsEnabled && !breakingNewsText) {
        return fail(
          "breaking news text is required when the ticker is enabled",
          422,
        );
      }
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

  if (!isLeader(user)) return fail("leadership access required", 403);

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
    const selectedEventMedia = (await Promise.all((eventResult.data ?? []).map(
      async (row) =>
        (await eventGalleryRows(svc, row as Record<string, unknown>)).map((
          media,
        ) => ({
          ...media,
          is_published: row.public_gallery_visible !== false,
          public_gallery_visible: row.public_gallery_visible !== false,
          status: text(row.status),
          destinations: row.destinations ?? [],
        })),
    ))).flat();
    return ok([...selectedEventMedia, ...managedMedia]);
  }
  if (path === "/website/gallery/upload" && method === "POST") {
    const form = await req.formData().catch(() => null);
    const file = form?.get("file");
    const allowedMedia = file instanceof File && (
      file.type.startsWith("image/") ||
      ["video/mp4", "video/webm", "video/quicktime"].includes(file.type)
    );
    if (!allowedMedia || !(file instanceof File)) {
      return fail("an image or MP4, WebM, or MOV video is required");
    }
    if (file.size > (file.type.startsWith("video/") ? 50 : 10) * 1024 * 1024) {
      return fail(
        file.type.startsWith("video/")
          ? "videos must be 50 MB or smaller"
          : "images must be 10 MB or smaller",
      );
    }
    const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "-");
    const mediaKey =
      `website-gallery/${school}/${crypto.randomUUID()}-${safeName}`;
    const r2Upload = await uploadPublicToR2(mediaKey, file, file.type);
    const mediaPath = r2Upload
      ? publicR2FileReference(r2Upload.key)
      : `${school}/${crypto.randomUUID()}-${safeName}`;
    if (!r2Upload) {
      if (!legacyStorageWritesEnabled()) {
        return fail(
          "R2 public storage is unavailable; legacy storage writes are disabled",
          503,
        );
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
    await deleteStoredObject(svc, existing.media_path, bucket);
    return ok({ deleted: true });
  }
  return fail("not found", 404);
}

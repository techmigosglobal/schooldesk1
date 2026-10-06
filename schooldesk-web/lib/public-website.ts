import { backendHeaders, configuredBackend } from "@/lib/backend";
import { env } from "@/lib/env";
import type { GalleryItem } from "@/lib/gallery";

export type { GalleryItem } from "@/lib/gallery";
export { isPublicGalleryImage, isPublicGalleryMedia, isPublicGalleryVideo, uniqueGalleryItems } from "@/lib/gallery";

export type PublicWebsite = {
  content?: Record<string, string | boolean>;
  gallery?: GalleryItem[];
  sections?: Array<{ section_key: string; title: string; body: string; image_url: string }>;
  entries?: Array<{ id: string; entry_type: "program" | "news_event" | "testimonial"; title: string; body: string; image_url: string; metadata?: Record<string, string>; created_at: string }>;
};

export function publicWebsiteMediaUrl(value: string, publicApiOrigin: string): string {
  try {
    const url = new URL(value);
    if (url.hostname !== "supabase-kong" || url.port !== "8000") return value;
    const publicOrigin = new URL(publicApiOrigin);
    url.protocol = publicOrigin.protocol;
    url.host = publicOrigin.host;
    url.port = publicOrigin.port;
    return url.toString();
  } catch {
    return value;
  }
}

export async function getPublicWebsite(): Promise<PublicWebsite> {
  const base = configuredBackend();
  const schoolId = env.SCHOOLDESK_PUBLIC_SCHOOL_ID;
  if (!base || !schoolId) return {};

  try {
    const response = await fetch(`${base}/website/public?school_id=${encodeURIComponent(schoolId)}`, {
      headers: backendHeaders(),
      next: { revalidate: 60, tags: ["school-public-website"] },
    });
    const body = await response.json();
    if (!body.success) return {};
    const data = body.data as PublicWebsite;
    const publicApiOrigin = new URL(base).origin;
    return {
      ...data,
      gallery: data.gallery?.map((item) => ({
        ...item,
        media_url: publicWebsiteMediaUrl(item.media_url, publicApiOrigin),
      })),
      sections: data.sections?.map((section) => ({
        ...section,
        image_url: publicWebsiteMediaUrl(section.image_url, publicApiOrigin),
      })),
      entries: data.entries?.map((entry) => ({
        ...entry,
        image_url: publicWebsiteMediaUrl(entry.image_url, publicApiOrigin),
      })),
    };
  } catch {
    return {};
  }
}

export const defaultWebsiteCopy = {
  hero_title: "Learn Today, Lead Tomorrow.",
  hero_body: "At Arish Ville Preschool, little learners are encouraged to explore, create, and grow with confidence.",
  mission_title: "Our Mission",
  mission_body: "To nurture curious, kind, and confident children through joyful early learning, meaningful experiences, and caring guidance.",
};

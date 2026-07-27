import { configuredBackend } from "@/lib/backend";
import { env } from "@/lib/env";
import type { GalleryItem } from "@/lib/gallery";

export type { GalleryItem } from "@/lib/gallery";
export { isPublicGalleryImage } from "@/lib/gallery";

export type PublicWebsite = {
  content?: Record<string, string | boolean>;
  gallery?: GalleryItem[];
  sections?: Array<{ section_key: string; title: string; body: string; image_url: string }>;
  entries?: Array<{ id: string; entry_type: "program" | "news_event" | "testimonial"; title: string; body: string; image_url: string; metadata?: Record<string, string>; created_at: string }>;
};

export async function getPublicWebsite(): Promise<PublicWebsite> {
  const base = configuredBackend();
  const schoolId = env.SCHOOLDESK_PUBLIC_SCHOOL_ID;
  if (!base || !schoolId) return {};

  try {
    const response = await fetch(`${base}/website/public?school_id=${encodeURIComponent(schoolId)}`, {
      next: { revalidate: 60, tags: ["school-public-website"] },
    });
    const body = await response.json();
    return body.success ? body.data : {};
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

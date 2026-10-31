import type { MetadataRoute } from "next";
import { absoluteUrl } from "@/lib/site";

export default function sitemap(): MetadataRoute.Sitemap {
  return ["/", "/about-us", "/our-mission", "/programs", "/admissions", "/campus-safety", "/gallery", "/contact", "/news-events"].map((path) => ({ url: absoluteUrl(path), changeFrequency: path === "/" || path === "/news-events" ? "weekly" : "monthly", priority: path === "/" ? 1 : 0.8 }));
}

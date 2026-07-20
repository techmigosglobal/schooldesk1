import type { MetadataRoute } from "next";
import { absoluteUrl } from "@/lib/site";

export default function sitemap(): MetadataRoute.Sitemap {
  return ["/", "/about-us", "/our-mission", "/gallery"].map((path) => ({ url: absoluteUrl(path), lastModified: new Date(), changeFrequency: path === "/" ? "weekly" : "monthly", priority: path === "/" ? 1 : 0.8 }));
}

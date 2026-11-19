import { env } from "@/lib/env";

export const siteName = "Arish Ville Preschool";
export const siteAliases = ["ArishVille", "arishville", "Arish Ville", "arish ville", "Arishville Preschool"];
export const siteDescription = "Arish Ville (ArishVille) Preschool in Miyapur, Hyderabad offers Daycare, Playgroup, Nursery, PP1 and PP2 in a caring, play-led learning environment.";

export function canonicalSiteUrl(configured: string) {
  const url = new URL(configured);
  // The Vercel deployment alias must never replace the school's public domain.
  return url.hostname.endsWith(".vercel.app") ||
      url.hostname.toLowerCase() === "www.arishville.com"
    ? "https://arishville.com"
    : url.origin;
}

export const siteUrl = canonicalSiteUrl(env.NEXT_PUBLIC_SITE_URL);

export function absoluteUrl(path = "/") {
  return new URL(path, `${siteUrl}/`).toString();
}

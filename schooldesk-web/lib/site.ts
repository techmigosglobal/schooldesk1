export const siteName = "ArishVille Preschool";
export const siteDescription = "A joyful, play-led preschool where little learners explore, create, build confidence, and grow together.";
export const siteUrl = (process.env.NEXT_PUBLIC_SITE_URL || "https://arishvillepreschool.com").replace(/\/$/, "");

export function absoluteUrl(path = "/") {
  return new URL(path, `${siteUrl}/`).toString();
}

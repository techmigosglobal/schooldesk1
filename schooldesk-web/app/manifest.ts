import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return { name: "Arish Ville Preschool", short_name: "Arish Ville", description: "Arish Ville Preschool public website", start_url: "/", display: "browser", background_color: "#f8fbfe", theme_color: "#0b2f5b", icons: [{ src: "/branding/arishville-logo.png", sizes: "any", type: "image/png" }] };
}

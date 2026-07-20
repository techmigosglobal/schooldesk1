import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return { name: "ArishVille Preschool", short_name: "ArishVille", description: "ArishVille Preschool public website", start_url: "/", display: "browser", background_color: "#f8fbf5", theme_color: "#075591", icons: [{ src: "/branding/arishville-logo.png", sizes: "any", type: "image/png" }] };
}

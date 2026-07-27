import { PublicPage } from "@/components/public-site";
import type { Metadata } from "next";
import { getPublicWebsite, isPublicGalleryImage } from "@/lib/public-website";

export const metadata: Metadata = { title: "School Gallery", description: "A curated visual archive of play, discovery, creativity, and everyday learning at ArishVille Preschool in Miyapur.", alternates: { canonical: "/gallery" } };

export default async function GalleryPage() {
  const gallery = ((await getPublicWebsite()).gallery ?? []).filter(isPublicGalleryImage);
  return <PublicPage>
    <section className="page-hero compact"><p className="eyebrow">ArishVille in moments</p><h1>School Gallery</h1><p>A visual archive of hands-on learning, creativity, and everyday joy. For announcements, event dates, and recaps, see News &amp; Events.</p></section>
    <section className="content-section"><div className="gallery-grid gallery-full">{gallery.length ? gallery.map((item) => {
      return <figure className="gallery-card" key={item.id}>
        <img className="gallery-media" src={item.media_url} alt={item.alt_text || item.title || "School gallery moment"} loading="lazy"/>
        <figcaption><b>{item.title || "ArishVille moment"}</b>{item.caption && <span>{item.caption}</span>}</figcaption>
      </figure>;
    }) : <div className="empty-gallery">The school is preparing its first curated gallery moments. Please check back soon.</div>}</div></section>
  </PublicPage>;
}

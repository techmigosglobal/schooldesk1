import { PublicPage } from "@/components/public-site";
import type { Metadata } from "next";
import { getPublicWebsite, isPublicGalleryImage } from "@/lib/public-website";
import { uniqueGalleryItems } from "@/lib/gallery";

export const metadata: Metadata = { title: "School Gallery", description: "A curated visual archive of play, discovery, creativity, and everyday learning at Arish Ville Preschool in Miyapur.", alternates: { canonical: "/gallery" } };

export default async function GalleryPage() {
  const managedGallery = ((await getPublicWebsite()).gallery ?? []).filter(isPublicGalleryImage);
  const gallery = uniqueGalleryItems(managedGallery);
  return <PublicPage>
    <section className="page-hero compact"><p className="eyebrow">Arish Ville in moments</p><h1>School Gallery</h1><p>A visual archive of hands-on learning, creativity, and everyday joy. For announcements, event dates, and recaps, see News &amp; Events.</p></section>
    <section className="content-section"><div className="gallery-grid gallery-full">{gallery.length ? gallery.map((item) => {
      return <figure className="gallery-card" key={`${item.id}-${item.media_url}`}>
        <img className="gallery-media" src={item.media_url} alt={item.alt_text || item.title || "School gallery moment"} loading="lazy" decoding="async"/>
        <figcaption><b>{item.title || "Arish Ville moment"}</b>{item.caption && <span>{item.caption}</span>}</figcaption>
      </figure>;
    }) : <p className="empty-gallery">No school moments have been selected for the public gallery yet.</p>}</div></section>
  </PublicPage>;
}

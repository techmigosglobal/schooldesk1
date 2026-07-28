import { PublicPage } from "@/components/public-site";
import type { Metadata } from "next";
import { getPublicWebsite, isPublicGalleryMedia } from "@/lib/public-website";
import { isPublicGalleryVideo, preschoolPhotography, uniqueGalleryItems } from "@/lib/gallery";

export const metadata: Metadata = { title: "School Gallery", description: "A curated visual archive of play, discovery, creativity, and everyday learning at ArishVille Preschool in Miyapur.", alternates: { canonical: "/gallery" } };

export default async function GalleryPage() {
  const managedGallery = ((await getPublicWebsite()).gallery ?? []).filter(isPublicGalleryMedia);
  const gallery = uniqueGalleryItems([...preschoolPhotography, ...managedGallery]);
  return <PublicPage>
    <section className="page-hero compact"><p className="eyebrow">ArishVille in moments</p><h1>School Gallery</h1><p>A visual archive of hands-on learning, creativity, and everyday joy. For announcements, event dates, and recaps, see News &amp; Events.</p></section>
    <section className="content-section"><div className="gallery-grid gallery-full">{gallery.map((item) => {
      return <figure className="gallery-card" key={`${item.id}-${item.media_url}`}>
        {isPublicGalleryVideo(item) ? <video className="gallery-media" controls preload="metadata" playsInline aria-label={item.alt_text || item.title || "School gallery video"}><source src={item.media_url} type={item.media_type || "video/mp4"} /></video> : <img className="gallery-media" src={item.media_url} alt={item.alt_text || item.title || "School gallery moment"} loading="lazy" decoding="async"/>}
        <figcaption><b>{item.title || "ArishVille moment"}</b>{item.caption && <span>{item.caption}</span>}</figcaption>
      </figure>;
    })}</div></section>
  </PublicPage>;
}

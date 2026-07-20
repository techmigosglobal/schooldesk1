import { PublicPage } from "@/components/public-site";
import type { Metadata } from "next";
import { getPublicWebsite } from "@/lib/public-website";

export const metadata: Metadata = { title: "School Gallery", description: "Explore curated moments of play, discovery, creativity, and everyday joy at ArishVille Preschool.", alternates: { canonical: "/gallery" } };

export default async function GalleryPage() {
  const gallery = (await getPublicWebsite()).gallery ?? [];
  return <PublicPage>
    <section className="page-hero compact"><p className="eyebrow">ArishVille in moments</p><h1>School Gallery</h1><p>A curated view of the hands-on learning, creativity, and everyday joy that make up life at ArishVille Preschool.</p></section>
    <section className="content-section"><div className="gallery-grid gallery-full">{gallery.length ? gallery.map((item) => <figure className="gallery-card" key={item.id} style={{ backgroundImage: `linear-gradient(0deg,rgba(10,44,62,.65),transparent 70%),url(${item.media_url})` }}><figcaption><b>{item.title || "ArishVille moment"}</b>{item.caption && <span>{item.caption}</span>}</figcaption></figure>) : <div className="empty-gallery">The school is preparing its first curated gallery moments. Please check back soon.</div>}</div></section>
  </PublicPage>;
}

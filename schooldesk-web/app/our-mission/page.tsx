import Link from "next/link";
import type { Metadata } from "next";
import { PublicPage } from "@/components/public-site";
import { defaultWebsiteCopy, getPublicWebsite } from "@/lib/public-website";
import { publicMetadata } from "@/lib/seo";

const description = "Learn how Arish Ville Preschool nurtures joyful discovery, kind confidence, and a strong partnership with families in Miyapur, Hyderabad.";
export const metadata: Metadata = publicMetadata({ title: "Our Mission", description, path: "/our-mission", keywords: ["Arish Ville mission", "play-based preschool values"] });

export default async function MissionPage() {
  const content = (await getPublicWebsite()).content ?? {};
  return <PublicPage schema={{ name: "Our Mission at Arish Ville Preschool", description, path: "/our-mission" }}>
    <section className="page-hero"><p className="eyebrow">Our purpose</p><h1>{content.mission_title || defaultWebsiteCopy.mission_title}</h1><p>{content.mission_body || defaultWebsiteCopy.mission_body}</p></section>
    <section className="content-section values-grid">
      <article><span>01</span><h2>Joyful discovery</h2><p>Children learn best when they are free to wonder, play, and ask questions in a safe, welcoming environment.</p></article>
      <article><span>02</span><h2>Kind confidence</h2><p>We make room for every child to build independence, express themselves, and learn with care for others.</p></article>
      <article><span>03</span><h2>Growing together</h2><p>Families and educators work together to give each child a strong and happy start to their learning journey.</p></article>
    </section>
    <section className="callout"><div><p className="eyebrow">Arish Ville Preschool</p><h2>Small steps today. Bright possibilities tomorrow.</h2></div><Link className="primary-button" href="/gallery">See school moments</Link></section>
  </PublicPage>;
}

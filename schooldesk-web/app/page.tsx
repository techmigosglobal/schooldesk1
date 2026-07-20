import Link from "next/link";
import type { Metadata } from "next";
import { DayExplorer, HomeHero } from "@/components/home-experience";
import { PublicPage } from "@/components/public-site";
import { Reveal } from "@/components/reveal";
import { defaultWebsiteCopy, getPublicWebsite } from "@/lib/public-website";

export const metadata: Metadata = { title: "Play-led Preschool for Little Learners", description: "Discover ArishVille Preschool: a joyful, caring place for children to explore, create, make friends, and grow with confidence.", alternates: { canonical: "/" } };

export default async function HomePage() {
  const site = await getPublicWebsite();
  const content = site.content ?? {};
  const gallery = site.gallery ?? [];
  return <PublicPage>
    <HomeHero heroTitle={content.hero_title || defaultWebsiteCopy.hero_title} heroBody={content.hero_body || defaultWebsiteCopy.hero_body} />
    <section className="parent-promise"><p>For curious little minds</p><div className="promise-track"><span>Play-led learning</span><span>Warm, caring guidance</span><span>Happy first friendships</span><span>Family partnership</span><span aria-hidden>Play-led learning</span><span aria-hidden>Warm, caring guidance</span></div></section>
    <Reveal><section className="about-preview"><div className="about-art" aria-hidden><span>☀</span><i>✦</i><b>♡</b></div><div><p className="eyebrow">A joyful first step</p><h2>Childhood should feel full of wonder.</h2><p>ArishVille is a preschool place for children to be themselves, build confidence, and fall in love with learning through the everyday magic of play.</p><Link className="text-link" href="/about-us">Discover our story <span aria-hidden>→</span></Link></div></section></Reveal>
    <DayExplorer />
    <Reveal><section className="learning-path"><div className="section-heading"><div><p className="eyebrow">Learning that feels like play</p><h2>So many ways to bloom.</h2></div></div><div className="path-grid"><article><span>01</span><h3>Imagine</h3><p>Stories, role play, music, and art help every child find their voice.</p></article><article><span>02</span><h3>Discover</h3><p>Hands-on activities encourage children to notice, question, test, and try.</p></article><article><span>03</span><h3>Belong</h3><p>Daily routines and gentle guidance grow confidence, kindness, and friendships.</p></article></div></section></Reveal>
    <Reveal><section className="mission home-mission"><div className="mission-copy"><div className="mission-icon" aria-hidden>✦</div><div><h2>{content.mission_title || defaultWebsiteCopy.mission_title}</h2><p>{content.mission_body || defaultWebsiteCopy.mission_body}</p></div></div><Link className="text-link" href="/our-mission">Read our mission <span aria-hidden>→</span></Link></section></Reveal>
    <Reveal><section className="gallery"><div className="section-heading"><div><p className="eyebrow">A glimpse of our days</p><h2>School Gallery</h2></div><Link className="section-link" href="/gallery">View all moments <span aria-hidden>→</span></Link></div><div className="gallery-grid">{gallery.length ? gallery.slice(0, 5).map((item) => <article className="gallery-card" key={item.id} style={{ backgroundImage: `linear-gradient(0deg,rgba(10,44,62,.65),transparent 70%),url(${item.media_url})` }} aria-label={item.alt_text || item.title}><span>{item.title || item.caption}</span></article>) : <div className="empty-gallery">Our curated school moments will be shared here as they are published.</div>}</div></section></Reveal>
    <Reveal><section className="home-cta"><div><p className="eyebrow">Begin the ArishVille journey</p><h2>Where small beginnings lead to bright tomorrows.</h2><p>We would love to welcome your family to the ArishVille community.</p></div><Link className="primary-button" href="/about-us">Why families choose us <span aria-hidden>→</span></Link></section></Reveal>
  </PublicPage>;
}

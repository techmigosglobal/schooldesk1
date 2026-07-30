import Link from "next/link";
import type { Metadata } from "next";
import { PublicPage } from "@/components/public-site";

export const metadata: Metadata = { title: "About Us", description: "Meet Arish Ville Preschool, a warm and playful early-learning community built for big beginnings.", alternates: { canonical: "/about-us" } };

export default function AboutUsPage() {
  return <PublicPage>
    <section className="page-hero about-hero"><p className="eyebrow">Welcome to Arish Ville</p><h1>A little world built for big beginnings.</h1><p>Arish Ville Preschool is a warm, happy place where children are encouraged to wonder, create, connect, and grow at their own beautiful pace.</p></section>
    <section className="about-story"><div><p className="eyebrow">Our story</p><h2>Growing confidence, one joyful day at a time.</h2><p>We believe the early years are a precious time: full of first questions, first friendships, and first proud “I did it!” moments. Our role is to make those moments feel safe, meaningful, and full of possibility.</p><p>With caring adults, playful learning experiences, and a strong partnership with families, we give children a gentle foundation for the school years ahead.</p></div><div className="story-art" aria-hidden><span>ABC</span><i>✦</i><b>☀</b></div></section>
    <section className="content-section values-grid"><article><span>01</span><h2>Children first</h2><p>We notice each child’s interests, celebrate their efforts, and make room for their unique way of learning.</p></article><article><span>02</span><h2>Play with purpose</h2><p>Purposeful play helps children explore early language, numeracy, creativity, movement, and social skills naturally.</p></article><article><span>03</span><h2>Families together</h2><p>Open, caring communication helps families feel connected to the learning and growth happening every day.</p></article></section>
    <section className="callout"><div><p className="eyebrow">A place to belong</p><h2>Ready for your child’s next little adventure?</h2></div><Link className="primary-button" href="/gallery">Step inside Arish Ville</Link></section>
  </PublicPage>;
}

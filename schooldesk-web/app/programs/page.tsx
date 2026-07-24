import type { Metadata } from "next";
import Link from "next/link";
import { PublicPage } from "@/components/public-site";

export const metadata: Metadata = { title: "Programs", description: "Early-years programs at Little Ville Preschool." };
const programs = [["Playgroup", "1.5 – 2.5 years", "A gentle beginning with sensory play, music, and warm routines."], ["Nursery", "2.5 – 3.5 years", "Stories, movement, friendship, and child-led exploration."], ["Junior KG", "3.5 – 4.5 years", "A playful foundation for language, numeracy, and independence."], ["Senior KG", "4.5 – 6 years", "Confident school readiness through meaningful everyday learning."]];
export default function ProgramsPage() { return <PublicPage><section className="page-hero compact"><p className="eyebrow">Our programs</p><h1>Every stage begins with wonder.</h1><p>Age-appropriate learning designed around a child’s curiosity, confidence, and joy.</p></section><section className="content-section values-grid">{programs.map(([name, age, copy]) => <article key={name}><span>{age}</span><h2>{name}</h2><p>{copy}</p></article>)}</section><section className="callout"><div><p className="eyebrow">Find the right fit</p><h2>Let’s talk about your child’s beautiful next step.</h2></div><Link className="primary-button" href="/admissions">Enquire now</Link></section></PublicPage>; }

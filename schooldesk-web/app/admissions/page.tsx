import type { Metadata } from "next";
import Link from "next/link";
import { PublicPage } from "@/components/public-site";
export const metadata: Metadata = { title: "Admissions", description: "Ask about preschool admissions, programs, and a campus visit at ArishVille Preschool in Miyapur, Hyderabad.", alternates: { canonical: "/admissions" } };
export default function AdmissionsPage() {
  const faqs = [
    ["Which preschool programs does ArishVille offer?", "ArishVille offers Daycare for ages 1.5–6, Playgroup for 2–3, Nursery for 3–4, PP1 for 4–5, and PP2 for 5–6 years."],
    ["How can I make an admissions enquiry?", "Use the admissions enquiry form to share your contact details, your child’s age, program of interest, and a message. The admissions team will respond personally."],
    ["Can our family visit the school?", "Yes. You can request a campus visit through the enquiry form or by contacting ArishVille Preschool in Miyapur, Hyderabad."],
  ];
  const faqSchema = { "@context": "https://schema.org", "@type": "FAQPage", mainEntity: faqs.map(([name, text]) => ({ "@type": "Question", name, acceptedAnswer: { "@type": "Answer", text } })) };
  return <PublicPage><script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }}/><section className="page-hero compact"><p className="eyebrow">Admissions</p><h1>A lovely first step starts here.</h1><p>We are here to make your family’s preschool journey clear, warm, and personal.</p></section><section className="content-section values-grid"><article><span>01</span><h2>Send an enquiry</h2><p>Tell us about your child and the program you are considering.</p></article><article><span>02</span><h2>Visit the campus</h2><p>Meet our team and see how our learning spaces feel in person.</p></article><article><span>03</span><h2>Begin together</h2><p>Our admissions team will guide you through the next steps.</p></article></section><section className="content-section values-grid" aria-labelledby="admissions-faq"><div style={{ gridColumn: "1 / -1" }}><p className="eyebrow">Admissions answers</p><h2 id="admissions-faq">Common family questions</h2></div>{faqs.map(([question, answer]) => <article key={question}><h3>{question}</h3><p>{answer}</p></article>)}</section><section className="callout"><div><p className="eyebrow">We’re ready to help</p><h2>Questions about admissions, age groups, or availability?</h2></div><Link className="primary-button" href="/contact">Contact admissions</Link></section></PublicPage>;
}

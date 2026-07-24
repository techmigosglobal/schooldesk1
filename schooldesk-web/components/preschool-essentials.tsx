"use client";

import { FormEvent, useEffect, useState } from "react";
import type { GalleryItem, PublicWebsite } from "@/lib/public-website";

const heroSlides = [
  { image: "/preschool/hero-garden.png", alt: "Children discovering nature together", title: "Where Curiosity Blossoms into", accent: "Confidence.", body: "At Little Ville, every child is valued, every moment is meaningful, and every day is an adventure in learning." },
  { image: "/preschool/hero-maker.png", alt: "Children enjoying a hands-on classroom activity", title: "Small Hands. Bright", accent: "Ideas.", body: "Joyful experiences, caring teachers, and playful learning help every child make a confident start." },
  { image: "/preschool/hero-music.png", alt: "Children making music outside", title: "A Happy Start to a", accent: "Lifelong Love of Learning.", body: "Music, movement, stories, and friendship make each school day something to look forward to." },
];

const fallbackPrograms = [
  ["Playgroup", "1.5 – 2.5 Years", "A joyful beginning with sensory play and gentle routines."],
  ["Nursery", "2.5 – 3.5 Years", "Building curiosity through play, stories, and exploration."],
  ["Junior KG", "3.5 – 4.5 Years", "Little learners take their first steps toward independence."],
  ["Senior KG", "4.5 – 6 Years", "Preparing confident children for a smooth school transition."],
  ["Enrichment Clubs", "3+ Years", "Music, movement, art, and more to spark every passion."],
];

type GooglePlace = { configured: boolean; name?: string; address?: string; rating?: number; userRatingCount?: number; googleMapsUri: string; reviews?: Array<{ author: string; rating?: number; text: string; relativeTime: string; photoUrl?: string }> };

function GoogleReviews() {
  const [place, setPlace] = useState<GooglePlace | null>(null);
  const [current, setCurrent] = useState(0);
  const [paused, setPaused] = useState(false);
  useEffect(() => { fetch("/api/google-place").then((response) => response.json()).then(setPlace).catch(() => setPlace({ configured: false, googleMapsUri: "https://www.google.com/search?q=Little+Ville+Miyapur" })); }, []);
  const reviews = place?.reviews ?? [];
  const review = reviews[current];
  const url = place?.googleMapsUri || "https://www.google.com/search?q=Little+Ville+Miyapur";
  useEffect(() => {
    if (paused || reviews.length < 2 || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const timer = window.setInterval(() => setCurrent((value) => (value + 1) % reviews.length), 3000);
    return () => window.clearInterval(timer);
  }, [paused, reviews.length]);
  const previous = () => setCurrent((value) => (value - 1 + reviews.length) % reviews.length);
  const next = () => setCurrent((value) => (value + 1) % reviews.length);
  return <div className="google-review-card" onMouseEnter={() => setPaused(true)} onMouseLeave={() => setPaused(false)} onFocus={() => setPaused(true)} onBlur={() => setPaused(false)}>
    <div className="google-review-heading"><span className="google-mark" aria-hidden>G</span><div><strong>Google Reviews</strong><p>{place?.rating ? <><b>{place.rating.toFixed(1)}</b> <span className="stars">★★★★★</span> · {place.userRatingCount ?? 0} reviews</> : "Verified family feedback on Google"}</p></div></div>
    {review ? <><blockquote key={current} className="review-copy">“{review.text}”</blockquote><div className="review-author">{review.photoUrl ? <img src={review.photoUrl} alt="" /> : <span>{review.author.slice(0, 1)}</span>}<div><b>{review.author}</b><small>{review.relativeTime || "Google review"}</small></div><div className="review-controls"><button type="button" aria-label="Previous Google review" onClick={previous}>‹</button><button type="button" aria-label="Next Google review" onClick={next}>›</button></div></div><div className="review-progress" aria-label={`${current + 1} of ${reviews.length} Google reviews`}><i style={{ width: `${((current + 1) / reviews.length) * 100}%` }} /></div></> : <p className="review-empty">Google reviews will appear here once the school’s approved Google Places connection is added.</p>}
    <a className="google-review-link" href={url} target="_blank" rel="noreferrer">Read all reviews on Google ↗</a>
  </div>;
}

export function PreschoolEssentials({ site }: { site: PublicWebsite }) {
  const [slide, setSlide] = useState(0); const [submitted, setSubmitted] = useState(false); const [sending, setSending] = useState(false);
  const programs = site.entries?.filter((entry) => entry.entry_type === "program") ?? [];
  const news = site.entries?.filter((entry) => entry.entry_type === "news_event") ?? [];
  const gallery = site.gallery?.slice(0, 6) ?? [];
  useEffect(() => { const timer = window.setInterval(() => setSlide((value) => (value + 1) % heroSlides.length), 6000); return () => window.clearInterval(timer); }, []);
  async function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); setSending(true); const form = new FormData(event.currentTarget); const response = await fetch("/api/backend/website/enquiries", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(Object.fromEntries(form)) }); setSending(false); setSubmitted(response.ok); }
  const currentSlide = heroSlides[slide];
  const galleryImages = gallery.length ? gallery.map((item: GalleryItem) => ({ src: item.media_url, alt: item.alt_text || item.title })) : heroSlides.concat(heroSlides).map((item) => ({ src: item.image, alt: item.alt }));
  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const observer = new IntersectionObserver((entries) => entries.forEach((entry) => { if (entry.isIntersecting) entry.target.classList.add("is-visible"); }), { threshold: .12 });
    const nodes = document.querySelectorAll(".reveal-on-scroll"); nodes.forEach((node) => observer.observe(node));
    return () => observer.disconnect();
  }, []);
  return <>
    <section className="preschool-hero" aria-label="Little Ville Preschool introduction">
      {heroSlides.map((item, index) => <img key={item.image} className={index === slide ? "is-active" : ""} src={item.image} alt={index === slide ? item.alt : ""} aria-hidden={index !== slide} />)}
      <div className="hero-wash" /><div className="hero-copy"><h1>{currentSlide.title} <em>{currentSlide.accent}</em></h1><p>{site.content?.hero_body || currentSlide.body}</p><div className="hero-actions"><a className="primary-button" href="#programs">Explore programs <span>→</span></a><a className="hero-outline-button" href="#enquire">Enquire now <span>→</span></a></div></div>
      <div className="hero-slider-controls"><button onClick={() => setSlide((slide + heroSlides.length - 1) % heroSlides.length)} aria-label="Previous hero image">‹</button>{heroSlides.map((item, index) => <button key={item.image} onClick={() => setSlide(index)} className={index === slide ? "active" : ""} aria-label={`Show slide ${index + 1}`} />)}<button onClick={() => setSlide((slide + 1) % heroSlides.length)} aria-label="Next hero image">›</button></div>
    </section>
    <section id="about" className="about-intro reveal-on-scroll"><p>Rooted in care. Made for discovery.</p><h2>A warm first school for confident little learners.</h2><span>Every child receives the attention, encouragement, and playful experiences they need to flourish.</span></section>
    <section id="programs" className="public-section program-section reveal-on-scroll"><h2>Our Programs <i>❧</i></h2><p className="section-intro">Thoughtfully designed programs that nurture every stage of early learning.</p><div className="preschool-programs">{(programs.length ? programs.slice(0, 5).map((item, index) => ({ id: item.id, title: item.title, age: fallbackPrograms[index]?.[1] || "Early years", body: item.body, image: item.image_url || heroSlides[index % heroSlides.length].image })) : fallbackPrograms.map(([title, age, body], index) => ({ id: title, title, age, body, image: heroSlides[index % heroSlides.length].image }))).map((program) => <article key={program.id}><img src={program.image} alt=""/><div className="program-label"><span>✦</span><div><h3>{program.title}</h3><small>{program.age}</small></div></div><p>{program.body}</p></article>)}</div></section>
    <section id="campus-safety" className="campus-section reveal-on-scroll"><div className="campus-copy"><p className="sr-only">A safe campus, every day.</p><h2>A Safe Campus.<br/><em>Every Day.</em></h2><p>Your child’s safety and well-being are our highest priority. Our campus is designed to be secure, welcoming, and child-friendly.</p><ul><li>CCTV monitored campus</li><li>Trained &amp; verified staff</li><li>Secure entry &amp; exit</li><li>Child-friendly infrastructure</li><li>Regular safety drills</li></ul></div><img src="/preschool/hero-garden.png" alt="Children learning in a safe, green preschool environment"/><aside><span>♢</span><p>Safety is not just our policy,<br/>our promise.</p><i>❧</i></aside></section>
    <section id="news-events" className="public-section news-review-section"><div className="news-column"><div className="section-heading-row"><h2>News &amp; Events <i>❧</i></h2><a href="/news-events">View all</a></div>{news.length ? news.slice(0, 3).map((entry, index) => <article className="news-row" key={entry.id}><img src={heroSlides[index].image} alt=""/><div><h3>{entry.title}</h3><small>{entry.created_at ? new Date(entry.created_at).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "School update"}</small><p>{entry.body}</p></div></article>) : ["Earth Day Celebration", "Storytelling Week", "Mini Sports Day"].map((title, index) => <article className="news-row" key={title}><img src={heroSlides[index].image} alt=""/><div><h3>{title}</h3><small>School update</small><p>Happy moments, creative learning, and experiences shared with our Little Ville families.</p></div></article>)}</div><div className="review-column"><h2>What Parents Say <i>❧</i></h2><GoogleReviews /></div></section>
    <section id="gallery" className="public-section gallery-section"><h2>Moments That Matter <i>❧</i></h2><div className="preschool-gallery">{galleryImages.map((item, index) => <img key={`${item.src}-${index}`} src={item.src} alt={item.alt}/>)}</div><a className="gallery-button" href="#enquire">Enquire for a campus visit <span>↗</span></a></section>
    <section id="enquire" className="enquiry-section"><div className="contact-details"><h2>We’d Love to Hear<br/>From You!</h2><p>Have questions or want to know more about Little Ville? We’re here to help.</p><address>⌖ &nbsp; Little Ville Preschool, Miyapur, Hyderabad<br/><br/>⌕ &nbsp; Contact the admissions team<br/><br/>✉ &nbsp; admissions@littlevillepreschool.com</address><div className="map-wrap"><iframe title="Little Ville Miyapur location" src="https://www.google.com/maps?q=Little+Ville+Miyapur&output=embed" loading="lazy" referrerPolicy="no-referrer-when-downgrade"/></div></div><form onSubmit={submit}><h2>Enquire Now</h2>{submitted ? <p className="enquiry-success">Thank you—our admissions team will be in touch.</p> : <><div className="form-grid"><input required name="name" placeholder="Parent Name"/><input required name="phone" placeholder="Phone Number"/><input required type="email" name="email" placeholder="Email Address"/><input name="child_name" placeholder="Child’s Name"/><select name="child_age" defaultValue=""><option value="" disabled>Child’s Age</option><option>Under 2 years</option><option>2–3 years</option><option>3–4 years</option><option>4–6 years</option></select><select name="program" defaultValue=""><option value="" disabled>Program of Interest</option>{fallbackPrograms.slice(0, 4).map(([title]) => <option key={title}>{title}</option>)}</select></div><textarea name="message" placeholder="Message" rows={4}/><button className="enquiry-submit" disabled={sending}>{sending ? "Sending…" : "Submit enquiry"} <span>→</span></button></>}</form></section>
  </>;
}

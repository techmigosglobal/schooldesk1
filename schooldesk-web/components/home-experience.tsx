"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

type HeroSlide = { eyebrow: string; title: string; body: string; link: string; action: string; theme: string };
const heroSlides: HeroSlide[] = [
  { eyebrow: "ArishVille Preschool", title: "Learn Today, Lead Tomorrow.", body: "At Arish Ville Preschool, little learners are encouraged to explore, create, and grow with confidence.", link: "/about-us", action: "Meet ArishVille", theme: "welcome" },
  { eyebrow: "Made for little wonders", title: "Every day begins with a happy hello.", body: "A warm, playful space where children can settle in, make friends, and feel proud of every new thing they try.", link: "/our-mission", action: "Our learning approach", theme: "wonder" },
  { eyebrow: "Growing together", title: "Small hands. Big imagination.", body: "Stories, songs, movement, art, and discovery come together to make early learning a joyful adventure.", link: "/gallery", action: "Explore school moments", theme: "imagine" },
];

export function HomeHero({ heroTitle, heroBody }: { heroTitle: string; heroBody: string }) {
  const [active, setActive] = useState(0); const [paused, setPaused] = useState(false);
  useEffect(() => { if (paused) return; const timer = window.setInterval(() => setActive((current) => (current + 1) % heroSlides.length), 6000); return () => window.clearInterval(timer); }, [paused]);
  const slide = active === 0 ? { ...heroSlides[0], title: heroTitle, body: heroBody } : heroSlides[active];
  const chooseSlide = (index: number) => { setActive(index); setPaused(true); };
  return <section className={`hero hero-${slide.theme}`} aria-roledescription="carousel" aria-label="ArishVille Preschool highlights" onMouseEnter={() => setPaused(true)} onMouseLeave={() => setPaused(false)}>
    <div className="hero-copy hero-copy-animated" key={slide.title} aria-live="polite"><p className="eyebrow">{slide.eyebrow}</p><h1>{slide.title}</h1><div className="hero-mark" /><p>{slide.body}</p><Link className="primary-button" href={slide.link}>{slide.action} <span aria-hidden>→</span></Link><div className="hero-controls" aria-label="Choose a highlight">{heroSlides.map((item, index) => <button key={item.theme} className={index === active ? "active" : ""} onClick={() => chooseSlide(index)} aria-label={`Show slide ${index + 1}`} aria-current={index === active ? "true" : undefined} />)}<button className="hero-pause" onClick={() => setPaused((value) => !value)} aria-label={paused ? "Resume automatic slides" : "Pause automatic slides"}>{paused ? <span aria-hidden>Play</span> : <span aria-hidden>Pause</span>}</button></div><div className="hero-progress" aria-hidden><span key={`${active}-${paused}`} className={paused ? "paused" : ""}/></div></div>
    <div className="hero-media" aria-hidden><div className="hero-cloud cloud-one"/><div className="hero-cloud cloud-two"/><div className="hero-sun"/><div className="hero-doodle doodle-one">✦</div><div className="hero-doodle doodle-two">●</div><div className="hero-message"><b>Play. Learn. Bloom.</b><span>One wonderful day at a time.</span></div></div>
  </section>;
}

const moments = [
  { name: "Welcome circle", time: "A cheerful start", text: "Songs, stories, and friendly faces help children arrive feeling secure and ready for the day.", icon: "☀" },
  { name: "Explore & create", time: "Hands-on discovery", text: "Art, sensory play, language, and early number experiences turn curiosity into confident learning.", icon: "✦" },
  { name: "Move & make friends", time: "Growing together", text: "Movement, outdoor play, and shared routines build happy bodies, kind friendships, and independence.", icon: "♡" },
];

export function DayExplorer() {
  const [active, setActive] = useState(0);
  const moment = moments[active];
  return <section className="day-explorer" aria-label="A day at ArishVille"><div className="day-intro"><p className="eyebrow">A gentle rhythm for growing minds</p><h2>A day made for little learners.</h2><p>Every part of the day gives children a chance to feel safe, capable, and excited to discover what comes next.</p><div className="day-tabs" role="tablist" aria-label="Explore the school day">{moments.map((item, index) => <button role="tab" aria-selected={active === index} key={item.name} className={active === index ? "active" : ""} onClick={() => setActive(index)}>{item.name}</button>)}</div></div><article className="moment-card" key={moment.name}><span className="moment-icon" aria-hidden>{moment.icon}</span><p>{moment.time}</p><h3>{moment.name}</h3><span>{moment.text}</span></article></section>;
}

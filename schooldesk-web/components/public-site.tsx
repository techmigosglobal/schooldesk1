import Image from "next/image";
import Link from "next/link";
import type { ReactNode } from "react";

export function PublicHeader() {
  return <header className="public-nav">
    <Link className="brand-lockup" href="/" aria-label="Arish Ville Preschool home">
      <Image src="/branding/arishville-logo.png" alt="Arish Ville Preschool" width={64} height={64} priority />
      <span><b>ArishVille</b><small>Preschool</small></span>
    </Link>
    <nav aria-label="Public navigation">
      <Link href="/">Home</Link>
      <Link href="/about-us">About</Link>
      <Link href="/programs">Programs</Link>
      <Link href="/admissions">Admissions</Link>
      <Link href="/campus-safety">Campus &amp; Safety</Link>
      <Link href="/gallery">Gallery</Link>
      <Link href="/news-events">News &amp; Events</Link>
      <Link href="/contact">Contact</Link>
    </nav>
    <Link className="outline-button" href="/login">Staff login</Link>
  </header>;
}

export function PublicFooter() {
  return <footer className="site-footer">
    <div className="footer-main">
      <div className="footer-brand"><Image src="/branding/arishville-logo.png" alt="ArishVille Preschool" width={54} height={54}/><div><b>ArishVille Preschool</b><span>Learn Today, Lead Tomorrow.</span><p>A happy first home for curiosity, confidence, and friendship.</p></div></div>
      <nav className="footer-links" aria-label="Explore ArishVille"><b>Explore</b><Link href="/">Home</Link><Link href="/about-us">About</Link><Link href="/programs">Programs</Link><Link href="/admissions">Admissions &amp; Contact</Link><Link href="/gallery">School Gallery</Link></nav>
      <nav className="footer-links" aria-label="SchoolDesk access"><b>SchoolDesk</b><Link href="/login">Staff login</Link><Link href="/login/principal">Principal portal</Link><Link href="/login/coordinator">Coordinator portal</Link><a href="#top">Back to top ↑</a></nav>
    </div>
    <div className="footer-bottom"><span>© {new Date().getFullYear()} ArishVille Preschool. All rights reserved.</span><a className="managed-by" href="https://techmigos.com" target="_blank" rel="noreferrer" aria-label="Managed by Techmigos"><Image src="/branding/techmigos-logo.png" alt="" width={24} height={24}/><span>Managed by <b>Techmigos</b></span></a></div>
  </footer>;
}

export function PublicPage({ children }: { children: ReactNode }) {
  return <main id="top" className="public-site"><PublicHeader />{children}<PublicFooter /></main>;
}

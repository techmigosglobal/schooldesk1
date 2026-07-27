"use client";

import Image from "next/image";
import Link from "next/link";
import type { ReactNode } from "react";
import { usePathname } from "next/navigation";
import { BreakingNewsTicker } from "@/components/breaking-news-ticker";

const navigation = [
  ["/", "Home"], ["/about-us", "About"], ["/programs", "Programs"],
  ["/admissions", "Admissions"], ["/campus-safety", "Campus & Safety"],
  ["/gallery", "Gallery"], ["/news-events", "News & Events"], ["/contact", "Contact"],
] as const;

export function PublicHeader() {
  const pathname = usePathname();
  return <header className="public-nav">
    <Link className="brand-lockup" href="/" aria-label="Arish Ville Preschool home">
      <Image src="/branding/arishville-logo.png" alt="Arish Ville Preschool" width={64} height={64} priority />
      <span><b>ArishVille</b><small>Preschool</small></span>
    </Link>
    <nav aria-label="Primary navigation">
      {navigation.map(([href, label]) => <Link key={href} href={href} aria-current={pathname === href ? "page" : undefined}>{label}</Link>)}
    </nav>
    <div className="public-nav-actions">
    <details className="public-menu">
      <summary aria-label="Open site navigation">Menu <span aria-hidden="true">☰</span></summary>
      <nav aria-label="Mobile navigation">{navigation.map(([href, label]) => <Link key={href} href={href} aria-current={pathname === href ? "page" : undefined}>{label}</Link>)}</nav>
    </details>
    <Link className="outline-button staff-login-button" href="/login"><span>Staff login</span><b aria-hidden="true">→</b></Link>
    </div>
  </header>;
}

export function PublicFooter() {
  return <footer className="site-footer">
    <div className="footer-main">
      <div className="footer-brand"><Image src="/branding/arishville-logo.png" alt="ArishVille Preschool" width={54} height={54}/><div><b>ArishVille Preschool</b><span>Learn Today, Lead Tomorrow.</span><p>A happy first home for curiosity, confidence, and friendship.</p></div></div>
      <nav className="footer-links" aria-label="Explore ArishVille"><b>Explore</b><Link href="/">Home</Link><Link href="/about-us">About</Link><Link href="/programs">Programs</Link><Link href="/admissions">Admissions &amp; Contact</Link><Link href="/gallery">School Gallery</Link></nav>
      <nav className="footer-links" aria-label="SchoolDesk access"><b>SchoolDesk</b><Link href="/login">Staff login</Link><Link href="/login/principal">Principal portal</Link><Link href="/login/coordinator">Coordinator portal</Link><a href="#top">Back to top ↑</a></nav>
    </div>
    <div className="footer-bottom"><span>© {new Date().getFullYear()} ArishVille Preschool. All rights reserved.</span><a className="managed-by" href="https://techmigos.com" target="_blank" rel="noreferrer" aria-label="Developed and managed by Techmigos"><Image src="/branding/techmigos-logo.png" alt="" width={24} height={24} style={{ width: "auto", height: "auto" }}/><span>Developed &amp; managed by <b>Techmigos</b><i aria-hidden="true">↗</i></span></a></div>
  </footer>;
}

export function PublicPage({ children, showBreakingNews = false }: { children: ReactNode; showBreakingNews?: boolean }) {
  return <main id="top" className="public-site"><PublicHeader />{showBreakingNews && <BreakingNewsTicker />}{children}<PublicFooter /></main>;
}

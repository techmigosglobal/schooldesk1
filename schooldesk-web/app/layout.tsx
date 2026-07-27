import type { Metadata } from "next";
import "./globals.css";
import { absoluteUrl, siteDescription, siteName, siteUrl } from "@/lib/site";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  applicationName: siteName,
  title: { default: siteName, template: `%s | ${siteName}` },
  description: siteDescription,
  keywords: ["ArishVille Preschool", "preschool in Miyapur", "early learning in Hyderabad", "play-led learning", "kindergarten", "school for young children"],
  alternates: { canonical: "/" },
  icons: { icon: "/branding/arishville-logo.png", apple: "/branding/arishville-logo.png" },
  openGraph: { type: "website", locale: "en_IN", url: "/", siteName, title: siteName, description: siteDescription, images: [{ url: "/opengraph-image", width: 1200, height: 630, alt: "ArishVille Preschool" }] },
  twitter: { card: "summary_large_image", title: siteName, description: siteDescription, images: ["/opengraph-image"] },
  robots: { index: true, follow: true, googleBot: { index: true, follow: true, "max-image-preview": "large", "max-snippet": -1, "max-video-preview": -1 } },
};
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const schoolSchema = { "@context": "https://schema.org", "@type": "Preschool", name: siteName, description: siteDescription, url: absoluteUrl("/"), logo: absoluteUrl("/branding/arishville-logo.png"), slogan: "Learn Today, Lead Tomorrow.", address: { "@type": "PostalAddress", streetAddress: "Plot No. 29, 1-42, PE/29, Chiranjeevi Nagar, Pragathi Enclave", addressLocality: "Miyapur, Hyderabad", addressRegion: "Telangana", postalCode: "500049", addressCountry: "IN" }, areaServed: ["Miyapur", "Hyderabad", "Telangana"] };
  return <html lang="en" data-scroll-behavior="smooth"><body><script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(schoolSchema) }}/>{children}</body></html>;
}

import type { Metadata } from "next";
import { absoluteUrl, siteAliases, siteDescription, siteName } from "@/lib/site";

export const publicKeywords = [
  ...siteAliases,
  "Arish Ville Preschool",
  "ArishVille Preschool",
  "arishville preschool",
  "preschool in Miyapur",
  "preschool in Hyderabad",
  "daycare in Miyapur",
  "playgroup in Miyapur",
  "nursery school in Miyapur",
  "PP1 preschool",
  "PP2 preschool",
  "early learning Hyderabad",
].filter((value, index, values) => values.indexOf(value) === index);

type PublicMetadataOptions = {
  title?: string;
  description?: string;
  path?: string;
  keywords?: string[];
};

export function publicMetadata({
  title,
  description = siteDescription,
  path = "/",
  keywords = [],
}: PublicMetadataOptions): Metadata {
  const pageTitle = title
    ? title.includes(siteName) ? title : `${title} | ${siteName}`
    : siteName;
  const url = absoluteUrl(path);
  const image = absoluteUrl("/opengraph-image");
  return {
    title: { absolute: pageTitle },
    description,
    keywords: [...new Set([...publicKeywords, ...keywords])],
    alternates: { canonical: url },
    openGraph: {
      type: "website",
      locale: "en_IN",
      url,
      siteName,
      title: pageTitle,
      description,
      images: [{ url: image, width: 1200, height: 630, alt: `${siteName} — Learn Today, Lead Tomorrow.` }],
    },
    twitter: {
      card: "summary_large_image",
      title: pageTitle,
      description,
      images: [image],
    },
    robots: {
      index: true,
      follow: true,
      googleBot: {
        index: true,
        follow: true,
        "max-image-preview": "large",
        "max-snippet": -1,
        "max-video-preview": -1,
      },
    },
  };
}

export type PublicPageSchemaOptions = {
  name: string;
  description: string;
  path: string;
  type?: "WebPage" | "AboutPage" | "ContactPage" | "CollectionPage";
};

export function publicPageSchema({
  name,
  description,
  path,
  type = "WebPage",
}: PublicPageSchemaOptions) {
  const url = absoluteUrl(path);
  return [
    {
      "@context": "https://schema.org",
      "@type": type,
      "@id": `${url}#webpage`,
      name,
      description,
      url,
      isPartOf: { "@id": `${absoluteUrl("/")}#website` },
      about: { "@id": `${absoluteUrl("/")}#school` },
    },
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      "@id": `${url}#breadcrumbs`,
      itemListElement: [
        {
          "@type": "ListItem",
          position: 1,
          name: siteName,
          item: absoluteUrl("/"),
        },
        ...(path === "/"
          ? []
          : [{ "@type": "ListItem", position: 2, name, item: url }]),
      ],
    },
  ];
}

export function JsonLd({ data }: { data: unknown }) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    />
  );
}

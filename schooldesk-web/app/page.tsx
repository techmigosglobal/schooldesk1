import type { Metadata } from "next";
import { PreschoolEssentials } from "@/components/preschool-essentials";
import { PublicPage } from "@/components/public-site";
import { getPublicWebsite } from "@/lib/public-website";
import { publicMetadata } from "@/lib/seo";

const description = "Discover Arish Ville, also known as ArishVille, in Miyapur, Hyderabad. Explore Daycare, Playgroup, Nursery, PP1 and PP2, and enquire about admissions.";
export const metadata: Metadata = publicMetadata({ title: "Arish Ville (ArishVille) Preschool in Miyapur, Hyderabad", description, path: "/", keywords: ["best preschool in Miyapur", "Arish Ville admissions"] });

export default async function HomePage() {
  const site = await getPublicWebsite();
  return <PublicPage showBreakingNews schema={{ name: "Arish Ville Preschool home", description, path: "/" }}><PreschoolEssentials site={site} /></PublicPage>;
}

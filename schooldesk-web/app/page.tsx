import type { Metadata } from "next";
import { PreschoolEssentials } from "@/components/preschool-essentials";
import { PublicPage } from "@/components/public-site";
import { getPublicWebsite } from "@/lib/public-website";

export const metadata: Metadata = {
  title: { absolute: "Arish Ville (ArishVille) Preschool in Miyapur, Hyderabad" },
  description: "Discover Arish Ville, also known as ArishVille, in Miyapur, Hyderabad. Explore Daycare, Playgroup, Nursery, PP1 and PP2, and enquire about admissions.",
  alternates: { canonical: "/" },
};

export default async function HomePage() {
  const site = await getPublicWebsite();
  return <PublicPage showBreakingNews><PreschoolEssentials site={site} /></PublicPage>;
}

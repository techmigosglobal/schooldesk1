import type { Metadata } from "next";
import { PreschoolEssentials } from "@/components/preschool-essentials";
import { PublicPage } from "@/components/public-site";
import { getPublicWebsite } from "@/lib/public-website";

export const metadata: Metadata = {
  title: "Play-led Preschool for Little Learners",
  description: "Discover Arish Ville Preschool: a joyful, caring place for children to explore, create, make friends, and grow with confidence.",
  alternates: { canonical: "/" },
};

export default async function HomePage() {
  const site = await getPublicWebsite();
  return <PublicPage showBreakingNews><PreschoolEssentials site={site} /></PublicPage>;
}

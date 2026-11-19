import { expect, test } from "bun:test";
import { canonicalSiteUrl, siteAliases } from "../lib/site";
import { publicMetadata, publicKeywords, publicPageSchema } from "../lib/seo";
import sitemap from "../app/sitemap";
import { reportLinkState } from "../lib/report-links";

test("a deployment alias cannot become the school's canonical domain", () => {
  expect(canonicalSiteUrl("https://schooldesk1.vercel.app")).toBe("https://arishville.com");
  expect(canonicalSiteUrl("https://arishville.com/")).toBe("https://arishville.com");
  expect(canonicalSiteUrl("https://www.arishville.com/about-us")).toBe("https://arishville.com");
  expect(canonicalSiteUrl("http://localhost:3100")).toBe("http://localhost:3100");
});

test("brand variants cover spaced and unspaced searches", () => {
  for (const name of ["ArishVille", "arishville", "Arish Ville", "arish ville"]) expect(siteAliases).toContain(name);
  for (const name of ["ArishVille", "arishville", "Arish Ville", "arish ville"]) expect(publicKeywords).toContain(name);
});

test("public metadata has a canonical, social image, and local search terms", () => {
  const metadata = publicMetadata({ title: "Admissions", description: "Admissions information", path: "/admissions" });
  expect(metadata.alternates?.canonical).toBe("http://localhost:3000/admissions");
  expect(metadata.openGraph?.url).toBe("http://localhost:3000/admissions");
  expect(metadata.openGraph?.images).toBeTruthy();
  expect(metadata.keywords).toContain("preschool in Miyapur");
});

test("public page schema contains a web page and breadcrumb list", () => {
  const schema = publicPageSchema({ name: "Admissions", description: "Admissions information", path: "/admissions" });
  expect(schema.map((item) => item["@type"])).toEqual(["WebPage", "BreadcrumbList"]);
});

test("sitemap contains every existing public page and excludes private routes", () => {
  const paths = sitemap().map((item) => new URL(item.url).pathname);
  expect(paths).toEqual(["/", "/about-us", "/our-mission", "/programs", "/admissions", "/campus-safety", "/gallery", "/contact", "/news-events"]);
});

test("report history distinguishes unavailable legacy links and expired signatures", () => {
  expect(reportLinkState("https://old.supabase.co/storage/v1/object/sign/reports/file.pdf")).toBe("legacy");
  const token = `header.${btoa(JSON.stringify({ exp: 10 }))}.signature`;
  expect(reportLinkState(`https://api.arishville.com/storage/v1/object/sign/reports/file.pdf?token=${token}`, 20_000)).toBe("expired");
  expect(reportLinkState("javascript:alert(1)")).toBe("missing");
});

import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { isFinanceReport, reportsForRole } from "../components/portal/report-catalog";
import {
  isPublicGalleryImage,
  isPublicGalleryMedia,
  isPublicGalleryVideo,
  uniqueGalleryItems,
} from "../lib/gallery";

const source = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");

test("report manifest grants fee PDFs only to principals", () => {
  const principal = reportsForRole("principal");
  const coordinator = reportsForRole("coordinator");
  expect(principal.some(isFinanceReport)).toBe(true);
  expect(coordinator.some(isFinanceReport)).toBe(false);
  expect(coordinator.map((report) => report.id)).toContain("admission_inquiry_summary");
  expect(principal.map((report) => report.id)).toContain("complete_fees_report");
});

test("leadership report API includes admissions summaries and blocks non-leadership exports", () => {
  const handler = source("../../supabase/functions/api/handlers/uploads.ts");
  expect(handler).toContain('"admission_inquiry_summary"');
  expect(handler).toContain('svc.from("admission_inquiries")');
  expect(handler).toContain('return fail("leadership access required", 403);');
});

test("gallery media helpers retain images and supported videos while deduplicating", () => {
  const image = { id: "image-1", title: "Image", alt_text: "Image", caption: "", media_url: "/photo.jpeg", media_type: "image/jpeg" };
  const video = { id: "video-1", title: "Video", alt_text: "Video", caption: "", media_url: "/clip.mp4", media_type: "video/mp4" };
  expect(isPublicGalleryImage(image)).toBe(true);
  expect(isPublicGalleryVideo(video)).toBe(true);
  expect(isPublicGalleryMedia(video)).toBe(true);
  expect(uniqueGalleryItems([image, video, { ...video }])).toHaveLength(2);
});

test("ticker keeps moving in normal and reduced-motion configurations", () => {
  const ticker = source("../components/breaking-news-ticker.tsx");
  const styles = source("../app/globals.css");
  expect(ticker).toContain('aria-label={`School announcement: ${message}`}');
  expect(ticker).toContain('className="breaking-news-group"');
  expect(ticker).toContain("Array.from({ length: 6");
  expect(styles).toContain("@media (prefers-reduced-motion:no-preference)");
  expect(styles).toContain("translate3d(-50%,0,0)");
  expect(styles).toContain("animation:breaking-news-scroll 100s linear infinite !important");
  expect(styles).toContain('.breaking-news-group[aria-hidden="true"],.breaking-news-item:not(:first-child) { display:inline-flex; }');
  expect(styles).not.toContain(".breaking-news-track { animation: none; overflow: auto; }");
});

test("public homepage and gallery render image media only", () => {
  const homepageGallery = source("../components/preschool-essentials.tsx");
  const galleryPage = source("../app/gallery/page.tsx");

  expect(homepageGallery).toContain("filter(isPublicGalleryImage)");
  expect(homepageGallery).not.toContain("<video");
  expect(galleryPage).toContain("filter(isPublicGalleryImage)");
  expect(galleryPage).not.toContain("<video");
});

test("web login and portal client keep only leadership wording and modules", () => {
  const login = source("../app/login/page.tsx");
  const portal = source("../components/portal-client.tsx");
  expect(login).toContain("SchoolDesk leadership access");
  expect(login).not.toContain("Staff login");
  expect(portal).not.toContain("AttendanceWorkspace");
  expect(portal).not.toContain("CommunicationsWorkspace");
});

test("student and teacher directories retain accessible live search", () => {
  const students = source("../components/portal/StudentDirectory.tsx");
  const teachers = source("../components/portal/TeacherDirectory.tsx");

  expect(students).toContain('type="search"');
  expect(students).toContain('aria-label="Search students"');
  expect(students).toContain("displayName(student)");
  expect(students).toContain("parentDetails(student).phone");
  expect(students).toContain("useEffect(() => setPage(1), [search, classFilter, statusFilter])");

  expect(teachers).toContain('type="search"');
  expect(teachers).toContain('aria-label="Search teachers"');
  expect(teachers).toContain("[name, staffCode, username, email, phone, designation]");
  expect(teachers).toContain("useEffect(() => setPage(1), [search, designationFilter, statusFilter])");
});

test("Arish Ville palette and loading skeletons cover login and portal transitions", () => {
  const styles = source("../app/globals.css");
  const loginForm = source("../components/login-form.tsx");
  const dashboard = source("../components/portal/DashboardPanel.tsx");
  const loginLoading = source("../app/login/loading.tsx");
  const roleLoginLoading = source("../app/login/[role]/loading.tsx");
  const portalLoading = source("../app/portal/[role]/loading.tsx");

  expect(styles).toContain("--brand-uniform-navy: #0b2f5b");
  expect(styles).toContain("--brand-academic-blue: #0e5ea8");
  expect(styles).toContain("--brand-school-gold: #f4c430");
  expect(styles).toContain("/* Arish Ville authenticated portals: school-uniform blue with warm yellow accents. */");
  expect(styles).toContain("background:linear-gradient(180deg,#0b2f5b 0%,#0d5b9f 100%)");
  expect(styles).toContain("background:linear-gradient(135deg,#ffe27a,#ffd24f)");
  expect(styles).toContain("@keyframes skeleton-shimmer");
  expect(styles).toContain(".activity-spinner");
  expect(styles).toContain("animation:skeleton-shimmer 1.8s ease-in-out infinite !important");
  expect(styles).toContain("animation:spin .9s linear infinite !important");
  expect(loginForm).toContain('className="login-auth-progress"');
  expect(loginForm).toContain("Verifying your account and preparing the portal");
  expect(dashboard).toContain("DashboardLoadingState");
  expect(loginLoading).toContain("<LoginSkeleton />");
  expect(roleLoginLoading).toContain("<LoginSkeleton />");
  expect(portalLoading).toContain("<PortalSkeleton />");
});

test("leadership feature workspaces use layout-shaped loading states", () => {
  const modules = [
    "../components/portal/StudentDirectory.tsx",
    "../components/portal/TeacherDirectory.tsx",
    "../components/portal/ParentDirectory.tsx",
    "../components/portal/ClassesWorkspace.tsx",
    "../components/portal/TimetableWorkspace.tsx",
    "../components/portal/ResourceModule.tsx",
    "../components/portal/FeesWorkspace.tsx",
    "../components/portal/ReportsWorkspace.tsx",
    "../components/portal/WebsiteManager.tsx",
    "../components/portal/AdmissionInquiriesWorkspace.tsx",
  ];

  for (const modulePath of modules) {
    expect(source(modulePath)).toContain("PortalModuleSkeleton");
  }

  const portal = source("../components/portal-client.tsx");
  expect(portal).toContain("branchesLoading");
  expect(portal).toContain("switchingBranch");
  expect(portal).toContain('<PortalModuleSkeleton variant="cards"');
  expect(source("../components/loading-skeletons.tsx")).toContain("LoadingIndicator");
  expect(source("../components/portal/FormActions.tsx")).toContain('<LoadingIndicator label="Saving…"');
  expect(source("../components/portal/TickerManager.tsx")).toContain('<LoadingIndicator label="Publishing…"');
});

test("website-facing school name is Arish Ville", () => {
  const sources = [
    source("../app/layout.tsx"),
    source("../app/page.tsx"),
    source("../app/about-us/page.tsx"),
    source("../app/login/page.tsx"),
    source("../components/public-site.tsx"),
    source("../components/home-experience.tsx"),
  ].join("\n");

  expect(sources).toContain("Arish Ville");
  expect(sources).not.toContain("Little Ville");
  expect(sources).not.toContain("ArishVille");
});

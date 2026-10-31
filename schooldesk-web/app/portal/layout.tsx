import "@/components/portal/directory-ux.css";
import "@/components/portal/media-ux.css";
import "@/components/portal/finance-ux.css";
import "@/components/portal/portal-ux.css";
import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = { title: "SchoolDesk workspace", robots: { index: false, follow: false }, alternates: { canonical: null } };

export default function PortalLayout({ children }: { children: ReactNode }) { return children; }

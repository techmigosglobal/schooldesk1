import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = { title: "Leadership login", robots: { index: false, follow: false }, alternates: { canonical: null } };

export default function LoginLayout({ children }: { children: ReactNode }) { return children; }

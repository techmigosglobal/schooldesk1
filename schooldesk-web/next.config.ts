import type { NextConfig } from "next";

const csp = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
  "font-src 'self' https://fonts.gstatic.com",
  "img-src 'self' data: blob: http: https:",
  // Local Docker Supabase is the only backend used by this development
  // build. Production media origins are injected during the separately
  // approved hosted promotion.
  "media-src 'self' http://127.0.0.1:54321 http://localhost:54321",
  "connect-src 'self'",
  "worker-src 'self' blob:",
  "frame-src 'self' https://www.google.com https://www.google.co.in https://maps.google.com",
  "frame-ancestors 'none'",
  "base-uri 'self'",
  "form-action 'self'",
].join("; ");

const embeddedMapFallbackCsp = [
  "default-src 'none'",
  "style-src 'unsafe-inline'",
  "frame-ancestors 'self'",
  "base-uri 'none'",
].join("; ");

const securityHeaders = [
  { key: "X-Frame-Options", value: "DENY" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-DNS-Prefetch-Control", value: "on" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=(), payment=()" },
  { key: "Strict-Transport-Security", value: "max-age=31536000; includeSubDomains; preload" },
  { key: "Content-Security-Policy", value: csp },
];

const nextConfig: NextConfig = {
  turbopack: { root: process.cwd() },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: securityHeaders,
      },
      {
        // The local map fallback is deliberately rendered in a same-origin
        // iframe. Keep the default site unembeddable while allowing this
        // narrowly scoped, static response to display its map link.
        source: "/api/google-map-embed",
        headers: [
          { key: "X-Frame-Options", value: "SAMEORIGIN" },
          { key: "Content-Security-Policy", value: embeddedMapFallbackCsp },
        ],
      },
    ];
  },
};

export default nextConfig;

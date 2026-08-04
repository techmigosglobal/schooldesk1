import { z } from "zod";

const productionDefaults = {
  SCHOOLDESK_API_BASE_URL:
    "https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api",
  SCHOOLDESK_PUBLIC_SCHOOL_ID: "b3409710-78ac-446d-b8f5-45c58d72a004",
  NEXT_PUBLIC_SITE_URL: "https://arishvillepreschool.com",
};

/**
 * Validates required environment variables at startup.
 * If any are missing or malformed, the server will fail fast with a clear error
 * rather than silently breaking at request time.
 *
 * Add new env vars here as the app grows.
 */
const envSchema = z.object({
  /** Base URL of the SchoolDesk backend API (no trailing slash). */
  SCHOOLDESK_API_BASE_URL: z
    .string()
    .url(
      "SCHOOLDESK_API_BASE_URL must be a valid URL (e.g. https://api.yourbackend.com)"
    )
    .default(productionDefaults.SCHOOLDESK_API_BASE_URL),
  /** Public website school UUID for fetching published branded content. */
  SCHOOLDESK_PUBLIC_SCHOOL_ID: z
    .string()
    .uuid()
    .default(productionDefaults.SCHOOLDESK_PUBLIC_SCHOOL_ID),
  /** Canonical site URL used for metadata. */
  NEXT_PUBLIC_SITE_URL: z.string().url().default(productionDefaults.NEXT_PUBLIC_SITE_URL),
  /** Secret for signing session cookies. Must be at least 32 characters. */
  SESSION_SECRET: z
    .string()
    .min(32, "SESSION_SECRET must be at least 32 characters long")
    .optional(),
  /** Node environment. Defaults to development. */
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
});

function parseEnv() {
  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    const issues = result.error.issues
      .map((i) => `  • ${i.path.join(".")}: ${i.message}`)
      .join("\n");
    throw new Error(
      `\n[schooldesk-web] Missing or invalid environment variables:\n${issues}\n\nCheck your .env.local file or Vercel Project Settings.`
    );
  }
  return result.data;
}

export const env = parseEnv();

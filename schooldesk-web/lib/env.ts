import { z } from "zod";

const localDefaults = {
  SCHOOLDESK_API_BASE_URL:
    "http://127.0.0.1:54321/functions/v1/api",
  SCHOOLDESK_PUBLIC_SCHOOL_ID: "00000000-0000-4000-8000-000000000001",
  NEXT_PUBLIC_SITE_URL: "http://localhost:3000",
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
  SCHOOLDESK_API_BASE_URL: z.string().url().optional(),
  /** Public website school UUID for fetching published branded content. */
  SCHOOLDESK_PUBLIC_SCHOOL_ID: z
    .string()
    .uuid()
    .optional(),
  /** Canonical site URL used for metadata. */
  NEXT_PUBLIC_SITE_URL: z.string().url().optional(),
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
  const parsed = result.data;
  const requiredProduction = [
    "SCHOOLDESK_API_BASE_URL",
    "SCHOOLDESK_PUBLIC_SCHOOL_ID",
    "NEXT_PUBLIC_SITE_URL",
  ] as const;
  if (parsed.NODE_ENV === "production") {
    const missing = requiredProduction.filter((key) => !parsed[key]);
    if (missing.length > 0) {
      throw new Error(
        `[schooldesk-web] Production configuration is missing: ${missing.join(", ")}. ` +
          "Inject protected deployment variables; local defaults are never used for production.",
      );
    }
  }
  return {
    ...parsed,
    SCHOOLDESK_API_BASE_URL:
      parsed.SCHOOLDESK_API_BASE_URL ?? localDefaults.SCHOOLDESK_API_BASE_URL,
    SCHOOLDESK_PUBLIC_SCHOOL_ID:
      parsed.SCHOOLDESK_PUBLIC_SCHOOL_ID ?? localDefaults.SCHOOLDESK_PUBLIC_SCHOOL_ID,
    NEXT_PUBLIC_SITE_URL:
      parsed.NEXT_PUBLIC_SITE_URL ?? localDefaults.NEXT_PUBLIC_SITE_URL,
  };
}

export const env = parseEnv();

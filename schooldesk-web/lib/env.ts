import { z } from "zod";

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
    ),
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
      `\n[schooldesk-web] Missing or invalid environment variables:\n${issues}\n\nCheck your .env.local file.`
    );
  }
  return result.data;
}

export const env = parseEnv();

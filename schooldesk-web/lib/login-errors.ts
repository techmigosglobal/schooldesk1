export const INVALID_CREDENTIALS_MESSAGE =
  "Invalid credentials. Please check your username/email and password.";

const invalidCredentialPatterns = [
  "invalid credentials",
  "invalid login credentials",
  "invalid username or password",
  "invalid email or password",
  "incorrect username or password",
  "incorrect email or password",
];

export function loginErrorMessage(
  value: unknown,
  fallback = "Unable to sign in. Please try again.",
): string {
  const message = value instanceof Error
    ? value.message.trim()
    : typeof value === "string"
    ? value.trim()
    : "";

  if (!message) return fallback;

  const normalized = message.toLowerCase();
  if (invalidCredentialPatterns.some((pattern) => normalized.includes(pattern))) {
    return INVALID_CREDENTIALS_MESSAGE;
  }

  return message;
}

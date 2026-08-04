import { describe, expect, test } from "bun:test";
import {
  INVALID_CREDENTIALS_MESSAGE,
  loginErrorMessage,
} from "../lib/login-errors";

describe("loginErrorMessage", () => {
  test("normalizes backend credential failures", () => {
    expect(loginErrorMessage("invalid username or password")).toBe(
      INVALID_CREDENTIALS_MESSAGE,
    );
    expect(loginErrorMessage(new Error("Invalid login credentials"))).toBe(
      INVALID_CREDENTIALS_MESSAGE,
    );
  });

  test("keeps actionable non-credential responses", () => {
    expect(loginErrorMessage("This account belongs to the principal portal.")).toBe(
      "This account belongs to the principal portal.",
    );
  });

  test("uses a safe fallback when no response message is available", () => {
    expect(loginErrorMessage(undefined)).toBe("Unable to sign in. Please try again.");
  });
});

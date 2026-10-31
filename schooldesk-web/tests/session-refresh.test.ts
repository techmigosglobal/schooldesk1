import { expect, spyOn, test } from "bun:test";
import { refreshSession } from "../lib/refresh-session";

test("parallel web requests share a refresh-token rotation", async () => {
  const request = spyOn(globalThis, "fetch").mockImplementation(async () => Response.json({ success: true, data: { access_token: "new-access", refresh_token: "new-refresh" } }));
  try {
    const sessions = await Promise.all(Array.from({ length: 12 }, () => refreshSession("test-shared-token")));
    expect(request).toHaveBeenCalledTimes(1);
    expect(sessions.every((session) => session?.access_token === "new-access")).toBe(true);
  } finally { request.mockRestore(); }
});

test("failed refresh does not create a session", async () => {
  const request = spyOn(globalThis, "fetch").mockImplementation(async () => Response.json({ success: false }, { status: 401 }));
  try { expect(await refreshSession("test-expired-token")).toBeNull(); }
  finally { request.mockRestore(); }
});

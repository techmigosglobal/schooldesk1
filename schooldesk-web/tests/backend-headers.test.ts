import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { backendHeaders } from "../lib/backend";
import { publicWebsiteMediaUrl } from "../lib/public-website";

test("sends the configured anon key through the Supabase API gateway", () => {
  const headers = backendHeaders({ "Content-Type": "application/json" }, "anon-key");

  expect(headers.get("apikey")).toBe("anon-key");
  expect(headers.get("authorization")).toBe("Bearer anon-key");
  expect(headers.get("content-type")).toBe("application/json");
});

test("keeps a signed-in user's bearer token while sending the anon API key", () => {
  const headers = backendHeaders(
    { Authorization: "Bearer user-token" },
    "anon-key",
  );

  expect(headers.get("apikey")).toBe("anon-key");
  expect(headers.get("authorization")).toBe("Bearer user-token");
});

test("public website content fetch uses the same authenticated API headers", () => {
  const source = readFileSync(new URL("../lib/public-website.ts", import.meta.url), "utf8");
  expect(source).toContain("headers: backendHeaders()");
});

test("public website media replaces the VPS-internal storage host", () => {
  expect(publicWebsiteMediaUrl(
    "http://supabase-kong:8000/storage/v1/object/public/school-public-media/gallery/a.jpg?width=640",
    "https://api.arishville.com",
  )).toBe("https://api.arishville.com/storage/v1/object/public/school-public-media/gallery/a.jpg?width=640");
  expect(publicWebsiteMediaUrl(
    "https://images.example.com/gallery/a.jpg",
    "https://api.arishville.com",
  )).toBe("https://images.example.com/gallery/a.jpg");
});

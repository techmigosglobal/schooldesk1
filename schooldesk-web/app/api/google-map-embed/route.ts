import { NextResponse } from "next/server";

export function GET() {
  const key = process.env.GOOGLE_MAPS_EMBED_API_KEY || process.env.GOOGLE_PLACES_API_KEY;
  const placeId = process.env.GOOGLE_PLACE_ID;
  if (!key || !placeId) {
    return new NextResponse('<!doctype html><html><body style="margin:0;display:grid;place-items:center;min-height:100vh;font-family:system-ui;color:#173d2b;background:#f6faf4"><a style="color:#154c34;font-weight:700" target="_blank" rel="noreferrer" href="https://www.google.com/maps?q=Little+Ville+Miyapur">Open Little Ville in Google Maps ↗</a></body></html>', { headers: { "Content-Type": "text/html; charset=utf-8" } });
  }
  const url = new URL("https://www.google.com/maps/embed/v1/place");
  url.searchParams.set("key", key);
  url.searchParams.set("q", `place_id:${placeId}`);
  return NextResponse.redirect(url);
}

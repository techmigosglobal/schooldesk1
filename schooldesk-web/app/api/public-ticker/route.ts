import { NextResponse } from "next/server";
import { getPublicWebsite } from "@/lib/public-website";

export async function GET() {
  const content = (await getPublicWebsite()).content ?? {};
  return NextResponse.json({
    data: {
      breaking_news_text: typeof content.breaking_news_text === "string" ? content.breaking_news_text : "",
      breaking_news_enabled: content.breaking_news_enabled === true,
    },
  }, { headers: { "Cache-Control": "public, max-age=30, s-maxage=60" } });
}

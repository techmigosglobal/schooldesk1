import { NextRequest, NextResponse } from "next/server";
import { backendFetch, backendHeaders, configuredBackend, unwrap } from "@/lib/backend";
import { getSession } from "@/lib/session";

/** Download only a report returned by the user's existing, branch-scoped API. */
export async function GET(request: NextRequest) {
  const session = await getSession();
  if (!session) return NextResponse.json({ error: "Please sign in again." }, { status: 401 });
  const finance = request.nextUrl.searchParams.get("kind") === "finance";
  if (finance && session.role !== "principal") return NextResponse.json({ error: "Principal access required." }, { status: 403 });
  if (session.role === "principal" && !session.branchId) return NextResponse.json({ error: "Select a branch first." }, { status: 409 });
  const id = request.nextUrl.searchParams.get("id");
  if (!id) return NextResponse.json({ error: "Select a report." }, { status: 400 });
  try {
    const upstream = await backendFetch(finance ? "fees/reports/exports" : "reports/exports", {
      headers: { Authorization: `Bearer ${session.accessToken}`, ...(session.branchId ? { "x-schooldesk-branch-id": session.branchId } : {}) },
    });
    if (!upstream.ok) return NextResponse.json({ error: "Unable to access this report." }, { status: upstream.status });
    const records = unwrap<Array<Record<string, unknown>>>(await upstream.json());
    const record = records.find((item) => String(item.id) === id);
    if (!record || typeof record.download_url !== "string") return NextResponse.json({ error: "This report file is unavailable. Generate a current PDF." }, { status: 404 });
    const stored = new URL(record.download_url);
    const origin = new URL(configuredBackend()).origin;
    if (!(stored.hostname.endsWith(".supabase.co") || stored.hostname === "supabase-kong" || stored.origin === origin)) {
      return NextResponse.json({ error: "This saved report needs to be regenerated." }, { status: 410 });
    }
    const match = stored.pathname.match(/^\/storage\/v1\/object\/(?:sign|public|authenticated)\/([^/]+)\/(.+)$/);
    if (!match || decodeURIComponent(match[2]).split("/").includes("..")) return NextResponse.json({ error: "This saved report needs to be regenerated." }, { status: 410 });
    if (stored.origin === origin || stored.hostname === "supabase-kong") {
      const current = new URL(`${stored.pathname}${stored.search}`, origin);
      const file = await fetch(current, { cache: "no-store", redirect: "error" });
      if (file.ok) {
        const filename = String(record.report_title || "school-report").toLowerCase().replace(/[^a-z0-9_-]+/g, "_");
        return new NextResponse(file.body, { headers: { "Content-Type": "application/pdf", "Content-Disposition": `attachment; filename="${filename}.pdf"`, "Cache-Control": "private, no-store" } });
      }
    }
    const candidates = [[match[1], match[2]]];
    if (match[1] !== "schooldesk-private-files") candidates.push(["schooldesk-private-files", `legacy/${match[1]}/${match[2]}`]);
    for (const [bucket, path] of candidates) {
      const signed = await fetch(`${origin}/storage/v1/object/sign/${bucket}/${path}`, {
        method: "POST", headers: backendHeaders({ Authorization: `Bearer ${session.accessToken}`, "Content-Type": "application/json" }),
        body: JSON.stringify({ expiresIn: 60 }), cache: "no-store", redirect: "error",
      });
      if (!signed.ok) continue;
      const payload = await signed.json();
      const signedPath = payload.signedURL ?? payload.signedUrl;
      if (typeof signedPath !== "string") continue;
      const download = new URL(signedPath.startsWith("/object/") ? `/storage/v1${signedPath}` : signedPath, origin);
      if (download.origin !== origin) continue;
      const file = await fetch(download, { cache: "no-store", redirect: "error" });
      if (!file.ok) continue;
      const filename = String(record.report_title || "school-report").toLowerCase().replace(/[^a-z0-9_-]+/g, "_");
      return new NextResponse(file.body, { headers: { "Content-Type": "application/pdf", "Content-Disposition": `attachment; filename="${filename}.pdf"`, "Cache-Control": "private, no-store" } });
    }
    return NextResponse.json({ error: "The saved file is unavailable in current storage. Use Generate PDF to create a current report." }, { status: 410 });
  } catch {
    return NextResponse.json({ error: "Unable to download this report. Please try again or generate a current PDF." }, { status: 502 });
  }
}

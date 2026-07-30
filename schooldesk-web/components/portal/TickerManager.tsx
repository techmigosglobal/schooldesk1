"use client";

import { useEffect, useState } from "react";
import { BellRing, CircleAlert, RefreshCw } from "@/lib/lucide-react";
import type { Row } from "./types";
import { api, stringValue } from "./utils";

export function TickerManager({ onNotify, compact = false }: { onNotify: (message: string) => void; compact?: boolean }) {
  const [ticker, setTicker] = useState<Row>({});
  const [notice, setNotice] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  async function load() {
    setLoading(true);
    try { setTicker((await api("website/ticker")) as Row); setNotice(""); }
    catch (error) { setNotice(error instanceof Error ? error.message : "Unable to load the public announcement"); }
    finally { setLoading(false); }
  }
  useEffect(() => { void load(); }, []);

  async function save(form: FormData) {
    setSaving(true); setNotice("");
    try {
      await api("website/ticker", { method: "PUT", body: JSON.stringify({
        breaking_news_text: String(form.get("breaking_news_text") ?? ""),
        breaking_news_enabled: form.get("breaking_news_enabled") === "on",
      }) });
      onNotify("Breaking-news bar updated. Visitors will see it shortly.");
      await load();
    } catch (error) { setNotice(error instanceof Error ? error.message : "Unable to publish the announcement"); }
    finally { setSaving(false); }
  }

  return <section className={compact ? "surface ops-form-surface" : "ops-module gallery-workspace"}>
    <div className="ops-module-heading">
      <div><div className="ops-module-icon blue" style={{ background: "#e7f1fa", color: "#0e5ea8" }}><BellRing size={20} /></div><div><p className="ops-kicker">Public announcement</p><h2>Breaking News Bar</h2><p>Publish one short, scrolling announcement across the public website. Turn it off any time.</p></div></div>
      <button className="secondary-button" type="button" onClick={() => void load()} disabled={loading}><RefreshCw size={16} className={loading ? "spin" : ""} /> Refresh</button>
    </div>
    {notice && <div className="ops-inline-error"><CircleAlert size={16} />{notice}</div>}
    {loading ? (
      <div className="operation-form-skeleton" role="status" aria-label="Loading announcement settings">
        <div className="skeleton skeleton-text narrow" />
        <div className="skeleton skeleton-input operation-textarea-skeleton" />
        <div className="skeleton skeleton-text wide" />
        <div className="skeleton skeleton-button" />
      </div>
    ) : (
      <>
        <p className={`ticker-visibility ${ticker.breaking_news_enabled === true && stringValue(ticker.breaking_news_text) ? "is-live" : "is-hidden"}`}>{ticker.breaking_news_enabled === true && stringValue(ticker.breaking_news_text) ? "Live now: visitors can see the scrolling announcement." : "Not visible on the public website yet. Add text, tick the display option, and publish."}</p>
        <form key={`${stringValue(ticker.breaking_news_text)}-${ticker.breaking_news_enabled === true}`} action={save} className="ops-detail-form" style={{ maxWidth: "760px" }}>
          <label className="field"><span>Announcement text <small>(240 characters maximum)</small></span><textarea name="breaking_news_text" maxLength={240} rows={3} defaultValue={stringValue(ticker.breaking_news_text)} placeholder="e.g. Admissions open for the 2026–27 academic year." /></label>
          <label className="field checkbox-field"><input name="breaking_news_enabled" type="checkbox" defaultChecked={ticker.breaking_news_enabled === true} /> <span>Show this announcement on the public website</span></label>
          <button className="primary-button" disabled={saving}>{saving ? "Publishing…" : "Publish announcement"}</button>
        </form>
      </>
    )}
  </section>;
}

"use client";

import { usePortalRefresh } from "./use-portal-refresh";

import { useCallback, useEffect, useState } from "react";
import { CircleAlert } from "@/lib/lucide-react";
import { LoadingIndicator } from "@/components/loading-skeletons";
import type { Row } from "./types";
import { api, stringValue } from "./utils";
import { usePortalGuard } from "./PortalStateProvider";

export function TickerManager({ onNotify, compact = false }: { onNotify: (message: string) => void; compact?: boolean }) {
  const [ticker, setTicker] = useState<Row>({});
  const [notice, setNotice] = useState("");
  const [loading, setLoading] = useState(true);
  const [loaded, setLoaded] = useState(false);
  const [saving, setSaving] = useState(false);
  const [dirty, setDirty] = useState(false);
  usePortalGuard(dirty, saving);

  const load = useCallback(async () => {
    setLoading(true);
    try { setTicker((await api("website/ticker")) as Row); setNotice(""); setDirty(false); setLoaded(true); }
    catch (error) { setNotice(error instanceof Error ? error.message : "Unable to load the public announcement"); }
    finally { setLoading(false); }
  }, []);
  usePortalRefresh(load);
  useEffect(() => { void load(); }, [load]);

  async function save(form: FormData, source: HTMLFormElement) {
    setSaving(true); setNotice("");
    try {
      await api("website/ticker", { method: "PUT", body: JSON.stringify({
        breaking_news_text: String(form.get("breaking_news_text") ?? ""),
        breaking_news_enabled: form.get("breaking_news_enabled") === "on",
      }) });
      setDirty(false);
      source.removeAttribute("data-portal-dirty");
      onNotify("News ticker updated. Visitors will see it shortly.");
      await load();
    } catch (error) { setNotice(error instanceof Error ? error.message : "Unable to publish the announcement"); }
    finally { setSaving(false); }
  }

  return <section className={compact ? "surface ops-form-surface" : "ops-module gallery-workspace"}>
    <div className="media-section-heading"><h2>News ticker</h2><p>Publish one short announcement across the public website. Turn it off any time.</p></div>
    {notice && <div className="ops-inline-error"><CircleAlert size={16} />{notice}</div>}
    {loading ? (
      <div className="operation-form-skeleton" role="status" aria-label="Loading announcement settings">
        <LoadingIndicator label="Loading announcement settings…" announce={false} />
        <div className="skeleton skeleton-text narrow" />
        <div className="skeleton skeleton-input operation-textarea-skeleton" />
        <div className="skeleton skeleton-text wide" />
        <div className="skeleton skeleton-button" />
      </div>
    ) : !loaded ? <p className="ops-empty">Announcement settings are unavailable. Use Refresh to try again.</p> : (
      <>
        <p className={`ticker-visibility ${ticker.breaking_news_enabled === true && stringValue(ticker.breaking_news_text) ? "is-live" : "is-hidden"}`}>{ticker.breaking_news_enabled === true && stringValue(ticker.breaking_news_text) ? "Live now: visitors can see the scrolling announcement." : "Not visible on the public website yet. Add text, tick the display option, and publish."}</p>
        <form key={`${stringValue(ticker.breaking_news_text)}-${ticker.breaking_news_enabled === true}`} onSubmit={(event) => { event.preventDefault(); void save(new FormData(event.currentTarget), event.currentTarget); }} className="ops-detail-form" aria-busy={saving} onChange={() => setDirty(true)} style={{ maxWidth: "760px" }}>
          <fieldset disabled={saving} className="ops-detail-form" style={{ border: 0, padding: 0, margin: 0, minWidth: 0 }}>
          <label className="field"><span>Announcement text <small>(240 characters maximum)</small></span><textarea name="breaking_news_text" maxLength={240} rows={3} defaultValue={stringValue(ticker.breaking_news_text)} placeholder="e.g. Admissions open for the 2026–27 academic year." /></label>
          <label className="field checkbox-field"><input name="breaking_news_enabled" type="checkbox" defaultChecked={ticker.breaking_news_enabled === true} /> <span>Show this announcement on the public website</span></label>
          <button className="primary-button" disabled={saving} aria-busy={saving}>{saving ? <LoadingIndicator label="Publishing…" compact announce={false} /> : "Publish announcement"}</button>
          </fieldset>
        </form>
      </>
    )}
  </section>;
}

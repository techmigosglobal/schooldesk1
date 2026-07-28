"use client";

import { useEffect, useState } from "react";

type Ticker = { breaking_news_text?: string; breaking_news_enabled?: boolean };

export function BreakingNewsTicker() {
  const [ticker, setTicker] = useState<Ticker>({});

  useEffect(() => {
    fetch("/api/public-ticker")
      .then((response) => response.ok ? response.json() : {})
      .then((payload: { data?: Ticker }) => setTicker(payload.data ?? {}))
      .catch(() => setTicker({}));
  }, []);

  const message = typeof ticker.breaking_news_text === "string" ? ticker.breaking_news_text.trim() : "";
  if (!ticker.breaking_news_enabled || !message) return null;

  return (
    <aside className="breaking-news" aria-label={`School announcement: ${message}`}>
      <div className="breaking-news-viewport">
        <div className="breaking-news-track">
          <span title={message}>{message}<i aria-hidden="true">◆</i>{message}<i aria-hidden="true">◆</i></span>
          <span aria-hidden="true">{message}<i>◆</i>{message}<i>◆</i></span>
        </div>
      </div>
    </aside>
  );
}

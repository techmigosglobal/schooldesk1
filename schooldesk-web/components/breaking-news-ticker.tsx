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
          {[false, true].map((duplicate) => (
            <div
              className="breaking-news-group"
              aria-hidden={duplicate || undefined}
              key={String(duplicate)}
            >
              {Array.from({ length: 6 }, (_, index) => (
                <span className="breaking-news-item" title={duplicate ? undefined : message} key={index}>
                  {message}
                  <i aria-hidden="true">◆</i>
                </span>
              ))}
            </div>
          ))}
        </div>
      </div>
    </aside>
  );
}

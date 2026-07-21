"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { BellRing, MessageSquareMore, RefreshCw, Send } from "@/lib/lucide-react";
import type { PortalRole } from "@/lib/roles";
import type { Row } from "./types";
import { api, apiRaw, formatDateTime, rowsFrom, stringValue } from "./utils";

type CommunicationsTab = "announcements" | "notifications" | "messages";

export function CommunicationsWorkspace({
  role,
  onNotify,
}: {
  role: PortalRole;
  onNotify: (message: string, type?: "success" | "error" | "info") => void;
}) {
  const [tab, setTab] = useState<CommunicationsTab>("announcements");
  const [announcements, setAnnouncements] = useState<Row[]>([]);
  const [notifications, setNotifications] = useState<Row[]>([]);
  const [messages, setMessages] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [announcementsData, notificationsData, monitorTeacher, monitorParent] = await Promise.all([
        api("announcements"),
        api("notifications"),
        apiRaw("chat/monitor?type=parent_teacher&monitor=true"),
        apiRaw(`chat/monitor?type=${role === "coordinator" ? "principal_teacher" : "principal_parent"}&monitor=true`),
      ]);
      const combinedMessages = [
        ...rowsFrom(monitorTeacher.body.data),
        ...(monitorParent.ok ? rowsFrom(monitorParent.body.data) : []),
      ].sort((left, right) =>
        stringValue(right.updated_at || right.last_message_at).localeCompare(
          stringValue(left.updated_at || left.last_message_at)
        )
      );
      setAnnouncements(rowsFrom(announcementsData));
      setNotifications(rowsFrom(notificationsData));
      setMessages(combinedMessages);
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load communications");
    } finally {
      setLoading(false);
    }
  }, [role]);

  useEffect(() => {
    void load();
  }, [load]);

  async function publishAnnouncement(form: FormData) {
    try {
      const title = stringValue(form.get("title")).trim();
      const content = stringValue(form.get("content")).trim();
      if (title.length < 3 || content.length < 10) {
        throw new Error("Please enter a clear title and a fuller announcement message.");
      }
      await api("announcements", {
        method: "POST",
        body: JSON.stringify({
          title,
          content,
          target_audience: stringValue(form.get("target_audience")) || "all",
          is_urgent: form.get("is_urgent") === "on",
        }),
      });
      onNotify("Announcement published.");
      void load();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to publish announcement");
    }
  }

  const unreadNotifications = useMemo(
    () => notifications.filter((item) => item.is_read !== true),
    [notifications]
  );

  return (
    <section className="ops-module">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon gold">
            <BellRing size={20} />
          </div>
          <div>
            <p className="ops-kicker">{role === "principal" ? "Leadership communications" : "Coordinator communications"}</p>
            <h2>Announcements & Notifications</h2>
            <p>Publish notices, track unread alerts, and keep an eye on school-wide message activity.</p>
          </div>
        </div>

        <div className="ops-actions">
          <button className="secondary-button" onClick={() => void load()}>
            <RefreshCw size={16} /> Refresh
          </button>
        </div>
      </div>

      {error && <div className="ops-inline-error">{error}</div>}

      <div className="finance-summary ops-summary-grid">
        <article>
          <small>Published Notices</small>
          <b>{announcements.length}</b>
        </article>
        <article>
          <small>Unread Alerts</small>
          <b>{unreadNotifications.length}</b>
        </article>
        <article>
          <small>Monitored Chats</small>
          <b>{messages.length}</b>
        </article>
        <article>
          <small>Urgent Notices</small>
          <b>{announcements.filter((item) => item.is_urgent === true).length}</b>
        </article>
      </div>

      <nav className="finance-tabs" aria-label="Communication sections">
        {([
          ["announcements", "Announcements"],
          ["notifications", `Notifications (${unreadNotifications.length})`],
          ["messages", `Message monitor (${messages.length})`],
        ] as const).map(([id, label]) => (
          <button key={id} className={tab === id ? "active" : ""} onClick={() => setTab(id)}>
            {label}
          </button>
        ))}
      </nav>

      <div className="ops-split-grid">
        <section className="surface ops-form-surface">
          <div className="ops-panel-header">
            <h3>Publish school notice</h3>
          </div>
          <form action={publishAnnouncement} className="ops-detail-form">
            <label className="field">
              Title
              <input name="title" placeholder="e.g. Friday closure notice" required />
            </label>
            <label className="field">
              Message
              <textarea name="content" rows={6} placeholder="Write the update that parents and staff should see." required />
            </label>
            <label className="field">
              Target audience
              <select name="target_audience" defaultValue="all">
                <option value="all">All</option>
                <option value="staff">Staff only</option>
                <option value="parents">Parents only</option>
                <option value="teachers">Teachers only</option>
              </select>
            </label>
            <label className="check-field">
              <input name="is_urgent" type="checkbox" /> Mark as urgent
            </label>
            <button className="primary-button">
              <Send size={16} /> Publish announcement
            </button>
          </form>
        </section>

        <section className="surface ops-form-surface">
          <div className="ops-panel-header">
            <h3>
              {tab === "announcements"
                ? "Recent announcements"
                : tab === "notifications"
                  ? "Leadership notifications"
                  : "Conversation monitor"}
            </h3>
          </div>

          {loading ? (
            <p className="ops-empty-small">Loading communication feeds…</p>
          ) : tab === "announcements" ? (
            <div className="ops-feed-list">
              {announcements.length ? (
                announcements.map((item) => (
                  <article key={stringValue(item.id)}>
                    <div>
                      <b>{stringValue(item.title)}</b>
                      <p>{stringValue(item.content)}</p>
                    </div>
                    <div className="ops-feed-meta">
                      <span>{stringValue(item.target_audience || "all")}</span>
                      <small>{formatDateTime(item.created_at)}</small>
                    </div>
                  </article>
                ))
              ) : (
                <p className="ops-empty-small">No announcements published yet.</p>
              )}
            </div>
          ) : tab === "notifications" ? (
            <div className="ops-feed-list">
              {notifications.length ? (
                notifications.map((item) => (
                  <article key={stringValue(item.id || item.notification_id)}>
                    <div>
                      <b>{stringValue(item.title || item.type || "Notification")}</b>
                      <p>{stringValue(item.body || item.message)}</p>
                    </div>
                    <div className="ops-feed-meta">
                      <span className={`ops-status-tag ${item.is_read ? "approved" : "pending"}`}>
                        {item.is_read ? "Read" : "Unread"}
                      </span>
                      <small>{formatDateTime(item.created_at)}</small>
                    </div>
                  </article>
                ))
              ) : (
                <p className="ops-empty-small">No notifications available for this role.</p>
              )}
            </div>
          ) : (
            <div className="ops-feed-list">
              {messages.length ? (
                messages.map((item) => (
                  <article key={stringValue(item.id)}>
                    <div>
                      <b>{stringValue(item.title || item.name || "Conversation")}</b>
                      <p>{stringValue(item.last_message || item.preview || item.body || "No recent message")}</p>
                    </div>
                    <div className="ops-feed-meta">
                      <span>
                        <MessageSquareMore size={14} /> {stringValue(item.unread_count || 0)} unread
                      </span>
                      <small>{formatDateTime(item.updated_at || item.last_message_at)}</small>
                    </div>
                  </article>
                ))
              ) : (
                <p className="ops-empty-small">No monitored conversations returned by the backend yet.</p>
              )}
            </div>
          )}
        </section>
      </div>
    </section>
  );
}

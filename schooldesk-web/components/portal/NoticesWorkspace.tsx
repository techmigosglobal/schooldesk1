"use client";

import { useCallback, useEffect, useState } from "react";
import {
  BellRing,
  CheckCircle2,
  CircleAlert,
  Clock,
  Megaphone,
  Plus,
  RefreshCw,
  Send,
  UsersRound,
} from "@/lib/lucide-react";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import { usePortalRefresh } from "./use-portal-refresh";
import { usePortalTab } from "./PortalStateProvider";
import type { PortalRole } from "@/lib/roles";
import type { Row } from "./types";
import { api, formatDateTime, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";

type NoticeItem = {
  id: string;
  title: string;
  message?: string;
  body?: string;
  target_roles?: string[];
  roles?: string[];
  created_at: string;
  sender_name?: string;
  status?: string;
  destinations?: string[];
};

export function NoticesWorkspace({
  role,
  onNotify,
}: {
  role: PortalRole;
  onNotify: (message: string, type?: "success" | "error" | "info") => void;
}) {
  const [tab, setTab] = usePortalTab<"all" | "create">("notices", "all");
  const [notices, setNotices] = useState<NoticeItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  // Create form state
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [targetRole, setTargetRole] = useState<"all" | "teacher" | "parent">("all");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const data = await api("notifications/broadcasts").catch(() => []);
      setNotices((Array.isArray(data) ? data : []) as NoticeItem[]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load announcements");
    } finally {
      setLoading(false);
    }
  }, []);

  usePortalRefresh(load);

  useEffect(() => {
    void load();
  }, [load]);

  const handleBroadcast = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !message.trim()) {
      onNotify("Title and announcement message are required", "error");
      return;
    }

    setSubmitting(true);
    setError("");

    try {
      await api("notifications/broadcasts", {
        method: "POST",
        headers: {
          "Idempotency-Key": crypto.randomUUID(),
        },
        body: JSON.stringify({
          title: title.trim(),
          message: message.trim(),
          roles: targetRole === "all" ? ["principal", "coordinator", "teacher", "parent"] : [targetRole],
          mode: "all",
          user_ids: [],
        }),
      });

      onNotify("Announcement broadcast dispatched successfully to mobile devices", "success");
      setTitle("");
      setMessage("");
      setTab("all");
      await load();
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Broadcast failed";
      setError(msg);
      onNotify(msg, "error");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <section className="ops-module notices-workspace" aria-busy={loading}>
      <div className="directory-context-bar" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "1rem" }}>
        <div>
          <p>
            <strong>School Announcements &amp; Broadcasts</strong> · Dispatch high-priority notices, circulars, and reminders directly to parent and teacher mobile apps.
          </p>
        </div>
        <div style={{ display: "flex", gap: "0.75rem", alignItems: "center" }}>
          <button
            type="button"
            className="btn-primary"
            onClick={() => setTab("create")}
            style={{ fontSize: "0.85rem", display: "inline-flex", alignItems: "center", gap: "0.35rem", padding: "0.4rem 0.85rem" }}
          >
            <Plus size={15} /> New Announcement
          </button>
          <button
            type="button"
            className="btn-secondary"
            onClick={() => void load()}
            style={{ fontSize: "0.85rem", display: "inline-flex", alignItems: "center", gap: "0.35rem", padding: "0.4rem 0.75rem" }}
          >
            <RefreshCw size={14} /> Refresh
          </button>
        </div>
      </div>

      {error && (
        <div className="ops-inline-error" role="alert" style={{ margin: "1rem 0" }}>
          <CircleAlert size={16} />
          {error}
        </div>
      )}

      {/* Tabs */}
      <nav className="finance-tabs" aria-label="Notices views">
        <button
          type="button"
          className={tab === "all" ? "active" : ""}
          onClick={() => setTab("all")}
        >
          Broadcast History ({notices.length})
        </button>
        <button
          type="button"
          className={tab === "create" ? "active" : ""}
          onClick={() => setTab("create")}
        >
          Create Announcement
        </button>
      </nav>

      {loading ? (
        <PortalModuleSkeleton variant="cards" label="Loading notices" />
      ) : tab === "all" ? (
        /* BROADCAST HISTORY */
        <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.25rem" }}>
          <div style={{ marginBottom: "1rem" }}>
            <h3 style={{ margin: 0, fontSize: "1.1rem", fontWeight: 700 }}>Published Announcements &amp; Circulars</h3>
            <p style={{ margin: "0.2rem 0 0", color: "var(--ops-muted)", fontSize: "0.85rem" }}>
              Log of pushed announcements delivered to registered users and notification subscribers.
            </p>
          </div>

          <div className="ops-table-wrap" style={{ overflowX: "auto" }}>
            <table className="ops-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr style={{ background: "var(--ops-surface-subtle, #f8fafc)", borderBottom: "1px solid var(--ops-border, #e2e8f0)", textAlign: "left" }}>
                  <th style={{ padding: "0.75rem 1rem" }}>Announcement</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Target Audience</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Broadcast Date</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "center" }}>Delivery</th>
                </tr>
              </thead>
              <tbody>
                {notices.length === 0 ? (
                  <tr>
                    <td colSpan={4} style={{ textAlign: "center", padding: "3rem", color: "var(--ops-muted)" }}>
                      <Megaphone size={36} style={{ color: "#0e5ea8", margin: "0 auto 0.5rem", display: "block", opacity: 0.6 }} />
                      <strong>No broadcasts dispatched yet</strong>
                      <p style={{ fontSize: "0.8rem", marginTop: "0.25rem" }}>Click "Create Announcement" to send your first official school notice.</p>
                    </td>
                  </tr>
                ) : (
                  notices.map((n) => (
                    <tr key={n.id} style={{ borderBottom: "1px solid var(--ops-border, #f1f5f9)" }}>
                      <td style={{ padding: "0.75rem 1rem" }}>
                        <div style={{ fontWeight: 600 }}>{n.title}</div>
                        <div style={{ fontSize: "0.8rem", color: "var(--ops-muted)", marginTop: "0.25rem", maxWidth: "500px", lineHeight: 1.4 }}>
                          {n.message || n.body}
                        </div>
                      </td>
                      <td style={{ padding: "0.75rem 1rem" }}>
                        <span
                          style={{
                            padding: "0.2rem 0.5rem",
                            borderRadius: "9999px",
                            fontSize: "0.75rem",
                            fontWeight: 600,
                            background: "#eff6ff",
                            color: "#1e40af",
                            textTransform: "capitalize",
                          }}
                        >
                          {(n.roles || n.target_roles || ["All"]).join(", ")}
                        </span>
                      </td>
                      <td style={{ padding: "0.75rem 1rem", color: "var(--ops-muted)" }}>
                        {formatDateTime(n.created_at)}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", textAlign: "center" }}>
                        <span
                          style={{
                            display: "inline-flex",
                            alignItems: "center",
                            gap: "0.3rem",
                            padding: "0.2rem 0.5rem",
                            borderRadius: "9999px",
                            fontSize: "0.75rem",
                            fontWeight: 600,
                            background: "#dcfce7",
                            color: "#166534",
                          }}
                        >
                          <CheckCircle2 size={12} /> Dispatched
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        /* CREATE ANNOUNCEMENT FORM */
        <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.75rem", maxWidth: "680px" }}>
          <div style={{ display: "flex", gap: "0.75rem", alignItems: "center", marginBottom: "1.25rem" }}>
            <Megaphone size={24} style={{ color: "#0e5ea8" }} />
            <div>
              <h3 style={{ margin: 0, fontSize: "1.15rem", fontWeight: 700 }}>Dispatch School Notice</h3>
              <p style={{ margin: "0.2rem 0 0", color: "var(--ops-muted)", fontSize: "0.85rem" }}>
                Send push notifications and broadcast alerts directly to parent and teacher mobile apps.
              </p>
            </div>
          </div>

          <form onSubmit={handleBroadcast}>
            <div style={{ display: "flex", flexDirection: "column", gap: "1.25rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Announcement Title:
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Early Dismissal for Annual Sports Meet Rehearsal"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem" }}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Target Recipients:
                </label>
                <select
                  value={targetRole}
                  onChange={(e) => setTargetRole(e.target.value as "all" | "teacher" | "parent")}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem" }}
                >
                  <option value="all">All School Community (Parents &amp; Teachers)</option>
                  <option value="parent">Parents Only</option>
                  <option value="teacher">Teachers &amp; Staff Only</option>
                </select>
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Announcement Message:
                </label>
                <textarea
                  required
                  rows={4}
                  placeholder="Provide complete circular details, timings, and instructions for parents/staff..."
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem", resize: "vertical" }}
                />
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "0.5rem" }}>
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={() => setTab("all")}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn-primary"
                  disabled={submitting || !title.trim() || !message.trim()}
                  style={{ display: "inline-flex", alignItems: "center", gap: "0.4rem" }}
                >
                  <Send size={14} /> {submitting ? "Broadcasting..." : "Broadcast Notice"}
                </button>
              </div>
            </div>
          </form>
        </div>
      )}
    </section>
  );
}

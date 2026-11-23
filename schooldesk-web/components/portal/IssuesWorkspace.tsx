"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CheckCircle2,
  CircleAlert,
  Clock,
  Eye,
  Plus,
  RefreshCw,
  Search,
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

type IssueItem = {
  id: string;
  title: string;
  description: string;
  category: string;
  priority: string;
  status: "pending" | "in_progress" | "resolved" | string;
  raised_by?: string;
  raised_by_role?: string;
  resolution_note?: string;
  resolved_at?: string;
  created_at: string;
  updated_at?: string;
  issue_attachments?: Array<{
    id: string;
    file_name: string;
    mime_type: string;
    file_size: number;
    storage_path: string;
  }>;
};

export function IssuesWorkspace({
  role,
  onNotify,
}: {
  role: PortalRole;
  onNotify: (message: string, type?: "success" | "error" | "info") => void;
}) {
  const [tab, setTab] = usePortalTab<"open" | "investigating" | "resolved">("issues", "open");
  const [issues, setIssues] = useState<IssueItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");

  // Modals
  const [selectedIssue, setSelectedIssue] = useState<IssueItem | null>(null);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [resolutionText, setResolutionText] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const res = await api("issues").catch(() => ({ data: [] }));
      const rows = Array.isArray(res) ? res : Array.isArray((res as { data?: unknown })?.data) ? (res as { data: unknown[] }).data : [];
      setIssues(rows as IssueItem[]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load issues");
    } finally {
      setLoading(false);
    }
  }, []);

  usePortalRefresh(load);

  useEffect(() => {
    void load();
  }, [load]);

  // Filtered issues based on status tab and search
  const filteredIssues = useMemo(() => {
    return issues.filter((item) => {
      if (tab === "open" && item.status !== "pending") return false;
      if (tab === "investigating" && item.status !== "in_progress") return false;
      if (tab === "resolved" && item.status !== "resolved") return false;

      if (search.trim()) {
        const q = search.toLowerCase();
        const matchesTitle = item.title.toLowerCase().includes(q);
        const matchesCategory = item.category.toLowerCase().includes(q);
        const matchesDesc = item.description.toLowerCase().includes(q);
        if (!matchesTitle && !matchesCategory && !matchesDesc) return false;
      }
      return true;
    });
  }, [issues, tab, search]);

  // Handle Create Issue
  const handleCreateIssue = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setActionLoading(true);
    const form = new FormData(e.currentTarget);
    const title = form.get("title") as string;
    const description = form.get("description") as string;
    const category = form.get("category") as string;
    const priority = form.get("priority") as string;

    try {
      await api("issues", {
        method: "POST",
        body: JSON.stringify({
          title,
          description,
          category,
          priority,
        }),
      });

      onNotify("Grievance ticket registered successfully", "success");
      setShowCreateModal(false);
      await load();
    } catch (err) {
      onNotify(err instanceof Error ? err.message : "Failed to register issue", "error");
    } finally {
      setActionLoading(false);
    }
  };

  // Status transition (resolve / investigate)
  const handleUpdateStatus = async (issueId: string, nextStatus: "in_progress" | "resolved") => {
    if (nextStatus === "resolved" && !resolutionText.trim()) {
      onNotify("Please provide resolution notes before closing the ticket", "error");
      return;
    }

    setActionLoading(true);
    try {
      await api(`issues/${issueId}`, {
        method: "PATCH",
        body: JSON.stringify({
          status: nextStatus,
          resolution_note: resolutionText.trim() || undefined,
        }),
      });

      onNotify(`Ticket updated to ${nextStatus.replace("_", " ")}`, "success");
      setSelectedIssue(null);
      setResolutionText("");
      await load();
    } catch (err) {
      onNotify(err instanceof Error ? err.message : "Failed to update ticket", "error");
    } finally {
      setActionLoading(false);
    }
  };

  const statusCounts = useMemo(() => {
    let open = 0;
    let investigating = 0;
    let resolved = 0;
    for (const i of issues) {
      if (i.status === "pending") open += 1;
      else if (i.status === "in_progress") investigating += 1;
      else if (i.status === "resolved") resolved += 1;
    }
    return { open, investigating, resolved };
  }, [issues]);

  return (
    <section className="ops-module issues-workspace" aria-busy={loading}>
      <div className="directory-context-bar" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "1rem" }}>
        <div>
          <p>
            <strong>Grievance &amp; Issue Desk</strong> · Track parent feedback, staff concerns, infrastructure repairs, and escalation status.
          </p>
        </div>
        <div style={{ display: "flex", gap: "0.75rem", alignItems: "center" }}>
          <button
            type="button"
            className="btn-primary"
            onClick={() => setShowCreateModal(true)}
            style={{ fontSize: "0.85rem", display: "inline-flex", alignItems: "center", gap: "0.35rem", padding: "0.4rem 0.85rem" }}
          >
            <Plus size={15} /> Log Grievance Ticket
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
      <nav className="finance-tabs" aria-label="Issue statuses">
        <button
          type="button"
          className={tab === "open" ? "active" : ""}
          onClick={() => setTab("open")}
        >
          Open Tickets ({statusCounts.open})
        </button>
        <button
          type="button"
          className={tab === "investigating" ? "active" : ""}
          onClick={() => setTab("investigating")}
        >
          Under Investigation ({statusCounts.investigating})
        </button>
        <button
          type="button"
          className={tab === "resolved" ? "active" : ""}
          onClick={() => setTab("resolved")}
        >
          Resolved &amp; Closed ({statusCounts.resolved})
        </button>
      </nav>

      {/* Search Toolbar */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", margin: "1.25rem 0", gap: "1rem", flexWrap: "wrap" }}>
        <div style={{ position: "relative", flex: 1, maxWidth: "340px" }}>
          <Search size={16} style={{ position: "absolute", left: "10px", top: "50%", transform: "translateY(-50%)", color: "var(--ops-muted)" }} />
          <input
            type="text"
            placeholder="Search tickets by subject, category, or note..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="ops-search-input"
            style={{ width: "100%", paddingLeft: "32px", fontSize: "0.85rem" }}
          />
        </div>
        <div style={{ fontSize: "0.85rem", color: "var(--ops-muted)" }}>
          Showing {filteredIssues.length} tickets
        </div>
      </div>

      {loading ? (
        <PortalModuleSkeleton variant="cards" label="Loading issues" />
      ) : (
        <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.25rem" }}>
          <div className="ops-table-wrap" style={{ overflowX: "auto" }}>
            <table className="ops-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr style={{ background: "var(--ops-surface-subtle, #f8fafc)", borderBottom: "1px solid var(--ops-border, #e2e8f0)", textAlign: "left" }}>
                  <th style={{ padding: "0.75rem 1rem" }}>Ticket Title</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Category</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "center" }}>Priority</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Raised By</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Created Date</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "right" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredIssues.length === 0 ? (
                  <tr>
                    <td colSpan={6} style={{ textAlign: "center", padding: "3rem", color: "var(--ops-muted)" }}>
                      <CheckCircle2 size={36} style={{ color: "#16a34a", margin: "0 auto 0.5rem", display: "block" }} />
                      <strong>No issues in this view</strong>
                      <p style={{ fontSize: "0.8rem", marginTop: "0.25rem" }}>All tickets in this category have been addressed.</p>
                    </td>
                  </tr>
                ) : (
                  filteredIssues.map((item) => (
                    <tr key={item.id} style={{ borderBottom: "1px solid var(--ops-border, #f1f5f9)" }}>
                      <td style={{ padding: "0.75rem 1rem" }}>
                        <div style={{ fontWeight: 600 }}>{item.title}</div>
                        <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)", marginTop: "0.2rem", maxWidth: "400px", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                          {item.description}
                        </div>
                      </td>
                      <td style={{ padding: "0.75rem 1rem" }}>
                        <span
                          style={{
                            padding: "0.2rem 0.5rem",
                            borderRadius: "4px",
                            fontSize: "0.75rem",
                            fontWeight: 600,
                            background: "#f1f5f9",
                            color: "#475569",
                            textTransform: "capitalize",
                          }}
                        >
                          {item.category || "General"}
                        </span>
                      </td>
                      <td style={{ padding: "0.75rem 1rem", textAlign: "center" }}>
                        <span
                          style={{
                            padding: "0.2rem 0.5rem",
                            borderRadius: "4px",
                            fontSize: "0.75rem",
                            fontWeight: 700,
                            textTransform: "uppercase",
                            background:
                              item.priority === "urgent" || item.priority === "high"
                                ? "#fee2e2"
                                : item.priority === "medium"
                                ? "#fef3c7"
                                : "#dcfce7",
                            color:
                              item.priority === "urgent" || item.priority === "high"
                                ? "#b91c1c"
                                : item.priority === "medium"
                                ? "#b45309"
                                : "#15803d",
                          }}
                        >
                          {item.priority}
                        </span>
                      </td>
                      <td style={{ padding: "0.75rem 1rem", textTransform: "capitalize" }}>
                        {item.raised_by_role || "User"}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", color: "var(--ops-muted)" }}>
                        {formatDateTime(item.created_at)}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", textAlign: "right" }}>
                        <button
                          type="button"
                          className="btn-secondary"
                          onClick={() => {
                            setSelectedIssue(item);
                            setResolutionText(item.resolution_note || "");
                          }}
                          style={{ padding: "0.35rem 0.65rem", fontSize: "0.8rem", display: "inline-flex", alignItems: "center", gap: "0.3rem" }}
                        >
                          <Eye size={13} /> View Ticket
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* CREATE GRIEVANCE MODAL */}
      {showCreateModal && (
        <Dialog
          kicker="Grievance Registry"
          title="Log New Grievance Ticket"
          onClose={() => setShowCreateModal(false)}
        >
          <form onSubmit={handleCreateIssue}>
            <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Issue Subject / Title:
                </label>
                <input
                  name="title"
                  type="text"
                  required
                  placeholder="e.g. Broken playground swing latch in Montessori area"
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.85rem" }}
                />
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                    Category:
                  </label>
                  <select
                    name="category"
                    className="ops-search-input"
                    style={{ width: "100%", fontSize: "0.85rem" }}
                  >
                    <option value="facilities">Facilities &amp; Campus</option>
                    <option value="academics">Academics &amp; Curriculum</option>
                    <option value="transport">Transport &amp; Bus Route</option>
                    <option value="fees">Fees &amp; Billing</option>
                    <option value="safety">Safety &amp; Health</option>
                    <option value="other">Other / General</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                    Priority:
                  </label>
                  <select
                    name="priority"
                    defaultValue="medium"
                    className="ops-search-input"
                    style={{ width: "100%", fontSize: "0.85rem" }}
                  >
                    <option value="low">Low</option>
                    <option value="medium">Medium</option>
                    <option value="high">High</option>
                    <option value="urgent">Urgent</option>
                  </select>
                </div>
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Detailed Description &amp; Incident Information:
                </label>
                <textarea
                  name="description"
                  required
                  rows={4}
                  placeholder="Explain the background, affected students or staff, and required action..."
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.85rem", resize: "vertical" }}
                />
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "0.5rem" }}>
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={() => setShowCreateModal(false)}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn-primary"
                  disabled={actionLoading}
                >
                  {actionLoading ? "Registering..." : "Submit Grievance Ticket"}
                </button>
              </div>
            </div>
          </form>
        </Dialog>
      )}

      {/* TICKET DETAIL & RESOLUTION MODAL */}
      {selectedIssue && (
        <Dialog
          kicker="Ticket Investigation"
          title={`Ticket #${selectedIssue.id.slice(0, 8)} · ${selectedIssue.title}`}
          onClose={() => setSelectedIssue(null)}
        >
          <div style={{ display: "flex", flexDirection: "column", gap: "1rem", fontSize: "0.875rem" }}>
            <div style={{ display: "flex", justifyContent: "space-between", background: "var(--ops-surface-subtle, #f8fafc)", padding: "0.75rem", borderRadius: "6px" }}>
              <div>
                <strong>Category:</strong> {selectedIssue.category} | <strong>Priority:</strong> {selectedIssue.priority}
              </div>
              <div>
                <strong>Raised By:</strong> {selectedIssue.raised_by_role} on {formatDateTime(selectedIssue.created_at)}
              </div>
            </div>

            <div>
              <strong>Description:</strong>
              <p style={{ marginTop: "0.35rem", color: "var(--ops-muted)", lineHeight: 1.5, background: "#f8fafc", padding: "0.75rem", borderRadius: "6px" }}>
                {selectedIssue.description}
              </p>
            </div>

            {selectedIssue.status === "resolved" ? (
              <div style={{ background: "#f0fdf4", border: "1px solid #bbf7d0", padding: "0.75rem", borderRadius: "6px" }}>
                <div style={{ fontWeight: 600, color: "#166534" }}>Resolved Notes:</div>
                <p style={{ margin: "0.25rem 0 0", color: "#15803d" }}>{selectedIssue.resolution_note || "Resolved by leadership."}</p>
                {selectedIssue.resolved_at && (
                  <div style={{ fontSize: "0.75rem", color: "#166534", marginTop: "0.35rem" }}>
                    Closed on {formatDateTime(selectedIssue.resolved_at)}
                  </div>
                )}
              </div>
            ) : (
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Resolution Notes / Action Taken:
                </label>
                <textarea
                  rows={3}
                  placeholder="Record investigation findings, contractor dispatched, or corrective measures taken..."
                  value={resolutionText}
                  onChange={(e) => setResolutionText(e.target.value)}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.85rem", resize: "vertical" }}
                />
              </div>
            )}

            <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "0.5rem" }}>
              <button
                type="button"
                className="btn-secondary"
                onClick={() => setSelectedIssue(null)}
              >
                Close
              </button>

              {selectedIssue.status === "pending" && (
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={() => handleUpdateStatus(selectedIssue.id, "in_progress")}
                  disabled={actionLoading}
                >
                  Mark In Progress
                </button>
              )}

              {selectedIssue.status !== "resolved" && (
                <button
                  type="button"
                  className="btn-primary"
                  onClick={() => handleUpdateStatus(selectedIssue.id, "resolved")}
                  disabled={actionLoading || !resolutionText.trim()}
                  style={{ background: "#16a34a", borderColor: "#15803d" }}
                >
                  {actionLoading ? "Resolving..." : "Mark as Resolved"}
                </button>
              )}
            </div>
          </div>
        </Dialog>
      )}
    </section>
  );
}

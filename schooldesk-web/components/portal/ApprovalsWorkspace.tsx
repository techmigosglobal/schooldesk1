"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CheckCircle2,
  CheckSquare,
  CircleAlert,
  Clock,
  Eye,
  Filter,
  RefreshCw,
  Search,
  UserCheck,
  X,
  XCircle,
} from "@/lib/lucide-react";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import { usePortalRefresh } from "./use-portal-refresh";
import { usePortalTab } from "./PortalStateProvider";
import type { PortalRole } from "@/lib/roles";
import type { Row } from "./types";
import { api, formatDateTime, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";

type ApprovalItem = Row & {
  id: string;
  type: string;
  requesterName?: string;
  requesterRole?: string;
  requesterClass?: string;
  submittedDate?: string;
  summary?: string;
  details?: string;
  status: string;
  remarks?: string | null;
  decisionPath?: string;
  proof_url?: string;
  amount?: number | string;
};

export function ApprovalsWorkspace({
  role,
  onNotify,
}: {
  role: PortalRole;
  onNotify: (message: string, type?: "success" | "error" | "info") => void;
}) {
  const [tab, setTab] = usePortalTab<
    "all" | "payments" | "staff_leaves" | "student_leaves" | "posts" | "reopens" | "history"
  >("approvals", "all");
  const [items, setItems] = useState<ApprovalItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [submittingId, setSubmittingId] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");

  // Rejection modal state
  const [rejectingItem, setRejectingItem] = useState<ApprovalItem | null>(null);
  const [rejectionReason, setRejectionReason] = useState("");

  // Detail / Screenshot preview modal state
  const [previewItem, setPreviewItem] = useState<ApprovalItem | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const statusParam = tab === "history" ? "all" : "pending";
      const feed = await api(`approvals/feed?status=${statusParam}&page_size=100`);
      const payload = (feed as { data?: Row[]; meta?: { pending_count?: number } }) ?? {};
      const rows = (Array.isArray(payload.data) ? payload.data : rowsFrom(feed)) as ApprovalItem[];
      setItems(rows);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load approval queue");
    } finally {
      setLoading(false);
    }
  }, [tab]);

  usePortalRefresh(load);

  useEffect(() => {
    void load();
  }, [load]);

  async function handleDecision(item: ApprovalItem, action: "approve" | "reject", reason?: string) {
    setSubmittingId(item.id);
    try {
      const type = stringValue(item.type).toLowerCase();
      const id = encodeURIComponent(stringValue(item.id));

      if (type === "account") {
        await api(`account-approvals/${id}/${action}`, {
          method: "POST",
          body: JSON.stringify(action === "reject" ? { rejection_reason: reason } : {}),
        });
      } else if (type === "leave") {
        await api(`leave/applications/${id}/${action}`, {
          method: "POST",
          body: JSON.stringify(action === "reject" ? { note: reason } : {}),
        });
      } else if (type === "student_leave") {
        await api(`student-leave/applications/${id}/decision`, {
          method: "PUT",
          body: JSON.stringify({
            status: action === "approve" ? "approved" : "rejected",
            ...(action === "reject" ? { rejection_reason: reason } : {}),
          }),
        });
      } else if (type === "fee" || type === "payment") {
        await api(`fees/payment-requests/${id}/decision`, {
          method: "PUT",
          body: JSON.stringify({
            status: action === "approve" ? "approved" : "rejected",
            ...(reason ? { admin_remarks: reason } : {}),
          }),
        });
      } else if (type === "event") {
        await api(`event-posts/${id}/${action}`, {
          method: "POST",
          body: JSON.stringify(action === "reject" ? { reason } : {}),
        });
      } else if (type === "fee_concession") {
        await api(`fees/concessions/${id}/decision`, {
          method: "POST",
          body: JSON.stringify({
            decision: action,
            ...(action === "reject" ? { rejection_reason: reason } : {}),
          }),
        });
      } else {
        await api(`approvals/${id}/${action}`, {
          method: "POST",
          body: JSON.stringify(reason ? { review_note: reason } : {}),
        });
      }

      onNotify(
        action === "approve"
          ? `${stringValue(item.summary ?? "Request")} approved successfully.`
          : `${stringValue(item.summary ?? "Request")} rejected.`,
        "success"
      );

      // Optimistically update list
      setItems((prev) => prev.filter((row) => row.id !== item.id));
      setRejectingItem(null);
      setRejectionReason("");
    } catch (err) {
      onNotify(
        err instanceof Error ? err.message : `Failed to ${action} request. Please retry.`,
        "error"
      );
    } finally {
      setSubmittingId(null);
    }
  }

  const categoryCounts = useMemo(() => {
    const counts = {
      all: 0,
      payments: 0,
      staff_leaves: 0,
      student_leaves: 0,
      posts: 0,
      reopens: 0,
    };
    for (const item of items) {
      if (item.status === "pending") {
        counts.all++;
        const type = stringValue(item.type).toLowerCase();
        if (type === "fee" || type === "payment" || type === "fee_concession") counts.payments++;
        else if (type === "leave") counts.staff_leaves++;
        else if (type === "student_leave") counts.student_leaves++;
        else if (type === "event") counts.posts++;
        else if (type.includes("reopen") || type.includes("attendance")) counts.reopens++;
      }
    }
    return counts;
  }, [items]);

  const visibleItems = useMemo(() => {
    const q = search.trim().toLowerCase();
    return items.filter((item) => {
      // Status filtering
      if (tab === "history") {
        if (item.status === "pending") return false;
      } else {
        if (item.status !== "pending") return false;
      }

      // Tab category filtering
      const type = stringValue(item.type).toLowerCase();
      if (tab === "payments" && !(type === "fee" || type === "payment" || type === "fee_concession"))
        return false;
      if (tab === "staff_leaves" && type !== "leave") return false;
      if (tab === "student_leaves" && type !== "student_leave") return false;
      if (tab === "posts" && type !== "event") return false;
      if (tab === "reopens" && !(type.includes("reopen") || type.includes("attendance")))
        return false;

      // Text query filtering
      if (!q) return true;
      const haystack = [
        item.requesterName,
        item.requesterRole,
        item.requesterClass,
        item.summary,
        item.details,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return haystack.includes(q);
    });
  }, [items, tab, search]);

  function typeBadge(type: string) {
    const t = type.toLowerCase();
    let bg = "#e5f3ff";
    let color = "#0d63a9";
    let label = "Request";

    if (t === "leave") {
      bg = "#eafaf1";
      color = "#187a41";
      label = "Staff Leave";
    } else if (t === "student_leave") {
      bg = "#fef3c7";
      color = "#92400e";
      label = "Student Leave";
    } else if (t === "fee" || t === "payment") {
      bg = "#ede9fe";
      color = "#5b21b6";
      label = "Payment Proof";
    } else if (t === "fee_concession") {
      bg = "#ede9fe";
      color = "#5b21b6";
      label = "Concession";
    } else if (t === "event") {
      bg = "#fce7f3";
      color = "#9d174d";
      label = "School Post";
    } else if (t === "account") {
      bg = "#e0f2fe";
      color = "#0369a1";
      label = "Account Access";
    } else if (t.includes("reopen") || t.includes("attendance")) {
      bg = "#ffedd5";
      color = "#9a3412";
      label = "Attendance Reopen";
    }

    return (
      <span
        style={{
          display: "inline-block",
          padding: "0.2rem 0.55rem",
          borderRadius: "6px",
          fontSize: "0.7rem",
          fontWeight: 750,
          background: bg,
          color,
          letterSpacing: "0.02em",
          textTransform: "uppercase",
        }}
      >
        {label}
      </span>
    );
  }

  return (
    <section className="ops-module approvals-workspace" aria-busy={loading}>
      <div className="directory-context-bar">
        <p>
          Unified Approval Center · Review and authorize staff leaves, student leaves, school posts,
          attendance reopens, and payment verifications.
        </p>
      </div>

      {error && (
        <div className="ops-inline-error" role="alert">
          <CircleAlert size={16} />
          {error}
        </div>
      )}

      {/* Tabs */}
      <nav className="finance-tabs" aria-label="Approval categories">
        <button
          type="button"
          className={tab === "all" ? "active" : ""}
          onClick={() => setTab("all")}
        >
          All Pending ({categoryCounts.all})
        </button>
        {role === "principal" && (
          <button
            type="button"
            className={tab === "payments" ? "active" : ""}
            onClick={() => setTab("payments")}
          >
            Payments ({categoryCounts.payments})
          </button>
        )}
        <button
          type="button"
          className={tab === "staff_leaves" ? "active" : ""}
          onClick={() => setTab("staff_leaves")}
        >
          Staff Leaves ({categoryCounts.staff_leaves})
        </button>
        <button
          type="button"
          className={tab === "student_leaves" ? "active" : ""}
          onClick={() => setTab("student_leaves")}
        >
          Student Leaves ({categoryCounts.student_leaves})
        </button>
        <button
          type="button"
          className={tab === "posts" ? "active" : ""}
          onClick={() => setTab("posts")}
        >
          School Posts ({categoryCounts.posts})
        </button>
        <button
          type="button"
          className={tab === "reopens" ? "active" : ""}
          onClick={() => setTab("reopens")}
        >
          Attendance Reopens ({categoryCounts.reopens})
        </button>
        <button
          type="button"
          className={tab === "history" ? "active" : ""}
          onClick={() => setTab("history")}
        >
          Decision History
        </button>
      </nav>

      {/* Search and summary bar */}
      <div className="ops-inquiry-toolbar" style={{ margin: "0.75rem 0 1rem" }}>
        <label className="search-input">
          <Search size={16} />
          <input
            type="search"
            aria-label="Search approvals"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by requester, student, role, or summary…"
          />
        </label>
        {search && (
          <button type="button" className="secondary-button" onClick={() => setSearch("")}>
            Clear search
          </button>
        )}
        <span style={{ fontSize: "0.82rem", color: "#627d98" }}>
          Showing <b>{visibleItems.length}</b> {visibleItems.length === 1 ? "item" : "items"}
        </span>
      </div>

      {/* Content list */}
      {loading ? (
        <PortalModuleSkeleton variant="cards" label="Loading approval requests" />
      ) : visibleItems.length === 0 ? (
        <div className="ops-empty-state surface" style={{ padding: "3rem 1.5rem", textAlign: "center" }}>
          <CheckSquare size={40} style={{ color: "#227c44", margin: "0 auto 0.75rem" }} />
          <h3>All caught up!</h3>
          <p style={{ color: "#627d98" }}>
            {tab === "history"
              ? "No decided approval records found."
              : "There are no pending approval requests matching this filter."}
          </p>
        </div>
      ) : (
        <div className="request-list surface" style={{ borderRadius: "12px", overflow: "hidden" }}>
          {visibleItems.map((item) => {
            const isSubmitting = submittingId === item.id;
            const detailsLines = stringValue(item.details).split("\n").filter(Boolean);

            return (
              <article
                key={item.id}
                style={{
                  display: "flex",
                  alignItems: "flex-start",
                  justifyContent: "space-between",
                  padding: "1.2rem 1.35rem",
                  borderBottom: "1px solid #edf2f6",
                  gap: "1.5rem",
                }}
              >
                <div style={{ display: "grid", gap: "0.4rem", flex: 1 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "0.6rem" }}>
                    {typeBadge(item.type)}
                    <b style={{ fontSize: "0.95rem", color: "#193f5c" }}>
                      {stringValue(item.summary ?? "Approval Request")}
                    </b>
                    {item.status !== "pending" && (
                      <span
                        style={{
                          fontSize: "0.72rem",
                          fontWeight: 700,
                          padding: "0.15rem 0.45rem",
                          borderRadius: "4px",
                          background: item.status === "approved" ? "#e6f4ea" : "#fce8e6",
                          color: item.status === "approved" ? "#137333" : "#c5221f",
                          textTransform: "capitalize",
                        }}
                      >
                        {item.status}
                      </span>
                    )}
                  </div>

                  <div style={{ fontSize: "0.82rem", color: "#4f6575" }}>
                    <b>{stringValue(item.requesterName || "Requester")}</b>
                    {item.requesterRole && <span> · {stringValue(item.requesterRole)}</span>}
                    {item.requesterClass && <span> · {stringValue(item.requesterClass)}</span>}
                  </div>

                  {detailsLines.length > 0 && (
                    <div style={{ fontSize: "0.8rem", color: "#5a6e7f", lineHeight: 1.5 }}>
                      {detailsLines.map((line, lIdx) => (
                        <div key={lIdx}>{line}</div>
                      ))}
                    </div>
                  )}

                  {item.submittedDate && (
                    <small style={{ fontSize: "0.72rem", color: "#8aa0af" }}>
                      Submitted: {formatDateTime(item.submittedDate)}
                    </small>
                  )}
                </div>

                {item.status === "pending" && (
                  <div style={{ display: "flex", gap: "0.5rem", flexShrink: 0, marginTop: "0.2rem" }}>
                    <button
                      type="button"
                      className="primary-button"
                      onClick={() => void handleDecision(item, "approve")}
                      disabled={isSubmitting}
                      style={{
                        padding: "0.5rem 0.85rem",
                        fontSize: "0.8rem",
                        background: "#187a41",
                        borderColor: "#187a41",
                        display: "inline-flex",
                        alignItems: "center",
                        gap: "0.35rem",
                      }}
                    >
                      <CheckCircle2 size={15} />
                      {isSubmitting ? "Saving…" : "Approve"}
                    </button>

                    <button
                      type="button"
                      className="secondary-button"
                      onClick={() => setRejectingItem(item)}
                      disabled={isSubmitting}
                      style={{
                        padding: "0.5rem 0.85rem",
                        fontSize: "0.8rem",
                        color: "#c5221f",
                        borderColor: "#f5c2c7",
                        display: "inline-flex",
                        alignItems: "center",
                        gap: "0.35rem",
                      }}
                    >
                      <XCircle size={15} />
                      Reject
                    </button>
                  </div>
                )}
              </article>
            );
          })}
        </div>
      )}

      {/* Rejection Remarks Modal */}
      {rejectingItem && (
        <Dialog
          kicker="Approvals Decision"
          title={`Reject ${stringValue(rejectingItem.summary ?? "Request")}`}
          onClose={() => {
            setRejectingItem(null);
            setRejectionReason("");
          }}
        >
          <div style={{ display: "grid", gap: "1rem" }}>
            <p style={{ margin: 0, fontSize: "0.85rem", color: "#4f6575" }}>
              Please provide a reason for rejecting this request. This reason will be logged and
              sent to the requester.
            </p>

            <label className="field" style={{ display: "grid", gap: "0.35rem" }}>
              <span style={{ fontSize: "0.8rem", fontWeight: 700 }}>Rejection Reason</span>
              <textarea
                rows={3}
                value={rejectionReason}
                onChange={(e) => setRejectionReason(e.target.value)}
                placeholder="e.g. Schedule conflict, incorrect amount, clarification needed…"
                style={{
                  width: "100%",
                  padding: "0.6rem",
                  borderRadius: "8px",
                  border: "1px solid #c9d9df",
                  fontSize: "0.85rem",
                }}
              />
            </label>

            <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.5rem", marginTop: "0.5rem" }}>
              <button
                type="button"
                className="secondary-button"
                onClick={() => {
                  setRejectingItem(null);
                  setRejectionReason("");
                }}
              >
                Cancel
              </button>
              <button
                type="button"
                className="primary-button"
                style={{ background: "#c5221f", borderColor: "#c5221f" }}
                onClick={() => void handleDecision(rejectingItem, "reject", rejectionReason)}
                disabled={submittingId === rejectingItem.id}
              >
                {submittingId === rejectingItem.id ? "Rejecting…" : "Confirm Rejection"}
              </button>
            </div>
          </div>
        </Dialog>
      )}
    </section>
  );
}

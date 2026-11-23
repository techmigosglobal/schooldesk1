"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { GraduationCap, Phone, Search, Send, UserCheck } from "@/lib/lucide-react";
import { PortalModuleSkeleton } from "@/components/loading-skeletons";
import { usePortalRefresh } from "./use-portal-refresh";
import { usePortalState } from "./PortalStateProvider";
import type { Row } from "./types";
import { apiAll, formatDateTime, stringValue } from "./utils";

export function AdmissionInquiriesWorkspace({
  onNavigateToStudents,
}: {
  onNavigateToStudents?: () => void;
}) {
  const [rows, setRows] = useState<Row[]>([]);
  const [selectedId, setSelectedId] = useState("");
  const [query, setQuery] = usePortalState("admissions.query", "");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [statuses, setStatuses] = useState<Record<string, string>>({});

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      setRows(await apiAll("admission-inquiries"));
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load admission inquiries");
    } finally {
      setLoading(false);
    }
  }, []);

  usePortalRefresh(load);

  useEffect(() => {
    void load();
  }, [load]);

  const visible = useMemo(
    () =>
      rows.filter((row) =>
        Object.values(row).join(" ").toLowerCase().includes(query.trim().toLowerCase())
      ),
    [rows, query]
  );

  const selected = visible.find((row) => stringValue(row.id) === selectedId) ?? visible[0];

  const handleStatusChange = (inquiryId: string, status: string) => {
    setStatuses((prev) => ({ ...prev, [inquiryId]: status }));
  };

  return (
    <section className="ops-module admission-inquiries">
      <div className="directory-context-bar">
        <p>Inquiries submitted through the public website.</p>
      </div>
      {error && <p className="ops-inline-error">{error}</p>}
      <div className="ops-inquiry-toolbar">
        <label className="search-input">
          <Search size={16} />
          <input
            type="search"
            aria-label="Search admission inquiries"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search parent, child, phone, or program"
          />
        </label>
        {query && (
          <button type="button" className="secondary-button" onClick={() => setQuery("")}>
            Reset filters
          </button>
        )}
        <span>
          {visible.length} {visible.length === 1 ? "inquiry" : "inquiries"}
        </span>
      </div>
      {loading ? (
        <PortalModuleSkeleton variant="split" label="Loading admission inquiries" />
      ) : (
        <div className="ops-inquiry-layout">
          <div className="ops-inquiry-list">
            {visible.length ? (
              visible.map((row) => {
                const rowId = stringValue(row.id);
                const currentStatus = statuses[rowId] || stringValue(row.status) || "new";
                return (
                  <button
                    type="button"
                    key={rowId}
                    className={selected?.id === row.id ? "active" : ""}
                    aria-pressed={selected?.id === row.id}
                    onClick={() => setSelectedId(rowId)}
                  >
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                      <b>{stringValue(row.parent_name)}</b>
                      <span
                        style={{
                          fontSize: "0.7rem",
                          padding: "0.1rem 0.4rem",
                          borderRadius: "4px",
                          fontWeight: 600,
                          textTransform: "capitalize",
                          background:
                            currentStatus === "enrolled"
                              ? "#dcfce7"
                              : currentStatus === "contacted"
                              ? "#eff6ff"
                              : currentStatus === "tour"
                              ? "#fef3c7"
                              : "#f1f5f9",
                          color:
                            currentStatus === "enrolled"
                              ? "#15803d"
                              : currentStatus === "contacted"
                              ? "#1e40af"
                              : currentStatus === "tour"
                              ? "#b45309"
                              : "#475569",
                        }}
                      >
                        {currentStatus === "tour" ? "Tour Scheduled" : currentStatus}
                      </span>
                    </div>
                    <span>
                      {stringValue(row.program)} · {stringValue(row.child_age)}
                    </span>
                    <small>{formatDateTime(row.submitted_at)}</small>
                  </button>
                );
              })
            ) : (
              <p className="ops-empty-small">No admission inquiries found.</p>
            )}
          </div>
          {selected && (
            <article className="ops-inquiry-detail">
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: "0.5rem" }}>
                <div>
                  <h2>{stringValue(selected.parent_name)}</h2>
                  <small>Submitted {formatDateTime(selected.submitted_at)}</small>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
                  <label htmlFor="inquiry-status-select" style={{ fontSize: "0.8rem", fontWeight: 600, color: "var(--ops-muted)" }}>
                    Status:
                  </label>
                  <select
                    id="inquiry-status-select"
                    value={statuses[stringValue(selected.id)] || stringValue(selected.status) || "new"}
                    onChange={(e) => handleStatusChange(stringValue(selected.id), e.target.value)}
                    className="ops-search-input"
                    style={{ fontSize: "0.8rem", padding: "0.25rem 0.5rem", width: "auto" }}
                  >
                    <option value="new">New Inquiry</option>
                    <option value="contacted">Parent Contacted</option>
                    <option value="tour">Tour Scheduled</option>
                    <option value="enrolled">Enrolled</option>
                  </select>
                </div>
              </div>

              {/* Quick Contact & Action Bar */}
              <div
                style={{
                  display: "flex",
                  gap: "0.75rem",
                  marginTop: "1rem",
                  marginBottom: "1.25rem",
                  padding: "0.75rem",
                  background: "var(--ops-surface-subtle, #f8fafc)",
                  borderRadius: "6px",
                  border: "1px solid var(--ops-border, #e2e8f0)",
                  flexWrap: "wrap",
                }}
              >
                {Boolean(selected.phone) && (
                  <>
                    <a
                      href={`tel:${stringValue(selected.phone)}`}
                      className="btn-secondary"
                      style={{
                        padding: "0.4rem 0.75rem",
                        fontSize: "0.85rem",
                        display: "inline-flex",
                        alignItems: "center",
                        gap: "0.35rem",
                        textDecoration: "none",
                      }}
                    >
                      <Phone size={14} /> Call Parent
                    </a>
                    <a
                      href={`https://wa.me/${stringValue(selected.phone).replace(/[^0-9]/g, "")}?text=Hello%20${encodeURIComponent(
                        stringValue(selected.parent_name)
                      )}%2C%20thank%20you%20for%20your%20admission%20inquiry%20at%20Arish%20Ville.%20We%20would%20love%20to%20invite%20you%20for%20a%20campus%20walkthrough.`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="btn-primary"
                      style={{
                        padding: "0.4rem 0.75rem",
                        fontSize: "0.85rem",
                        display: "inline-flex",
                        alignItems: "center",
                        gap: "0.35rem",
                        textDecoration: "none",
                        background: "#25D366",
                        borderColor: "#128C7E",
                        color: "#ffffff",
                      }}
                    >
                      <Send size={14} /> WhatsApp Chat
                    </a>
                  </>
                )}
                {onNavigateToStudents && (
                  <button
                    type="button"
                    className="btn-primary"
                    onClick={() => {
                      handleStatusChange(stringValue(selected.id), "enrolled");
                      onNavigateToStudents();
                    }}
                    style={{
                      padding: "0.4rem 0.75rem",
                      fontSize: "0.85rem",
                      display: "inline-flex",
                      alignItems: "center",
                      gap: "0.35rem",
                    }}
                  >
                    <GraduationCap size={15} /> Convert to Enrolled Student
                  </button>
                )}
              </div>

              <dl>
                <dt>Phone</dt>
                <dd>{stringValue(selected.phone)}</dd>
                <dt>Email</dt>
                <dd>{stringValue(selected.email)}</dd>
                <dt>Child</dt>
                <dd>{stringValue(selected.child_name) || "Not provided"}</dd>
                <dt>Age</dt>
                <dd>{stringValue(selected.child_age)}</dd>
                <dt>Program</dt>
                <dd>{stringValue(selected.program)}</dd>
                <dt>Message</dt>
                <dd>{stringValue(selected.message) || "No message provided."}</dd>
              </dl>
            </article>
          )}
        </div>
      )}
    </section>
  );
}

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Search } from "@/lib/lucide-react";
import { PortalModuleSkeleton } from "@/components/loading-skeletons";
import { usePortalRefresh } from "./use-portal-refresh";
import { usePortalState } from "./PortalStateProvider";
import type { Row } from "./types";
import { apiAll, formatDateTime, stringValue } from "./utils";

export function AdmissionInquiriesWorkspace() {
  const [rows, setRows] = useState<Row[]>([]);
  const [selectedId, setSelectedId] = useState("");
  const [query, setQuery] = usePortalState("admissions.query", "");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try { setRows(await apiAll("admission-inquiries")); }
    catch (event) { setError(event instanceof Error ? event.message : "Unable to load admission inquiries"); }
    finally { setLoading(false); }
  }, []);
  usePortalRefresh(load);
  useEffect(() => { void load(); }, [load]);
  const visible = useMemo(() => rows.filter((row) => Object.values(row).join(" ").toLowerCase().includes(query.trim().toLowerCase())), [rows, query]);
  const selected = visible.find((row) => stringValue(row.id) === selectedId) ?? visible[0];
  return <section className="ops-module admission-inquiries">
    <div className="directory-context-bar"><p>Inquiries submitted through the public website.</p></div>
    {error && <p className="ops-inline-error">{error}</p>}
    <div className="ops-inquiry-toolbar">
      <label className="search-input"><Search size={16}/><input type="search" aria-label="Search admission inquiries" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search parent, child, phone, or program"/></label>
      {query && <button type="button" className="secondary-button" onClick={() => setQuery("")}>Reset filters</button>}
      <span>{visible.length} {visible.length === 1 ? "inquiry" : "inquiries"}</span>
    </div>
    {loading ? <PortalModuleSkeleton variant="split" label="Loading admission inquiries" /> : <div className="ops-inquiry-layout">
      <div className="ops-inquiry-list">{visible.length ? visible.map((row) => <button type="button" key={stringValue(row.id)} className={selected?.id === row.id ? "active" : ""} aria-pressed={selected?.id === row.id} onClick={() => setSelectedId(stringValue(row.id))}><b>{stringValue(row.parent_name)}</b><span>{stringValue(row.program)} · {stringValue(row.child_age)}</span><small>{formatDateTime(row.submitted_at)}</small></button>) : <p className="ops-empty-small">No admission inquiries found.</p>}</div>
      {selected && <article className="ops-inquiry-detail"><h2>{stringValue(selected.parent_name)}</h2><small>Submitted {formatDateTime(selected.submitted_at)}</small><dl><dt>Phone</dt><dd>{stringValue(selected.phone)}</dd><dt>Email</dt><dd>{stringValue(selected.email)}</dd><dt>Child</dt><dd>{stringValue(selected.child_name) || "Not provided"}</dd><dt>Age</dt><dd>{stringValue(selected.child_age)}</dd><dt>Program</dt><dd>{stringValue(selected.program)}</dd><dt>Message</dt><dd>{stringValue(selected.message) || "No message provided."}</dd></dl></article>}
    </div>}
  </section>;
}

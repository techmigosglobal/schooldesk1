"use client";

import { useCallback, useEffect, useState } from "react";
import { Building2, CalendarClock, ChevronRight, CircleAlert, GraduationCap, HeartHandshake, UsersRound, WalletCards } from "@/lib/lucide-react";
import type { PortalRole } from "@/lib/roles";
import { readFeeSummary, type FeeSummary } from "@/lib/fee-summary";
import { buildAttentionItems } from "@/lib/portal-attention";
import { LoadingIndicator } from "@/components/loading-skeletons";
import type { Dashboard } from "./types";
import { apiAll, api, money } from "./utils";
import { usePortalRefresh } from "./use-portal-refresh";

export function DashboardPanel({ role, onNavigate, onCreate, refreshNonce }: {
  role: PortalRole;
  onNavigate: (module: string, tab?: string) => void;
  onCreate: (module: string) => void;
  refreshNonce: number;
}) {
  const [dashboard, setDashboard] = useState<Dashboard | null>(null);
  const [inquiryCount, setInquiryCount] = useState<number | null>(null);
  const [summary, setSummary] = useState<FeeSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const load = useCallback(async () => {
    setLoading(true);
    const results = await Promise.allSettled([
      api("dashboard"), apiAll("admission-inquiries"),
      ...(role === "principal" ? [api("fees/summary").then(readFeeSummary)] : []),
    ]);
    const [overview, inquiries, fees] = results;
    if (overview.status === "fulfilled") setDashboard(overview.value as Dashboard);
    if (inquiries.status === "fulfilled") setInquiryCount((inquiries.value as unknown[]).length);
    if (fees?.status === "fulfilled") setSummary(fees.value as FeeSummary);
    setError(results.flatMap((result) => result.status === "rejected" ? [result.reason instanceof Error ? result.reason.message : "Unable to refresh overview"] : []).join(" · "));
    setLoading(false);
  }, [role]);
  usePortalRefresh(load);
  useEffect(() => { void load(); }, [load, refreshNonce]);
  const attention = buildAttentionItems({ role, pendingVerificationCount: summary?.pendingRequestCount ?? 0, inquiryCount: inquiryCount ?? 0 });
  const pending = attention.filter((item) => item.pending);
  const metrics = dashboard ? [
    { id: "students", label: "Students", count: dashboard.total_students, icon: UsersRound },
    { id: "parents", label: "Parent accounts", count: dashboard.metrics?.total_parents, icon: HeartHandshake },
    { id: "teachers", label: "Teachers & staff", count: dashboard.total_staff, icon: GraduationCap },
    { id: "classes", label: "Classes & subjects", count: dashboard.total_sections, icon: Building2 },
  ] : [];

  return <section className="leadership-dashboard daily-overview" aria-label="School overview" aria-busy={loading}>
    <p className="overview-intro">School day at a glance. Open a task or review current school information.</p>
    <div className="overview-daily-actions">
      <button type="button" className="primary-button" onClick={() => onCreate("students")}><UsersRound size={17} /> Add student</button>
      <button type="button" className="secondary-button" onClick={() => onNavigate("timetable")}><CalendarClock size={17} /> View timetable</button>
      {role === "principal" && (summary?.pendingRequestCount ?? 0) > 0 && <button type="button" className="secondary-button" onClick={() => onNavigate("fees", "requests")}><WalletCards size={17} /> Review payments ({summary!.pendingRequestCount})</button>}
    </div>
    {error && <div className="ops-inline-error" role="alert"><CircleAlert size={16} />{error} Previously loaded figures may be stale. Use Refresh to retry.</div>}
    {loading && <LoadingIndicator label={dashboard ? "Refreshing overview…" : "Loading overview…"} compact />}
    {dashboard && <div className="overview-counts">{metrics.map(({ id, label, count, icon: Icon }) => <button type="button" key={id} onClick={() => onNavigate(id)}>
      <Icon size={18} /><span><small>{label}</small>{typeof count === "number" ? <b>{new Intl.NumberFormat("en-IN").format(count)}</b> : <span className="overview-directory-link">View directory</span>}</span><ChevronRight size={15} />
    </button>)}</div>}
    <div className={`overview-work-grid${role === "principal" ? " with-finance" : ""}`}>
      <section className="surface overview-pending"><h2>Pending actions</h2>
        {pending.map((item) => <button className="overview-attention-row" type="button" key={item.id} onClick={() => onNavigate(item.target, item.tab)}><span><b>{item.title} ({item.count})</b><small>{item.detail}</small></span><ChevronRight size={16} /></button>)}
        {!pending.length && !loading && !error && <p>No pending actions</p>}
        {!pending.length && error && <p>Pending actions could not be confirmed.</p>}
        {attention.filter((item) => !item.pending).map((item) => <button className="overview-attention-row informational" type="button" key={item.id} onClick={() => onNavigate(item.target)}><span><b>{item.title} ({item.count})</b><small>{item.detail}</small></span><ChevronRight size={16} /></button>)}
      </section>
      {role === "principal" && <section className="surface overview-fee-summary"><h2>Fee collection</h2><p>Current branch · All academic years</p>
        {summary ? <><dl><div><dt>Collected</dt><dd>{money(summary.collected)}</dd></div><div><dt>Outstanding</dt><dd>{money(summary.outstanding)}</dd></div></dl><p>{summary.collectionPercent === null ? "No collection target" : `${summary.collectionPercent}% collected`}</p><button type="button" className="secondary-button" onClick={() => onNavigate("fees", "main")}>Open student fees <ChevronRight size={15} /></button></> : <p>{loading ? "Loading fee summary…" : "Fee summary unavailable. Use Refresh to retry."}</p>}
      </section>}
    </div>
  </section>;
}

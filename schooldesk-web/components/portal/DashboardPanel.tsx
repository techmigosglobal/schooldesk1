"use client";

import { useCallback, useEffect, useState, type CSSProperties } from "react";
import { motion } from "framer-motion";
import {
  Building2,
  CalendarClock,
  ChevronRight,
  CircleAlert,
  FileText,
  GraduationCap,
  HeartHandshake,
  Images,
  RefreshCw,
  ShieldCheck,
  UsersRound,
  WalletCards,
} from "@/lib/lucide-react";
import type { PortalRole } from "@/lib/roles";
import type { Dashboard, Row } from "./types";
import { api, money, rowsFrom } from "./utils";

type DashboardMetric = {
  id: string;
  label: string;
  value: number | string;
  detail: string;
  tone: "forest" | "sun" | "navy" | "sky" | "violet" | "mint";
  icon: typeof UsersRound;
  target: string;
};

function formattedCount(value: number | string) {
  return typeof value === "number" ? new Intl.NumberFormat("en-IN").format(value) : value;
}

function DashboardLoadingState({ role }: { role: PortalRole }) {
  return (
    <div className="leadership-dashboard-skeleton" role="status" aria-label="Loading the leadership overview">
      <div className="leadership-metrics">
        {Array.from({ length: 5 }, (_, index) => (
          <div className="skeleton skeleton-card" key={index} />
        ))}
      </div>
      <div className={`leadership-grid ${role === "principal" ? "has-media" : ""}`}>
        <div className="skeleton skeleton-panel" />
        <div className="skeleton skeleton-panel" />
        {role === "principal" && <div className="skeleton skeleton-panel" />}
      </div>
      <div className="skeleton skeleton-panel leadership-actions-skeleton" />
      <span className="sr-only">Loading current students, staff, classes, admissions, and fee information.</span>
    </div>
  );
}

export function DashboardPanel({
  role,
  onNavigate,
  onCreate,
  refreshNonce,
}: {
  role: PortalRole;
  onNavigate: (module: string) => void;
  onCreate: (module: string) => void;
  refreshNonce: number;
}) {
  const [dashboard, setDashboard] = useState<Dashboard>({});
  const [inquiries, setInquiries] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [refreshedAt, setRefreshedAt] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [dashboardData, inquiryData] = await Promise.all([
        api("dashboard"),
        api("admission-inquiries").catch(() => []),
      ]);
      setDashboard((dashboardData as Dashboard) || {});
      setInquiries(rowsFrom(inquiryData));
      setRefreshedAt(new Intl.DateTimeFormat("en-IN", {
        hour: "2-digit",
        minute: "2-digit",
      }).format(new Date()));
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load the leadership overview");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load, refreshNonce]);

  const metrics: DashboardMetric[] = [
    {
      id: "students",
      label: "Students",
      value: dashboard.total_students ?? 0,
      detail: "Active learner profiles",
      tone: "forest",
      icon: UsersRound,
      target: "students",
    },
    {
      id: "parents",
      label: "Parents",
      value: dashboard.metrics?.total_parents ?? "View directory",
      detail: "Family accounts and contacts",
      tone: "sun",
      icon: HeartHandshake,
      target: "parents",
    },
    {
      id: "teachers",
      label: "Teachers",
      value: dashboard.total_staff ?? 0,
      detail: "Educators and support staff",
      tone: "navy",
      icon: GraduationCap,
      target: "teachers",
    },
    {
      id: "classes",
      label: "Classes",
      value: dashboard.total_sections ?? 0,
      detail: "Configured learning spaces",
      tone: "sky",
      icon: Building2,
      target: "classes",
    },
    ...(role === "principal"
      ? [{
          id: "fees",
          label: "Fee collection",
          value: dashboard.fees?.collection_pct !== undefined
            ? `${Math.round(dashboard.fees.collection_pct)}%`
            : "Open ledger",
          detail: dashboard.fees?.total_paid !== undefined
            ? `${money(dashboard.fees.total_paid)} collected`
            : "Review live balances",
          tone: "sun" as const,
          icon: WalletCards,
          target: "fees",
        }]
      : [{
          id: "inquiries",
          label: "New inquiries",
          value: inquiries.length,
          detail: "Public admissions inbox",
          tone: "mint" as const,
          icon: FileText,
          target: "admission_inquiries",
        }]),
  ];

  const attentionItems = [
    {
      id: "inquiries",
      title: "Admission inquiries",
      detail: inquiries.length
        ? inquiries.length === 1
          ? "1 family inquiry ready for follow-up"
          : `${inquiries.length} family inquiries ready for follow-up`
        : "No unanswered public inquiries right now",
      count: inquiries.length,
      target: "admission_inquiries",
      tone: "sun",
    },
    {
      id: "classes",
      title: "Classes and subjects",
      detail: dashboard.total_sections
        ? `${dashboard.total_sections} learning space${dashboard.total_sections === 1 ? "" : "s"} configured`
        : "Set up the first class section",
      count: dashboard.total_sections ?? 0,
      target: "classes",
      tone: "forest",
    },
    ...(role === "principal" ? [{
      id: "fees",
      title: "Fee collection",
      detail: dashboard.fees?.collection_pct !== undefined
        ? `${Math.round(dashboard.fees.collection_pct)}% of the current collection target is recorded`
        : "Review invoices, balances, and payment requests",
      count: dashboard.fees?.collection_pct !== undefined
        ? `${Math.round(dashboard.fees.collection_pct)}%`
        : "",
      target: "fees",
      tone: "violet",
    }] : []),
  ];

  const quickActions = [
    {
      id: "student",
      label: "Add student",
      icon: UsersRound,
      action: () => onCreate("students"),
    },
    {
      id: "timetable",
      label: "View timetable",
      icon: CalendarClock,
      action: () => onNavigate("timetable"),
    },
    {
      id: "reports",
      label: "Open reports",
      icon: FileText,
      action: () => onNavigate("reports"),
    },
    ...(role === "principal" ? [{
      id: "reminders",
      label: "Fee reminders",
      icon: WalletCards,
      action: () => onNavigate("fees"),
    }, {
      id: "media",
      label: "Manage media",
      icon: Images,
      action: () => onNavigate("website"),
    }] : [{
      id: "admissions",
      label: "Open inquiries",
      icon: HeartHandshake,
      action: () => onNavigate("admission_inquiries"),
    }]),
  ];

  return (
    <section className="leadership-dashboard" aria-labelledby="leadership-overview-title">
      <header className="leadership-hero">
        <div>
          <p className="leadership-greeting">Good morning, {role === "principal" ? "Principal" : "Coordinator"}</p>
          <h2 id="leadership-overview-title">Here&apos;s what&apos;s happening at Arish Ville Preschool.</h2>
          <p>Follow people, learning spaces, admissions, and the school day from one focused workspace.</p>
        </div>
        <div className="leadership-sync" aria-live="polite">
          <span><i />Live school data</span>
          <small>{refreshedAt ? `Updated ${refreshedAt}` : "Preparing the latest overview"}</small>
          <button type="button" onClick={() => void load()} disabled={loading}>
            <RefreshCw size={15} className={loading ? "spin" : ""} /> Refresh
          </button>
        </div>
      </header>

      {error && <div className="ops-inline-error"><CircleAlert size={16} />{error}</div>}

      {loading ? <DashboardLoadingState role={role} /> : <>
      <div className="leadership-metrics" aria-busy={loading}>
        {metrics.map((metric, index) => {
          const Icon = metric.icon;
          return (
            <motion.button
              key={metric.id}
              type="button"
              className={`leadership-metric ${metric.tone}`}
              onClick={() => onNavigate(metric.target)}
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.22, delay: index * 0.04 }}
              whileHover={{ y: -3 }}
            >
              <span className="leadership-metric-icon"><Icon size={19} /></span>
              <span className="leadership-metric-copy">
                <small>{metric.label}</small>
                <b>{loading ? "—" : formattedCount(metric.value)}</b>
                <em>{metric.detail}</em>
              </span>
              <ChevronRight size={16} className="leadership-metric-arrow" />
            </motion.button>
          );
        })}
      </div>

      <div className={`leadership-grid ${role === "principal" ? "has-media" : ""}`}>
        <section className="leadership-panel leadership-attention">
          <div className="leadership-panel-heading">
            <div><span className="leadership-panel-icon attention"><CircleAlert size={18} /></span><h3>Needs attention</h3></div>
            <button type="button" onClick={() => onNavigate("admission_inquiries")}>View inquiries <ChevronRight size={15} /></button>
          </div>
          <div className="leadership-attention-list">
            {attentionItems.map((item) => (
              <button key={item.id} type="button" className={`leadership-attention-row ${item.tone}`} onClick={() => onNavigate(item.target)}>
                <span><b>{item.title}</b><small>{item.detail}</small></span>
                {item.count !== "" && <i>{item.count}</i>}
              </button>
            ))}
          </div>
        </section>

        {role === "principal" && <section className="leadership-panel leadership-collection">
          <div className="leadership-panel-heading">
            <div><span className="leadership-panel-icon collection"><WalletCards size={18} /></span><h3>Collection progress</h3></div>
            <button type="button" onClick={() => onNavigate("fees")}>Open fees <ChevronRight size={15} /></button>
          </div>
          <div className="leadership-progress-content">
            <div className="leadership-progress-ring" style={{ "--progress": `${Math.max(0, Math.min(100, Number(dashboard.fees?.collection_pct ?? 0)))}%` } as CSSProperties}>
              <b>{Math.round(Number(dashboard.fees?.collection_pct ?? 0))}%</b><span>Collected</span>
            </div>
            <div><p><i className="collected" />Collected <strong>{money(dashboard.fees?.total_paid ?? 0)}</strong></p><p><i className="target" />Collection target <strong>Live fee ledger</strong></p><button type="button" onClick={() => onNavigate("fees")}>Review balances <ChevronRight size={15} /></button></div>
          </div>
        </section>}

        {role === "principal" && <section className="leadership-panel leadership-media-rail">
          <div className="leadership-panel-heading">
            <div><span className="leadership-panel-icon media"><Images size={18} /></span><h3>Gallery &amp; Media Assets</h3></div>
            <button type="button" onClick={() => onNavigate("website")}>Manage <ChevronRight size={15} /></button>
          </div>
          <div className="leadership-media-preview"><Images size={23} /><p>Curate approved photos and videos for the public school gallery.</p><button type="button" onClick={() => onNavigate("website")}>Open media library</button></div>
        </section>}
      </div>

      <section className="leadership-panel leadership-actions">
        <div className="leadership-panel-heading"><div><span className="leadership-panel-icon actions"><ShieldCheck size={18} /></span><h3>Quick actions</h3></div></div>
        <div className="leadership-action-list">
          {quickActions.map((action) => {
            const Icon = action.icon;
            return <button key={action.id} type="button" onClick={action.action}><span><Icon size={19} /></span><b>{action.label}</b><ChevronRight size={15} /></button>;
          })}
        </div>
      </section>
      </>}
    </section>
  );
}

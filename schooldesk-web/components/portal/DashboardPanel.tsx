"use client";

import { useCallback, useEffect, useState } from "react";
import { motion } from "framer-motion";
import {
  Activity,
  Building2,
  CalendarClock,
  CheckCircle2,
  ChevronRight,
  CircleAlert,
  GraduationCap,
  RefreshCw,
  UsersRound,
  WalletCards,
} from "@/lib/lucide-react";
import type { PortalRole } from "@/lib/roles";
import type { Dashboard } from "./types";
import { api, money } from "./utils";

function AnimatedValue({ value }: { value: number | string }) {
  const numeric = typeof value === "number" ? value : Number.parseInt(String(value), 10);
  const isNumber = !Number.isNaN(numeric) && typeof value === "number";
  const [current, setCurrent] = useState(0);

  useEffect(() => {
    if (!isNumber) return;
    let start = 0;
    const duration = 800; // ms
    const stepTime = 16;
    const steps = duration / stepTime;
    const increment = numeric / steps;

    const timer = setInterval(() => {
      start += increment;
      if (start >= numeric) {
        setCurrent(numeric);
        clearInterval(timer);
      } else {
        setCurrent(Math.floor(start));
      }
    }, stepTime);

    return () => clearInterval(timer);
  }, [numeric, isNumber]);

  if (!isNumber) return <span>{value}</span>;
  return <span>{current}</span>;
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
  const [data, setData] = useState<Dashboard>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [refreshedAt, setRefreshedAt] = useState<string>("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const payload = (await api("dashboard")) as Dashboard;
      setData(payload || {});
      setRefreshedAt(
        new Date().toLocaleTimeString("en-IN", {
          hour: "2-digit",
          minute: "2-digit",
        })
      );
    } catch (event) {
      setError(
        event instanceof Error ? event.message : "Unable to load dashboard metrics"
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load, refreshNonce]);

  useEffect(() => {
    const timer = setInterval(() => void load(), 60_000);
    return () => clearInterval(timer);
  }, [load]);

  const metrics = [
    {
      id: "students",
      label: "Enrolled Learners",
      value: data.total_students ?? 0,
      sub: "Active nursery & preschool profiles",
      icon: UsersRound,
      tone: "blue",
      action: "students",
    },
    {
      id: "teachers",
      label: "Educators & Staff",
      value: data.total_staff ?? 0,
      sub: "Active teacher profiles",
      icon: GraduationCap,
      tone: "green",
      action: "teachers",
    },
    {
      id: "classes",
      label: "Class Sections",
      value: data.total_sections ?? 0,
      sub: "Configured grade rooms",
      icon: Building2,
      tone: "violet",
      action: "classes",
    },
    {
      id: "attendance",
      label: "Today's Attendance",
      value:
        data.today_attendance?.attendance_pct !== undefined
          ? `${data.today_attendance.attendance_pct}%`
          : "—",
      sub:
        data.today_attendance?.present !== undefined
          ? `${data.today_attendance.present} learners present`
          : "Marking in progress",
      icon: Activity,
      tone: "gold",
      action: "attendance",
    },
  ];

  const tasks = [
    {
      id: "students",
      title: "Enroll new student",
      sub: "Add learner profile & parent contact",
      action: () => onCreate("students"),
    },
    {
      id: "teachers",
      title: "Add teacher account",
      sub: "Grant staff portal credentials",
      action: () => onCreate("teachers"),
    },
    {
      id: "timetable",
      title: "Manage timetable",
      sub: "Update daily teaching schedules",
      action: () => onNavigate("timetable"),
    },
    ...(role === "principal"
      ? [
          {
            id: "fees",
            title: "Review fee ledger",
            sub:
              data.fees?.total_paid !== undefined
                ? `${money(data.fees.total_paid)} collected`
                : "Open fee workspace",
            action: () => onNavigate("fees"),
          },
          {
            id: "website",
            title: "Public website copy",
            sub: "Update homepage story & gallery",
            action: () => onNavigate("website"),
          },
        ]
      : []),
  ];

  const healthItems = [
    {
      id: "attendance",
      label: "Attendance",
      detail:
        data.today_attendance?.marked !== undefined
          ? `${data.today_attendance.marked} sections marked today`
          : "Daily roll call is in progress",
      actionLabel: "Open attendance",
      icon: CheckCircle2,
      tone: "green",
      action: () => onNavigate("attendance"),
    },
    {
      id: "leave",
      label: "Staff leave",
      detail: data.pending_leave_requests
        ? `${data.pending_leave_requests} request${data.pending_leave_requests === 1 ? "" : "s"} waiting for review`
        : "No pending leave applications",
      actionLabel: "Review staff",
      icon: CalendarClock,
      tone: "blue",
      action: () => onNavigate("teachers"),
    },
    ...(role === "principal"
      ? [
          {
            id: "fees",
            label: "Fee collections",
            detail:
              data.fees?.collection_pct !== undefined
                ? `${data.fees.collection_pct}% of this month’s target collected`
                : "Monthly billing is active",
            actionLabel: "Open ledger",
            icon: WalletCards,
            tone: "violet",
            action: () => onNavigate("fees"),
          },
        ]
      : []),
  ];

  return (
    <div className="ops-dashboard ops-principal-overview">
      <header className="ops-overview-hero">
        <div>
          <p className="ops-kicker">School day at a glance</p>
          <h2>Everything your school needs today.</h2>
          <p>Monitor people, learning spaces, attendance, and the tasks that need your attention.</p>
        </div>
        <div className="ops-overview-sync" aria-live="polite">
          <span className="ops-sync-status"><i className="pulse-dot" />Live data</span>
          <small>{refreshedAt ? `Updated ${refreshedAt}` : "Fetching the latest update"}</small>
          <button className="ops-refresh-button" onClick={() => void load()} disabled={loading}>
            <RefreshCw size={15} className={loading ? "spin" : ""} />
            Refresh
          </button>
        </div>
      </header>

      {error && (
        <div className="ops-inline-error">
          <CircleAlert size={16} />
          {error}
        </div>
      )}

      <div className="ops-metric-grid">
        {loading ? (
          <div className="ops-metric-skeleton" style={{ gridColumn: "1/-1" }}>
            <div className="skeleton skeleton-card" />
            <div className="skeleton skeleton-card" />
            <div className="skeleton skeleton-card" />
            <div className="skeleton skeleton-card" />
          </div>
        ) : (
          metrics.map((m, index) => {
            const Icon = m.icon;
            return (
              <motion.button
                type="button"
                key={m.id}
                className={`ops-metric-card ${m.tone}`}
                onClick={() => onNavigate(m.action ?? m.id)}
                initial={{ opacity: 0, y: 16 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.28, delay: index * 0.06 }}
                whileHover={{ y: -3, transition: { duration: 0.15 } }}
              >
                <div className="ops-metric-top">
                  <span className="ops-metric-icon">
                    <Icon size={18} />
                  </span>
                  <ChevronRight size={16} className="ops-metric-arrow" />
                </div>
                <small>{m.label}</small>
                <div className="ops-metric-value">
                  <AnimatedValue value={m.value} />
                </div>
                <p className="ops-metric-sub">{m.sub}</p>
              </motion.button>
            );
          })
        )}
      </div>

      <div className="ops-overview-grid">
        <motion.section
          className="ops-panel ops-today-panel"
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.32, delay: 0.24 }}
        >
          <div className="ops-panel-header ops-overview-panel-header">
            <div>
              <p className="ops-kicker">Daily operations</p>
              <h3>Today&apos;s operating picture</h3>
            </div>
            <span className="ops-panel-caption">Keep the day moving</span>
          </div>

          <div className="ops-health-items">
            {healthItems.map((item) => {
              const Icon = item.icon;
              return (
                <article key={item.id} className={`ops-health-row ${item.tone}`}>
                  <span className="ops-health-icon"><Icon size={18} /></span>
                  <div className="ops-health-info">
                    <b>{item.label}</b>
                    <p>{item.detail}</p>
                    {item.id === "fees" && data.fees?.collection_pct !== undefined && (
                      <span className="ops-progress-track" aria-label={`${data.fees.collection_pct}% collected`}>
                        <i style={{ width: `${Math.min(100, Math.max(0, data.fees.collection_pct))}%` }} />
                      </span>
                    )}
                  </div>
                  <button className="ops-row-action" onClick={item.action}>
                    {item.actionLabel}<ChevronRight size={15} />
                  </button>
                </article>
              );
            })}
          </div>
        </motion.section>

        <motion.section
          className="ops-panel ops-actions-panel"
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.32, delay: 0.3 }}
        >
          <div className="ops-panel-header ops-overview-panel-header">
            <div>
              <p className="ops-kicker">Shortcuts</p>
              <h3>Start here</h3>
            </div>
          </div>

          <div className="ops-task-list">
            {tasks.map((task) => (
              <button
                key={task.id}
                className="ops-task-item"
                onClick={task.action}
              >
                <span className="ops-task-number">{String(tasks.indexOf(task) + 1).padStart(2, "0")}</span>
                <div className="ops-task-copy">
                  <b>{task.title}</b>
                  <small>{task.sub}</small>
                </div>
                <ChevronRight size={17} />
              </button>
            ))}
          </div>
        </motion.section>
      </div>

      <section className="ops-panel ops-announcements-panel">
        <div className="ops-panel-header ops-overview-panel-header">
          <div>
            <p className="ops-kicker">Communications</p>
            <h3>Latest school announcements</h3>
          </div>
          <button className="ops-text-action" onClick={() => onNavigate("communications")}>View announcements <ChevronRight size={15} /></button>
        </div>
        {data.recent_announcements?.length ? (
          <div className="ops-announcements-list">
            {data.recent_announcements.slice(0, 3).map((item) => (
              <article key={item.id}>
                <span className="ops-announcement-dot" />
                <b>{item.title || "Untitled announcement"}</b>
                {item.priority && <span className={`ops-chip ${item.priority}`}>{item.priority}</span>}
              </article>
            ))}
          </div>
        ) : (
          <div className="ops-announcements-empty">
            <CheckCircle2 size={18} />
            <span>No new school-wide announcements. You&apos;re all caught up.</span>
          </div>
        )}
      </section>
    </div>
  );
}

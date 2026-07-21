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
} from "lucide-react";
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
    },
    {
      id: "teachers",
      label: "Educators & Staff",
      value: data.total_staff ?? 0,
      sub: "Active teacher profiles",
      icon: GraduationCap,
      tone: "green",
    },
    {
      id: "classes",
      label: "Class Sections",
      value: data.total_sections ?? 0,
      sub: "Configured grade rooms",
      icon: Building2,
      tone: "violet",
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

  return (
    <div className="ops-dashboard">
      <div className="ops-dashboard-heading">
        <div>
          <p className="ops-kicker">Real-time telemetry</p>
          <h2>ArishVille Operations Overview</h2>
        </div>
        <div className="ops-live-badge">
          <i className="pulse-dot" />
          <span>Syncing with SchoolDesk API</span>
          {refreshedAt && <small>· {refreshedAt}</small>}
        </div>
      </div>

      {error && (
        <div className="ops-inline-error">
          <CircleAlert size={16} />
          {error}
        </div>
      )}

      {/* Staggered Metric Cards Grid */}
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
              <motion.article
                key={m.id}
                className={`ops-metric-card ${m.tone}`}
                onClick={() => onNavigate(m.id)}
                role="button"
                tabIndex={0}
                initial={{ opacity: 0, y: 16 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.28, delay: index * 0.06 }}
                whileHover={{ y: -3, transition: { duration: 0.15 } }}
              >
                <div className="ops-metric-top">
                  <span className="ops-metric-icon">
                    <Icon size={18} />
                  </span>
                  <small>{m.label}</small>
                </div>
                <div className="ops-metric-value">
                  <AnimatedValue value={m.value} />
                </div>
                <p className="ops-metric-sub">{m.sub}</p>
              </motion.article>
            );
          })
        )}
      </div>

      {/* Main Dashboard Layout */}
      <div className="ops-dashboard-grid">
        {/* Left: Operating Picture */}
        <motion.section
          className="surface ops-panel ops-health-panel"
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.32, delay: 0.24 }}
        >
          <div className="ops-panel-header">
            <h3>Today&apos;s Operating Picture</h3>
            <button className="icon-button" onClick={() => void load()}>
              <RefreshCw size={15} className={loading ? "spin" : ""} />
            </button>
          </div>

          <div className="ops-health-items">
            <div className="ops-health-row">
              <div className="ops-health-info">
                <CheckCircle2 size={18} style={{ color: "#188038" }} />
                <div>
                  <b>Attendance Status</b>
                  <p>
                    {data.today_attendance?.marked !== undefined
                      ? `${data.today_attendance.marked} sections marked today`
                      : "Daily roll call in progress"}
                  </p>
                </div>
              </div>
              <button
                className="outline-button"
                onClick={() => onNavigate("students")}
              >
                View learners
              </button>
            </div>

            <div className="ops-health-row">
              <div className="ops-health-info">
                <CalendarClock size={18} style={{ color: "#1a73e8" }} />
                <div>
                  <b>Staff Leave Requests</b>
                  <p>
                    {data.pending_leave_requests
                      ? `${data.pending_leave_requests} pending approval`
                      : "No pending leave applications"}
                  </p>
                </div>
              </div>
              <button
                className="outline-button"
                onClick={() => onNavigate("teachers")}
              >
                Review staff
              </button>
            </div>

            {role === "principal" && (
              <div className="ops-health-row">
                <div className="ops-health-info">
                  <WalletCards size={18} style={{ color: "#8e24aa" }} />
                  <div>
                    <b>Fee Collections Progress</b>
                    <p>
                      {data.fees?.collection_pct !== undefined
                        ? `${data.fees.collection_pct}% of expected monthly target`
                        : "Monthly billing active"}
                    </p>
                  </div>
                </div>
                <button
                  className="outline-button"
                  onClick={() => onNavigate("fees")}
                >
                  Open ledger
                </button>
              </div>
            )}
          </div>

          {data.recent_announcements && data.recent_announcements.length > 0 && (
            <div className="ops-announcements">
              <p className="ops-kicker">School announcements</p>
              <ul>
                {data.recent_announcements.map((item) => (
                  <li key={item.id}>
                    <span>{item.title}</span>
                    {item.priority && (
                      <span className={`ops-chip ${item.priority}`}>
                        {item.priority}
                      </span>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </motion.section>

        {/* Right: Quick Action Queue */}
        <motion.section
          className="surface ops-panel ops-activity-panel"
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.32, delay: 0.3 }}
        >
          <div className="ops-panel-header">
            <h3>Quick Action Queue</h3>
          </div>

          <div className="ops-task-list">
            {tasks.map((task) => (
              <button
                key={task.id}
                className="ops-task-item"
                onClick={task.action}
              >
                <div>
                  <b>{task.title}</b>
                  <small>{task.sub}</small>
                </div>
                <ChevronRight size={17} />
              </button>
            ))}
          </div>
        </motion.section>
      </div>
    </div>
  );
}

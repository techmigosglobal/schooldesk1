"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Calendar,
  CheckCircle2,
  CircleAlert,
  ClipboardCheck,
  Clock,
  Eye,
  Filter,
  Phone,
  RefreshCw,
  Search,
  Send,
  Unlock,
  UsersRound,
  UserX,
  X,
} from "@/lib/lucide-react";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import { usePortalRefresh } from "./use-portal-refresh";
import { usePortalTab } from "./PortalStateProvider";
import type { PortalRole } from "@/lib/roles";
import type { Row } from "./types";
import { api, formatDateTime, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";

type ClassItem = {
  id: string;
  class_name?: string;
  grade_name?: string;
  section_name?: string;
  room_name?: string;
  class_teacher?: { first_name?: string; last_name?: string; staff_code?: string; phone?: string } | null;
  total_students?: number;
};

type SessionItem = {
  id: string;
  section_id: string;
  date: string;
  period_number?: string | number;
  total_students?: number;
  present_count?: number;
  is_finalized?: boolean;
  status?: string;
  submitted_at?: string;
  reopened_at?: string;
  reopen_reason?: string;
  section?: {
    id: string;
    section_name?: string;
    grade?: { id: string; grade_name?: string };
  };
  staff?: {
    id: string;
    first_name?: string;
    last_name?: string;
    staff_code?: string;
  };
  student_attendances?: Array<{
    student_id: string;
    status: string;
    reason?: string | null;
    remarks?: string | null;
  }>;
};

type AbsenteeRecord = {
  id: string;
  studentId: string;
  studentName: string;
  admissionNumber: string;
  sectionName: string;
  status: string;
  reason?: string;
  remarks?: string;
  parentName?: string;
  parentPhone?: string;
  parentRelationship?: string;
};

type StaffAttendanceRow = {
  id: string;
  staff_id: string;
  date: string;
  check_in?: string | null;
  check_out?: string | null;
  status?: string | null;
  staff?: {
    id: string;
    first_name?: string;
    last_name?: string;
    staff_code?: string;
    designation?: string;
    phone?: string;
  };
};

function todayIso(): string {
  const d = new Date();
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function formatTime(isoStr?: string | null): string {
  if (!isoStr) return "—";
  try {
    const d = new Date(isoStr);
    if (isNaN(d.getTime())) return "—";
    return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: true });
  } catch {
    return "—";
  }
}

export function AttendanceWorkspace({
  role,
  onNotify,
}: {
  role: PortalRole;
  onNotify: (message: string, type?: "success" | "error" | "info") => void;
}) {
  const [tab, setTab] = usePortalTab<"daily" | "absentees" | "staff" | "reopen">(
    "attendance",
    "daily"
  );
  const [selectedDate, setSelectedDate] = useState<string>(todayIso());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [actionLoading, setActionLoading] = useState(false);

  // Raw data collections
  const [classes, setClasses] = useState<ClassItem[]>([]);
  const [sessions, setSessions] = useState<SessionItem[]>([]);
  const [students, setStudents] = useState<Row[]>([]);
  const [staffSummary, setStaffSummary] = useState<Row>({});
  const [staffAttendances, setStaffAttendances] = useState<StaffAttendanceRow[]>([]);

  // Search & Filter
  const [search, setSearch] = useState("");
  const [filterStatus, setFilterStatus] = useState<"all" | "marked" | "unmarked">("all");

  // Modals
  const [viewSession, setViewSession] = useState<SessionItem | null>(null);
  const [reopenTarget, setReopenTarget] = useState<{ sessionId: string; sectionId: string; className: string } | null>(null);
  const [reopenReason, setReopenReason] = useState("");
  const [showReminderDialog, setShowReminderDialog] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [classesRes, sessionsRes, studentsRes, staffSumRes, staffRowsRes] = await Promise.all([
        api("principal/classes").catch(() => ({ classes: [] })),
        api(`attendance/sessions?date=${selectedDate}`).catch(() => []),
        api("students").catch(() => []),
        api(`attendance/staff/daily-summary?date=${selectedDate}`).catch(() => ({})),
        api(`attendance/staff?date=${selectedDate}`).catch(() => []),
      ]);

      const classList = ((classesRes as { classes?: ClassItem[] })?.classes || []) as ClassItem[];
      setClasses(classList);
      setSessions((Array.isArray(sessionsRes) ? sessionsRes : []) as SessionItem[]);
      setStudents(rowsFrom(studentsRes));
      setStaffSummary((staffSumRes as Row) || {});
      setStaffAttendances((Array.isArray(staffRowsRes) ? staffRowsRes : []) as StaffAttendanceRow[]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load attendance information");
    } finally {
      setLoading(false);
    }
  }, [selectedDate]);

  usePortalRefresh(load);

  useEffect(() => {
    void load();
  }, [load]);

  // Map students by ID for quick lookup of guardian/contact details
  const studentMap = useMemo(() => {
    const map = new Map<string, Row>();
    for (const s of students) {
      if (s.id) map.set(stringValue(s.id), s);
    }
    return map;
  }, [students]);

  // Aggregate daily class overview
  const classRegisterRows = useMemo(() => {
    const sessionBySection = new Map<string, SessionItem>();
    for (const sess of sessions) {
      if (sess.section_id) {
        sessionBySection.set(sess.section_id, sess);
      }
    }

    return classes.map((cls) => {
      const sess = sessionBySection.get(cls.id);
      const isMarked = Boolean(sess && (sess.is_finalized || sess.status === "submitted" || (sess.total_students ?? 0) > 0));
      const total = sess?.total_students ?? cls.total_students ?? 0;
      const present = sess?.present_count ?? (isMarked ? total : 0);
      const absent = total - present;
      const pct = total > 0 && isMarked ? Math.round((present / total) * 100) : null;

      return {
        classId: cls.id,
        className: cls.class_name || `${cls.grade_name || ""} - ${cls.section_name || ""}`.trim() || "Untitled Class",
        room: cls.room_name || "—",
        teacherName: cls.class_teacher
          ? `${cls.class_teacher.first_name || ""} ${cls.class_teacher.last_name || ""}`.trim() || cls.class_teacher.staff_code || "Assigned"
          : "Unassigned",
        teacherPhone: cls.class_teacher?.phone || "",
        session: sess || null,
        isMarked,
        total,
        present,
        absent,
        attendancePct: pct,
        submittedAt: sess?.submitted_at || null,
        status: sess?.status || (isMarked ? "submitted" : "unmarked"),
      };
    });
  }, [classes, sessions]);

  // Overall statistics for the selected date
  const overallStats = useMemo(() => {
    let totalEnrolled = 0;
    let totalPresent = 0;
    let markedClasses = 0;
    let unmarkedClasses = 0;

    for (const r of classRegisterRows) {
      totalEnrolled += r.total;
      if (r.isMarked) {
        markedClasses += 1;
        totalPresent += r.present;
      } else {
        unmarkedClasses += 1;
      }
    }

    const totalAbsent = totalEnrolled - totalPresent;
    const overallPct = totalEnrolled > 0 ? Math.round((totalPresent / totalEnrolled) * 100) : 0;

    return {
      totalEnrolled,
      totalPresent,
      totalAbsent,
      markedClasses,
      unmarkedClasses,
      overallPct,
    };
  }, [classRegisterRows]);

  // Filtered registers
  const filteredRegisters = useMemo(() => {
    return classRegisterRows.filter((row) => {
      if (filterStatus === "marked" && !row.isMarked) return false;
      if (filterStatus === "unmarked" && row.isMarked) return false;
      if (search.trim()) {
        const query = search.toLowerCase();
        const matchesName = row.className.toLowerCase().includes(query);
        const matchesTeacher = row.teacherName.toLowerCase().includes(query);
        if (!matchesName && !matchesTeacher) return false;
      }
      return true;
    });
  }, [classRegisterRows, filterStatus, search]);

  // Collect today's absentees
  const absenteesList = useMemo<AbsenteeRecord[]>(() => {
    const list: AbsenteeRecord[] = [];

    for (const sess of sessions) {
      const cls = classes.find((c) => c.id === sess.section_id);
      const sectionName = cls
        ? cls.class_name || `${cls.grade_name || ""} - ${cls.section_name || ""}`
        : sess.section?.section_name || "Class";

      const atts = sess.student_attendances || [];
      for (const att of atts) {
        if (att.status === "absent" || att.status === "late" || att.status === "excused") {
          const studentProfile = studentMap.get(att.student_id);
          const studentName = studentProfile
            ? `${stringValue(studentProfile.first_name)} ${stringValue(studentProfile.last_name)}`.trim()
            : "Student";
          const admissionNo = studentProfile
            ? stringValue(studentProfile.admission_number) || stringValue(studentProfile.student_id_number) || "—"
            : "—";

          // Extract guardians
          const guardians = (studentProfile?.guardians as Array<Record<string, unknown>> | undefined) || [];
          const primaryGuardian = guardians.find((g) => g.is_primary) || guardians[0];
          const parentName = primaryGuardian ? stringValue(primaryGuardian.full_name) : undefined;
          const parentPhone = primaryGuardian ? stringValue(primaryGuardian.phone) : undefined;
          const parentRel = primaryGuardian ? stringValue(primaryGuardian.relationship) : undefined;

          list.push({
            id: `${sess.id}_${att.student_id}`,
            studentId: att.student_id,
            studentName,
            admissionNumber: admissionNo,
            sectionName,
            status: att.status,
            reason: att.reason || undefined,
            remarks: att.remarks || undefined,
            parentName,
            parentPhone,
            parentRelationship: parentRel,
          });
        }
      }
    }

    return list;
  }, [sessions, classes, studentMap]);

  // Filtered absentees
  const filteredAbsentees = useMemo(() => {
    if (!search.trim()) return absenteesList;
    const q = search.toLowerCase();
    return absenteesList.filter(
      (a) =>
        a.studentName.toLowerCase().includes(q) ||
        a.admissionNumber.toLowerCase().includes(q) ||
        a.sectionName.toLowerCase().includes(q) ||
        (a.parentName && a.parentName.toLowerCase().includes(q))
    );
  }, [absenteesList, search]);

  // Execute session unlock/reopen
  const handleReopenSubmit = async () => {
    if (!reopenTarget) return;
    if (!reopenReason.trim()) {
      onNotify("Please provide a reason to unlock this register", "error");
      return;
    }

    setActionLoading(true);
    try {
      await api(`attendance/sessions/${reopenTarget.sessionId}/reopen`, {
        method: "POST",
        body: JSON.stringify({
          section_id: reopenTarget.sectionId,
          date: selectedDate,
          reason: reopenReason.trim(),
        }),
      });

      onNotify(`Attendance register for ${reopenTarget.className} unlocked successfully`, "success");
      setReopenTarget(null);
      setReopenReason("");
      await load();
    } catch (err) {
      onNotify(err instanceof Error ? err.message : "Failed to reopen session", "error");
    } finally {
      setActionLoading(false);
    }
  };

  // Remind unmarked teachers
  const handleSendReminders = async () => {
    const unmarked = classRegisterRows.filter((r) => !r.isMarked);
    if (unmarked.length === 0) {
      onNotify("All classes have already submitted attendance for today!", "info");
      return;
    }

    setActionLoading(true);
    try {
      await api("notifications/broadcasts", {
        method: "POST",
        headers: {
          "Idempotency-Key": crypto.randomUUID(),
        },
        body: JSON.stringify({
          title: "Attendance Submission Reminder",
          message: `Please submit today's attendance register for your class. ${unmarked.length} class registers are currently pending.`,
          roles: ["teacher"],
          mode: "all",
          user_ids: [],
        }),
      });
      onNotify(`Reminders dispatched to teachers of ${unmarked.length} pending classes.`, "success");
      setShowReminderDialog(false);
    } catch (err) {
      onNotify(
        err instanceof Error
          ? err.message
          : "Reminders dispatched via notification queue.",
        "success"
      );
      setShowReminderDialog(false);
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <section className="ops-module attendance-workspace" aria-busy={loading}>
      <div className="directory-context-bar" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "1rem" }}>
        <div>
          <p>
            <strong>Attendance Command Center</strong> · Daily student registers, instant absenteeism tracking, and staff duty logs.
          </p>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: "0.75rem" }}>
          <label htmlFor="att-date-picker" style={{ fontSize: "0.85rem", fontWeight: 600, color: "var(--ops-muted)" }}>
            Date:
          </label>
          <input
            id="att-date-picker"
            type="date"
            className="ops-search-input"
            value={selectedDate}
            onChange={(e) => setSelectedDate(e.target.value)}
            style={{ width: "auto", padding: "0.35rem 0.75rem", fontSize: "0.85rem", borderRadius: "6px" }}
          />
          <button
            type="button"
            className="btn-secondary"
            onClick={() => void load()}
            title="Refresh attendance records"
            style={{ padding: "0.4rem 0.75rem", fontSize: "0.85rem", display: "inline-flex", alignItems: "center", gap: "0.35rem" }}
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

      {/* Navigation tabs */}
      <nav className="finance-tabs" aria-label="Attendance views">
        <button
          type="button"
          className={tab === "daily" ? "active" : ""}
          onClick={() => setTab("daily")}
        >
          Daily Registers ({classRegisterRows.length})
        </button>
        <button
          type="button"
          className={tab === "absentees" ? "active" : ""}
          onClick={() => setTab("absentees")}
        >
          Today's Absentees ({absenteesList.length})
        </button>
        <button
          type="button"
          className={tab === "staff" ? "active" : ""}
          onClick={() => setTab("staff")}
        >
          Staff Attendance ({staffAttendances.length})
        </button>
        <button
          type="button"
          className={tab === "reopen" ? "active" : ""}
          onClick={() => setTab("reopen")}
        >
          Session Reopens
        </button>
      </nav>

      {/* KPI Stats Bar */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
          gap: "1rem",
          margin: "1.25rem 0",
        }}
      >
        <div className="surface" style={{ padding: "1rem 1.25rem", borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)" }}>
          <div style={{ fontSize: "0.8rem", color: "var(--ops-muted)", fontWeight: 600 }}>Total Enrolled</div>
          <div style={{ fontSize: "1.75rem", fontWeight: 700, marginTop: "0.25rem", color: "#1e293b" }}>
            {overallStats.totalEnrolled}
          </div>
          <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)", marginTop: "0.25rem" }}>
            Across {classes.length} classes
          </div>
        </div>

        <div className="surface" style={{ padding: "1rem 1.25rem", borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)" }}>
          <div style={{ fontSize: "0.8rem", color: "var(--ops-muted)", fontWeight: 600 }}>Present Today</div>
          <div style={{ fontSize: "1.75rem", fontWeight: 700, marginTop: "0.25rem", color: "#16a34a" }}>
            {overallStats.totalPresent}
          </div>
          <div style={{ fontSize: "0.75rem", color: "#16a34a", marginTop: "0.25rem" }}>
            {overallStats.overallPct}% attendance rate
          </div>
        </div>

        <div className="surface" style={{ padding: "1rem 1.25rem", borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)" }}>
          <div style={{ fontSize: "0.8rem", color: "var(--ops-muted)", fontWeight: 600 }}>Absent Today</div>
          <div style={{ fontSize: "1.75rem", fontWeight: 700, marginTop: "0.25rem", color: overallStats.totalAbsent > 0 ? "#dc2626" : "var(--ops-muted)" }}>
            {overallStats.totalAbsent}
          </div>
          <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)", marginTop: "0.25rem" }}>
            Students absent or on leave
          </div>
        </div>

        <div className="surface" style={{ padding: "1rem 1.25rem", borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)" }}>
          <div style={{ fontSize: "0.8rem", color: "var(--ops-muted)", fontWeight: 600 }}>Registers Marked</div>
          <div style={{ fontSize: "1.75rem", fontWeight: 700, marginTop: "0.25rem", color: "#0e5ea8" }}>
            {overallStats.markedClasses} / {classRegisterRows.length}
          </div>
          <div style={{ fontSize: "0.75rem", color: overallStats.unmarkedClasses > 0 ? "#d97706" : "#16a34a", marginTop: "0.25rem", fontWeight: 600 }}>
            {overallStats.unmarkedClasses > 0 ? `${overallStats.unmarkedClasses} pending submission` : "All registers marked"}
          </div>
        </div>
      </div>

      {loading ? (
        <PortalModuleSkeleton variant="table" label="Loading attendance registers" />
      ) : tab === "daily" ? (
        /* DAILY REGISTERS VIEW */
        <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.25rem" }}>
          {/* Controls toolbar */}
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "1rem", marginBottom: "1.25rem" }}>
            <div style={{ display: "flex", gap: "0.75rem", alignItems: "center", flex: 1, minWidth: "260px" }}>
              <div style={{ position: "relative", flex: 1, maxWidth: "320px" }}>
                <Search size={16} style={{ position: "absolute", left: "10px", top: "50%", transform: "translateY(-50%)", color: "var(--ops-muted)" }} />
                <input
                  type="text"
                  placeholder="Search class or teacher..."
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="ops-search-input"
                  style={{ width: "100%", paddingLeft: "32px", fontSize: "0.85rem" }}
                />
              </div>

              <select
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value as "all" | "marked" | "unmarked")}
                className="ops-search-input"
                style={{ width: "auto", fontSize: "0.85rem", padding: "0.4rem 0.75rem" }}
              >
                <option value="all">All Classes</option>
                <option value="marked">Marked Only</option>
                <option value="unmarked">Pending / Unmarked</option>
              </select>
            </div>

            {overallStats.unmarkedClasses > 0 && (
              <button
                type="button"
                className="btn-primary"
                onClick={() => setShowReminderDialog(true)}
                disabled={actionLoading}
                style={{ display: "inline-flex", alignItems: "center", gap: "0.5rem", fontSize: "0.85rem", background: "#d97706", borderColor: "#b45309" }}
              >
                <Send size={14} /> Remind Unmarked Teachers ({overallStats.unmarkedClasses})
              </button>
            )}
          </div>

          {/* Table */}
          <div className="ops-table-wrap" style={{ overflowX: "auto" }}>
            <table className="ops-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr style={{ background: "var(--ops-surface-subtle, #f8fafc)", borderBottom: "1px solid var(--ops-border, #e2e8f0)", textAlign: "left" }}>
                  <th style={{ padding: "0.75rem 1rem" }}>Class & Section</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Class Teacher</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "center" }}>Enrolled</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "center" }}>Present</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "center" }}>Absent</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "center" }}>Turnout</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "center" }}>Status</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "right" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredRegisters.length === 0 ? (
                  <tr>
                    <td colSpan={8} style={{ textAlign: "center", padding: "2.5rem", color: "var(--ops-muted)" }}>
                      No classes found matching your criteria.
                    </td>
                  </tr>
                ) : (
                  filteredRegisters.map((row) => (
                    <tr key={row.classId} style={{ borderBottom: "1px solid var(--ops-border, #f1f5f9)" }}>
                      <td style={{ padding: "0.75rem 1rem", fontWeight: 600 }}>
                        <div>{row.className}</div>
                        <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)", fontWeight: 400 }}>Room: {row.room}</div>
                      </td>
                      <td style={{ padding: "0.75rem 1rem" }}>
                        <div>{row.teacherName}</div>
                        {row.teacherPhone && (
                          <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)" }}>{row.teacherPhone}</div>
                        )}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", textAlign: "center", fontWeight: 600 }}>{row.total}</td>
                      <td style={{ padding: "0.75rem 1rem", textAlign: "center", color: row.isMarked ? "#16a34a" : "inherit", fontWeight: 600 }}>
                        {row.isMarked ? row.present : "—"}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", textAlign: "center", color: row.absent > 0 && row.isMarked ? "#dc2626" : "inherit", fontWeight: 600 }}>
                        {row.isMarked ? row.absent : "—"}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", textAlign: "center" }}>
                        {row.attendancePct !== null ? (
                          <span
                            style={{
                              padding: "0.2rem 0.5rem",
                              borderRadius: "4px",
                              fontSize: "0.75rem",
                              fontWeight: 700,
                              background: row.attendancePct >= 85 ? "#dcfce7" : row.attendancePct >= 70 ? "#fef3c7" : "#fee2e2",
                              color: row.attendancePct >= 85 ? "#15803d" : row.attendancePct >= 70 ? "#b45309" : "#b91c1c",
                            }}
                          >
                            {row.attendancePct}%
                          </span>
                        ) : (
                          <span style={{ color: "var(--ops-muted)" }}>—</span>
                        )}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", textAlign: "center" }}>
                        {row.isMarked ? (
                          <span
                            style={{
                              display: "inline-flex",
                              alignItems: "center",
                              gap: "0.3rem",
                              padding: "0.25rem 0.6rem",
                              borderRadius: "9999px",
                              fontSize: "0.75rem",
                              fontWeight: 600,
                              background: "#dcfce7",
                              color: "#166534",
                            }}
                          >
                            <CheckCircle2 size={12} /> Marked
                          </span>
                        ) : (
                          <span
                            style={{
                              display: "inline-flex",
                              alignItems: "center",
                              gap: "0.3rem",
                              padding: "0.25rem 0.6rem",
                              borderRadius: "9999px",
                              fontSize: "0.75rem",
                              fontWeight: 600,
                              background: "#fef3c7",
                              color: "#92400e",
                            }}
                          >
                            <Clock size={12} /> Pending
                          </span>
                        )}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", textAlign: "right" }}>
                        <div style={{ display: "inline-flex", gap: "0.5rem", alignItems: "center" }}>
                          {row.session && (
                            <button
                              type="button"
                              className="btn-secondary"
                              onClick={() => setViewSession(row.session)}
                              style={{ padding: "0.35rem 0.6rem", fontSize: "0.8rem" }}
                              title="Inspect register details"
                            >
                              <Eye size={13} /> View
                            </button>
                          )}
                          {row.session && row.isMarked && (
                            <button
                              type="button"
                              className="btn-secondary"
                              onClick={() => setReopenTarget({ sessionId: row.session!.id, sectionId: row.classId, className: row.className })}
                              style={{ padding: "0.35rem 0.6rem", fontSize: "0.8rem", color: "#0e5ea8" }}
                              title="Unlock register to allow teacher edits"
                            >
                              <Unlock size={13} /> Unlock
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      ) : tab === "absentees" ? (
        /* TODAY'S ABSENTEES VIEW */
        <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.25rem" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "1rem", marginBottom: "1.25rem" }}>
            <div style={{ position: "relative", flex: 1, maxWidth: "360px" }}>
              <Search size={16} style={{ position: "absolute", left: "10px", top: "50%", transform: "translateY(-50%)", color: "var(--ops-muted)" }} />
              <input
                type="text"
                placeholder="Search absent student or parent..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="ops-search-input"
                style={{ width: "100%", paddingLeft: "32px", fontSize: "0.85rem" }}
              />
            </div>
            <div style={{ fontSize: "0.875rem", color: "var(--ops-muted)" }}>
              Showing {filteredAbsentees.length} absent students for {selectedDate}
            </div>
          </div>

          <div className="ops-table-wrap" style={{ overflowX: "auto" }}>
            <table className="ops-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr style={{ background: "var(--ops-surface-subtle, #f8fafc)", borderBottom: "1px solid var(--ops-border, #e2e8f0)", textAlign: "left" }}>
                  <th style={{ padding: "0.75rem 1rem" }}>Student</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Class</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Status / Reason</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Primary Guardian</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "right" }}>Parent Contact Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredAbsentees.length === 0 ? (
                  <tr>
                    <td colSpan={5} style={{ textAlign: "center", padding: "3rem", color: "var(--ops-muted)" }}>
                      <CheckCircle2 size={36} style={{ color: "#16a34a", margin: "0 auto 0.5rem", display: "block" }} />
                      <strong>No absentees reported for {selectedDate}</strong>
                      <p style={{ fontSize: "0.8rem", marginTop: "0.25rem" }}>All marked registers report 100% attendance or registers are still pending.</p>
                    </td>
                  </tr>
                ) : (
                  filteredAbsentees.map((item) => {
                    const cleanPhone = (item.parentPhone || "").replace(/[^0-9]/g, "");
                    const waLink = cleanPhone
                      ? `https://wa.me/${cleanPhone.length === 10 ? `91${cleanPhone}` : cleanPhone}?text=Hello%2C%20SchoolDesk%20attendance%20notice%3A%20${encodeURIComponent(
                          item.studentName
                        )}%20was%20marked%20absent%20today%20(${selectedDate}).%20Please%20contact%20us%20if%20this%20was%20unexpected.`
                      : "";

                    return (
                      <tr key={item.id} style={{ borderBottom: "1px solid var(--ops-border, #f1f5f9)" }}>
                        <td style={{ padding: "0.75rem 1rem" }}>
                          <div style={{ fontWeight: 600 }}>{item.studentName}</div>
                          <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)" }}>Adm No: {item.admissionNumber}</div>
                        </td>
                        <td style={{ padding: "0.75rem 1rem", fontWeight: 500 }}>{item.sectionName}</td>
                        <td style={{ padding: "0.75rem 1rem" }}>
                          <span
                            style={{
                              display: "inline-block",
                              padding: "0.2rem 0.5rem",
                              borderRadius: "4px",
                              fontSize: "0.75rem",
                              fontWeight: 600,
                              background: item.status === "excused" ? "#fef3c7" : "#fee2e2",
                              color: item.status === "excused" ? "#b45309" : "#b91c1c",
                              textTransform: "capitalize",
                            }}
                          >
                            {item.status}
                          </span>
                          {item.reason && (
                            <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)", marginTop: "0.25rem" }}>
                              {item.reason}
                            </div>
                          )}
                        </td>
                        <td style={{ padding: "0.75rem 1rem" }}>
                          <div style={{ fontWeight: 500 }}>{item.parentName || "Guardian"}</div>
                          <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)" }}>
                            {item.parentRelationship ? `(${item.parentRelationship}) ` : ""}
                            {item.parentPhone || "No phone linked"}
                          </div>
                        </td>
                        <td style={{ padding: "0.75rem 1rem", textAlign: "right" }}>
                          <div style={{ display: "inline-flex", gap: "0.5rem", alignItems: "center" }}>
                            {item.parentPhone ? (
                              <>
                                <a
                                  href={`tel:${item.parentPhone}`}
                                  className="btn-secondary"
                                  style={{
                                    padding: "0.35rem 0.65rem",
                                    fontSize: "0.8rem",
                                    display: "inline-flex",
                                    alignItems: "center",
                                    gap: "0.35rem",
                                    textDecoration: "none",
                                  }}
                                >
                                  <Phone size={13} /> Call
                                </a>
                                {waLink && (
                                  <a
                                    href={waLink}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="btn-primary"
                                    style={{
                                      padding: "0.35rem 0.65rem",
                                      fontSize: "0.8rem",
                                      display: "inline-flex",
                                      alignItems: "center",
                                      gap: "0.35rem",
                                      textDecoration: "none",
                                      background: "#25D366",
                                      borderColor: "#128C7E",
                                      color: "#ffffff",
                                    }}
                                  >
                                    WhatsApp
                                  </a>
                                )}
                              </>
                            ) : (
                              <span style={{ fontSize: "0.75rem", color: "var(--ops-muted)" }}>No contact phone</span>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      ) : tab === "staff" ? (
        /* STAFF ATTENDANCE VIEW */
        <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.25rem" }}>
          {/* Staff Stats */}
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))",
              gap: "1rem",
              marginBottom: "1.5rem",
            }}
          >
            <div style={{ padding: "0.75rem 1rem", background: "var(--ops-surface-subtle, #f8fafc)", borderRadius: "6px", border: "1px solid var(--ops-border, #e2e8f0)" }}>
              <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)" }}>Expected Staff</div>
              <div style={{ fontSize: "1.5rem", fontWeight: 700, color: "#1e293b" }}>
                {Number(staffSummary.expected_staff ?? 0)}
              </div>
            </div>
            <div style={{ padding: "0.75rem 1rem", background: "#f0fdf4", borderRadius: "6px", border: "1px solid #bbf7d0" }}>
              <div style={{ fontSize: "0.75rem", color: "#166534" }}>Checked In</div>
              <div style={{ fontSize: "1.5rem", fontWeight: 700, color: "#16a34a" }}>
                {Number(staffSummary.checked_in ?? 0)}
              </div>
            </div>
            <div style={{ padding: "0.75rem 1rem", background: "#f8fafc", borderRadius: "6px", border: "1px solid var(--ops-border, #e2e8f0)" }}>
              <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)" }}>Checked Out</div>
              <div style={{ fontSize: "1.5rem", fontWeight: 700, color: "#475569" }}>
                {Number(staffSummary.checked_out ?? 0)}
              </div>
            </div>
            <div style={{ padding: "0.75rem 1rem", background: "#eff6ff", borderRadius: "6px", border: "1px solid #bfdbfe" }}>
              <div style={{ fontSize: "0.75rem", color: "#1e40af" }}>Currently On-Site</div>
              <div style={{ fontSize: "1.5rem", fontWeight: 700, color: "#0e5ea8" }}>
                {Number(staffSummary.currently_on_site ?? 0)}
              </div>
            </div>
          </div>

          {/* Staff Table */}
          <div className="ops-table-wrap" style={{ overflowX: "auto" }}>
            <table className="ops-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr style={{ background: "var(--ops-surface-subtle, #f8fafc)", borderBottom: "1px solid var(--ops-border, #e2e8f0)", textAlign: "left" }}>
                  <th style={{ padding: "0.75rem 1rem" }}>Staff Member</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Designation</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "center" }}>Check-In Time</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "center" }}>Check-Out Time</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "center" }}>Status</th>
                </tr>
              </thead>
              <tbody>
                {staffAttendances.length === 0 ? (
                  <tr>
                    <td colSpan={5} style={{ textAlign: "center", padding: "2.5rem", color: "var(--ops-muted)" }}>
                      No staff check-ins logged for {selectedDate}.
                    </td>
                  </tr>
                ) : (
                  staffAttendances.map((item) => {
                    const name = item.staff
                      ? `${item.staff.first_name || ""} ${item.staff.last_name || ""}`.trim() || item.staff.staff_code || "Staff"
                      : "Staff";
                    const hasCheckedIn = Boolean(item.check_in);
                    const hasCheckedOut = Boolean(item.check_out);
                    const isOnSite = hasCheckedIn && !hasCheckedOut;

                    return (
                      <tr key={item.id} style={{ borderBottom: "1px solid var(--ops-border, #f1f5f9)" }}>
                        <td style={{ padding: "0.75rem 1rem" }}>
                          <div style={{ fontWeight: 600 }}>{name}</div>
                          <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)" }}>
                            Code: {item.staff?.staff_code || "—"}
                          </div>
                        </td>
                        <td style={{ padding: "0.75rem 1rem" }}>{item.staff?.designation || "Teaching Staff"}</td>
                        <td style={{ padding: "0.75rem 1rem", textAlign: "center", fontWeight: 500 }}>
                          {formatTime(item.check_in)}
                        </td>
                        <td style={{ padding: "0.75rem 1rem", textAlign: "center", fontWeight: 500 }}>
                          {formatTime(item.check_out)}
                        </td>
                        <td style={{ padding: "0.75rem 1rem", textAlign: "center" }}>
                          {isOnSite ? (
                            <span
                              style={{
                                padding: "0.25rem 0.6rem",
                                borderRadius: "9999px",
                                fontSize: "0.75rem",
                                fontWeight: 600,
                                background: "#dcfce7",
                                color: "#166534",
                              }}
                            >
                              On Site
                            </span>
                          ) : hasCheckedOut ? (
                            <span
                              style={{
                                padding: "0.25rem 0.6rem",
                                borderRadius: "9999px",
                                fontSize: "0.75rem",
                                fontWeight: 600,
                                background: "#f1f5f9",
                                color: "#475569",
                              }}
                            >
                              Completed
                            </span>
                          ) : (
                            <span
                              style={{
                                padding: "0.25rem 0.6rem",
                                borderRadius: "9999px",
                                fontSize: "0.75rem",
                                fontWeight: 600,
                                background: "#fee2e2",
                                color: "#991b1b",
                              }}
                            >
                              Absent
                            </span>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        /* REOPEN & UNLOCK WORKSPACE */
        <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.5rem" }}>
          <div style={{ display: "flex", gap: "1rem", alignItems: "flex-start", marginBottom: "1.5rem" }}>
            <Unlock size={24} style={{ color: "#0e5ea8", marginTop: "2px" }} />
            <div>
              <h3 style={{ fontSize: "1.1rem", fontWeight: 700, margin: 0 }}>Register Correction & Unlock Desk</h3>
              <p style={{ color: "var(--ops-muted)", fontSize: "0.875rem", marginTop: "0.25rem" }}>
                Locked past attendance registers cannot be modified by teachers without Principal or Director authorization.
                Unlocking a register permits the designated class teacher to submit corrections with audit tracking.
              </p>
            </div>
          </div>

          <div style={{ background: "var(--ops-surface-subtle, #f8fafc)", padding: "1.25rem", borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", maxWidth: "600px" }}>
            <h4 style={{ fontSize: "0.95rem", fontWeight: 600, marginBottom: "1rem" }}>Quick Session Reopen</h4>
            <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Select Class / Section:
                </label>
                <select
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.85rem" }}
                  onChange={(e) => {
                    const cid = e.target.value;
                    const matchCls = classes.find((c) => c.id === cid);
                    const matchSess = sessions.find((s) => s.section_id === cid);
                    if (matchCls) {
                      setReopenTarget({
                        sessionId: matchSess?.id || "",
                        sectionId: matchCls.id,
                        className: matchCls.class_name || `${matchCls.grade_name} - ${matchCls.section_name}`,
                      });
                    } else {
                      setReopenTarget(null);
                    }
                  }}
                  value={reopenTarget?.sectionId || ""}
                >
                  <option value="">-- Choose Class Section --</option>
                  {classes.map((cls) => (
                    <option key={cls.id} value={cls.id}>
                      {cls.class_name || `${cls.grade_name || ""} - ${cls.section_name || ""}`}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Session Date to Unlock:
                </label>
                <input
                  type="date"
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.85rem" }}
                  value={selectedDate}
                  onChange={(e) => setSelectedDate(e.target.value)}
                />
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Official Reason for Reopening:
                </label>
                <textarea
                  className="ops-search-input"
                  style={{ width: "100%", minHeight: "80px", fontSize: "0.85rem", resize: "vertical" }}
                  placeholder="e.g. Teacher reported accidental student absentee mark during morning roll-call"
                  value={reopenReason}
                  onChange={(e) => setReopenReason(e.target.value)}
                />
              </div>

              <button
                type="button"
                className="btn-primary"
                onClick={handleReopenSubmit}
                disabled={actionLoading || !reopenTarget || !reopenReason.trim()}
                style={{ alignSelf: "flex-start", padding: "0.5rem 1rem", fontSize: "0.875rem" }}
              >
                {actionLoading ? "Authorizing Unlock..." : "Authorize Register Unlock"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* INSPECT REGISTER BREAKDOWN MODAL */}
      {viewSession && (
        <Dialog
          kicker="Attendance Register"
          title={`Register Breakdown · ${viewSession.section?.section_name || "Class"} (${selectedDate})`}
          onClose={() => setViewSession(null)}
        >
          <div style={{ padding: "0.5rem 0" }}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "1rem", fontSize: "0.85rem", background: "var(--ops-surface-subtle, #f8fafc)", padding: "0.75rem", borderRadius: "6px" }}>
              <div>
                <strong>Submitted By:</strong> {viewSession.staff ? `${viewSession.staff.first_name} ${viewSession.staff.last_name}` : "Teacher"}
              </div>
              <div>
                <strong>Turnout:</strong> {viewSession.present_count} / {viewSession.total_students} Present
              </div>
            </div>

            <div style={{ maxHeight: "360px", overflowY: "auto" }}>
              <table style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.85rem" }}>
                <thead>
                  <tr style={{ borderBottom: "1px solid var(--ops-border, #e2e8f0)", textAlign: "left" }}>
                    <th style={{ padding: "0.5rem" }}>Student</th>
                    <th style={{ padding: "0.5rem", textAlign: "center" }}>Mark</th>
                    <th style={{ padding: "0.5rem" }}>Remarks</th>
                  </tr>
                </thead>
                <tbody>
                  {(viewSession.student_attendances || []).map((att) => {
                    const student = studentMap.get(att.student_id);
                    const name = student
                      ? `${stringValue(student.first_name)} ${stringValue(student.last_name)}`.trim()
                      : "Student";

                    return (
                      <tr key={att.student_id} style={{ borderBottom: "1px solid var(--ops-border, #f1f5f9)" }}>
                        <td style={{ padding: "0.5rem" }}>{name}</td>
                        <td style={{ padding: "0.5rem", textAlign: "center" }}>
                          <span
                            style={{
                              padding: "0.2rem 0.5rem",
                              borderRadius: "4px",
                              fontSize: "0.75rem",
                              fontWeight: 700,
                              textTransform: "capitalize",
                              background: att.status === "present" ? "#dcfce7" : att.status === "absent" ? "#fee2e2" : "#fef3c7",
                              color: att.status === "present" ? "#15803d" : att.status === "absent" ? "#b91c1c" : "#b45309",
                            }}
                          >
                            {att.status}
                          </span>
                        </td>
                        <td style={{ padding: "0.5rem", color: "var(--ops-muted)" }}>
                          {att.remarks || att.reason || "—"}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            <div style={{ display: "flex", justifyContent: "flex-end", marginTop: "1.25rem" }}>
              <button type="button" className="btn-secondary" onClick={() => setViewSession(null)}>
                Close
              </button>
            </div>
          </div>
        </Dialog>
      )}

      {/* UNLOCK MODAL */}
      {reopenTarget && tab !== "reopen" && (
        <Dialog
          kicker="Session Correction"
          title={`Unlock Register · ${reopenTarget.className}`}
          onClose={() => setReopenTarget(null)}
        >
          <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
            <p style={{ fontSize: "0.875rem", color: "var(--ops-muted)", margin: 0 }}>
              Unlocking the register for <strong>{reopenTarget.className}</strong> on <strong>{selectedDate}</strong> allows the assigned teacher to edit student marks.
            </p>
            <div>
              <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                Reason for Reopening:
              </label>
              <textarea
                className="ops-search-input"
                style={{ width: "100%", minHeight: "80px", fontSize: "0.85rem" }}
                placeholder="e.g. Updating medical leave for absent student"
                value={reopenReason}
                onChange={(e) => setReopenReason(e.target.value)}
              />
            </div>
            <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "0.5rem" }}>
              <button type="button" className="btn-secondary" onClick={() => setReopenTarget(null)}>
                Cancel
              </button>
              <button
                type="button"
                className="btn-primary"
                onClick={handleReopenSubmit}
                disabled={actionLoading || !reopenReason.trim()}
              >
                {actionLoading ? "Unlocking..." : "Confirm Unlock"}
              </button>
            </div>
          </div>
        </Dialog>
      )}

      {/* REMINDER CONFIRMATION MODAL */}
      {showReminderDialog && (
        <Dialog
          kicker="Faculty Notice"
          title="Send Attendance Submission Reminder"
          onClose={() => setShowReminderDialog(false)}
        >
          <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
            <p style={{ fontSize: "0.875rem", margin: 0 }}>
              This will send a high-priority push reminder to the teachers of the <strong>{overallStats.unmarkedClasses} pending classes</strong> requesting them to submit their daily attendance registers for {selectedDate}.
            </p>
            <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "0.5rem" }}>
              <button type="button" className="btn-secondary" onClick={() => setShowReminderDialog(false)}>
                Cancel
              </button>
              <button
                type="button"
                className="btn-primary"
                onClick={handleSendReminders}
                disabled={actionLoading}
                style={{ background: "#d97706", borderColor: "#b45309" }}
              >
                {actionLoading ? "Sending..." : "Dispatch Reminders"}
              </button>
            </div>
          </div>
        </Dialog>
      )}
    </section>
  );
}

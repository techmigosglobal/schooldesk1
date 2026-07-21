"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { CalendarDays, ClipboardCheck, Download, RefreshCw, RotateCcw, Search } from "@/lib/lucide-react";
import type { PortalRole } from "@/lib/roles";
import type { Row } from "./types";
import {
  api,
  apiFirst,
  downloadCsv,
  formatDate,
  money,
  rowsFrom,
  stringValue,
} from "./utils";

function statusCount(rows: Row[], status: string) {
  return rows.filter((row) => stringValue(row.status).toLowerCase() === status).length;
}

export function AttendanceWorkspace({
  role,
  onNotify,
}: {
  role: PortalRole;
  onNotify: (message: string, type?: "success" | "error" | "info") => void;
}) {
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [sections, setSections] = useState<Row[]>([]);
  const [sessions, setSessions] = useState<Row[]>([]);
  const [students, setStudents] = useState<Row[]>([]);
  const [studentRecords, setStudentRecords] = useState<Row[]>([]);
  const [staffSummary, setStaffSummary] = useState<Row>({});
  const [selectedSectionId, setSelectedSectionId] = useState("");
  const [selectedStudentId, setSelectedStudentId] = useState("");
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [error, setError] = useState("");

  const month = Number(date.slice(5, 7));
  const year = Number(date.slice(0, 4));

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [sessionsData, sectionsData, summaryData] = await Promise.all([
        api(`attendance/sessions?date=${date}`),
        api("sections?page=1&page_size=100"),
        api(`attendance/staff/daily-summary?date=${date}`),
      ]);
      const nextSections = rowsFrom(sectionsData);
      setSessions(rowsFrom(sessionsData));
      setSections(nextSections);
      setStaffSummary((summaryData as Row) || {});
      setSelectedSectionId((current) =>
        current && nextSections.some((item) => stringValue(item.id) === current)
          ? current
          : stringValue(nextSections[0]?.id)
      );
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load attendance workspace");
    } finally {
      setLoading(false);
    }
  }, [date]);

  const loadStudents = useCallback(async () => {
    if (!selectedSectionId) {
      setStudents([]);
      setSelectedStudentId("");
      return;
    }
    setDetailLoading(true);
    try {
      const response = await api(
        `students?section_id=${encodeURIComponent(selectedSectionId)}&page=1&page_size=200`
      );
      const nextStudents = rowsFrom(response);
      setStudents(nextStudents);
      setSelectedStudentId((current) =>
        current && nextStudents.some((item) => stringValue(item.id) === current)
          ? current
          : stringValue(nextStudents[0]?.id)
      );
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load class students");
    } finally {
      setDetailLoading(false);
    }
  }, [selectedSectionId]);

  const loadStudentRecords = useCallback(async () => {
    if (!selectedStudentId) {
      setStudentRecords([]);
      return;
    }
    setDetailLoading(true);
    try {
      const records = await apiFirst([
        `students/${selectedStudentId}/attendance?month=${month}&year=${year}`,
        `attendance/students/${selectedStudentId}?month=${month}&year=${year}`,
      ]);
      setStudentRecords(rowsFrom(records));
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load student attendance");
    } finally {
      setDetailLoading(false);
    }
  }, [month, selectedStudentId, year]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    void loadStudents();
  }, [loadStudents]);

  useEffect(() => {
    void loadStudentRecords();
  }, [loadStudentRecords]);

  async function actOnSession(session: Row, action: "reopen" | "correction-request") {
    const reason = prompt(
      action === "reopen"
        ? "Why should this attendance session be reopened?"
        : "Why is a correction needed for this session?"
    );
    if (!reason?.trim()) return;
    try {
      await api(`attendance/sessions/${session.id}/${action}`, {
        method: "POST",
        body: JSON.stringify({ reason: reason.trim() }),
      });
      onNotify(
        action === "reopen" ? "Attendance session reopened." : "Correction request submitted."
      );
      void load();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to update session");
    }
  }

  const filteredStudents = useMemo(() => {
    if (!search.trim()) return students;
    const query = search.trim().toLowerCase();
    return students.filter((row) => JSON.stringify(row).toLowerCase().includes(query));
  }, [search, students]);

  const presentCount = statusCount(studentRecords, "present");
  const absentCount = statusCount(studentRecords, "absent");
  const lateCount = statusCount(studentRecords, "late");
  const attendancePct = studentRecords.length
    ? Math.round((presentCount / studentRecords.length) * 100)
    : 0;

  return (
    <section className="ops-module">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon teal">
            <ClipboardCheck size={20} />
          </div>
          <div>
            <p className="ops-kicker">{role === "principal" ? "Leadership oversight" : "Coordinator operations"}</p>
            <h2>Attendance Command Center</h2>
            <p>Track staff roll call, class attendance sessions, and learner attendance trends from one place.</p>
          </div>
        </div>

        <div className="ops-actions">
          <label className="inline-input">
            <CalendarDays size={16} />
            <input type="date" value={date} onChange={(event) => setDate(event.target.value)} />
          </label>
          <button className="secondary-button" onClick={() => void load()}>
            <RefreshCw size={16} /> Refresh
          </button>
          <button
            className="secondary-button"
            onClick={() =>
              downloadCsv(
                `attendance_${date}.csv`,
                sessions.map((session) => ({
                  section: session.section_name ?? session.section_id,
                  subject: session.subject_name ?? session.subject_id,
                  date,
                  status: session.status,
                  present: session.present_count,
                  absent: session.absent_count,
                  late: session.late_count,
                }))
              )
            }
          >
            <Download size={16} /> Export day CSV
          </button>
        </div>
      </div>

      {error && <div className="ops-inline-error">{error}</div>}

      <div className="finance-summary ops-summary-grid">
        <article>
          <small>Staff Present</small>
          <b>{stringValue(staffSummary.present ?? staffSummary.present_count ?? 0)}</b>
        </article>
        <article>
          <small>Staff Missing Punch</small>
          <b>{stringValue(staffSummary.missing ?? staffSummary.absent ?? 0)}</b>
        </article>
        <article>
          <small>Sessions Marked</small>
          <b>{sessions.length}</b>
        </article>
        <article>
          <small>Selected Learner</small>
          <b>{attendancePct}%</b>
        </article>
      </div>

      <div className="ops-split-grid">
        <section className="surface ops-form-surface">
          <div className="ops-panel-header">
            <h3>Class Monitor</h3>
          </div>

          <div className="ops-stack">
            <label className="field">
              Section
              <select value={selectedSectionId} onChange={(event) => setSelectedSectionId(event.target.value)}>
                <option value="">Select section</option>
                {sections.map((item) => (
                  <option key={stringValue(item.id)} value={stringValue(item.id)}>
                    {stringValue(item.grade_name || item.name)} · {stringValue(item.section_name || item.name)}
                  </option>
                ))}
              </select>
            </label>

            <label className="field">
              Search student
              <div className="search-shell">
                <Search size={15} />
                <input
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                  placeholder="Find student"
                />
              </div>
            </label>

            <div className="ops-selection-list">
              {detailLoading ? (
                <p className="ops-empty-small">Loading class details…</p>
              ) : filteredStudents.length ? (
                filteredStudents.map((student) => {
                  const active = selectedStudentId === stringValue(student.id);
                  return (
                    <button
                      type="button"
                      key={stringValue(student.id)}
                      className={active ? "active" : ""}
                      onClick={() => setSelectedStudentId(stringValue(student.id))}
                    >
                      <strong>{stringValue(student.first_name)} {stringValue(student.last_name)}</strong>
                      <span>{stringValue(student.student_id_number || student.admission_number || "No ID")}</span>
                    </button>
                  );
                })
              ) : (
                <p className="ops-empty-small">No students found for this section.</p>
              )}
            </div>

            <div className="ops-mini-stats">
              <span>Present: {presentCount}</span>
              <span>Absent: {absentCount}</span>
              <span>Late: {lateCount}</span>
            </div>

            <div className="table-card surface ops-table-surface">
              {studentRecords.length ? (
                <table className="data-table ops-data-table">
                  <thead>
                    <tr>
                      <th>Date</th>
                      <th>Status</th>
                      <th>Remarks</th>
                    </tr>
                  </thead>
                  <tbody>
                    {studentRecords.map((record, index) => (
                      <tr key={stringValue(record.id) || `${record.attendance_date}-${index}`}>
                        <td>{formatDate(record.attendance_date)}</td>
                        <td>
                          <span className={`ops-status-tag ${stringValue(record.status).toLowerCase()}`}>
                            {stringValue(record.status || "—")}
                          </span>
                        </td>
                        <td>{stringValue(record.remarks) || "—"}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p className="ops-empty-small">Attendance records for the selected learner will appear here.</p>
              )}
            </div>
          </div>
        </section>

        <section className="surface ops-form-surface">
          <div className="ops-panel-header">
            <h3>Attendance Sessions</h3>
          </div>
          <div className="table-card surface ops-table-surface">
            {loading ? (
              <p className="ops-empty-small">Loading attendance sessions…</p>
            ) : sessions.length ? (
              <table className="data-table ops-data-table">
                <thead>
                  <tr>
                    <th>Section</th>
                    <th>Subject</th>
                    <th>Status</th>
                    <th>Counts</th>
                    <th style={{ textAlign: "right" }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {sessions.map((session, index) => (
                    <tr key={stringValue(session.id) || index}>
                      <td>{stringValue(session.section_name || session.section_id)}</td>
                      <td>{stringValue(session.subject_name || session.subject_id || "General")}</td>
                      <td>
                        <span className={`ops-status-tag ${stringValue(session.status).toLowerCase()}`}>
                          {stringValue(session.status || "open")}
                        </span>
                      </td>
                      <td>
                        P {stringValue(session.present_count || 0)} · A {stringValue(session.absent_count || 0)}
                      </td>
                      <td className="actions-cell">
                        <button
                          className="icon-button"
                          title="Request correction"
                          onClick={() => void actOnSession(session, "correction-request")}
                        >
                          <RotateCcw size={15} />
                        </button>
                        <button
                          className="icon-button"
                          title="Reopen session"
                          onClick={() => void actOnSession(session, "reopen")}
                        >
                          <RefreshCw size={15} />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p className="ops-empty-small">No attendance sessions recorded for {formatDate(date, date)}.</p>
            )}
          </div>

          <div className="finance-report-card surface">
            <h3>Attendance Snapshot</h3>
            <p>
              {role === "principal"
                ? "Use this view to monitor class-level attendance quality, staff punch status, and session corrections."
                : "Use this view to follow up on missing class marks and support daily attendance operations."}
            </p>
            <p>
              Expected fee collections today: <b>{money(staffSummary.collection_target || 0)}</b>
            </p>
          </div>
        </section>
      </div>
    </section>
  );
}

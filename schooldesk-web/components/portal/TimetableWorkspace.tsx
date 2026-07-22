"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CalendarClock,
  CircleAlert,
  Eye,
  Pencil,
  Plus,
  RefreshCw,
  Sparkles,
  Trash2,
} from "@/lib/lucide-react";
import type { Row } from "./types";
import { api, displayName, nested, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";
import { TimetableSlotDialog } from "./TimetableSlotDialog";
import { TimetableGeneratorDialog } from "./TimetableGeneratorDialog";

const DAYS = [
  { value: 1, label: "Monday", short: "Mon" },
  { value: 2, label: "Tuesday", short: "Tue" },
  { value: 3, label: "Wednesday", short: "Wed" },
  { value: 4, label: "Thursday", short: "Thu" },
  { value: 5, label: "Friday", short: "Fri" },
  { value: 6, label: "Saturday", short: "Sat" },
];

type SlotDialogState = {
  open: boolean;
  row?: Row;
  readOnly?: boolean;
};

function educatorInitials(name: string) {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase() || "T";
}

export function TimetableWorkspace({
  createToken,
  onSaved,
  onNotify,
}: {
  createToken: number;
  onSaved: () => void;
  onNotify: (message: string) => void;
}) {
  const [classes, setClasses] = useState<Row[]>([]);
  const [selectedSectionId, setSelectedSectionId] = useState<string>("");
  const [slots, setSlots] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState("");
  const [viewMode, setViewMode] = useState<"grid" | "day">("grid");
  const [selectedDay, setSelectedDay] = useState<number>(1);

  const [slotDialog, setSlotDialog] = useState<SlotDialogState>({ open: false });
  const [generatorOpen, setGeneratorOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Row | null>(null);
  const [deleting, setDeleting] = useState(false);

  const loadClasses = useCallback(async () => {
    try {
      const res = await api("principal/classes");
      const list = rowsFrom(res);
      setClasses(list);
      if (list.length > 0 && !selectedSectionId) {
        setSelectedSectionId(stringValue(list[0].section_id || list[0].id));
      }
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load class sections");
    }
  }, [selectedSectionId]);

  const loadSlots = useCallback(async (sectionId: string, manual = false) => {
    if (!sectionId) return;
    if (manual) setRefreshing(true);
    else setLoading(true);
    setError("");
    try {
      const res = await api(`timetable/slots?section_id=${sectionId}`);
      setSlots(rowsFrom(res));
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load timetable slots");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    void loadClasses();
  }, [loadClasses]);

  useEffect(() => {
    if (selectedSectionId) {
      void loadSlots(selectedSectionId);
    }
  }, [selectedSectionId, loadSlots]);

  useEffect(() => {
    if (createToken > 0) {
      setSlotDialog({ open: true, readOnly: false });
    }
  }, [createToken]);

  const currentClass = useMemo(
    () => classes.find((c) => stringValue(c.section_id || c.id) === selectedSectionId),
    [classes, selectedSectionId]
  );

  const periodsList = useMemo(() => {
    const periodNums = Array.from(new Set(slots.map((s) => Number(s.period_number || 1)))).sort(
      (a, b) => a - b
    );
    return periodNums.length > 0 ? periodNums : [1, 2, 3, 4, 5, 6, 7];
  }, [slots]);

  async function deleteSlot() {
    if (!deleteTarget) return;
    setDeleting(true);
    setError("");
    try {
      await api(`timetable/slots/${deleteTarget.id}`, { method: "DELETE" });
      onSaved();
      onNotify("Timetable period slot removed.");
      setDeleteTarget(null);
      await loadSlots(selectedSectionId, true);
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to delete timetable slot");
    } finally {
      setDeleting(false);
    }
  }

  async function clearClassSchedule() {
    if (!selectedSectionId) return;
    if (!confirm("Are you sure you want to clear all timetable slots for this class?")) return;
    setRefreshing(true);
    try {
      await api(`timetable/slots?section_id=${selectedSectionId}`, { method: "DELETE" });
      onSaved();
      onNotify("Class timetable schedule cleared.");
      await loadSlots(selectedSectionId, true);
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to clear class schedule");
    } finally {
      setRefreshing(false);
    }
  }

  return (
    <section className="ops-module timetable-workspace">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon teal" style={{ background: "#e0f2f1", color: "#00695c" }}>
            <CalendarClock size={20} />
          </div>
          <div>
            <p className="ops-kicker">Resource management</p>
            <h2>Timetables</h2>
            <p>Class period schedules, educator assignments, and smart timetable generator.</p>
          </div>
        </div>
        <div className="ops-actions">
          <button className="secondary-button" onClick={() => void loadSlots(selectedSectionId, true)} disabled={refreshing}>
            <RefreshCw size={16} className={refreshing ? "spin" : ""} /> Refresh
          </button>
          <button className="secondary-button" onClick={() => setGeneratorOpen(true)}>
            <Sparkles size={16} /> Smart Auto-Generate
          </button>
          <button className="primary-button" onClick={() => setSlotDialog({ open: true, readOnly: false })}>
            <Plus size={16} /> Add period slot
          </button>
        </div>
      </div>

      <div className="student-directory-toolbar" style={{ flexWrap: "wrap", gap: "0.8rem" }}>
        <label style={{ display: "flex", alignItems: "center", gap: "0.5rem", fontWeight: 650, color: "#193c59" }}>
          Select Class Section:
          <select
            value={selectedSectionId}
            onChange={(e) => setSelectedSectionId(e.target.value)}
            style={{ padding: "0.5rem 0.8rem", borderRadius: "8px", border: "1px solid #c8d8e4", background: "#fff", fontWeight: 600 }}
          >
            {classes.map((cls) => {
              const cId = stringValue(cls.section_id || cls.id);
              return (
                <option key={cId} value={cId}>
                  {stringValue(cls.grade_name)} - {stringValue(cls.section_name ?? cls.name)}
                </option>
              );
            })}
          </select>
        </label>

        <div className="finance-tabs" style={{ margin: 0 }}>
          <button
            type="button"
            className={viewMode === "grid" ? "active" : ""}
            onClick={() => setViewMode("grid")}
          >
            Weekly Grid Matrix
          </button>
          <button
            type="button"
            className={viewMode === "day" ? "active" : ""}
            onClick={() => setViewMode("day")}
          >
            Day-by-Day View
          </button>
        </div>

        <span className="ops-count" style={{ marginLeft: "auto" }}>
          <b>{slots.length}</b> period slot{slots.length === 1 ? "" : "s"} scheduled
        </span>

        {slots.length > 0 && (
          <button className="secondary-button danger" style={{ fontSize: "0.78rem" }} onClick={() => void clearClassSchedule()}>
            Clear Class Schedule
          </button>
        )}
      </div>

      {currentClass && (
        <div style={{ padding: "0.75rem 1rem", background: "#f4f8fb", border: "1px solid #d6e4ef", borderRadius: "10px", marginBottom: "1rem", display: "flex", gap: "1.5rem", flexWrap: "wrap", fontSize: "0.83rem" }}>
          <span>Class Section: <b>{stringValue(currentClass.grade_name)} - {stringValue(currentClass.section_name ?? currentClass.name)}</b></span>
          <span>Class Teacher: <b>{stringValue(currentClass.class_teacher || "Unassigned")}</b></span>
          <span>Co-Teacher: <b>{stringValue(currentClass.co_teacher || "Unassigned")}</b></span>
          <span>Room: <b>{stringValue(currentClass.room_number || "Unassigned")}</b></span>
        </div>
      )}

      {error && (
        <div className="ops-inline-error">
          <CircleAlert size={16} />
          {error}
        </div>
      )}

      {loading ? (
        <div className="skeleton-container" style={{ padding: "1rem" }}>
          {Array.from({ length: 5 }, (_, idx) => (
            <div className="skeleton skeleton-row" key={idx} />
          ))}
        </div>
      ) : viewMode === "grid" ? (
        <div className="table-card surface ops-table-surface student-directory-table-wrap" style={{ overflowX: "auto" }}>
          <table className="data-table" style={{ minWidth: "900px" }}>
            <thead>
              <tr>
                <th style={{ width: "90px" }}>Period</th>
                {DAYS.map((day) => (
                  <th key={day.value} style={{ textAlign: "center" }}>
                    {day.label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {periodsList.map((periodNum) => (
                <tr key={periodNum}>
                  <td style={{ verticalAlign: "top", background: "#fcfdfe" }}>
                    <b style={{ color: "#1c4a70" }}>Period {periodNum}</b>
                  </td>
                  {DAYS.map((day) => {
                    const slot = slots.find(
                      (s) => Number(s.day_of_week) === day.value && Number(s.period_number) === periodNum
                    );
                    if (!slot) {
                      return (
                        <td
                          key={day.value}
                          style={{
                            textAlign: "center",
                            background: "#fafcfd",
                            border: "1px stroke #eef3f6",
                            padding: "0.6rem",
                          }}
                        >
                          <span style={{ color: "#b4c3cf", fontSize: "0.75rem" }}>—</span>
                        </td>
                      );
                    }

                    const slotType = stringValue(slot.slot_type || "regular");
                    const subjectName = stringValue(
                      slot.subject_name || (slot.subject as Row)?.subject_name || (slotType === "break" ? "Break" : "Study Period")
                    );
                    const subjectCode = stringValue((slot.subject as Row)?.subject_code);
                    const teacherName = displayName((slot.staff as Row) ?? {}) || stringValue(slot.staff_name);
                    const startTime = stringValue(slot.start_time);
                    const endTime = stringValue(slot.end_time);

                    if (slotType === "break") {
                      return (
                        <td
                          key={day.value}
                          style={{
                            background: "#fef8ea",
                            border: "1px solid #f6e6be",
                            textAlign: "center",
                            padding: "0.5rem",
                            borderRadius: "6px",
                          }}
                        >
                          <span style={{ color: "#9c6700", fontWeight: 700, fontSize: "0.78rem" }}>
                            ☕ {subjectName}
                          </span>
                          <small style={{ display: "block", color: "#b5821c", fontSize: "0.72rem" }}>
                            {startTime} - {endTime}
                          </small>
                        </td>
                      );
                    }

                    return (
                      <td
                        key={day.value}
                        style={{
                          background: slotType === "free" ? "#f8fafb" : "#f0f8ff",
                          border: "1px solid #cde3f7",
                          padding: "0.5rem",
                          borderRadius: "8px",
                          position: "relative",
                        }}
                      >
                        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                          <span
                            style={{
                              fontWeight: 700,
                              fontSize: "0.82rem",
                              color: slotType === "free" ? "#5a6e7c" : "#0d5291",
                            }}
                          >
                            {subjectName}
                          </span>
                          {subjectCode && (
                            <span
                              style={{
                                fontSize: "0.68rem",
                                padding: "0.1rem 0.35rem",
                                background: "#fff",
                                border: "1px solid #bad8f5",
                                borderRadius: "10px",
                                color: "#0c5496",
                                fontWeight: 650,
                              }}
                            >
                              {subjectCode}
                            </span>
                          )}
                        </div>

                        {teacherName && (
                          <div style={{ display: "flex", alignItems: "center", gap: "0.3rem", marginTop: "0.3rem" }}>
                            <span
                              style={{
                                width: "18px",
                                height: "18px",
                                borderRadius: "50%",
                                background: "#dbeefe",
                                color: "#1d639e",
                                fontSize: "0.62rem",
                                fontWeight: 750,
                                display: "inline-flex",
                                alignItems: "center",
                                justifyContent: "center",
                              }}
                            >
                              {educatorInitials(teacherName)}
                            </span>
                            <small style={{ color: "#3d576b", fontWeight: 600, fontSize: "0.74rem" }}>
                              {teacherName}
                            </small>
                          </div>
                        )}

                        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: "0.35rem" }}>
                          <small style={{ color: "#6a8192", fontSize: "0.71rem" }}>
                            {startTime} - {endTime}
                          </small>
                          <div style={{ display: "flex", gap: "0.2rem" }}>
                            <button
                              className="icon-button"
                              title="Edit slot"
                              style={{ width: "20px", height: "20px", padding: 0 }}
                              onClick={() => setSlotDialog({ open: true, row: slot, readOnly: false })}
                            >
                              <Pencil size={12} />
                            </button>
                            <button
                              className="icon-button danger"
                              title="Delete slot"
                              style={{ width: "20px", height: "20px", padding: 0 }}
                              onClick={() => setDeleteTarget(slot)}
                            >
                              <Trash2 size={12} />
                            </button>
                          </div>
                        </div>
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div style={{ display: "grid", gap: "1rem" }}>
          <div className="finance-tabs" style={{ margin: 0 }}>
            {DAYS.map((day) => (
              <button
                key={day.value}
                type="button"
                className={selectedDay === day.value ? "active" : ""}
                onClick={() => setSelectedDay(day.value)}
              >
                {day.label}
              </button>
            ))}
          </div>

          <div className="table-card surface ops-table-surface student-directory-table-wrap">
            {slots.filter((s) => Number(s.day_of_week) === selectedDay).length ? (
              <table className="data-table student-directory-table">
                <thead>
                  <tr>
                    <th>Period</th>
                    <th>Time</th>
                    <th>Subject</th>
                    <th>Educator</th>
                    <th>Room</th>
                    <th style={{ textAlign: "right" }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {slots
                    .filter((s) => Number(s.day_of_week) === selectedDay)
                    .sort((a, b) => Number(a.period_number) - Number(b.period_number))
                    .map((slot) => {
                      const slotType = stringValue(slot.slot_type || "regular");
                      const subjectName = stringValue(
                        slot.subject_name || (slot.subject as Row)?.subject_name || (slotType === "break" ? "Break" : "Study Period")
                      );
                      const teacherName = displayName((slot.staff as Row) ?? {}) || stringValue(slot.staff_name);
                      return (
                        <tr key={stringValue(slot.id)}>
                          <td><b>Period {stringValue(slot.period_number)}</b></td>
                          <td>{stringValue(slot.start_time)} - {stringValue(slot.end_time)}</td>
                          <td>
                            <span className="status-pill" style={{ background: slotType === "break" ? "#fff8e7" : "#eef6fd", color: slotType === "break" ? "#916000" : "#0d5598" }}>
                              {subjectName}
                            </span>
                          </td>
                          <td>{teacherName || "—"}</td>
                          <td>{stringValue(slot.room_number || (slot.room as Row)?.room_number || "—")}</td>
                          <td className="actions-cell" style={{ textAlign: "right" }}>
                            <button
                              className="icon-button"
                              title="Edit slot"
                              onClick={() => setSlotDialog({ open: true, row: slot, readOnly: false })}
                            >
                              <Pencil size={15} />
                            </button>
                            <button
                              className="icon-button danger"
                              title="Delete slot"
                              onClick={() => setDeleteTarget(slot)}
                            >
                              <Trash2 size={15} />
                            </button>
                          </td>
                        </tr>
                      );
                    })}
                </tbody>
              </table>
            ) : (
              <p className="ops-empty">No period slots scheduled for {DAYS.find((d) => d.value === selectedDay)?.label}.</p>
            )}
          </div>
        </div>
      )}

      {slotDialog.open && (
        <TimetableSlotDialog
          row={slotDialog.row}
          defaultSectionId={selectedSectionId}
          readOnly={slotDialog.readOnly}
          onClose={() => setSlotDialog({ open: false })}
          onSaved={() => {
            onSaved();
            onNotify(slotDialog.row ? "Timetable slot updated." : "Timetable slot added.");
            void loadSlots(selectedSectionId, true);
          }}
        />
      )}

      {generatorOpen && (
        <TimetableGeneratorDialog
          defaultSectionId={selectedSectionId}
          onClose={() => setGeneratorOpen(false)}
          onGenerated={(count) => {
            onSaved();
            onNotify(`Generated ${count} timetable slots cleanly!`);
            void loadSlots(selectedSectionId, true);
          }}
        />
      )}

      {deleteTarget && (
        <Dialog kicker="Permanent action" title="Delete timetable period slot?" onClose={() => !deleting && setDeleteTarget(null)}>
          <div className="student-delete-dialog">
            <CircleAlert size={22} />
            <p>
              Remove Period {stringValue(deleteTarget.period_number)} slot (
              {stringValue(deleteTarget.subject_name || "Period")}) from the class schedule?
            </p>
          </div>
          <div className="dialog-footer">
            <button className="secondary-button" type="button" disabled={deleting} onClick={() => setDeleteTarget(null)}>
              Cancel
            </button>
            <button className="danger-button" type="button" disabled={deleting} onClick={() => void deleteSlot()}>
              {deleting ? "Deleting…" : "Delete slot"}
            </button>
          </div>
        </Dialog>
      )}
    </section>
  );
}

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CalendarClock,
  CircleAlert,
  Info,
  Minus,
  Plus,
  RefreshCw,
  X,
} from "@/lib/lucide-react";
import { PortalModuleSkeleton } from "@/components/loading-skeletons";
import type { Row } from "./types";
import { api, nested, rowsFrom, stringValue } from "./utils";

const DEFAULT_WORKING_DAYS = [1, 2, 3, 4, 5, 6];
const DAYS = [
  { value: 1, label: "Monday", short: "Mon" },
  { value: 2, label: "Tuesday", short: "Tue" },
  { value: 3, label: "Wednesday", short: "Wed" },
  { value: 4, label: "Thursday", short: "Thu" },
  { value: 5, label: "Friday", short: "Fri" },
  { value: 6, label: "Saturday", short: "Sat" },
  { value: 7, label: "Sunday", short: "Sun" },
];

type DraftRow = {
  id: string;
  startTime: string;
  endTime: string;
  subjectId: string;
  staffId: string;
};

type References = {
  subjects: Row[];
  gradeSubjects: Row[];
  staffSubjects: Row[];
};

function newRow(): DraftRow {
  return {
    id: `${Date.now()}-${Math.random()}`,
    startTime: "",
    endTime: "",
    subjectId: "",
    staffId: "",
  };
}

function text(value: unknown) {
  return stringValue(value).trim();
}

function minutes(value: string): number | null {
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(value.trim())) return null;
  const [hour, minute] = value.split(":").map(Number);
  return hour * 60 + minute;
}

function classId(row: Row) {
  return text(row.section_id || row.id);
}

function classLabel(row: Row) {
  const grade = text(row.grade_name || nested(row, "grade").grade_name);
  const section = text(row.section_name || row.name);
  return [grade, section].filter(Boolean).join(" - ") || "Class";
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
  const [selectedSectionId, setSelectedSectionId] = useState("");
  const [slots, setSlots] = useState<Row[]>([]);
  const [workingDays, setWorkingDays] = useState<number[]>(DEFAULT_WORKING_DAYS);
  const [refs, setRefs] = useState<References>({
    subjects: [],
    gradeSubjects: [],
    staffSubjects: [],
  });
  const [editorOpen, setEditorOpen] = useState(false);
  const [selectedDays, setSelectedDays] = useState<number[]>(DAYS.map((day) => day.value));
  const [rows, setRows] = useState<DraftRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const currentClass = useMemo(
    () => classes.find((row) => classId(row) === selectedSectionId),
    [classes, selectedSectionId],
  );
  const academicYearId = text(currentClass?.academic_year_id);

  const loadReferences = useCallback(async () => {
    const [subjects, gradeSubjects, staffSubjects] = await Promise.all([
      api("subjects").catch(() => []),
      api("grade-subjects?page_size=500").catch(() => []),
      api("staff-subjects?page_size=500").catch(() => []),
    ]);
    setRefs({
      subjects: rowsFrom(subjects),
      gradeSubjects: rowsFrom(gradeSubjects),
      staffSubjects: rowsFrom(staffSubjects),
    });
  }, []);

  const loadClasses = useCallback(async () => {
    const response = await api("principal/classes");
    const list = rowsFrom(response);
    setClasses(list);
    if (!list.length) setLoading(false);
    setSelectedSectionId((current) =>
      list.some((row) => classId(row) === current) ? current : classId(list[0] || {}),
    );
  }, []);

  const loadWorkingDays = useCallback(async () => {
    try {
      const response = await api("timetable/working-days");
      const configured: number[] = Array.isArray(response?.days)
        ? response.days.map((value: unknown) => Number(value)).filter((day: number) => day >= 1 && day <= 7)
        : [];
      const days: number[] = [...new Set<number>(configured)].sort((a, b) => a - b);
      const activeDays = days.length ? days : DEFAULT_WORKING_DAYS;
      setWorkingDays(activeDays);
      setSelectedDays(activeDays);
    } catch {
      setWorkingDays(DEFAULT_WORKING_DAYS);
      setSelectedDays(DEFAULT_WORKING_DAYS);
    }
  }, []);

  const loadSlots = useCallback(async (sectionId: string, manual = false) => {
    if (!sectionId) return;
    if (manual) setRefreshing(true);
    else setLoading(true);
    setError("");
    try {
      const row = classes.find((item) => classId(item) === sectionId);
      const query = new URLSearchParams({ section_id: sectionId });
      const year = text(row?.academic_year_id);
      if (year) query.set("academic_year_id", year);
      setSlots(rowsFrom(await api(`timetable/slots?${query.toString()}`)));
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load timetable slots");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [classes]);

  const loadAll = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      await Promise.all([loadClasses(), loadReferences(), loadWorkingDays()]);
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load timetable setup");
      setLoading(false);
    }
  }, [loadClasses, loadReferences, loadWorkingDays]);

  useEffect(() => {
    void loadAll();
  }, [loadAll]);

  useEffect(() => {
    if (selectedSectionId) void loadSlots(selectedSectionId);
  }, [selectedSectionId, loadSlots]);

  useEffect(() => {
    if (createToken > 0 && selectedSectionId) openEditor(slots);
    // createToken is an explicit create command from the portal shell.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [createToken]);

  const subjectOptions = useMemo(() => {
    const gradeId = text(currentClass?.grade_id || nested(currentClass || {}, "grade").id);
    const subjectNames = new Map(
      refs.subjects.map((subject) => [text(subject.id), text(subject.subject_name || subject.name)]),
    );
    const ids = new Set<string>();
    refs.gradeSubjects.forEach((mapping) => {
      const mappingSection = text(mapping.section_id);
      const mappingGrade = text(mapping.grade_id || nested(mapping, "grade").id);
      const mappingYear = text(mapping.academic_year_id);
      const applies = (mappingSection ? mappingSection === selectedSectionId : mappingGrade === gradeId) &&
        (!mappingYear || !academicYearId || mappingYear === academicYearId);
      if (applies) ids.add(text(mapping.subject_id || nested(mapping, "subject").id));
    });
    return [...ids]
      .filter(Boolean)
      .map((id) => ({ id, name: subjectNames.get(id) || text(refs.gradeSubjects.find((mapping) => text(mapping.subject_id) === id)?.subject_name) || id }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }, [academicYearId, currentClass, refs, selectedSectionId]);

  function staffForSubject(subjectId: string) {
    if (!subjectId || !currentClass) return "";
    const gradeId = text(currentClass.grade_id || nested(currentClass, "grade").id);
    const candidates = refs.staffSubjects
      .filter((mapping) => text(mapping.subject_id || nested(mapping, "subject").id) === subjectId)
      .filter((mapping) => {
        const mappingSection = text(mapping.section_id);
        const mappingGrade = text(mapping.grade_id || nested(mapping, "grade").id);
        const mappingYear = text(mapping.academic_year_id);
        return (mappingSection === selectedSectionId || (!mappingSection && mappingGrade === gradeId)) &&
          (!mappingYear || !academicYearId || mappingYear === academicYearId);
      })
      .sort((a, b) => Number(b.is_primary === true) - Number(a.is_primary === true));
    return text(candidates[0]?.staff_id);
  }

  function rowsForDay(day: number, source = slots): DraftRow[] {
    return source
      .filter((slot) => Number(slot.day_of_week) === day)
      .sort((a, b) => Number(a.period_number || 0) - Number(b.period_number || 0))
      .map((slot) => ({
        id: `${text(slot.id)}-${day}`,
        startTime: text(slot.start_time),
        endTime: text(slot.end_time),
        subjectId: text(slot.slot_type) === "free" ? "" : text(slot.subject_id),
        staffId: text(slot.staff_id),
      }));
  }

  function openEditor(source: Row[]) {
    const firstDay = DAYS.find((day) => source.some((slot) => Number(slot.day_of_week) === day.value))?.value || 1;
    const existingRows = rowsForDay(firstDay, source);
    setRows(existingRows.length ? existingRows : [newRow(), newRow(), newRow()]);
    setSelectedDays([...workingDays]);
    setEditorOpen(true);
  }

  function toggleDay(day: number) {
    setSelectedDays((current) => {
      if (current.includes(day)) {
        if (current.length === 1) return current;
        const next = current.filter((value) => value !== day);
        if (next.length === 1) {
          const nextRows = rowsForDay(next[0]);
          setRows(nextRows.length ? nextRows : [newRow(), newRow(), newRow()]);
        }
        return next;
      }
      return [...current, day].sort((a, b) => a - b);
    });
  }

  function updateRow(index: number, patch: Partial<DraftRow>) {
    setRows((current) => current.map((row, rowIndex) => rowIndex === index ? { ...row, ...patch } : row));
  }

  function addRow(after?: number) {
    setRows((current) => {
      const next = [...current];
      next.splice(after === undefined ? next.length : after + 1, 0, newRow());
      return next;
    });
  }

  function removeRow(index: number) {
    if (rows.length <= 1) return;
    setRows((current) => current.filter((_, rowIndex) => rowIndex !== index));
  }

  function validateRows() {
    if (!rows.length) return "Add at least one timetable row.";
    let previousEnd = -1;
    for (const [index, row] of rows.entries()) {
      const start = minutes(row.startTime);
      const end = minutes(row.endTime);
      if (start === null || end === null) return `Enter From and To as HH:MM on row ${index + 1}.`;
      if (end <= start) return `To time must be after From time on row ${index + 1}.`;
      if (start < previousEnd) return "Rows must be in ascending order and cannot overlap.";
      if (row.subjectId && !subjectOptions.some((subject) => subject.id === row.subjectId)) {
        return `Choose a subject mapped to this class on row ${index + 1}.`;
      }
      previousEnd = end;
    }
    return "";
  }

  async function save() {
    const validation = validateRows();
    if (validation) {
      setError(validation);
      return;
    }
    if (!selectedSectionId || !academicYearId || !selectedDays.length) {
      setError("Select a class, academic year, and at least one day.");
      return;
    }
    const existingCount = slots.filter((slot) => selectedDays.includes(Number(slot.day_of_week))).length;
    if (existingCount && !window.confirm(`Replace the existing timetable on ${selectedDays.map((day) => DAYS[day - 1].label).join(", ")}? Other days will stay unchanged.`)) return;
    setSaving(true);
    setError("");
    try {
      await api("timetable/slots/replace-days", {
        method: "PUT",
        body: JSON.stringify({
          section_id: selectedSectionId,
          academic_year_id: academicYearId,
          days: selectedDays,
          rows: rows.map((row) => ({
            start_time: row.startTime,
            end_time: row.endTime,
            subject_id: row.subjectId || null,
            staff_id: row.staffId || staffForSubject(row.subjectId) || null,
          })),
        }),
      });
      await loadSlots(selectedSectionId, true);
      setEditorOpen(false);
      onSaved();
      onNotify("Timetable saved and published.");
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to save timetable");
    } finally {
      setSaving(false);
    }
  }

  return (
    <section className="ops-module timetable-workspace">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon teal" style={{ background: "#e7f1fa", color: "#0e5ea8" }}>
            <CalendarClock size={20} />
          </div>
          <div>
            <p className="ops-kicker">Class schedule</p>
            <h2>Timetables</h2>
            <p>Enter one timetable template and apply it to selected days.</p>
          </div>
        </div>
        <button type="button" className="secondary-button" onClick={() => void loadSlots(selectedSectionId, true)} disabled={refreshing || !selectedSectionId}>
          <RefreshCw size={16} className={refreshing ? "spin" : ""} /> Refresh
        </button>
      </div>

      <div className="student-directory-toolbar" style={{ flexWrap: "wrap", gap: "0.8rem" }}>
        <label style={{ display: "flex", alignItems: "center", gap: "0.5rem", fontWeight: 650, color: "#193c59" }}>
          Select Class:
          <select value={selectedSectionId} onChange={(event) => { setSelectedSectionId(event.target.value); setEditorOpen(false); }} disabled={!classes.length || saving} aria-label="Select timetable class section">
            {classes.map((row) => <option key={classId(row)} value={classId(row)}>{classLabel(row)}</option>)}
          </select>
        </label>
        <span className="ops-count" style={{ marginLeft: "auto" }}><b>{slots.length}</b> saved row{slots.length === 1 ? "" : "s"}</span>
      </div>

      {error && <div className="ops-inline-error"><CircleAlert size={16} />{error}</div>}

      {loading ? (
        <PortalModuleSkeleton variant="timetable" label="Loading timetable editor" />
      ) : !classes.length ? (
        <div className="ops-empty" role="status">No class sections are available yet. Create and assign a class before managing its timetable.</div>
      ) : editorOpen ? (
        <div className="timetable-editor-shell">
          <div className="table-card surface ops-table-surface" style={{ padding: "1rem" }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: "1rem", alignItems: "flex-start", flexWrap: "wrap" }}>
              <div>
                <h3 style={{ margin: 0 }}>{classLabel(currentClass || {})}</h3>
                <p style={{ margin: "0.35rem 0 0", color: "#637887", fontSize: "0.85rem" }}>Select days, then edit the shared two-column timetable.</p>
              </div>
              <button type="button" className="icon-button" title="Close editor" aria-label="Close editor" onClick={() => setEditorOpen(false)} disabled={saving}><X size={17} /></button>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: "0.55rem", flexWrap: "wrap", marginTop: "1rem" }}>
              <strong style={{ color: "#193c59" }}>Apply to days</strong>
              <div className="timetable-day-picker" role="group" aria-label="Working days">
                {DAYS.map((day) => {
                  const selected = selectedDays.includes(day.value);
                  const active = workingDays.includes(day.value);
                  return <button key={day.value} type="button" className={`timetable-day-button ${selected ? "selected" : ""} ${active ? "" : "optional"}`} aria-pressed={selected} onClick={() => toggleDay(day.value)} disabled={saving}>{day.short}</button>;
                })}
              </div>
              <button type="button" className="secondary-button" onClick={() => setSelectedDays([...workingDays])} disabled={saving}>Select all working days</button>
            </div>
            <p style={{ margin: "0.65rem 0 0", color: "#637887", fontSize: "0.8rem" }}>{selectedDays.length} day{selectedDays.length === 1 ? "" : "s"} selected. Plus, minus, and field changes apply to all selected days.</p>
          </div>

          {!subjectOptions.length && <div className="ops-inline-error" style={{ marginTop: "1rem" }}><Info size={16} />No subjects are mapped to this class yet. Configure class subjects before adding teaching periods.</div>}

          <div className="table-card surface ops-table-surface" style={{ overflowX: "auto", marginTop: "1rem" }}>
            <table className="data-table" style={{ minWidth: "700px" }}>
              <thead><tr><th scope="col">Time</th><th scope="col">Subject</th><th scope="col" aria-label="Row actions" /></tr></thead>
              <tbody>
                {rows.map((row, index) => {
                  const validSubject = !row.subjectId || subjectOptions.some((subject) => subject.id === row.subjectId);
                  return <tr key={row.id}>
                    <td style={{ width: "260px" }}>
                      <div style={{ display: "flex", alignItems: "center", gap: "0.45rem" }}>
                        <input aria-label={`From time row ${index + 1}`} value={row.startTime} onChange={(event) => updateRow(index, { startTime: event.target.value })} placeholder="HH:MM" inputMode="numeric" maxLength={5} />
                        <span>to</span>
                        <input aria-label={`To time row ${index + 1}`} value={row.endTime} onChange={(event) => updateRow(index, { endTime: event.target.value })} placeholder="HH:MM" inputMode="numeric" maxLength={5} />
                      </div>
                    </td>
                    <td>
                      <select aria-label={`Subject row ${index + 1}`} value={validSubject ? row.subjectId : ""} onChange={(event) => updateRow(index, { subjectId: event.target.value, staffId: staffForSubject(event.target.value) })}>
                        <option value="">Free Period</option>
                        {subjectOptions.map((subject) => <option key={subject.id} value={subject.id}>{subject.name}</option>)}
                      </select>
                    </td>
                    <td style={{ whiteSpace: "nowrap", textAlign: "right" }}>
                      <button type="button" className="icon-button" title={`Add row after ${index + 1}`} aria-label={`Add row after ${index + 1}`} onClick={() => addRow(index)} disabled={saving}><Plus size={16} /></button>
                      <button type="button" className="icon-button danger" title={`Remove row ${index + 1}`} aria-label={`Remove row ${index + 1}`} onClick={() => removeRow(index)} disabled={saving || rows.length <= 1}><Minus size={16} /></button>
                    </td>
                  </tr>;
                })}
              </tbody>
            </table>
            {!rows.length && <div className="ops-empty" style={{ margin: "1rem" }}><button type="button" className="primary-button" onClick={() => addRow()} disabled={saving}><Plus size={15} /> Add row</button></div>}
          </div>

          <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.7rem", marginTop: "1rem" }}>
            <button type="button" className="secondary-button" onClick={() => setEditorOpen(false)} disabled={saving}>Cancel</button>
            <button type="button" className="primary-button" onClick={() => void save()} disabled={saving}>{saving ? "Saving…" : "Save timetable"}</button>
          </div>
        </div>
      ) : (
        <div className="table-card surface ops-table-surface" style={{ padding: "1.2rem" }}>
          <div style={{ display: "flex", gap: "0.8rem", alignItems: "flex-start" }}>
            <CalendarClock size={22} style={{ color: "#0e5ea8", marginTop: "0.15rem" }} />
            <div>
              <h3 style={{ margin: 0 }}>{slots.length ? "Existing timetable" : "No timetable published yet"}</h3>
              <p style={{ color: "#637887", margin: "0.4rem 0 1rem" }}>{slots.length ? `${slots.length} saved row${slots.length === 1 ? "" : "s"} for ${classLabel(currentClass || {})}.` : "Start with three rows and apply them to selected working days."}</p>
              <button type="button" className="primary-button" onClick={() => openEditor(slots)}><Plus size={16} /> {slots.length ? "View / Edit timetable" : "Create timetable"}</button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}

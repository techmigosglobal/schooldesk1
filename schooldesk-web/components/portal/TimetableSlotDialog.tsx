"use client";

import { useEffect, useState } from "react";
import type { Row } from "./types";
import { api, displayName, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

const DAYS = [
  { value: 1, label: "Monday" },
  { value: 2, label: "Tuesday" },
  { value: 3, label: "Wednesday" },
  { value: 4, label: "Thursday" },
  { value: 5, label: "Friday" },
  { value: 6, label: "Saturday" },
];

export function TimetableSlotDialog({
  row,
  defaultSectionId,
  readOnly,
  onClose,
  onSaved,
}: {
  row?: Row;
  defaultSectionId?: string;
  readOnly?: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [refs, setRefs] = useState<{
    classes: Row[];
    subjects: Row[];
    staff: Row[];
    years: Row[];
    gradeSubjects: Row[];
    staffSubjects: Row[];
  }>({
    classes: [],
    subjects: [],
    staff: [],
    years: [],
    gradeSubjects: [],
    staffSubjects: [],
  });

  const [sectionId, setSectionId] = useState(
    stringValue(row?.section_id || defaultSectionId)
  );
  const [slotType, setSlotType] = useState(stringValue(row?.slot_type || "regular"));
  const [subjectId, setSubjectId] = useState(
    stringValue(row?.subject_id || (row?.subject as Row)?.id)
  );
  const [staffId, setStaffId] = useState(
    stringValue(row?.staff_id || (row?.staff as Row)?.id)
  );
  const [academicYearId, setAcademicYearId] = useState(
    stringValue(row?.academic_year_id)
  );

  useEffect(() => {
    void Promise.all([
      api("principal/classes").catch(() => []),
      api("subjects").catch(() => []),
      api("staff?page=1&page_size=100").catch(() => []),
      api("academic-years").catch(() => []),
      api("grade-subjects?page_size=500").catch(() => []),
      api("staff-subjects?page_size=500").catch(() => []),
    ])
      .then(([cRes, subRes, stRes, yRes, gsRes, ssRes]) => {
        const classRows = rowsFrom(cRes);
        const yearRows = rowsFrom(yRes);
        setRefs({
          classes: classRows,
          subjects: rowsFrom(subRes),
          staff: rowsFrom(stRes),
          years: yearRows,
          gradeSubjects: rowsFrom(gsRes),
          staffSubjects: rowsFrom(ssRes),
        });
        setAcademicYearId((current) => {
          if (current) return current;
          const selectedClassRow = classRows.find(
            (cls) => stringValue(cls.section_id || cls.id) === sectionId,
          );
          const classYearId = stringValue(selectedClassRow?.academic_year_id);
          if (classYearId) return classYearId;
          const currentYear = yearRows.find(
            (year) => year.is_current === true || year.isCurrent === true,
          );
          return stringValue(currentYear?.id || yearRows[0]?.id);
        });
      })
      .catch(() => undefined);
  }, []);

  const selectedClass = refs.classes.find(
    (cls) => stringValue(cls.section_id || cls.id) === sectionId,
  );
  const selectedGradeId = stringValue(
    selectedClass?.grade_id || (selectedClass?.grade as Row)?.id,
  );
  const appliesToClass = (mapping: Row) => {
    if (!sectionId) return false;
    const mappingSectionId = stringValue(mapping.section_id);
    const mappingGradeId = stringValue(mapping.grade_id || (mapping.grade as Row)?.id);
    const mappingYearId = stringValue(mapping.academic_year_id);
    return (
      (mappingSectionId ? mappingSectionId === sectionId : mappingGradeId === selectedGradeId) &&
      (!mappingYearId || !academicYearId || mappingYearId === academicYearId)
    );
  };
  const mappedSubjectIds = new Set(
    refs.gradeSubjects
      .filter(appliesToClass)
      .map((mapping) => stringValue(mapping.subject_id || (mapping.subject as Row)?.id))
      .filter(Boolean),
  );
  const subjectOptions = refs.subjects.filter((subject) => {
    const id = stringValue(subject.id);
    return mappedSubjectIds.has(id) || id === subjectId;
  });
  const mappedStaffRows = refs.staffSubjects
    .filter(appliesToClass)
    .filter((mapping) => stringValue(mapping.subject_id || (mapping.subject as Row)?.id) === subjectId)
    .sort((a, b) => {
      const primary = (value: Row) => value.is_primary === true || value.isPrimary === true ? 1 : 0;
      return primary(b) - primary(a);
    });
  const mappedStaffIds = new Set(
    mappedStaffRows
      .map((mapping) => stringValue(mapping.staff_id || (mapping.staff as Row)?.id))
      .filter(Boolean),
  );
  const sectionStaffIds = new Set(
    [selectedClass?.class_teacher_id, selectedClass?.co_teacher_id]
      .map((value) => stringValue(value))
      .filter(Boolean),
  );
  const staffOptions = refs.staff.filter((staff) => {
    const id = stringValue(staff.id);
    return mappedStaffIds.has(id) || sectionStaffIds.has(id) || id === staffId;
  });
  const defaultStaffIdForSubject = (nextSubjectId: string) => {
    const mapping = refs.staffSubjects
      .filter(appliesToClass)
      .filter((item) => stringValue(item.subject_id || (item.subject as Row)?.id) === nextSubjectId)
      .sort((a, b) => {
        const score = (value: Row) => {
          const sectionMatch = stringValue(value.section_id) === sectionId;
          const gradeMatch = stringValue(value.grade_id) === selectedGradeId;
          const yearMatch = stringValue(value.academic_year_id) === academicYearId;
          const primary = value.is_primary === true || value.isPrimary === true;
          return (sectionMatch ? 8 : 0) + (gradeMatch ? 4 : 0) + (yearMatch ? 2 : 0) + (primary ? 1 : 0);
        };
        return score(b) - score(a);
      })[0];
    return stringValue(mapping?.staff_id || (mapping?.staff as Row)?.id);
  };

  async function submit(form: FormData) {
    if (readOnly || saving) return;
    setSaving(true);
    setError("");
    try {
      const selectedSection = sectionId || stringValue(form.get("section_id"));
      const dayOfWeek = Number(form.get("day_of_week") || 1);
      const periodNumber = Number(form.get("period_number") || 1);
      const startTime = stringValue(form.get("start_time")) || "08:30";
      const endTime = stringValue(form.get("end_time")) || "09:10";
      const customSubjectName = stringValue(form.get("custom_subject_name"));
      const roomNumber = stringValue(form.get("room_number"));
      const yearId = stringValue(form.get("academic_year_id")) || academicYearId;

      if (!selectedSection) throw new Error("Please select a class section.");
      if (!yearId) throw new Error("Please select an academic year.");
      if (slotType === "regular" && !subjectId && !customSubjectName) {
        throw new Error("Select a mapped subject for a regular teaching period.");
      }

      const selectedSub = refs.subjects.find((s) => stringValue(s.id) === subjectId);
      const finalSubjectName =
        customSubjectName ||
        (selectedSub ? stringValue(selectedSub.subject_name) : slotType === "break" ? "Break" : "Study Period");

      const payload: Row = {
        section_id: selectedSection,
        academic_year_id: yearId || undefined,
        day_of_week: dayOfWeek,
        period_number: periodNumber,
        slot_type: slotType,
        start_time: startTime,
        end_time: endTime,
        subject_id: slotType === "regular" && subjectId ? subjectId : null,
        staff_id: slotType === "regular" && staffId ? staffId : null,
        subject_name: finalSubjectName,
        room_number: roomNumber || null,
      };

      if (row?.id) {
        await api(`timetable/slots/${row.id}`, {
          method: "PATCH",
          body: JSON.stringify(payload),
        });
      } else {
        await api("timetable/slots", {
          method: "POST",
          body: JSON.stringify(payload),
        });
      }

      onSaved();
      onClose();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to save timetable period slot");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Dialog
      kicker="Schedule period"
      title={readOnly ? "Period slot details" : row ? "Update period slot" : "Add period slot"}
      onClose={onClose}
    >
      <form
        className="ops-detail-form"
        aria-busy={saving}
        onSubmit={(event) => {
          event.preventDefault();
          if (saving) return;
          void submit(new FormData(event.currentTarget));
        }}
      >
        <div className="form-grid">
          <label className="field">
            Class section
            <select
              name="section_id"
              disabled={readOnly}
              value={sectionId}
              onChange={(e) => {
                setSectionId(e.target.value);
                if (!row?.academic_year_id) {
                  const nextClass = refs.classes.find(
                    (cls) => stringValue(cls.section_id || cls.id) === e.target.value,
                  );
                  const nextYear = stringValue(nextClass?.academic_year_id);
                  if (nextYear) setAcademicYearId(nextYear);
                }
              }}
              required
            >
              <option value="">Select class section…</option>
              {refs.classes.map((cls) => {
                const cId = stringValue(cls.section_id || cls.id);
                const gName = stringValue(cls.grade_name);
                const sName = stringValue(cls.section_name ?? cls.name);
                return (
                  <option key={cId} value={cId}>
                    {gName} - {sName}
                  </option>
                );
              })}
            </select>
          </label>

          <label className="field">
            Academic year
            <select
              name="academic_year_id"
              disabled={readOnly}
              value={academicYearId}
              onChange={(e) => setAcademicYearId(e.target.value)}
              required
            >
              <option value="" disabled>Select academic year…</option>
              {refs.years.map((year) => (
                <option key={stringValue(year.id)} value={stringValue(year.id)}>
                  {stringValue(year.year_label || year.name)}{year.is_current === true || year.isCurrent === true ? " (Current)" : ""}
                </option>
              ))}
            </select>
          </label>

          <label className="field">
            Day of week
            <select name="day_of_week" disabled={readOnly} defaultValue={Number(row?.day_of_week || 1)}>
              {DAYS.map((d) => (
                <option key={d.value} value={d.value}>
                  {d.label}
                </option>
              ))}
            </select>
          </label>

          <label className="field">
            Period number
            <input
              name="period_number"
              type="number"
              min={1}
              max={12}
              required
              readOnly={readOnly}
              defaultValue={Number(row?.period_number || 1)}
            />
          </label>

          <label className="field">
            Slot type
            <select
              name="slot_type"
              disabled={readOnly}
              value={slotType}
              onChange={(e) => setSlotType(e.target.value)}
            >
              <option value="regular">Regular Teaching Period</option>
              <option value="break">Recess / Lunch Break</option>
              <option value="free">Free / Study Period</option>
            </select>
          </label>

          <label className="field">
            Start time
            <input
              name="start_time"
              type="time"
              required
              readOnly={readOnly}
              defaultValue={stringValue(row?.start_time || "08:30")}
            />
          </label>

          <label className="field">
            End time
            <input
              name="end_time"
              type="time"
              required
              readOnly={readOnly}
              defaultValue={stringValue(row?.end_time || "09:10")}
            />
          </label>

          {slotType === "regular" && (
            <>
              <label className="field">
                Subject
                <select
                  name="subject_id"
                  disabled={readOnly}
                  value={subjectId}
                  required={!readOnly}
                  onChange={(e) => {
                    setSubjectId(e.target.value);
                    setStaffId(defaultStaffIdForSubject(e.target.value));
                  }}
                >
                  <option value="">
                    {subjectOptions.length ? "Select mapped subject…" : "No mapped subjects for this class"}
                  </option>
                  {subjectOptions.map((sub) => (
                    <option key={stringValue(sub.id)} value={stringValue(sub.id)}>
                      {stringValue(sub.subject_name)} {sub.subject_code ? `(${sub.subject_code})` : ""}
                    </option>
                  ))}
                </select>
              </label>

              <label className="field">
                Educator / Staff
                <select
                  name="staff_id"
                  disabled={readOnly}
                  value={staffId}
                  onChange={(e) => setStaffId(e.target.value)}
                >
                  <option value="">Use mapped subject teacher / section teacher</option>
                  {staffOptions.map((st) => (
                    <option key={stringValue(st.id)} value={stringValue(st.id)}>
                      {displayName(st)} {st.staff_code ? `(${st.staff_code})` : ""}
                    </option>
                  ))}
                </select>
              </label>
            </>
          )}

          {slotType === "break" && (
            <label className="field">
              Break label
              <input
                name="custom_subject_name"
                readOnly={readOnly}
                defaultValue={stringValue(row?.subject_name || "Recess Break")}
                placeholder="e.g. Morning Recess / Lunch"
              />
            </label>
          )}

          <label className="field">
            Room number <small>(optional)</small>
            <input
              name="room_number"
              readOnly={readOnly}
              defaultValue={stringValue(row?.room_number || (row?.room as Row)?.room_number)}
              placeholder="e.g. R-101"
            />
          </label>
        </div>

        {error && <p className="form-error">{error}</p>}

        {readOnly ? (
          <div className="dialog-footer">
            <button className="secondary-button" type="button" onClick={onClose}>
              Close
            </button>
          </div>
        ) : (
          <FormActions
            saving={saving}
            onClose={onClose}
            label={row ? "Update slot" : "Save period slot"}
          />
        )}
      </form>
    </Dialog>
  );
}

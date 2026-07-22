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
  }>({
    classes: [],
    subjects: [],
    staff: [],
    years: [],
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

  useEffect(() => {
    void Promise.all([
      api("principal/classes").catch(() => []),
      api("subjects").catch(() => []),
      api("staff?page=1&page_size=100").catch(() => []),
      api("academic-years").catch(() => []),
    ])
      .then(([cRes, subRes, stRes, yRes]) => {
        setRefs({
          classes: rowsFrom(cRes),
          subjects: rowsFrom(subRes),
          staff: rowsFrom(stRes),
          years: rowsFrom(yRes),
        });
      })
      .catch(() => undefined);
  }, []);

  async function submit(form: FormData) {
    if (readOnly) return;
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
      const yearId = stringValue(form.get("academic_year_id"));

      if (!selectedSection) throw new Error("Please select a class section.");

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
      <form action={submit} className="ops-detail-form">
        <div className="form-grid">
          <label className="field">
            Class section
            <select
              name="section_id"
              disabled={readOnly}
              value={sectionId}
              onChange={(e) => setSectionId(e.target.value)}
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
                  onChange={(e) => setSubjectId(e.target.value)}
                >
                  <option value="">Select subject…</option>
                  {refs.subjects.map((sub) => (
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
                  <option value="">Use Section Class Teacher</option>
                  {refs.staff.map((st) => (
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

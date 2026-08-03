"use client";

import { useEffect, useState } from "react";
import type { Row } from "./types";
import { api, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

export function TimetableGeneratorDialog({
  defaultSectionId,
  onClose,
  onGenerated,
}: {
  defaultSectionId?: string;
  onClose: () => void;
  onGenerated: (count: number) => void;
}) {
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [classes, setClasses] = useState<Row[]>([]);
  const [years, setYears] = useState<Row[]>([]);
  const [sectionId, setSectionId] = useState(defaultSectionId || "");
  const [academicYearId, setAcademicYearId] = useState("");
  const [dayPreset, setDayPreset] = useState("mon-sat");
  const [includeBreak, setIncludeBreak] = useState(true);

  useEffect(() => {
    void Promise.all([
      api("principal/classes").catch(() => []),
      api("academic-years").catch(() => []),
    ])
      .then(([cRes, yRes]) => {
        const cList = rowsFrom(cRes);
        const yList = rowsFrom(yRes);
        setClasses(cList);
        setYears(yList);
        setAcademicYearId((current) => {
          const selectedClass = cList.find(
            (cls) => stringValue(cls.section_id || cls.id) === sectionId,
          ) || cList[0];
          const classYearId = stringValue(selectedClass?.academic_year_id);
          if (classYearId) return classYearId;
          if (current) return current;
          const currentYear = yList.find(
            (year) => year.is_current === true || year.isCurrent === true,
          );
          return stringValue(currentYear?.id || yList[0]?.id);
        });
        if (!sectionId && cList.length > 0) {
          setSectionId(stringValue(cList[0].section_id || cList[0].id));
        }
      })
      .catch(() => undefined);
  }, [sectionId]);

  async function submit(form: FormData) {
    if (saving) return;
    setSaving(true);
    setError("");
    try {
      const selectedSection = sectionId || stringValue(form.get("section_id"));
      const selectedYear = stringValue(form.get("academic_year_id")) || academicYearId;
      const periodsPerDay = Number(form.get("periods_per_day") || 7);
      const startTime = stringValue(form.get("start_time")) || "08:30";
      const duration = Number(form.get("period_duration") || 40);
      const gap = Number(form.get("gap_minutes") || 5);
      const breakName = stringValue(form.get("break_name")) || "Recess Break";
      const breakStart = stringValue(form.get("break_start")) || "10:15";
      const breakEnd = stringValue(form.get("break_end")) || "10:35";

      if (!selectedSection) throw new Error("Please select a class section.");
      if (!selectedYear) throw new Error("Please select an academic year.");

      const days = dayPreset === "mon-fri" ? [1, 2, 3, 4, 5] : [1, 2, 3, 4, 5, 6];
      const breaks = includeBreak
        ? [{ name: breakName, start_time: breakStart, end_time: breakEnd, days }]
        : [];

      const payload = {
        section_id: selectedSection,
        academic_year_id: selectedYear || undefined,
        days,
        periods_per_day: periodsPerDay,
        start_time: startTime,
        period_duration_minutes: duration,
        gap_minutes: gap,
        breaks,
      };

      const res = (await api("timetable/smart/generate", {
        method: "POST",
        body: JSON.stringify(payload),
      })) as Row;

      const generatedCount = Number(res.generated_count || 0);
      onGenerated(generatedCount);
      onClose();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to generate smart timetable");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Dialog
      kicker="Smart Schedule Generator"
      title="Auto-generate class timetable"
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
        <p style={{ fontSize: "0.85rem", color: "#4f6575", marginBottom: "1rem" }}>
          Automatically generate a balanced weekly timetable with subjects, educators, and break slots for the selected class.
        </p>

        <div className="form-grid">
          <label className="field">
            Target class section
            <select
              name="section_id"
              value={sectionId}
              onChange={(e) => setSectionId(e.target.value)}
              required
            >
              <option value="">Select class section…</option>
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

          <label className="field">
            Academic Year
            <select
              name="academic_year_id"
              value={academicYearId}
              onChange={(event) => setAcademicYearId(event.target.value)}
              required
            >
              <option value="" disabled>Select academic year…</option>
              {years.map((y) => (
                <option key={stringValue(y.id)} value={stringValue(y.id)}>
                  {stringValue(y.year_label || y.name)}{y.is_current === true || y.isCurrent === true ? " (Current)" : ""}
                </option>
              ))}
            </select>
          </label>

          <label className="field">
            Working Days Preset
            <select value={dayPreset} onChange={(e) => setDayPreset(e.target.value)}>
              <option value="mon-sat">Monday to Saturday (6 Days)</option>
              <option value="mon-fri">Monday to Friday (5 Days)</option>
            </select>
          </label>

          <label className="field">
            Periods per day
            <input name="periods_per_day" type="number" min={4} max={10} defaultValue={7} required />
          </label>

          <label className="field">
            School Start Time
            <input name="start_time" type="time" defaultValue="08:30" required />
          </label>

          <label className="field">
            Period Duration (mins)
            <input name="period_duration" type="number" min={20} max={90} defaultValue={40} required />
          </label>

          <label className="field">
            Inter-period Gap (mins)
            <input name="gap_minutes" type="number" min={0} max={20} defaultValue={5} required />
          </label>
        </div>

        <div style={{ padding: "0.85rem", background: "#f5f9fc", border: "1px solid #d4e3ee", borderRadius: "12px", marginTop: "0.75rem" }}>
          <label style={{ display: "flex", alignItems: "center", gap: "0.5rem", fontWeight: 650, color: "#194263", fontSize: "0.85rem", cursor: "pointer" }}>
            <input
              type="checkbox"
              checked={includeBreak}
              onChange={(e) => setIncludeBreak(e.target.checked)}
            />
            Include Recess / Lunch Break slot
          </label>

          {includeBreak && (
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "0.5rem", marginTop: "0.6rem" }}>
              <input name="break_name" defaultValue="Recess Break" placeholder="Break label" style={{ padding: "0.4rem", borderRadius: "6px", border: "1px solid #ccd8de", fontSize: "0.8rem" }} />
              <input name="break_start" type="time" defaultValue="10:15" style={{ padding: "0.4rem", borderRadius: "6px", border: "1px solid #ccd8de", fontSize: "0.8rem" }} />
              <input name="break_end" type="time" defaultValue="10:35" style={{ padding: "0.4rem", borderRadius: "6px", border: "1px solid #ccd8de", fontSize: "0.8rem" }} />
            </div>
          )}
        </div>

        {error && <p className="form-error">{error}</p>}

        <FormActions saving={saving} onClose={onClose} label="Generate schedule" />
      </form>
    </Dialog>
  );
}

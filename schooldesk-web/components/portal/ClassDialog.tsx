"use client";

import { useEffect, useState } from "react";
import type { Row } from "./types";
import { api, displayName, nested, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";
import { FormActions } from "./FormActions";

type SubjectMappingRow = {
  subject_id: string;
  subject_name: string;
  periods_per_week: number;
  teacher_id: string;
};

export function ClassDialog({
  row,
  readOnly,
  onClose,
  onSaved,
}: {
  row?: Row;
  readOnly?: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [tab, setTab] = useState<"general" | "subjects" | "students">("general");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [refs, setRefs] = useState<{
    academicYears: Row[];
    staff: Row[];
    subjects: Row[];
  }>({
    academicYears: [],
    staff: [],
    subjects: [],
  });

  const [academicYearId, setAcademicYearId] = useState(stringValue(row?.academic_year_id));
  const [classTeacherId, setClassTeacherId] = useState(
    stringValue(row?.class_teacher_id ?? nested(row ?? {}, "class_teacher").id)
  );
  const [coTeacherId, setCoTeacherId] = useState(
    stringValue(row?.co_teacher_id ?? nested(row ?? {}, "co_teacher").id)
  );
  const [subjectMappings, setSubjectMappings] = useState<SubjectMappingRow[]>([]);

  useEffect(() => {
    void Promise.all([
      api("academic-years").catch(() => []),
      api("staff?page=1&page_size=100").catch(() => []),
      api("subjects").catch(() => []),
    ])
      .then(([years, staffRes, subjectRes]) => {
        setRefs({
          academicYears: rowsFrom(years),
          staff: rowsFrom(staffRes),
          subjects: rowsFrom(subjectRes),
        });
      })
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    if (row?.id || row?.section_id) {
      const targetId = stringValue(row.section_id || row.id);
      void api(`principal/classes/${targetId}`)
        .then((detailRes) => {
          const detail = detailRes as Row;
          if (detail.academic_year_id) setAcademicYearId(stringValue(detail.academic_year_id));
          if (detail.class_teacher_id) setClassTeacherId(stringValue(detail.class_teacher_id));
          if (detail.co_teacher_id) setCoTeacherId(stringValue(detail.co_teacher_id));
          if (Array.isArray(detail.subject_mappings)) {
            const mapped = (detail.subject_mappings as Row[]).map((sm) => ({
              subject_id: stringValue(sm.subject_id),
              subject_name: stringValue(sm.subject_name),
              periods_per_week: Number(sm.periods_per_week || 5),
              teacher_id: stringValue(sm.teacher_id || sm.staff_id),
            }));
            setSubjectMappings(mapped);
          }
        })
        .catch(() => undefined);
    }
  }, [row]);

  function addSubjectMapping(subjectId: string) {
    if (!subjectId) return;
    const existing = subjectMappings.find((m) => m.subject_id === subjectId);
    if (existing) return;
    const subObj = refs.subjects.find((s) => stringValue(s.id) === subjectId);
    setSubjectMappings((prev) => [
      ...prev,
      {
        subject_id: subjectId,
        subject_name: stringValue(subObj?.subject_name ?? "Subject"),
        periods_per_week: 5,
        teacher_id: "",
      },
    ]);
  }

  function updateMapping(index: number, patch: Partial<SubjectMappingRow>) {
    setSubjectMappings((prev) =>
      prev.map((item, i) => (i === index ? { ...item, ...patch } : item))
    );
  }

  function removeMapping(index: number) {
    setSubjectMappings((prev) => prev.filter((_, i) => i !== index));
  }

  async function submit(form: FormData) {
    if (readOnly || saving) return;
    setSaving(true);
    setError("");
    try {
      const gradeName = stringValue(form.get("grade_name"));
      const sectionName = stringValue(form.get("section_name"));
      const gradeNumber = Number(form.get("grade_number") || 1);
      const capacity = Number(form.get("capacity") || 30);
      const roomNumber = stringValue(form.get("room_number"));
      const selectedYearId = academicYearId || stringValue(form.get("academic_year_id"));

      if (!gradeName) throw new Error("Grade name is required.");
      if (!sectionName) throw new Error("Section name is required.");

      const payload: Row = {
        academic_year_id: selectedYearId || undefined,
        grade_name: gradeName,
        grade_number: gradeNumber,
        section_name: sectionName,
        capacity,
        room_number: roomNumber || null,
        class_teacher_id: classTeacherId || null,
        co_teacher_id: coTeacherId || null,
        subject_mappings: subjectMappings,
      };

      const targetId = stringValue(row?.section_id || row?.id);
      if (targetId) {
        await api(`principal/classes/${targetId}`, {
          method: "PUT",
          body: JSON.stringify(payload),
        });
      } else {
        await api("principal/classes", {
          method: "POST",
          body: JSON.stringify(payload),
        });
      }

      onSaved();
      onClose();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to save class section");
    } finally {
      setSaving(false);
    }
  }

  const initialGradeName = stringValue(row?.grade_name);
  const initialSectionName = stringValue(row?.section_name ?? row?.name);
  const students = Array.isArray(row?.students) ? row.students as Row[] : [];

  return (
    <Dialog
      kicker="Class setup"
      title={readOnly ? "Class section details" : row ? "Update class section" : "Add class section"}
      onClose={onClose}
    >
      <div className="finance-tabs" style={{ marginBottom: "1rem" }}>
        <button
          type="button"
          className={tab === "general" ? "active" : ""}
          onClick={() => setTab("general")}
        >
          General &amp; Educators
        </button>
        <button
          type="button"
          className={tab === "subjects" ? "active" : ""}
          onClick={() => setTab("subjects")}
        >
          Subject Curriculum ({subjectMappings.length})
        </button>
        <button
          type="button"
          className={tab === "students" ? "active" : ""}
          onClick={() => setTab("students")}
        >
          Students ({students.length})
        </button>
      </div>

      <form
        className="ops-detail-form"
        aria-busy={saving}
        onSubmit={(event) => {
          event.preventDefault();
          if (saving) return;
          void submit(new FormData(event.currentTarget));
        }}
      >
        {/* preserve sort order so edits don't reset all sections to grade_number=1 */}
        <input type="hidden" name="grade_number" value={Number(row?.grade_number ?? 1)} />
        {tab === "general" ? (
          <div className="form-grid">
            <label className="field">
              Grade name
              <input
                name="grade_name"
                required
                readOnly={readOnly}
                defaultValue={initialGradeName}
                placeholder="e.g. Nursery, LKG, Grade 1"
              />
            </label>
            <label className="field">
              Section name
              <input
                name="section_name"
                required
                readOnly={readOnly}
                defaultValue={initialSectionName}
                placeholder="e.g. Section A"
              />
            </label>
            <label className="field">
              Academic Year
              <select
                name="academic_year_id"
                disabled={readOnly}
                value={academicYearId}
                onChange={(e) => setAcademicYearId(e.target.value)}
              >
                <option value="">Current Academic Year</option>
                {refs.academicYears.map((ay) => (
                  <option key={stringValue(ay.id)} value={stringValue(ay.id)}>
                    {stringValue(ay.year_label || ay.name)}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              Capacity limit
              <input
                name="capacity"
                type="number"
                required
                readOnly={readOnly}
                defaultValue={Number(row?.capacity || 30)}
              />
            </label>
            <label className="field">
              Room number <small>(optional)</small>
              <input
                name="room_number"
                readOnly={readOnly}
                defaultValue={stringValue(row?.room_number)}
                placeholder="e.g. R-101"
              />
            </label>
            <label className="field">
              Class Teacher
              <select
                name="class_teacher_id"
                disabled={readOnly}
                value={classTeacherId}
                onChange={(e) => setClassTeacherId(e.target.value)}
              >
                <option value="">Unassigned</option>
                {refs.staff.map((st) => (
                  <option key={stringValue(st.id)} value={stringValue(st.id)}>
                    {displayName(st)} {st.staff_code ? `(${st.staff_code})` : ""}
                  </option>
                ))}
              </select>
            </label>
            <label className="field">
              Co-Teacher <small>(optional)</small>
              <select
                name="co_teacher_id"
                disabled={readOnly}
                value={coTeacherId}
                onChange={(e) => setCoTeacherId(e.target.value)}
              >
                <option value="">Unassigned</option>
                {refs.staff.map((st) => (
                  <option key={stringValue(st.id)} value={stringValue(st.id)}>
                    {displayName(st)} {st.staff_code ? `(${st.staff_code})` : ""}
                  </option>
                ))}
              </select>
            </label>
          </div>
        ) : tab === "subjects" ? (
          <div style={{ display: "grid", gap: "1rem" }}>
            {!readOnly && (
              <div style={{ display: "flex", gap: "0.5rem", alignItems: "center" }}>
                <select
                  style={{ flex: 1, padding: "0.6rem", borderRadius: "8px", border: "1px solid #c9d9df" }}
                  onChange={(e) => {
                    addSubjectMapping(e.target.value);
                    e.target.value = "";
                  }}
                >
                  <option value="">+ Assign subject to this class…</option>
                  {refs.subjects.map((sub) => (
                    <option key={stringValue(sub.id)} value={stringValue(sub.id)}>
                      {stringValue(sub.subject_name)} {sub.subject_code ? `(${sub.subject_code})` : ""}
                    </option>
                  ))}
                </select>
              </div>
            )}

            {subjectMappings.length > 0 ? (
              <div style={{ display: "grid", gap: "0.6rem" }}>
                {subjectMappings.map((item, idx) => (
                  <div
                    key={item.subject_id || idx}
                    style={{
                      display: "grid",
                      gridTemplateColumns: "1.2fr 80px 1.5fr auto",
                      gap: "0.5rem",
                      alignItems: "center",
                      padding: "0.6rem 0.8rem",
                      background: "#f9fcfd",
                      border: "1px solid #dce8ee",
                      borderRadius: "10px",
                    }}
                  >
                    <b>{item.subject_name}</b>
                    <input
                      type="number"
                      min={1}
                      max={20}
                      disabled={readOnly}
                      value={item.periods_per_week}
                      onChange={(e) => updateMapping(idx, { periods_per_week: Number(e.target.value) })}
                      title="Periods per week"
                      style={{ padding: "0.35rem", borderRadius: "6px", border: "1px solid #ccd8de" }}
                    />
                    <select
                      disabled={readOnly}
                      value={item.teacher_id}
                      onChange={(e) => updateMapping(idx, { teacher_id: e.target.value })}
                      style={{ padding: "0.35rem", borderRadius: "6px", border: "1px solid #ccd8de" }}
                    >
                      <option value="">Assign Educator</option>
                      {refs.staff.map((st) => (
                        <option key={stringValue(st.id)} value={stringValue(st.id)}>
                          {displayName(st)}
                        </option>
                      ))}
                    </select>
                    {!readOnly && (
                      <button
                        type="button"
                        className="icon-button danger"
                        onClick={() => removeMapping(idx)}
                        title="Remove subject"
                      >
                        ×
                      </button>
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <p style={{ color: "#718592", fontSize: "0.85rem", padding: "1rem 0" }}>
                No subjects assigned to this class section yet.
              </p>
            )}
          </div>
        ) : (
          <div style={{ display: "grid", gap: "0.7rem" }}>
            <p style={{ margin: 0, color: "#718592", fontSize: "0.85rem" }}>
              Active students currently assigned to {initialGradeName || "this class"} - {initialSectionName || "this section"}.
            </p>
            {students.length ? students.map((student, index) => {
              const name = [stringValue(student.first_name), stringValue(student.last_name)]
                .filter(Boolean)
                .join(" ") || "Unnamed student";
              const identifier = stringValue(student.student_id_number || student.admission_number);
              return (
                <div
                  key={stringValue(student.id) || `${name}-${index}`}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: "0.75rem",
                    padding: "0.7rem 0.8rem",
                    background: "#f9fcfd",
                    border: "1px solid #dce8ee",
                    borderRadius: "10px",
                  }}
                >
                  <span
                    aria-hidden="true"
                    style={{
                      width: 34,
                      height: 34,
                      borderRadius: "50%",
                      display: "grid",
                      placeItems: "center",
                      background: "#e7f1fa",
                      color: "#0e5ea8",
                      fontWeight: 800,
                      fontSize: "0.78rem",
                    }}
                  >
                    {name.slice(0, 1).toUpperCase()}
                  </span>
                  <span style={{ display: "grid", gap: "0.15rem" }}>
                    <b>{name}</b>
                    {identifier && <small style={{ color: "#718592" }}>ID: {identifier}</small>}
                  </span>
                </div>
              );
            }) : (
              <p style={{ color: "#718592", fontSize: "0.85rem", padding: "1rem 0" }}>
                No active students are currently assigned to this class section.
              </p>
            )}
          </div>
        )}

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
            label={row ? "Update class" : "Create class section"}
          />
        )}
      </form>
    </Dialog>
  );
}

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Building2,
  CheckCircle2,
  CircleAlert,
  Eye,
  Pencil,
  Plus,
  RefreshCw,
  Trash2,
} from "@/lib/lucide-react";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import type { Row } from "./types";
import { api, displayName, nested, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";
import { ClassDialog } from "./ClassDialog";
import { SubjectDialog } from "./SubjectDialog";

type ClassDialogState = {
  open: boolean;
  row?: Row;
  readOnly?: boolean;
};

function educatorName(raw: unknown) {
  if (!raw) return "Unassigned";
  if (typeof raw === "string") return raw;
  if (typeof raw === "object") {
    const obj = raw as Row;
    const first = stringValue(obj.first_name);
    const last = stringValue(obj.last_name);
    const full = [first, last].filter(Boolean).join(" ");
    return full || stringValue(obj.name || obj.staff_code || "Staff");
  }
  return "Unassigned";
}

export function ClassesWorkspace({
  createToken,
  onSaved,
  onNotify,
}: {
  createToken: number;
  onSaved: () => void;
  onNotify: (message: string) => void;
}) {
  const [mode, setMode] = useState<"classes" | "subjects">("classes");
  const [classes, setClasses] = useState<Row[]>([]);
  const [subjects, setSubjects] = useState<Row[]>([]);
  const [staff, setStaff] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [gradeFilter, setGradeFilter] = useState("all");
  const [page, setPage] = useState(1);

  const [classDialog, setClassDialog] = useState<ClassDialogState>({ open: false });
  const [subjectDialogOpen, setSubjectDialogOpen] = useState(false);
  const [subjectEditTarget, setSubjectEditTarget] = useState<Row | null>(null);
  const [subjectDeleteTarget, setSubjectDeleteTarget] = useState<Row | null>(null);
  const [subjectDeleting, setSubjectDeleting] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Row | null>(null);
  const [deleting, setDeleting] = useState(false);

  const load = useCallback(async (manual = false) => {
    if (manual) setRefreshing(true);
    else setLoading(true);
    setError("");
    try {
      const [classData, subjectData, staffData] = await Promise.all([
        api("principal/classes").catch(() => []),
        api("subjects").catch(() => []),
        api("staff?page=1&page_size=100").catch(() => []),
      ]);
      setClasses(rowsFrom(classData));
      setSubjects(rowsFrom(subjectData));
      setStaff(rowsFrom(staffData));
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load class section data");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (createToken > 0) {
      setClassDialog({ open: true, readOnly: false });
    }
  }, [createToken]);

  const gradeOptions = useMemo(
    () => Array.from(new Set(classes.map((c) => stringValue(c.grade_name)))).filter(Boolean).sort(),
    [classes]
  );

  const filteredClasses = useMemo(() => {
    const query = search.trim().toLowerCase();
    return classes.filter((cls) => {
      const gradeName = stringValue(cls.grade_name);
      const sectionName = stringValue(cls.section_name ?? cls.name);
      const classTeacher = educatorName(cls.class_teacher);
      const coTeacher = educatorName(cls.co_teacher);
      const room = stringValue(cls.room_number);

      const matchesSearch =
        !query ||
        [gradeName, sectionName, classTeacher, coTeacher, room].some((val) =>
          val.toLowerCase().includes(query)
        );

      const matchesGrade = gradeFilter === "all" || gradeName === gradeFilter;

      return matchesSearch && matchesGrade;
    });
  }, [classes, search, gradeFilter]);

  const filteredSubjects = useMemo(() => {
    const query = search.trim().toLowerCase();
    return subjects.filter((sub) => {
      const name = stringValue(sub.subject_name);
      const code = stringValue(sub.subject_code);
      const dept = stringValue(sub.department_name);
      return !query || [name, code, dept].some((val) => val.toLowerCase().includes(query));
    });
  }, [subjects, search]);

  const pageSize = 10;
  const totalPages = Math.max(1, Math.ceil(filteredClasses.length / pageSize));
  const visibleClasses = useMemo(
    () => filteredClasses.slice((page - 1) * pageSize, page * pageSize),
    [filteredClasses, page]
  );

  useEffect(() => setPage(1), [search, gradeFilter, mode]);

  async function deleteClass() {
    if (!deleteTarget) return;
    setDeleting(true);
    setError("");
    try {
      const targetId = stringValue(deleteTarget.section_id || deleteTarget.id);
      await api(`principal/classes/${targetId}`, { method: "DELETE" });
      onSaved();
      onNotify(`${stringValue(deleteTarget.grade_name)} ${stringValue(deleteTarget.section_name)} deleted.`);
      setDeleteTarget(null);
      await load(true);
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to delete class section");
    } finally {
      setDeleting(false);
    }
  }

  async function deleteSubject() {
    if (!subjectDeleteTarget) return;
    setSubjectDeleting(true);
    try {
      await api(`subjects/${stringValue(subjectDeleteTarget.id)}`, { method: "DELETE" });
      onNotify(`"${stringValue(subjectDeleteTarget.subject_name)}" removed from curriculum.`);
      setSubjectDeleteTarget(null);
      await load(true);
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to delete subject");
    } finally {
      setSubjectDeleting(false);
    }
  }

  return (
    <section className="ops-module classes-workspace">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon violet">
            <Building2 size={20} />
          </div>
          <div>
            <p className="ops-kicker">Resource management</p>
            <h2>Classes &amp; Subjects</h2>
            <p>Manage class sections, capacity limits, class teachers, co-teachers, and subject curriculum.</p>
          </div>
        </div>
        <div className="ops-actions">
          <button className="secondary-button" onClick={() => void load(true)} disabled={refreshing}>
            <RefreshCw size={16} className={refreshing ? "spin" : ""} /> Refresh
          </button>
          <button className="secondary-button" onClick={() => setSubjectDialogOpen(true)}>
            <Plus size={16} /> Add subject
          </button>
          <button className="primary-button" onClick={() => setClassDialog({ open: true, readOnly: false })}>
            <Plus size={16} /> Add class section
          </button>
        </div>
      </div>

      <div className="finance-tabs" style={{ marginBottom: "1.2rem" }}>
        <button
          type="button"
          className={mode === "classes" ? "active" : ""}
          onClick={() => setMode("classes")}
        >
          Class Sections ({classes.length})
        </button>
        <button
          type="button"
          className={mode === "subjects" ? "active" : ""}
          onClick={() => setMode("subjects")}
        >
          Subject Curriculum ({subjects.length})
        </button>
      </div>

      {mode === "classes" ? (
        <>
          <div className="student-directory-toolbar">
            <input
              className="search-input"
              placeholder="Search grade, section, class teacher, co-teacher, or room…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <select value={gradeFilter} onChange={(e) => setGradeFilter(e.target.value)} aria-label="Filter by grade">
              <option value="all">All grade levels</option>
              {gradeOptions.map((g) => (
                <option key={g} value={g}>{g}</option>
              ))}
            </select>
            <span className="ops-count">
              Showing <b>{filteredClasses.length}</b> section{filteredClasses.length === 1 ? "" : "s"}
            </span>
          </div>

          {error && (
            <div className="ops-inline-error">
              <CircleAlert size={16} />
              {error}
            </div>
          )}

          <div className="table-card surface ops-table-surface student-directory-table-wrap">
            {loading ? (
              <PortalModuleSkeleton variant="table" rows={5} label="Loading classes and sections" />
            ) : filteredClasses.length ? (
              <>
                <table className="data-table student-directory-table">
                  <thead>
                    <tr>
                      <th>Class &amp; Section</th>
                      <th>Enrollment &amp; Capacity</th>
                      <th>Class Teacher</th>
                      <th>Co-Teacher</th>
                      <th>Room</th>
                      <th aria-label="Class actions" style={{ textAlign: "right" }}>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {visibleClasses.map((cls) => {
                      const id = stringValue(cls.section_id || cls.id);
                      const gradeName = stringValue(cls.grade_name || "Grade");
                      const sectionName = stringValue(cls.section_name ?? cls.name ?? "Section");
                      const count = Number(cls.student_count || cls.total_students || 0);
                      const cap = Number(cls.capacity || 30);
                      const pct = Math.min(100, Math.round((count / Math.max(1, cap)) * 100));
                      const cTeacher = educatorName(cls.class_teacher);
                      const coTeach = educatorName(cls.co_teacher);

                      return (
                        <tr key={id}>
                          <td>
                            <div className="student-cell">
                              <span className="student-avatar" style={{ background: "#fff4d7", color: "#9a6b00" }}>
                                {gradeName.slice(0, 1).toUpperCase()}{sectionName.slice(0, 1).toUpperCase()}
                              </span>
                              <div>
                                <b>{gradeName} - {sectionName}</b>
                                <small>Capacity: {cap} students</small>
                              </div>
                            </div>
                          </td>
                          <td>
                            <div style={{ minWidth: "140px" }}>
                              <b style={{ fontSize: "0.86rem", color: count === 0 ? "#95a5b2" : "#193852" }}>
                                {count} / {cap} students ({pct}%)
                              </b>
                              {count === 0 ? (
                                <p style={{ margin: "0.2rem 0 0", fontSize: "0.7rem", color: "#b07800", background: "#fff8e1", border: "1px solid #ffe082", borderRadius: "6px", padding: "0.15rem 0.4rem", display: "inline-block" }}>
                                  No active students assigned
                                </p>
                              ) : (
                                <div
                                  style={{
                                    width: "100%",
                                    height: "6px",
                                    background: "#e8eff3",
                                    borderRadius: "99px",
                                    marginTop: "0.3rem",
                                    overflow: "hidden",
                                  }}
                                >
                                  <div
                                    style={{
                                      width: `${pct}%`,
                                      height: "100%",
                                      background: pct >= 100 ? "#d94326" : pct >= 80 ? "#e0901b" : "#248548",
                                      borderRadius: "99px",
                                      transition: "width 0.3s ease",
                                    }}
                                  />
                                </div>
                              )}
                            </div>
                          </td>
                          <td>
                            <span className="status-pill" style={{ background: "#f0f6fc", color: "#0d5b9e" }}>
                              {cTeacher}
                            </span>
                          </td>
                          <td>
                            <span className="status-pill" style={{ background: "#f6f8fa", color: "#546573" }}>
                              {coTeach}
                            </span>
                          </td>
                          <td>
                            <b>{stringValue(cls.room_number || "Unassigned")}</b>
                          </td>
                          <td className="actions-cell" style={{ textAlign: "right" }}>
                            <button
                              className="icon-button"
                              title="View class setup"
                              onClick={() => setClassDialog({ open: true, row: cls, readOnly: true })}
                            >
                              <Eye size={15} />
                            </button>
                            <button
                              className="icon-button"
                              title="Edit class section"
                              onClick={() => setClassDialog({ open: true, row: cls, readOnly: false })}
                            >
                              <Pencil size={15} />
                            </button>
                            <button
                              className="icon-button danger"
                              title="Delete class section"
                              onClick={() => setDeleteTarget(cls)}
                            >
                              <Trash2 size={15} />
                            </button>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
                <div className="ops-pagination">
                  <button
                    className="secondary-button"
                    disabled={page === 1}
                    onClick={() => setPage((val) => val - 1)}
                  >
                    Previous
                  </button>
                  <span>
                    Page {page} of {totalPages}
                  </span>
                  <button
                    className="secondary-button"
                    disabled={page === totalPages}
                    onClick={() => setPage((val) => val + 1)}
                  >
                    Next
                  </button>
                </div>
              </>
            ) : (
              <p className="ops-empty">No class sections match the current filters.</p>
            )}
          </div>
        </>
      ) : (
        <>
          <div className="student-directory-toolbar">
            <input
              className="search-input"
              placeholder="Search subject name, code, or department…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <span className="ops-count">
              Showing <b>{filteredSubjects.length}</b> subject{filteredSubjects.length === 1 ? "" : "s"}
            </span>
          </div>

          {(() => {
            const typeConfig: Record<string, { label: string; bg: string; color: string; dot: string }> = {
              core:     { label: "Core",              bg: "#eef5fc", color: "#0c5496", dot: "#0c5496" },
              elective: { label: "Elective",          bg: "#fef3e2", color: "#8a4f00", dot: "#d4780a" },
              activity: { label: "Activity / Co-Curricular", bg: "#f0f9f1", color: "#1d632f", dot: "#2e8b47" },
            };
            const grouped = new Map<string, Row[]>();
            for (const sub of filteredSubjects) {
              const t = stringValue(sub.subject_type || "core");
              if (!grouped.has(t)) grouped.set(t, []);
              grouped.get(t)!.push(sub);
            }
            const order = ["core", "elective", "activity"];
            const entries = order
              .filter((t) => grouped.has(t))
              .map((t) => [t, grouped.get(t)!] as [string, Row[]])
              .concat([...grouped.entries()].filter(([t]) => !order.includes(t)));

            if (!filteredSubjects.length) {
              return (
                <div className="table-card surface ops-table-surface student-directory-table-wrap">
                  <p className="ops-empty">No subjects created yet. Click &quot;Add subject&quot; to define curriculum subjects.</p>
                </div>
              );
            }

            return (
              <div style={{ display: "flex", flexDirection: "column", gap: "1.5rem" }}>
                {entries.map(([type, subs]) => {
                  const cfg = typeConfig[type] ?? { label: type, bg: "#f4f7f9", color: "#3d5a6c", dot: "#3d5a6c" };
                  return (
                    <div key={type}>
                      <div style={{ display: "flex", alignItems: "center", gap: "0.5rem", marginBottom: "0.6rem" }}>
                        <span style={{ width: 9, height: 9, borderRadius: "50%", background: cfg.dot, display: "inline-block", flexShrink: 0 }} />
                        <span style={{ fontSize: "0.72rem", fontWeight: 700, textTransform: "uppercase", letterSpacing: "0.07em", color: "#637887" }}>
                          {cfg.label}
                        </span>
                        <span style={{ fontSize: "0.72rem", color: "#95a5b2", fontWeight: 500 }}>— {subs.length} subject{subs.length === 1 ? "" : "s"}</span>
                      </div>
                      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: "0.65rem" }}>
                        {subs.map((sub) => {
                          const code = stringValue(sub.subject_code);
                          const dept = stringValue(sub.department_name || "Academics");
                          const name = stringValue(sub.subject_name);
                          return (
                            <div
                              key={stringValue(sub.id)}
                              style={{
                                background: "#fff",
                                border: "1.5px solid #dde8ef",
                                borderRadius: "12px",
                                padding: "0.85rem 1rem",
                                display: "flex",
                                flexDirection: "column",
                                gap: "0.4rem",
                                position: "relative",
                              }}
                            >
                              <div style={{ display: "flex", alignItems: "flex-start", gap: "0.6rem" }}>
                                <span style={{
                                  flexShrink: 0, width: 36, height: 36, borderRadius: 9,
                                  background: cfg.bg, color: cfg.color,
                                  display: "grid", placeItems: "center",
                                  fontWeight: 800, fontSize: "0.78rem", letterSpacing: "0.04em",
                                }}>
                                  {code || name.slice(0, 2).toUpperCase()}
                                </span>
                                <div style={{ flex: 1, minWidth: 0 }}>
                                  <b style={{ fontSize: "0.9rem", color: "#193852", display: "block", lineHeight: 1.3 }}>{name}</b>
                                  <span style={{ fontSize: "0.73rem", color: "#7a94a2" }}>{dept}</span>
                                </div>
                              </div>
                              {code && (
                                <span style={{
                                  alignSelf: "flex-start", fontSize: "0.7rem", fontWeight: 700,
                                  padding: "0.15rem 0.5rem", borderRadius: "6px",
                                  background: cfg.bg, color: cfg.color, letterSpacing: "0.05em",
                                }}>
                                  {code}
                                </span>
                              )}
                              <div style={{ display: "flex", gap: "0.35rem", marginTop: "0.15rem", justifyContent: "flex-end" }}>
                                <button
                                  className="icon-button"
                                  title="Edit subject"
                                  onClick={() => setSubjectEditTarget(sub)}
                                  style={{ padding: "0.25rem" }}
                                >
                                  <Pencil size={13} />
                                </button>
                                <button
                                  className="icon-button danger"
                                  title="Delete subject"
                                  onClick={() => setSubjectDeleteTarget(sub)}
                                  style={{ padding: "0.25rem" }}
                                >
                                  <Trash2 size={13} />
                                </button>
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  );
                })}
              </div>
            );
          })()}
        </>
      )}

      {classDialog.open && (
        <ClassDialog
          row={classDialog.row}
          readOnly={classDialog.readOnly}
          onClose={() => setClassDialog({ open: false })}
          onSaved={() => {
            onSaved();
            onNotify(classDialog.row ? "Class setup updated." : "Class section created.");
            void load(true);
          }}
        />
      )}

      {(subjectDialogOpen || subjectEditTarget) && (
        <SubjectDialog
          row={subjectEditTarget ?? undefined}
          onClose={() => { setSubjectDialogOpen(false); setSubjectEditTarget(null); }}
          onSaved={() => {
            onSaved();
            onNotify(subjectEditTarget ? "Subject updated." : "New subject added to curriculum.");
            void load(true);
          }}
        />
      )}

      {subjectDeleteTarget && (
        <Dialog kicker="Curriculum" title="Remove subject?" onClose={() => !subjectDeleting && setSubjectDeleteTarget(null)}>
          <div className="student-delete-dialog">
            <CircleAlert size={22} />
            <p>
              <b>{stringValue(subjectDeleteTarget.subject_name)}</b> will be removed from the curriculum. Class sections that use it will lose this subject assignment.
            </p>
          </div>
          <div className="dialog-footer">
            <button className="secondary-button" type="button" disabled={subjectDeleting} onClick={() => setSubjectDeleteTarget(null)}>
              Cancel
            </button>
            <button className="danger-button" type="button" disabled={subjectDeleting} onClick={() => void deleteSubject()}>
              {subjectDeleting ? <LoadingIndicator label="Removing…" compact announce={false} /> : "Remove subject"}
            </button>
          </div>
        </Dialog>
      )}

      {deleteTarget && (
        <Dialog kicker="Permanent action" title="Delete class section?" onClose={() => !deleting && setDeleteTarget(null)}>
          <div className="student-delete-dialog">
            <CircleAlert size={22} />
            <p>
              <b>{stringValue(deleteTarget.grade_name)} - {stringValue(deleteTarget.section_name ?? deleteTarget.name)}</b> will be permanently removed.
            </p>
          </div>
          <div className="dialog-footer">
            <button className="secondary-button" type="button" disabled={deleting} onClick={() => setDeleteTarget(null)}>
              Cancel
            </button>
            <button className="danger-button" type="button" disabled={deleting} onClick={() => void deleteClass()}>
              {deleting ? <LoadingIndicator label="Deleting…" compact announce={false} /> : "Delete class section"}
            </button>
          </div>
        </Dialog>
      )}
    </section>
  );
}

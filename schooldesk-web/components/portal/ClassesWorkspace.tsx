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
              <div className="skeleton-container" style={{ padding: "1rem" }}>
                {Array.from({ length: 5 }, (_, idx) => (
                  <div className="skeleton skeleton-row" key={idx} />
                ))}
              </div>
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
                                <small>Grade {stringValue(cls.grade_number || "—")}</small>
                              </div>
                            </div>
                          </td>
                          <td>
                            <div style={{ minWidth: "140px" }}>
                              <b style={{ fontSize: "0.86rem", color: "#193852" }}>
                                {count} / {cap} learners ({pct}%)
                              </b>
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

          <div className="table-card surface ops-table-surface student-directory-table-wrap">
            {filteredSubjects.length ? (
              <table className="data-table student-directory-table">
                <thead>
                  <tr>
                    <th>Subject</th>
                    <th>Subject Code</th>
                    <th>Department</th>
                    <th>Type</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredSubjects.map((sub) => (
                    <tr key={stringValue(sub.id)}>
                      <td>
                        <b>{stringValue(sub.subject_name)}</b>
                      </td>
                      <td>
                        <span className="status-pill" style={{ background: "#eef5fc", color: "#0c5496" }}>
                          {stringValue(sub.subject_code || "—")}
                        </span>
                      </td>
                      <td>{stringValue(sub.department_name || "Academics")}</td>
                      <td>
                        <span className="status-pill" style={{ background: "#eef7ee", color: "#1d632f" }}>
                          {stringValue(sub.subject_type || "core")}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p className="ops-empty">No subjects created yet. Click &quot;Add subject&quot; to define curriculum subjects.</p>
            )}
          </div>
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

      {subjectDialogOpen && (
        <SubjectDialog
          onClose={() => setSubjectDialogOpen(false)}
          onSaved={() => {
            onSaved();
            onNotify("New subject added to curriculum.");
            void load(true);
          }}
        />
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
              {deleting ? "Deleting…" : "Delete class section"}
            </button>
          </div>
        </Dialog>
      )}
    </section>
  );
}

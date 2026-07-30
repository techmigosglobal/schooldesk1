"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CircleAlert,
  Eye,
  Pencil,
  Plus,
  RefreshCw,
  Search,
  Trash2,
  UsersRound,
  X,
} from "@/lib/lucide-react";
import type { Row } from "./types";
import {
  api,
  displayName,
  formatDate,
  nested,
  rowsFrom,
  stringValue,
} from "./utils";
import { Dialog } from "./Dialog";
import { StudentDialog } from "./StudentDialog";

type StudentDialogState = {
  open: boolean;
  row?: Row;
  readOnly?: boolean;
};

function studentPhoto(row: Row) {
  return stringValue(row.photo_url ?? row.photo ?? row.avatar);
}

function studentId(row: Row) {
  return stringValue(row.student_id_number ?? row.student_code);
}

function studentInitials(row: Row) {
  return displayName(row)
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase() || "S";
}

function classLabel(row: Row) {
  const section = nested(row, "section");
  const grade = nested(section, "grade");
  const gradeName = stringValue(grade.grade_name ?? grade.name);
  const sectionName = stringValue(section.section_name ?? section.name);
  return [gradeName, sectionName].filter(Boolean).join(" · ") || "Not assigned";
}

function parentDetails(row: Row) {
  const links = Array.isArray(row.parent_student_links)
    ? (row.parent_student_links as Row[])
    : [];
  const linkedParent = nested(links[0] ?? {}, "parent");
  const guardians = Array.isArray(row.guardians) ? (row.guardians as Row[]) : [];
  const linkedName = stringValue(linkedParent.name ?? linkedParent.username);
  const linkedPhone = stringValue(linkedParent.phone);
  const guardian = guardians.find((item) => item.is_primary === true) ?? guardians[0] ?? {};
  return {
    name: linkedName || stringValue(guardian.full_name) || "Not linked",
    phone: linkedPhone || stringValue(guardian.phone) || "—",
  };
}

function StudentAvatar({ student }: { student: Row }) {
  const photo = studentPhoto(student);
  const [error, setError] = useState(false);

  if (photo && !error) {
    return (
      <span className="student-avatar">
        <img src={photo} alt="" onError={() => setError(true)} />
      </span>
    );
  }
  return <span className="student-avatar">{studentInitials(student)}</span>;
}

export function StudentDirectory({
  createToken,
  onSaved,
  onNotify,
}: {
  createToken: number;
  onSaved: () => void;
  onNotify: (message: string) => void;
}) {
  const [students, setStudents] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingStudent, setLoadingStudent] = useState(false);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [classFilter, setClassFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");
  const [page, setPage] = useState(1);
  const [dialog, setDialog] = useState<StudentDialogState>({ open: false });
  const [deleteTarget, setDeleteTarget] = useState<Row | null>(null);
  const [deleting, setDeleting] = useState(false);

  const load = useCallback(async (manual = false) => {
    if (manual) setRefreshing(true);
    else setLoading(true);
    setError("");
    try {
      const payload = await api("students?page=1&page_size=100");
      setStudents(rowsFrom(payload));
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load the student directory");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (createToken > 0) setDialog({ open: true, readOnly: false });
  }, [createToken]);

  const classOptions = useMemo(
    () => Array.from(new Set(students.map(classLabel))).filter(Boolean).sort(),
    [students],
  );
  const filteredStudents = useMemo(() => {
    const query = search.trim().toLowerCase();
    return students.filter((student) => {
      const matchesSearch = !query || [
        displayName(student),
        studentId(student),
        stringValue(student.admission_number),
        classLabel(student),
        parentDetails(student).name,
        parentDetails(student).phone,
      ].some((value) => value.toLowerCase().includes(query));
      const matchesClass = classFilter === "all" || classLabel(student) === classFilter;
      const status = stringValue(student.status || "active").toLowerCase();
      const matchesStatus = statusFilter === "all" || status === statusFilter;
      return matchesSearch && matchesClass && matchesStatus;
    });
  }, [students, search, classFilter, statusFilter]);

  const pageSize = 12;
  const totalPages = Math.max(1, Math.ceil(filteredStudents.length / pageSize));
  const visibleStudents = useMemo(
    () => filteredStudents.slice((page - 1) * pageSize, page * pageSize),
    [filteredStudents, page],
  );

  useEffect(() => setPage(1), [search, classFilter, statusFilter]);
  useEffect(() => {
    if (page > totalPages) setPage(totalPages);
  }, [page, totalPages]);

  async function openStudent(row: Row, readOnly: boolean) {
    setLoadingStudent(true);
    setError("");
    try {
      const detail = (await api(`students/${stringValue(row.id)}`)) as Row;
      setDialog({ open: true, row: detail, readOnly });
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load the student profile");
    } finally {
      setLoadingStudent(false);
    }
  }

  async function deleteStudent() {
    if (!deleteTarget) return;
    setDeleting(true);
    setError("");
    try {
      await api(`students/${stringValue(deleteTarget.id)}`, { method: "DELETE" });
      onSaved();
      onNotify(`${displayName(deleteTarget)} was deleted.`);
      setDeleteTarget(null);
      await load(true);
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to delete the student");
    } finally {
      setDeleting(false);
    }
  }

  return (
    <section className="ops-module student-directory">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon blue"><UsersRound size={20} /></div>
          <div>
            <p className="ops-kicker">Resource management</p>
            <h2>Students &amp; Parents</h2>
            <p>Live student records shared with the SchoolDesk Flutter directory.</p>
          </div>
        </div>
        <div className="ops-actions">
          <button className="secondary-button" onClick={() => void load(true)} disabled={refreshing}>
            <RefreshCw size={16} className={refreshing ? "spin" : ""} /> Refresh
          </button>
          <button className="primary-button" onClick={() => setDialog({ open: true, readOnly: false })}>
            <Plus size={16} /> Add student
          </button>
        </div>
      </div>

      <div className="student-directory-toolbar">
        <div className="directory-search" role="search">
          <Search size={17} />
          <input
            type="search"
            placeholder="Search name, student ID, admission number, parent, or phone…"
            aria-label="Search students"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
          {search && (
            <button type="button" className="directory-search-clear" aria-label="Clear student search" onClick={() => setSearch("")}>
              <X size={15} />
            </button>
          )}
        </div>
        <select value={classFilter} onChange={(event) => setClassFilter(event.target.value)} aria-label="Filter by class">
          <option value="all">All classes</option>
          {classOptions.map((option) => <option key={option} value={option}>{option}</option>)}
        </select>
        <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)} aria-label="Filter by status">
          <option value="all">All statuses</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
          <option value="withdrawn">Withdrawn</option>
          <option value="transferred">Transferred</option>
        </select>
        <span className="ops-count"><b>{filteredStudents.length}</b> student{filteredStudents.length === 1 ? "" : "s"}</span>
      </div>

      {error && <div className="ops-inline-error"><CircleAlert size={16} />{error}</div>}

      <div className="table-card surface ops-table-surface student-directory-table-wrap">
        {loading ? (
          <div className="skeleton-container" style={{ padding: "1rem" }}>
            {Array.from({ length: 6 }, (_, index) => <div className="skeleton skeleton-row" key={index} />)}
          </div>
        ) : filteredStudents.length ? (
          <>
            <table className="data-table student-directory-table">
              <thead>
                <tr>
                  <th>Student</th>
                  <th>Admission</th>
                  <th>Class / section</th>
                  <th>Parent / guardian</th>
                  <th>Contact</th>
                  <th>Profile</th>
                  <th>Status</th>
                  <th aria-label="Student actions" />
                </tr>
              </thead>
              <tbody>
                {visibleStudents.map((student) => {
                  const parent = parentDetails(student);
                  const status = stringValue(student.status || "active");
                  return (
                    <tr key={stringValue(student.id)}>
                      <td>
                        <div className="student-cell">
                          <StudentAvatar student={student} />
                          <div>
                            <b>{displayName(student)}</b>
                            <small>ID: {studentId(student) || "—"}</small>
                          </div>
                        </div>
                      </td>
                      <td>
                        <b>{stringValue(student.admission_number) || "—"}</b>
                        <small>{formatDate(student.admission_date, "Admission date not set")}</small>
                      </td>
                      <td>{classLabel(student)}</td>
                      <td>{parent.name}</td>
                      <td>{parent.phone}</td>
                      <td>
                        <span>{stringValue(student.gender) || "—"}</span>
                        <small>DOB: {formatDate(student.date_of_birth)}</small>
                      </td>
                      <td><span className={`student-status ${status.toLowerCase()}`}>{status}</span></td>
                      <td className="actions-cell">
                        <button className="icon-button" title="View student profile" onClick={() => void openStudent(student, true)} disabled={loadingStudent}><Eye size={15} /></button>
                        <button className="icon-button" title="Edit student" onClick={() => void openStudent(student, false)} disabled={loadingStudent}><Pencil size={15} /></button>
                        <button className="icon-button danger" title="Delete student" onClick={() => setDeleteTarget(student)}><Trash2 size={15} /></button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            <div className="ops-pagination">
              <button className="secondary-button" disabled={page === 1} onClick={() => setPage((value) => value - 1)}>Previous</button>
              <span>Page {page} of {totalPages}</span>
              <button className="secondary-button" disabled={page === totalPages} onClick={() => setPage((value) => value + 1)}>Next</button>
            </div>
          </>
        ) : <p className="ops-empty">No students match the current filters.</p>}
      </div>

      {dialog.open && <StudentDialog row={dialog.row} readOnly={dialog.readOnly} onClose={() => setDialog({ open: false })} onSaved={() => { onSaved(); onNotify(dialog.row ? "Student profile updated." : "Student registered."); void load(true); }} />}
      {deleteTarget && (
        <Dialog kicker="Permanent action" title="Delete this student?" onClose={() => !deleting && setDeleteTarget(null)}>
          <div className="student-delete-dialog">
            <CircleAlert size={22} />
            <p><b>{displayName(deleteTarget)}</b> will be removed from SchoolDesk. Their linked directory, attendance, fee, and document records follow the backend&apos;s retention rules and cannot be restored from this screen.</p>
          </div>
          <div className="dialog-footer">
            <button className="secondary-button" type="button" disabled={deleting} onClick={() => setDeleteTarget(null)}>Cancel</button>
            <button className="danger-button" type="button" disabled={deleting} onClick={() => void deleteStudent()}>{deleting ? "Deleting…" : "Delete student"}</button>
          </div>
        </Dialog>
      )}
    </section>
  );
}

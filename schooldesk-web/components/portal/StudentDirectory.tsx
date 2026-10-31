"use client";

import { usePortalGuard, usePortalState } from "./PortalStateProvider";
import { RecordActions } from "./RecordActions";

import { usePortalRefresh } from "./use-portal-refresh";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CircleAlert,
  Eye,
  Pencil,
  Plus,
  Search,
  X,
} from "@/lib/lucide-react";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import type { Row } from "./types";
import {
  apiAll,
  api,
  displayName,
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

function normalizedStatus(value: unknown) {
  const status = stringValue(value || "active").toLowerCase();
  if (status === "transferred") return "transfer";
  if (status === "withdrawn") return "inactive";
  return status;
}

function statusLabel(value: unknown) {
  const status = normalizedStatus(value);
  if (status === "transfer") return "Transferred";
  return status ? status[0].toUpperCase() + status.slice(1) : "Active";
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
  initialRecord,
  createToken,
  onSaved,
  onNotify,
}: {
  initialRecord?: Row;
  createToken: number;
  onSaved: () => void;
  onNotify: (message: string) => void;
}) {
  const [students, setStudents] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadingStudent, setLoadingStudent] = useState(false);
  const [error, setError] = useState("");
  const [search, setSearch] = usePortalState("students.search", "");
  const [classFilter, setClassFilter] = usePortalState("students.classFilter", "all");
  const [statusFilter, setStatusFilter] = usePortalState("students.statusFilter", "all");
  const [page, setPage] = usePortalState("students.page", 1);
  const [dialog, setDialog] = useState<StudentDialogState>({ open: false });
  const [deleteTarget, setDeleteTarget] = useState<Row | null>(null);
  const [deleting, setDeleting] = useState(false);
  usePortalGuard(false, deleting);

  const load = useCallback(async (manual = false) => {
    if (!manual) setLoading(true);
    setError("");
    try {
      const payload = await apiAll("students?page=1&page_size=100");
      setStudents(rowsFrom(payload));
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load the student directory");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { if (initialRecord) void openStudent(initialRecord, true); }, [initialRecord]);

  usePortalRefresh(load);

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
  useEffect(() => {
    if (!loading && !error && classFilter !== "all" && !classOptions.includes(classFilter)) { setClassFilter("all"); setPage(1); }
  }, [loading, error, classFilter, classOptions, setClassFilter, setPage]);

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
      const status = normalizedStatus(student.status);
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

  useEffect(() => {
    if (!loading && !error && (!Number.isInteger(page) || page < 1 || page > totalPages)) setPage(Number.isInteger(page) ? Math.max(1, Math.min(page, totalPages)) : 1);
  }, [page, totalPages, loading, error, setPage]);

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
      <div className="directory-context-bar"><p>Live student records and linked family contacts.</p><button type="button" className="primary-button" onClick={() => setDialog({ open: true, readOnly: false })}><Plus size={16} /> Add student</button></div>

      <div className="student-directory-toolbar">
        <div className="directory-search" role="search">
          <Search size={17} />
          <input
            type="search"
            placeholder="Search name, student ID, admission number, parent, or phone…"
            aria-label="Search students"
            value={search}
            onChange={(event) => { setSearch(event.target.value); setPage(1); }}
          />
          {search && (
            <button type="button" className="directory-search-clear" aria-label="Clear student search" onClick={() => setSearch("")}>
              <X size={15} />
            </button>
          )}
        </div>
        <select value={classFilter} onChange={(event) => { setClassFilter(event.target.value); setPage(1); }} aria-label="Filter by class">
          <option value="all">All classes</option>
          {classOptions.map((option) => <option key={option} value={option}>{option}</option>)}
        </select>
        <select value={statusFilter} onChange={(event) => { setStatusFilter(event.target.value); setPage(1); }} aria-label="Filter by status">
          <option value="all">All statuses</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
          <option value="transfer">Transferred</option>
          <option value="pending">Pending</option>
        </select>
        {(search || classFilter !== "all" || statusFilter !== "all") && <button type="button" className="secondary-button directory-reset" onClick={() => { setSearch(""); setClassFilter("all"); setStatusFilter("all"); setPage(1); }}>Reset filters</button>}
        <span className="ops-count"><b>{filteredStudents.length}</b> student{filteredStudents.length === 1 ? "" : "s"}</span>
      </div>

      {error && <div className="ops-inline-error"><CircleAlert size={16} />{error}</div>}

      <div className="table-card surface ops-table-surface student-directory-table-wrap">
        {loading ? (
          <PortalModuleSkeleton variant="table" label="Loading student records" />
        ) : filteredStudents.length ? (
          <>
            <table className="data-table student-directory-table">
              <thead>
                <tr>
                  <th>Student / admission</th>
                  <th>Class / section</th>
                  <th>Parent / contact</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {visibleStudents.map((student) => {
                  const parent = parentDetails(student);
                  const status = normalizedStatus(student.status);
                  return (
                    <tr key={stringValue(student.id)}>
                      <td>
                        <div className="student-cell">
                          <StudentAvatar student={student} />
                          <div>
                            <b>{displayName(student)}</b>
                            <small>Admission: {stringValue(student.admission_number) || "—"}</small>
                          </div>
                        </div>
                      </td>
                      <td>{classLabel(student)}</td>
                      <td><b>{parent.name}</b><small>{parent.phone}</small></td>
                      <td><span className={`student-status ${status}`}>{statusLabel(status)}</span></td>
                      <td className="actions-cell">
                        <button className="icon-button" title="View student profile" onClick={() => void openStudent(student, true)} disabled={loadingStudent} aria-busy={loadingStudent}>{loadingStudent ? <span className="activity-spinner" aria-hidden="true" /> : <Eye size={15} />}<span>View</span></button>
                        <button className="icon-button" title="Edit student" onClick={() => void openStudent(student, false)} disabled={loadingStudent} aria-busy={loadingStudent}>{loadingStudent ? <span className="activity-spinner" aria-hidden="true" /> : <Pencil size={15} />}<span>Edit</span></button>
                        <RecordActions label={`More actions for ${displayName(student)}`} actions={[{ label: "Delete student", danger: true, onSelect: () => setDeleteTarget(student) }]} />
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
            <button className="danger-button" type="button" disabled={deleting} aria-busy={deleting} onClick={() => void deleteStudent()}>{deleting ? <LoadingIndicator label="Deleting…" compact announce={false} /> : "Delete student"}</button>
          </div>
        </Dialog>
      )}
    </section>
  );
}

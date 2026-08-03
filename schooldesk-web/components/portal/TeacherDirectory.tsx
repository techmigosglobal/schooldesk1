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
  UserCog,
  X,
} from "@/lib/lucide-react";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import type { Row } from "./types";
import {
  api,
  displayName,
  nested,
  rowsFrom,
  stringValue,
} from "./utils";
import { Dialog } from "./Dialog";
import { TeacherDialog } from "./TeacherDialog";

type TeacherDialogState = {
  open: boolean;
  row?: Row;
  readOnly?: boolean;
};

function teacherInitials(row: Row) {
  const name = displayName(row) || stringValue(row.username || "Teacher");
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase() || "T";
}

function teacherClassAssignments(teacherId: string, staffCode: string, classes: Row[]) {
  if (!teacherId && !staffCode) return [];
  const assigned: Array<{ role: string; label: string }> = [];

  for (const cls of classes) {
    const classTeacherId = stringValue(cls.class_teacher_id ?? nested(cls, "class_teacher").id);
    const coTeacherId = stringValue(cls.co_teacher_id ?? nested(cls, "co_teacher").id);
    const gradeName = stringValue(cls.grade_name);
    const sectionName = stringValue(cls.section_name ?? cls.name);
    const classLabel = [gradeName, sectionName].filter(Boolean).join(" - ");

    if (classTeacherId && (classTeacherId === teacherId || classTeacherId === staffCode)) {
      assigned.push({ role: "Class Teacher", label: classLabel });
    }
    if (coTeacherId && (coTeacherId === teacherId || coTeacherId === staffCode)) {
      assigned.push({ role: "Co-Teacher", label: classLabel });
    }
  }

  return assigned;
}

export function TeacherDirectory({
  createToken,
  onSaved,
  onNotify,
}: {
  createToken: number;
  onSaved: () => void;
  onNotify: (message: string) => void;
}) {
  const [teachers, setTeachers] = useState<Row[]>([]);
  const [classes, setClasses] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingStaff, setLoadingStaff] = useState(false);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [designationFilter, setDesignationFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");
  const [page, setPage] = useState(1);
  const [dialog, setDialog] = useState<TeacherDialogState>({ open: false });
  const [deleteTarget, setDeleteTarget] = useState<Row | null>(null);
  const [deleting, setDeleting] = useState(false);

  const load = useCallback(async (manual = false) => {
    if (manual) setRefreshing(true);
    else setLoading(true);
    setError("");
    try {
      const [staffData, classData] = await Promise.all([
        api("staff?page=1&page_size=100"),
        api("principal/classes").catch(() => []),
      ]);
      setTeachers(rowsFrom(staffData));
      setClasses(rowsFrom(classData));
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load teacher records");
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

  const designationOptions = useMemo(
    () => Array.from(new Set(teachers.map((t) => stringValue(t.designation || "Teacher")))).filter(Boolean).sort(),
    [teachers]
  );

  const filteredTeachers = useMemo(() => {
    const query = search.trim().toLowerCase();
    return teachers.filter((teacher) => {
      const name = displayName(teacher);
      const staffCode = stringValue(teacher.staff_code);
      const username = stringValue(teacher.username);
      const email = stringValue(teacher.email);
      const phone = stringValue(teacher.phone);
      const designation = stringValue(teacher.designation || "Teacher");

      const matchesSearch =
        !query ||
        [name, staffCode, username, email, phone, designation].some((val) =>
          val.toLowerCase().includes(query)
        );

      const matchesDesignation =
        designationFilter === "all" || designation === designationFilter;

      const isActive = teacher.is_active !== false;
      const matchesStatus =
        statusFilter === "all" ||
        (statusFilter === "active" && isActive) ||
        (statusFilter === "inactive" && !isActive);

      return matchesSearch && matchesDesignation && matchesStatus;
    });
  }, [teachers, search, designationFilter, statusFilter]);

  const pageSize = 10;
  const totalPages = Math.max(1, Math.ceil(filteredTeachers.length / pageSize));
  const visibleTeachers = useMemo(
    () => filteredTeachers.slice((page - 1) * pageSize, page * pageSize),
    [filteredTeachers, page]
  );

  useEffect(() => setPage(1), [search, designationFilter, statusFilter]);
  useEffect(() => {
    if (page > totalPages) setPage(totalPages);
  }, [page, totalPages]);

  async function openTeacher(row: Row, readOnly: boolean) {
    setLoadingStaff(true);
    setError("");
    try {
      const detail = (await api(`staff/${stringValue(row.id)}`)) as Row;
      setDialog({ open: true, row: detail || row, readOnly });
    } catch {
      setDialog({ open: true, row, readOnly });
    } finally {
      setLoadingStaff(false);
    }
  }

  async function deleteTeacher() {
    if (!deleteTarget) return;
    setDeleting(true);
    setError("");
    try {
      await api(`staff/${stringValue(deleteTarget.id)}`, { method: "DELETE" });
      onSaved();
      onNotify(`${displayName(deleteTarget)}'s account was removed.`);
      setDeleteTarget(null);
      await load(true);
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to delete teacher account");
    } finally {
      setDeleting(false);
    }
  }

  return (
    <section className="ops-module teacher-directory">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon green">
            <UserCog size={20} />
          </div>
          <div>
            <p className="ops-kicker">Resource management</p>
            <h2>Teachers</h2>
            <p>Educator and coordinator profiles, staff credentials, and teaching assignments.</p>
          </div>
        </div>
        <div className="ops-actions">
          <button className="secondary-button" onClick={() => void load(true)} disabled={refreshing}>
            <RefreshCw size={16} className={refreshing ? "spin" : ""} /> Refresh
          </button>
          <button className="primary-button" onClick={() => setDialog({ open: true, readOnly: false })}>
            <Plus size={16} /> Add teacher
          </button>
        </div>
      </div>

      <div className="student-directory-toolbar">
        <div className="directory-search" role="search">
          <Search size={17} />
          <input
            type="search"
            placeholder="Search educator name, employee ID, username, email, or designation…"
            aria-label="Search teachers"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
          {search && (
            <button type="button" className="directory-search-clear" aria-label="Clear teacher search" onClick={() => setSearch("")}>
              <X size={15} />
            </button>
          )}
        </div>
        <select value={designationFilter} onChange={(event) => setDesignationFilter(event.target.value)} aria-label="Filter by designation">
          <option value="all">All designations</option>
          {designationOptions.map((opt) => (
            <option key={opt} value={opt}>{opt}</option>
          ))}
        </select>
        <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)} aria-label="Filter by status">
          <option value="all">All statuses</option>
          <option value="active">Active staff</option>
          <option value="inactive">Inactive staff</option>
        </select>
        <span className="ops-count">
          Showing <b>{filteredTeachers.length}</b> educator{filteredTeachers.length === 1 ? "" : "s"}
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
          <PortalModuleSkeleton variant="table" rows={5} label="Loading teacher records" />
        ) : filteredTeachers.length ? (
          <>
            <table className="data-table student-directory-table">
              <thead>
                <tr>
                  <th>Educator</th>
                  <th>Designation</th>
                  <th>Contact Details</th>
                  <th>Class Assignments</th>
                  <th>Status</th>
                  <th aria-label="Teacher actions" style={{ textAlign: "right" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {visibleTeachers.map((teacher) => {
                  const teacherId = stringValue(teacher.id);
                  const staffCode = stringValue(teacher.staff_code);
                  const designation = stringValue(teacher.designation || "Teacher");
                  const assignments = teacherClassAssignments(teacherId, staffCode, classes);
                  const isActive = teacher.is_active !== false;

                  return (
                    <tr key={teacherId}>
                      <td>
                        <div className="student-cell">
                          <span className="student-avatar" style={{ background: "#e7f1fa", color: "#0e5ea8" }}>
                            {teacherInitials(teacher)}
                          </span>
                          <div>
                            <b>{displayName(teacher)}</b>
                            <small>Emp ID: {staffCode || "—"} {teacher.username ? `· @${teacher.username}` : ""}</small>
                          </div>
                        </div>
                      </td>
                      <td>
                        <span
                          className="status-pill"
                          style={{
                            background: designation.toLowerCase().includes("coordinator")
                              ? "#fff4d7"
                              : "#e7f1fa",
                            color: designation.toLowerCase().includes("coordinator")
                              ? "#8a6100"
                              : "#0b477e",
                          }}
                        >
                          {designation}
                        </span>
                      </td>
                      <td>
                        <div>
                          <b>{stringValue(teacher.phone || "Phone not set")}</b>
                          <small style={{ color: "#637887", display: "block" }}>{stringValue(teacher.email || "Email not set")}</small>
                        </div>
                      </td>
                      <td>
                        {assignments.length > 0 ? (
                          <div style={{ display: "flex", flexWrap: "wrap", gap: "0.35rem" }}>
                            {assignments.map((item, idx) => (
                              <span
                                key={idx}
                                style={{
                                  display: "inline-flex",
                                  alignItems: "center",
                                  gap: "0.35rem",
                                  padding: "0.2rem 0.5rem",
                                  background: "#f0f4fb",
                                  border: "1px solid #c7d8ee",
                                  borderRadius: "14px",
                                  fontSize: "0.75rem",
                                  color: "#0f4a80",
                                  fontWeight: 600,
                                }}
                              >
                                {item.role}: {item.label}
                              </span>
                            ))}
                          </div>
                        ) : (
                          <span style={{ color: "#95a5b2", fontSize: "0.78rem" }}>General staff</span>
                        )}
                      </td>
                      <td>
                        <span className={`student-status ${isActive ? "active" : "inactive"}`}>
                          {isActive ? "Active" : "Inactive"}
                        </span>
                      </td>
                      <td className="actions-cell" style={{ textAlign: "right" }}>
                        <button
                          className="icon-button"
                          title="View staff profile"
                          onClick={() => void openTeacher(teacher, true)}
                          disabled={loadingStaff}
                          aria-busy={loadingStaff}
                        >
                          {loadingStaff ? <span className="activity-spinner" aria-hidden="true" /> : <Eye size={15} />}
                        </button>
                        <button
                          className="icon-button"
                          title="Edit staff member"
                          onClick={() => void openTeacher(teacher, false)}
                          disabled={loadingStaff}
                          aria-busy={loadingStaff}
                        >
                          {loadingStaff ? <span className="activity-spinner" aria-hidden="true" /> : <Pencil size={15} />}
                        </button>
                        <button
                          className="icon-button danger"
                          title="Delete staff account"
                          onClick={() => setDeleteTarget(teacher)}
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
          <p className="ops-empty">No educators match the current filters.</p>
        )}
      </div>

      {dialog.open && (
        <TeacherDialog
          row={dialog.row}
          readOnly={dialog.readOnly}
          classes={classes}
          onClose={() => setDialog({ open: false })}
          onSaved={() => {
            onSaved();
            onNotify(dialog.row ? "Staff profile updated." : "Staff account created.");
            void load(true);
          }}
        />
      )}

      {deleteTarget && (
        <Dialog kicker="Permanent action" title="Delete staff account?" onClose={() => !deleting && setDeleteTarget(null)}>
          <div className="student-delete-dialog">
            <CircleAlert size={22} />
            <p>
              <b>{displayName(deleteTarget)}</b> will be permanently removed from SchoolDesk. Linked teaching assignments and portal credentials will be revoked.
            </p>
          </div>
          <div className="dialog-footer">
            <button className="secondary-button" type="button" disabled={deleting} onClick={() => setDeleteTarget(null)}>
              Cancel
            </button>
            <button className="danger-button" type="button" disabled={deleting} onClick={() => void deleteTeacher()}>
              {deleting ? <LoadingIndicator label="Deleting…" compact announce={false} /> : "Delete staff account"}
            </button>
          </div>
        </Dialog>
      )}
    </section>
  );
}

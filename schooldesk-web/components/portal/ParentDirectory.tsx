"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CircleAlert,
  Eye,
  HeartHandshake,
  Pencil,
  Plus,
  RefreshCw,
  Trash2,
} from "@/lib/lucide-react";
import type { Row } from "./types";
import {
  api,
  displayName,
  nested,
  rowsFrom,
  stringValue,
} from "./utils";
import { Dialog } from "./Dialog";
import { ParentDialog } from "./ParentDialog";

type ParentDialogState = {
  open: boolean;
  row?: Row;
  readOnly?: boolean;
};

function parentInitials(row: Row) {
  const name = stringValue(row.name || row.username || "Parent");
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase() || "P";
}

function linkedStudentsForParent(parentId: string, students: Row[]) {
  if (!parentId) return [];
  return students.filter((st) => {
    if (stringValue(st.parent_user_id) === parentId) return true;
    const links = Array.isArray(st.parent_student_links)
      ? (st.parent_student_links as Row[])
      : [];
    return links.some((lnk) => {
      const pId = stringValue(lnk?.parent_user_id ?? nested(lnk ?? {}, "parent").id);
      return pId === parentId;
    });
  });
}

function studentClassLabel(student: Row) {
  const section = nested(student, "section");
  const grade = nested(section, "grade");
  const gradeName = stringValue(grade.grade_name ?? grade.name);
  const sectionName = stringValue(section.section_name ?? section.name);
  return [gradeName, sectionName].filter(Boolean).join(" - ");
}

export function ParentDirectory({
  createToken,
  onSaved,
  onNotify,
}: {
  createToken: number;
  onSaved: () => void;
  onNotify: (message: string) => void;
}) {
  const [parents, setParents] = useState<Row[]>([]);
  const [students, setStudents] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [linkFilter, setLinkFilter] = useState("all");
  const [page, setPage] = useState(1);
  const [dialog, setDialog] = useState<ParentDialogState>({ open: false });
  const [deleteTarget, setDeleteTarget] = useState<Row | null>(null);
  const [deleting, setDeleting] = useState(false);

  const load = useCallback(async (manual = false) => {
    if (manual) setRefreshing(true);
    else setLoading(true);
    setError("");
    try {
      const [parentData, studentData] = await Promise.all([
        api("users?role=parent&page=1&page_size=100"),
        api("students?page=1&page_size=100"),
      ]);
      setParents(rowsFrom(parentData));
      setStudents(rowsFrom(studentData));
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load parent records");
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

  const filteredParents = useMemo(() => {
    const query = search.trim().toLowerCase();
    return parents.filter((parent) => {
      const parentId = stringValue(parent.id);
      const name = stringValue(parent.name || parent.username);
      const username = stringValue(parent.username);
      const email = stringValue(parent.email);
      const phone = stringValue(parent.phone);
      const children = linkedStudentsForParent(parentId, students);
      const childrenNames = children.map(displayName).join(" ");

      const matchesSearch =
        !query ||
        [name, username, email, phone, childrenNames].some((val) =>
          val.toLowerCase().includes(query)
        );

      const isActive = parent.is_active !== false;
      const matchesStatus =
        statusFilter === "all" ||
        (statusFilter === "active" && isActive) ||
        (statusFilter === "inactive" && !isActive);

      const matchesLink =
        linkFilter === "all" ||
        (linkFilter === "linked" && children.length > 0) ||
        (linkFilter === "unlinked" && children.length === 0);

      return matchesSearch && matchesStatus && matchesLink;
    });
  }, [parents, students, search, statusFilter, linkFilter]);

  const pageSize = 10;
  const totalPages = Math.max(1, Math.ceil(filteredParents.length / pageSize));
  const visibleParents = useMemo(
    () => filteredParents.slice((page - 1) * pageSize, page * pageSize),
    [filteredParents, page]
  );

  useEffect(() => setPage(1), [search, statusFilter, linkFilter]);
  useEffect(() => {
    if (page > totalPages) setPage(totalPages);
  }, [page, totalPages]);

  async function deleteParent() {
    if (!deleteTarget) return;
    setDeleting(true);
    setError("");
    try {
      await api(`users/${stringValue(deleteTarget.id)}`, { method: "DELETE" });
      onSaved();
      onNotify(`${stringValue(deleteTarget.name || deleteTarget.username)} was deleted.`);
      setDeleteTarget(null);
      await load(true);
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to delete parent account");
    } finally {
      setDeleting(false);
    }
  }

  return (
    <section className="ops-module parent-directory">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon gold">
            <HeartHandshake size={20} />
          </div>
          <div>
            <p className="ops-kicker">Resource management</p>
            <h2>Parents</h2>
            <p>Parent portal accounts, family contacts, and linked learner profiles.</p>
          </div>
        </div>
        <div className="ops-actions">
          <button className="secondary-button" onClick={() => void load(true)} disabled={refreshing}>
            <RefreshCw size={16} className={refreshing ? "spin" : ""} /> Refresh
          </button>
          <button className="primary-button" onClick={() => setDialog({ open: true, readOnly: false })}>
            <Plus size={16} /> Add parent
          </button>
        </div>
      </div>

      <div className="student-directory-toolbar">
        <input
          className="search-input"
          placeholder="Search parent name, username, email, phone, or child name…"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)} aria-label="Filter by account status">
          <option value="all">All account statuses</option>
          <option value="active">Active accounts</option>
          <option value="inactive">Inactive accounts</option>
        </select>
        <select value={linkFilter} onChange={(event) => setLinkFilter(event.target.value)} aria-label="Filter by linked children">
          <option value="all">All parents</option>
          <option value="linked">With linked children</option>
          <option value="unlinked">Unlinked accounts</option>
        </select>
        <span className="ops-count">
          Showing <b>{filteredParents.length}</b> parent{filteredParents.length === 1 ? "" : "s"}
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
            {Array.from({ length: 5 }, (_, index) => (
              <div className="skeleton skeleton-row" key={index} />
            ))}
          </div>
        ) : filteredParents.length ? (
          <>
            <table className="data-table student-directory-table">
              <thead>
                <tr>
                  <th>Parent</th>
                  <th>Username</th>
                  <th>Contact Details</th>
                  <th>Linked Learners</th>
                  <th>Status</th>
                  <th aria-label="Parent actions" style={{ textAlign: "right" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {visibleParents.map((parent) => {
                  const parentId = stringValue(parent.id);
                  const children = linkedStudentsForParent(parentId, students);
                  const isActive = parent.is_active !== false;
                  return (
                    <tr key={parentId}>
                      <td>
                        <div className="student-cell">
                          <span className="student-avatar" style={{ background: "#fef3d6", color: "#8a5c00" }}>
                            {parentInitials(parent)}
                          </span>
                          <div>
                            <b>{stringValue(parent.name || parent.username)}</b>
                            <small>ID: {parentId.slice(0, 8)}…</small>
                          </div>
                        </div>
                      </td>
                      <td>
                        <span className="status-pill" style={{ background: "#eef5fc", color: "#0c5496" }}>
                          @{stringValue(parent.username || "—")}
                        </span>
                      </td>
                      <td>
                        <div>
                          <b>{stringValue(parent.phone || "Phone not set")}</b>
                          <small style={{ color: "#637887", display: "block" }}>{stringValue(parent.email || "Email not set")}</small>
                        </div>
                      </td>
                      <td>
                        {children.length > 0 ? (
                          <div style={{ display: "flex", flexWrap: "wrap", gap: "0.35rem" }}>
                            {children.map((child) => {
                              const cClass = studentClassLabel(child);
                              return (
                                <span
                                  key={stringValue(child.id)}
                                  style={{
                                    display: "inline-flex",
                                    alignItems: "center",
                                    gap: "0.35rem",
                                    padding: "0.2rem 0.5rem",
                                    background: "#eef8f1",
                                    border: "1px solid #c5eacc",
                                    borderRadius: "14px",
                                    fontSize: "0.75rem",
                                    color: "#1b542a",
                                    fontWeight: 600,
                                  }}
                                >
                                  {displayName(child)} {cClass ? `· ${cClass}` : ""}
                                </span>
                              );
                            })}
                          </div>
                        ) : (
                          <span style={{ color: "#95a5b2", fontSize: "0.78rem" }}>No linked students</span>
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
                          title="View parent details"
                          onClick={() => setDialog({ open: true, row: parent, readOnly: true })}
                        >
                          <Eye size={15} />
                        </button>
                        <button
                          className="icon-button"
                          title="Edit parent account"
                          onClick={() => setDialog({ open: true, row: parent, readOnly: false })}
                        >
                          <Pencil size={15} />
                        </button>
                        <button
                          className="icon-button danger"
                          title="Delete parent account"
                          onClick={() => setDeleteTarget(parent)}
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
          <p className="ops-empty">No parents match the current filters.</p>
        )}
      </div>

      {dialog.open && (
        <ParentDialog
          row={dialog.row}
          readOnly={dialog.readOnly}
          onClose={() => setDialog({ open: false })}
          onSaved={() => {
            onSaved();
            onNotify(dialog.row ? "Parent profile updated." : "Parent registered.");
            void load(true);
          }}
        />
      )}

      {deleteTarget && (
        <Dialog kicker="Permanent action" title="Delete parent account?" onClose={() => !deleting && setDeleteTarget(null)}>
          <div className="student-delete-dialog">
            <CircleAlert size={22} />
            <p>
              <b>{stringValue(deleteTarget.name || deleteTarget.username)}</b> will be permanently removed from SchoolDesk. Linked student relationships will be cleared.
            </p>
          </div>
          <div className="dialog-footer">
            <button className="secondary-button" type="button" disabled={deleting} onClick={() => setDeleteTarget(null)}>
              Cancel
            </button>
            <button className="danger-button" type="button" disabled={deleting} onClick={() => void deleteParent()}>
              {deleting ? "Deleting…" : "Delete parent"}
            </button>
          </div>
        </Dialog>
      )}
    </section>
  );
}

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CircleAlert,
  Eye,
  HeartHandshake,
  Pencil,
  Plus,
  RefreshCw,
  RotateCcw,
  ShieldCheck,
  Trash2,
  UserCog,
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

function linkedStudentsForParent(parentId: string, parentName: string, students: Row[]) {
  if (!parentId) return [];
  const normName = parentName.trim().toLowerCase();
  return students.filter((st) => {
    // Formal link via parent_student_links table
    if (stringValue(st.parent_user_id) === parentId) return true;
    const links = Array.isArray(st.parent_student_links)
      ? (st.parent_student_links as Row[])
      : [];
    if (links.some((lnk) => {
      const pId = stringValue(lnk?.parent_user_id ?? nested(lnk ?? {}, "parent").id);
      return pId === parentId;
    })) return true;
    // Soft match: guardian full_name matches parent account name (catches legacy records)
    if (normName) {
      const guardians = Array.isArray(st.guardians) ? (st.guardians as Row[]) : [];
      return guardians.some((g) =>
        stringValue(g.full_name ?? g.name).trim().toLowerCase() === normName
      );
    }
    return false;
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
  const [resetTarget, setResetTarget] = useState<Row | null>(null);
  const [resetResult, setResetResult] = useState<{ username: string; temporary_password: string } | null>(null);
  const [resetting, setResetting] = useState(false);
  const [resetError, setResetError] = useState("");
  const [linkTarget, setLinkTarget] = useState<Row | null>(null);
  const [linkStudentId, setLinkStudentId] = useState("");
  const [linking, setLinking] = useState(false);
  const [linkError, setLinkError] = useState("");

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
      const children = linkedStudentsForParent(parentId, stringValue(parent.name || parent.username), students);
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

  async function resetCredentials() {
    if (!resetTarget) return;
    setResetting(true);
    setResetError("");
    try {
      const result = await api(`users/${stringValue(resetTarget.id)}/reset-credentials`, { method: "POST" }) as { username: string; temporary_password: string };
      setResetResult(result);
      setResetTarget(null);
    } catch (event) {
      setResetError(event instanceof Error ? event.message : "Unable to reset credentials");
    } finally {
      setResetting(false);
    }
  }

  async function linkStudent() {
    if (!linkTarget || !linkStudentId) return;
    setLinking(true);
    setLinkError("");
    try {
      await api(`students/${linkStudentId}/parent`, {
        method: "PUT",
        body: JSON.stringify({ parent_user_id: stringValue(linkTarget.id) }),
      });
      onNotify(`Student linked to ${stringValue(linkTarget.name || linkTarget.username)}.`);
      setLinkTarget(null);
      setLinkStudentId("");
      await load(true);
    } catch (event) {
      setLinkError(event instanceof Error ? event.message : "Unable to link student");
    } finally {
      setLinking(false);
    }
  }

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
          <PortalModuleSkeleton variant="table" rows={5} label="Loading parent records" />
        ) : filteredParents.length ? (
          <>
            <table className="data-table student-directory-table">
              <thead>
                <tr>
                  <th>Parent</th>
                  <th>Login Credentials</th>
                  <th>Contact Details</th>
                  <th>Linked Students</th>
                  <th>Status</th>
                  <th aria-label="Parent actions" style={{ textAlign: "right" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {visibleParents.map((parent) => {
                  const parentId = stringValue(parent.id);
                  const children = linkedStudentsForParent(parentId, stringValue(parent.name || parent.username), students);
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
                        <div style={{ display: "flex", flexDirection: "column", gap: "0.25rem" }}>
                          <span className="status-pill" style={{ background: "#eef5fc", color: "#0c5496", width: "fit-content" }}>
                            @{stringValue(parent.username || "—")}
                          </span>
                          <span style={{ fontSize: "0.72rem", color: "#95a5b2" }}>
                            {parent.password_reset_at
                              ? `Last reset: ${stringValue(parent.password_reset_at).slice(0, 10)}`
                              : "Password not yet reset"}
                          </span>
                        </div>
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
                          title="Link / unlink students"
                          onClick={() => { setLinkTarget(parent); setLinkStudentId(""); setLinkError(""); }}
                        >
                          <UserCog size={15} />
                        </button>
                        <button
                          className="icon-button"
                          title="Reset login credentials"
                          onClick={() => { setResetTarget(parent); setResetError(""); }}
                        >
                          <RotateCcw size={15} />
                        </button>
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
              {deleting ? <LoadingIndicator label="Deleting…" compact announce={false} /> : "Delete parent"}
            </button>
          </div>
        </Dialog>
      )}

      {linkTarget && (() => {
        const parentId = stringValue(linkTarget.id);
        const parentName = stringValue(linkTarget.name || linkTarget.username);
        const currentLinked = linkedStudentsForParent(parentId, parentName, students);
        const unlinkedStudents = students.filter((st) => {
          const stId = stringValue(st.id);
          return !currentLinked.some((c) => stringValue(c.id) === stId);
        });
        return (
          <Dialog kicker="Student linking" title={`Linked students — ${parentName}`} onClose={() => !linking && setLinkTarget(null)}>
            <div style={{ display: "flex", flexDirection: "column", gap: "1rem", padding: "0.25rem 0" }}>
              {currentLinked.length > 0 ? (
                <div>
                  <p style={{ margin: "0 0 0.5rem", fontSize: "0.78rem", fontWeight: 600, color: "#637887", textTransform: "uppercase", letterSpacing: "0.05em" }}>Currently linked</p>
                  <div style={{ display: "flex", flexWrap: "wrap", gap: "0.4rem" }}>
                    {currentLinked.map((child) => (
                      <span
                        key={stringValue(child.id)}
                        style={{ display: "inline-flex", alignItems: "center", gap: "0.35rem", padding: "0.25rem 0.6rem", background: "#eef8f1", border: "1px solid #c5eacc", borderRadius: "14px", fontSize: "0.78rem", color: "#1b542a", fontWeight: 600 }}
                      >
                        {displayName(child)}
                        {studentClassLabel(child) ? ` · ${studentClassLabel(child)}` : ""}
                      </span>
                    ))}
                  </div>
                </div>
              ) : (
                <p style={{ margin: 0, color: "#95a5b2", fontSize: "0.85rem" }}>No students linked yet.</p>
              )}
              <div>
                <p style={{ margin: "0 0 0.5rem", fontSize: "0.78rem", fontWeight: 600, color: "#637887", textTransform: "uppercase", letterSpacing: "0.05em" }}>Link a student</p>
                <div style={{ display: "flex", gap: "0.5rem", alignItems: "center" }}>
                  <select
                    value={linkStudentId}
                    onChange={(e) => setLinkStudentId(e.target.value)}
                    style={{ flex: 1 }}
                    disabled={linking}
                  >
                    <option value="">Select a student…</option>
                    {unlinkedStudents.map((st) => {
                      const cls = studentClassLabel(st);
                      return (
                        <option key={stringValue(st.id)} value={stringValue(st.id)}>
                          {displayName(st)}{cls ? ` — ${cls}` : ""}
                        </option>
                      );
                    })}
                  </select>
                  <button
                    className="primary-button"
                    type="button"
                    disabled={!linkStudentId || linking}
                    onClick={() => void linkStudent()}
                    style={{ whiteSpace: "nowrap" }}
                  >
                    {linking ? "Linking…" : "Link student"}
                  </button>
                </div>
                {linkError && (
                  <p style={{ margin: "0.4rem 0 0", color: "#c0392b", fontSize: "0.82rem", display: "flex", gap: "0.35rem", alignItems: "center" }}>
                    <CircleAlert size={13} /> {linkError}
                  </p>
                )}
                <p style={{ margin: "0.6rem 0 0", fontSize: "0.75rem", color: "#95a5b2" }}>
                  Linking creates a permanent connection so the parent can view this student in the app.
                </p>
              </div>
            </div>
            <div className="dialog-footer">
              <button className="secondary-button" type="button" onClick={() => setLinkTarget(null)}>
                Done
              </button>
            </div>
          </Dialog>
        );
      })()}

      {resetTarget && (
        <Dialog kicker="Credentials" title="Reset login credentials?" onClose={() => !resetting && setResetTarget(null)}>
          <div className="student-delete-dialog">
            <ShieldCheck size={22} style={{ color: "#0c5496" }} />
            <p>
              A new temporary password will be generated for{" "}
              <b>{stringValue(resetTarget.name || resetTarget.username)}</b>. Share it with the parent so they can log in and change it.
            </p>
          </div>
          {resetError && (
            <div className="ops-inline-error" style={{ margin: "0 0 .75rem" }}>
              <CircleAlert size={14} /> {resetError}
            </div>
          )}
          <div className="dialog-footer">
            <button className="secondary-button" type="button" disabled={resetting} onClick={() => setResetTarget(null)}>
              Cancel
            </button>
            <button className="primary-button" type="button" disabled={resetting} onClick={() => void resetCredentials()}>
              {resetting ? <LoadingIndicator label="Resetting…" compact announce={false} /> : <><RotateCcw size={14} /> Reset password</>}
            </button>
          </div>
        </Dialog>
      )}

      {resetResult && (
        <Dialog kicker="Credentials reset" title="New login credentials" onClose={() => setResetResult(null)}>
          <div style={{ display: "flex", flexDirection: "column", gap: "1rem", padding: "0.5rem 0" }}>
            <p style={{ color: "#2d4a5e", margin: 0, fontSize: "0.9rem" }}>
              Share these credentials with the parent. The password is temporary — they will be prompted to change it on first login.
            </p>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.75rem" }}>
              <div style={{ background: "#eef5fc", borderRadius: "10px", padding: "0.85rem 1rem" }}>
                <p style={{ margin: "0 0 0.25rem", fontSize: "0.72rem", color: "#637887", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.06em" }}>Username</p>
                <p style={{ margin: 0, fontWeight: 700, fontSize: "1rem", color: "#0c5496", wordBreak: "break-all" }}>{resetResult.username}</p>
              </div>
              <div style={{ background: "#f3f8ec", borderRadius: "10px", padding: "0.85rem 1rem" }}>
                <p style={{ margin: "0 0 0.25rem", fontSize: "0.72rem", color: "#637887", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.06em" }}>Temporary Password</p>
                <p style={{ margin: 0, fontWeight: 700, fontSize: "1rem", color: "#1b542a", wordBreak: "break-all" }}>{resetResult.temporary_password}</p>
              </div>
            </div>
            <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
              <button
                className="secondary-button"
                type="button"
                onClick={() => void navigator.clipboard.writeText(resetResult.username)}
              >
                Copy username
              </button>
              <button
                className="secondary-button"
                type="button"
                onClick={() => void navigator.clipboard.writeText(resetResult.temporary_password)}
              >
                Copy password
              </button>
              <button
                className="secondary-button"
                type="button"
                onClick={() => void navigator.clipboard.writeText(`Username: ${resetResult.username}\nPassword: ${resetResult.temporary_password}`)}
              >
                Copy both
              </button>
            </div>
          </div>
          <div className="dialog-footer">
            <button className="primary-button" type="button" onClick={() => setResetResult(null)}>
              Done
            </button>
          </div>
        </Dialog>
      )}
    </section>
  );
}

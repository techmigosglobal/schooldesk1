"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CircleAlert,
  Eye,
  Pencil,
  Plus,
  RefreshCw,
  Trash2,
} from "lucide-react";
import type { Module, Row } from "./types";
import { api, rowsFrom, rowText, stringValue } from "./utils";
import { StudentDialog } from "./StudentDialog";
import { TeacherDialog } from "./TeacherDialog";
import { GenericDialog } from "./GenericDialog";

export function ResourceModule({
  module,
  createToken,
  onSaved,
  onNotify,
}: {
  module: Module;
  createToken: number;
  onSaved: () => void;
  onNotify: (message: string) => void;
}) {
  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [dialogState, setDialogState] = useState<{
    open: boolean;
    row?: Row;
    readOnly?: boolean;
  }>({ open: false });

  const load = useCallback(
    async (isManualRefresh = false) => {
      if (isManualRefresh) setRefreshing(true);
      else setLoading(true);
      setError("");
      try {
        const raw = await api(module.endpoint);
        setRows(rowsFrom(raw));
      } catch (event) {
        setError(event instanceof Error ? event.message : "Unable to load records");
      } finally {
        setLoading(false);
        setRefreshing(false);
      }
    },
    [module.endpoint]
  );

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    if (createToken > 0) {
      setDialogState({ open: true, row: undefined, readOnly: false });
    }
  }, [createToken]);

  const filteredRows = useMemo(() => {
    if (!search.trim()) return rows;
    const query = search.toLowerCase();
    return rows.filter((row) =>
      JSON.stringify(row).toLowerCase().includes(query)
    );
  }, [rows, search]);

  async function remove(row: Row) {
    const label = stringValue(row.name || row.first_name || row.id || "this record");
    if (!confirm(`Are you sure you want to delete ${label}?`)) return;
    try {
      await api(`${module.create}/${row.id}`, { method: "DELETE" });
      onNotify(`${label} removed.`);
      onSaved();
      void load();
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to delete");
    }
  }

  const Icon = module.icon;

  return (
    <section className="ops-module">
      <div className="ops-module-heading">
        <div>
          <div className={`ops-module-icon ${module.tone}`}>
            <Icon size={20} />
          </div>
          <div>
            <p className="ops-kicker">Resource management</p>
            <h2>{module.label}</h2>
            <p>{module.description}</p>
          </div>
        </div>

        <div className="ops-actions">
          <input
            className="search-input"
            placeholder={`Search ${module.label.toLowerCase()}…`}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <button
            className="secondary-button"
            onClick={() => void load(true)}
            disabled={refreshing}
          >
            <RefreshCw size={16} className={refreshing ? "spin" : ""} /> Refresh
          </button>
          <button
            className="primary-button"
            onClick={() => setDialogState({ open: true, row: undefined, readOnly: false })}
          >
            <Plus size={16} /> Add {module.label.slice(0, -1)}
          </button>
        </div>
      </div>

      {error && (
        <div className="ops-inline-error">
          <CircleAlert size={16} />
          {error}
        </div>
      )}

      <div className="table-card surface ops-table-surface">
        {loading ? (
          <div className="skeleton-container" style={{ padding: "1rem" }}>
            <div className="skeleton skeleton-row" />
            <div className="skeleton skeleton-row" />
            <div className="skeleton skeleton-row" />
            <div className="skeleton skeleton-row" />
            <div className="skeleton skeleton-row" />
          </div>
        ) : filteredRows.length ? (
          <table className="data-table ops-data-table">
            <thead>
              <tr>
                {module.columns.map(([key, title]) => (
                  <th key={key}>{title}</th>
                ))}
                <th style={{ width: "110px", textAlign: "right" }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredRows.map((row, index) => (
                <tr key={stringValue(row.id) || index}>
                  {module.columns.map(([key]) => (
                    <td key={key}>{rowText(row, key)}</td>
                  ))}
                  <td className="actions-cell" style={{ textAlign: "right" }}>
                    <button
                      className="icon-button"
                      title="View details"
                      onClick={() =>
                        setDialogState({ open: true, row, readOnly: true })
                      }
                    >
                      <Eye size={15} />
                    </button>
                    <button
                      className="icon-button"
                      title="Edit record"
                      onClick={() =>
                        setDialogState({ open: true, row, readOnly: false })
                      }
                    >
                      <Pencil size={15} />
                    </button>
                    <button
                      className="icon-button danger"
                      title="Delete record"
                      onClick={() => void remove(row)}
                    >
                      <Trash2 size={15} />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <p className="ops-empty">
            {search
              ? "No records matching your search."
              : `No ${module.label.toLowerCase()} registered yet.`}
          </p>
        )}
      </div>

      {dialogState.open &&
        (module.id === "students" ? (
          <StudentDialog
            row={dialogState.row}
            readOnly={dialogState.readOnly}
            onClose={() => setDialogState({ open: false })}
            onSaved={() => {
              onSaved();
              onNotify(
                dialogState.row ? "Student updated." : "Student registered."
              );
              void load();
            }}
          />
        ) : module.id === "teachers" ? (
          <TeacherDialog
            row={dialogState.row}
            readOnly={dialogState.readOnly}
            onClose={() => setDialogState({ open: false })}
            onSaved={() => {
              onSaved();
              onNotify(
                dialogState.row ? "Staff profile updated." : "Staff account created."
              );
              void load();
            }}
          />
        ) : (
          <GenericDialog
            module={module}
            row={dialogState.row}
            readOnly={dialogState.readOnly}
            onClose={() => setDialogState({ open: false })}
            onSaved={() => {
              onSaved();
              onNotify("Record saved.");
              void load();
            }}
          />
        ))}
    </section>
  );
}

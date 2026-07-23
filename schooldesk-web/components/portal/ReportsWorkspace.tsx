"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { ChartNoAxesCombined, Download, RefreshCw } from "@/lib/lucide-react";
import type { PortalRole } from "@/lib/roles";
import type { Row } from "./types";
import { api, formatDate, money, nested, rowsFrom, stringValue } from "./utils";

export function ReportsWorkspace({
  role,
  onNotify,
}: {
  role: PortalRole;
  onNotify: (message: string, type?: "success" | "error" | "info") => void;
}) {
  const [dashboard, setDashboard] = useState<Row>({});
  const [sessions, setSessions] = useState<Row[]>([]);
  const [students, setStudents] = useState<Row[]>([]);
  const [staff, setStaff] = useState<Row[]>([]);
  const [invoices, setInvoices] = useState<Row[]>([]);
  const [payments, setPayments] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const today = new Date();
      const monthStart = new Date(today.getFullYear(), today.getMonth(), 1)
        .toISOString()
        .slice(0, 10);
      const monthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0)
        .toISOString()
        .slice(0, 10);
      const [dashboardData, studentsData, staffData, sessionsData, invoicesData, paymentsData] =
        await Promise.all([
          api("dashboard"),
          api("students?page=1&page_size=200"),
          api("staff?page=1&page_size=200"),
          api(`attendance/sessions?start_date=${monthStart}&end_date=${monthEnd}`),
          role === "principal" ? api("fees/invoices?page=1&page_size=200") : Promise.resolve([]),
          role === "principal" ? api("fees/payments?page=1&page_size=200") : Promise.resolve([]),
        ]);

      setDashboard((dashboardData as Row) || {});
      setStudents(rowsFrom(studentsData));
      setStaff(rowsFrom(staffData));
      setSessions(rowsFrom(sessionsData));
      setInvoices(rowsFrom(invoicesData));
      setPayments(rowsFrom(paymentsData));
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load reporting workspace");
    } finally {
      setLoading(false);
    }
  }, [role]);

  useEffect(() => {
    void load();
  }, [load]);

  const totals = useMemo(() => {
    const billed = invoices.reduce((sum, row) => sum + Number(row.net_amount || row.total_amount || 0), 0);
    const collected = payments.reduce((sum, row) => sum + Number(row.amount_paid || 0), 0);
    return {
      billed,
      collected,
      outstanding: Math.max(billed - collected, 0),
    };
  }, [invoices, payments]);
  const todayAttendance = nested(dashboard, "today_attendance");

  function previewPdf(kind: "operations" | "finance") {
    const title = kind === "finance" ? "Fee Operations Summary" : "Principal Operations Summary";
    const popup = window.open("", "_blank", "noopener,noreferrer");
    if (!popup) { setError("Allow pop-ups to preview this PDF report."); return; }
    const financeRows = kind === "finance" ? `<tr><td>Billed</td><td>${money(totals.billed)}</td></tr><tr><td>Collected</td><td>${money(totals.collected)}</td></tr><tr><td>Outstanding</td><td>${money(totals.outstanding)}</td></tr>` : "";
    popup.document.write(`<!doctype html><title>${title}</title><style>body{font-family:Arial;padding:32px;color:#102a43}table{border-collapse:collapse;width:100%;max-width:680px}td{border:1px solid #cbd5e1;padding:10px}h1{margin-bottom:4px}@media print{button{display:none}}</style><h1>${title}</h1><p>Generated ${new Date().toLocaleString()}</p><table><tr><td>Students</td><td>${students.length}</td></tr><tr><td>Staff</td><td>${staff.length}</td></tr><tr><td>Attendance sessions</td><td>${sessions.length}</td></tr>${financeRows}</table><p><button onclick="window.print()">Preview / Save as PDF</button></p>`);
    popup.document.close();
    onNotify(`${title} is ready for PDF preview.`);
  }

  return (
    <section className="ops-module">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon blue">
            <ChartNoAxesCombined size={20} />
          </div>
          <div>
            <p className="ops-kicker">Operational intelligence</p>
            <h2>Reports & Exports</h2>
            <p>Review live operational totals and generate export-ready summaries for leadership follow-up.</p>
          </div>
        </div>
        <div className="ops-actions">
          <button className="secondary-button" onClick={() => void load()}>
            <RefreshCw size={16} /> Refresh
          </button>
        </div>
      </div>

      {error && <div className="ops-inline-error">{error}</div>}

      <div className="finance-summary ops-summary-grid">
        <article>
          <small>Students</small>
          <b>{stringValue(dashboard.total_students ?? students.length)}</b>
        </article>
        <article>
          <small>Staff</small>
          <b>{stringValue(dashboard.total_staff ?? staff.length)}</b>
        </article>
        <article>
          <small>Attendance Sessions</small>
          <b>{sessions.length}</b>
        </article>
        <article>
          <small>{role === "principal" ? "Collected Fees" : "Attendance Today"}</small>
          <b>
            {role === "principal"
              ? money(totals.collected)
              : `${stringValue(todayAttendance.attendance_pct ?? 0)}%`}
          </b>
        </article>
      </div>

      <div className="ops-split-grid">
        <section className="surface ops-form-surface">
          <div className="ops-panel-header">
            <h3>Operational summaries</h3>
          </div>
          {loading ? (
            <p className="ops-empty-small">Loading report signals…</p>
          ) : (
            <div className="ops-feed-list">
              <article>
                <div>
                  <b>Leadership overview</b>
                  <p>
                    {students.length} students, {staff.length} staff, {sessions.length} attendance
                    sessions this month.
                  </p>
                </div>
                <div className="ops-feed-meta">
                  <small>{formatDate(new Date().toISOString())}</small>
                </div>
              </article>
              {role === "principal" && (
                <article>
                  <div>
                    <b>Finance health</b>
                    <p>
                      Billed {money(totals.billed)} · Collected {money(totals.collected)} ·
                      Outstanding {money(totals.outstanding)}
                    </p>
                  </div>
                  <div className="ops-feed-meta">
                    <small>{invoices.length} invoices</small>
                  </div>
                </article>
              )}
              <article>
                <div>
                  <b>Recent attendance follow-up</b>
                  <p>
                    {sessions.filter((item) => stringValue(item.status).toLowerCase() !== "finalized").length}
                    {" "}sessions still need attention or review.
                  </p>
                </div>
                <div className="ops-feed-meta">
                  <small>Actionable now</small>
                </div>
              </article>
            </div>
          )}
        </section>

        <section className="surface ops-form-surface">
          <div className="ops-panel-header">
            <h3>Export center</h3>
          </div>
          <div className="ops-report-grid">
            <button className="ops-report-card" onClick={() => previewPdf("operations")}>
              <Download size={18} />
              <strong>Operations PDF</strong>
              <span>Leadership-ready summary for meetings and print-outs.</span>
            </button>
            {role === "principal" && (
              <>
                <button className="ops-report-card" onClick={() => previewPdf("finance")}>
                  <Download size={18} />
                  <strong>Finance PDF</strong>
                  <span>Preview the live finance snapshot before saving as PDF.</span>
                </button>
              </>
            )}
          </div>
        </section>
      </div>
    </section>
  );
}

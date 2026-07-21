"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { ChartNoAxesCombined, Download, FileSpreadsheet, RefreshCw } from "@/lib/lucide-react";
import type { PortalRole } from "@/lib/roles";
import type { Row } from "./types";
import { api, downloadCsv, formatDate, money, nested, rowsFrom, stringValue } from "./utils";

async function downloadRemoteFile(url: string, filename: string) {
  const response = await fetch(url);
  if (!response.ok) throw new Error("The generated export file could not be downloaded.");
  const blob = await response.blob();
  const objectUrl = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = objectUrl;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(objectUrl);
}

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

  async function requestExport(kind: "operations" | "finance", format: "csv" | "pdf") {
    try {
      const title = kind === "finance" ? "Fee Operations Summary" : "Principal Operations Summary";
      const path = kind === "finance" ? "fees/reports/exports" : "reports/exports";
      const payload: Row = {
        reportTitle: title,
        reportType: kind === "finance" ? "fee_outstanding_report" : "principal_summary",
        format,
        scope: role,
        parameters: {
          total_students: students.length,
          total_staff: staff.length,
          total_sessions: sessions.length,
          total_billed: totals.billed,
          total_collected: totals.collected,
        },
      };
      const exportResponse = (await api(path, {
        method: "POST",
        body: JSON.stringify(payload),
      })) as Row;
      const downloadUrl = stringValue(exportResponse.download_url);
      if (downloadUrl) {
        await downloadRemoteFile(
          downloadUrl,
          `${kind}_${new Date().toISOString().slice(0, 10)}.${format === "pdf" ? "pdf" : "csv"}`
        );
        onNotify(`${title} downloaded.`);
      } else {
        onNotify(`${title} export requested. The backend will finish generating it shortly.`, "info");
      }
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to request export");
    }
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
            <button className="ops-report-card" onClick={() => void requestExport("operations", "csv")}>
              <FileSpreadsheet size={18} />
              <strong>Operations CSV</strong>
              <span>School-wide summary with attendance and people metrics.</span>
            </button>
            <button className="ops-report-card" onClick={() => void requestExport("operations", "pdf")}>
              <Download size={18} />
              <strong>Operations PDF</strong>
              <span>Leadership-ready summary for meetings and print-outs.</span>
            </button>
            {role === "principal" && (
              <>
                <button className="ops-report-card" onClick={() => void requestExport("finance", "csv")}>
                  <FileSpreadsheet size={18} />
                  <strong>Finance CSV</strong>
                  <span>Fee operations export with billed, paid, and outstanding totals.</span>
                </button>
                <button
                  className="ops-report-card"
                  onClick={() =>
                    downloadCsv(
                      `finance_snapshot_${new Date().toISOString().slice(0, 10)}.csv`,
                      invoices.map((row) => ({
                        invoice_number: row.invoice_number,
                        student: `${row.student_name ?? row.first_name ?? ""}`.trim(),
                        status: row.status,
                        net_amount: row.net_amount,
                        total_paid: row.total_paid,
                        balance: row.balance,
                      }))
                    )
                  }
                >
                  <Download size={18} />
                  <strong>Invoice Snapshot</strong>
                  <span>Quick CSV fallback generated directly from live portal data.</span>
                </button>
              </>
            )}
          </div>
        </section>
      </div>
    </section>
  );
}

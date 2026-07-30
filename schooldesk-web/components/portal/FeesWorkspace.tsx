"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CircleAlert,
  Download,
  FileText,
  Plus,
  ReceiptIndianRupee,
  RefreshCw,
  WalletCards,
} from "@/lib/lucide-react";
import type { FeeState, Row } from "./types";
import {
  api,
  displayName,
  downloadCsv,
  money,
  nested,
  rowsFrom,
  rowText,
  stringValue,
} from "./utils";
import { FeeStructureDialog } from "./FeeStructureDialog";
import { PaymentDialog } from "./PaymentDialog";
import { ConcessionDialog } from "./ConcessionDialog";

function studentInitials(name: string) {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase() || "S";
}

function FinanceTable({
  headers,
  rows,
  renderRow,
  emptyText,
}: {
  headers: string[];
  rows: Row[];
  renderRow: (row: Row) => React.ReactNode;
  emptyText: string;
}) {
  if (!rows.length) return <p className="ops-empty">{emptyText}</p>;
  return (
    <table className="data-table student-directory-table">
      <thead>
        <tr>
          {headers.map((h) => (
            <th key={h}>{h}</th>
          ))}
        </tr>
      </thead>
      <tbody>{rows.map(renderRow)}</tbody>
    </table>
  );
}

export function FeesWorkspace({
  onNotify,
}: {
  onNotify: (message: string, type?: "success" | "error" | "info") => void;
}) {
  const [tab, setTab] = useState<
    "structures" | "invoices" | "collections" | "requests" | "concessions" | "reports"
  >("structures");
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState("");
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [dialog, setDialog] = useState<"structure" | "payment" | "concession" | false>(
    false
  );
  const [state, setState] = useState<FeeState>({
    structures: [],
    invoices: [],
    payments: [],
    requests: [],
    concessions: [],
    categories: [],
    years: [],
    grades: [],
    sections: [],
    config: {},
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [
        structures,
        invoices,
        payments,
        requests,
        concessions,
        categories,
        years,
        grades,
        sections,
        config,
      ] = await Promise.all([
        api("fees/structures").catch(() => []),
        api("fees/invoices?page=1&page_size=100").catch(() => []),
        api("fees/payments?page=1&page_size=100").catch(() => []),
        api("fees/payment-requests").catch(() => []),
        api("fees/concessions").catch(() => []),
        api("fees/categories").catch(() => []),
        api("academic-years").catch(() => []),
        api("grades").catch(() => []),
        api("sections?page=1&page_size=100").catch(() => []),
        api("fees/payment-config").catch(() => ({})),
      ]);

      setState({
        structures: rowsFrom(structures),
        invoices: rowsFrom(invoices),
        payments: rowsFrom(payments),
        requests: rowsFrom(requests),
        concessions: rowsFrom(concessions),
        categories: rowsFrom(categories),
        years: rowsFrom(years),
        grades: rowsFrom(grades),
        sections: rowsFrom(sections),
        config: (config as Row) || {},
      });
      setNotice("");
    } catch (event) {
      setNotice(
        event instanceof Error ? event.message : "Unable to load finance data"
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const filteredInvoices = useMemo(() => {
    const query = search.trim().toLowerCase();
    return state.invoices.filter((inv) => {
      const invNum = stringValue(inv.invoice_number);
      const stName = displayName(nested(inv, "student"));
      const status = stringValue(inv.status).toLowerCase();

      const matchesSearch = !query || [invNum, stName].some((v) => v.toLowerCase().includes(query));
      const matchesStatus =
        statusFilter === "all" ||
        (statusFilter === "paid" && status === "paid") ||
        (statusFilter === "unpaid" && status === "unpaid") ||
        (statusFilter === "partial" && status === "partial");

      return matchesSearch && matchesStatus;
    });
  }, [state.invoices, search, statusFilter]);

  async function requestFinanceExport(reportType: string, title: string) {
    try {
      const result = (await api("fees/reports/exports", {
        method: "POST",
        body: JSON.stringify({
          report_title: title,
          report_type: reportType,
          format: "pdf",
          parameters: {
            invoice_count: state.invoices.length,
            payment_count: state.payments.length,
            concession_count: state.concessions.length,
          },
        }),
      })) as Row;
      if (stringValue(result.download_url)) {
        const response = await fetch(stringValue(result.download_url));
        if (!response.ok) throw new Error("The fee export could not be downloaded.");
        const blob = await response.blob();
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = `${title.toLowerCase().replaceAll(/\s+/g, "_")}.pdf`;
        link.click();
        URL.revokeObjectURL(url);
        onNotify(`${title} downloaded.`);
        return;
      }
      onNotify(`${title} export requested.`, "info");
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to export finance report");
    }
  }

  async function applyFines() {
    try {
      const res = (await api("fees/invoices/late-fines/apply", {
        method: "POST",
      })) as Row;
      onNotify(`Late fines applied. Updated ${stringValue(res.updated || 0)} invoices.`);
      void load();
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to apply late fines");
    }
  }

  async function decide(req: Row, status: "approved" | "rejected") {
    try {
      await api(`fees/payment-requests/${req.id}/decision`, {
        method: "PUT",
        body: JSON.stringify({ status }),
      });
      onNotify(`Payment request ${status}.`);
      void load();
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Decision failed");
    }
  }

  async function saveConfig(form: FormData) {
    try {
      await api("fees/payment-config", {
        method: "PUT",
        body: JSON.stringify(Object.fromEntries(form)),
      });
      onNotify("Bank and UPI gateway settings saved.");
      void load();
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Save failed");
    }
  }

  const totalBilled = state.invoices.reduce(
    (sum, r) => sum + Number(r.net_amount || r.total_amount || 0),
    0
  );
  const totalPaid = state.payments.reduce(
    (sum, r) => sum + Number(r.amount_paid || 0),
    0
  );
  const totalOutstanding = state.invoices.reduce(
    (sum, r) => sum + Number(r.balance || r.net_amount || 0),
    0
  );
  const collectionRate = totalBilled > 0 ? Math.min(100, Math.round((totalPaid / totalBilled) * 100)) : 0;
  const pendingRequestsCount = state.requests.filter(
    (r) => stringValue(r.status).toLowerCase() === "pending"
  ).length;
  const overdueInvoices = state.invoices.filter(
    (row) =>
      Number(row.balance || 0) > 0 &&
      stringValue(row.status).toLowerCase() !== "paid"
  );

  return (
    <section className="ops-module fees-workspace">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon gold" style={{ background: "#fff4d7", color: "#9a6b00" }}>
            <WalletCards size={20} />
          </div>
          <div>
            <p className="ops-kicker">Principal ledger</p>
            <h2>Fee Operations &amp; Accounting</h2>
            <p>
              Automate monthly billing, track UPI receipts, apply late fines, and approve concessions.
            </p>
          </div>
        </div>

        <div className="ops-actions">
          <button className="secondary-button" onClick={() => void load()}>
            <RefreshCw size={16} /> Refresh ledger
          </button>
          <button className="secondary-button" onClick={() => void applyFines()}>
            <ReceiptIndianRupee size={16} /> Apply late fines
          </button>
          <button className="primary-button" onClick={() => setDialog("structure")}>
            <Plus size={16} /> New fee structure
          </button>
        </div>
      </div>

      {notice && (
        <div className="ops-inline-error">
          <CircleAlert size={16} />
          {notice}
        </div>
      )}

      {/* KPI Cards */}
      <div className="finance-summary">
        <article>
          <small>Total Billed</small>
          <b>{money(totalBilled)}</b>
        </article>
        <article>
          <small>Total Collections</small>
          <b style={{ color: "#188038" }}>{money(totalPaid)} ({collectionRate}% efficiency)</b>
        </article>
        <article>
          <small>Outstanding Balance</small>
          <b style={{ color: "#d93025" }}>{money(totalOutstanding)}</b>
        </article>
        <article>
          <small>Verification Queue</small>
          <b>{pendingRequestsCount} requests</b>
        </article>
      </div>

      {/* Sub-navigation tabs */}
      <nav className="finance-tabs" aria-label="Fee workspace sections" style={{ marginBottom: "1rem" }}>
        {(
          [
            ["structures", "Fee structures"],
            ["invoices", `Student Invoices (${state.invoices.length})`],
            ["collections", `Payments (${state.payments.length})`],
            ["requests", `Verification Queue (${pendingRequestsCount})`],
            ["concessions", "Concessions"],
            ["reports", "Gateway Config"],
          ] as const
        ).map(([key, label]) => (
          <button
            key={key}
            className={tab === key ? "active" : ""}
            onClick={() => setTab(key)}
          >
            {label}
          </button>
        ))}
      </nav>

      {/* Tab content */}
      <div className="table-card surface ops-table-surface student-directory-table-wrap">
        {loading ? (
          <div className="skeleton-container" style={{ padding: "1rem" }}>
            <div className="skeleton skeleton-row" />
            <div className="skeleton skeleton-row" />
            <div className="skeleton skeleton-row" />
          </div>
        ) : tab === "structures" ? (
          <FinanceTable
            headers={["Class", "Section", "Category", "Amount", "Frequency", "Due Day", "Fine/Day"]}
            rows={state.structures}
            emptyText="No fee structures configured yet. Click 'New fee structure' to set up pricing."
            renderRow={(r) => (
              <tr key={stringValue(r.id)}>
                <td><b>{rowText(r, "grade_name")}</b></td>
                <td>{stringValue(r.section_name) || "All sections"}</td>
                <td>
                  <span className="status-pill" style={{ background: "#f0f6fc", color: "#0c5496" }}>
                    {stringValue(nested(r, "category").name || r.fee_category_name)}
                  </span>
                </td>
                <td><b>{money(r.amount)}</b></td>
                <td><span className="ops-chip">{stringValue(r.frequency)}</span></td>
                <td>Day {stringValue(r.due_day)}</td>
                <td>{money(r.late_fine_per_day)}</td>
              </tr>
            )}
          />
        ) : tab === "invoices" ? (
          <>
            <div className="student-directory-toolbar">
              <input
                className="search-input"
                placeholder="Search student name or invoice number…"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
              <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} aria-label="Filter status">
                <option value="all">All statuses</option>
                <option value="paid">Paid</option>
                <option value="unpaid">Unpaid</option>
                <option value="partial">Partial</option>
              </select>
              <div className="finance-actions" style={{ marginLeft: "auto", display: "flex", gap: "0.5rem" }}>
                <button className="primary-button" onClick={() => setDialog("payment")}>
                  <Plus size={16} /> Record payment
                </button>
                <button className="secondary-button" onClick={() => setDialog("concession")}>
                  Grant concession
                </button>
              </div>
            </div>

            <FinanceTable
              headers={["Invoice #", "Learner", "Gross", "Concession", "Net Due", "Paid", "Balance", "Status"]}
              rows={filteredInvoices}
              emptyText="No invoices match your search."
              renderRow={(r) => {
                const stName = displayName(nested(r, "student"));
                const status = stringValue(r.status).toLowerCase();

                return (
                  <tr key={stringValue(r.id)}>
                    <td><b>{stringValue(r.invoice_number)}</b></td>
                    <td>
                      <div className="student-cell">
                        <span className="student-avatar" style={{ background: "#e8f4fc", color: "#0d5598" }}>
                          {studentInitials(stName)}
                        </span>
                        <b>{stName}</b>
                      </div>
                    </td>
                    <td>{money(r.gross_amount)}</td>
                    <td>{money(r.concession_amount)}</td>
                    <td><b>{money(r.net_amount)}</b></td>
                    <td>{money(r.total_paid)}</td>
                    <td><b style={{ color: Number(r.balance) > 0 ? "#c0340f" : "#1e8e3e" }}>{money(r.balance)}</b></td>
                    <td>
                      <span className={`student-status ${status === "paid" ? "active" : "inactive"}`}>
                        {stringValue(r.status)}
                      </span>
                    </td>
                  </tr>
                );
              }}
            />
          </>
        ) : tab === "collections" ? (
          <FinanceTable
            headers={["Receipt #", "Learner", "Amount Paid", "Date", "Mode", "Transaction Ref"]}
            rows={state.payments}
            emptyText="No payments recorded."
            renderRow={(r) => {
              const stName = displayName(nested(nested(r, "invoice"), "student"));
              return (
                <tr key={stringValue(r.id)}>
                  <td><b>{stringValue(r.receipt_number)}</b></td>
                  <td>
                    <div className="student-cell">
                      <span className="student-avatar" style={{ background: "#eef8f1", color: "#1c6b32" }}>
                        {studentInitials(stName)}
                      </span>
                      <b>{stName}</b>
                    </div>
                  </td>
                  <td><b style={{ color: "#1e8e3e" }}>{money(r.amount_paid)}</b></td>
                  <td>{stringValue(r.payment_date).slice(0, 10)}</td>
                  <td><span className="status-pill" style={{ background: "#f0f4fb", color: "#0d5291" }}>{stringValue(r.payment_mode)}</span></td>
                  <td>{stringValue(r.transaction_id) || "—"}</td>
                </tr>
              );
            }}
          />
        ) : tab === "requests" ? (
          <div className="request-list" style={{ padding: "1rem" }}>
            {state.requests.length ? (
              state.requests.map((r) => (
                <article key={stringValue(r.id)} style={{ padding: "0.85rem 1rem", background: "#f9fcfd", border: "1px solid #dce8ee", borderRadius: "10px", marginBottom: "0.75rem" }}>
                  <div>
                    <b>{displayName(nested(r, "student"))} · {money(r.amount)}</b>
                    <span style={{ display: "block", color: "#597080", fontSize: "0.78rem", marginTop: "0.2rem" }}>
                      Mode: {stringValue(r.payment_mode)} · Ref: {stringValue(r.transaction_id || "None")} · Submitted: {stringValue(r.created_at).slice(0, 10)}
                    </span>
                  </div>
                  <div style={{ display: "flex", gap: "0.5rem", marginTop: "0.5rem" }}>
                    {stringValue(r.status).toLowerCase() === "pending" ? (
                      <>
                        <button className="primary-button" onClick={() => void decide(r, "approved")}>Approve</button>
                        <button className="secondary-button danger" onClick={() => void decide(r, "rejected")}>Reject</button>
                      </>
                    ) : (
                      <span className={`student-status ${stringValue(r.status).toLowerCase() === "approved" ? "active" : "inactive"}`}>{stringValue(r.status)}</span>
                    )}
                  </div>
                </article>
              ))
            ) : (
              <p className="ops-empty">No pending parent payment verification requests.</p>
            )}
          </div>
        ) : tab === "concessions" ? (
          <FinanceTable
            headers={["Learner", "Reason", "Amount/Discount", "Granted Date"]}
            rows={state.concessions}
            emptyText="No fee concessions granted."
            renderRow={(r) => (
              <tr key={stringValue(r.id)}>
                <td><b>{displayName(nested(nested(r, "invoice"), "student"))}</b></td>
                <td>{stringValue(r.reason)}</td>
                <td><b>{r.amount ? money(r.amount) : `${stringValue(r.percentage)}%`}</b></td>
                <td>{stringValue(r.created_at).slice(0, 10)}</td>
              </tr>
            )}
          />
        ) : tab === "reports" ? (
          <form action={saveConfig} className="finance-report-grid" style={{ padding: "1.2rem" }}>
            <section className="surface ops-form-surface">
              <h3>UPI &amp; Bank Account Settings</h3>
              <p>Parents see these payment details when making online transfers.</p>
              <label className="field">
                UPI VPA / Handle
                <input name="upi_id" defaultValue={stringValue(state.config.upi_id)} placeholder="e.g. arishville@icici" />
              </label>
              <label className="field">
                Account Holder Name
                <input name="account_name" defaultValue={stringValue(state.config.account_name)} />
              </label>
              <label className="field">
                Bank Name
                <input name="bank_name" defaultValue={stringValue(state.config.bank_name)} />
              </label>
              <label className="field">
                Account Number
                <input name="account_number" defaultValue={stringValue(state.config.account_number)} />
              </label>
              <label className="field">
                IFSC Code
                <input name="ifsc_code" defaultValue={stringValue(state.config.ifsc_code)} />
              </label>
              <button className="primary-button" style={{ marginTop: "0.5rem" }}>
                Save bank configuration
              </button>
            </section>
            <section className="finance-report-card surface">
              <FileText size={24} />
              <h3>Ledger Export</h3>
              <p>Download full transaction history, audit trails, and student fee statements in CSV format.</p>
              <div className="ops-stack">
                <button
                  className="secondary-button"
                  type="button"
                  onClick={() => void requestFinanceExport("fee_outstanding_report", "Fee outstanding report")}
                >
                  <Download size={16} /> Export outstanding report
                </button>
                <button
                  className="secondary-button"
                  type="button"
                  onClick={() =>
                    downloadCsv(
                      `fee_receipt_register_${new Date().toISOString().slice(0, 10)}.csv`,
                      state.payments.map((payment) => ({
                        receipt_number: payment.receipt_number,
                        invoice_id: payment.invoice_id,
                        amount_paid: payment.amount_paid,
                        payment_mode: payment.payment_mode,
                        payment_date: payment.payment_date,
                        transaction_id: payment.transaction_id,
                      }))
                    )
                  }
                >
                  <FileText size={16} /> Receipt register CSV
                </button>
              </div>
            </section>
            <section className="finance-report-card surface">
              <ReceiptIndianRupee size={24} />
              <h3>Overdue follow-up</h3>
              <p>{overdueInvoices.length} invoices currently have an outstanding balance and need fee collection follow-up.</p>
              <div className="ops-chip-cloud">
                {overdueInvoices.slice(0, 6).map((invoice) => (
                  <span key={stringValue(invoice.id)} className="ops-chip">
                    {stringValue(invoice.invoice_number)} · {money(invoice.balance)}
                  </span>
                ))}
                {!overdueInvoices.length && <span className="ops-chip success">No overdue invoices</span>}
              </div>
              <button
                className="secondary-button"
                type="button"
                onClick={() =>
                  downloadCsv(
                    `overdue_follow_up_${new Date().toISOString().slice(0, 10)}.csv`,
                    overdueInvoices.map((invoice) => ({
                      invoice_number: invoice.invoice_number,
                      student: displayName(nested(invoice, "student")),
                      balance: invoice.balance,
                      status: invoice.status,
                    }))
                  )
                }
              >
                Export overdue follow-up list
              </button>
            </section>
          </form>
        ) : null}
      </div>

      {dialog === "structure" && (
        <FeeStructureDialog
          refs={state}
          onClose={() => setDialog(false)}
          onSaved={() => {
            onNotify("Fee structure saved & invoices generated.");
            void load();
          }}
        />
      )}

      {dialog === "payment" && (
        <PaymentDialog
          invoices={state.invoices}
          onClose={() => setDialog(false)}
          onSaved={() => {
            onNotify("Payment recorded.");
            void load();
          }}
        />
      )}

      {dialog === "concession" && (
        <ConcessionDialog
          invoices={state.invoices}
          onClose={() => setDialog(false)}
          onSaved={() => {
            onNotify("Concession granted.");
            void load();
          }}
        />
      )}
    </section>
  );
}

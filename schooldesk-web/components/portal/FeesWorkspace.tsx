"use client";

import { useCallback, useEffect, useState } from "react";
import {
  CircleAlert,
  FileText,
  Plus,
  ReceiptIndianRupee,
  RefreshCw,
  WalletCards,
} from "lucide-react";
import type { FeeState, Row } from "./types";
import { api, rowsFrom, rowText, stringValue, money, displayName, nested } from "./utils";
import { FeeStructureDialog } from "./FeeStructureDialog";
import { PaymentDialog } from "./PaymentDialog";
import { ConcessionDialog } from "./ConcessionDialog";

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
    <table className="data-table ops-data-table">
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
  onNotify: (message: string) => void;
}) {
  const [tab, setTab] = useState<
    "structures" | "invoices" | "collections" | "requests" | "concessions" | "reports"
  >("structures");
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState("");
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
        api("fees/structures"),
        api("fees/invoices?page=1&page_size=100"),
        api("fees/payments?page=1&page_size=100"),
        api("fees/payment-requests"),
        api("fees/concessions"),
        api("fees/categories"),
        api("academic-years"),
        api("grades"),
        api("sections?page=1&page_size=100"),
        api("fees/payment-config"),
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
  const pendingRequestsCount = state.requests.filter(
    (r) => stringValue(r.status).toLowerCase() === "pending"
  ).length;

  return (
    <section className="ops-module">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon violet">
            <WalletCards size={20} />
          </div>
          <div>
            <p className="ops-kicker">Principal-only ledger</p>
            <h2>Fee Operations & Accounting</h2>
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
          <b style={{ color: "#188038" }}>{money(totalPaid)}</b>
        </article>
        <article>
          <small>Outstanding Balance</small>
          <b style={{ color: "#d93025" }}>{money(totalOutstanding)}</b>
        </article>
        <article>
          <small>Pending Approval</small>
          <b>{pendingRequestsCount} requests</b>
        </article>
      </div>

      {/* Sub-navigation tabs */}
      <nav className="finance-tabs" aria-label="Fee workspace sections">
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
      <div className="table-card surface ops-table-surface">
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
                <td>{rowText(r, "grade_name")}</td>
                <td>{stringValue(r.section_name) || "All sections"}</td>
                <td>{stringValue(nested(r, "category").name || r.fee_category_name)}</td>
                <td><b>{money(r.amount)}</b></td>
                <td><span className="ops-chip">{stringValue(r.frequency)}</span></td>
                <td>Day {stringValue(r.due_day)}</td>
                <td>{money(r.late_fine_per_day)}</td>
              </tr>
            )}
          />
        ) : tab === "invoices" ? (
          <>
            <div className="finance-actions" style={{ padding: "0.8rem 1rem 0" }}>
              <button className="primary-button" onClick={() => setDialog("payment")}>
                <Plus size={16} /> Record offline payment
              </button>
              <button className="secondary-button" onClick={() => setDialog("concession")}>
                Grant concession
              </button>
            </div>
            <FinanceTable
              headers={["Invoice #", "Student", "Gross", "Concession", "Net Due", "Paid", "Balance", "Status"]}
              rows={state.invoices}
              emptyText="No invoices issued."
              renderRow={(r) => (
                <tr key={stringValue(r.id)}>
                  <td><b>{stringValue(r.invoice_number)}</b></td>
                  <td>{displayName(nested(r, "student"))}</td>
                  <td>{money(r.gross_amount)}</td>
                  <td>{money(r.concession_amount)}</td>
                  <td><b>{money(r.net_amount)}</b></td>
                  <td>{money(r.total_paid)}</td>
                  <td><b style={{ color: Number(r.balance) > 0 ? "#c0340f" : "#1e8e3e" }}>{money(r.balance)}</b></td>
                  <td><span className={`ops-status-tag ${stringValue(r.status).toLowerCase()}`}>{stringValue(r.status)}</span></td>
                </tr>
              )}
            />
          </>
        ) : tab === "collections" ? (
          <FinanceTable
            headers={["Receipt #", "Student", "Amount Paid", "Date", "Mode", "Transaction Ref"]}
            rows={state.payments}
            emptyText="No payments recorded."
            renderRow={(r) => (
              <tr key={stringValue(r.id)}>
                <td><b>{stringValue(r.receipt_number)}</b></td>
                <td>{displayName(nested(nested(r, "invoice"), "student"))}</td>
                <td><b style={{ color: "#1e8e3e" }}>{money(r.amount_paid)}</b></td>
                <td>{stringValue(r.payment_date).slice(0, 10)}</td>
                <td><span className="ops-chip">{stringValue(r.payment_mode)}</span></td>
                <td>{stringValue(r.transaction_id) || "—"}</td>
              </tr>
            )}
          />
        ) : tab === "requests" ? (
          <div className="request-list">
            {state.requests.length ? (
              state.requests.map((r) => (
                <article key={stringValue(r.id)}>
                  <div>
                    <b>{displayName(nested(r, "student"))} · {money(r.amount)}</b>
                    <span>
                      Mode: {stringValue(r.payment_mode)} · Ref: {stringValue(r.transaction_id || "None")} · Submitted: {stringValue(r.created_at).slice(0, 10)}
                    </span>
                  </div>
                  <div>
                    {stringValue(r.status).toLowerCase() === "pending" ? (
                      <>
                        <button className="primary-button" onClick={() => void decide(r, "approved")}>Approve</button>
                        <button className="outline-button" onClick={() => void decide(r, "rejected")}>Reject</button>
                      </>
                    ) : (
                      <span className={`ops-status-tag ${stringValue(r.status).toLowerCase()}`}>{stringValue(r.status)}</span>
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
            headers={["Student", "Reason", "Amount/Discount", "Granted Date"]}
            rows={state.concessions}
            emptyText="No fee concessions granted."
            renderRow={(r) => (
              <tr key={stringValue(r.id)}>
                <td>{displayName(nested(nested(r, "invoice"), "student"))}</td>
                <td>{stringValue(r.reason)}</td>
                <td><b>{r.amount ? money(r.amount) : `${stringValue(r.percentage)}%`}</b></td>
                <td>{stringValue(r.created_at).slice(0, 10)}</td>
              </tr>
            )}
          />
        ) : tab === "reports" ? (
          <form action={saveConfig} className="finance-report-grid" style={{ padding: "1.2rem" }}>
            <section className="surface ops-form-surface">
              <h3>UPI & Bank Account Settings</h3>
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
              <button className="secondary-button" type="button" onClick={() => onNotify("CSV export initiated.")}>
                Export full ledger (CSV)
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

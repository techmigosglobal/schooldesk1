"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  ChevronLeft,
  ChevronRight,
  CircleAlert,
  Download,
  FileText,
  Plus,
  ReceiptIndianRupee,
  RefreshCw,
  Trash2,
  WalletCards,
} from "@/lib/lucide-react";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
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
import { Dialog } from "./Dialog";
import { FeeStructureDialog } from "./FeeStructureDialog";
import { PaymentDialog } from "./PaymentDialog";
import { ConcessionDialog } from "./ConcessionDialog";

function feeLabel(catName: string): "tuition" | "bookskit" | "other" {
  const n = catName.toLowerCase();
  if (n.includes("tuition")) return "tuition";
  if (n.includes("book") || n.includes("kit")) return "bookskit";
  return "other";
}

function studentInitials(name: string) {
  return (
    name
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((p) => p[0])
      .join("")
      .toUpperCase() || "S"
  );
}

function isOperationalInvoice(invoice: Row) {
  const status = stringValue(invoice.status).toLowerCase();
  return status !== "void" && status !== "voided" && status !== "cancelled" && status !== "canceled";
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

function StructuresAccordion({ structures, onNew }: { structures: Row[]; onNew: () => void }) {
  const [expanded, setExpanded] = useState<Set<string>>(new Set());

  // Group by gradeId + sectionId key → parent row
  const groups = useMemo(() => {
    const map = new Map<string, { label: string; section: string; total: number; items: Row[] }>();
    for (const r of structures) {
      const gradeId = stringValue(r.grade_id);
      const sectionId = stringValue(r.section_id ?? "");
      const key = `${gradeId}::${sectionId}`;
      const gradeName = rowText(r, "grade_name");
      const sectionName = stringValue(
        nested(r, "section").section_name ??
        nested(r, "section").name ??
        r.section_name
      );
      // Use "Grade Section" as display label so Nursery A ≠ Nursery B
      const label = sectionName ? `${gradeName} ${sectionName}`.trim() : gradeName || "—";
      const existing = map.get(key);
      if (existing) {
        existing.total += Number(r.amount || 0);
        existing.items.push(r);
      } else {
        map.set(key, { label, section: sectionName, total: Number(r.amount || 0), items: [r] });
      }
    }
    return [...map.entries()].sort(([, a], [, b]) => a.label.localeCompare(b.label));
  }, [structures]);

  if (!structures.length) {
    return (
      <div style={{ padding: "1rem" }}>
        <div style={{ display: "flex", justifyContent: "flex-end", marginBottom: ".75rem" }}>
          <button className="primary-button" onClick={onNew}><Plus size={16} /> New fee structure</button>
        </div>
        <p className="ops-empty">No fee structures configured yet.</p>
      </div>
    );
  }

  return (
    <div style={{ padding: "1rem" }}>
      <div style={{ display: "flex", justifyContent: "flex-end", marginBottom: ".75rem" }}>
        <button className="primary-button" onClick={onNew}><Plus size={16} /> New fee structure</button>
      </div>
      <div className="fee-struct-accordion">
        {groups.map(([key, group]) => {
          const isOpen = expanded.has(key);
          return (
            <div key={key} className={`fee-struct-group${isOpen ? " open" : ""}`}>
              {/* Parent row — summary */}
              <button
                className="fee-struct-parent"
                onClick={() => setExpanded((prev) => {
                  const next = new Set(prev);
                  isOpen ? next.delete(key) : next.add(key);
                  return next;
                })}
              >
                <span className="fee-struct-chevron">
                  {isOpen ? <ChevronRight size={15} style={{ transform: "rotate(90deg)" }} /> : <ChevronRight size={15} />}
                </span>
                <span className="fee-struct-class">
                  <b>{group.label}</b>
                  <span style={{ color: "#9ab3c4" }}>{group.section ? "Section specific" : "All sections"}</span>
                </span>
                <span className="fee-struct-meta">Total Fees</span>
                <span className="fee-struct-amount"><b>{money(group.total)}</b></span>
                <span className="fee-struct-meta">{group.items.length} component{group.items.length !== 1 ? "s" : ""}</span>
              </button>

              {/* Child rows — one per category */}
              {isOpen && (
                <div className="fee-struct-children">
                  {group.items.map((r) => {
                    const catName = stringValue((nested(r, "category") as { name?: unknown }).name ?? r.fee_category_name ?? r.category_name);
                    const freq = stringValue(r.frequency);
                    return (
                      <div key={stringValue(r.id)} className="fee-struct-child">
                        <span className="fee-struct-child-dot" />
                        <span className="fee-struct-child-cat">
                          <span className="status-pill" style={{ background: "#f0f6fc", color: "#0c5496", fontSize: ".75rem" }}>
                            {catName || "—"}
                          </span>
                        </span>
                        <span className="fee-struct-child-amount">{money(r.amount)}</span>
                        <span className="fee-struct-child-freq">
                          <span className="ops-chip" style={{ fontSize: ".73rem" }}>{freq}</span>
                        </span>
                        <span className="fee-struct-child-meta" style={{ color: "#8fa5b3", fontSize: ".76rem" }}>
                          Due day {stringValue(r.due_day)}
                        </span>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function printReceipt(r: Row, stName: string) {
  const receipts = Array.isArray(r.fee_receipts) ? r.fee_receipts as Row[] : [];
  const receipt = receipts[0] ?? {};
  const receiptNum = stringValue(receipt.receipt_number ?? r.receipt_number);
  const amount = Number(r.amount ?? 0);
  const payDate = stringValue(r.paid_at ?? r.created_at).slice(0, 10);
  const payMode = stringValue(r.payment_method ?? "—");
  const txnRef = stringValue(r.reference_number ?? receipt.transaction_ref ?? "");
  const invoiceNum = stringValue((r.invoice as Row | null)?.invoice_number ?? r.invoice_id);
  const issuedAt = stringValue(receipt.issued_at ?? r.paid_at ?? r.created_at).slice(0, 10);

  const html = `<!DOCTYPE html><html><head><meta charset="UTF-8">
<title>Receipt ${receiptNum}</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: Arial, sans-serif; font-size: 13px; color: #1a2e3b; padding: 32px; max-width: 480px; margin: 0 auto; }
  .logo-row { display: flex; align-items: center; gap: 12px; margin-bottom: 20px; border-bottom: 2px solid #0d5598; padding-bottom: 16px; }
  .school-name { font-size: 17px; font-weight: 800; color: #0d5598; line-height: 1.2; }
  .school-sub { font-size: 11px; color: #5f8ea8; margin-top: 2px; }
  .receipt-title { text-align: center; margin: 16px 0 20px; }
  .receipt-title h2 { font-size: 18px; font-weight: 700; color: #1a2e3b; letter-spacing: 1px; text-transform: uppercase; }
  .receipt-title .badge { display: inline-block; background: #e8f4fc; color: #0d5598; font-size: 11px; font-weight: 700; padding: 3px 10px; border-radius: 20px; margin-top: 4px; }
  .row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #edf2f6; }
  .row:last-child { border-bottom: none; }
  .label { color: #627988; font-size: 12px; }
  .value { font-weight: 600; font-size: 12px; }
  .amount-row { background: #f0f7ff; border-radius: 8px; padding: 12px 16px; margin: 16px 0; display: flex; justify-content: space-between; align-items: center; }
  .amount-row .label { font-size: 13px; font-weight: 600; color: #1a3d52; }
  .amount-row .value { font-size: 22px; font-weight: 800; color: #0d5598; }
  .footer { margin-top: 24px; text-align: center; font-size: 11px; color: #9bb0bc; border-top: 1px dashed #dde8ef; padding-top: 12px; }
  .seal { text-align: right; margin-top: 32px; font-size: 11px; color: #9bb0bc; }
  @media print { body { padding: 16px; } }
</style>
</head><body>
<div class="logo-row">
  <div>
    <div class="school-name">Arish Ville Preschool</div>
    <div class="school-sub">Fee Payment Receipt</div>
  </div>
</div>
<div class="receipt-title">
  <h2>Payment Receipt</h2>
  <span class="badge">${receiptNum || "RECEIPT"}</span>
</div>
<div class="row"><span class="label">Student Name</span><span class="value">${stName}</span></div>
${invoiceNum ? `<div class="row"><span class="label">Invoice No.</span><span class="value">${invoiceNum}</span></div>` : ""}
<div class="row"><span class="label">Payment Date</span><span class="value">${payDate || "—"}</span></div>
<div class="row"><span class="label">Payment Mode</span><span class="value">${payMode}</span></div>
${txnRef ? `<div class="row"><span class="label">Transaction Ref</span><span class="value">${txnRef}</span></div>` : ""}
${issuedAt && issuedAt !== payDate ? `<div class="row"><span class="label">Receipt Issued</span><span class="value">${issuedAt}</span></div>` : ""}
<div class="amount-row">
  <span class="label">Amount Paid</span>
  <span class="value">₹${amount.toLocaleString("en-IN")}</span>
</div>
<div class="footer">This is a computer-generated receipt and does not require a signature.<br>Arish Ville Preschool · SchoolDesk</div>
<div class="seal">Authorised Signatory _______________</div>
</body></html>`;

  const win = window.open("", "_blank", "width=520,height=700");
  if (!win) return;
  win.document.write(html);
  win.document.close();
  win.focus();
  setTimeout(() => { win.print(); }, 400);
}

type SecondaryTab = "structures" | "collections" | "requests" | "concessions" | "reports";

export function FeesWorkspace({
  onNotify,
}: {
  onNotify: (message: string, type?: "success" | "error" | "info") => void;
}) {
  // "main" = 3-step fee workflow; secondary tabs are utility views
  const [view, setView] = useState<"main" | SecondaryTab>("main");
  const [loading, setLoading] = useState(true);
  const [busyAction, setBusyAction] = useState("");
  const [notice, setNotice] = useState("");

  // 3-step navigation state
  const [selectedSectionId, setSelectedSectionId] = useState<string | null>(null);
  const [selectedStudentId, setSelectedStudentId] = useState<string | null>(null);

  // Search (used in step 2)
  const [search, setSearch] = useState("");

  // selected invoice inside step 3 (derived from selectedStudentId — user picks which invoice if many)
  const [selectedInvoiceId, setSelectedInvoiceId] = useState<string | null>(null);

  // Dialog state — payment/concession opened from step 3; structure from secondary tab
  const [dialog, setDialog] = useState<"structure" | "payment" | "concession" | false>(false);
  const [deletingPaymentId, setDeletingPaymentId] = useState<string | null>(null);
  const [confirmDeletePaymentId, setConfirmDeletePaymentId] = useState<string | null>(null);

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
  // Full student list — used to join invoice.student_id → current_section_id
  const [students, setStudents] = useState<Row[]>([]);

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
        allStudents,
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
        api("students?page=1&page_size=500").catch(() => []),
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
      setStudents(rowsFrom(allStudents));
      setNotice("");
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to load finance data");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  // ── Computed maps ──────────────────────────────────────────────────────────

  // Cancelled/void invoices remain in the backend for audit history, but must
  // not contribute to active fee totals or payment selection.
  const operationalInvoices = useMemo(
    () => state.invoices.filter(isOperationalInvoice),
    [state.invoices],
  );

  // Per-invoice fee breakdown derived from fee_invoice_items (returned by the invoices API)
  const invoiceBreakdownMap = useMemo(() => {
    const result = new Map<string, { tuition: number; bookskit: number; other: number; total: number }>();
    for (const inv of operationalInvoices) {
      const id = stringValue(inv.id);
      const breakdown = { tuition: 0, bookskit: 0, other: 0, total: 0 };
      const items = Array.isArray(inv.fee_invoice_items) ? inv.fee_invoice_items as Row[] : [];
      for (const item of items) {
        const catName = stringValue(item.category_name ?? item.fee_item_name ?? "");
        const amt = Number(item.amount || 0);
        breakdown[feeLabel(catName)] += amt;
        breakdown.total += amt;
      }
      // fall back to invoice-level amounts if items are missing
      if (breakdown.total === 0) {
        breakdown.total = Number(inv.total_amount || inv.net_amount || 0);
      }
      result.set(id, breakdown);
    }
    return result;
  }, [operationalInvoices]);

  // Per-student aggregated breakdown (sum all invoices for a student)
  const studentBreakdownMap = useMemo(() => {
    const result = new Map<string, { tuition: number; bookskit: number; other: number; total: number }>();
    for (const inv of operationalInvoices) {
      const stId = stringValue(inv.student_id ?? (nested(inv, "student") as { id?: unknown }).id);
      if (!stId) continue;
      const bd = invoiceBreakdownMap.get(stringValue(inv.id)) ?? { tuition: 0, bookskit: 0, other: 0, total: 0 };
      const cur = result.get(stId) ?? { tuition: 0, bookskit: 0, other: 0, total: 0 };
      result.set(stId, {
        tuition: cur.tuition + bd.tuition,
        bookskit: cur.bookskit + bd.bookskit,
        other: cur.other + bd.other,
        total: cur.total + bd.total,
      });
    }
    return result;
  }, [operationalInvoices, invoiceBreakdownMap]);

  // student_id → current_section_id, built from the full students list
  const studentSectionMap = useMemo(() => {
    const map = new Map<string, string>();
    for (const st of students) {
      const stId = stringValue(st.id);
      // current_section_id is a flat scalar on the student record
      const secId = stringValue(
        (st as { current_section_id?: unknown }).current_section_id
      );
      if (stId && secId) map.set(stId, secId);
    }
    return map;
  }, [students]);

  // Count unique students per section for class card badges
  const sectionStudentCount = useMemo(() => {
    const map = new Map<string, Set<string>>();
    for (const inv of operationalInvoices) {
      const stId = stringValue(inv.student_id ?? (nested(inv, "student") as { id?: unknown }).id);
      const sid = studentSectionMap.get(stId) ?? "";
      if (!sid || !stId) continue;
      if (!map.has(sid)) map.set(sid, new Set());
      map.get(sid)!.add(stId);
    }
    const counts = new Map<string, number>();
    for (const [sid, set] of map) counts.set(sid, set.size);
    return counts;
  }, [operationalInvoices, studentSectionMap]);

  // Deduplicated student list for step 2 — one entry per student_id in the selected section
  const classStudents = useMemo(() => {
    if (!selectedSectionId) return [] as Array<{ studentId: string; name: string }>;
    const query = search.trim().toLowerCase();
    const seen = new Set<string>();
    const result: Array<{ studentId: string; name: string }> = [];
    for (const inv of operationalInvoices) {
      const stId = stringValue(inv.student_id ?? (nested(inv, "student") as { id?: unknown }).id);
      const sid = studentSectionMap.get(stId) ?? "";
      if (sid !== selectedSectionId || !stId || seen.has(stId)) continue;
      seen.add(stId);
      const stName = displayName(nested(inv, "student"));
      if (!query || stName.toLowerCase().includes(query)) {
        result.push({ studentId: stId, name: stName });
      }
    }
    return result.sort((a, b) => a.name.localeCompare(b.name));
  }, [operationalInvoices, selectedSectionId, search, studentSectionMap]);

  // ── KPI totals ──────────────────────────────────────────────────────────────

  const totalBilled = operationalInvoices.reduce((s, r) => s + Number(r.net_amount || r.total_amount || 0), 0);
  const totalPaid = state.payments.reduce((s, r) => s + Number(r.amount_paid ?? r.amount ?? 0), 0);
  const totalOutstanding = operationalInvoices.reduce((s, r) => s + Number(r.balance || 0), 0);
  const collectionRate = totalBilled > 0 ? Math.min(100, Math.round((totalPaid / totalBilled) * 100)) : 0;
  const pendingRequestsCount = state.requests.filter(
    (r) => stringValue(r.status).toLowerCase() === "pending"
  ).length;
  const overdueInvoices = operationalInvoices.filter(
    (r) => Number(r.balance || 0) > 0 && stringValue(r.status).toLowerCase() !== "paid"
  );

  // ── Actions ────────────────────────────────────────────────────────────────

  async function requestFinanceExport(reportType: string, title: string) {
    setBusyAction(`export:${reportType}`);
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
    } finally {
      setBusyAction("");
    }
  }

  async function applyFines() {
    setBusyAction("fines");
    try {
      const res = (await api("fees/invoices/late-fines/apply", { method: "POST" })) as Row;
      onNotify(`Late fines applied. Updated ${stringValue(res.updated || 0)} invoices.`);
      void load();
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to apply late fines");
    } finally {
      setBusyAction("");
    }
  }

  async function decide(req: Row, status: "approved" | "rejected") {
    setBusyAction(`decision:${req.id}:${status}`);
    try {
      await api(`fees/payment-requests/${req.id}/decision`, {
        method: "PUT",
        body: JSON.stringify({ status }),
      });
      onNotify(`Payment request ${status}.`);
      void load();
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Decision failed");
    } finally {
      setBusyAction("");
    }
  }

  async function saveConfig(form: FormData) {
    setBusyAction("config");
    try {
      await api("fees/payment-config", {
        method: "PUT",
        body: JSON.stringify(Object.fromEntries(form)),
      });
      onNotify("Bank and UPI gateway settings saved.");
      void load();
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Save failed");
    } finally {
      setBusyAction("");
    }
  }

  async function deletePayment(paymentId: string) {
    setConfirmDeletePaymentId(null);
    setDeletingPaymentId(paymentId);
    try {
      await api(`fees/payments/${paymentId}`, { method: "DELETE" });
      // Silent refresh — re-fetch only invoices so navigation state is preserved
      const fresh = await api("fees/invoices?page=1&page_size=100").catch(() => null);
      if (fresh) setState((prev) => ({ ...prev, invoices: rowsFrom(fresh) }));
      onNotify("Payment deleted. Invoice totals updated.");
    } catch (event) {
      onNotify(event instanceof Error ? event.message : "Unable to delete payment");
    } finally {
      setDeletingPaymentId(null);
    }
  }

  // Navigate back to class grid and reset step state
  function goToClasses() {
    setSelectedSectionId(null);
    setSelectedStudentId(null);
    setSelectedInvoiceId(null);
    setSearch("");
  }

  function goToStudentList() {
    setSelectedStudentId(null);
    setSelectedInvoiceId(null);
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  const activeSection = selectedSectionId
    ? state.sections.find((s) => stringValue(s.id) === selectedSectionId) ?? null
    : null;

  // All invoices for the selected student
  const studentInvoices = useMemo(() => {
    if (!selectedStudentId) return [] as Row[];
    return operationalInvoices.filter(
      (inv) => stringValue(inv.student_id ?? (nested(inv, "student") as { id?: unknown }).id) === selectedStudentId
    );
  }, [operationalInvoices, selectedStudentId]);

  // Active invoice in step 3 — auto-select first if only one, otherwise use selectedInvoiceId
  const activeInvoice = useMemo(() => {
    if (!selectedStudentId) return null;
    if (selectedInvoiceId) return studentInvoices.find((i) => stringValue(i.id) === selectedInvoiceId) ?? null;
    return studentInvoices[0] ?? null;
  }, [studentInvoices, selectedStudentId, selectedInvoiceId]);

  // Student name for step 3 header (from any of their invoices)
  const activeStudentName = useMemo(() => {
    const inv = studentInvoices[0];
    return inv ? displayName(nested(inv, "student")) : "";
  }, [studentInvoices]);

  return (
    <section className="ops-module fees-workspace">
      {/* ── Module heading ── */}
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon gold" style={{ background: "#fff4d7", color: "#9a6b00" }}>
            <WalletCards size={20} />
          </div>
          <div>
            <p className="ops-kicker">Principal ledger</p>
            <h2>Fee Operations &amp; Accounting</h2>
            <p>Select a class to view and manage student fees, record payments, and apply concessions.</p>
          </div>
        </div>
        <div className="ops-actions">
          <button className="secondary-button" onClick={() => void load()} disabled={loading}>
            <RefreshCw size={16} className={loading ? "spin" : ""} /> Refresh
          </button>
          <button
            className="secondary-button"
            onClick={() => void applyFines()}
            disabled={Boolean(busyAction)}
            aria-busy={busyAction === "fines"}
          >
            {busyAction === "fines"
              ? <LoadingIndicator label="Applying fines…" compact announce={false} />
              : <><ReceiptIndianRupee size={16} /> Apply late fines</>}
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

      {loading ? (
        <PortalModuleSkeleton variant="finance" label="Loading fee operations and accounting" />
      ) : (
        <>
          {/* ── KPI summary ── */}
          <div className="finance-summary">
            <article>
              <small>Total Billed</small>
              <b>{money(totalBilled)}</b>
            </article>
            <article>
              <small>Total Collections</small>
              <b style={{ color: "#188038" }}>{money(totalPaid)} <span style={{ fontSize: ".8rem", fontWeight: 600 }}>({collectionRate}%)</span></b>
            </article>
            <article>
              <small>Outstanding Balance</small>
              <b style={{ color: "#d93025" }}>{money(totalOutstanding)}</b>
            </article>
            <article>
              <small>Pending Verifications</small>
              <b>{pendingRequestsCount} requests</b>
            </article>
          </div>

          {/* ── Tab bar ── */}
          <nav className="finance-tabs" aria-label="Fee workspace sections" style={{ marginBottom: "1.25rem" }}>
            {(
              [
                ["main", "Student Fees"],
                ["structures", "Fee Structures"],
                ["collections", `Payments (${state.payments.length})`],
                ["requests", `Verification Queue${pendingRequestsCount > 0 ? ` (${pendingRequestsCount})` : ""}`],
                ["concessions", "Concessions"],
                ["reports", "Gateway Config"],
              ] as const
            ).map(([key, label]) => (
              <button
                key={key}
                className={view === key ? "active" : ""}
                onClick={() => {
                  setView(key);
                  if (key === "main") goToClasses();
                }}
              >
                {label}
              </button>
            ))}
          </nav>

          {/* ═══════════════════════════════════════════════════════════════
              MAIN VIEW — 3-step student fee workflow
          ════════════════════════════════════════════════════════════════ */}
          {view === "main" && (
            <div className="fees-main-view">

              {/* Step 1 — Class selection grid */}
              {!selectedSectionId && !selectedStudentId && (
                <>
                  <p className="fees-step-label">Step 1 — Select a class</p>
                  {state.sections.length === 0 ? (
                    <p className="ops-empty">No classes found. Set up classes first under Classes &amp; Subjects.</p>
                  ) : (
                    <div className="fee-class-grid">
                      {state.sections.map((sec) => {
                        const sid = stringValue(sec.id);
                        const gradeName = rowText(sec, "grade_name");
                        const sectionName = stringValue(sec.section_name ?? sec.name);
                        const initials = `${gradeName.slice(0, 1)}${sectionName.slice(0, 1)}`.toUpperCase() || "C";
                        const count = sectionStudentCount.get(sid) ?? 0;
                        return (
                          <button
                            key={sid}
                            className="fee-class-card"
                            onClick={() => { setSelectedSectionId(sid); setSearch(""); }}
                          >
                            <span className="fee-class-badge">{initials}</span>
                            <b className="fee-class-name">{gradeName}</b>
                            <span className="fee-class-section">{sectionName}</span>
                            <span className="fee-class-count">{count} student{count !== 1 ? "s" : ""}</span>
                          </button>
                        );
                      })}
                    </div>
                  )}
                </>
              )}

              {/* Step 2 — Student list for selected class */}
              {selectedSectionId && !selectedStudentId && (
                <>
                  <div className="fees-step-header">
                    <button className="fees-back-btn" onClick={goToClasses}>
                      <ChevronLeft size={15} /> All Classes
                    </button>
                    <p className="fees-step-label" style={{ margin: 0 }}>
                      Step 2 — Select a student
                      {activeSection && (
                        <span className="fees-step-context">
                          {rowText(activeSection, "grade_name")} {stringValue(activeSection.section_name ?? activeSection.name)}
                        </span>
                      )}
                    </p>
                  </div>

                  <div className="student-directory-toolbar" style={{ marginBottom: ".75rem" }}>
                    <input
                      className="search-input"
                      placeholder="Search by student name…"
                      value={search}
                      onChange={(e) => setSearch(e.target.value)}
                    />
                  </div>

                  {classStudents.length === 0 ? (
                    <p className="ops-empty">No students found in this class{search ? " matching your search" : ""}.</p>
                  ) : (
                    <div className="fee-student-list">
                      {classStudents.map(({ studentId, name }) => (
                        <button
                          key={studentId}
                          className="fee-student-row"
                          onClick={() => { setSelectedStudentId(studentId); setSelectedInvoiceId(null); }}
                        >
                          <span
                            className="student-avatar"
                            style={{ background: "#e8f4fc", color: "#0d5598", borderRadius: 10, width: 38, height: 38, display: "grid", placeItems: "center", fontWeight: 800, fontSize: ".85rem", flexShrink: 0 }}
                          >
                            {studentInitials(name)}
                          </span>
                          <span className="fee-student-row-name">
                            <b>{name}</b>
                            {activeSection && (
                              <span style={{ color: "#8fa5b3", fontSize: ".78rem" }}>
                                {rowText(activeSection, "grade_name")} {stringValue(activeSection.section_name ?? activeSection.name)}
                              </span>
                            )}
                          </span>
                        </button>
                      ))}
                    </div>
                  )}
                </>
              )}

              {/* Step 3 — Student fee overview + actions */}
              {selectedStudentId && (() => {
                if (!activeInvoice) return (
                  <div>
                    <button className="fees-back-btn" onClick={goToStudentList}>
                      <ChevronLeft size={15} /> Back
                    </button>
                    <p className="ops-empty">No invoices found for this student.</p>
                  </div>
                );

                const bd = studentBreakdownMap.get(selectedStudentId) ?? { tuition: 0, bookskit: 0, other: 0, total: 0 };
                const classLabel = activeSection
                  ? `${rowText(activeSection, "grade_name")} ${stringValue(activeSection.section_name ?? activeSection.name)}`.trim()
                  : "";

                // Aggregate across all invoices for this student
                const totalNetDue = studentInvoices.reduce((s, i) => s + Number(i.net_amount || i.total_amount || 0), 0);
                const totalAmountPaid = studentInvoices.reduce((s, i) => s + Number(i.paid_amount || i.total_paid || 0), 0);
                const totalBalance = studentInvoices.reduce((s, i) => s + Number(i.balance || 0), 0);
                const totalConcession = studentInvoices.reduce((s, i) => s + Number(i.concession_amount || i.discount_amount || 0), 0);
                const overallStatus = totalBalance <= 0 ? "paid" : totalAmountPaid > 0 ? "partial" : "pending";
                const isPaid = overallStatus === "paid";

                return (
                  <div className="fees-detail-view">
                    <div className="fees-step-header">
                      <button className="fees-back-btn" onClick={goToStudentList}>
                        <ChevronLeft size={15} /> {classLabel || "Class"}
                      </button>
                      <p className="fees-step-label" style={{ margin: 0 }}>
                        Step 3 — Fee overview
                        <span className="fees-step-context">{activeStudentName}</span>
                      </p>
                    </div>

                    <div className="fees-detail-layout">
                      {/* Student identity card */}
                      <div className="fees-student-identity surface">
                        <span
                          className="student-avatar"
                          style={{ background: "#e8f4fc", color: "#0d5598", borderRadius: 14, width: 56, height: 56, display: "grid", placeItems: "center", fontWeight: 900, fontSize: "1.3rem", margin: "0 auto .75rem" }}
                        >
                          {studentInitials(activeStudentName)}
                        </span>
                        <b className="fees-student-fullname">{activeStudentName}</b>
                        {classLabel && <p className="fees-student-meta">{classLabel}</p>}
                        <span className={`student-status ${isPaid ? "active" : "inactive"}`} style={{ margin: ".5rem auto 0", display: "table" }}>
                          {overallStatus}
                        </span>
                      </div>

                      {/* Fee breakdown */}
                      <div className="fees-breakdown-card surface">
                        <p className="fees-breakdown-heading">Fee Breakdown</p>
                        <table className="fee-breakdown-table">
                          <tbody>
                            <tr className="fee-row-total">
                              <td>Total Fees</td>
                              <td>{money(bd.total || totalNetDue)}</td>
                            </tr>
                            {bd.tuition > 0 && (
                              <tr className="fee-row-sub">
                                <td><span className="fee-dot fee-dot-tuition" />Tuition Fee</td>
                                <td>{money(bd.tuition)}</td>
                              </tr>
                            )}
                            {bd.bookskit > 0 && (
                              <tr className="fee-row-sub">
                                <td><span className="fee-dot fee-dot-bookskit" />Books &amp; Kit Fee</td>
                                <td>{money(bd.bookskit)}</td>
                              </tr>
                            )}
                            {bd.other > 0 && (
                              <tr className="fee-row-sub">
                                <td><span className="fee-dot fee-dot-other" />Other Fees</td>
                                <td>{money(bd.other)}</td>
                              </tr>
                            )}
                            {totalConcession > 0 && (
                              <tr className="fee-row-concession">
                                <td>Concession Applied</td>
                                <td style={{ color: "#1e8e3e" }}>− {money(totalConcession)}</td>
                              </tr>
                            )}
                            <tr className="fee-row-divider">
                              <td>Net Due</td>
                              <td><b>{money(totalNetDue)}</b></td>
                            </tr>
                            <tr>
                              <td>Amount Paid</td>
                              <td style={{ color: "#1e8e3e" }}>{money(totalAmountPaid)}</td>
                            </tr>
                            <tr className={totalBalance > 0 ? "fee-row-balance-due" : "fee-row-balance-clear"}>
                              <td><b>Balance Remaining</b></td>
                              <td><b>{money(totalBalance)}</b></td>
                            </tr>
                          </tbody>
                        </table>

                        {/* Invoice selector if student has multiple invoices */}
                        {studentInvoices.length > 1 && (
                          <div style={{ marginTop: "1rem", borderTop: "1px solid #e3ecf2", paddingTop: ".75rem" }}>
                            <p style={{ fontSize: ".78rem", color: "#627988", marginBottom: ".4rem", fontWeight: 600 }}>
                              {studentInvoices.length} invoices — select for actions:
                            </p>
                            {studentInvoices.map((inv) => {
                              const invId = stringValue(inv.id);
                              const isActive = (selectedInvoiceId ?? stringValue(studentInvoices[0].id)) === invId;
                              return (
                                <button
                                  key={invId}
                                  onClick={() => setSelectedInvoiceId(invId)}
                                  style={{ display: "flex", justifyContent: "space-between", width: "100%", padding: ".4rem .6rem", borderRadius: 7, marginBottom: ".3rem", border: isActive ? "1.5px solid #0d5598" : "1.5px solid #dde8ef", background: isActive ? "#f0f7ff" : "transparent", cursor: "pointer", fontSize: ".82rem" }}
                                >
                                  <span>{stringValue(inv.invoice_number) || invId.slice(0, 12)}</span>
                                  <span style={{ color: Number(inv.balance) > 0 ? "#c0340f" : "#1e8e3e" }}>{money(inv.balance)}</span>
                                </button>
                              );
                            })}
                          </div>
                        )}

                        {/* Payment history — list each recorded payment with delete */}
                        {(() => {
                          const allPayments = studentInvoices.flatMap((inv) =>
                            Array.isArray(inv.payments) ? (inv.payments as Row[]) : []
                          );
                          if (allPayments.length === 0) return null;
                          return (
                            <div style={{ marginTop: "1rem", borderTop: "1px solid #e3ecf2", paddingTop: ".75rem" }}>
                              <p style={{ fontSize: ".78rem", color: "#627988", marginBottom: ".5rem", fontWeight: 600, textTransform: "uppercase", letterSpacing: ".04em" }}>
                                Payment history
                              </p>
                              {allPayments.map((pmt) => {
                                const pmtId = stringValue(pmt.id);
                                const receipt = nested(pmt, "fee_receipts") as Row | null;
                                const receiptNo = stringValue((Array.isArray(pmt.fee_receipts) ? (pmt.fee_receipts as Row[])[0]?.receipt_number : receipt?.receipt_number) ?? pmt.receipt_number ?? "");
                                const pmtDate = stringValue(pmt.paid_at ?? pmt.payment_date ?? pmt.created_at).slice(0, 10);
                                const pmtMethod = stringValue(pmt.payment_method ?? "—");
                                const isDeleting = deletingPaymentId === pmtId;
                                return (
                                  <div
                                    key={pmtId}
                                    style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: ".35rem .5rem", borderRadius: 7, marginBottom: ".25rem", background: "#f7fafb", border: "1px solid #e3ecf2" }}
                                  >
                                    <div style={{ fontSize: ".78rem" }}>
                                      <span style={{ fontWeight: 700, color: "#1e8e3e" }}>{money(pmt.amount)}</span>
                                      <span style={{ color: "#627988", marginLeft: ".4rem" }}>{pmtMethod}</span>
                                      {pmtDate && <span style={{ color: "#95a5b2", marginLeft: ".4rem" }}>{pmtDate}</span>}
                                      {receiptNo && <span style={{ color: "#adb8c0", marginLeft: ".4rem", fontSize: ".72rem" }}>{receiptNo}</span>}
                                    </div>
                                    <button
                                      title="Delete this payment"
                                      disabled={isDeleting}
                                      onClick={() => setConfirmDeletePaymentId(pmtId)}
                                      style={{ background: "none", border: "none", cursor: isDeleting ? "wait" : "pointer", color: isDeleting ? "#bbb" : "#c0340f", padding: ".2rem .3rem", borderRadius: 5, display: "flex", alignItems: "center" }}
                                    >
                                      {isDeleting ? <LoadingIndicator compact announce={false} label="" /> : <Trash2 size={14} />}
                                    </button>
                                  </div>
                                );
                              })}
                            </div>
                          );
                        })()}
                      </div>

                      {/* Actions panel */}
                      <div className="fees-actions-panel surface">
                        <p className="fees-breakdown-heading">Actions</p>
                        <div className="fees-action-list">
                          {totalBalance > 0 && (
                            <button className="fees-action-btn fees-action-primary" onClick={() => setDialog("payment")}>
                              <ReceiptIndianRupee size={18} />
                              <span>
                                <b>Record Payment</b>
                                <small>Mark fee collected from student</small>
                              </span>
                            </button>
                          )}
                          <button className="fees-action-btn fees-action-secondary" onClick={() => setDialog("concession")}>
                            <FileText size={18} />
                            <span>
                              <b>Grant Concession</b>
                              <small>Apply discount or waiver on fees</small>
                            </span>
                          </button>
                          <button
                            className="fees-action-btn fees-action-secondary"
                            onClick={() => {
                              const allPmts = studentInvoices.flatMap((inv) =>
                                Array.isArray(inv.payments) ? (inv.payments as Row[]) : []
                              );
                              const today = new Date().toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
                              const fmtMoney = (v: unknown) => `₹${Number(v || 0).toLocaleString("en-IN")}`;
                              const invoiceRows = studentInvoices.map((inv) => `
                                <tr>
                                  <td>${stringValue(inv.invoice_number) || stringValue(inv.id).slice(0, 16)}</td>
                                  <td style="text-align:right">${fmtMoney(inv.net_amount ?? inv.total_amount)}</td>
                                  <td style="text-align:right;color:#1e8e3e">${fmtMoney(inv.paid_amount ?? inv.total_paid ?? 0)}</td>
                                  <td style="text-align:right;color:${Number(inv.balance ?? 0) > 0 ? "#c0340f" : "#1e8e3e"}">${fmtMoney(inv.balance ?? 0)}</td>
                                  <td style="text-align:center"><span style="padding:2px 8px;border-radius:99px;background:${inv.status === "paid" ? "#eef8f1" : inv.status === "partial" ? "#fff8e1" : "#fef3f2"};color:${inv.status === "paid" ? "#1e8e3e" : inv.status === "partial" ? "#8a5c00" : "#c0340f"};font-size:11px;font-weight:600">${stringValue(inv.status).toUpperCase()}</span></td>
                                </tr>`).join("");
                              const paymentRows = allPmts.length ? allPmts.map((p) => {
                                const receiptArr = Array.isArray(p.fee_receipts) ? (p.fee_receipts as Row[]) : [];
                                const rcpt = stringValue(receiptArr[0]?.receipt_number ?? p.receipt_number ?? "");
                                return `<tr>
                                  <td>${rcpt || "—"}</td>
                                  <td>${stringValue(p.paid_at ?? p.payment_date ?? "").slice(0, 10)}</td>
                                  <td>${stringValue(p.payment_method ?? "—").toUpperCase()}</td>
                                  <td style="text-align:right;font-weight:700;color:#1e8e3e">${fmtMoney(p.amount)}</td>
                                </tr>`;
                              }).join("") : `<tr><td colspan="4" style="color:#95a5b2;text-align:center">No payments recorded</td></tr>`;
                              const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>Fee Invoice — ${activeStudentName}</title>
                              <style>
                                *{box-sizing:border-box;margin:0;padding:0}
                                body{font-family:system-ui,sans-serif;font-size:13px;color:#1a2533;padding:32px;max-width:760px;margin:0 auto}
                                h1{font-size:22px;font-weight:800;color:#0d5598;margin-bottom:2px}
                                .meta{color:#637887;font-size:12px;margin-bottom:24px}
                                .section{margin-bottom:24px}
                                .section-title{font-size:11px;font-weight:700;color:#637887;text-transform:uppercase;letter-spacing:.06em;margin-bottom:8px;padding-bottom:4px;border-bottom:1px solid #e3ecf2}
                                table{width:100%;border-collapse:collapse}
                                th{text-align:left;font-size:11px;font-weight:700;color:#637887;text-transform:uppercase;letter-spacing:.05em;padding:6px 8px;background:#f7fafb;border-bottom:1px solid #e3ecf2}
                                td{padding:7px 8px;border-bottom:1px solid #f0f4f8;font-size:13px}
                                .summary{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-bottom:24px}
                                .kpi{background:#f7fafb;border:1px solid #e3ecf2;border-radius:8px;padding:12px 16px}
                                .kpi small{font-size:11px;color:#637887;display:block;margin-bottom:4px}
                                .kpi b{font-size:18px;color:#1a2533}
                                .student-card{background:#eef5fc;border-radius:10px;padding:14px 18px;margin-bottom:24px}
                                .student-card b{font-size:16px;color:#0d5598;display:block}
                                .student-card span{font-size:12px;color:#637887}
                                @media print{body{padding:16px}button{display:none}}
                              </style></head><body>
                              <h1>Fee Invoice</h1>
                              <p class="meta">Generated on ${today} &nbsp;·&nbsp; SchoolDesk</p>
                              <div class="student-card">
                                <b>${activeStudentName}</b>
                                <span>${classLabel || "—"}</span>
                              </div>
                              <div class="summary">
                                <div class="kpi"><small>Total Fees</small><b>${fmtMoney(totalNetDue)}</b></div>
                                <div class="kpi"><small>Amount Paid</small><b style="color:#1e8e3e">${fmtMoney(totalAmountPaid)}</b></div>
                                <div class="kpi"><small>Balance</small><b style="color:${totalBalance > 0 ? "#c0340f" : "#1e8e3e"}">${fmtMoney(totalBalance)}</b></div>
                              </div>
                              <div class="section">
                                <p class="section-title">Invoices</p>
                                <table><thead><tr><th>Invoice No.</th><th style="text-align:right">Net Due</th><th style="text-align:right">Paid</th><th style="text-align:right">Balance</th><th style="text-align:center">Status</th></tr></thead>
                                <tbody>${invoiceRows}</tbody></table>
                              </div>
                              <div class="section">
                                <p class="section-title">Payment History</p>
                                <table><thead><tr><th>Receipt No.</th><th>Date</th><th>Method</th><th style="text-align:right">Amount</th></tr></thead>
                                <tbody>${paymentRows}</tbody></table>
                              </div>
                              <script>window.onload=()=>{window.print()}</script>
                              </body></html>`;
                              const w = window.open("", "_blank");
                              if (w) { w.document.write(html); w.document.close(); }
                            }}
                          >
                            <Download size={18} />
                            <span>
                              <b>Download Invoice</b>
                              <small>Print or save as PDF</small>
                            </span>
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })()}
            </div>
          )}

          {/* ═══════════════════════════════════════════════════════════════
              SECONDARY TABS
          ════════════════════════════════════════════════════════════════ */}
          {view !== "main" && (
            <div className="table-card surface ops-table-surface student-directory-table-wrap">
              {view === "structures" && (
                <StructuresAccordion
                  structures={state.structures}
                  onNew={() => setDialog("structure")}
                />
              )}

              {view === "collections" && (
                <FinanceTable
                  headers={["Receipt #", "Student", "Amount Paid", "Date", "Mode", "Transaction Ref", ""]}
                  rows={state.payments}
                  emptyText="No payments recorded."
                  renderRow={(r) => {
                    // payments API returns: student (nested), fee_receipts[] (array),
                    // amount, payment_method, paid_at, reference_number on the row itself
                    const stName = displayName(nested(r, "student"));
                    const receipts = Array.isArray(r.fee_receipts) ? r.fee_receipts as Row[] : [];
                    const receipt = receipts[0] ?? {};
                    const receiptNum = stringValue(receipt.receipt_number ?? r.receipt_number);
                    const amountPaid = Number(r.amount ?? 0);
                    const payDate = stringValue(r.paid_at ?? r.created_at).slice(0, 10);
                    const payMode = stringValue(r.payment_method);
                    const txnRef = stringValue(r.reference_number ?? receipt.transaction_ref ?? "");
                    return (
                      <tr key={stringValue(r.id)}>
                        <td><b>{receiptNum || "—"}</b></td>
                        <td>
                          <div className="student-cell">
                            <span className="student-avatar" style={{ background: "#eef8f1", color: "#1c6b32" }}>
                              {studentInitials(stName)}
                            </span>
                            <b>{stName}</b>
                          </div>
                        </td>
                        <td><b style={{ color: "#1e8e3e" }}>{money(amountPaid)}</b></td>
                        <td>{payDate || "—"}</td>
                        <td>
                          <span className="status-pill" style={{ background: "#f0f4fb", color: "#0d5291" }}>
                            {payMode || "—"}
                          </span>
                        </td>
                        <td style={{ maxWidth: 160, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{txnRef || "—"}</td>
                        <td>
                          <button
                            className="secondary-button"
                            style={{ padding: "4px 10px", fontSize: ".78rem", gap: 5 }}
                            onClick={() => printReceipt(r, stName)}
                            title="Download / Print receipt"
                          >
                            <Download size={13} /> Receipt
                          </button>
                        </td>
                      </tr>
                    );
                  }}
                />
              )}

              {view === "requests" && (
                <div className="request-list" style={{ padding: "1rem" }}>
                  {state.requests.length ? (
                    state.requests.map((r) => (
                      <article
                        key={stringValue(r.id)}
                        style={{ padding: "0.85rem 1rem", background: "#f9fcfd", border: "1px solid #dce8ee", borderRadius: "10px", marginBottom: "0.75rem" }}
                      >
                        <div>
                          <b>{displayName(nested(r, "student"))} · {money(r.amount)}</b>
                          <span style={{ display: "block", color: "#597080", fontSize: "0.78rem", marginTop: "0.2rem" }}>
                            Mode: {stringValue(r.payment_mode)} · Ref: {stringValue(r.transaction_id || "None")} · Submitted: {stringValue(r.created_at).slice(0, 10)}
                          </span>
                        </div>
                        <div style={{ display: "flex", gap: "0.5rem", marginTop: "0.5rem" }}>
                          {stringValue(r.status).toLowerCase() === "pending" ? (
                            <>
                              <button
                                className="primary-button"
                                disabled={Boolean(busyAction)}
                                aria-busy={busyAction === `decision:${r.id}:approved`}
                                onClick={() => void decide(r, "approved")}
                              >
                                {busyAction === `decision:${r.id}:approved`
                                  ? <LoadingIndicator label="Approving…" compact announce={false} />
                                  : "Approve"}
                              </button>
                              <button
                                className="secondary-button danger"
                                disabled={Boolean(busyAction)}
                                aria-busy={busyAction === `decision:${r.id}:rejected`}
                                onClick={() => void decide(r, "rejected")}
                              >
                                {busyAction === `decision:${r.id}:rejected`
                                  ? <LoadingIndicator label="Rejecting…" compact announce={false} />
                                  : "Reject"}
                              </button>
                            </>
                          ) : (
                            <span className={`student-status ${stringValue(r.status).toLowerCase() === "approved" ? "active" : "inactive"}`}>
                              {stringValue(r.status)}
                            </span>
                          )}
                        </div>
                      </article>
                    ))
                  ) : (
                    <p className="ops-empty">No pending parent payment verification requests.</p>
                  )}
                </div>
              )}

              {view === "concessions" && (
                <FinanceTable
                  headers={["Student", "Reason", "Amount / Discount", "Granted Date"]}
                  rows={state.concessions}
                  emptyText="No fee concessions granted."
                  renderRow={(r) => {
                    const concInvoice = operationalInvoices.find(
                      (i) => stringValue(i.id) === stringValue(r.invoice_id)
                    );
                    return (
                      <tr key={stringValue(r.id)}>
                        <td><b>{displayName(nested(concInvoice ?? {}, "student"))}</b></td>
                        <td>{stringValue(r.reason)}</td>
                        <td><b>{r.amount ? money(r.amount) : `${stringValue(r.percentage)}%`}</b></td>
                        <td>{stringValue(r.created_at).slice(0, 10)}</td>
                      </tr>
                    );
                  }}
                />
              )}

              {view === "reports" && (
                <form action={saveConfig} className="finance-report-grid" style={{ padding: "1.2rem" }}>
                  <section className="surface ops-form-surface">
                    <h3>UPI &amp; Bank Account Settings</h3>
                    <p>Parents see these payment details when making online transfers.</p>
                    <label className="field">UPI VPA / Handle<input name="upi_id" defaultValue={stringValue(state.config.upi_id)} placeholder="e.g. arishville@icici" /></label>
                    <label className="field">Account Holder Name<input name="account_name" defaultValue={stringValue(state.config.account_name)} /></label>
                    <label className="field">Bank Name<input name="bank_name" defaultValue={stringValue(state.config.bank_name)} /></label>
                    <label className="field">Account Number<input name="account_number" defaultValue={stringValue(state.config.account_number)} /></label>
                    <label className="field">IFSC Code<input name="ifsc_code" defaultValue={stringValue(state.config.ifsc_code)} /></label>
                    <button className="primary-button" style={{ marginTop: "0.5rem" }} disabled={busyAction === "config"} aria-busy={busyAction === "config"}>
                      {busyAction === "config" ? <LoadingIndicator label="Saving…" compact announce={false} /> : "Save bank configuration"}
                    </button>
                  </section>
                  <section className="finance-report-card surface">
                    <FileText size={24} />
                    <h3>Ledger Export</h3>
                    <p>Download full transaction history, audit trails, and student fee statements.</p>
                    <div className="ops-stack">
                      <button
                        className="secondary-button"
                        type="button"
                        disabled={Boolean(busyAction)}
                        aria-busy={busyAction === "export:fee_outstanding_report"}
                        onClick={() => void requestFinanceExport("fee_outstanding_report", "Fee outstanding report")}
                      >
                        {busyAction === "export:fee_outstanding_report"
                          ? <LoadingIndicator label="Preparing…" compact announce={false} />
                          : <><Download size={16} /> Export outstanding report</>}
                      </button>
                      <button
                        className="secondary-button"
                        type="button"
                        onClick={() =>
                          downloadCsv(
                            `fee_receipt_register_${new Date().toISOString().slice(0, 10)}.csv`,
                            state.payments.map((p) => ({
                              receipt_number: p.receipt_number,
                              invoice_id: p.invoice_id,
                              amount_paid: p.amount_paid,
                              payment_mode: p.payment_mode,
                              payment_date: p.payment_date,
                              transaction_id: p.transaction_id,
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
                    <p>{overdueInvoices.length} invoices currently have an outstanding balance.</p>
                    <div className="ops-chip-cloud">
                      {overdueInvoices.slice(0, 6).map((inv) => (
                        <span key={stringValue(inv.id)} className="ops-chip">
                          {stringValue(inv.invoice_number)} · {money(inv.balance)}
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
                          overdueInvoices.map((inv) => ({
                            invoice_number: inv.invoice_number,
                            student: displayName(nested(inv, "student")),
                            balance: inv.balance,
                            status: inv.status,
                          }))
                        )
                      }
                    >
                      Export overdue follow-up list
                    </button>
                  </section>
                </form>
              )}
            </div>
          )}
        </>
      )}

      {/* ── Dialogs ── */}
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
          invoices={operationalInvoices}
          preselectedInvoiceId={activeInvoice ? stringValue(activeInvoice.id) : undefined}
          onClose={() => setDialog(false)}
          onSaved={() => {
            onNotify("Payment recorded.");
            void load();
          }}
        />
      )}

      {dialog === "concession" && (
        <ConcessionDialog
          invoices={operationalInvoices}
          preselectedInvoiceId={activeInvoice ? stringValue(activeInvoice.id) : undefined}
          onClose={() => setDialog(false)}
          onSaved={() => {
            onNotify("Concession granted.");
            void load();
          }}
        />
      )}

      {confirmDeletePaymentId && (
        <Dialog kicker="Permanent action" title="Delete this payment?" onClose={() => !deletingPaymentId && setConfirmDeletePaymentId(null)}>
          <div className="student-delete-dialog">
            <CircleAlert size={22} />
            <p>
              This will permanently remove the payment record and reverse the invoice totals. This cannot be undone.
            </p>
          </div>
          <div className="dialog-footer">
            <button className="secondary-button" type="button" disabled={!!deletingPaymentId} onClick={() => setConfirmDeletePaymentId(null)}>
              Cancel
            </button>
            <button className="danger-button" type="button" disabled={!!deletingPaymentId} onClick={() => void deletePayment(confirmDeletePaymentId)}>
              {deletingPaymentId ? <LoadingIndicator label="Deleting…" compact announce={false} /> : "Delete payment"}
            </button>
          </div>
        </Dialog>
      )}
    </section>
  );
}

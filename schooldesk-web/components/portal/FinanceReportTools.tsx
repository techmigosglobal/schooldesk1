"use client";

import { useState } from "react";
import { Download, FileText } from "@/lib/lucide-react";
import { reportDownloadPath } from "@/lib/report-links";
import { receiptRegisterRows } from "@/lib/receipt-register";
import { api, apiAll, downloadCsv, stringValue } from "./utils";
import type { Row } from "./types";

/** Relocated existing fee exports. Mounted only inside Principal Finance reports. */
export function FinanceReportTools({ onExported, onNotify }: { onExported: () => void; onNotify: (message: string, type?: "success" | "error" | "info") => void }) {
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  async function exportOutstanding() {
    if (busy) return;
    setBusy("outstanding"); setError("");
    try {
      const result = await api("fees/reports/exports", { method: "POST", body: JSON.stringify({ report_title: "Fee outstanding report", report_type: "fee_outstanding_report", format: "pdf", parameters: {} }) }) as Row;
      onExported();
      if (stringValue(result.download_url)) {
        const response = await fetch(reportDownloadPath(stringValue(result.id), true));
        if (!response.ok) throw new Error("The fee export could not be downloaded. Find it in export history or retry.");
        const url = URL.createObjectURL(await response.blob());
        const link = document.createElement("a"); link.href = url; link.download = "fee_outstanding_report.pdf"; link.click();
        setTimeout(() => URL.revokeObjectURL(url), 1000);
        onNotify("Fee outstanding report downloaded.");
      } else onNotify("Fee outstanding report requested. Check export history for its status.", "info");
    } catch (event) { setError(event instanceof Error ? event.message : "Unable to export outstanding report."); }
    finally { setBusy(""); }
  }
  async function exportReceipts() {
    if (busy) return;
    setBusy("receipts"); setError("");
    try {
      const payments = await apiAll("fees/payments?page=1&page_size=100");
      downloadCsv(`fee_receipt_register_${new Date().toISOString().slice(0, 10)}.csv`, receiptRegisterRows(payments).map((row, index) => ({ ...row, status: payments[index]?.status ?? "", receipt_voided_at: Array.isArray(payments[index]?.fee_receipts) ? stringValue((payments[index].fee_receipts as Row[])[0]?.voided_at) : "" })));
      onNotify("Receipt register CSV downloaded.");
    } catch (event) { setError(event instanceof Error ? event.message : "Unable to export receipt register."); }
    finally { setBusy(""); }
  }
  return <section className="finance-report-tools" aria-label="Ledger exports">
    <h3>Ledger exports</h3><p>Current branch · All academic years. Receipt history includes historical payment records.</p>
    {error && <p className="ops-inline-error" role="alert">{error}</p>}
    <div className="ops-actions"><button type="button" className="secondary-button" disabled={Boolean(busy)} aria-busy={busy === "outstanding"} onClick={() => void exportOutstanding()}><Download size={16} /> {busy === "outstanding" ? "Preparing outstanding PDF…" : "Outstanding balances PDF"}</button><button type="button" className="secondary-button" disabled={Boolean(busy)} aria-busy={busy === "receipts"} onClick={() => void exportReceipts()}><FileText size={16} /> {busy === "receipts" ? "Preparing receipts…" : "Receipt register CSV"}</button></div>
  </section>;
}

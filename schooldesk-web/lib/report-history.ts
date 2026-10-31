import type { PortalRole } from "./roles";

type HistoryRecord = { id?: unknown; created_at?: unknown; finance?: unknown; report_type?: unknown };
const financeTypes = new Set(["fee_structure", "student_fee_invoices", "paid_fees", "pending_fees", "due_fees", "complete_fees_report", "fee_outstanding_report"]);
export function selectReportHistory<T extends HistoryRecord>(records: T[], role: PortalRole, requestedPage: number, pageSize = 12) {
  const size = Number.isInteger(pageSize) && pageSize > 0 ? pageSize : 12;
  const timestamp = (record: T) => { const time = Date.parse(String(record.created_at ?? "")); return Number.isFinite(time) ? time : 0; };
  const visible = records.filter((item) => role === "principal" || (item.finance !== true && !financeTypes.has(String(item.report_type ?? ""))));
  const sorted = [...visible].sort((a, b) => timestamp(b) - timestamp(a) || String(a.id ?? "").localeCompare(String(b.id ?? "")));
  const totalPages = Math.max(1, Math.ceil(sorted.length / size));
  const page = Math.max(1, Math.min(totalPages, Number.isInteger(requestedPage) ? requestedPage : 1));
  return { items: sorted.slice((page - 1) * size, page * size), page, totalPages, total: sorted.length };
}

"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { ChevronLeft, ChevronRight, Download, FileText } from "@/lib/lucide-react";
import { reportDownloadPath, reportLinkState } from "@/lib/report-links";
import { selectReportHistory } from "@/lib/report-history";
import { readFeeSummary, type FeeSummary } from "@/lib/fee-summary";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import type { PortalRole } from "@/lib/roles";
import { isFinanceReport, reportDefinitionForHistory, reportsForRole, type PortalReportDefinition } from "./report-catalog";
import { FinanceReportTools } from "./FinanceReportTools";
import { usePortalRefresh } from "./use-portal-refresh";
import { usePortalState, usePortalTab } from "./PortalStateProvider";
import type { Row } from "./types";
import { apiAll, api, formatDateTime, money, rowsFrom, stringValue } from "./utils";

type ExportRecord = Row & { id?: string; report_title?: string; report_type?: string; status?: string; download_url?: string; created_at?: string; finance?: boolean };
const records = (value: unknown): ExportRecord[] => rowsFrom(value) as ExportRecord[];

export function ReportsWorkspace({ role, onNotify }: { role: PortalRole; onNotify: (message: string, type?: "success" | "error" | "info") => void }) {
  const [years, setYears] = useState<Row[]>([]), [grades, setGrades] = useState<Row[]>([]), [sections, setSections] = useState<Row[]>([]);
  const [history, setHistory] = useState<ExportRecord[]>([]);
  const [summary, setSummary] = useState<FeeSummary | null>(null);
  const [loading, setLoading] = useState(true), [loaded, setLoaded] = useState(false), [exporting, setExporting] = useState(""), [error, setError] = useState("");
  const [scope, setScope] = usePortalState("reports.scope", { academic_year_id: "", grade_id: "", section_id: "" });
  const [historyPage, setHistoryPage] = usePortalState("reports.historyPage", 1);
  const [group, setGroup] = usePortalTab<"academic" | "finance">("reports", "academic");
  const reports = useMemo(() => reportsForRole(role), [role]);
  const load = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const [yearData, gradeData, sectionData, academicHistory, feeHistory, feeSummary] = await Promise.all([
        apiAll("academic-years?page=1&page_size=100"), apiAll("grades?page=1&page_size=100"), api("principal/classes"), api("reports/exports"),
        role === "principal" ? api("fees/reports/exports") : Promise.resolve([]),
        role === "principal" ? api("fees/summary").then(readFeeSummary) : Promise.resolve(null),
      ]);
      const loadedYears = rowsFrom(yearData), loadedGrades = rowsFrom(gradeData), loadedSections = rowsFrom(sectionData);
      setYears(loadedYears); setGrades(loadedGrades); setSections(loadedSections);
      setScope((current) => ({ academic_year_id: loadedYears.some((r) => stringValue(r.id) === current.academic_year_id) ? current.academic_year_id : "", grade_id: loadedGrades.some((r) => stringValue(r.id) === current.grade_id) ? current.grade_id : "", section_id: loadedSections.some((r) => stringValue(r.id || r.section_id) === current.section_id && (!current.grade_id || stringValue(r.grade_id) === current.grade_id)) ? current.section_id : "" }));
      setHistory([...records(academicHistory).map((item) => ({ ...item, finance: false })), ...records(feeHistory).map((item) => ({ ...item, finance: true }))]);
      setSummary(feeSummary); setLoaded(true);
    } catch (event) { setError(event instanceof Error ? event.message : "Unable to load reports and exports"); }
    finally { setLoading(false); }
  }, [role, setScope]);
  usePortalRefresh(load);
  useEffect(() => { void load(); }, [load]);
  const page = selectReportHistory(history, role, historyPage);
  useEffect(() => { if (loaded && historyPage !== page.page) setHistoryPage(page.page); }, [loaded, historyPage, page.page, setHistoryPage]);
  const activeGroup = role === "principal" ? group : "academic";
  const selectedSections = sections.filter((section) => !scope.grade_id || stringValue(section.grade_id) === scope.grade_id);
  async function downloadFile(id: string, finance: boolean, filename: string) {
    const response = await fetch(reportDownloadPath(id, finance));
    if (!response.ok) { const body = await response.json().catch(() => ({})); throw new Error(body.error || "The PDF could not be downloaded. Please retry or generate a current PDF."); }
    const url = URL.createObjectURL(await response.blob()); const link = document.createElement("a"); link.href = url; link.download = `${filename.toLowerCase().replace(/[^a-z0-9_-]+/g, "_")}.pdf`; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  async function downloadSaved(item: ExportRecord) {
    if (role !== "principal" && item.finance) return;
    setExporting(`download:${stringValue(item.id)}`); setError("");
    try { await downloadFile(stringValue(item.id), item.finance === true, stringValue(item.report_title || "school-report")); }
    catch (event) { setError(event instanceof Error ? event.message : "Unable to download this PDF."); }
    finally { setExporting(""); }
  }
  async function generate(report: PortalReportDefinition) {
    if (exporting || (isFinanceReport(report) && role !== "principal")) return;
    setExporting(report.id); setError("");
    try {
      const finance = isFinanceReport(report);
      const result = await api(report.endpoint, { method: "POST", body: JSON.stringify({ report_title: report.title, report_type: report.id, format: "pdf", scope: finance ? "school" : scope.section_id ? "section" : scope.grade_id ? "grade" : "school", parameters: finance ? {} : scope }) }) as ExportRecord;
      setHistory((previous) => [{ ...result, finance }, ...previous.filter((item) => !(stringValue(item.id) === stringValue(result.id) && item.finance === finance))]);
      const url = stringValue(result.download_url);
      if (url) await downloadFile(stringValue(result.id), finance, report.id);
      onNotify(url ? `${report.title} PDF is ready.` : `${report.title} is queued for export.`, url ? "success" : "info");
    } catch (event) { setError(event instanceof Error ? event.message : `Unable to generate ${report.title}`); }
    finally { setExporting(""); }
  }
  return <section className="ops-module leadership-reports" aria-busy={loading}>
    {error && <div className="ops-inline-error" role="alert">{error}{loaded && " Previously loaded reports and figures may be stale. Use Refresh to retry."}</div>}
    {loading && !loaded ? <PortalModuleSkeleton variant="reports" label="Loading reports" /> : loaded && <>
      {role === "principal" && <nav className="finance-tabs" aria-label="Report groups"><button type="button" className={activeGroup === "academic" ? "active" : ""} onClick={() => setGroup("academic")}>Academic (8)</button><button type="button" className={activeGroup === "finance" ? "active" : ""} onClick={() => setGroup("finance")}>Finance (6)</button></nav>}
      <section className="report-group" aria-label={`${activeGroup === "academic" ? "Academic" : "Finance"} reports`}>
        <h2>{activeGroup === "academic" ? "Academic reports" : "Finance reports"}</h2>
        {activeGroup === "academic" ? <section className="leadership-report-scope surface"><div><h3>Academic scope</h3><p>Applies to the academic PDFs below.</p></div><div className="leadership-report-selects">
          <label>Academic year<select value={scope.academic_year_id} onChange={(event) => setScope((current) => ({ ...current, academic_year_id: event.target.value }))}><option value="">All academic years</option>{years.map((year) => <option key={stringValue(year.id)} value={stringValue(year.id)}>{stringValue(year.year_name || year.name || year.academic_year)}</option>)}</select></label>
          <label>Class<select value={scope.grade_id} onChange={(event) => setScope((current) => ({ ...current, grade_id: event.target.value, section_id: "" }))}><option value="">All classes</option>{grades.map((grade) => <option key={stringValue(grade.id)} value={stringValue(grade.id)}>{stringValue(grade.grade_name || grade.name)}</option>)}</select></label>
          <label>Section<select value={scope.section_id} onChange={(event) => setScope((current) => ({ ...current, section_id: event.target.value }))}><option value="">All sections</option>{selectedSections.map((section) => <option key={stringValue(section.id || section.section_id)} value={stringValue(section.id || section.section_id)}>{stringValue(section.section_name || section.name)}</option>)}</select></label>
        </div></section> : <p className="finance-scope-note">Current branch · All academic years{summary && ` · Collected ${money(summary.collected)} · Outstanding ${money(summary.outstanding)} · ${summary.collectionPercent === null ? "No collection target" : `${summary.collectionPercent}% collected`}`}</p>}
        <div className="leadership-report-grid">{reports.filter((report) => isFinanceReport(report) === (activeGroup === "finance")).map((report) => <article className={isFinanceReport(report) ? "finance" : "academic"} key={report.id}><span><FileText size={18} /></span><div><h3>{report.title}</h3><p>{report.description}</p></div><button type="button" className="secondary-button" aria-label={`Generate ${report.title} PDF`} onClick={() => void generate(report)} disabled={Boolean(exporting)} aria-busy={exporting === report.id}>{exporting === report.id ? <LoadingIndicator label="Preparing PDF…" compact announce={false} /> : <><Download size={15} /> Generate PDF</>}</button></article>)}</div>
        {role === "principal" && activeGroup === "finance" && <FinanceReportTools onExported={() => void load()} onNotify={onNotify} />}
      </section>
      <section className="leadership-export-history surface"><div className="ops-panel-header"><div><h2>Export history</h2><p>All returned exports, newest first. Missing historical files can be regenerated from current data.</p></div></div>
        {page.total ? <><div className="leadership-export-list">{page.items.map((item) => {
          const url = stringValue(item.download_url), status = stringValue(item.status || "queued"), definition = reportDefinitionForHistory(role, stringValue(item.report_type)), linkState = reportLinkState(url);
          return <article key={`${item.finance ? "finance" : "academic"}:${stringValue(item.id)}`}><div><b>{stringValue(item.report_title || item.report_type || "Report export")}</b><small>{item.finance ? "Finance" : "Academic"} · {formatDateTime(item.created_at)} · {status}</small></div>{url && linkState !== "legacy" && linkState !== "missing" ? <button type="button" className="secondary-button" aria-label={`Download ${stringValue(item.report_title || item.report_type || "report")} PDF`} disabled={Boolean(exporting)} onClick={() => void downloadSaved(item)}><Download size={15} />{exporting === `download:${stringValue(item.id)}` ? "Downloading…" : "Download"}</button> : definition && (url || status === "completed" || status === "failed") ? <div><small>Saved file unavailable</small><button type="button" className="secondary-button" disabled={Boolean(exporting)} onClick={() => void generate(definition)}>Generate current PDF</button></div> : <span className="leadership-export-status">{url ? "Saved file unavailable" : status}</span>}</article>;
        })}</div><nav className="report-history-pagination" aria-label="Export history pages"><button type="button" className="secondary-button" disabled={page.page === 1} onClick={() => setHistoryPage(page.page - 1)}><ChevronLeft size={15} />Previous</button><span>Page {page.page} of {page.totalPages} · {page.total} exports</span><button type="button" className="secondary-button" disabled={page.page === page.totalPages} onClick={() => setHistoryPage(page.page + 1)}>Next<ChevronRight size={15} /></button></nav></> : <p className="ops-empty-small">No report exports have been requested yet.</p>}
      </section>
    </>}
  </section>;
}

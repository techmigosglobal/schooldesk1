"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { ChartNoAxesCombined, Download, FileText, RefreshCw } from "@/lib/lucide-react";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import type { PortalRole } from "@/lib/roles";
import { isFinanceReport, reportsForRole, type PortalReportDefinition } from "./report-catalog";
import type { Row } from "./types";
import { api, formatDateTime, money, rowsFrom, stringValue } from "./utils";

type ExportRecord = Row & {
  id?: string;
  report_title?: string;
  report_type?: string;
  status?: string;
  download_url?: string;
  created_at?: string;
};

const records = (value: unknown): ExportRecord[] => rowsFrom(value) as ExportRecord[];

export function ReportsWorkspace({ role, onNotify }: {
  role: PortalRole;
  onNotify: (message: string, type?: "success" | "error" | "info") => void;
}) {
  const [dashboard, setDashboard] = useState<Row>({});
  const [students, setStudents] = useState<Row[]>([]);
  const [staff, setStaff] = useState<Row[]>([]);
  const [inquiries, setInquiries] = useState<Row[]>([]);
  const [years, setYears] = useState<Row[]>([]);
  const [grades, setGrades] = useState<Row[]>([]);
  const [sections, setSections] = useState<Row[]>([]);
  const [history, setHistory] = useState<ExportRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [exporting, setExporting] = useState("");
  const [error, setError] = useState("");
  const [scope, setScope] = useState({ academic_year_id: "", grade_id: "", section_id: "" });
  const reports = useMemo(() => reportsForRole(role), [role]);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const requests: Promise<unknown>[] = [
        api("dashboard"), api("students?page=1&page_size=200"), api("staff?page=1&page_size=200"),
        api("admission-inquiries"), api("academic-years?page=1&page_size=100").catch(() => []),
        api("grades?page=1&page_size=100").catch(() => []), api("principal/classes").catch(() => []),
        api("reports/exports").catch(() => []),
      ];
      if (role === "principal") requests.push(api("fees/reports/exports").catch(() => []));
      const [dashboardData, studentsData, staffData, inquiryData, yearData, gradeData, sectionData, academicHistory, feeHistory] = await Promise.all(requests);
      setDashboard((dashboardData as Row) || {});
      setStudents(rowsFrom(studentsData));
      setStaff(rowsFrom(staffData));
      setInquiries(rowsFrom(inquiryData));
      setYears(rowsFrom(yearData));
      setGrades(rowsFrom(gradeData));
      setSections(rowsFrom(sectionData));
      setHistory([...records(academicHistory), ...records(feeHistory)].sort((a, b) => stringValue(b.created_at).localeCompare(stringValue(a.created_at))));
    } catch (event) {
      setError(event instanceof Error ? event.message : "Unable to load reports and exports");
    } finally {
      setLoading(false);
    }
  }, [role]);

  useEffect(() => { void load(); }, [load]);

  const selectedSections = sections.filter((section) => !scope.grade_id || stringValue(section.grade_id) === scope.grade_id);

  async function generate(report: PortalReportDefinition) {
    setExporting(report.id);
    setError("");
    try {
      const result = await api(report.endpoint, {
        method: "POST",
        body: JSON.stringify({ report_title: report.title, report_type: report.id, format: "pdf", scope: scope.section_id ? "section" : scope.grade_id ? "grade" : "school", parameters: scope }),
      }) as ExportRecord;
      setHistory((previous) => [result, ...previous.filter((item) => stringValue(item.id) !== stringValue(result.id))].sort((a, b) => stringValue(b.created_at).localeCompare(stringValue(a.created_at))));
      const url = stringValue(result.download_url);
      if (url) window.open(url, "_blank", "noopener,noreferrer");
      onNotify(url ? `${report.title} PDF is ready.` : `${report.title} is queued for export.`, url ? "success" : "info");
    } catch (event) {
      setError(event instanceof Error ? event.message : `Unable to generate ${report.title}`);
    } finally {
      setExporting("");
    }
  }

  return <section className="ops-module leadership-reports">
    <div className="ops-module-heading">
      <div><div className="ops-module-icon navy"><ChartNoAxesCombined size={20} /></div><div><p className="ops-kicker">Leadership reporting</p><h2>Reports &amp; Exports</h2><p>Generate stored PDF summaries directly from live school data, with a clear export history and download links.</p></div></div>
      <div className="ops-actions"><button className="secondary-button" type="button" onClick={() => void load()} disabled={loading}><RefreshCw size={16} className={loading ? "spin" : ""} /> Refresh</button></div>
    </div>
    {error && <div className="ops-inline-error">{error}</div>}

    {loading ? <PortalModuleSkeleton variant="reports" label="Loading leadership reports" /> : <>
    <div className="leadership-report-summary">
      <article><small>Students</small><b>{stringValue(dashboard.total_students ?? students.length)}</b></article>
      <article><small>Staff</small><b>{stringValue(dashboard.total_staff ?? staff.length)}</b></article>
      <article><small>Admission inquiries</small><b>{inquiries.length}</b></article>
      {role === "principal" && <article><small>Fee collection</small><b>{money((dashboard.fees as Row | undefined)?.total_paid ?? 0)}</b></article>}
    </div>

    <section className="leadership-report-scope surface">
      <div><h3>Report scope</h3><p>Choose a class filter for focused academic reports. Finance reports remain school-ledger reports.</p></div>
      <div className="leadership-report-selects">
        <label>Academic year<select value={scope.academic_year_id} onChange={(event) => setScope((current) => ({ ...current, academic_year_id: event.target.value }))}><option value="">All academic years</option>{years.map((year) => <option key={stringValue(year.id)} value={stringValue(year.id)}>{stringValue(year.year_name || year.name || year.academic_year)}</option>)}</select></label>
        <label>Class<select value={scope.grade_id} onChange={(event) => setScope((current) => ({ ...current, grade_id: event.target.value, section_id: "" }))}><option value="">All classes</option>{grades.map((grade) => <option key={stringValue(grade.id)} value={stringValue(grade.id)}>{stringValue(grade.grade_name || grade.name)}</option>)}</select></label>
        <label>Section<select value={scope.section_id} onChange={(event) => setScope((current) => ({ ...current, section_id: event.target.value }))}><option value="">All sections</option>{selectedSections.map((section) => <option key={stringValue(section.id || section.section_id)} value={stringValue(section.id || section.section_id)}>{stringValue(section.section_name || section.name)}</option>)}</select></label>
      </div>
    </section>

    <div className="leadership-report-grid">
      {reports.map((report) => <article className={isFinanceReport(report) ? "finance" : "academic"} key={report.id}><span><FileText size={18} /></span><div><h3>{report.title}</h3><p>{report.description}</p></div><button type="button" className="secondary-button" onClick={() => void generate(report)} disabled={Boolean(exporting)} aria-busy={exporting === report.id}>{exporting === report.id ? <LoadingIndicator label="Preparing PDF…" compact announce={false} /> : <><Download size={15} /> Generate PDF</>}</button></article>)}
    </div>

    <section className="leadership-export-history surface">
      <div className="ops-panel-header"><div><h3>Recent exports</h3><p>Completed reports include a download link. Queued reports remain visible until processing completes.</p></div></div>
      {history.length ? <div className="leadership-export-list">{history.slice(0, 12).map((item) => { const url = stringValue(item.download_url); const status = stringValue(item.status || "queued"); return <article key={stringValue(item.id)}><div><b>{stringValue(item.report_title || item.report_type || "Report export")}</b><small>{formatDateTime(item.created_at)} · {status}</small></div>{url ? <a className="secondary-button" href={url} target="_blank" rel="noreferrer"><Download size={15} /> Download</a> : <span className="leadership-export-status">{status}</span>}</article>; })}</div> : <p className="ops-empty-small">No report exports have been requested yet.</p>}
    </section>
    </>}
  </section>;
}

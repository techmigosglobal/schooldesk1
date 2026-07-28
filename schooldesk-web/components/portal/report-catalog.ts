import type { PortalRole } from "@/lib/roles";

export type ReportEndpoint = "reports/exports" | "fees/reports/exports";

export type PortalReportDefinition = {
  id: string;
  title: string;
  description: string;
  endpoint: ReportEndpoint;
};

const academicReports: PortalReportDefinition[] = [
  { id: "class_summary", title: "Class summary", description: "Classes, sections, capacity, and teacher assignments.", endpoint: "reports/exports" },
  { id: "students_list", title: "Student list", description: "Current learner roster for the selected academic scope.", endpoint: "reports/exports" },
  { id: "users_wise_export", title: "Staff and user accounts", description: "Active leadership, educator, and parent account directory.", endpoint: "reports/exports" },
  { id: "subjects_mapping", title: "Subjects mapping", description: "Subjects and periods mapped to each class and section.", endpoint: "reports/exports" },
  { id: "teacher_mapping", title: "Teacher mapping", description: "Class teacher and co-teacher assignments.", endpoint: "reports/exports" },
  { id: "timetable_summary", title: "Timetable summary", description: "Teaching timetable for the selected class scope.", endpoint: "reports/exports" },
  { id: "complete_classwise_data", title: "Complete classwise data", description: "Combined class, learner, subject, teacher, and timetable summary.", endpoint: "reports/exports" },
  { id: "admission_inquiry_summary", title: "Admission inquiry summary", description: "Website enquiries by programme, date, and family contact details.", endpoint: "reports/exports" },
];

const financeReports: PortalReportDefinition[] = [
  { id: "fee_structure", title: "Fee structures", description: "Configured fee categories and structures.", endpoint: "fees/reports/exports" },
  { id: "student_fee_invoices", title: "Student fee invoices", description: "Issued invoices and current balances.", endpoint: "fees/reports/exports" },
  { id: "paid_fees", title: "Paid fees", description: "Approved collections and receipt details.", endpoint: "fees/reports/exports" },
  { id: "pending_fees", title: "Pending fees", description: "Invoices with a remaining balance.", endpoint: "fees/reports/exports" },
  { id: "due_fees", title: "Due fees", description: "Overdue and due fee follow-up summary.", endpoint: "fees/reports/exports" },
  { id: "complete_fees_report", title: "Complete fees report", description: "Combined structure and invoice ledger report.", endpoint: "fees/reports/exports" },
];

export function reportsForRole(role: PortalRole): PortalReportDefinition[] {
  return role === "principal" ? [...academicReports, ...financeReports] : academicReports;
}

export function isFinanceReport(report: PortalReportDefinition): boolean {
  return report.endpoint === "fees/reports/exports";
}

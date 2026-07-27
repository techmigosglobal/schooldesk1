import type { ComponentType } from "react";
import {
  LayoutDashboard,
  GraduationCap,
  HeartHandshake,
  UserCog,
  Building2,
  CalendarClock,
  ClipboardCheck,
  MessageSquareMore,
  WalletCards,
  ChartNoAxesCombined,
  Images,
} from "@/lib/lucide-react";
import type { PortalRole } from "@/lib/roles";

export type Row = Record<string, unknown>;

export interface StudentRecord extends Row {
  id?: string;
  student_id_number?: string;
  first_name?: string;
  last_name?: string;
  gender?: string;
  date_of_birth?: string;
  current_section_id?: string;
  admission_number?: string;
  admission_date?: string;
  parent_user_id?: string;
  status?: string;
}

export interface StaffRecord extends Row {
  id?: string;
  staff_code?: string;
  first_name?: string;
  last_name?: string;
  username?: string;
  designation?: string;
  phone?: string;
  email?: string;
  account_role?: string;
}

export interface SectionRecord extends Row {
  id?: string;
  section_name?: string;
  name?: string;
  grade_name?: string;
  capacity?: number;
  student_count?: number;
}

export interface FeeStructureRecord extends Row {
  id?: string;
  academic_year_id?: string;
  grade_id?: string;
  section_id?: string;
  fee_category_id?: string;
  amount?: number;
  frequency?: string;
  due_day?: number;
  late_fine_per_day?: number;
}

export interface InvoiceRecord extends Row {
  id?: string;
  invoice_number?: string;
  student_id?: string;
  gross_amount?: number;
  concession_amount?: number;
  net_amount?: number;
  total_paid?: number;
  balance?: number;
  status?: string;
}

export interface PaymentRecord extends Row {
  id?: string;
  invoice_id?: string;
  receipt_number?: string;
  amount_paid?: number;
  payment_date?: string;
  payment_mode?: string;
  transaction_id?: string;
}

export interface ConcessionRecord extends Row {
  id?: string;
  invoice_id?: string;
  reason?: string;
  amount?: number;
  percentage?: number;
  created_at?: string;
}


export type ModuleId = "students" | "parents" | "teachers" | "classes" | "timetable";

export interface Field {
  key: string;
  label: string;
  type?: "text" | "number" | "textarea";
}

export interface Module {
  id: ModuleId;
  label: string;
  endpoint: string;
  description: string;
  fields: Field[];
  columns: Array<[string, string]>;
  create: string;
  icon: ComponentType<any>;
  tone: string;
}

export interface Dashboard {
  total_students?: number;
  total_staff?: number;
  total_sections?: number;
  pending_leave_requests?: number;
  metrics?: Record<string, number>;
  today_attendance?: {
    attendance_pct?: number;
    present?: number;
    marked?: number;
  };
  fees?: {
    collection_pct?: number;
    total_paid?: number;
  };
  recent_announcements?: Array<{
    id: string;
    title?: string;
    priority?: string;
  }>;
}

export interface FeeState {
  structures: Row[];
  invoices: Row[];
  payments: Row[];
  requests: Row[];
  concessions: Row[];
  categories: Row[];
  years: Row[];
  grades: Row[];
  sections: Row[];
  config: Row;
}

export const navMeta: Record<string, { icon: ComponentType<any>; label: string }> = {
  overview: { icon: LayoutDashboard, label: "Overview" },
  students: { icon: GraduationCap, label: "Students" },
  parents: { icon: HeartHandshake, label: "Parents" },
  teachers: { icon: UserCog, label: "Teachers" },
  classes: { icon: Building2, label: "Classes & Subjects" },
  timetable: { icon: CalendarClock, label: "Timetables" },
  attendance: { icon: ClipboardCheck, label: "Attendance" },
  communications: { icon: MessageSquareMore, label: "Communications" },
  fees: { icon: WalletCards, label: "Fees" },
  reports: { icon: ChartNoAxesCombined, label: "Reports" },
  admission_inquiries: { icon: MessageSquareMore, label: "Admission Inquiries" },
  website: { icon: Images, label: "Public Website" },
};

export const modules: Module[] = [
  {
    id: "students",
    label: "Students",
    endpoint: "students?page=1&page_size=50",
    description: "Admissions, learner profiles, and parent accounts from the live SchoolDesk backend.",
    create: "students",
    fields: [],
    columns: [
      ["student_id_number", "Student ID"],
      ["first_name", "Student"],
      ["current_section", "Class / section"],
      ["status", "Status"],
    ],
    icon: GraduationCap,
    tone: "blue",
  },
  {
    id: "parents",
    label: "Parents",
    endpoint: "users?role=parent&page=1&page_size=50",
    description: "Manage parent portal accounts and family details.",
    create: "users",
    fields: [
      { key: "name", label: "Parent name" },
      { key: "username", label: "Username" },
      { key: "email", label: "Email" },
      { key: "phone", label: "Phone" },
      { key: "password", label: "Temporary password" },
    ],
    columns: [
      ["name", "Parent"],
      ["username", "Username"],
      ["email", "Email"],
      ["phone", "Phone"],
    ],
    icon: HeartHandshake,
    tone: "gold",
  },
  {
    id: "teachers",
    label: "Teachers",
    endpoint: "staff?page=1&page_size=50",
    description: "Teacher and coordinator profiles.",
    create: "staff",
    fields: [],
    columns: [
      ["staff_code", "Employee ID"],
      ["first_name", "Teacher"],
      ["designation", "Designation"],
      ["phone", "Phone"],
    ],
    icon: UserCog,
    tone: "green",
  },
  {
    id: "classes",
    label: "Classes & Subjects",
    endpoint: "principal/classes",
    description: "Set up class sections, teaching assignments, capacity, and subject mapping.",
    create: "principal/classes",
    fields: [
      { key: "academic_year_id", label: "Academic year ID" },
      { key: "grade_name", label: "Grade name" },
      { key: "grade_number", label: "Grade number", type: "number" },
      { key: "section_name", label: "Section" },
      { key: "capacity", label: "Capacity", type: "number" },
    ],
    columns: [
      ["grade_name", "Class"],
      ["section_name", "Section"],
      ["student_count", "Students"],
      ["capacity", "Capacity"],
    ],
    icon: Building2,
    tone: "violet",
  },
  {
    id: "timetable",
    label: "Timetables",
    endpoint: "timetable/slots",
    description: "Create and update timetable slots.",
    create: "timetable/slots",
    fields: [
      { key: "section_id", label: "Section ID" },
      { key: "academic_year_id", label: "Academic year ID" },
      { key: "day_of_week", label: "Day (1-7)", type: "number" },
      { key: "start_time", label: "Start time" },
      { key: "end_time", label: "End time" },
      { key: "subject_id", label: "Subject ID" },
    ],
    columns: [
      ["day_of_week", "Day"],
      ["start_time", "Starts"],
      ["end_time", "Ends"],
      ["subject_name", "Subject"],
    ],
    icon: CalendarClock,
    tone: "teal",
  },
];

import { z } from "zod";

// ─── Auth ─────────────────────────────────────────────────────────────────────

export const loginSchema = z.object({
  identity: z.string().min(2, "Username must be at least 2 characters"),
  password: z.string().min(6, "Password must be at least 6 characters"),
});
export type LoginInput = z.infer<typeof loginSchema>;

// ─── Students ─────────────────────────────────────────────────────────────────

export const studentSchema = z.object({
  student_name: z.string().min(2, "Student name is required"),
  current_section_id: z.string().min(1, "Class / section is required"),
  student_id_number: z.string().min(1, "Student ID is required"),
  date_of_birth: z.string().min(1, "Date of birth is required"),
  gender: z.enum(["male", "female", "other"]),
  admission_number: z.string().optional(),
  admission_date: z.string().optional(),
  parent_user_id: z.string().optional(),
});
export type StudentInput = z.infer<typeof studentSchema>;

// ─── Teachers / Staff ─────────────────────────────────────────────────────────

export const teacherSchema = z.object({
  full_name: z.string().min(2, "Full name is required"),
  username: z.string().min(2, "Username is required"),
  designation: z.string().min(1, "Designation is required"),
  staff_code: z.string().optional(),
  phone: z.string().optional(),
  email: z.string().email("Invalid email address").optional().or(z.literal("")),
  password: z.string().min(8, "Password must be at least 8 characters").optional().or(z.literal("")),
  account_role: z.enum(["Teacher", "Coordinator"]).optional(),
});
export type TeacherInput = z.infer<typeof teacherSchema>;

// ─── Parents ─────────────────────────────────────────────────────────────────

export const parentSchema = z.object({
  name: z.string().min(2, "Parent name is required"),
  username: z.string().min(2, "Username is required"),
  email: z.string().email("Invalid email").optional().or(z.literal("")),
  phone: z.string().optional(),
  password: z.string().min(8, "Password must be at least 8 characters"),
});
export type ParentInput = z.infer<typeof parentSchema>;

// ─── Fee Structure ────────────────────────────────────────────────────────────

export const feeStructureSchema = z.object({
  academic_year_id: z.string().min(1, "Academic year is required"),
  grade_id: z.string().min(1, "Class is required"),
  section_id: z.string().optional(),
  fee_category_id: z.string().min(1, "Fee category is required"),
  amount: z
    .number({ invalid_type_error: "Amount must be a number" })
    .positive("Amount must be greater than 0"),
  frequency: z.enum(["one_time", "yearly", "monthly", "term"]),
  due_day: z.number().int().min(1).max(31),
  late_fine_per_day: z.number().min(0).default(0),
  replace_existing: z.boolean().default(false),
});
export type FeeStructureInput = z.infer<typeof feeStructureSchema>;

// ─── Payments ─────────────────────────────────────────────────────────────────

export const paymentSchema = z.object({
  invoice_id: z.string().min(1, "Invoice is required"),
  receipt_number: z.string().min(1, "Receipt number is required"),
  amount_paid: z
    .number({ invalid_type_error: "Amount must be a number" })
    .positive("Amount must be greater than 0"),
  payment_date: z.string().min(1, "Payment date is required"),
  payment_mode: z.enum(["cash", "online", "cheque", "dd"]),
  transaction_id: z.string().optional(),
});
export type PaymentInput = z.infer<typeof paymentSchema>;

// ─── Concessions ─────────────────────────────────────────────────────────────

export const concessionSchema = z.object({
  invoice_id: z.string().min(1, "Invoice is required"),
  reason: z.string().min(3, "Reason is required"),
  kind: z.enum(["amount", "percentage"]),
  value: z
    .number({ invalid_type_error: "Value must be a number" })
    .positive("Value must be greater than 0"),
});
export type ConcessionInput = z.infer<typeof concessionSchema>;

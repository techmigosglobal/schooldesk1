import { describe, test, expect } from "bun:test";
import {
  loginSchema,
  studentSchema,
  teacherSchema,
  paymentSchema,
  feeStructureSchema,
  concessionSchema,
} from "../lib/schemas";

// ─── loginSchema ─────────────────────────────────────────────────────────────

describe("loginSchema", () => {
  test("accepts valid credentials", () => {
    const result = loginSchema.safeParse({ identity: "admin", password: "secret123" });
    expect(result.success).toBe(true);
  });

  test("rejects short username (< 2 chars)", () => {
    const result = loginSchema.safeParse({ identity: "a", password: "secret123" });
    expect(result.success).toBe(false);
    expect(result.error?.issues[0].path[0]).toBe("identity");
  });

  test("rejects short password (< 6 chars)", () => {
    const result = loginSchema.safeParse({ identity: "admin", password: "123" });
    expect(result.success).toBe(false);
    expect(result.error?.issues[0].path[0]).toBe("password");
  });

  test("rejects empty fields", () => {
    const result = loginSchema.safeParse({ identity: "", password: "" });
    expect(result.success).toBe(false);
    expect(result.error?.issues.length).toBeGreaterThanOrEqual(2);
  });
});

// ─── studentSchema ────────────────────────────────────────────────────────────

describe("studentSchema", () => {
  const valid = {
    student_name: "Aryan Sharma",
    current_section_id: "sec-001",
    student_id_number: "STU-2024-001",
    date_of_birth: "2019-04-15",
    gender: "male" as const,
  };

  test("accepts valid student data", () => {
    expect(studentSchema.safeParse(valid).success).toBe(true);
  });

  test("rejects empty student name", () => {
    expect(studentSchema.safeParse({ ...valid, student_name: "" }).success).toBe(false);
  });

  test("rejects missing section", () => {
    expect(studentSchema.safeParse({ ...valid, current_section_id: "" }).success).toBe(false);
  });

  test("rejects invalid gender", () => {
    // @ts-expect-error intentional bad value
    expect(studentSchema.safeParse({ ...valid, gender: "unknown" }).success).toBe(false);
  });

  test("accepts optional fields absent", () => {
    expect(studentSchema.safeParse(valid).success).toBe(true);
  });
});

// ─── teacherSchema ────────────────────────────────────────────────────────────

describe("teacherSchema", () => {
  const valid = {
    full_name: "Priya Nair",
    username: "priya.nair",
    designation: "Teacher",
  };

  test("accepts valid teacher data", () => {
    expect(teacherSchema.safeParse(valid).success).toBe(true);
  });

  test("rejects password shorter than 8 chars", () => {
    expect(teacherSchema.safeParse({ ...valid, password: "short" }).success).toBe(false);
  });

  test("accepts empty password string (edit mode — no change)", () => {
    expect(teacherSchema.safeParse({ ...valid, password: "" }).success).toBe(true);
  });

  test("rejects invalid email", () => {
    expect(teacherSchema.safeParse({ ...valid, email: "not-an-email" }).success).toBe(false);
  });

  test("accepts missing optional fields", () => {
    expect(teacherSchema.safeParse(valid).success).toBe(true);
  });
});

// ─── paymentSchema ────────────────────────────────────────────────────────────

describe("paymentSchema", () => {
  const valid = {
    invoice_id: "inv-001",
    receipt_number: "RCP1234",
    amount_paid: 500,
    payment_date: "2024-06-01",
    payment_mode: "cash" as const,
  };

  test("accepts valid payment", () => {
    expect(paymentSchema.safeParse(valid).success).toBe(true);
  });

  test("rejects zero amount", () => {
    expect(paymentSchema.safeParse({ ...valid, amount_paid: 0 }).success).toBe(false);
  });

  test("rejects negative amount", () => {
    expect(paymentSchema.safeParse({ ...valid, amount_paid: -100 }).success).toBe(false);
  });

  test("rejects invalid payment mode", () => {
    // @ts-expect-error intentional bad value
    expect(paymentSchema.safeParse({ ...valid, payment_mode: "bitcoin" }).success).toBe(false);
  });

  test("accepts optional transaction_id", () => {
    expect(paymentSchema.safeParse({ ...valid, transaction_id: "TXN-123" }).success).toBe(true);
  });
});

// ─── feeStructureSchema ───────────────────────────────────────────────────────

describe("feeStructureSchema", () => {
  const valid = {
    academic_year_id: "yr-001",
    grade_id: "grade-001",
    fee_category_id: "cat-001",
    amount: 5000,
    frequency: "monthly" as const,
    due_day: 10,
    late_fine_per_day: 0,
  };

  test("accepts valid fee structure", () => {
    expect(feeStructureSchema.safeParse(valid).success).toBe(true);
  });

  test("rejects due_day > 31", () => {
    expect(feeStructureSchema.safeParse({ ...valid, due_day: 32 }).success).toBe(false);
  });

  test("rejects due_day < 1", () => {
    expect(feeStructureSchema.safeParse({ ...valid, due_day: 0 }).success).toBe(false);
  });

  test("rejects negative amount", () => {
    expect(feeStructureSchema.safeParse({ ...valid, amount: -100 }).success).toBe(false);
  });

  test("rejects invalid frequency", () => {
    // @ts-expect-error intentional bad value
    expect(feeStructureSchema.safeParse({ ...valid, frequency: "weekly" }).success).toBe(false);
  });
});

// ─── concessionSchema ─────────────────────────────────────────────────────────

describe("concessionSchema", () => {
  test("accepts valid amount concession", () => {
    expect(
      concessionSchema.safeParse({
        invoice_id: "inv-001",
        reason: "Financial hardship",
        kind: "amount",
        value: 500,
      }).success
    ).toBe(true);
  });

  test("accepts valid percentage concession", () => {
    expect(
      concessionSchema.safeParse({
        invoice_id: "inv-001",
        reason: "Merit scholarship",
        kind: "percentage",
        value: 10,
      }).success
    ).toBe(true);
  });

  test("rejects reason shorter than 3 chars", () => {
    expect(
      concessionSchema.safeParse({
        invoice_id: "inv-001",
        reason: "ok",
        kind: "amount",
        value: 100,
      }).success
    ).toBe(false);
  });

  test("rejects zero value", () => {
    expect(
      concessionSchema.safeParse({
        invoice_id: "inv-001",
        reason: "Valid reason",
        kind: "amount",
        value: 0,
      }).success
    ).toBe(false);
  });

  test("rejects invalid kind", () => {
    expect(
      // @ts-expect-error intentional bad value
      concessionSchema.safeParse({
        invoice_id: "inv-001",
        reason: "Valid reason",
        kind: "discount",
        value: 100,
      }).success
    ).toBe(false);
  });
});

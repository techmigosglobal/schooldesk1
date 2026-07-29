// handlers/fees.ts — categories, structures, invoices, payments, requests, config
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok, triggerPushProcessing } from "../index.ts";
import { queueReportExport } from "./uploads.ts";

function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}

function roleName(u: User) {
  return `${u.app_metadata?.role_name ?? u.app_metadata?.role ?? ""}`
    .toLowerCase();
}

function isAdminOrPrincipal(u: User) {
  return ["admin", "principal", "super_admin"].includes(roleName(u));
}

function text(value: unknown, fallback = "") {
  const raw = `${value ?? ""}`.trim();
  return raw === "null" ? fallback : raw || fallback;
}

function money(value: unknown) {
  const parsed = typeof value === "number"
    ? value
    : parseFloat(`${value ?? 0}`);
  return Math.round((Number.isFinite(parsed) ? parsed : 0) * 100) / 100;
}

function normalizeFrequency(value: unknown) {
  const raw = text(value, "term").toLowerCase().replaceAll("-", "_").replaceAll(
    " ",
    "_",
  );
  if (raw.includes("one")) return "one_time";
  if (raw.includes("year")) return "yearly";
  if (raw.includes("month")) return "monthly";
  if (raw.includes("term")) return "term";
  return raw || "term";
}

function normalizeFeeType(value: unknown, fallback = "") {
  const raw = text(value, fallback).toLowerCase().replaceAll("-", "_")
    .replaceAll(" ", "_");
  if (raw.includes("tuition")) return "tuition";
  if (raw.includes("daycare") || raw.includes("day_care")) {
    return "daycare_hourly";
  }
  return "other";
}

const defaultFeeCategories = [
  {
    name: "Tuition",
    description: "Recurring tuition fee",
  },
  {
    name: "Books & Kit",
    description: "One-time books and learning materials fee",
  },
  {
    name: "Transport",
    description: "Recurring transport fee",
  },
  {
    name: "Activity",
    description: "Activity and enrichment fee",
  },
  {
    name: "Daycare",
    description: "Per-child hourly daycare plan",
  },
];

async function ensureDefaultFeeCategories(
  svc: SupabaseClient,
  school: string,
) {
  const { count, error } = await svc.from("fee_categories").select("id", {
    count: "exact",
    head: true,
  }).eq("school_id", school);
  if (error) throw error;
  if ((count ?? 0) > 0) return;

  const { error: insertError } = await svc.from("fee_categories").insert(
    defaultFeeCategories.map((category) => ({
      school_id: school,
      ...category,
      is_active: true,
    })),
  );
  if (insertError) throw insertError;
}

function invoiceFeeType(invoice: Record<string, unknown>) {
  const items = Array.isArray(invoice.fee_invoice_items)
    ? invoice.fee_invoice_items
    : [];
  for (const item of items) {
    if (item && typeof item === "object") {
      const categoryName = text(
        (item as Record<string, unknown>).category_name,
      );
      if (categoryName) return normalizeFeeType(categoryName);
    }
  }
  const direct = normalizeFeeType(invoice.fee_type, "");
  if (direct) return direct;
  return "tuition";
}

function invoiceComponentLabel(invoice: Record<string, unknown>) {
  const items = Array.isArray(invoice.fee_invoice_items)
    ? invoice.fee_invoice_items
    : [];
  for (const item of items) {
    if (item && typeof item === "object") {
      const categoryName = text(
        (item as Record<string, unknown>).category_name,
      );
      if (categoryName) return categoryName;
    }
  }
  return invoiceFeeType(invoice) === "tuition" ? "Tuition Fee" : "One-time Fee";
}

function decorateInvoice(invoice: Record<string, unknown>) {
  return {
    ...invoice,
    fee_type: invoiceFeeType(invoice),
    fee_item_name: text(invoice.fee_item_name, invoiceComponentLabel(invoice)),
    balance: money(invoice.balance ?? invoice.net_amount ?? invoice.total_amount),
  };
}

function validateInvoicePaymentAmount(
  invoice: Record<string, unknown>,
  requestedAmount: unknown,
) {
  const balance = money(
    invoice.balance ?? invoice.net_amount ?? invoice.total_amount,
  );
  if (balance <= 0) throw new Error("This fee has already been fully paid");
  const amount = money(requestedAmount);
  if (amount > 0) {
    if (amount > balance) {
      throw new Error(
        `payment amount cannot exceed the remaining balance of ${balance.toFixed(2)}`,
      );
    }
    return { amount };
  }
  throw new Error("payment amount must be greater than zero");
}

function dueDateFrom(dueDate: unknown, dueDay: unknown) {
  const explicit = text(dueDate);
  if (explicit) return explicit.split("T")[0];
  const now = new Date();
  const day = Math.min(Math.max(parseInt(text(dueDay, "10")), 1), 28);
  return `${now.getUTCFullYear()}-${
    `${now.getUTCMonth() + 1}`.padStart(2, "0")
  }-${`${day}`.padStart(2, "0")}`;
}

async function parentCanAccessStudent(
  svc: SupabaseClient,
  school: string,
  user: User,
  studentId: string,
) {
  if (isAdminOrPrincipal(user)) return true;
  const { data, error } = await svc.from("parent_student_links").select("id")
    .eq("school_id", school)
    .eq("parent_user_id", user.id)
    .eq("student_id", studentId)
    .maybeSingle();
  if (error) throw error;
  return Boolean(data);
}

function configRecordId(scope: string, gradeId = "", sectionId = ""): string {
  return [scope || "school", gradeId, sectionId].filter(Boolean).join(":");
}

async function loadPaymentConfigRecord(
  svc: SupabaseClient,
  school: string,
  recordId: string,
) {
  const { data, error } = await svc.from("frontend_records").select("*").eq(
    "school_id",
    school,
  ).eq("table_name", "payment_config").eq("record_id", recordId).maybeSingle();
  if (error) throw error;
  return data;
}

async function savePaymentConfigRecord(
  svc: SupabaseClient,
  school: string,
  recordId: string,
  payload: Record<string, unknown>,
) {
  const existing = await loadPaymentConfigRecord(svc, school, recordId);
  const merged = {
    ...((existing?.data as Record<string, unknown> | null) ?? {}),
    ...payload,
  };
  if (existing != null) {
    const { data, error } = await svc.from("frontend_records").update({
      data: merged,
      updated_at: new Date().toISOString(),
    }).eq("id", existing.id).eq("school_id", school).select().single();
    if (error) throw error;
    return data;
  }
  const { data, error } = await svc.from("frontend_records").insert({
    school_id: school,
    table_name: "payment_config",
    record_id: recordId,
    data: merged,
  }).select().single();
  if (error) throw error;
  return data;
}

async function resolveScopedPaymentConfig(
  svc: SupabaseClient,
  school: string,
  invoiceId: string,
) {
  if (!invoiceId) {
    return await loadPaymentConfigRecord(svc, school, configRecordId("school"));
  }
  const { data: invoice, error: invoiceError } = await svc.from("fee_invoices")
    .select(
      "id, student_id",
    ).eq("school_id", school).eq("id", invoiceId).maybeSingle();
  if (invoiceError) throw invoiceError;
  if (!invoice) {
    return await loadPaymentConfigRecord(svc, school, configRecordId("school"));
  }
  const { data: student, error: studentError } = await svc.from("students")
    .select(
      "current_section_id",
    ).eq("school_id", school).eq("id", invoice.student_id).maybeSingle();
  if (studentError) throw studentError;
  const sectionId = text(student?.current_section_id);
  let gradeId = "";
  if (sectionId) {
    const { data: section, error: sectionError } = await svc.from("sections")
      .select(
        "id, grade_id",
      ).eq("school_id", school).eq("id", sectionId).maybeSingle();
    if (sectionError) throw sectionError;
    gradeId = text(section?.grade_id);
  }
  const candidates = [
    sectionId && gradeId ? configRecordId("section", gradeId, sectionId) : "",
    gradeId ? configRecordId("grade", gradeId) : "",
    configRecordId("school"),
  ].filter(Boolean);
  for (const recordId of candidates) {
    const data = await loadPaymentConfigRecord(svc, school, recordId);
    const config = data?.data as Record<string, unknown> | null;
    const isEnabled = config?.upi_enabled !== false;
    const hasPaymentDestination = Boolean(
      text(config?.upi_id) || text(config?.qr_image_url),
    );
    // An empty or disabled section/grade record must not hide a valid
    // school-wide payment destination from parents.
    if (config && isEnabled && hasPaymentDestination) return data;
  }
  return null;
}

async function attachFeeCategories(
  svc: SupabaseClient,
  school: string,
  rows: Record<string, unknown>[],
) {
  const categoryIds = [
    ...new Set(
      rows.map((row) => text(row.fee_category_id ?? row.category_id)).filter(
        Boolean,
      ),
    ),
  ];
  if (categoryIds.length === 0) {
    return rows.map((row) => ({ ...row, category: null, fee_category: null }));
  }
  const { data, error } = await svc.from("fee_categories").select("*")
    .eq("school_id", school)
    .in("id", categoryIds);
  if (error) throw error;
  const byId = new Map(
    (data ?? []).map((category: Record<string, unknown>) => [
      text(category.id),
      category,
    ]),
  );
  return rows.map((row) => {
    const category = byId.get(text(row.fee_category_id ?? row.category_id)) ??
      null;
    const categoryName = text(
      category?.category_name ?? category?.name ?? row.category_name,
      "Fee",
    );
    return {
      ...row,
      category,
      fee_category: category,
      category_name: categoryName,
      fee_item_name: categoryName,
    };
  });
}

async function attachStructureAssignmentStats(
  svc: SupabaseClient,
  school: string,
  rows: Record<string, unknown>[],
) {
  const structureIds = rows.map((row) => text(row.id)).filter(Boolean);
  if (structureIds.length === 0) return rows;

  const [sectionsResult, studentsResult, invoicesResult] = await Promise.all([
    svc.from("sections").select("id, grade_id, academic_year_id").eq(
      "school_id",
      school,
    ),
    svc.from("students").select("id, current_section_id").eq(
      "school_id",
      school,
    ).eq("status", "active"),
    svc.from("fee_invoices").select("fee_structure_id, student_id").eq(
      "school_id",
      school,
    ).in("fee_structure_id", structureIds),
  ]);
  if (sectionsResult.error) throw sectionsResult.error;
  if (studentsResult.error) throw studentsResult.error;
  if (invoicesResult.error) throw invoicesResult.error;

  const sectionById = new Map(
    (sectionsResult.data ?? []).map((section: Record<string, unknown>) => [
      text(section.id),
      section,
    ]),
  );
  const activeStudents = studentsResult.data ?? [];
  const invoiceStudentsByStructure = new Map<string, Set<string>>();
  for (const invoice of invoicesResult.data ?? []) {
    const structureId = text(invoice.fee_structure_id);
    const studentId = text(invoice.student_id);
    if (!structureId || !studentId) continue;
    const studentIds = invoiceStudentsByStructure.get(structureId) ??
      new Set<string>();
    studentIds.add(studentId);
    invoiceStudentsByStructure.set(structureId, studentIds);
  }

  return rows.map((row) => {
    const structureId = text(row.id);
    const gradeId = text(row.grade_id);
    const academicYearId = text(row.academic_year_id);
    const sectionId = text(row.section_id);
    const eligibleStudentIds = new Set(
      activeStudents.filter((student: Record<string, unknown>) => {
        const studentSectionId = text(student.current_section_id);
        const section = sectionById.get(studentSectionId);
        if (!section) return false;
        return text(section.grade_id) === gradeId &&
          text(section.academic_year_id) === academicYearId &&
          (!sectionId || studentSectionId === sectionId);
      }).map((student: Record<string, unknown>) => text(student.id)),
    );
    const invoicedStudentIds = invoiceStudentsByStructure.get(structureId) ??
      new Set<string>();
    const assignedCount = [...eligibleStudentIds].filter((studentId) =>
      invoicedStudentIds.has(studentId)
    ).length;
    return {
      ...row,
      eligible_student_count: eligibleStudentIds.size,
      invoiced_student_count: assignedCount,
      missing_invoice_count: Math.max(
        0,
        eligibleStudentIds.size - assignedCount,
      ),
    };
  });
}

async function attachPaymentRequestRelations(
  svc: SupabaseClient,
  school: string,
  rows: Record<string, unknown>[],
) {
  const invoiceIds = [
    ...new Set(rows.map((row) => text(row.invoice_id)).filter(Boolean)),
  ];
  const studentIds = [
    ...new Set(rows.map((row) => text(row.student_id)).filter(Boolean)),
  ];
  const parentIds = [
    ...new Set(rows.map((row) => text(row.parent_user_id)).filter(Boolean)),
  ];

  const invoicesById = new Map<string, Record<string, unknown>>();
  const studentsById = new Map<string, Record<string, unknown>>();
  const parentsById = new Map<string, Record<string, unknown>>();
  const receiptsById = new Map<string, Record<string, unknown>>();
  const receiptIds = [
    ...new Set(rows.map((row) => text(row.receipt_id)).filter(Boolean)),
  ];

  if (invoiceIds.length) {
    const { data, error } = await svc.from("fee_invoices").select("*")
      .eq("school_id", school)
      .in("id", invoiceIds);
    if (error) throw error;
    for (const row of data ?? []) invoicesById.set(text(row.id), row);
  }

  if (studentIds.length) {
    const { data, error } = await svc.from("students").select("*")
      .eq("school_id", school)
      .in("id", studentIds);
    if (error) throw error;
    for (const row of data ?? []) studentsById.set(text(row.id), row);
  }

  if (parentIds.length) {
    const { data, error } = await svc.from("users").select("*")
      .eq("school_id", school)
      .in("id", parentIds);
    if (error) throw error;
    for (const row of data ?? []) parentsById.set(text(row.id), row);
  }

  if (receiptIds.length) {
    const { data, error } = await svc.from("fee_receipts").select("*")
      .eq("school_id", school)
      .in("id", receiptIds);
    if (error) throw error;
    for (const row of data ?? []) receiptsById.set(text(row.id), row);
  }

  return await Promise.all(rows.map(async (row) => {
    const storedProof = text(row.proof_url);
    const proofPath = storedProof.startsWith("payment-proofs/")
      ? storedProof.slice("payment-proofs/".length)
      : storedProof;
    const proofUrl = storedProof
      ? (await svc.storage.from("payment-proofs").createSignedUrl(
        proofPath,
        10 * 60,
      )).data?.signedUrl ?? ""
      : "";
    return {
      ...row,
      proof_url: proofUrl,
      invoice: invoicesById.get(text(row.invoice_id)) ?? null,
      student: studentsById.get(text(row.student_id)) ?? null,
      parent_user: parentsById.get(text(row.parent_user_id)) ?? null,
      receipt: receiptsById.get(text(row.receipt_id)) ?? null,
    };
  }));
}

async function uploadPrivatePaymentProof(
  svc: SupabaseClient,
  school: string,
  requestId: string,
  file: File,
) {
  const path = `${school}/${requestId}/${Date.now()}-${file.name}`;
  const { error } = await svc.storage.from("payment-proofs").upload(
    path,
    file,
    { upsert: false },
  );
  if (error) throw error;
  return `payment-proofs/${path}`;
}

async function invoiceIdsForFeeStructure(
  svc: SupabaseClient,
  school: string,
  structureId: string,
) {
  const ids = new Set<string>();

  // 1. Direct link: fee_invoices.fee_structure_id = structureId
  const direct = await svc.from("fee_invoices").select("id").eq(
    "school_id",
    school,
  ).eq("fee_structure_id", structureId);
  if (direct.error) throw new Error(direct.error.message);
  for (const row of direct.data ?? []) ids.add(text(row.id));

  // 2. Indirect link via fee_invoice_items
  const items = await svc.from("fee_invoice_items").select("invoice_id").eq(
    "fee_structure_id",
    structureId,
  );
  if (items.error) throw new Error(items.error.message);
  for (const row of items.data ?? []) {
    const invoiceId = text(row.invoice_id);
    if (invoiceId) ids.add(invoiceId);
  }

  // 3. Scope-based fallback: find orphaned invoices that belong to the same
  //    academic_year + students in the fee structure's grade/section but were
  //    created without a fee_structure_id link (e.g. via the payment request flow).
  //    Only include unpaid invoices so we don't destroy payment history.
  const { data: structure } = await svc.from("fee_structures")
    .select("academic_year_id, grade_id, section_id")
    .eq("id", structureId).eq("school_id", school).maybeSingle();
  if (structure) {
    // Find student IDs in the matching grade/section
    let studentQuery = svc.from("students")
      .select("id")
      .eq("school_id", school)
      .eq("status", "active");
    if (structure.section_id) {
      studentQuery = studentQuery.eq(
        "current_section_id",
        structure.section_id,
      );
    } else if (structure.grade_id) {
      const { data: sections } = await svc.from("sections")
        .select("id")
        .eq("school_id", school).eq("grade_id", structure.grade_id);
      const sectionIds = (sections ?? []).map((s: Record<string, unknown>) =>
        text(s.id)
      ).filter(Boolean);
      if (sectionIds.length > 0) {
        studentQuery = studentQuery.in("current_section_id", sectionIds);
      }
    }
    const { data: students } = await studentQuery;
    const studentIds = (students ?? []).map((s: Record<string, unknown>) =>
      text(s.id)
    ).filter(Boolean);

    if (studentIds.length > 0) {
      // Find orphaned invoices: same academic year, same students, no fee_structure_id, not fully paid
      const { data: orphaned } = await svc.from("fee_invoices")
        .select("id")
        .eq("school_id", school)
        .eq("academic_year_id", text(structure.academic_year_id))
        .in("student_id", studentIds)
        .neq("status", "paid")
        .is("fee_structure_id", null);
      for (const row of orphaned ?? []) {
        ids.add(text(row.id));
      }
    }
  }

  return [...ids].filter(Boolean);
}

type FeeInvoiceSyncRow = {
  invoice: Record<string, unknown>;
  nextTotal: number;
  nextNet: number;
  nextBalance: number;
  nextStatus: string;
  feeType: string;
  billingMode: string;
  priority: number;
  categoryName: string;
};

async function feeInvoiceSyncPlan(
  svc: SupabaseClient,
  school: string,
  structureId: string,
  includePartiallyPaid: boolean,
) {
  const { data: structure, error: structureError } = await svc.from(
    "fee_structures",
  ).select("*").eq("id", structureId).eq("school_id", school).maybeSingle();
  if (structureError) throw new Error(structureError.message);
  if (!structure) throw new Error("Fee structure not found");

  const hydrated =
    (await attachFeeCategories(svc, school, [structure]))[0] as Record<
      string,
      unknown
    >;
  const category = hydrated.fee_category &&
      typeof hydrated.fee_category === "object"
    ? hydrated.fee_category as Record<string, unknown>
    : hydrated.category && typeof hydrated.category === "object"
    ? hydrated.category as Record<string, unknown>
    : {};
  const feeType = normalizeFeeType(
    hydrated.fee_type ?? category.name ?? category.category_name,
  );
  const billingMode = feeType === "tuition" ? "monthly" : "one_time";
  const priority = parseInt(
    text(hydrated.priority, feeType === "tuition" ? "2" : "1"),
  ) || (feeType === "tuition" ? 2 : 1);
  const categoryName = text(
    category.name ?? category.category_name,
    feeType === "tuition" ? "Tuition Fee" : "Fee",
  );
  const nextTotal = money(hydrated.amount);

  // Sync only invoices explicitly linked to this structure. Scope-based
  // orphan matching is intentionally excluded here because a class may have
  // several fee components and an orphan cannot be attributed safely.
  const direct = await svc.from("fee_invoices").select("id").eq(
    "school_id",
    school,
  ).eq("fee_structure_id", structureId);
  if (direct.error) throw new Error(direct.error.message);
  const itemLinks = await svc.from("fee_invoice_items").select("invoice_id")
    .eq("fee_structure_id", structureId);
  if (itemLinks.error) throw new Error(itemLinks.error.message);
  const invoiceIds = [
    ...new Set([
      ...(direct.data ?? []).map((row) => text(row.id)),
      ...(itemLinks.data ?? []).map((row) => text(row.invoice_id)),
    ].filter(Boolean)),
  ];

  if (invoiceIds.length === 0) {
    return {
      structure: hydrated,
      eligible: [] as FeeInvoiceSyncRow[],
      skippedPaid: 0,
      skippedPartial: 0,
      skippedBelowPaid: 0,
    };
  }

  const { data: invoices, error: invoiceError } = await svc.from(
    "fee_invoices",
  ).select("*").eq("school_id", school).in("id", invoiceIds);
  if (invoiceError) throw new Error(invoiceError.message);

  const eligible: FeeInvoiceSyncRow[] = [];
  let skippedPaid = 0;
  let skippedPartial = 0;
  let skippedBelowPaid = 0;
  for (const invoice of invoices ?? []) {
    const status = text(invoice.status).toLowerCase();
    const paidAmount = money(invoice.paid_amount);
    if (["paid", "settled", "void", "cancelled"].includes(status)) {
      skippedPaid++;
      continue;
    }
    if (paidAmount > 0 && !includePartiallyPaid) {
      skippedPartial++;
      continue;
    }
    const discount = money(invoice.discount_amount);
    const proposedNet = Math.max(0, money(nextTotal - discount));
    if (proposedNet < paidAmount) {
      skippedBelowPaid++;
      continue;
    }
    const nextBalance = money(proposedNet - paidAmount);
    const nextStatus = nextBalance <= 0
      ? "paid"
      : paidAmount > 0
      ? "partial"
      : "pending";
    eligible.push({
      invoice,
      nextTotal,
      nextNet: proposedNet,
      nextBalance,
      nextStatus,
      feeType,
      billingMode,
      priority,
      categoryName,
    });
  }
  return {
    structure: hydrated,
    eligible,
    skippedPaid,
    skippedPartial,
    skippedBelowPaid,
  };
}

async function applyFeeInvoiceSyncPlan(
  svc: SupabaseClient,
  school: string,
  structureId: string,
  rows: FeeInvoiceSyncRow[],
) {
  let synced = 0;
  for (const row of rows) {
    const invoiceId = text(row.invoice.id);
    const invoiceUpdate = await svc.from("fee_invoices").update({
      total_amount: row.nextTotal,
      net_amount: row.nextNet,
      balance: row.nextBalance,
      status: row.nextStatus,
      fee_type: row.feeType,
      billing_mode: row.billingMode,
      priority: row.priority,
      updated_at: new Date().toISOString(),
    }).eq("id", invoiceId).eq("school_id", school);
    if (invoiceUpdate.error) throw new Error(invoiceUpdate.error.message);

    const itemUpdate = await svc.from("fee_invoice_items").update({
      amount: row.nextTotal,
      category_name: row.categoryName,
    }).eq("invoice_id", invoiceId).eq("fee_structure_id", structureId);
    if (itemUpdate.error) throw new Error(itemUpdate.error.message);
    synced++;
  }
  return synced;
}

async function deleteInvoiceWorkflowRows(
  svc: SupabaseClient,
  school: string,
  invoiceIds: string[],
) {
  return {
    retained_invoices: invoiceIds.length,
    retained_receipts: 0,
    retained_payments: 0,
    retained_requests: 0,
    reason: "Financial history is immutable; archive the structure instead.",
  };
}

async function deleteFeeStructureWorkflowRows(
  svc: SupabaseClient,
  school: string,
  structureId: string,
) {
  const { data, error } = await svc.from("fee_structures").update({
    archived_at: new Date().toISOString(),
    is_active: false,
    updated_at: new Date().toISOString(),
  }).eq("id", structureId).eq("school_id", school).select("id").maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error("Fee structure not found");
  return { archived_structure_id: structureId, deleted_invoices: 0 };
}

/**
 * Queues reviewed, principal-triggered reminders.  The delivery table is the
 * source of truth for the one-day per-parent/invoice cooldown; notification
 * events remain the existing FCM processor input rather than a second push
 * implementation.
 */
async function queueManualFeeReminders(
  svc: SupabaseClient,
  school: string,
  requestedInvoiceIds: string[],
  customMessage: string,
  createdBy: string,
) {
  const today = new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Kolkata",
  });
  const uniqueIds = [...new Set(requestedInvoiceIds.filter(Boolean))];
  const result = {
    eligible_invoices: 0,
    queued: 0,
    skipped_cooldown: 0,
    unavailable_recipients: 0,
    skipped_settled: 0,
  };
  if (uniqueIds.length === 0) return result;

  const { data: invoices, error: invoiceError } = await svc.from(
    "fee_invoices",
  ).select("*, student:students(first_name, last_name)")
    .eq("school_id", school)
    .in("id", uniqueIds);
  if (invoiceError) throw new Error(invoiceError.message);

  const eventIds: string[] = [];
  for (const invoice of invoices ?? []) {
    const balance = money(invoice.balance);
    if (balance <= 0 || ["paid", "settled", "void", "cancelled"].includes(
      text(invoice.status).toLowerCase(),
    )) {
      result.skipped_settled++;
      continue;
    }
    result.eligible_invoices++;
    const invoiceId = text(invoice.id);
    const studentId = text(invoice.student_id);
    const { data: links, error: linkError } = await svc.from(
      "parent_student_links",
    ).select("parent_user_id").eq("school_id", school).eq(
      "student_id",
      studentId,
    );
    if (linkError) throw new Error(linkError.message);
    const parentIds = [...new Set((links ?? []).map((link) =>
      text(link.parent_user_id)
    ).filter(Boolean))];
    if (parentIds.length === 0) {
      result.unavailable_recipients++;
      continue;
    }
    const student = invoice.student as Record<string, unknown> | null;
    const studentName = student
      ? `${text(student.first_name)} ${text(student.last_name)}`.trim()
      : "your child";
    const dueDate = text(invoice.due_date).split("T")[0];
    const message = customMessage ||
      `Fee reminder for ${studentName}: ₹${balance.toFixed(0)} remains due${dueDate ? ` by ${dueDate}` : ""}.`;

    for (const parentId of parentIds) {
      const { data: delivery, error: deliveryError } = await svc.from(
        "fee_reminder_deliveries",
      ).insert({
        school_id: school,
        invoice_id: invoiceId,
        parent_user_id: parentId,
        stage: "manual",
        delivery_date: today,
        created_by: createdBy,
      }).select("id").maybeSingle();
      if (deliveryError) {
        // The unique delivery key is the cooldown.  Re-throw every real
        // database error so a broken reminder system is visible to staff.
        if (deliveryError.code === "23505") {
          result.skipped_cooldown++;
          continue;
        }
        throw new Error(deliveryError.message);
      }
      if (!delivery) {
        result.skipped_cooldown++;
        continue;
      }
      const { data: event, error: eventError } = await svc.from(
        "notification_events",
      ).insert({
        school_id: school,
        user_id: parentId,
        event_type: "fee_due",
        event_data: {
          invoice_id: invoiceId,
          student_id: studentId,
          balance,
          due_date: dueDate,
          message,
          stage: "manual",
          reference_type: "fee",
          reference_id: invoiceId,
          route: "/parent-fees-screen",
        },
        processed: false,
      }).select("id").single();
      if (eventError) throw new Error(eventError.message);
      const { error: deliveryUpdateError } = await svc.from(
        "fee_reminder_deliveries",
      ).update({ notification_event_id: event.id }).eq("id", delivery.id);
      if (deliveryUpdateError) throw new Error(deliveryUpdateError.message);
      const { error: logError } = await svc.from("notification_logs").insert({
        school_id: school,
        user_id: parentId,
        title: "Fee payment reminder",
        body: message,
        type: "fee",
        entity_type: "fee_invoice",
        entity_id: invoiceId,
        reference_type: "fee",
        reference_id: invoiceId,
        route: "/parent-fees-screen",
        student_id: studentId,
        is_read: false,
      });
      if (logError) throw new Error(logError.message);
      eventIds.push(text(event.id));
      result.queued++;
    }
  }
  if (eventIds.length > 0) triggerPushProcessing(eventIds);
  return result;
}

export async function handleFees(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const contentType = req.headers.get("content-type") ?? "";
  const body = method !== "GET" && contentType.includes("application/json")
    ? await req.json().catch(() => ({}))
    : {};
  const feesPath = path.replace(/^\/fees/, "");
  const isParent = roleName(user) === "parent";

  // Fee setup, invoice generation, cash collection, reports, concessions and
  // payment configuration are school-finance operations. Parents only use the
  // child-scoped invoice and manual UPI proof endpoints further below.
  const isParentPaymentAction = [
    "/payments/intent",
    "/payments/request",
    "/payments/submit",
  ].includes(feesPath) ||
    /^\/payments\/[^/]+\/resubmit$/.test(feesPath);
  const requestedInvoiceStudentId = text(url.searchParams.get("student_id"));
  let isParentLinkedInvoiceRead = false;
  if (isParent && method === "GET" && feesPath === "/invoices") {
    if (!requestedInvoiceStudentId) {
      return fail("parent invoice access requires a linked student", 403);
    }
    try {
      if (
        !await parentCanAccessStudent(
          svc,
          school,
          user,
          requestedInvoiceStudentId,
        )
      ) {
        return fail("Student does not belong to a linked child", 403);
      }
      isParentLinkedInvoiceRead = true;
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "failed to verify parent access",
      );
    }
  }
  const isFinanceManagementPath = path.startsWith("/fee-categories") ||
    path.startsWith("/fee-structures") ||
    path.startsWith("/fee-invoices") ||
    path.startsWith("/fee-concessions") ||
    path === "/invoices" ||
    path.startsWith("/fee-payments") ||
    path === "/payments" ||
    feesPath.startsWith("/categories") ||
    feesPath.startsWith("/structures") ||
    feesPath.startsWith("/invoices") ||
    (feesPath.startsWith("/payments") && !isParentPaymentAction) ||
    feesPath.startsWith("/daycare-plans") ||
    feesPath.startsWith("/concessions") ||
    feesPath.startsWith("/reminders") ||
    feesPath.startsWith("/payment-configs") ||
    (feesPath === "/payment-config" && method !== "GET") ||
    feesPath === "/reports/exports";
  if (
    isFinanceManagementPath && !isAdminOrPrincipal(user) &&
    !isParentLinkedInvoiceRead
  ) {
    return fail("principal access required", 403);
  }
  if (isParentPaymentAction && !isParent) {
    return fail("only parents can submit manual UPI payment proofs", 403);
  }

  if (feesPath === "/reports/exports" && method === "POST") {
    try {
      const data = await queueReportExport(
        svc,
        school,
        user,
        "fee_report_exports",
        body,
      );
      return ok(data);
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "failed to queue fee report export",
      );
    }
  }

  if (feesPath === "/reports/exports" && method === "GET") {
    const { data, error } = await svc.from("frontend_records").select("*")
      .eq("school_id", school).eq("table_name", "fee_report_exports")
      .order("updated_at", { ascending: false });
    if (error) return fail(error.message);
    return ok((data ?? []).map((row: Record<string, unknown>) => {
      const payload = typeof row.data === "object" && row.data !== null
        ? row.data as Record<string, unknown>
        : row;
      return { ...payload, id: payload.id ?? row.id ?? row.record_id };
    }));
  }

  function normalizeCategoryPayload(input: Record<string, unknown>) {
    return {
      school_id: school,
      name: input.name ?? input.category_name ?? "",
      description: input.description ?? input.frequency ?? "",
      is_active: input.is_active ?? true,
    };
  }

  function normalizeStructurePayload(input: Record<string, unknown>) {
    const categoryId = input.category_id ?? input.fee_category_id;
    const feeType = normalizeFeeType(
      input.fee_type ?? input.category_name ?? input.name,
    );
    const normalizedFrequency = feeType === "tuition" ||
        feeType === "daycare_hourly"
      ? "monthly"
      : normalizeFrequency(input.frequency ?? input.billing_mode);
    return {
      school_id: school,
      academic_year_id: input.academic_year_id,
      grade_id: input.grade_id ?? null,
      section_id: input.section_id ?? null,
      category_id: categoryId,
      fee_category_id: categoryId,
      amount: input.amount ?? 0,
      due_date: input.due_date ?? null,
      due_day: input.due_day ?? 10,
      late_fine_per_day: input.late_fine_per_day ?? 0,
      frequency: normalizedFrequency,
      fee_type: feeType,
      billing_mode: feeType === "tuition" || feeType === "daycare_hourly"
        ? "monthly"
        : text(input.billing_mode, "one_time"),
      priority:
        parseInt(text(input.priority, feeType === "tuition" ? "2" : "1")) ||
        (feeType === "tuition" ? 2 : 1),
      is_mandatory: input.is_mandatory ?? input.is_active ?? true,
    };
  }

  if (
    path.startsWith("/fee-categories") || feesPath.startsWith("/categories")
  ) {
    const base = path.startsWith("/fee-categories")
      ? "/fee-categories"
      : "/fees/categories";
    const seg = path.slice(base.length).split("/").filter(Boolean)[0];
    if (!seg && method === "GET") {
      // A new school can begin fee setup as soon as it has an academic year
      // and classes. Supply the small standard category baseline once, while
      // preserving every category that the school has already configured.
      if (isAdminOrPrincipal(user)) {
        try {
          await ensureDefaultFeeCategories(svc, school);
        } catch (error) {
          return fail(
            error instanceof Error
              ? error.message
              : "failed to prepare default fee categories",
          );
        }
      }
      const { data, error } = await svc.from("fee_categories").select("*").eq(
        "school_id",
        school,
      );
      if (error) return fail(error.message);
      return ok(data ?? []);
    }
    if (!seg && method === "POST") {
      const { data, error } = await svc.from("fee_categories").insert(
        normalizeCategoryPayload(body as Record<string, unknown>),
      ).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (seg && (method === "PATCH" || method === "PUT")) {
      const { school_id: _ignored, ...payload } = normalizeCategoryPayload(
        body as Record<string, unknown>,
      );
      const { data, error } = await svc.from("fee_categories").update({
        ...payload,
        updated_at: new Date().toISOString(),
      }).eq("id", seg).eq("school_id", school).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (seg && method === "DELETE") {
      const { error } = await svc.from("fee_categories").update({
        is_active: false,
        archived_at: new Date().toISOString(),
        archived_by: user.id,
        updated_at: new Date().toISOString(),
      }).eq("id", seg).eq("school_id", school);
      if (error) return fail(error.message);
      return ok({ success: true, archived_category_id: seg });
    }
  }

  if (
    path.startsWith("/fee-structures") || feesPath.startsWith("/structures")
  ) {
    const base = path.startsWith("/fee-structures")
      ? "/fee-structures"
      : "/fees/structures";
    const remainder = path.slice(base.length);
    const parts = remainder.split("/").filter(Boolean);
    const seg = parts[0];

    if (!seg && method === "GET") {
      let q = svc.from("fee_structures").select(
        "*, grade:grades(*), section:sections(*)",
      ).eq("school_id", school);
      if (url.searchParams.get("academic_year_id")) {
        q = q.eq("academic_year_id", url.searchParams.get("academic_year_id")!);
      }
      if (url.searchParams.get("grade_id")) {
        q = q.eq("grade_id", url.searchParams.get("grade_id")!);
      }
      if (url.searchParams.get("section_id")) {
        q = q.eq("section_id", url.searchParams.get("section_id")!);
      }
      const { data, error } = await q;
      if (error) return fail(error.message);
      try {
        const categorized = await attachFeeCategories(svc, school, data ?? []);
        return ok(
          await attachStructureAssignmentStats(svc, school, categorized),
        );
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to load fee categories",
        );
      }
    }

    if (!seg && method === "POST") {
      const { data, error } = await svc.from("fee_structures").insert(
        normalizeStructurePayload(body as Record<string, unknown>),
      ).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }

    if (seg === "rollover" && method === "POST") {
      const fromYear = body.from_academic_year_id;
      const toYear = body.to_academic_year_id;
      if (!fromYear || !toYear) {
        return fail(
          "from_academic_year_id and to_academic_year_id are required",
        );
      }

      const { data: sourceStructures, error: fetchErr } = await svc
        .from("fee_structures")
        .select("*")
        .eq("school_id", school)
        .eq("academic_year_id", fromYear);
      if (fetchErr) return fail(fetchErr.message);

      const { data: targetStructures, error: targetErr } = await svc
        .from("fee_structures")
        .select("grade_id, section_id, category_id")
        .eq("school_id", school)
        .eq("academic_year_id", toYear);
      if (targetErr) return fail(targetErr.message);

      const targetSet = new Set(
        (targetStructures ?? []).map(
          (s) => `${s.grade_id}_${s.section_id}_${s.category_id}`,
        ),
      );

      const toInsert: Record<string, unknown>[] = [];
      let skippedCount = 0;

      for (const src of sourceStructures ?? []) {
        const key = `${src.grade_id}_${src.section_id}_${src.category_id}`;
        if (targetSet.has(key)) {
          skippedCount++;
          continue;
        }
        toInsert.push({
          school_id: school,
          academic_year_id: toYear,
          grade_id: src.grade_id,
          section_id: src.section_id,
          category_id: src.category_id,
          amount: src.amount,
          frequency: src.frequency,
          is_mandatory: src.is_mandatory,
          due_date: src.due_date,
        });
      }

      let copiedCount = 0;
      if (toInsert.length > 0) {
        const { error: insertErr } = await svc.from("fee_structures").insert(
          toInsert,
        );
        if (insertErr) return fail(insertErr.message);
        copiedCount = toInsert.length;
      }

      return ok({
        copied_count: copiedCount,
        skipped_count: skippedCount,
        from_academic_year_id: fromYear,
        to_academic_year_id: toYear,
      });
    }

    if (
      seg && parts[1] === "invoice-sync" && parts[2] === "preview" &&
      method === "POST"
    ) {
      const includePartiallyPaid = body.include_partially_paid === true;
      try {
        const plan = await feeInvoiceSyncPlan(
          svc,
          school,
          seg,
          includePartiallyPaid,
        );
        return ok({
          structure_id: seg,
          structure: plan.structure,
          affected_invoice_count: plan.eligible.length,
          skipped_paid_count: plan.skippedPaid,
          skipped_partial_count: plan.skippedPartial,
          skipped_below_paid_count: plan.skippedBelowPaid,
          include_partially_paid: includePartiallyPaid,
          mode: "preview",
        });
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to preview invoice sync",
        );
      }
    }

    if (
      seg && parts[1] === "invoice-sync" && parts[2] === "apply" &&
      method === "POST"
    ) {
      const includePartiallyPaid = body.include_partially_paid === true;
      try {
        const plan = await feeInvoiceSyncPlan(
          svc,
          school,
          seg,
          includePartiallyPaid,
        );
        const synced = await applyFeeInvoiceSyncPlan(
          svc,
          school,
          seg,
          plan.eligible,
        );
        return ok({
          structure_id: seg,
          synced_invoice_count: synced,
          skipped_paid_count: plan.skippedPaid,
          skipped_partial_count: plan.skippedPartial,
          skipped_below_paid_count: plan.skippedBelowPaid,
          include_partially_paid: includePartiallyPaid,
          mode: "apply",
        });
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to apply invoice sync",
        );
      }
    }

    if (seg && method === "PUT") {
      const { school_id: _ignored, ...payload } = normalizeStructurePayload(
        body as Record<string, unknown>,
      );
      const { data, error } = await svc.from("fee_structures").update({
        ...payload,
        updated_at: new Date().toISOString(),
      }).eq("id", seg).eq("school_id", school).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }

    if (seg && method === "DELETE") {
      try {
        const archived = await deleteFeeStructureWorkflowRows(svc, school, seg);
        return ok({ success: true, ...archived });
      } catch (error) {
        return fail(error instanceof Error ? error.message : "failed to archive fee structure");
      }
    }
  }

  if (feesPath.startsWith("/daycare-plans")) {
    const segments = feesPath.split("/").filter(Boolean);
    const planId = segments[1] ?? "";
    const today = new Date().toLocaleDateString("en-CA", {
      timeZone: "Asia/Kolkata",
    });

    if (!planId && method === "GET") {
      let query = svc.from("daycare_fee_plans").select(
        "*, student:students(first_name, last_name, admission_number), fee_structure:fee_structures(id, fee_type, due_day, academic_year_id)",
      ).eq("school_id", school).order("effective_from", { ascending: false });
      if (url.searchParams.get("student_id")) {
        query = query.eq("student_id", url.searchParams.get("student_id")!);
      }
      if (url.searchParams.get("active") === "true") {
        query = query.eq("is_active", true).or(
          `effective_to.is.null,effective_to.gte.${today}`,
        );
      }
      const { data, error } = await query;
      if (error) return fail(error.message);
      const currentPeriod = `${today.slice(0, 7)}-01`;
      const planIds = (data ?? []).map((plan) => text(plan.id)).filter(Boolean);
      const { data: currentInvoices, error: invoiceError } = planIds.length === 0
        ? { data: [], error: null }
        : await svc.from("fee_invoices").select("id, student_id, fee_structure_id, billing_period, balance, status")
          .eq("school_id", school).eq("billing_period", currentPeriod)
          .in("fee_structure_id", [...new Set((data ?? []).map((plan) => text(plan.fee_structure_id))) ]);
      if (invoiceError) return fail(invoiceError.message);
      return ok((data ?? []).map((plan) => ({
        ...plan,
        current_period_invoice: (currentInvoices ?? []).find((invoice) =>
          text(invoice.student_id) === text(plan.student_id) &&
          text(invoice.fee_structure_id) === text(plan.fee_structure_id)
        ) ?? null,
      })));
    }

    if (!planId && method === "POST") {
      const studentId = text(body.student_id);
      const structureId = text(body.fee_structure_id);
      const academicYearId = text(body.academic_year_id);
      const hourlyRate = money(body.hourly_rate);
      const monthlyHours = money(body.contracted_hours_per_month);
      const effectiveFrom = text(body.effective_from, today);
      if (!studentId || !structureId || !academicYearId) {
        return fail("student_id, fee_structure_id, and academic_year_id are required");
      }
      if (hourlyRate <= 0 || monthlyHours <= 0) {
        return fail("hourly_rate and contracted_hours_per_month must be greater than zero");
      }
      const [{ data: student, error: studentError }, { data: structure, error: structureError }] = await Promise.all([
        svc.from("students").select("id").eq("id", studentId).eq("school_id", school).maybeSingle(),
        svc.from("fee_structures").select("id, academic_year_id, fee_type").eq("id", structureId).eq("school_id", school).maybeSingle(),
      ]);
      if (studentError) return fail(studentError.message);
      if (structureError) return fail(structureError.message);
      if (!student) return fail("Student not found", 404);
      if (!structure || text(structure.academic_year_id) !== academicYearId) {
        return fail("Daycare fee structure does not belong to this academic year", 400);
      }
      if (normalizeFeeType(structure.fee_type) !== "daycare_hourly") {
        return fail("Select a daycare hourly fee structure", 400);
      }
      const { data: existing, error: existingError } = await svc.from(
        "daycare_fee_plans",
      ).select("id, effective_from, effective_to, is_active").eq("school_id", school)
        .eq("student_id", studentId).eq("fee_structure_id", structureId).eq("is_active", true);
      if (existingError) return fail(existingError.message);
      const requestedStart = new Date(`${effectiveFrom}T00:00:00Z`).getTime();
      const overlaps = (existing ?? []).some((plan) => {
        const start = new Date(`${text(plan.effective_from)}T00:00:00Z`).getTime();
        const endRaw = text(plan.effective_to);
        const end = endRaw
          ? new Date(`${endRaw}T23:59:59Z`).getTime()
          : Number.POSITIVE_INFINITY;
        return requestedStart >= start && requestedStart <= end;
      });
      if (overlaps) return fail("An active daycare plan already covers this period", 409);
      const { data: plan, error: insertError } = await svc.from("daycare_fee_plans").insert({
        school_id: school,
        student_id: studentId,
        academic_year_id: academicYearId,
        fee_structure_id: structureId,
        hourly_rate: hourlyRate,
        contracted_hours_per_month: monthlyHours,
        effective_from: effectiveFrom,
        is_active: true,
        created_by: user.id,
      }).select().single();
      if (insertError) return fail(insertError.message);
      let currentInvoiceId: string | null = null;
      // A plan started today (or recorded late) receives the current period
      // only. Passing today deliberately avoids creating historical invoices.
      if (effectiveFrom <= today) {
        const { data: generated, error: generateError } = await svc.rpc(
          "ensure_daycare_invoice_for_plan",
          { p_plan_id: plan.id, p_period: today },
        );
        if (generateError) return fail(generateError.message);
        currentInvoiceId = text(generated) || null;
      }
      return ok({ ...plan, current_period_invoice_id: currentInvoiceId });
    }

    if (planId && method === "PUT") {
      const { data: previous, error: previousError } = await svc.from(
        "daycare_fee_plans",
      ).select("*").eq("id", planId).eq("school_id", school).maybeSingle();
      if (previousError) return fail(previousError.message);
      if (!previous) return fail("Daycare plan not found", 404);
      const nextMonth = new Date(Date.UTC(
        Number(today.slice(0, 4)),
        Number(today.slice(5, 7)),
        1,
      )).toISOString().slice(0, 10);
      const effectiveFrom = text(body.effective_from, nextMonth);
      if (effectiveFrom < nextMonth) {
        return fail("Daycare plan changes take effect from next month", 400);
      }
      const hourlyRate = money(body.hourly_rate ?? previous.hourly_rate);
      const monthlyHours = money(
        body.contracted_hours_per_month ?? previous.contracted_hours_per_month,
      );
      if (hourlyRate <= 0 || monthlyHours <= 0) {
        return fail("hourly_rate and contracted_hours_per_month must be greater than zero");
      }
      const previousEnd = new Date(`${effectiveFrom}T00:00:00Z`);
      previousEnd.setUTCDate(previousEnd.getUTCDate() - 1);
      const { error: closeError } = await svc.from("daycare_fee_plans").update({
        effective_to: previousEnd.toISOString().slice(0, 10),
        // It remains active through the end of its already-contracted period;
        // the date range (not a premature flag) prevents future invoices.
        is_active: true,
        updated_at: new Date().toISOString(),
      }).eq("id", planId).eq("school_id", school);
      if (closeError) return fail(closeError.message);
      const { data: replacement, error: replacementError } = await svc.from(
        "daycare_fee_plans",
      ).insert({
        school_id: school,
        student_id: previous.student_id,
        academic_year_id: previous.academic_year_id,
        fee_structure_id: previous.fee_structure_id,
        hourly_rate: hourlyRate,
        contracted_hours_per_month: monthlyHours,
        effective_from: effectiveFrom,
        is_active: true,
        created_by: user.id,
      }).select().single();
      if (replacementError) return fail(replacementError.message);
      return ok({ previous_plan_id: planId, replacement });
    }

    if (planId && (method === "PATCH" || method === "DELETE")) {
      const { data, error } = await svc.from("daycare_fee_plans").update({
        is_active: false,
        effective_to: today,
        updated_at: new Date().toISOString(),
      }).eq("id", planId).eq("school_id", school).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  if (
    path.startsWith("/fee-invoices") || path === "/invoices" ||
    feesPath.startsWith("/invoices")
  ) {
    const normalized = path.replace(/^\/fee-invoices/, "").replace(
      /^\/invoices/,
      "",
    ).replace(/^\/fees\/invoices/, "");
    const parts = normalized.split("/").filter(Boolean);
    const seg = parts[0];

    if (!seg && method === "GET") {
      const page = parseInt(url.searchParams.get("page") ?? "1");
      const size = parseInt(url.searchParams.get("page_size") ?? "50");
      let q = svc.from("fee_invoices").select(
        "*, student:students(first_name, last_name, admission_number, student_id_number, current_section:sections(id, section_name, grade:grades(id, grade_name))), fee_invoice_items(*), payments(*)",
        { count: "exact" },
      ).eq("school_id", school).range((page - 1) * size, page * size - 1);
      if (url.searchParams.get("student_id")) {
        q = q.eq("student_id", url.searchParams.get("student_id")!);
      }
      if (url.searchParams.get("status")) {
        q = q.eq("status", url.searchParams.get("status")!);
      }
      if (url.searchParams.get("academic_year_id")) {
        q = q.eq("academic_year_id", url.searchParams.get("academic_year_id")!);
      }
      const { data, error, count } = await q;
      if (error) return fail(error.message);
      return cors({
        success: true,
        data: (data ?? []).map((invoice: Record<string, unknown>) =>
          decorateInvoice(invoice)
        ),
        total: count ?? 0,
        page,
        page_size: size,
      });
    }

    if (seg === "generate" && method === "POST") {
      const academicYearId = text(body.academic_year_id);
      const gradeId = text(body.grade_id);
      const sectionId = text(body.section_id);
      const studentId = text(body.student_id);
      if (!academicYearId || !gradeId) {
        return fail("academic_year_id and grade_id are required");
      }

      let structuresQuery = svc.from("fee_structures").select("*")
        .eq("school_id", school)
        .eq("academic_year_id", academicYearId)
        .eq("grade_id", gradeId);
      if (sectionId) {
        structuresQuery = structuresQuery.or(
          `section_id.is.null,section_id.eq.${sectionId}`,
        );
      } else {
        // A grade-wide batch must never include a structure configured for a
        // different section of the same grade.
        structuresQuery = structuresQuery.is("section_id", null);
      }
      const { data: rawStructures, error: structuresError } =
        await structuresQuery;
      if (structuresError) return fail(structuresError.message);
      const includeOneTime = body.include_one_time === true;
      const includeYearly = body.include_yearly === true;
      let hydratedStructures: Record<string, unknown>[];
      try {
        hydratedStructures = await attachFeeCategories(
          svc,
          school,
          rawStructures ?? [],
        );
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to load fee categories",
        );
      }
      const structures = hydratedStructures.filter(
        (row: Record<string, unknown>) => {
          // Daycare invoices are created only from child-specific hourly
          // plans. A generic class invoice would lose the contracted-hours
          // snapshot and create an incorrect duplicate balance.
          if (normalizeFeeType(row.fee_type) === "daycare_hourly") {
            return false;
          }
          const frequency = normalizeFrequency(row.frequency);
          if (frequency === "one_time") return includeOneTime;
          if (frequency === "yearly") return includeYearly;
          return true;
        },
      );
      if (structures.length === 0) {
        return ok({
          created: 0,
          skipped: 0,
          generated_count: 0,
          skipped_count: 0,
        });
      }

      let sectionIds = sectionId ? [sectionId] : [];
      if (sectionIds.length === 0) {
        const { data: sections, error: sectionError } = await svc.from(
          "sections",
        ).select("id")
          .eq("school_id", school)
          .eq("grade_id", gradeId);
        if (sectionError) return fail(sectionError.message);
        sectionIds = (sections ?? []).map((section: Record<string, unknown>) =>
          text(section.id)
        ).filter(Boolean);
      }

      let studentsQuery = svc.from("students").select("*")
        .eq("school_id", school)
        .eq("status", "active");
      if (studentId) studentsQuery = studentsQuery.eq("id", studentId);
      else if (sectionIds.length > 0) {
        studentsQuery = studentsQuery.in("current_section_id", sectionIds);
      }
      const { data: students, error: studentsError } = await studentsQuery;
      if (studentsError) return fail(studentsError.message);

      const studentIds = (students ?? []).map((student) => text(student.id))
        .filter(Boolean);
      const structureIds = structures.map((structure) => text(structure.id))
        .filter(Boolean);
      const existingInvoiceKeys = new Set<string>();
      let existingPaid = 0;
      let existingUnpaid = 0;
      if (studentIds.length > 0 && structureIds.length > 0) {
        const { data: existingInvoices, error: existingInvoicesError } =
          await svc.from("fee_invoices")
            .select("student_id, fee_structure_id, status, balance")
            .eq("school_id", school)
            .eq("academic_year_id", academicYearId)
            .in("student_id", studentIds)
            .in("fee_structure_id", structureIds);
        if (existingInvoicesError) return fail(existingInvoicesError.message);
        for (const existing of existingInvoices ?? []) {
          const key = `${text(existing.student_id)}:${
            text(existing.fee_structure_id)
          }`;
          if (!key || existingInvoiceKeys.has(key)) continue;
          existingInvoiceKeys.add(key);
          if (
            text(existing.status).toLowerCase() === "paid" ||
            money(existing.balance) <= 0
          ) {
            existingPaid++;
          } else {
            existingUnpaid++;
          }
        }
      }

      let created = 0;
      let skipped = 0;
      const createdInvoices: Record<string, unknown>[] = [];
      const label = text(body.invoice_label, "Fees").replace(
        /[^A-Za-z0-9]+/g,
        "-",
      ).replace(/^-|-$/g, "").toUpperCase();
      for (const student of students ?? []) {
        const studentCode = text(
          student.admission_number ?? student.student_id_number ?? student.id,
        ).replace(/[^A-Za-z0-9]+/g, "").slice(-8);
        for (const structure of structures) {
          const invoiceKey = `${text(student.id)}:${text(structure.id)}`;
          if (existingInvoiceKeys.has(invoiceKey)) {
            skipped++;
            continue;
          }
          const categoryName = text(
            (structure.fee_category as Record<string, unknown> | null)
              ?.category_name ??
              (structure.fee_category as Record<string, unknown> | null)
                ?.name ??
              structure.category_name,
            "Fee",
          );
          const feeType = normalizeFeeType(
            structure.fee_type ?? categoryName,
          );
          const billingMode = text(
            structure.billing_mode,
            feeType === "tuition" ? "monthly" : "one_time",
          );
          const total = money(structure.amount);
          const dueDate = dueDateFrom(
            body.due_date ?? structure.due_date,
            structure.due_day,
          );
          const structureTag = categoryName
            .replace(/[^A-Za-z0-9]+/g, "")
            .slice(0, 12)
            .toUpperCase() || (feeType === "tuition" ? "TUITION" : "FEE");
          const invoiceNumber = `FEE-${label}-${
            studentCode || text(student.id).slice(0, 8)
          }-${structureTag}`;
          const { data: invoice, error: invoiceError } = await svc.from(
            "fee_invoices",
          ).insert({
            school_id: school,
            student_id: student.id,
            academic_year_id: academicYearId,
            fee_structure_id: structure.id,
            invoice_number: invoiceNumber,
            due_date: dueDate,
            total_amount: total,
            net_amount: total,
            balance: total,
            status: "pending",
            fee_type: feeType,
            billing_mode: billingMode,
            priority: parseInt(
              text(structure.priority, feeType === "tuition" ? "2" : "1"),
            ) || (feeType === "tuition" ? 2 : 1),
          }).select().single();
          if (invoiceError) {
            if (invoiceError.message.toLowerCase().includes("duplicate")) {
              skipped++;
              continue;
            }
            return fail(invoiceError.message);
          }
          const { error: itemError } = await svc.from("fee_invoice_items")
            .insert({
              invoice_id: invoice.id,
              fee_structure_id: structure.id,
              category_name: text(
                categoryName,
              ),
              amount: total,
            });
          if (itemError) return fail(itemError.message);
          created++;
          existingInvoiceKeys.add(invoiceKey);
          createdInvoices.push(decorateInvoice(invoice));
        }
      }
      return ok({
        created,
        skipped,
        generated_count: created,
        skipped_count: skipped,
        existing_paid_count: existingPaid,
        existing_unpaid_count: existingUnpaid,
        academic_year_id: academicYearId,
        section_id: sectionId || null,
        student_id: studentId || null,
        invoices: createdInvoices,
      });
    }

    if (!seg && method === "POST") {
      const { items, ...invoicePayload } = body;
      const { data: invoice, error: invErr } = await svc.from("fee_invoices")
        .insert({ ...invoicePayload, school_id: school }).select().single();
      if (invErr) return fail(invErr.message);
      if (Array.isArray(items) && items.length > 0) {
        await svc.from("fee_invoice_items").insert(
          items.map((it: Record<string, unknown>) => ({
            ...it,
            invoice_id: invoice.id,
          })),
        );
      }
      return ok(invoice);
    }

    if (seg === "late-fines" && parts[1] === "apply" && method === "POST") {
      return ok({
        adjusted_invoice_count: 0,
        applied_at: new Date().toISOString(),
      });
    }

    if (seg && method === "GET") {
      const { data, error } = await svc.from("fee_invoices").select(
        "*, student:students(first_name, last_name, admission_number, student_id_number, current_section:sections(id, section_name, grade:grades(id, grade_name))), fee_invoice_items(*), payments(*)",
      ).eq("id", seg).eq("school_id", school).maybeSingle();
      if (error) return fail(error.message);
      if (!data) return fail("not found", 404);
      return ok(decorateInvoice(data));
    }

    if (seg && (method === "PATCH" || method === "PUT")) {
      const { data, error } = await svc.from("fee_invoices").update({
        ...body,
        updated_at: new Date().toISOString(),
      }).eq("id", seg).eq("school_id", school).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  if (
    path.startsWith("/fee-payments") || path === "/payments" ||
    feesPath.startsWith("/payments")
  ) {
    const normalized = path.replace(/^\/fee-payments/, "").replace(
      /^\/payments/,
      "",
    ).replace(/^\/fees\/payments/, "");
    const seg = normalized.split("/").filter(Boolean)[0];

    if (!seg && method === "GET") {
      const page = parseInt(url.searchParams.get("page") ?? "1");
      const size = parseInt(url.searchParams.get("page_size") ?? "50");
      let q = svc.from("payments").select(
        "*, student:students(first_name, last_name), invoice:fee_invoices(*), fee_receipts(*)",
        { count: "exact" },
      ).eq("school_id", school).range((page - 1) * size, page * size - 1);
      if (url.searchParams.get("student_id")) {
        q = q.eq("student_id", url.searchParams.get("student_id")!);
      }
      if (url.searchParams.get("invoice_id")) {
        q = q.eq("invoice_id", url.searchParams.get("invoice_id")!);
      }
      if (url.searchParams.get("status")) {
        q = q.eq("status", url.searchParams.get("status")!);
      }
      const { data, error, count } = await q;
      if (error) return fail(error.message);
      return cors({
        success: true,
        data: data ?? [],
        total: count ?? 0,
        page,
        page_size: size,
      });
    }

    if ((seg === "intent" || seg === "request") && method === "POST") {
      const { data: invoice, error: invoiceError } = body.invoice_id
        ? await svc.from("fee_invoices").select("*").eq("id", body.invoice_id)
          .eq("school_id", school).maybeSingle()
        : { data: null };
      if (invoiceError) return fail(invoiceError.message);
      if (!invoice) return fail("Invoice not found", 404);
      if (
        !isAdminOrPrincipal(user) &&
        text(body.payment_method, "upi").toLowerCase() !== "upi"
      ) {
        return fail("Parents can submit manual UPI payment proofs only", 400);
      }
      try {
        if (
          !await parentCanAccessStudent(
            svc,
            school,
            user,
            text(invoice.student_id),
          )
        ) {
          return fail("Invoice does not belong to a linked child", 403);
        }
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to verify parent access",
        );
      }
      let selection;
      try {
        selection = validateInvoicePaymentAmount(
          invoice as Record<string, unknown>,
          body.amount ?? body.amount_paid,
        );
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to validate payment amount",
        );
      }
      const reference = `FPR-${Date.now()}-${
        crypto.randomUUID().slice(0, 8).toUpperCase()
      }`;
      const { data: request, error: requestError } = await svc.from(
        "parent_payment_requests",
      ).insert({
        school_id: school,
        student_id: invoice.student_id,
        invoice_id: invoice.id,
        parent_user_id: isAdminOrPrincipal(user) ? null : user.id,
        amount: selection.amount,
        payment_method: body.payment_method ?? "upi",
        request_reference: reference,
        payment_date: new Date().toISOString().split("T")[0],
        remarks: body.remarks ?? "",
        status: "initiated",
        idempotency_key: text(body.idempotency_key) || crypto.randomUUID(),
      }).select().single();
      if (requestError) return fail(requestError.message);
      return ok({
        id: request.id,
        request_reference: reference,
        invoice_id: body.invoice_id ?? null,
        payment_method: body.payment_method ?? "",
        amount: selection.amount,
        remarks: body.remarks ?? "",
      });
    }

    if (seg === "submit" && method === "POST") {
      const form = await req.formData().catch(() => null);
      if (!form) return fail("multipart form required");
      const screenshot = form.get("screenshot") as File | null;
      const invoiceId = text(
        form.get("invoice_id") ?? form.get("student_fee_id"),
      );
      const requestId = text(
        form.get("payment_request_id") ?? form.get("request_id"),
      );
      const requestReference = text(form.get("request_reference"));
      let existingRequest: Record<string, unknown> | null = null;
      if (requestId || requestReference) {
        let requestQuery = svc.from("parent_payment_requests").select("*").eq(
          "school_id",
          school,
        );
        if (requestId) requestQuery = requestQuery.eq("id", requestId);
        else {requestQuery = requestQuery.eq(
            "request_reference",
            requestReference,
          );}
        if (!isAdminOrPrincipal(user)) {
          requestQuery = requestQuery.eq("parent_user_id", user.id);
        }
        const { data, error } = await requestQuery.maybeSingle();
        if (error) return fail(error.message);
        if (!data) return fail("Payment intent not found", 404);
        existingRequest = data as Record<string, unknown>;
      }
      const effectiveInvoiceId = text(existingRequest?.invoice_id, invoiceId);
      const { data: invoice, error: invoiceError } = await svc.from(
        "fee_invoices",
      ).select("*")
        .eq("id", effectiveInvoiceId)
        .eq("school_id", school)
        .maybeSingle();
      if (invoiceError) return fail(invoiceError.message);
      if (!invoice) return fail("Invoice not found", 404);
      try {
        if (
          !await parentCanAccessStudent(
            svc,
            school,
            user,
            text(invoice.student_id),
          )
        ) {
          return fail("Invoice does not belong to a linked child", 403);
        }
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to verify parent access",
        );
      }
      let selection;
      try {
        selection = validateInvoicePaymentAmount(
          invoice as Record<string, unknown>,
          existingRequest?.amount ?? form.get("amount"),
        );
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to validate payment amount",
        );
      }
      const expectedAmount = selection.amount;
      if (money(form.get("amount")) !== expectedAmount) {
        return fail(
          `payment proof amount must match the prepared payment amount of ${
            expectedAmount.toFixed(2)
          }`,
        );
      }
      let proofUrl = "";
      if (screenshot) {
        try {
          proofUrl = await uploadPrivatePaymentProof(
            svc,
            school,
            text(existingRequest?.id, requestReference),
            screenshot,
          );
        } catch (error) {
          return fail(
            error instanceof Error ? error.message : "proof upload failed",
          );
        }
      }
      const payload = {
        school_id: school,
        student_id: invoice.student_id,
        invoice_id: invoice.id,
        parent_user_id: isAdminOrPrincipal(user) ? null : user.id,
        amount: expectedAmount,
        payment_method: `${form.get("payment_method") ?? ""}` || "upi",
        request_reference: requestReference ||
          text(existingRequest?.request_reference) ||
          `FPR-${Date.now()}-${crypto.randomUUID().slice(0, 8).toUpperCase()}`,
        transaction_ref: text(
          form.get("transaction_ref") ?? form.get("transaction_id"),
        ),
        transaction_id: text(
          form.get("transaction_ref") ?? form.get("transaction_id"),
        ),
        payment_date: text(
          form.get("payment_date"),
          new Date().toISOString().split("T")[0],
        ),
        proof_url: proofUrl,
        proof_file_name: screenshot?.name ?? null,
        proof_content_type: screenshot?.type ?? null,
        proof_size: screenshot?.size ?? null,
        remarks: `${form.get("remarks") ?? ""}`,
        status: existingRequest?.status === "clarification_required"
          ? "resubmitted"
          : "pending_verification",
        updated_at: new Date().toISOString(),
      };
      const { data, error } = existingRequest
        ? await svc.from("parent_payment_requests").update(payload).eq(
          "id",
          existingRequest.id,
        ).eq("school_id", school).select().single()
        : await svc.from("parent_payment_requests").insert(payload).select()
          .single();
      if (error) return fail(error.message);
      // Notify principals/admins about the new payment proof submission
      try {
        const { data: principals } = await svc.from("users")
          .select("id")
          .eq("school_id", school)
          .in("role_name", ["principal", "admin", "super_admin"]);
        if (principals && principals.length > 0) {
          const amountLabel = `INR ${expectedAmount.toFixed(0)}`;
          const validPrincipals = principals.filter((
            p: Record<string, unknown>,
          ) => text(p.id));
          if (validPrincipals.length > 0) {
            // Resolve student name for a readable notification
            let studentName = text(invoice.student_id, "a student");
            const { data: studentRow } = await svc.from("students")
              .select("first_name, last_name")
              .eq("id", invoice.student_id)
              .eq("school_id", school)
              .maybeSingle();
            if (studentRow) {
              const fn = text(studentRow.first_name);
              const ln = text(studentRow.last_name);
              studentName = fn && ln ? `${fn} ${ln}` : fn || ln || "a student";
            }
            const feeMessage =
              `A parent submitted ${amountLabel} payment proof for ${studentName}. Please review and verify.`;
            const { error: logError } = await svc.from("notification_logs")
              .insert(validPrincipals.map((p: Record<string, unknown>) => ({
                school_id: school,
                user_id: text(p.id),
                target_role: "principal",
                title: "New payment proof submitted",
                body: feeMessage,
                type: "fee",
                entity_type: "parent_payment_requests",
                entity_id: text(data.id),
                reference_type: "fee",
                reference_id: text(data.id),
                action: "payment_submitted",
                route: "/principal-fees-screen/payment-requests",
                student_id: text(invoice.student_id),
                is_read: false,
              })));
            if (logError) {
              console.error(
                "Failed to write fee in-app notifications",
                logError.message,
              );
            }
            const { data: feeEvents, error: feeEventError } = await svc
              .from("notification_events")
              .insert(
                validPrincipals.map((p: Record<string, unknown>) => ({
                  school_id: school,
                  user_id: text(p.id),
                  event_type: "fee_payment_submitted",
                  event_data: {
                    payment_request_id: data.id,
                    invoice_id: invoice.id,
                    student_id: invoice.student_id,
                    amount: expectedAmount,
                    request_reference: data.request_reference,
                    message: feeMessage,
                    reference_type: "fee",
                    reference_id: text(data.id),
                    action: "payment_submitted",
                    route: "/principal-fees-screen/payment-requests",
                  },
                  processed: false,
                })),
              )
              .select("id");
            if (!feeEventError) {
              const feeEventIds = (feeEvents ?? []).map((row: { id: string }) =>
                `${row.id ?? ""}`.trim()
              ).filter(Boolean);
              if (feeEventIds.length > 0) triggerPushProcessing(feeEventIds);
            }
          }
        }
      } catch (_) {
        // Best-effort notification — don't fail the submission.
      }
      try {
        return ok(
          (await attachPaymentRequestRelations(svc, school, [data]))[0],
        );
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to load payment request details",
        );
      }
    }

    if (seg && normalized.endsWith("/resubmit") && method === "PATCH") {
      if (!isParent) {
        return fail("only parents can resubmit payment proofs", 403);
      }
      const form = await req.formData().catch(() => null);
      if (!form) return fail("multipart form required");
      const screenshot = form.get("screenshot") as File | null;
      const paymentId = normalized.split("/").filter(Boolean)[0];
      let proofUrl: string | null = null;
      if (screenshot) {
        try {
          proofUrl = await uploadPrivatePaymentProof(
            svc,
            school,
            paymentId,
            screenshot,
          );
        } catch (error) {
          return fail(
            error instanceof Error ? error.message : "proof upload failed",
          );
        }
      }
      const { data, error } = await svc.from("parent_payment_requests").update({
        transaction_ref: text(
          form.get("transaction_ref") ?? form.get("transaction_id"),
        ),
        transaction_id: text(
          form.get("transaction_ref") ?? form.get("transaction_id"),
        ),
        proof_url: proofUrl ?? undefined,
        proof_file_name: screenshot?.name ?? undefined,
        proof_content_type: screenshot?.type ?? undefined,
        proof_size: screenshot?.size ?? undefined,
        remarks: `${form.get("remarks") ?? ""}`,
        status: "pending_verification",
        updated_at: new Date().toISOString(),
      }).eq("id", paymentId).eq("school_id", school).eq(
        "parent_user_id",
        user.id,
      ).select().single();
      if (error) return fail(error.message);
      try {
        return ok(
          (await attachPaymentRequestRelations(svc, school, [data]))[0],
        );
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to load payment request details",
        );
      }
    }

    if (!seg && method === "POST") {
      const invoiceId = text(body.invoice_id);
      const amount = money(body.amount ?? body.amount_paid);
      if (!invoiceId) return fail("invoice_id is required");
      if (amount <= 0) return fail("amount must be greater than zero");
      const { data: invoice, error: invoiceError } = await svc.from(
        "fee_invoices",
      ).select("*")
        .eq("id", invoiceId)
        .eq("school_id", school)
        .maybeSingle();
      if (invoiceError) return fail(invoiceError.message);
      if (!invoice) return fail("Invoice not found", 404);
      let selection;
      try {
        selection = validateInvoicePaymentAmount(
          invoice as Record<string, unknown>,
          amount,
        );
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to validate payment amount",
        );
      }
      const { data: payment, error } = await svc.rpc("record_fee_payment", {
        p_school_id: school,
        p_invoice_id: invoiceId,
        p_student_id: invoice.student_id,
        p_amount: amount,
        p_payment_method: text(
          body.payment_method ?? body.payment_mode,
          "cash",
        ),
        p_reference_number: text(
          body.reference_number ?? body.transaction_ref ??
            body.transaction_id ?? body.receipt_number,
        ),
        p_paid_at: text(body.payment_date)
          ? `${text(body.payment_date)}T00:00:00.000Z`
          : new Date().toISOString(),
        p_notes: text(body.remarks),
        p_created_by: user.id,
        p_idempotency_key: text(body.idempotency_key) || crypto.randomUUID(),
      }).single();
      if (error) return fail(error.message);
      const atomicPayment = payment as Record<string, unknown>;
      return ok({
        ...atomicPayment,
      });
    }
  }

  if (/^\/parent\/students\/[^/]+\/fees$/.test(path) && method === "GET") {
    const studentId = path.split("/")[3];
    try {
      if (!await parentCanAccessStudent(svc, school, user, studentId)) {
        return fail("Student does not belong to a linked child", 403);
      }
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "failed to verify parent access",
      );
    }
    // This is the parent-safe invoice source. Include payments here so parent
    // fee/history screens never need the principal-wide /fees/invoices route.
    const { data, error } = await svc.from("fee_invoices").select(
      "*, student:students(first_name, last_name, admission_number, student_id_number, current_section:sections(id, section_name, grade:grades(id, grade_name))), fee_invoice_items(*), payments(*)",
    ).eq("school_id", school).eq("student_id", studentId).order(
      "invoice_date",
      { ascending: false },
    );
    if (error) return fail(error.message);
    const invoices = data ?? [];
    const paymentIds = invoices.flatMap((invoice: Record<string, unknown>) =>
      Array.isArray(invoice.payments)
        ? (invoice.payments as Record<string, unknown>[]).map((payment) =>
          text(payment.id)
        ).filter(Boolean)
        : []
    );
    const receiptsByPaymentId = new Map<string, Record<string, unknown>>();
    if (paymentIds.length > 0) {
      const { data: receipts, error: receiptsError } = await svc.from(
        "fee_receipts",
      ).select("*").eq("school_id", school).in("payment_id", paymentIds);
      if (receiptsError) return fail(receiptsError.message);
      for (const receipt of receipts ?? []) {
        receiptsByPaymentId.set(text(receipt.payment_id), receipt);
      }
    }
    return ok(invoices.map((invoice: Record<string, unknown>) => {
      const decorated = decorateInvoice(invoice);
      const payments = Array.isArray(invoice.payments)
        ? (invoice.payments as Record<string, unknown>[]).map((payment) => {
          const receipt = receiptsByPaymentId.get(text(payment.id)) ?? null;
          return {
            ...payment,
            receipt,
            receipt_number: text(
              receipt?.receipt_number ?? payment.receipt_number,
            ),
          };
        })
        : [];
      return {
        ...decorated,
        payments,
        amount: money(
          invoice.balance ?? invoice.net_amount ?? invoice.total_amount,
        ),
        balance_amount: money(
          invoice.balance ?? invoice.net_amount ?? invoice.total_amount,
        ),
      };
    }));
  }

  if (feesPath.startsWith("/payment-requests")) {
    const seg = path.replace(/^\/fees\/payment-requests/, "").split("/").filter(
      Boolean,
    )[0];
    if (!seg && method === "GET") {
      if (!isAdminOrPrincipal(user) && !isParent) {
        return fail("parent or principal access required", 403);
      }
      let q = svc.from("parent_payment_requests").select("*").eq(
        "school_id",
        school,
      );
      if (!isAdminOrPrincipal(user)) q = q.eq("parent_user_id", user.id);
      if (url.searchParams.get("student_id")) {
        q = q.eq("student_id", url.searchParams.get("student_id")!);
      }
      if (url.searchParams.get("invoice_id")) {
        q = q.eq("invoice_id", url.searchParams.get("invoice_id")!);
      }
      if (url.searchParams.get("status")) {
        q = q.eq("status", url.searchParams.get("status")!);
      }
      const { data, error } = await q.order("created_at", { ascending: false });
      if (error) return fail(error.message);
      try {
        return ok(await attachPaymentRequestRelations(svc, school, data ?? []));
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to load payment request details",
        );
      }
    }
    if (!seg && method === "POST") {
      if (!isParent) {
        return fail("only parents can submit payment requests", 403);
      }
      const studentId = text((body as Record<string, unknown>).student_id);
      try {
        if (
          studentId &&
          !await parentCanAccessStudent(svc, school, user, studentId)
        ) {
          return fail("Student does not belong to a linked child", 403);
        }
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to verify parent access",
        );
      }
      const { data, error } = await svc.from("parent_payment_requests").insert({
        ...body,
        school_id: school,
        parent_user_id: isAdminOrPrincipal(user)
          ? body.parent_user_id ?? null
          : user.id,
      }).select().single();
      if (error) return fail(error.message);
      try {
        return ok(
          (await attachPaymentRequestRelations(svc, school, [data]))[0],
        );
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to load payment request details",
        );
      }
    }
    if (seg && path.endsWith("/decision") && method === "PUT") {
      if (!isAdminOrPrincipal(user)) {
        return fail("admin or principal access required", 403);
      }
      const status = text(body.status).toLowerCase();
      if (!["approved", "rejected", "clarification_required"].includes(status)) {
        return fail("status must be approved, rejected, or clarification_required", 400);
      }
      const { data: existing, error: existingError } = await svc.from(
        "parent_payment_requests",
      )
        .select("*")
        .eq("id", seg)
        .eq("school_id", school)
        .maybeSingle();
      if (existingError) return fail(existingError.message);
      if (!existing) return fail("not found", 404);
      if (!["pending_verification", "resubmitted"].includes(text(existing.status))) {
        return fail("Only pending or resubmitted payment requests can be decided", 409);
      }
      let paymentId: string | null = null;
      let receiptId: string | null = null;
      if (status === "approved") {
        const { data: invoice } = await svc.from("fee_invoices").select("*")
          .eq("id", existing.invoice_id)
          .eq("school_id", school)
          .maybeSingle();
        if (!invoice) return fail("Invoice not found", 404);
        let selection;
        try {
          selection = validateInvoicePaymentAmount(
            invoice as Record<string, unknown>,
            existing.amount,
          );
        } catch (validationError) {
          return fail(
            validationError instanceof Error
              ? validationError.message
              : "failed to validate approved payment amount",
          );
        }
        const paymentResponse = await svc.rpc("record_fee_payment", {
          p_school_id: school,
          p_invoice_id: existing.invoice_id,
          p_student_id: existing.student_id,
          p_amount: existing.amount,
          p_payment_method: existing.payment_method ?? "upi",
          p_reference_number: existing.transaction_ref ??
            existing.transaction_id ?? existing.request_reference,
          p_paid_at: existing.payment_date ?? new Date().toISOString(),
          p_notes: existing.remarks ?? "",
          p_created_by: user.id,
          p_request_id: seg,
          p_idempotency_key: `request:${seg}`,
        }).single();
        const { data: payment, error: paymentError } = paymentResponse;
        if (paymentError) return fail(paymentError.message);
        const atomicPayment = payment as Record<string, unknown>;
        paymentId = text(atomicPayment.payment_id);
        receiptId = text(atomicPayment.receipt_id);
      }
      const { data, error } = await svc.from("parent_payment_requests").update({
        status,
        admin_remarks: body.admin_remarks ?? null,
        reviewed_by: user.id,
        reviewed_at: new Date().toISOString(),
        payment_id: paymentId ?? existing.payment_id ?? null,
        receipt_id: receiptId ?? existing.receipt_id ?? null,
        updated_at: new Date().toISOString(),
      }).eq("id", seg).eq("school_id", school).select().single();
      if (error) return fail(error.message);
      // Notify the parent about the approval/rejection decision
      try {
        const parentUserId = text(existing.parent_user_id);
        if (parentUserId) {
          const isApproved = status === "approved";
          const statusLabel = isApproved
            ? "approved"
            : (status === "clarification_required"
              ? "requires clarification"
              : "rejected");
          const amountLabel = `INR ${money(existing.amount).toFixed(0)}`;
          const approvalBody = isApproved
            ? `Your ${amountLabel} payment has been verified and approved. Receipt is now available.`
            : `Your ${amountLabel} payment was ${statusLabel}.${
              body.admin_remarks ? ` Remark: ${text(body.admin_remarks)}` : ""
            }`;
          const { error: logError } = await svc.from("notification_logs")
            .insert({
              school_id: school,
              user_id: parentUserId,
              target_role: "parent",
              title: isApproved
                ? "Payment Approved ✅"
                : `Payment ${statusLabel}`,
              body: approvalBody,
              type: "fee",
              entity_type: "parent_payment_requests",
              entity_id: seg,
              reference_type: "fee",
              reference_id: seg,
              action: isApproved ? "payment_approved" : "payment_rejected",
              route: "/parent-fees-screen",
              student_id: text(existing.student_id),
              is_read: false,
            });
          if (logError) {
            console.error(
              "Failed to write parent fee in-app notification",
              logError.message,
            );
          }
          const { data: feeDecisionEvent } = await svc.from(
            "notification_events",
          ).insert({
            school_id: school,
            user_id: parentUserId,
            event_type: isApproved
              ? "fee_payment_approved"
              : "fee_payment_rejected",
            event_data: {
              payment_request_id: seg,
              invoice_id: existing.invoice_id,
              amount: money(existing.amount),
              status: status,
              admin_remarks: text(body.admin_remarks),
              message: approvalBody,
              reference_type: "fee",
              reference_id: seg,
              action: isApproved ? "payment_approved" : "payment_rejected",
              route: "/parent-fees-screen",
              student_id: text(existing.student_id),
            },
            processed: false,
          }).select("id").maybeSingle();
          if (feeDecisionEvent?.id) triggerPushProcessing(feeDecisionEvent.id);
        }
      } catch (_) {
        // Best-effort notification — don't fail the decision.
      }
      try {
        return ok(
          (await attachPaymentRequestRelations(svc, school, [data]))[0],
        );
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to load payment request details",
        );
      }
    }
  }

  if (feesPath === "/payment-config" && method === "GET") {
    try {
      const data = await resolveScopedPaymentConfig(
        svc,
        school,
        text(url.searchParams.get("invoice_id")),
      );
      return ok((data?.data as Record<string, unknown> | null) ?? {});
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "failed to load payment config",
      );
    }
  }

  if (feesPath === "/payment-config" && method === "PUT") {
    const payload: Record<string, unknown> = { scope: "school" };
    for (
      const key of [
        "upi_id",
        "payee_name",
        "merchant_code",
        "qr_note",
        "qr_image_url",
        "upi_enabled",
      ]
    ) {
      if (Object.hasOwn(body, key)) payload[key] = body[key];
    }
    try {
      const data = await savePaymentConfigRecord(
        svc,
        school,
        configRecordId("school"),
        payload,
      );
      return ok((data?.data as Record<string, unknown> | null) ?? payload);
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "failed to save payment config",
      );
    }
  }

  if (feesPath === "/payment-config/qr" && method === "POST") {
    const form = await req.formData().catch(() => null);
    const file = form?.get("file") as File | null;
    if (!file) return fail("file required");
    const filePath = `payment-config/${school}/${Date.now()}-${file.name}`;
    const { error: uploadError } = await svc.storage.from("school-assets")
      .upload(filePath, file, { upsert: true });
    if (uploadError) return fail(uploadError.message);
    const publicUrl =
      svc.storage.from("school-assets").getPublicUrl(filePath).data.publicUrl;
    try {
      const data = await savePaymentConfigRecord(
        svc,
        school,
        configRecordId("school"),
        { scope: "school", qr_image_url: publicUrl },
      );
      return ok({
        ...((data?.data as Record<string, unknown> | null) ?? {}),
        qr_image_url: publicUrl,
      });
    } catch (error) {
      return fail(
        error instanceof Error ? error.message : "failed to save payment qr",
      );
    }
  }

  if (feesPath === "/payment-configs" && method === "GET") {
    const { data, error } = await svc.from("frontend_records").select("*").eq(
      "school_id",
      school,
    ).eq("table_name", "payment_config").order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    return ok((data ?? []).map((row: Record<string, unknown>) => ({
      id: row.id,
      ...((row.data as Record<string, unknown> | null) ?? {}),
    })));
  }

  if (feesPath === "/payment-configs" && method === "POST") {
    const scope = `${body.scope ?? "school"}`.trim() || "school";
    const gradeId = `${body.grade_id ?? ""}`.trim();
    const sectionId = `${body.section_id ?? ""}`.trim();
    const payload = {
      scope,
      grade_id: gradeId,
      section_id: sectionId,
      upi_id: body.upi_id ?? "",
      payee_name: body.payee_name ?? "",
      merchant_code: body.merchant_code ?? "",
      qr_note: body.qr_note ?? "",
      qr_image_url: body.qr_image_url ?? "",
      upi_enabled: body.upi_enabled ?? true,
    };
    try {
      const recordId = configRecordId(scope, gradeId, sectionId);
      const data = await savePaymentConfigRecord(
        svc,
        school,
        recordId,
        payload,
      );
      return ok({
        id: data?.id,
        ...((data?.data as Record<string, unknown> | null) ?? payload),
      });
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "failed to create payment config",
      );
    }
  }

  if (feesPath.startsWith("/payment-configs/") && method === "PUT") {
    const id = feesPath.split("/")[2] ?? "";
    if (!id) return fail("config id required");
    const { data: existing, error: lookupError } = await svc.from(
      "frontend_records",
    )
      .select("*")
      .eq("id", id)
      .eq("school_id", school)
      .eq("table_name", "payment_config")
      .maybeSingle();
    if (lookupError) return fail(lookupError.message);
    if (!existing) return fail("not found", 404);
    const current = (existing.data as Record<string, unknown> | null) ?? {};
    const payload: Record<string, unknown> = {
      scope: body.scope ?? current.scope ?? "school",
      grade_id: body.grade_id ?? current.grade_id ?? "",
      section_id: body.section_id ?? current.section_id ?? "",
    };
    for (
      const key of [
        "upi_id",
        "payee_name",
        "merchant_code",
        "qr_note",
        "qr_image_url",
        "upi_enabled",
      ]
    ) {
      if (Object.hasOwn(body, key)) payload[key] = body[key];
    }
    const { data, error } = await svc.from("frontend_records").update({
      data: {
        ...((existing.data as Record<string, unknown> | null) ?? {}),
        ...payload,
      },
      updated_at: new Date().toISOString(),
    }).eq("id", id).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok({
      id: data?.id,
      ...((data?.data as Record<string, unknown> | null) ?? payload),
    });
  }

  if (
    feesPath.startsWith("/payment-configs/") && feesPath.endsWith("/qr") &&
    method === "POST"
  ) {
    const id = feesPath.split("/")[2] ?? "";
    if (!id) return fail("config id required");
    const { data: existing, error: lookupError } = await svc.from(
      "frontend_records",
    )
      .select("*")
      .eq("id", id)
      .eq("school_id", school)
      .eq("table_name", "payment_config")
      .maybeSingle();
    if (lookupError) return fail(lookupError.message);
    if (!existing) return fail("not found", 404);
    const form = await req.formData().catch(() => null);
    const file = form?.get("file") as File | null;
    if (!file) return fail("file required");
    const filePath =
      `payment-config/${school}/${id}/${Date.now()}-${file.name}`;
    const { error: uploadError } = await svc.storage.from("school-assets")
      .upload(filePath, file, { upsert: true });
    if (uploadError) return fail(uploadError.message);
    const publicUrl =
      svc.storage.from("school-assets").getPublicUrl(filePath).data.publicUrl;
    const { data, error } = await svc.from("frontend_records").update({
      data: {
        ...((existing.data as Record<string, unknown> | null) ?? {}),
        qr_image_url: publicUrl,
      },
      updated_at: new Date().toISOString(),
    }).eq("id", id).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok({
      id: data?.id,
      ...((data?.data as Record<string, unknown> | null) ?? {}),
      qr_image_url: publicUrl,
    });
  }

  if (feesPath.startsWith("/concessions")) {
    const seg = path.replace(/^\/fees\/concessions/, "").split("/").filter(
      Boolean,
    )[0];
    if (!seg && method === "GET") {
      let query = svc.from("fee_concessions").select(
        "*, student:students(first_name, last_name, admission_number, student_id_number), invoice:fee_invoices(invoice_number, total_amount, net_amount, paid_amount, balance), fee_structure:fee_structures(id, fee_category_id, category_id)",
      ).eq("school_id", school);
      const studentId = text(url.searchParams.get("student_id"));
      const invoiceId = text(url.searchParams.get("invoice_id"));
      const status = text(url.searchParams.get("status")).toLowerCase();
      if (studentId) query = query.eq("student_id", studentId);
      if (invoiceId) query = query.eq("invoice_id", invoiceId);
      if (["pending", "approved", "rejected"].includes(status)) {
        query = query.eq("status", status);
      }
      const { data, error } = await query.order("created_at", {
        ascending: false,
      });
      if (error) return fail(error.message);

      // fee_structures keeps both category_id (legacy) and fee_category_id
      // (current) so older schools remain compatible. Embedding
      // fee_categories through PostgREST is therefore ambiguous. Hydrate the
      // categories explicitly, using the same compatibility helper as the fee
      // structures endpoint.
      const rows = (data ?? []) as Record<string, unknown>[];
      const rawStructures = rows.map((row) => row.fee_structure).filter(
        (structure): structure is Record<string, unknown> =>
          structure !== null && typeof structure === "object",
      );
      let hydratedStructures: Record<string, unknown>[];
      try {
        hydratedStructures = await attachFeeCategories(
          svc,
          school,
          rawStructures,
        );
      } catch (categoryError) {
        return fail(
          categoryError instanceof Error
            ? categoryError.message
            : "failed to load concession fee categories",
        );
      }
      const structuresById = new Map(
        hydratedStructures.map((structure) => [text(structure.id), structure]),
      );

      const search = text(url.searchParams.get("q")).toLowerCase();
      const normalized = rows.map((row: Record<string, unknown>) => {
        const student = (row.student as Record<string, unknown> | null) ?? {};
        const rawStructure =
          (row.fee_structure as Record<string, unknown> | null) ??
            {};
        const structure = structuresById.get(text(rawStructure.id)) ??
          rawStructure;
        const category =
          (structure.fee_category as Record<string, unknown> | null) ??
            (structure.category as Record<string, unknown> | null) ??
            {};
        return {
          ...row,
          fee_structure: structure,
          student_name: `${text(student.first_name)} ${text(student.last_name)}`
            .trim() || "Student",
          student_identifier: text(
            student.student_id_number ?? student.admission_number,
          ),
          fee_item_name: text(category.name, "Fee"),
        };
      });
      return ok(
        search
          ? normalized.filter((row) =>
            `${row.student_name} ${row.student_identifier} ${row.fee_item_name}`
              .toLowerCase().includes(search)
          )
          : normalized,
      );
    }
    if (!seg && method === "POST") {
      const invoiceId = text(body.invoice_id);
      const amount = money(body.amount);
      const percentage = money(body.percentage);
      const reason = text(body.reason);
      if (!invoiceId) return fail("invoice_id is required");
      if ((amount > 0) === (percentage > 0)) {
        return fail("provide either a concession amount or percentage");
      }
      if (percentage > 100) return fail("percentage cannot exceed 100");
      if (!reason) return fail("concession reason is required");
      const { data: invoice, error: invoiceError } = await svc.from(
        "fee_invoices",
      ).select("id, student_id, fee_structure_id, total_amount, balance")
        .eq("id", invoiceId).eq("school_id", school).maybeSingle();
      if (invoiceError) return fail(invoiceError.message);
      if (!invoice?.fee_structure_id) {
        return fail("a fee-structure invoice is required", 404);
      }
      const effectiveAmount = amount > 0
        ? amount
        : money(money(invoice.total_amount) * percentage / 100);
      if (effectiveAmount <= 0 || effectiveAmount > money(invoice.balance)) {
        return fail("concession must not exceed the outstanding balance");
      }
      const { data, error } = await svc.from("fee_concessions").insert({
        school_id: school,
        student_id: invoice.student_id,
        fee_structure_id: invoice.fee_structure_id,
        invoice_id: invoice.id,
        amount: amount > 0 ? amount : null,
        percentage: percentage > 0 ? percentage : null,
        reason,
        status: "approved",
        approved_by: user.id,
      }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (seg && (method === "PATCH" || method === "PUT")) {
      const { data: current, error: currentError } = await svc.from(
        "fee_concessions",
      ).select("*").eq("id", seg).eq("school_id", school).maybeSingle();
      if (currentError) return fail(currentError.message);
      if (!current) return fail("concession not found", 404);
      const updates: Record<string, unknown> = {
        updated_at: new Date().toISOString(),
      };
      if (Object.hasOwn(body, "amount")) {
        updates.amount = money(body.amount) > 0 ? money(body.amount) : null;
        updates.percentage = null;
      } else if (Object.hasOwn(body, "percentage")) {
        const percentage = money(body.percentage);
        if (percentage <= 0 || percentage > 100) {
          return fail("percentage must be between 0 and 100");
        }
        updates.percentage = percentage;
        updates.amount = null;
      }
      if (Object.hasOwn(body, "reason")) {
        const reason = text(body.reason);
        if (!reason) return fail("concession reason is required");
        updates.reason = reason;
      }
      if (Object.hasOwn(body, "status")) {
        const status = text(body.status).toLowerCase();
        if (!["pending", "approved", "rejected"].includes(status)) {
          return fail("invalid concession status");
        }
        updates.status = status;
        if (status === "approved") updates.approved_by = user.id;
      }
      if (Object.hasOwn(body, "amount") || Object.hasOwn(body, "percentage")) {
        const { data: invoice, error: invoiceError } = await svc.from(
          "fee_invoices",
        ).select("id, total_amount, balance, paid_amount")
          .eq("id", current.invoice_id).eq("school_id", school).maybeSingle();
        if (invoiceError) return fail(invoiceError.message);
        if (!invoice) return fail("linked invoice not found", 404);
        const proposedAmount = money(updates.amount);
        const proposedPercentage = money(updates.percentage);
        const effective = proposedAmount > 0
          ? proposedAmount
          : money(money(invoice.total_amount) * proposedPercentage / 100);
        if (effective <= 0 || effective > money(invoice.balance)) {
          return fail("concession must not exceed the outstanding balance");
        }
      }
      const { data, error } = await svc.from("fee_concessions").update(updates)
        .eq("id", seg).eq("school_id", school).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (seg && method === "DELETE") {
      const { error } = await svc.from("fee_concessions").delete().eq(
        "id",
        seg,
      ).eq("school_id", school);
      if (error) return fail(error.message);
      return ok({ success: true });
    }
  }

  if (feesPath.startsWith("/reminders") && method === "GET") {
    const limit = Math.min(
      Math.max(parseInt(url.searchParams.get("limit") ?? "50"), 1),
      200,
    );
    const { data, error } = await svc.from("fee_reminder_deliveries").select(
      "*, notification_event:notification_events(processed, sent_at, event_data)",
    ).eq("school_id", school).order("created_at", { ascending: false }).limit(
      limit,
    );
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  if (
    feesPath.startsWith("/reminders") && method === "POST" &&
    Array.isArray(body.invoice_ids)
  ) {
    const invoiceIds = (body.invoice_ids as unknown[]).map((id) => text(id))
      .filter(Boolean);
    if (invoiceIds.length === 0) {
      return fail("Select at least one eligible invoice", 400);
    }
    try {
      const summary = await queueManualFeeReminders(
        svc,
        school,
        invoiceIds,
        text(body.message),
        user.id,
      );
      return ok({
        ...summary,
        message: `${summary.queued} reminder${summary.queued === 1 ? "" : "s"} queued.`,
      });
    } catch (error) {
      return fail(
        error instanceof Error ? error.message : "failed to queue reminders",
      );
    }
  }

  // Backwards-compatible endpoint for older staff clients. New dashboard
  // clients send invoice_ids above and receive cooldown/delivery diagnostics.
  if (feesPath.startsWith("/reminders") && method === "POST") {
    const invoiceId = text(body.invoice_id);
    const studentId = text(body.student_id);
    const customMessage = text(body.message);

    try {
      if (invoiceId) {
        // 1. Single Invoice Reminder (triggered by Admin UI)
        const { data: invoice, error: invoiceError } = await svc
          .from("fee_invoices")
          .select("*, student:students(first_name, last_name)")
          .eq("id", invoiceId)
          .eq("school_id", school)
          .maybeSingle();

        if (invoiceError) return fail(invoiceError.message);
        if (!invoice) return fail("Invoice not found", 404);

        const currentStudentId = studentId || text(invoice.student_id);
        if (!currentStudentId) {
          return fail("student_id not found on invoice", 400);
        }

        // Find the parent user ID(s)
        const { data: links, error: linksError } = await svc
          .from("parent_student_links")
          .select("parent_user_id")
          .eq("school_id", school)
          .eq("student_id", currentStudentId);

        if (linksError) return fail(linksError.message);
        const parentUserIds = (links ?? [])
          .map((l: Record<string, unknown>) => text(l.parent_user_id))
          .filter(Boolean);

        if (parentUserIds.length === 0) {
          return fail("No parent linked to this student", 404);
        }

        const student = invoice.student as Record<string, unknown> | null;
        const studentName = student
          ? `${text(student.first_name)} ${text(student.last_name)}`.trim()
          : "your child";
        const balanceVal = money(invoice.balance);
        const amountLabel = `INR ${balanceVal.toFixed(0)}`;
        const dueDateLabel = text(invoice.due_date).split("T")[0];

        const messageBody = customMessage ||
          `Reminder: Outstanding balance of ${amountLabel} is due for ${studentName} by ${dueDateLabel}.`;

        const eventsToInsert = parentUserIds.map((pId) => ({
          school_id: school,
          user_id: pId,
          event_type: "fee_due",
          event_data: {
            invoice_id: invoiceId,
            student_id: currentStudentId,
            amount: amountLabel,
            balance: balanceVal,
            due_date: dueDateLabel,
            message: messageBody,
            reference_type: "fee",
          },
          processed: false,
        }));

        const { data: insertedEvents, error: insertEventError } = await svc
          .from("notification_events")
          .insert(eventsToInsert)
          .select("id");

        if (insertEventError) return fail(insertEventError.message);

        // Insert in-app notifications too so it shows up in history
        const logsToInsert = parentUserIds.map((pId) => ({
          school_id: school,
          user_id: pId,
          title: "Fee Due Reminder",
          body: messageBody,
          type: "fee",
          entity_type: "fee_invoices",
          entity_id: invoiceId,
          target_role: "parent",
          is_read: false,
        }));
        await svc.from("notification_logs").insert(logsToInsert);

        const eventIds = (insertedEvents ?? []).map((row: { id: string }) =>
          text(row.id)
        ).filter(Boolean);
        if (eventIds.length > 0) {
          triggerPushProcessing(eventIds);
        }

        return ok({
          success: true,
          sent_to_count: parentUserIds.length,
          message: messageBody,
        });
      } else {
        // 2. Bulk/Scheduled Outstanding Invoice Reminders (no single invoice_id supplied)
        const { data: invoices, error: invoicesError } = await svc
          .from("fee_invoices")
          .select("*, student:students(first_name, last_name)")
          .eq("school_id", school)
          .gt("balance", 0)
          .neq("status", "paid");

        if (invoicesError) return fail(invoicesError.message);
        if (!invoices || invoices.length === 0) {
          return ok({
            success: true,
            message: "No outstanding invoices found.",
          });
        }

        let totalRemindersSent = 0;
        for (const invoice of invoices) {
          const currentStudentId = text(invoice.student_id);
          if (!currentStudentId) continue;

          const { data: links } = await svc
            .from("parent_student_links")
            .select("parent_user_id")
            .eq("school_id", school)
            .eq("student_id", currentStudentId);

          const parentUserIds = (links ?? [])
            .map((l: Record<string, unknown>) => text(l.parent_user_id))
            .filter(Boolean);

          if (parentUserIds.length === 0) continue;

          const student = invoice.student as Record<string, unknown> | null;
          const studentName = student
            ? `${text(student.first_name)} ${text(student.last_name)}`.trim()
            : "your child";
          const balanceVal = money(invoice.balance);
          const amountLabel = `INR ${balanceVal.toFixed(0)}`;
          const dueDateLabel = text(invoice.due_date).split("T")[0];

          const messageBody =
            `Reminder: Outstanding balance of ${amountLabel} is due for ${studentName} by ${dueDateLabel}.`;

          const eventsToInsert = parentUserIds.map((pId) => ({
            school_id: school,
            user_id: pId,
            event_type: "fee_due",
            event_data: {
              invoice_id: invoice.id,
              student_id: currentStudentId,
              amount: amountLabel,
              balance: balanceVal,
              due_date: dueDateLabel,
              message: messageBody,
              reference_type: "fee",
            },
            processed: false,
          }));

          const { data: insertedEvents } = await svc
            .from("notification_events")
            .insert(eventsToInsert)
            .select("id");

          const logsToInsert = parentUserIds.map((pId) => ({
            school_id: school,
            user_id: pId,
            title: "Fee Due Reminder",
            body: messageBody,
            type: "fee",
            entity_type: "fee_invoices",
            entity_id: invoice.id,
            target_role: "parent",
            is_read: false,
          }));
          await svc.from("notification_logs").insert(logsToInsert);

          const eventIds = (insertedEvents ?? []).map((row: { id: string }) =>
            text(row.id)
          ).filter(Boolean);
          if (eventIds.length > 0) {
            triggerPushProcessing(eventIds);
          }
          totalRemindersSent += parentUserIds.length;
        }

        return ok({
          success: true,
          sent_to_count: totalRemindersSent,
          message: `Processed bulk outstanding fee reminders.`,
        });
      }
    } catch (err) {
      return fail(err instanceof Error ? err.message : String(err));
    }
  }

  if (path === "/parent-payment-requests" && method === "POST") {
    if (!isParent) return fail("only parents can submit payment requests", 403);
    const studentId = text(body.student_id);
    if (
      !studentId || !await parentCanAccessStudent(svc, school, user, studentId)
    ) {
      return fail("payment request must belong to a linked child", 403);
    }
    const { data, error } = await svc.from("parent_payment_requests").insert({
      ...body,
      school_id: school,
      parent_user_id: user.id,
      status: "pending_verification",
    }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  if (path === "/fee-concessions" && method === "POST") {
    const { data, error } = await svc.from("fee_concessions").insert({
      ...body,
      school_id: school,
    }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  return fail("not found", 404);
}

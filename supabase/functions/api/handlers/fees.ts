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
  return "other";
}

const monthNames = [
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
  "January",
  "February",
  "March",
];

const monthNameLookup = new Map(
  monthNames.map((month, index) => [month.toLowerCase(), index]),
);

function selectedMonthNamesFrom(value: unknown) {
  const raw = Array.isArray(value) ? value : text(value).split(",");
  const selected = raw.map((item) => text(item)).filter((item) =>
    monthNames.map((m) => m.toLowerCase()).includes(item.toLowerCase())
  );
  return [
    ...new Set(
      selected.map((item) =>
        monthNames.find((month) => month.toLowerCase() === item.toLowerCase())!
      ),
    ),
  ];
}

function monthNamesEqual(left: string[], right: string[]) {
  return left.length === right.length &&
    left.every((month, index) => month === right[index]);
}

function invoiceFeeType(invoice: Record<string, unknown>) {
  const direct = normalizeFeeType(invoice.fee_type, "");
  if (direct) return direct;
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
  return "tuition";
}

function invoiceBillingMode(invoice: Record<string, unknown>) {
  const direct = text(invoice.billing_mode).toLowerCase().replaceAll("-", "_")
    .replaceAll(" ", "_");
  if (direct) return direct;
  return invoiceFeeType(invoice) === "tuition" ? "monthly" : "one_time";
}

function invoiceAllowedMonthNames(invoice: Record<string, unknown>) {
  const configured = selectedMonthNamesFrom(invoice.allowed_month_names);
  if (configured.length > 0) return configured;
  const feeType = invoiceFeeType(invoice);
  const billingMode = invoiceBillingMode(invoice);
  if (feeType !== "tuition" || billingMode === "one_time") return [];
  if (billingMode === "monthly") return [...monthNames];
  return [];
}

function invoicePaidMonthNames(invoice: Record<string, unknown>) {
  const paid = selectedMonthNamesFrom(invoice.paid_month_names);
  return paid.sort((left, right) =>
    (monthNameLookup.get(left.toLowerCase()) ?? 99) -
    (monthNameLookup.get(right.toLowerCase()) ?? 99)
  );
}

function invoiceMonthlyAmount(invoice: Record<string, unknown>) {
  const configured = money(invoice.monthly_amount);
  if (configured > 0) return configured;
  const allowedCount = invoiceAllowedMonthNames(invoice).length || 10;
  return money(
    money(invoice.net_amount ?? invoice.total_amount) / allowedCount,
  );
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
  const feeType = invoiceFeeType(invoice);
  const billingMode = invoiceBillingMode(invoice);
  const allowedMonthNames = invoiceAllowedMonthNames(invoice);
  const paidMonthNames = invoicePaidMonthNames(invoice);
  const unpaidMonthNames = allowedMonthNames.filter((month) =>
    !paidMonthNames.includes(month)
  );
  const monthlyAmount = feeType === "tuition"
    ? invoiceMonthlyAmount(invoice)
    : 0;
  return {
    ...invoice,
    fee_type: feeType,
    billing_mode: billingMode,
    priority: feeType === "tuition" ? 2 : 1,
    fee_item_name: text(invoice.fee_item_name, invoiceComponentLabel(invoice)),
    monthly_amount: monthlyAmount,
    term_amount: money(invoice.term_amount),
    term_count: Math.max(0, parseInt(text(invoice.term_count, "0")) || 0),
    allowed_month_names: allowedMonthNames,
    paid_month_names: paidMonthNames,
    unpaid_month_names: unpaidMonthNames,
  };
}

function validateInvoiceSelection(
  invoice: Record<string, unknown>,
  selectedMonthNames: string[],
  selectedMonths: number,
  selectedTerms: number,
) {
  const decorated = decorateInvoice(invoice);
  const feeType = text(decorated.fee_type);
  const billingMode = text(decorated.billing_mode);
  const balance = money(
    invoice.balance ?? invoice.net_amount ?? invoice.total_amount,
  );

  // One-time fees: book_kit or any fee with one_time billing mode.
  if (feeType !== "tuition" || billingMode === "one_time") {
    if (
      selectedMonthNames.length > 0 || selectedMonths > 0 || selectedTerms > 0
    ) {
      throw new Error("This fee is one-time only and cannot be split");
    }
    return {
      amount: balance,
      selectedMonthNames: [] as string[],
      selectedMonths: 0,
      selectedTerms: 0,
      paidMonthNames: decorated.paid_month_names as string[],
    };
  }

  // Monthly fees: month-by-month installment payment.
  if (billingMode === "monthly") {
    if (selectedMonthNames.length > 10 || selectedMonths > 10) {
      throw new Error("selected_months cannot exceed the June–March cycle of 10");
    }
    if (selectedTerms > 0) {
      throw new Error("selected_terms cannot exceed configured academic terms");
    }

    const unpaidMonthNames = decorated.unpaid_month_names as string[];
    if (unpaidMonthNames.length === 0) {
      throw new Error("All monthly installments are already paid");
    }

    let months = selectedMonthNames.length > 0
      ? selectedMonthNames
      : unpaidMonthNames.slice(0, Math.max(1, selectedMonths));
    months = selectedMonthNamesFrom(months);
    if (months.length === 0) {
      throw new Error("Select at least one monthly installment");
    }
    if (months.length > unpaidMonthNames.length) {
      throw new Error(
        "Selected months exceed the remaining unpaid installments",
      );
    }
    const expectedPrefix = unpaidMonthNames.slice(0, months.length);
    if (!monthNamesEqual(months, expectedPrefix)) {
      throw new Error(
        "Monthly installments must be paid in order without skipping",
      );
    }

    const monthlyAmount = invoiceMonthlyAmount(invoice);
    const amount = months.length === unpaidMonthNames.length
      ? balance
      : money(monthlyAmount * months.length);
    return {
      amount,
      selectedMonthNames: months,
      selectedMonths: months.length,
      selectedTerms: 0,
      paidMonthNames: decorated.paid_month_names as string[],
    };
  }

  // Lump-sum fees: term, yearly, or any other billing mode — pay full balance.
  if (balance <= 0) {
    throw new Error("This fee has already been fully paid");
  }
  return {
    amount: balance,
    selectedMonthNames: [] as string[],
    selectedMonths: 0,
    selectedTerms: 0,
    paidMonthNames: decorated.paid_month_names as string[],
  };
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

function _invoicePayableAmount(
  invoice: Record<string, unknown>,
  selectedMonthNames: string[],
  selectedMonths: number,
  selectedTerms: number,
) {
  return validateInvoiceSelection(
    invoice,
    selectedMonthNames,
    selectedMonths,
    selectedTerms,
  ).amount;
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
    if (data?.data) return data;
  }
  return null;
}

async function applyInvoiceAllocationUpdate(
  svc: SupabaseClient,
  school: string,
  invoice: Record<string, unknown>,
  amount: number,
  selectedMonthNames: string[],
) {
  const decorated = decorateInvoice(invoice);
  const feeType = text(decorated.fee_type);
  const paidMonthNames = feeType === "tuition"
    ? [
      ...new Set([
        ...(decorated.paid_month_names as string[]),
        ...selectedMonthNames,
      ]),
    ]
    : [];
  const newPaid = money(invoice.paid_amount) + amount;
  const newBalance = Math.max(0, money(invoice.net_amount) - newPaid);
  const status = newBalance <= 0 ? "paid" : "partial";
  const payload: Record<string, unknown> = {
    paid_amount: newPaid,
    balance: newBalance,
    status,
    updated_at: new Date().toISOString(),
  };
  if (feeType === "tuition") {
    payload.paid_month_names = paidMonthNames;
  }
  const { error } = await svc.from("fee_invoices").update(payload)
    .eq("id", text(invoice.id))
    .eq("school_id", school);
  if (error) throw error;
  return {
    paidAmount: newPaid,
    balance: newBalance,
    status,
    paidMonthNames,
  };
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
    return { ...row, category, fee_category: category };
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

  return await Promise.all(rows.map(async (row) => {
    const storedProof = text(row.proof_url);
    const proofUrl = storedProof.startsWith("payment-proofs/")
      ? (await svc.storage.from("payment-proofs").createSignedUrl(
        storedProof,
        10 * 60,
      )).data?.signedUrl ?? ""
      : storedProof;
    return {
      ...row,
      proof_url: proofUrl,
      invoice: invoicesById.get(text(row.invoice_id)) ?? null,
      student: studentsById.get(text(row.student_id)) ?? null,
      parent_user: parentsById.get(text(row.parent_user_id)) ?? null,
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
      studentQuery = studentQuery.eq("current_section_id", structure.section_id);
    } else if (structure.grade_id) {
      const { data: sections } = await svc.from("sections")
        .select("id")
        .eq("school_id", school).eq("grade_id", structure.grade_id);
      const sectionIds = (sections ?? []).map((s: Record<string, unknown>) => text(s.id)).filter(Boolean);
      if (sectionIds.length > 0) {
        studentQuery = studentQuery.in("current_section_id", sectionIds);
      }
    }
    const { data: students } = await studentQuery;
    const studentIds = (students ?? []).map((s: Record<string, unknown>) => text(s.id)).filter(Boolean);

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

async function deleteInvoiceWorkflowRows(
  svc: SupabaseClient,
  school: string,
  invoiceIds: string[],
) {
  if (invoiceIds.length === 0) return { 
    deleted_invoices: 0,
    deleted_receipts: 0, 
    deleted_payments: 0,
    deleted_requests: 0,
  };
  const scoped = await svc.from("fee_invoices").select("id").eq(
    "school_id",
    school,
  ).in("id", invoiceIds);
  if (scoped.error) throw new Error(scoped.error.message);
  const ids = (scoped.data ?? []).map((row) => text(row.id)).filter(Boolean);
  if (ids.length === 0) return { 
    deleted_invoices: 0,
    deleted_receipts: 0, 
    deleted_payments: 0,
    deleted_requests: 0,
  };

  // Delete receipts by payment IDs, since fee_receipts are linked to payments.
  const paymentIds = await svc.from("payments").select("id").eq(
    "school_id",
    school,
  ).in("invoice_id", ids);
  if (paymentIds.error) throw new Error(paymentIds.error.message);
  const paymentIdList = (paymentIds.data ?? []).map((row) => text(row.id)).filter(Boolean);

  const receiptDelete = paymentIdList.length === 0
    ? { error: null, count: 0 }
    : await svc.from("fee_receipts").delete().in("payment_id", paymentIdList);
  if (receiptDelete.error) throw new Error(receiptDelete.error.message);

  // Delete parent payment requests
  const requestDelete = await svc.from("parent_payment_requests").delete().eq(
    "school_id",
    school,
  ).in("invoice_id", ids);
  if (requestDelete.error) throw new Error(requestDelete.error.message);

  // Delete payments (cascades to receipts via ON DELETE CASCADE)
  const paymentDelete = await svc.from("payments").delete().eq(
    "school_id",
    school,
  ).in("invoice_id", ids);
  if (paymentDelete.error) throw new Error(paymentDelete.error.message);

  // Delete invoice items (normally cascades from invoices via ON DELETE CASCADE)
  const invoiceItemsDelete = await svc.from("fee_invoice_items").delete().in(
    "invoice_id",
    ids,
  );
  if (invoiceItemsDelete.error) throw new Error(invoiceItemsDelete.error.message);
  // Delete invoices themselves
  const invoiceDelete = await svc.from("fee_invoices").delete().eq(
    "school_id",
    school,
  ).in("id", ids);
  if (invoiceDelete.error) throw new Error(invoiceDelete.error.message);

  return {
    deleted_invoices: ids.length,
    deleted_receipts: receiptDelete.count ?? 0,
    deleted_payments: paymentDelete.count ?? 0,
    deleted_requests: requestDelete.count ?? 0,
  };
}

async function deleteFeeStructureWorkflowRows(
  svc: SupabaseClient,
  school: string,
  structureId: string,
) {
  // 1. Get all invoice IDs related to this fee structure
  const invoiceIds = await invoiceIdsForFeeStructure(svc, school, structureId);
  
  // 2. Delete invoice-related workflow (payments, receipts, requests, invoices, items)
  const invoiceDeletionStats = await deleteInvoiceWorkflowRows(
    svc,
    school,
    invoiceIds,
  );

  // 3. Delete fee_installments (linked to this structure)
  const installmentsDelete = await svc.from("fee_installments").delete().eq(
    "fee_structure_id",
    structureId,
  );
  if (installmentsDelete.error) throw new Error(installmentsDelete.error.message);

  // 4. Delete fee_concessions (linked to this structure)
  const concessionDelete = await svc.from("fee_concessions").delete().eq(
    "school_id",
    school,
  ).eq("fee_structure_id", structureId);
  if (concessionDelete.error) throw new Error(concessionDelete.error.message);

  return { 
    deleted_invoices: invoiceDeletionStats.deleted_invoices,
    deleted_receipts: invoiceDeletionStats.deleted_receipts,
    deleted_payments: invoiceDeletionStats.deleted_payments,
    deleted_requests: invoiceDeletionStats.deleted_requests,
    deleted_installments: installmentsDelete.count ?? 0,
    deleted_concessions: concessionDelete.count ?? 0,
  };
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
        error instanceof Error ? error.message : "failed to queue fee report export",
      );
    }
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
      frequency: normalizeFrequency(input.frequency ?? input.billing_mode),
      fee_type: feeType,
      billing_mode: text(
        input.billing_mode,
        feeType === "tuition" ? "monthly" : "one_time",
      ),
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
      const { error } = await svc.from("fee_categories").delete().eq(
        "id",
        seg,
      ).eq("school_id", school);
      if (error) return fail(error.message);
      return ok({ success: true });
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
        return ok(await attachFeeCategories(svc, school, data ?? []));
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
        return fail("from_academic_year_id and to_academic_year_id are required");
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
        const { error: insertErr } = await svc.from("fee_structures").insert(toInsert);
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
      const { data: structure, error } = await svc.from("fee_structures")
        .select(
          "*",
        ).eq("id", seg).eq("school_id", school).maybeSingle();
      if (error) return fail(error.message);
      let hydratedStructure = structure;
      if (structure) {
        try {
          hydratedStructure =
            (await attachFeeCategories(svc, school, [structure]))[0];
        } catch (error) {
          return fail(
            error instanceof Error
              ? error.message
              : "failed to load fee category",
          );
        }
      }
      return ok({
        structure_id: seg,
        structure: hydratedStructure,
        affected_invoice_count: 0,
        include_partially_paid: false,
        mode: "preview",
      });
    }

    if (
      seg && parts[1] === "invoice-sync" && parts[2] === "apply" &&
      method === "POST"
    ) {
      return ok({
        structure_id: seg,
        synced_invoice_count: 0,
        include_partially_paid: body.include_partially_paid ?? false,
        mode: "apply",
      });
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
      const removePending = url.searchParams.get("remove_pending") !== "false";
      let cleanup: Record<string, unknown> = { deleted_invoices: 0 };
      if (removePending) {
        try {
          cleanup = await deleteFeeStructureWorkflowRows(svc, school, seg);
        } catch (error) {
          return fail(
            error instanceof Error
              ? error.message
              : "failed to clear fee structure dues",
          );
        }
      }
      const { error } = await svc.from("fee_structures").delete().eq(
        "id",
        seg,
      ).eq("school_id", school);
      if (error) return fail(error.message);

      // Reconciliation sweep: after the structure is deleted (which sets
      // fee_structure_id = NULL via ON DELETE SET NULL), clean up any remaining
      // orphaned unpaid invoices that have no fee_structure_id link.
      if (removePending) {
        try {
          const { data: orphanedInvoices } = await svc.from("fee_invoices")
            .select("id")
            .eq("school_id", school)
            .neq("status", "paid")
            .is("fee_structure_id", null);
          const orphanIds = (orphanedInvoices ?? [])
            .map((r: Record<string, unknown>) => text(r.id))
            .filter(Boolean);
          if (orphanIds.length > 0) {
            await deleteInvoiceWorkflowRows(svc, school, orphanIds);
          }
          (cleanup as Record<string, unknown>).reconciled_orphans = orphanIds.length;
        } catch (_) {
          // Best-effort reconciliation — don't fail the whole request.
        }
      }

      return ok({ success: true, ...cleanup });
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
        "*, student:students(first_name, last_name, admission_number, student_id_number, current_section_id), fee_invoice_items(*), payments(*)",
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
          const feeType = normalizeFeeType(
            structure.fee_type ??
              (structure.fee_category as Record<string, unknown> | null)?.name,
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
          const structureTag = feeType !== "tuition" ? "ONE" : text(
            (structure.fee_category as Record<string, unknown> | null)?.name,
            "TUI",
          )
            .replace(/[^A-Za-z0-9]+/g, "")
            .slice(0, 6)
            .toUpperCase() || "TUI";
          const invoiceNumber = `FEE-${label}-${
            studentCode || text(student.id).slice(0, 8)
          }-${structureTag}-${text(structure.id).slice(0, 4).toUpperCase()}`;
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
            monthly_amount: billingMode === "monthly" ? money(total / 10) : 0,
            term_amount: 0,
            term_count: 0,
            allowed_month_names: billingMode === "monthly" ? monthNames : [],
            paid_month_names: [],
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
                (structure.fee_category as Record<string, unknown> | null)
                  ?.name,
                "Fee",
              ),
              amount: total,
            });
          if (itemError) return fail(itemError.message);
          created++;
          createdInvoices.push(decorateInvoice(invoice));
        }
      }
      return ok({
        created,
        skipped,
        generated_count: created,
        skipped_count: skipped,
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
        "*, student:students(first_name, last_name, admission_number, student_id_number, current_section_id), fee_invoice_items(*), payments(*)",
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
      const selectedMonthNames = selectedMonthNamesFrom(
        body.selected_month_names,
      );
      const selectedMonths = parseInt(
        text(body.selected_months, `${selectedMonthNames.length || 0}`),
      ) || 0;
      const selectedTerms = parseInt(text(body.selected_terms, "0")) || 0;
      const { data: invoice, error: invoiceError } = body.invoice_id
        ? await svc.from("fee_invoices").select("*").eq("id", body.invoice_id)
          .eq("school_id", school).maybeSingle()
        : { data: null };
      if (invoiceError) return fail(invoiceError.message);
      if (!invoice) return fail("Invoice not found", 404);
      if (!isAdminOrPrincipal(user) && text(body.payment_method, "upi").toLowerCase() !== "upi") {
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
        selection = validateInvoiceSelection(
          invoice as Record<string, unknown>,
          selectedMonthNames,
          selectedMonths,
          selectedTerms,
        );
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to validate tuition selection",
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
        selected_months: selection.selectedMonths,
        selected_month_names: selection.selectedMonthNames,
        selected_terms: selection.selectedTerms,
        remarks: body.remarks ?? "",
        status: "initiated",
      }).select().single();
      if (requestError) return fail(requestError.message);
      return ok({
        id: request.id,
        request_reference: reference,
        invoice_id: body.invoice_id ?? null,
        payment_method: body.payment_method ?? "",
        amount: selection.amount,
        selected_months: selection.selectedMonths,
        selected_month_names: selection.selectedMonthNames,
        selected_terms: selection.selectedTerms,
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
      const selectedMonthNames = selectedMonthNamesFrom(
        form.get("selected_month_names"),
      );
      const selectedMonths = parseInt(
        text(
          form.get("selected_months"),
          `${selectedMonthNames.length || 0}`,
        ),
      ) || 0;
      const selectedTerms = parseInt(text(form.get("selected_terms"), "0")) ||
        0;
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
        selection = validateInvoiceSelection(
          invoice as Record<string, unknown>,
          selectedMonthNames.length > 0
            ? selectedMonthNames
            : selectedMonthNamesFrom(existingRequest?.selected_month_names),
          selectedMonths || money(existingRequest?.selected_months),
          selectedTerms || money(existingRequest?.selected_terms),
        );
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to validate tuition selection",
        );
      }
      const expectedAmount = selection.amount;
      if (money(form.get("amount")) !== expectedAmount) {
        return fail(
          `payment amount must be ${
            expectedAmount.toFixed(2)
          } for selected fee interval`,
        );
      }
      let proofUrl = "";
      if (screenshot) {
        try {
          proofUrl = await uploadPrivatePaymentProof(
            svc, school, text(existingRequest?.id, requestReference), screenshot,
          );
        } catch (error) {
          return fail(error instanceof Error ? error.message : "proof upload failed");
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
        selected_months: selection.selectedMonths,
        selected_month_names: selection.selectedMonthNames,
        selected_terms: selection.selectedTerms,
        proof_url: proofUrl,
        proof_file_name: screenshot?.name ?? null,
        proof_content_type: screenshot?.type ?? null,
        proof_size: screenshot?.size ?? null,
        remarks: `${form.get("remarks") ?? ""}`,
        status: "pending_verification",
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
          const validPrincipals = principals.filter((p: Record<string, unknown>) => text(p.id));
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
            const { data: feeEvents, error: feeEventError } = await svc
              .from("notification_events")
              .insert(
                validPrincipals.map((p: Record<string, unknown>) => ({
                  school_id: school,
                  user_id: text(p.id),
                  event_type: "fee_payment_submitted",
                  title: "New payment proof submitted",
                  body: `A parent submitted ${amountLabel} payment proof for ${studentName}. Please review and verify.`,
                  event_data: {
                    payment_request_id: data.id,
                    invoice_id: invoice.id,
                    student_id: invoice.student_id,
                    amount: expectedAmount,
                    request_reference: data.request_reference,
                    message: `A parent submitted ${amountLabel} payment proof for ${studentName}. Please review and verify.`,
                  },
                  entity_type: "parent_payment_requests",
                  entity_id: data.id,
                  processed: false,
                }))
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
      const form = await req.formData().catch(() => null);
      if (!form) return fail("multipart form required");
      const screenshot = form.get("screenshot") as File | null;
      const paymentId = normalized.split("/").filter(Boolean)[0];
      let proofUrl: string | null = null;
      if (screenshot) {
        try {
          proofUrl = await uploadPrivatePaymentProof(svc, school, paymentId, screenshot);
        } catch (error) {
          return fail(error instanceof Error ? error.message : "proof upload failed");
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
      }).eq("id", paymentId).eq("school_id", school).select().single();
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
      const selectedMonthNames = selectedMonthNamesFrom(
        body.selected_month_names,
      );
      const selectedMonths = parseInt(
        text(body.selected_months, `${selectedMonthNames.length || 0}`),
      ) || 0;
      const selectedTerms = parseInt(text(body.selected_terms, "0")) || 0;
      let selection;
      try {
        selection = validateInvoiceSelection(
          invoice as Record<string, unknown>,
          selectedMonthNames,
          selectedMonths,
          selectedTerms,
        );
      } catch (error) {
        return fail(
          error instanceof Error
            ? error.message
            : "failed to validate fee selection",
        );
      }
      if (amount !== selection.amount) {
        return fail(
          `payment amount must be ${
            selection.amount.toFixed(2)
          } for selected fee interval`,
        );
      }
      const { data: payment, error } = await svc.rpc("record_fee_payment", {
        p_school_id: school, p_invoice_id: invoiceId, p_student_id: invoice.student_id,
        p_amount: amount, p_payment_method: text(body.payment_method ?? body.payment_mode, "cash"),
        p_reference_number: text(body.reference_number ?? body.transaction_ref ?? body.transaction_id ?? body.receipt_number),
        p_paid_at: text(body.payment_date) ? `${text(body.payment_date)}T00:00:00.000Z` : new Date().toISOString(),
        p_notes: text(body.remarks), p_created_by: user.id,
        p_selected_month_names: selection.selectedMonthNames, p_selected_months: selection.selectedMonths,
      }).single();
      if (error) return fail(error.message);
      const atomicPayment = payment as Record<string, unknown>;
      return ok({
        ...atomicPayment,
        selected_month_names: selection.selectedMonthNames,
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
    const { data, error } = await svc.from("fee_invoices").select(
      "*, fee_invoice_items(*)",
    ).eq("school_id", school).eq("student_id", studentId).order(
      "invoice_date",
      { ascending: false },
    );
    if (error) return fail(error.message);
    return ok((data ?? []).map((invoice: Record<string, unknown>) => {
      const decorated = decorateInvoice(invoice);
      return {
        ...decorated,
        amount: money(
          invoice.balance ?? invoice.net_amount ?? invoice.total_amount,
        ),
        balance_amount: money(
          invoice.balance ?? invoice.net_amount ?? invoice.total_amount,
        ),
        monthly_amount: decorated.monthly_amount,
      };
    }));
  }

  if (feesPath.startsWith("/payment-requests")) {
    const seg = path.replace(/^\/fees\/payment-requests/, "").split("/").filter(
      Boolean,
    )[0];
    if (!seg && method === "GET") {
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
      const status = text(body.status, "pending");
      const { data: existing, error: existingError } = await svc.from(
        "parent_payment_requests",
      )
        .select("*")
        .eq("id", seg)
        .eq("school_id", school)
        .maybeSingle();
      if (existingError) return fail(existingError.message);
      if (!existing) return fail("not found", 404);
      let paymentId: string | null = null;
      let receiptId: string | null = null;
      if (["approved", "completed", "paid"].includes(status)) {
        const { data: invoice } = await svc.from("fee_invoices").select("*")
          .eq("id", existing.invoice_id)
          .eq("school_id", school)
          .maybeSingle();
        if (!invoice) return fail("Invoice not found", 404);
        let selection;
        try {
          selection = validateInvoiceSelection(
            invoice as Record<string, unknown>,
            selectedMonthNamesFrom(existing.selected_month_names),
            money(existing.selected_months),
            money(existing.selected_terms),
          );
        } catch (validationError) {
          return fail(
            validationError instanceof Error
              ? validationError.message
              : "failed to validate approved fee selection",
          );
        }
        const { data: payment, error: paymentError } = await svc.rpc("record_fee_payment", {
          p_school_id: school, p_invoice_id: existing.invoice_id, p_student_id: existing.student_id,
          p_amount: existing.amount, p_payment_method: existing.payment_method ?? "upi",
          p_reference_number: existing.transaction_ref ?? existing.transaction_id ?? existing.request_reference,
          p_paid_at: existing.payment_date ?? new Date().toISOString(), p_notes: existing.remarks ?? "",
          p_created_by: user.id, p_selected_month_names: selection.selectedMonthNames,
          p_selected_months: selection.selectedMonths, p_request_id: seg,
        }).single();
        if (paymentError) return fail(paymentError.message);
        const atomicPayment = payment as Record<string, unknown>;
        paymentId = text(atomicPayment.payment_id);
        receiptId = text(atomicPayment.receipt_id);
      }
      const { data, error } = await svc.from("parent_payment_requests").update({
        status: body.status ?? "pending",
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
          const isApproved = ["approved", "completed", "paid"].includes(status);
          const statusLabel = isApproved ? "approved" : (status === "clarification_required" ? "requires clarification" : "rejected");
          const amountLabel = `INR ${money(existing.amount).toFixed(0)}`;
          const approvalBody = isApproved
            ? `Your ${amountLabel} payment has been verified and approved. Receipt is now available.`
            : `Your ${amountLabel} payment was ${statusLabel}.${body.admin_remarks ? ` Remark: ${text(body.admin_remarks)}` : ""}`;
          const { data: feeDecisionEvent } = await svc.from("notification_events").insert({
            school_id: school,
            user_id: parentUserId,
            event_type: isApproved ? "fee_payment_approved" : "fee_payment_rejected",
            title: isApproved ? "Payment Approved ✅" : `Payment ${statusLabel}`,
            body: approvalBody,
            event_data: {
              payment_request_id: seg,
              invoice_id: existing.invoice_id,
              amount: money(existing.amount),
              status: status,
              admin_remarks: text(body.admin_remarks),
              message: approvalBody,
            },
            entity_type: "parent_payment_requests",
            entity_id: seg,
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
    const payload = {
      scope: "school",
      upi_id: body.upi_id ?? "",
      payee_name: body.payee_name ?? "",
      merchant_code: body.merchant_code ?? "",
      qr_note: body.qr_note ?? "",
      qr_image_url: body.qr_image_url ?? "",
      upi_enabled: body.upi_enabled ?? true,
    };
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
    const payload = {
      scope: body.scope ??
        ((existing.data as Record<string, unknown> | null)?.["scope"]) ??
        "school",
      grade_id: body.grade_id ??
        ((existing.data as Record<string, unknown> | null)?.["grade_id"]) ?? "",
      section_id: body.section_id ??
        ((existing.data as Record<string, unknown> | null)?.["section_id"]) ??
        "",
      upi_id: body.upi_id ?? "",
      payee_name: body.payee_name ?? "",
      merchant_code: body.merchant_code ?? "",
      qr_note: body.qr_note ?? "",
      qr_image_url: body.qr_image_url ?? "",
      upi_enabled: body.upi_enabled ?? true,
    };
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
      const { data, error } = await svc.from("fee_concessions").select("*").eq(
        "school_id",
        school,
      ).order("created_at", { ascending: false });
      if (error) return fail(error.message);
      return ok(data ?? []);
    }
    if (!seg && method === "POST") {
      const { data, error } = await svc.from("fee_concessions").insert({
        ...body,
        school_id: school,
      }).select().single();
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
        if (!currentStudentId) return fail("student_id not found on invoice", 400);

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

        const eventIds = (insertedEvents ?? []).map((row: { id: string }) => text(row.id)).filter(Boolean);
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
          return ok({ success: true, message: "No outstanding invoices found." });
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
          
          const messageBody = `Reminder: Outstanding balance of ${amountLabel} is due for ${studentName} by ${dueDateLabel}.`;

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

          const eventIds = (insertedEvents ?? []).map((row: { id: string }) => text(row.id)).filter(Boolean);
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
    const { data, error } = await svc.from("parent_payment_requests").insert({
      ...body,
      school_id: school,
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

// handlers/fees.ts — categories, structures, invoices, payments, requests, config
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";

function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}

function roleName(u: User) {
  return `${u.app_metadata?.role_name ?? u.app_metadata?.role ?? ""}`.toLowerCase();
}

function isAdminOrPrincipal(u: User) {
  return ["admin", "principal", "super_admin"].includes(roleName(u));
}

function text(value: unknown, fallback = "") {
  const raw = `${value ?? ""}`.trim();
  return raw === "null" ? fallback : raw || fallback;
}

function money(value: unknown) {
  const parsed = typeof value === "number" ? value : parseFloat(`${value ?? 0}`);
  return Math.round((Number.isFinite(parsed) ? parsed : 0) * 100) / 100;
}

function normalizeFrequency(value: unknown) {
  const raw = text(value, "term").toLowerCase().replaceAll("-", "_").replaceAll(" ", "_");
  if (raw.includes("one")) return "one_time";
  if (raw.includes("year")) return "yearly";
  if (raw.includes("month")) return "monthly";
  if (raw.includes("term")) return "term";
  return raw || "term";
}

const monthNames = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];

function selectedMonthNamesFrom(value: unknown) {
  const raw = Array.isArray(value) ? value : text(value).split(",");
  const selected = raw.map((item) => text(item)).filter((item) =>
    monthNames.map((m) => m.toLowerCase()).includes(item.toLowerCase())
  );
  return [...new Set(selected.map((item) =>
    monthNames.find((month) => month.toLowerCase() === item.toLowerCase())!
  ))];
}

function dueDateFrom(dueDate: unknown, dueDay: unknown) {
  const explicit = text(dueDate);
  if (explicit) return explicit.split("T")[0];
  const now = new Date();
  const day = Math.min(Math.max(parseInt(text(dueDay, "10")), 1), 28);
  return `${now.getUTCFullYear()}-${`${now.getUTCMonth() + 1}`.padStart(2, "0")}-${`${day}`.padStart(2, "0")}`;
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

function invoicePayableAmount(
  invoice: Record<string, unknown>,
  selectedMonthNames: string[],
  selectedMonths: number,
  selectedTerms: number,
) {
  const balance = money(invoice.balance ?? invoice.net_amount ?? invoice.total_amount);
  const monthCount = selectedMonthNames.length || selectedMonths;
  if (monthCount > 0) {
    return Math.min(balance, money((money(invoice.net_amount ?? invoice.total_amount) / 12) * monthCount));
  }
  if (selectedTerms > 0) {
    return Math.min(balance, money((money(invoice.net_amount ?? invoice.total_amount) / selectedTerms) * selectedTerms));
  }
  return balance;
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
  const { data, error } = await svc.from("frontend_records").upsert({
    school_id: school,
    table_name: "payment_config",
    record_id: recordId,
    data: merged,
  }, { onConflict: "school_id,table_name,record_id" }).select().single();
  if (error) throw error;
  return data;
}

async function attachFeeCategories(
  svc: SupabaseClient,
  school: string,
  rows: Record<string, unknown>[],
) {
  const categoryIds = [...new Set(rows.map((row) =>
    text(row.fee_category_id ?? row.category_id)
  ).filter(Boolean))];
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
    const id = crypto.randomUUID();
    const payload = {
      id,
      report_title: `${body.report_title ?? body.report ?? "Fees report"}`.trim(),
      report_type: `${body.report_type ?? "fees"}`.trim(),
      format: `${body.format ?? "pdf"}`.trim().toLowerCase(),
      scope: `${body.scope ?? "fees"}`.trim(),
      parameters: body.parameters ?? body,
      status: "queued",
      requested_by: user.id,
      created_at: new Date().toISOString(),
      download_url: "",
    };
    const { data, error } = await svc.from("frontend_records").insert({
      school_id: school,
      table_name: "fee_report_exports",
      record_id: id,
      data: payload,
    }).select().single();
    if (error) return fail(error.message);
    return ok(data?.data ?? payload);
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
      is_mandatory: input.is_mandatory ?? input.is_active ?? true,
    };
  }

  if (path.startsWith("/fee-categories") || feesPath.startsWith("/categories")) {
    const base = path.startsWith("/fee-categories") ? "/fee-categories" : "/fees/categories";
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

  if (path.startsWith("/fee-structures") || feesPath.startsWith("/structures")) {
    const base = path.startsWith("/fee-structures") ? "/fee-structures" : "/fees/structures";
    const remainder = path.slice(base.length);
    const parts = remainder.split("/").filter(Boolean);
    const seg = parts[0];

    if (!seg && method === "GET") {
      let q = svc.from("fee_structures").select(
        "*, grade:grades(*), section:sections(*)",
      ).eq("school_id", school);
      if (url.searchParams.get("academic_year_id")) q = q.eq("academic_year_id", url.searchParams.get("academic_year_id")!);
      if (url.searchParams.get("grade_id")) q = q.eq("grade_id", url.searchParams.get("grade_id")!);
      if (url.searchParams.get("section_id")) q = q.eq("section_id", url.searchParams.get("section_id")!);
      const { data, error } = await q;
      if (error) return fail(error.message);
      try {
        return ok(await attachFeeCategories(svc, school, data ?? []));
      } catch (error) {
        return fail(error instanceof Error ? error.message : "failed to load fee categories");
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
      return ok({
        copied_count: 0,
        skipped_count: 0,
        from_academic_year_id: body.from_academic_year_id ?? null,
        to_academic_year_id: body.to_academic_year_id ?? null,
      });
    }

    if (seg && parts[1] === "invoice-sync" && parts[2] === "preview" && method === "POST") {
      const { data: structure, error } = await svc.from("fee_structures").select(
        "*",
      ).eq("id", seg).eq("school_id", school).maybeSingle();
      if (error) return fail(error.message);
      let hydratedStructure = structure;
      if (structure) {
        try {
          hydratedStructure = (await attachFeeCategories(svc, school, [structure]))[0];
        } catch (error) {
          return fail(error instanceof Error ? error.message : "failed to load fee category");
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

    if (seg && parts[1] === "invoice-sync" && parts[2] === "apply" && method === "POST") {
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
      const { error } = await svc.from("fee_structures").delete().eq(
        "id",
        seg,
      ).eq("school_id", school);
      if (error) return fail(error.message);
      return ok({ success: true });
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
        "*, student:students(first_name, last_name, admission_number, current_section_id), fee_invoice_items(*)",
        { count: "exact" },
      ).eq("school_id", school).range((page - 1) * size, page * size - 1);
      if (url.searchParams.get("student_id")) q = q.eq("student_id", url.searchParams.get("student_id")!);
      if (url.searchParams.get("status")) q = q.eq("status", url.searchParams.get("status")!);
      if (url.searchParams.get("academic_year_id")) q = q.eq("academic_year_id", url.searchParams.get("academic_year_id")!);
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

    if (seg === "generate" && method === "POST") {
      const academicYearId = text(body.academic_year_id);
      const gradeId = text(body.grade_id);
      const sectionId = text(body.section_id);
      const studentId = text(body.student_id);
      if (!academicYearId || !gradeId) return fail("academic_year_id and grade_id are required");

      let structuresQuery = svc.from("fee_structures").select("*")
        .eq("school_id", school)
        .eq("academic_year_id", academicYearId)
        .eq("grade_id", gradeId);
      if (sectionId) {
        structuresQuery = structuresQuery.or(`section_id.is.null,section_id.eq.${sectionId}`);
      }
      const { data: rawStructures, error: structuresError } = await structuresQuery;
      if (structuresError) return fail(structuresError.message);
      const includeOneTime = body.include_one_time === true;
      const includeYearly = body.include_yearly === true;
      let hydratedStructures: Record<string, unknown>[];
      try {
        hydratedStructures = await attachFeeCategories(svc, school, rawStructures ?? []);
      } catch (error) {
        return fail(error instanceof Error ? error.message : "failed to load fee categories");
      }
      const structures = hydratedStructures.filter((row: Record<string, unknown>) => {
        const frequency = normalizeFrequency(row.frequency);
        if (frequency === "one_time") return includeOneTime;
        if (frequency === "yearly") return includeYearly;
        return true;
      });
      if (structures.length === 0) {
        return ok({ created: 0, skipped: 0, generated_count: 0, skipped_count: 0 });
      }

      let sectionIds = sectionId ? [sectionId] : [];
      if (sectionIds.length === 0) {
        const { data: sections, error: sectionError } = await svc.from("sections").select("id")
          .eq("school_id", school)
          .eq("grade_id", gradeId);
        if (sectionError) return fail(sectionError.message);
        sectionIds = (sections ?? []).map((section: Record<string, unknown>) => text(section.id)).filter(Boolean);
      }

      let studentsQuery = svc.from("students").select("*")
        .eq("school_id", school)
        .eq("status", "active");
      if (studentId) studentsQuery = studentsQuery.eq("id", studentId);
      else if (sectionIds.length > 0) studentsQuery = studentsQuery.in("current_section_id", sectionIds);
      const { data: students, error: studentsError } = await studentsQuery;
      if (studentsError) return fail(studentsError.message);

      let created = 0;
      let skipped = 0;
      const createdInvoices: Record<string, unknown>[] = [];
      const label = text(body.invoice_label, "Fees").replace(/[^A-Za-z0-9]+/g, "-").replace(/^-|-$/g, "").toUpperCase();
      for (const student of students ?? []) {
        const studentCode = text(student.admission_number ?? student.student_code ?? student.id).replace(/[^A-Za-z0-9]+/g, "").slice(-8);
        const invoiceNumber = `FEE-${label}-${studentCode || text(student.id).slice(0, 8)}`;
        const total = money(structures.reduce((sum: number, row: Record<string, unknown>) => sum + money(row.amount), 0));
        const dueDate = dueDateFrom(body.due_date, structures[0]?.due_day);
        const { data: invoice, error: invoiceError } = await svc.from("fee_invoices").insert({
          school_id: school,
          student_id: student.id,
          academic_year_id: academicYearId,
          invoice_number: invoiceNumber,
          due_date: dueDate,
          total_amount: total,
          net_amount: total,
          balance: total,
          status: "pending",
        }).select().single();
        if (invoiceError) {
          if (invoiceError.message.toLowerCase().includes("duplicate")) {
            skipped++;
            continue;
          }
          return fail(invoiceError.message);
        }
        const items = structures.map((structure: Record<string, unknown>) => ({
          invoice_id: invoice.id,
          fee_structure_id: structure.id,
          category_name: text((structure.fee_category as Record<string, unknown> | null)?.name, "Fee"),
          amount: money(structure.amount),
        }));
        const { error: itemError } = await svc.from("fee_invoice_items").insert(items);
        if (itemError) return fail(itemError.message);
        created++;
        createdInvoices.push({
          ...invoice,
          monthly_amount: money(total / 12),
        });
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
        "*, student:students(first_name, last_name, admission_number, current_section_id), fee_invoice_items(*)",
      ).eq("id", seg).eq("school_id", school).maybeSingle();
      if (error) return fail(error.message);
      if (!data) return fail("not found", 404);
      return ok(data);
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
      if (url.searchParams.get("student_id")) q = q.eq("student_id", url.searchParams.get("student_id")!);
      if (url.searchParams.get("invoice_id")) q = q.eq("invoice_id", url.searchParams.get("invoice_id")!);
      if (url.searchParams.get("status")) q = q.eq("status", url.searchParams.get("status")!);
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

    if (seg === "intent" && method === "POST") {
      const selectedMonthNames = selectedMonthNamesFrom(body.selected_month_names);
      const selectedMonths = parseInt(text(body.selected_months, `${selectedMonthNames.length || 0}`)) || 0;
      const selectedTerms = parseInt(text(body.selected_terms, "0")) || 0;
      const { data: invoice, error: invoiceError } = body.invoice_id
        ? await svc.from("fee_invoices").select("*").eq("id", body.invoice_id)
          .eq("school_id", school).maybeSingle()
        : { data: null };
      if (invoiceError) return fail(invoiceError.message);
      if (!invoice) return fail("Invoice not found", 404);
      try {
        if (!await parentCanAccessStudent(svc, school, user, text(invoice.student_id))) {
          return fail("Invoice does not belong to a linked child", 403);
        }
      } catch (error) {
        return fail(error instanceof Error ? error.message : "failed to verify parent access");
      }
      const amount = invoicePayableAmount(
        invoice as Record<string, unknown>,
        selectedMonthNames,
        selectedMonths,
        selectedTerms,
      );
      const reference = `FPR-${Date.now()}-${crypto.randomUUID().slice(0, 8).toUpperCase()}`;
      const { data: request, error: requestError } = await svc.from("parent_payment_requests").insert({
        school_id: school,
        student_id: invoice.student_id,
        invoice_id: invoice.id,
        parent_user_id: isAdminOrPrincipal(user) ? null : user.id,
        amount,
        payment_method: body.payment_method ?? "upi",
        request_reference: reference,
        payment_date: new Date().toISOString().split("T")[0],
        selected_months: selectedMonthNames.length || selectedMonths,
        selected_month_names: selectedMonthNames,
        selected_terms: selectedTerms,
        remarks: body.remarks ?? "",
        status: "initiated",
      }).select().single();
      if (requestError) return fail(requestError.message);
      return ok({
        id: request.id,
        request_reference: reference,
        invoice_id: body.invoice_id ?? null,
        payment_method: body.payment_method ?? "",
        amount,
        selected_months: selectedMonthNames.length || selectedMonths,
        selected_month_names: selectedMonthNames,
        selected_terms: selectedTerms,
        remarks: body.remarks ?? "",
      });
    }

    if (seg === "submit" && method === "POST") {
      const form = await req.formData().catch(() => null);
      if (!form) return fail("multipart form required");
      const screenshot = form.get("screenshot") as File | null;
      const invoiceId = text(form.get("invoice_id") ?? form.get("student_fee_id"));
      const requestId = text(form.get("payment_request_id") ?? form.get("request_id"));
      const requestReference = text(form.get("request_reference"));
      const selectedMonthNames = selectedMonthNamesFrom(form.get("selected_month_names"));
      const selectedMonths = parseInt(text(form.get("selected_months"), `${selectedMonthNames.length || 0}`)) || 0;
      const selectedTerms = parseInt(text(form.get("selected_terms"), "0")) || 0;
      let existingRequest: Record<string, unknown> | null = null;
      if (requestId || requestReference) {
        let requestQuery = svc.from("parent_payment_requests").select("*").eq("school_id", school);
        if (requestId) requestQuery = requestQuery.eq("id", requestId);
        else requestQuery = requestQuery.eq("request_reference", requestReference);
        const { data, error } = await requestQuery.maybeSingle();
        if (error) return fail(error.message);
        if (!data) return fail("Payment intent not found", 404);
        existingRequest = data as Record<string, unknown>;
      }
      const effectiveInvoiceId = text(existingRequest?.invoice_id, invoiceId);
      const { data: invoice, error: invoiceError } = await svc.from("fee_invoices").select("*")
        .eq("id", effectiveInvoiceId)
        .eq("school_id", school)
        .maybeSingle();
      if (invoiceError) return fail(invoiceError.message);
      if (!invoice) return fail("Invoice not found", 404);
      try {
        if (!await parentCanAccessStudent(svc, school, user, text(invoice.student_id))) {
          return fail("Invoice does not belong to a linked child", 403);
        }
      } catch (error) {
        return fail(error instanceof Error ? error.message : "failed to verify parent access");
      }
      const expectedAmount = invoicePayableAmount(
        invoice as Record<string, unknown>,
        selectedMonthNames.length > 0 ? selectedMonthNames : selectedMonthNamesFrom(existingRequest?.selected_month_names),
        selectedMonths || money(existingRequest?.selected_months),
        selectedTerms || money(existingRequest?.selected_terms),
      );
      if (money(form.get("amount")) !== expectedAmount) {
        return fail(`payment amount must be ${expectedAmount.toFixed(2)} for selected fee interval`);
      }
      let proofUrl = "";
      if (screenshot) {
        const filePath =
          `payment-proofs/${school}/${Date.now()}-${screenshot.name}`;
        const { error: uploadError } = await svc.storage.from("school-assets")
          .upload(filePath, screenshot, { upsert: true });
        if (uploadError) return fail(uploadError.message);
        proofUrl =
          svc.storage.from("school-assets").getPublicUrl(filePath).data.publicUrl;
      }
      const payload = {
        school_id: school,
        student_id: invoice.student_id,
        invoice_id: invoice.id,
        parent_user_id: isAdminOrPrincipal(user) ? null : user.id,
        amount: expectedAmount,
        payment_method: `${form.get("payment_method") ?? ""}` || "upi",
        request_reference: requestReference || text(existingRequest?.request_reference) || `FPR-${Date.now()}-${crypto.randomUUID().slice(0, 8).toUpperCase()}`,
        transaction_ref: text(form.get("transaction_ref") ?? form.get("transaction_id")),
        transaction_id: text(form.get("transaction_ref") ?? form.get("transaction_id")),
        payment_date: text(form.get("payment_date"), new Date().toISOString().split("T")[0]),
        selected_months: selectedMonthNames.length || selectedMonths || money(existingRequest?.selected_months),
        selected_month_names: selectedMonthNames.length > 0 ? selectedMonthNames : selectedMonthNamesFrom(existingRequest?.selected_month_names),
        selected_terms: selectedTerms || money(existingRequest?.selected_terms),
        proof_url: proofUrl,
        proof_file_name: screenshot?.name ?? null,
        proof_content_type: screenshot?.type ?? null,
        proof_size: screenshot?.size ?? null,
        remarks: `${form.get("remarks") ?? ""}`,
        status: "pending_verification",
        updated_at: new Date().toISOString(),
      };
      const { data, error } = existingRequest
        ? await svc.from("parent_payment_requests").update(payload).eq("id", existingRequest.id).eq("school_id", school).select().single()
        : await svc.from("parent_payment_requests").insert(payload).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }

    if (seg && normalized.endsWith("/resubmit") && method === "PATCH") {
      const form = await req.formData().catch(() => null);
      if (!form) return fail("multipart form required");
      const screenshot = form.get("screenshot") as File | null;
      let proofUrl: string | null = null;
      if (screenshot) {
        const filePath =
          `payment-proofs/${school}/${Date.now()}-${screenshot.name}`;
        const { error: uploadError } = await svc.storage.from("school-assets")
          .upload(filePath, screenshot, { upsert: true });
        if (uploadError) return fail(uploadError.message);
        proofUrl =
          svc.storage.from("school-assets").getPublicUrl(filePath).data.publicUrl;
      }
      const paymentId = normalized.split("/").filter(Boolean)[0];
      const { data, error } = await svc.from("parent_payment_requests").update({
        proof_url: proofUrl ?? undefined,
        remarks: `${form.get("remarks") ?? ""}`,
        status: "pending",
        updated_at: new Date().toISOString(),
      }).eq("id", paymentId).eq("school_id", school).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }

    if (!seg && method === "POST") {
      const { data: payment, error } = await svc.from("payments").insert({
        ...body,
        school_id: school,
        paid_at: new Date().toISOString(),
      }).select().single();
      if (error) return fail(error.message);
      const receiptNum = `RCP-${Date.now()}`;
      await svc.from("fee_receipts").insert({
        school_id: school,
        invoice_id: body.invoice_id ?? null,
        payment_id: payment.id,
        receipt_number: receiptNum,
        amount: body.amount ?? payment.amount ?? null,
        payment_method: body.payment_method ?? payment.payment_method ?? null,
        transaction_ref: body.reference_number ?? payment.reference_number ?? null,
      });
      if (body.invoice_id) {
        const { data: inv } = await svc.from("fee_invoices").select(
          "net_amount, paid_amount",
        ).eq("id", body.invoice_id).single();
        if (inv) {
          const newPaid = (inv.paid_amount ?? 0) + (body.amount ?? 0);
          const newBal = Math.max(0, (inv.net_amount ?? 0) - newPaid);
          await svc.from("fee_invoices").update({
            paid_amount: newPaid,
            balance: newBal,
            status: newBal <= 0 ? "paid" : "partial",
          }).eq("id", body.invoice_id);
        }
      }
      return ok({ ...payment, receipt_number: receiptNum });
    }
  }

  if (/^\/parent\/students\/[^/]+\/fees$/.test(path) && method === "GET") {
    const studentId = path.split("/")[3];
    try {
      if (!await parentCanAccessStudent(svc, school, user, studentId)) {
        return fail("Student does not belong to a linked child", 403);
      }
    } catch (error) {
      return fail(error instanceof Error ? error.message : "failed to verify parent access");
    }
    const { data, error } = await svc.from("fee_invoices").select(
      "*, fee_invoice_items(*)",
    ).eq("school_id", school).eq("student_id", studentId).order(
      "invoice_date",
      { ascending: false },
    );
    if (error) return fail(error.message);
    return ok((data ?? []).map((invoice: Record<string, unknown>) => ({
      ...invoice,
      amount: money(invoice.balance ?? invoice.net_amount ?? invoice.total_amount),
      balance_amount: money(invoice.balance ?? invoice.net_amount ?? invoice.total_amount),
      monthly_amount: money(money(invoice.net_amount ?? invoice.total_amount) / 12),
    })));
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
      if (url.searchParams.get("student_id")) q = q.eq("student_id", url.searchParams.get("student_id")!);
      if (url.searchParams.get("invoice_id")) q = q.eq("invoice_id", url.searchParams.get("invoice_id")!);
      if (url.searchParams.get("status")) q = q.eq("status", url.searchParams.get("status")!);
      const { data, error } = await q.order("created_at", { ascending: false });
      if (error) return fail(error.message);
      return ok(data ?? []);
    }
    if (!seg && method === "POST") {
      const studentId = text((body as Record<string, unknown>).student_id);
      try {
        if (studentId && !await parentCanAccessStudent(svc, school, user, studentId)) {
          return fail("Student does not belong to a linked child", 403);
        }
      } catch (error) {
        return fail(error instanceof Error ? error.message : "failed to verify parent access");
      }
      const { data, error } = await svc.from("parent_payment_requests").insert({
        ...body,
        school_id: school,
        parent_user_id: isAdminOrPrincipal(user) ? body.parent_user_id ?? null : user.id,
      }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (seg && path.endsWith("/decision") && method === "PUT") {
      if (!isAdminOrPrincipal(user)) return fail("admin or principal access required", 403);
      const status = text(body.status, "pending");
      const { data: existing, error: existingError } = await svc.from("parent_payment_requests")
        .select("*")
        .eq("id", seg)
        .eq("school_id", school)
        .maybeSingle();
      if (existingError) return fail(existingError.message);
      if (!existing) return fail("not found", 404);
      let paymentId: string | null = null;
      let receiptId: string | null = null;
      if (["approved", "completed", "paid"].includes(status)) {
        const { data: payment, error: paymentError } = await svc.from("payments").insert({
          school_id: school,
          student_id: existing.student_id,
          invoice_id: existing.invoice_id,
          amount: existing.amount,
          payment_method: existing.payment_method ?? "upi",
          reference_number: existing.transaction_ref ?? existing.transaction_id ?? existing.request_reference,
          paid_at: existing.payment_date ?? new Date().toISOString(),
          notes: existing.remarks ?? "",
          status: "completed",
          created_by: user.id,
        }).select().single();
        if (paymentError) return fail(paymentError.message);
        paymentId = payment.id;
        const receiptNumber = `RCP-${Date.now()}`;
        const { data: receipt, error: receiptError } = await svc.from("fee_receipts").insert({
          school_id: school,
          invoice_id: existing.invoice_id,
          payment_id: payment.id,
          receipt_number: receiptNumber,
          amount: existing.amount,
          payment_method: existing.payment_method ?? "upi",
          transaction_ref: existing.transaction_ref ?? existing.transaction_id ?? existing.request_reference,
        }).select().single();
        if (receiptError) return fail(receiptError.message);
        receiptId = receipt.id;
        const { data: invoice } = await svc.from("fee_invoices").select("net_amount, paid_amount")
          .eq("id", existing.invoice_id)
          .eq("school_id", school)
          .maybeSingle();
        if (invoice) {
          const newPaid = money(invoice.paid_amount) + money(existing.amount);
          const newBalance = Math.max(0, money(invoice.net_amount) - newPaid);
          await svc.from("fee_invoices").update({
            paid_amount: newPaid,
            balance: newBalance,
            status: newBalance <= 0 ? "paid" : "partial",
            updated_at: new Date().toISOString(),
          }).eq("id", existing.invoice_id).eq("school_id", school);
        }
      }
      const { data, error } = await svc.from("parent_payment_requests").update({
        status: body.status ?? "pending",
        remarks: body.admin_remarks ?? body.remarks ?? null,
        reviewed_by: user.id,
        reviewed_at: new Date().toISOString(),
        payment_id: paymentId ?? existing.payment_id ?? null,
        receipt_id: receiptId ?? existing.receipt_id ?? null,
        updated_at: new Date().toISOString(),
      }).eq("id", seg).eq("school_id", school).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  if (feesPath === "/payment-config" && method === "GET") {
    try {
      const data = await loadPaymentConfigRecord(
        svc,
        school,
        configRecordId("school"),
      );
      return ok((data?.data as Record<string, unknown> | null) ?? {});
    } catch (error) {
      return fail(error instanceof Error ? error.message : "failed to load payment config");
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
      return fail(error instanceof Error ? error.message : "failed to save payment config");
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
      return fail(error instanceof Error ? error.message : "failed to save payment qr");
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
      const data = await savePaymentConfigRecord(svc, school, recordId, payload);
      return ok({
        id: data?.id,
        ...((data?.data as Record<string, unknown> | null) ?? payload),
      });
    } catch (error) {
      return fail(error instanceof Error ? error.message : "failed to create payment config");
    }
  }

  if (feesPath.startsWith("/payment-configs/") && method === "PUT") {
    const id = feesPath.split("/")[2] ?? "";
    if (!id) return fail("config id required");
    const { data: existing, error: lookupError } = await svc.from("frontend_records")
      .select("*")
      .eq("id", id)
      .eq("school_id", school)
      .eq("table_name", "payment_config")
      .maybeSingle();
    if (lookupError) return fail(lookupError.message);
    if (!existing) return fail("not found", 404);
    const payload = {
      scope: body.scope ?? ((existing.data as Record<string, unknown> | null)?.["scope"]) ?? "school",
      grade_id: body.grade_id ?? ((existing.data as Record<string, unknown> | null)?.["grade_id"]) ?? "",
      section_id: body.section_id ?? ((existing.data as Record<string, unknown> | null)?.["section_id"]) ?? "",
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

  if (feesPath.startsWith("/payment-configs/") && feesPath.endsWith("/qr") && method === "POST") {
    const id = feesPath.split("/")[2] ?? "";
    if (!id) return fail("config id required");
    const { data: existing, error: lookupError } = await svc.from("frontend_records")
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
    const filePath = `payment-config/${school}/${id}/${Date.now()}-${file.name}`;
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
    return ok({
      success: true,
      reminder: {
        ...body,
        school_id: school,
        sent_at: new Date().toISOString(),
      },
    });
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

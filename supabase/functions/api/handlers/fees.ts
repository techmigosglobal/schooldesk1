// handlers/fees.ts — categories, structures, invoices, payments, requests, config
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";

function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
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
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};
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
    return {
      school_id: school,
      academic_year_id: input.academic_year_id,
      grade_id: input.grade_id ?? null,
      section_id: input.section_id ?? null,
      category_id: input.category_id ?? input.fee_category_id,
      amount: input.amount ?? 0,
      due_date: input.due_date ?? null,
      frequency: input.frequency ?? input.billing_mode ?? "term",
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
        "*, category:fee_categories(*), grade:grades(*), section:sections(*)",
      ).eq("school_id", school);
      if (url.searchParams.get("academic_year_id")) q = q.eq("academic_year_id", url.searchParams.get("academic_year_id")!);
      if (url.searchParams.get("grade_id")) q = q.eq("grade_id", url.searchParams.get("grade_id")!);
      if (url.searchParams.get("section_id")) q = q.eq("section_id", url.searchParams.get("section_id")!);
      const { data, error } = await q;
      if (error) return fail(error.message);
      return ok(data ?? []);
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
        "*, category:fee_categories(*)",
      ).eq("id", seg).eq("school_id", school).maybeSingle();
      if (error) return fail(error.message);
      return ok({
        structure_id: seg,
        structure,
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
      return ok({
        generated_count: 0,
        academic_year_id: body.academic_year_id ?? null,
        section_id: body.section_id ?? null,
        student_id: body.student_id ?? null,
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
      const { data: invoice } = body.invoice_id
        ? await svc.from("fee_invoices").select("*").eq("id", body.invoice_id)
          .eq("school_id", school).maybeSingle()
        : { data: null };
      return ok({
        invoice_id: body.invoice_id ?? null,
        payment_method: body.payment_method ?? "",
        amount: invoice?.balance ?? invoice?.net_amount ?? 0,
        selected_months: body.selected_months ?? 0,
        selected_terms: body.selected_terms ?? 0,
        remarks: body.remarks ?? "",
      });
    }

    if (seg === "submit" && method === "POST") {
      const form = await req.formData().catch(() => null);
      if (!form) return fail("multipart form required");
      const screenshot = form.get("screenshot") as File | null;
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
      const { data, error } = await svc.from("parent_payment_requests").insert({
        school_id: school,
        student_id:
          `${form.get("student_id") ?? form.get("student_fee_id") ?? ""}`,
        invoice_id: `${form.get("invoice_id") ?? ""}` || null,
        amount: parseFloat(`${form.get("amount") ?? "0"}`) || 0,
        payment_method: `${form.get("payment_method") ?? ""}`,
        proof_url: proofUrl,
        remarks: `${form.get("remarks") ?? ""}`,
        status: "pending",
      }).select().single();
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
        payment_id: payment.id,
        receipt_number: receiptNum,
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
    const { data, error } = await svc.from("fee_invoices").select(
      "*, fee_invoice_items(*)",
    ).eq("school_id", school).eq("student_id", studentId).order(
      "invoice_date",
      { ascending: false },
    );
    if (error) return fail(error.message);
    return ok(data ?? []);
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
      if (url.searchParams.get("student_id")) q = q.eq("student_id", url.searchParams.get("student_id")!);
      if (url.searchParams.get("invoice_id")) q = q.eq("invoice_id", url.searchParams.get("invoice_id")!);
      if (url.searchParams.get("status")) q = q.eq("status", url.searchParams.get("status")!);
      const { data, error } = await q.order("created_at", { ascending: false });
      if (error) return fail(error.message);
      return ok(data ?? []);
    }
    if (!seg && method === "POST") {
      const { data, error } = await svc.from("parent_payment_requests").insert({
        ...body,
        school_id: school,
      }).select().single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (seg && path.endsWith("/decision") && method === "PUT") {
      const { data, error } = await svc.from("parent_payment_requests").update({
        status: body.status ?? "pending",
        remarks: body.admin_remarks ?? body.remarks ?? null,
        reviewed_by: user.id,
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

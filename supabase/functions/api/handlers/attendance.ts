// handlers/attendance.ts — sessions, mark, summary, staff, QR, corrections
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}
function role(u: User) {
  return `${u.app_metadata?.role_name ?? ""}`.trim().toLowerCase();
}
function canDisplayStaffQr(roleName: string) {
  return ["admin", "principal", "kiosk", "super_admin"].includes(roleName);
}
function canScanStaffQr(roleName: string) {
  return ["teacher", "staff", "kiosk"].includes(roleName);
}
const staffQRRefreshSeconds = 7;
const staffQRScanGraceSeconds = 10;

function todayDate() {
  return new Date().toISOString().split("T")[0];
}

function base64UrlEncode(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/g,
    "",
  );
}

function base64UrlDecode(value: string) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(
    Math.ceil(value.length / 4) * 4,
    "=",
  );
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function staffQrSignature(payload: string) {
  const secret = Deno.env.get("STAFF_QR_SECRET") ||
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
    "schooldesk-staff-qr-dev-secret";
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(payload),
  );
  return base64UrlEncode(new Uint8Array(signature));
}

async function createStaffQrToken(payload: Record<string, unknown>) {
  const encodedPayload = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify(payload)),
  );
  return `${encodedPayload}.${await staffQrSignature(encodedPayload)}`;
}

async function verifyStaffQrToken(token: string) {
  const parts = token.split(".");
  if (parts.length !== 2) throw new Error("invalid token");
  const [payload, signature] = parts;
  if (await staffQrSignature(payload) !== signature) {
    throw new Error("invalid token");
  }
  const decoded = new TextDecoder().decode(base64UrlDecode(payload));
  const parsed = JSON.parse(decoded) as Record<string, unknown>;
  const expiresAt = new Date(`${parsed.expires_at ?? ""}`).getTime();
  if (!Number.isFinite(expiresAt)) throw new Error("invalid token");
  if (Date.now() > expiresAt + staffQRScanGraceSeconds * 1000) {
    throw new Error("expired token");
  }
  return parsed;
}

function staffAttendanceCsv(rows: Array<Record<string, any>>) {
  const header = [
    "date",
    "staff_name",
    "staff_code",
    "status",
    "check_in",
    "check_out",
    "source",
    "qr_scanned",
  ];
  const escape = (value: unknown) => {
    const text = `${value ?? ""}`.replace(/"/g, '""');
    return /[",\n]/.test(text) ? `"${text}"` : text;
  };
  const lines = rows.map((row) => {
    const staff = row.staff as Record<string, unknown> | undefined;
    const staffName = [staff?.first_name, staff?.last_name]
      .map((part) => `${part ?? ""}`.trim())
      .filter(Boolean)
      .join(" ");
    return [
      row.date,
      staffName,
      staff?.staff_code,
      row.status,
      row.check_in,
      row.check_out,
      row.source,
      row.qr_scanned,
    ].map(escape).join(",");
  });
  return [header.join(","), ...lines].join("\n");
}

export async function handleAttendance(
  req: Request,
  path: string,
  method: string,
  url: URL,
  client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};
  const linkedStaffId = (user.app_metadata?.linked_id as string | undefined) ??
    "";
  const roleName = role(user);

  if (path === "/attendance/reports/exports" && method === "POST") {
    const id = crypto.randomUUID();
    const payload = {
      id,
      report_title: `${body.report_title ?? body.report ?? "Attendance report"}`
        .trim(),
      report_type: `${body.report_type ?? "attendance"}`.trim(),
      format: `${body.format ?? "pdf"}`.trim().toLowerCase(),
      scope: `${body.scope ?? "principal_attendance"}`.trim(),
      parameters: body.parameters ?? body,
      status: "queued",
      requested_by: user.id,
      created_at: new Date().toISOString(),
      download_url: "",
    };
    const { data, error } = await svc.from("frontend_records").insert({
      school_id: school,
      table_name: "attendance_report_exports",
      record_id: id,
      data: payload,
    }).select().single();
    if (error) return fail(error.message);
    return ok(data?.data ?? payload);
  }

  // ── Sessions ───────────────────────────────────────────────
  if (path === "/attendance/sessions" && method === "GET") {
    let q = svc.from("attendance_sessions").select(
      "*, section:sections(*), staff:staff(*)",
    ).eq("school_id", school);
    if (url.searchParams.get("section_id")) {
      q = q.eq("section_id", url.searchParams.get("section_id")!);
    }
    if (url.searchParams.get("date")) {
      q = q.eq("date", url.searchParams.get("date")!);
    }
    if (url.searchParams.get("subject_id")) {
      q = q.eq("subject_id", url.searchParams.get("subject_id")!);
    }
    if (url.searchParams.get("staff_id")) {
      q = q.eq("staff_id", url.searchParams.get("staff_id")!);
    }
    const { data, error } = await q.order("date", { ascending: false });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  if (path === "/attendance/sessions" && method === "POST") {
    const { period_no: _legacyPeriodNo, ...rest } = body as Record<
      string,
      unknown
    >;
    const payload = {
      ...rest,
      school_id: school,
      period_number: body.period_number ?? body.period_no ?? null,
    };
    const { data, error } = await svc.from("attendance_sessions").insert(
      payload,
    ).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  const sessionMatch = path.match(/^\/attendance\/sessions\/([^/]+)$/);
  if (sessionMatch && method === "GET") {
    const { data, error } = await svc.from("attendance_sessions").select(
      "*, student_attendances(*, student:students(*)), section:sections(*, grade:grades(*)), staff:staff(*)",
    ).eq("id", sessionMatch[1]).single();
    if (error) return fail(error.message);
    return ok(data);
  }

  const sessionMarkMatch = path.match(
    /^\/attendance\/sessions\/([^/]+)\/mark$/,
  );
  if (sessionMarkMatch && method === "POST") {
    const sessionId = sessionMarkMatch[1];
    const attendances = Array.isArray(body.attendances)
      ? body.attendances
      : body.attendance_records;
    if (!Array.isArray(attendances)) return fail("attendances required");
    const records = attendances.map((r: Record<string, unknown>) => ({
      session_id: sessionId,
      student_id: r.student_id,
      status: r.status ?? "present",
      remarks: r.remarks ?? null,
    }));
    const { data, error } = await svc.from("student_attendances").upsert(
      records,
      { onConflict: "session_id,student_id" },
    ).select();
    if (error) return fail(error.message);
    if (body.finalize != false) {
      await svc.from("attendance_sessions").update({
        is_finalized: true,
        correction_request: null,
        updated_at: new Date().toISOString(),
      }).eq("id", sessionId).eq("school_id", school);
    }
    return ok({ marked: data?.length ?? 0, attendances: data ?? [] });
  }

  // Legacy bulk mark path kept for older callers.
  if (path === "/attendance/mark" && method === "POST") {
    const sessionId = `${body.session_id ?? ""}`.trim();
    const attendanceRecords = Array.isArray(body.attendance_records)
      ? body.attendance_records
      : [];
    if (!sessionId || attendanceRecords.length == 0) {
      return fail("session_id and attendance_records required");
    }
    const records = attendanceRecords.map((r: Record<string, unknown>) => ({
      session_id: sessionId,
      student_id: r.student_id,
      status: r.status ?? "present",
      remarks: r.remarks ?? null,
    }));
    const { data, error } = await svc.from("student_attendances").upsert(
      records,
      { onConflict: "session_id,student_id" },
    ).select();
    if (error) return fail(error.message);
    await svc.from("attendance_sessions").update({
      is_finalized: true,
      updated_at: new Date().toISOString(),
    }).eq("id", sessionId).eq("school_id", school);
    return ok({ marked: data?.length ?? 0, attendances: data ?? [] });
  }

  // ── Correction request ────────────────────────────────────
  const correctionMatch = path.match(
    /^\/attendance\/sessions\/([^/]+)\/correction-request$/,
  );
  if (correctionMatch && method === "POST") {
    const { data, error } = await svc.from("attendance_sessions").update({
      correction_request: body.reason ?? "",
      is_finalized: false,
      updated_at: new Date().toISOString(),
    }).eq("id", correctionMatch[1]).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  const reopenMatch = path.match(/^\/attendance\/sessions\/([^/]+)\/reopen$/);
  if (reopenMatch && method === "POST") {
    const { data, error } = await svc.from("attendance_sessions").update({
      is_finalized: false,
      correction_request: body.reason ?? null,
      updated_at: new Date().toISOString(),
    }).eq("id", reopenMatch[1]).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  // ── Summary ───────────────────────────────────────────────
  if (path === "/attendance/summary" && method === "GET") {
    let q = svc.from("attendance_summaries").select("*, student:students(*)")
      .eq("school_id", school);
    if (url.searchParams.get("academic_year_id")) {
      q = q.eq("academic_year_id", url.searchParams.get("academic_year_id")!);
    }
    if (url.searchParams.get("student_id")) {
      q = q.eq("student_id", url.searchParams.get("student_id")!);
    }
    const { data, error } = await q;
    if (error) return fail(error.message);
    const rows = data ?? [];
    if (url.searchParams.get("student_id")) {
      const row = (rows[0] as Record<string, unknown> | undefined) ?? {
        student_id: url.searchParams.get("student_id"),
        percentage: 0,
        present_days: 0,
        absent_days: 0,
        late_days: 0,
      };
      return ok({
        ...row,
        attendance_percentage: row["percentage"] ?? 0,
      });
    }
    return ok(rows);
  }

  // ── Staff attendance ──────────────────────────────────────
  if (path === "/attendance/staff" && method === "GET") {
    if (!canDisplayStaffQr(roleName) && !linkedStaffId) {
      return fail("forbidden", 403);
    }
    let q = svc.from("staff_attendances").select("*, staff:staff(*)").eq(
      "school_id",
      school,
    );
    if (url.searchParams.get("date")) {
      q = q.eq("date", url.searchParams.get("date")!);
    }
    if (url.searchParams.get("staff_id")) {
      q = q.eq("staff_id", url.searchParams.get("staff_id")!);
    }
    if (!canDisplayStaffQr(roleName) && linkedStaffId) {
      q = q.eq("staff_id", linkedStaffId);
    }
    const { data, error } = await q;
    if (error) return fail(error.message);
    return ok(data);
  }

  if (path === "/attendance/staff" && method === "POST") {
    const { data, error } = await svc.from("staff_attendances").upsert({
      ...body,
      school_id: school,
    }, { onConflict: "staff_id,date" }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  if (path === "/attendance/staff/me/today" && method === "GET") {
    if (!linkedStaffId) return ok({ attendance: null });
    const today = todayDate();
    const { data, error } = await svc.from("staff_attendances").select(
      "*, staff:staff(*)",
    ).eq("school_id", school).eq("staff_id", linkedStaffId).eq("date", today)
      .maybeSingle();
    if (error) return fail(error.message);
    return ok({ attendance: data ?? null });
  }

  if (path === "/attendance/staff/qr-token" && method === "GET") {
    if (!canDisplayStaffQr(roleName)) return fail("forbidden", 403);
    const today = todayDate();
    const issuedAt = new Date().toISOString();
    const expiresAt = new Date(
      Date.now() + staffQRRefreshSeconds * 1000,
    ).toISOString();
    const token = await createStaffQrToken({
      purpose: "staff_attendance",
      school_id: school,
      date: today,
      issued_at: issuedAt,
      expires_at: expiresAt,
      refresh_nonce: url.searchParams.get("refresh_nonce") ?? "",
    });
    return ok({
      token,
      school_date: today,
      issued_at: issuedAt,
      expires_at: expiresAt,
      server_time: new Date().toISOString(),
      refresh_after_seconds: staffQRRefreshSeconds,
      scan_grace_seconds: staffQRScanGraceSeconds,
      role: roleName,
      kiosk: roleName === "kiosk",
    });
  }

  if (path === "/attendance/staff/qr-scan" && method === "POST") {
    if (!canScanStaffQr(roleName)) return fail("forbidden", 403);
    if (!linkedStaffId) return fail("staff profile not linked", 400);
    const rawToken = `${body.token ?? ""}`.trim();
    if (!rawToken) return fail("token required");
    let parsed: Record<string, unknown>;
    try {
      parsed = await verifyStaffQrToken(rawToken);
    } catch (_error) {
      return fail("invalid token", 400);
    }
    if (`${parsed.school_id ?? ""}` !== school) {
      return fail("invalid token", 400);
    }
    if (`${parsed.purpose ?? ""}` !== "staff_attendance") {
      return fail("invalid token", 400);
    }
    const date = `${parsed.date ?? todayDate()}`.trim();
    const now = new Date();
    const timeValue = now.toTimeString().split(" ")[0];
    const existing = await svc.from("staff_attendances").select(
      "*, staff:staff(*)",
    )
      .eq("school_id", school)
      .eq("staff_id", linkedStaffId)
      .eq("date", date)
      .maybeSingle();
    if (existing.error) return fail(existing.error.message);
    if (existing.data?.check_in) return ok(existing.data);
    const { data, error } = await svc.from("staff_attendances").upsert({
      school_id: school,
      staff_id: linkedStaffId,
      date,
      status: "present",
      qr_scanned: true,
      check_in: body.check_in ?? timeValue,
      notes: body.location ?? null,
      source: "qr",
      marked_by: user.id,
    }, { onConflict: "staff_id,date" }).select().single();
    if (error) return fail(error.message);
    const withStaff = await svc.from("staff_attendances").select(
      "*, staff:staff(*)",
    )
      .eq("id", data.id)
      .single();
    if (withStaff.error) return ok(data);
    return ok(withStaff.data);
  }

  if (path === "/attendance/staff/qr-logs/export" && method === "GET") {
    if (!canDisplayStaffQr(roleName)) return fail("forbidden", 403);
    const date = url.searchParams.get("date") || todayDate();
    const { data, error } = await svc.from("staff_attendances")
      .select("*, staff:staff(*)")
      .eq("school_id", school)
      .eq("date", date)
      .order("check_in", { ascending: true });
    if (error) return fail(error.message);
    return new Response(staffAttendanceCsv(data ?? []), {
      status: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition":
          `attachment; filename="staff_qr_logs_${date}.csv"`,
      },
    });
  }

  // ── QR attendance ─────────────────────────────────────────
  if (path === "/attendance/qr" && method === "POST") {
    const { qr_token, staff_id } = body;
    if (!qr_token || !staff_id) return fail("qr_token and staff_id required");
    const today = new Date().toISOString().split("T")[0];
    const { data, error } = await svc.from("staff_attendances").upsert({
      school_id: school,
      staff_id,
      date: today,
      status: "present",
      qr_scanned: true,
      check_in: new Date().toTimeString().split(" ")[0],
    }, { onConflict: "staff_id,date" }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  const studentAttendanceMatch = path.match(
    /^\/attendance\/students\/([^/]+)$/,
  );
  if (studentAttendanceMatch && method === "GET") {
    let q = svc.from("student_attendances").select(
      "*, session:attendance_sessions!inner(*)",
    ).eq("student_id", studentAttendanceMatch[1]).eq(
      "session.school_id",
      school,
    );
    const year = url.searchParams.get("year");
    const month = url.searchParams.get("month");
    if (year && month) {
      const from = `${year}-${month}-01`;
      const to = `${year}-${month}-31`;
      q = q.gte("created_at", from).lte("created_at", to);
    }
    const { data, error } = await q.order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  return fail("not found", 404);
}

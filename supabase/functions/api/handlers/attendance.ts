// handlers/attendance.ts — sessions, mark, summary, staff, QR, corrections
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, triggerPushProcessing } from "../index.ts";
import { queueReportExport } from "./uploads.ts";

/**
 * Notify parents when a student is marked absent. Each notification is stored
 * for the in-app inbox first, then queued for FCM, so either delivery channel
 * can be unavailable without losing the other.
 */
async function notifyParentsOfAbsence(
  svc: SupabaseClient,
  school: string,
  absentStudentIds: string[],
  attendanceDate: string,
): Promise<void> {
  if (absentStudentIds.length === 0) return;
  try {
    // Find parent user IDs for all absent students
    const { data: links } = await svc.from("parent_student_links")
      .select("parent_user_id, student_id")
      .eq("school_id", school)
      .in("student_id", absentStudentIds);
    if (!links || links.length === 0) return;

    // Build per-parent events: deduplicate if parent has multiple absent children
    const parentEventMap = new Map<
      string,
      { studentIds: string[]; parentUserId: string }
    >();
    for (const link of links) {
      const parentId = `${link.parent_user_id ?? ""}`.trim();
      const studentId = `${link.student_id ?? ""}`.trim();
      if (!parentId || !studentId) continue;
      if (!parentEventMap.has(parentId)) {
        parentEventMap.set(parentId, {
          parentUserId: parentId,
          studentIds: [],
        });
      }
      parentEventMap.get(parentId)!.studentIds.push(studentId);
    }

    const deliveries = Array.from(parentEventMap.values()).map((
      { parentUserId, studentIds },
    ) => {
      const sortedStudentIds = [...new Set(studentIds)].sort();
      const entityId = `absence:${attendanceDate}:${sortedStudentIds.join(",")}`;
      const message = sortedStudentIds.length === 1
        ? `Your child was marked absent on ${attendanceDate}. Please contact the school if this is incorrect.`
        : `Your children were marked absent on ${attendanceDate}. Please contact the school if this is incorrect.`;
      return {
        userId: parentUserId,
        studentIds: sortedStudentIds,
        entityId,
        message,
      };
    });

    // Prevent a retry or a re-submitted attendance session from duplicating a
    // parent's in-app alert for the same students and date.
    const entityIds = deliveries.map((delivery) => delivery.entityId);
    const { data: existingLogs, error: existingLogsError } = await svc.from(
      "notification_logs",
    )
      .select("user_id, entity_id")
      .eq("school_id", school)
      .eq("entity_type", "attendance")
      .in("entity_id", entityIds);
    if (existingLogsError) throw existingLogsError;
    const existingLogKeys = new Set(
      (existingLogs ?? []).map((row) =>
        `${row.user_id ?? ""}|${row.entity_id ?? ""}`
      ),
    );
    const newDeliveries = deliveries.filter(
      (delivery) =>
        !existingLogKeys.has(`${delivery.userId}|${delivery.entityId}`),
    );
    if (newDeliveries.length > 0) {
      const { error: logError } = await svc.from("notification_logs").insert(
        newDeliveries.map((delivery) => ({
          school_id: school,
          user_id: delivery.userId,
          target_role: "parent",
          title: "Attendance Update",
          body: delivery.message,
          type: "attendance",
          entity_type: "attendance",
          entity_id: delivery.entityId,
          route: "/parent-attendance-screen",
          priority: "high",
          student_id: delivery.studentIds.length === 1
            ? delivery.studentIds[0]
            : null,
          is_read: false,
        })),
      );
      if (logError) throw logError;
    }

    const eventRows = newDeliveries.map((delivery) => ({
      school_id: school,
      user_id: delivery.userId,
      event_type: "attendance_marked",
      dedupe_key: `attendance:${delivery.userId}:${delivery.entityId}`,
      event_data: {
        student_ids: delivery.studentIds,
        student_id: delivery.studentIds.length === 1 ? delivery.studentIds[0] : "",
        status: "absent",
        date: attendanceDate,
        message: delivery.message,
        reference_type: "attendance",
        reference_id: delivery.entityId,
        route: "/parent-attendance-screen",
      },
    }));

    const { data: events, error: eventError } = eventRows.length === 0
      ? { data: [], error: null }
      : await svc.from("notification_events").insert(eventRows).select("id");
    if (!eventError) {
      const eventIds = (events ?? []).map((row: { id: string }) =>
        `${row.id ?? ""}`.trim()
      ).filter(Boolean);
      if (eventIds.length > 0) triggerPushProcessing(eventIds);
    }
  } catch (_) { /* best-effort — attendance was already saved */ }
}

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
  return ["teacher", "staff"].includes(roleName);
}
function canManageAttendance(roleName: string) {
  return ["admin", "principal", "super_admin"].includes(roleName);
}

async function parentCanAccessStudent(
  svc: SupabaseClient,
  user: User,
  school: string,
  studentId: string,
) {
  if (role(user) !== "parent") return true;
  if (!studentId) return false;
  const { data, error } = await svc.from("parent_student_links")
    .select("student_id").eq("school_id", school)
    .eq("parent_user_id", user.id).eq("student_id", studentId).maybeSingle();
  if (error) throw error;
  return Boolean(data);
}

function attendanceSummaryFromRows(rows: Array<Record<string, unknown>>) {
  const counts = {
    present_days: 0,
    absent_days: 0,
    late_count: 0,
    leave_days: 0,
    half_day_count: 0,
  };
  for (const row of rows) {
    const status = `${row.status ?? ""}`.trim().toLowerCase().replaceAll(
      "-",
      "_",
    );
    if (status === "present" || status === "p") counts.present_days++;
    else if (status === "absent" || status === "a") counts.absent_days++;
    else if (status === "late" || status === "l") counts.late_count++;
    else if (status === "leave") counts.leave_days++;
    else if (status === "half_day") counts.half_day_count++;
  }
  const marked = Object.values(counts).reduce((sum, value) => sum + value, 0);
  const presentEquivalent = counts.present_days + counts.late_count +
    counts.half_day_count * 0.5;
  const attendance_pct = marked > 0
    ? Number((presentEquivalent * 100 / marked).toFixed(2))
    : 0;
  return {
    ...counts,
    late_days: counts.late_count,
    attendance_pct,
    attendance_percentage: attendance_pct,
    percentage: attendance_pct,
  };
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

function staffAttendanceCsv(rows: Array<Record<string, unknown>>) {
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

async function teacherCanUseSection(
  svc: SupabaseClient,
  school: string,
  staffId: string,
  sectionId: string,
) {
  if (!staffId || !sectionId) return false;
  const section = await svc.from("sections").select("id").eq(
    "school_id",
    school,
  )
    .eq("id", sectionId)
    .or(`class_teacher_id.eq.${staffId},co_teacher_id.eq.${staffId}`)
    .maybeSingle();
  if (section.error) throw new Error(section.error.message);
  if (section.data) return true;

  const subject = await svc.from("staff_subjects").select("id").eq(
    "school_id",
    school,
  ).eq("staff_id", staffId).eq("section_id", sectionId).limit(1);
  if (subject.error) throw new Error(subject.error.message);
  return (subject.data ?? []).length > 0;
}

async function loadAttendanceSession(
  svc: SupabaseClient,
  school: string,
  sessionId: string,
) {
  const { data, error } = await svc.from("attendance_sessions").select("*")
    .eq("id", sessionId).eq("school_id", school).maybeSingle();
  if (error) throw new Error(error.message);
  return data as Record<string, unknown> | null;
}

function canUseAttendanceSession(
  svc: SupabaseClient,
  school: string,
  roleName: string,
  linkedStaffId: string,
  session: Record<string, unknown>,
) {
  if (canManageAttendance(roleName)) return true;
  if (!linkedStaffId) return false;
  if (`${session.staff_id ?? ""}` !== linkedStaffId) return false;
  return teacherCanUseSection(
    svc,
    school,
    linkedStaffId,
    `${session.section_id ?? ""}`,
  );
}

export async function handleAttendance(
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
  const linkedStaffId = (user.app_metadata?.linked_id as string | undefined) ??
    "";
  const roleName = role(user);

  if (path === "/attendance/reports/exports" && method === "POST") {
    try {
      const data = await queueReportExport(
        svc,
        school,
        user,
        "attendance_report_exports",
        body,
      );
      return ok(data);
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "failed to queue attendance report export",
      );
    }
  }

  // ── Sessions ───────────────────────────────────────────────
  if (path === "/attendance/sessions" && method === "GET") {
    let q = svc.from("attendance_sessions").select(
      "*, section:sections(*), staff:staff(*), subject:subjects(*), student_attendances(*)",
    ).eq("school_id", school);
    const sectionId = url.searchParams.get("section_id") ?? "";
    if (!canManageAttendance(roleName) && linkedStaffId) {
      if (
        sectionId &&
        !await teacherCanUseSection(svc, school, linkedStaffId, sectionId)
      ) {
        return fail("forbidden", 403);
      }
      q = q.eq("staff_id", linkedStaffId);
    }
    if (sectionId) {
      q = q.eq("section_id", sectionId);
    }
    if (url.searchParams.get("date")) {
      q = q.eq("date", url.searchParams.get("date")!);
    }
    if (url.searchParams.get("start_date")) {
      q = q.gte("date", url.searchParams.get("start_date")!);
    }
    if (url.searchParams.get("end_date")) {
      q = q.lte("date", url.searchParams.get("end_date")!);
    }
    if (url.searchParams.get("subject_id")) {
      q = q.eq("subject_id", url.searchParams.get("subject_id")!);
    }
    if (url.searchParams.get("staff_id")) {
      q = q.eq("staff_id", url.searchParams.get("staff_id")!);
    }
    const { data, error } = await q.order("date", { ascending: false });
    if (error) return fail(error.message);
    const mapped = (data ?? []).map((sess: any) => {
      if (Array.isArray(sess.student_attendances)) {
        sess.student_attendances = sess.student_attendances.map((row: any) => ({
          ...row,
          marked_at: row.created_at || row.updated_at,
        }));
      }
      return sess;
    });
    return ok(mapped);
  }

  if (path === "/attendance/sessions" && method === "POST") {
    const { period_no: _legacyPeriodNo, ...rest } = body as Record<
      string,
      unknown
    >;
    const sectionId = `${body.section_id ?? ""}`.trim();
    const staffId = `${body.staff_id ?? ""}`.trim();
    if (!sectionId) return fail("section_id required");
    if (!canManageAttendance(roleName)) {
      if (!linkedStaffId) return fail("staff profile not linked", 400);
      if (staffId && staffId !== linkedStaffId) return fail("forbidden", 403);
      if (!await teacherCanUseSection(svc, school, linkedStaffId, sectionId)) {
        return fail("forbidden", 403);
      }
    }
    const payload = {
      ...rest,
      school_id: school,
      subject_id: `${body.subject_id ?? ""}`.trim() || null,
      timetable_slot_id: `${body.timetable_slot_id ?? ""}`.trim() || null,
      staff_id: canManageAttendance(roleName) ? body.staff_id : linkedStaffId,
      period_number: body.period_number ?? body.period_no ?? null,
      status: "draft",
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
    if (data && Array.isArray(data.student_attendances)) {
      data.student_attendances = data.student_attendances.map((row: any) => ({
        ...row,
        marked_at: row.created_at || row.updated_at,
      }));
    }
    return ok(data);
  }

  const sessionMarkMatch = path.match(
    /^\/attendance\/sessions\/([^/]+)\/mark$/,
  );
  if (sessionMarkMatch && method === "POST") {
    const sessionId = sessionMarkMatch[1];
    let session: Record<string, unknown> | null;
    try {
      session = await loadAttendanceSession(svc, school, sessionId);
      if (!session) return fail("session not found", 404);
      if (
        !await canUseAttendanceSession(
          svc,
          school,
          roleName,
          linkedStaffId,
          session,
        )
      ) {
        return fail("forbidden", 403);
      }
    } catch (error) {
      return fail(
        error instanceof Error ? error.message : "failed to load session",
      );
    }
    if (session.is_finalized === true) {
      return fail("attendance session is finalized", 409);
    }
    const attendances = Array.isArray(body.attendances)
      ? body.attendances
      : body.attendance_records;
    if (!Array.isArray(attendances)) return fail("attendances required");
    const now = new Date().toISOString();
    const records = attendances.map((r: Record<string, unknown>) => ({
      session_id: sessionId,
      student_id: r.student_id,
      enrollment_id: r.enrollment_id || null,
      status: r.status ?? "present",
      reason: r.reason ?? r.remarks ?? "",
      remarks: r.remarks ?? r.reason ?? null,
      marked_at: now,
      updated_at: now,
    }));
    const { data, error } = await svc.from("student_attendances").upsert(
      records,
      { onConflict: "session_id,student_id" },
    ).select();
    if (error) return fail(error.message);
    if (body.finalize != false) {
      await svc.from("attendance_sessions").update({
        is_finalized: true,
        status: "submitted",
        submitted_at: new Date().toISOString(),
        correction_request: null,
        correction_reason: null,
        correction_asked_at: null,
        updated_at: new Date().toISOString(),
      }).eq("id", sessionId).eq("school_id", school);
    } else {
      await svc.from("attendance_sessions").update({
        status: "draft",
        updated_at: new Date().toISOString(),
      }).eq("id", sessionId).eq("school_id", school);
    }
    // Notify parents of absent students via FCM push
    const absentIds = (data ?? []).filter(
      (r: Record<string, unknown>) =>
        `${r.status ?? ""}`.toLowerCase() === "absent",
    ).map((r: Record<string, unknown>) => `${r.student_id ?? ""}`.trim())
      .filter(Boolean);
    const attendanceDate = `${
      session.date ?? new Date().toISOString().split("T")[0]
    }`;
    await notifyParentsOfAbsence(svc, school, absentIds, attendanceDate);
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
    let session: Record<string, unknown> | null;
    try {
      session = await loadAttendanceSession(svc, school, sessionId);
      if (!session) return fail("session not found", 404);
      if (
        !await canUseAttendanceSession(
          svc,
          school,
          roleName,
          linkedStaffId,
          session,
        )
      ) {
        return fail("forbidden", 403);
      }
    } catch (error) {
      return fail(
        error instanceof Error ? error.message : "failed to load session",
      );
    }
    if (session.is_finalized === true) {
      return fail("attendance session is finalized", 409);
    }
    const now = new Date().toISOString();
    const records = attendanceRecords.map((r: Record<string, unknown>) => ({
      session_id: sessionId,
      student_id: r.student_id,
      enrollment_id: r.enrollment_id || null,
      status: r.status ?? "present",
      reason: r.reason ?? r.remarks ?? "",
      remarks: r.remarks ?? r.reason ?? null,
      marked_at: now,
      updated_at: now,
    }));
    const { data, error } = await svc.from("student_attendances").upsert(
      records,
      { onConflict: "session_id,student_id" },
    ).select();
    if (error) return fail(error.message);
    await svc.from("attendance_sessions").update({
      is_finalized: true,
      status: "submitted",
      submitted_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }).eq("id", sessionId).eq("school_id", school);
    // Notify parents of absent students via FCM push (legacy bulk mark path)
    const absentIdsLegacy = (data ?? []).filter(
      (r: Record<string, unknown>) =>
        `${r.status ?? ""}`.toLowerCase() === "absent",
    ).map((r: Record<string, unknown>) => `${r.student_id ?? ""}`.trim())
      .filter(Boolean);
    const legacyDate = `${
      session.date ?? new Date().toISOString().split("T")[0]
    }`;
    await notifyParentsOfAbsence(svc, school, absentIdsLegacy, legacyDate);
    return ok({ marked: data?.length ?? 0, attendances: data ?? [] });
  }

  // ── Correction request ────────────────────────────────────
  const correctionMatch = path.match(
    /^\/attendance\/sessions\/([^/]+)\/correction-request$/,
  );
  if (correctionMatch && method === "POST") {
    let session: Record<string, unknown> | null;
    try {
      session = await loadAttendanceSession(svc, school, correctionMatch[1]);
      if (!session) return fail("session not found", 404);
      if (
        !await canUseAttendanceSession(
          svc,
          school,
          roleName,
          linkedStaffId,
          session,
        )
      ) {
        return fail("forbidden", 403);
      }
    } catch (error) {
      return fail(
        error instanceof Error ? error.message : "failed to load session",
      );
    }
    const { data, error } = await svc.from("attendance_sessions").update({
      correction_request: body.reason ?? "",
      correction_reason: body.reason ?? "",
      correction_asked_at: new Date().toISOString(),
      status: "needs_review",
      updated_at: new Date().toISOString(),
    }).eq("id", correctionMatch[1]).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  const reopenMatch = path.match(/^\/attendance\/sessions\/([^/]+)\/reopen$/);
  if (reopenMatch && method === "POST") {
    if (!canManageAttendance(roleName)) return fail("forbidden", 403);
    const { data, error } = await svc.from("attendance_sessions").update({
      is_finalized: false,
      status: "reopened",
      correction_request: body.reason ?? null,
      reopen_reason: body.reason ?? null,
      reopened_by: user.id,
      reopened_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }).eq("id", reopenMatch[1]).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  // ── Summary ───────────────────────────────────────────────
  if (path === "/attendance/summary" && method === "GET") {
    const requestedStudentId = url.searchParams.get("student_id") ?? "";
    if (
      requestedStudentId && !(await parentCanAccessStudent(
        svc,
        user,
        school,
        requestedStudentId,
      ))
    ) {
      return fail("student not linked to parent", 403);
    }
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
    if (requestedStudentId) {
      const { data: attendanceRows, error: attendanceError } = await svc
        .from("student_attendances")
        .select(
          "id, status, reason, marked_at, session:attendance_sessions!inner(id, date, period_number, staff:staff(first_name, last_name))",
        )
        .eq("student_id", requestedStudentId)
        .eq("session.school_id", school)
        .order("marked_at", { ascending: false });
      if (attendanceError) return fail(attendanceError.message);
      const records = (attendanceRows ?? []) as Array<Record<string, unknown>>;
      const stored = (rows[0] as Record<string, unknown> | undefined) ?? {};
      const computed = attendanceSummaryFromRows(records);
      const periodRows = records.map((row) => {
        const session = row.session && typeof row.session === "object"
          ? row.session as Record<string, unknown>
          : {};
        return {
          id: row.id,
          session_id: session.id,
          date: session.date ?? row.marked_at,
          period_number: session.period_number ?? "—",
          status: row.status,
          reason: row.reason ?? "",
        };
      });
      return ok({
        ...stored,
        student_id: requestedStudentId,
        ...(records.length > 0 ? computed : {
          present_days: Number(stored.present_days ?? 0),
          absent_days: Number(stored.absent_days ?? 0),
          late_count: Number(stored.late_count ?? stored.late_days ?? 0),
          leave_days: Number(stored.leave_days ?? 0),
          half_day_count: Number(stored.half_day_count ?? 0),
          attendance_pct: Number(
            stored.attendance_pct ?? stored.attendance_percentage ??
              stored.percentage ?? 0,
          ),
          attendance_percentage: Number(
            stored.attendance_pct ?? stored.attendance_percentage ??
              stored.percentage ?? 0,
          ),
          percentage: Number(
            stored.attendance_pct ?? stored.attendance_percentage ??
              stored.percentage ?? 0,
          ),
        }),
        period_rows: periodRows,
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
    if (url.searchParams.get("start_date")) {
      q = q.gte("date", url.searchParams.get("start_date")!);
    }
    if (url.searchParams.get("end_date")) {
      q = q.lte("date", url.searchParams.get("end_date")!);
    }
    if (url.searchParams.get("staff_id")) {
      q = q.eq("staff_id", url.searchParams.get("staff_id")!);
    }
    if (!canDisplayStaffQr(roleName) && linkedStaffId) {
      q = q.eq("staff_id", linkedStaffId);
    }
    const { data, error } = await q.order("date", { ascending: false });
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
    const timeValue = now.toISOString();
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
    const { qr_token } = body;
    if (!canScanStaffQr(roleName)) return fail("forbidden", 403);
    if (!linkedStaffId) return fail("staff profile not linked", 400);
    if (!qr_token) return fail("qr_token required");
    const today = new Date().toISOString().split("T")[0];
    const { data, error } = await svc.from("staff_attendances").upsert({
      school_id: school,
      staff_id: linkedStaffId,
      date: today,
      status: "present",
      qr_scanned: true,
      check_in: new Date().toISOString(),
      source: "qr",
      marked_by: user.id,
    }, { onConflict: "staff_id,date" }).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  const studentAttendanceMatch = path.match(
    /^\/attendance\/students\/([^/]+)$/,
  );
  if (studentAttendanceMatch && method === "GET") {
    if (
      !(await parentCanAccessStudent(
        svc,
        user,
        school,
        studentAttendanceMatch[1],
      ))
    ) {
      return fail("student not linked to parent", 403);
    }
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
      q = q.gte("session.date", from).lte("session.date", to);
    }
    const { data, error } = await q.order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok(data ?? []);
  }

  return fail("not found", 404);
}

// handlers/attendance.ts — sessions, mark, summary, staff, QR, corrections
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok, triggerPushProcessing } from "../index.ts";
import { queueReportExport } from "./uploads.ts";
import {
  claimDailyOperation,
  DailyClaimConflict,
  loadDailyClaim,
  sectionAcademicYear,
  teacherCanUseSection,
  todayDate,
  wasDailyClaimCreatedByThisRequest,
} from "./daily_claims.ts";
import { teacherCanAccessStudent } from "./teacher_scope.ts";

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

    // A parent with several children receives one separately routable alert
    // per absent child. This avoids an ambiguous notification that cannot open
    // the correct child context in the parent app.
    const parentIds = [...new Set(
      links.map((link) => `${link.parent_user_id ?? ""}`.trim()).filter(Boolean),
    )];
    const { data: activeParents, error: parentError } = parentIds.length === 0
      ? { data: [], error: null }
      : await svc.from("users").select("id").eq("school_id", school)
        .eq("role_name", "parent").eq("is_active", true).in("id", parentIds);
    if (parentError) throw parentError;
    const activeParentIds = new Set(
      (activeParents ?? []).map((parent) => `${parent.id ?? ""}`.trim()),
    );
    const deliveryKeys = new Set<string>();
    const deliveries = links.map((link) => {
      const userId = `${link.parent_user_id ?? ""}`.trim();
      const studentId = `${link.student_id ?? ""}`.trim();
      if (!userId || !studentId || !activeParentIds.has(userId)) return null;
      const entityId = `absence:${attendanceDate}:${studentId}`;
      const key = `${userId}:${entityId}`;
      if (deliveryKeys.has(key)) return null;
      deliveryKeys.add(key);
      return {
        userId,
        studentId,
        entityId,
        message:
          `Your child was marked absent on ${attendanceDate}. Please contact the school if this is incorrect.`,
      };
    }).filter((delivery): delivery is {
      userId: string;
      studentId: string;
      entityId: string;
      message: string;
    } => delivery !== null);

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
          student_id: delivery.studentId,
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
        student_id: delivery.studentId,
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
  return ["admin", "principal", "coordinator", "kiosk", "super_admin"].includes(
    roleName,
  );
}
function canScanStaffQr(roleName: string) {
  return ["teacher", "staff"].includes(roleName);
}
function canManageAttendance(roleName: string) {
  return ["admin", "principal", "coordinator", "super_admin"].includes(
    roleName,
  );
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

function indiaDateParts(value: Date) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    hourCycle: "h23",
  }).formatToParts(value);
  const get = (type: string) =>
    parts.find((part) => part.type === type)?.value || "";
  return {
    date: `${get("year")}-${get("month")}-${get("day")}`,
    hour: Number(get("hour")),
  };
}

function staffPunchPayload(
  attendance: Record<string, unknown>,
  punchAction:
    | "check_in"
    | "check_out"
    | "already_checked_in"
    | "already_checked_out",
) {
  const checkIn = `${attendance.check_in ?? ""}`;
  const checkOut = `${attendance.check_out ?? ""}`;
  const durationMinutes = checkIn && checkOut
    ? Math.max(
      0,
      Math.round((Date.parse(checkOut) - Date.parse(checkIn)) / 60000),
    )
    : null;
  return {
    ...attendance,
    punch_action: punchAction,
    worked_minutes: durationMinutes,
  };
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
    "check_out_source",
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
      row.check_out_source,
      row.source,
      row.qr_scanned,
    ].map(escape).join(",");
  });
  return [header.join(","), ...lines].join("\n");
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

async function attendanceStudentsBelongToSection(
  svc: SupabaseClient,
  school: string,
  sectionId: string,
  studentIds: string[],
): Promise<boolean> {
  const uniqueIds = [...new Set(studentIds.map((id) => `${id ?? ""}`.trim()))]
    .filter(Boolean);
  if (!sectionId || uniqueIds.length !== studentIds.length || uniqueIds.length === 0) {
    return false;
  }
  const { data, error } = await svc.from("students").select("id").eq(
    "school_id",
    school,
  ).eq("current_section_id", sectionId).eq("status", "active").in("id", uniqueIds);
  if (error) throw new Error(error.message);
  return (data ?? []).length === uniqueIds.length;
}

async function canUseAttendanceSession(
  svc: SupabaseClient,
  school: string,
  roleName: string,
  linkedStaffId: string,
  session: Record<string, unknown>,
) {
  if (canManageAttendance(roleName)) return true;
  if (!linkedStaffId) return false;
  if (!await teacherCanUseSection(
    svc,
    school,
    linkedStaffId,
    `${session.section_id ?? ""}`,
  )) return false;
  const claim = await loadDailyClaim(
    svc,
    school,
    `${session.academic_year_id ?? ""}`,
    `${session.section_id ?? ""}`,
    "attendance",
    `${session.date ?? ""}`.split("T")[0],
  );
  if (claim && `${claim.status ?? ""}` === "claimed") {
    return `${claim.claimed_by_staff_id ?? ""}` === linkedStaffId;
  }
  if (claim && `${claim.status ?? ""}` === "reopened") return true;
  return `${session.staff_id ?? ""}` === linkedStaffId;
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
    if (!canManageAttendance(roleName)) return fail("forbidden", 403);
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
      "id, school_id, section_id, academic_year_id, subject_id, staff_id, timetable_slot_id, date, period_number, total_students, present_count, is_finalized, status, submitted_at, reopened_at, reopened_by, reopen_reason, correction_reason, correction_asked_at, corrected_at, section:sections(id, section_name, grade:grades(id, grade_name)), staff:staff(id, first_name, last_name, staff_code), subject:subjects(id, subject_name)",
      { count: "exact" },
    ).eq("school_id", school);
    const sectionId = url.searchParams.get("section_id") ?? "";
    if (!canManageAttendance(roleName)) {
      if (!linkedStaffId) return fail("forbidden", 403);
      if (
        sectionId &&
        !await teacherCanUseSection(svc, school, linkedStaffId, sectionId)
      ) {
        return fail("forbidden", 403);
      }
      // A co-teacher must be able to read the class teacher's shared session.
      // The teacher screen supplies section_id; retain staff-scoped history
      // only for unscoped legacy callers.
      if (!sectionId) q = q.eq("staff_id", linkedStaffId);
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
    const page = Math.max(1, Number(url.searchParams.get("page") ?? "1") || 1);
    const pageSize = Math.min(
      100,
      Math.max(1, Number(url.searchParams.get("page_size") ?? "20") || 20),
    );
    const { data, error, count } = await q.order("date", { ascending: false })
      .order("id", { ascending: false })
      .range((page - 1) * pageSize, page * pageSize - 1);
    if (error) return fail(error.message);
    const mapped = await Promise.all((data ?? []).map(async (sess: any) => {
      sess.daily_claim = await loadDailyClaim(
        svc,
        school,
        `${sess.academic_year_id ?? ""}`,
        `${sess.section_id ?? ""}`,
        "attendance",
        `${sess.date ?? ""}`.split("T")[0],
      );
      return sess;
    }));
    return cors({
      success: true,
      data: mapped,
      total: count ?? 0,
      page,
      page_size: pageSize,
      has_more: page * pageSize < (count ?? 0),
    });
  }

  if (path === "/attendance/sessions" && method === "POST") {
    const { period_no: _legacyPeriodNo, ...rest } = body as Record<
      string,
      unknown
    >;
    const sectionId = `${body.section_id ?? ""}`.trim();
    const staffId = `${body.staff_id ?? ""}`.trim();
    const operationDate = `${body.date ?? todayDate()}`
      .split("T")[0];
    if (!sectionId) return fail("section_id required");
    if (!canManageAttendance(roleName)) {
      if (!linkedStaffId) return fail("staff profile not linked", 400);
      if (staffId && staffId !== linkedStaffId) return fail("forbidden", 403);
      if (!await teacherCanUseSection(svc, school, linkedStaffId, sectionId)) {
        return fail("forbidden", 403);
      }
    }
    const academicYearId = await sectionAcademicYear(
      svc,
      school,
      sectionId,
      `${body.academic_year_id ?? ""}`.trim(),
    );
    if (!academicYearId) return fail("section and academic year do not match", 422);
    const claimingStaffId = canManageAttendance(roleName)
      ? staffId || linkedStaffId
      : linkedStaffId;
    if (!claimingStaffId) return fail("staff profile not linked", 400);
    const periodNumber = body.period_number ?? body.period_no ?? 1;
    const existingSession = await svc.from("attendance_sessions").select("*")
      .eq("school_id", school).eq("section_id", sectionId)
      .eq("academic_year_id", academicYearId).eq("date", operationDate)
      .eq("period_number", periodNumber).limit(1).maybeSingle();
    if (existingSession.error) return fail(existingSession.error.message);
    if (existingSession.data) {
      const existingClaim = await loadDailyClaim(
        svc,
        school,
        academicYearId,
        sectionId,
        "attendance",
        operationDate,
      );
      if (!canManageAttendance(roleName) &&
        `${existingClaim?.status ?? ""}`.trim() === "reopened") {
        try {
          const reassignedClaim = await claimDailyOperation({
            svc,
            school,
            sectionId,
            academicYearId,
            operation: "attendance",
            operationDate,
            staffId: linkedStaffId,
          });
          return ok({ ...existingSession.data, daily_claim: reassignedClaim });
        } catch (error) {
          if (error instanceof DailyClaimConflict) {
            return cors({
              success: false,
              error: "attendance is already claimed by another teacher",
              daily_claim: error.claim,
            }, 409);
          }
          return fail(
            error instanceof Error ? error.message : "failed to reassign attendance",
            409,
          );
        }
      }
      if (!canManageAttendance(roleName) &&
        `${existingClaim?.claimed_by_staff_id ?? existingSession.data.staff_id ?? ""}`
            .trim() !== linkedStaffId) {
        return cors({
          success: false,
          error: "attendance is already claimed by another teacher",
          daily_claim: existingClaim,
          session: existingSession.data,
        }, 409);
      }
      return ok({ ...existingSession.data, daily_claim: existingClaim });
    }
    let claim: Record<string, unknown>;
    try {
      claim = await claimDailyOperation({
        svc,
        school,
        sectionId,
        academicYearId,
        operation: "attendance",
        operationDate,
        staffId: claimingStaffId,
      });
    } catch (error) {
      if (error instanceof DailyClaimConflict) {
        return cors({
          success: false,
          error: "attendance is already claimed by another teacher",
          daily_claim: error.claim,
        }, 409);
      }
      return fail(
        error instanceof Error ? error.message : "failed to claim attendance",
        409,
      );
    }

    const payload = {
      ...rest,
      school_id: school,
      date: operationDate,
      academic_year_id: academicYearId,
      subject_id: `${body.subject_id ?? ""}`.trim() || null,
      timetable_slot_id: `${body.timetable_slot_id ?? ""}`.trim() || null,
      staff_id: canManageAttendance(roleName) ? body.staff_id : linkedStaffId,
      period_number: periodNumber,
      status: "draft",
    };
    const { data, error } = await svc.from("attendance_sessions").insert(
      payload,
    ).select().single();
    if (error) {
      if (wasDailyClaimCreatedByThisRequest(claim)) {
        await svc.from("class_daily_operation_claims").delete().eq(
          "id",
          claim.id,
        ).eq("school_id", school).eq(
          "claimed_by_staff_id",
          claimingStaffId,
        );
      }
      return fail(error.message);
    }
    return ok({ ...data, daily_claim: claim });
  }

  const sessionMatch = path.match(/^\/attendance\/sessions\/([^/]+)$/);
  if (sessionMatch && method === "GET") {
    const { data, error } = await svc.from("attendance_sessions").select(
      "*, student_attendances(*, student:students(*)), section:sections(*, grade:grades(*)), staff:staff(*)",
    ).eq("id", sessionMatch[1]).eq("school_id", school).maybeSingle();
    if (error) return fail(error.message);
    if (!data) return fail("session not found", 404);
    if (data && Array.isArray(data.student_attendances)) {
      data.student_attendances = data.student_attendances.map((row: any) => ({
        ...row,
        marked_at: row.created_at || row.updated_at,
      }));
    }
    if (!canManageAttendance(roleName)) {
      if (!linkedStaffId) return fail("forbidden", 403);
      if (!await teacherCanUseSection(svc, school, linkedStaffId, `${data.section_id ?? ""}`)) {
        return fail("forbidden", 403);
      }
    }
    const claim = await loadDailyClaim(
      svc,
      school,
      `${data.academic_year_id ?? ""}`,
      `${data.section_id ?? ""}`,
      "attendance",
      `${data.date ?? ""}`.split("T")[0],
    );
    return ok({ ...data, daily_claim: claim });
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
    if (!canManageAttendance(roleName)) {
      try {
        const claim = await claimDailyOperation({
          svc,
          school,
          sectionId: `${session.section_id ?? ""}`,
          academicYearId: `${session.academic_year_id ?? ""}`,
          operation: "attendance",
          operationDate: `${session.date ?? ""}`.split("T")[0],
          staffId: linkedStaffId,
        });
        if (`${claim.claimed_by_staff_id ?? ""}` !== linkedStaffId) {
          return fail("attendance is claimed by another teacher", 409);
        }
      } catch (error) {
        if (error instanceof DailyClaimConflict) {
          return cors({
            success: false,
            error: "attendance is claimed by another teacher",
            daily_claim: error.claim,
          }, 409);
        }
        return fail(
          error instanceof Error ? error.message : "failed to claim attendance",
          409,
        );
      }
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
    if (!await attendanceStudentsBelongToSection(
      svc,
      school,
      `${session.section_id ?? ""}`,
      records.map((record: Record<string, unknown>) => `${record.student_id ?? ""}`),
    )) return fail("attendance records must belong to the active session section", 422);
    const { data, error } = await svc.from("student_attendances").upsert(
      records,
      { onConflict: "session_id,student_id" },
    ).select();
    if (error) return fail(error.message);
    if (body.finalize != false) {
      const { error: finalizeError } = await svc.from("attendance_sessions").update({
        is_finalized: true,
        status: "submitted",
        submitted_at: new Date().toISOString(),
        correction_request: null,
        correction_reason: null,
        correction_asked_at: null,
        updated_at: new Date().toISOString(),
      }).eq("id", sessionId).eq("school_id", school);
      if (finalizeError) return fail(finalizeError.message);
    } else {
      const { error: draftError } = await svc.from("attendance_sessions").update({
        status: "draft",
        updated_at: new Date().toISOString(),
      }).eq("id", sessionId).eq("school_id", school);
      if (draftError) return fail(draftError.message);
    }
    // Notify parents of absent students via FCM push
    const absentIds = (data ?? []).filter(
      (r: Record<string, unknown>) =>
        `${r.status ?? ""}`.toLowerCase() === "absent",
    ).map((r: Record<string, unknown>) => `${r.student_id ?? ""}`.trim())
      .filter(Boolean);
    const attendanceDate = `${
      session.date ?? todayDate()
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
    if (!await attendanceStudentsBelongToSection(
      svc,
      school,
      `${session.section_id ?? ""}`,
      records.map((record: Record<string, unknown>) => `${record.student_id ?? ""}`),
    )) return fail("attendance records must belong to the active session section", 422);
    const { data, error } = await svc.from("student_attendances").upsert(
      records,
      { onConflict: "session_id,student_id" },
    ).select();
    if (error) return fail(error.message);
    const { error: finalizeLegacyError } = await svc.from("attendance_sessions").update({
      is_finalized: true,
      status: "submitted",
      submitted_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }).eq("id", sessionId).eq("school_id", school);
    if (finalizeLegacyError) return fail(finalizeLegacyError.message);
    // Notify parents of absent students via FCM push (legacy bulk mark path)
    const absentIdsLegacy = (data ?? []).filter(
      (r: Record<string, unknown>) =>
        `${r.status ?? ""}`.toLowerCase() === "absent",
    ).map((r: Record<string, unknown>) => `${r.student_id ?? ""}`.trim())
      .filter(Boolean);
    const legacyDate = `${
      session.date ?? todayDate()
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
    if (data) {
      await svc.from("class_daily_operation_claims").update({
        status: "reopened",
        reopened_at: new Date().toISOString(),
        reopened_by: user.id,
        reopen_reason: body.reason ?? null,
        updated_at: new Date().toISOString(),
      }).eq("school_id", school).eq("section_id", `${data.section_id ?? ""}`)
        .eq("operation", "attendance").eq(
          "operation_date",
          `${data.date ?? ""}`.split("T")[0],
        );
    }
    return ok(data);
  }

  // ── Summary ───────────────────────────────────────────────
  if (path === "/attendance/summary" && method === "GET") {
    const requestedStudentId = url.searchParams.get("student_id") ?? "";
    if (roleName === "parent" &&
      (!requestedStudentId || !(await parentCanAccessStudent(
        svc,
        user,
        school,
        requestedStudentId,
      )))) {
      return fail("student not linked to parent", 403);
    }
    if (!canManageAttendance(roleName) && roleName !== "parent") {
      if (!linkedStaffId || !requestedStudentId ||
        !(await teacherCanAccessStudent(
          svc,
          school,
          linkedStaffId,
          requestedStudentId,
        ))) {
        return fail("forbidden", 403);
      }
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

  if (path === "/attendance/staff/me/punch-out" && method === "POST") {
    if (!canScanStaffQr(roleName)) return fail("forbidden", 403);
    if (!linkedStaffId) return fail("staff profile not linked", 400);
    const date = todayDate();
    const { data: existing, error: existingError } = await svc
      .from("staff_attendances")
      .select("*, staff:staff(*)")
      .eq("school_id", school)
      .eq("staff_id", linkedStaffId)
      .eq("date", date)
      .maybeSingle();
    if (existingError) return fail(existingError.message);
    if (!existing?.check_in) {
      return fail("check-in is required before punch-out", 409);
    }
    if (existing.check_out) {
      return ok(staffPunchPayload(existing, "already_checked_out"));
    }
    const now = new Date().toISOString();
    const { data, error } = await svc.from("staff_attendances").update({
      check_out: now,
      check_out_source: "manual",
      check_out_marked_by: user.id,
      updated_at: now,
    }).eq("id", existing.id).select("*, staff:staff(*)").single();
    if (error) return fail(error.message);
    return ok(staffPunchPayload(data, "check_out"));
  }

  if (path === "/attendance/staff/daily-summary" && method === "GET") {
    if (!canDisplayStaffQr(roleName)) return fail("forbidden", 403);
    const date = url.searchParams.get("date") || todayDate();
    const [
      { data: staff, error: staffError },
      { data: attendance, error: attendanceError },
    ] = await Promise.all([
      // The dashboard only needs the active staff count here. `staff` stores
      // names as first_name / last_name; it does not have a full_name column.
      // Selecting only the ID keeps this count query schema-safe and avoids
      // failing the whole attendance dashboard before any data can render.
      svc.from("staff").select("id")
        .eq("school_id", school),
      svc.from("staff_attendances").select("*, staff:staff(*)")
        .eq("school_id", school).eq("date", date).order("check_in", {
          ascending: true,
        }),
    ]);
    if (staffError) return fail(staffError.message);
    if (attendanceError) return fail(attendanceError.message);
    const rows = attendance ?? [];
    const checkedIn = rows.filter((row) => Boolean(row.check_in));
    const checkedOut = rows.filter((row) => Boolean(row.check_out));
    return ok({
      date,
      timezone: "Asia/Kolkata",
      expected_staff: staff?.length ?? 0,
      checked_in: checkedIn.length,
      checked_out: checkedOut.length,
      currently_on_site: checkedIn.length - checkedOut.length,
      pending: Math.max(0, (staff?.length ?? 0) - checkedIn.length),
      attendances: rows.map((row) =>
        staffPunchPayload(
          row,
          row.check_out
            ? "already_checked_out"
            : row.check_in
            ? "already_checked_in"
            : "check_in",
        )
      ),
    });
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
    const afterNoon = indiaDateParts(now).hour >= 12;
    if (existing.data?.check_out) {
      return ok(staffPunchPayload(existing.data, "already_checked_out"));
    }
    if (existing.data?.check_in && afterNoon) {
      const { data, error } = await svc.from("staff_attendances").update({
        check_out: timeValue,
        check_out_source: "qr",
        check_out_marked_by: user.id,
        updated_at: timeValue,
      }).eq("id", existing.data.id).select("*, staff:staff(*)").single();
      if (error) return fail(error.message);
      return ok(staffPunchPayload(data, "check_out"));
    }
    if (existing.data?.check_in) {
      return ok(staffPunchPayload(existing.data, "already_checked_in"));
    }
    const { data, error } = await svc.from("staff_attendances").upsert({
      school_id: school,
      staff_id: linkedStaffId,
      date,
      status: "present",
      qr_scanned: true,
      check_in: timeValue,
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
    if (withStaff.error) return ok(staffPunchPayload(data, "check_in"));
    return ok(staffPunchPayload(withStaff.data, "check_in"));
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
    let parsed: Record<string, unknown>;
    try {
      parsed = await verifyStaffQrToken(`${qr_token}`.trim());
    } catch (_error) {
      return fail("invalid token", 400);
    }
    if (
      `${parsed.school_id ?? ""}` !== school ||
      `${parsed.purpose ?? ""}` !== "staff_attendance"
    ) {
      return fail("invalid token", 400);
    }
    const today = `${parsed.date ?? todayDate()}`.trim();
    const now = new Date();
    const timeValue = now.toISOString();
    const { data: existing, error: existingError } = await svc
      .from("staff_attendances")
      .select("*, staff:staff(*)")
      .eq("school_id", school)
      .eq("staff_id", linkedStaffId)
      .eq("date", today)
      .maybeSingle();
    if (existingError) return fail(existingError.message);
    if (existing?.check_out) {
      return ok(staffPunchPayload(existing, "already_checked_out"));
    }
    if (existing?.check_in && indiaDateParts(now).hour >= 12) {
      const { data, error } = await svc.from("staff_attendances").update({
        check_out: timeValue,
        check_out_source: "qr",
        check_out_marked_by: user.id,
        updated_at: timeValue,
      }).eq("id", existing.id).select("*, staff:staff(*)").single();
      if (error) return fail(error.message);
      return ok(staffPunchPayload(data, "check_out"));
    }
    if (existing?.check_in) {
      return ok(staffPunchPayload(existing, "already_checked_in"));
    }
    const { data, error } = await svc.from("staff_attendances").insert({
      school_id: school,
      staff_id: linkedStaffId,
      date: today,
      status: "present",
      qr_scanned: true,
      check_in: timeValue,
      source: "qr",
      marked_by: user.id,
    }).select("*, staff:staff(*)").single();
    if (error) return fail(error.message);
    return ok(staffPunchPayload(data, "check_in"));
  }

  const studentAttendanceMatch = path.match(
    /^\/attendance\/students\/([^/]+)$/,
  );
  if (studentAttendanceMatch && method === "GET") {
    const requestedStudentId = studentAttendanceMatch[1];
    if (roleName === "parent" &&
      !(await parentCanAccessStudent(
        svc,
        user,
        school,
        requestedStudentId,
      ))) {
      return fail("student not linked to parent", 403);
    }
    if (!canManageAttendance(roleName) && roleName !== "parent") {
      if (!linkedStaffId || !await teacherCanAccessStudent(
        svc,
        school,
        linkedStaffId,
        requestedStudentId,
      )) return fail("forbidden", 403);
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

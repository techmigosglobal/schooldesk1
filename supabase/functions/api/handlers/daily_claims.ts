import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";
import {
  teacherCanUseSection as hasActiveTeacherSectionAccess,
} from "./teacher_scope.ts";
import { isIsoDate, isUuid } from "../lib/homework_legacy.ts";

export type DailyOperation = "attendance" | "homework";

const claimsCreatedByThisRequest = new WeakSet<object>();

export class DailyClaimConflict extends Error {
  claim: Record<string, unknown>;

  constructor(claim: Record<string, unknown>) {
    super("this class-day operation was already claimed by another teacher");
    this.name = "DailyClaimConflict";
    this.claim = claim;
  }
}

function text(value: unknown): string {
  return `${value ?? ""}`.trim();
}

function schoolId(user: User): string {
  return text(user.app_metadata?.school_id);
}

function roleName(user: User): string {
  return text(user.app_metadata?.role_name).toLowerCase();
}

export function canManageDailyClaims(user: User): boolean {
  return ["principal", "coordinator", "admin", "super_admin"].includes(
    roleName(user),
  );
}

export async function teacherCanUseSection(
  svc: SupabaseClient,
  school: string,
  staffId: string,
  sectionId: string,
) {
  return hasActiveTeacherSectionAccess(svc, school, staffId, sectionId);
}

export function todayDate(): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const value = (type: string) =>
    parts.find((part) => part.type === type)?.value ?? "";
  return `${value("year")}-${value("month")}-${value("day")}`;
}

export async function sectionAcademicYear(
  svc: SupabaseClient,
  school: string,
  sectionId: string,
  requestedYearId = "",
) {
  if (!isUuid(sectionId) || (requestedYearId && !isUuid(requestedYearId))) {
    return "";
  }
  const section = await svc.from("sections").select(
    "id, academic_year_id",
  ).eq("school_id", school).eq("id", sectionId).maybeSingle();
  if (section.error) throw new Error(section.error.message);
  if (!section.data) return "";
  const yearId = text(section.data.academic_year_id);
  if (requestedYearId && requestedYearId !== yearId) return "";
  return yearId;
}

export async function loadDailyClaim(
  svc: SupabaseClient,
  school: string,
  academicYearId: string,
  sectionId: string,
  operation: DailyOperation,
  operationDate: string,
) {
  // Legacy homework rows can have no academic year. Never send empty or
  // malformed UUID/date values to Postgres; a missing claim is safe for reads
  // and preserves the existing claim-conflict behavior for valid rows.
  if (
    !isUuid(academicYearId) || !isUuid(sectionId) || !isIsoDate(operationDate)
  ) {
    return null;
  }
  const { data, error } = await svc.from("class_daily_operation_claims")
    .select(
      "*, claimed_by:staff!class_daily_operation_claims_claimed_by_staff_id_fkey(id, first_name, last_name)",
    ).eq("school_id", school).eq("academic_year_id", academicYearId).eq(
      "section_id",
      sectionId,
    ).eq(
      "operation",
      operation,
    ).eq("operation_date", operationDate).maybeSingle();
  if (error) throw new Error(error.message);
  return data as Record<string, unknown> | null;
}

export function wasDailyClaimCreatedByThisRequest(
  claim: Record<string, unknown>,
): boolean {
  return claimsCreatedByThisRequest.has(claim);
}

export async function claimDailyOperation({
  svc,
  school,
  sectionId,
  academicYearId,
  operation,
  operationDate,
  staffId,
}: {
  svc: SupabaseClient;
  school: string;
  sectionId: string;
  academicYearId: string;
  operation: DailyOperation;
  operationDate: string;
  staffId: string;
}) {
  const payload = {
    school_id: school,
    academic_year_id: academicYearId,
    section_id: sectionId,
    operation,
    operation_date: operationDate,
    claimed_by_staff_id: staffId,
    status: "claimed",
    reopened_at: null,
    reopened_by: null,
    reopen_reason: null,
    updated_at: new Date().toISOString(),
  };
  const inserted = await svc.from("class_daily_operation_claims").insert(
    payload,
  ).select(
    "*, claimed_by:staff!class_daily_operation_claims_claimed_by_staff_id_fkey(id, first_name, last_name)",
  ).single();
  if (!inserted.error && inserted.data) {
    const claim = inserted.data as Record<string, unknown>;
    claimsCreatedByThisRequest.add(claim);
    return claim;
  }

  const existing = await loadDailyClaim(
    svc,
    school,
    academicYearId,
    sectionId,
    operation,
    operationDate,
  );
  if (!existing) {
    throw new Error(
      inserted.error?.message ?? "failed to claim class-day operation",
    );
  }
  if (
    text(existing.claimed_by_staff_id) === staffId &&
    text(existing.status) === "claimed"
  ) {
    return existing;
  }
  if (text(existing.status) === "reopened") {
    const reassigned = await svc.from("class_daily_operation_claims").update({
      school_id: school,
      academic_year_id: academicYearId,
      section_id: sectionId,
      operation,
      operation_date: operationDate,
      claimed_by_staff_id: staffId,
      status: "claimed",
      reopened_at: null,
      reopened_by: null,
      reopen_reason: null,
      updated_at: new Date().toISOString(),
    }).eq("id", existing.id).eq("school_id", school).select(
      "*, claimed_by:staff!class_daily_operation_claims_claimed_by_staff_id_fkey(id, first_name, last_name)",
    ).single();
    if (!reassigned.error && reassigned.data) {
      return reassigned.data as Record<string, unknown>;
    }
  }
  throw new DailyClaimConflict(existing);
}

export async function handleDailyClaims(
  req: Request,
  path: string,
  method: string,
  url: URL,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = schoolId(user);
  const linkedStaffId = text(user.app_metadata?.linked_id);
  if (path === "/class-daily-claims" && method === "GET") {
    const sectionId = text(url.searchParams.get("section_id"));
    const operation = text(url.searchParams.get("operation")) as DailyOperation;
    const operationDate = text(url.searchParams.get("date"));
    if (
      !sectionId || !["attendance", "homework"].includes(operation) ||
      !operationDate
    ) {
      return fail("section_id, operation, and date are required", 422);
    }
    if (
      !canManageDailyClaims(user) &&
      !(await teacherCanUseSection(svc, school, linkedStaffId, sectionId))
    ) {
      return fail("forbidden", 403);
    }
    try {
      const academicYearId = await sectionAcademicYear(
        svc,
        school,
        sectionId,
        text(url.searchParams.get("academic_year_id")),
      );
      if (!academicYearId) {
        return fail("section and academic year do not match", 422);
      }
      return ok(
        await loadDailyClaim(
          svc,
          school,
          academicYearId,
          sectionId,
          operation,
          operationDate,
        ),
      );
    } catch (error) {
      return fail(
        error instanceof Error ? error.message : "failed to load claim",
      );
    }
  }

  const reopenMatch = path.match(/^\/class-daily-claims\/([^/]+)\/reopen$/);
  if (reopenMatch && method === "POST") {
    if (!canManageDailyClaims(user)) return fail("forbidden", 403);
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const result = await svc.from("class_daily_operation_claims").update({
      status: "reopened",
      reopened_at: new Date().toISOString(),
      reopened_by: user.id,
      reopen_reason: text(body.reason) || null,
      updated_at: new Date().toISOString(),
    }).eq("id", reopenMatch[1]).eq("school_id", school).select().single();
    if (result.error) return fail(result.error.message);
    return ok(result.data);
  }
  return fail("not found", 404);
}

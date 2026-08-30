import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import {
  resolveActiveTeacherScope,
  teacherCanAccessStudent,
} from "./teacher_scope.ts";

export type SchoolRole =
  | "super_admin"
  | "principal"
  | "admin"
  | "coordinator"
  | "teacher"
  | "staff"
  | "parent"
  | "kiosk";

export type Permission =
  | "academics.manage"
  | "accounts.manage"
  | "finance.manage"
  | "guardians.manage"
  | "staff.manage"
  | "staff.read"
  | "students.manage"
  | "students.read_all";

const ALL_ROLES = new Set<SchoolRole>([
  "super_admin",
  "principal",
  "admin",
  "coordinator",
  "teacher",
  "staff",
  "parent",
  "kiosk",
]);

const STAFF_ASSIGNABLE_ROLES = new Set<SchoolRole>([
  "teacher",
  "staff",
  "coordinator",
  "admin",
  "principal",
  "super_admin",
]);

function text(value: unknown): string {
  return `${value ?? ""}`.trim();
}

export function roleName(user: User): string {
  return text(user.app_metadata?.role_name).toLowerCase();
}

export function normalizedRole(value: unknown): SchoolRole | null {
  const role = text(value).toLowerCase();
  return ALL_ROLES.has(role as SchoolRole) ? role as SchoolRole : null;
}

export function linkedStaffId(user: User): string {
  return text(user.app_metadata?.linked_id);
}

/** Roles that administer a single school. Finance is deliberately separate. */
export function isSchoolLeader(user: User): boolean {
  return ["principal", "coordinator", "admin", "super_admin"].includes(
    roleName(user),
  );
}

/** Never use this helper for fees: coordinators must not cross that boundary. */
export function isFinanceLeader(user: User): boolean {
  return ["principal", "admin", "super_admin"].includes(roleName(user));
}

export function hasPermission(user: User, permission: Permission): boolean {
  const role = roleName(user);
  switch (permission) {
    case "finance.manage":
      return isFinanceLeader(user);
    case "accounts.manage":
      // Generic account provisioning can create non-staff identities. Keep it
      // above the Coordinator role; staff provisioning has a narrower policy.
      return ["principal", "admin", "super_admin"].includes(role);
    case "academics.manage":
    case "guardians.manage":
    case "staff.manage":
    case "students.manage":
    case "students.read_all":
      return isSchoolLeader(user);
    case "staff.read":
      return isSchoolLeader(user) || role === "teacher" || role === "staff";
  }
}

export function canManageStaff(user: User): boolean {
  return hasPermission(user, "staff.manage");
}

export function canManageAccounts(user: User): boolean {
  return hasPermission(user, "accounts.manage");
}

export function canManageAcademics(user: User): boolean {
  return hasPermission(user, "academics.manage");
}

export function canManageStudents(user: User): boolean {
  return hasPermission(user, "students.manage");
}

export function canManageGuardians(user: User): boolean {
  return hasPermission(user, "guardians.manage");
}

/**
 * Staff creation is intentionally narrower than generic platform account
 * management: Coordinators may create teacher/staff accounts only; Principal
 * and Admin may additionally appoint Coordinators; platform roles remain a
 * Super Admin responsibility.
 */
export function canAssignStaffRole(user: User, candidate: unknown): boolean {
  const role = normalizedRole(candidate);
  if (!role || !STAFF_ASSIGNABLE_ROLES.has(role)) return false;
  const actor = roleName(user);
  if (actor === "super_admin") return true;
  if (actor === "principal" || actor === "admin") {
    return ["teacher", "staff", "coordinator"].includes(role);
  }
  if (actor === "coordinator") {
    return ["teacher", "staff"].includes(role);
  }
  return false;
}

/**
 * Generic user-account roles; only school leaders may use this surface for
 * arbitrary account management. Coordinators get a deliberately narrow
 * parent-account exception through `canCreateParentAccount`, because the
 * student/guardian workflow creates that login before linking the student.
 */
export function canAssignAccountRole(user: User, candidate: unknown): boolean {
  const role = normalizedRole(candidate);
  if (!role) return false;
  const actor = roleName(user);
  if (actor === "super_admin") return true;
  if (actor === "coordinator") return role === "parent";
  if (!["principal", "admin"].includes(actor)) return false;
  return ["teacher", "staff", "coordinator", "parent", "kiosk"].includes(
    role,
  );
}

/** Parent login creation is part of Coordinator guardian management. */
export function canCreateParentAccount(user: User, candidate: unknown): boolean {
  return roleName(user) === "coordinator" &&
    normalizedRole(candidate) === "parent";
}

/** Coordinators may read only the parent directory needed for student links. */
export function canReadParentAccounts(user: User, candidate: unknown): boolean {
  return canManageAccounts(user) || canCreateParentAccount(user, candidate);
}

export function isSchoolLeadershipRole(value: unknown): boolean {
  return ["principal", "coordinator", "admin", "super_admin"].includes(
    text(value).toLowerCase(),
  );
}

export type StudentAccess = "all" | "scoped" | null;

/**
 * Resolve student access from server-owned relationships. Never accept a
 * client-provided staff, section, parent, or student relation as authority.
 */
export async function studentAccess(
  svc: SupabaseClient,
  school: string,
  user: User,
  studentId: string,
): Promise<StudentAccess> {
  if (!school || !studentId) return null;
  // A leadership role has school-wide authority, not authority over a made-up
  // or another school's UUID. Resolve the target before returning `all` so
  // callers can consistently turn cross-tenant/unowned identifiers into 404.
  if (canManageStudents(user)) {
    const { data, error } = await svc.from("students").select("id")
      .eq("school_id", school).eq("id", studentId).maybeSingle();
    if (error) throw new Error(error.message);
    return data ? "all" : null;
  }

  const role = roleName(user);
  if (role === "teacher") {
    const staffId = linkedStaffId(user);
    return staffId &&
        await teacherCanAccessStudent(svc, school, staffId, studentId)
      ? "scoped"
      : null;
  }
  if (role === "parent") {
    const { data, error } = await svc.from("parent_student_links").select("id")
      .eq("school_id", school).eq("parent_user_id", user.id).eq(
        "student_id",
        studentId,
      ).maybeSingle();
    if (error) throw new Error(error.message);
    return data ? "scoped" : null;
  }
  return null;
}

/** `null` means unrestricted school-admin access; an empty set means none. */
export async function visibleStudentIds(
  svc: SupabaseClient,
  school: string,
  user: User,
): Promise<Set<string> | null> {
  if (canManageStudents(user)) return null;
  const role = roleName(user);
  if (role === "teacher") {
    const staffId = linkedStaffId(user);
    if (!staffId) return new Set();
    const scope = await resolveActiveTeacherScope(svc, school, staffId);
    const sectionIds = [...scope.sections.keys()];
    if (sectionIds.length === 0) return new Set();
    const { data, error } = await svc.from("students").select("id")
      .eq("school_id", school).in("current_section_id", sectionIds);
    if (error) throw new Error(error.message);
    return new Set((data ?? []).map((row) => text(row.id)).filter(Boolean));
  }
  if (role === "parent") {
    const { data, error } = await svc.from("parent_student_links")
      .select("student_id").eq("school_id", school).eq(
        "parent_user_id",
        user.id,
      );
    if (error) throw new Error(error.message);
    return new Set((data ?? []).map((row) => text(row.student_id)).filter(Boolean));
  }
  return new Set();
}

export async function canAccessGuardian(
  svc: SupabaseClient,
  school: string,
  user: User,
  guardianId: string,
): Promise<boolean> {
  const { data, error } = await svc.from("guardians").select("student_id")
    .eq("id", guardianId).eq("school_id", school).maybeSingle();
  if (error) throw new Error(error.message);
  const studentId = text(data?.student_id);
  return Boolean(await studentAccess(svc, school, user, studentId));
}

export function guardianSelectFor(user: User): string {
  // Teachers only need operational contact data. Parents may read their own
  // family's record, while leadership handles complete school records.
  return roleName(user) === "teacher"
    ? "id, student_id, full_name, relationship, phone, is_primary, created_at, updated_at"
    : "*";
}

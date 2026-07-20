import { User } from "https://esm.sh/@supabase/supabase-js@2";

/** Roles that administer a single school.  Finance is deliberately separate. */
export function roleName(user: User): string {
  return `${user.app_metadata?.role_name ?? ""}`.trim().toLowerCase();
}

export function isSchoolLeader(user: User): boolean {
  return ["principal", "coordinator", "admin", "super_admin"].includes(
    roleName(user),
  );
}

/** Never use this helper for fees: coordinators must not cross that boundary. */
export function isFinanceLeader(user: User): boolean {
  return ["principal", "admin", "super_admin"].includes(roleName(user));
}

export function isSchoolLeadershipRole(value: unknown): boolean {
  return ["principal", "coordinator", "admin", "super_admin"].includes(
    `${value ?? ""}`.trim().toLowerCase(),
  );
}

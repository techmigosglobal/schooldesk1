import {
  canAssignAccountRole,
  canCreateParentAccount,
  canManageAccounts,
  canReadParentAccounts,
  hasPermission,
} from "./authorization.ts";
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

function actor(role_name: string) {
  return {
    id: `${role_name}-id`,
    app_metadata: {
      school_id: "school-a",
      role_name,
    },
  } as never;
}

Deno.test("Coordinator can manage assigned-school accounts, not platform roles", () => {
  const coordinator = actor("coordinator");
  assert(canCreateParentAccount(coordinator, "parent"));
  assert(canManageAccounts(coordinator));
  assert(hasPermission(coordinator, "accounts.manage"));
  assert(!hasPermission(coordinator, "finance.manage"));
  assert(canReadParentAccounts(coordinator, "Parent"));
  assert(canReadParentAccounts(coordinator, null));
  assert(canAssignAccountRole(coordinator, "parent"));
  assert(canAssignAccountRole(coordinator, "kiosk"));
  assert(canAssignAccountRole(coordinator, "coordinator"));
  assert(!canAssignAccountRole(coordinator, "super_admin"));
  assert(!canAssignAccountRole(coordinator, "admin"));
  assert(!canAssignAccountRole(coordinator, "principal"));
});

Deno.test("school leaders retain managed account role ceilings", () => {
  const admin = actor("admin");
  assert(canAssignAccountRole(admin, "parent"));
  assert(canAssignAccountRole(admin, "coordinator"));
  assert(!canAssignAccountRole(admin, "principal"));
  assertEquals(canCreateParentAccount(admin, "parent"), false);
  assert(canReadParentAccounts(admin, null));
});

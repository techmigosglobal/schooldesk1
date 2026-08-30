import {
  canAssignAccountRole,
  canCreateParentAccount,
  canReadParentAccounts,
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

Deno.test("Coordinator may create a parent login for student onboarding only", () => {
  const coordinator = actor("coordinator");
  assert(canCreateParentAccount(coordinator, "parent"));
  assert(canReadParentAccounts(coordinator, "Parent"));
  assert(!canReadParentAccounts(coordinator, null));
  assert(canAssignAccountRole(coordinator, "parent"));
  assert(!canAssignAccountRole(coordinator, "kiosk"));
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

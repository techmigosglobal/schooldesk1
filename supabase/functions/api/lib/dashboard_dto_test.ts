import {
  coordinatorDashboardDto,
  financeDashboardDto,
  type DashboardOperationsInput,
} from "./dashboard_dto.ts";
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const operations: DashboardOperationsInput = {
  activeAssignedStudents: 21,
  activeUnassignedStudents: 3,
  staffCount: 7,
  sectionCount: 4,
  pendingLeaveCount: 2,
  recentAnnouncements: [{ id: "announcement-1", title: "Holiday" }],
  pendingEventApprovals: 5,
  pendingAccessApprovals: 1,
  attendanceToday: 18,
  attendancePercentage: 89,
  attendancePresent: 16,
  attendanceMarked: 18,
};

Deno.test("coordinator dashboard DTO excludes every finance property", () => {
  const dashboard = coordinatorDashboardDto(operations);

  assertEquals(dashboard.total_students, 21);
  assertEquals(dashboard.metrics.pending_access_approvals, 1);
  assert(!("fees" in dashboard));
  assert(!("pending_fee_balance" in dashboard));
  assert(!("pending_fee_requests" in dashboard.metrics));
  assert(!JSON.stringify(dashboard).includes("fee"));
});

Deno.test("finance dashboard DTO adds finance data only for authorized callers", () => {
  const dashboard = financeDashboardDto(operations, {
    pendingFeeBalance: 1250,
    pendingFeeRequests: 2,
    collectionPercentage: 67,
    totalPaid: 2500,
    totalDue: 1250,
  });

  assertEquals(dashboard.pending_fee_balance, 1250);
  assertEquals(dashboard.metrics.pending_fee_requests, 2);
  assertEquals(dashboard.fees, {
    collection_pct: 67,
    total_paid: 2500,
    total_due: 1250,
  });
});

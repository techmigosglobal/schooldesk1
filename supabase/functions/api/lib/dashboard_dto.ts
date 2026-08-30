export type DashboardOperationsInput = {
  activeAssignedStudents: number;
  activeUnassignedStudents: number;
  staffCount: number;
  sectionCount: number;
  pendingLeaveCount: number;
  recentAnnouncements: Array<Record<string, unknown>>;
  pendingEventApprovals: number;
  pendingAccessApprovals: number;
  attendanceToday: number;
  attendancePercentage: number;
  attendancePresent: number;
  attendanceMarked: number;
};

export type CoordinatorDashboardDto = {
  total_students: number;
  total_staff: number;
  total_sections: number;
  pending_leave_requests: number;
  recent_announcements: Array<Record<string, unknown>>;
  metrics: {
    total_students: number;
    active_unassigned_students: number;
    total_staff: number;
    total_classes: number;
    pending_event_approvals: number;
    pending_access_approvals: number;
    attendance_today: number;
  };
  today_attendance: {
    attendance_pct: number;
    present: number;
    marked: number;
  };
};

export type FinanceDashboardInput = {
  pendingFeeBalance: number;
  pendingFeeRequests: number;
  collectionPercentage: number;
  totalPaid: number;
  totalDue: number;
};

export type FinanceDashboardDto = CoordinatorDashboardDto & {
  pending_fee_balance: number;
  metrics: CoordinatorDashboardDto["metrics"] & {
    pending_fee_requests: number;
  };
  fees: {
    collection_pct: number;
    total_paid: number;
    total_due: number;
  };
};

/**
 * Operations-only dashboard contract for coordinators. Keep finance fields out
 * of this object rather than removing them after constructing a broader DTO.
 */
export function coordinatorDashboardDto(
  input: DashboardOperationsInput,
): CoordinatorDashboardDto {
  return {
    total_students: input.activeAssignedStudents,
    total_staff: input.staffCount,
    total_sections: input.sectionCount,
    pending_leave_requests: input.pendingLeaveCount,
    recent_announcements: input.recentAnnouncements,
    metrics: {
      total_students: input.activeAssignedStudents,
      active_unassigned_students: input.activeUnassignedStudents,
      total_staff: input.staffCount,
      total_classes: input.sectionCount,
      pending_event_approvals: input.pendingEventApprovals,
      pending_access_approvals: input.pendingAccessApprovals,
      attendance_today: input.attendanceToday,
    },
    today_attendance: {
      attendance_pct: input.attendancePercentage,
      present: input.attendancePresent,
      marked: input.attendanceMarked,
    },
  };
}

/**
 * Finance-capable dashboard contract used only after the caller has passed the
 * dashboard authorization check. It intentionally extends the operations DTO
 * at construction time so the coordinator response cannot inherit these keys.
 */
export function financeDashboardDto(
  operations: DashboardOperationsInput,
  finance: FinanceDashboardInput,
): FinanceDashboardDto {
  const base = coordinatorDashboardDto(operations);
  return {
    ...base,
    pending_fee_balance: finance.pendingFeeBalance,
    metrics: {
      ...base.metrics,
      pending_fee_requests: finance.pendingFeeRequests,
    },
    fees: {
      collection_pct: finance.collectionPercentage,
      total_paid: finance.totalPaid,
      total_due: finance.totalDue,
    },
  };
}

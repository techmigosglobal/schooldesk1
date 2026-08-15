/// Canonical status handling for parent-submitted fee payment proofs.
///
/// The database retains a few historical status names. This helper keeps
/// those aliases consistent across principal dashboards and approval queues.
enum FeePaymentRequestState {
  initiated,
  pending,
  clarificationRequired,
  approved,
  rejected,
  reversed,
  unknown,
}

abstract final class FeePaymentRequestStatus {
  static const principalPendingStatuses = <String>{
    'pending',
    'submitted',
    'pending_verification',
    'resubmitted',
  };

  static const terminalStatuses = <String>{'approved', 'rejected', 'reversed'};

  static String normalize(Object? value) {
    return '${value ?? ''}'
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  static FeePaymentRequestState state(Object? value) {
    final status = normalize(value);
    if (status == 'initiated') return FeePaymentRequestState.initiated;
    if (principalPendingStatuses.contains(status)) {
      return FeePaymentRequestState.pending;
    }
    if (status == 'clarification_required') {
      return FeePaymentRequestState.clarificationRequired;
    }
    if (status == 'approved') return FeePaymentRequestState.approved;
    if (status == 'rejected') return FeePaymentRequestState.rejected;
    if (status == 'reversed') return FeePaymentRequestState.reversed;
    return FeePaymentRequestState.unknown;
  }

  static bool isPrincipalPending(Object? value) =>
      state(value) == FeePaymentRequestState.pending;

  static bool isReviewRecord(Object? value) {
    final current = state(value);
    return current != FeePaymentRequestState.initiated &&
        current != FeePaymentRequestState.unknown;
  }

  static bool isTerminal(Object? value) =>
      terminalStatuses.contains(normalize(value));

  static String label(Object? value) {
    final status = normalize(value);
    switch (state(status)) {
      case FeePaymentRequestState.initiated:
        return 'Not submitted';
      case FeePaymentRequestState.pending:
        return status == 'pending' ? 'Pending' : 'Pending Review';
      case FeePaymentRequestState.clarificationRequired:
        return 'Clarification Required';
      case FeePaymentRequestState.approved:
        return 'Approved';
      case FeePaymentRequestState.rejected:
        return 'Rejected';
      case FeePaymentRequestState.reversed:
        return 'Reversed';
      case FeePaymentRequestState.unknown:
        return status.isEmpty ? 'Unknown' : status;
    }
  }
}

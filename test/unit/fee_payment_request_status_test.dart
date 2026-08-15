import 'package:flutter_test/flutter_test.dart';

import 'package:schooldesk1/core/utils/fee_payment_request_status.dart';

void main() {
  group('FeePaymentRequestStatus', () {
    test('classifies every principal-pending alias consistently', () {
      for (final status in [
        'pending',
        'submitted',
        'pending_verification',
        'resubmitted',
      ]) {
        expect(
          FeePaymentRequestStatus.state(status),
          FeePaymentRequestState.pending,
          reason: status,
        );
        expect(FeePaymentRequestStatus.isPrincipalPending(status), isTrue);
        expect(FeePaymentRequestStatus.isReviewRecord(status), isTrue);
      }
    });

    test('keeps clarification outside the principal pending queue', () {
      expect(
        FeePaymentRequestStatus.state('clarification_required'),
        FeePaymentRequestState.clarificationRequired,
      );
      expect(
        FeePaymentRequestStatus.isPrincipalPending('clarification_required'),
        isFalse,
      );
      expect(
        FeePaymentRequestStatus.isReviewRecord('clarification_required'),
        isTrue,
      );
    });

    test('excludes unfinished initiated intents', () {
      expect(
        FeePaymentRequestStatus.state('initiated'),
        FeePaymentRequestState.initiated,
      );
      expect(FeePaymentRequestStatus.isPrincipalPending('initiated'), isFalse);
      expect(FeePaymentRequestStatus.isReviewRecord('initiated'), isFalse);
    });

    test('classifies all terminal statuses and preserves reversed visibly', () {
      for (final status in ['approved', 'rejected', 'reversed']) {
        expect(FeePaymentRequestStatus.isTerminal(status), isTrue);
        expect(FeePaymentRequestStatus.isReviewRecord(status), isTrue);
      }
      expect(FeePaymentRequestStatus.label('approved'), 'Approved');
      expect(FeePaymentRequestStatus.label('rejected'), 'Rejected');
      expect(FeePaymentRequestStatus.label('reversed'), 'Reversed');
    });

    test('normalizes legacy formatting variations', () {
      expect(
        FeePaymentRequestStatus.normalize(' Pending-Verification '),
        'pending_verification',
      );
      expect(FeePaymentRequestStatus.isPrincipalPending('SUBMITTED'), isTrue);
    });
  });
}

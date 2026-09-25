enum MutationStatus { queued, syncing, synced, failed, conflict }

class MutationReceipt {
  const MutationReceipt({
    required this.localId,
    required this.status,
    this.serverId,
    this.error,
    this.idempotencyKey,
  });

  final String localId;
  final String? serverId;
  final MutationStatus status;
  final Object? error;
  final String? idempotencyKey;

  bool get isPending =>
      status == MutationStatus.queued || status == MutationStatus.syncing;
}

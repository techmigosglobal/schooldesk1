class SyncWorkItem {
  const SyncWorkItem({
    required this.localId,
    required this.accountScope,
    required this.method,
    required this.path,
    required this.idempotencyKey,
    required this.createdAt,
    this.dependsOn = const <String>[],
  });

  final String localId;
  final String accountScope;
  final String method;
  final String path;
  final String idempotencyKey;
  final DateTime createdAt;
  final List<String> dependsOn;
}

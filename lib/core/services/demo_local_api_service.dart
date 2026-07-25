import 'dart:async';

import 'package:dio/dio.dart';

import 'package:schooldesk1/core/services/demo_fixture_store.dart';
import 'package:schooldesk1/core/services/demo_sandbox_service.dart';

/// The in-app backend for a verified demo session. Every request after the
/// shared credential check is resolved from fictional encrypted device data,
/// never over the network.
class DemoLocalApiService {
  DemoLocalApiService._();

  static final instance = DemoLocalApiService._();
  static const localSchoolId = '00000000-0000-4000-8000-000000000001';
  static const localUserId = '00000000-0000-4000-8000-000000000010';

  bool _active = false;
  bool _awaitingRoleSelection = false;
  String _role = '';
  Map<String, dynamic> _snapshot = const {};
  DemoFixtureStore _store = DemoFixtureStore.pristine();
  final List<Map<String, dynamic>> _localMutations = [];

  bool get isActive => _active;
  bool get isAwaitingRoleSelection => _awaitingRoleSelection;
  String get role => _role;
  List<Map<String, dynamic>> get localMutations =>
      List.unmodifiable(_localMutations);

  void start({required String role, required Map<String, dynamic> snapshot}) {
    _active = true;
    _awaitingRoleSelection = false;
    _role = role.trim().toLowerCase();
    _snapshot = Map<String, dynamic>.from(snapshot);
    _store = DemoFixtureStore.fromSnapshot(_snapshot);
    _localMutations
      ..clear()
      ..addAll(
        (snapshot['local_mutations'] as List? ?? const []).whereType<Map>().map(
          (entry) => Map<String, dynamic>.from(entry),
        ),
      );
  }

  void stop() {
    _active = false;
    _awaitingRoleSelection = false;
    _role = '';
    _snapshot = const {};
    _store = DemoFixtureStore.pristine();
    _localMutations.clear();
  }

  /// Preserves the local demo credential state while returning to the role
  /// chooser. Logout itself resets the fixture content before this is called.
  void awaitRoleSelection() {
    stop();
    _awaitingRoleSelection = true;
  }

  /// Clears only fictional local records and persists the pristine snapshot.
  Future<void> reset() async {
    _store = DemoFixtureStore.pristine();
    _localMutations.clear();
    _snapshot = {..._snapshot, ..._store.toSnapshot(), 'local_mutations': []};
    await DemoSandboxService.instance.saveSnapshot(_snapshot);
  }

  Response<dynamic> responseFor(RequestOptions options) {
    final path = options.path.toLowerCase();
    final method = options.method.toUpperCase();
    final request = options.data;
    if (method != 'GET') {
      _localMutations.add({
        'path': path,
        'method': method,
        'payload': request is Map ? Map<String, dynamic>.from(request) : {},
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    final data = _store.respond(
      path: path,
      method: method,
      role: _role,
      body: request is Map ? Map<String, dynamic>.from(request) : const {},
      query: Map<String, dynamic>.from(options.queryParameters),
    );
    if (method != 'GET') {
      _snapshot = {
        ..._snapshot,
        ..._store.toSnapshot(),
        'local_mutations': _localMutations,
      };
      unawaited(DemoSandboxService.instance.saveSnapshot(_snapshot));
    }
    return Response<dynamic>(
      requestOptions: options,
      statusCode: 200,
      data: data,
    );
  }
}

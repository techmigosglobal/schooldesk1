import 'package:flutter/material.dart';

import '../../../../services/backend_data_service.dart';

/// Service locator — provides singleton instances of all controllers and repositories.
/// Replace with proper DI framework (get_it) when scaling to production.
class ServiceLocator {
  ServiceLocator._();

  static BackendDataService? _storage;

  static Future<void> initialize() async {
    _storage = await BackendDataService.getInstance();
  }

  static BackendDataService get storage {
    assert(
      _storage != null,
      'ServiceLocator.initialize() must be called first.',
    );
    return _storage!;
  }
}

/// Provider widget that makes controllers available to the widget tree.
/// Wraps the app with all necessary ChangeNotifierProviders.
///
/// Usage: Wrap MaterialApp with AppProviders in main.dart when adding
/// proper state management (Provider package or Riverpod).
///
/// For now, controllers are instantiated directly in screens using:
/// ```dart
/// late final _controller = PrincipalDashboardController();
/// ```
class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // TODO: Wrap with MultiProvider when adding Provider package
    // return MultiProvider(
    //   providers: [
    //     ChangeNotifierProvider(create: (_) => AuthController(ServiceLocator.storage)),
    //     ChangeNotifierProvider(create: (_) => PrincipalDashboardController()),
    //     ChangeNotifierProvider(create: (_) => AdminDashboardController()),
    //     ChangeNotifierProvider(create: (_) => StudentController(ApiStudentRepository())),
    //     ChangeNotifierProvider(create: (_) => LeaveController(ApiLeaveRepository())),
    //   ],
    //   child: child,
    // );
    return child;
  }
}

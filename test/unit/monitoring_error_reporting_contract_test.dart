import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;

  String read(String relativePath) =>
      File('$root/$relativePath').readAsStringSync();

  group('monitoring and crash reporting contract', () {
    test('backend persists error events and exposes principal monitoring APIs', () {
      final model = read('school-backend/internal/models/error_event.go');
      final database = read('school-backend/internal/database/database.go');
      final routes = read('school-backend/internal/routes/routes.go');
      final handler = read('school-backend/internal/handlers/error_event.go');
      final middleware = read(
        'school-backend/internal/middleware/error_event.go',
      );
      final main = read('school-backend/main.go');

      expect(model, contains('type ErrorEvent struct'));
      expect(model, contains('ErrorID'));
      expect(model, contains('RequestID'));
      expect(model, contains('Status'));
      expect(model, contains('ResolutionNote'));
      expect(database, contains('&models.ErrorEvent{}'));

      expect(routes, contains('NewErrorEventHandler'));
      expect(routes, contains('monitoring := api.Group("/monitoring")'));
      expect(routes, contains('monitoring.POST("/error-events"'));
      expect(
        routes,
        contains(
          'monitoring.GET("/error-events", middleware.RBACMiddleware("Principal")',
        ),
      );
      expect(
        routes,
        contains(
          'monitoring.GET("/error-events/:id", middleware.RBACMiddleware("Principal")',
        ),
      );
      expect(
        routes,
        contains(
          'monitoring.PATCH("/error-events/:id/resolve", middleware.RBACMiddleware("Principal")',
        ),
      );

      expect(handler, contains('func (h *ErrorEventHandler) Create'));
      expect(handler, contains('func (h *ErrorEventHandler) List'));
      expect(handler, contains('func (h *ErrorEventHandler) Get'));
      expect(handler, contains('func (h *ErrorEventHandler) Resolve'));
      expect(handler, contains('sanitizeErrorMetadata'));

      expect(
        middleware,
        contains('func ErrorEventMiddleware() gin.HandlerFunc'),
      );
      expect(middleware, contains('X-Error-ID'));
      expect(middleware, contains('error_id'));
      expect(middleware, contains('debug.Stack()'));
      expect(main, contains('middleware.ErrorEventMiddleware()'));
      expect(main, contains('gin.New()'));
    });

    test('Flutter reports crashes and API failures to backend', () {
      final main = read('lib/main.dart');
      final client = read('lib/core/network/backend_api_client.dart');
      final monitoringApi = read(
        'lib/core/network/api_modules/monitoring_api.dart',
      );
      final service = read('lib/core/services/error_reporting_service.dart');

      expect(main, contains('ErrorReportingService.instance.initialize'));
      expect(main, contains('FlutterError.onError'));
      expect(main, contains('PlatformDispatcher.instance.onError'));

      expect(client, contains('ApiErrorReporter'));
      expect(client, contains('apiErrorReporter'));
      expect(client, contains("part 'api_modules/monitoring_api.dart';"));
      expect(monitoringApi, contains('submitErrorEvent'));
      expect(monitoringApi, contains('getErrorEvents'));
      expect(monitoringApi, contains('resolveErrorEvent'));

      expect(service, contains('class ErrorReportingService'));
      expect(service, contains('recordFlutterError'));
      expect(service, contains('recordPlatformError'));
      expect(service, contains('recordApiError'));
      expect(service, contains('submitErrorEvent'));
      expect(service, contains('/monitoring/error-events'));
    });

    test('principal has a usable system monitor screen', () {
      final routes = read('lib/routes/app_routes.dart');
      final guard = read('lib/routes/route_access_guard.dart');
      final registry = read('lib/routes/schooldesk_screen_registry.dart');
      final drawer = read('lib/core/widgets/app_navigation.dart');
      final screen = read(
        'lib/features/monitoring/presentation/screens/system_monitor_screen.dart',
      );

      expect(routes, contains('systemMonitor'));
      expect(routes, contains('SystemMonitorScreen'));
      expect(guard, contains('AppRoutes.systemMonitor: {\'principal\'}'));
      expect(registry, contains('System Monitor'));
      expect(drawer, contains('System Monitor'));
      expect(screen, contains('getErrorEvents'));
      expect(screen, contains('resolveErrorEvent'));
      expect(screen, contains('Request ID'));
      expect(screen, contains('Error ID'));
    });
  });
}

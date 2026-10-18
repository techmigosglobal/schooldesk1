import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class _Inbox implements HttpClientAdapter {
  _Inbox(this.role);
  final String role;
  bool read = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? f,
  ) async {
    Object data = {};
    if (o.path == '/notifications')
      data = {
        'items': [
          {
            'id': 'notice',
            'title': 'School subject $role',
            'body': 'Complete custom notification message',
            'target_role': role,
            'type': 'custom_notification',
            'is_read': read,
            'created_at': '2026-10-17T01:00:00Z',
          },
        ],
        'has_more': false,
      };
    if (o.path.endsWith('/read')) read = true;
    if (o.path.endsWith('/unread-count')) data = {'count': read ? 0 : 1};
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final role in [
    'parent',
    'teacher',
    'coordinator',
    'principal',
    'super_admin',
  ]) {
    testWidgets(
      '$role sees inbox subject, reads full message, and has correct diagnostic permission',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        SharedPreferences.setMockInitialValues({});
        NotificationService.resetInstance();
        final api = BackendApiClient.instance;
        api.dio.interceptors.clear();
        api.dio.httpClientAdapter = _Inbox(role);
        api.setAuthToken('synthetic-token');
        api.setCurrentUserId('$role-user');
        api.setCurrentRole(role);
        tester.view.physicalSize = const Size(900, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: NotificationCenterScreen(role: role),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('School subject $role'), findsOneWidget);
        expect(
          find.text('Test Push'),
          const {'principal', 'super_admin'}.contains(role)
              ? findsWidgets
              : findsNothing,
        );
        final service = await NotificationService.getInstance();
        expect(service.getUnreadCountForRole(role), 1);
        await tester.tap(find.text('School subject $role'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(service.getUnreadCountForRole(role), 0);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        NotificationService.resetInstance();
        api.setCurrentRole(null);
      },
    );
  }
  test(
    'parent profile redirects to Settings and cannot appear as an accessible route',
    () {
      expect(
        RouteAccessGuard.redirectFor(
          routeName: AppRoutes.profileScreen,
          isAuthenticated: true,
          currentRole: 'parent',
        ),
        AppRoutes.settingsScreen,
      );
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.profileScreen,
          role: 'parent',
        ),
        false,
      );
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.profileScreen,
          role: 'teacher',
        ),
        true,
      );
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.principalSendNotification,
          role: 'coordinator',
        ),
        false,
      );
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.principalSendNotification,
          role: 'principal',
        ),
        true,
      );
    },
  );
}

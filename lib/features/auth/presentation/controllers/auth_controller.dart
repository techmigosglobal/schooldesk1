import 'dart:async';

import 'package:flutter/material.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/push_notification_service.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';

/// Authentication controller — manages login state for all 4 roles.
class AuthController extends ChangeNotifier {
  AuthController();

  // ─── State ────────────────────────────────────────────────────────────────

  bool _isLoading = false;
  String? _error;
  String? _currentRole;
  bool _isLoggedIn = false;

  // ─── Getters ──────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentRole => _currentRole;
  bool get isLoggedIn => _isLoggedIn;
  bool get hasError => _error != null;

  // ─── Actions ──────────────────────────────────────────────────────────────

  /// Validates credentials and returns the dashboard route on success.
  /// Returns null on failure (error is set in [error]).
  Future<String?> login({
    required String username,
    required String password,
    String? role,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      RoleAccessService.resetSignOutGuard();
      final response = await BackendApiClient.instance.login(
        LoginRequest(username: username.trim(), password: password),
      );
      final actualRole = response.user.roleName.toLowerCase();
      if (role != null && actualRole != role.toLowerCase()) {
        // The backend has already issued and persisted a valid session at this
        // point. Revoke it before showing the role mismatch so a parent token,
        // for example, cannot remain active behind the teacher login screen.
        await BackendApiClient.instance.logout();
        RoleAccessService.clear();
        _currentRole = null;
        _isLoggedIn = false;
        _setError(
          'Access denied for role "$role". Logged in user role is "${response.user.roleName}".',
        );
        _setLoading(false);
        return null;
      }

      _currentRole = actualRole;
      _isLoggedIn = true;
      unawaited(
        PushNotificationService.instance.registerDeviceTokenIfPossible(),
      );
      _setLoading(false);
      return AppRoutes.loginLoading;
    } on Object catch (e) {
      _setError('Login failed. Please try again. $e');
      _setLoading(false);
      return null;
    }
  }

  Future<void> logout(BuildContext context) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      await PushNotificationService.instance.revokeCurrentToken();
    } on Object catch (_) {
      // Sign-out must still complete if token revocation cannot reach backend.
    }
    await BackendApiClient.instance.logout();
    RoleAccessService.clear();
    _currentRole = null;
    _isLoggedIn = false;
    notifyListeners();
    if (!navigator.mounted) return;
    navigator.pushNamedAndRemoveUntil(AppRoutes.landingPage, (route) => false);
  }

  void clearError() => _clearError();

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/constants/app_constants.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/errors/exceptions.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/push_notification_service.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/services/notification_topic_manager.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class AuthLoginScreen extends StatefulWidget {
  const AuthLoginScreen({super.key});

  @override
  State<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends State<AuthLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      // Reset any previous sign-out guard so RoleAccessService can re-initialize.
      RoleAccessService.resetSignOutGuard();

      final response = await BackendApiClient.instance.login(
        LoginRequest(username: username, password: password),
      );
      if (EnvConfig.enableLogging) {
        developer.log('Backend login successful for ${response.user.roleName}');
      }

      unawaited(
        PushNotificationService.instance.registerDeviceTokenIfPossible(),
      );

      // Set up notification topics for the user's role
      final role = _roleFromRoleName(response.user.roleName);
      if (role != null) {
        unawaited(NotificationTopicManager().setupTopicsForRole(role));
      }

      if (!mounted) return;
      // Navigate to the loading screen which will initialize
      // RoleAccessService and then redirect to the correct dashboard.
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.loginLoading,
        (_) => false,
      );
      await PushNotificationService.instance
          .handlePendingNotificationAfterLogin();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = switch (e) {
          NetworkException() =>
            'Unable to connect to the school server. Please check the backend connection.',
          AuthException() => 'Invalid username or password.',
          ServerException(:final message) => message,
          _ => 'Sign in failed. Please try again.',
        };
      });
    }
  }

  SchoolDeskRole? _roleFromRoleName(String roleName) {
    final lower = roleName.trim().toLowerCase();
    switch (lower) {
      case AppConstants.rolePrincipal:
      case AppConstants.roleAdmin:
      case 'super_admin':
        return SchoolDeskRole.principal;
      case AppConstants.roleTeacher:
        return SchoolDeskRole.teacher;
      case AppConstants.roleParent:
        return SchoolDeskRole.parent;
      case 'student':
        return SchoolDeskRole.student;
      case 'kiosk':
        return SchoolDeskRole
            .student; // Map kiosk to student for notification purposes
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 820;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 48 : 20,
              vertical: wide ? 40 : 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: wide ? _buildWideLayout() : _buildCompactLayout(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(child: _buildIntroPanel(expanded: true)),
        const SizedBox(width: 40),
        SizedBox(width: 420, child: _buildLoginPanel()),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIntroPanel(),
        const SizedBox(height: 24),
        _buildLoginPanel(),
      ],
    );
  }

  Widget _buildIntroPanel({bool expanded = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: expanded
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/branding/ArishVilleLogo.png',
            width: expanded ? 180 : 132,
            height: expanded ? 180 : 132,
            fit: BoxFit.cover,
            semanticLabel: '${AppConstants.appName} logo',
          ),
        ),
        const SizedBox(height: 22),
        Text(
          AppConstants.appName,
          style: GoogleFonts.dmSans(
            fontSize: expanded ? 44 : 34,
            height: 1.05,
            fontWeight: FontWeight.w800,
            color: context.appTheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Learn Today, Lead Tomorrow',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            height: 1.5,
            color: context.appTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RoleChip(label: 'Principal', icon: Icons.account_balance_rounded),
            _RoleChip(label: 'Teacher', icon: Icons.cast_for_education_rounded),
            _RoleChip(label: 'Parent', icon: Icons.family_restroom_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginPanel() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: context.appTheme.onSurface.withAlpha(12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sign in',
              style: GoogleFonts.dmSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.appTheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter only your username and password. Role access is resolved by the backend.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                height: 1.4,
                color: context.appTheme.muted,
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              label: 'Username',
              textField: true,
              child: TextFormField(
                controller: _usernameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter username';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Password',
              textField: true,
              child: TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter password';
                  }
                  return null;
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appTheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: context.appTheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Semantics(
              button: true,
              label: _loading ? 'Signing in' : 'Sign in',
              enabled: !_loading,
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _login,
                  icon: _loading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.appTheme.surface,
                          ),
                        )
                      : const Icon(Icons.login_rounded, size: 18),
                  label: Text(
                    _loading ? 'Signing in' : 'Sign in',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.landingPage,
                (_) => false,
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _RoleChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: context.appTheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.appTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.appTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

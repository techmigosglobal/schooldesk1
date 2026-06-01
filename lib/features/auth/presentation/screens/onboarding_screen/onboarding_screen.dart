import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/errors/exceptions.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/push_notification_service.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameCtrl = TextEditingController();
  final _boardCtrl = TextEditingController();
  final _schoolEmailCtrl = TextEditingController();
  final _schoolPhoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _adminUsernameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPhoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _adminRole = 'Principal';
  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _schoolNameCtrl.dispose();
    _boardCtrl.dispose();
    _schoolEmailCtrl.dispose();
    _schoolPhoneCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminUsernameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPhoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final response = await BackendApiClient.instance.setupSchool(
        SchoolSetupRequest(
          schoolName: _schoolNameCtrl.text,
          schoolType: 'school',
          affiliationBoard: _boardCtrl.text,
          email: _schoolEmailCtrl.text,
          phone: _schoolPhoneCtrl.text,
          city: _cityCtrl.text,
          state: _stateCtrl.text,
          adminName: _adminNameCtrl.text,
          adminUsername: _adminUsernameCtrl.text,
          adminEmail: _adminEmailCtrl.text,
          adminPhone: _adminPhoneCtrl.text,
          adminPassword: _passwordCtrl.text,
          adminRole: _adminRole,
        ),
      );
      unawaited(RoleAccessService.initialize());
      unawaited(
        PushNotificationService.instance.registerDeviceTokenIfPossible(),
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        _dashboardRouteFor(response.user.roleName),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (error) {
          NetworkException() =>
            'Unable to connect to the school server. Please check the backend connection.',
          ServerException(:final message) => message,
          ValidationException(:final message) => message,
          _ => 'School setup failed. Please try again.',
        };
      });
    }
  }

  String _dashboardRouteFor(String roleName) {
    switch (roleName.trim().toLowerCase()) {
      case 'principal':
        return AppRoutes.principalDashboard;
      case 'admin':
        return AppRoutes.adminDashboard;
      default:
        return AppRoutes.principalDashboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 820;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 44 : 18,
              vertical: wide ? 36 : 18,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _IntroPanel(onBack: _goToLogin)),
                        const SizedBox(width: 32),
                        SizedBox(width: 470, child: _buildFormCard()),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _IntroPanel(onBack: _goToLogin),
                        const SizedBox(height: 20),
                        _buildFormCard(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _goToLogin() {
    Navigator.pushReplacementNamed(context, AppRoutes.principalLogin);
  }

  Widget _buildFormCard() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SectionTitle(
                title: 'Start Your School',
                subtitle: 'Create the school and first operator account.',
              ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: 14),
              ],
              _field(
                controller: _schoolNameCtrl,
                label: 'School name',
                icon: Icons.account_balance_rounded,
                requiredMessage: 'Enter school name',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _boardCtrl,
                      label: 'Board',
                      icon: Icons.workspace_premium_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _schoolPhoneCtrl,
                      label: 'School phone',
                      icon: Icons.call_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                controller: _schoolEmailCtrl,
                label: 'School email',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                email: false,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _cityCtrl,
                      label: 'City',
                      icon: Icons.location_city_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _stateCtrl,
                      label: 'State',
                      icon: Icons.map_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                title: 'First Login',
                subtitle: 'This account is created and signed in immediately.',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _adminRole,
                decoration: const InputDecoration(
                  labelText: 'Account role',
                  prefixIcon: Icon(Icons.admin_panel_settings_rounded),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Principal',
                    child: Text('Principal'),
                  ),
                  DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _adminRole = value!),
              ),
              const SizedBox(height: 12),
              _field(
                controller: _adminNameCtrl,
                label: 'Full name',
                icon: Icons.person_rounded,
                requiredMessage: 'Enter account holder name',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _adminUsernameCtrl,
                label: 'Username',
                icon: Icons.badge_rounded,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _adminEmailCtrl,
                label: 'Email',
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                requiredMessage: 'Enter email',
                email: true,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _adminPhoneCtrl,
                label: 'Phone',
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                enabled: !_saving,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _finish(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    onPressed: _saving
                        ? null
                        : () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'Enter at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _finish,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rocket_launch_rounded, size: 18),
                label: Text(_saving ? 'Setting Up...' : 'Create School'),
              ),
              TextButton(
                onPressed: _saving ? null : _goToLogin,
                child: const Text('Already have a login? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? requiredMessage,
    bool email = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) {
        final text = (value ?? '').trim();
        if (requiredMessage != null && text.isEmpty) return requiredMessage;
        if (email && (!text.contains('@') || !text.contains('.'))) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to login',
        ),
        const SizedBox(height: 18),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.school_rounded, size: 42, color: AppTheme.primary),
        ),
        const SizedBox(height: 24),
        Text(
          'Clean school setup, ready for guided operations.',
          style: GoogleFonts.dmSans(
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Create the school record, system roles, permissions, and first login in one safe transaction.',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            height: 1.55,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SetupChip(icon: Icons.verified_rounded, label: 'Roles'),
            _SetupChip(icon: Icons.lock_rounded, label: 'Permissions'),
            _SetupChip(icon: Icons.person_add_alt_1_rounded, label: 'Login'),
            _SetupChip(icon: Icons.fact_check_rounded, label: 'Audit ready'),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            height: 1.4,
            color: AppTheme.muted,
          ),
        ),
      ],
    );
  }
}

class _SetupChip extends StatelessWidget {
  const _SetupChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: AppTheme.primary),
      label: Text(label),
      backgroundColor: AppTheme.primary.withAlpha(14),
      side: BorderSide(color: AppTheme.primary.withAlpha(36)),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                height: 1.35,
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

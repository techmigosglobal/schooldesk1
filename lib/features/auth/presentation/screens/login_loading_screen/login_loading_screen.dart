import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/auth/api_auth_repository.dart';
import 'package:schooldesk1/core/auth/auth_repository.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/loading_skeleton_widget.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';

/// Transient loading screen shown after login while [RoleAccessService]
/// fetches the user's scope data in the background.
///
/// Once initialization completes the screen navigates to the appropriate
/// dashboard for the authenticated role.
import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';

class LoginLoadingScreen extends StatefulWidget {
  final AuthRepository? repository;

  const LoginLoadingScreen({super.key, this.repository});

  @override
  State<LoginLoadingScreen> createState() => _LoginLoadingScreenState();
}

class _LoginLoadingScreenState extends State<LoginLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseOpacity;
  String _statusMessage = 'Signing you in…';
  bool _navigated = false;
  RepositoryState<Object> _state = const RepositoryState.loading();

  AuthRepository get _repository =>
      widget.repository ?? ApiAuthRepository.legacyDefault;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Phase 1: Ensure role access data is loaded.
      setState(() => _statusMessage = 'Loading your school data…');
      await RoleAccessService.initialize();

      if (!mounted || _navigated) return;
      _navigated = true;

      // Phase 2: Navigate to the correct dashboard.
      final role = _repository.currentRoleName?.trim().toLowerCase() ?? '';
      final route =
          RouteAccessGuard.dashboardForRole(role) ?? '/landing-page-screen';
      SchoolDeskNavigation.go(context, route);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _state = RepositoryState<Object>.error(error: error));
      // Even if RoleAccessService fails, still navigate – the dashboard
      // will show its own error state.
      final role = _repository.currentRoleName?.trim().toLowerCase() ?? '';
      final route =
          RouteAccessGuard.dashboardForRole(role) ?? '/landing-page-screen';
      _navigated = true;
      SchoolDeskNavigation.go(context, route);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.background,
      body: SchoolDeskRepositoryStateView<Object>(
        state: _state,
        onRetry: _initialize,
        errorTitle: 'Unable to restore your session',
        loadingMessage: _statusMessage,
        data: (_) => SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: context.appTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x240B2F5B),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/branding/ArishVilleLogo.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.account_balance_rounded,
                      size: 48,
                      color: context.appTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Pulsing status text
                AnimatedBuilder(
                  animation: _pulseOpacity,
                  builder: (context, child) {
                    return Opacity(opacity: _pulseOpacity.value, child: child);
                  },
                  child: Text(
                    _statusMessage,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: const Column(
                    children: [
                      LoadingSkeletonWidget(height: 12, borderRadius: 6),
                      SizedBox(height: 10),
                      LoadingSkeletonWidget(
                        width: 230,
                        height: 12,
                        borderRadius: 6,
                      ),
                      SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: LoadingSkeletonWidget(
                              height: 44,
                              borderRadius: 10,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: LoadingSkeletonWidget(
                              height: 44,
                              borderRadius: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

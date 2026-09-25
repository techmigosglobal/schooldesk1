import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schooldesk1/app/router/app_router.dart';
import 'package:schooldesk1/core/constants/app_constants.dart';
import 'package:schooldesk1/core/desktop/desktop_layout_wrapper.dart';
import 'package:schooldesk1/core/offline/offline_status_banner.dart';
import 'package:schooldesk1/core/widgets/animated_startup_splash.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

/// Riverpod composition root for the single installable Flutter application.
/// Every top-level location enters GoRouter through a typed route contract.
class SchoolDeskApp extends ConsumerWidget {
  const SchoolDeskApp({
    required this.themeMode,
    required this.textScaleFactor,
    this.child,
    super.key,
  });

  final ThemeMode themeMode;
  final double textScaleFactor;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppConstants.schoolName,
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      builder: (context, routedChild) {
        final mediaQuery = MediaQuery.of(context);
        final effectiveTextScale = mediaQuery.textScaler
            .scale(textScaleFactor)
            .clamp(1.0, SchoolDeskResponsive.maxSupportedTextScale)
            .toDouble();
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(effectiveTextScale),
          ),
          child: DesktopLayoutWrapper(
            child: OfflineStatusBanner(
              child: AnimatedStartupSplash(
                child: routedChild ?? child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}

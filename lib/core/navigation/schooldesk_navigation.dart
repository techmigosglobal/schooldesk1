import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navigation adapter for screens still using legacy route names.
/// GoRouter owns production navigation; Navigator fallback keeps isolated
/// widget tests and pre-router hosts functional during migration.
class SchoolDeskNavigation {
  SchoolDeskNavigation._();

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    String route, {
    Object? arguments,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      return router.push<T>(route, extra: arguments);
    }
    return Navigator.of(context).pushNamed<T>(route, arguments: arguments);
  }

  static void go(
    BuildContext context,
    String route, {
    Object? arguments,
  }) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(route, extra: arguments);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  static bool pushFromRoot(
    GlobalKey<NavigatorState> navigatorKey,
    String route, {
    Object? arguments,
  }) {
    final context = navigatorKey.currentContext;
    final router = context == null ? null : GoRouter.maybeOf(context);
    if (router != null) {
      unawaited(router.push(route, extra: arguments));
      return true;
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) return false;
    navigator.pushNamed(route, arguments: arguments);
    return true;
  }

  /// Adapter for infrastructure widgets that already hold a NavigatorState.
  /// The legacy predicate is accepted for source compatibility and ignored
  /// because GoRouter owns the stack when the app is running normally.
  static Future<T?> pushFromNavigator<T extends Object?>(
    NavigatorState navigator,
    String route, {
    Object? arguments,
  }) {
    return push<T>(navigator.context, route, arguments: arguments);
  }

  static void goFromNavigator(
    NavigatorState navigator,
    String route, {
    RoutePredicate? legacyPredicate,
    Object? arguments,
  }) {
    go(navigator.context, route, arguments: arguments);
  }

  static bool goFromRoot(
    GlobalKey<NavigatorState> navigatorKey,
    String route, {
    Object? arguments,
  }) {
    final context = navigatorKey.currentContext;
    final router = context == null ? null : GoRouter.maybeOf(context);
    if (router != null) {
      router.go(route, extra: arguments);
      return true;
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) return false;
    navigator.pushNamedAndRemoveUntil(
      route,
      (_) => false,
      arguments: arguments,
    );
    return true;
  }
}

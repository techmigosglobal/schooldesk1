import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:schooldesk1/core/utils/extensions.dart';

/// Shared decorative page background used behind role dashboards and other
/// high-traffic screens.
///
/// Replaces the previous pattern of every screen hardcoding its own flat
/// `backgroundColor` (e.g. `Color(0xFFF3F7FC)`) with a subtle brand-tinted
/// gradient plus soft, out-of-focus color blobs. This is intentionally
/// lightweight (no images, no animation cost) so it does not affect scroll
/// performance, and it automatically adapts to the current theme via
/// [context.appTheme].
class AppBackground extends StatelessWidget {
  final Widget child;

  /// Optional override for the accent color used to tint the decorative
  /// blobs. Defaults to the current theme's primary color, but dashboards
  /// with a distinct role color (e.g. teacher = purple, parent = green) can
  /// pass their own accent for a subtle sense of place.
  final Color? accent;

  const AppBackground({super.key, required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final tint = accent ?? theme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.isDark
              ? [theme.pageBackground, theme.pageBackground]
              : [
                  Color.alphaBlend(tint.withAlpha(15), theme.pageBackground),
                  theme.pageBackground,
                ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!theme.isDark) ...[
            Positioned(
              top: -60,
              right: -50,
              child: _Blob(color: tint.withAlpha(26), size: 220),
            ),
            Positioned(
              top: 160,
              left: -70,
              child: _Blob(color: theme.secondary.withAlpha(20), size: 180),
            ),
          ],
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

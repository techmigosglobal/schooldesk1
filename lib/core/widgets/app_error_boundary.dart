import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A reusable fallback wrapper for screens that already surface recoverable
/// errors through state.
///
/// Usage:
/// ```dart
/// AppErrorBoundary(
///   child: SomeRiskyWidget(),
///   fallbackTitle: 'Something went wrong',
/// )
/// ```
class AppErrorBoundary extends StatefulWidget {
  final Widget child;
  final Object? error;
  final String? fallbackTitle;
  final String? fallbackMessage;
  final VoidCallback? onRetry;
  final WidgetBuilder? fallbackBuilder;

  const AppErrorBoundary({
    super.key,
    required this.child,
    this.error,
    this.fallbackTitle,
    this.fallbackMessage,
    this.onRetry,
    this.fallbackBuilder,
  });

  @override
  State<AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<AppErrorBoundary> {
  @override
  Widget build(BuildContext context) {
    if (widget.error != null) {
      if (widget.fallbackBuilder != null) {
        return widget.fallbackBuilder!(context);
      }
      return _buildFallback(context);
    }

    return widget.child;
  }

  Widget _buildFallback(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return Material(
      color: theme.colorScheme.errorContainer.withOpacity(0.3),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: errorColor),
              const SizedBox(height: 16),
              Text(
                widget.fallbackTitle ?? 'Something went wrong',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.fallbackMessage ??
                    'An unexpected error occurred. Please try again.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    widget.onRetry!();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    'Retry',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

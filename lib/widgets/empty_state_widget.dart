import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? subtitle;

  const EmptyStateWidget({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    this.description = 'No data available right now.',
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(tokens.radius.sheet),
              ),
              child: Icon(icon, size: 48, color: theme.colorScheme.primary),
            ),
            SizedBox(height: tokens.spacing.lg),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing.sm),
            Text(
              subtitle ?? description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: tokens.spacing.lg),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.lg,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radius.control),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

enum BadgeStatus {
  active,
  inactive,
  pending,
  approved,
  rejected,
  warning,
  onLeave,
  defaulter,
  excellent,
  absent,
}

class StatusBadgeWidget extends StatelessWidget {
  final Object? status;
  final String? label;
  final String? customLabel;
  final bool compact;

  const StatusBadgeWidget({
    super.key,
    required this.status,
    this.label,
    this.customLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: BorderRadius.circular(tokens.radius.control),
        border: Border.all(color: config.border, width: 1),
      ),
      child: Text(
        customLabel ?? _resolvedLabel(config.label),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: config.textColor,
        ),
      ),
    );
  }

  _BadgeConfig _getConfig() {
    switch (_normalizeStatus(status, label)) {
      case BadgeStatus.active:
        return _BadgeConfig(
          label: 'Active',
          background: AppTheme.successContainer,
          border: AppTheme.success.withAlpha(77),
          textColor: AppTheme.success,
        );
      case BadgeStatus.inactive:
        return _BadgeConfig(
          label: 'Inactive',
          background: AppTheme.surfaceVariant,
          border: AppTheme.outline,
          textColor: AppTheme.muted,
        );
      case BadgeStatus.pending:
        return _BadgeConfig(
          label: 'Pending',
          background: AppTheme.warningContainer,
          border: AppTheme.warning.withAlpha(77),
          textColor: AppTheme.warning,
        );
      case BadgeStatus.approved:
        return _BadgeConfig(
          label: 'Approved',
          background: AppTheme.successContainer,
          border: AppTheme.success.withAlpha(77),
          textColor: AppTheme.success,
        );
      case BadgeStatus.rejected:
        return _BadgeConfig(
          label: 'Rejected',
          background: AppTheme.errorContainer,
          border: AppTheme.error.withAlpha(77),
          textColor: AppTheme.error,
        );
      case BadgeStatus.warning:
        return _BadgeConfig(
          label: 'Warning',
          background: AppTheme.warningContainer,
          border: AppTheme.warning.withAlpha(77),
          textColor: AppTheme.warning,
        );
      case BadgeStatus.onLeave:
        return _BadgeConfig(
          label: 'On Leave',
          background: AppTheme.infoContainer,
          border: AppTheme.info.withAlpha(77),
          textColor: AppTheme.info,
        );
      case BadgeStatus.defaulter:
        return _BadgeConfig(
          label: 'Defaulter',
          background: AppTheme.errorContainer,
          border: AppTheme.error.withAlpha(77),
          textColor: AppTheme.error,
        );
      case BadgeStatus.excellent:
        return _BadgeConfig(
          label: 'Excellent',
          background: AppTheme.secondaryContainer,
          border: AppTheme.secondary.withAlpha(77),
          textColor: AppTheme.secondary,
        );
      case BadgeStatus.absent:
        return _BadgeConfig(
          label: 'Absent',
          background: AppTheme.errorContainer,
          border: AppTheme.error.withAlpha(77),
          textColor: AppTheme.error,
        );
    }
  }

  static BadgeStatus _statusFromLabel(String? label) {
    switch ((label ?? '').trim().toLowerCase()) {
      case 'active':
        return BadgeStatus.active;
      case 'inactive':
        return BadgeStatus.inactive;
      case 'pending':
        return BadgeStatus.pending;
      case 'approved':
        return BadgeStatus.approved;
      case 'rejected':
        return BadgeStatus.rejected;
      case 'paid':
      case 'excellent':
        return BadgeStatus.excellent;
      case 'overdue':
      case 'defaulter':
        return BadgeStatus.defaulter;
      case 'on leave':
        return BadgeStatus.onLeave;
      case 'absent':
        return BadgeStatus.absent;
      case 'warning':
        return BadgeStatus.warning;
      default:
        return BadgeStatus.inactive;
    }
  }

  static BadgeStatus _normalizeStatus(Object? status, String? label) {
    if (status is BadgeStatus) return status;
    if (status is String) return _statusFromLabel(status);
    return _statusFromLabel(label);
  }

  String _resolvedLabel(String defaultLabel) {
    if (status is String && (status as String).trim().isNotEmpty) {
      return (status as String).trim();
    }
    if (label != null && label!.trim().isNotEmpty) {
      return label!.trim();
    }
    return defaultLabel;
  }
}

class _BadgeConfig {
  final String label;
  final Color background;
  final Color border;
  final Color textColor;

  _BadgeConfig({
    required this.label,
    required this.background,
    required this.border,
    required this.textColor,
  });
}

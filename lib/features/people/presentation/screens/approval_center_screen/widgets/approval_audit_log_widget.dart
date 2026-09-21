import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/utils/extensions.dart';

class ApprovalAuditLogWidget extends StatelessWidget {
  const ApprovalAuditLogWidget({
    required this.logs,
    required this.isLoading,
    required this.onRetry,
    this.error,
    super.key,
  });

  final List<Map<String, dynamic>> logs;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appTheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: context.appTheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Audit Log',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  'Recent actions by you',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: context.appTheme.muted,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Refresh audit log',
                  visualDensity: VisualDensity.compact,
                  onPressed: isLoading ? null : onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (error != null)
            _buildError(context)
          else if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: Text(
                  'No approval decisions recorded yet.',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: context.appTheme.muted,
                  ),
                ),
              ),
            )
          else
            ...List.generate(
              logs.length,
              (index) => Column(
                children: [
                  _buildLogItem(context, logs[index]),
                  if (index < logs.length - 1)
                    const Divider(height: 1, indent: 56, endIndent: 16),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: context.appTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not load approval history. $error',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: context.appTheme.onSurface,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildLogItem(BuildContext context, Map<String, dynamic> log) {
    final event = (log['event_type'] ?? log['action'] ?? '').toString();
    final rejected = event.contains('rejected');
    final changesRequested = event.contains('changes_requested');
    final decision = rejected
        ? 'Rejected'
        : changesRequested
        ? 'Changes requested'
        : 'Approved';
    final color = rejected
        ? context.appTheme.error
        : changesRequested
        ? context.appTheme.warning
        : context.appTheme.success;
    final summary = (log['summary'] ?? 'Approval decision recorded').toString();
    final role = (log['actor_role'] ?? '').toString().trim();
    final createdAt = _formatTimestamp(log['created_at']);
    final details = log['details'];
    final detailsMap = details is Map
        ? Map<String, dynamic>.from(details)
        : const <String, dynamic>{};
    final note = (detailsMap['review_note'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(31),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              rejected
                  ? Icons.close_rounded
                  : changesRequested
                  ? Icons.edit_note_rounded
                  : Icons.check_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$decision — $summary',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (role.isNotEmpty) _titleCase(role),
                    createdAt,
                  ].where((part) => part.isNotEmpty).join(' · '),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: context.appTheme.muted,
                  ),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      color: context.appTheme.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '';
    final local = parsed.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${local.day} ${months[local.month - 1]}, $hour:$minute $period';
  }

  String _titleCase(String value) {
    return value
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

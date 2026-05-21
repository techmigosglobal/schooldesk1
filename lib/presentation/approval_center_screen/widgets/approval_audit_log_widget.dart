import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ApprovalAuditLogWidget extends StatelessWidget {
  const ApprovalAuditLogWidget({super.key});

  final List<Map<String, dynamic>> _auditLog = const [];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: AppTheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Audit Log',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  'Recent actions by you',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(
            _auditLog.length,
            (i) => Column(
              children: [
                _buildLogItem(_auditLog[i]),
                if (i < _auditLog.length - 1)
                  const Divider(height: 1, indent: 56, endIndent: 16),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (log['color'] as Color).withAlpha(31),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              log['icon'] as IconData,
              color: log['color'] as Color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${log['action']} — ',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: log['color'] as Color,
                        ),
                      ),
                      TextSpan(
                        text: log['item'] as String,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  log['time'] as String,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

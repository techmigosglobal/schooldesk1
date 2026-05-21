import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class StudentListItemWidget extends StatelessWidget {
  final dynamic student;
  final VoidCallback onTap;

  const StudentListItemWidget({
    super.key,
    required this.student,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = student;
    Color feeColor;
    String feeLabel;
    switch (s.feeStatus) {
      case 'paid':
        feeColor = AppTheme.success;
        feeLabel = 'Paid';
        break;
      case 'pending':
        feeColor = AppTheme.warning;
        feeLabel = 'Pending';
        break;
      case 'overdue':
        feeColor = AppTheme.error;
        feeLabel = 'Overdue';
        break;
      default:
        feeColor = Colors.red.shade900;
        feeLabel = 'Defaulter';
    }

    Color gradeColor;
    switch (s.performanceGrade) {
      case 'A+':
      case 'A':
        gradeColor = AppTheme.success;
        break;
      case 'B+':
      case 'B':
        gradeColor = AppTheme.info;
        break;
      case 'C+':
      case 'C':
        gradeColor = AppTheme.warning;
        break;
      default:
        gradeColor = AppTheme.error;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (s.hasAttendanceAlert || s.hasFeeAlert)
                ? AppTheme.error.withAlpha(80)
                : AppTheme.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  s.avatarInitials,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (s.hasAttendanceAlert)
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: AppTheme.error,
                        ),
                    ],
                  ),
                  Text(
                    'Class ${s.classSection} · Roll: ${s.rollNumber}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildBadge(
                        '${s.attendancePercent.toStringAsFixed(0)}% att.',
                        s.attendancePercent < 75
                            ? AppTheme.error
                            : AppTheme.success,
                      ),
                      _buildBadge(s.performanceGrade, gradeColor),
                      _buildBadge(feeLabel, feeColor),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

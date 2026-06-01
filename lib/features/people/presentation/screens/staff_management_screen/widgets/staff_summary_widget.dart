import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart';

class StaffSummaryWidget extends StatelessWidget {
  final List<StaffModel> staff;

  const StaffSummaryWidget({super.key, required this.staff});

  @override
  Widget build(BuildContext context) {
    final active = staff.where((s) => s.status == 'active').length;
    final onLeave = staff.where((s) => s.status == 'on_leave').length;
    final absent = staff.where((s) => s.status == 'absent').length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Staff',
            staff.length.toString(),
            Icons.people_rounded,
            AppTheme.primary,
            AppTheme.primaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            'Present Today',
            active.toString(),
            Icons.check_circle_rounded,
            AppTheme.success,
            AppTheme.successContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            'On Leave',
            onLeave.toString(),
            Icons.event_busy_rounded,
            AppTheme.info,
            AppTheme.infoContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            'Absent',
            absent.toString(),
            Icons.person_off_rounded,
            AppTheme.error,
            AppTheme.errorContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(51), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color.withAlpha(204),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

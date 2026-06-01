import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';

class StudentSummaryCardsWidget extends StatelessWidget {
  final int totalStudents;
  final int alertStudents;
  final int topperStudents;
  final int feeDefaulters;

  const StudentSummaryCardsWidget({
    super.key,
    required this.totalStudents,
    required this.alertStudents,
    required this.topperStudents,
    required this.feeDefaulters,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620 ? 2 : 4;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final cardHeight = 104 * textScale.clamp(1.0, 1.2).toDouble();
        final tileWidth =
            (constraints.maxWidth - 24 - ((columns - 1) * 8)) / columns;
        return Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: tileWidth / cardHeight,
            children: [
              _buildCard(
                'Total',
                '$totalStudents',
                Icons.school_rounded,
                AppTheme.primary,
                AppTheme.primaryContainer,
              ),
              _buildCard(
                'Alerts',
                '$alertStudents',
                Icons.warning_amber_rounded,
                AppTheme.error,
                AppTheme.errorContainer,
              ),
              _buildCard(
                'Toppers',
                '$topperStudents',
                Icons.emoji_events_rounded,
                AppTheme.secondary,
                AppTheme.secondaryContainer,
              ),
              _buildCard(
                'Defaulters',
                '$feeDefaulters',
                Icons.account_balance_wallet_outlined,
                AppTheme.warning,
                AppTheme.warningContainer,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';

class StaffFilterBarWidget extends StatelessWidget {
  final String searchQuery;
  final String selectedDesignation;
  final String selectedStatus;
  final List<String> designations;
  final Function(String) onSearchChanged;
  final Function(String) onDesignationChanged;
  final Function(String) onStatusChanged;

  const StaffFilterBarWidget({
    super.key,
    required this.searchQuery,
    required this.selectedDesignation,
    required this.selectedStatus,
    required this.designations,
    required this.onSearchChanged,
    required this.onDesignationChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = ['All', 'Active', 'On Leave', 'Absent'];
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final designationChipHeight = (36.0 * textScale)
        .clamp(38.0, 56.0)
        .toDouble();
    final statusChipHeight = (32.0 * textScale).clamp(36.0, 52.0).toDouble();

    return Column(
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant, width: 1),
          ),
          child: TextField(
            onChanged: onSearchChanged,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: AppTheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Search by name, ID, or designation...',
              hintStyle: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                color: AppTheme.muted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.muted,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Designation filter chips
        SizedBox(
          height: designationChipHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: designations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final designation = designations[i];
              final isSelected = selectedDesignation == designation;
              return GestureDetector(
                onTap: () => onDesignationChanged(designation),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    designation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Status filter chips
        SizedBox(
          height: statusChipHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: statuses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final status = statuses[i];
              final isSelected = selectedStatus == status;
              Color chipColor = AppTheme.muted;
              if (status == 'Active') chipColor = AppTheme.success;
              if (status == 'On Leave') chipColor = AppTheme.info;
              if (status == 'Absent') chipColor = AppTheme.error;

              return GestureDetector(
                onTap: () => onStatusChanged(status),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? chipColor.withAlpha(38)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? chipColor : AppTheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? chipColor : AppTheme.muted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

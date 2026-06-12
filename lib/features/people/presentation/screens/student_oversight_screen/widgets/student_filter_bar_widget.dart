import 'package:flutter/material.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class StudentFilterBarWidget extends StatelessWidget {
  final String searchQuery;
  final String selectedClass;
  final String selectedFeeStatus;
  final List<String> classOptions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onClassChanged;
  final ValueChanged<String> onFeeStatusChanged;

  const StudentFilterBarWidget({
    super.key,
    required this.searchQuery,
    required this.selectedClass,
    required this.selectedFeeStatus,
    required this.classOptions,
    required this.onSearchChanged,
    required this.onClassChanged,
    required this.onFeeStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final feeStatuses = ['All', 'Paid', 'Pending', 'Overdue', 'Defaulter'];
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final filterRowHeight = (34.0 * textScale).clamp(38.0, 56.0).toDouble();

    return Container(
      color: context.appTheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          TextField(
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search student name or roll number...',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: filterRowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: classOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final selected = selectedClass == classOptions[i];
                return FilterChip(
                  label: Text(
                    classOptions[i] == 'All'
                        ? 'All Classes'
                        : 'Class ${classOptions[i]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : context.appTheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: selected,
                  selectedColor: context.appTheme.primary,
                  checkmarkColor: context.appTheme.surface,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: context.appTheme.surfaceVariant,
                  side: BorderSide(
                    color: selected ? context.appTheme.primary : context.appTheme.outline,
                  ),
                  onSelected: (_) => onClassChanged(classOptions[i]),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: filterRowHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: feeStatuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final selected = selectedFeeStatus == feeStatuses[i];
                return FilterChip(
                  label: Text(
                    feeStatuses[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : context.appTheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: selected,
                  selectedColor: context.appTheme.primary,
                  checkmarkColor: context.appTheme.surface,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: context.appTheme.surfaceVariant,
                  side: BorderSide(
                    color: selected ? context.appTheme.primary : context.appTheme.outline,
                  ),
                  onSelected: (_) => onFeeStatusChanged(feeStatuses[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

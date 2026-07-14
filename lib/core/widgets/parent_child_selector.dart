import 'package:flutter/material.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';

/// A consistent, photo-led child picker for parent workflows.
///
/// The selected child remains owned by the calling screen so existing loading,
/// refresh, and [ParentChildSelectionService] behaviour is preserved.
class ParentChildSelector extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;

  const ParentChildSelector({
    super.key,
    required this.children,
    required this.selectedIndex,
    required this.onSelected,
    this.isLoading = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final tokens = Theme.of(context).schoolDesk;
    final color = tokens.roleColor(SchoolDeskRole.parent);
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 2),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final child = children[index];
          final selected = index == selectedIndex;
          final name = _name(child);
          final classLabel = _classLabel(child);
          return Semantics(
            button: true,
            selected: selected,
            label: '$name${selected ? ', selected' : ''}',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: isLoading || selected ? null : () => onSelected(index),
                child: AnimatedContainer(
                  duration: animationsDisabled
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(minWidth: 132),
                  padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
                  decoration: BoxDecoration(
                    color: selected ? color : tokens.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? color : color.withAlpha(48),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withAlpha(tokens.isDark ? 54 : 36),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StudentAvatar(child: child, selected: selected),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SchoolDeskAdaptiveText(
                              name,
                              maxLines: 1,
                              minFontSize: 10,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: selected
                                        ? Colors.white
                                        : tokens.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            if (classLabel.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                classLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: selected
                                          ? Colors.white.withAlpha(220)
                                          : tokens.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  final Map<String, dynamic> child;
  final bool selected;

  const _StudentAvatar({required this.child, required this.selected});

  @override
  Widget build(BuildContext context) {
    final photo = _firstText(child, const ['photo_url', 'photo', 'avatar']);
    final name = _name(child);
    final fallbackColor = selected
        ? Colors.white.withAlpha(42)
        : Theme.of(
            context,
          ).schoolDesk.roleColor(SchoolDeskRole.parent).withAlpha(24);
    final foreground = selected
        ? Colors.white
        : Theme.of(context).schoolDesk.roleColor(SchoolDeskRole.parent);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fallbackColor,
        border: Border.all(
          color: selected
              ? Colors.white.withAlpha(150)
              : foreground.withAlpha(70),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.isEmpty
          ? Center(
              child: Text(
                _initials(name),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : photo.startsWith('assets/')
          ? Image.asset(photo, fit: BoxFit.cover)
          : Image.network(
              photo.startsWith('http') ? photo : '${EnvConfig.apiOrigin}$photo',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  _initials(name),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }
}

String _name(Map<String, dynamic> child) {
  final direct = _firstText(child, const ['name', 'full_name', 'student_name']);
  if (direct.isNotEmpty) return direct;
  final combined = [
    _firstText(child, const ['first_name']),
    _firstText(child, const ['last_name']),
  ].where((part) => part.isNotEmpty).join(' ');
  return combined.isEmpty ? 'Student' : combined;
}

String _firstText(Map<String, dynamic> child, List<String> keys) {
  for (final key in keys) {
    final value = child[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _classLabel(Map<String, dynamic> child) {
  return parentChildClassAndSectionLabel(child);
}

/// Formats the child’s academic placement for every parent-facing surface.
///
/// Database identifiers are deliberately excluded: parents should see a class
/// and section name, never the UUID used to scope backend requests.
String parentChildClassAndSectionLabel(Map<String, dynamic> child) {
  String scalarText(List<String> keys) {
    for (final key in keys) {
      final value = child[key];
      if (value is Map) continue;
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String nestedText(String key, List<String> nestedKeys) {
    final value = child[key];
    if (value is! Map) return '';
    for (final nestedKey in nestedKeys) {
      final text = value[nestedKey]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  final directGrade = scalarText(const ['grade_name', 'class_name', 'class']);
  final grade = directGrade.isNotEmpty
      ? directGrade
      : nestedText('grade', const ['grade_name', 'name']);
  final sectionData = child['current_section'] is Map
      ? child['current_section']
      : child['section'];
  final nestedSection = sectionData is Map
      ? Map<dynamic, dynamic>.from(sectionData)
      : const <dynamic, dynamic>{};
  final nestedGrade = nestedSection['grade'];
  final gradeFromSection = nestedGrade is Map
      ? _firstMapText(nestedGrade, const ['grade_name', 'name'])
      : '';
  final resolvedGrade = grade.isNotEmpty ? grade : gradeFromSection;
  final directSection = scalarText(const [
    'section_name',
    'current_section_name',
  ]);
  final section = directSection.isNotEmpty
      ? directSection
      : _firstMapText(nestedSection, const ['section_name', 'name']);
  final values = [
    if (resolvedGrade.isNotEmpty) _withPrefix(resolvedGrade, 'Class'),
    if (section.isNotEmpty) _withPrefix(section, 'Section'),
  ];
  return values.join(' • ');
}

String _firstMapText(Map<dynamic, dynamic> value, List<String> keys) {
  for (final key in keys) {
    final text = value[key]?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _withPrefix(String value, String prefix) {
  final normalized = value.trim();
  return normalized.toLowerCase().startsWith('${prefix.toLowerCase()} ')
      ? normalized
      : '$prefix $normalized';
}

String _initials(String name) {
  final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final result = parts.take(2).map((part) => part[0]).join().toUpperCase();
  return result.isEmpty ? 'ST' : result;
}

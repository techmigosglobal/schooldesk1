import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Subject icon mapping — maps subject names to themed icons
// ─────────────────────────────────────────────────────────────────────────────
IconData _subjectIcon(String subject) {
  final lower = subject.trim().toLowerCase();
  if (lower.contains('math')) {
    return Icons.calculate_rounded;
  }
  if (lower.contains('science')) {
    return Icons.science_rounded;
  }
  if (lower.contains('english') || lower.contains('language')) {
    return Icons.translate_rounded;
  }
  if (lower.contains('hindi')) {
    return Icons.language_rounded;
  }
  if (lower.contains('social') ||
      lower.contains('history') ||
      lower.contains('geography')) {
    return Icons.public_rounded;
  }
  if (lower.contains('computer') ||
      lower.contains('it') ||
      lower.contains('coding')) {
    return Icons.computer_rounded;
  }
  if (lower.contains('art') ||
      lower.contains('drawing') ||
      lower.contains('craft')) {
    return Icons.palette_rounded;
  }
  if (lower.contains('music') || lower.contains('vocal')) {
    return Icons.music_note_rounded;
  }
  if (lower.contains('physical') ||
      lower.contains('sport') ||
      lower.contains('pt')) {
    return Icons.sports_soccer_rounded;
  }
  if (lower.contains('moral') ||
      lower.contains('value') ||
      lower.contains('ethics')) {
    return Icons.volunteer_activism_rounded;
  }
  if (lower.contains('evs') || lower.contains('environment')) {
    return Icons.eco_rounded;
  }
  if (lower.contains('dance')) {
    return Icons.directions_run_rounded;
  }
  if (lower.contains('gk') || lower.contains('general knowledge')) {
    return Icons.lightbulb_rounded;
  }
  return Icons.menu_book_rounded;
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject Card Grid — for teacher homework forms (multi / single selection)
// ─────────────────────────────────────────────────────────────────────────────

/// A selectable grid of subject cards.
///
/// The teacher taps cards to toggle selection; selected cards show a tick and
/// highlight color. Supports both single-select and multi-select modes.
class SubjectCardGrid extends StatelessWidget {
  /// All available subjects for the current class.
  final List<String> subjects;

  /// Currently selected subjects.
  final Set<String> selectedSubjects;

  /// Called when a subject is tapped (toggled).
  final ValueChanged<String> onToggle;

  /// Whether interaction is disabled (e.g. while saving).
  final bool enabled;

  /// If true, only one subject can be selected at a time.
  final bool singleSelect;

  /// Optional label shown above the grid.
  final String? label;

  const SubjectCardGrid({
    super.key,
    required this.subjects,
    required this.selectedSubjects,
    required this.onToggle,
    this.enabled = true,
    this.singleSelect = false,
    this.label,
  });

  static const _accent = Color(0xFF0F9F8E);
  static const _accentLight = Color(0xFFE3FAF5);
  static const _unselectedBg = Color(0xFFF4FAFB);
  static const _unselectedBorder = Color(0xFFD0EDEA);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 16, color: _accent),
              const SizedBox(width: 6),
              Text(
                label!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF183037),
                ),
              ),
              if (singleSelect)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text(
                    '(pick one)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9DB5BC)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < subjects.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _SubjectCard(
                  subject: subjects[i],
                  isSelected: selectedSubjects.contains(subjects[i]),
                  enabled: enabled,
                  onTap: () => onToggle(subjects[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectCard extends StatefulWidget {
  final String subject;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.subject,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.enabled) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final icon = _subjectIcon(widget.subject);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          constraints: const BoxConstraints(minWidth: 100),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? SubjectCardGrid._accentLight
                : SubjectCardGrid._unselectedBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? SubjectCardGrid._accent
                  : SubjectCardGrid._unselectedBorder,
              width: widget.isSelected ? 1.8 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: SubjectCardGrid._accent.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated check / subject icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: widget.isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('check'),
                        size: 20,
                        color: SubjectCardGrid._accent,
                      )
                    : Icon(
                        icon,
                        key: const ValueKey('icon'),
                        size: 20,
                        color: const Color(0xFF9DB5BC),
                      ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.subject,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: widget.isSelected
                        ? const Color(0xFF0A5C4E)
                        : const Color(0xFF183037),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject Chips — for parent homework screens (read-only display)
// ─────────────────────────────────────────────────────────────────────────────

/// Renders a comma-separated subject string as individual colored chips.
class SubjectChips extends StatelessWidget {
  /// The raw subject string (may be comma-separated for multiple subjects).
  final String subjectString;

  /// Text size for chip labels.
  final double fontSize;

  const SubjectChips({
    super.key,
    required this.subjectString,
    this.fontSize = 11,
  });

  static const _accent = Color(0xFF0F9F8E);
  static const _accentLight = Color(0xFFE3FAF5);

  List<String> get _subjects {
    return subjectString
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _subjects;
    if (subjects.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: subjects.map((subject) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _accentLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_subjectIcon(subject), size: 12, color: _accent),
              const SizedBox(width: 4),
              Text(
                subject,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0A5C4E),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

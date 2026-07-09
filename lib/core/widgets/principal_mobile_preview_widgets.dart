import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class PrincipalPreviewColors {
  PrincipalPreviewColors._();

  static const primary = Color(0xFF005CE6);
  static const primaryDark = Color(0xFF0045AD);
  static const role = Color(0xFF2457D6);
  static const roleDark = Color(0xFF1D4ED8);
  static const roleLight = Color(0xFFDBEAFE);
  static const ink = Color(0xFF171717);
  static const dark = Color(0xFF313131);
  static const muted = Color(0xFF667085);
  static const gray500 = Color(0xFF6B7280);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray300 = Color(0xFFD0D5DD);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray100 = Color(0xFFF3F4F6);
  static const bg = Color(0xFFF3F6FA);
  static const white = Colors.white;
  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0xFFDCFCE7);
  static const orange = Color(0xFFF97316);
  static const orangeSoft = Color(0xFFFFF7ED);
  static const red = Color(0xFFF04444);
  static const redSoft = Color(0xFFFDE3E3);
  static const purple = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFEDE9FE);
  static const teal = Color(0xFF0E9384);
  static const tealSoft = Color(0xFFCCFBF1);
  static const cyan = Color(0xFF0891B2);
  static const cyanSoft = Color(0xFFCFFAFE);
}

enum PrincipalPreviewTone {
  role,
  green,
  orange,
  red,
  purple,
  teal,
  cyan,
  neutral,
}

Color principalPreviewToneColor(PrincipalPreviewTone tone) {
  switch (tone) {
    case PrincipalPreviewTone.role:
      return PrincipalPreviewColors.roleDark;
    case PrincipalPreviewTone.green:
      return PrincipalPreviewColors.green;
    case PrincipalPreviewTone.orange:
      return PrincipalPreviewColors.orange;
    case PrincipalPreviewTone.red:
      return PrincipalPreviewColors.red;
    case PrincipalPreviewTone.purple:
      return PrincipalPreviewColors.purple;
    case PrincipalPreviewTone.teal:
      return PrincipalPreviewColors.teal;
    case PrincipalPreviewTone.cyan:
      return PrincipalPreviewColors.cyan;
    case PrincipalPreviewTone.neutral:
      return PrincipalPreviewColors.muted;
  }
}

Color principalPreviewToneSoft(PrincipalPreviewTone tone) {
  switch (tone) {
    case PrincipalPreviewTone.role:
      return PrincipalPreviewColors.roleLight;
    case PrincipalPreviewTone.green:
      return PrincipalPreviewColors.greenSoft;
    case PrincipalPreviewTone.orange:
      return PrincipalPreviewColors.orangeSoft;
    case PrincipalPreviewTone.red:
      return PrincipalPreviewColors.redSoft;
    case PrincipalPreviewTone.purple:
      return PrincipalPreviewColors.purpleSoft;
    case PrincipalPreviewTone.teal:
      return PrincipalPreviewColors.tealSoft;
    case PrincipalPreviewTone.cyan:
      return PrincipalPreviewColors.cyanSoft;
    case PrincipalPreviewTone.neutral:
      return PrincipalPreviewColors.gray100;
  }
}

TextStyle principalPreviewTextStyle({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
}) {
  return GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: 0,
  );
}

class PrincipalPreviewCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Border? border;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const PrincipalPreviewCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = Colors.white,
    this.border,
    this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: border ?? Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    final wrapped = semanticLabel == null
        ? card
        : Semantics(label: semanticLabel, container: true, child: card);
    if (onTap == null) return wrapped;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: wrapped,
      ),
    );
  }
}

class PrincipalPreviewHeader extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final String leadingTooltip;
  final VoidCallback onLeadingPressed;
  final List<Widget> trailing;

  const PrincipalPreviewHeader({
    super.key,
    required this.title,
    required this.leadingIcon,
    required this.leadingTooltip,
    required this.onLeadingPressed,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF103869), Color(0xFF1D4ED8), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Tooltip(
            message: leadingTooltip,
            child: Material(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onLeadingPressed,
                borderRadius: BorderRadius.circular(999),
                child: SizedBox.square(
                  dimension: 38,
                  child: Icon(leadingIcon, size: 19, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: principalPreviewTextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ...trailing.map(
            (w) => IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: w,
            ),
          ),
        ],
      ),
    );
  }
}

class PrincipalPreviewCircleButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const PrincipalPreviewCircleButton({
    super.key,
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox.square(
          dimension: 40,
          child: IconButton.filledTonal(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: PrincipalPreviewColors.gray100,
              foregroundColor: PrincipalPreviewColors.dark,
              shape: const CircleBorder(),
            ),
          ),
        ),
      ),
    );
  }
}

class PrincipalPreviewAvatar extends StatelessWidget {
  final String label;

  const PrincipalPreviewAvatar({super.key, this.label = 'PR'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            PrincipalPreviewColors.role,
            PrincipalPreviewColors.primaryDark,
          ],
        ),
      ),
      child: Text(
        label,
        style: principalPreviewTextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class PrincipalPreviewTitleBlock extends StatelessWidget {
  final String title;
  final String subtitle;

  const PrincipalPreviewTitleBlock({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF103869), Color(0xFF1D4ED8), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x301D4ED8),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative circles in background
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(18),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(12),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: principalPreviewTextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: principalPreviewTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(210),
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class PrincipalPreviewSection extends StatelessWidget {
  final Widget child;
  final double top;

  const PrincipalPreviewSection({
    super.key,
    required this.child,
    this.top = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.fromLTRB(16, top, 16, 0), child: child);
  }
}

class PrincipalPreviewSectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const PrincipalPreviewSectionHeader({
    super.key,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: principalPreviewTextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: PrincipalPreviewColors.ink,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 10), action!],
        ],
      ),
    );
  }
}

class PrincipalPreviewLinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const PrincipalPreviewLinkButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: PrincipalPreviewColors.primary,
        minimumSize: const Size(44, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: principalPreviewTextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class PrincipalPreviewBadge extends StatelessWidget {
  final String label;
  final PrincipalPreviewTone tone;

  const PrincipalPreviewBadge({
    super.key,
    required this.label,
    this.tone = PrincipalPreviewTone.role,
  });

  @override
  Widget build(BuildContext context) {
    final color = principalPreviewToneColor(tone);
    final soft = principalPreviewToneSoft(tone);
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [soft, soft.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: principalPreviewTextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class PrincipalPreviewIconBox extends StatelessWidget {
  final String label;
  final PrincipalPreviewTone tone;
  final double size;

  const PrincipalPreviewIconBox({
    super.key,
    required this.label,
    this.tone = PrincipalPreviewTone.role,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: principalPreviewToneSoft(tone),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: principalPreviewTextStyle(
          fontSize: size <= 40 ? 11 : 13,
          fontWeight: FontWeight.w900,
          color: principalPreviewToneColor(tone),
        ),
      ),
    );
  }
}

class PrincipalPreviewFilterTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const PrincipalPreviewFilterTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: selectedIndex == index
                      ? const LinearGradient(
                          colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selectedIndex == index
                      ? null
                      : PrincipalPreviewColors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selectedIndex == index
                        ? Colors.transparent
                        : PrincipalPreviewColors.gray200,
                    width: 1.5,
                  ),
                  boxShadow: selectedIndex == index
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1D4ED8).withAlpha(50),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labels[index],
                  style: principalPreviewTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selectedIndex == index
                        ? Colors.white
                        : PrincipalPreviewColors.muted,
                  ),
                ),
              ),
            ),
            if (index != labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class PrincipalPreviewSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const PrincipalPreviewSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  @override
  State<PrincipalPreviewSearchField> createState() =>
      _PrincipalPreviewSearchFieldState();
}

class _PrincipalPreviewSearchFieldState
    extends State<PrincipalPreviewSearchField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: Semantics(
        textField: true,
        label: widget.hintText,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: context.appTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused
                  ? const Color(0xFF1D4ED8)
                  : PrincipalPreviewColors.gray200,
              width: _focused ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _focused
                    ? const Color(0xFF1D4ED8).withAlpha(20)
                    : const Color(0x100F172A),
                blurRadius: _focused ? 12 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 22,
                color: _focused
                    ? const Color(0xFF1D4ED8)
                    : PrincipalPreviewColors.gray400,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  onChanged: widget.onChanged,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle: principalPreviewTextStyle(
                      fontSize: 13,
                      color: PrincipalPreviewColors.muted,
                    ),
                  ),
                  style: principalPreviewTextStyle(
                    fontSize: 13,
                    color: PrincipalPreviewColors.dark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrincipalPreviewMetricRow extends StatelessWidget {
  final List<PrincipalPreviewMetric> metrics;

  const PrincipalPreviewMetricRow({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          Expanded(child: _MetricCard(metric: metrics[index])),
          if (index != metrics.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class PrincipalPreviewMetric {
  final String value;
  final String label;
  final Color? valueColor;

  const PrincipalPreviewMetric({
    required this.value,
    required this.label,
    this.valueColor,
  });
}

class _MetricCard extends StatelessWidget {
  final PrincipalPreviewMetric metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final valueColor =
        metric.valueColor ?? PrincipalPreviewColors.roleDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            valueColor.withAlpha(22),
            valueColor.withAlpha(10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: valueColor.withAlpha(45)),
        boxShadow: [
          BoxShadow(
            color: valueColor.withAlpha(18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              metric.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: principalPreviewTextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: principalPreviewTextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: PrincipalPreviewColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrincipalPreviewSignalGrid extends StatelessWidget {
  final List<PrincipalPreviewSignal> signals;

  const PrincipalPreviewSignalGrid({super.key, required this.signals});

  // Color cycle for signal tiles
  static const List<Color> _palette = [
    Color(0xFF1D4ED8),
    Color(0xFF0F766E),
    Color(0xFF7C3AED),
    Color(0xFFEA580C),
    Color(0xFF0284C7),
    Color(0xFF16A34A),
    Color(0xFFB91C1C),
    Color(0xFFB45309),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: signals.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 70,
      ),
      itemBuilder: (context, index) {
        final color = _palette[index % _palette.length];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withAlpha(22), color.withAlpha(10)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(40)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                signals[index].value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: principalPreviewTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                signals[index].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: principalPreviewTextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: PrincipalPreviewColors.muted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PrincipalPreviewSignal {
  final String value;
  final String label;

  const PrincipalPreviewSignal({required this.value, required this.label});
}

class PrincipalPreviewSmallNote extends StatelessWidget {
  final String title;
  final String body;

  const PrincipalPreviewSmallNote({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: principalPreviewTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: PrincipalPreviewColors.dark,
                height: 1.5,
              ),
            ),
            TextSpan(
              text: '\n$body',
              style: principalPreviewTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: PrincipalPreviewColors.muted,
                height: 1.5,
              ),
            ),
          ],
        ),
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class PrincipalPreviewActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PrincipalPreviewTone tone;
  final bool filled;

  const PrincipalPreviewActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.tone = PrincipalPreviewTone.role,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = tone == PrincipalPreviewTone.role
        ? PrincipalPreviewColors.primary
        : principalPreviewToneColor(tone);

    if (filled) {
      // Use a gradient-wrapped InkWell for the role tone
      if (tone == PrincipalPreviewTone.role) {
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 42),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: principalPreviewTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 42),
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: principalPreviewTextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 42),
        foregroundColor: color,
        side: BorderSide(color: color, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: principalPreviewTextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class PrincipalPreviewBottomNav extends StatelessWidget {
  final List<PrincipalPreviewBottomItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const PrincipalPreviewBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE5E7EB)),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x180F172A),
              blurRadius: 20,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: selectedIndex == index,
                  label: items[index].label,
                  child: InkWell(
                    onTap: () => onSelected(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Active indicator pill
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: selectedIndex == index ? 36 : 0,
                            height: 3,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF1D4ED8),
                                  Color(0xFF0F766E),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Icon(
                            selectedIndex == index
                                ? items[index].activeIcon
                                : items[index].icon,
                            size: 22,
                            color: selectedIndex == index
                                ? PrincipalPreviewColors.roleDark
                                : PrincipalPreviewColors.gray500,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            items[index].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: principalPreviewTextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: selectedIndex == index
                                  ? PrincipalPreviewColors.roleDark
                                  : PrincipalPreviewColors.gray500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PrincipalPreviewBottomItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const PrincipalPreviewBottomItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class PrincipalPreviewEmpty extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const PrincipalPreviewEmpty({
    super.key,
    required this.title,
    required this.message,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1D4ED8).withAlpha(14),
            const Color(0xFF1D4ED8).withAlpha(6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF1D4ED8).withAlpha(40),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D4ED8).withAlpha(50),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.inbox_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: principalPreviewTextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: PrincipalPreviewColors.dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: principalPreviewTextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PrincipalPreviewColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(width: 10),
            PrincipalPreviewLinkButton(
              label: actionLabel!,
              onPressed: onAction!,
            ),
          ],
        ],
      ),
    );
  }
}

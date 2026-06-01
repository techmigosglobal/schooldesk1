import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const white = Color(0xFFFFFFFF);
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
    this.color = PrincipalPreviewColors.white,
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
        borderRadius: BorderRadius.circular(12),
        border: border ?? Border.all(color: const Color(0xF2E2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: PrincipalPreviewColors.white,
        border: Border(
          bottom: BorderSide(color: PrincipalPreviewColors.gray200),
        ),
      ),
      child: Row(
        children: [
          PrincipalPreviewCircleButton(
            tooltip: leadingTooltip,
            icon: leadingIcon,
            onPressed: onLeadingPressed,
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
                color: PrincipalPreviewColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ...trailing,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PrincipalPreviewColors.role,
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), PrincipalPreviewColors.role],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: principalPreviewTextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.84),
              height: 1.45,
            ),
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
      constraints: const BoxConstraints(minHeight: 23),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: principalPreviewTextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
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
            ChoiceChip(
              label: Text(labels[index]),
              selected: selectedIndex == index,
              onSelected: (_) => onSelected(index),
              selectedColor: PrincipalPreviewColors.role,
              backgroundColor: PrincipalPreviewColors.white,
              side: BorderSide(
                color: selectedIndex == index
                    ? PrincipalPreviewColors.role
                    : PrincipalPreviewColors.gray200,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              showCheckmark: false,
              labelStyle: principalPreviewTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: selectedIndex == index
                    ? Colors.white
                    : PrincipalPreviewColors.muted,
              ),
            ),
            if (index != labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class PrincipalPreviewSearchField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: hintText,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PrincipalPreviewColors.gray200),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 22,
              color: PrincipalPreviewColors.gray400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: hintText,
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
    return PrincipalPreviewCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: metric.valueColor ?? PrincipalPreviewColors.dark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: principalPreviewTextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
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
        mainAxisExtent: 66,
      ),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: PrincipalPreviewColors.gray100,
          borderRadius: BorderRadius.circular(10),
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
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: PrincipalPreviewColors.dark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              signals[index].label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: principalPreviewTextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: PrincipalPreviewColors.muted,
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PrincipalPreviewColors.gray100,
        borderRadius: BorderRadius.circular(10),
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
                height: 1.45,
              ),
            ),
            TextSpan(
              text: '\n$body',
              style: principalPreviewTextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: PrincipalPreviewColors.muted,
                height: 1.45,
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
          color: PrincipalPreviewColors.white,
          border: Border(
            top: BorderSide(color: PrincipalPreviewColors.gray200),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 18,
              offset: Offset(0, -4),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selectedIndex == index
                              ? items[index].activeIcon
                              : items[index].icon,
                          size: 22,
                          color: selectedIndex == index
                              ? PrincipalPreviewColors.role
                              : PrincipalPreviewColors.gray500,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[index].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: principalPreviewTextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: selectedIndex == index
                                ? PrincipalPreviewColors.role
                                : PrincipalPreviewColors.gray500,
                          ),
                        ),
                      ],
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
    return PrincipalPreviewCard(
      child: Row(
        children: [
          const Icon(Icons.inbox_rounded, color: PrincipalPreviewColors.role),
          const SizedBox(width: 12),
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
                    fontWeight: FontWeight.w700,
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

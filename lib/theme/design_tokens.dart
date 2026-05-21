import 'package:flutter/material.dart';

enum SchoolDeskRole { principal, admin, teacher, parent, student }

@immutable
class SchoolDeskSpacing {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  const SchoolDeskSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  static const standard = SchoolDeskSpacing(
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 48,
  );

  static SchoolDeskSpacing lerp(
    SchoolDeskSpacing a,
    SchoolDeskSpacing b,
    double t,
  ) {
    return SchoolDeskSpacing(
      xs: lerpDouble(a.xs, b.xs, t),
      sm: lerpDouble(a.sm, b.sm, t),
      md: lerpDouble(a.md, b.md, t),
      lg: lerpDouble(a.lg, b.lg, t),
      xl: lerpDouble(a.xl, b.xl, t),
      xxl: lerpDouble(a.xxl, b.xxl, t),
    );
  }
}

@immutable
class SchoolDeskRadius {
  final double control;
  final double card;
  final double sheet;
  final double pill;

  const SchoolDeskRadius({
    required this.control,
    required this.card,
    required this.sheet,
    required this.pill,
  });

  static const standard = SchoolDeskRadius(
    control: 8,
    card: 8,
    sheet: 12,
    pill: 999,
  );

  static SchoolDeskRadius lerp(
    SchoolDeskRadius a,
    SchoolDeskRadius b,
    double t,
  ) {
    return SchoolDeskRadius(
      control: lerpDouble(a.control, b.control, t),
      card: lerpDouble(a.card, b.card, t),
      sheet: lerpDouble(a.sheet, b.sheet, t),
      pill: lerpDouble(a.pill, b.pill, t),
    );
  }
}

@immutable
class SchoolDeskElevation {
  final List<BoxShadow> card;
  final List<BoxShadow> floating;

  const SchoolDeskElevation({required this.card, required this.floating});

  static const light = SchoolDeskElevation(
    card: [
      BoxShadow(color: Color(0x140F172A), blurRadius: 18, offset: Offset(0, 8)),
    ],
    floating: [
      BoxShadow(
        color: Color(0x1F0F172A),
        blurRadius: 28,
        offset: Offset(0, 14),
      ),
    ],
  );

  static const dark = SchoolDeskElevation(
    card: [
      BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
    floating: [
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 28,
        offset: Offset(0, 14),
      ),
    ],
  );
}

@immutable
class SchoolDeskMotion {
  final Duration fast;
  final Duration normal;
  final Duration slow;
  final Curve curve;

  const SchoolDeskMotion({
    required this.fast,
    required this.normal,
    required this.slow,
    required this.curve,
  });

  static const standard = SchoolDeskMotion(
    fast: Duration(milliseconds: 140),
    normal: Duration(milliseconds: 220),
    slow: Duration(milliseconds: 360),
    curve: Curves.easeOutCubic,
  );
}

@immutable
class SchoolDeskTheme extends ThemeExtension<SchoolDeskTheme> {
  final bool isDark;
  final SchoolDeskSpacing spacing;
  final SchoolDeskRadius radius;
  final SchoolDeskElevation elevation;
  final SchoolDeskMotion motion;
  final Map<SchoolDeskRole, Color> roleColors;
  final Color pageBackground;
  final Color panel;
  final Color panelMuted;
  final Color panelBorder;
  final Color textMuted;
  final Color focusRing;

  const SchoolDeskTheme({
    required this.isDark,
    required this.spacing,
    required this.radius,
    required this.elevation,
    required this.motion,
    required this.roleColors,
    required this.pageBackground,
    required this.panel,
    required this.panelMuted,
    required this.panelBorder,
    required this.textMuted,
    required this.focusRing,
  });

  factory SchoolDeskTheme.fallback({required bool isDark}) {
    return SchoolDeskTheme(
      isDark: isDark,
      spacing: SchoolDeskSpacing.standard,
      radius: SchoolDeskRadius.standard,
      elevation: isDark ? SchoolDeskElevation.dark : SchoolDeskElevation.light,
      motion: SchoolDeskMotion.standard,
      roleColors: const {
        SchoolDeskRole.principal: Color(0xFF2457D6),
        SchoolDeskRole.admin: Color(0xFF0E9384),
        SchoolDeskRole.teacher: Color(0xFF7C3AED),
        SchoolDeskRole.parent: Color(0xFF16A34A),
        SchoolDeskRole.student: Color(0xFFEA580C),
      },
      pageBackground: isDark
          ? const Color(0xFF0B1120)
          : const Color(0xFFF3F6FA),
      panel: isDark ? const Color(0xFF111827) : Colors.white,
      panelMuted: isDark ? const Color(0xFF1F2937) : const Color(0xFFF6F8FB),
      panelBorder: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      textMuted: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF667085),
      focusRing: isDark ? const Color(0xFF7EA2FF) : const Color(0xFF2457D6),
    );
  }

  Color roleColor(SchoolDeskRole role) {
    return roleColors[role] ?? roleColors[SchoolDeskRole.admin]!;
  }

  @override
  SchoolDeskTheme copyWith({
    bool? isDark,
    SchoolDeskSpacing? spacing,
    SchoolDeskRadius? radius,
    SchoolDeskElevation? elevation,
    SchoolDeskMotion? motion,
    Map<SchoolDeskRole, Color>? roleColors,
    Color? pageBackground,
    Color? panel,
    Color? panelMuted,
    Color? panelBorder,
    Color? textMuted,
    Color? focusRing,
  }) {
    return SchoolDeskTheme(
      isDark: isDark ?? this.isDark,
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      elevation: elevation ?? this.elevation,
      motion: motion ?? this.motion,
      roleColors: roleColors ?? this.roleColors,
      pageBackground: pageBackground ?? this.pageBackground,
      panel: panel ?? this.panel,
      panelMuted: panelMuted ?? this.panelMuted,
      panelBorder: panelBorder ?? this.panelBorder,
      textMuted: textMuted ?? this.textMuted,
      focusRing: focusRing ?? this.focusRing,
    );
  }

  @override
  SchoolDeskTheme lerp(ThemeExtension<SchoolDeskTheme>? other, double t) {
    if (other is! SchoolDeskTheme) return this;
    return SchoolDeskTheme(
      isDark: t < 0.5 ? isDark : other.isDark,
      spacing: SchoolDeskSpacing.lerp(spacing, other.spacing, t),
      radius: SchoolDeskRadius.lerp(radius, other.radius, t),
      elevation: t < 0.5 ? elevation : other.elevation,
      motion: t < 0.5 ? motion : other.motion,
      roleColors: {
        for (final role in SchoolDeskRole.values)
          role: Color.lerp(roleColor(role), other.roleColor(role), t)!,
      },
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelMuted: Color.lerp(panelMuted, other.panelMuted, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
    );
  }
}

extension SchoolDeskThemeLookup on ThemeData {
  SchoolDeskTheme get schoolDesk {
    return extension<SchoolDeskTheme>() ??
        SchoolDeskTheme.fallback(isDark: brightness == Brightness.dark);
  }
}

double lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}

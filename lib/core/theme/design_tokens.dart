import 'package:flutter/material.dart';

enum SchoolDeskRole { principal, teacher, parent, student }

@immutable
class SchoolDeskSpacing {
  final double xs;
  final double sm;
  final double compact;
  final double md;
  final double relaxed;
  final double lg;
  final double xl;
  final double xxl;

  const SchoolDeskSpacing({
    required this.xs,
    required this.sm,
    required this.compact,
    required this.md,
    required this.relaxed,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  static const standard = SchoolDeskSpacing(
    xs: 4,
    sm: 8,
    compact: 12,
    md: 16,
    relaxed: 20,
    lg: 24,
    xl: 32,
    xxl: 32,
  );

  List<double> get scale => [xs, sm, compact, md, relaxed, lg, xl];

  static SchoolDeskSpacing lerp(
    SchoolDeskSpacing a,
    SchoolDeskSpacing b,
    double t,
  ) {
    return SchoolDeskSpacing(
      xs: lerpDouble(a.xs, b.xs, t),
      sm: lerpDouble(a.sm, b.sm, t),
      compact: lerpDouble(a.compact, b.compact, t),
      md: lerpDouble(a.md, b.md, t),
      relaxed: lerpDouble(a.relaxed, b.relaxed, t),
      lg: lerpDouble(a.lg, b.lg, t),
      xl: lerpDouble(a.xl, b.xl, t),
      xxl: lerpDouble(a.xxl, b.xxl, t),
    );
  }
}

@immutable
class SchoolDeskTypography {
  final double headingLarge;
  final double headingMedium;
  final double sectionTitle;
  final double cardTitle;
  final double body;
  final double caption;

  const SchoolDeskTypography({
    required this.headingLarge,
    required this.headingMedium,
    required this.sectionTitle,
    required this.cardTitle,
    required this.body,
    required this.caption,
  });

  static const standard = SchoolDeskTypography(
    headingLarge: 32,
    headingMedium: 26,
    sectionTitle: 20,
    cardTitle: 18,
    body: 15,
    caption: 13,
  );

  List<double> get scale => [
    headingLarge,
    headingMedium,
    sectionTitle,
    cardTitle,
    body,
    caption,
  ];

  static SchoolDeskTypography lerp(
    SchoolDeskTypography a,
    SchoolDeskTypography b,
    double t,
  ) {
    return SchoolDeskTypography(
      headingLarge: lerpDouble(a.headingLarge, b.headingLarge, t),
      headingMedium: lerpDouble(a.headingMedium, b.headingMedium, t),
      sectionTitle: lerpDouble(a.sectionTitle, b.sectionTitle, t),
      cardTitle: lerpDouble(a.cardTitle, b.cardTitle, t),
      body: lerpDouble(a.body, b.body, t),
      caption: lerpDouble(a.caption, b.caption, t),
    );
  }
}

@immutable
class SchoolDeskSizing {
  final double toolbarHeight;
  final double appBarHeight;
  final double buttonHeight;
  final double formFieldHeight;
  final double searchBarHeight;
  final double fabSize;
  final double iconContainer;
  final double compactIconContainer;
  final double bottomNavigationHeight;
  final double bottomSheetMaxWidth;
  final double contentMaxWidth;

  const SchoolDeskSizing({
    required this.toolbarHeight,
    required this.appBarHeight,
    required this.buttonHeight,
    required this.formFieldHeight,
    required this.searchBarHeight,
    required this.fabSize,
    required this.iconContainer,
    required this.compactIconContainer,
    required this.bottomNavigationHeight,
    required this.bottomSheetMaxWidth,
    required this.contentMaxWidth,
  });

  static const standard = SchoolDeskSizing(
    toolbarHeight: 64,
    appBarHeight: 64,
    buttonHeight: 48,
    formFieldHeight: 48,
    searchBarHeight: 48,
    fabSize: 56,
    iconContainer: 44,
    compactIconContainer: 40,
    bottomNavigationHeight: 72,
    bottomSheetMaxWidth: 720,
    contentMaxWidth: 1280,
  );

  static SchoolDeskSizing lerp(
    SchoolDeskSizing a,
    SchoolDeskSizing b,
    double t,
  ) {
    return SchoolDeskSizing(
      toolbarHeight: lerpDouble(a.toolbarHeight, b.toolbarHeight, t),
      appBarHeight: lerpDouble(a.appBarHeight, b.appBarHeight, t),
      buttonHeight: lerpDouble(a.buttonHeight, b.buttonHeight, t),
      formFieldHeight: lerpDouble(a.formFieldHeight, b.formFieldHeight, t),
      searchBarHeight: lerpDouble(a.searchBarHeight, b.searchBarHeight, t),
      fabSize: lerpDouble(a.fabSize, b.fabSize, t),
      iconContainer: lerpDouble(a.iconContainer, b.iconContainer, t),
      compactIconContainer: lerpDouble(
        a.compactIconContainer,
        b.compactIconContainer,
        t,
      ),
      bottomNavigationHeight: lerpDouble(
        a.bottomNavigationHeight,
        b.bottomNavigationHeight,
        t,
      ),
      bottomSheetMaxWidth: lerpDouble(
        a.bottomSheetMaxWidth,
        b.bottomSheetMaxWidth,
        t,
      ),
      contentMaxWidth: lerpDouble(a.contentMaxWidth, b.contentMaxWidth, t),
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
  final SchoolDeskTypography typography;
  final SchoolDeskSizing sizing;
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

  // Added semantic colors
  final Color primary;
  final Color primaryLight;
  final Color primaryContainer;
  final Color onPrimary;
  final Color secondary;
  final Color secondaryContainer;
  final Color onSecondary;
  final Color accent;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color error;
  final Color errorContainer;
  final Color info;
  final Color infoContainer;
  final Color surface;
  final Color surfaceVariant;
  final Color background;
  final Color outline;
  final Color outlineVariant;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color muted;

  Color get surface24 => surface.withOpacity(0.24);
  Color get surface60 => surface.withOpacity(0.60);
  Color get surface70 => surface.withOpacity(0.70);

  const SchoolDeskTheme({
    required this.isDark,
    required this.spacing,
    required this.typography,
    required this.sizing,
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
    required this.primary,
    required this.primaryLight,
    required this.primaryContainer,
    required this.onPrimary,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondary,
    required this.accent,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.error,
    required this.errorContainer,
    required this.info,
    required this.infoContainer,
    required this.surface,
    required this.surfaceVariant,
    required this.background,
    required this.outline,
    required this.outlineVariant,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.muted,
  });

  factory SchoolDeskTheme.fallback({required bool isDark}) {
    return SchoolDeskTheme(
      isDark: isDark,
      spacing: SchoolDeskSpacing.standard,
      typography: SchoolDeskTypography.standard,
      sizing: SchoolDeskSizing.standard,
      radius: SchoolDeskRadius.standard,
      elevation: isDark ? SchoolDeskElevation.dark : SchoolDeskElevation.light,
      motion: SchoolDeskMotion.standard,
      roleColors: const {
        SchoolDeskRole.principal: Color(0xFF2457D6),
        SchoolDeskRole.teacher: Color(0xFF7C3AED),
        SchoolDeskRole.parent: Color(0xFF1A6B4A),
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
      primary: isDark ? const Color(0xFF7EA2FF) : const Color(0xFF2457D6),
      primaryLight: const Color(0xFF7EA2FF),
      primaryContainer: isDark
          ? const Color(0xFF1A3A5C)
          : const Color(0xFFE6EDFF),
      onPrimary: const Color(0xFFFFFFFF),
      secondary: const Color(0xFF0E9384),
      secondaryContainer: isDark
          ? const Color(0xFF4A2E00)
          : const Color(0xFFDDFCF6),
      onSecondary: const Color(0xFFFFFFFF),
      accent: const Color(0xFF16A34A),
      success: const Color(0xFF15803D),
      successContainer: isDark
          ? const Color(0xFF14301B)
          : const Color(0xFFDCFCE7),
      warning: const Color(0xFFB45309),
      warningContainer: isDark
          ? const Color(0xFF4A2A04)
          : const Color(0xFFFEF3C7),
      error: const Color(0xFFE57373),
      errorContainer: isDark
          ? const Color(0xFF4A1515)
          : const Color(0xFFFEE4E2),
      info: const Color(0xFF2563EB),
      infoContainer: isDark ? const Color(0xFF1A2A4A) : const Color(0xFFE0EAFF),
      surface: isDark ? const Color(0xFF1E2530) : const Color(0xFFFFFFFF),
      surfaceVariant: isDark
          ? const Color(0xFF252D3A)
          : const Color(0xFFF6F8FB),
      background: isDark ? const Color(0xFF151C26) : const Color(0xFFF3F6FA),
      outline: isDark ? const Color(0xFF455A64) : const Color(0xFFCBD5E1),
      outlineVariant: isDark
          ? const Color(0xFF2D3748)
          : const Color(0xFFE2E8F0),
      onSurface: isDark ? const Color(0xFFE8EDF2) : const Color(0xFF101828),
      onSurfaceVariant: isDark
          ? const Color(0xFFB0BEC5)
          : const Color(0xFF475467),
      muted: isDark ? const Color(0xFF90A4AE) : const Color(0xFF667085),
    );
  }

  Color roleColor(SchoolDeskRole role) {
    return roleColors[role] ?? roleColors[SchoolDeskRole.principal]!;
  }

  @override
  SchoolDeskTheme copyWith({
    bool? isDark,
    SchoolDeskSpacing? spacing,
    SchoolDeskTypography? typography,
    SchoolDeskSizing? sizing,
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
    Color? primary,
    Color? primaryLight,
    Color? primaryContainer,
    Color? onPrimary,
    Color? secondary,
    Color? secondaryContainer,
    Color? onSecondary,
    Color? accent,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? error,
    Color? errorContainer,
    Color? info,
    Color? infoContainer,
    Color? surface,
    Color? surfaceVariant,
    Color? background,
    Color? outline,
    Color? outlineVariant,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? muted,
  }) {
    return SchoolDeskTheme(
      isDark: isDark ?? this.isDark,
      spacing: spacing ?? this.spacing,
      typography: typography ?? this.typography,
      sizing: sizing ?? this.sizing,
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
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondary: onSecondary ?? this.onSecondary,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      background: background ?? this.background,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      muted: muted ?? this.muted,
    );
  }

  @override
  SchoolDeskTheme lerp(ThemeExtension<SchoolDeskTheme>? other, double t) {
    if (other is! SchoolDeskTheme) return this;
    return SchoolDeskTheme(
      isDark: t < 0.5 ? isDark : other.isDark,
      spacing: SchoolDeskSpacing.lerp(spacing, other.spacing, t),
      typography: SchoolDeskTypography.lerp(typography, other.typography, t),
      sizing: SchoolDeskSizing.lerp(sizing, other.sizing, t),
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
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryContainer: Color.lerp(
        secondaryContainer,
        other.secondaryContainer,
        t,
      )!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      background: Color.lerp(background, other.background, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

extension SchoolDeskThemeLookup on ThemeData {
  SchoolDeskTheme get schoolDesk {
    return extension<SchoolDeskTheme>() ??
        SchoolDeskTheme.fallback(isDark: brightness == Brightness.dark);
  }
}

class SchoolDeskResponsive {
  SchoolDeskResponsive._();

  static const double maxSupportedTextScale = 1.3;

  static double effectiveTextScale(double textScale) {
    return textScale.clamp(1.0, maxSupportedTextScale).toDouble();
  }

  static double textScaleOf(BuildContext context) {
    return effectiveTextScale(MediaQuery.textScalerOf(context).scale(1));
  }

  static int gridColumnsForWidth(double width) {
    if (!width.isFinite || width <= 0) return 2;
    if (width < 280) return 1;
    if (width < 600) return 2;
    if (width < 840) return 3;
    if (width < 1180) return 4;
    return (width / 280).floor().clamp(4, 6);
  }

  static double contentHorizontalPaddingForWidth(
    double width,
    SchoolDeskSpacing spacing,
  ) {
    return width >= 600 ? spacing.relaxed : spacing.md;
  }

  static double bottomNavigationHeightForTextScale(
    SchoolDeskTheme tokens,
    double textScale,
  ) {
    final effectiveScale = effectiveTextScale(textScale);
    return (tokens.sizing.bottomNavigationHeight +
            ((effectiveScale - 1) * tokens.spacing.md))
        .clamp(
          tokens.sizing.bottomNavigationHeight,
          tokens.sizing.bottomNavigationHeight + tokens.spacing.sm,
        )
        .toDouble();
  }
}

double lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}

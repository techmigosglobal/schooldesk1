import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/widgets/custom_page_transition_builder.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

class AppTheme {
  // Arish Ville uniform palette: structured navy, clear academic blue,
  // optimistic school gold, and cool blue surfaces for long sessions.
  static const Color primary = Color(0xFF0E5EA8);
  static const Color primaryLight = Color(0xFF54A9E8);
  static const Color primaryContainer = Color(0xFFDCEFFF);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color secondary = Color(0xFF0B2F5B);
  static const Color secondaryContainer = Color(0xFFE7F1FA);
  static const Color onSecondary = Color(0xFFFFFFFF);

  static const Color accent = Color(0xFFF4C430);

  // Semantic colors
  static const Color success = Color(0xFF16A34A);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorContainer = Color(0xFFFEE4E2);
  static const Color info = Color(0xFF0284C7);
  static const Color infoContainer = Color(0xFFE0EAFF);

  // Surface system
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF7FF);
  static const Color background = Color(0xFFF8FBFE);
  static const Color outline = Color(0xFFC7DCEA);
  static const Color outlineVariant = Color(0xFFDCEAF4);

  // Text colors
  static const Color onSurface = Color(0xFF102A43);
  static const Color onSurfaceVariant = Color(0xFF334E68);
  static const Color muted = Color(0xFF627D98);

  static const SchoolDeskTheme _lightTokens = SchoolDeskTheme(
    isDark: false,
    spacing: SchoolDeskSpacing.standard,
    typography: SchoolDeskTypography.standard,
    sizing: SchoolDeskSizing.standard,
    radius: SchoolDeskRadius.standard,
    elevation: SchoolDeskElevation.light,
    motion: SchoolDeskMotion.standard,
    roleColors: {
      SchoolDeskRole.principal: Color(0xFF0E5EA8),
      SchoolDeskRole.coordinator: Color(0xFF0B2F5B),
      SchoolDeskRole.teacher: Color(0xFF2E7FC1),
      SchoolDeskRole.parent: Color(0xFF4A90C9),
      SchoolDeskRole.student: Color(0xFFC88700),
    },
    pageBackground: background,
    panel: surface,
    panelMuted: surfaceVariant,
    panelBorder: outlineVariant,
    textMuted: muted,
    focusRing: primary,
    primary: primary,
    primaryLight: primaryLight,
    primaryContainer: primaryContainer,
    onPrimary: onPrimary,
    secondary: secondary,
    secondaryContainer: secondaryContainer,
    onSecondary: onSecondary,
    accent: accent,
    success: success,
    successContainer: successContainer,
    warning: warning,
    warningContainer: warningContainer,
    error: error,
    errorContainer: errorContainer,
    info: info,
    infoContainer: infoContainer,
    surface: surface,
    surfaceVariant: surfaceVariant,
    background: background,
    outline: outline,
    outlineVariant: outlineVariant,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    muted: muted,
  );

  static const SchoolDeskTheme _darkTokens = SchoolDeskTheme(
    isDark: true,
    spacing: SchoolDeskSpacing.standard,
    typography: SchoolDeskTypography.standard,
    sizing: SchoolDeskSizing.standard,
    radius: SchoolDeskRadius.standard,
    elevation: SchoolDeskElevation.dark,
    motion: SchoolDeskMotion.standard,
    roleColors: {
      SchoolDeskRole.principal: Color(0xFF86C9F4),
      SchoolDeskRole.coordinator: Color(0xFFB8DCF5),
      SchoolDeskRole.teacher: Color(0xFF71B7E6),
      SchoolDeskRole.parent: Color(0xFFA2D4F5),
      SchoolDeskRole.student: Color(0xFFFFE27A),
    },
    pageBackground: Color(0xFF081F3C),
    panel: Color(0xFF0B294B),
    panelMuted: Color(0xFF12395F),
    panelBorder: Color(0xFF334E68),
    textMuted: Color(0xFFA8C2D8),
    focusRing: primaryLight,
    primary: primaryLight,
    primaryLight: Color(0xFF86C9F4),
    primaryContainer: Color(0xFF123E70),
    onPrimary: onPrimary,
    secondary: Color(0xFF86C9F4),
    secondaryContainer: Color(0xFF153A5E),
    onSecondary: onPrimary,
    accent: Color(0xFFFBBF24),
    success: Color(0xFF22C55E),
    successContainer: Color(0xFF14532D),
    warning: Color(0xFFFBBF24),
    warningContainer: Color(0xFF451A03),
    error: Color(0xFFF87171),
    errorContainer: Color(0xFF7F1D1D),
    info: Color(0xFF38BDF8),
    infoContainer: Color(0xFF0C4A6E),
    surface: Color(0xFF0B294B),
    surfaceVariant: Color(0xFF12395F),
    background: Color(0xFF081F3C),
    outline: Color(0xFF5B7792),
    outlineVariant: Color(0xFF334E68),
    onSurface: Color(0xFFF8FBFE),
    onSurfaceVariant: Color(0xFFC7DCEA),
    muted: Color(0xFFA8C2D8),
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    extensions: const <ThemeExtension<dynamic>>[_lightTokens],
    colorScheme: const ColorScheme.light(
      primary: primary,
      primaryContainer: primaryContainer,
      onPrimary: onPrimary,
      secondary: secondary,
      secondaryContainer: secondaryContainer,
      onSecondary: onSecondary,
      surface: surface,
      surfaceContainerHighest: surfaceVariant,
      error: error,
      errorContainer: errorContainer,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
    ),
    scaffoldBackgroundColor: background,
    textTheme: GoogleFonts.ibmPlexSansTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        displaySmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
        labelSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
      ),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 64,
      scrolledUnderElevation: 1,
      shadowColor: const Color(0x14081F3C),
      centerTitle: false,
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      iconTheme: const IconThemeData(color: onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: surfaceVariant,
      constraints: const BoxConstraints(minHeight: 48),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: outlineVariant, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: error, width: 2),
      ),
      labelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
      hintStyle: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      errorStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: error,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        disabledBackgroundColor: outlineVariant,
        disabledForegroundColor: muted,
        elevation: 0,
        shadowColor: const Color(0x1F0E5EA8),
        overlayColor: primaryLight.withAlpha(56),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        backgroundColor: surface,
        disabledForegroundColor: muted,
        side: const BorderSide(color: Color(0xFF93C5FD), width: 1.5),
        overlayColor: primaryContainer,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        disabledBackgroundColor: outlineVariant,
        disabledForegroundColor: muted,
        overlayColor: primaryLight.withAlpha(56),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceVariant,
      selectedColor: primaryContainer,
      side: const BorderSide(color: outlineVariant),
      labelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(
      color: outlineVariant,
      thickness: 1,
      space: 0,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minVerticalPadding: 8,
      iconColor: muted,
      textColor: onSurface,
      selectedColor: primary,
      selectedTileColor: primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      subtitleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Color(0x14000000),
      scrimColor: Color(0x47000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: const Color(0x1F000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(surfaceVariant),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryContainer;
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFF8FBFE);
        }
        return surface;
      }),
      dividerThickness: 1,
      columnSpacing: 28,
      horizontalMargin: 20,
      headingTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      dataTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: onSurfaceVariant,
      ),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) return primary;
        if (states.contains(WidgetState.hovered)) return muted;
        return outline;
      }),
      trackColor: WidgetStateProperty.all(surfaceVariant),
      thickness: WidgetStateProperty.all(8),
      radius: const Radius.circular(999),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: surface,
      indicatorColor: primaryContainer,
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0,
      indicatorColor: primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? primary : muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) ? primary : muted,
          size: 24,
        );
      }),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      labelColor: primary,
      unselectedLabelColor: muted,
      indicatorColor: primary,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size.square(44)),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return outline;
          return onSurfaceVariant;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return primaryContainer;
          if (states.contains(WidgetState.hovered)) return surfaceVariant;
          return Colors.transparent;
        }),
        overlayColor: WidgetStateProperty.all(primaryContainer),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 4,
      sizeConstraints: BoxConstraints.tightFor(width: 56, height: 56),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: outlineVariant,
      refreshBackgroundColor: surface,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: onSurface,
      contentTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      contentTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        color: onSurfaceVariant,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CustomPageTransitionBuilder(),
        TargetPlatform.iOS: CustomPageTransitionBuilder(),
        TargetPlatform.linux: CustomPageTransitionBuilder(),
        TargetPlatform.macOS: CustomPageTransitionBuilder(),
        TargetPlatform.windows: CustomPageTransitionBuilder(),
        TargetPlatform.fuchsia: CustomPageTransitionBuilder(),
      },
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    extensions: const <ThemeExtension<dynamic>>[_darkTokens],
    colorScheme: const ColorScheme.dark(
      primary: primaryLight,
      primaryContainer: Color(0xFF123E70),
      onPrimary: onPrimary,
      secondary: Color(0xFF86C9F4),
      secondaryContainer: Color(0xFF153A5E),
      onSecondary: onPrimary,
      surface: Color(0xFF0B294B),
      surfaceContainerHighest: Color(0xFF12395F),
      error: Color(0xFFF87171),
      errorContainer: Color(0xFF7F1D1D),
      onSurface: Color(0xFFF8FBFE),
      onSurfaceVariant: Color(0xFFC7DCEA),
      outline: Color(0xFF5B7792),
      outlineVariant: Color(0xFF334E68),
    ),
    scaffoldBackgroundColor: const Color(0xFF081F3C),
    textTheme: GoogleFonts.ibmPlexSansTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF8FBFE),
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF8FBFE),
        ),
        displaySmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF8FBFE),
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF8FBFE),
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF8FBFE),
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF8FBFE),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF8FBFE),
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFFF8FBFE),
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFFF8FBFE),
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Color(0xFFF8FBFE),
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Color(0xFFF8FBFE),
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFFA8C2D8),
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF8FBFE),
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFFF8FBFE),
        ),
        labelSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFFA8C2D8),
        ),
      ),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: const Color(0xFF0B294B),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 64,
      scrolledUnderElevation: 1,
      shadowColor: const Color(0x99000000),
      centerTitle: false,
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFF8FBFE),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFF8FBFE)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      color: const Color(0xFF0B294B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF334E68)),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: const Color(0xFF12395F),
      constraints: const BoxConstraints(minHeight: 48),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF334E68), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryLight, width: 2),
      ),
      labelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFA8C2D8),
      ),
      hintStyle: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: const Color(0xFFA8C2D8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: const Color(0xFF082F49),
        disabledBackgroundColor: const Color(0xFF334E68),
        disabledForegroundColor: const Color(0xFFA8C2D8),
        elevation: 0,
        overlayColor: const Color(0xFFDCEFFF).withAlpha(40),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: const Color(0xFF082F49),
        disabledBackgroundColor: const Color(0xFF334E68),
        disabledForegroundColor: const Color(0xFFA8C2D8),
        overlayColor: const Color(0xFFDCEFFF).withAlpha(40),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryLight,
        backgroundColor: const Color(0xFF0B294B),
        disabledForegroundColor: const Color(0xFF627D98),
        side: const BorderSide(color: primaryLight, width: 1.5),
        overlayColor: const Color(0xFF123E70),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF12395F),
      selectedColor: const Color(0xFF123E70),
      side: const BorderSide(color: Color(0xFF334E68)),
      labelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF334E68),
      thickness: 1,
      space: 0,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minVerticalPadding: 8,
      iconColor: const Color(0xFFB0BEC5),
      textColor: const Color(0xFFF8FBFE),
      selectedColor: primaryLight,
      selectedTileColor: const Color(0xFF123E70),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFF8FBFE),
      ),
      subtitleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: const Color(0xFFC7DCEA),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xFF0B294B),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Color(0x99000000),
      scrimColor: Color(0x99000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xFF0B294B),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: const Color(0x99000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFF8FBFE),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(const Color(0xFF12395F)),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF123E70);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFF172033);
        }
        return const Color(0xFF0B294B);
      }),
      dividerThickness: 1,
      columnSpacing: 28,
      horizontalMargin: 20,
      headingTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFF8FBFE),
      ),
      dataTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFC7DCEA),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0B294B),
        border: Border.all(color: const Color(0xFF334E68)),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) return primaryLight;
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFB0BEC5);
        }
        return const Color(0xFF5B7792);
      }),
      trackColor: WidgetStateProperty.all(const Color(0xFF12395F)),
      thickness: WidgetStateProperty.all(8),
      radius: const Radius.circular(999),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: const Color(0xFF0B294B),
      indicatorColor: const Color(0xFF123E70),
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFFF8FBFE),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0B294B),
      elevation: 0,
      indicatorColor: const Color(0xFF123E70),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? primaryLight : const Color(0xFFA8C2D8),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? primaryLight
              : const Color(0xFFA8C2D8),
          size: 24,
        );
      }),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      labelColor: primaryLight,
      unselectedLabelColor: const Color(0xFFA8C2D8),
      indicatorColor: primaryLight,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size.square(44)),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF5B7792);
          }
          return const Color(0xFFC7DCEA);
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return const Color(0xFF123E70);
          }
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFF12395F);
          }
          return Colors.transparent;
        }),
        overlayColor: WidgetStateProperty.all(const Color(0xFF123E70)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryLight,
      foregroundColor: Color(0xFF082F49),
      elevation: 4,
      sizeConstraints: BoxConstraints.tightFor(width: 56, height: 56),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryLight,
      linearTrackColor: Color(0xFF334E68),
      refreshBackgroundColor: Color(0xFF0B294B),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF12395F),
      contentTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF0B294B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFF8FBFE),
      ),
      contentTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        color: const Color(0xFFC7DCEA),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF0B294B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CustomPageTransitionBuilder(),
        TargetPlatform.iOS: CustomPageTransitionBuilder(),
        TargetPlatform.linux: CustomPageTransitionBuilder(),
        TargetPlatform.macOS: CustomPageTransitionBuilder(),
        TargetPlatform.windows: CustomPageTransitionBuilder(),
        TargetPlatform.fuchsia: CustomPageTransitionBuilder(),
      },
    ),
  );
}

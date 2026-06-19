import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/widgets/custom_page_transition_builder.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

class AppTheme {
  // SchoolDesk trust palette: calm blue leadership, warm teal support,
  // and soft slate surfaces for long operational sessions.
  static const Color primary = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryContainer = Color(0xFFDBEAFE);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color secondary = Color(0xFF0F766E);
  static const Color secondaryContainer = Color(0xFFCCFBF1);
  static const Color onSecondary = Color(0xFFFFFFFF);

  static const Color accent = Color(0xFFD97706);

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
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color background = Color(0xFFF8FAFC);
  static const Color outline = Color(0xFFCBD5E1);
  static const Color outlineVariant = Color(0xFFE2E8F0);

  // Text colors
  static const Color onSurface = Color(0xFF0F172A);
  static const Color onSurfaceVariant = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);

  static const SchoolDeskTheme _lightTokens = SchoolDeskTheme(
    isDark: false,
    spacing: SchoolDeskSpacing.standard,
    typography: SchoolDeskTypography.standard,
    sizing: SchoolDeskSizing.standard,
    radius: SchoolDeskRadius.standard,
    elevation: SchoolDeskElevation.light,
    motion: SchoolDeskMotion.standard,
    roleColors: {
      SchoolDeskRole.principal: Color(0xFF1D4ED8),
      SchoolDeskRole.teacher: Color(0xFF7C3AED),
      SchoolDeskRole.parent: Color(0xFF0F766E),
      SchoolDeskRole.student: Color(0xFFEA580C),
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
      SchoolDeskRole.principal: Color(0xFF93C5FD),
      SchoolDeskRole.teacher: Color(0xFFC4B5FD),
      SchoolDeskRole.parent: Color(0xFF5EEAD4),
      SchoolDeskRole.student: Color(0xFFFDBA74),
    },
    pageBackground: Color(0xFF0F172A),
    panel: Color(0xFF111827),
    panelMuted: Color(0xFF1E293B),
    panelBorder: Color(0xFF334155),
    textMuted: Color(0xFF94A3B8),
    focusRing: primaryLight,
    primary: primaryLight,
    primaryLight: Color(0xFF93C5FD),
    primaryContainer: Color(0xFF1E3A8A),
    onPrimary: onPrimary,
    secondary: Color(0xFF5EEAD4),
    secondaryContainer: Color(0xFF134E4A),
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
    surface: Color(0xFF111827),
    surfaceVariant: Color(0xFF1E293B),
    background: Color(0xFF0F172A),
    outline: Color(0xFF475569),
    outlineVariant: Color(0xFF334155),
    onSurface: Color(0xFFF8FAFC),
    onSurfaceVariant: Color(0xFFCBD5E1),
    muted: Color(0xFF94A3B8),
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
      shadowColor: const Color(0x140F172A),
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
        shadowColor: const Color(0x1F1D4ED8),
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
          return const Color(0xFFF8FAFC);
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
      primaryContainer: Color(0xFF1E3A8A),
      onPrimary: onPrimary,
      secondary: Color(0xFF5EEAD4),
      secondaryContainer: Color(0xFF134E4A),
      onSecondary: onPrimary,
      surface: Color(0xFF111827),
      surfaceContainerHighest: Color(0xFF1E293B),
      error: Color(0xFFF87171),
      errorContainer: Color(0xFF7F1D1D),
      onSurface: Color(0xFFF8FAFC),
      onSurfaceVariant: Color(0xFFCBD5E1),
      outline: Color(0xFF475569),
      outlineVariant: Color(0xFF334155),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    textTheme: GoogleFonts.ibmPlexSansTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF8FAFC),
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF8FAFC),
        ),
        displaySmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF8FAFC),
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF8FAFC),
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF8FAFC),
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF8FAFC),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF8FAFC),
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFFF8FAFC),
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFFF8FAFC),
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Color(0xFFF8FAFC),
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Color(0xFFF8FAFC),
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFF94A3B8),
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF8FAFC),
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFFF8FAFC),
        ),
        labelSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF94A3B8),
        ),
      ),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: const Color(0xFF111827),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 64,
      scrolledUnderElevation: 1,
      shadowColor: const Color(0x99000000),
      centerTitle: false,
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFF8FAFC),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFF8FAFC)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      color: const Color(0xFF111827),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: const Color(0xFF1E293B),
      constraints: const BoxConstraints(minHeight: 48),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryLight, width: 2),
      ),
      labelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF94A3B8),
      ),
      hintStyle: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Color(0xFF94A3B8),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: const Color(0xFF082F49),
        disabledBackgroundColor: const Color(0xFF334155),
        disabledForegroundColor: const Color(0xFF94A3B8),
        elevation: 0,
        overlayColor: const Color(0xFFDBEAFE).withAlpha(40),
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
        disabledBackgroundColor: const Color(0xFF334155),
        disabledForegroundColor: const Color(0xFF94A3B8),
        overlayColor: const Color(0xFFDBEAFE).withAlpha(40),
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
        backgroundColor: const Color(0xFF111827),
        disabledForegroundColor: const Color(0xFF64748B),
        side: const BorderSide(color: primaryLight, width: 1.5),
        overlayColor: const Color(0xFF1E3A8A),
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
      backgroundColor: const Color(0xFF1E293B),
      selectedColor: const Color(0xFF1E3A8A),
      side: const BorderSide(color: Color(0xFF334155)),
      labelStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF334155),
      thickness: 1,
      space: 0,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minVerticalPadding: 8,
      iconColor: const Color(0xFFB0BEC5),
      textColor: const Color(0xFFF8FAFC),
      selectedColor: primaryLight,
      selectedTileColor: const Color(0xFF1E3A8A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFF8FAFC),
      ),
      subtitleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: const Color(0xFFCBD5E1),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xFF111827),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Color(0x99000000),
      scrimColor: Color(0x99000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xFF111827),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: const Color(0x99000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFF8FAFC),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF1E3A8A);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFF172033);
        }
        return const Color(0xFF111827);
      }),
      dividerThickness: 1,
      columnSpacing: 28,
      horizontalMargin: 20,
      headingTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFF8FAFC),
      ),
      dataTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFCBD5E1),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) return primaryLight;
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFB0BEC5);
        }
        return const Color(0xFF475569);
      }),
      trackColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
      thickness: WidgetStateProperty.all(8),
      radius: const Radius.circular(999),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: const Color(0xFF111827),
      indicatorColor: const Color(0xFF1E3A8A),
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFFF8FAFC),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF111827),
      elevation: 0,
      indicatorColor: const Color(0xFF1E3A8A),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? primaryLight : const Color(0xFF94A3B8),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? primaryLight
              : const Color(0xFF94A3B8),
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
      unselectedLabelColor: const Color(0xFF94A3B8),
      indicatorColor: primaryLight,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size.square(44)),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF475569);
          }
          return const Color(0xFFCBD5E1);
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return const Color(0xFF1E3A8A);
          }
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFF1E293B);
          }
          return Colors.transparent;
        }),
        overlayColor: WidgetStateProperty.all(const Color(0xFF1E3A8A)),
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
      linearTrackColor: Color(0xFF334155),
      refreshBackgroundColor: Color(0xFF111827),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1E293B),
      contentTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFF8FAFC),
      ),
      contentTextStyle: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        color: const Color(0xFFCBD5E1),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF111827),
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

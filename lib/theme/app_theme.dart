import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/custom_page_transition_builder.dart';
import 'design_tokens.dart';

class AppTheme {
  // Operational SaaS palette: calm, readable, and role-neutral by default.
  static const Color primary = Color(0xFF2457D6);
  static const Color primaryLight = Color(0xFF7EA2FF);
  static const Color primaryContainer = Color(0xFFE6EDFF);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary keeps school warmth without overpowering operational screens.
  static const Color secondary = Color(0xFF0E9384);
  static const Color secondaryContainer = Color(0xFFDDFCF6);
  static const Color onSecondary = Color(0xFFFFFFFF);

  static const Color accent = Color(0xFF16A34A);

  // Semantic colors
  static const Color success = Color(0xFF15803D);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFB45309);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFB42318);
  static const Color errorContainer = Color(0xFFFEE4E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoContainer = Color(0xFFE0EAFF);

  // Surface system
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF6F8FB);
  static const Color background = Color(0xFFF3F6FA);
  static const Color outline = Color(0xFFCBD5E1);
  static const Color outlineVariant = Color(0xFFE2E8F0);

  // Text colors
  static const Color onSurface = Color(0xFF101828);
  static const Color onSurfaceVariant = Color(0xFF475467);
  static const Color muted = Color(0xFF667085);

  static const SchoolDeskTheme _lightTokens = SchoolDeskTheme(
    isDark: false,
    spacing: SchoolDeskSpacing.standard,
    radius: SchoolDeskRadius.standard,
    elevation: SchoolDeskElevation.light,
    motion: SchoolDeskMotion.standard,
    roleColors: {
      SchoolDeskRole.principal: Color(0xFF2457D6),
      SchoolDeskRole.admin: Color(0xFF0E9384),
      SchoolDeskRole.teacher: Color(0xFF7C3AED),
      SchoolDeskRole.parent: Color(0xFF16A34A),
      SchoolDeskRole.student: Color(0xFFEA580C),
    },
    pageBackground: background,
    panel: surface,
    panelMuted: surfaceVariant,
    panelBorder: outlineVariant,
    textMuted: muted,
    focusRing: primary,
  );

  static const SchoolDeskTheme _darkTokens = SchoolDeskTheme(
    isDark: true,
    spacing: SchoolDeskSpacing.standard,
    radius: SchoolDeskRadius.standard,
    elevation: SchoolDeskElevation.dark,
    motion: SchoolDeskMotion.standard,
    roleColors: {
      SchoolDeskRole.principal: Color(0xFF8EA8FF),
      SchoolDeskRole.admin: Color(0xFF5EEAD4),
      SchoolDeskRole.teacher: Color(0xFFC4B5FD),
      SchoolDeskRole.parent: Color(0xFF86EFAC),
      SchoolDeskRole.student: Color(0xFFFDBA74),
    },
    pageBackground: Color(0xFF0B1120),
    panel: Color(0xFF111827),
    panelMuted: Color(0xFF1F2937),
    panelBorder: Color(0xFF334155),
    textMuted: Color(0xFFCBD5E1),
    focusRing: primaryLight,
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
    textTheme: GoogleFonts.interTextTheme(
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
          fontSize: 22,
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
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
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
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
      ),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      iconTheme: const IconThemeData(color: onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      errorStyle: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: error,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceVariant,
      selectedColor: primaryContainer,
      labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(
      color: outlineVariant,
      thickness: 1,
      space: 0,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      minVerticalPadding: 10,
      iconColor: muted,
      textColor: onSurface,
      selectedColor: primary,
      selectedTileColor: primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      subtitleTextStyle: GoogleFonts.inter(
        fontSize: 12,
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
      textStyle: GoogleFonts.inter(
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
          return const Color(0xFFFAFBFD);
        }
        return surface;
      }),
      dividerThickness: 1,
      columnSpacing: 28,
      horizontalMargin: 20,
      headingTextStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      dataTextStyle: GoogleFonts.inter(
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
        GoogleFonts.inter(
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
        return GoogleFonts.inter(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? primary : muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) ? primary : muted,
          size: 22,
        );
      }),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(
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
        minimumSize: WidgetStateProperty.all(const Size.square(40)),
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
      contentTextStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
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
      primaryContainer: Color(0xFF1A3A5C),
      onPrimary: onPrimary,
      secondary: secondary,
      secondaryContainer: Color(0xFF4A2E00),
      onSecondary: onPrimary,
      surface: Color(0xFF1E2530),
      surfaceContainerHighest: Color(0xFF252D3A),
      error: Color(0xFFE57373),
      errorContainer: Color(0xFF4A1515),
      onSurface: Color(0xFFE8EDF2),
      onSurfaceVariant: Color(0xFFB0BEC5),
      outline: Color(0xFF455A64),
      outlineVariant: Color(0xFF2D3748),
    ),
    scaffoldBackgroundColor: const Color(0xFF151C26),
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Color(0xFFE8EDF2),
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Color(0xFFE8EDF2),
        ),
        displaySmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Color(0xFFE8EDF2),
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE8EDF2),
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE8EDF2),
        ),
        headlineSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE8EDF2),
        ),
        titleLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE8EDF2),
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFFE8EDF2),
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFFE8EDF2),
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Color(0xFFE8EDF2),
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFFE8EDF2),
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF90A4AE),
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE8EDF2),
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFFE8EDF2),
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF90A4AE),
        ),
      ),
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: const Color(0xFF1E2530),
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFE8EDF2),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFE8EDF2)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1E2530),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: const Color(0xFF252D3A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2D3748), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryLight, width: 2),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Color(0xFF90A4AE),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF90A4AE),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryLight,
        side: const BorderSide(color: primaryLight, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF252D3A),
      selectedColor: const Color(0xFF1A3A5C),
      labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2D3748),
      thickness: 1,
      space: 0,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      minVerticalPadding: 10,
      iconColor: const Color(0xFFB0BEC5),
      textColor: const Color(0xFFE8EDF2),
      selectedColor: primaryLight,
      selectedTileColor: const Color(0xFF1A3A5C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFE8EDF2),
      ),
      subtitleTextStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: const Color(0xFFB0BEC5),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xFF1E2530),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Color(0x99000000),
      scrimColor: Color(0x99000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xFF1E2530),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: const Color(0x99000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFE8EDF2),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(const Color(0xFF252D3A)),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF1A3A5C);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFF202938);
        }
        return const Color(0xFF1E2530);
      }),
      dividerThickness: 1,
      columnSpacing: 28,
      horizontalMargin: 20,
      headingTextStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFE8EDF2),
      ),
      dataTextStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: const Color(0xFFB0BEC5),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2530),
        border: Border.all(color: const Color(0xFF2D3748)),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) return primaryLight;
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFB0BEC5);
        }
        return const Color(0xFF455A64);
      }),
      trackColor: WidgetStateProperty.all(const Color(0xFF252D3A)),
      thickness: WidgetStateProperty.all(8),
      radius: const Radius.circular(999),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: const Color(0xFF1E2530),
      indicatorColor: const Color(0xFF1A3A5C),
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFFE8EDF2),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1E2530),
      elevation: 0,
      indicatorColor: const Color(0xFF1A3A5C),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? primaryLight : const Color(0xFFB0BEC5),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? primaryLight
              : const Color(0xFFB0BEC5),
          size: 22,
        );
      }),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      labelColor: primaryLight,
      unselectedLabelColor: const Color(0xFFB0BEC5),
      indicatorColor: primaryLight,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size.square(40)),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF455A64);
          }
          return const Color(0xFFB0BEC5);
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return const Color(0xFF1A3A5C);
          }
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFF252D3A);
          }
          return Colors.transparent;
        }),
        overlayColor: WidgetStateProperty.all(const Color(0xFF1A3A5C)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryLight,
      foregroundColor: onPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryLight,
      linearTrackColor: Color(0xFF2D3748),
      refreshBackgroundColor: Color(0xFF1E2530),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF252D3A),
      contentTextStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF1E2530),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFE8EDF2),
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        color: const Color(0xFFB0BEC5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1E2530),
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

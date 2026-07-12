/// Desktop-specific layout breakpoints for progressive enhancement.
abstract final class DesktopBreakpoints {
  /// Minimum width to treat layout as desktop (persistent sidebar, multi-column).
  static const double desktop = 1200;

  /// Comfortable wide layout with extra columns and spacing.
  static const double wide = 1440;

  /// Ultra-wide monitors — max content width with side gutters.
  static const double ultraWide = 1920;

  /// Sidebar width when expanded.
  static const double sidebarExpanded = 280;

  /// Sidebar width when collapsed to icons only.
  static const double sidebarCollapsed = 72;

  /// Master panel in master-detail layouts.
  static const double masterPanelMin = 320;
  static const double masterPanelMax = 420;

  /// Default minimum window size.
  static const double minWindowWidth = 1024;
  static const double minWindowHeight = 640;

  /// Default initial window size.
  static const double defaultWindowWidth = 1280;
  static const double defaultWindowHeight = 800;

  static bool isDesktopWidth(double width) => width >= desktop;
  static bool isWideWidth(double width) => width >= wide;
  static bool isUltraWideWidth(double width) => width >= ultraWide;

  static int gridColumnsForWidth(double width) {
    if (width >= ultraWide) return 6;
    if (width >= wide) return 5;
    if (width >= desktop) return 4;
    if (width >= 840) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  static double contentMaxWidth(double width) {
    if (width >= ultraWide) return 1680;
    if (width >= wide) return 1440;
    if (width >= desktop) return 1280;
    return width;
  }
}

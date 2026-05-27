import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_components.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/teacher_navigation.dart';

class TeacherMyAttendanceScreen extends StatefulWidget {
  const TeacherMyAttendanceScreen({super.key});

  @override
  State<TeacherMyAttendanceScreen> createState() =>
      _TeacherMyAttendanceScreenState();
}

class _TeacherMyAttendanceScreenState extends State<TeacherMyAttendanceScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  StaffAttendanceModel? _attendance;
  bool _loading = true;
  bool _scannerOpen = false;
  bool _submitting = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _loadToday() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final attendance = await BackendApiClient.instance
          .getMyStaffAttendanceToday();
      if (!mounted) return;
      setState(() {
        _attendance = attendance;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openScanner() async {
    setState(() {
      _scannerOpen = true;
      _error = null;
      _success = null;
    });
  }

  Future<void> _closeScanner() async {
    await _scannerController.stop();
    if (!mounted) return;
    setState(() => _scannerOpen = false);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_submitting) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      unawaited(_submitToken(raw));
      return;
    }
  }

  Future<void> _submitToken(String token) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });
    try {
      await _scannerController.stop();
      final attendance = await BackendApiClient.instance.scanStaffQr(token);
      if (!mounted) return;
      setState(() {
        _attendance = attendance;
        _scannerOpen = false;
        _success = attendance.checkedIn
            ? 'Checked in at ${attendance.checkInTimeLabel}'
            : 'Attendance recorded';
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _scannerOpen = false;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'My Attendance',
      subtitle: 'QR check-in',
      drawer: TeacherDrawer(selectedIndex: 14, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.teacher,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          tooltip: 'Refresh status',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadToday,
        ),
      ],
      mobileBottomActions: const [
        SchoolDeskModuleBottomAction(
          label: 'Home',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          route: AppRoutes.teacherDashboard,
        ),
        SchoolDeskModuleBottomAction(
          label: 'Scan',
          icon: Icons.qr_code_scanner_outlined,
          activeIcon: Icons.qr_code_scanner_rounded,
          route: AppRoutes.teacherMyAttendance,
        ),
        SchoolDeskModuleBottomAction(
          label: 'Classes',
          icon: Icons.class_outlined,
          activeIcon: Icons.class_rounded,
          route: AppRoutes.teacherClasses,
        ),
        SchoolDeskModuleBottomAction(
          label: 'Students',
          icon: Icons.how_to_reg_outlined,
          activeIcon: Icons.how_to_reg_rounded,
          route: AppRoutes.teacherAttendance,
        ),
        SchoolDeskModuleBottomAction(
          label: 'More',
          icon: Icons.menu_rounded,
          activeIcon: Icons.menu_open_rounded,
          route: SchoolDeskModuleScaffold.openNavigationAction,
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _loadToday,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_loading)
              const SchoolDeskStatusPanel.loading(message: 'Loading check-in')
            else ...[
              _StatusHero(attendance: _attendance, onScan: _openScanner),
              const SizedBox(height: 16),
              if (_scannerOpen)
                _ScannerPanel(
                  controller: _scannerController,
                  submitting: _submitting,
                  onDetect: _onDetect,
                  onClose: _closeScanner,
                ),
              if (_scannerOpen) const SizedBox(height: 16),
              _ActionGrid(
                checkedIn: _attendance?.checkedIn == true,
                onScan: _openScanner,
              ),
              const SizedBox(height: 16),
              _MessageStrip(
                error: _error,
                success: _success,
                onRetry: _openScanner,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  final StaffAttendanceModel? attendance;
  final VoidCallback onScan;

  const _StatusHero({required this.attendance, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final checked = attendance?.checkedIn == true;
    final color = checked ? const Color(0xFF16A34A) : const Color(0xFFD97706);
    final icon = checked
        ? Icons.check_circle_rounded
        : Icons.qr_code_scanner_rounded;
    final time = checked ? attendance!.checkInTimeLabel : '--:--';

    return Semantics(
      label: checked
          ? 'Teacher attendance checked in at $time'
          : 'Teacher attendance pending',
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 190),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tokens.panel,
          borderRadius: BorderRadius.circular(tokens.radius.card),
          border: Border.all(color: tokens.panelBorder),
          boxShadow: tokens.elevation.card,
        ),
        child: Row(
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(tokens.radius.card),
              ),
              child: Icon(icon, color: color, size: 46),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    checked ? 'Checked in' : 'Pending',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onScan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(checked ? 'Scan again' : 'Scan QR'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerPanel extends StatelessWidget {
  final MobileScannerController controller;
  final bool submitting;
  final void Function(BarcodeCapture capture) onDetect;
  final VoidCallback onClose;

  const _ScannerPanel({
    required this.controller,
    required this.submitting,
    required this.onDetect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Semantics(
      label: 'QR scanner camera',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.panel,
          borderRadius: BorderRadius.circular(tokens.radius.card),
          border: Border.all(color: tokens.panelBorder),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.center_focus_strong_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scan QR',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Close scanner',
                  child: IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radius.card),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: controller,
                      fit: BoxFit.cover,
                      onDetect: onDetect,
                    ),
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                    if (submitting)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final bool checkedIn;
  final VoidCallback onScan;

  const _ActionGrid({required this.checkedIn, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _TileAction(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Scan QR',
        color: const Color(0xFF2563EB),
        onTap: onScan,
      ),
      _TileAction(
        icon: Icons.check_circle_rounded,
        label: checkedIn ? 'Done' : 'Pending',
        color: checkedIn ? const Color(0xFF16A34A) : const Color(0xFFD97706),
        onTap: onScan,
      ),
      _TileAction(
        icon: Icons.history_rounded,
        label: 'Students',
        color: const Color(0xFF0E9384),
        onTap: () => Navigator.pushNamed(context, AppRoutes.teacherAttendance),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: columns == 3 ? 1.35 : 1.08,
          ),
          itemBuilder: (context, index) => _IconTile(action: actions[index]),
        );
      },
    );
  }
}

class _IconTile extends StatelessWidget {
  final _TileAction action;

  const _IconTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Semantics(
      button: true,
      label: action.label,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(tokens.radius.card),
        child: Ink(
          decoration: BoxDecoration(
            color: action.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(tokens.radius.card),
            border: Border.all(color: action.color.withValues(alpha: 0.24)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action.icon, color: action.color, size: 42),
                const SizedBox(height: 10),
                Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: action.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageStrip extends StatelessWidget {
  final String? error;
  final String? success;
  final VoidCallback onRetry;

  const _MessageStrip({
    required this.error,
    required this.success,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final hasError = error != null;
    final text = hasError ? error! : success;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final color = hasError ? theme.colorScheme.error : const Color(0xFF16A34A);
    return Semantics(
      liveRegion: true,
      label: text,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(tokens.radius.control),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(
              hasError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasError ? 'Scan failed' : text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (hasError)
              IconButton(
                tooltip: 'Retry scan',
                onPressed: onRetry,
                icon: Icon(Icons.refresh_rounded, color: color),
              ),
          ],
        ),
      ),
    );
  }
}

class _TileAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TileAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

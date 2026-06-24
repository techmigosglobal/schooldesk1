import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/share_export_service.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class StaffQrAttendancePanel extends StatefulWidget {
  final bool compact;

  const StaffQrAttendancePanel({super.key, this.compact = false});

  @override
  State<StaffQrAttendancePanel> createState() => _StaffQrAttendancePanelState();
}

class _StaffQrAttendancePanelState extends State<StaffQrAttendancePanel> {
  static const int _qrRefreshSeconds = 7;
  static const Duration _qrRefreshInterval = Duration(
    seconds: _qrRefreshSeconds,
  );

  StaffQrTokenModel? _token;
  List<StaffAttendanceModel> _recent = const [];
  Timer? _ticker;
  Timer? _qrRefreshTimer;
  Timer? _pollingTimer;
  DateTime? _nextQrRefreshAt;
  bool _loading = true;
  bool _refreshing = false;
  bool _exportingLog = false;
  String? _error;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollRecentScans(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _qrRefreshTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (_refreshing) return;
    _qrRefreshTimer?.cancel();
    setState(() {
      _refreshing = true;
      if (!quiet) _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final token = await api.getStaffQrToken(nonce: _qrRefreshNonce());
      if (!mounted) return;
      setState(() {
        _token = token;
        _nextQrRefreshAt = DateTime.now().add(_qrRefreshInterval);
        _secondsLeft = _qrRefreshSeconds;
        _loading = false;
        _refreshing = false;
      });
      _startLiveTicker();
      unawaited(_loadRecentScans());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _nextQrRefreshAt = DateTime.now().add(_qrRefreshInterval);
        _secondsLeft = _qrRefreshSeconds;
        _loading = false;
        _refreshing = false;
      });
    } finally {
      if (mounted) _scheduleQrRefresh();
    }
  }

  Future<void> _loadRecentScans() async {
    try {
      final rows = await BackendApiClient.instance.getStaffAttendanceForDate();
      if (!mounted) return;
      setState(() => _recent = rows);
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Staff QR polling failed: $error',
          name: 'StaffQrAttendancePanel',
        );
      }
      if (!mounted) return;
      setState(() => _recent = const []);
    }
  }

  Future<void> _pollRecentScans() async {
    if (_refreshing || _loading) return;
    try {
      final rows = await BackendApiClient.instance.getStaffAttendanceForDate();
      if (!mounted) return;
      setState(() => _recent = rows);
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Staff QR poll scan check failed: $error',
          name: 'StaffQrAttendancePanel',
        );
      }
    }
  }

  Future<void> _refreshQrCode() async {
    await _load(quiet: true);
  }

  void _scheduleQrRefresh() {
    _qrRefreshTimer?.cancel();
    _qrRefreshTimer = Timer(
      _qrRefreshInterval,
      () => unawaited(_refreshQrCode()),
    );
  }

  String _qrRefreshNonce() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _exportDailyQrLog() async {
    if (_exportingLog) return;
    setState(() => _exportingLog = true);
    final date = _todayDateText();
    try {
      final bytes = await BackendApiClient.instance.exportStaffQrLogsCsv(
        date: date,
      );
      final fileName = 'staff_qr_logs_$date.csv';
      await const ShareExportService().shareBytes(
        bytes: Uint8List.fromList(bytes),
        fileName: fileName,
        mimeType: 'text/csv',
        title: 'Staff QR logs',
        subject: 'Staff QR logs for $date',
        text: 'Daily staff QR attendance log exported from Arish Ville.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Staff QR log exported for $date'),
          backgroundColor: Theme.of(context).schoolDesk.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Staff QR log export failed: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingLog = false);
    }
  }

  String _todayDateText() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  void _startLiveTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final nextRefreshAt = _nextQrRefreshAt;
      if (nextRefreshAt == null) return;
      final next = nextRefreshAt.difference(DateTime.now()).inSeconds + 1;
      final clamped = next < 0 ? 0 : next;
      setState(() => _secondsLeft = clamped);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final presentCount = _recent
        .where((row) => row.checkedIn && row.status.toLowerCase() == 'present')
        .length;

    return Semantics(
      label: 'Staff QR attendance panel',
      container: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(widget.compact ? 16 : 20),
        decoration: BoxDecoration(
          color: tokens.panel,
          borderRadius: BorderRadius.circular(tokens.radius.card),
          border: Border.all(color: tokens.panelBorder),
          boxShadow: tokens.elevation.card,
        ),
        child: _loading && _token == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720 && !widget.compact;
                  final qr = _QrBlock(
                    token: _token,
                    secondsLeft: _secondsLeft,
                    refreshing: _refreshing,
                    error: _error,
                    compact: widget.compact,
                    onRefresh: () => _load(),
                    exportingLog: _exportingLog,
                    onExport: _exportDailyQrLog,
                  );
                  final status = _StaffQrStatusBlock(
                    presentCount: presentCount,
                    recent: _recent.take(5).toList(),
                  );
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [qr, const SizedBox(height: 16), status],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: qr),
                      const SizedBox(width: 20),
                      Expanded(flex: 5, child: status),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _QrBlock extends StatelessWidget {
  final StaffQrTokenModel? token;
  final int secondsLeft;
  final bool refreshing;
  final bool exportingLog;
  final String? error;
  final bool compact;
  final VoidCallback onRefresh;
  final VoidCallback onExport;

  const _QrBlock({
    required this.token,
    required this.secondsLeft,
    required this.refreshing,
    required this.exportingLog,
    required this.error,
    required this.compact,
    required this.onRefresh,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    final color = secondsLeft <= 10
        ? theme.colorScheme.error
        : secondsLeft <= 25
        ? const Color(0xFFD97706)
        : const Color(0xFF16A34A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Staff QR',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Tooltip(
              message: 'Export daily QR log',
              child: IconButton.filledTonal(
                onPressed: exportingLog ? null : onExport,
                icon: exportingLog
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
              ),
            ),
            Tooltip(
              message: 'Refresh QR',
              child: IconButton.filledTonal(
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Semantics(
          label: 'Dynamic staff attendance QR code',
          image: true,
          child: Container(
            width: compact ? 190 : 260,
            height: compact ? 190 : 260,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appTheme.surface,
              borderRadius: BorderRadius.circular(tokens.radius.card),
              border: Border.all(color: tokens.panelBorder),
            ),
            child: token == null || token!.token.isEmpty
                ? Icon(
                    Icons.qr_code_2_rounded,
                    size: 96,
                    color: tokens.textMuted,
                  )
                : QrImageView(
                    key: ValueKey(token!.token),
                    data: token!.token,
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    backgroundColor: context.appTheme.surface,
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          label: 'QR refresh countdown $secondsLeft seconds',
          liveRegion: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(tokens.radius.control),
              border: Border.all(color: color.withValues(alpha: 0.24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, color: color),
                    const SizedBox(width: 8),
                    Text(
                      '${secondsLeft}s',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'QR refreshes every 7 seconds',
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _StatusStrip(
            color: theme.colorScheme.error,
            icon: Icons.error_outline_rounded,
            text: 'QR unavailable',
          ),
        ],
      ],
    );
  }
}

class _StaffQrStatusBlock extends StatelessWidget {
  final int presentCount;
  final List<StaffAttendanceModel> recent;

  const _StaffQrStatusBlock({required this.presentCount, required this.recent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.verified_rounded,
                label: 'Present',
                value: '$presentCount',
                color: const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                icon: Icons.history_rounded,
                label: 'Recent',
                value: '${recent.length}',
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Recent scans',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          _StatusStrip(
            color: tokens.textMuted,
            icon: Icons.qr_code_scanner_rounded,
            text: 'No scans yet',
          )
        else
          ...recent.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                label: '${row.staffName} checked in at ${row.checkInTimeLabel}',
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.panelMuted,
                    borderRadius: BorderRadius.circular(tokens.radius.control),
                    border: Border.all(color: tokens.panelBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          row.staffName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        row.checkInTimeLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tokens.radius.card),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _StatusStrip({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(tokens.radius.control),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

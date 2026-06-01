import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

class StaffQrAttendancePanel extends StatefulWidget {
  final bool compact;

  const StaffQrAttendancePanel({super.key, this.compact = false});

  @override
  State<StaffQrAttendancePanel> createState() => _StaffQrAttendancePanelState();
}

class _StaffQrAttendancePanelState extends State<StaffQrAttendancePanel> {
  StaffQrTokenModel? _token;
  List<StaffAttendanceModel> _recent = const [];
  Timer? _timer;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      if (!quiet) _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getStaffQrToken(),
        api.getStaffAttendanceForDate(),
      ]);
      final token = results[0] as StaffQrTokenModel;
      final rows = results[1] as List<StaffAttendanceModel>;
      if (!mounted) return;
      setState(() {
        _token = token;
        _recent = rows;
        _secondsLeft = token.secondsRemaining;
        _loading = false;
        _refreshing = false;
      });
      _startCountdown();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
        _refreshing = false;
      });
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final token = _token;
      if (token == null || !mounted) return;
      final next = token.secondsRemaining;
      setState(() => _secondsLeft = next);
      if (next <= 0) {
        _timer?.cancel();
        _load(quiet: true);
      }
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
  final String? error;
  final bool compact;
  final VoidCallback onRefresh;

  const _QrBlock({
    required this.token,
    required this.secondsLeft,
    required this.refreshing,
    required this.error,
    required this.compact,
    required this.onRefresh,
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
              color: Colors.white,
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
                    data: token!.token,
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    backgroundColor: Colors.white,
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
            child: Row(
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

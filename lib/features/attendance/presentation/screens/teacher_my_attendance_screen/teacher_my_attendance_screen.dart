import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/app/router/route_arguments.dart';
import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/roles/teacher/data/api_teacher_attendance_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_repository.dart';

@immutable
class _TeacherStaffAttendanceSnapshot {
  final StaffAttendanceModel? today;
  final List<StaffAttendanceModel> log;

  const _TeacherStaffAttendanceSnapshot({this.today, required this.log});
}

class TeacherMyAttendanceScreen extends StatefulWidget {
  final TeacherAttendanceRepository? repository;

  const TeacherMyAttendanceScreen({super.key, this.repository});

  @override
  State<TeacherMyAttendanceScreen> createState() =>
      _TeacherMyAttendanceScreenState();
}

class _TeacherMyAttendanceScreenState extends State<TeacherMyAttendanceScreen> {
  RepositoryState<_TeacherStaffAttendanceSnapshot> _state =
      const RepositoryState.loading();
  bool _submitting = false;
  String? _message;
  bool _routeArgumentsRead = false;
  bool _autoScanRequested = false;
  bool _autoScannerOpened = false;

  StaffAttendanceModel? get _attendance => _state.data?.today;
  List<StaffAttendanceModel> get _attendanceLog => _state.data?.log ?? const [];

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgumentsRead) return;
    _routeArgumentsRead = true;
    final args = SchoolDeskRouteArguments.maybeOf<Object?>(context);
    if (args is Map) {
      _autoScanRequested = args['auto_scan'] == true;
    }
    _maybeOpenAutoScanner();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadToday() async {
    final previous = _state.data;
    setState(() {
      _state = RepositoryState.loading(
        data: previous,
        source: previous == null
            ? RepositorySource.empty
            : RepositorySource.cache,
        isStale: previous != null,
        isRefreshing: previous != null,
      );
      _message = null;
    });
    try {
      final result =
          await (widget.repository ??
                  ApiTeacherAttendanceRepository.legacyDefault)
              .loadStaffAttendance();
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to load attendance',
        );
      }
      final snapshot = result.dataOrNull!;
      if (!mounted) return;
      setState(() {
        _state = RepositoryState(
          data: _TeacherStaffAttendanceSnapshot(
            today: snapshot.today,
            log: snapshot.log,
          ),
          source: RepositorySource.remote,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
      _maybeOpenAutoScanner();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _state = previous == null
            ? RepositoryState.error(error: error)
            : RepositoryState(
                data: previous,
                source: RepositorySource.cache,
                isStale: true,
                error: error,
                lastUpdated: _state.lastUpdated,
              );
      });
    }
  }

  void _maybeOpenAutoScanner() {
    final shouldOpen =
        _autoScanRequested &&
        !_autoScannerOpened &&
        !_state.isLoading &&
        !_submitting &&
        !(_attendance?.checkedIn ?? false);
    if (!shouldOpen) return;
    _autoScannerOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openScanner();
    });
  }

  void _openScanner() async {
    final token = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const FullScreenScannerScreen()),
    );
    if (token != null && token.isNotEmpty) {
      unawaited(_submitToken(token));
    }
  }

  Future<void> _submitToken(String token) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      final result =
          await (widget.repository ??
                  ApiTeacherAttendanceRepository.legacyDefault)
              .scanStaffQr(token);
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to scan staff QR',
        );
      }
      final snapshot = result.dataOrNull!;
      if (!mounted) return;
      setState(() {
        _state = RepositoryState(
          data: _TeacherStaffAttendanceSnapshot(
            today: snapshot.today,
            log: snapshot.log,
          ),
          source: RepositorySource.localMutation,
          lastUpdated: DateTime.now().toUtc(),
        );
        _submitting = false;
        _message = snapshot.today?.checkOut != null
            ? 'Check-out recorded'
            : 'Check-in recorded';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        final previous = _state.data;
        _state = previous == null
            ? RepositoryState.error(error: error)
            : RepositoryState(
                data: previous,
                source: RepositorySource.cache,
                isStale: true,
                error: error,
                lastUpdated: _state.lastUpdated,
              );
      });
    }
  }

  Future<void> _punchOut() async {
    if (_submitting ||
        _attendance?.checkedIn != true ||
        _attendance?.checkOut != null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Punch out'),
        content: const Text('Record your attendance check-out time now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Punch out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      final result =
          await (widget.repository ??
                  ApiTeacherAttendanceRepository.legacyDefault)
              .punchOutStaffAttendance();
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to record check-out',
        );
      }
      final attendance = result.dataOrNull!;
      if (!mounted) return;
      setState(() {
        _state = RepositoryState(
          data: _TeacherStaffAttendanceSnapshot(
            today: attendance,
            log: _attendanceLog,
          ),
          source: RepositorySource.localMutation,
          lastUpdated: DateTime.now().toUtc(),
        );
        _submitting = false;
        _message = 'Check-out recorded';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        final previous = _state.data;
        _state = previous == null
            ? RepositoryState.error(error: error)
            : RepositoryState(
                data: previous,
                source: RepositorySource.cache,
                isStale: true,
                error: error,
                lastUpdated: _state.lastUpdated,
              );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'My Attendance',
      subtitle: 'QR check-in and check-out',
      selectedIndex: TeacherNav.myAttendance,
      loading: false,
      error: null,
      onRefresh: _loadToday,
      child: SchoolDeskRepositoryStateView<_TeacherStaffAttendanceSnapshot>(
        state: _state,
        onRetry: _loadToday,
        loadingMessage: 'Loading attendance…',
        emptyTitle: 'Attendance unavailable',
        emptyMessage: 'No attendance record is available for today.',
        data: (_) => TeacherFlowScrollView(
          children: [
            Semantics(
              label: 'Teacher QR attendance punch screen',
              child: TeacherCurrentClassCard(
                greeting: _attendance?.checkOut != null
                    ? 'Checked out'
                    : _attendance?.checkedIn == true
                    ? 'Checked in'
                    : 'Ready to check in',
                classLabel: _attendance?.checkOut != null
                    ? 'Your attendance is complete for today'
                    : 'Scan the live staff QR',
                subject: _attendance?.checkOut != null
                    ? 'In ${_attendance?.checkInTimeLabel ?? '--:--'} · Out ${_attendance?.checkOutTimeLabel ?? '--:--'}'
                    : _attendance?.checkInTimeLabel ?? 'Check-in pending',
                timeLabel: '',
                actions: [
                  TeacherFlowAction(
                    label: 'Scan QR',
                    icon: Icons.qr_code_scanner_rounded,
                    filled: true,
                    onTap: _openScanner,
                  ),
                  if (_attendance?.checkedIn == true &&
                      _attendance?.checkOut == null)
                    TeacherFlowAction(
                      label: 'Punch Out',
                      icon: Icons.logout_rounded,
                      filled: true,
                      onTap: _punchOut,
                    ),
                  TeacherFlowAction(
                    label: 'Refresh Status',
                    icon: Icons.refresh_rounded,
                    onTap: _loadToday,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _AttendanceLogCard(records: _attendanceLog),
            if (_submitting) ...[
              const SizedBox(height: 18),
              const TeacherFlowCard(
                icon: Icons.hourglass_top_rounded,
                title: 'Recording punch...',
                subtitle: 'Saving your attendance to the system.',
                status: 'Saving',
                statusColor: Colors.orange,
              ),
            ] else if (_message != null) ...[
              const SizedBox(height: 18),
              TeacherFlowCard(
                icon: Icons.check_circle_rounded,
                title: 'Attendance saved',
                subtitle: _message!,
                status: 'Done',
                statusColor: Colors.green,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttendanceLogCard extends StatelessWidget {
  const _AttendanceLogCard({required this.records});

  final List<StaffAttendanceModel> records;

  @override
  Widget build(BuildContext context) {
    return TeacherFlowCard(
      icon: Icons.history_rounded,
      title: 'Attendance Log',
      subtitle: 'Last 30 days',
      status: '${records.length}',
      statusColor: teacherFlowAccent,
      body: records.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                'No recorded punch-ins in the last 30 days.',
                style: TextStyle(
                  color: teacherFlowMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                children: [
                  for (final record in records) _AttendanceLogRow(record),
                ],
              ),
            ),
    );
  }
}

class _AttendanceLogRow extends StatelessWidget {
  const _AttendanceLogRow(this.record);

  final StaffAttendanceModel record;

  @override
  Widget build(BuildContext context) {
    final date = record.date ?? record.checkIn;
    final checkIn = record.checkIn;
    final checkOut = record.checkOut;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3FAF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: teacherFlowAccent.withAlpha(46)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              checkOut == null ? Icons.login_rounded : Icons.logout_rounded,
              color: teacherFlowAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _dateLabel(date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: teacherFlowInk,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'In ${_timeLabel(checkIn)}',
                style: const TextStyle(
                  color: teacherFlowInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Out ${_timeLabel(checkOut)}',
                style: const TextStyle(color: teacherFlowMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime? value) {
    if (value == null) return 'Unknown date';
    return DateFormat('dd MMM yyyy').format(value.toLocal());
  }

  static String _timeLabel(DateTime? value) {
    if (value == null) return '--:--';
    return DateFormat('HH:mm').format(value.toLocal());
  }
}

class FullScreenScannerScreen extends StatefulWidget {
  const FullScreenScannerScreen({super.key});

  @override
  State<FullScreenScannerScreen> createState() =>
      _FullScreenScannerScreenState();
}

class _FullScreenScannerScreenState extends State<FullScreenScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final token = barcode.rawValue?.trim();
      if (token == null || token.isEmpty) continue;
      setState(() => _isProcessing = true);
      _scannerController.stop().then((_) {
        if (mounted) Navigator.of(context).pop(token);
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _scannerController, onDetect: _onDetect),
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(178),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 280,
                    width: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Align(
            alignment: Alignment.center,
            child: SizedBox(
              height: 280,
              width: 280,
              child: Stack(
                children: [
                  _ScannerCorner(alignment: Alignment.topLeft),
                  _ScannerCorner(alignment: Alignment.topRight),
                  _ScannerCorner(alignment: Alignment.bottomLeft),
                  _ScannerCorner(alignment: Alignment.bottomRight),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 100),
                child: Text(
                  'Scan Staff QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'Align QR code within the frame to punch in',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerCorner extends StatelessWidget {
  final Alignment alignment;

  const _ScannerCorner({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top:
                alignment == Alignment.topLeft ||
                    alignment == Alignment.topRight
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            bottom:
                alignment == Alignment.bottomLeft ||
                    alignment == Alignment.bottomRight
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            left:
                alignment == Alignment.topLeft ||
                    alignment == Alignment.bottomLeft
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            right:
                alignment == Alignment.topRight ||
                    alignment == Alignment.bottomRight
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

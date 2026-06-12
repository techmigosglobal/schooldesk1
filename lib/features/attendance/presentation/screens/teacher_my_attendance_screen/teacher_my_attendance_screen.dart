import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherMyAttendanceScreen extends StatefulWidget {
  const TeacherMyAttendanceScreen({super.key});

  @override
  State<TeacherMyAttendanceScreen> createState() =>
      _TeacherMyAttendanceScreenState();
}

class _TeacherMyAttendanceScreenState extends State<TeacherMyAttendanceScreen> {
  StaffAttendanceModel? _attendance;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadToday() async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
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
        _loading = false;
        _error = error.toString();
      });
    }
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
      _error = null;
      _message = null;
    });
    try {
      final attendance = await BackendApiClient.instance.scanStaffQr(token);
      if (!mounted) return;
      setState(() {
        _attendance = attendance;
        _submitting = false;
        _message = 'Attendance punch recorded';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'My Attendance',
      subtitle: 'QR Punch-in',
      selectedIndex: 14,
      loading: _loading,
      error: _error,
      onRefresh: _loadToday,
      child: TeacherFlowScrollView(
        children: [
          Semantics(
            label: 'Teacher QR attendance punch screen',
            child: TeacherCurrentClassCard(
              greeting: _attendance?.checkedIn == true
                  ? 'Attendance Recorded'
                  : 'Ready to punch in',
              classLabel: 'Scan the live staff QR',
              subject: _attendance?.checkInTimeLabel ?? 'Punch In pending',
              timeLabel: '',
              actions: [
                TeacherFlowAction(
                  label: 'Scan QR',
                  icon: Icons.qr_code_scanner_rounded,
                  filled: true,
                  onTap: _openScanner,
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
          TeacherFlowMetricGrid(
            metrics: [
              TeacherFlowMetric(
                label: 'Punch In',
                value: _attendance?.checkInTimeLabel ?? '--:--',
                icon: Icons.login_rounded,
                color: teacherFlowAccent,
                tone: const Color(0xFFE3FAF5),
              ),
              TeacherFlowMetric(
                label: 'Status',
                value: teacherFlowTitleCase(_attendance?.status ?? 'Pending'),
                icon: Icons.verified_rounded,
                color: Colors.orange,
                tone: const Color(0xFFFFF4E5),
              ),
              TeacherFlowMetric(
                label: 'Source',
                value: teacherFlowTitleCase(_attendance?.source ?? 'QR'),
                icon: Icons.qr_code_2_rounded,
                color: Colors.purple,
                tone: const Color(0xFFF5EAFE),
              ),
            ],
          ),
          if (_submitting) ...[
            const SizedBox(height: 18),
            TeacherFlowCard(
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
    );
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
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              height: 280,
              width: 280,
              child: Stack(
                children: const [
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

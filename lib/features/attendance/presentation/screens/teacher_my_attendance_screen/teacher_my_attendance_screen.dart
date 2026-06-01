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
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  StaffAttendanceModel? _attendance;
  bool _loading = true;
  bool _scannerOpen = false;
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
    _scannerController.dispose();
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

  void _onDetect(BarcodeCapture capture) {
    if (_submitting) return;
    for (final barcode in capture.barcodes) {
      final token = barcode.rawValue?.trim();
      if (token == null || token.isEmpty) continue;
      unawaited(_submitToken(token));
      return;
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
      await _scannerController.stop();
      final attendance = await BackendApiClient.instance.scanStaffQr(token);
      if (!mounted) return;
      setState(() {
        _attendance = attendance;
        _scannerOpen = false;
        _submitting = false;
        _message = attendance.checkedIn
            ? 'Punch-in recorded at ${attendance.checkInTimeLabel}'
            : 'Attendance recorded';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scannerOpen = false;
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _closeScanner() async {
    await _scannerController.stop();
    if (mounted) setState(() => _scannerOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'My Attendance',
      subtitle: 'QR punch-in and punch-out',
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
                  ? 'You are checked in'
                  : 'Ready to punch in',
              classLabel: _attendance?.checkedIn == true
                  ? 'Working day active'
                  : 'Scan the live staff QR',
              subject: _attendance?.checkInTimeLabel ?? 'Punch In',
              timeLabel: _attendance?.checkOutTimeLabel ?? 'Punch Out pending',
              actions: [
                TeacherFlowAction(
                  label: 'Scan QR',
                  icon: Icons.qr_code_scanner_rounded,
                  filled: true,
                  onTap: () => setState(() => _scannerOpen = true),
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
                label: 'Punch Out',
                value: _attendance?.checkOutTimeLabel ?? '--:--',
                icon: Icons.logout_rounded,
                color: Colors.indigo,
                tone: const Color(0xFFEAF0FF),
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
          if (_scannerOpen) ...[
            const SizedBox(height: 18),
            _ScannerCard(
              controller: _scannerController,
              submitting: _submitting,
              onDetect: _onDetect,
              onClose: _closeScanner,
            ),
          ],
          if (_message != null) ...[
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

class _ScannerCard extends StatelessWidget {
  final MobileScannerController controller;
  final bool submitting;
  final void Function(BarcodeCapture) onDetect;
  final Future<void> Function() onClose;

  const _ScannerCard({
    required this.controller,
    required this.submitting,
    required this.onDetect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return TeacherFlowCard(
      icon: Icons.qr_code_scanner_rounded,
      title: submitting ? 'Recording punch...' : 'Scan live QR',
      subtitle: 'Use the entrance QR. Screenshots and expired QR codes fail.',
      status: submitting ? 'Saving' : 'Live',
      statusColor: submitting ? Colors.orange : teacherFlowAccent,
      body: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 280,
              child: MobileScanner(controller: controller, onDetect: onDetect),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: submitting ? null : () => onClose(),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Close Scanner'),
          ),
        ],
      ),
    );
  }
}

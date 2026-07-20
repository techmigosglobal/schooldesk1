import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/logout_service.dart';
import 'package:schooldesk1/core/widgets/staff_qr_attendance_panel.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';

class KioskQrAttendanceScreen extends StatefulWidget {
  const KioskQrAttendanceScreen({super.key});

  @override
  State<KioskQrAttendanceScreen> createState() =>
      _KioskQrAttendanceScreenState();
}

class _KioskQrAttendanceScreenState extends State<KioskQrAttendanceScreen> {
  @override
  void initState() {
    super.initState();
    // Defensive guard: only kiosk role should be on this screen.
    final role =
        BackendApiClient.instance.currentRoleName?.trim().toLowerCase() ?? '';
    if (role != 'kiosk') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final target = RouteAccessGuard.dashboardForRole(role) ?? '/';
          Navigator.of(context).pushReplacementNamed(target);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final role =
        BackendApiClient.instance.currentRoleName?.trim().toLowerCase() ?? '';
    // Show a loading placeholder while redirecting non-kiosk users.
    if (role != 'kiosk') {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F8FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Staff Attendance QR Display'),
        actions: [
          IconButton(
            tooltip: 'Sign out kiosk',
            onPressed: () => LogoutService.confirmAndSignOut(
              context,
              portalName: 'Attendance kiosk',
            ),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 32 : 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Live staff check-in and check-out QR',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.appTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep this screen open on the attendance display device. Teachers use the same QR for check-in and, after 12:00 p.m. India time, check-out.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appTheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  StaffQrAttendancePanel(compact: !wide),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

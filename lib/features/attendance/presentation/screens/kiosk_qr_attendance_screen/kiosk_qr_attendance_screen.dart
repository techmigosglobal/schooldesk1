import 'package:flutter/material.dart';

import 'package:schooldesk1/core/services/logout_service.dart';
import 'package:schooldesk1/core/widgets/staff_qr_attendance_panel.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class KioskQrAttendanceScreen extends StatelessWidget {
  const KioskQrAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
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
                    'Live staff punch-in QR',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.appTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep this screen open on the attendance display device. Teachers scan this QR from My Attendance to record their own staff attendance.',
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

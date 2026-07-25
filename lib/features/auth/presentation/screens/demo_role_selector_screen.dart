import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/demo_local_api_service.dart';
import 'package:schooldesk1/core/services/demo_sandbox_service.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/routes/app_routes.dart';

/// The only screen shown after a verified shared demo credential.  Selecting a
/// role opens the normal role route, backed exclusively by fictional local API
/// responses saved on this device.
class DemoRoleSelectorScreen extends StatefulWidget {
  const DemoRoleSelectorScreen({super.key});

  @override
  State<DemoRoleSelectorScreen> createState() => _DemoRoleSelectorScreenState();
}

class _DemoRoleSelectorScreenState extends State<DemoRoleSelectorScreen> {
  Map<String, dynamic>? _snapshot;

  @override
  void initState() {
    super.initState();
    DemoSandboxService.instance.snapshot().then((value) {
      if (mounted) setState(() => _snapshot = value);
    });
  }

  Future<void> _openRole(String role) async {
    final stored = _snapshot;
    if (stored == null) return;
    final snapshot = stored['snapshot'] is Map
        ? Map<String, dynamic>.from(stored['snapshot'] as Map)
        : stored;
    await DemoSandboxService.instance.selectRole(role);
    DemoLocalApiService.instance.start(role: role, snapshot: snapshot);
    BackendApiClient.instance.beginLocalDemoSession(
      role: role,
      userId: DemoLocalApiService.localUserId,
      schoolId: DemoLocalApiService.localSchoolId,
    );
    RoleAccessService.resetSignOutGuard();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.loginLoading, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a demo role')),
      body: _snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore SchoolDesk locally',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose one role. Every screen uses fictional data stored on this device; demo actions remain local and never reach your school records.',
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _roleCard(
                            'principal',
                            'Principal',
                            Icons.account_balance_rounded,
                            'School overview, people, approvals, and reports',
                          ),
                          _roleCard(
                            'teacher',
                            'Teacher',
                            Icons.auto_stories_rounded,
                            'Classroom flow, attendance, and communication',
                          ),
                          _roleCard(
                            'parent',
                            'Parent',
                            Icons.family_restroom_rounded,
                            'Child updates, attendance, fees, and notices',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Quick showcase guide',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Principal: overview → approvals → reports. Teacher: class → attendance → homework. Parent: feed → child updates → simulated fee receipt. Every action is local and resets when you sign out.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _roleCard(
    String value,
    String label,
    IconData icon,
    String description,
  ) {
    return SizedBox(
      width: 210,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openRole(value),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 30),
                const SizedBox(height: 14),
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

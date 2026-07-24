import 'package:flutter/material.dart';
import 'package:schooldesk1/core/services/demo_sandbox_service.dart';

/// A deliberately isolated role preview. It reads and writes only the
/// encrypted fictional snapshot saved during demo sign-in.
class DemoSandboxScreen extends StatefulWidget {
  final String role;
  const DemoSandboxScreen({super.key, required this.role});

  @override
  State<DemoSandboxScreen> createState() => _DemoSandboxScreenState();
}

class _DemoSandboxScreenState extends State<DemoSandboxScreen> {
  Map<String, dynamic>? _snapshot;
  bool _localActionDone = false;

  @override
  void initState() {
    super.initState();
    DemoSandboxService.instance.snapshot().then((value) {
      if (mounted) setState(() => _snapshot = value);
    });
  }

  Future<void> _completeLocalAction() async {
    final next = Map<String, dynamic>.from(_snapshot ?? {});
    next['last_local_demo_action'] = '${widget.role}_action_completed';
    next['last_local_demo_action_at'] = DateTime.now().toIso8601String();
    await DemoSandboxService.instance.saveSnapshot(next);
    if (mounted) {
      setState(() {
        _snapshot = next;
        _localActionDone = true;
      });
    }
  }

  ({String title, String subtitle, IconData icon, Color color}) get _header =>
      switch (widget.role) {
        'principal' => (
          title: 'Principal demo',
          subtitle: 'Today’s fictional school overview',
          icon: Icons.account_balance_rounded,
          color: const Color(0xFF155B3B),
        ),
        'teacher' => (
          title: 'Teacher demo',
          subtitle: 'Sunshine Nursery · fictional class',
          icon: Icons.auto_stories_rounded,
          color: const Color(0xFF8A5A16),
        ),
        _ => (
          title: 'Parent demo',
          subtitle: 'Aarav’s fictional school day',
          icon: Icons.favorite_rounded,
          color: const Color(0xFF7654B5),
        ),
      };

  @override
  Widget build(BuildContext context) {
    final header = _header;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FBF7),
        elevation: 0,
        title: Text(header.title),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Chip(
                label: Text('LOCAL SANDBOX'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: _snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                _DemoHero(header: header),
                const SizedBox(height: 20),
                _RoleSnapshot(role: widget.role, snapshot: _snapshot!),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _completeLocalAction,
                  icon: Icon(
                    _localActionDone ? Icons.check_circle : Icons.edit_note,
                  ),
                  label: Text(
                    _localActionDone
                        ? 'Saved on this device only'
                        : _localActionLabel(widget.role),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: header.color,
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This is fictional data. No demo action, upload, notification, or operational update is sent to SchoolDesk.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64756A), fontSize: 12),
                ),
              ],
            ),
    );
  }

  String _localActionLabel(String role) => switch (role) {
    'principal' => 'Mark review item complete',
    'teacher' => 'Mark today’s attendance locally',
    _ => 'Save a local acknowledgement',
  };
}

class _DemoHero extends StatelessWidget {
  final ({String title, String subtitle, IconData icon, Color color}) header;
  const _DemoHero({required this.header});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: header.color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.white24,
          child: Icon(header.icon, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                header.subtitle,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              const Text(
                'Fictional offline preview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RoleSnapshot extends StatelessWidget {
  final String role;
  final Map<String, dynamic> snapshot;
  const _RoleSnapshot({required this.role, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final data = Map<String, dynamic>.from(snapshot[role] as Map? ?? const {});
    final cards = switch (role) {
      'principal' => [
        ('Learners', '${data['students'] ?? 42}', Icons.groups_rounded),
        (
          'Pending approvals',
          '${data['pending_approvals'] ?? 3}',
          Icons.rule_rounded,
        ),
        ('Local reports', 'Ready', Icons.insights_rounded),
      ],
      'teacher' => [
        (
          'Class',
          '${data['class_name'] ?? 'Sunshine Nursery'}',
          Icons.class_rounded,
        ),
        (
          'Attendance',
          data['attendance_ready'] == true ? 'Ready' : 'Pending',
          Icons.fact_check_rounded,
        ),
        ('Today', 'Story circle', Icons.menu_book_rounded),
      ],
      _ => [
        (
          'Child',
          '${data['child_name'] ?? 'Aarav Demo'}',
          Icons.child_care_rounded,
        ),
        (
          'Next event',
          '${data['next_event'] ?? 'Storytelling Friday'}',
          Icons.celebration_rounded,
        ),
        ('Updates', '2 new', Icons.notifications_active_rounded),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          role == 'principal'
              ? 'School at a glance'
              : role == 'teacher'
              ? 'Today in your class'
              : 'Your child’s day',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...cards.map(
          (card) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE6F2E8),
                child: Icon(card.$3, color: const Color(0xFF155B3B)),
              ),
              title: Text(card.$1),
              trailing: Text(
                card.$2,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

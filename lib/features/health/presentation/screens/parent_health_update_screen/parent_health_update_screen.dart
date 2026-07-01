import 'package:flutter/material.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';

/// Parent Health Update screen — parents can set pill/medication reminders
/// for their children. These reminders are visible to teachers and principals
/// so they can monitor student health during school hours.
class ParentHealthUpdateScreen extends StatefulWidget {
  const ParentHealthUpdateScreen({super.key});

  @override
  State<ParentHealthUpdateScreen> createState() =>
      _ParentHealthUpdateScreenState();
}

class _ParentHealthUpdateScreenState extends State<ParentHealthUpdateScreen> {
  int _selectedNavIndex = 19;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _children = [];
  int _activeChildIndex = 0;
  List<Map<String, dynamic>> _healthRecords = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final childrenResp = await api.getMyStudents();
      _children = childrenResp
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList();
      if (_children.isNotEmpty) {
        await _loadHealthRecords(_children[0]['id'].toString());
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load data: $e';
      });
    }
  }

  Future<void> _loadHealthRecords(String studentId) async {
    setState(() => _loading = true);
    try {
      final api = BackendApiClient.instance;
      final response = await api.dio.get('/medical-records', queryParameters: {
        'student_id': studentId,
      });
      final data = response.data;
      final records = data is Map ? (data['data'] as List? ?? []) : (data is List ? data : []);
      setState(() {
        _healthRecords = records
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _healthRecords = [];
        _loading = false;
      });
    }
  }

  void _showAddReminderDialog() {
    final student = _children.isNotEmpty ? _children[_activeChildIndex] : null;
    if (student == null) return;

    final conditionCtrl = TextEditingController();
    final medicationCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String reminderTime = 'Morning';
    bool active = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add Health Reminder',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'For: ${student['first_name'] ?? ''} ${student['last_name'] ?? ''}',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: conditionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Health Condition',
                        hintText: 'e.g. Cold, Fever, Allergy',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: medicationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Medication / Pill Name',
                        hintText: 'e.g. Paracetamol, Cetirizine',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dosageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dosage',
                        hintText: 'e.g. 500mg twice daily',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: reminderTime,
                      decoration: const InputDecoration(
                        labelText: 'Reminder Time',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Morning', child: Text('Morning')),
                        DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon')),
                        DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                        DropdownMenuItem(value: 'Night', child: Text('Night')),
                      ],
                      onChanged: (v) {
                        if (v != null) setModalState(() => reminderTime = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Active'),
                      subtitle: const Text('Enable this reminder'),
                      value: active,
                      onChanged: (v) => setModalState(() => active = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes',
                        hintText: 'Special instructions for teacher/principal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        final payload = {
                          'student_id': student['id'],
                          'conditions': conditionCtrl.text.trim(),
                          'medications': medicationCtrl.text.trim(),
                          'dosage': dosageCtrl.text.trim(),
                          'reminder_time': reminderTime,
                          'notes': notesCtrl.text.trim(),
                          'allergies': '',
                          'is_active': active,
                        };
                        try {
                          await BackendApiClient.instance.dio.post(
                            '/medical-records',
                            data: payload,
                          );
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Health reminder saved. Teacher and principal will be notified.'),
                              ),
                            );
                            _loadHealthRecords(student['id'].toString());
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save: $e'),
                                backgroundColor: Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Reminder'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Health Updates',
      subtitle: 'Set pill reminders for your child',
      drawer: ParentDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _children.isNotEmpty ? _showAddReminderDialog : null,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Reminder'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _children.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline_rounded,
                  size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              const Text('No linked students found.'),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Child selector
        if (_children.length > 1)
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _children.length,
              itemBuilder: (ctx, i) {
                final c = _children[i];
                final name =
                    '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim();
                final isActive = i == _activeChildIndex;
                final theme = Theme.of(context);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(name.isEmpty ? 'Student' : name),
                    selected: isActive,
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surface,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : theme.colorScheme.onSurface,
                    ),
                    side: BorderSide(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                    onSelected: (_) {
                      setState(() => _activeChildIndex = i);
                      _loadHealthRecords(c['id'].toString());
                    },
                  ),
                );
              },
            ),
          ),
        // Health records list
        Expanded(
          child: _healthRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.medical_services_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      const Text('No health records yet.'),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap "Add Reminder" to set a pill or medication reminder.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _healthRecords.length,
                    itemBuilder: (ctx, i) =>
                        _HealthRecordCard(record: _healthRecords[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _HealthRecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  const _HealthRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final conditions = record['conditions']?.toString() ?? '';
    final medications = record['medications']?.toString() ?? '';
    final dosage = record['dosage']?.toString() ?? '';
    final reminderTime = record['reminder_time']?.toString() ?? '';
    final notes = record['notes']?.toString() ?? '';
    final isActive = record['is_active'] != false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withAlpha(60)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medical_services_rounded,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conditions.isNotEmpty ? conditions : 'Health Update',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withAlpha(100)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
            if (medications.isNotEmpty) ...[
              const SizedBox(height: 10),
              _detailRow(context, Icons.medication_rounded, 'Medication',
                  medications),
            ],
            if (dosage.isNotEmpty)
              _detailRow(context, Icons.science_rounded, 'Dosage', dosage),
            if (reminderTime.isNotEmpty)
              _detailRow(context, Icons.access_time_rounded, 'Reminder Time',
                  reminderTime),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                notes,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Visible to: Teacher & Principal',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Text('$label: ',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

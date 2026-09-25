import 'package:flutter/material.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/parent_child_selector.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_health_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_health_repository.dart';

/// Parent Health Update screen — parents can set pill/medication reminders
/// for their children. These reminders are visible to teachers and principals
/// so they can monitor student health during school hours.
final class _ParentHealthSnapshot {
  const _ParentHealthSnapshot({
    required this.children,
    required this.healthRecords,
  });

  final List<Map<String, dynamic>> children;
  final List<Map<String, dynamic>> healthRecords;
}

class ParentHealthUpdateScreen extends StatefulWidget {
  final ParentHealthRepository? repository;

  const ParentHealthUpdateScreen({super.key, this.repository});

  @override
  State<ParentHealthUpdateScreen> createState() =>
      _ParentHealthUpdateScreenState();
}

class _ParentHealthUpdateScreenState extends State<ParentHealthUpdateScreen> {
  ParentHealthRepository get _repository =>
      widget.repository ?? ApiParentHealthRepository.legacyDefault;
  int _selectedNavIndex = 19;
  RepositoryState<_ParentHealthSnapshot> _repositoryState =
      const RepositoryState.loading();
  List<Map<String, dynamic>> _children = [];
  int _activeChildIndex = 0;
  List<Map<String, dynamic>> _healthRecords = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final previous = _repositoryState;
    setState(() {
      _repositoryState = RepositoryState.loading(
        data: previous.data,
        source: previous.source,
        isStale: previous.isStale,
        isRefreshing: previous.hasData,
        lastUpdated: previous.lastUpdated,
      );
    });
    try {
      final childrenResult = await _repository.loadChildren();
      final childrenResp = childrenResult.dataOrNull;
      if (childrenResp == null) {
        throw StateError(
          childrenResult.failureOrNull?.message ?? 'Unable to load children',
        );
      }
      _children = childrenResp
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList();
      if (_children.isNotEmpty) {
        final selectedIndex = await ParentChildSelectionService.indexFor(
          _children,
          fallback: _activeChildIndex,
        );
        _activeChildIndex = selectedIndex;
        await _loadHealthRecords(_children[selectedIndex]['id'].toString());
      } else {
        if (!mounted) return;
        setState(() {
          _healthRecords = const [];
          _repositoryState = const RepositoryState(
            data: _ParentHealthSnapshot(children: [], healthRecords: []),
            source: RepositorySource.remote,
          );
        });
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _repositoryState = previous.hasData
            ? RepositoryState(
                data: previous.data,
                source: RepositorySource.cache,
                isStale: true,
                error: 'Failed to load data: $e',
                lastUpdated: previous.lastUpdated,
              )
            : RepositoryState.error(error: 'Failed to load data: $e');
      });
    }
  }

  Future<void> _loadHealthRecords(String studentId) async {
    final previous = _repositoryState;
    setState(() {
      _repositoryState = RepositoryState.loading(
        data: previous.data,
        source: previous.source,
        isStale: previous.isStale,
        isRefreshing: previous.hasData,
        lastUpdated: previous.lastUpdated,
      );
    });
    try {
      final result = await _repository.loadReminders(studentId);
      final records = result.dataOrNull;
      if (records == null) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to load reminders',
        );
      }
      setState(() {
        _healthRecords = records;
        _repositoryState = RepositoryState(
          data: _ParentHealthSnapshot(
            children: List.unmodifiable(_children),
            healthRecords: List.unmodifiable(records),
          ),
          source: RepositorySource.remote,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _repositoryState = previous.hasData
            ? RepositoryState(
                data: previous.data,
                source: RepositorySource.cache,
                isStale: true,
                error: error,
                lastUpdated: previous.lastUpdated,
              )
            : RepositoryState.error(error: error);
      });
    }
  }

  void _showReminderDialog({Map<String, dynamic>? existing}) {
    final student = _children.isNotEmpty ? _children[_activeChildIndex] : null;
    if (student == null) return;

    final conditionCtrl = TextEditingController(
      text:
          existing?['condition']?.toString() ??
          existing?['conditions']?.toString() ??
          '',
    );
    final medicationCtrl = TextEditingController(
      text:
          existing?['medication']?.toString() ??
          existing?['medications']?.toString() ??
          '',
    );
    final dosageCtrl = TextEditingController(
      text: existing?['dosage']?.toString() ?? '',
    );
    final notesCtrl = TextEditingController(
      text: existing?['notes']?.toString() ?? '',
    );
    DateTime reminderDate =
        DateTime.tryParse(existing?['reminder_date']?.toString() ?? '') ??
        DateTime.now();
    bool active = existing?['is_active'] != false;
    bool saving = false;

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
                20,
                20,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null
                          ? 'Add Health Reminder'
                          : 'Edit Health Reminder',
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
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: reminderDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => reminderDate = picked);
                        }
                      },
                      icon: const Icon(Icons.event_rounded),
                      label: Text('Reminder Date: ${_dateLabel(reminderDate)}'),
                    ),
                    const SizedBox(height: 12),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'The class teacher, co-teacher and principal will see this in Today\'s Highlights at 4:00 PM on the selected date.',
                              style: Theme.of(ctx).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      ctx,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
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
                      onPressed: saving
                          ? null
                          : () async {
                              setModalState(() => saving = true);
                              final payload = {
                                'student_id': student['id'],
                                'reminder_date': _dateValue(reminderDate),
                                'condition': conditionCtrl.text.trim(),
                                'medication': medicationCtrl.text.trim(),
                                'dosage': dosageCtrl.text.trim(),
                                'reminder_time': '4:00 PM',
                                'notes': notesCtrl.text.trim(),
                                'is_active': active,
                              };
                              try {
                                final result = existing == null
                                    ? await _repository.createReminder(payload)
                                    : await _repository.updateReminder(
                                        existing['id'].toString(),
                                        payload,
                                      );
                                if (result.isFailure) {
                                  throw StateError(
                                    result.failureOrNull?.message ??
                                        'Unable to save reminder',
                                  );
                                }
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        existing == null
                                            ? 'Health reminder saved. It will appear for the class team and principal at 4:00 PM on the selected date.'
                                            : 'Health reminder updated.',
                                      ),
                                    ),
                                  );
                                  _loadHealthRecords(student['id'].toString());
                                }
                              } on Object catch (_) {
                                if (mounted) {
                                  setModalState(() => saving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        existing == null
                                            ? 'Could not save the health reminder. Please try again.'
                                            : 'Could not update the health reminder. Please try again.',
                                      ),
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        saving
                            ? 'Saving...'
                            : existing == null
                            ? 'Save Reminder'
                            : 'Save Changes',
                      ),
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
        onPressed: _children.isNotEmpty ? _showReminderDialog : null,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Reminder'),
      ),
      body: SchoolDeskRepositoryStateView<_ParentHealthSnapshot>(
        state: _repositoryState,
        onRetry: _loadData,
        emptyTitle: 'No linked students found',
        emptyMessage: 'Link a student account before adding health reminders.',
        errorTitle: 'Health data unavailable',
        data: (_) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ParentChildSelector(
              children: _children,
              selectedIndex: _activeChildIndex,
              onSelected: (index) {
                setState(() => _activeChildIndex = index);
                ParentChildSelectionService.saveIndex(_children, index);
                _loadHealthRecords(_children[index]['id'].toString());
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
                      Icon(
                        Icons.medical_services_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
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
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Reminder History',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._healthRecords.map(
                        (record) => _HealthRecordCard(
                          record: record,
                          onEdit: () => _showReminderDialog(existing: record),
                          onDelete: () => _deleteReminder(record),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _deleteReminder(Map<String, dynamic> record) async {
    final reminderId = record['id']?.toString() ?? '';
    if (reminderId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete health reminder?'),
        content: const Text(
          'This removes the reminder and its visible health highlight for the class team.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await _repository.deleteReminder(reminderId);
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to delete reminder',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Health reminder deleted.')));
      await _loadHealthRecords(_children[_activeChildIndex]['id'].toString());
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not delete the health reminder. Please try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

String _dateValue(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _dateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class _HealthRecordCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HealthRecordCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final conditions = record['conditions']?.toString() ?? '';
    final condition = record['condition']?.toString().trim().isNotEmpty == true
        ? record['condition']?.toString() ?? ''
        : conditions;
    final medications = record['medications']?.toString() ?? '';
    final medication =
        record['medication']?.toString().trim().isNotEmpty == true
        ? record['medication']?.toString() ?? ''
        : medications;
    final dosage = record['dosage']?.toString() ?? '';
    final reminderTime = record['reminder_time']?.toString() ?? '';
    final reminderDate = record['reminder_date']?.toString() ?? '';
    final notes = record['notes']?.toString() ?? '';
    final isActive = record['is_active'] != false;

    final activeColor = isActive
        ? const Color(0xFF0F766E)
        : Theme.of(context).colorScheme.outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? activeColor.withAlpha(60)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: activeColor.withAlpha(isActive ? 25 : 10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isActive
                    ? [const Color(0xFF0F766E), const Color(0xFF14B8A6)]
                    : [
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.medical_services_rounded,
                    color: isActive
                        ? Colors.white
                        : Theme.of(context).colorScheme.outline,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    condition.isNotEmpty ? condition : 'Health Update',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(isActive ? 40 : 30),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? Colors.white
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Manage health reminder',
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: isActive
                        ? Colors.white
                        : Theme.of(context).colorScheme.outline,
                  ),
                  onSelected: (action) {
                    if (action == 'edit') onEdit();
                    if (action == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_rounded),
                        title: Text('Edit'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Body details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reminderDate.isNotEmpty)
                  _detailRow(
                    context,
                    Icons.event_rounded,
                    'Reminder Date',
                    reminderDate,
                    activeColor,
                  ),
                if (medication.isNotEmpty)
                  _detailRow(
                    context,
                    Icons.medication_rounded,
                    'Medication',
                    medication,
                    activeColor,
                  ),
                if (dosage.isNotEmpty)
                  _detailRow(
                    context,
                    Icons.science_rounded,
                    'Dosage',
                    dosage,
                    activeColor,
                  ),
                if (reminderTime.isNotEmpty)
                  _detailRow(
                    context,
                    Icons.access_time_rounded,
                    'Reminder Time',
                    reminderTime,
                    activeColor,
                  ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: activeColor.withAlpha(12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: activeColor.withAlpha(30)),
                    ),
                    child: Text(
                      notes,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: activeColor.withAlpha(12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: activeColor.withAlpha(30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_rounded,
                        size: 13,
                        color: activeColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Visible to: Teacher & Principal',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: activeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color accentColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: accentColor),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

@immutable
class TeacherLeaveRequestFormArgs {
  final String staffId;
  final String staffName;
  final List<Map<String, dynamic>> leaveTypes;
  final List<Map<String, dynamic>> balances;

  const TeacherLeaveRequestFormArgs({
    required this.staffId,
    required this.staffName,
    required this.leaveTypes,
    required this.balances,
  });
}

@immutable
class TeacherLeaveRequestResult {
  final String message;

  const TeacherLeaveRequestResult(this.message);
}

class TeacherLeaveRequestFormScreen extends StatefulWidget {
  final TeacherLeaveRequestFormArgs args;

  const TeacherLeaveRequestFormScreen({super.key, required this.args});

  @override
  State<TeacherLeaveRequestFormScreen> createState() =>
      _TeacherLeaveRequestFormScreenState();
}

class _TeacherLeaveRequestFormScreenState
    extends State<TeacherLeaveRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  late final TextEditingController _fromDateController;
  late final TextEditingController _toDateController;
  String _leaveTypeId = '';
  String _staffId = '';
  String _staffName = '';
  List<Map<String, dynamic>> _leaveTypes = const [];
  List<Map<String, dynamic>> _balances = const [];
  bool _loadingContext = true;
  bool _halfDay = false;
  bool _saving = false;
  String? _error;

  // Backing ISO dates for API submission
  DateTime _fromDate = DateTime.now().add(const Duration(days: 1));
  DateTime _toDate = DateTime.now().add(const Duration(days: 1));

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _displayDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = _monthNames[date.month - 1];
    return '$day $month ${date.year}';
  }

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _fromDate = tomorrow;
    _toDate = tomorrow;
    _fromDateController = TextEditingController(text: _displayDate(tomorrow));
    _toDateController = TextEditingController(text: _displayDate(tomorrow));
    _staffId = widget.args.staffId;
    _staffName = widget.args.staffName;
    _leaveTypes = widget.args.leaveTypes;
    _balances = widget.args.balances;
    _leaveTypeId = _firstLeaveTypeId();
    _loadMissingContext();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final validationError = _validateLeaveRequest();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    if (_staffId.trim().isEmpty) {
      setState(
        () =>
            _error = 'Teacher profile is still syncing. Refresh and try again.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.submitLeaveApplication(
        LeaveApplicationRequest(
          staffId: _staffId,
          leaveTypeId: _leaveTypeId,
          fromDate: teacherFlowDate(_fromDate),
          toDate: teacherFlowDate(_toDate),
          halfDay: _halfDay,
          reason: _reasonController.text.trim(),
        ),
      );
      if (mounted) {
        Navigator.pop(
          context,
          const TeacherLeaveRequestResult('Leave request submitted'),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingContext) {
      return const TeacherFlowScaffold(
        title: 'Apply Leave',
        subtitle: 'Loading teacher leave context',
        selectedIndex: 10,
        loading: true,
        child: SizedBox.shrink(),
      );
    }
    final leaveTypeOptions = _selectableLeaveTypes();
    final selectedLeaveTypeId =
        leaveTypeOptions.any((type) => _leaveTypeIdFrom(type) == _leaveTypeId)
        ? _leaveTypeId
        : null;
    final hasLeaveTypes = leaveTypeOptions.isNotEmpty;
    return TeacherFlowScaffold(
      title: 'Apply Leave',
      subtitle: 'Submit leave for principal approval',
      selectedIndex: 10,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Leave application',
            classLabel: _staffName.isEmpty
                ? RoleAccessService.teacherName
                : _staffName,
            subject: 'Approval required',
            timeLabel: _halfDay ? 'Half day' : 'Full day',
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (hasLeaveTypes) ...[
                  DropdownButtonFormField<String>(
                    value: selectedLeaveTypeId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Leave type',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: leaveTypeOptions
                        .map(
                          (type) => DropdownMenuItem(
                            value: _leaveTypeIdFrom(type),
                            child: Text(_leaveTypeName(type)),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        (value ?? '').isEmpty ? 'Select leave type.' : null,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _leaveTypeId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fromDateController,
                        readOnly: true,
                        style: const TextStyle(overflow: TextOverflow.visible),
                        decoration: const InputDecoration(
                          labelText: 'From date',
                          hintText: 'DD MMM YYYY',
                          prefixIcon: Icon(Icons.event_rounded),
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                          isDense: true,
                        ),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ? 'Required' : null,
                        onTap: _saving
                            ? null
                            : () => _pickDateField(isFrom: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _toDateController,
                        readOnly: true,
                        style: const TextStyle(overflow: TextOverflow.visible),
                        decoration: const InputDecoration(
                          labelText: 'To date',
                          hintText: 'DD MMM YYYY',
                          prefixIcon: Icon(Icons.event_available_rounded),
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                          isDense: true,
                        ),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ? 'Required' : null,
                        onTap: _saving
                            ? null
                            : () => _pickDateField(isFrom: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _halfDay,
                  title: const Text('Permission hours / half day'),
                  subtitle: const Text('Use for short leave requests'),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _halfDay = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Enter reason.' : null,
                ),
                const SizedBox(height: 12),
                if (hasLeaveTypes)
                  _BalancePreview(
                    leaveTypeId: _leaveTypeId,
                    balances: _balances,
                  ),
                if (_error != null) ...[
                  SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: context.appTheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_saving ? 'Submitting...' : 'Submit Leave'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _selectableLeaveTypes() {
    return _leaveTypes
        .where((type) => _leaveTypeIdFrom(type).isNotEmpty)
        .toList(growable: false);
  }

  String _firstLeaveTypeId([List<Map<String, dynamic>>? types]) {
    for (final type in types ?? _selectableLeaveTypes()) {
      final id = _leaveTypeIdFrom(type);
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  Future<void> _pickDateField({required bool isFrom}) async {
    final initial = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        _fromDateController.text = _displayDate(picked);
        // If to-date is now before from-date, push it forward
        if (_toDate.isBefore(picked)) {
          _toDate = picked;
          _toDateController.text = _displayDate(picked);
        }
      } else {
        _toDate = picked;
        _toDateController.text = _displayDate(picked);
      }
    });
  }

  Future<void> _loadMissingContext() async {
    try {
      await RoleAccessService.initialize();
      final dashboard = _staffId.isEmpty || _staffName.isEmpty
          ? await BackendApiClient.instance.getDashboard('teacher')
          : const <String, dynamic>{};
      final staffId = _staffId.isEmpty
          ? _resolveStaffIdFromDashboard(dashboard)
          : _staffId;
      final staffName = _staffName.isEmpty
          ? teacherFlowText(
              dashboard['staff_name'] ??
                  dashboard['teacher_name'] ??
                  dashboard['name'],
              fallback: RoleAccessService.teacherName,
            )
          : _staffName;
      final rawTypes = _leaveTypes.isEmpty
          ? await BackendApiClient.instance.getLeaveTypes()
          : _leaveTypes;
      final types = rawTypes
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      var balances = _balances;
      if (_balances.isEmpty && staffId.isNotEmpty) {
        try {
          balances = await BackendApiClient.instance.getLeaveBalances(
            staffId: staffId,
          );
        } catch (_) {
          balances = const [];
        }
      }
      final selectableTypes = types
          .where((type) => _leaveTypeIdFrom(type).isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _staffId = staffId;
        _staffName = staffName;
        _leaveTypes = types;
        _balances = balances;
        _leaveTypeId =
            selectableTypes.any(
              (type) => _leaveTypeIdFrom(type) == _leaveTypeId,
            )
            ? _leaveTypeId
            : _firstLeaveTypeId(selectableTypes);
        _loadingContext = false;
        if (_staffId.isEmpty) {
          _error = 'Teacher profile is still syncing. Refresh and try again.';
        }
      });
      return;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingContext = false;
        _error = error.toString();
      });
    }
  }

  String _resolveStaffIdFromDashboard(Map<String, dynamic> dashboard) {
    return teacherFlowText(
      RoleAccessService.teacherStaffId.isNotEmpty
          ? RoleAccessService.teacherStaffId
          : dashboard['staff_id'] ??
                dashboard['teacher_id'] ??
                dashboard['id'] ??
                dashboard['linked_id'],
    );
  }

  String _leaveTypeIdFrom(Map<String, dynamic> type) {
    return teacherFlowText(
      type['id'] ?? type['leave_type_id'] ?? type['leave_id'] ?? type['code'],
    );
  }

  String _leaveTypeName(Map<String, dynamic> type) {
    return teacherFlowText(
      type['leave_name'] ??
          type['name'] ??
          type['leave_type'] ??
          type['type_name'],
      fallback: teacherFlowText(
        type['id'] ?? type['leave_type_id'],
        fallback: teacherFlowText(
          type['leave_id'] ?? type['code'],
          fallback: 'Leave',
        ),
      ),
    );
  }

  String? _validateLeaveRequest() {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final fromOnly = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final toOnly = DateTime(_toDate.year, _toDate.month, _toDate.day);
    if (fromOnly.isBefore(todayOnly)) {
      return 'Leave cannot start before today.';
    }
    if (toOnly.isBefore(fromOnly)) {
      return 'To date cannot be before from date.';
    }
    final requestedDays = _halfDay
        ? 0.5
        : toOnly.difference(fromOnly).inDays.toDouble() + 1;
    final remaining = _remainingDaysFor(_leaveTypeId);
    if (remaining != null && requestedDays > remaining) {
      return 'Requested leave exceeds available balance.';
    }
    return null;
  }

  double? _remainingDaysFor(String leaveTypeId) {
    for (final row in _balances) {
      if (teacherFlowText(row['leave_type_id']) != leaveTypeId) continue;
      final raw = row['remaining_days'] ?? row['balance'];
      if (raw is num) return raw.toDouble();
      return double.tryParse('$raw'.trim());
    }
    return null;
  }
}

class _BalancePreview extends StatelessWidget {
  final String leaveTypeId;
  final List<Map<String, dynamic>> balances;

  const _BalancePreview({required this.leaveTypeId, required this.balances});

  @override
  Widget build(BuildContext context) {
    final match = balances.where(
      (row) => teacherFlowText(row['leave_type_id']) == leaveTypeId,
    );
    final row = match.isEmpty ? const <String, dynamic>{} : match.first;
    return TeacherFlowCard(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Leave Balance',
      subtitle: row.isEmpty
          ? 'Balance will be verified by backend during approval.'
          : '${teacherFlowText(row['remaining_days'] ?? row['balance'], fallback: '0')} day(s) remaining',
      status: 'Live',
      statusColor: teacherFlowAccent,
    );
  }
}

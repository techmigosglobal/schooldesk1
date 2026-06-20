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

  bool get _missingRequiredContext =>
      _staffId.trim().isEmpty || _leaveTypes.isEmpty;

  @override
  void initState() {
    super.initState();
    final tomorrow = teacherFlowDate(
      DateTime.now().add(const Duration(days: 1)),
    );
    _fromDateController = TextEditingController(text: tomorrow);
    _toDateController = TextEditingController(text: tomorrow);
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
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.submitLeaveApplication(
        LeaveApplicationRequest(
          staffId: _staffId,
          leaveTypeId: _leaveTypeId,
          fromDate: _fromDateController.text.trim(),
          toDate: _toDateController.text.trim(),
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
    if (_missingRequiredContext) {
      return TeacherFlowScaffold(
        title: 'Apply Leave',
        subtitle: 'Teacher module context required',
        selectedIndex: 10,
        child: TeacherFlowScrollView(
          children: [
            TeacherFlowCard(
              icon: Icons.info_outline_rounded,
              title: 'Open from Teacher module',
              subtitle:
                  'Please open this screen from the related Teacher module.',
              body: TeacherFlowActionWrap(
                actions: [
                  TeacherFlowAction(
                    label: 'Back',
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.maybePop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return TeacherFlowScaffold(
      title: 'Apply Leave',
      subtitle: 'Submit leave for admin review',
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
                DropdownButtonFormField<String>(
                  value: _leaveTypeId.isEmpty ? null : _leaveTypeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Leave type',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: _leaveTypes
                      .where((type) => _leaveTypeIdFrom(type).isNotEmpty)
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fromDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'From date',
                          hintText: 'YYYY-MM-DD',
                          prefixIcon: Icon(Icons.event_rounded),
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ? 'Required' : null,
                        onTap: _saving ? null : () => _pickDate(_fromDateController),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _toDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'To date',
                          hintText: 'YYYY-MM-DD',
                          prefixIcon: Icon(Icons.event_available_rounded),
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ? 'Required' : null,
                        onTap: _saving ? null : () => _pickDate(_toDateController),
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
                _BalancePreview(leaveTypeId: _leaveTypeId, balances: _balances),
                if (_error != null) ...[
                  SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: context.appTheme.error),
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

  String _firstLeaveTypeId() {
    for (final type in _leaveTypes) {
      final id = _leaveTypeIdFrom(type);
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text.trim()) ??
        DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    controller.text = teacherFlowDate(picked);
    if (controller == _fromDateController &&
        DateTime.tryParse(_toDateController.text.trim())?.isBefore(picked) ==
            true) {
      _toDateController.text = teacherFlowDate(picked);
    }
  }

  Future<void> _loadMissingContext() async {
    try {
      await RoleAccessService.initialize();
      final staffId = _staffId.isEmpty
          ? RoleAccessService.teacherStaffId
          : _staffId;
      final types = _leaveTypes.isEmpty
          ? await BackendApiClient.instance.getLeaveTypes()
          : _leaveTypes;
      final balances = _balances.isEmpty && staffId.isNotEmpty
          ? await BackendApiClient.instance.getLeaveBalances(staffId: staffId)
          : _balances;
      if (!mounted) return;
      setState(() {
        _staffId = staffId;
        _staffName = _staffName.isEmpty
            ? RoleAccessService.teacherName
            : _staffName;
        _leaveTypes = types;
        _balances = balances;
        _leaveTypeId = _firstLeaveTypeId();
        _loadingContext = false;
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

  String _leaveTypeIdFrom(Map<String, dynamic> type) {
    return teacherFlowText(type['id'] ?? type['leave_type_id']);
  }

  String _leaveTypeName(Map<String, dynamic> type) {
    return teacherFlowText(
      type['leave_name'] ??
          type['name'] ??
          type['leave_type'] ??
          type['type_name'],
      fallback: teacherFlowText(
        type['id'] ?? type['leave_type_id'],
        fallback: 'Leave',
      ),
    );
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

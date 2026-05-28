import 'package:flutter/material.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/teacher_flow_ui.dart';

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
  bool _halfDay = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tomorrow = teacherFlowDate(
      DateTime.now().add(const Duration(days: 1)),
    );
    _fromDateController = TextEditingController(text: tomorrow);
    _toDateController = TextEditingController(text: tomorrow);
    _leaveTypeId = _firstLeaveTypeId();
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
          staffId: widget.args.staffId,
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
    return TeacherFlowScaffold(
      title: 'Apply Leave',
      subtitle: 'Submit leave for admin review',
      selectedIndex: 10,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Leave application',
            classLabel: widget.args.staffName,
            subject: 'Approval required',
            timeLabel: _halfDay ? 'Half day' : 'Full day',
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _leaveTypeId.isEmpty ? null : _leaveTypeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Leave type',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: widget.args.leaveTypes
                      .where((type) => teacherFlowText(type['id']).isNotEmpty)
                      .map(
                        (type) => DropdownMenuItem(
                          value: teacherFlowText(type['id']),
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
                        decoration: const InputDecoration(
                          labelText: 'From date',
                          hintText: 'YYYY-MM-DD',
                          prefixIcon: Icon(Icons.event_rounded),
                        ),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _toDateController,
                        decoration: const InputDecoration(
                          labelText: 'To date',
                          hintText: 'YYYY-MM-DD',
                          prefixIcon: Icon(Icons.event_available_rounded),
                        ),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ? 'Required' : null,
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
                _BalancePreview(
                  leaveTypeId: _leaveTypeId,
                  balances: widget.args.balances,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppTheme.error)),
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
    for (final type in widget.args.leaveTypes) {
      final id = teacherFlowText(type['id']);
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  String _leaveTypeName(Map<String, dynamic> type) {
    return teacherFlowText(
      type['name'] ?? type['leave_type'] ?? type['type_name'],
      fallback: teacherFlowText(type['id'], fallback: 'Leave'),
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

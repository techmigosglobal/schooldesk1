import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_components.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/teacher_navigation.dart';

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

  bool get _ready =>
      widget.args.staffId.trim().isNotEmpty &&
      widget.args.leaveTypes.any((type) => _text(type['id']).isNotEmpty);

  @override
  void initState() {
    super.initState();
    final tomorrow = _dateInput(DateTime.now().add(const Duration(days: 1)));
    _fromDateController = TextEditingController(text: tomorrow);
    _toDateController = TextEditingController(text: tomorrow);
    _leaveTypeId = _initialLeaveTypeId();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Apply Leave',
      subtitle: 'Submit a teacher leave request for approval',
      drawer: TeacherDrawer(selectedIndex: 10, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.teacher,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_ready)
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _staffContext(),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _leaveTypeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Leave type'),
                    items: widget.args.leaveTypes
                        .where((type) => _text(type['id']).isNotEmpty)
                        .map(
                          (type) => DropdownMenuItem(
                            value: _text(type['id']),
                            child: Text(
                              _leaveTypeName(type),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        _required(value, 'Select leave type.'),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _leaveTypeId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  _selectedBalanceCard(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField(
                          controller: _fromDateController,
                          label: 'From date',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateField(
                          controller: _toDateController,
                          label: 'To date',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _halfDay,
                    contentPadding: EdgeInsets.zero,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _halfDay = value;
                            if (value) {
                              _toDateController.text = _fromDateController.text;
                            }
                          }),
                    title: Text(
                      'Half-day leave',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _reasonController,
                    enabled: !_saving,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      hintText: 'Write the reason for this leave request',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().length < 5) {
                        return 'Enter a clear reason.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_saving ? 'Submitting...' : 'Submit Request'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back to Leave History'),
                  ),
                ],
              ),
            )
          else
            const SchoolDeskStatusPanel.empty(
              title: 'Teacher leave setup required',
              message:
                  'A linked staff profile and backend leave types are required before a teacher can apply for leave.',
            ),
          const SizedBox(height: 84),
        ],
      ),
    );
  }

  Widget _staffContext() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.args.staffName.trim().isEmpty
                      ? 'Current teacher'
                      : widget.args.staffName,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Staff ID: ${widget.args.staffId}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedBalanceCard() {
    final balance = _balanceForType(_leaveTypeId);
    if (balance.isEmpty) {
      return _softPanel(
        'No balance row exists for this leave type yet. The backend will still validate staff and leave type access.',
      );
    }
    final total = _number(balance['total_entitled']);
    final used = _number(balance['used_days']);
    final pending = _number(balance['pending_days']);
    final remaining = _number(balance['remaining_days']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.infoContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.info.withAlpha(70)),
      ),
      child: Wrap(
        runSpacing: 8,
        spacing: 16,
        children: [
          _metric('Entitled', _days(total)),
          _metric('Used', _days(used)),
          _metric('Pending', _days(pending)),
          _metric('Remaining', _days(remaining)),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              color: AppTheme.info,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _dateField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(labelText: label, helperText: 'YYYY-MM-DD'),
      validator: _dateValidator,
      onChanged: (value) {
        if (_halfDay && controller == _fromDateController) {
          _toDateController.text = value;
        }
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final from = DateTime.parse(_fromDateController.text.trim());
    final to = DateTime.parse(_toDateController.text.trim());
    if (to.isBefore(from)) {
      _showError('To date cannot be before from date.');
      return;
    }
    if (_halfDay && _fromDateController.text != _toDateController.text) {
      _showError('Half-day leave must start and end on the same date.');
      return;
    }
    setState(() => _saving = true);
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
      if (!mounted) return;
      Navigator.pop(
        context,
        const TeacherLeaveRequestResult('Leave request submitted for approval'),
      );
    } catch (error) {
      _showError('Leave request failed: ${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _initialLeaveTypeId() {
    final withBalance = widget.args.balances
        .map((balance) => _text(balance['leave_type_id']))
        .firstWhere((id) => id.isNotEmpty, orElse: () => '');
    if (withBalance.isNotEmpty) return withBalance;
    return widget.args.leaveTypes
        .map((type) => _text(type['id']))
        .firstWhere((id) => id.isNotEmpty, orElse: () => '');
  }

  Map<String, dynamic> _balanceForType(String leaveTypeId) {
    return widget.args.balances.firstWhere(
      (balance) => _text(balance['leave_type_id']) == leaveTypeId,
      orElse: () => const <String, dynamic>{},
    );
  }

  String _leaveTypeName(Map<String, dynamic> type) {
    return _text(type['leave_name'], fallback: _text(type['name']));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }
}

Widget _softPanel(String message) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.surfaceVariant,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      message,
      style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
    ),
  );
}

String? _required(String? value, String message) {
  if (value == null || value.trim().isEmpty) return message;
  return null;
}

String? _dateValidator(String? value) {
  final text = (value ?? '').trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return 'Use YYYY-MM-DD.';
  }
  return DateTime.tryParse(text) == null ? 'Enter a valid date.' : null;
}

String _dateInput(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _text(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

String _days(double value) {
  final formatted = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$formatted day${value == 1 ? '' : 's'}';
}

String _cleanError(Object error) {
  final raw = error.toString();
  final server = RegExp(r'ServerException\([^)]*\):\s*(.*)').firstMatch(raw);
  if (server != null) return server.group(1)?.trim() ?? raw;
  final network = RegExp(r'NetworkException\([^)]*\):\s*(.*)').firstMatch(raw);
  if (network != null) return network.group(1)?.trim() ?? raw;
  return raw.replaceFirst('Exception: ', '').trim();
}

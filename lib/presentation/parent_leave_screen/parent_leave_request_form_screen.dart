import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/parent_navigation.dart';

class ParentLeaveRequestFormArgs {
  final List<Map<String, dynamic>> children;
  final String initialStudentId;
  final String? initialLeaveType;

  const ParentLeaveRequestFormArgs({
    required this.children,
    required this.initialStudentId,
    this.initialLeaveType,
  });
}

class ParentLeaveRequestFormScreen extends StatefulWidget {
  final ParentLeaveRequestFormArgs args;

  const ParentLeaveRequestFormScreen({super.key, required this.args});

  @override
  State<ParentLeaveRequestFormScreen> createState() =>
      _ParentLeaveRequestFormScreenState();
}

class _ParentLeaveRequestFormScreenState
    extends State<ParentLeaveRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  late final TextEditingController _fromDateController;
  late final TextEditingController _toDateController;
  String _selectedStudentId = '';
  String _selectedLeaveType = 'Sick Leave';
  bool _halfDay = false;
  bool _submitting = false;
  int _selectedNavIndex = 7;

  static const _leaveTypes = [
    'Sick Leave',
    'Personal Leave',
    'Early Pickup',
    'Special Permission',
  ];

  @override
  void initState() {
    super.initState();
    final today = _dateInput(DateTime.now());
    _fromDateController = TextEditingController(text: today);
    _toDateController = TextEditingController(text: today);
    _selectedStudentId = widget.args.initialStudentId;
    if (_selectedStudentId.isEmpty && widget.args.children.isNotEmpty) {
      _selectedStudentId = widget.args.children.first['id']?.toString() ?? '';
    }
    final incomingType = widget.args.initialLeaveType;
    if (incomingType != null && _leaveTypes.contains(incomingType)) {
      _selectedLeaveType = incomingType;
    }
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
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    return SchoolDeskModuleScaffold(
      title: 'Submit Leave Request',
      subtitle: 'Create a student leave request for school approval',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStudentDropdown(),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedLeaveType,
              decoration: const InputDecoration(labelText: 'Leave type'),
              items: _leaveTypes
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type, style: GoogleFonts.dmSans()),
                    ),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedLeaveType = value);
                      }
                    },
            ),
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
              onChanged: _submitting
                  ? null
                  : (value) => setState(() {
                      _halfDay = value;
                      if (value) {
                        _toDateController.text = _fromDateController.text;
                      }
                    }),
              contentPadding: EdgeInsets.zero,
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
              enabled: !_submitting,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Write the reason for this leave request',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 5) {
                  return 'Enter a clear reason';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submitting || widget.args.children.isEmpty
                  ? null
                  : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _submitting ? 'Submitting...' : 'Submit Request',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(
                'Back to Leave Requests',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentDropdown() {
    if (widget.args.children.isEmpty) {
      return Text(
        'No linked students are available for this account.',
        style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.error),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedStudentId,
      decoration: const InputDecoration(labelText: 'Student'),
      items: widget.args.children
          .map(
            (child) => DropdownMenuItem(
              value: child['id']?.toString() ?? '',
              child: Text(_studentLabel(child), style: GoogleFonts.dmSans()),
            ),
          )
          .toList(),
      validator: (value) {
        if ((value ?? '').isEmpty) return 'Select a student';
        return null;
      },
      onChanged: _submitting
          ? null
          : (value) {
              if (value != null) setState(() => _selectedStudentId = value);
            },
    );
  }

  Widget _dateField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_submitting && (!_halfDay || label == 'From date'),
      keyboardType: TextInputType.datetime,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(labelText: label, hintText: 'YYYY-MM-DD'),
      validator: (value) {
        final raw = (value ?? '').trim();
        if (raw.isEmpty) return 'Required';
        if (!_isIsoDate(raw)) return 'Use YYYY-MM-DD';
        return null;
      },
      onChanged: (value) {
        if (_halfDay && label == 'From date') {
          _toDateController.text = value;
        }
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final fromDate = _fromDateController.text.trim();
    final toDate = _toDateController.text.trim();
    final from = DateTime.tryParse(fromDate);
    final to = DateTime.tryParse(toDate);
    if (from == null || to == null || to.isBefore(from)) {
      _showError('To date must be on or after from date.');
      return;
    }
    if (_halfDay && fromDate != toDate) {
      _showError('Half-day leave must use the same from and to date.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await BackendApiClient.instance.submitStudentLeaveApplication(
        studentId: _selectedStudentId,
        leaveType: _selectedLeaveType,
        fromDate: fromDate,
        toDate: toDate,
        halfDay: _halfDay,
        reason: _reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request submitted for approval'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(error.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _studentLabel(Map<String, dynamic> row) {
    final explicit = row['name'] ?? row['full_name'] ?? row['student_name'];
    final first = row['first_name']?.toString().trim() ?? '';
    final last = row['last_name']?.toString().trim() ?? '';
    final name = (explicit?.toString().trim().isNotEmpty ?? false)
        ? explicit.toString().trim()
        : [first, last].where((part) => part.isNotEmpty).join(' ');
    final classLabel =
        [
              row['class'] ?? row['grade_name'],
              row['section'] ?? row['section_name'],
            ]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .join(' ');
    if (classLabel.isEmpty) return name.isEmpty ? 'Student' : name;
    return '${name.isEmpty ? 'Student' : name} - $classLabel';
  }

  bool _isIsoDate(String raw) {
    final match = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw);
    return match && DateTime.tryParse(raw) != null;
  }

  String _dateInput(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

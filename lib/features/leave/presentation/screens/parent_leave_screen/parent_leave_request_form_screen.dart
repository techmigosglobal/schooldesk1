import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/parent_child_selector.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_leave_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_leave_repository.dart';

class ParentLeaveRequestFormArgs {
  final List<Map<String, dynamic>> children;
  final String initialStudentId;
  final String? initialLeaveType;
  final List<Map<String, dynamic>> leaveTypes;
  final ParentLeaveRepository? repository;

  const ParentLeaveRequestFormArgs({
    required this.children,
    required this.initialStudentId,
    this.leaveTypes = const [],
    this.initialLeaveType,
    this.repository,
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
  String _selectedLeaveType = '';
  List<String> _leaveTypes = [];
  RepositoryState<List<String>> _leaveTypeState =
      const RepositoryState.loading();
  RepositoryState<Object> _submitState = const RepositoryState.empty();

  bool get _loadingLeaveTypes => _leaveTypeState.isLoading;
  bool get _submitting => _submitState.isRefreshing;
  String? _leaveTypeNotice;
  bool _halfDay = false;
  int _selectedNavIndex = ParentNav.leave;

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
    if (widget.args.leaveTypes.isNotEmpty) {
      _leaveTypes = widget.args.leaveTypes
          .map(_leaveTypeLabel)
          .where((label) => label.isNotEmpty)
          .toSet()
          .toList();
    }
    _loadLeaveTypes();
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
      body: SchoolDeskRepositoryStateView<List<String>>(
        state: _leaveTypeState,
        onRetry: _loadLeaveTypes,
        errorTitle: 'Unable to load leave types',
        emptyTitle: 'No leave types configured',
        emptyMessage:
            _leaveTypeNotice ??
            'The school has not configured leave types for parent requests.',
        data: (_) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStudentDropdown(),
              const SizedBox(height: 14),
              _buildLeaveTypeDropdown(),
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
                onPressed:
                    _submitting ||
                        _loadingLeaveTypes ||
                        _leaveTypes.isEmpty ||
                        widget.args.children.isEmpty
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
      ),
    );
  }

  Widget _buildStudentDropdown() {
    if (widget.args.children.isEmpty) {
      return Text(
        'No linked students are available for this account.',
        style: GoogleFonts.dmSans(fontSize: 13, color: context.appTheme.error),
      );
    }
    final selectedIndex = widget.args.children.indexWhere(
      (child) => child['id']?.toString() == _selectedStudentId,
    );
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Student'),
      child: ParentChildSelector(
        children: widget.args.children,
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        isLoading: _submitting,
        onSelected: (index) => setState(
          () => _selectedStudentId =
              widget.args.children[index]['id']?.toString() ?? '',
        ),
      ),
    );
  }

  Widget _buildLeaveTypeDropdown() {
    if (_loadingLeaveTypes) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: 'Leave type'),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading leave types...',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: context.appTheme.muted,
              ),
            ),
          ],
        ),
      );
    }
    final leaveTypes = _leaveTypes;
    if (leaveTypes.isEmpty) {
      return Text(
        _leaveTypeNotice ?? 'No school leave types are configured.',
        style: GoogleFonts.dmSans(
          fontSize: 13,
          color: context.appTheme.onSurfaceVariant,
        ),
      );
    }
    final selectedValue = leaveTypes.contains(_selectedLeaveType)
        ? _selectedLeaveType
        : leaveTypes.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedValue,
          decoration: const InputDecoration(labelText: 'Leave type'),
          items: leaveTypes
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(type, style: GoogleFonts.dmSans()),
                ),
              )
              .toList(),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) return 'Select a leave type';
            return null;
          },
          onChanged: _submitting
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => _selectedLeaveType = value);
                  }
                },
        ),
        if (_leaveTypeNotice != null) ...[
          const SizedBox(height: 6),
          Text(
            _leaveTypeNotice!,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.appTheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _dateField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_submitting && (!_halfDay || label == 'From date'),
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_rounded),
      ),
      onTap: _submitting || (_halfDay && label != 'From date')
          ? null
          : () => _pickDate(controller: controller, label: label),
      validator: (value) {
        final raw = (value ?? '').trim();
        if (raw.isEmpty) return 'Required';
        if (!_isIsoDate(raw)) return 'Use YYYY-MM-DD';
        return null;
      },
    );
  }

  Future<void> _pickDate({
    required TextEditingController controller,
    required String label,
  }) async {
    final current = DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    final value = _dateInput(picked);
    setState(() {
      controller.text = value;
      if (_halfDay && label == 'From date') {
        _toDateController.text = value;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final selectedLeaveType = _selectedLeaveType.trim();
    if (selectedLeaveType.isEmpty) {
      _showError('No school leave type is available. Connect and retry.');
      return;
    }
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
    setState(() {
      _submitState = const RepositoryState<Object>.loading(
        data: Object(),
        source: RepositorySource.localMutation,
        isRefreshing: true,
      );
    });
    try {
      final result =
          await (widget.args.repository ??
                  ApiParentLeaveRepository.legacyDefault)
              .submitRequest(
                studentId: _selectedStudentId,
                leaveType: selectedLeaveType,
                fromDate: fromDate,
                toDate: toDate,
                halfDay: _halfDay,
                reason: _reasonController.text.trim(),
              );
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to submit leave request',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request submitted for approval'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _submitState = RepositoryState<Object>.error(error: error);
      });
      _showError(error.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.appTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadLeaveTypes() async {
    if (widget.args.leaveTypes.isNotEmpty) {
      final incomingType = widget.args.initialLeaveType?.trim();
      if (mounted) {
        setState(() {
          _selectedLeaveType =
              incomingType != null && _leaveTypes.contains(incomingType)
              ? incomingType
              : _leaveTypes.first;
          _leaveTypeState = RepositoryState<List<String>>(
            data: _leaveTypes,
            source: RepositorySource.remote,
            phase: _leaveTypes.isEmpty
                ? RepositoryPhase.empty
                : RepositoryPhase.ready,
          );
        });
      }
      return;
    }
    try {
      final result =
          await (widget.args.repository ??
                  ApiParentLeaveRepository.legacyDefault)
              .getLeaveTypes();
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to load school leave types',
        );
      }
      final rows = result.dataOrNull!;
      final configuredLabels = rows
          .map(_leaveTypeLabel)
          .where((label) {
            return label.trim().isNotEmpty;
          })
          .toSet()
          .toList();
      final incomingType = widget.args.initialLeaveType?.trim();
      if (!mounted) return;
      setState(() {
        _leaveTypes = configuredLabels;
        _selectedLeaveType =
            incomingType != null && configuredLabels.contains(incomingType)
            ? incomingType
            : configuredLabels.firstOrNull ?? '';
        _leaveTypeState = RepositoryState<List<String>>(
          data: configuredLabels,
          source: RepositorySource.remote,
          phase: configuredLabels.isEmpty
              ? RepositoryPhase.empty
              : RepositoryPhase.ready,
        );
        _leaveTypeNotice = configuredLabels.isEmpty
            ? 'No school leave types are configured for parent requests.'
            : null;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _leaveTypes = const [];
        _selectedLeaveType = '';
        _leaveTypeState = const RepositoryState<List<String>>.error(
          error: 'Unable to load school leave types. Connect and retry.',
        );
        _leaveTypeNotice =
            'Unable to load school leave types. Connect and retry.';
      });
    }
  }

  String _leaveTypeLabel(Map<String, dynamic> row) {
    for (final key in const ['leave_name', 'name', 'leave_type', 'type']) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
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

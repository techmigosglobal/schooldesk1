import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/operations_workspace.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

enum _FinanceView { structures, invoices, payments, concessions, reports }

class AdminFeesScreen extends StatefulWidget {
  const AdminFeesScreen({super.key});

  @override
  State<AdminFeesScreen> createState() => _AdminFeesScreenState();
}

class _AdminFeesScreenState extends State<AdminFeesScreen> {
  bool _loading = true;
  String? _error;
  _FinanceView _view = _FinanceView.invoices;

  List<Map<String, dynamic>> _feeStructures = [];
  List<Map<String, dynamic>> _pendingDues = [];
  List<Map<String, dynamic>> _recentPayments = [];
  List<Map<String, dynamic>> _feeCategories = [];
  List<Map<String, dynamic>> _concessions = [];
  List<AcademicYearModel> _academicYears = [];
  List<GradeModel> _grades = [];
  List<SectionModel> _sections = [];
  List<StudentModel> _students = [];
  Map<String, dynamic> _paymentConfig = const {};
  final _upiIdController = TextEditingController();
  final _payeeNameController = TextEditingController();
  final _qrNoteController = TextEditingController();
  bool _savingPaymentConfig = false;
  bool _uploadingQr = false;

  String _paymentSearchQuery = '';
  String _paymentModeFilter = 'All';
  String _paymentStatusFilter = 'All';
  DateTime? _paymentDateFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _payeeNameController.dispose();
    _qrNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final feeStructures = await api.getFeeStructures();
      final invoices = await api.getInvoices();
      final feeCategories = await api.getRawList('/fees/categories');
      final concessions = await api.getRawList('/fees/concessions');
      final paymentConfig = await api.getPaymentConfig();
      final academicYears = await api.getAcademicYears();
      final grades = await api.getGrades();
      final sections = await api.getSections();
      final students = await api.getStudents(page: 1, pageSize: 500);
      final normalizedInvoices = invoices.map(_normalizeInvoice).toList();
      if (!mounted) return;
      setState(() {
        _feeStructures = feeStructures.map(_normalizeFeeStructure).toList();
        _feeCategories = feeCategories;
        _concessions = concessions;
        _paymentConfig = paymentConfig;
        _upiIdController.text = _textValue(paymentConfig['upi_id']);
        _payeeNameController.text = _textValue(paymentConfig['payee_name']);
        _qrNoteController.text = _textValue(paymentConfig['qr_note']);
        _academicYears = academicYears;
        _grades = grades;
        _sections = sections;
        _students = students.data;
        _pendingDues = normalizedInvoices
            .where((invoice) => _numValue(invoice['balance']) > 0)
            .toList();
        _recentPayments = invoices.expand(_normalizePayments).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load finance workspace from backend. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Finance Operations',
      subtitle:
          'Structures, invoices, payments, concessions, receipts, and reconciliation',
      drawer: AdminDrawer(selectedIndex: 4, onDestinationSelected: (_) {}),
      railBreakpoint: double.infinity,
      navigationDrawerEnabled: false,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      actions: [
        IconButton(
          tooltip: 'Prepare fee structure request',
          icon: const Icon(Icons.add_card_outlined),
          onPressed: _openCreateFeeStructureForm,
        ),
        IconButton(
          tooltip: 'Submit invoice request for approval',
          icon: const Icon(Icons.receipt_long_outlined),
          onPressed: () => _openGenerateInvoiceForm(),
        ),
        IconButton(
          tooltip: 'Refresh finance',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return OpsEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Finance unavailable',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _loadData,
      );
    }
    return OpsWorkspace(
      children: [
        OpsResponsiveGrid(
          minTileWidth: 210,
          children: [
            OpsMetricCard(
              label: 'Fee structures',
              value: '${_feeStructures.length}',
              icon: Icons.price_change_outlined,
              color: Colors.indigo,
              caption: '/fees/structures',
            ),
            OpsMetricCard(
              label: 'Outstanding',
              value: _money(_pendingTotal),
              icon: Icons.pending_actions_outlined,
              color: Colors.orange,
              caption: '${_pendingDues.length} invoices',
            ),
            OpsMetricCard(
              label: 'Collected',
              value: _money(_collectedTotal),
              icon: Icons.payments_outlined,
              color: Colors.green,
              caption: '${_recentPayments.length} payments',
            ),
            OpsMetricCard(
              label: 'Concessions',
              value: '${_concessions.length}',
              icon: Icons.volunteer_activism_outlined,
              color: Colors.deepPurple,
              caption: '/fees/concessions',
            ),
          ],
        ),
        _buildViewPicker(),
        _buildPaymentQrSettings(),
        _buildCurrentView(),
      ],
    );
  }

  Widget _buildPaymentQrSettings() {
    final qrImageUrl = _textValue(_paymentConfig['qr_image_url']);
    final upiEnabled = _paymentConfig['upi_enabled'] == true;
    return OpsPanel(
      title: 'Payment QR Settings',
      subtitle: upiEnabled
          ? 'Parents will see this QR on UPI payment requests'
          : 'Set a QR or UPI ID before parents submit UPI proofs',
      trailing: OpsStatusPill(
        label: upiEnabled ? 'Active' : 'Not Set',
        color: upiEnabled ? Colors.green : Colors.orange,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.appTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.appTheme.outlineVariant),
                ),
                child: qrImageUrl.isEmpty
                    ? Icon(
                        Icons.qr_code_2_rounded,
                        size: 64,
                        color: context.appTheme.muted,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _absoluteMediaUrl(qrImageUrl),
                          width: 140,
                          height: 140,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.broken_image_outlined,
                            color: context.appTheme.error,
                          ),
                        ),
                      ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _upiIdController,
                  enabled: !_savingPaymentConfig && !_uploadingQr,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _payeeNameController,
                  enabled: !_savingPaymentConfig && !_uploadingQr,
                  decoration: const InputDecoration(
                    labelText: 'Payee name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _qrNoteController,
                  enabled: !_savingPaymentConfig && !_uploadingQr,
                  decoration: const InputDecoration(
                    labelText: 'Payment note',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _savingPaymentConfig || _uploadingQr
                    ? null
                    : _savePaymentConfig,
                icon: _savingPaymentConfig
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _savingPaymentConfig ? 'Saving...' : 'Save Payment Details',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _savingPaymentConfig || _uploadingQr
                    ? null
                    : _pickPaymentQr,
                icon: _uploadingQr
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(_uploadingQr ? 'Uploading...' : 'Upload QR'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewPicker() {
    return OpsPanel(
      title: 'Admin Finance Workspace',
      subtitle:
          'Admin prepares finance requests; Principal final-approves decisions',
      trailing: TextButton.icon(
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.principalPaymentRequests),
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Payment requests'),
      ),
      child: OpsModeSelector<_FinanceView>(
        selected: _view,
        options: const [
          OpsModeOption(
            value: _FinanceView.structures,
            icon: Icons.price_change_outlined,
            label: 'Structures',
          ),
          OpsModeOption(
            value: _FinanceView.invoices,
            icon: Icons.receipt_long_outlined,
            label: 'Invoices',
          ),
          OpsModeOption(
            value: _FinanceView.payments,
            icon: Icons.payments_outlined,
            label: 'Payments',
          ),
          OpsModeOption(
            value: _FinanceView.concessions,
            icon: Icons.volunteer_activism_outlined,
            label: 'Concessions',
          ),
          OpsModeOption(
            value: _FinanceView.reports,
            icon: Icons.summarize_outlined,
            label: 'Reports',
          ),
        ],
        onSelected: (value) => setState(() => _view = value),
      ),
    );
  }

  Widget _buildCurrentView() {
    return switch (_view) {
      _FinanceView.structures => _buildStructures(),
      _FinanceView.invoices => _buildInvoices(),
      _FinanceView.payments => _buildPayments(),
      _FinanceView.concessions => _buildConcessions(),
      _FinanceView.reports => _buildReports(),
    };
  }

  Widget _buildStructures() {
    return OpsPanel(
      title: 'Fee Structures',
      subtitle: 'Class/category/frequency rules used to generate invoices',
      trailing: FilledButton.icon(
        onPressed: _openCreateFeeStructureForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Prepare Fee Structure Request'),
      ),
      child: _feeStructures.isEmpty
          ? OpsEmptyState(
              icon: Icons.price_change_outlined,
              title: 'No fee structures',
              message:
                  'Prepare fee structure requests before submitting student invoices.',
            )
          : Column(
              children: [
                for (final structure in _feeStructures)
                  OpsListRow(
                    icon: Icons.price_change_outlined,
                    title:
                        '${_textValue(structure['category'], fallback: 'Fee')} - ${_textValue(structure['class'], fallback: 'Class pending')}',
                    subtitle:
                        '${_money(_numValue(structure['amount']))} | ${_textValue(structure['frequency'], fallback: 'frequency pending')} | due day ${structure['due_day'] ?? '-'}',
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => _openEditFeeStructureForm(structure),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Prepare Update Request'),
                        ),
                        TextButton.icon(
                          onPressed: () => _deleteFeeStructure(structure),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Delete fee component'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildInvoices() {
    return OpsPanel(
      title: 'Invoices And Outstanding',
      subtitle:
          'Pending dues are derived from backend balance, not local status labels',
      trailing: FilledButton.icon(
        onPressed: () => _openGenerateInvoiceForm(),
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('Submit Invoice Request'),
      ),
      child: _pendingDues.isEmpty
          ? OpsListRow(
              icon: Icons.verified_outlined,
              title: 'No outstanding balances',
              subtitle:
                  'Backend invoice balances are clear for the current result set.',
              trailing: const OpsStatusPill(
                label: 'Clear',
                color: Colors.green,
              ),
            )
          : Column(
              children: [
                for (final invoice in _pendingDues.take(20))
                  OpsListRow(
                    icon: Icons.receipt_long_outlined,
                    title: _textValue(
                      invoice['name'],
                      fallback: 'Student invoice',
                    ),
                    subtitle:
                        '${_textValue(invoice['class'], fallback: 'Class pending')} | Due ${_dateLabel(invoice['due_date'])} | Paid ${_money(_numValue(invoice['paid']))}',
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        OpsStatusPill(
                          label: _money(_numValue(invoice['balance'])),
                          color: Colors.orange,
                        ),
                        IconButton(
                          tooltip: 'Submit payment for approval',
                          icon: const Icon(Icons.payments_outlined),
                          onPressed: () =>
                              _openRecordPaymentForm(invoice: invoice),
                        ),
                        IconButton(
                          tooltip: 'Send reminder',
                          icon: const Icon(Icons.notifications_active_outlined),
                          onPressed: () => _sendFeeReminder(invoice),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildPayments() {
    final filteredPayments = _recentPayments.where((payment) {
      if (_paymentSearchQuery.isNotEmpty) {
        final name = _textValue(payment['name']).toLowerCase();
        final txId = _textValue(payment['transaction_id']).toLowerCase();
        final query = _paymentSearchQuery.toLowerCase();
        if (!name.contains(query) && !txId.contains(query)) return false;
      }
      if (_paymentModeFilter != 'All' &&
          _textValue(payment['mode']) != _paymentModeFilter) {
        return false;
      }
      if (_paymentStatusFilter != 'All' &&
          _textValue(payment['status'], fallback: 'completed') !=
              _paymentStatusFilter) {
        return false;
      }
      if (_paymentDateFilter != null) {
        final date = DateTime.tryParse(_textValue(payment['date']));
        if (date == null ||
            date.year != _paymentDateFilter!.year ||
            date.month != _paymentDateFilter!.month ||
            date.day != _paymentDateFilter!.day) {
          return false;
        }
      }
      return true;
    }).toList();

    return OpsPanel(
      title: 'Payments And Receipts',
      subtitle:
          'Recorded payments and receipt preview stay tied to backend invoices',
      trailing: OutlinedButton.icon(
        onPressed: () => _openRecordPaymentForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Submit Payment Request'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPaymentFilters(),
          if (filteredPayments.isEmpty)
            OpsEmptyState(
              icon: Icons.payments_outlined,
              title: 'No payments found',
              message: 'No payments match the current filters.',
            )
          else
            ...filteredPayments
                .take(20)
                .map(
                  (payment) => OpsListRow(
                    icon: Icons.payments_outlined,
                    title: _textValue(payment['name'], fallback: 'Payment'),
                    subtitle:
                        'Txn: ${_textValue(payment['transaction_id'], fallback: 'N/A')} | ${_textValue(payment['mode'], fallback: 'Mode pending')} | ${_dateLabel(payment['date'])} | Status: ${_textValue(payment['status'], fallback: 'Completed')}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () => _previewReceipt(payment),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(_money(_numValue(payment['amount']))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download_outlined),
                          tooltip: 'Export Receipt',
                          onPressed: () => _exportReceipt(payment),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPaymentFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search Student/Txn',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _paymentSearchQuery = value),
            ),
          ),
          DropdownButton<String>(
            value: _paymentModeFilter,
            items: ['All', 'Cash', 'Card', 'UPI', 'Netbanking'].map((mode) {
              return DropdownMenuItem(value: mode, child: Text(mode));
            }).toList(),
            onChanged: (value) =>
                setState(() => _paymentModeFilter = value ?? 'All'),
            hint: const Text('Mode'),
          ),
          DropdownButton<String>(
            value: _paymentStatusFilter,
            items: ['All', 'completed', 'pending', 'failed', 'refunded'].map((
              status,
            ) {
              return DropdownMenuItem(value: status, child: Text(status));
            }).toList(),
            onChanged: (value) =>
                setState(() => _paymentStatusFilter = value ?? 'All'),
            hint: const Text('Status'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text(
              _paymentDateFilter == null
                  ? 'Select Date'
                  : _dateLabel(_paymentDateFilter!.toIso8601String()),
            ),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _paymentDateFilter ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _paymentDateFilter = date);
              }
            },
          ),
          if (_paymentSearchQuery.isNotEmpty ||
              _paymentModeFilter != 'All' ||
              _paymentStatusFilter != 'All' ||
              _paymentDateFilter != null)
            TextButton(
              onPressed: () => setState(() {
                _paymentSearchQuery = '';
                _paymentModeFilter = 'All';
                _paymentStatusFilter = 'All';
                _paymentDateFilter = null;
              }),
              child: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildConcessions() {
    return OpsPanel(
      title: 'Concessions',
      subtitle:
          'Review fee concessions without mixing them into invoice balances',
      child: _concessions.isEmpty
          ? OpsEmptyState(
              icon: Icons.volunteer_activism_outlined,
              title: 'No concession requests',
              message:
                  'Backend concession requests will appear here for finance review.',
            )
          : Column(
              children: [
                for (final concession in _concessions.take(20))
                  OpsListRow(
                    icon: Icons.volunteer_activism_outlined,
                    title: _textValue(
                      concession['student_name'] ?? concession['student_id'],
                      fallback: 'Concession request',
                    ),
                    subtitle:
                        '${_textValue(concession['reason'], fallback: 'Reason pending')} | ${_textValue(concession['status'], fallback: 'pending')}',
                    trailing: OpsStatusPill(
                      label: _textValue(
                        concession['status'],
                        fallback: 'Pending',
                      ),
                      color: _statusColor(_textValue(concession['status'])),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildReports() {
    final reports = [
      ('Collection summary', 'fee_collection_summary', 'pdf'),
      ('Outstanding aging', 'fee_outstanding_aging', 'csv'),
      ('Concession register', 'fee_concession_register', 'pdf'),
    ];
    return OpsPanel(
      title: 'Reports And Reconciliation',
      subtitle: 'Exports use typed report lifecycle artifacts',
      child: Column(
        children: [
          for (final report in reports)
            OpsListRow(
              icon: Icons.summarize_outlined,
              title: report.$1,
              subtitle:
                  'Submit ${report.$3.toUpperCase()} export request through /fees/reports/exports',
              trailing: FilledButton.icon(
                onPressed: () => _requestReportExport(report.$2, report.$3),
                icon: const Icon(Icons.file_download_outlined),
                label: Text(report.$3.toUpperCase()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openCreateFeeStructureForm() => _openFeeStructureForm();

  Future<void> _openEditFeeStructureForm(Map<String, dynamic> structure) =>
      _openFeeStructureForm(structure: structure);

  Future<void> _deleteFeeStructure(Map<String, dynamic> structure) async {
    final id = '${structure['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      _snack('Fee structure ID is missing.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete fee component?'),
        content: Text(
          'This removes ${_textValue(structure['category'], fallback: 'this fee component')} from ${_textValue(structure['class'], fallback: 'this class')}. Existing generated invoices and payments are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await BackendApiClient.instance.deleteRaw('/fees/structures/$id');
      if (!mounted) return;
      await _loadData();
      _snack('Fee component deleted.', success: true);
    } catch (error) {
      _snack('Unable to delete fee component: $error');
    }
  }

  Future<void> _openFeeStructureForm({Map<String, dynamic>? structure}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicYearFeesExport,
      arguments: AdminFeeStructureFormArgs(
        academicYears: _academicYears,
        grades: _grades,
        feeCategories: _feeCategories,
        feeStructure: structure,
      ),
    );
    if (!mounted || result is! AdminFeeStructureFormResult) return;
    await _loadData();
    _snack(result.message, success: true);
  }

  Future<void> _openGenerateInvoiceForm({Map<String, dynamic>? seed}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicYearFeesExport,
      arguments: AdminInvoiceGenerationFormArgs(
        academicYears: _academicYears,
        grades: _grades,
        sections: _sections,
        students: _students,
        feeStructures: _feeStructures,
        seedStructure: seed,
      ),
    );
    if (!mounted || result is! AdminInvoiceGenerationFormResult) return;
    await _loadData();
    _snack(
      'Invoice request submitted: ${result.created} invoice(s), skipped ${result.skipped}.',
      success: true,
    );
  }

  Future<void> _openRecordPaymentForm({Map<String, dynamic>? invoice}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.feePaymentReceipt,
      arguments: AdminPaymentRecordFormArgs(
        pendingDues: _pendingDues,
        initialInvoice: invoice,
      ),
    );
    if (!mounted || result is! AdminPaymentRecordFormResult) return;
    await _loadData();
    _snack(
      'Payment request of ${_money(result.amount)} submitted for ${result.studentName}',
      success: true,
    );
  }

  Future<void> _sendFeeReminder(Map<String, dynamic> due) async {
    final invoiceId = _textValue(due['id']);
    if (invoiceId.isEmpty) {
      _snack('Backend invoice ID is missing');
      return;
    }
    try {
      await BackendApiClient.instance.createRaw('/fees/reminders', {
        'invoice_id': invoiceId,
        'student_id': due['student_id'],
        'message':
            'Payment reminder for outstanding balance ${_money(_numValue(due['balance']))}',
      });
      _snack('Reminder request saved', success: true);
    } catch (error) {
      _snack('Unable to send reminder: $error');
    }
  }

  Future<void> _requestReportExport(String reportType, String format) async {
    try {
      await BackendApiClient.instance.createReportExport(
        '/fees/reports/exports',
        reportTitle: reportType,
        reportType: reportType,
        format: format,
        parameters: {
          'pending_count': _pendingDues.length,
          'structure_count': _feeStructures.length,
          'payment_mode': _paymentModeFilter,
          'payment_status': _paymentStatusFilter,
        },
      );
      _snack('Report export queued', success: true);
    } catch (error) {
      _snack('Unable to queue report export: $error');
    }
  }

  Future<void> _exportReceipt(Map<String, dynamic> payment) async {
    try {
      await BackendApiClient.instance.createReportExport(
        '/fees/reports/exports',
        reportTitle:
            'Receipt Export - ${_textValue(payment['transaction_id'])}',
        reportType: 'receipt_export',
        format: 'pdf',
        parameters: {
          'transaction_id': payment['transaction_id'],
          'invoice_id': payment['invoice_id'],
          'receipt_number': payment['receipt'],
        },
      );
      _snack('Receipt export queued', success: true);
    } catch (error) {
      _snack('Unable to queue receipt export: $error');
    }
  }

  Future<void> _previewReceipt(Map<String, dynamic> payment) async {
    try {
      final pdfService = PdfService.getInstance();
      final amount = _numValue(payment['amount']);
      final bytes = await pdfService.generateFeeReceipt(
        receiptNo: _textValue(payment['receipt'], fallback: 'RCP'),
        studentName: _textValue(payment['name'], fallback: 'Student'),
        className: _textValue(payment['class'], fallback: 'Class'),
        rollNo: _textValue(payment['roll'], fallback: '-'),
        parentName: _textValue(payment['parent_name'], fallback: 'Parent'),
        feeItems: [
          {'description': 'Fee payment', 'amount': amount, 'status': 'Paid'},
        ],
        totalAmount: amount,
        paidAmount: amount,
        balance: 0,
        paymentMode: _textValue(payment['mode'], fallback: 'Recorded'),
        paymentDate:
            DateTime.tryParse(_textValue(payment['date'])) ?? DateTime.now(),
      );
      if (!mounted) return;
      await pdfService.previewDocument(context, bytes, 'Fee Receipt');
    } catch (error) {
      _snack('Unable to preview receipt: $error');
    }
  }

  Future<void> _savePaymentConfig() async {
    setState(() => _savingPaymentConfig = true);
    try {
      final config = await BackendApiClient.instance
          .updateRaw('/fees/payment-config', {
            'upi_id': _upiIdController.text.trim(),
            'payee_name': _payeeNameController.text.trim(),
            'qr_note': _qrNoteController.text.trim(),
            'qr_image_url': _textValue(_paymentConfig['qr_image_url']),
            'upi_enabled':
                _upiIdController.text.trim().isNotEmpty ||
                _textValue(_paymentConfig['qr_image_url']).isNotEmpty,
          });
      if (!mounted) return;
      setState(() => _paymentConfig = config);
      _snack('Payment details saved for parent fee payments.', success: true);
    } catch (error) {
      _snack('Unable to save payment details: $error');
    } finally {
      if (mounted) setState(() => _savingPaymentConfig = false);
    }
  }

  Future<void> _pickPaymentQr() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null || path.isEmpty) return;
    setState(() => _uploadingQr = true);
    try {
      final response = await BackendApiClient.instance.dio.post(
        '/fees/payment-config/qr',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(path, filename: file.name),
        }),
      );
      final responseData = response.data;
      final data = responseData is Map ? responseData['data'] : null;
      if (data is! Map) throw Exception('QR upload did not return settings');
      if (!mounted) return;
      final config = Map<String, dynamic>.from(data);
      setState(() => _paymentConfig = config);
      _snack('Payment QR updated for parents.', success: true);
    } catch (error) {
      _snack('Unable to upload payment QR: $error');
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  Map<String, dynamic> _normalizeFeeStructure(Map<String, dynamic> fee) {
    final category = _mapValue(fee['fee_category']);
    final grade = _mapValue(fee['grade']);
    return {
      ...fee,
      'class': _textValue(
        grade['grade_name'],
        fallback: _textValue(fee['grade_id']),
      ),
      'category': _textValue(
        category['category_name'] ?? category['name'],
        fallback: 'Fee',
      ),
      'amount': _numValue(fee['amount'] ?? fee['tuition']),
      'frequency': _textValue(
        fee['frequency'] ?? category['frequency'],
        fallback: 'term',
      ),
      'due_day': fee['due_day'] ?? '-',
    };
  }

  Map<String, dynamic> _normalizeInvoice(Map<String, dynamic> invoice) {
    final student = _mapValue(invoice['student']);
    final section = _mapValue(student['current_section'] ?? invoice['section']);
    final grade = _mapValue(section['grade']);
    final classLabel = [
      _textValue(grade['grade_name'] ?? invoice['grade_name']),
      _textValue(section['section_name'] ?? invoice['section_name']),
    ].where((part) => part.isNotEmpty).join(' - ');
    return {
      ...invoice,
      'id': _textValue(invoice['id']),
      'student_id': _textValue(invoice['student_id']),
      'name': _studentName(
        student,
        fallback: _textValue(invoice['student_name']),
      ),
      'class': classLabel.isEmpty
          ? _textValue(invoice['class'], fallback: 'Class pending')
          : classLabel,
      'total': _numValue(invoice['total_amount'] ?? invoice['net_amount']),
      'paid': _numValue(invoice['paid_amount']),
      'balance': _numValue(invoice['balance']),
      'due_date': invoice['due_date'],
      'status': _textValue(invoice['status'], fallback: 'pending'),
    };
  }

  Iterable<Map<String, dynamic>> _normalizePayments(
    Map<String, dynamic> invoice,
  ) {
    final normalized = _normalizeInvoice(invoice);
    final payments = invoice['payments'];
    if (payments is! List) return const [];
    return payments.whereType<Map>().map((payment) {
      final row = Map<String, dynamic>.from(payment);
      return {
        ...row,
        'name': normalized['name'],
        'class': normalized['class'],
        'student_id': normalized['student_id'],
        'invoice_id': normalized['id'],
        'amount': _numValue(row['amount_paid'] ?? row['amount']),
        'mode': _textValue(row['payment_mode'] ?? row['mode']),
        'date': row['payment_date'] ?? row['created_at'],
        'receipt': row['receipt_number'] ?? row['receipt'],
        'status': _textValue(row['status'], fallback: 'completed'),
        'transaction_id': _textValue(row['transaction_id'], fallback: 'N/A'),
      };
    });
  }

  double get _pendingTotal =>
      _pendingDues.fold(0, (sum, row) => sum + _numValue(row['balance']));

  double get _collectedTotal =>
      _recentPayments.fold(0, (sum, row) => sum + _numValue(row['amount']));

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('approved') || lower.contains('paid')) {
      return Colors.green;
    }
    if (lower.contains('reject')) return Colors.red;
    return Colors.orange;
  }

  void _snack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? context.appTheme.success
            : context.appTheme.error,
      ),
    );
  }

  Map<String, dynamic> _mapValue(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  double _numValue(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  String _studentName(Map<String, dynamic> student, {String fallback = ''}) {
    final direct = _textValue(student['name']);
    if (direct.isNotEmpty) return direct;
    final fullName =
        '${_textValue(student['first_name'])} ${_textValue(student['last_name'])}'
            .trim();
    return fullName.isEmpty ? fallback : fullName;
  }

  String _dateLabel(Object? value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null
        ? 'date pending'
        : date.toIso8601String().split('T').first;
  }

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  String _textValue(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _absoluteMediaUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return '${EnvConfig.apiOrigin}$trimmed';
    return '${EnvConfig.apiOrigin}/$trimmed';
  }
}

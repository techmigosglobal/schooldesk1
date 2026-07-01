import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/errors/exceptions.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
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
  List<Map<String, dynamic>> _paymentConfigs = [];
  final _upiIdController = TextEditingController();
  final _payeeNameController = TextEditingController();
  final _qrNoteController = TextEditingController();
  bool _savingPaymentConfig = false;
  bool _uploadingQr = false;
  bool _generatingInAppReport = false;
  final Set<String> _updatingConcessionIds = <String>{};

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
      await api.applyLateFineAdjustments();
      final invoices = await api.getInvoices();
      final feeCategories = await api.getRawList('/fees/categories');
      final concessions = await api.getRawList('/fees/concessions');
      final paymentConfig = await api.getPaymentConfig();
      final paymentConfigs = await api.getPaymentConfigs();
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
        _paymentConfigs = paymentConfigs;
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
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.fees,
        onDestinationSelected: (_) {},
      ),
      railBreakpoint: double.infinity,
      navigationDrawerEnabled: false,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      actions: [
        IconButton(
          tooltip: 'Create Fee Structure',
          icon: const Icon(Icons.add_card_outlined),
          onPressed: _openCreateFeeStructureForm,
        ),
        IconButton(
          tooltip: 'Generate Invoices',
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
      return _buildLoadingSkeleton();
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

  Widget _buildLoadingSkeleton() {
    final base = context.appTheme.surfaceVariant.withOpacity(0.35);
    final highlight = context.appTheme.surfaceVariant.withOpacity(0.6);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Metric cards skeleton
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            4,
            (_) => Container(
              width: 160,
              height: 80,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: highlight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 50,
                    height: 18,
                    decoration: BoxDecoration(
                      color: highlight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Row skeletons
        for (var i = 0; i < 4; i++) ...[
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: highlight,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 130,
                        height: 12,
                        decoration: BoxDecoration(
                          color: highlight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 10,
                        decoration: BoxDecoration(
                          color: highlight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
          if (_paymentConfigs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Scoped payment configs',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final config in _paymentConfigs.take(6))
              OpsListRow(
                icon: Icons.qr_code_2_rounded,
                title:
                    '${_textValue(config['scope'], fallback: 'school')} scope',
                subtitle:
                    '${_textValue(config['upi_id'], fallback: 'UPI pending')} | ${_textValue(config['qr_note'], fallback: 'No note')}',
                trailing: OpsStatusPill(
                  label: config['upi_enabled'] == true ? 'Active' : 'Off',
                  color: config['upi_enabled'] == true
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
          ],
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
        label: const Text('Create Fee Structure'),
      ),
      child: _feeStructures.isEmpty
          ? OpsEmptyState(
              icon: Icons.price_change_outlined,
              title: 'No fee structures',
              message: 'Create fee structures before generating invoices.',
            )
          : Column(
              children: [
                for (final structure in _feeStructures)
                  OpsListRow(
                    icon: Icons.price_change_outlined,
                    title:
                        '${_textValue(structure['category'], fallback: 'Fee')} - ${_textValue(structure['class'], fallback: 'Class pending')}',
                    subtitle:
                        '${_money(_numValue(structure['amount']))} | ${_textValue(structure['frequency'], fallback: 'frequency pending')} | ${_textValue(structure['section'], fallback: 'All sections')} | due day ${structure['due_day'] ?? '-'}',
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => _openEditFeeStructureForm(structure),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Save Structure'),
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
        label: const Text('Generate Invoices'),
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
                          tooltip: 'Preview Invoice',
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          onPressed: () => _previewInvoicePdf(invoice),
                        ),
                        IconButton(
                          tooltip: 'Record Payment',
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
        label: const Text('Record Payment'),
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

  String _concessionStatusFilter = 'All';

  Widget _buildConcessions() {
    final filtered = _concessionStatusFilter == 'All'
        ? _concessions
        : _concessions
              .where(
                (c) =>
                    _textValue(
                      c['status'],
                      fallback: 'pending',
                    ).toLowerCase() ==
                    _concessionStatusFilter.toLowerCase(),
              )
              .toList();
    final pendingCount = _concessions
        .where(
          (c) =>
              _textValue(c['status'], fallback: 'pending').toLowerCase() ==
              'pending',
        )
        .length;
    final totalAmount = _concessions.fold<double>(
      0,
      (sum, c) =>
          sum +
          (double.tryParse(_textValue(c['amount'] ?? c['concession_amount'])) ??
              0),
    );
    return OpsPanel(
      title: 'Concessions',
      subtitle:
          'Review fee concessions — $pendingCount pending · ₹${totalAmount.toStringAsFixed(0)} total',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final status in ['All', 'Pending', 'Approved', 'Rejected'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(status),
                      selected: _concessionStatusFilter == status,
                      onSelected: (_) =>
                          setState(() => _concessionStatusFilter = status),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            OpsEmptyState(
              icon: Icons.volunteer_activism_outlined,
              title: 'No concession requests',
              message:
                  'Backend concession requests will appear here for finance review.',
            )
          else
            for (final concession in filtered.take(20))
              _buildConcessionRow(concession),
        ],
      ),
    );
  }

  Widget _buildConcessionRow(Map<String, dynamic> concession) {
    final status = _textValue(concession['status'], fallback: 'pending');
    final id = _textValue(concession['id']);
    final canDecide =
        id.isNotEmpty &&
        status.toLowerCase() != 'approved' &&
        status.toLowerCase() != 'rejected';
    final saving = id.isNotEmpty && _updatingConcessionIds.contains(id);
    final amount =
        double.tryParse(
          _textValue(concession['amount'] ?? concession['concession_amount']),
        ) ??
        0;
    final reason = _textValue(
      concession['reason'] ?? concession['concession_reason'],
      fallback: 'Reason pending',
    );
    return OpsListRow(
      icon: Icons.volunteer_activism_outlined,
      title: _textValue(
        concession['student_name'] ?? concession['student_id'],
        fallback: 'Concession request',
      ),
      subtitle:
          '$reason${amount > 0 ? ' · ₹${amount.toStringAsFixed(0)}' : ''} | $status',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OpsStatusPill(label: status, color: _statusColor(status)),
          if (canDecide) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Approve concession',
              onPressed: saving
                  ? null
                  : () => _updateConcessionStatus(concession, approved: true),
              icon: saving
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              color: Colors.green,
            ),
            IconButton(
              tooltip: 'Reject concession',
              onPressed: saving
                  ? null
                  : () => _updateConcessionStatus(concession, approved: false),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              color: Colors.red,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateConcessionStatus(
    Map<String, dynamic> concession, {
    required bool approved,
  }) async {
    final id = _textValue(concession['id']);
    if (id.isEmpty) {
      _snack('Concession id is missing, cannot update status.');
      return;
    }
    setState(() => _updatingConcessionIds.add(id));
    final targetStatus = approved ? 'approved' : 'rejected';
    try {
      final updated = await BackendApiClient.instance.updateRaw(
        '/fees/concessions/$id',
        {'status': targetStatus},
      );
      if (!mounted) return;
      setState(() {
        _concessions = _concessions.map((row) {
          if (_textValue(row['id']) != id) return row;
          return {
            ...row,
            ...updated,
            'status': _textValue(updated['status'], fallback: targetStatus),
          };
        }).toList();
      });
      _snack(
        approved
            ? 'Concession approved successfully.'
            : 'Concession rejected successfully.',
        success: true,
      );
    } catch (error) {
      _snack('Unable to update concession: $error');
    } finally {
      if (mounted) {
        setState(() => _updatingConcessionIds.remove(id));
      }
    }
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAgingSummaryCard(),
          const SizedBox(height: 12),
          // In-app PDF summary
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bar_chart_rounded, color: Color(0xFF4F46E5)),
                      SizedBox(width: 8),
                      Text(
                        'In-App PDF Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generates an instant fee collection summary PDF from live data. '
                    'Includes class-wise breakdown, totals, and outstanding dues.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _generatingInAppReport
                        ? null
                        : _generateAdminInAppReport,
                    icon: _generatingInAppReport
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text(
                      _generatingInAppReport ? 'Generating...' : 'Generate PDF',
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  Widget _buildAgingSummaryCard() {
    final buckets = _agingBuckets;
    Widget tile(String label, int count, Color color) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timer_outlined, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text(
                  'Overdue Aging Summary',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                tile('0-30 days', buckets.$1, const Color(0xFFF59E0B)),
                tile('31-60 days', buckets.$2, const Color(0xFFEF4444)),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withAlpha(22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withAlpha(50),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${buckets.$3}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '61+ days',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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

  Future<void> _openCreateFeeStructureForm() => _openFeeStructureForm();

  Future<void> _openEditFeeStructureForm(Map<String, dynamic> structure) =>
      _openFeeStructureForm(structure: structure);

  Future<void> _deleteFeeStructure(Map<String, dynamic> structure) async {
    final id = '${structure['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      _snack('Fee structure ID is missing.');
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delete fee component?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                'This removes ${_textValue(structure['category'], fallback: 'this fee component')} from ${_textValue(structure['class'], fallback: 'this class')}; existing invoices and payments are not changed.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await BackendApiClient.instance.deleteFeeStructure(id);
      if (!mounted) return;
      await _loadData();
      _snack('Fee component deleted.', success: true);
    } on ServerException catch (e) {
      // Unwrap backend error message explicitly for clarity.
      _snack(
        e.message.isNotEmpty
            ? 'Delete failed: ${e.message}'
            : 'Unable to delete fee component.',
      );
    } catch (error) {
      _snack('Unable to delete fee component: $error');
    }
  }

  Future<void> _openFeeStructureForm({Map<String, dynamic>? structure}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.principalFeeStructureForm,
      arguments: AdminFeeStructureFormArgs(
        academicYears: _academicYears,
        grades: _grades,
        sections: _sections,
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
      AppRoutes.principalInvoiceGenerationForm,
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
      'Generated ${result.created} invoice(s), skipped ${result.skipped}.',
      success: true,
    );
  }

  Future<void> _openRecordPaymentForm({Map<String, dynamic>? invoice}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.principalPaymentRecordForm,
      arguments: AdminPaymentRecordFormArgs(
        pendingDues: _pendingDues,
        initialInvoice: invoice,
      ),
    );
    if (!mounted || result is! AdminPaymentRecordFormResult) return;
    await _loadData();
    _snack(
      'Recorded payment of ${_money(result.amount)} for ${result.studentName}',
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
      // Attempt to fetch full invoice for itemized fee line items.
      List<Map<String, dynamic>> feeItems;
      final invoiceId = _textValue(payment['invoice_id']);
      if (invoiceId.isNotEmpty) {
        try {
          final detail = await BackendApiClient.instance.getInvoiceDetail(
            invoiceId,
          );
          final rawItems = detail['items'];
          if (rawItems is List && rawItems.isNotEmpty) {
            feeItems = rawItems.whereType<Map>().map((item) {
              return <String, dynamic>{
                'description': _textValue(
                  item['category_name'] ?? item['description'] ?? item['name'],
                  fallback: 'Fee component',
                ),
                'amount': _numValue(item['amount']),
                'status': _textValue(item['status'], fallback: 'Paid'),
              };
            }).toList();
          } else {
            throw Exception('No items in invoice');
          }
        } catch (_) {
          feeItems = [
            {'description': 'Fee payment', 'amount': amount, 'status': 'Paid'},
          ];
        }
      } else {
        feeItems = [
          {'description': 'Fee payment', 'amount': amount, 'status': 'Paid'},
        ];
      }
      final bytes = await pdfService.generateFeeReceipt(
        receiptNo: _textValue(payment['receipt'], fallback: 'RCP'),
        studentName: _textValue(payment['name'], fallback: 'Student'),
        className: _textValue(payment['class'], fallback: 'Class'),
        rollNo: _textValue(payment['roll'], fallback: '-'),
        parentName: _textValue(payment['parent_name'], fallback: 'Parent'),
        feeItems: feeItems,
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

  Future<void> _previewInvoicePdf(Map<String, dynamic> invoice) async {
    try {
      final pdfService = PdfService.getInstance();
      final invoiceId = _textValue(invoice['id']);
      if (invoiceId.isEmpty) {
        _snack('Invoice ID is missing.');
        return;
      }

      List<Map<String, dynamic>> feeItems = [];
      try {
        final detail = await BackendApiClient.instance.getInvoiceDetail(
          invoiceId,
        );
        final rawItems = detail['items'];
        if (rawItems is List && rawItems.isNotEmpty) {
          feeItems = rawItems.whereType<Map>().map((item) {
            return <String, dynamic>{
              'description': _textValue(
                item['category_name'] ?? item['description'] ?? item['name'],
                fallback: 'Fee component',
              ),
              'amount': _numValue(item['amount']),
              'status': _textValue(item['status'], fallback: 'Pending'),
            };
          }).toList();
        }
      } catch (_) {}

      if (feeItems.isEmpty) {
        feeItems = [
          {
            'description': 'Academic Fees',
            'amount': _numValue(invoice['total']),
            'status': 'Pending',
          },
        ];
      }

      final bytes = await pdfService.generateFeeReceipt(
        receiptNo: _textValue(invoice['invoice_number'], fallback: 'INV'),
        studentName: _textValue(invoice['name'], fallback: 'Student'),
        className: _textValue(invoice['class'], fallback: 'Class'),
        rollNo: _textValue(invoice['roll'], fallback: '-'),
        parentName: _textValue(invoice['parent_name'], fallback: 'Parent'),
        feeItems: feeItems,
        totalAmount: _numValue(invoice['total']),
        paidAmount: _numValue(invoice['paid']),
        balance: _numValue(invoice['balance']),
        paymentMode: 'Invoice',
        paymentDate:
            DateTime.tryParse(_textValue(invoice['due_date'])) ??
            DateTime.now(),
      );

      if (!mounted) return;
      await pdfService.previewDocument(context, bytes, 'Fee Invoice');
    } catch (error) {
      _snack('Unable to preview invoice: $error');
    }
  }

  Future<void> _generateAdminInAppReport() async {
    setState(() => _generatingInAppReport = true);
    try {
      // Build class-wise breakdown from invoices.
      final classMap = <String, Map<String, double>>{};
      final allInvoices = [..._pendingDues, ..._recentPayments];
      for (final inv in allInvoices) {
        final classKey = _textValue(inv['class'], fallback: 'Unknown');
        classMap.putIfAbsent(
          classKey,
          () => {'total': 0, 'paid': 0, 'balance': 0},
        );
        classMap[classKey]!['paid'] =
            (classMap[classKey]!['paid'] ?? 0) +
            _numValue(inv['amount'] ?? inv['paid_amount']);
      }
      for (final inv in _pendingDues) {
        final classKey = _textValue(inv['class'], fallback: 'Unknown');
        classMap.putIfAbsent(
          classKey,
          () => {'total': 0, 'paid': 0, 'balance': 0},
        );
        classMap[classKey]!['balance'] =
            (classMap[classKey]!['balance'] ?? 0) + _numValue(inv['balance']);
      }

      final totalCollected = _recentPayments.fold<double>(
        0,
        (sum, p) => sum + _numValue(p['amount']),
      );
      final totalDue = _pendingDues.fold<double>(
        0,
        (sum, p) => sum + _numValue(p['balance']),
      );

      final summaryItems = <Map<String, dynamic>>[
        {
          'description': 'Total Collected',
          'amount': totalCollected,
          'status': 'Collected',
        },
        {
          'description': 'Outstanding Dues',
          'amount': totalDue,
          'status': totalDue > 0 ? 'Pending' : 'Clear',
        },
        for (final entry in classMap.entries)
          {
            'description': entry.key,
            'amount': entry.value['paid'] ?? 0,
            'status':
                '₹${(entry.value['balance'] ?? 0).toStringAsFixed(0)} due',
          },
      ];

      final pdfService = PdfService.getInstance();
      final bytes = await pdfService.generateFeeReceipt(
        receiptNo: 'RPT-${DateTime.now().millisecondsSinceEpoch}',
        studentName: 'All Students',
        className: 'All Classes',
        rollNo: '${_pendingDues.length + _recentPayments.length} invoices',
        parentName: 'Fee Collection Report',
        feeItems: summaryItems,
        totalAmount: totalCollected + totalDue,
        paidAmount: totalCollected,
        balance: totalDue,
        paymentMode: 'Summary Report',
        paymentDate: DateTime.now(),
        schoolName: 'School Fee Summary',
        schoolAddress:
            'Generated: ${DateTime.now().toString().substring(0, 16)}',
      );
      if (!mounted) return;
      await pdfService.previewDocument(context, bytes, 'Fee Collection Report');
    } catch (error) {
      if (mounted) _snack('Unable to generate report: $error');
    } finally {
      if (mounted) setState(() => _generatingInAppReport = false);
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
    final section = _mapValue(fee['section']);
    return {
      ...fee,
      'class': _textValue(
        grade['grade_name'],
        fallback: _textValue(fee['grade_id']),
      ),
      'section': _textValue(
        section['section_name'],
        fallback: _textValue(fee['section_id']).isEmpty
            ? 'All sections'
            : _textValue(fee['section_id']),
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

  (int, int, int) get _agingBuckets {
    var bucket0To30 = 0;
    var bucket31To60 = 0;
    var bucket61Plus = 0;
    for (final invoice in _pendingDues) {
      final due = DateTime.tryParse(_textValue(invoice['due_date']));
      if (due == null) continue;
      final days = DateTime.now().difference(due).inDays;
      if (days <= 0) continue;
      if (days <= 30) {
        bucket0To30++;
      } else if (days <= 60) {
        bucket31To60++;
      } else {
        bucket61Plus++;
      }
    }
    return (bucket0To30, bucket31To60, bucket61Plus);
  }

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

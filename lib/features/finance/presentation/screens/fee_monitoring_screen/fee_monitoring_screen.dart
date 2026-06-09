import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/routes/app_routes.dart';

enum _FeeView {
  home,
  structures,
  structureDetails,
  students,
  ledger,
  collectMode,
  collectDetails,
  paymentSuccess,
  dues,
  reports,
}

enum _FeeStatusFilter { all, paid, partial, unpaid, due }

enum _PaymentMode { cash, onlinePayment, cheque, bankTransfer, other }

extension on _PaymentMode {
  String get label {
    return switch (this) {
      _PaymentMode.cash => 'Cash',
      _PaymentMode.onlinePayment => 'Online Payment',
      _PaymentMode.cheque => 'Cheque',
      _PaymentMode.bankTransfer => 'Bank Transfer',
      _PaymentMode.other => 'Other',
    };
  }

  IconData get icon {
    return switch (this) {
      _PaymentMode.cash => Icons.payments_outlined,
      _PaymentMode.onlinePayment => Icons.credit_card_outlined,
      _PaymentMode.cheque => Icons.receipt_long_outlined,
      _PaymentMode.bankTransfer => Icons.account_balance_outlined,
      _PaymentMode.other => Icons.more_horiz_rounded,
    };
  }

  Color get color {
    return switch (this) {
      _PaymentMode.cash => const Color(0xFF16A34A),
      _PaymentMode.onlinePayment => const Color(0xFF2563EB),
      _PaymentMode.cheque => const Color(0xFF7C3AED),
      _PaymentMode.bankTransfer => const Color(0xFFEA580C),
      _PaymentMode.other => const Color(0xFFEF4444),
    };
  }
}

class FeeMonitoringScreen extends StatefulWidget {
  const FeeMonitoringScreen({super.key});

  @override
  State<FeeMonitoringScreen> createState() => _FeeMonitoringScreenState();
}

class _FeeMonitoringScreenState extends State<FeeMonitoringScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  final _transactionController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _query = '';
  String _reportRange = '01 May 2024 - 15 May 2024';
  _FeeView _view = _FeeView.home;
  _FeeStatusFilter _statusFilter = _FeeStatusFilter.all;
  _PaymentMode _selectedPaymentMode = _PaymentMode.onlinePayment;
  DateTime _paymentDate = DateTime.now();

  List<Map<String, dynamic>> _feeStructures = const [];
  List<Map<String, dynamic>> _invoices = const [];
  List<Map<String, dynamic>> _recentPayments = const [];
  List<AcademicYearModel> _academicYears = const [];
  List<GradeModel> _grades = const [];

  _FeeStructureBundle? _selectedStructure;
  _FeeStudentAccount? _selectedAccount;
  Map<String, dynamic>? _selectedInvoice;
  _FeePaymentResult? _lastPayment;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _paymentAmountController.dispose();
    _transactionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getFeeStructures(),
        api.getInvoices(pageSize: 500),
        api.getAcademicYears(),
        api.getGrades(),
      ]);

      final structures = (results[0] as List<Map<String, dynamic>>)
          .map(_normalizeFeeStructure)
          .toList();
      final invoices = (results[1] as List<Map<String, dynamic>>)
          .map(_normalizeInvoice)
          .toList();
      final payments = invoices.expand(_normalizePayments).toList()
        ..sort((a, b) => _sortDate(b['date']).compareTo(_sortDate(a['date'])));

      if (!mounted) return;
      setState(() {
        _feeStructures = structures;
        _invoices = invoices;
        _recentPayments = payments;
        _academicYears = results[2] as List<AcademicYearModel>;
        _grades = results[3] as List<GradeModel>;
        _selectedStructure = _reselectStructure(_selectedStructure);
        _selectedAccount = _reselectAccount(_selectedAccount);
        _selectedInvoice = _reselectInvoice(_selectedInvoice);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load fee information from backend. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7FAFF),
      drawer: PrincipalDrawer(selectedIndex: 7, onDestinationSelected: (_) {}),
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primary,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 260),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 120),
        children: [
          _FeeHeader(
            title: 'Fees',
            subtitle: 'View and manage fee information',
            leadingIcon: Icons.menu_rounded,
            onLeading: () => _scaffoldKey.currentState?.openDrawer(),
            trailing: IconButton(
              tooltip: 'Refresh fees',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
          ),
          const SizedBox(height: 120),
          _FeeEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Fees unavailable',
            message: _error!,
            actionLabel: 'Retry',
            onAction: _loadData,
          ),
        ],
      );
    }

    return switch (_view) {
      _FeeView.home => _buildHomeView(),
      _FeeView.structures => _buildStructuresView(),
      _FeeView.structureDetails => _buildStructureDetailsView(),
      _FeeView.students => _buildStudentsView(),
      _FeeView.ledger => _buildLedgerView(),
      _FeeView.collectMode => _buildCollectModeView(),
      _FeeView.collectDetails => _buildCollectDetailsView(),
      _FeeView.paymentSuccess => _buildPaymentSuccessView(),
      _FeeView.dues => _buildOutstandingDuesView(),
      _FeeView.reports => _buildReportsView(),
    };
  }

  Widget _buildHomeView() {
    return _FeePage(
      header: _FeeHeader(
        title: 'Fees',
        subtitle: 'View and manage fee information',
        leadingIcon: Icons.menu_rounded,
        onLeading: () => _scaffoldKey.currentState?.openDrawer(),
        trailing: IconButton(
          tooltip: 'Filter fees',
          icon: const Icon(Icons.filter_alt_outlined),
          onPressed: _openStatusFilter,
        ),
      ),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: [
            _FeeMetricTile(
              label: 'Total Fee Structures',
              value: '${_structureBundles.length}',
              icon: Icons.assignment_outlined,
              color: const Color(0xFF2563EB),
            ),
            _FeeMetricTile(
              label: 'Total Collections',
              value: _money(_totalCollected),
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF16A34A),
            ),
            _FeeMetricTile(
              label: 'Total Due',
              value: _money(_totalDue),
              icon: Icons.pending_actions_outlined,
              color: const Color(0xFFEA580C),
            ),
            _FeeMetricTile(
              label: 'Students',
              value: '${_studentAccounts.length}',
              icon: Icons.groups_outlined,
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _FeeSectionTitle('Quick Actions'),
        const SizedBox(height: 10),
        _FeeActionRow(
          icon: Icons.assignment_outlined,
          iconColor: const Color(0xFF2563EB),
          title: 'Fee Structures',
          subtitle: 'View all fee structures',
          onTap: () => _setView(_FeeView.structures),
        ),
        _FeeActionRow(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: const Color(0xFF16A34A),
          title: 'Fee Collection',
          subtitle: 'View collections and payments',
          onTap: _openStudentsForCollection,
        ),
        _FeeActionRow(
          icon: Icons.receipt_long_outlined,
          iconColor: const Color(0xFFEA580C),
          title: 'Outstanding Dues',
          subtitle: 'View pending fee payments',
          onTap: () => _setView(_FeeView.dues),
        ),
        _FeeActionRow(
          icon: Icons.summarize_outlined,
          iconColor: const Color(0xFF2563EB),
          title: 'Fee Reports',
          subtitle: 'View fee reports and analytics',
          onTap: () => _setView(_FeeView.reports),
        ),
      ],
    );
  }

  Widget _buildStructuresView() {
    final rows = _filteredStructures;
    return _FeePage(
      header: _FeeHeader(
        title: 'Fee Structures',
        subtitle: 'View all fee structures',
        leadingIcon: Icons.arrow_back_rounded,
        onLeading: _goBack,
        trailing: IconButton(
          tooltip: 'Open Class Hub fee setup',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () => _openClassesHubForFees(),
        ),
      ),
      children: [
        _FeeSearchBox(
          controller: _searchController,
          hint: 'Search fee structures',
          onChanged: _setQuery,
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const _FeeEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No fee structures found',
            message: 'Use Classes Hub Step 4 to set up class-wise fee rules.',
          )
        else
          for (final bundle in rows)
            _FeeStructureCard(
              bundle: bundle,
              onTap: () => _openStructureDetails(bundle),
            ),
      ],
    );
  }

  Widget _buildStructureDetailsView() {
    final bundle = _selectedStructure ?? _structureBundles.firstOrNull;
    if (bundle == null) {
      return _missingSelectionPage(
        title: 'Fee Structure Details',
        message: 'No fee structure is available to inspect.',
      );
    }

    return _FeePage(
      header: _FeeHeader(
        title: 'Fee Structure Details',
        subtitle: bundle.title,
        leadingIcon: Icons.arrow_back_rounded,
        onLeading: _goBack,
        trailing: IconButton(
          tooltip: 'Edit in Classes Hub',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _openClassesHubForFees(gradeId: bundle.gradeId),
        ),
      ),
      children: [
        _FeeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _FeeIconBadge(
                    icon: Icons.assignment_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bundle.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Applicable for ${bundle.classLabel}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _FeeStatusPill(
                    label: bundle.statusLabel,
                    color: bundle.isActive
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFF59E0B),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Academic Year',
                      value: bundle.academicYearLabel,
                    ),
                  ),
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Total Components',
                      value: '${bundle.components.length}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _FeeSectionTitle('Fee Components'),
        const SizedBox(height: 10),
        for (final component in bundle.components)
          _FeeComponentTile(component: component),
        const SizedBox(height: 4),
        _FeeCard(
          child: Row(
            children: [
              Expanded(
                child: _FeeInfoTile(
                  label: 'Total (One Time)',
                  value: _money(bundle.oneTimeTotal),
                ),
              ),
              Expanded(
                child: _FeeInfoTile(
                  label: 'Total (Yearly)',
                  value: _money(bundle.yearlyTotal),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _FeeInfoBanner(
          text:
              'To make changes to this fee structure, go to Classes Hub -> Step 4 (Fees).',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _openClassesHubForFees(gradeId: bundle.gradeId),
          icon: const Icon(Icons.apartment_outlined),
          label: const Text('Go to Classes Hub'),
        ),
        FilledButton.icon(
          onPressed: () => _openStudentsForCollection(structure: bundle),
          icon: const Icon(Icons.groups_outlined),
          label: const Text('View Students'),
        ),
      ],
    );
  }

  Widget _buildStudentsView() {
    final rows = _filteredStudentAccounts;
    final title = _selectedStructure?.classLabel ?? 'Students';
    return _FeePage(
      header: _FeeHeader(
        title: 'Students',
        subtitle: title == 'Students'
            ? 'All fee accounts'
            : '$title - ${_selectedStructure?.title ?? 'Fee Structure'}',
        leadingIcon: Icons.arrow_back_rounded,
        onLeading: _goBack,
        trailing: IconButton(
          tooltip: 'Filter students',
          icon: const Icon(Icons.filter_alt_outlined),
          onPressed: _openStatusFilter,
        ),
      ),
      children: [
        _FeeSearchBox(
          controller: _searchController,
          hint: 'Search student',
          onChanged: _setQuery,
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
          children: [
            _FeeMiniMetric(
              label: 'Total Students',
              value: '${rows.length}',
              icon: Icons.groups_outlined,
              color: const Color(0xFF2563EB),
            ),
            _FeeMiniMetric(
              label: 'Paid',
              value: '${rows.where((row) => row.status == 'Paid').length}',
              icon: Icons.payments_outlined,
              color: const Color(0xFF16A34A),
            ),
            _FeeMiniMetric(
              label: 'Partial Paid',
              value: '${rows.where((row) => row.status == 'Partial').length}',
              icon: Icons.group_outlined,
              color: const Color(0xFFF59E0B),
            ),
            _FeeMiniMetric(
              label: 'Unpaid',
              value:
                  '${rows.where((row) => row.status == 'Unpaid' || row.status == 'Due').length}',
              icon: Icons.group_remove_outlined,
              color: const Color(0xFFEF4444),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Students (${rows.length})',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _openStatusFilter,
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: const Text('Filter'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (rows.isEmpty)
          const _FeeEmptyState(
            icon: Icons.groups_outlined,
            title: 'No students found',
            message:
                'Generate invoices for this fee structure before collecting fees.',
          )
        else
          for (final account in rows)
            _FeeStudentRow(account: account, onTap: () => _openLedger(account)),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: rows.any((row) => row.balance > 0)
              ? () => _openCollectForAccount(
                  rows.firstWhere((row) => row.balance > 0),
                )
              : null,
          child: const Text('Collect Fee'),
        ),
      ],
    );
  }

  Widget _buildLedgerView() {
    final account = _selectedAccount;
    if (account == null) {
      return _missingSelectionPage(
        title: 'Fee Ledger',
        message: 'Select a student to view the fee ledger.',
      );
    }

    final primaryInvoice =
        _primaryDueInvoice(account) ?? account.invoices.first;
    return _FeePage(
      header: _FeeHeader(
        title: 'Fee Ledger',
        subtitle: '${account.name} - ${account.rollNumber}',
        leadingIcon: Icons.arrow_back_rounded,
        onLeading: _goBack,
        trailing: IconButton(
          tooltip: 'Filter ledger',
          icon: const Icon(Icons.filter_alt_outlined),
          onPressed: _openStatusFilter,
        ),
      ),
      children: [
        _FeeCard(
          child: Column(
            children: [
              Row(
                children: [
                  _FeeAvatar(label: account.name, photoUrl: account.photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          account.rollNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _FeeStatusPill(
                    label: account.status,
                    color: _statusColor(account.status),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Grade / Section',
                      value: account.classLabel,
                    ),
                  ),
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Academic Year',
                      value: account.academicYearLabel,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _FeeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Fee Structure',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openStructureForInvoice(primaryInvoice),
                    child: const Text('View Details'),
                  ),
                ],
              ),
              Text(
                account.structureTitle,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Total Fees',
                      value: _money(account.total),
                    ),
                  ),
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Paid Amount',
                      value: _money(account.paid),
                      highlighted: true,
                    ),
                  ),
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Due Amount',
                      value: _money(account.balance),
                      danger: account.balance > 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _FeeSectionTitle('Payment History'),
        const SizedBox(height: 10),
        if (account.payments.isEmpty)
          const _FeeEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No payments recorded',
            message: 'Payments will appear here after collection is recorded.',
          )
        else
          for (final payment in account.payments)
            _FeePaymentHistoryTile(payment: payment),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: account.balance <= 0
              ? null
              : () => _openCollectForAccount(account),
          child: const Text('Make Payment'),
        ),
      ],
    );
  }

  Widget _buildCollectModeView() {
    final account = _selectedAccount;
    if (account == null) {
      return _missingSelectionPage(
        title: 'Collect Fee',
        message: 'Select a student before collecting a fee.',
      );
    }

    return _FeePage(
      header: _FeeHeader(
        title: 'Collect Fee',
        subtitle: '${account.name} - ${account.rollNumber}',
        leadingIcon: Icons.arrow_back_rounded,
        onLeading: _goBack,
        trailing: IconButton(
          tooltip: 'Open ledger',
          icon: const Icon(Icons.receipt_long_outlined),
          onPressed: () => _setView(_FeeView.ledger),
        ),
      ),
      children: [
        const _FeeSectionTitle('Payment Summary'),
        const SizedBox(height: 10),
        _FeeCard(
          child: Column(
            children: [
              _FeeAmountRow(label: 'Total Fees', value: _money(account.total)),
              _FeeAmountRow(label: 'Paid Amount', value: _money(account.paid)),
              _FeeAmountRow(
                label: 'Due Amount',
                value: _money(account.balance),
                danger: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _FeeSectionTitle('Select Payment Mode'),
        const SizedBox(height: 10),
        for (final mode in _PaymentMode.values)
          _FeePaymentModeTile(
            mode: mode,
            selected: _selectedPaymentMode == mode,
            onTap: () => setState(() => _selectedPaymentMode = mode),
          ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: account.balance <= 0 ? null : _continueToPaymentDetails,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildCollectDetailsView() {
    final account = _selectedAccount;
    if (account == null) {
      return _missingSelectionPage(
        title: 'Collect Fee',
        message: 'Select a student before collecting a fee.',
      );
    }

    return _FeePage(
      header: _FeeHeader(
        title: 'Collect Fee',
        subtitle: '${account.name} - ${account.rollNumber}',
        leadingIcon: Icons.arrow_back_rounded,
        onLeading: _goBack,
        trailing: IconButton(
          tooltip: 'Pick payment date',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: _pickPaymentDate,
        ),
      ),
      children: [
        const _FeeSectionTitle('Payment Details'),
        const SizedBox(height: 10),
        _FeeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _paymentAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount to be Paid',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<_PaymentMode>(
                initialValue: _selectedPaymentMode,
                decoration: const InputDecoration(labelText: 'Payment Mode'),
                items: [
                  for (final mode in _PaymentMode.values)
                    DropdownMenuItem(value: mode, child: Text(mode.label)),
                ],
                onChanged: (mode) {
                  if (mode == null) return;
                  setState(() => _selectedPaymentMode = mode);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _transactionController,
                decoration: const InputDecoration(labelText: 'Transaction ID'),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _pickPaymentDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Payment Date'),
                  child: Row(
                    children: [
                      Expanded(child: Text(_displayDate(_paymentDate))),
                      const Icon(Icons.calendar_month_outlined, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _confirmPayment,
          child: Text(_saving ? 'Recording...' : 'Confirm Payment'),
        ),
      ],
    );
  }

  Widget _buildPaymentSuccessView() {
    final result = _lastPayment;
    if (result == null) {
      return _missingSelectionPage(
        title: 'Payment Successful',
        message: 'No recent payment is available to display.',
      );
    }

    return _FeePage(
      header: const SizedBox.shrink(),
      children: [
        const SizedBox(height: 18),
        const _FeeSuccessCircle(),
        const SizedBox(height: 18),
        Center(
          child: Column(
            children: [
              const Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Fee payment of ${_money(result.amount)} has been recorded for ${result.studentName}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const _FeeSectionTitle('Payment Details'),
        const SizedBox(height: 10),
        _FeeCard(
          child: Column(
            children: [
              _FeeAmountRow(label: 'Amount Paid', value: _money(result.amount)),
              _FeeAmountRow(label: 'Payment Mode', value: result.paymentMode),
              _FeeAmountRow(
                label: 'Transaction ID',
                value: result.transactionId.isEmpty
                    ? result.receiptNumber
                    : result.transactionId,
              ),
              _FeeAmountRow(
                label: 'Payment Date',
                value: _displayDate(result.paymentDate),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _previewLastReceipt,
          child: const Text('View Receipt'),
        ),
        OutlinedButton(
          onPressed: () => _setView(_FeeView.students),
          child: const Text('Back to Students'),
        ),
      ],
    );
  }

  Widget _buildOutstandingDuesView() {
    final rows = _filteredDueAccounts;
    return _FeePage(
      header: _FeeHeader(
        title: 'Outstanding Dues',
        subtitle: 'View all pending fee payments',
        leadingIcon: Icons.arrow_back_rounded,
        onLeading: _goBack,
        trailing: IconButton(
          tooltip: 'Filter dues',
          icon: const Icon(Icons.filter_alt_outlined),
          onPressed: _openStatusFilter,
        ),
      ),
      children: [
        _FeeSearchBox(
          controller: _searchController,
          hint: 'Search student',
          onChanged: _setQuery,
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.22,
          children: [
            _FeeMiniMetric(
              label: 'Total Dues',
              value: _money(_totalDue),
              icon: Icons.pending_actions_outlined,
              color: const Color(0xFF7C3AED),
            ),
            _FeeMiniMetric(
              label: 'Students',
              value: '${rows.length}',
              icon: Icons.groups_outlined,
              color: const Color(0xFFF59E0B),
            ),
            _FeeMiniMetric(
              label: 'Invoices',
              value:
                  '${_invoices.where((row) => _numValue(row['balance']) > 0).length}',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFF16A34A),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _FeeSectionTitle('Students with Dues'),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const _FeeEmptyState(
            icon: Icons.verified_outlined,
            title: 'No outstanding dues',
            message: 'All visible fee accounts are clear.',
          )
        else
          for (final account in rows)
            _FeeDueStudentTile(
              account: account,
              onTap: () => _openLedger(account),
            ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: rows.isEmpty || _saving ? null : _sendRemindersForDues,
          icon: const Icon(Icons.notifications_active_outlined, size: 18),
          label: Text(_saving ? 'Sending...' : 'Send Reminders'),
        ),
      ],
    );
  }

  Widget _buildReportsView() {
    final reports = const [
      _FeeReportDefinition(
        title: 'Collection Summary',
        subtitle: 'View overall collection summary',
        reportType: 'fee_collection_summary',
        icon: Icons.summarize_outlined,
        color: Color(0xFFEC4899),
      ),
      _FeeReportDefinition(
        title: 'Class Wise Collection',
        subtitle: 'View collection by class/section',
        reportType: 'fee_class_collection',
        icon: Icons.assignment_outlined,
        color: Color(0xFF2563EB),
      ),
      _FeeReportDefinition(
        title: 'Student Wise Report',
        subtitle: 'View student wise payment report',
        reportType: 'fee_student_report',
        icon: Icons.groups_outlined,
        color: Color(0xFF4F46E5),
      ),
      _FeeReportDefinition(
        title: 'Outstanding Report',
        subtitle: 'View all pending dues',
        reportType: 'fee_outstanding_report',
        icon: Icons.pending_actions_outlined,
        color: Color(0xFFEA580C),
      ),
      _FeeReportDefinition(
        title: 'Daily Collection Report',
        subtitle: 'View day wise collection report',
        reportType: 'fee_daily_collection',
        icon: Icons.payments_outlined,
        color: Color(0xFF16A34A),
      ),
    ];

    return _FeePage(
      header: _FeeHeader(
        title: 'Fee Reports',
        subtitle: 'View fee reports and analytics',
        leadingIcon: Icons.arrow_back_rounded,
        onLeading: _goBack,
        trailing: IconButton(
          tooltip: 'Report filters',
          icon: const Icon(Icons.filter_alt_outlined),
          onPressed: _pickReportRange,
        ),
      ),
      children: [
        const _FeeSectionTitle('Select Report Type'),
        const SizedBox(height: 10),
        for (final report in reports)
          _FeeReportTile(
            report: report,
            onTap: () => _requestReportExport(report),
          ),
        const SizedBox(height: 14),
        const _FeeSectionTitle('Select Date Range'),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _pickReportRange,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date Range'),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_reportRange)),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () => _requestReportExport(reports.first),
          child: const Text('Generate Report'),
        ),
      ],
    );
  }

  Widget _missingSelectionPage({
    required String title,
    required String message,
  }) {
    return _FeePage(
      header: _FeeHeader(
        title: title,
        subtitle: 'Fees',
        leadingIcon: Icons.arrow_back_rounded,
        onLeading: _goBack,
      ),
      children: [
        const SizedBox(height: 110),
        _FeeEmptyState(
          icon: Icons.info_outline_rounded,
          title: title,
          message: message,
          actionLabel: 'Back to Fees',
          onAction: () => _setView(_FeeView.home),
        ),
      ],
    );
  }

  void _setView(_FeeView view) {
    setState(() {
      _view = view;
      if (view == _FeeView.home ||
          view == _FeeView.structures ||
          view == _FeeView.students ||
          view == _FeeView.dues) {
        _clearSearch();
      }
    });
  }

  void _goBack() {
    setState(() {
      _view = switch (_view) {
        _FeeView.structures => _FeeView.home,
        _FeeView.structureDetails => _FeeView.structures,
        _FeeView.students =>
          _selectedStructure == null
              ? _FeeView.home
              : _FeeView.structureDetails,
        _FeeView.ledger => _FeeView.students,
        _FeeView.collectMode => _FeeView.ledger,
        _FeeView.collectDetails => _FeeView.collectMode,
        _FeeView.paymentSuccess => _FeeView.students,
        _FeeView.dues => _FeeView.home,
        _FeeView.reports => _FeeView.home,
        _FeeView.home => _FeeView.home,
      };
      _clearSearch();
    });
  }

  void _clearSearch() {
    _query = '';
    _searchController.clear();
  }

  void _setQuery(String value) {
    setState(() => _query = value);
  }

  void _openStatusFilter() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter fee status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                for (final filter in _FeeStatusFilter.values)
                  RadioListTile<_FeeStatusFilter>(
                    value: filter,
                    groupValue: _statusFilter,
                    title: Text(_statusFilterLabel(filter)),
                    onChanged: (value) {
                      if (value == null) return;
                      Navigator.pop(context);
                      setState(() => _statusFilter = value);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openStructureDetails(_FeeStructureBundle bundle) {
    setState(() {
      _selectedStructure = bundle;
      _view = _FeeView.structureDetails;
      _clearSearch();
    });
  }

  void _openStructureForInvoice(Map<String, dynamic> invoice) {
    final bundle = _structureBundles.firstWhereOrNull((structure) {
      final sameGrade =
          structure.gradeId.isNotEmpty &&
          structure.gradeId == _textValue(invoice['grade_id']);
      final sameYear =
          structure.academicYearId.isNotEmpty &&
          structure.academicYearId == _textValue(invoice['academic_year_id']);
      return sameGrade && sameYear;
    });
    setState(() {
      if (bundle != null) _selectedStructure = bundle;
      _view = _FeeView.structureDetails;
    });
  }

  void _openStudentsForCollection({_FeeStructureBundle? structure}) {
    setState(() {
      _selectedStructure = structure;
      _view = _FeeView.students;
      _clearSearch();
    });
  }

  void _openLedger(_FeeStudentAccount account) {
    setState(() {
      _selectedAccount = account;
      _selectedInvoice = _primaryDueInvoice(account) ?? account.invoices.first;
      _view = _FeeView.ledger;
      _clearSearch();
    });
  }

  void _openCollectForAccount(_FeeStudentAccount account) {
    final invoice = _primaryDueInvoice(account);
    if (invoice == null) {
      _snack('This student has no outstanding invoice.');
      return;
    }
    setState(() {
      _selectedAccount = account;
      _selectedInvoice = invoice;
      _selectedPaymentMode = _PaymentMode.onlinePayment;
      _paymentDate = DateTime.now();
      _paymentAmountController.text = _amountText(
        _numValue(invoice['balance']),
      );
      _transactionController.text = _suggestedTransactionId();
      _notesController.clear();
      _view = _FeeView.collectMode;
    });
  }

  void _continueToPaymentDetails() {
    final account = _selectedAccount;
    final invoice = _selectedInvoice;
    if (account == null || invoice == null) {
      _snack('Select a student invoice before continuing.');
      return;
    }
    _paymentAmountController.text = _amountText(_numValue(invoice['balance']));
    setState(() => _view = _FeeView.collectDetails);
  }

  Future<void> _confirmPayment() async {
    final account = _selectedAccount;
    final invoice = _selectedInvoice;
    if (account == null || invoice == null) {
      _snack('Select a student invoice before recording payment.');
      return;
    }

    final invoiceId = _textValue(invoice['id']);
    final amount = double.tryParse(_paymentAmountController.text.trim()) ?? 0.0;
    final balance = _numValue(invoice['balance']);
    if (invoiceId.isEmpty) {
      _snack('Backend invoice ID is missing.');
      return;
    }
    if (amount <= 0) {
      _snack('Payment amount must be greater than zero.');
      return;
    }
    if (amount > balance) {
      _snack('Payment amount exceeds outstanding balance.');
      return;
    }

    final receiptNumber = _receiptNumber();
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.recordPayment(
        PaymentRequest(
          invoiceId: invoiceId,
          receiptNumber: receiptNumber,
          amountPaid: amount,
          paymentDate: _isoDate(_paymentDate),
          paymentMode: _selectedPaymentMode.label,
          transactionId: _transactionController.text.trim().isEmpty
              ? null
              : _transactionController.text.trim(),
        ),
      );
      final result = _FeePaymentResult(
        studentName: account.name,
        classLabel: account.classLabel,
        rollNumber: account.rollNumber,
        amount: amount,
        paymentMode: _selectedPaymentMode.label,
        transactionId: _transactionController.text.trim(),
        receiptNumber: receiptNumber,
        paymentDate: _paymentDate,
        balanceAfterPayment: (balance - amount).clamp(0, double.infinity),
      );
      await _loadData();
      if (!mounted) return;
      setState(() {
        _lastPayment = result;
        _view = _FeeView.paymentSuccess;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Unable to record payment: $error');
    }
  }

  Future<void> _pickPaymentDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    setState(() => _paymentDate = date);
  }

  Future<void> _pickReportRange() async {
    final today = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 1),
      initialDateRange: DateTimeRange(
        start: today.subtract(const Duration(days: 14)),
        end: today,
      ),
    );
    if (range == null || !mounted) return;
    setState(() {
      _reportRange =
          '${_displayDate(range.start)} - ${_displayDate(range.end)}';
    });
  }

  Future<void> _sendRemindersForDues() async {
    final dues = _filteredDueAccounts;
    if (dues.isEmpty) return;
    setState(() => _saving = true);
    var sent = 0;
    try {
      for (final account in dues) {
        final invoice = _primaryDueInvoice(account);
        if (invoice == null) continue;
        await BackendApiClient.instance.createRaw('/fees/reminders', {
          'invoice_id': _textValue(invoice['id']),
          'student_id': account.studentId,
          'message':
              'Payment reminder for outstanding balance ${_money(account.balance)}',
        });
        sent++;
      }
      if (!mounted) return;
      _snack('Queued $sent fee reminder(s).', success: true);
    } catch (error) {
      if (!mounted) return;
      _snack('Unable to send reminders: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestReportExport(_FeeReportDefinition report) async {
    try {
      await BackendApiClient.instance.createReportExport(
        '/fees/reports/exports',
        reportTitle: report.title,
        reportType: report.reportType,
        format: 'pdf',
        scope: 'principal',
        parameters: {
          'date_range': _reportRange,
          'structure_count': _structureBundles.length,
          'student_count': _studentAccounts.length,
          'outstanding_total': _totalDue,
          'source': 'principal_fees',
        },
      );
      _snack('${report.title} export queued.', success: true);
    } catch (error) {
      _snack('Unable to generate report: $error');
    }
  }

  Future<void> _previewLastReceipt() async {
    final result = _lastPayment;
    if (result == null) return;
    try {
      final pdfService = PdfService.getInstance();
      final bytes = await pdfService.generateFeeReceipt(
        receiptNo: result.receiptNumber,
        studentName: result.studentName,
        className: result.classLabel,
        rollNo: result.rollNumber,
        parentName: 'Parent',
        feeItems: [
          {
            'description': 'Fee payment',
            'amount': result.amount,
            'status': 'Paid',
          },
        ],
        totalAmount: result.amount + result.balanceAfterPayment,
        paidAmount: result.amount,
        balance: result.balanceAfterPayment,
        paymentMode: result.paymentMode,
        paymentDate: result.paymentDate,
      );
      if (!mounted) return;
      await pdfService.previewDocument(context, bytes, 'Fee Receipt');
    } catch (error) {
      _snack('Unable to preview receipt: $error');
    }
  }

  void _openClassesHubForFees({String gradeId = '', String sectionId = ''}) {
    Navigator.pushNamed(
      context,
      AppRoutes.principalClasses,
      arguments: {
        'class_hub_action': 'fees',
        'action': 'fees',
        'selectedStep': 'fee_setup',
        if (gradeId.isNotEmpty) 'grade_id': gradeId,
        if (gradeId.isNotEmpty) 'classId': gradeId,
        if (sectionId.isNotEmpty) 'section_id': sectionId,
        if (sectionId.isNotEmpty) 'sectionId': sectionId,
        'source': 'principal_fees',
      },
    );
  }

  List<_FeeStructureBundle> get _structureBundles {
    final grouped = <String, List<_FeeComponent>>{};
    for (final row in _feeStructures) {
      final gradeId = _textValue(row['grade_id']);
      final yearId = _textValue(row['academic_year_id']);
      final key = '$gradeId::$yearId';
      grouped.putIfAbsent(key, () => []).add(_FeeComponent.fromRow(row));
    }

    final rows = grouped.entries.map((entry) {
      final components = entry.value;
      final first = components.first.source;
      final gradeId = _textValue(first['grade_id']);
      final yearId = _textValue(first['academic_year_id']);
      final classLabel = _classLabelForGrade(
        gradeId,
        fallback: _textValue(first['class'], fallback: 'Class pending'),
      );
      final yearLabel = _yearLabelForId(
        yearId,
        fallback: _textValue(first['academic_year'], fallback: 'Academic year'),
      );
      return _FeeStructureBundle(
        id: entry.key,
        gradeId: gradeId,
        academicYearId: yearId,
        title: '$classLabel Fee Structure $yearLabel',
        classLabel: classLabel,
        academicYearLabel: yearLabel,
        components: components..sort((a, b) => a.name.compareTo(b.name)),
        isActive: components.any((item) => item.status != 'Draft'),
      );
    }).toList()..sort((a, b) => a.title.compareTo(b.title));

    return rows;
  }

  List<_FeeStudentAccount> get _studentAccounts {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final invoice in _invoices) {
      final key = _textValue(
        invoice['student_id'],
        fallback: _textValue(invoice['name']),
      );
      if (key.isEmpty) continue;
      grouped.putIfAbsent(key, () => []).add(invoice);
    }

    final rows = grouped.entries.map((entry) {
      final invoices = entry.value
        ..sort(
          (a, b) =>
              _sortDate(a['due_date']).compareTo(_sortDate(b['due_date'])),
        );
      final first = invoices.first;
      final payments = invoices.expand(_normalizePayments).toList()
        ..sort((a, b) => _sortDate(b['date']).compareTo(_sortDate(a['date'])));
      final total = invoices.fold<double>(
        0,
        (sum, row) => sum + _numValue(row['total']),
      );
      final paid = invoices.fold<double>(
        0,
        (sum, row) => sum + _numValue(row['paid']),
      );
      final balance = invoices.fold<double>(
        0,
        (sum, row) => sum + _numValue(row['balance']),
      );
      return _FeeStudentAccount(
        studentId: entry.key,
        name: _textValue(first['name'], fallback: 'Student'),
        rollNumber: _textValue(
          first['roll'],
          fallback: _textValue(first['student_code'], fallback: entry.key),
        ),
        classLabel: _textValue(first['class'], fallback: 'Class pending'),
        academicYearLabel: _textValue(
          first['academic_year'],
          fallback: 'Academic year',
        ),
        structureTitle: _structureTitleForInvoice(first),
        gradeId: _textValue(first['grade_id']),
        academicYearId: _textValue(first['academic_year_id']),
        photoUrl: _textValue(first['photo_url']),
        total: total,
        paid: paid,
        balance: balance,
        invoices: invoices,
        payments: payments,
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return rows;
  }

  List<_FeeStructureBundle> get _filteredStructures {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _structureBundles;
    return _structureBundles.where((bundle) {
      final haystack = [
        bundle.title,
        bundle.classLabel,
        bundle.academicYearLabel,
        ...bundle.components.map((component) => component.name),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<_FeeStudentAccount> get _filteredStudentAccounts {
    final structure = _selectedStructure;
    final query = _query.trim().toLowerCase();
    return _studentAccounts.where((account) {
      if (structure != null) {
        final sameGrade =
            structure.gradeId.isEmpty ||
            account.gradeId.isEmpty ||
            account.gradeId == structure.gradeId;
        final sameYear =
            structure.academicYearId.isEmpty ||
            account.academicYearId.isEmpty ||
            account.academicYearId == structure.academicYearId;
        if (!sameGrade || !sameYear) return false;
      }
      if (!_matchesStatus(account)) return false;
      if (query.isEmpty) return true;
      final haystack = [
        account.name,
        account.rollNumber,
        account.classLabel,
        account.status,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<_FeeStudentAccount> get _filteredDueAccounts {
    final query = _query.trim().toLowerCase();
    return _studentAccounts.where((account) {
      if (account.balance <= 0) return false;
      if (query.isEmpty) return true;
      final haystack = [
        account.name,
        account.rollNumber,
        account.classLabel,
        account.status,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList()..sort((a, b) => b.balance.compareTo(a.balance));
  }

  bool _matchesStatus(_FeeStudentAccount account) {
    return switch (_statusFilter) {
      _FeeStatusFilter.all => true,
      _FeeStatusFilter.paid => account.status == 'Paid',
      _FeeStatusFilter.partial => account.status == 'Partial',
      _FeeStatusFilter.unpaid => account.status == 'Unpaid',
      _FeeStatusFilter.due => account.balance > 0,
    };
  }

  Map<String, dynamic>? _primaryDueInvoice(_FeeStudentAccount account) {
    final due =
        account.invoices
            .where((invoice) => _numValue(invoice['balance']) > 0)
            .toList()
          ..sort(
            (a, b) =>
                _sortDate(a['due_date']).compareTo(_sortDate(b['due_date'])),
          );
    return due.isEmpty ? null : due.first;
  }

  _FeeStructureBundle? _reselectStructure(_FeeStructureBundle? current) {
    if (current == null) return null;
    return _structureBundles.firstWhereOrNull((row) => row.id == current.id);
  }

  _FeeStudentAccount? _reselectAccount(_FeeStudentAccount? current) {
    if (current == null) return null;
    return _studentAccounts.firstWhereOrNull(
      (row) => row.studentId == current.studentId,
    );
  }

  Map<String, dynamic>? _reselectInvoice(Map<String, dynamic>? current) {
    if (current == null) return null;
    final id = _textValue(current['id']);
    return _invoices.firstWhereOrNull((row) => _textValue(row['id']) == id);
  }

  Map<String, dynamic> _normalizeFeeStructure(Map<String, dynamic> row) {
    final category = _mapValue(row['fee_category']);
    final grade = _mapValue(row['grade']);
    final year = _mapValue(row['academic_year']);
    return {
      ...row,
      'id': _textValue(row['id']),
      'grade_id': _textValue(row['grade_id'] ?? grade['id']),
      'academic_year_id': _textValue(row['academic_year_id'] ?? year['id']),
      'class': _textValue(
        grade['grade_name'] ?? grade['name'],
        fallback: _textValue(row['class']),
      ),
      'academic_year': _textValue(
        year['year_label'] ?? year['name'],
        fallback: _textValue(row['academic_year_label']),
      ),
      'category': _textValue(
        category['category_name'] ?? category['name'],
        fallback: 'Fee',
      ),
      'frequency': _frequencyLabel(row['frequency'] ?? category['frequency']),
      'amount': _numValue(row['amount']),
      'status': _textValue(row['status'], fallback: 'Active'),
    };
  }

  Map<String, dynamic> _normalizeInvoice(Map<String, dynamic> row) {
    final student = _mapValue(row['student']);
    final section = _mapValue(student['current_section'] ?? row['section']);
    final grade = _mapValue(section['grade'] ?? row['grade']);
    final year = _mapValue(row['academic_year']);
    final classLabel = [
      _textValue(grade['grade_name'] ?? row['grade_name']),
      _textValue(section['section_name'] ?? row['section_name']),
    ].where((part) => part.isNotEmpty).join(' - ');
    final name = _studentName(
      student,
      fallback: _textValue(row['student_name']),
    );
    return {
      ...row,
      'id': _textValue(row['id']),
      'student_id': _textValue(row['student_id']),
      'student_code': _textValue(student['student_code']),
      'roll': _textValue(
        student['admission_number'] ?? student['student_code'],
        fallback: _textValue(row['roll']),
      ),
      'name': name,
      'class': classLabel.isEmpty
          ? _textValue(row['class'], fallback: 'Class pending')
          : classLabel,
      'section_id': _textValue(
        row['section_id'] ?? section['id'] ?? section['section_id'],
      ),
      'grade_id': _textValue(
        row['grade_id'] ?? section['grade_id'] ?? grade['id'],
      ),
      'academic_year_id': _textValue(row['academic_year_id'] ?? year['id']),
      'academic_year': _textValue(
        year['year_label'] ?? row['academic_year_label'],
        fallback: 'Academic year',
      ),
      'photo_url': _textValue(student['photo_url'] ?? student['photo']),
      'invoice_number': _textValue(row['invoice_number']),
      'total': _numValue(row['total_amount'] ?? row['net_amount']),
      'discount': _numValue(row['discount_amount']),
      'paid': _numValue(row['paid_amount']),
      'balance': _numValue(row['balance']),
      'status': _textValue(row['status'], fallback: 'pending'),
      'due_date': row['due_date'],
    };
  }

  Iterable<Map<String, dynamic>> _normalizePayments(
    Map<String, dynamic> invoice,
  ) {
    final payments = invoice['payments'];
    if (payments is! List) return const [];
    return payments.whereType<Map>().map((payment) {
      final row = Map<String, dynamic>.from(payment);
      return {
        ...row,
        'student_id': _textValue(invoice['student_id']),
        'invoice_id': _textValue(invoice['id']),
        'name': _textValue(invoice['name'], fallback: 'Student'),
        'class': _textValue(invoice['class'], fallback: 'Class'),
        'amount': _numValue(row['amount_paid'] ?? row['amount']),
        'mode': _textValue(row['payment_mode'] ?? row['mode']),
        'date': row['payment_date'] ?? row['created_at'],
        'receipt': _textValue(row['receipt_number'] ?? row['receipt']),
        'transaction_id': _textValue(row['transaction_id']),
      };
    });
  }

  String _structureTitleForInvoice(Map<String, dynamic> invoice) {
    final bundle = _structureBundles.firstWhereOrNull((structure) {
      return structure.gradeId == _textValue(invoice['grade_id']) &&
          structure.academicYearId == _textValue(invoice['academic_year_id']);
    });
    return bundle?.title ??
        '${_textValue(invoice['class'], fallback: 'Class')} Fee Structure ${_textValue(invoice['academic_year'], fallback: '')}'
            .trim();
  }

  String _classLabelForGrade(String gradeId, {required String fallback}) {
    final grade = _grades.firstWhereOrNull((row) => row.id == gradeId);
    return grade?.gradeName.trim().isNotEmpty == true
        ? grade!.gradeName
        : fallback;
  }

  String _yearLabelForId(String yearId, {required String fallback}) {
    final year = _academicYears.firstWhereOrNull((row) => row.id == yearId);
    return year?.yearLabel.trim().isNotEmpty == true
        ? year!.yearLabel
        : fallback;
  }

  String _studentName(Map<String, dynamic> student, {String fallback = ''}) {
    final direct = _textValue(student['name']);
    if (direct.isNotEmpty) return direct;
    final full =
        '${_textValue(student['first_name'])} ${_textValue(student['last_name'])}'
            .trim();
    return full.isEmpty ? fallback : full;
  }

  String _frequencyLabel(Object? value) {
    final text = _textValue(value, fallback: 'Term');
    final normalized = text.toLowerCase().replaceAll('-', '_');
    if (normalized.contains('one')) return 'One Time';
    if (normalized.contains('year')) return 'Yearly';
    if (normalized.contains('month')) return 'Monthly';
    return 'Term';
  }

  double get _totalDue =>
      _invoices.fold(0, (sum, row) => sum + _numValue(row['balance']));

  double get _totalCollected =>
      _recentPayments.fold(0, (sum, row) => sum + _numValue(row['amount']));

  String _statusFilterLabel(_FeeStatusFilter filter) {
    return switch (filter) {
      _FeeStatusFilter.all => 'All',
      _FeeStatusFilter.paid => 'Paid',
      _FeeStatusFilter.partial => 'Partial',
      _FeeStatusFilter.unpaid => 'Unpaid',
      _FeeStatusFilter.due => 'Due',
    };
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('paid') && !lower.contains('partial')) {
      return const Color(0xFF16A34A);
    }
    if (lower.contains('partial')) return const Color(0xFFF59E0B);
    if (lower.contains('due') || lower.contains('unpaid')) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF2563EB);
  }

  DateTime _sortDate(Object? value) {
    return DateTime.tryParse(_textValue(value)) ?? DateTime(1970);
  }

  Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  double _numValue(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_textValue(value)) ?? 0;
  }

  String _textValue(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _money(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: amount.truncateToDouble() == amount ? 0 : 2,
    );
    return formatter.format(amount);
  }

  String _amountText(double amount) {
    return amount.truncateToDouble() == amount
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
  }

  String _displayDate(DateTime value) =>
      DateFormat('dd MMM yyyy').format(value);

  String _isoDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  String _receiptNumber() {
    final stamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    return 'RCP-$stamp';
  }

  String _suggestedTransactionId() {
    return 'UPI${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
  }

  void _snack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
      ),
    );
  }
}

class _FeePage extends StatelessWidget {
  final Widget header;
  final List<Widget> children;

  const _FeePage({required this.header, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 116),
      children: [header, const SizedBox(height: 14), ...children],
    );
  }
}

class _FeeHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final VoidCallback? onLeading;
  final Widget? trailing;

  const _FeeHeader({
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    this.onLeading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: title == 'Fees' ? 'Open menu' : 'Back',
          onPressed: onLeading,
          icon: Icon(leadingIcon, size: 22),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
        trailing ?? const SizedBox(width: 48),
      ],
    );
  }
}

class _FeeCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _FeeCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: card,
    );
  }
}

class _FeeMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _FeeMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _FeeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _FeeIconBadge(icon: icon, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeeMiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _FeeMiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _FeeCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FeeIconBadge(icon: icon, color: color, compact: true),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeeActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _FeeCard(
      onTap: onTap,
      child: Row(
        children: [
          _FeeIconBadge(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
        ],
      ),
    );
  }
}

class _FeeSearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _FeeSearchBox({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
      ),
    );
  }
}

class _FeeSectionTitle extends StatelessWidget {
  final String label;

  const _FeeSectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: AppTheme.onSurface,
      ),
    );
  }
}

class _FeeStructureCard extends StatelessWidget {
  final _FeeStructureBundle bundle;
  final VoidCallback onTap;

  const _FeeStructureCard({required this.bundle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _FeeCard(
      onTap: onTap,
      child: Row(
        children: [
          _FeeIconBadge(
            icon: Icons.assignment_outlined,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bundle.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${bundle.classLabel}\n${bundle.components.length} Components',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _FeeStatusPill(
            label: bundle.statusLabel,
            color: bundle.isActive
                ? const Color(0xFF16A34A)
                : const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _FeeComponentTile extends StatelessWidget {
  final _FeeComponent component;

  const _FeeComponentTile({required this.component});

  @override
  Widget build(BuildContext context) {
    return _FeeCard(
      child: Row(
        children: [
          _FeeIconBadge(
            icon: component.frequency == 'One Time'
                ? Icons.assignment_outlined
                : Icons.account_balance_wallet_outlined,
            color: component.frequency == 'One Time'
                ? const Color(0xFF7C3AED)
                : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  component.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  component.frequency,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹ ',
              decimalDigits: 0,
            ).format(component.amount),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _FeeStudentRow extends StatelessWidget {
  final _FeeStudentAccount account;
  final VoidCallback onTap;

  const _FeeStudentRow({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _FeeCard(
      onTap: onTap,
      child: Row(
        children: [
          _FeeAvatar(label: account.name, photoUrl: account.photoUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  account.rollNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _FeeStatusPill(
            label: account.status,
            color: _studentStatusColor(account.status),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: Text(
              NumberFormat.currency(
                locale: 'en_IN',
                symbol: '₹ ',
                decimalDigits: 0,
              ).format(account.balance > 0 ? account.balance : account.total),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeDueStudentTile extends StatelessWidget {
  final _FeeStudentAccount account;
  final VoidCallback onTap;

  const _FeeDueStudentTile({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _FeeCard(
      onTap: onTap,
      child: Row(
        children: [
          _FeeAvatar(label: account.name, photoUrl: account.photoUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  account.rollNumber,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹ ',
              decimalDigits: 0,
            ).format(account.balance),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          const _FeeStatusPill(label: 'Due', color: Color(0xFFEF4444)),
        ],
      ),
    );
  }
}

class _FeePaymentHistoryTile extends StatelessWidget {
  final Map<String, dynamic> payment;

  const _FeePaymentHistoryTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    final amount = _num(payment['amount']);
    final date = DateTime.tryParse('${payment['date'] ?? ''}');
    return _FeeCard(
      child: Row(
        children: [
          _FeeIconBadge(
            icon: Icons.payments_outlined,
            color: const Color(0xFF16A34A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date == null
                      ? 'Payment'
                      : DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${payment['mode'] ?? 'Payment'}\n${payment['receipt'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹ ',
              decimalDigits: 0,
            ).format(amount),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  static double _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }
}

class _FeePaymentModeTile extends StatelessWidget {
  final _PaymentMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _FeePaymentModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _FeeCard(
      onTap: onTap,
      child: Row(
        children: [
          _FeeIconBadge(icon: mode.icon, color: mode.color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mode.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
          Radio<bool>(
            value: true,
            groupValue: selected,
            onChanged: (_) => onTap(),
          ),
        ],
      ),
    );
  }
}

class _FeeReportTile extends StatelessWidget {
  final _FeeReportDefinition report;
  final VoidCallback onTap;

  const _FeeReportTile({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _FeeCard(
      onTap: onTap,
      child: Row(
        children: [
          _FeeIconBadge(icon: report.icon, color: report.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
        ],
      ),
    );
  }
}

class _FeeInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;
  final bool danger;

  const _FeeInfoTile({
    required this.label,
    required this.value,
    this.highlighted = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppTheme.error
        : highlighted
        ? AppTheme.success
        : AppTheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.successContainer
            : danger
            ? AppTheme.errorContainer
            : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              color: AppTheme.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeAmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool danger;

  const _FeeAmountRow({
    required this.label,
    required this.value,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: danger ? AppTheme.error : AppTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool compact;

  const _FeeIconBadge({
    required this.icon,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 24.0 : 34.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: compact ? 15 : 19),
    );
  }
}

class _FeeStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _FeeStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _FeeAvatar extends StatelessWidget {
  final String label;
  final String photoUrl;

  const _FeeAvatar({required this.label, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final initials = label
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFE0EAFF),
      foregroundColor: AppTheme.primary,
      backgroundImage: photoUrl.trim().isEmpty ? null : NetworkImage(photoUrl),
      child: photoUrl.trim().isEmpty
          ? Text(
              initials.isEmpty ? 'ST' : initials,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            )
          : null,
    );
  }
}

class _FeeInfoBanner extends StatelessWidget {
  final String text;

  const _FeeInfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.infoContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withAlpha(40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.onSurface,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _FeeEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(icon, size: 46, color: AppTheme.muted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeeSuccessCircle extends StatelessWidget {
  const _FeeSuccessCircle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 78,
        height: 78,
        decoration: const BoxDecoration(
          color: AppTheme.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 42),
      ),
    );
  }
}

class _FeeStructureBundle {
  final String id;
  final String gradeId;
  final String academicYearId;
  final String title;
  final String classLabel;
  final String academicYearLabel;
  final List<_FeeComponent> components;
  final bool isActive;

  const _FeeStructureBundle({
    required this.id,
    required this.gradeId,
    required this.academicYearId,
    required this.title,
    required this.classLabel,
    required this.academicYearLabel,
    required this.components,
    required this.isActive,
  });

  String get statusLabel => isActive ? 'Active' : 'Draft';

  double get total => components.fold(0, (sum, row) => sum + row.amount);

  double get oneTimeTotal => components
      .where((row) => row.frequency == 'One Time')
      .fold(0, (sum, row) => sum + row.amount);

  double get yearlyTotal => components
      .where((row) => row.frequency != 'One Time')
      .fold(0, (sum, row) => sum + row.amount);
}

class _FeeComponent {
  final String name;
  final String frequency;
  final double amount;
  final String status;
  final Map<String, dynamic> source;

  const _FeeComponent({
    required this.name,
    required this.frequency,
    required this.amount,
    required this.status,
    required this.source,
  });

  factory _FeeComponent.fromRow(Map<String, dynamic> row) {
    return _FeeComponent(
      name: '${row['category'] ?? 'Fee'}',
      frequency: '${row['frequency'] ?? 'Term'}',
      amount: row['amount'] is num
          ? (row['amount'] as num).toDouble()
          : double.tryParse('${row['amount'] ?? ''}') ?? 0,
      status: '${row['status'] ?? 'Active'}',
      source: row,
    );
  }
}

class _FeeStudentAccount {
  final String studentId;
  final String name;
  final String rollNumber;
  final String classLabel;
  final String academicYearLabel;
  final String structureTitle;
  final String gradeId;
  final String academicYearId;
  final String photoUrl;
  final double total;
  final double paid;
  final double balance;
  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> payments;

  const _FeeStudentAccount({
    required this.studentId,
    required this.name,
    required this.rollNumber,
    required this.classLabel,
    required this.academicYearLabel,
    required this.structureTitle,
    required this.gradeId,
    required this.academicYearId,
    required this.photoUrl,
    required this.total,
    required this.paid,
    required this.balance,
    required this.invoices,
    required this.payments,
  });

  String get status {
    if (balance <= 0) return 'Paid';
    if (paid > 0) return 'Partial';
    return 'Unpaid';
  }
}

class _FeePaymentResult {
  final String studentName;
  final String classLabel;
  final String rollNumber;
  final double amount;
  final String paymentMode;
  final String transactionId;
  final String receiptNumber;
  final DateTime paymentDate;
  final double balanceAfterPayment;

  const _FeePaymentResult({
    required this.studentName,
    required this.classLabel,
    required this.rollNumber,
    required this.amount,
    required this.paymentMode,
    required this.transactionId,
    required this.receiptNumber,
    required this.paymentDate,
    required this.balanceAfterPayment,
  });
}

class _FeeReportDefinition {
  final String title;
  final String subtitle;
  final String reportType;
  final IconData icon;
  final Color color;

  const _FeeReportDefinition({
    required this.title,
    required this.subtitle,
    required this.reportType,
    required this.icon,
    required this.color,
  });
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T value) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}

Color _studentStatusColor(String status) {
  final lower = status.toLowerCase();
  if (lower == 'paid') return const Color(0xFF16A34A);
  if (lower == 'partial') return const Color(0xFFF59E0B);
  return const Color(0xFFEF4444);
}

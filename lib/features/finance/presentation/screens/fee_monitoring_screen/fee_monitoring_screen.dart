import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_payment_request_decision_screen.dart';

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
  final _overviewScrollController = ScrollController();
  final _upiIdController = TextEditingController();
  final _payeeNameController = TextEditingController();
  final _qrNoteController = TextEditingController();
  final Set<String> _selectedPaymentMonths = <String>{};

  bool _loading = true;
  bool _saving = false;
  bool _savingPaymentConfig = false;
  bool _uploadingQr = false;
  bool _showFeeNavigation = false;
  bool _routeArgsApplied = false;
  bool _classHubFilter = false;
  bool _generatingReport = false;
  String? _error;
  String _query = '';
  String _reportRange = '01 May 2024 - 15 May 2024';
  String _selectedAcademicYearId = '';
  String _selectedGradeId = '';
  String _selectedSectionId = '';
  _FeeView _view = _FeeView.home;
  _FeeStatusFilter _statusFilter = _FeeStatusFilter.all;
  _PaymentMode _selectedPaymentMode = _PaymentMode.onlinePayment;
  DateTime _paymentDate = DateTime.now();

  List<Map<String, dynamic>> _feeStructures = const [];
  List<Map<String, dynamic>> _invoices = const [];
  List<Map<String, dynamic>> _recentPayments = const [];
  List<Map<String, dynamic>> _paymentRequests = const [];
  List<Map<String, dynamic>> _concessions = const [];
  List<AcademicYearModel> _academicYears = const [];
  List<GradeModel> _grades = const [];
  List<SectionModel> _sections = const [];
  Map<String, dynamic> _paymentConfig = const {};

  _FeeStructureBundle? _selectedStructure;
  _FeeStudentAccount? _selectedAccount;
  Map<String, dynamic>? _selectedInvoice;
  _FeePaymentResult? _lastPayment;

  @override
  void initState() {
    super.initState();
    _overviewScrollController.addListener(_handleOverviewScroll);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgsApplied) return;
    _routeArgsApplied = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final gradeId = _textValue(args['grade_id'] ?? args['classId']);
      final sectionId = _textValue(args['section_id'] ?? args['sectionId']);
      if (gradeId.isNotEmpty || sectionId.isNotEmpty) {
        _selectedGradeId = gradeId;
        _selectedSectionId = sectionId;
        _classHubFilter = true;
        // After data loads, _loadData will set _view to students.
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _paymentAmountController.dispose();
    _transactionController.dispose();
    _notesController.dispose();
    _overviewScrollController
      ..removeListener(_handleOverviewScroll)
      ..dispose();
    _upiIdController.dispose();
    _payeeNameController.dispose();
    _qrNoteController.dispose();
    super.dispose();
  }

  List<String> _invoiceMonthList(Map<String, dynamic>? invoice, String key) {
    final raw = invoice?[key];
    if (raw is! List) return const <String>[];
    return raw
        .map((value) => '$value'.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  bool _isTuitionInvoice(Map<String, dynamic>? invoice) =>
      _textValue(invoice?['fee_type']) == 'tuition';

  List<String> _allowedInvoiceMonths(Map<String, dynamic>? invoice) =>
      _invoiceMonthList(invoice, 'allowed_month_names');

  List<String> _paidInvoiceMonths(Map<String, dynamic>? invoice) =>
      _invoiceMonthList(invoice, 'paid_month_names');

  List<String> _unpaidInvoiceMonths(Map<String, dynamic>? invoice) {
    final allowed = _allowedInvoiceMonths(invoice);
    final paid = _paidInvoiceMonths(invoice).toSet();
    return allowed.where((month) => !paid.contains(month)).toList();
  }

  void _seedManualPaymentMonths(Map<String, dynamic>? invoice) {
    _selectedPaymentMonths.clear();
    final unpaid = _unpaidInvoiceMonths(invoice);
    if (_isTuitionInvoice(invoice) && unpaid.isNotEmpty) {
      _selectedPaymentMonths.add(unpaid.first);
    }
  }

  void _recalculateManualPaymentAmount() {
    final invoice = _selectedInvoice;
    if (invoice == null) return;
    if (!_isTuitionInvoice(invoice)) {
      _paymentAmountController.text = _amountText(
        _numValue(invoice['balance']),
      );
      return;
    }
    final unpaid = _unpaidInvoiceMonths(invoice);
    final monthly = _numValue(invoice['monthly_amount']);
    if (_selectedPaymentMonths.isEmpty || monthly <= 0) {
      _paymentAmountController.text = _amountText(0);
      return;
    }
    final amount = _selectedPaymentMonths.length == unpaid.length
        ? _numValue(invoice['balance'])
        : monthly * _selectedPaymentMonths.length;
    _paymentAmountController.text = _amountText(amount);
  }

  void _selectManualMonthsForAmount(double amount) {
    final invoice = _selectedInvoice;
    if (!_isTuitionInvoice(invoice)) return;
    final unpaid = _unpaidInvoiceMonths(invoice);
    final monthly = _numValue(invoice?['monthly_amount']);
    _selectedPaymentMonths.clear();
    if (unpaid.isEmpty || monthly <= 0 || amount <= 0) return;
    final balance = _numValue(invoice?['balance']);
    final cappedAmount = amount > balance && balance > 0 ? balance : amount;
    final selectedCount = (cappedAmount / monthly).round().clamp(
      1,
      unpaid.length,
    );
    _selectedPaymentMonths.addAll(unpaid.take(selectedCount));
  }

  void _syncManualMonthsFromAmount() {
    final invoice = _selectedInvoice;
    if (!_isTuitionInvoice(invoice)) return;
    final amount = double.tryParse(_paymentAmountController.text.trim()) ?? 0;
    setState(() => _selectManualMonthsForAmount(amount));
  }

  double _manualPaymentAmountForSelection(Map<String, dynamic> invoice) {
    if (!_isTuitionInvoice(invoice)) return _numValue(invoice['balance']);
    final unpaid = _unpaidInvoiceMonths(invoice);
    final monthly = _numValue(invoice['monthly_amount']);
    if (_selectedPaymentMonths.isEmpty || monthly <= 0) return 0;
    return _selectedPaymentMonths.length == unpaid.length
        ? _numValue(invoice['balance'])
        : monthly * _selectedPaymentMonths.length;
  }

  bool _canAddManualMonth(String month) {
    final invoice = _selectedInvoice;
    final unpaid = _unpaidInvoiceMonths(invoice);
    if (!_isTuitionInvoice(invoice) ||
        _paidInvoiceMonths(invoice).contains(month)) {
      return false;
    }
    final nextIndex = _selectedPaymentMonths.length;
    if (nextIndex >= unpaid.length) return false;
    return unpaid[nextIndex] == month;
  }

  bool _canRemoveManualMonth(String month) {
    if (!_selectedPaymentMonths.contains(month) ||
        _selectedPaymentMonths.length <= 1) {
      return false;
    }
    final ordered = _unpaidInvoiceMonths(
      _selectedInvoice,
    ).where(_selectedPaymentMonths.contains).toList(growable: false);
    return ordered.isNotEmpty && ordered.last == month;
  }

  void _toggleManualMonth(String month) {
    final invoice = _selectedInvoice;
    if (!_isTuitionInvoice(invoice)) return;
    setState(() {
      if (_selectedPaymentMonths.contains(month)) {
        if (_canRemoveManualMonth(month)) {
          _selectedPaymentMonths.remove(month);
        }
      } else if (_canAddManualMonth(month)) {
        _selectedPaymentMonths.add(month);
      }
      _recalculateManualPaymentAmount();
    });
  }

  void _handleOverviewScroll() {
    final shouldShow =
        _overviewScrollController.hasClients &&
        _overviewScrollController.offset > 280;
    if (shouldShow != _showFeeNavigation && mounted) {
      setState(() => _showFeeNavigation = shouldShow);
    }
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
        api.getSections(),
      ]);

      final structures = (results[0] as List<Map<String, dynamic>>)
          .map(_normalizeFeeStructure)
          .toList();
      final invoices = (results[1] as List<Map<String, dynamic>>)
          .map(_normalizeInvoice)
          .toList();
      final payments = invoices.expand(_normalizePayments).toList()
        ..sort((a, b) => _sortDate(b['date']).compareTo(_sortDate(a['date'])));

      List<Map<String, dynamic>> prList = const [];
      try {
        prList = (await api.getParentPaymentRequests()).where((request) {
          final status = _textValue(request['status']).toLowerCase();
          return status == 'pending' ||
              status == 'pending_verification' ||
              status == 'clarification_required';
        }).toList();
      } catch (_) {
        // Payment requests endpoint may not exist yet — fail gracefully.
      }
      List<Map<String, dynamic>> concessionList = const [];
      try {
        concessionList = await api.getRawList('/fees/concessions');
      } catch (_) {
        // Concessions endpoint may not exist yet — fail gracefully.
      }
      Map<String, dynamic> paymentConfig = const {};
      try {
        paymentConfig = await api.getPaymentConfig();
      } catch (_) {
        paymentConfig = const {};
      }

      if (!mounted) return;
      final years = results[2] as List<AcademicYearModel>;
      final grades = results[3] as List<GradeModel>;
      final sections = results[4] as List<SectionModel>;
      final selectedYear = _selectedAcademicYearId.isNotEmpty
          ? _selectedAcademicYearId
          : (years.firstWhereOrNull((year) => year.isCurrent)?.id ??
                (years.isEmpty ? '' : years.first.id));
      setState(() {
        _feeStructures = structures;
        _invoices = invoices;
        _recentPayments = payments;
        _paymentRequests = prList;
        _concessions = concessionList;
        _academicYears = years;
        _grades = grades;
        _sections = sections;
        _paymentConfig = paymentConfig;
        _selectedAcademicYearId = selectedYear;
        _selectedStructure = _reselectStructure(_selectedStructure);
        _selectedAccount = _reselectAccount(_selectedAccount);
        _selectedInvoice = _reselectInvoice(_selectedInvoice);
        _loading = false;
      });
      _syncPaymentConfigControllers();
      // Auto-navigate to students when opened from the Classes Hub.
      if (_classHubFilter && mounted) {
        setState(() => _view = _FeeView.students);
      }
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Always use internal _goBack() navigation instead of native pop.
        // This ensures back button stays within the fees module view hierarchy.
        if (!didPop) _goBack();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF7FAFF),
        drawer: PrincipalDrawer(
          selectedIndex: PrincipalNav.fees,
          onDestinationSelected: (_) {},
        ),
        bottomNavigationBar: const PrincipalShellBottomBar(),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: context.appTheme.primary,
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          for (var i = 0; i < 5; i++) ...[
            Container(
              height: i == 0 ? 100 : 64,
              decoration: BoxDecoration(
                color: context.appTheme.surfaceVariant.withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.appTheme.surfaceVariant.withOpacity(0.6),
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
                          width: 140,
                          height: 12,
                          decoration: BoxDecoration(
                            color: context.appTheme.surfaceVariant.withOpacity(
                              0.6,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 90,
                          height: 10,
                          decoration: BoxDecoration(
                            color: context.appTheme.surfaceVariant.withOpacity(
                              0.6,
                            ),
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
    final selectedBundle = _selectedOverviewBundle;
    return _FeePage(
      controller: _overviewScrollController,
      header: _FeeHeader(
        title: 'Fees Overview',
        subtitle: 'Class-wise fee structures, payments, and parent QR',
        leadingIcon: Icons.menu_rounded,
        onLeading: () => _scaffoldKey.currentState?.openDrawer(),
        trailing: IconButton(
          tooltip: 'Refresh fees',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
        ),
      ),
      children: [
        _FeeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Academic Year',
                style: TextStyle(
                  color: context.appTheme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedAcademicYearId.isEmpty
                    ? null
                    : _selectedAcademicYearId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _academicYears
                    .map(
                      (year) => DropdownMenuItem(
                        value: year.id,
                        child: Text(year.yearLabel),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedAcademicYearId = value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _FeeCard(
          onTap: _showClassPicker,
          child: Row(
            children: [
              _FeeIconBadge(
                icon: Icons.groups_2_outlined,
                color: const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Class & Section',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedClassLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _FeeCard(
          child: Row(
            children: [
              _FeeIconBadge(
                icon: Icons.verified_outlined,
                color: const Color(0xFF16A34A),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FeeInfoTile(
                  label: 'Active Structure',
                  value: selectedBundle?.title ?? 'No active fee structure',
                ),
              ),
              _FeeStatusPill(
                label: selectedBundle == null ? 'Pending' : 'Active',
                color: selectedBundle == null
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF16A34A),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
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
            _FeeMetricTile(
              label: 'Concessions Granted',
              value: _money(
                _concessions
                    .where(
                      (c) =>
                          (_textValue(
                            c['status'],
                            fallback: 'pending',
                          ).toLowerCase()) ==
                          'approved',
                    )
                    .fold<double>(
                      0,
                      (sum, c) =>
                          sum +
                          (double.tryParse(
                                _textValue(
                                  c['amount'] ?? c['concession_amount'],
                                ),
                              ) ??
                              0),
                    ),
              ),
              icon: Icons.volunteer_activism_outlined,
              color: const Color(0xFF7C3AED),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _FeeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FeeSectionTitle('Collection Progress'),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: _collectionRate,
                          strokeWidth: 12,
                          backgroundColor: const Color(0xFFFEE2E2),
                          color: const Color(0xFF16A34A),
                        ),
                        Center(
                          child: Text(
                            '${(_collectionRate * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      children: [
                        _FeeInfoTile(
                          label: 'Collected',
                          value: _money(_totalCollected),
                        ),
                        const SizedBox(height: 10),
                        _FeeInfoTile(
                          label: 'Balance',
                          value: _money(_totalDue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _FeeCard(
          child: Row(
            children: [
              _FeeIconBadge(
                icon: Icons.qr_code_2_rounded,
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FeeInfoTile(
                  label: 'Parent Payment QR',
                  value: _textValue(
                    _paymentConfig['upi_id'],
                    fallback: _textValue(
                      _paymentConfig['payee_name'],
                      fallback: 'Not configured',
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showPaymentQrEditor,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Parent QR'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _FeeSectionTitle('Find It Faster'),
        const SizedBox(height: 10),
        _FeeActionRow(
          icon: Icons.rule_folder_outlined,
          iconColor: const Color(0xFF7C3AED),
          title: 'Review Parent Requests',
          subtitle: _paymentRequests.isEmpty
              ? 'No parent fee proofs are waiting right now'
              : '${_paymentRequests.length} request(s) waiting for review',
          onTap: _openAllPaymentRequests,
        ),
        _FeeActionRow(
          icon: Icons.payments_outlined,
          iconColor: const Color(0xFF16A34A),
          title: 'Manual Fee Update',
          subtitle:
              'Open a student ledger and record old cash or offline payments',
          onTap: _openStudentsForCollection,
        ),
        _FeeActionRow(
          icon: Icons.bar_chart_outlined,
          iconColor: const Color(0xFF2563EB),
          title: 'Reports',
          subtitle:
              'Collection summary, class-wise, student-wise, and outstanding reports',
          onTap: () => _setView(_FeeView.reports),
        ),
        _FeeActionRow(
          icon: Icons.qr_code_2_rounded,
          iconColor: const Color(0xFFF59E0B),
          title: 'Parent Payment QR',
          subtitle: 'Edit the QR details parents use before submitting proof',
          onTap: _showPaymentQrEditor,
        ),
        if (_paymentRequests.isNotEmpty) ...[
          const SizedBox(height: 20),
          _FeeSectionTitle('Review Requests (${_paymentRequests.length})'),
          const SizedBox(height: 10),
          for (final request in _paymentRequests.take(5))
            _PaymentRequestRow(
              request: request,
              onTap: () => _openPaymentRequestDecision(request),
            ),
          if (_paymentRequests.length > 5)
            TextButton(
              onPressed: _openAllPaymentRequests,
              child: Text('View all ${_paymentRequests.length} requests'),
            ),
        ],
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _showFeeNavigation
              ? Column(
                  key: const ValueKey('fee-navigation-visible'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FeeSectionTitle('Quick Actions'),
                    const SizedBox(height: 10),
                    _FeeActionRow(
                      icon: Icons.assignment_outlined,
                      iconColor: const Color(0xFF2563EB),
                      title: 'Manage Fee Structures',
                      subtitle: 'Create / Edit Structure',
                      onTap: () => _setView(_FeeView.structures),
                    ),
                    _FeeActionRow(
                      icon: Icons.calendar_month_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Fee Items & Payment Rules',
                      subtitle:
                          'Book & Kit is one-time; Tuition is split automatically for parents',
                      onTap: () {
                        final bundle =
                            selectedBundle ?? _structureBundles.firstOrNull;
                        if (bundle == null) {
                          _snack(
                            'Create / Edit Structure before planning installments.',
                          );
                          return;
                        }
                        _openStructureDetails(bundle);
                      },
                    ),
                    _FeeActionRow(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: const Color(0xFF16A34A),
                      title: 'Payments Overview',
                      subtitle: 'Collected, balance, partial and unpaid',
                      onTap: () => _setView(_FeeView.dues),
                    ),
                    _FeeActionRow(
                      icon: Icons.groups_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Student Payments',
                      subtitle: 'Student Fee Details and collection history',
                      onTap: _openStudentsForCollection,
                    ),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('fee-navigation-hidden')),
        ),
      ],
    );
  }

  Widget _buildStructuresView() {
    final rows = _filteredStructures;
    return _FeePage(
      header: _FeeHeader(
        title: 'Manage Fee Structures',
        subtitle: 'Create / Edit Structure',
        leadingIcon: Icons.arrow_back_rounded,
        onLeading: _goBack,
        trailing: IconButton(
          tooltip: 'Create / Edit Structure',
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: _showFeeStructureEditor,
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
          _FeeEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No fee structures found',
            message:
                'Create / Edit Structure from Fees to set up class-wise fee rules.',
            actionLabel: 'Create / Edit Structure',
            onAction: _showFeeStructureEditor,
          )
        else
          for (final bundle in rows)
            _FeeStructureCard(
              bundle: bundle,
              onTap: () => _openStructureDetails(bundle),
              onDelete: () => _deleteFeeStructureBundle(bundle),
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
        title: 'Class Fee Structure',
        subtitle: bundle.title,
        leadingIcon: Icons.arrow_back_rounded,
        onLeading: _goBack,
        trailing: IconButton(
          tooltip: 'Create / Edit Structure',
          icon: const Icon(Icons.edit_outlined),
          onPressed: _showFeeStructureEditor,
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
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: context.appTheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Applicable for ${bundle.classLabel}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.appTheme.muted,
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
              'Manage components and installment schedules from this Fees module so class, student, parent, and report data stay linked.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _showFeeStructureEditor,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Create / Edit Structure'),
        ),
        FilledButton.icon(
          onPressed: () => _openStudentsForCollection(structure: bundle),
          icon: const Icon(Icons.groups_outlined),
          label: const Text('View Students'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _deleteFeeStructureBundle(bundle),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFDC2626),
            side: const BorderSide(color: Color(0xFFDC2626)),
          ),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete Fee Structure'),
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
        subtitle: _selectedStructure != null
            ? '$title - ${_selectedStructure?.title ?? 'Fee Structure'}'
            : (_selectedGradeId.isNotEmpty
                  ? 'Viewing fees for $_selectedClassLabel'
                  : 'All fee accounts'),
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
        if (_selectedGradeId.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF2563EB),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Viewing class-specific fees for $_selectedClassLabel',
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedGradeId = '';
                      _selectedSectionId = '';
                      _classHubFilter = false;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.88,
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
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTheme.muted,
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
                  Expanded(
                    child: Text(
                      'Fee Structure',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.appTheme.muted,
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
        const _FeeSectionTitle('Invoices & Installments'),
        const SizedBox(height: 10),
        if (account.invoices.isEmpty)
          const _FeeEmptyState(
            icon: Icons.receipt_outlined,
            title: 'No invoices',
            message: 'No invoices have been generated for this student yet.',
          )
        else
          for (final invoice in account.invoices)
            _buildInvoiceInstallmentCard(invoice),
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
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: account.balance <= 0
                  ? null
                  : () => _openCollectForAccount(account),
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Manual Update'),
            ),
            OutlinedButton.icon(
              onPressed: () => _previewInvoicePdf(account),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Print Invoice'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showGrantConcessionSheet(account),
              icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
              label: const Text('Grant Concession'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollectModeView() {
    final account = _selectedAccount;
    if (account == null) {
      return _missingSelectionPage(
        title: 'Manual Fee Update',
        message: 'Select a student before recording an offline fee update.',
      );
    }

    return _FeePage(
      header: _FeeHeader(
        title: 'Manual Fee Update',
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
        _FeeInfoBanner(
          text:
              'Use this for cash or older offline payments. For tuition, record the next continuous unpaid months so parent UPI and principal cash stay in sync.',
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
    final invoice = _selectedInvoice;
    if (account == null) {
      return _missingSelectionPage(
        title: 'Manual Fee Update',
        message: 'Select a student before recording an offline fee update.',
      );
    }

    return _FeePage(
      header: _FeeHeader(
        title: 'Manual Fee Update',
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
              if (_isTuitionInvoice(invoice)) ...[
                Text(
                  'Tuition months',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.appTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the next continuous unpaid month range. Already paid months stay locked.',
                  style: TextStyle(fontSize: 12, color: context.appTheme.muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allowedInvoiceMonths(invoice).map((month) {
                    final isPaid = _paidInvoiceMonths(invoice).contains(month);
                    final isSelected = _selectedPaymentMonths.contains(month);
                    final canToggle =
                        _canAddManualMonth(month) ||
                        _canRemoveManualMonth(month);
                    return FilterChip(
                      label: Text(isPaid ? '$month Paid' : month),
                      selected: isPaid || isSelected,
                      onSelected: canToggle
                          ? (_) => _toggleManualMonth(month)
                          : null,
                      selectedColor: isPaid
                          ? context.appTheme.success.withOpacity(0.16)
                          : context.appTheme.primaryContainer,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedPaymentMonths.isEmpty
                      ? 'Pick the next payable month.'
                      : 'Selected months: ${_unpaidInvoiceMonths(invoice).where(_selectedPaymentMonths.contains).join(', ')}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _paymentAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount to be Paid',
                ),
                onChanged: (_) => _syncManualMonthsFromAmount(),
                onEditingComplete: () {
                  if (_isTuitionInvoice(invoice)) {
                    _paymentAmountController.text = _amountText(
                      _manualPaymentAmountForSelection(invoice!),
                    );
                  }
                  FocusScope.of(context).unfocus();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<_PaymentMode>(
                value: _selectedPaymentMode,
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
                decoration: const InputDecoration(
                  labelText: 'Reference Number (Optional)',
                ),
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
                style: TextStyle(
                  color: context.appTheme.muted,
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
        // In-app Summary card
        _FeeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _FeeIconBadge(
                    icon: Icons.bar_chart_rounded,
                    color: const Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Fee Summary',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Current data snapshot',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Total Expected',
                      value: _money(_totalExpected),
                    ),
                  ),
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Collected',
                      value: _money(_totalCollected),
                      highlighted: true,
                    ),
                  ),
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Outstanding',
                      value: _money(_totalDue),
                      danger: _totalDue > 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Students',
                      value: '${_studentAccounts.length}',
                    ),
                  ),
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Structures',
                      value: '${_structureBundles.length}',
                    ),
                  ),
                  Expanded(
                    child: _FeeInfoTile(
                      label: 'Collection%',
                      value: '${(_collectionRate * 100).toStringAsFixed(1)}%',
                      highlighted: _collectionRate >= 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _generatingReport ? null : _generateInAppReport,
                icon: _generatingReport
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(
                  _generatingReport ? 'Generating...' : 'Download PDF Summary',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _FeeSectionTitle('Server-side Exports'),
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
        OutlinedButton.icon(
          onPressed: () => _requestReportExport(reports.first),
          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
          label: const Text('Queue Server Export'),
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

  void _showClassPicker() {
    var query = '';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final rows =
                _sections.where((section) {
                  final haystack = '${section.gradeName} ${section.sectionName}'
                      .toLowerCase();
                  return query.isEmpty ||
                      haystack.contains(query.toLowerCase());
                }).toList()..sort(
                  (a, b) => '${a.gradeName} ${a.sectionName}'.compareTo(
                    '${b.gradeName} ${b.sectionName}',
                  ),
                );
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Class & Section',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search class or section',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) =>
                          setSheetState(() => query = value.trim()),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: rows.isEmpty
                          ? _FeeEmptyState(
                              icon: Icons.groups_2_outlined,
                              title: 'No classes found',
                              message:
                                  'Create classes and sections before assigning fee structures.',
                              actionLabel: 'Open Class Hub',
                              onAction: () {
                                Navigator.pop(context);
                                _openClassHubFeeSetup();
                              },
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final section = rows[index];
                                final selected =
                                    section.id == _selectedSectionId;
                                return _FeeCard(
                                  onTap: () {
                                    setState(() {
                                      _selectedGradeId = section.gradeId;
                                      _selectedSectionId = section.id;
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: Row(
                                    children: [
                                      _FeeIconBadge(
                                        icon: selected
                                            ? Icons.check_circle_outline
                                            : Icons.groups_2_outlined,
                                        color: selected
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFF7C3AED),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${section.gradeName} - ${section.sectionName}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              'Capacity ${section.capacity}',
                                              style: TextStyle(
                                                color: context.appTheme.muted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _money(_classExpectedTotal(section)),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedGradeId = '';
                          _selectedSectionId = '';
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Show all classes'),
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

  Future<void> _openClassHubFeeSetup() async {
    await Navigator.pushNamed(
      context,
      AppRoutes.principalClasses,
      arguments: {
        'source': 'principal_fees',
        'action': 'fees',
        'selectedStep': 'fee_setup',
        'classId': _selectedGradeId,
        'sectionId': _selectedSectionId,
      },
    );
    if (mounted) await _loadData();
  }

  void _showPaymentQrEditor() {
    _syncPaymentConfigControllers();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final qrImageUrl = _textValue(_paymentConfig['qr_image_url']);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Edit Parent QR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Current QR image'),
                      const SizedBox(height: 8),
                      Container(
                        height: 170,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.appTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.appTheme.outlineVariant,
                          ),
                        ),
                        child: qrImageUrl.isEmpty
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 56,
                                    color: context.appTheme.muted,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No QR uploaded yet',
                                    style: TextStyle(
                                      color: context.appTheme.muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _absoluteMediaUrl(qrImageUrl),
                                  height: 154,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image_outlined,
                                    color: context.appTheme.error,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _upiIdController,
                        decoration: const InputDecoration(
                          labelText: 'UPI ID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _payeeNameController,
                        decoration: const InputDecoration(
                          labelText: 'Payee name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _qrNoteController,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Payment note for parents',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _uploadingQr
                            ? null
                            : () => _pickPaymentQr(
                                onUpdated: () => setSheetState(() {}),
                              ),
                        icon: _uploadingQr
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.qr_code_2_rounded),
                        label: const Text('Upload QR Image'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _savingPaymentConfig
                            ? null
                            : () async {
                                final saved = await _savePaymentConfig();
                                if (saved && sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                        icon: _savingPaymentConfig
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save Payment Details'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _absoluteMediaUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return '${EnvConfig.apiOrigin}$trimmed';
    return '${EnvConfig.apiOrigin}/$trimmed';
  }

  Future<bool> _savePaymentConfig() async {
    setState(() => _savingPaymentConfig = true);
    try {
      final config = await BackendApiClient.instance.updatePaymentConfig(
        upiId: _upiIdController.text,
        payeeName: _payeeNameController.text,
        qrNote: _qrNoteController.text,
        qrImageUrl: _textValue(_paymentConfig['qr_image_url']),
      );
      if (!mounted) return false;
      setState(() => _paymentConfig = config);
      _snack('Parent payment QR details saved.', success: true);
      return true;
    } catch (error) {
      _snack('Unable to save payment QR details: $error');
      return false;
    } finally {
      if (mounted) setState(() => _savingPaymentConfig = false);
    }
  }

  Future<void> _pickPaymentQr({VoidCallback? onUpdated}) async {
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
      final config = await BackendApiClient.instance.uploadPaymentQr(
        path: path,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() => _paymentConfig = config);
      _syncPaymentConfigControllers();
      onUpdated?.call();
      _snack('Payment QR uploaded for parents.', success: true);
    } catch (error) {
      _snack('Unable to upload payment QR: $error');
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  void _syncPaymentConfigControllers() {
    _upiIdController.text = _textValue(_paymentConfig['upi_id']);
    _payeeNameController.text = _textValue(_paymentConfig['payee_name']);
    _qrNoteController.text = _textValue(_paymentConfig['qr_note']);
  }

  void _disposeFeeComponentAfterFrame(_FeeComponentEntry component) {
    WidgetsBinding.instance.addPostFrameCallback((_) => component.dispose());
  }

  void _showFeeStructureEditor() {
    var saving = false;

    final components = <_FeeComponentEntry>[
      _FeeComponentEntry(name: 'Book & Kit Fee'),
      _FeeComponentEntry(name: 'Tuition Fee'),
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Create / Edit Structure',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Class: $_selectedClassLabel',
                        style: TextStyle(
                          color: context.appTheme.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // --- Fee Components ---
                      for (var i = 0; i < components.length; i++) ...[
                        Row(
                          children: [
                            Text(
                              'Component ${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            if (components.length > 1)
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 20,
                                ),
                                tooltip: 'Remove component',
                                onPressed: () {
                                  setSheetState(() {
                                    final removed = components.removeAt(i);
                                    _disposeFeeComponentAfterFrame(removed);
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: components[i].nameController,
                          decoration: const InputDecoration(
                            labelText: 'Component name',
                            hintText: 'Book & Kit Fee or Tuition Fee',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: components[i].amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Fee amount',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => setSheetState(
                          () => components.add(_FeeComponentEntry(name: '')),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Fee Item'),
                      ),
                      const SizedBox(height: 12),
                      _FeeInfoBanner(
                        text:
                            'Principal sets only the total amount and due date. Book & Kit Fee stays one-time. Tuition Fee is automatically divided month-wise, and parents or the principal must clear the months in continuous order.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                // Validate all components
                                for (final comp in components) {
                                  final name = comp.nameController.text.trim();
                                  final amt =
                                      double.tryParse(
                                        comp.amountController.text.trim(),
                                      ) ??
                                      0;
                                  if (name.isEmpty) {
                                    _snack(
                                      'Enter a name for each fee component.',
                                    );
                                    return;
                                  }
                                  if (amt <= 0) {
                                    _snack('Enter a valid amount for "$name".');
                                    return;
                                  }
                                }
                                final gradeId = _selectedGradeId.isNotEmpty
                                    ? _selectedGradeId
                                    : (_sections.isNotEmpty
                                          ? _sections.first.gradeId
                                          : '');
                                final yearId = _selectedAcademicYearId;
                                if (gradeId.isEmpty || yearId.isEmpty) {
                                  _snack(
                                    'Select class and academic year first.',
                                  );
                                  return;
                                }
                                setSheetState(() => saving = true);
                                try {
                                  final api = BackendApiClient.instance;
                                  final categories = await api
                                      .getFeeCategories();

                                  final structureIdsToSync = <String>{};
                                  for (final comp in components) {
                                    final compName = comp.nameController.text
                                        .trim();
                                    final amount =
                                        double.tryParse(
                                          comp.amountController.text.trim(),
                                        ) ??
                                        0;
                                    final feeType = _feeTypeForName(compName);
                                    final billingMode = feeType == 'book_kit'
                                        ? 'one_time'
                                        : 'monthly';

                                    // Find or create the fee category
                                    final existing = categories
                                        .firstWhereOrNull(
                                          (row) =>
                                              _textValue(
                                                row['category_name'] ??
                                                    row['name'],
                                              ).toLowerCase() ==
                                              compName.toLowerCase(),
                                        );
                                    final categoryId = existing != null
                                        ? _textValue(existing['id'])
                                        : _textValue(
                                            (await api.createFeeCategory(
                                              categoryName: compName,
                                              frequency: feeType == 'book_kit'
                                                  ? 'one_time'
                                                  : 'yearly',
                                            ))['id'],
                                          );

                                    final created = await api
                                        .createFeeStructure(
                                          academicYearId: yearId,
                                          gradeId: gradeId,
                                          sectionId: _selectedSectionId,
                                          feeCategoryId: categoryId,
                                          amount: amount,
                                          feeType: feeType,
                                          billingMode: billingMode,
                                          priority: feeType == 'book_kit'
                                              ? 1
                                              : 2,
                                          effectiveFrom: DateFormat(
                                            'yyyy-MM-dd',
                                          ).format(DateTime.now()),
                                        );
                                    final createdId = _textValue(created['id']);
                                    if (createdId.isNotEmpty) {
                                      structureIdsToSync.add(createdId);
                                    }
                                  }
                                  for (final structureId
                                      in structureIdsToSync) {
                                    await api.applyFeeInvoiceSync(
                                      structureId,
                                      includePartiallyPaid: true,
                                    );
                                  }
                                  setSheetState(() => saving = false);
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  _snack(
                                    '${components.length} fee component(s) saved.',
                                    success: true,
                                  );
                                  await _loadData();
                                } catch (error) {
                                  _snack(
                                    'Unable to save fee structure: $error',
                                  );
                                  setSheetState(() => saving = false);
                                }
                              },
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save Structure'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      for (final c in components) {
        c.dispose();
      }
    });
  }

  String _feeTypeForName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('book') || lower.contains('kit')) return 'book_kit';
    return 'tuition';
  }

  void _openStructureDetails(_FeeStructureBundle bundle) {
    setState(() {
      _selectedStructure = bundle;
      _view = _FeeView.structureDetails;
      _clearSearch();
    });
  }

  Future<void> _deleteFeeStructureBundle(_FeeStructureBundle bundle) async {
    // First confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text('Delete Fee Structure?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to delete:',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                bundle.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              Text(
                '${bundle.classLabel} · ${bundle.components.length} components',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text(
                'Deleting this fee structure also removes it from unpaid student invoices and pending parent requests. Paid history remains available.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    // Second confirmation — type to confirm
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Are you absolutely sure?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action is IRREVERSIBLE. Type DELETE to confirm:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Type DELETE',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: controller.text.trim() == 'DELETE'
                    ? () => Navigator.pop(context, true)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                ),
                child: const Text('Confirm Delete'),
              ),
            ],
          ),
        );
      },
    );
    if (doubleConfirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      // A bundle groups multiple fee structure records by grade+year+section.
      // We must delete each individual record using its real UUID, not the
      // composite key that is used internally as the bundle id.
      final idsToDelete = bundle.componentIds;
      if (idsToDelete.isEmpty) {
        _snack('Unable to delete: no fee structure IDs found in this bundle.');
        return;
      }
      final api = BackendApiClient.instance;
      for (final structureId in idsToDelete) {
        await api.deleteFeeStructure(structureId, removePending: true);
      }
      if (!mounted) return;
      setState(() {
        _feeStructures = const [];
        _invoices = const [];
        _recentPayments = const [];
        _paymentRequests = const [];
        _concessions = const [];
        _selectedStructure = null;
        _selectedAccount = null;
        _selectedInvoice = null;
      });
      _snack('Fee structure deleted.', success: true);
      // Go back to list view and refresh
      if (_view == _FeeView.structureDetails) {
        setState(() => _view = _FeeView.structures);
      }
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      _snack('Unable to delete: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openStructureForInvoice(Map<String, dynamic> invoice) {
    final bundle = _structureBundles.firstWhereOrNull((structure) {
      final sameGrade =
          structure.gradeId.isNotEmpty &&
          structure.gradeId == _textValue(invoice['grade_id']);
      final sameSection =
          structure.sectionId.isEmpty ||
          structure.sectionId == _textValue(invoice['section_id']);
      final sameYear =
          structure.academicYearId.isNotEmpty &&
          structure.academicYearId == _textValue(invoice['academic_year_id']);
      return sameGrade && sameSection && sameYear;
    });
    setState(() {
      if (bundle != null) _selectedStructure = bundle;
      _view = _FeeView.structureDetails;
    });
  }

  Widget _buildInvoiceInstallmentCard(Map<String, dynamic> invoice) {
    final invoiceNumber = _textValue(
      invoice['invoice_number'],
      fallback: 'Invoice',
    );
    final total = _numValue(invoice['total']);
    final paid = _numValue(invoice['paid']);
    final balance = _numValue(invoice['balance']);
    final status = _textValue(invoice['status'], fallback: 'pending');
    final dueDate = _textValue(invoice['due_date']);
    final rawInstallments = invoice['installments'];
    final installments = rawInstallments is List
        ? rawInstallments.whereType<Map>().toList()
        : <Map>[];

    return _FeeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FeeIconBadge(
                icon: Icons.receipt_long_outlined,
                color: _statusColor(status),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoiceNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (dueDate.isNotEmpty)
                      Text(
                        'Due: ${_displayDateStr(dueDate)}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: context.appTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              _FeeStatusPill(
                label: status.toUpperCase(),
                color: _statusColor(status),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _generateInvoicePdf(invoice),
                child: Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 18,
                  color: context.appTheme.muted,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _editInvoiceSheet(invoice),
                child: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: context.appTheme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FeeInfoTile(label: 'Total', value: _money(total)),
              ),
              Expanded(
                child: _FeeInfoTile(
                  label: 'Paid',
                  value: _money(paid),
                  highlighted: paid > 0,
                ),
              ),
              Expanded(
                child: _FeeInfoTile(
                  label: 'Balance',
                  value: _money(balance),
                  danger: balance > 0,
                ),
              ),
            ],
          ),
          if (installments.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              'Installments (${installments.length})',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: context.appTheme.muted,
              ),
            ),
            const SizedBox(height: 6),
            for (final inst in installments)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: _statusColor(
                        _textValue(inst['status'], fallback: 'pending'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _textValue(
                          inst['label'] ?? inst['name'],
                          fallback:
                              'Installment ${installments.indexOf(inst) + 1}',
                        ),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _money(_numValue(inst['amount'])),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FeeStatusPill(
                      label:
                          _textValue(
                                inst['status'],
                                fallback: 'pending',
                              ).toLowerCase() ==
                              'paid'
                          ? 'Paid'
                          : 'Due',
                      color: _statusColor(
                        _textValue(inst['status'], fallback: 'pending'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _displayDateStr(String raw) {
    if (raw.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  void _editInvoiceSheet(Map<String, dynamic> invoice) {
    final invoiceId = _textValue(invoice['id']);
    if (invoiceId.isEmpty) {
      _snack('Invoice ID is missing.');
      return;
    }
    final dueDateController = TextEditingController(
      text: _textValue(invoice['due_date']),
    );
    final amountController = TextEditingController(
      text: _numValue(
        invoice['total'] ?? invoice['total_amount'],
      ).toStringAsFixed(0),
    );
    final concessionController = TextEditingController(
      text: _numValue(
        invoice['concession_amount'] ?? invoice['discount'],
      ).toStringAsFixed(0),
    );
    final concessionReasonController = TextEditingController(
      text: _textValue(invoice['concession_reason']),
    );
    final notesController = TextEditingController(
      text: _textValue(invoice['notes']),
    );
    String currentStatus = _textValue(
      invoice['status'],
      fallback: 'pending',
    ).toLowerCase();
    if (![
      'pending',
      'unpaid',
      'partially_paid',
      'paid',
      'overdue',
      'cancelled',
    ].contains(currentStatus)) {
      currentStatus = 'pending';
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit Installment Invoice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dueDateController,
                decoration: const InputDecoration(
                  labelText: 'Due Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Installment Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: concessionController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Concession Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.discount_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: concessionReasonController,
                decoration: const InputDecoration(
                  labelText: 'Concession Reason',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_rounded),
                  hintText: 'e.g. Scholarship, Financial hardship, Staff ward',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: currentStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline_rounded),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('Pending (Unpaid)'),
                  ),
                  DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                  DropdownMenuItem(
                    value: 'partially_paid',
                    child: Text('Partially Paid'),
                  ),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    currentStatus = val;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final dueDate = dueDateController.text.trim();
                  final amount = double.tryParse(amountController.text.trim());
                  final concession =
                      double.tryParse(concessionController.text.trim()) ?? 0;
                  final concessionReason = concessionReasonController.text
                      .trim();
                  final notes = notesController.text.trim();
                  try {
                    await BackendApiClient.instance.updateInvoice(
                      invoiceId,
                      dueDate: dueDate.isEmpty ? null : dueDate,
                      totalAmount: amount,
                      concessionAmount: concession > 0 ? concession : null,
                      concessionReason: concessionReason.isEmpty
                          ? null
                          : concessionReason,
                      status: currentStatus,
                      notes: notes.isEmpty ? null : notes,
                    );
                    await _loadData();
                    if (mounted) {
                      _snack('Invoice updated successfully.', success: true);
                    }
                  } catch (error) {
                    if (mounted) _snack('Failed to update invoice: $error');
                  }
                },
                child: const Text('Save Changes'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generateInvoicePdf(Map<String, dynamic> invoice) async {
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
        studentName:
            _selectedAccount?.name ??
            _textValue(invoice['name'], fallback: 'Student'),
        className:
            _selectedAccount?.classLabel ??
            _textValue(invoice['class'], fallback: 'Class'),
        rollNo:
            _selectedAccount?.rollNumber ??
            _textValue(invoice['roll'], fallback: '-'),
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
      _selectedPaymentMode = _PaymentMode.cash;
      _paymentDate = DateTime.now();
      _seedManualPaymentMonths(invoice);
      _paymentAmountController.text = _amountText(
        _numValue(invoice['balance']),
      );
      _recalculateManualPaymentAmount();
      _transactionController.text = _suggestedTransactionId();
      _notesController.clear();
      _view = _FeeView.collectMode;
    });
  }

  Future<void> _showGrantConcessionSheet(_FeeStudentAccount account) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    String selectedType = 'Financial Hardship';
    const types = [
      'Academic',
      'Financial Hardship',
      'Sibling Discount',
      'Sports / Arts',
      'Staff Ward',
      'Other',
    ];
    bool saving = false;

    final granted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_outlined,
                      color: Color(0xFF7C3AED),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Grant Concession',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          account.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              sheetContext,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Student info strip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withAlpha(12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withAlpha(40),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${account.name}  •  ${account.classLabel}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      account.rollNumber,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          sheetContext,
                        ).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Concession Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) =>
                    setSheetState(() => selectedType = v ?? selectedType),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Concession Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Why is this concession being granted?',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final amount = double.tryParse(
                                amountController.text.trim(),
                              );
                              if (amount == null || amount <= 0) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Enter a valid concession amount.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => saving = true);
                              try {
                                await BackendApiClient.instance.createRaw(
                                  '/fees/concessions',
                                  {
                                    'student_id': account.studentId,
                                    'student_name': account.name,
                                    'class_section': account.classLabel,
                                    'type': selectedType,
                                    'amount': amount,
                                    'concession_amount': amount,
                                    'reason': reasonController.text.trim(),
                                    'concession_reason': reasonController.text
                                        .trim(),
                                    'status': 'pending',
                                    'submitted_at': DateTime.now()
                                        .toIso8601String(),
                                    'academic_year_id': account.academicYearId,
                                  },
                                );
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext, true);
                                }
                              } catch (error) {
                                setSheetState(() => saving = false);
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to submit concession: $error',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.volunteer_activism_outlined,
                              size: 18,
                            ),
                      label: Text(saving ? 'Submitting...' : 'Grant'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (granted == true && mounted) {
      await _loadData();
      _snack('Concession request submitted for approval.', success: true);
    }
  }

  void _continueToPaymentDetails() {
    final account = _selectedAccount;
    final invoice = _selectedInvoice;
    if (account == null || invoice == null) {
      _snack('Select a student invoice before continuing.');
      return;
    }
    _seedManualPaymentMonths(invoice);
    _paymentAmountController.text = _amountText(_numValue(invoice['balance']));
    _recalculateManualPaymentAmount();
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
    var amount = double.tryParse(_paymentAmountController.text.trim()) ?? 0.0;
    final balance = _numValue(invoice['balance']);
    if (invoiceId.isEmpty) {
      _snack('Backend invoice ID is missing.');
      return;
    }
    if (amount <= 0) {
      _snack('Payment amount must be greater than zero.');
      return;
    }
    if (_isTuitionInvoice(invoice)) {
      _selectManualMonthsForAmount(amount);
      if (_selectedPaymentMonths.isEmpty) {
        _snack('Select the next continuous tuition month range first.');
        return;
      }
      amount = _manualPaymentAmountForSelection(invoice);
      _paymentAmountController.text = _amountText(amount);
    }
    if (amount > balance) {
      _snack('Payment amount exceeds outstanding balance.');
      return;
    }

    final receiptNumber = _receiptNumber();
    setState(() => _saving = true);
    try {
      final unpaidMonths = _unpaidInvoiceMonths(invoice);
      final selectedMonths = unpaidMonths
          .where(_selectedPaymentMonths.contains)
          .toList(growable: false);
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
          remarks: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          selectedMonthNames: _isTuitionInvoice(invoice)
              ? selectedMonths
              : const [],
          selectedMonths: _isTuitionInvoice(invoice)
              ? selectedMonths.length
              : 0,
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
    // Try to build itemized fee items from the student's invoice data.
    final account = _selectedAccount;
    final List<Map<String, dynamic>> feeItems;
    if (account != null) {
      feeItems = _buildFeeItemsFromAccount(account);
    } else {
      feeItems = [
        {
          'description': 'Fee payment',
          'amount': result.amount,
          'status': 'Paid',
        },
      ];
    }
    try {
      final pdfService = PdfService.getInstance();
      final bytes = await pdfService.generateFeeReceipt(
        receiptNo: result.receiptNumber,
        studentName: result.studentName,
        className: result.classLabel,
        rollNo: result.rollNumber,
        parentName: 'Parent',
        feeItems: feeItems,
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

  Future<void> _previewInvoicePdf(_FeeStudentAccount account) async {
    final feeItems = _buildFeeItemsFromAccount(account);
    try {
      final pdfService = PdfService.getInstance();
      final dueInvoice = _primaryDueInvoice(account) ?? account.invoices.first;
      final bytes = await pdfService.generateFeeReceipt(
        receiptNo: _textValue(
          dueInvoice['invoice_number'],
          fallback: 'INV-${account.studentId.substring(0, 6).toUpperCase()}',
        ),
        studentName: account.name,
        className: account.classLabel,
        rollNo: account.rollNumber,
        parentName: 'Parent / Guardian',
        feeItems: feeItems,
        totalAmount: account.total,
        paidAmount: account.paid,
        balance: account.balance,
        paymentMode: account.payments.isNotEmpty
            ? _textValue(account.payments.last['mode'], fallback: 'N/A')
            : 'Pending',
        paymentDate: account.payments.isNotEmpty
            ? (DateTime.tryParse(_textValue(account.payments.last['date'])) ??
                  DateTime.now())
            : DateTime.now(),
      );
      if (!mounted) return;
      await pdfService.previewDocument(
        context,
        bytes,
        'Invoice — ${account.name}',
      );
    } catch (error) {
      _snack('Unable to generate invoice PDF: $error');
    }
  }

  List<Map<String, dynamic>> _buildFeeItemsFromAccount(
    _FeeStudentAccount account,
  ) {
    final items = <Map<String, dynamic>>[];
    for (final invoice in account.invoices) {
      final rawItems = invoice['items'];
      if (rawItems is List && rawItems.isNotEmpty) {
        for (final item in rawItems.whereType<Map>()) {
          final desc = _textValue(
            item['category_name'] ?? item['description'] ?? item['name'],
            fallback: 'Fee component',
          );
          final amount = _numValue(item['amount']);
          final status = _textValue(item['status'], fallback: 'Pending');
          items.add({'description': desc, 'amount': amount, 'status': status});
        }
      } else {
        // Fallback: create a single line item per invoice.
        final label = _textValue(
          invoice['invoice_label'] ?? invoice['invoice_number'],
          fallback: 'Fee',
        );
        items.add({
          'description': label,
          'amount': _numValue(invoice['total']),
          'status': _textValue(invoice['status'], fallback: 'pending'),
        });
      }
    }
    if (items.isEmpty) {
      items.add({
        'description': 'Fee payment',
        'amount': account.total,
        'status': account.balance <= 0 ? 'Paid' : 'Pending',
      });
    }
    return items;
  }

  Future<void> _generateInAppReport() async {
    setState(() => _generatingReport = true);
    try {
      // Build class-wise breakdown.
      final classMap = <String, Map<String, double>>{};
      for (final account in _studentAccounts) {
        final classKey = account.classLabel.isEmpty
            ? 'Unknown'
            : account.classLabel;
        classMap.putIfAbsent(
          classKey,
          () => {'total': 0, 'paid': 0, 'balance': 0},
        );
        classMap[classKey]!['total'] =
            (classMap[classKey]!['total'] ?? 0) + account.total;
        classMap[classKey]!['paid'] =
            (classMap[classKey]!['paid'] ?? 0) + account.paid;
        classMap[classKey]!['balance'] =
            (classMap[classKey]!['balance'] ?? 0) + account.balance;
      }

      // Build fee items list for the PDF summary.
      final summaryItems = <Map<String, dynamic>>[
        {
          'description': 'Total Expected',
          'amount': _totalExpected,
          'status': 'Summary',
        },
        {
          'description': 'Total Collected',
          'amount': _totalCollected,
          'status': 'Collected',
        },
        {
          'description': 'Outstanding Dues',
          'amount': _totalDue,
          'status': _totalDue > 0 ? 'Pending' : 'Clear',
        },
        for (final entry in classMap.entries)
          {
            'description': entry.key,
            'amount': entry.value['paid'] ?? 0,
            'status':
                'Collected ₹${(entry.value['balance'] ?? 0).toStringAsFixed(0)} due',
          },
      ];

      final pdfService = PdfService.getInstance();
      final bytes = await pdfService.generateFeeReceipt(
        receiptNo: 'RPT-${DateTime.now().millisecondsSinceEpoch}',
        studentName: 'All Students',
        className: _selectedClassLabel,
        rollNo: '${_studentAccounts.length} students',
        parentName: 'Fee Report',
        feeItems: summaryItems,
        totalAmount: _totalExpected,
        paidAmount: _totalCollected,
        balance: _totalDue,
        paymentMode: 'Summary Report',
        paymentDate: DateTime.now(),
        schoolName: 'School Fee Summary',
        schoolAddress: 'Date range: $_reportRange',
      );
      if (!mounted) return;
      await pdfService.previewDocument(context, bytes, 'Fee Collection Report');
    } catch (error) {
      if (mounted) _snack('Unable to generate report: $error');
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  void _openAllPaymentRequests() {
    Navigator.pushNamed(context, AppRoutes.principalPaymentRequests);
  }

  void _openPaymentRequestDecision(Map<String, dynamic> request) {
    Navigator.pushNamed(
      context,
      AppRoutes.principalPaymentRequestDecision,
      arguments: AdminPaymentRequestDecisionArgs(request: request),
    ).then((_) => _loadData());
  }

  List<_FeeStructureBundle> get _structureBundles {
    final grouped = <String, List<_FeeComponent>>{};
    for (final row in _feeStructures) {
      final gradeId = _textValue(row['grade_id']);
      final yearId = _textValue(row['academic_year_id']);
      final sectionId = _textValue(row['section_id']);
      final key = '$gradeId::$yearId::$sectionId';
      grouped.putIfAbsent(key, () => []).add(_FeeComponent.fromRow(row));
    }

    final rows = grouped.entries.map((entry) {
      final components = entry.value;
      final first = components.first.source;
      final gradeId = _textValue(first['grade_id']);
      final yearId = _textValue(first['academic_year_id']);
      final sectionId = _textValue(first['section_id']);
      final sectionLabel = _textValue(
        first['section'],
        fallback: _sectionLabelForId(sectionId),
      );
      final gradeLabel = _classLabelForGrade(
        gradeId,
        fallback: _textValue(first['class'], fallback: 'Class pending'),
      );
      final classLabel = [
        gradeLabel,
        sectionLabel,
      ].where((part) => part.isNotEmpty && part != 'All sections').join(' - ');
      final yearLabel = _yearLabelForId(
        yearId,
        fallback: _textValue(first['academic_year'], fallback: 'Academic year'),
      );
      return _FeeStructureBundle(
        id: entry.key,
        componentIds: components
            .map((c) => _textValue(c.source['id']))
            .where((id) => id.isNotEmpty)
            .toList(),
        gradeId: gradeId,
        sectionId: sectionId,
        academicYearId: yearId,
        title:
            '${classLabel.isEmpty ? gradeLabel : classLabel} Fee Structure $yearLabel',
        classLabel: classLabel.isEmpty ? gradeLabel : classLabel,
        sectionLabel: sectionLabel,
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
        sectionId: _textValue(first['section_id']),
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
        final sameSection =
            structure.sectionId.isEmpty ||
            account.sectionId.isEmpty ||
            account.sectionId == structure.sectionId;
        final sameYear =
            structure.academicYearId.isEmpty ||
            account.academicYearId.isEmpty ||
            account.academicYearId == structure.academicYearId;
        if (!sameGrade || !sameSection || !sameYear) return false;
      } else {
        if (_selectedGradeId.isNotEmpty) {
          if (account.gradeId.isNotEmpty &&
              account.gradeId != _selectedGradeId) {
            return false;
          }
        }
        if (_selectedSectionId.isNotEmpty) {
          if (account.sectionId.isNotEmpty &&
              account.sectionId != _selectedSectionId) {
            return false;
          }
        }
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
          ..sort((a, b) {
            final priorityCompare = _feeInvoicePriority(
              a,
            ).compareTo(_feeInvoicePriority(b));
            if (priorityCompare != 0) return priorityCompare;
            return _sortDate(a['due_date']).compareTo(_sortDate(b['due_date']));
          });
    return due.isEmpty ? null : due.first;
  }

  int _feeInvoicePriority(Map<String, dynamic> invoice) {
    final raw = invoice['priority'];
    final parsed = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (parsed != null && parsed > 0) return parsed;
    return _textValue(invoice['fee_type']) == 'book_kit' ? 1 : 2;
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

  Map<String, dynamic>? _invoiceById(String invoiceId) {
    return _invoices.firstWhereOrNull((row) => _textValue(row['id']) == invoiceId);
  }

  Map<String, dynamic> _normalizeFeeStructure(Map<String, dynamic> row) {
    final category = _mapValue(row['fee_category']);
    final grade = _mapValue(row['grade']);
    final section = _mapValue(row['section']);
    final year = _mapValue(row['academic_year']);
    return {
      ...row,
      'id': _textValue(row['id']),
      'grade_id': _textValue(row['grade_id'] ?? grade['id']),
      'section_id': _textValue(row['section_id'] ?? section['id']),
      'academic_year_id': _textValue(row['academic_year_id'] ?? year['id']),
      'class': _textValue(
        grade['grade_name'] ?? grade['name'],
        fallback: _textValue(row['class']),
      ),
      'section': _textValue(
        section['section_name'],
        fallback: _sectionLabelForId(
          _textValue(row['section_id'] ?? section['id']),
        ),
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
      'fee_type': _textValue(row['fee_type']),
      'billing_mode': _textValue(row['billing_mode']),
      'priority': row['priority'],
      'total': _numValue(row['total_amount'] ?? row['net_amount']),
      'discount': _numValue(row['discount_amount']),
      'paid': _numValue(row['paid_amount']),
      'balance': _numValue(row['balance']),
      'monthly_amount': _numValue(row['monthly_amount']),
      'allowed_month_names': row['allowed_month_names'],
      'paid_month_names': row['paid_month_names'],
      'unpaid_month_names': row['unpaid_month_names'],
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
        'section_id': _textValue(invoice['section_id']),
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
          (structure.sectionId.isEmpty ||
              structure.sectionId == _textValue(invoice['section_id'])) &&
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

  double get _totalDue {
    final structureIds = _feeStructures
        .map((s) => _textValue(s['id']))
        .where((id) => id.isNotEmpty)
        .toSet();
    if (structureIds.isEmpty) return 0;
    return _invoices
        .where((row) =>
            structureIds.contains(_textValue(row['fee_structure_id'])))
        .fold(0, (sum, row) => sum + _numValue(row['balance']));
  }

  double get _totalCollected {
    final structureIds = _feeStructures
        .map((s) => _textValue(s['id']))
        .where((id) => id.isNotEmpty)
        .toSet();
    if (structureIds.isEmpty) return 0;
    return _recentPayments
        .where((row) {
          final invoiceId = _textValue(row['invoice_id']);
          if (invoiceId.isEmpty) return false;
          final invoice = _invoiceById(invoiceId);
          return invoice != null &&
              structureIds.contains(
                _textValue(invoice['fee_structure_id']),
              );
        })
        .fold(0, (sum, row) => sum + _numValue(row['amount']));
  }

  double get _totalExpected => _totalCollected + _totalDue;

  double get _collectionRate => _totalExpected <= 0
      ? 0
      : (_totalCollected / _totalExpected).clamp(0, 1).toDouble();

  _FeeStructureBundle? get _selectedOverviewBundle {
    final rows = _structureBundles.where((bundle) {
      final yearMatches =
          _selectedAcademicYearId.isEmpty ||
          bundle.academicYearId == _selectedAcademicYearId;
      final gradeMatches =
          _selectedGradeId.isEmpty || bundle.gradeId == _selectedGradeId;
      final sectionMatches =
          _selectedSectionId.isEmpty ||
          bundle.sectionId.isEmpty ||
          bundle.sectionId == _selectedSectionId;
      return yearMatches && gradeMatches && sectionMatches;
    }).toList();
    if (rows.isEmpty) return null;
    return rows.first;
  }

  String get _selectedClassLabel {
    final section = _sections.firstWhereOrNull(
      (row) => row.id == _selectedSectionId,
    );
    if (section != null) {
      return '${section.gradeName} - ${section.sectionName}';
    }
    final grade = _grades.firstWhereOrNull((row) => row.id == _selectedGradeId);
    if (grade != null) return grade.gradeName;
    return 'All Classes';
  }

  double _classExpectedTotal(SectionModel section) {
    return _structureBundles
        .where(
          (bundle) =>
              bundle.gradeId == section.gradeId &&
              (bundle.sectionId.isEmpty || bundle.sectionId == section.id) &&
              (_selectedAcademicYearId.isEmpty ||
                  bundle.academicYearId == _selectedAcademicYearId),
        )
        .fold(0, (sum, row) => sum + row.total);
  }

  String _sectionLabelForId(String sectionId) {
    if (sectionId.isEmpty) return 'All sections';
    final section = _sections.firstWhereOrNull((row) => row.id == sectionId);
    return section?.sectionName ?? sectionId;
  }

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
        backgroundColor: success
            ? context.appTheme.success
            : context.appTheme.error,
      ),
    );
  }
}

class _FeePage extends StatelessWidget {
  final Widget header;
  final List<Widget> children;
  final ScrollController? controller;

  const _FeePage({
    required this.header,
    required this.children,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: context.appTheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.appTheme.muted,
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
  final VoidCallback? onLongPress;

  const _FeeCard({required this.child, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: context.appTheme.onSurface.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      onLongPress: onLongPress,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          _FeeIconBadge(icon: icon, color: color),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.appTheme.muted,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: context.appTheme.onSurface,
                    ),
                  ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: context.appTheme.onSurface.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FeeIconBadge(icon: icon, color: color, compact: true),
          const SizedBox(height: 6),
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
            style: TextStyle(
              fontSize: 8.5,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: context.appTheme.muted,
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
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: context.appTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.appTheme.muted),
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
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: context.appTheme.onSurface,
      ),
    );
  }
}

class _FeeStructureCard extends StatelessWidget {
  final _FeeStructureBundle bundle;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _FeeStructureCard({
    required this.bundle,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _FeeCard(
      onTap: onTap,
      onLongPress: onDelete,
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
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    color: context.appTheme.muted,
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
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Colors.red[300],
            ),
          ],
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
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: context.appTheme.muted,
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
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.appTheme.muted,
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
          Flexible(
            child: Text(
              NumberFormat.currency(
                locale: 'en_IN',
                symbol: '₹ ',
                decimalDigits: 0,
              ).format(account.balance > 0 ? account.balance : account.total),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
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
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.appTheme.muted,
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
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.appTheme.muted,
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
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.appTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.appTheme.muted),
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
        ? context.appTheme.error
        : highlighted
        ? context.appTheme.success
        : context.appTheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlighted
            ? context.appTheme.successContainer
            : danger
            ? context.appTheme.errorContainer
            : context.appTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              color: context.appTheme.muted,
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
              style: TextStyle(
                color: context.appTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: danger
                  ? context.appTheme.error
                  : context.appTheme.onSurface,
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
      foregroundColor: context.appTheme.primary,
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

class _FeeComponentEntry {
  _FeeComponentEntry({String name = ''})
    : nameController = TextEditingController(text: name),
      amountController = TextEditingController();
  final TextEditingController nameController;
  final TextEditingController amountController;
  void dispose() {
    nameController.dispose();
    amountController.dispose();
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
        color: context.appTheme.infoContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appTheme.primary.withAlpha(40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: context.appTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.appTheme.onSurface,
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
            Icon(icon, size: 46, color: context.appTheme.muted),
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
              style: TextStyle(
                color: context.appTheme.muted,
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
        decoration: BoxDecoration(
          color: context.appTheme.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 42),
      ),
    );
  }
}

class _FeeStructureBundle {
  final String id;
  final List<String> componentIds;
  final String gradeId;
  final String sectionId;
  final String academicYearId;
  final String title;
  final String classLabel;
  final String sectionLabel;
  final String academicYearLabel;
  final List<_FeeComponent> components;
  final bool isActive;

  const _FeeStructureBundle({
    required this.id,
    required this.componentIds,
    required this.gradeId,
    required this.sectionId,
    required this.academicYearId,
    required this.title,
    required this.classLabel,
    required this.sectionLabel,
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
  final String sectionId;
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
    required this.sectionId,
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

class _PaymentRequestRow extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onTap;

  const _PaymentRequestRow({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final student = _mapDynamic(request['student']);
    final studentName = [
      _textVal(student['first_name']),
      _textVal(student['last_name']),
    ].where((p) => p.isNotEmpty).join(' ').trim();
    final amount = _numVal(request['amount']);
    final mode = (request['payment_mode'] ?? '-').toString();
    final hasProof = (request['proof_url'] ?? '').toString().trim().isNotEmpty;

    return _FeeCard(
      onTap: onTap,
      child: Row(
        children: [
          _FeeIconBadge(
            icon: hasProof
                ? Icons.receipt_long_outlined
                : Icons.payment_outlined,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName.isEmpty ? 'Student' : studentName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$mode • ₹${amount.toStringAsFixed(0)}${hasProof ? ' • Proof attached' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: context.appTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const _FeeStatusPill(label: 'Review', color: Color(0xFF7C3AED)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: context.appTheme.muted),
        ],
      ),
    );
  }

  static double _numVal(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static String _textVal(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return (text.isEmpty || text == 'null') ? '' : text;
  }

  static Map<String, dynamic> _mapDynamic(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

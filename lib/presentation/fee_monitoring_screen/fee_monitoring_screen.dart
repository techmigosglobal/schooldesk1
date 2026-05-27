import 'package:flutter/material.dart';

import '../../services/backend_api_client.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/operations_workspace.dart';
import '../../widgets/principal_directory_ui.dart';

class FeeMonitoringScreen extends StatefulWidget {
  const FeeMonitoringScreen({super.key});

  @override
  State<FeeMonitoringScreen> createState() => _FeeMonitoringScreenState();
}

class _FeeMonitoringScreenState extends State<FeeMonitoringScreen> {
  String _searchQuery = '';
  String _selectedClass = 'All';
  String _selectedStatus = 'All';
  String _selectedView = 'Overview';

  List<Map<String, dynamic>> _feeStructures = [];
  List<Map<String, dynamic>> _studentFees = [];
  List<Map<String, dynamic>> _recentPayments = [];
  List<Map<String, dynamic>> _concessionRequests = [];
  List<Map<String, dynamic>> _feeCategories = [];
  List<AcademicYearModel> _academicYears = [];
  List<GradeModel> _grades = [];
  bool _loading = true;
  String? _error;

  final _statusFilters = const ['All', 'Paid', 'Pending', 'Overdue', 'Partial'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final feeStructures = await api.getFeeStructures();
      final studentFees = await api.getInvoices();
      final concessionRequests = await api.getRawList('/fees/concessions');
      final feeCategories = await api.getRawList('/fees/categories');
      final academicYears = await api.getAcademicYears();
      final grades = await api.getGrades();
      if (!mounted) return;
      setState(() {
        _feeStructures = feeStructures.map(_normalizeFeeStructure).toList();
        _studentFees = studentFees.map(_normalizeInvoice).toList();
        _recentPayments = studentFees.expand(_normalizePayments).toList();
        _concessionRequests = concessionRequests;
        _feeCategories = feeCategories;
        _academicYears = academicYears;
        _grades = grades;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load principal fee monitoring from backend. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    final cards = _feeDirectoryCards;
    return PrincipalDirectoryScaffold(
      title: 'Fee Dashboard',
      subtitle: 'Collection, pending dues, receipts, and class-wise fee setup',
      loading: _loading,
      error: _error,
      onRefresh: _loadData,
      onAdd: _showFeeStructureForm,
      addTooltip: 'Add Class-wise Fee Structure',
      filters: _buildDirectoryFilters(),
      isEmpty: !_loading && _error == null && cards.isEmpty,
      emptyState: const OpsEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No fee rows found',
        message: 'Create a fee entry or adjust the directory filters.',
      ),
      slivers: [
        SliverToBoxAdapter(child: _buildDirectoryMetrics()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
            child: _buildDirectoryQuickActions(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 96),
          sliver: SliverList.builder(
            itemCount: cards.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: cards[index],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectoryFilters() {
    final realClasses = [
      ..._studentFees
          .map((row) => _textValue(row['class']))
          .where((value) => value.isNotEmpty)
          .where((value) => value.toLowerCase() != 'class not assigned')
          .toSet(),
    ];
    final classes = ['All Classes', ...realClasses];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child: Column(
        children: [
          PrincipalDirectorySearchBox(
            hint: 'Search student, class, invoice, fee type...',
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                for (final option in const [
                  ('Overview', Icons.insights_outlined),
                  ('Class Fees', Icons.class_outlined),
                  ('Student Fees', Icons.receipt_long_outlined),
                  ('Payments', Icons.payments_outlined),
                  ('Concessions', Icons.volunteer_activism_outlined),
                  ('Analytics', Icons.bar_chart_rounded),
                  ('Fee Types', Icons.category_outlined),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PrincipalDirectoryChip(
                      label: option.$1,
                      icon: option.$2,
                      selected: _selectedView == option.$1,
                      onTap: () => setState(() => _selectedView = option.$1),
                    ),
                  ),
              ],
            ),
          ),
          if (_selectedView == 'Student Fees' && realClasses.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final classValue in classes)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: PrincipalDirectoryChip(
                        label: classValue,
                        selected:
                            (_selectedClass == 'All' &&
                                classValue == 'All Classes') ||
                            _selectedClass == classValue,
                        onTap: () => setState(
                          () => _selectedClass = classValue == 'All Classes'
                              ? 'All'
                              : classValue,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_selectedView == 'Student Fees') ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final status in _statusFilters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: PrincipalDirectoryChip(
                        label: status == 'All' ? 'All Status' : status,
                        selected: _selectedStatus == status,
                        onTap: () => setState(() => _selectedStatus = status),
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

  Widget _buildDirectoryMetrics() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.52,
        children: [
          _FeeDashboardMetricCard(
            title: 'Total Collection',
            value: _money(_totalCollected),
            subtitle: 'This academic year',
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF3157F6),
          ),
          _FeeDashboardMetricCard(
            title: 'Fees Pending',
            value: _money(_totalPending),
            subtitle: 'From $_pendingStudentCount students',
            icon: Icons.pending_actions_outlined,
            color: const Color(0xFF18B57D),
          ),
          _FeeDashboardMetricCard(
            title: 'Today Collection',
            value: _money(_todayCollection),
            subtitle: _dateLabel(DateTime.now()),
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFF8751F4),
          ),
          _FeeDashboardMetricCard(
            title: 'Overdue Students',
            value: '$_overdueStudentCount',
            subtitle: 'Need attention',
            icon: Icons.notifications_active_outlined,
            color: const Color(0xFFFF8A12),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Quick Actions',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedView = 'Class Fees'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.06,
          children: [
            _FeeQuickActionTile(
              label: 'Add Fee Structure',
              icon: Icons.add_circle_outline_rounded,
              color: const Color(0xFF3157F6),
              onTap: _showFeeStructureForm,
            ),
            _FeeQuickActionTile(
              label: 'Class Fee Info',
              icon: Icons.class_outlined,
              color: const Color(0xFF1984E8),
              onTap: () => setState(() => _selectedView = 'Class Fees'),
            ),
            _FeeQuickActionTile(
              label: 'Collect Payment',
              icon: Icons.payments_outlined,
              color: const Color(0xFF18B57D),
              onTap: () => _showPaymentSheet(_firstCollectibleInvoice),
            ),
            _FeeQuickActionTile(
              label: 'Generate Receipt',
              icon: Icons.receipt_outlined,
              color: const Color(0xFF8751F4),
              onTap: () {
                final invoice = _studentFees
                    .where((row) => _numValue(row['paid']) > 0)
                    .firstOrNull;
                if (invoice == null) {
                  _snack('No paid invoice is available for receipt preview');
                  return;
                }
                _printReceiptFromInvoice(invoice);
              },
            ),
            _FeeQuickActionTile(
              label: 'Concessions',
              icon: Icons.volunteer_activism_outlined,
              color: const Color(0xFFFF8A12),
              onTap: () => setState(() => _selectedView = 'Concessions'),
            ),
            _FeeQuickActionTile(
              label: 'Analytics',
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFFE84D68),
              onTap: () => setState(() => _selectedView = 'Analytics'),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> get _feeDirectoryCards {
    return switch (_selectedView) {
      'Overview' => _overviewCards,
      'Class Fees' => [
        for (final row in _feeStructures) _buildStructureCard(row),
      ],
      'Fee Types' => [
        for (final row in _feeCategories) _buildFeeCategoryCard(row),
      ],
      'Payments' => [
        for (final row in _filteredPaymentRows) _buildPaymentCard(row),
      ],
      'Concessions' => [
        for (final row in _filteredConcessionRows) _buildConcessionCard(row),
      ],
      'Analytics' => _analyticsCards,
      _ => [for (final row in _filteredStudents) _buildStudentFeeCard(row)],
    };
  }

  List<Widget> get _overviewCards {
    final byClass = <String, double>{};
    for (final fee in _studentFees) {
      final className = _textValue(fee['class'], fallback: 'Unassigned');
      byClass[className] =
          (byClass[className] ?? 0) + _numValue(fee['balance']);
    }
    return [
      for (final entry in byClass.entries)
        PrincipalDirectoryCard(
          icon: Icons.meeting_room_outlined,
          title: entry.key,
          subtitle: 'Class-wise outstanding balance from backend invoices',
          status: entry.value <= 0 ? 'Clear' : 'Outstanding',
          statusColor: entry.value <= 0 ? AppTheme.success : AppTheme.warning,
          chips: [
            PrincipalInfoPill(
              icon: Icons.account_balance_wallet_outlined,
              label: _money(entry.value),
            ),
          ],
        ),
    ];
  }

  List<Widget> get _analyticsCards {
    final totalInvoiced = _studentFees.fold(
      0.0,
      (sum, row) => sum + _numValue(row['total']),
    );
    final paidPct = totalInvoiced <= 0
        ? 0
        : ((_totalCollected / totalInvoiced) * 100).clamp(0, 100);
    final classesCovered = _feeStructures
        .map((row) => _textValue(row['class']))
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
    return [
      PrincipalDirectoryCard(
        icon: Icons.pie_chart_outline_rounded,
        title: 'Collection Rate',
        subtitle: 'Collected against total invoiced fees',
        status: '${paidPct.toStringAsFixed(0)}%',
        statusColor: AppTheme.success,
        chips: [
          PrincipalInfoPill(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Collected ${_money(_totalCollected)}',
          ),
          PrincipalInfoPill(
            icon: Icons.receipt_long_outlined,
            label: 'Invoiced ${_money(totalInvoiced)}',
          ),
        ],
      ),
      PrincipalDirectoryCard(
        icon: Icons.class_outlined,
        title: 'Class Fee Coverage',
        subtitle: 'Classes with configured fee structures',
        status: '$classesCovered classes',
        statusColor: AppTheme.primary,
        chips: [
          PrincipalInfoPill(
            icon: Icons.price_change_outlined,
            label: '${_feeStructures.length} structures',
          ),
          PrincipalInfoPill(
            icon: Icons.category_outlined,
            label: '${_feeCategories.length} fee types',
          ),
        ],
        onTap: () => setState(() => _selectedView = 'Class Fees'),
      ),
      PrincipalDirectoryCard(
        icon: Icons.warning_amber_rounded,
        title: 'Pending and Overdue',
        subtitle: 'Students needing fee follow-up',
        status: '$_overdueStudentCount overdue',
        statusColor: AppTheme.warning,
        chips: [
          PrincipalInfoPill(
            icon: Icons.pending_actions_outlined,
            label: 'Pending ${_money(_totalPending)}',
          ),
          PrincipalInfoPill(
            icon: Icons.people_outline_rounded,
            label: '$_pendingStudentCount students',
          ),
        ],
        onTap: () => setState(() => _selectedView = 'Student Fees'),
      ),
      PrincipalDirectoryCard(
        icon: Icons.volunteer_activism_outlined,
        title: 'Concessions Provided',
        subtitle: 'Concession requests and decisions recorded',
        status: '${_concessionRequests.length} requests',
        statusColor: AppTheme.primary,
        onTap: () => setState(() => _selectedView = 'Concessions'),
      ),
      PrincipalDirectoryCard(
        icon: Icons.file_download_outlined,
        title: 'Fee Analytics Export',
        subtitle: 'Generate the backend fee report for this selection',
        status: 'Report',
        statusColor: AppTheme.success,
        chips: [
          PrincipalInfoPill(
            icon: Icons.filter_alt_outlined,
            label: 'Class $_selectedClass',
          ),
          PrincipalInfoPill(
            icon: Icons.verified_outlined,
            label: 'Status $_selectedStatus',
          ),
        ],
        onTap: _exportFeeReport,
      ),
    ];
  }

  Widget _buildStudentFeeCard(Map<String, dynamic> row) {
    final status = _statusForInvoice(row);
    final total = _numValue(row['total']);
    final paid = _numValue(row['paid']);
    final paidPct = total <= 0 ? 0 : ((paid / total) * 100).clamp(0, 100);
    return PrincipalDirectoryCard(
      icon: Icons.receipt_long_outlined,
      title: _textValue(row['name'], fallback: 'Student'),
      subtitle:
          '${_textValue(row['class'], fallback: 'Class not assigned')} | Due ${_dateLabel(row['due_date'])}',
      status: status,
      statusColor: _statusColor(status),
      chips: [
        PrincipalInfoPill(
          icon: Icons.payments_outlined,
          label: 'Paid ${_money(_numValue(row['paid']))}',
        ),
        PrincipalInfoPill(
          icon: Icons.pending_actions_outlined,
          label: 'Balance ${_money(_numValue(row['balance']))}',
        ),
        PrincipalInfoPill(
          icon: Icons.pie_chart_outline_rounded,
          label: '${paidPct.toStringAsFixed(0)}% paid',
        ),
      ],
      trailing: PopupMenuButton<String>(
        tooltip: 'Fee options',
        onSelected: (value) => _handleInvoiceAction(value, row),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'payment', child: Text('Record payment')),
          PopupMenuItem(value: 'receipt', child: Text('Preview receipt')),
        ],
      ),
      onTap: () => _openInvoiceDetail(row),
    );
  }

  Widget _buildStructureCard(Map<String, dynamic> row) {
    return PrincipalDirectoryCard(
      icon: Icons.price_change_outlined,
      title:
          '${_textValue(row['category'], fallback: 'Fee')} - ${_textValue(row['class'], fallback: 'Class')}',
      subtitle:
          '${_money(_numValue(row['amount']))} | ${_textValue(row['frequency'], fallback: 'term')} | Due day ${row['due_day'] ?? '-'}',
      status: 'Structure',
      statusColor: AppTheme.primary,
      chips: [
        PrincipalInfoPill(
          icon: Icons.account_balance_wallet_outlined,
          label: _money(_numValue(row['amount'])),
        ),
      ],
      trailing: PopupMenuButton<String>(
        tooltip: 'Fee structure options',
        onSelected: (value) => _handleStructureAction(value, row),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit structure')),
          PopupMenuItem(value: 'generate', child: Text('Generate invoices')),
          PopupMenuItem(value: 'delete', child: Text('Delete structure')),
        ],
      ),
      onTap: () => _openGenericFeeDetail('Fee Structure', row),
    );
  }

  Widget _buildFeeCategoryCard(Map<String, dynamic> row) {
    final categoryID = _textValue(row['id']);
    final linkedStructures = _feeStructures
        .where(
          (structure) => _textValue(structure['fee_category_id']) == categoryID,
        )
        .length;
    return PrincipalDirectoryCard(
      icon: Icons.category_outlined,
      title: _textValue(
        row['category_name'] ?? row['name'],
        fallback: 'Fee element',
      ),
      subtitle:
          '${_textValue(row['frequency'], fallback: 'term')} | $linkedStructures class-wise structures',
      status: linkedStructures == 0 ? 'Unused' : 'Linked',
      statusColor: linkedStructures == 0 ? AppTheme.success : AppTheme.warning,
      chips: [
        PrincipalInfoPill(
          icon: Icons.price_change_outlined,
          label: '$linkedStructures structures',
        ),
      ],
      trailing: PopupMenuButton<String>(
        tooltip: 'Fee element options',
        onSelected: (value) {
          if (value == 'delete') _deleteFeeCategory(row);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'delete', child: Text('Delete element')),
        ],
      ),
      onTap: () => _openGenericFeeDetail('Fee Element', row),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> row) {
    return PrincipalDirectoryCard(
      icon: Icons.payments_outlined,
      title: _textValue(row['name'], fallback: 'Payment'),
      subtitle:
          '${_textValue(row['mode'], fallback: 'mode')} | ${_dateLabel(row['date'])} | ${_textValue(row['receipt'], fallback: 'Receipt pending')}',
      status: _money(_numValue(row['amount'])),
      statusColor: AppTheme.success,
      onTap: () => _openGenericFeeDetail('Payment Details', row),
    );
  }

  Widget _buildConcessionCard(Map<String, dynamic> row) {
    final status = _textValue(row['status'], fallback: 'Pending');
    return PrincipalDirectoryCard(
      icon: Icons.volunteer_activism_outlined,
      title: _textValue(
        row['student_name'] ?? row['student_id'],
        fallback: 'Concession request',
      ),
      subtitle: _textValue(row['reason'], fallback: 'Reason pending'),
      status: status,
      statusColor: _statusColor(status),
      onTap: () => _openGenericFeeDetail('Concession Details', row),
    );
  }

  Future<void> _handleInvoiceAction(
    String action,
    Map<String, dynamic> row,
  ) async {
    switch (action) {
      case 'payment':
        await _showPaymentSheet(row);
        break;
      case 'receipt':
        await _printReceiptFromInvoice(row);
        break;
    }
  }

  Future<void> _handleStructureAction(
    String action,
    Map<String, dynamic> row,
  ) async {
    switch (action) {
      case 'edit':
        await _showFeeStructureForm(structure: row);
        break;
      case 'generate':
        await _generateStudentFeeRecords(seed: row);
        break;
      case 'delete':
        await _deleteFeeStructure(row);
        break;
    }
  }

  Future<void> _openInvoiceDetail(Map<String, dynamic> row) async {
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (detailContext) => _FeeInvoiceDetailPage(
          invoice: row,
          status: _statusForInvoice(row),
          onCollectPayment: () => Navigator.pop(detailContext, 'payment'),
          onReceipt: () => Navigator.pop(detailContext, 'receipt'),
        ),
      ),
    );
    if (!mounted || action == null) return;
    await _handleInvoiceAction(action, row);
  }

  Future<void> _openGenericFeeDetail(
    String title,
    Map<String, dynamic> row,
  ) async {
    final fields = row.entries
        .where((entry) => _textValue(entry.value).isNotEmpty)
        .take(16)
        .toList();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PrincipalDetailPage(
          title: title,
          children: [
            PrincipalDetailCard(
              title: title,
              children: [
                for (final field in fields)
                  PrincipalDetailRow(
                    label: _labelize(field.key),
                    value: _textValue(field.value),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFeeStructureForm({Map<String, dynamic>? structure}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrincipalInputPage(
          title: structure == null
              ? 'Add Class-wise Fee'
              : 'Edit Class-wise Fee',
          icon: Icons.price_change_outlined,
          child: _FeeStructureInputForm(
            academicYears: _academicYears,
            grades: _grades,
            feeCategories: _feeCategories,
            structure: structure,
            onSubmit: (payload) => _saveFeeStructure(
              payload,
              structureId: _textValue(structure?['id']),
            ),
          ),
        ),
      ),
    );
    if (result == true) await _loadData();
  }

  Future<void> _saveFeeStructure(
    Map<String, dynamic> payload, {
    String structureId = '',
  }) async {
    final body = Map<String, dynamic>.from(payload);
    if (_textValue(body['fee_category_id']).isEmpty) {
      final categoryName = _textValue(body.remove('category_name'));
      final frequency = _textValue(body.remove('frequency'), fallback: 'term');
      final category = await BackendApiClient.instance.createRaw(
        '/fees/categories',
        {
          'category_name': categoryName,
          'frequency': frequency,
          'is_refundable': false,
        },
      );
      body['fee_category_id'] = _textValue(category['id']);
    }
    if (_textValue(body['fee_category_id']).isEmpty) {
      throw Exception('Fee category is required');
    }
    if (structureId.isEmpty) {
      await BackendApiClient.instance.createRaw('/fees/structures', body);
      _snack('Class-wise fee structure created', success: true);
    } else {
      await BackendApiClient.instance.updateRaw(
        '/fees/structures/$structureId',
        body,
      );
      _snack('Class-wise fee structure updated', success: true);
    }
  }

  Future<void> _deleteFeeStructure(Map<String, dynamic> row) async {
    final id = _textValue(row['id']);
    if (id.isEmpty) {
      _snack('Fee structure id is missing');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete fee structure'),
        content: Text(
          'Delete ${_textValue(row['category'], fallback: 'this fee')} for ${_textValue(row['class'], fallback: 'this class')}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
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
      await _loadData();
      _snack('Fee structure deleted', success: true);
    } catch (error) {
      _snack('Unable to delete fee structure: $error');
    }
  }

  Future<void> _deleteFeeCategory(Map<String, dynamic> row) async {
    final id = _textValue(row['id']);
    if (id.isEmpty) {
      _snack('Fee element id is missing');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete fee element'),
        content: Text(
          'Delete ${_textValue(row['category_name'] ?? row['name'], fallback: 'this fee element')}? Linked fee structures or invoices must be removed first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await BackendApiClient.instance.deleteRaw('/fees/categories/$id');
      await _loadData();
      _snack('Fee element deleted', success: true);
    } catch (error) {
      _snack('Unable to delete fee element: $error');
    }
  }

  Future<void> _generateStudentFeeRecords({Map<String, dynamic>? seed}) async {
    final year =
        _academicYears
            .where((item) => item.id == _textValue(seed?['academic_year_id']))
            .firstOrNull ??
        _academicYears.where((item) => item.isCurrent).firstOrNull ??
        (_academicYears.isEmpty ? null : _academicYears.first);
    final grade =
        _grades
            .where((item) => item.id == _textValue(seed?['grade_id']))
            .firstOrNull ??
        (_grades.isEmpty ? null : _grades.first);
    if (year == null || grade == null) {
      _snack(
        'Academic year and grade are required before generating fee records',
      );
      return;
    }
    try {
      // createRaw('/fees/structures' remains the structure-write contract; generation writes invoices.
      await BackendApiClient.instance.createRaw('/fees/invoices/generate', {
        'academic_year_id': year.id,
        'grade_id': grade.id,
        'invoice_label': seed == null
            ? 'Principal generated records'
            : 'Principal ${_textValue(seed['category'], fallback: 'fee')}',
        'due_date': DateTime.now()
            .add(const Duration(days: 15))
            .toIso8601String()
            .split('T')
            .first,
      });
      _snack('Student fee record generation queued', success: true);
      await _loadData();
    } catch (error) {
      _snack('Unable to generate student fee records: $error');
    }
  }

  Future<void> _showPaymentSheet(Map<String, dynamic>? invoice) async {
    if (invoice == null) {
      _snack('Select an invoice before recording payment');
      return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CashPaymentPage(
          invoice: invoice,
          onSubmit: (amount, receipt, remarks) async {
            await BackendApiClient.instance.recordPayment(
              PaymentRequest(
                invoiceId: _textValue(invoice['id']),
                receiptNumber: receipt,
                amountPaid: amount,
                paymentDate: DateTime.now().toIso8601String().split('T').first,
                paymentMode: 'cash',
                transactionId: remarks.trim().isEmpty ? null : remarks.trim(),
              ),
            );
          },
        ),
      ),
    );
    if (result == true) {
      await _loadData();
      _snack('Payment recorded', success: true);
    }
  }

  Future<void> _exportFeeReport() async {
    try {
      await BackendApiClient.instance.createReportExport(
        '/fees/reports/exports',
        reportTitle: 'Principal fee monitoring',
        reportType: 'principal_fee_monitoring',
        format: 'pdf',
        parameters: {'class': _selectedClass, 'status': _selectedStatus},
      );
      _snack('Fee report export queued', success: true);
    } catch (error) {
      _snack('Unable to export fee report: $error');
    }
  }

  Future<void> _printReceiptFromInvoice(Map<String, dynamic> invoice) async {
    try {
      final pdfService = PdfService.getInstance();
      final amount = _numValue(
        invoice['amount'] ?? invoice['paid'] ?? invoice['total'],
      );
      final bytes = await pdfService.generateFeeReceipt(
        receiptNo: _textValue(invoice['receipt'], fallback: 'RCP'),
        studentName: _textValue(invoice['name'], fallback: 'Student'),
        className: _textValue(invoice['class'], fallback: 'Class'),
        rollNo: _textValue(invoice['roll'], fallback: '-'),
        parentName: _textValue(invoice['parent_name'], fallback: 'Parent'),
        feeItems: [
          {'description': 'Fee payment', 'amount': amount, 'status': 'Paid'},
        ],
        totalAmount: amount,
        paidAmount: amount,
        balance: _numValue(invoice['balance']),
        paymentMode: _textValue(invoice['mode'], fallback: 'Recorded'),
        paymentDate:
            DateTime.tryParse(_textValue(invoice['date'])) ?? DateTime.now(),
      );
      if (!mounted) return;
      await pdfService.previewDocument(context, bytes, 'Fee Receipt');
    } catch (error) {
      _snack('Unable to preview receipt: $error');
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    final query = _searchQuery.trim().toLowerCase();
    return _studentFees.where((row) {
      final className = _textValue(row['class']);
      final status = _statusForInvoice(row);
      final matchesClass =
          _selectedClass == 'All' || className == _selectedClass;
      final matchesStatus =
          _selectedStatus == 'All' ||
          status.toLowerCase() == _selectedStatus.toLowerCase();
      final haystack = [
        row['name'],
        row['class'],
        row['invoice_number'],
        row['status'],
      ].map(_textValue).join(' ').toLowerCase();
      return matchesClass &&
          matchesStatus &&
          (query.isEmpty || haystack.contains(query));
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredPaymentRows {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _recentPayments;
    return _recentPayments.where((row) {
      final haystack = [
        row['name'],
        row['class'],
        row['mode'],
        row['receipt'],
        row['amount'],
      ].map(_textValue).join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredConcessionRows {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _concessionRequests;
    return _concessionRequests.where((row) {
      final haystack = [
        row['student_name'],
        row['student_id'],
        row['reason'],
        row['status'],
      ].map(_textValue).join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Map<String, dynamic> _normalizeFeeStructure(Map<String, dynamic> structure) {
    final category = _mapValue(structure['fee_category']);
    final grade = _mapValue(structure['grade']);
    return {
      ...structure,
      'class': _textValue(
        grade['grade_name'],
        fallback: _textValue(structure['grade_id']),
      ),
      'category': _textValue(
        category['category_name'] ?? category['name'],
        fallback: 'Fee',
      ),
      'amount': _numValue(structure['amount'] ?? structure['tuition']),
      'frequency': _textValue(structure['frequency'], fallback: 'term'),
      'due_day': structure['due_day'] ?? '-',
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
          ? _textValue(invoice['class'], fallback: 'Class not assigned')
          : classLabel,
      'total': _numValue(invoice['total_amount'] ?? invoice['net_amount']),
      'discount': _numValue(invoice['discount_amount']),
      'paid': _numValue(invoice['paid_amount']),
      'balance': _numValue(invoice['balance']),
      'due_date': invoice['due_date'],
      'status': _textValue(invoice['status'], fallback: 'pending'),
      'invoice_number': invoice['invoice_number'],
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
      };
    });
  }

  String _statusForInvoice(Map<String, dynamic> row) {
    final balance = _numValue(row['balance']);
    final paid = _numValue(row['paid']);
    if (balance <= 0) return 'Paid';
    if (paid > 0) return 'Partial';
    final dueDate = DateTime.tryParse(_textValue(row['due_date']));
    if (dueDate != null && dueDate.isBefore(DateTime.now())) return 'Overdue';
    return 'Pending';
  }

  double get _totalPending =>
      _studentFees.fold(0, (sum, row) => sum + _numValue(row['balance']));
  double get _totalCollected =>
      _studentFees.fold(0, (sum, row) => sum + _numValue(row['paid']));
  int get _pendingStudentCount =>
      _studentFees.where((row) => _numValue(row['balance']) > 0).length;
  int get _overdueStudentCount =>
      _studentFees.where((row) => _statusForInvoice(row) == 'Overdue').length;
  double get _todayCollection {
    final today = DateTime.now().toIso8601String().split('T').first;
    return _recentPayments
        .where((row) => _dateLabel(row['date']) == today)
        .fold(0, (sum, row) => sum + _numValue(row['amount']));
  }

  Map<String, dynamic>? get _firstCollectibleInvoice {
    final rows = _studentFees.where((row) => _numValue(row['balance']) > 0);
    return rows.isEmpty ? null : rows.first;
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('paid') || lower.contains('approved')) {
      return Colors.green;
    }
    if (lower.contains('overdue') || lower.contains('rejected')) {
      return Colors.red;
    }
    if (lower.contains('partial')) return Colors.indigo;
    return Colors.orange;
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

  String _labelize(String key) {
    final label = key.replaceAll('_', ' ').trim();
    if (label.isEmpty) return 'Field';
    return '${label[0].toUpperCase()}${label.substring(1)}';
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

class _FeeDashboardMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _FeeDashboardMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withAlpha(215)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(32),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withAlpha(220),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeQuickActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeeQuickActionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE3EDF5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withAlpha(18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  color: principalDirectoryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeeInvoiceDetailPage extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final String status;
  final VoidCallback onCollectPayment;
  final VoidCallback onReceipt;

  const _FeeInvoiceDetailPage({
    required this.invoice,
    required this.status,
    required this.onCollectPayment,
    required this.onReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final total = _num(invoice['total']);
    final paid = _num(invoice['paid']);
    final balance = _num(invoice['balance']);
    final progress = total <= 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);
    final items = _items(invoice);
    final payments = _payments(invoice);

    return Scaffold(
      backgroundColor: principalDirectoryBackground,
      appBar: AppBar(
        backgroundColor: principalDirectoryBackground,
        elevation: 0,
        title: const Text('Student Fee Details'),
        actions: [
          IconButton(
            tooltip: 'Receipt',
            onPressed: paid > 0 ? onReceipt : null,
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x1F7FA6BD),
                blurRadius: 16,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: balance > 0 ? onCollectPayment : null,
                  child: Text('Collect ${_money(balance)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: balance > 0
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Reminder queue is not connected yet. Use contact workflow after selecting the student.',
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Send Reminder'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _detailPanel(
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_circle_outlined,
                      color: principalDirectoryAccent,
                      size: 42,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(invoice['name'], fallback: 'Student'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: principalDirectoryText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _text(
                            invoice['class'],
                            fallback: 'Class not assigned',
                          ),
                          style: const TextStyle(
                            color: principalDirectoryMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Invoice ${_text(invoice['invoice_number'], fallback: '-')}',
                          style: const TextStyle(
                            color: principalDirectoryMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PrincipalStatusPill(
                    label: status,
                    color: _statusColor(status),
                  ),
                ],
              ),
            ),
            _detailPanel(
              title: 'Fee Summary',
              child: Row(
                children: [
                  SizedBox(
                    width: 108,
                    height: 108,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 94,
                          height: 94,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 13,
                            backgroundColor: const Color(0xFFEFF3F8),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF18B57D),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: principalDirectoryText,
                              ),
                            ),
                            const Text(
                              'Paid',
                              style: TextStyle(
                                fontSize: 11,
                                color: principalDirectoryMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _amountRow(
                          'Total Fees',
                          _money(total),
                          const Color(0xFF3157F6),
                        ),
                        _amountRow(
                          'Paid Fees',
                          _money(paid),
                          const Color(0xFF18B57D),
                        ),
                        _amountRow(
                          'Pending Fees',
                          _money(balance),
                          const Color(0xFFE84D68),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _detailPanel(
              title: 'Fee Breakdown',
              child: Column(
                children: [
                  if (items.isEmpty)
                    _emptyText('No invoice item breakdown is available.')
                  else
                    for (final item in items)
                      _breakdownRow(
                        title: _text(
                          item['description'] ??
                              _map(item['fee_category'])['category_name'],
                          fallback: 'Fee item',
                        ),
                        amount: _num(item['amount']),
                        balance: balance,
                        paid: paid,
                      ),
                ],
              ),
            ),
            _detailPanel(
              title: 'Payments',
              child: Column(
                children: [
                  if (payments.isEmpty)
                    _emptyText('No payment has been recorded yet.')
                  else
                    for (final payment in payments)
                      _paymentRow(
                        amount: _num(payment['amount_paid']),
                        mode: _text(payment['payment_mode'], fallback: 'cash'),
                        date: _date(payment['payment_date']),
                        receipt: _text(payment['receipt_number']),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _detailPanel({String? title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7FA6BD).withAlpha(36),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: principalDirectoryText,
              ),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }

  static Widget _amountRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: principalDirectoryMuted,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: principalDirectoryText,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _breakdownRow({
    required String title,
    required double amount,
    required double balance,
    required double paid,
  }) {
    final paidRatio = amount <= 0 ? 0.0 : (paid / amount).clamp(0.0, 1.0);
    final statusLabel = balance <= 0
        ? 'Paid'
        : paid > 0
        ? 'Paid ${(paidRatio * 100).toStringAsFixed(0)}%'
        : 'Due ${_money(amount)}';
    final statusColor = balance <= 0 || paid > 0
        ? const Color(0xFF18B57D)
        : const Color(0xFFFF8A12);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3EDF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.local_offer_outlined, color: statusColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(amount),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _paymentRow({
    required double amount,
    required String mode,
    required String date,
    required String receipt,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFEAFBF3),
        child: Icon(Icons.payments_outlined, color: Color(0xFF18B57D)),
      ),
      title: Text(
        _money(amount),
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        [date, mode, receipt].where((part) => part.isNotEmpty).join(' | '),
      ),
    );
  }

  static Widget _emptyText(String message) {
    return Text(
      message,
      style: const TextStyle(
        color: principalDirectoryMuted,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static List<Map<String, dynamic>> _items(Map<String, dynamic> invoice) {
    final raw = invoice['items'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  static List<Map<String, dynamic>> _payments(Map<String, dynamic> invoice) {
    final raw = invoice['payments'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((payment) {
      return Map<String, dynamic>.from(payment);
    }).toList();
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static double _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  static String _date(Object? value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? '' : date.toIso8601String().split('T').first;
  }

  static String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  static Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('paid')) return const Color(0xFF18B57D);
    if (lower.contains('overdue')) return const Color(0xFFE84D68);
    if (lower.contains('partial')) return const Color(0xFF3157F6);
    return const Color(0xFFFF8A12);
  }
}

class _CashPaymentPage extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final Future<void> Function(double amount, String receipt, String remarks)
  onSubmit;

  const _CashPaymentPage({required this.invoice, required this.onSubmit});

  @override
  State<_CashPaymentPage> createState() => _CashPaymentPageState();
}

class _CashPaymentPageState extends State<_CashPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _receiptController;
  late final TextEditingController _remarksController;
  bool _saving = false;

  double get _balance => _num(widget.invoice['balance']);
  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _amountController = TextEditingController(
      text: _balance.toStringAsFixed(0),
    );
    _receiptController = TextEditingController(
      text:
          'CASH-${now.year}${_two(now.month)}${_two(now.day)}-${now.millisecondsSinceEpoch.toString().substring(8)}',
    );
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _receiptController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: principalDirectoryBackground,
      appBar: AppBar(
        backgroundColor: principalDirectoryBackground,
        elevation: 0,
        title: const Text('Collect Payment'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: [
              _panel(
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_circle_outlined,
                        color: principalDirectoryAccent,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text(widget.invoice['name'], fallback: 'Student'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: principalDirectoryText,
                            ),
                          ),
                          Text(
                            _text(
                              widget.invoice['class'],
                              fallback: 'Class not assigned',
                            ),
                            style: const TextStyle(
                              color: principalDirectoryMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Due amount',
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _money(_balance),
                      style: const TextStyle(
                        color: Color(0xFFE84D68),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Select Fee Type',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _panel(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _text(
                          widget.invoice['invoice_number'],
                          fallback: 'Student fee invoice',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      'Due: ${_money(_balance)}',
                      style: const TextStyle(
                        color: principalDirectoryMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Payment Details',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountController,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                ),
                validator: (value) {
                  final amount = double.tryParse((value ?? '').trim()) ?? 0;
                  if (amount <= 0) return 'Enter an amount';
                  if (amount > _balance) return 'Amount cannot exceed balance';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _readonlyMoney('Discount', 0),
              const SizedBox(height: 12),
              _readonlyMoney('Fine / Late Fee', 0),
              const SizedBox(height: 12),
              _readonlyMoney('Total Amount', _amount),
              const SizedBox(height: 18),
              const Text(
                'Payment Method',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _panel(
                child: Row(
                  children: const [
                    Icon(Icons.payments_outlined, color: Color(0xFF18B57D)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cash',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Icon(Icons.check_circle_rounded, color: Color(0xFF18B57D)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _receiptController,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Receipt number'),
                validator: (value) {
                  if ((value ?? '').trim().length < 3) {
                    return 'Enter receipt number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarksController,
                enabled: !_saving,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                  hintText: 'Enter remarks',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(
                  _saving
                      ? 'Collecting...'
                      : 'Collect ${_money(_amount <= 0 ? _balance : _amount)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readonlyMoney(String label, double amount) {
    return TextFormField(
      enabled: false,
      initialValue: _money(amount),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3EDF5)),
      ),
      child: child,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        _amount,
        _receiptController.text.trim(),
        _remarksController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to collect payment: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  double _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  String _two(int value) => value.toString().padLeft(2, '0');
}

class _FeeStructureInputForm extends StatefulWidget {
  final List<AcademicYearModel> academicYears;
  final List<GradeModel> grades;
  final List<Map<String, dynamic>> feeCategories;
  final Map<String, dynamic>? structure;
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  const _FeeStructureInputForm({
    required this.academicYears,
    required this.grades,
    required this.feeCategories,
    required this.onSubmit,
    this.structure,
  });

  @override
  State<_FeeStructureInputForm> createState() => _FeeStructureInputFormState();
}

class _FeeStructureInputFormState extends State<_FeeStructureInputForm> {
  static const _newCategoryId = '__new_category__';
  static const _frequencies = ['monthly', 'term', 'annual', 'one_time'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _categoryName;
  late final TextEditingController _amount;
  late final TextEditingController _dueDay;
  late final TextEditingController _lateFine;
  String _academicYearId = '';
  String _gradeId = '';
  String _feeCategoryId = '';
  String _frequency = 'term';
  bool _saving = false;

  bool get _hasReferenceData =>
      widget.academicYears.isNotEmpty && widget.grades.isNotEmpty;

  bool get _usingNewCategory =>
      _feeCategoryId == _newCategoryId || widget.feeCategories.isEmpty;

  @override
  void initState() {
    super.initState();
    final structure = widget.structure ?? const <String, dynamic>{};
    _academicYearId = _initialId(
      _textValue(structure['academic_year_id']),
      widget.academicYears.map((year) => year.id),
      fallback: widget.academicYears
          .where((year) => year.isCurrent)
          .firstOrNull
          ?.id,
    );
    _gradeId = _initialId(
      _textValue(structure['grade_id']),
      widget.grades.map((grade) => grade.id),
    );
    _feeCategoryId = _initialId(
      _textValue(structure['fee_category_id']),
      widget.feeCategories.map((category) => _textValue(category['id'])),
      fallback: widget.feeCategories.isEmpty ? _newCategoryId : null,
    );
    if (_feeCategoryId.isEmpty) _feeCategoryId = _newCategoryId;
    _categoryName = TextEditingController(
      text: _usingNewCategory ? _textValue(structure['category']) : '',
    );
    _amount = TextEditingController(
      text: _controllerNumber(structure['amount']),
    );
    _dueDay = TextEditingController(
      text: _controllerInt(structure['due_day'], fallback: '10'),
    );
    _lateFine = TextEditingController(
      text: _controllerNumber(structure['late_fine_per_day'], fallback: '0'),
    );
  }

  @override
  void dispose() {
    _categoryName.dispose();
    _amount.dispose();
    _dueDay.dispose();
    _lateFine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasReferenceData) {
      return const OpsEmptyState(
        icon: Icons.price_change_outlined,
        title: 'Class setup required',
        message:
            'Create an academic year and class before adding class-wise fee structures.',
      );
    }
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _academicYearId,
            decoration: const InputDecoration(labelText: 'Academic year'),
            items: widget.academicYears
                .map(
                  (year) => DropdownMenuItem(
                    value: year.id,
                    child: Text(year.yearLabel),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select academic year.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _academicYearId = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _gradeId,
            decoration: const InputDecoration(labelText: 'Class'),
            items: widget.grades
                .map(
                  (grade) => DropdownMenuItem(
                    value: grade.id,
                    child: Text(grade.gradeName),
                  ),
                )
                .toList(),
            validator: (value) => _required(value, 'Select class.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _gradeId = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _feeCategoryId,
            decoration: const InputDecoration(labelText: 'Fee element'),
            items: [
              for (final category in widget.feeCategories)
                DropdownMenuItem(
                  value: _textValue(category['id']),
                  child: Text(
                    _textValue(category['category_name'], fallback: 'Fee'),
                  ),
                ),
              const DropdownMenuItem(
                value: _newCategoryId,
                child: Text('Create new fee element'),
              ),
            ],
            validator: (value) => _required(value, 'Select fee element.'),
            onChanged: _saving
                ? null
                : (value) => setState(() => _feeCategoryId = value ?? ''),
          ),
          if (_usingNewCategory) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryName,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'New fee element name',
                hintText: 'Tuition, Transport, Books...',
              ),
              validator: (value) => _required(value, 'Enter fee element name.'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: [
                for (final value in _frequencies)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _frequency = value ?? 'term'),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: 'INR ',
            ),
            validator: (value) {
              final amount = double.tryParse((value ?? '').trim()) ?? 0;
              return amount <= 0 ? 'Enter a valid amount.' : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _dueDay,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Due day'),
            validator: (value) {
              final dueDay = int.tryParse((value ?? '').trim()) ?? 0;
              return dueDay < 1 || dueDay > 31
                  ? 'Enter a due day from 1 to 31.'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lateFine,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Late fine per day',
              prefixText: 'INR ',
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save class-wise fee'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit({
        'academic_year_id': _academicYearId,
        'grade_id': _gradeId,
        'fee_category_id': _usingNewCategory ? '' : _feeCategoryId,
        if (_usingNewCategory) 'category_name': _categoryName.text.trim(),
        if (_usingNewCategory) 'frequency': _frequency,
        'amount': double.parse(_amount.text.trim()),
        'due_day': int.parse(_dueDay.text.trim()),
        'late_fine_per_day': double.tryParse(_lateFine.text.trim()) ?? 0,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save class-wise fee: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _initialId(
    String preferred,
    Iterable<String> options, {
    String? fallback,
  }) {
    final values = options.where((value) => value.trim().isNotEmpty).toList();
    if (preferred.trim().isNotEmpty && values.contains(preferred)) {
      return preferred;
    }
    if (fallback != null &&
        fallback.trim().isNotEmpty &&
        values.contains(fallback)) {
      return fallback;
    }
    return values.isEmpty ? '' : values.first;
  }

  static String _controllerNumber(Object? value, {String fallback = ''}) {
    if (value is num) {
      final amount = value.toDouble();
      return amount == amount.roundToDouble()
          ? amount.toStringAsFixed(0)
          : amount.toStringAsFixed(2);
    }
    final text = _textValue(value);
    return text.isEmpty ? fallback : text;
  }

  static String _controllerInt(Object? value, {String fallback = ''}) {
    if (value is num) return value.toInt().toString();
    final text = _textValue(value);
    return text.isEmpty ? fallback : text;
  }

  static String _textValue(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  static String? _required(String? value, String message) {
    return (value ?? '').trim().isEmpty ? message : null;
  }
}

class _ManualFeeEntrySheet extends StatefulWidget {
  final List<StudentModel> students;
  final List<Map<String, dynamic>> feeCategories;
  final Future<bool> Function(Map<String, dynamic> payload) onSubmit;

  const _ManualFeeEntrySheet({
    required this.students,
    required this.feeCategories,
    required this.onSubmit,
  });

  @override
  State<_ManualFeeEntrySheet> createState() => _ManualFeeEntrySheetState();
}

class _ManualFeeEntrySheetState extends State<_ManualFeeEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _dueDate = TextEditingController(
    text: DateTime.now()
        .add(const Duration(days: 15))
        .toIso8601String()
        .split('T')
        .first,
  );
  String _studentId = '';
  bool _paymentNow = false;
  bool _saving = false;

  double get _actualFee => double.tryParse(_actual.text.trim()) ?? 0;
  double get _discountValue => double.tryParse(_discount.text.trim()) ?? 0;
  double get _payable =>
      (_actualFee - _discountValue).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _studentId = widget.students.isEmpty ? '' : widget.students.first.id;
    _actual.addListener(() => setState(() {}));
    _discount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _actual.dispose();
    _discount.dispose();
    _dueDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Student Fee Entry',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _studentId.isEmpty ? null : _studentId,
                decoration: const InputDecoration(labelText: 'Student'),
                items: widget.students
                    .map(
                      (student) => DropdownMenuItem(
                        value: student.id,
                        child: Text(student.fullName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => _studentId = value ?? '',
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Student is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _actual,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Actual Fee'),
                validator: (value) =>
                    (double.tryParse((value ?? '').trim()) ?? 0) <= 0
                    ? 'Actual fee is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Discount Given'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dueDate,
                decoration: const InputDecoration(labelText: 'Due date'),
              ),
              const SizedBox(height: 12),
              OpsListRow(
                icon: Icons.price_check_outlined,
                title: 'To Be Paid',
                subtitle: '₹${_payable.toStringAsFixed(0)}',
                trailing: Switch(
                  value: _paymentNow,
                  onChanged: (value) => setState(() => _paymentNow = value),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save fee entry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final ok = await widget.onSubmit({
      'student_id': _studentId,
      'invoice_date': DateTime.now().toIso8601String().split('T').first,
      'due_date': _dueDate.text.trim(),
      'total_amount': _actualFee,
      'discount_amount': _discountValue,
      'net_amount': _payable,
      'payment_received_now': _paymentNow,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok && context.mounted) Navigator.pop(context, true);
  }
}

class _PaymentEntryForm extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final double balance;
  final Future<void> Function(double amount, String receipt) onSubmit;

  const _PaymentEntryForm({
    required this.invoice,
    required this.balance,
    required this.onSubmit,
  });

  @override
  State<_PaymentEntryForm> createState() => _PaymentEntryFormState();
}

class _PaymentEntryFormState extends State<_PaymentEntryForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _receipt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.balance.toStringAsFixed(0));
    _receipt = TextEditingController(
      text: 'RCP-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _receipt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentName = '${widget.invoice['name'] ?? 'Student'}'.trim();
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrincipalActionTile(
            icon: Icons.receipt_long_outlined,
            title: studentName.isEmpty ? 'Student invoice' : studentName,
            subtitle:
                'Balance ₹${widget.balance.toStringAsFixed(0)} | ${widget.invoice['class'] ?? 'Class not assigned'}',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount received'),
            validator: (value) =>
                (double.tryParse((value ?? '').trim()) ?? 0) <= 0
                ? 'Amount is required'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _receipt,
            decoration: const InputDecoration(labelText: 'Receipt number'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Receipt is required' : null,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save payment'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        double.tryParse(_amount.text.trim()) ?? 0,
        _receipt.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to record payment: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}

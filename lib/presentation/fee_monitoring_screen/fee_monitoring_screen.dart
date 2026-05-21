import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/erp_module_scaffold.dart';

class FeeMonitoringScreen extends StatefulWidget {
  const FeeMonitoringScreen({super.key});

  @override
  State<FeeMonitoringScreen> createState() => _FeeMonitoringScreenState();
}

class _FeeMonitoringScreenState extends State<FeeMonitoringScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDrawerIndex = 7;
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedClass = 'All';

  List<Map<String, dynamic>> _feeStructures = [];
  List<Map<String, dynamic>> _studentFees = [];
  List<Map<String, dynamic>> _recentPayments = [];
  List<Map<String, dynamic>> _concessionRequests = [];
  List<GradeModel> _grades = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = BackendApiClient.instance;
      final feeStructures = await api.getFeeStructures();
      final studentFees = await api.getInvoices();
      final concessionRequests = await api.getRawList('/fees/concessions');
      final grades = await api.getGrades();
      final normalizedInvoices = studentFees.map(_normalizeInvoice).toList();
      if (!mounted) return;
      setState(() {
        _feeStructures = feeStructures.map(_normalizeFeeStructure).toList();
        _studentFees = normalizedInvoices;
        _recentPayments = studentFees.expand(_normalizePayments).toList();
        _concessionRequests = concessionRequests;
        _grades = grades;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load fee monitoring data: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _mapValue(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  double _numValue(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _textValue(dynamic value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _dateLabel(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return 'Not recorded';
    return parsed.toIso8601String().split('T').first;
  }

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  Map<String, dynamic> _normalizeFeeStructure(Map<String, dynamic> structure) {
    final category = _mapValue(structure['fee_category']);
    final grade = _mapValue(structure['grade']);
    final amount = _numValue(structure['amount']);
    return {
      ...structure,
      'class': _textValue(
        grade['grade_name'],
        fallback: _textValue(structure['grade_id']),
      ),
      'year': _textValue(
        _yearLabel(structure),
        fallback: _textValue(structure['academic_year_id']),
      ),
      'category': _textValue(category['category_name'], fallback: 'Fee'),
      'frequency': _textValue(
        category['frequency'],
        fallback: _textValue(structure['frequency'], fallback: 'term'),
      ),
      'total': amount,
      'due_day': structure['due_day'] ?? 0,
      'late_fine_per_day': _numValue(structure['late_fine_per_day']),
    };
  }

  Object? _yearLabel(Map<String, dynamic> structure) {
    final year = _mapValue(structure['academic_year']);
    return year['year_label'];
  }

  Map<String, dynamic> _normalizeInvoice(Map<String, dynamic> invoice) {
    final student = _mapValue(invoice['student']);
    final section = _mapValue(student['current_section']);
    final grade = _mapValue(section['grade']);
    final payments = (invoice['payments'] as List? ?? const [])
        .whereType<Map>()
        .map((payment) => Map<String, dynamic>.from(payment))
        .toList();
    payments.sort(
      (a, b) => '${b['payment_date'] ?? b['created_at'] ?? ''}'.compareTo(
        '${a['payment_date'] ?? a['created_at'] ?? ''}',
      ),
    );
    final latestPayment = payments.isEmpty
        ? <String, dynamic>{}
        : payments.first;
    final balance = _numValue(invoice['balance']);
    final amount = balance > 0 ? balance : _numValue(invoice['net_amount']);
    final dueDate = DateTime.tryParse('${invoice['due_date'] ?? ''}');
    final overdueMonths = dueDate == null
        ? 0
        : ((DateTime.now().difference(dueDate).inDays / 30).ceil()).clamp(
            0,
            99,
          );
    final classLabel = [
      _textValue(grade['grade_name']),
      _textValue(section['section_name']),
    ].where((part) => part.isNotEmpty).join(' ');
    final name = [
      _textValue(student['first_name']),
      _textValue(student['last_name']),
    ].where((part) => part.isNotEmpty).join(' ');
    final roll = _textValue(
      student['admission_number'],
      fallback: _textValue(
        student['student_code'],
        fallback: _textValue(invoice['roll'], fallback: '-'),
      ),
    );
    return {
      ...invoice,
      'name': name.isEmpty ? 'Student ${invoice['student_id'] ?? ''}' : name,
      'class': classLabel.isEmpty ? 'Unassigned class' : classLabel,
      'roll': roll,
      'amount': amount,
      'months': overdueMonths,
      'lastPaid': latestPayment.isEmpty
          ? 'No payment'
          : _dateLabel(
              latestPayment['payment_date'] ?? latestPayment['created_at'],
            ),
      'receipt': latestPayment['receipt_number'] ?? '',
      'mode': latestPayment['payment_mode'] ?? '',
      'date': _dateLabel(invoice['due_date']),
    };
  }

  Iterable<Map<String, dynamic>> _normalizePayments(
    Map<String, dynamic> invoice,
  ) {
    final normalizedInvoice = _normalizeInvoice(invoice);
    return (invoice['payments'] as List? ?? const []).whereType<Map>().map((
      payment,
    ) {
      final item = Map<String, dynamic>.from(payment);
      return {
        'id': item['id'],
        'invoice_id': invoice['id'],
        'name': normalizedInvoice['name'],
        'class': normalizedInvoice['class'],
        'date': _dateLabel(item['payment_date'] ?? item['created_at']),
        'mode': _textValue(item['payment_mode'], fallback: 'cash'),
        'receipt': _textValue(item['receipt_number'], fallback: ''),
        'amount': _numValue(item['amount_paid']),
        'payment_date': item['payment_date'] ?? item['created_at'],
        'amount_paid': _numValue(item['amount_paid']),
      };
    });
  }

  String _studentName(Map<String, dynamic> invoice) {
    final normalized = _textValue(invoice['name']);
    if (normalized.isNotEmpty) return normalized;
    final student = _mapValue(invoice['student']);
    final fullName =
        '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim();
    return fullName.isNotEmpty
        ? fullName
        : '${invoice['student_name'] ?? invoice['name'] ?? 'Student'}';
  }

  String _studentClass(Map<String, dynamic> invoice) {
    final normalized = _textValue(invoice['class']);
    if (normalized.isNotEmpty && normalized != 'Unassigned class') {
      return normalized;
    }
    final student = _mapValue(invoice['student']);
    final section = _mapValue(student['current_section']);
    final grade = _mapValue(section['grade']);
    final classLabel = [
      _textValue(grade['grade_name']),
      _textValue(section['section_name']),
    ].where((part) => part.isNotEmpty).join(' ');
    return classLabel.isNotEmpty ? classLabel : 'Unassigned';
  }

  String _studentRoll(Map<String, dynamic> invoice) {
    final normalized = _textValue(invoice['roll']);
    if (normalized.isNotEmpty) return normalized;
    final student = _mapValue(invoice['student']);
    return '${student['admission_number'] ?? student['student_code'] ?? invoice['roll'] ?? '-'}';
  }

  String _statusForInvoice(Map<String, dynamic> invoice) {
    final status = '${invoice['status'] ?? ''}'.toLowerCase();
    if (status == 'paid') return 'paid';
    final dueDate = DateTime.tryParse('${invoice['due_date'] ?? ''}');
    final balance = _numValue(invoice['balance']);
    if (balance <= 0) return 'paid';
    if (dueDate != null && dueDate.isBefore(DateTime.now())) return 'overdue';
    return status.isEmpty ? 'pending' : status;
  }

  String _structureClass(Map<String, dynamic> structure) {
    final normalized = _textValue(structure['class']);
    if (normalized.isNotEmpty) return normalized;
    final grade = _mapValue(structure['grade']);
    return '${grade['grade_name'] ?? structure['class'] ?? 'Class'}';
  }

  String _structureCategory(Map<String, dynamic> structure) {
    final normalized = _textValue(structure['category']);
    if (normalized.isNotEmpty) return normalized;
    final category = _mapValue(structure['fee_category']);
    return '${category['category_name'] ?? structure['category_name'] ?? 'Fee'}';
  }

  String _structureYear(Map<String, dynamic> structure) {
    final normalized = _textValue(structure['year']);
    if (normalized.isNotEmpty) return normalized;
    final year = _mapValue(structure['academic_year']);
    return '${year['year_label'] ?? structure['year_label'] ?? ''}';
  }

  String _structureFrequency(Map<String, dynamic> structure) {
    final normalized = _textValue(structure['frequency']);
    if (normalized.isNotEmpty) return normalized;
    final category = _mapValue(structure['fee_category']);
    final value =
        '${category['frequency'] ?? structure['frequency'] ?? 'term'}';
    return value.isEmpty ? 'term' : value;
  }

  String _concessionStudent(Map<String, dynamic> concession) {
    return '${concession['student_name'] ?? concession['requester_name'] ?? 'Student'}';
  }

  String _concessionClass(Map<String, dynamic> concession) {
    return '${concession['class_section'] ?? concession['class_name'] ?? concession['section'] ?? 'Unassigned'}';
  }

  String _concessionType(Map<String, dynamic> concession) {
    return '${concession['type'] ?? concession['summary'] ?? 'Fee concession'}';
  }

  String _concessionReason(Map<String, dynamic> concession) {
    return '${concession['reason'] ?? concession['details'] ?? concession['description'] ?? ''}';
  }

  String _concessionDate(Map<String, dynamic> concession) {
    return '${concession['submitted_at'] ?? concession['created_at'] ?? concession['updated_at'] ?? ''}'
        .split('T')
        .first;
  }

  String _concessionStatus(Map<String, dynamic> concession) {
    return '${concession['status'] ?? 'pending'}'.toLowerCase();
  }

  List<Map<String, dynamic>> get _filteredStudents {
    return _studentFees.where((s) {
      final matchSearch =
          _searchQuery.isEmpty ||
          _studentName(s).toLowerCase().contains(_searchQuery.toLowerCase());
      final matchClass =
          _selectedClass == 'All' || _studentClass(s) == _selectedClass;
      return matchSearch && matchClass;
    }).toList();
  }

  List<String> get _classFilters {
    final classes =
        _studentFees
            .map(_studentClass)
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...classes];
  }

  @override
  Widget build(BuildContext context) {
    final drawer = PrincipalDrawer(
      selectedIndex: _selectedDrawerIndex,
      onDestinationSelected: (i) => setState(() => _selectedDrawerIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Fee Monitoring',
        subtitle: 'Review collections, dues, structures, and concession risk',
        drawer: drawer,
        floatingActionButton: const DashboardFabWidget(
          role: DashboardRole.principal,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Fee Monitoring',
      subtitle: 'Review collections, dues, structures, and concession risk',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Student Fees'),
          Tab(text: 'Fee Structure'),
          Tab(text: 'Payments'),
          Tab(text: 'Concessions'),
        ],
      ),
      body: MediaQuery.of(context).size.width >= 840
          ? _buildTabletLayout(context)
          : _buildPhoneLayout(context),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildStudentFeesTab(),
        _buildFeeStructureTab(),
        _buildPaymentsTab(),
        _buildConcessionsTab(),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return _buildPhoneLayout(context);
  }

  Widget _buildOverviewTab() {
    final totalFee = _studentFees.fold<double>(
      0,
      (s, e) => s + _numValue(e['net_amount'] ?? e['total_amount']),
    );
    final totalPaid = _studentFees.fold<double>(
      0,
      (s, e) => s + _numValue(e['paid_amount']),
    );
    final totalPending = _studentFees.fold<double>(
      0,
      (s, e) => s + _numValue(e['balance']),
    );
    final overdue = _studentFees
        .where((s) => _statusForInvoice(s) == 'overdue')
        .length;
    final pending = _studentFees
        .where((s) => _statusForInvoice(s) == 'pending')
        .length;
    final paid = _studentFees
        .where((s) => _statusForInvoice(s) == 'paid')
        .length;
    final collectionRate = totalFee > 0 ? totalPaid / totalFee : 0.0;
    final configuredGradeIds = _feeStructures
        .map((s) => '${s['grade_id'] ?? _mapValue(s['grade'])['id'] ?? ''}')
        .where((id) => id.isNotEmpty)
        .toSet();
    final uncoveredClasses = _grades.length - configuredGradeIds.length;
    final classTotals = <String, double>{};
    for (final invoice in _studentFees) {
      final className = _studentClass(invoice);
      classTotals[className] =
          (classTotals[className] ?? 0) + _numValue(invoice['balance']);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Billed',
                  _money(totalFee),
                  Icons.receipt_long_rounded,
                  AppTheme.info,
                  AppTheme.infoContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Collected',
                  _money(totalPaid),
                  Icons.check_circle_outline_rounded,
                  AppTheme.success,
                  AppTheme.successContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Pending',
                  _money(totalPending),
                  Icons.pending_outlined,
                  AppTheme.warning,
                  AppTheme.warningContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Overdue',
                  '$overdue invoices',
                  Icons.warning_amber_rounded,
                  AppTheme.error,
                  AppTheme.errorContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Collection Progress',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Annual Collection Rate',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(collectionRate * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: collectionRate.clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: AppTheme.successContainer,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.success,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildStatusDot(AppTheme.success, 'Paid: $paid'),
                    _buildStatusDot(AppTheme.warning, 'Pending: $pending'),
                    _buildStatusDot(AppTheme.error, 'Overdue: $overdue'),
                    _buildStatusDot(
                      AppTheme.primary,
                      'Structures: ${_feeStructures.length}',
                    ),
                    _buildStatusDot(
                      AppTheme.info,
                      'Payments: ${_recentPayments.length}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Class Coverage',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  'Classes with fee structure',
                  '${configuredGradeIds.length}/${_grades.length}',
                ),
                _buildDetailRow(
                  'Classes needing setup',
                  uncoveredClasses <= 0 ? '0' : '$uncoveredClasses',
                ),
                _buildDetailRow(
                  'Pending concession requests',
                  '${_concessionRequests.where((c) => '${c['status'] ?? 'pending'}'.toLowerCase() == 'pending').length}',
                ),
              ],
            ),
          ),
          if (classTotals.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Class-wise Outstanding',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...classTotals.entries.map(
              (entry) => _buildClassOutstandingRow(entry.key, entry.value),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Due Alerts',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_studentFees
              .where((s) => _statusForInvoice(s) == 'overdue')
              .isEmpty)
            const EmptyStateWidget(
              icon: Icons.check_circle_outline_rounded,
              title: 'No overdue invoices',
              description:
                  'Outstanding alerts will appear here from backend invoices.',
            )
          else
            ..._studentFees
                .where((s) => _statusForInvoice(s) == 'overdue')
                .map((s) => _buildDueAlert(s)),
        ],
      ),
    );
  }

  Widget _buildClassOutstandingRow(String className, double amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              className,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            _money(amount),
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: amount > 0 ? AppTheme.warning : AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
        ),
      ],
    );
  }

  Widget _buildDueAlert(Map<String, dynamic> s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: AppTheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_studentName(s)} — ${_studentClass(s)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Pending: ${_money(_numValue(s['balance']))} · Due: ${'${s['due_date'] ?? ''}'.split('T').first}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showFeeDetail(s),
            child: Text(
              'View',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentFeesTab() {
    final classes = _classFilters;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.surface,
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search student name...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: classes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => _buildClassFilterChip(classes[i]),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredStudents.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No records found',
                  description: 'Try adjusting your search or filter',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredStudents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _buildStudentFeeCard(_filteredStudents[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildClassFilterChip(String classValue) {
    final selected = _selectedClass == classValue;
    final label = classValue == 'All' ? 'All Classes' : classValue;

    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: selected,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      checkmarkColor: AppTheme.onPrimary,
      side: BorderSide(
        color: selected ? AppTheme.primary : AppTheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? AppTheme.onPrimary : AppTheme.onSurfaceVariant,
      ),
      onSelected: (_) => setState(() => _selectedClass = classValue),
    );
  }

  Widget _buildStudentFeeCard(Map<String, dynamic> s) {
    Color statusColor;
    String statusLabel;
    switch (_statusForInvoice(s)) {
      case 'paid':
        statusColor = AppTheme.success;
        statusLabel = 'Paid';
        break;
      case 'pending':
        statusColor = AppTheme.warning;
        statusLabel = 'Pending';
        break;
      case 'overdue':
        statusColor = AppTheme.error;
        statusLabel = 'Overdue';
        break;
      default:
        statusColor = Colors.red.shade900;
        statusLabel = 'Defaulter';
    }

    return GestureDetector(
      onTap: () => _showFeeDetail(s),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _studentName(s).substring(0, 1),
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _studentName(s),
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_studentClass(s)} · ID: ${_studentRoll(s)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Paid: ${_money(_numValue(s['paid_amount']))}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_numValue(s['balance']) > 0)
                        Text(
                          'Due: ${_money(_numValue(s['balance']))}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusLabel,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeStructureTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class-wise Fee Structure',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Review backend fee rows by class, academic year, and category.',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Chip(label: Text('Admin managed')),
          ],
        ),
        const SizedBox(height: 16),
        if (_feeStructures.isEmpty)
          const EmptyStateWidget(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No fee structures configured',
            description:
                'Admin-created class-wise fee structures will appear here.',
          )
        else
          ..._feeStructures.map((f) => _buildFeeStructureCard(f)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.infoContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.info.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppTheme.info,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Fee Notes',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildNote('Fee policy notes are loaded from backend settings.'),
              _buildNote(
                'If no notes appear here, configure fee rules in the backend before sharing them with parents.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNote(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: AppTheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildFeeStructureCard(Map<String, dynamic> f) {
    final amount = _numValue(f['amount']);
    final dueDay = f['due_day'] ?? '-';
    final lateFine = _numValue(f['late_fine_per_day']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _structureClass(f),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_structureCategory(f)} · ${_structureYear(f)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _money(amount),
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFeeItem('Frequency', _structureFrequency(f)),
              ),
              Expanded(child: _buildFeeItem('Due Day', '$dueDay')),
              Expanded(child: _buildFeeItem('Late Fine', _money(lateFine))),
            ],
          ),
          const SizedBox(height: 12),
          _buildPrincipalReadOnlyNotice(
            'Fee structure setup is admin-managed. Principal can monitor coverage and request corrections through the school finance workflow.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeeItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.muted),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPrincipalReadOnlyNotice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.infoContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.info.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPrincipalReadOnlyNotice(
          'Payment recording and receipt generation are admin-managed. Principal can review the same backend payment history here for finance oversight.',
        ),
        const SizedBox(height: 12),
        if (_recentPayments.isEmpty)
          const EmptyStateWidget(
            icon: Icons.payments_outlined,
            title: 'No payments recorded',
            description: 'Admin-recorded payment receipts will appear here.',
          )
        else
          ..._recentPayments.map(_buildPaymentHistoryCard),
      ],
    );
  }

  Widget _buildPaymentHistoryCard(Map<String, dynamic> payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.successContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 20,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _textValue(payment['name'], fallback: 'Student'),
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${payment['class']} · ${payment['date']} · ${payment['mode']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Receipt: ${_textValue(payment['receipt'], fallback: '-')}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _money(_numValue(payment['amount'])),
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConcessionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Concession Requests',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Chip(label: Text('Principal decision record')),
          ],
        ),
        const SizedBox(height: 12),
        if (_concessionRequests.isEmpty)
          const EmptyStateWidget(
            icon: Icons.discount_outlined,
            title: 'No concession requests',
            description: 'Fee concession approvals will appear here.',
          )
        else
          ..._concessionRequests.map((c) => _buildConcessionCard(c)),
      ],
    );
  }

  Widget _buildConcessionCard(Map<String, dynamic> c) {
    final status = _concessionStatus(c);
    final isPending = status == 'pending';
    final approved = status == 'approved';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _concessionStudent(c),
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPending
                      ? AppTheme.warningContainer
                      : approved
                      ? AppTheme.successContainer
                      : AppTheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPending
                      ? 'Pending'
                      : approved
                      ? 'Approved'
                      : 'Rejected',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPending
                        ? AppTheme.warning
                        : approved
                        ? AppTheme.success
                        : AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_concessionClass(c)} · ${_concessionType(c)}',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(height: 6),
          Text(
            _concessionReason(c),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submitted: ${_concessionDate(c).isEmpty ? '-' : _concessionDate(c)}',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
          ),
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleConcession(c, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleConcession(c, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(fontSize: 11, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
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

  void _showFeeDetail(Map<String, dynamic> s) {
    final pending = _numValue(s['balance']);
    final student = _mapValue(s['student']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _studentName(s),
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_studentClass(s)} · ID: ${_studentRoll(s)}',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                'Student Code',
                '${student['student_code'] ?? '-'}',
              ),
              _buildDetailRow(
                'Invoice Number',
                '${s['invoice_number'] ?? '-'}',
              ),
              _buildDetailRow(
                'Total Fee',
                _money(_numValue(s['net_amount'] ?? s['total_amount'])),
              ),
              _buildDetailRow(
                'Amount Paid',
                _money(_numValue(s['paid_amount'])),
              ),
              _buildDetailRow('Amount Pending', _money(pending)),
              _buildDetailRow(
                'Due Date',
                '${s['due_date'] ?? ''}'.split('T').first,
              ),
              _buildDetailRow('Status', _statusForInvoice(s).toUpperCase()),
              _buildDetailRow(
                'Last Payment',
                _textValue(s['lastPaid'], fallback: 'No payment'),
              ),
              if (_textValue(s['receipt']).isNotEmpty)
                _buildDetailRow('Receipt', _textValue(s['receipt'])),
              const SizedBox(height: 20),
              _buildPrincipalReadOnlyNotice(
                pending > 0
                    ? 'Payment recording and fee reminders are admin-managed. Principal can use this view to monitor recovery and follow up with the finance team.'
                    : 'This invoice is fully paid. Principal payment actions remain read-only.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConcession(Map<String, dynamic> c, bool approved) async {
    try {
      await BackendApiClient.instance.updateRaw(
        '/fees/concessions/${c['id']}/decision',
        {'status': approved ? 'approved' : 'rejected'},
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Concession approval saved'
                : 'Concession rejection saved',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Concession decision failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}

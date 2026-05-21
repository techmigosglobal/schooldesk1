import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_components.dart';
import '../../widgets/erp_module_scaffold.dart';
import 'admin_fee_form_screens.dart';

class AdminFeesScreen extends StatefulWidget {
  const AdminFeesScreen({super.key});

  @override
  State<AdminFeesScreen> createState() => _AdminFeesScreenState();
}

class _AdminFeesScreenState extends State<AdminFeesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _feeStructures = [];
  List<Map<String, dynamic>> _pendingDues = [];
  List<Map<String, dynamic>> _recentPayments = [];
  List<Map<String, dynamic>> _feeCategories = [];
  List<AcademicYearModel> _academicYears = [];
  List<GradeModel> _grades = [];
  List<SectionModel> _sections = [];
  List<StudentModel> _students = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = BackendApiClient.instance;
      final feeStructures = await api.getFeeStructures();
      final invoices = await api.getInvoices();
      final feeCategories = await api.getRawList('/fees/categories');
      final academicYears = await api.getAcademicYears();
      final grades = await api.getGrades();
      final sections = await api.getSections();
      final students = await api.getStudents(page: 1, pageSize: 100);
      final normalizedInvoices = invoices.map(_normalizeInvoice).toList();
      if (!mounted) return;
      setState(() {
        _feeStructures = feeStructures.map(_normalizeFeeStructure).toList();
        _feeCategories = feeCategories;
        _academicYears = academicYears;
        _grades = grades;
        _sections = sections;
        _students = students.data;
        _pendingDues = normalizedInvoices
            .where((invoice) => _numValue(invoice['balance']) > 0)
            .toList();
        _recentPayments = invoices.expand(_normalizePayments).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _feeStructures = [
          {'error': e.toString()},
        ],
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Fees',
      subtitle: 'Fee structures, dues, payments, receipts, and reports',
      drawer: AdminDrawer(selectedIndex: 4, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      actions: _toolbarActions(context),
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Fee Structure'),
          Tab(text: 'Pending Dues'),
          Tab(text: 'Payments'),
          Tab(text: 'Reports'),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFeeStructure(),
                _buildPendingDues(),
                _buildPayments(),
                _buildFinanceReports(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _toolbarActions(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    if (compact) {
      return [
        _compactToolbarButton(
          tooltip: 'Refresh finance data',
          icon: Icons.refresh_rounded,
          onPressed: _loadData,
        ),
        _compactToolbarButton(
          tooltip: 'Payment requests',
          icon: Icons.fact_check_rounded,
          onPressed: () => Navigator.pushNamed(
            context,
            AppRoutes.adminPaymentRequests,
          ).then((_) => _loadData()),
        ),
        _compactToolbarButton(
          tooltip: 'New structure',
          icon: Icons.playlist_add_rounded,
          onPressed: _openCreateFeeStructureForm,
        ),
        _compactToolbarButton(
          tooltip: 'Generate invoices',
          icon: Icons.receipt_long_rounded,
          onPressed: _openGenerateInvoiceForm,
        ),
        _compactToolbarButton(
          tooltip: 'Record payment',
          icon: Icons.payments_rounded,
          onPressed: _openRecordPaymentForm,
        ),
      ];
    }

    return [
      IconButton(
        tooltip: 'Refresh finance data',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: _loadData,
      ),
      OutlinedButton.icon(
        onPressed: () => Navigator.pushNamed(
          context,
          AppRoutes.adminPaymentRequests,
        ).then((_) => _loadData()),
        icon: const Icon(Icons.fact_check_rounded, size: 18),
        label: const Text('Payment requests'),
      ),
      OutlinedButton.icon(
        onPressed: _openCreateFeeStructureForm,
        icon: const Icon(Icons.playlist_add_rounded, size: 18),
        label: const Text('New structure'),
      ),
      FilledButton.icon(
        onPressed: _openGenerateInvoiceForm,
        icon: const Icon(Icons.receipt_long_rounded, size: 18),
        label: const Text('Generate invoices'),
      ),
      FilledButton.icon(
        onPressed: _openRecordPaymentForm,
        icon: const Icon(Icons.payments_rounded, size: 18),
        label: const Text('Record payment'),
      ),
    ];
  }

  Widget _compactToolbarButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    );
  }

  Widget _buildSummaryBar() {
    final tokens = Theme.of(context).schoolDesk;
    final collected = _recentPayments.fold<double>(
      0,
      (sum, payment) =>
          sum + _numValue(payment['amount_paid'] ?? payment['amount']),
    );
    final pending = _pendingDues.fold<double>(
      0,
      (sum, invoice) =>
          sum +
          ((invoice['balance'] as num?)?.toDouble() ??
              (invoice['amount'] as num?)?.toDouble() ??
              0),
    );
    final now = DateTime.now();
    final thisMonth = _recentPayments
        .where((payment) {
          final paidAt = DateTime.tryParse('${payment['payment_date'] ?? ''}');
          return paidAt != null &&
              paidAt.year == now.year &&
              paidAt.month == now.month;
        })
        .fold<double>(
          0,
          (sum, payment) =>
              sum + ((payment['amount_paid'] as num?)?.toDouble() ?? 0),
        );
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.md),
      child: SchoolDeskResponsiveGrid(
        minTileWidth: 180,
        mainAxisExtent: 126,
        children: [
          SchoolDeskKpiCard(
            title: 'Collected',
            value: _money(collected),
            subtitle: 'Total paid',
            icon: Icons.check_circle_rounded,
            color: AppTheme.success,
          ),
          SchoolDeskKpiCard(
            title: 'Pending',
            value: _money(pending),
            subtitle: 'Outstanding dues',
            icon: Icons.warning_rounded,
            color: AppTheme.error,
          ),
          SchoolDeskKpiCard(
            title: 'This Month',
            value: _money(thisMonth),
            subtitle: 'Payments received',
            icon: Icons.calendar_month_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

  Map<String, dynamic> _normalizeFeeStructure(Map<String, dynamic> fee) {
    final category = _mapValue(fee['fee_category']);
    final grade = _mapValue(fee['grade']);
    final amount = _numValue(fee['amount']);
    return {
      ...fee,
      'class': _textValue(grade['grade_name'], fallback: fee['grade_id']),
      'year': _textValue(yearLabel(fee), fallback: fee['academic_year_id']),
      'category': _textValue(category['category_name'], fallback: 'Fee'),
      'total': amount,
      'tuition': amount,
      'exam': 0,
      'library': 0,
      'sports': 0,
      'due_day': fee['due_day'] ?? 0,
      'late_fine_per_day': _numValue(fee['late_fine_per_day']),
    };
  }

  Object? yearLabel(Map<String, dynamic> fee) {
    final year = _mapValue(fee['academic_year']);
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
      _textValue(grade['grade_name'], fallback: ''),
      _textValue(section['section_name'], fallback: ''),
    ].where((part) => part.isNotEmpty).join(' ');
    final name = [
      _textValue(student['first_name'], fallback: ''),
      _textValue(student['last_name'], fallback: ''),
    ].where((part) => part.isNotEmpty).join(' ');
    return {
      ...invoice,
      'name': name.isEmpty ? 'Student ${invoice['student_id'] ?? ''}' : name,
      'class': classLabel.isEmpty ? 'Unassigned class' : classLabel,
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

  Widget _buildFeeStructure() {
    if (_feeStructures.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: SchoolDeskStatusPanel.empty(
          title: 'No fee structures',
          message: 'Backend fee structures will appear here once configured.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: _feeStructures.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final f = _feeStructures[i];
        return Container(
          padding: const EdgeInsets.all(12),
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
                      _textValue(f['class'], fallback: 'Unassigned grade'),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _money(_numValue(f['total'])),
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              _buildFeeRow('Category', _textValue(f['category'])),
              _buildFeeRow('Amount', _money(_numValue(f['tuition']))),
              _buildFeeRow('Due Day', '${f['due_day'] ?? 0}'),
              _buildFeeRow(
                'Late Fine / Day',
                _money(_numValue(f['late_fine_per_day'])),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openEditFeeStructureForm(f),
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: Text(
                        'Edit Structure',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openGenerateInvoiceForm(seed: f),
                      icon: const Icon(Icons.receipt_rounded, size: 14),
                      label: Text(
                        'Generate',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingDues() {
    if (_pendingDues.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: SchoolDeskStatusPanel.empty(
          title: 'No pending dues',
          message: 'Outstanding invoices will appear here from backend.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: _pendingDues.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final d = _pendingDues[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (_numValue(d['months']).toInt()) >= 2
                  ? AppTheme.errorContainer
                  : AppTheme.warningContainer,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _textValue(d['name'], fallback: 'Student'),
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_textValue(d['class'], fallback: 'Unassigned class')} • Last paid: ${d['lastPaid']}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(_numValue(d['amount'])),
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.error,
                        ),
                      ),
                      Text(
                        '${_numValue(d['months']).toInt()} month(s)',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sendFeeReminder(d),
                      icon: const Icon(Icons.sms_rounded, size: 14),
                      label: Text(
                        'Send Reminder',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openRecordPaymentForm(invoice: d),
                      icon: const Icon(Icons.payment_rounded, size: 14),
                      label: Text(
                        'Record Payment',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPayments() {
    if (_recentPayments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: SchoolDeskStatusPanel.empty(
          title: 'No payments recorded',
          message: 'Backend payment receipts will appear here.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: _recentPayments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = _recentPayments[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
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
                      p['name'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${p['class']} • ${p['date']} • ${p['mode']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                    Text(
                      'Receipt: ${p['receipt']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${p['amount']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _printReceipt(p),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                    ),
                    child: Text(
                      'Print',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinanceReports() {
    final reports = [
      {
        'label': 'Monthly Collection Report',
        'icon': Icons.calendar_month_rounded,
        'color': AppTheme.primary,
      },
      {
        'label': 'Pending Dues Report',
        'icon': Icons.warning_rounded,
        'color': AppTheme.error,
      },
      {
        'label': 'Class-wise Fee Report',
        'icon': Icons.class_rounded,
        'color': AppTheme.success,
      },
      {
        'label': 'Concession Report',
        'icon': Icons.discount_rounded,
        'color': AppTheme.warning,
      },
      {
        'label': 'Annual Finance Summary',
        'icon': Icons.summarize_rounded,
        'color': Color(0xFF6C3483),
      },
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = reports[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (r['color'] as Color).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  r['icon'] as IconData,
                  size: 20,
                  color: r['color'] as Color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r['label'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => _requestReportExport(r, 'pdf'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    child: Text('PDF', style: GoogleFonts.dmSans(fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _requestReportExport(r, 'csv'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    child: Text('CSV', style: GoogleFonts.dmSans(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCreateFeeStructureForm() => _openFeeStructureForm();

  Future<void> _openEditFeeStructureForm(Map<String, dynamic> structure) =>
      _openFeeStructureForm(structure: structure);

  Future<void> _openFeeStructureForm({Map<String, dynamic>? structure}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminFeeStructureForm,
      arguments: AdminFeeStructureFormArgs(
        academicYears: _academicYears,
        grades: _grades,
        feeCategories: _feeCategories,
        feeStructure: structure,
      ),
    );
    if (!mounted || result is! AdminFeeStructureFormResult) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _openGenerateInvoiceForm({Map<String, dynamic>? seed}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminInvoiceGenerationForm,
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Generated ${result.created} invoice(s), skipped ${result.skipped} existing invoice(s).',
        ),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _openRecordPaymentForm({Map<String, dynamic>? invoice}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminPaymentRecordForm,
      arguments: AdminPaymentRecordFormArgs(
        pendingDues: _pendingDues,
        initialInvoice: invoice,
      ),
    );
    if (!mounted || result is! AdminPaymentRecordFormResult) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment of ${_money(result.amount)} recorded for ${result.studentName}',
        ),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _sendFeeReminder(Map<String, dynamic> due) async {
    final invoiceId = '${due['id'] ?? ''}';
    if (invoiceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backend invoice ID is missing'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    try {
      await BackendApiClient.instance.createRaw('/fees/reminders', {
        'invoice_ids': [invoiceId],
        'message': 'Fee reminder for ${due['name'] ?? 'student'}',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder queued for ${due['name'] ?? 'student'}'),
          backgroundColor: AppTheme.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _requestReportExport(
    Map<String, dynamic> report,
    String format,
  ) async {
    try {
      final export = await BackendApiClient.instance.createReportExport(
        '/fees/reports/exports',
        reportTitle: '${report['label']}',
        format: format,
        scope: 'admin',
        parameters: {'source_screen': 'admin_fees'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${report['label']} export ${export['status'] ?? 'requested'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report export failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _printReceipt(Map<String, dynamic> payment) async {
    try {
      final pdfService = PdfService.getInstance();
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
      final pdfBytes = await pdfService.generateFeeReceipt(
        receiptNo: payment['receipt'] as String? ?? 'RCP001',
        studentName: payment['name'] as String? ?? '',
        className: payment['class'] as String? ?? '',
        rollNo: '01',
        parentName: 'Parent of ${payment['name'] ?? ''}',
        feeItems: [
          {
            'description': 'Tuition Fee',
            'amount': amount * 0.7,
            'status': 'Paid',
          },
          {
            'description': 'Activity Fee',
            'amount': amount * 0.2,
            'status': 'Paid',
          },
          {'description': 'Misc', 'amount': amount * 0.1, 'status': 'Paid'},
        ],
        totalAmount: amount,
        paidAmount: amount,
        balance: 0,
        paymentMode: payment['mode'] as String? ?? 'Cash',
        paymentDate: DateTime.now(),
      );
      if (!mounted) return;
      await pdfService.previewDocument(
        context,
        pdfBytes,
        'Receipt ${payment['receipt'] ?? 'RCP'}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate receipt.')),
        );
      }
    }
  }
}

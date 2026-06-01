import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/operations_workspace.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart';

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
      final invoices = await api.getInvoices();
      final feeCategories = await api.getRawList('/fees/categories');
      final concessions = await api.getRawList('/fees/concessions');
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
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      actions: [
        IconButton(
          tooltip: 'Create fee structure',
          icon: const Icon(Icons.add_card_outlined),
          onPressed: _openCreateFeeStructureForm,
        ),
        IconButton(
          tooltip: 'Generate invoices',
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
        _buildCurrentView(),
      ],
    );
  }

  Widget _buildViewPicker() {
    return OpsPanel(
      title: 'Admin Finance Workspace',
      subtitle:
          'Admin owns operational writes; Principal can monitor and decide requests',
      trailing: TextButton.icon(
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.adminPaymentRequests),
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
        label: const Text('Create'),
      ),
      child: _feeStructures.isEmpty
          ? OpsEmptyState(
              icon: Icons.price_change_outlined,
              title: 'No fee structures',
              message: 'Create structures before generating student invoices.',
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
                    trailing: TextButton.icon(
                      onPressed: () => _openEditFeeStructureForm(structure),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
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
        label: const Text('Generate'),
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
                          tooltip: 'Record payment',
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
    return OpsPanel(
      title: 'Payments And Receipts',
      subtitle:
          'Recorded payments and receipt preview stay tied to backend invoices',
      trailing: OutlinedButton.icon(
        onPressed: () => _openRecordPaymentForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record payment'),
      ),
      child: _recentPayments.isEmpty
          ? OpsEmptyState(
              icon: Icons.payments_outlined,
              title: 'No payments yet',
              message:
                  'Payments will appear after Admin records them against invoices.',
            )
          : Column(
              children: [
                for (final payment in _recentPayments.take(20))
                  OpsListRow(
                    icon: Icons.payments_outlined,
                    title: _textValue(payment['name'], fallback: 'Payment'),
                    subtitle:
                        '${_textValue(payment['mode'], fallback: 'Mode pending')} | ${_dateLabel(payment['date'])} | ${_textValue(payment['receipt'], fallback: 'Receipt pending')}',
                    trailing: TextButton.icon(
                      onPressed: () => _previewReceipt(payment),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(_money(_numValue(payment['amount']))),
                    ),
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
                  'Create ${report.$3.toUpperCase()} export through /fees/reports/exports',
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
    _snack(result.message, success: true);
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
    _snack(
      'Generated ${result.created} invoice(s), skipped ${result.skipped}.',
      success: true,
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
    _snack(
      'Payment of ${_money(result.amount)} recorded for ${result.studentName}',
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
        },
      );
      _snack('Report export queued', success: true);
    } catch (error) {
      _snack('Unable to queue report export: $error');
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
      'frequency': _textValue(fee['frequency'], fallback: 'term'),
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
        backgroundColor: success ? AppTheme.success : AppTheme.error,
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
}

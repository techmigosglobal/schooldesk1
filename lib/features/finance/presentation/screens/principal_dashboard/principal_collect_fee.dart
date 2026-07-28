import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';

// ── Payment Modes ────────────────────────────────────────────────────────────

enum _PaymentMode { cash, other }

extension on _PaymentMode {
  String get label => switch (this) {
    _PaymentMode.cash => 'Cash',
    _PaymentMode.other => 'Others',
  };
  IconData get icon => switch (this) {
    _PaymentMode.cash => Icons.payments_outlined,
    _PaymentMode.other => Icons.more_horiz_rounded,
  };
  Color get color => switch (this) {
    _PaymentMode.cash => const Color(0xFF16A34A),
    _PaymentMode.other => const Color(0xFF6366F1),
  };
}

// ── Fee-type visual metadata ─────────────────────────────────────────────────

class _FeeTypeBadge {
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;
  const _FeeTypeBadge({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
  });
}

_FeeTypeBadge _feeTypeBadge(Map<String, dynamic> inv) {
  final raw = '${textValue(inv['fee_item_name'])} ${textValue(inv['fee_type'])}'
      .toLowerCase();
  if (raw.contains('book')) {
    return const _FeeTypeBadge(
      label: 'Books Fee',
      color: Color(0xFF1D4ED8),
      bg: Color(0xFFDBEAFE),
      icon: Icons.menu_book_rounded,
    );
  }
  if (raw.contains('kit') || raw.contains('uniform')) {
    return const _FeeTypeBadge(
      label: 'Kit Fee',
      color: Color(0xFF92400E),
      bg: Color(0xFFFEF3C7),
      icon: Icons.backpack_rounded,
    );
  }
  if (raw.contains('tuition') || raw.contains('monthly')) {
    return const _FeeTypeBadge(
      label: 'Tuition Fee',
      color: Color(0xFF1A6B4A),
      bg: Color(0xFFDCFCE7),
      icon: Icons.school_rounded,
    );
  }
  return const _FeeTypeBadge(
    label: 'Fee',
    color: Color(0xFF7C3AED),
    bg: Color(0xFFF5F3FF),
    icon: Icons.receipt_outlined,
  );
}

// ── Screen ───────────────────────────────────────────────────────────────────

class PrincipalCollectFee extends StatefulWidget {
  const PrincipalCollectFee({super.key});

  @override
  State<PrincipalCollectFee> createState() => _PrincipalCollectFeeState();
}

class _PrincipalCollectFeeState extends State<PrincipalCollectFee> {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _amountController = TextEditingController();
  final _transactionController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchCtrl = TextEditingController();

  // ── State ────────────────────────────────────────────────────────────────
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // ── Selection (stepped flow) ─────────────────────────────────────────────
  String _selectedSectionLabel = '';
  String _selectedStudentId = '';
  String _selectedInvoiceId = '';
  String _query = '';

  // ── Payment form ─────────────────────────────────────────────────────────
  _PaymentMode _paymentMode = _PaymentMode.cash;
  DateTime _paymentDate = DateTime.now();

  // ── Data ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _invoices = const [];

  // ── Computed: Due invoices ───────────────────────────────────────────────

  List<Map<String, dynamic>> get _dueInvoices =>
      _invoices.where((inv) => numValue(inv['balance']) > 0).toList();

  // Unique class/section labels derived from invoices.
  List<Map<String, dynamic>> get _classSections {
    final Set<String> seen = {};
    final List<Map<String, dynamic>> result = [];
    for (final inv in _dueInvoices) {
      final label = '${inv['class'] ?? ''}'.trim();
      if (label.isEmpty || seen.contains(label)) continue;
      seen.add(label);
      result.add({'label': label});
    }
    result.sort((a, b) => '${a['label']}'.compareTo('${b['label']}'));
    return result;
  }

  double get _totalOutstanding =>
      _dueInvoices.fold(0, (sum, inv) => sum + numValue(inv['balance']));

  // Invoices in the selected section.
  List<Map<String, dynamic>> get _sectionInvoices {
    if (_selectedSectionLabel.isEmpty) return [];
    return _dueInvoices
        .where((inv) => '${inv['class']}' == _selectedSectionLabel)
        .toList();
  }

  double get _sectionOutstanding =>
      _sectionInvoices.fold(0, (sum, inv) => sum + numValue(inv['balance']));

  // Students with dues in the selected section, grouped by student_id.
  List<Map<String, dynamic>> get _sectionStudents {
    final Map<String, Map<String, dynamic>> students = {};
    for (final inv in _sectionInvoices) {
      final sid = '${inv['student_id']}'.trim();
      if (sid.isEmpty) continue;
      if (!students.containsKey(sid)) {
        students[sid] = {
          'student_id': sid,
          'name': inv['name'] ?? 'Student',
          'class': inv['class'] ?? '',
          'total_due': numValue(inv['balance']),
          'invoice_count': 1,
        };
      } else {
        students[sid]!['total_due'] =
            (students[sid]!['total_due'] as double) + numValue(inv['balance']);
        students[sid]!['invoice_count'] =
            (students[sid]!['invoice_count'] as int) + 1;
      }
    }
    final list = students.values.toList();
    list.sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    return list;
  }

  List<Map<String, dynamic>> get _filteredStudents {
    final students = _sectionStudents;
    if (_query.isEmpty) return students;
    return students
        .where(
          (s) => '${s['name']}'.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
  }

  // Invoices for the selected student.
  List<Map<String, dynamic>> get _studentInvoices {
    if (_selectedStudentId.isEmpty) return [];
    return _sectionInvoices
        .where((inv) => '${inv['student_id']}' == _selectedStudentId)
        .toList();
  }

  String get _selectedStudentName {
    final student = _sectionStudents.firstWhereOrNull(
      (s) => '${s['student_id']}' == _selectedStudentId,
    );
    return '${student?['name'] ?? 'Student'}';
  }

  // The specific invoice selected for payment.
  Map<String, dynamic>? get _selectedInvoice {
    if (_selectedInvoiceId.isEmpty) return null;
    return _studentInvoices.firstWhereOrNull(
      (inv) => '${inv['id']}' == _selectedInvoiceId,
    );
  }

  // ── Current step for the progress indicator ──────────────────────────────

  int get _currentStep {
    if (_selectedInvoiceId.isNotEmpty) return 3;
    if (_selectedStudentId.isNotEmpty) return 2;
    if (_selectedSectionLabel.isNotEmpty) return 1;
    return 0;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionController.dispose();
    _notesController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final raw = await api.getInvoices(pageSize: 1000);
      if (!mounted) return;
      setState(() {
        _invoices = raw.map(normalizeInvoice).toList();
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // ── Navigation helpers ───────────────────────────────────────────────────

  void _backToStudents() {
    setState(() {
      _selectedStudentId = '';
      _selectedInvoiceId = '';
      _amountController.clear();
    });
  }

  void _backToSections() {
    setState(() {
      _selectedSectionLabel = '';
      _selectedStudentId = '';
      _selectedInvoiceId = '';
      _amountController.clear();
      _searchCtrl.clear();
      _query = '';
    });
  }

  void _backToFeeTypes() {
    setState(() {
      _selectedInvoiceId = '';
      _amountController.clear();
    });
  }

  /// Keeps every back affordance inside the collection wizard until the
  /// section picker is reached.  Popping the route from a later step loses
  /// the selected student/section and makes the flow feel broken.
  void _handleWizardBack() {
    if (_saving) return;
    if (_selectedInvoiceId.isNotEmpty) {
      _backToFeeTypes();
      return;
    }
    if (_selectedStudentId.isNotEmpty) {
      _backToStudents();
      return;
    }
    if (_selectedSectionLabel.isNotEmpty) {
      _backToSections();
      return;
    }
    Navigator.of(context).maybePop();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0 && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleWizardBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FDF4),
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleWizardBack,
          ),
          title: Text(
            'Record Payment',
            style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1A6B4A),
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _saving ? null : _loadData,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorState()
            : _dueInvoices.isEmpty
            ? _buildEmptyState()
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildProgressIndicator(),
        const Divider(height: 1),
        Expanded(
          child: _selectedInvoice != null
              ? _buildPaymentForm()
              : _selectedStudentId.isNotEmpty
              ? _buildFeeTypeSelector()
              : _selectedSectionLabel.isNotEmpty
              ? _buildStudentPicker()
              : _buildClassSectionSelector(),
        ),
      ],
    );
  }

  // ── Progress Indicator ───────────────────────────────────────────────────

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Row(
        children: [
          _buildStep(0, 'Section'),
          _buildStepConnector(0),
          _buildStep(1, 'Student'),
          _buildStepConnector(1),
          _buildStep(2, 'Fee Type'),
          _buildStepConnector(2),
          _buildStep(3, 'Payment'),
        ],
      ),
    );
  }

  Widget _buildStep(int index, String label) {
    final isActive = index == _currentStep;
    final isCompleted = index < _currentStep;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? const Color(0xFF1A6B4A)
                : isActive
                ? const Color(0xFF1A6B4A).withOpacity(0.15)
                : Colors.grey.shade100,
            border: Border.all(
              color: isActive || isCompleted
                  ? const Color(0xFF1A6B4A)
                  : Colors.grey.shade300,
              width: isActive ? 2 : 1.5,
            ),
          ),
          child: isCompleted
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? const Color(0xFF1A6B4A) : Colors.grey,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive || isCompleted
                ? const Color(0xFF1A6B4A)
                : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(int afterStep) {
    final isCompleted = afterStep < _currentStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFF1A6B4A) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  // ── Error / Empty States ─────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_error',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                color: context.appTheme.muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A6B4A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 64,
              color: const Color(0xFF1A6B4A).withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'All Clear!',
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: const Color(0xFF1A6B4A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no outstanding dues to collect.',
              style: GoogleFonts.ibmPlexSans(
                color: context.appTheme.muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1: Class/Section Selector
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildClassSectionSelector() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A6B4A), Color(0xFF2F9B6F)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.class_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Class & Section',
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${_classSections.length} sections with outstanding dues',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Summary stats
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _miniStat(
                '${_dueInvoices.length}',
                'Outstanding',
                const Color(0xFFF59E0B),
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.grey.shade200,
              ),
              _miniStat(
                money(_totalOutstanding),
                'Total Due',
                Colors.orange.shade700,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section list
        Text(
          'Available Sections',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: context.appTheme.muted,
          ),
        ),
        const SizedBox(height: 10),
        for (final section in _classSections) _buildSectionCard(section),
      ],
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11,
              color: context.appTheme.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> section) {
    final label = '${section['label']}';
    final sectionInvoices = _dueInvoices
        .where((inv) => '${inv['class']}' == label)
        .toList();
    final studentCount = sectionInvoices
        .map((inv) => '${inv['student_id']}')
        .toSet()
        .length;
    final totalDue = sectionInvoices.fold<double>(
      0,
      (sum, inv) => sum + numValue(inv['balance']),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1FAE5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _selectedSectionLabel = label;
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A6B4A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Color(0xFF1A6B4A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.ibmPlexSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$studentCount student${studentCount == 1 ? '' : 's'} with dues',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          color: context.appTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(totalDue),
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Outstanding',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 10,
                        color: context.appTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.appTheme.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2: Student Picker
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStudentPicker() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Selected section banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A6B4A), Color(0xFF2F9B6F)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedSectionLabel,
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${_sectionStudents.length} students · ${money(_sectionOutstanding)} due',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _backToSections,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text(
                  'Change',
                  style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search
        TextFormField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search student name...',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF1A6B4A),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 16),

        // Student list
        if (_filteredStudents.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.person_off_rounded,
                    size: 48,
                    color: const Color(0xFF1A6B4A).withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No students found',
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.bold,
                      color: context.appTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        for (final student in _filteredStudents) _buildStudentCard(student),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _backToSections,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A6B4A),
              side: const BorderSide(color: Color(0xFF1A6B4A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(
              'Back to Sections',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final invoiceCount = student['invoice_count'] as int;
    final totalDue = student['total_due'] as double;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() {
            _selectedStudentId = '${student['student_id']}';
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${student['name']}',
                        style: GoogleFonts.ibmPlexSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$invoiceCount invoice${invoiceCount == 1 ? '' : 's'}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          color: context.appTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(totalDue),
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Outstanding',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 10,
                        color: context.appTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.appTheme.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3: Fee Type Selector
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFeeTypeSelector() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Student summary header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                child: const Icon(Icons.person_rounded, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedStudentName,
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _selectedSectionLabel,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _backToStudents,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text(
                  'Change',
                  style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Select Fee Type',
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: context.appTheme.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose which fee to record a payment for',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            color: context.appTheme.muted,
          ),
        ),
        const SizedBox(height: 12),

        // Fee type cards
        if (_studentInvoices.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 48,
                    color: const Color(0xFF1A6B4A).withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No outstanding invoices',
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.bold,
                      color: context.appTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All fees for this student are paid.',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      color: context.appTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final inv in _studentInvoices) _buildFeeTypeCard(inv),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _backToStudents,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A6B4A),
              side: const BorderSide(color: Color(0xFF1A6B4A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: Text(
              'Back to Students',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeeTypeCard(Map<String, dynamic> inv) {
    final badge = _feeTypeBadge(inv);
    final balance = numValue(inv['balance']);
    final total = numValue(inv['total']);
    final paid = numValue(inv['paid']);
    final isPartial = paid > 0 && balance > 0;

    // Determine fee type category for display
    final feeTypeRaw =
        '${textValue(inv['fee_item_name'])} ${textValue(inv['fee_type'])}'
            .toLowerCase();
    final isBooksKit =
        feeTypeRaw.contains('book') ||
        feeTypeRaw.contains('kit') ||
        feeTypeRaw.contains('uniform');
    final isFullyPaid = balance <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isFullyPaid
            ? Border.all(color: const Color(0xFFD1FAE5), width: 1.5)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: isFullyPaid
                ? Colors.black.withOpacity(0.02)
                : Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isFullyPaid
              ? null
              : () {
                  setState(() {
                    _selectedInvoiceId = '${inv['id']}';
                    _amountController.text = numValue(
                      inv['balance'],
                    ).toStringAsFixed(2);
                  });
                },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: badge.bg,
                      child: Icon(badge.icon, color: badge.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badge.label,
                            style: GoogleFonts.ibmPlexSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Total: ${money(total)}',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 12,
                              color: context.appTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isFullyPaid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Paid',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        money(balance),
                        style: GoogleFonts.ibmPlexSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange.shade700,
                        ),
                      ),
                  ],
                ),
                if (isFullyPaid) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isBooksKit
                          ? 'Books & Kit fee is already paid. No action needed.'
                          : 'This fee is already fully paid.',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: const Color(0xFF1A6B4A),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isPartial
                          ? const Color(0xFFF59E0B).withOpacity(0.08)
                          : const Color(0xFF2563EB).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPartial
                              ? Icons.info_outline_rounded
                              : Icons.arrow_forward_rounded,
                          size: 14,
                          color: isPartial
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isPartial
                                ? 'Partially paid · ₹${paid.toStringAsFixed(0)} paid · Select to pay ₹${balance.toStringAsFixed(0)} balance'
                                : 'Select to record payment of ${money(balance)}',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isPartial
                                  ? const Color(0xFF92400E)
                                  : const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4: Payment Form
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPaymentForm() {
    final inv = _selectedInvoice!;
    final badge = _feeTypeBadge(inv);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Student summary header — gradient card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [badge.color, badge.color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                child: const Icon(Icons.person_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedStudentName,
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$_selectedSectionLabel · ${badge.label}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badge.icon, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            badge.label,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _backToFeeTypes,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Change'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Fee breakdown
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice Summary',
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _detailRow('Total Invoiced', money(numValue(inv['total']))),
              const Divider(height: 16),
              _detailRow(
                'Total Paid',
                money(numValue(inv['paid'])),
                isSuccess: true,
              ),
              const Divider(height: 16),
              _detailRow(
                'Balance Due',
                money(numValue(inv['balance'])),
                isDanger: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5EE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFB8E0C7)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF1A6B4A),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Record any amount up to the current balance. Previous month allocations remain available only in receipt history.',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    height: 1.35,
                    color: const Color(0xFF14532D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Amount
        _sectionHeader(
          'Payment Amount',
          icon: Icons.currency_rupee_rounded,
          color: Colors.orange.shade700,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText: 'Amount to Record',
            helperText: 'Maximum ${money(numValue(inv['balance']))}',
            prefixText: '₹ ',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
            ),
          ),
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 20),

        // Payment method
        _sectionHeader(
          'Payment Method',
          icon: Icons.payments_rounded,
          color: const Color(0xFF6366F1),
        ),
        const SizedBox(height: 10),
        Row(
          children: _PaymentMode.values.map((mode) {
            final selected = _paymentMode == mode;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _paymentMode = mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? mode.color : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? mode.color : const Color(0xFFE5E7EB),
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: mode.color.withOpacity(0.25),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          mode.icon,
                          size: 22,
                          color: selected ? Colors.white : mode.color,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          mode.label,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : mode.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Reference number
        TextFormField(
          controller: _transactionController,
          decoration: InputDecoration(
            labelText: 'Reference / Receipt No (Optional)',
            prefixIcon: const Icon(Icons.tag_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Date picker
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Payment Date',
              prefixIcon: const Icon(Icons.calendar_month_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(_paymentDate),
                  style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Notes
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'Administrative Notes (Optional)',
            prefixIcon: const Icon(Icons.notes_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
            ),
          ),
          maxLines: 2,
        ),

        const SizedBox(height: 32),

        // Submit
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : _confirmPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6B4A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Record Payment',
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _backToFeeTypes,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A6B4A),
              side: const BorderSide(color: Color(0xFF1A6B4A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Back to Fee Types',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(
    String title, {
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: context.appTheme.muted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    String label,
    String val, {
    bool isDanger = false,
    bool isSuccess = false,
  }) {
    final color = isDanger
        ? Colors.orange.shade700
        : isSuccess
        ? const Color(0xFF1A6B4A)
        : context.appTheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            color: context.appTheme.muted,
            fontSize: 13,
          ),
        ),
        Text(
          val,
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _confirmPayment() async {
    final inv = _selectedInvoice;
    if (inv == null) return;
    final amount =
        double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid positive payment amount.'),
        ),
      );
      return;
    }
    final balance = numValue(inv['balance']);
    if (amount > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment cannot be more than the remaining ${money(balance)}.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.recordPayment(
        PaymentRequest(
          invoiceId: inv['id'],
          receiptNumber:
              'RCP-${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}',
          amountPaid: amount,
          paymentDate: DateFormat('yyyy-MM-dd').format(_paymentDate),
          paymentMode: _paymentMode.label.toLowerCase(),
          transactionId: _transactionController.text.trim().isEmpty
              ? null
              : _transactionController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF1A6B4A)),
              SizedBox(width: 8),
              Text('Payment Recorded'),
            ],
          ),
          content: Text(
            'Successfully recorded ₹${amount.toStringAsFixed(0)} payment for $_selectedStudentName.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A6B4A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      // Navigate back to student list
      setState(() {
        _selectedStudentId = '';
        _selectedInvoiceId = '';
      });
      _amountController.clear();
      _transactionController.clear();
      _notesController.clear();
      await _loadData();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record: $e'),
          backgroundColor: context.appTheme.error,
        ),
      );
    }
  }
}

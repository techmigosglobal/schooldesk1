import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';

class PrincipalReports extends StatefulWidget {
  const PrincipalReports({super.key});

  @override
  State<PrincipalReports> createState() => _PrincipalReportsState();
}

class _PrincipalReportsState extends State<PrincipalReports> {
  bool _loading = true;
  bool _generatingPdf = false;
  String? _error;
  List<Map<String, dynamic>> _invoices = const [];
  List<Map<String, dynamic>> _payments = const [];
  List<Map<String, dynamic>> _structures = const [];
  Map<String, dynamic> _school = const {};

  static const _serverReports = [
    _ReportDef(
      'Collection Summary',
      'Overall collection summary',
      'fee_collection_summary',
      Icons.summarize_outlined,
      Color(0xFF7C3AED),
    ),
    _ReportDef(
      'Class Wise Collection',
      'Collection by class/section',
      'fee_class_collection',
      Icons.assignment_outlined,
      Color(0xFF2563EB),
    ),
    _ReportDef(
      'Outstanding Report',
      'All pending dues',
      'fee_outstanding_report',
      Icons.pending_actions_outlined,
      Color(0xFFF97316),
    ),
    _ReportDef(
      'Daily Collection Report',
      'Day wise collection',
      'fee_daily_collection',
      Icons.payments_outlined,
      Color(0xFF16A34A),
    ),
  ];

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
      final results = await Future.wait<Object>([
        api.getInvoices(pageSize: 1000),
        api.getFeeStructures(),
        api.getCurrentSchool(),
      ]);
      final rawInvoices = (results[0] as List).cast<Map<String, dynamic>>();
      final allPayments = rawInvoices.expand(normalizePayments).toList();
      if (!mounted) return;
      setState(() {
        _invoices = rawInvoices.map(normalizeInvoice).toList();
        _payments = allPayments.cast<Map<String, dynamic>>();
        _structures = (results[1] as List)
            .cast<Map<String, dynamic>>()
            .map(normalizeFeeStructure)
            .toList();
        _school = Map<String, dynamic>.from(results[2] as Map);
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

  Future<Uint8List?> _networkImageBytes(String url) async {
    if (url.isEmpty) return null;
    try {
      return (await NetworkAssetBundle(
        Uri.parse(url),
      ).load(url)).buffer.asUint8List();
    } on Object catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _schoolLogoBytes() =>
      _networkImageBytes(textValue(_school['logo_url']));

  Future<Uint8List?> _schoolSignatureBytes() =>
      _networkImageBytes(textValue(_school['authorized_signature_url']));

  String get _schoolName => textValue(_school['name'], fallback: 'School');
  String get _schoolAddress => [
    _school['address'],
    _school['address_line1'],
    _school['address_line2'],
    _school['city'],
    _school['state'],
    _school['postal_code'],
  ].map(textValue).where((value) => value.isNotEmpty).toSet().join(', ');

  double get _totalExpected =>
      _invoices.fold<double>(0, (s, i) => s + numValue(i['total']));
  double get _totalCollected =>
      _payments.fold<double>(0, (s, p) => s + numValue(p['amount']));
  double get _totalDue =>
      _invoices.fold<double>(0, (s, i) => s + numValue(i['balance']));
  double get _collectionRate =>
      _totalExpected > 0 ? _totalCollected / _totalExpected : 0;

  List<Map<String, dynamic>> get _studentAccounts {
    final grouped = <String, Map<String, dynamic>>{};
    for (final invoice in _invoices) {
      final studentId = textValue(invoice['student_id']);
      final key = studentId.isNotEmpty
          ? studentId
          : '${textValue(invoice['name'])}|${textValue(invoice['class'])}';
      final account = grouped.putIfAbsent(
        key,
        () => <String, dynamic>{
          ...invoice,
          'student_id': studentId,
          'total': 0.0,
          'paid': 0.0,
          'balance': 0.0,
          'invoices': <Map<String, dynamic>>[],
          'components': <String>[],
        },
      );
      account['total'] =
          numValue(account['total']) + numValue(invoice['total']);
      account['paid'] = numValue(account['paid']) + numValue(invoice['paid']);
      account['balance'] =
          numValue(account['balance']) + numValue(invoice['balance']);
      (account['invoices'] as List<Map<String, dynamic>>).add(invoice);
      final component = _componentName(invoice);
      final components = account['components'] as List<String>;
      if (!components.contains(component)) components.add(component);
    }
    return grouped.values.toList()..sort(
      (left, right) => textValue(
        left['name'],
      ).toLowerCase().compareTo(textValue(right['name']).toLowerCase()),
    );
  }

  String _componentName(Map<String, dynamic> invoice) {
    final name = textValue(
      invoice['fee_item_name'] ?? invoice['category_name'],
    );
    if (name.isNotEmpty) return name;
    final feeType = textValue(invoice['fee_type']).toLowerCase();
    return feeType.contains('tuition') ? 'Tuition' : 'Books & Kit';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Fee Reports',
          style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error: $_error'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Live summary card
                  _buildSummaryCard(),
                  const SizedBox(height: 20),

                  // Individual student report (NEW)
                  _buildStudentReportCard(),
                  const SizedBox(height: 20),

                  // Server exports
                  Text(
                    'Export Reports',
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._serverReports.map(
                    (report) => _buildServerReportCard(report),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Live Summary Card ─────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9F67FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Live Collection Summary',
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _kpiColumn('Expected', '₹${_totalExpected.toStringAsFixed(0)}'),
              _divider(),
              _kpiColumn(
                'Collected',
                '₹${_totalCollected.toStringAsFixed(0)}',
                color: Colors.greenAccent,
              ),
              _divider(),
              _kpiColumn(
                'Outstanding',
                '₹${_totalDue.toStringAsFixed(0)}',
                color: Colors.orangeAccent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _kpiColumn('Templates', '${_structures.length}'),
              _divider(),
              _kpiColumn('Invoices', '${_invoices.length}'),
              _divider(),
              _kpiColumn(
                'Rate',
                '${(_collectionRate * 100).toStringAsFixed(0)}%',
                color: Colors.greenAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generatingPdf ? null : _generatePdf,
              icon: _generatingPdf
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Download PDF Summary Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiColumn(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(height: 28, width: 1, color: Colors.white24);

  // ── Individual Student Report Card ────────────────────────────────────────

  Widget _buildStudentReportCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Individual Student Report',
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Generate a detailed fee report for a specific student',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        color: context.appTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _invoices.isEmpty ? null : _showStudentReportPicker,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Select Student & Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentReportPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StudentReportPickerSheet(
        invoices: _studentAccounts,
        payments: _payments,
        onGenerate: (inv) {
          Navigator.pop(ctx);
          _generateStudentPdf(inv);
        },
      ),
    );
  }

  Future<void> _generateStudentPdf(Map<String, dynamic> inv) async {
    setState(() => _generatingPdf = true);
    try {
      final accountInvoices = inv['invoices'] is List
          ? (inv['invoices'] as List)
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : <Map<String, dynamic>>[inv];
      final items = accountInvoices
          .map(
            (invoice) => <String, dynamic>{
              'description': _componentName(invoice),
              'amount': numValue(invoice['total']),
              'status': numValue(invoice['balance']) > 0
                  ? 'Paid ${money(numValue(invoice['paid']))} · Due ${money(numValue(invoice['balance']))}'
                  : 'Cleared',
            },
          )
          .toList();

      // Add paid months detail for tuition
      final paidMonths = accountInvoices
          .expand(paidInvoiceMonths)
          .toSet()
          .toList();
      if (paidMonths.isNotEmpty) {
        items.add({
          'description': 'Months Paid: ${paidMonths.join(', ')}',
          'amount': 0,
          'status': '—',
        });
      }

      final pdfService = PdfService.getInstance();
      final assets = await Future.wait([
        _schoolLogoBytes(),
        _schoolSignatureBytes(),
      ]);
      final student = inv['student'] is Map
          ? Map<String, dynamic>.from(inv['student'] as Map)
          : const <String, dynamic>{};
      final bytes = await pdfService.generateFeeReceipt(
        documentKind: FeeDocumentKind.accountStatement,
        receiptNo:
            'STMT-${textValue(inv['student_id'], fallback: 'STUDENT')}-${DateTime.now().millisecondsSinceEpoch}',
        studentName: textValue(inv['name'], fallback: 'Student'),
        className: textValue(inv['class'], fallback: '—'),
        rollNo: studentIdentifier(student),
        parentName: '',
        feeItems: items,
        totalAmount: numValue(inv['total']),
        paidAmount: numValue(inv['paid']),
        balance: numValue(inv['balance']),
        paymentMode: '',
        paymentDate: DateTime.now(),
        schoolName: _schoolName,
        schoolAddress: _schoolAddress,
        schoolLogo: assets[0],
        authorizedSignature: assets[1],
        authorizedSignatoryName: textValue(_school['principal_name']),
      );
      if (!mounted) return;
      await pdfService.previewDocument(
        context,
        bytes,
        '${textValue(inv['name'])} — Fee Statement',
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF error: $e')));
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  // ── Server Export Card ────────────────────────────────────────────────────

  Widget _buildServerReportCard(_ReportDef report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _requestExport(report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: report.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(report.icon, color: report.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      report.subtitle,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: context.appTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: report.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_rounded, size: 12, color: report.color),
                    const SizedBox(width: 4),
                    Text(
                      'Preview PDF',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: report.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdf() async {
    setState(() => _generatingPdf = true);
    try {
      final classMap = <String, Map<String, double>>{};
      for (final inv in _invoices) {
        final cls = textValue(inv['class'], fallback: 'Unknown');
        classMap.putIfAbsent(cls, () => {'paid': 0, 'balance': 0});
        classMap[cls]!['paid'] =
            classMap[cls]!['paid']! + numValue(inv['paid']);
        classMap[cls]!['balance'] =
            classMap[cls]!['balance']! + numValue(inv['balance']);
      }

      final items = <Map<String, dynamic>>[
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
        for (final e in classMap.entries)
          {
            'description': e.key,
            'amount': e.value['paid']!,
            'status': '₹${e.value['balance']!.toStringAsFixed(0)} due',
          },
      ];

      final pdfService = PdfService.getInstance();
      final assets = await Future.wait([
        _schoolLogoBytes(),
        _schoolSignatureBytes(),
      ]);
      final bytes = await pdfService.generateFeeReceipt(
        receiptNo: 'RPT-${DateTime.now().millisecondsSinceEpoch}',
        studentName: 'All Students',
        className: 'All Classes',
        rollNo: '${_invoices.length} invoices',
        parentName: 'Fee Collection Report',
        feeItems: items,
        totalAmount: _totalExpected,
        paidAmount: _totalCollected,
        balance: _totalDue,
        paymentMode: 'Summary Report',
        paymentDate: DateTime.now(),
        schoolName: _schoolName,
        schoolAddress: _schoolAddress,
        schoolLogo: assets[0],
        authorizedSignature: assets[1],
        authorizedSignatoryName: textValue(_school['principal_name']),
      );
      if (!mounted) return;
      await pdfService.previewDocument(context, bytes, 'Fee Collection Report');
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF error: $e')));
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _requestExport(_ReportDef _) => _generatePdf();
}

// ── Student Report Picker Bottom Sheet ────────────────────────────────────────

class _StudentReportPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> payments;
  final ValueChanged<Map<String, dynamic>> onGenerate;

  const _StudentReportPickerSheet({
    required this.invoices,
    required this.payments,
    required this.onGenerate,
  });

  @override
  State<_StudentReportPickerSheet> createState() =>
      _StudentReportPickerSheetState();
}

class _StudentReportPickerSheetState extends State<_StudentReportPickerSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.length < 2) return widget.invoices;
    final q = _query.toLowerCase();
    return widget.invoices.where((inv) {
      return '${inv['name']} ${inv['class']}'.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Student',
                    style: GoogleFonts.ibmPlexSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _ctrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search by name or class...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF2563EB),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final inv = _filtered[i];
                  final balance = numValue(inv['balance']);
                  final paid = numValue(inv['paid']);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: balance > 0
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFDCFCE7),
                      child: Icon(
                        balance > 0
                            ? Icons.pending_actions_rounded
                            : Icons.check_circle_rounded,
                        color: balance > 0
                            ? const Color(0xFFF97316)
                            : const Color(0xFF16A34A),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      textValue(inv['name'], fallback: 'Student'),
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${textValue(inv['class'])} • ${(inv['components'] as List? ?? const []).join(' + ')} • Paid: ${money(paid)}',
                      style: GoogleFonts.ibmPlexSans(fontSize: 12),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          money(balance),
                          style: GoogleFonts.ibmPlexSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: balance > 0
                                ? const Color(0xFFF97316)
                                : const Color(0xFF16A34A),
                          ),
                        ),
                        Text(
                          balance > 0 ? 'due' : 'cleared',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => widget.onGenerate(inv),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data Class ────────────────────────────────────────────────────────────────

class _ReportDef {
  final String title, subtitle, reportType;
  final IconData icon;
  final Color color;
  const _ReportDef(
    this.title,
    this.subtitle,
    this.reportType,
    this.icon,
    this.color,
  );
}

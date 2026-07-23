/// Fee Reports — PDF generation and server-side export reports.
library;

import 'package:flutter/material.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_widgets.dart';

class FeeReportsScreen extends StatefulWidget {
  const FeeReportsScreen({super.key});

  @override
  State<FeeReportsScreen> createState() => _FeeReportsScreenState();
}

class _FeeReportsScreenState extends State<FeeReportsScreen> {
  bool _loading = true;
  bool _generatingPdf = false;
  String? _error;
  List<Map<String, dynamic>> _invoices = const [];
  List<Map<String, dynamic>> _payments = const [];
  List<Map<String, dynamic>> _structures = const [];

  static const _serverReports = [
    _ReportDef(
      'Collection Summary',
      'Overall collection summary',
      'fee_collection_summary',
      Icons.summarize_outlined,
      Color(0xFFEC4899),
    ),
    _ReportDef(
      'Class Wise Collection',
      'Collection by class/section',
      'fee_class_collection',
      Icons.assignment_outlined,
      Color(0xFF2563EB),
    ),
    _ReportDef(
      'Student Wise Report',
      'Student payment report',
      'fee_student_report',
      Icons.groups_outlined,
      Color(0xFF4F46E5),
    ),
    _ReportDef(
      'Outstanding Report',
      'All pending dues',
      'fee_outstanding_report',
      Icons.pending_actions_outlined,
      Color(0xFFEA580C),
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
        api.getInvoices(pageSize: 500),
        api.getFeeStructures(),
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

  double get _totalExpected =>
      _invoices.fold<double>(0, (s, i) => s + numValue(i['total']));
  double get _totalCollected =>
      _payments.fold<double>(0, (s, p) => s + numValue(p['amount']));
  double get _totalDue =>
      _invoices.fold<double>(0, (s, i) => s + numValue(i['balance']));
  double get _collectionRate =>
      _totalExpected > 0 ? _totalCollected / _totalExpected : 0;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Fee Reports',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFF7FAFF),
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
          ? FeeEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Error',
              message: _error!,
              actionLabel: 'Retry',
              onAction: _loadData,
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // Live summary card
                  FeeCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            FeeIconBadge(
                              icon: Icons.bar_chart_rounded,
                              color: Color(0xFF4F46E5),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Live Fee Summary',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
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
                              child: FeeInfoTile(
                                label: 'Expected',
                                value: money(_totalExpected),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FeeInfoTile(
                                label: 'Collected',
                                value: money(_totalCollected),
                                highlighted: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FeeInfoTile(
                                label: 'Outstanding',
                                value: money(_totalDue),
                                danger: _totalDue > 0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FeeInfoTile(
                                label: 'Structures',
                                value: '${_structures.length}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FeeInfoTile(
                                label: 'Students',
                                value: '${_invoices.length} invoices',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FeeInfoTile(
                                label: 'Rate',
                                value: '${(_collectionRate * 100).round()}%',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _generatingPdf ? null : _generatePdf,
                          icon: _generatingPdf
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            _generatingPdf
                                ? 'Generating...'
                                : 'Download PDF Summary',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Server-side exports
                  const FeeSectionTitle('Server-side Exports'),
                  const SizedBox(height: 10),
                  for (final report in _serverReports)
                    FeeCard(
                      onTap: () => _requestExport(report),
                      child: Row(
                        children: [
                          FeeIconBadge(icon: report.icon, color: report.color),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  report.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.appTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _generatePdf() async {
    setState(() => _generatingPdf = true);
    try {
      // Build class-wise breakdown
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
        schoolName: 'Fee Collection Report',
        schoolAddress:
            'Generated: ${DateTime.now().toString().substring(0, 16)}',
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

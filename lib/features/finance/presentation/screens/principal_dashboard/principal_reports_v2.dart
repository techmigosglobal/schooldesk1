import 'package:flutter/material.dart';
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

  static const _serverReports = [
    _ReportDef('Collection Summary', 'Overall collection summary', 'fee_collection_summary', Icons.summarize_outlined, Colors.purple),
    _ReportDef('Class Wise Collection', 'Collection by class/section', 'fee_class_collection', Icons.assignment_outlined, Colors.blue),
    _ReportDef('Student Wise Report', 'Student payment report', 'fee_student_report', Icons.groups_outlined, Colors.indigo),
    _ReportDef('Outstanding Report', 'All pending dues', 'fee_outstanding_report', Icons.pending_actions_outlined, Colors.orange),
    _ReportDef('Daily Collection Report', 'Day wise collection', 'fee_daily_collection', Icons.payments_outlined, Colors.green),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getInvoices(pageSize: 1000),
        api.getFeeStructures(),
      ]);
      final rawInvoices = (results[0] as List).cast<Map<String, dynamic>>();
      final allPayments = rawInvoices.expand(normalizePayments).toList();
      if (!mounted) return;
      setState(() {
        _invoices = rawInvoices.map(normalizeInvoice).toList();
        _payments = allPayments.cast<Map<String, dynamic>>();
        _structures = (results[1] as List).cast<Map<String, dynamic>>().map(normalizeFeeStructure).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  double get _totalExpected => _invoices.fold<double>(0, (s, i) => s + numValue(i['total']));
  double get _totalCollected => _payments.fold<double>(0, (s, p) => s + numValue(p['amount']));
  double get _totalDue => _invoices.fold<double>(0, (s, i) => s + numValue(i['balance']));
  double get _collectionRate => _totalExpected > 0 ? _totalCollected / _totalExpected : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.surface,
      appBar: AppBar(
        title: const Text('Fee Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.appTheme.onSurface,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          )
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
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: context.appTheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.bar_chart_rounded, color: Color(0xFF1A6B4A)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Live Collection Summary',
                                    style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _kpiColumn('Expected', '₹${_totalExpected.toStringAsFixed(0)}'),
                                  _kpiColumn('Collected', '₹${_totalCollected.toStringAsFixed(0)}', color: Colors.green),
                                  _kpiColumn('Outstanding', '₹${_totalDue.toStringAsFixed(0)}', color: Colors.orange),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _kpiColumn('Templates', '${_structures.length}'),
                                  _kpiColumn('Invoices', '${_invoices.length}'),
                                  _kpiColumn('Collection Rate', '${(_collectionRate * 100).toStringAsFixed(0)}%'),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _generatingPdf ? null : _generatePdf,
                                  icon: _generatingPdf
                                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.picture_as_pdf_outlined),
                                  label: const Text('Download PDF Summary Report'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A6B4A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Available Server-side Exports',
                        style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ..._serverReports.map((report) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: context.appTheme.outlineVariant),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _requestExport(report),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: report.color.withOpacity(0.1),
                                      child: Icon(report.icon, color: report.color),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            report.title,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            report.subtitle,
                                            style: TextStyle(fontSize: 12, color: context.appTheme.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded),
                                  ],
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
    );
  }

  Widget _kpiColumn(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(fontSize: 11, color: context.appTheme.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color ?? context.appTheme.onSurface,
          ),
        ),
      ],
    );
  }

  Future<void> _generatePdf() async {
    setState(() => _generatingPdf = true);
    try {
      final classMap = <String, Map<String, double>>{};
      for (final inv in _invoices) {
        final cls = textValue(inv['class'], fallback: 'Unknown');
        classMap.putIfAbsent(cls, () => {'paid': 0, 'balance': 0});
        classMap[cls]!['paid'] = classMap[cls]!['paid']! + numValue(inv['paid']);
        classMap[cls]!['balance'] = classMap[cls]!['balance']! + numValue(inv['balance']);
      }

      final items = <Map<String, dynamic>>[
        {'description': 'Total Collected', 'amount': _totalCollected, 'status': 'Collected'},
        {'description': 'Outstanding Dues', 'amount': _totalDue, 'status': _totalDue > 0 ? 'Pending' : 'Clear'},
        for (final e in classMap.entries)
          {'description': e.key, 'amount': e.value['paid']!, 'status': '₹${e.value['balance']!.toStringAsFixed(0)} due'},
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
        schoolAddress: 'Generated: ${DateTime.now().toString().substring(0, 16)}',
      );
      if (!mounted) return;
      await pdfService.previewDocument(context, bytes, 'Fee Collection Report');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF error: $e')));
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _requestExport(_ReportDef report) async {
    try {
      await BackendApiClient.instance.createReportExport(
        '/fees/reports/exports',
        reportTitle: report.title,
        reportType: report.reportType,
        format: 'pdf',
        parameters: {
          'invoice_count': _invoices.length,
          'structure_count': _structures.length,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report export queued')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

class _ReportDef {
  final String title, subtitle, reportType;
  final IconData icon;
  final Color color;
  const _ReportDef(this.title, this.subtitle, this.reportType, this.icon, this.color);
}

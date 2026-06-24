import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class AdminPaymentRequestDecisionArgs {
  final Map<String, dynamic> request;

  const AdminPaymentRequestDecisionArgs({required this.request});
}

class AdminPaymentRequestDecisionScreen extends StatefulWidget {
  final AdminPaymentRequestDecisionArgs args;

  const AdminPaymentRequestDecisionScreen({super.key, required this.args});

  @override
  State<AdminPaymentRequestDecisionScreen> createState() =>
      _AdminPaymentRequestDecisionScreenState();
}

class _AdminPaymentRequestDecisionScreenState
    extends State<AdminPaymentRequestDecisionScreen> {
  final _remarksController = TextEditingController();
  String _decision = 'approved';
  bool _submitting = false;
  bool _navigatingToInvoice = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.args.request;
    return SchoolDeskModuleScaffold(
      title: 'Payment Decision',
      subtitle: 'Approve or reject parent-submitted fee payments',
      drawer: PrincipalDrawer(selectedIndex: 7, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Form(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDetails(request),
            const SizedBox(height: 16),
            _buildDecisionSelector(),
            const SizedBox(height: 14),
            TextFormField(
              controller: _remarksController,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: _decision == 'approved'
                    ? 'Payment approval note'
                    : 'Rejection reason',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            if (_navigatingToInvoice)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Loading invoice form...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _decision == 'approved'
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 18,
                    ),
              label: Text(
                _submitting
                    ? 'Submitting...'
                    : _decision == 'approved'
                    ? 'Approve Payment'
                    : 'Reject Payment',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(
                'Back to Requests',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(Map<String, dynamic> request) {
    final invoice = _map(request['invoice']);
    final student = _map(request['student']);
    final parent = _map(request['parent_user']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _studentName(student),
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _detailRow(
            'Parent',
            _text(parent['name'], fallback: parent['email']),
          ),
          _detailRow(
            'Invoice',
            _text(invoice['invoice_number'], fallback: request['invoice_id']),
          ),
          _detailRow('Amount', _money(_num(request['amount']))),
          _detailRow('Payment date', _date(request['payment_date'])),
          _detailRow('Mode', _text(request['payment_mode'], fallback: '-')),
          if (_text(request['transaction_id']).isNotEmpty)
            _detailRow('Transaction', _text(request['transaction_id'])),
          if (_text(request['proof_url']).isNotEmpty) ...[
            _detailRow('Proof upload', _text(request['proof_url'])),
            const SizedBox(height: 10),
            _buildProofPreview(request['proof_url']),
          ],
          if (_text(request['remarks']).isNotEmpty)
            _detailRow('Parent note', _text(request['remarks'])),
        ],
      ),
    );
  }

  Widget _buildDecisionSelector() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            selected: _decision == 'approved',
            label: const Text('Approve Payment'),
            avatar: const Icon(Icons.check_rounded, size: 16),
            onSelected: _submitting
                ? null
                : (_) => setState(() => _decision = 'approved'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ChoiceChip(
            selected: _decision == 'rejected',
            label: const Text('Reject Payment'),
            avatar: const Icon(Icons.close_rounded, size: 16),
            onSelected: _submitting
                ? null
                : (_) => setState(() => _decision = 'rejected'),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: context.appTheme.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final requestID = _text(widget.args.request['id']);
    if (requestID.isEmpty) {
      _showError('Payment request ID is missing.');
      return;
    }
    final remarks = _remarksController.text.trim();
    if (_decision == 'rejected' && remarks.length < 3) {
      _showError('Enter a rejection reason.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await BackendApiClient.instance.decideParentPaymentRequest(
        requestID,
        status: _decision,
        adminRemarks: remarks,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment request ${_decision == 'approved' ? 'approved' : 'rejected'}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (_decision == 'approved' && mounted) {
        final invoiceShown = await _offerGenerateInvoice(widget.args.request);
        if (!invoiceShown && mounted) Navigator.pop(context, true);
      } else {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(error.toString());
    }
  }

  Future<bool> _offerGenerateInvoice(Map<String, dynamic> req) async {
    final student = _map(req['student']);
    final studentName = _studentName(student);
    final amount = _money(_num(req['amount']));
    final studentId = '${req['student_id'] ?? student['id'] ?? ''}'.trim();
    final gradeId = '${req['grade_id'] ?? student['grade_id'] ?? ''}'.trim();

    if (!mounted) return false;
    final shouldGenerate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Invoice?'),
        content: Text(
          'Payment of $amount approved for $studentName.\n\n'
          'Would you like to generate a fee receipt / invoice for this payment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate Invoice'),
          ),
        ],
      ),
    );
    if (shouldGenerate != true) return true; // user chose 'Later'
    if (!mounted) return false;
    setState(() => _navigatingToInvoice = true);
    try {
      await _navigateToInvoiceGeneration(
        studentId: studentId,
        gradeId: gradeId,
        studentName: studentName,
      );
      return true;
    } catch (error) {
      if (mounted) _showError(error.toString());
      return false;
    } finally {
      if (mounted) setState(() => _navigatingToInvoice = false);
    }
  }

  Future<void> _navigateToInvoiceGeneration({
    required String studentId,
    required String gradeId,
    required String studentName,
  }) async {
    final api = BackendApiClient.instance;
    final results = await Future.wait<Object>([
      api.getAcademicYears(),
      api.getGrades(),
      api.getSections(),
      api.getStudents(page: 1, pageSize: 500),
      api.getFeeStructures(),
    ]);
    if (!mounted) return;
    final academicYears = results[0] as List<AcademicYearModel>;
    final grades = results[1] as List<GradeModel>;
    final sections = results[2] as List<SectionModel>;
    final students = (results[3] as PaginatedList<StudentModel>).data;
    final feeStructures = results[4] as List<Map<String, dynamic>>;

    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicYearFeesExport,
      arguments: AdminInvoiceGenerationFormArgs(
        academicYears: academicYears,
        grades: grades,
        sections: sections,
        students: students,
        feeStructures: feeStructures,
        seedStructure: {if (gradeId.isNotEmpty) 'grade_id': gradeId},
        ownerRole: 'principal',
      ),
    );
    if (!mounted) return;
    if (result is AdminInvoiceGenerationFormResult) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invoice request submitted: ${result.created} created, ${result.skipped} skipped for $studentName.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.appTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  double _num(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _text(dynamic value, {dynamic fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return '${fallback ?? ''}'.trim();
    return text;
  }

  String _studentName(Map<String, dynamic> student) {
    final name = [
      _text(student['first_name']),
      _text(student['last_name']),
    ].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? 'Student' : name;
  }

  String _money(double value) => '₹${value.toStringAsFixed(0)}';

  String _date(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return '-';
    return parsed.toIso8601String().split('T').first;
  }

  Widget _buildProofPreview(String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    final isImage =
        url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.png');
    if (!isImage) {
      return OutlinedButton.icon(
        onPressed: () {
          // Open PDF/link in browser
        },
        icon: const Icon(Icons.open_in_new_rounded, size: 16),
        label: Text(
          'Open proof document',
          style: GoogleFonts.dmSans(fontSize: 12),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _showFullImage(url),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.appTheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: context.appTheme.surfaceVariant,
            child: const Center(
              child: Icon(Icons.broken_image_rounded, size: 32),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullImage(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

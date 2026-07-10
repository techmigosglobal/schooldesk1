import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

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
      subtitle: 'Approve, reject, or request payment clarification',
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.fees,
        onDestinationSelected: (_) {},
      ),
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
                    : _decision == 'clarification_required'
                    ? 'Clarification note'
                    : 'Rejection reason',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
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
                          : _decision == 'clarification_required'
                          ? Icons.help_outline_rounded
                          : Icons.cancel_rounded,
                      size: 18,
                    ),
              label: Text(
                _submitting
                    ? 'Submitting...'
                    : _decision == 'approved'
                    ? 'Approve Payment'
                    : _decision == 'clarification_required'
                    ? 'Request Clarification'
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SizedBox(
          width: 170,
          child: ChoiceChip(
            selected: _decision == 'approved',
            label: const Text('Approve Payment'),
            avatar: const Icon(Icons.check_rounded, size: 16),
            onSelected: _submitting
                ? null
                : (_) => setState(() => _decision = 'approved'),
          ),
        ),
        SizedBox(
          width: 170,
          child: ChoiceChip(
            selected: _decision == 'clarification_required',
            label: const Text('Request Clarification'),
            avatar: const Icon(Icons.help_outline_rounded, size: 16),
            onSelected: _submitting
                ? null
                : (_) => setState(() => _decision = 'clarification_required'),
          ),
        ),
        SizedBox(
          width: 170,
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
    if (_decision == 'clarification_required' && remarks.length < 3) {
      _showError('Enter a clarification note.');
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
            _decision == 'approved'
                ? 'Payment request approved.'
                : _decision == 'clarification_required'
                ? 'Clarification requested from parent.'
                : 'Payment request rejected.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (_decision == 'approved' && mounted) {
        await _showPaymentCompleted(widget.args.request);
        if (mounted) Navigator.pop(context, true);
      } else {
        Navigator.pop(context, true);
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(error.toString());
    }
  }

  Future<void> _showPaymentCompleted(Map<String, dynamic> req) async {
    final student = _map(req['student']);
    final studentName = _studentName(student);
    final amount = _money(_num(req['amount']));

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment Completed'),
        content: Text(
          'Payment of $amount has been approved for $studentName.\n\n'
          'The receipt/payment record is complete and the parent fee balance will show the updated status.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
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
    final lower = url.toLowerCase();
    final isImage =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
    final isPdf = lower.endsWith('.pdf');
    if (isPdf) {
      return OutlinedButton.icon(
        onPressed: () => _showProofDocumentPreview(url),
        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
        label: Text(
          'Open proof inside app',
          style: GoogleFonts.dmSans(fontSize: 12),
        ),
      );
    }
    if (!isImage) {
      return OutlinedButton.icon(
        onPressed: () => _showProofDocumentPreview(url),
        icon: const Icon(Icons.description_rounded, size: 16),
        label: Text(
          'Open proof inside app',
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
          _absoluteMediaUrl(url),
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

  void _showProofDocumentPreview(String url) {
    openEventPostMediaPreview(context, EventPostMediaItem.fromUrl(url));
  }

  String _absoluteMediaUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return '${EnvConfig.apiOrigin}$trimmed';
    return '${EnvConfig.apiOrigin}/$trimmed';
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
              InteractiveViewer(
                child: Image.network(
                  _absoluteMediaUrl(url),
                  fit: BoxFit.contain,
                ),
              ),
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

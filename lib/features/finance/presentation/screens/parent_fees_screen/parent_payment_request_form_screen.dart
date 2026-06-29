import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';

@immutable
class ParentPaymentRequestFormArgs {
  final List<Map<String, dynamic>> fees;
  final Map<String, dynamic>? student;

  const ParentPaymentRequestFormArgs({required this.fees, this.student});
}

@immutable
class ParentPaymentRequestFormResult {
  final int submittedCount;
  final List<String> references;

  const ParentPaymentRequestFormResult({
    required this.submittedCount,
    required this.references,
  });
}

class ParentPaymentRequestFormScreen extends StatefulWidget {
  final ParentPaymentRequestFormArgs args;

  const ParentPaymentRequestFormScreen({super.key, required this.args});

  @override
  State<ParentPaymentRequestFormScreen> createState() =>
      _ParentPaymentRequestFormScreenState();
}

class _ParentPaymentRequestFormScreenState
    extends State<ParentPaymentRequestFormScreen> {
  static const List<String> _paymentModes = ['upi', 'cash', 'bank_transfer'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _utrController;
  late final TextEditingController _paymentDateController;
  final _remarksController = TextEditingController();

  bool _loadingConfig = true;
  bool _uploadingProof = false;
  bool _submitting = false;
  String? _proofUrl;
  String? _proofName;
  String? _configError;
  Map<String, dynamic> _paymentConfig = const {};
  String _paymentMode = 'upi';

  List<Map<String, dynamic>> get _fees => widget.args.fees
      .where((fee) {
        final invoiceId = '${fee['id'] ?? ''}'.trim();
        final amount = (fee['amount'] as num?)?.toDouble() ?? 0;
        return invoiceId.isNotEmpty && amount > 0;
      })
      .map((fee) => Map<String, dynamic>.from(fee))
      .toList();

  double get _totalAmount => _fees.fold<double>(
    0,
    (sum, fee) => sum + ((fee['amount'] as num?)?.toDouble() ?? 0),
  );

  String get _upiId => _text(_paymentConfig['upi_id']);
  String get _payeeName =>
      _text(_paymentConfig['payee_name'], fallback: 'School');
  String get _qrImageUrl => _text(_paymentConfig['qr_image_url']);
  bool get _upiEnabled =>
      _paymentConfig['upi_enabled'] == true &&
      (_upiId.isNotEmpty || _qrImageUrl.isNotEmpty);
  bool get _isUpiMode => _paymentMode == 'upi';
  bool get _isCashMode => _paymentMode == 'cash';
  bool get _requiresProof => _isUpiMode;
  bool get _requiresReference => !_isCashMode;

  String get _upiUri {
    final params = {
      'pa': _upiId,
      'pn': _payeeName,
      'am': _totalAmount.toStringAsFixed(2),
      'cu': 'INR',
      'tn': _text(_paymentConfig['qr_note'], fallback: 'School fee payment'),
    };
    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    return 'upi://pay?$query';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _utrController = TextEditingController();
    _paymentDateController = TextEditingController(text: _dateInput(now));
    _loadPaymentConfig();
  }

  @override
  void dispose() {
    _utrController.dispose();
    _paymentDateController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentConfig() async {
    setState(() {
      _loadingConfig = true;
      _configError = null;
    });
    try {
      final invoiceId = _fees.isEmpty ? '' : _text(_fees.first['id']);
      final config = await BackendApiClient.instance.getPaymentConfig(
        invoiceId: invoiceId,
      );
      if (!mounted) return;
      setState(() {
        _paymentConfig = config;
        _loadingConfig = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _configError = error.toString();
        _loadingConfig = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Fee Payment Request',
      subtitle: 'Choose payment mode and submit request for verification',
      drawer: ParentDrawer(
        selectedIndex: ParentNav.fees,
        onDestinationSelected: (_) {},
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStudentSummary(),
            const SizedBox(height: 14),
            _buildFeeBreakdown(),
            const SizedBox(height: 14),
            _buildPaymentModeSelector(),
            const SizedBox(height: 14),
            _buildUpiPanel(),
            const SizedBox(height: 14),
            _buildReferenceFields(),
            const SizedBox(height: 14),
            _buildProofUpload(),
            const SizedBox(height: 14),
            TextFormField(
              controller: _remarksController,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notes for school office',
                hintText: 'Optional payer details or bank note',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            _buildVerificationNotice(),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _canSubmit ? _submit : null,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _submitting
                    ? 'Submitting...'
                    : 'Submit ${_paymentModeLabel(_paymentMode)} Request INR ${_totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(
                'Back to Fees',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit =>
      !_submitting &&
      !_loadingConfig &&
      _fees.isNotEmpty &&
      (!_isUpiMode || _upiEnabled) &&
      _isIsoDate(_paymentDateController.text.trim()) &&
      (!_requiresReference || _utrController.text.trim().length >= 6) &&
      (!_requiresProof || (_proofUrl?.isNotEmpty ?? false));

  Widget _buildPaymentModeSelector() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment mode',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paymentModes
                .map(
                  (mode) => ChoiceChip(
                    label: Text(
                      mode == 'upi' ? 'Pay by UPI' : _paymentModeLabel(mode),
                    ),
                    selected: _paymentMode == mode,
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() => _paymentMode = mode),
                  ),
                )
                .toList(),
          ),
          if (_isCashMode) ...[
            const SizedBox(height: 10),
            Text(
              'Cash mode submits a pay-at-office request. No UPI setup is required.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.appTheme.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentSummary() {
    final student = widget.args.student ?? const <String, dynamic>{};
    final name = _studentName(student);
    final classLabel =
        '${student['class'] ?? student['class_name'] ?? student['current_section_id'] ?? ''}'
            .trim();
    return _panel(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.appTheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.account_circle_rounded,
              color: context.appTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Linked student' : name,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.appTheme.onSurface,
                  ),
                ),
                if (classLabel.isNotEmpty)
                  Text(
                    classLabel,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: context.appTheme.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeBreakdown() {
    if (_fees.isEmpty) {
      return _panel(
        child: Text(
          'No pending invoice is available for payment request.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: context.appTheme.error,
          ),
        ),
      );
    }
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected installment breakdown',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ..._fees.map(
            (fee) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Selected installment: ${fee['component'] ?? fee['invoiceNumber'] ?? 'Invoice'}',
                      style: GoogleFonts.dmSans(fontSize: 12),
                    ),
                  ),
                  Text(
                    'INR ${((fee['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 16),
          Row(
            children: [
              Text(
                'Total payable amount',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'INR ${_totalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                  color: context.appTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpiPanel() {
    if (!_isUpiMode) {
      return _panel(
        child: Text(
          _isCashMode
              ? 'Pay this amount at the school office and submit this request for approval.'
              : 'Enter your bank transfer reference below and submit for verification.',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: context.appTheme.onSurface,
          ),
        ),
      );
    }
    if (_loadingConfig) {
      return _panel(child: const Center(child: CircularProgressIndicator()));
    }
    if (_configError != null || !_upiEnabled) {
      return _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UPI payment is not configured',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _configError ??
                  'UPI is not available. Switch to Cash or Bank Transfer to continue.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.appTheme.error,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadPaymentConfig,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Scan this QR in any UPI app',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_qrImageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _absoluteMediaUrl(_qrImageUrl),
                width: 210,
                height: 210,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => QrImageView(
                  data: _upiUri,
                  version: QrVersions.auto,
                  size: 190,
                ),
              ),
            )
          else
            QrImageView(data: _upiUri, version: QrVersions.auto, size: 190),
          if (_upiId.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(
              _upiId,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Payee: $_payeeName',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appTheme.onSurface,
              ),
            ),
            if (_text(_paymentConfig['qr_note']).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _text(_paymentConfig['qr_note']),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: context.appTheme.muted,
                ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _upiId));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('UPI ID copied')));
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy UPI ID'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReferenceFields() {
    return _panel(
      child: Column(
        children: [
          if (_requiresReference) ...[
            TextFormField(
              controller: _utrController,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: _isUpiMode
                    ? 'UTR / transaction reference'
                    : 'Bank transfer reference',
                hintText: _isUpiMode
                    ? 'Enter UTR after successful UPI payment'
                    : 'Enter NEFT/RTGS/IMPS transaction reference',
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 6) {
                  return 'Enter a valid transaction reference';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _paymentDateController,
            enabled: !_submitting,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Payment date',
              hintText: 'YYYY-MM-DD',
            ),
            validator: (value) {
              final raw = (value ?? '').trim();
              if (raw.isEmpty) return 'Required';
              if (!_isIsoDate(raw)) return 'Use YYYY-MM-DD';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProofUpload() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _requiresProof
                ? 'Upload payment screenshot'
                : 'Upload proof (optional)',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _requiresProof
                ? 'Upload the UPI success screenshot so the school can verify the transaction.'
                : 'Optional: attach a transfer receipt or payment note for faster verification.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.appTheme.muted,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _uploadingProof || _submitting ? null : _pickProof,
            icon: _uploadingProof
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(_uploadingProof ? 'Uploading...' : 'Upload Screenshot'),
          ),
          if (_proofUrl != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: context.appTheme.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _proofName ?? 'Payment proof uploaded',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove proof',
                  onPressed: _submitting
                      ? null
                      : () => setState(() {
                          _proofUrl = null;
                          _proofName = null;
                        }),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationNotice() {
    return _panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: context.appTheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fees will be updated in 12-24 hrs after Principal verification.',
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

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: child,
    );
  }

  Future<void> _pickProof() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null || path.isEmpty) return;
    setState(() => _uploadingProof = true);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: file.name),
      });
      final response = await BackendApiClient.instance.dio.post(
        '/uploads',
        data: formData,
      );
      final responseData = response.data;
      final data = responseData is Map ? responseData['data'] : null;
      final url =
          '${responseData is Map ? responseData['url'] : ''}'.trim().isNotEmpty
          ? '${responseData['url']}'.trim()
          : '${data is Map ? data['url'] : ''}'.trim();
      if (url.isEmpty) throw Exception('Upload did not return a proof URL');
      if (!mounted) return;
      setState(() {
        _proofUrl = url;
        _proofName = file.name;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proof upload failed: $error'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingProof = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiresProof && (_proofUrl == null || _proofUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Upload payment screenshot before submitting.'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    final references = <String>[];
    try {
      for (final fee in _fees) {
        final reference = _utrController.text.trim();
        final fallbackReference =
            'REQ-${_paymentMode.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch}-${_text(fee['id'])}';
        final request = await BackendApiClient.instance
            .submitParentPaymentRequest(
              PaymentRequest(
                invoiceId: '${fee['id']}',
                receiptNumber: reference.isNotEmpty
                    ? reference
                    : fallbackReference,
                amountPaid: (fee['amount'] as num?)?.toDouble() ?? 0,
                paymentDate: _paymentDateController.text.trim(),
                paymentMode: _paymentMode,
                transactionId: reference.isNotEmpty ? reference : null,
                proofUrl: (_proofUrl?.isNotEmpty ?? false) ? _proofUrl : null,
              ),
              remarks: _remarksController.text.trim(),
            );
        final requestReference = '${request['request_reference'] ?? ''}'.trim();
        if (requestReference.isNotEmpty) references.add(requestReference);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_paymentModeLabel(_paymentMode)} request submitted. Fees will be updated in 12-24 hrs.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(
        context,
        ParentPaymentRequestFormResult(
          submittedCount: _fees.length,
          references: references,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _studentName(Map<String, dynamic> student) {
    final name = '${student['name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    return '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
        .trim();
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  bool _isIsoDate(String raw) {
    final match = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw);
    return match && DateTime.tryParse(raw) != null;
  }

  String _absoluteMediaUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return '${EnvConfig.apiOrigin}$trimmed';
    return '${EnvConfig.apiOrigin}/$trimmed';
  }

  String _paymentModeLabel(String mode) {
    switch (mode) {
      case 'cash':
        return 'Cash';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return 'UPI';
    }
  }
}

String _dateInput(DateTime dt) =>
    '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

String _two(int value) => value.toString().padLeft(2, '0');

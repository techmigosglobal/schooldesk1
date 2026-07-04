import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final Map<String, dynamic>? paymentRequest;

  const ParentPaymentRequestFormArgs({
    required this.fees,
    this.student,
    this.paymentRequest,
  });
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
  static const List<String> _paymentModes = ['upi'];
  static const String _verificationNotice =
      'Your payment proof will stay pending until the principal verifies it.';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _utrController;
  late final TextEditingController _paymentDateController;
  final _remarksController = TextEditingController();

  bool _loadingConfig = true;
  bool _uploadingProof = false;
  bool _creatingIntent = false;
  bool _submitting = false;
  bool _upiOpened = false;
  String? _proofName;
  String? _proofPath;
  String? _configError;
  Map<String, dynamic> _paymentConfig = const {};
  Map<String, dynamic>? _paymentIntent;
  String _paymentMode = 'upi';
  final Set<String> _selectedMonthNames = <String>{};
  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  List<Map<String, dynamic>> get _fees => widget.args.fees
      .where((fee) {
        final invoiceId = '${fee['id'] ?? ''}'.trim();
        final amount = (fee['amount'] as num?)?.toDouble() ?? 0;
        return invoiceId.isNotEmpty && amount > 0;
      })
      .map((fee) => Map<String, dynamic>.from(fee))
      .toList();

  Map<String, dynamic> get _selectedFee =>
      _fees.isEmpty ? const <String, dynamic>{} : _fees.first;

  bool get _isTuition => _text(_selectedFee['fee_type']) == 'tuition';
  List<String> get _allowedMonthNames {
    final configured = (_selectedFee['allowed_month_names'] is List
            ? (_selectedFee['allowed_month_names'] as List)
                .map((value) => '$value'.trim())
                .where((value) => value.isNotEmpty)
                .toList()
            : const <String>[])
        .cast<String>();
    if (configured.isEmpty && _isTuition) {
      return _monthNames;
    }
    return configured;
  }
  List<String> get _paidMonthNames =>
      (_selectedFee['paid_month_names'] is List
              ? (_selectedFee['paid_month_names'] as List)
                  .map((value) => '$value'.trim())
                  .where((value) => value.isNotEmpty)
                  .toList()
              : const <String>[])
          .cast<String>();
  List<String> get _unpaidMonthNames =>
      _allowedMonthNames
          .where((month) => !_paidMonthNames.contains(month))
          .toList(growable: false);
  double get _totalAmount {
    final balance =
        (_selectedFee['amount'] as num?)?.toDouble() ??
        (_selectedFee['balance_amount'] as num?)?.toDouble() ??
        0;
    if (_isTuition) {
      final monthly =
          (_selectedFee['monthly_amount'] as num?)?.toDouble() ?? balance / 12;
      return monthly * _selectedMonthNames.length;
    }
    return balance;
  }

  String get _upiId => _text(_paymentConfig['upi_id']);
  String get _payeeName =>
      _text(_paymentConfig['payee_name'], fallback: 'School');
  String get _qrImageUrl => _text(_paymentConfig['qr_image_url']);
  String get _qrImageCacheKey =>
      _text(_paymentConfig['updated_at'], fallback: _qrImageUrl);
  bool get _upiEnabled =>
      _paymentConfig['upi_enabled'] == true &&
      (_upiId.isNotEmpty || _qrImageUrl.isNotEmpty);
  bool get _isUpiMode => _paymentMode == 'upi';
  bool get _requiresProof => true;
  bool get _requiresReference => true;
  bool get _isBusy => _uploadingProof || _creatingIntent || _submitting;
  Map<String, dynamic> get _resubmissionRequest =>
      widget.args.paymentRequest == null
      ? const <String, dynamic>{}
      : Map<String, dynamic>.from(widget.args.paymentRequest!);
  bool get _isClarificationResubmit =>
      _text(_resubmissionRequest['status']).toLowerCase() ==
      'clarification_required';
  String get _intentId => _text(_paymentIntent?['id']);
  String get _intentReference => _text(_paymentIntent?['request_reference']);
  String get _intentUpiUri => _text(_paymentIntent?['upi_uri']);
  String get _effectiveUpiUri =>
      _intentUpiUri.isNotEmpty ? _intentUpiUri : _upiUri;
  double get _payableAmount =>
      (_paymentIntent?['amount'] as num?)?.toDouble() ?? _totalAmount;

  String get _upiUri {
    final params = {
      'pa': _upiId,
      'pn': _payeeName,
      'am': _payableAmount.toStringAsFixed(2),
      'cu': 'INR',
      'tn': _intentReference.isNotEmpty
          ? _intentReference
          : _text(_paymentConfig['qr_note'], fallback: 'School fee payment'),
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
    if (_isClarificationResubmit) {
      _utrController.text = _text(_resubmissionRequest['transaction_id']);
      _paymentMode = _text(
        _resubmissionRequest['payment_mode'],
        fallback: _paymentMode,
      );
    }
    _seedMonthSelection();
    _loadPaymentConfig(forceRefresh: true);
  }

  @override
  void dispose() {
    _utrController.dispose();
    _paymentDateController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _seedMonthSelection() {
    _selectedMonthNames
      ..clear()
      ..addAll(_initialContinuousMonthSelection());
  }

  List<String> _initialContinuousMonthSelection() {
    if (!_isTuition) return const <String>[];
    if (_unpaidMonthNames.isEmpty) return const <String>[];
    return <String>[_unpaidMonthNames.first];
  }

  Future<void> _loadPaymentConfig({bool forceRefresh = false}) async {
    setState(() {
      _loadingConfig = true;
      _configError = null;
    });
    try {
      final invoiceId = _fees.isEmpty ? '' : _text(_fees.first['id']);
      final config = await BackendApiClient.instance.getPaymentConfig(
        invoiceId: invoiceId,
        refreshNonce: forceRefresh
            ? DateTime.now().millisecondsSinceEpoch
            : null,
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
    return PopScope(
      canPop: !_isBusy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_isBusy) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please wait for the payment step to finish before leaving this screen.',
            ),
          ),
        );
      },
      child: SchoolDeskModuleScaffold(
        title: 'Fee Payment Request',
        subtitle: _isClarificationResubmit
            ? 'Update proof requested by the school'
            : 'Pay with the school UPI QR and submit proof for verification',
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
              _buildIntervalSelector(),
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
                      : _isClarificationResubmit
                      ? 'Resubmit Payment for Verification'
                      : 'Submit Payment for Verification INR ${_payableAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(
                  'Back to Fees',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSubmit =>
      !_submitting &&
      (!_loadingConfig || _isClarificationResubmit) &&
      _fees.isNotEmpty &&
      (_isClarificationResubmit || !_isUpiMode || _upiEnabled) &&
      _isIsoDate(_paymentDateController.text.trim()) &&
      (!_requiresReference || _utrController.text.trim().length >= 6) &&
      (!_isTuition || _selectedMonthNames.isNotEmpty) &&
      (!_requiresProof || (_proofPath?.isNotEmpty ?? false));

  bool _isPaidMonth(String month) => _paidMonthNames.contains(month);

  bool _canAddMonth(String month) {
    if (!_isTuition || _isPaidMonth(month)) return false;
    final nextIndex = _selectedMonthNames.length;
    if (nextIndex >= _unpaidMonthNames.length) return false;
    return _unpaidMonthNames[nextIndex] == month;
  }

  bool _canRemoveMonth(String month) {
    if (!_selectedMonthNames.contains(month)) return false;
    if (_selectedMonthNames.length <= 1) return false;
    final ordered = _unpaidMonthNames
        .where(_selectedMonthNames.contains)
        .toList(growable: false);
    return ordered.isNotEmpty && ordered.last == month;
  }

  void _toggleMonthSelection(String month) {
    if (_submitting || !_isTuition) return;
    setState(() {
      if (_selectedMonthNames.contains(month)) {
        if (_canRemoveMonth(month)) {
          _selectedMonthNames.remove(month);
        }
      } else if (_canAddMonth(month)) {
        _selectedMonthNames.add(month);
      }
      _resetPaymentIntent();
    });
  }

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
            children: _paymentModes.map((mode) {
              final selected = _paymentMode == mode;
              return ChoiceChip(
                label: Text(
                  mode == 'upi' ? 'Pay by UPI' : _paymentModeLabel(mode),
                  style: GoogleFonts.dmSans(
                    color: selected ? Colors.white : context.appTheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                selected: selected,
                selectedColor: context.appTheme.primary,
                backgroundColor: context.appTheme.surface,
                disabledColor: context.appTheme.surfaceVariant,
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: selected
                      ? context.appTheme.primary
                      : context.appTheme.outlineVariant,
                ),
                onSelected: _submitting
                    ? null
                    : (_) => setState(() {
                        _paymentMode = mode;
                        _resetPaymentIntent();
                      }),
              );
            }).toList(),
          ),
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
            'Selected fee breakdown',
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
                      'Selected fee: ${fee['component'] ?? fee['fee_item_name'] ?? fee['invoiceNumber'] ?? 'Invoice'}',
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
                'INR ${_payableAmount.toStringAsFixed(0)}',
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

  Widget _buildIntervalSelector() {
    if (_fees.isEmpty) return const SizedBox.shrink();
    if (!_isTuition) {
      return _panel(
        child: Row(
          children: [
            Icon(Icons.shopping_bag_rounded, color: context.appTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Book & Kit is a one-time fee. Parents must clear the remaining balance in one payment.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.appTheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final monthly = (_selectedFee['monthly_amount'] as num?)?.toDouble() ?? 0;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tuition month selection',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            '₹${monthly.toStringAsFixed(0)} per month',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            'Months already marked by the school stay locked. You can only extend the next continuous unpaid month range.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.appTheme.muted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _monthNames.map((month) {
              final selected = _selectedMonthNames.contains(month);
              final paid = _isPaidMonth(month);
              final canAdd = _canAddMonth(month);
              final canRemove = _canRemoveMonth(month);
              final enabled = canAdd || canRemove;
              return FilterChip(
                label: Text(paid ? '$month Paid' : month),
                selected: selected || paid,
                onSelected: enabled ? (_) => _toggleMonthSelection(month) : null,
                selectedColor: paid
                    ? context.appTheme.success.withOpacity(0.16)
                    : context.appTheme.primaryContainer,
                disabledColor: paid
                    ? context.appTheme.success.withOpacity(0.10)
                    : context.appTheme.surfaceVariant,
                checkmarkColor: paid
                    ? context.appTheme.success
                    : context.appTheme.primary,
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedMonthNames.isEmpty
                ? 'Select the next payable month to continue.'
                : 'Selected months: ${_unpaidMonthNames.where(_selectedMonthNames.contains).join(', ')}',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
          if (_paidMonthNames.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Already paid: ${_paidMonthNames.join(', ')}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.appTheme.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Divider(height: 18),
          Row(
            children: [
              Text(
                'Payable now',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'INR ${_payableAmount.toStringAsFixed(0)}',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w900,
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
    if (_isClarificationResubmit) {
      return _panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.help_outline_rounded, color: context.appTheme.info),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clarification Required',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _text(
                      _resubmissionRequest['admin_remarks'],
                      fallback:
                          'Upload a clearer payment proof or correct the UTR.',
                    ),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: context.appTheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  'No school UPI QR is configured yet. Please retry after the school updates the QR.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.appTheme.error,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _loadPaymentConfig(forceRefresh: true),
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Confirm Payment',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _intentReference.isEmpty
                  ? 'Generate a school reference before opening UPI.'
                  : 'Reference: $_intentReference',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _intentReference.isEmpty
                    ? context.appTheme.muted
                    : context.appTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_creatingIntent || _submitting)
                  ? null
                  : _intentReference.isEmpty
                  ? () => _createPaymentIntent()
                  : _openUpiApp,
              icon: _creatingIntent
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _intentReference.isEmpty
                          ? Icons.fact_check_rounded
                          : Icons.open_in_new_rounded,
                      size: 18,
                    ),
              label: Text(
                _creatingIntent
                    ? 'Creating Reference...'
                    : _intentReference.isEmpty
                    ? 'Confirm Payment'
                    : 'Pay Now',
              ),
            ),
          ),
          if (_upiOpened) ...[
            const SizedBox(height: 8),
            Text(
              'After payment, enter the UTR and upload the success screenshot below.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.appTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Scan this QR in any UPI app',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_qrImageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _absoluteMediaUrl(_qrImageUrl, cacheKey: _qrImageCacheKey),
                width: 210,
                height: 210,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => QrImageView(
                  data: _effectiveUpiUri,
                  version: QrVersions.auto,
                  size: 190,
                ),
              ),
            )
          else
            QrImageView(
              data: _effectiveUpiUri,
              version: QrVersions.auto,
              size: 190,
            ),
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
              decoration: const InputDecoration(
                labelText: 'UTR / transaction reference',
                hintText: 'Enter UTR after successful UPI payment',
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
          if (_proofPath != null) ...[
            const SizedBox(height: 10),
            _buildProofThumbnail(),
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
              _verificationNotice,
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

  Widget _buildProofThumbnail() {
    final isImage =
        _proofPath != null &&
        (_proofPath!.toLowerCase().endsWith('.jpg') ||
            _proofPath!.toLowerCase().endsWith('.jpeg') ||
            _proofPath!.toLowerCase().endsWith('.png'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                _proofName ?? 'Payment proof selected',
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
                      _proofName = null;
                      _proofPath = null;
                    }),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
        if (isImage) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              onTap: () => _showFullImagePreview(_proofPath!),
              child: Image.file(
                File(_proofPath!),
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 140,
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded, size: 32),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap image to preview full size',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: context.appTheme.muted,
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _proofName ?? 'PDF document selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showFullImagePreview(String path) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.file(File(path), fit: BoxFit.contain),
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
    setState(() {
      _uploadingProof = false;
      _proofPath = path;
      _proofName = file.name;
    });
  }

  void _resetPaymentIntent() {
    _paymentIntent = null;
    _upiOpened = false;
  }

  Future<Map<String, dynamic>?> _createPaymentIntent({
    bool showSnack = true,
  }) async {
    if (_fees.isEmpty) return null;
    setState(() => _creatingIntent = true);
    try {
      final intent = await BackendApiClient.instance.createFeePaymentIntent(
        invoiceId: '${_selectedFee['id']}',
        paymentMethod: _paymentMode,
        selectedMonthNames:
            _isTuition ? _unpaidMonthNames.where(_selectedMonthNames.contains).toList() : const [],
        selectedMonths: _isTuition ? _selectedMonthNames.length : 0,
        selectedTerms: 0,
        remarks: _remarksController.text.trim(),
      );
      if (!mounted) return intent;
      setState(() {
        _paymentIntent = intent;
        _creatingIntent = false;
      });
      if (showSnack) {
        final reference = _text(intent['request_reference']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reference.isEmpty
                  ? 'Payment reference created.'
                  : 'Payment reference created: $reference',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return intent;
    } catch (error) {
      if (mounted) {
        setState(() => _creatingIntent = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: context.appTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _openUpiApp() async {
    var intent = _paymentIntent;
    intent ??= await _createPaymentIntent(showSnack: false);
    if (intent == null) return;
    final uriText = _effectiveUpiUri;
    if (uriText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('UPI link is not available for this payment.'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uri = Uri.parse(uriText);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    setState(() => _upiOpened = opened);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to open a UPI app. You can scan the QR instead.',
          ),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiresProof && (_proofPath == null || _proofPath!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Upload payment screenshot before submitting.'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!await _confirmSubmission()) return;
    setState(() => _submitting = true);
    final references = <String>[];
    try {
      if (_isClarificationResubmit) {
        final request = await BackendApiClient.instance.resubmitFeePaymentProof(
          id: _text(_resubmissionRequest['id']),
          transactionRef: _utrController.text.trim(),
          screenshotPath: _proofPath!,
          screenshotName: _proofName ?? 'payment-proof',
          remarks: _remarksController.text.trim(),
        );
        final requestReference = '${request['request_reference'] ?? ''}'.trim();
        final proofUrl = '${request['proof_url'] ?? ''}'.trim();
        if (requestReference.isNotEmpty) references.add(requestReference);
        if (proofUrl.isEmpty) {
          throw StateError(
            'Payment proof was submitted, but the saved proof could not be confirmed.',
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment proof resubmitted for verification.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(
          context,
          ParentPaymentRequestFormResult(
            submittedCount: 1,
            references: references,
          ),
        );
        return;
      }
      var intent = _paymentIntent;
      if (intent == null) {
        intent = await _createPaymentIntent(showSnack: false);
        if (intent == null) {
          if (mounted) setState(() => _submitting = false);
          return;
        }
      }
      final reference = _utrController.text.trim();
      final request = await BackendApiClient.instance.submitFeePaymentProof(
        paymentRequestId: _intentId,
        requestReference: _intentReference,
        studentFeeId: '${_selectedFee['id']}',
        amount: _payableAmount,
        paymentMethod: _paymentMode,
        transactionRef: reference,
        screenshotPath: _proofPath!,
        screenshotName: _proofName ?? 'payment-proof',
        selectedMonthNames:
            _isTuition ? _unpaidMonthNames.where(_selectedMonthNames.contains).toList() : const [],
        selectedMonths: _isTuition ? _selectedMonthNames.length : 0,
        selectedTerms: 0,
        remarks: _remarksController.text.trim(),
      );
      final requestReference = '${request['request_reference'] ?? ''}'.trim();
      final proofUrl = '${request['proof_url'] ?? ''}'.trim();
      if (requestReference.isNotEmpty) references.add(requestReference);
      if (proofUrl.isEmpty) {
        throw StateError(
          'Payment proof was submitted, but the saved proof could not be confirmed.',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'UPI proof submitted. Fees will be updated after principal verification.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(
        context,
        ParentPaymentRequestFormResult(
          submittedCount: 1,
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

  Future<bool> _confirmSubmission() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit payment proof?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Amount', 'INR ${_payableAmount.toStringAsFixed(0)}'),
            _confirmRow(
              'Invoice',
              _text(
                _selectedFee['invoice_number'],
                fallback: _text(_selectedFee['id']),
              ),
            ),
            if (_isTuition)
              _confirmRow(
                'Months',
                _unpaidMonthNames.where(_selectedMonthNames.contains).join(', '),
              ),
            _confirmRow('UTR', _utrController.text.trim()),
            _confirmRow('Proof', _proofName ?? 'Selected proof'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Review'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value, style: GoogleFonts.dmSans())),
        ],
      ),
    );
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

  String _absoluteMediaUrl(String value, {String cacheKey = ''}) {
    final trimmed = value.trim();
    final base = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : trimmed.startsWith('/')
        ? '${EnvConfig.apiOrigin}$trimmed'
        : '${EnvConfig.apiOrigin}/$trimmed';
    if (cacheKey.trim().isEmpty) return base;
    final uri = Uri.parse(base);
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'cache_key': cacheKey.trim(),
          },
        )
        .toString();
  }

  String _paymentModeLabel(String mode) {
    return 'UPI';
  }
}

String _dateInput(DateTime dt) =>
    '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

String _two(int value) => value.toString().padLeft(2, '0');

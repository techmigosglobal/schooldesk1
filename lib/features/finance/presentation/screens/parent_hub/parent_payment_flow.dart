import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class ParentPaymentFlow extends StatefulWidget {
  final ParentPaymentSelectionArgs args;

  const ParentPaymentFlow({super.key, required this.args});

  @override
  State<ParentPaymentFlow> createState() => _ParentPaymentFlowState();
}

class _ParentPaymentFlowState extends State<ParentPaymentFlow> {
  int _currentStep = 1; // 1: Confirm, 2: Pay, 3: Done
  bool _loadingConfig = true;
  bool _creatingIntent = false;
  bool _submitting = false;

  Map<String, dynamic> _paymentConfig = const {};
  Map<String, dynamic>? _paymentIntent;

  final Set<String> _selectedMonthNames = <String>{};
  final _remarksController = TextEditingController();
  final _utrController = TextEditingController();

  String? _proofName;
  String? _proofPath;
  String? _configError;

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

  static const List<String> _monthNames = [
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
    'January',
    'February',
    'March',
  ];

  List<String> get _allowedMonthNames {
    final configured =
        (_selectedFee['allowed_month_names'] is List
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

  List<String> get _unpaidMonthNames => _allowedMonthNames
      .where((month) => !_paidMonthNames.contains(month))
      .toList(growable: false);

  double get _totalAmount {
    final balance = (_selectedFee['amount'] as num?)?.toDouble() ?? 0.0;
    if (_isTuition) {
      final monthly =
          (_selectedFee['monthly_amount'] as num?)?.toDouble() ??
          (balance / 10);
      return monthly * _selectedMonthNames.length;
    }
    return balance;
  }

  String get _upiId => _text(_paymentConfig['upi_id']);
  String get _payeeName =>
      _text(_paymentConfig['payee_name'], fallback: 'School');

  Map<String, dynamic> get _resubmissionRequest =>
      widget.args.paymentRequest == null
      ? const <String, dynamic>{}
      : Map<String, dynamic>.from(widget.args.paymentRequest!);

  bool get _isClarificationResubmit =>
      _text(_resubmissionRequest['status']).toLowerCase() ==
      'clarification_required';

  String get _intentId => _text(_paymentIntent?['id']);
  String get _intentReference => _text(_paymentIntent?['request_reference']);

  @override
  void initState() {
    super.initState();
    if (_isClarificationResubmit) {
      _utrController.text = _text(_resubmissionRequest['transaction_id']);
      _currentStep = 2; // Jump to payment step for clarification resubmission
    }
    _seedMonthSelection();
    _loadPaymentConfig(forceRefresh: true);
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _utrController.dispose();
    super.dispose();
  }

  void _seedMonthSelection() {
    _selectedMonthNames.clear();
    if (_isTuition && _unpaidMonthNames.isNotEmpty) {
      _selectedMonthNames.add(_unpaidMonthNames.first);
    }
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
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _configError = e.toString();
        _loadingConfig = false;
      });
    }
  }

  Future<void> _proceedToPay() async {
    if (_fees.isEmpty) return;
    if (_isTuition && _selectedMonthNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one month to pay.'),
        ),
      );
      return;
    }

    setState(() => _creatingIntent = true);
    try {
      final intent = await BackendApiClient.instance.createFeePaymentIntent(
        invoiceId: '${_selectedFee['id']}',
        paymentMethod: 'upi',
        selectedMonthNames: _isTuition
            ? _selectedMonthNames.toList()
            : const [],
        selectedMonths: _isTuition ? _selectedMonthNames.length : 0,
        selectedTerms: 0,
        remarks: _remarksController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _paymentIntent = intent;
        _creatingIntent = false;
        _currentStep = 2;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _creatingIntent = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparing payment: $error'),
            backgroundColor: context.appTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickProofFile() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _proofName = image.name;
          _proofPath = image.path;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick file: $e')));
      }
    }
  }

  Future<void> _submitPaymentProof() async {
    if (_proofPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your payment screenshot proof.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = BackendApiClient.instance;
      if (_isClarificationResubmit) {
        await api.resubmitFeePaymentProof(
          id: _text(_resubmissionRequest['id']),
          transactionRef: _utrController.text.trim(),
          screenshotPath: _proofPath!,
          screenshotName: _proofName!,
          remarks: _remarksController.text.trim(),
        );
      } else {
        await api.submitFeePaymentProof(
          studentFeeId: _text(_selectedFee['id']),
          paymentRequestId: _intentId,
          requestReference: _intentReference,
          amount: _totalAmount,
          paymentMethod: 'upi',
          transactionRef: _utrController.text.trim(),
          screenshotPath: _proofPath!,
          screenshotName: _proofName!,
          selectedMonthNames: _isTuition
              ? _selectedMonthNames.toList()
              : const [],
          selectedMonths: _isTuition ? _selectedMonthNames.length : 0,
          remarks: _remarksController.text.trim(),
        );
      }
      if (!mounted) return;
      try {
        final studentName = _text(
          widget.args.student?['name'],
          fallback: 'A student',
        );
        final amount = _totalAmount.toString();
        NotificationService.getInstance().then(
          (s) => s.triggerFeePaymentAlert(
            studentName: studentName,
            amount: amount,
            paymentMode: 'UPI',
          ),
        );
      } on Object catch (_) {}

      setState(() {
        _submitting = false;
        _currentStep = 3;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: context.appTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.surface,
      appBar: AppBar(
        title: Text(
          _isClarificationResubmit ? 'Resubmit Payment Proof' : 'Pay Fee',
          style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.appTheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepIndicator(),
            const Divider(height: 1),
            Expanded(
              child: _loadingConfig
                  ? const Center(child: CircularProgressIndicator())
                  : _configError != null
                  ? _buildConfigError()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildCurrentStepView(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: context.appTheme.surfaceVariant.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stepNode(
            1,
            'Confirm',
            isActive: _currentStep >= 1,
            isCompleted: _currentStep > 1,
          ),
          _stepDivider(isActive: _currentStep > 1),
          _stepNode(
            2,
            'Pay',
            isActive: _currentStep >= 2,
            isCompleted: _currentStep > 2,
          ),
          _stepDivider(isActive: _currentStep > 2),
          _stepNode(
            3,
            'Done',
            isActive: _currentStep >= 3,
            isCompleted: _currentStep > 3,
          ),
        ],
      ),
    );
  }

  Widget _stepNode(
    int index,
    String label, {
    required bool isActive,
    required bool isCompleted,
  }) {
    final activeColor = const Color(0xFF1A6B4A);
    final color = isCompleted
        ? activeColor
        : isActive
        ? activeColor
        : context.appTheme.muted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '$index',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _stepDivider({required bool isActive}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: isActive
            ? const Color(0xFF1A6B4A)
            : context.appTheme.outlineVariant,
      ),
    );
  }

  Widget _buildConfigError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: context.appTheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'UPI Payment Unconfigured',
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The school has not completed the payment configuration setup. Please contact the administrator.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(color: context.appTheme.muted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _loadPaymentConfig(forceRefresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
      default:
        return _buildStep3();
    }
  }

  Widget _buildStep1() {
    final componentName = _selectedFee['component'] ?? 'Fee Component';
    final amountDue = (_selectedFee['amount'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          componentName,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appTheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _infoRow('Total Outstanding', _money(amountDue)),
              if (_isTuition) ...[
                const Divider(height: 24),
                _infoRow(
                  'Monthly Rate',
                  _money(
                    (_selectedFee['monthly_amount'] as num?)?.toDouble() ??
                        amountDue / 10,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_isTuition) ...[
          const SizedBox(height: 20),
          Text(
            'Select Months to Pay',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Installments must be paid continuously from the first unpaid month.',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: context.appTheme.muted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _unpaidMonthNames.map((month) {
              final isSelected = _selectedMonthNames.contains(month);
              final selectedInOrder = _unpaidMonthNames
                  .where(_selectedMonthNames.contains)
                  .toList(growable: false);
              final nextMonth =
                  selectedInOrder.length < _unpaidMonthNames.length
                  ? _unpaidMonthNames[selectedInOrder.length]
                  : null;
              final canAdd = !isSelected && month == nextMonth;
              final canRemove =
                  isSelected &&
                  selectedInOrder.length > 1 &&
                  selectedInOrder.last == month;
              return FilterChip(
                selected: isSelected,
                label: Text(month),
                onSelected: canAdd || canRemove
                    ? (val) {
                        setState(() {
                          if (val) {
                            _selectedMonthNames.add(month);
                          } else if (canRemove) {
                            _selectedMonthNames.remove(month);
                          }
                        });
                      }
                    : null,
                selectedColor: const Color(0xFF1A6B4A).withOpacity(0.15),
                checkmarkColor: const Color(0xFF1A6B4A),
                labelStyle: GoogleFonts.ibmPlexSans(
                  color: isSelected
                      ? const Color(0xFF1A6B4A)
                      : context.appTheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ],
        if (!_isTuition) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appTheme.warningContainer.withAlpha(90),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appTheme.warning.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: context.appTheme.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_selectedFee['component'] ?? 'This fee'} is payable as one full amount. Month selection is only available for tuition.',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      height: 1.35,
                      color: context.appTheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appTheme.primaryContainer.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appTheme.primary.withAlpha(40)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isTuition
                    ? 'Paying for ${_selectedMonthNames.length} month(s)'
                    : 'Book & Kit: one-time payment',
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.primary,
                ),
              ),
              Text(
                _money(_totalAmount),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.appTheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _creatingIntent ? null : _proceedToPay,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6B4A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: _creatingIntent
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Continue to Pay',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appTheme.surfaceVariant.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appTheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay to School UPI ID',
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Copy the UPI ID and complete payment manually in your own UPI app. Then submit the UTR and screenshot below.',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        color: context.appTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 54),
              const SizedBox(height: 12),
              SelectableText(
                _upiId,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Payee: $_payeeName',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: context.appTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _upiId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'UPI ID copied. Complete payment manually in your UPI app.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy UPI ID'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A6B4A),
                  side: const BorderSide(color: Color(0xFF1A6B4A)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 20),
        Text(
          'Enter Transaction Proof',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _utrController,
          decoration: InputDecoration(
            labelText: 'UTR / Transaction Reference (Optional)',
            hintText: 'Enter 12-digit UPI reference number',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.bookmark_added_rounded),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickProofFile,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: context.appTheme.surfaceVariant.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _proofPath != null
                    ? const Color(0xFF1A6B4A)
                    : context.appTheme.outlineVariant,
                style: _proofPath != null
                    ? BorderStyle.solid
                    : BorderStyle.none,
                width: _proofPath != null ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _proofPath != null
                      ? Icons.check_circle_rounded
                      : Icons.add_photo_alternate_rounded,
                  color: _proofPath != null
                      ? const Color(0xFF1A6B4A)
                      : context.appTheme.muted,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _proofPath != null
                            ? 'Screenshot Uploaded'
                            : 'Upload Payment Screenshot *',
                        style: GoogleFonts.ibmPlexSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _proofPath != null
                              ? const Color(0xFF1A6B4A)
                              : context.appTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _proofPath != null
                            ? '$_proofName'
                            : 'JPEG, PNG format accepted',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 11,
                          color: context.appTheme.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_proofPath != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _proofPath = null;
                        _proofName = null;
                      });
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submitPaymentProof,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6B4A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Submit Verification Request — ${_money(_totalAmount)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 54,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Payment Request Submitted!',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We have received your proof for ${_money(_totalAmount)}. The principal will review your submission shortly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(
                color: context.appTheme.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appTheme.surfaceVariant.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appTheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(
                    'Status',
                    'Pending Verification',
                    valColor: context.appTheme.warning,
                  ),
                  if (_intentReference.isNotEmpty) ...[
                    const Divider(height: 20),
                    _infoRow('Reference ID', _intentReference),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A6B4A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Back to Fees'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                  Navigator.pushNamed(context, '/parent/payment-history');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A6B4A),
                  side: const BorderSide(color: Color(0xFF1A6B4A)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('View Payment History'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: context.appTheme.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valColor ?? context.appTheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  String _text(dynamic value, {dynamic fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return '${fallback ?? ''}'.trim();
    return text;
  }

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';
}

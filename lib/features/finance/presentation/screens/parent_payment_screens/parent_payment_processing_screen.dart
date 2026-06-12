import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:schooldesk1/features/finance/presentation/screens/parent_payment_screens/parent_payment_success_screen.dart';
import 'package:schooldesk1/features/finance/data/datasources/parent_fees_remote_datasource.dart';
import 'package:schooldesk1/features/finance/data/models/payment_models.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

class ParentPaymentProcessingScreen extends StatefulWidget {
  final List<String> selectedInvoiceIds;
  final double totalAmount;
  final Map<String, dynamic>? student;

  const ParentPaymentProcessingScreen({
    super.key,
    required this.selectedInvoiceIds,
    required this.totalAmount,
    this.student,
  });

  @override
  State<ParentPaymentProcessingScreen> createState() =>
      _ParentPaymentProcessingScreenState();
}

class _ParentPaymentProcessingScreenState
    extends State<ParentPaymentProcessingScreen> {
  late Razorpay _razorpay;
  late ParentFeesRemoteDataSource _datasource;

  String _statusMessage = 'Initializing secure connection...';
  double _progress = 0.2;
  bool _hasError = false;
  String _errorMessage = '';
  
  String? _paymentOrderId;
  String? _razorpayOrderId;

  @override
  void initState() {
    super.initState();
    _datasource = ParentFeesRemoteDataSourceImpl();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    
    _startPaymentProcess();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _startPaymentProcess() async {
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _statusMessage = 'Initializing secure connection...';
      _progress = 0.2;
    });

    try {
      // 0. Fetch payment configuration from backend
      final config = await _datasource.getPaymentConfig();
      final razorpayEnabled = config['razorpay_enabled'] as bool? ?? false;
      final razorpayKey = config['razorpay_key_id'] as String? ?? '';

      if (!razorpayEnabled || razorpayKey.isEmpty) {
        throw Exception("Razorpay online payments are not enabled on the server.");
      }

      setState(() {
        _statusMessage = 'Creating order...';
        _progress = 0.4;
      });

      // 1. Create Order on Backend
      final orderResponse = await _datasource.createRazorpayOrder(
        CreateRazorpayOrderRequest(invoiceIds: widget.selectedInvoiceIds),
      );

      _paymentOrderId = orderResponse.paymentOrderId;
      _razorpayOrderId = orderResponse.razorpayOrderId;

      setState(() {
        _statusMessage = 'Opening payment gateway...';
        _progress = 0.6;
      });

      // Fetch user profile for prefill details
      String email = '';
      String contact = '';
      try {
        final profile = await BackendApiClient.instance.getProfile();
        email = profile.email;
        contact = profile.phone;
      } catch (_) {}

      // 2. Open Razorpay Checkout
      var options = {
        'key': razorpayKey,
        'amount': (orderResponse.amount * 100).toInt(), // amount in paisa
        'name': 'SchoolDesk',
        'description': 'Fee Payment',
        'order_id': orderResponse.razorpayOrderId,
        'prefill': {
          'contact': contact, 
          'email': email
        }
      };

      _razorpay.open(options);

    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize payment: ${e.toString()}';
          _progress = 0.0;
        });
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() {
      _statusMessage = 'Verifying payment...';
      _progress = 0.8;
    });

    try {
      // 3. Verify Payment on Backend
      await _datasource.verifyRazorpayPayment(
        VerifyRazorpayPaymentRequest(
          paymentOrderId: _paymentOrderId!,
          razorpayOrderId: response.orderId ?? _razorpayOrderId!,
          razorpayPaymentId: response.paymentId!,
          razorpaySignature: response.signature!,
        ),
      );

      setState(() {
        _statusMessage = 'Payment successful!';
        _progress = 1.0;
      });

      // Navigate to Success Screen
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ParentPaymentSuccessScreen(
            transactionId: response.paymentId ?? 'TXN-${DateTime.now().millisecondsSinceEpoch}',
            amountPaid: widget.totalAmount,
            invoiceIds: widget.selectedInvoiceIds,
            date: DateTime.now().toString(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Payment verification failed: ${e.toString()}';
          _progress = 0.0;
        });
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Payment failed: ${response.message ?? "Unknown error"}';
        _progress = 0.0;
      });
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = 'External wallets not supported.';
        _progress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: _hasError
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: context.appTheme.error,
                        size: 80,
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Payment Failed',
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: context.appTheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: context.appTheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _startPaymentProcess,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.appTheme.primary,
                          foregroundColor: context.appTheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Retry Payment',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            color: context.appTheme.muted,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 6,
                          color: context.appTheme.primary,
                          backgroundColor: context.appTheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Processing Payment',
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: context.appTheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: context.appTheme.muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 8,
                          backgroundColor: context.appTheme.outlineVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(context.appTheme.primary),
                        ),
                      ),
                      const SizedBox(height: 48),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: context.appTheme.muted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Secure 256-bit SSL Encryption',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: context.appTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

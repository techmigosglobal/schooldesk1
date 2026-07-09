import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/routes/app_routes.dart';

class ParentPaymentHistoryV2 extends StatefulWidget {
  const ParentPaymentHistoryV2({super.key});

  @override
  State<ParentPaymentHistoryV2> createState() => _ParentPaymentHistoryV2State();
}

class _ParentPaymentHistoryV2State extends State<ParentPaymentHistoryV2> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _paymentHistory = [];
  List<Map<String, dynamic>> _childrenData = [];
  int _activeChildIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final children = await BackendApiClient.instance.getMyStudents();
      if (children.isEmpty) {
        setState(() {
          _childrenData = [];
          _paymentHistory = [];
          _loading = false;
        });
        return;
      }
      
      final child = children[_activeChildIndex];
      final studentId = (child['id'] ?? child['student_id'] ?? '').toString();
      
      final invoices = studentId.isEmpty
          ? <Map<String, dynamic>>[]
          : await BackendApiClient.instance.getInvoices(studentId: studentId);
      final paymentRequests = studentId.isEmpty
          ? <Map<String, dynamic>>[]
          : await BackendApiClient.instance.getParentPaymentRequests(studentId: studentId);

      final List<Map<String, dynamic>> historyList = [];

      for (final inv in invoices) {
        final payments = inv['payments'];
        if (payments is List) {
          for (final p in payments.whereType<Map>()) {
            final payment = Map<String, dynamic>.from(p);
            historyList.add({
              'id': payment['id'] ?? '',
              'invoiceId': inv['id'] ?? '',
              'component': 'Invoice ${inv['invoice_number'] ?? ''}',
              'amount': (payment['amount_paid'] as num?)?.toDouble() ?? 0.0,
              'date': (payment['payment_date'] ?? '').toString(),
              'method': (payment['payment_mode'] ?? '').toString(),
              'receiptNo': (payment['receipt_number'] ?? '').toString(),
              'student': _studentName(child),
              'class': _studentClass(child),
              'rollNo': _studentRoll(child),
              'status': 'Paid',
              'rawStatus': 'completed',
            });
          }
        }
      }

      for (final request in paymentRequests) {
        final invoice = request['invoice'] is Map
            ? Map<String, dynamic>.from(request['invoice'] as Map)
            : invoices.firstWhere(
                (inv) => '${inv['id']}' == '${request['invoice_id']}',
                orElse: () => const <String, dynamic>{},
              );
        historyList.add({
          'id': request['id'] ?? '',
          'invoiceId': request['invoice_id'] ?? '',
          'component': 'Invoice ${invoice['invoice_number'] ?? request['invoice_id'] ?? ''}',
          'amount': (request['amount'] as num?)?.toDouble() ?? 0.0,
          'date': (request['payment_date'] ?? request['created_at'] ?? '').toString(),
          'method': (request['payment_mode'] ?? '').toString(),
          'receiptNo': (request['request_reference'] ?? '').toString(),
          'student': _studentName(child),
          'class': _studentClass(child),
          'rollNo': _studentRoll(child),
          'status': _paymentStatusLabel(request['status']),
          'rawStatus': '${request['status'] ?? ''}'.toLowerCase(),
          'paymentRequest': Map<String, dynamic>.from(request),
        });
      }

      historyList.sort(
        (a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()),
      );

      setState(() {
        _childrenData = children;
        _paymentHistory = historyList;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Payment History',
      subtitle: 'Timeline of your online payments and approvals',
      drawer: ParentDrawer(
        selectedIndex: ParentNav.fees,
        onDestinationSelected: (_) {},
      ),
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.parent),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_childrenData.length > 1) ...[
                        _buildChildSelector(),
                        const SizedBox(height: 16),
                      ],
                      if (_paymentHistory.isEmpty)
                        _buildEmptyState()
                      else
                        ..._paymentHistory.map((item) => _buildHistoryCard(item)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildChildSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_childrenData.length, (i) {
          final isActive = i == _activeChildIndex;
          return GestureDetector(
            onTap: () {
              if (isActive) return;
              setState(() {
                _activeChildIndex = i;
              });
              _loadHistory();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF1A6B4A) : context.appTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: isActive ? null : Border.all(color: context.appTheme.outlineVariant),
              ),
              child: Text(
                _studentName(_childrenData[i]).split(' ').first,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : context.appTheme.onSurface,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: context.appTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error Loading Payments',
              style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(color: context.appTheme.muted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 64, color: context.appTheme.muted),
            const SizedBox(height: 16),
            Text(
              'No Payment Records',
              style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Once you initiate payments or submit screenshot proofs, they will appear in this timeline.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSans(color: context.appTheme.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final status = _text(item['status']);
    final rawStatus = _text(item['rawStatus']);
    final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final dateStr = _formatDate(_text(item['date']));
    final reference = _text(item['receiptNo']);
    final method = _text(item['method'], fallback: 'UPI');

    Color statusColor = context.appTheme.warning;
    Color statusBg = context.appTheme.warningContainer;
    IconData statusIcon = Icons.pending_actions_rounded;

    if (rawStatus == 'completed' || rawStatus == 'approved' || status == 'Paid') {
      statusColor = context.appTheme.success;
      statusBg = context.appTheme.successContainer;
      statusIcon = Icons.check_circle_rounded;
    } else if (rawStatus == 'clarification_required') {
      statusColor = context.appTheme.info;
      statusBg = context.appTheme.infoContainer;
      statusIcon = Icons.help_outline_rounded;
    } else if (rawStatus == 'rejected') {
      statusColor = context.appTheme.error;
      statusBg = context.appTheme.errorContainer;
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['component'],
                      style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paid via ${method.toUpperCase()} · $dateStr',
                      style: GoogleFonts.ibmPlexSans(fontSize: 11, color: context.appTheme.muted),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ref: $reference',
                style: GoogleFonts.ibmPlexSans(fontSize: 12, color: context.appTheme.muted),
              ),
              if (rawStatus == 'completed' || rawStatus == 'approved' || status == 'Paid')
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/parent/receipt',
                      arguments: ParentPaymentSelectionArgs(
                        fees: const [],
                        student: _childrenData[_activeChildIndex],
                        paymentRequest: item['paymentRequest'],
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_rounded, size: 14),
                  label: const Text('Receipt'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A6B4A),
                    side: const BorderSide(color: Color(0xFF1A6B4A)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                )
              else if (rawStatus == 'clarification_required')
                FilledButton.icon(
                  onPressed: () => _openClarificationResubmit(item),
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Resubmit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.appTheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openClarificationResubmit(Map<String, dynamic> payment) async {
    final invoiceId = _text(payment['invoiceId']);
    final request = payment['paymentRequest'] is Map
        ? Map<String, dynamic>.from(payment['paymentRequest'] as Map)
        : <String, dynamic>{};
    
    final student = _childrenData.isEmpty ? null : Map<String, dynamic>.from(_childrenData[_activeChildIndex]);
    final result = await Navigator.pushNamed(
      context,
      '/parent/payment-flow',
      arguments: ParentPaymentSelectionArgs(
        fees: [
          {
            'id': invoiceId,
            'component': payment['component'],
            'amount': payment['amount'],
            'fee_type': 'tuition',
          }
        ],
        student: student,
        paymentRequest: request,
      ),
    );
    if (result != null) {
      _loadHistory();
    }
  }

  String _studentClass(Map<String, dynamic> student) =>
      '${student['class'] ?? student['class_name'] ?? student['current_section_id'] ?? ''}';

  String _studentRoll(Map<String, dynamic> student) =>
      '${student['rollNo'] ?? student['roll_no'] ?? student['student_code'] ?? ''}';

  String _text(dynamic value, {dynamic fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return '${fallback ?? ''}'.trim();
    return text;
  }

  String _paymentStatusLabel(dynamic raw) {
    switch ('${raw ?? ''}'.toLowerCase()) {
      case 'initiated':
      case 'payment_app_opened':
        return 'Initiated';
      case 'pending_verification':
      case 'submitted':
        return 'Pending Verification';
      case 'clarification_required':
        return 'Clarification Required';
      case 'approved':
      case 'completed':
      case 'paid':
        return 'Paid';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  String _studentName(Map<String, dynamic> student) {
    final name = '${student['name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    return '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim();
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.isEmpty ? '-' : raw;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }
}

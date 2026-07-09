import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';

class PrincipalFeeDashboard extends StatefulWidget {
  const PrincipalFeeDashboard({super.key});

  @override
  State<PrincipalFeeDashboard> createState() => _PrincipalFeeDashboardState();
}

class _PrincipalFeeDashboardState extends State<PrincipalFeeDashboard> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _feeStructures = const [];
  List<Map<String, dynamic>> _invoices = const [];
  List<Map<String, dynamic>> _recentPayments = const [];
  List<Map<String, dynamic>> _concessions = const [];
  
  double _outstandingTotal = 0.0;
  double _collectedTotal = 0.0;
  int _pendingRequestsCount = 0;

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
        api.getFeeStructures(),
        api.getInvoices(pageSize: 1000),
        api.getParentPaymentRequests(pageSize: 500),
        api.getRawList('/fees/concessions'),
      ]);

      final structures = (results[0] as List)
          .cast<Map<String, dynamic>>()
          .map(normalizeFeeStructure)
          .toList();
      final invoices = (results[1] as List)
          .cast<Map<String, dynamic>>()
          .map(normalizeInvoice)
          .toList();
      final payments = invoices.expand(normalizePayments).toList()
        ..sort((a, b) => '${b['date'] ?? ''}'.compareTo('${a['date'] ?? ''}'));

      final requests = (results[2] as List)
          .cast<Map<String, dynamic>>()
          .where((r) => '${r['status']}'.toLowerCase() == 'pending' || '${r['status']}'.toLowerCase() == 'pending_verification')
          .toList();

      final concessions = (results[3] as List).cast<Map<String, dynamic>>();

      double outstanding = 0.0;
      for (final inv in invoices) {
        outstanding += (inv['balance'] as num?)?.toDouble() ?? 0.0;
      }

      double collected = 0.0;
      for (final p in payments) {
        collected += (p['amount'] as num?)?.toDouble() ?? 0.0;
      }

      if (!mounted) return;
      setState(() {
        _feeStructures = structures;
        _invoices = invoices;
        _recentPayments = payments;
        _concessions = concessions;
        _outstandingTotal = outstanding;
        _collectedTotal = collected;
        _pendingRequestsCount = requests.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load dashboard data: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawer = PrincipalDrawer(
      selectedIndex: PrincipalNav.fees,
      onDestinationSelected: (_) {},
    );

    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Fee Operations',
        subtitle: 'Key metrics and shortcuts for fee collection',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SchoolDeskModuleScaffold(
        title: 'Fee Operations',
        subtitle: 'Key metrics and shortcuts for fee collection',
        drawer: drawer,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSans(color: context.appTheme.onSurface),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totalTarget = _collectedTotal + _outstandingTotal;
    final progressVal = totalTarget > 0 ? (_collectedTotal / totalTarget) : 0.0;

    return SchoolDeskModuleScaffold(
      title: 'Fee Operations',
      subtitle: 'Dashboard analysis and system actions',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.principal),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      actions: [
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildKpiGrid(),
            const SizedBox(height: 16),
            if (_pendingRequestsCount > 0) ...[
              _buildNeedsAttentionCard(),
              const SizedBox(height: 16),
            ],
            Text(
              'Quick Actions',
              style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildQuickActionsGrid(),
            const SizedBox(height: 20),
            Text(
              'Collection Progress',
              style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildProgressCard(progressVal, totalTarget),
            const SizedBox(height: 20),
            Text(
              'Outstanding Aging Analysis',
              style: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildAgingBucketsCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildKpiCard(
          title: 'Outstanding Due',
          value: _money(_outstandingTotal),
          subtitle: '${_invoices.where((i) => (i['balance'] as num?)?.toDouble() != 0).length} invoices',
          icon: Icons.pending_actions_rounded,
          color: Colors.orange,
        ),
        _buildKpiCard(
          title: 'Collected',
          value: _money(_collectedTotal),
          subtitle: '${_recentPayments.length} receipts',
          icon: Icons.check_circle_outline_rounded,
          color: Colors.green,
        ),
        _buildKpiCard(
          title: 'Fee Structures',
          value: '${_feeStructures.length}',
          subtitle: 'Active templates',
          icon: Icons.schema_rounded,
          color: Colors.blue,
        ),
        _buildKpiCard(
          title: 'Concessions',
          value: '${_concessions.length}',
          subtitle: 'Assigned accounts',
          icon: Icons.volunteer_activism_rounded,
          color: Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.ibmPlexSans(fontSize: 11, color: context.appTheme.muted, fontWeight: FontWeight.w600),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(fontSize: 18, fontWeight: FontWeight.bold, color: context.appTheme.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.ibmPlexSans(fontSize: 10, color: context.appTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedsAttentionCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.error.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: context.appTheme.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_pendingRequestsCount Payment Requests Pending',
                  style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, color: context.appTheme.error, fontSize: 14),
                ),
                Text(
                  'Parents have submitted manual payment proofs. Review them to record.',
                  style: GoogleFonts.ibmPlexSans(fontSize: 11, color: context.appTheme.onSurface),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/principal/payment-requests');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _actionButton('Fee Structures', Icons.list_alt_rounded, '/principal/fee-structures'),
        _actionButton('Generate Invoices', Icons.receipt_long_rounded, '/principal/invoice-generate'),
        _actionButton('Collect Fee', Icons.add_circle_outline_rounded, '/principal/collect-fee'),
        _actionButton('Reports', Icons.analytics_outlined, '/principal/fee-reports'),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, String route) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: context.appTheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appTheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1A6B4A), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 13, color: context.appTheme.onSurface),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: context.appTheme.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(double progressVal, double target) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Collection Rate: ${(progressVal * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                '${_money(_collectedTotal)} collected of ${_money(target)}',
                style: GoogleFonts.ibmPlexSans(fontSize: 11, color: context.appTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressVal,
              backgroundColor: context.appTheme.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A6B4A)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgingBucketsCard() {
    // Basic mock logic bucketed by date constraints
    final now = DateTime.now();
    int b0to30 = 0;
    int b31to60 = 0;
    int b61plus = 0;

    for (final inv in _invoices) {
      final bal = (inv['balance'] as num?)?.toDouble() ?? 0.0;
      if (bal <= 0) continue;
      final dueStr = inv['due_date']?.toString() ?? '';
      final due = DateTime.tryParse(dueStr);
      if (due == null) {
        b0to30++;
        continue;
      }
      final diff = now.difference(due).inDays;
      if (diff <= 30) {
        b0to30++;
      } else if (diff <= 60) {
        b31to60++;
      } else {
        b61plus++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _agingColumn('0-30 Days', b0to30, Colors.blue),
          _verticalDivider(),
          _agingColumn('31-60 Days', b31to60, Colors.orange),
          _verticalDivider(),
          _agingColumn('61+ Days', b61plus, Colors.red),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(height: 36, width: 1, color: context.appTheme.outlineVariant);
  }

  Widget _agingColumn(String bucket, int count, Color color) {
    return Column(
      children: [
        Text(
          bucket,
          style: GoogleFonts.ibmPlexSans(fontSize: 11, color: context.appTheme.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          '$count invoices',
          style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';
}

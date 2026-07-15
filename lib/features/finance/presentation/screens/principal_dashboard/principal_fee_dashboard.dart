import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart';

class PrincipalFeeDashboard extends StatefulWidget {
  const PrincipalFeeDashboard({super.key});

  @override
  State<PrincipalFeeDashboard> createState() => _PrincipalFeeDashboardState();
}

class _PrincipalFeeDashboardState extends State<PrincipalFeeDashboard>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _feeStructures = const [];
  List<Map<String, dynamic>> _invoices = const [];
  List<Map<String, dynamic>> _recentPayments = const [];
  List<Map<String, dynamic>> _concessions = const [];

  double _outstandingTotal = 0.0;
  double _collectedTotal = 0.0;
  int _pendingRequestsCount = 0;

  late AnimationController _animCtrl;
  late Animation<double> _pieAnimation;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pieAnimation = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
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
          .where(
            (r) =>
                '${r['status']}'.toLowerCase() == 'pending' ||
                '${r['status']}'.toLowerCase() == 'pending_verification',
          )
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
      _animCtrl.forward(from: 0);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load dashboard data: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openInvoiceGenerator() async {
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait([
        api.getAcademicYears(),
        api.getGrades(),
        api.getSections(),
        api.getStudents(page: 1, pageSize: 1000),
        api.getFeeStructures(),
      ]);
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        '/principal/invoice-generate',
        arguments: AdminInvoiceGenerationFormArgs(
          academicYears: results[0] as List<AcademicYearModel>,
          grades: results[1] as List<GradeModel>,
          sections: results[2] as List<SectionModel>,
          students: (results[3] as PaginatedList<StudentModel>).data,
          feeStructures: results[4] as List<Map<String, dynamic>>,
          ownerRole: 'principal',
        ),
      );
      _loadData();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load invoice references: $error')),
      );
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
                  style: GoogleFonts.ibmPlexSans(
                    color: context.appTheme.onSurface,
                  ),
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
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      actions: [
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6FAFF), Color(0xFFFFF8F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: RefreshIndicator(
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
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildQuickActionsGrid(),
              const SizedBox(height: 20),
              Text(
                'Collection Progress',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildPieChartCard(progressVal, totalTarget),
              const SizedBox(height: 20),
              Text(
                'Outstanding Aging Analysis',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildAgingBucketsCard(),
              const SizedBox(height: 32),
            ],
          ),
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
      // Keep the overview compact: these cards are navigation summaries, not
      // large dashboard panels. A wider ratio also keeps the next actions
      // visible without an unnecessary scroll on a phone.
      childAspectRatio: 1.82,
      children: [
        _buildKpiCard(
          title: 'Outstanding Due',
          value: _money(_outstandingTotal),
          subtitle:
              '${_invoices.where((i) => (i['balance'] as num?)?.toDouble() != 0).length} invoices',
          icon: Icons.pending_actions_rounded,
          gradientColors: [const Color(0xFFF97316), const Color(0xFFFB923C)],
          route: '/principal/collect-fee',
        ),
        _buildKpiCard(
          title: 'Collected',
          value: _money(_collectedTotal),
          subtitle: '${_recentPayments.length} receipts',
          icon: Icons.check_circle_outline_rounded,
          gradientColors: [const Color(0xFF16A34A), const Color(0xFF22C55E)],
          route: '/principal/fee-reports',
        ),
        _buildKpiCard(
          title: 'Fee Structures',
          value: '${_feeStructures.length}',
          subtitle: 'Active templates',
          icon: Icons.schema_rounded,
          gradientColors: [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
          route: '/principal/fee-structures',
        ),
        _buildKpiCard(
          title: 'Concessions',
          value: '${_concessions.length}',
          subtitle: 'Assigned accounts',
          icon: Icons.volunteer_activism_rounded,
          gradientColors: [const Color(0xFF7C3AED), const Color(0xFF8B5CF6)],
          route: null, // No dedicated route yet — show info
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    String? route,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: route != null
            ? () => Navigator.pushNamed(context, route)
            : () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title: $value $subtitle'),
                  behavior: SnackBarBehavior.floating,
                ),
              ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, color: Colors.white, size: 15),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      subtitle,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 9,
                        color: Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    if (route != null)
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: Colors.white60,
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
          Icon(
            Icons.warning_amber_rounded,
            color: context.appTheme.error,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_pendingRequestsCount Payment Requests Pending',
                  style: GoogleFonts.ibmPlexSans(
                    fontWeight: FontWeight.bold,
                    color: context.appTheme.error,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Parents have submitted manual payment proofs. Review them to record.',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    color: context.appTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/principal/payment-requests'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Review',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    const actions = [
      (
        label: 'Fee Structures',
        icon: Icons.list_alt_rounded,
        route: '/principal/fee-structures',
        color: Color(0xFF2563EB),
      ),
      (
        label: 'Generate Invoices',
        icon: Icons.receipt_long_rounded,
        route: '/principal/invoice-generate',
        color: Color(0xFF7C3AED),
      ),
      (
        label: 'Collect Fee',
        icon: Icons.add_circle_outline_rounded,
        route: '/principal/collect-fee',
        color: Color(0xFF16A34A),
      ),
      (
        label: 'Reports',
        icon: Icons.analytics_outlined,
        route: '/principal/fee-reports',
        color: Color(0xFFF97316),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.3,
      children: actions
          .map((a) => _actionButton(a.label, a.icon, a.route, a.color))
          .toList(),
    );
  }

  Widget _actionButton(String label, IconData icon, String route, Color color) {
    return InkWell(
      onTap: route == '/principal/invoice-generate'
          ? _openInvoiceGenerator
          : () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.22), color.withOpacity(0.09)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.28)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: context.appTheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: color.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pie Chart ─────────────────────────────────────────────────────────────

  Widget _buildPieChartCard(double progressVal, double target) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pie chart
          AnimatedBuilder(
            animation: _pieAnimation,
            builder: (context, _) {
              return SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _PieChartPainter(
                    collected: _collectedTotal,
                    outstanding: _outstandingTotal,
                    progress: _pieAnimation.value,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(progressVal * 100 * _pieAnimation.value).toStringAsFixed(0)}%',
                          style: GoogleFonts.ibmPlexSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                        Text(
                          'Collected',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 9,
                            color: context.appTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 20),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Collection Rate',
                  style: GoogleFonts.ibmPlexSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                _legendRow(
                  color: const Color(0xFF16A34A),
                  label: 'Collected',
                  value: _money(_collectedTotal),
                ),
                const SizedBox(height: 10),
                _legendRow(
                  color: const Color(0xFFF97316),
                  label: 'Outstanding',
                  value: _money(_outstandingTotal),
                ),
                if (target > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Target: ${_money(target)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: context.appTheme.muted,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildAgingBucketsCard() {
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _agingColumn('0–30 Days', b0to30, const Color(0xFF3B82F6)),
          _verticalDivider(),
          _agingColumn('31–60 Days', b31to60, const Color(0xFFF97316)),
          _verticalDivider(),
          _agingColumn('61+ Days', b61plus, const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _verticalDivider() =>
      Container(height: 36, width: 1, color: context.appTheme.outlineVariant);

  Widget _agingColumn(String bucket, int count, Color color) {
    return Column(
      children: [
        Text(
          bucket,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            color: context.appTheme.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          'invoices',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 10,
            color: context.appTheme.muted,
          ),
        ),
      ],
    );
  }

  String _money(double amount) => '₹${amount.toStringAsFixed(0)}';
}

// ── Pie Chart Painter ─────────────────────────────────────────────────────────

class _PieChartPainter extends CustomPainter {
  final double collected;
  final double outstanding;
  final double progress;

  const _PieChartPainter({
    required this.collected,
    required this.outstanding,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    final total = collected + outstanding;
    if (total <= 0) {
      // Draw a grey full circle when no data
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.grey.shade200;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    // Background ring
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.grey.shade100;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Outstanding arc (full background, warm orange)
    final outstandingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFFFED7AA);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      outstandingPaint,
    );

    // Collected arc (on top, green)
    final collectedFraction = total > 0 ? (collected / total) : 0.0;
    final collectedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF16A34A);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * collectedFraction * progress,
      false,
      collectedPaint,
    );

    // Dot at the end of collected arc
    if (collectedFraction > 0.02) {
      final angle = -math.pi / 2 + 2 * math.pi * collectedFraction * progress;
      final dotCenter = Offset(
        center.dx + (radius - strokeWidth / 2) * math.cos(angle),
        center.dy + (radius - strokeWidth / 2) * math.sin(angle),
      );
      canvas.drawCircle(dotCenter, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        dotCenter,
        5,
        Paint()
          ..color = const Color(0xFF16A34A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter old) =>
      old.collected != collected ||
      old.outstanding != outstanding ||
      old.progress != progress;
}

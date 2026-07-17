/// Principal Fee Home — the unified hub replacing the former 5,800-line monolith.
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_widgets.dart';

class FeeHomeScreen extends StatefulWidget {
  const FeeHomeScreen({super.key});
  @override
  State<FeeHomeScreen> createState() => _FeeHomeScreenState();
}

class _FeeHomeScreenState extends State<FeeHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = true;
  String? _error;
  String _selectedAcademicYearId = '';

  List<Map<String, dynamic>> _feeStructures = const [];
  List<Map<String, dynamic>> _invoices = const [];
  List<Map<String, dynamic>> _recentPayments = const [];
  List<Map<String, dynamic>> _paymentRequests = const [];
  List<AcademicYearModel> _academicYears = const [];
  List<GradeModel> _grades = const [];
  List<SectionModel> _sections = const [];
  Map<String, dynamic> _paymentConfig = const {};

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
        api.getInvoices(pageSize: 500),
        api.getAcademicYears(),
        api.getGrades(),
        api.getSections(),
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
        ..sort((a, b) => _sortDate(b['date']).compareTo(_sortDate(a['date'])));

      List<Map<String, dynamic>> prList = const [];
      try {
        prList = (await api.getParentPaymentRequests())
            .whereType<Map<String, dynamic>>()
            .where((r) => _isPendingRequest(r))
            .toList();
      } on Object catch (_) {}

      Map<String, dynamic> paymentConfig = const {};
      try {
        paymentConfig = await api.getPaymentConfig();
      } on Object catch (_) {}

      if (!mounted) return;
      final years = results[2] as List<AcademicYearModel>;
      final selectedYear = _selectedAcademicYearId.isNotEmpty
          ? _selectedAcademicYearId
          : (years.firstWhereOrNull((y) => y.isCurrent)?.id ??
                (years.isEmpty ? '' : years.first.id));

      setState(() {
        _feeStructures = structures;
        _invoices = invoices;
        _recentPayments = payments;
        _paymentRequests = prList;
        _academicYears = years;
        _grades = results[3] as List<GradeModel>;
        _sections = results[4] as List<SectionModel>;
        _paymentConfig = paymentConfig;
        _selectedAcademicYearId = selectedYear;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load fee data. $error';
        _loading = false;
      });
    }
  }

  // ── Computed properties ───────────────────────────────────────────────────

  List<_FeeBundle> get _bundles {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final s in _feeStructures) {
      final key =
          '${s['grade_id']}::${s['academic_year_id']}::${s['section_id']}';
      map.putIfAbsent(key, () => []).add(s);
    }
    return map.entries.map((entry) {
      final rows = entry.value;
      final first = rows.first;
      final grade = _grades.firstWhereOrNull((g) => g.id == first['grade_id']);
      final section = _sections.firstWhereOrNull(
        (s) => s.id == first['section_id'],
      );
      final year = _academicYears.firstWhereOrNull(
        (y) => y.id == first['academic_year_id'],
      );
      return _FeeBundle(
        id: rows.map((r) => '${r['id']}').join(','),
        gradeId: '${first['grade_id'] ?? ''}',
        sectionId: '${first['section_id'] ?? ''}',
        academicYearId: '${first['academic_year_id'] ?? ''}',
        title: rows
            .map((r) => textValue(r['category'], fallback: 'Fee'))
            .join(' + '),
        classLabel: grade != null
            ? grade.gradeName
            : textValue(first['grade_id']),
        sectionLabel: section != null ? section.sectionName : 'All',
        academicYearLabel: year != null
            ? year.yearLabel
            : textValue(first['academic_year_id']),
        total: rows.fold<double>(0, (sum, r) => sum + numValue(r['amount'])),
      );
    }).toList();
  }

  List<_FeeStudentView> get _studentAccounts {
    final map = <String, _FeeStudentView>{};
    for (final inv in _invoices) {
      final sid = textValue(
        inv['student_id'],
        fallback: textValue(inv['name']),
      );
      if (sid.isEmpty) continue;
      final total = numValue(inv['total']);
      final paid = numValue(inv['paid']);
      final balance = numValue(inv['balance']);
      final existing = map[sid];
      if (existing == null) {
        map[sid] = _FeeStudentView(
          name: textValue(inv['name'], fallback: 'Student'),
          classLabel: textValue(inv['class'], fallback: ''),
          total: total,
          paid: paid,
          balance: balance,
        );
      } else {
        map[sid] = _FeeStudentView(
          name: existing.name,
          classLabel: existing.classLabel,
          total: existing.total + total,
          paid: existing.paid + paid,
          balance: existing.balance + balance,
        );
      }
    }
    return map.values.toList()..sort((a, b) => b.balance.compareTo(a.balance));
  }

  double get _totalDue => _studentAccounts.fold(0, (s, a) => s + a.balance);
  double get _totalCollected =>
      _recentPayments.fold(0.0, (s, p) => s + numValue(p['amount']));
  double get _totalExpected => _totalCollected + _totalDue;
  double get _collectionRate =>
      _totalExpected > 0 ? _totalCollected / _totalExpected : 0;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7FAFF),
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.fees,
        onDestinationSelected: (_) {},
      ),
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _loading
              ? _buildSkeleton()
              : (_error != null ? _buildError() : _buildContent()),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < 6; i++)
          Container(
            height: 64,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: context.appTheme.surfaceVariant.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
      ],
    );
  }

  Widget _buildError() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        _header(),
        const SizedBox(height: 80),
        FeeEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Fees unavailable',
          message: _error!,
          actionLabel: 'Retry',
          onAction: _loadData,
        ),
      ],
    );
  }

  Widget _buildContent() {
    final activeBundle = _bundles.isNotEmpty ? _bundles.first : null;
    return FeePage(
      header: _header(),
      children: [
        // ── Academic Year ────────────────────────────────────
        FeeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Academic Year',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.appTheme.muted,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedAcademicYearId.isEmpty
                    ? null
                    : _selectedAcademicYearId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _academicYears
                    .map(
                      (y) => DropdownMenuItem(
                        value: y.id,
                        child: Text(y.yearLabel),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedAcademicYearId = v);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Quick metrics ────────────────────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            FeeMetricTile(
              label: 'Fee Structures',
              value: '${_bundles.length}',
              icon: Icons.assignment_outlined,
              color: const Color(0xFF2563EB),
            ),
            FeeMetricTile(
              label: 'Collected',
              value: money(_totalCollected),
              icon: Icons.account_balance_wallet_outlined,
              color: const Color(0xFF16A34A),
            ),
            FeeMetricTile(
              label: 'Outstanding',
              value: money(_totalDue),
              icon: Icons.pending_actions_outlined,
              color: const Color(0xFFEA580C),
            ),
            FeeMetricTile(
              label: 'Students',
              value: '${_studentAccounts.length}',
              icon: Icons.groups_outlined,
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Collection Progress ──────────────────────────────
        FeeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FeeSectionTitle('Collection Progress'),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: _collectionRate,
                          strokeWidth: 10,
                          backgroundColor: const Color(0xFFFEE2E2),
                          color: const Color(0xFF16A34A),
                        ),
                        Center(
                          child: Text(
                            '${(_collectionRate * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        FeeInfoTile(
                          label: 'Collected',
                          value: money(_totalCollected),
                          highlighted: true,
                        ),
                        const SizedBox(height: 8),
                        FeeInfoTile(
                          label: 'Balance',
                          value: money(_totalDue),
                          danger: _totalDue > 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Payment QR ───────────────────────────────────────
        FeeActionRow(
          icon: Icons.qr_code_2_rounded,
          iconColor: const Color(0xFF2563EB),
          title: 'Parent Payment Setup',
          subtitle: _paymentConfig.isEmpty
              ? 'Set UPI ID and upload QR code'
              : textValue(
                  _paymentConfig['upi_id'],
                  fallback: textValue(
                    _paymentConfig['payee_name'],
                    fallback: 'Upload or replace payment QR',
                  ),
                ),
          onTap: () => Navigator.pushNamed(context, AppRoutes.feePaymentConfig),
        ),

        // ── Pending requests badge ───────────────────────────
        if (_paymentRequests.isNotEmpty)
          FeeActionRow(
            icon: Icons.rule_folder_outlined,
            iconColor: const Color(0xFF7C3AED),
            title: 'Parent Payment Requests',
            subtitle:
                '${_paymentRequests.length} request(s) waiting for review',
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.principalPaymentRequests,
            ),
            trailing: Container(
              constraints: const BoxConstraints(minWidth: 24),
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                '${_paymentRequests.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // ── Quick Actions (always visible) ───────────────────
        const FeeSectionTitle('Quick Actions'),
        const SizedBox(height: 10),
        FeeActionRow(
          icon: Icons.assignment_outlined,
          iconColor: const Color(0xFF2563EB),
          title: 'Fee Structures',
          subtitle: 'Create, edit, and manage fee structures',
          onTap: () => Navigator.pushNamed(context, AppRoutes.feeStructures),
        ),
        FeeActionRow(
          icon: Icons.payments_outlined,
          iconColor: const Color(0xFF16A34A),
          title: 'Collect Fee',
          subtitle: 'Record cash or offline payments',
          onTap: () => Navigator.pushNamed(context, AppRoutes.feeCollect),
        ),
        FeeActionRow(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: const Color(0xFFEA580C),
          title: 'Student Ledger & Dues',
          subtitle:
              '${_studentAccounts.where((a) => a.balance > 0).length} students with outstanding balance',
          onTap: () => Navigator.pushNamed(context, AppRoutes.feeLedger),
        ),
        FeeActionRow(
          icon: Icons.bar_chart_outlined,
          iconColor: const Color(0xFF4F46E5),
          title: 'Reports',
          subtitle: 'Collection summaries and PDF exports',
          onTap: () => Navigator.pushNamed(context, AppRoutes.feeReports),
        ),

        // ── Active structure summary ─────────────────────────
        if (activeBundle != null) ...[
          const SizedBox(height: 16),
          const FeeSectionTitle('Active Structure'),
          const SizedBox(height: 10),
          FeeCard(
            child: Row(
              children: [
                const FeeIconBadge(
                  icon: Icons.verified_outlined,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeBundle.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${activeBundle.classLabel} - ${activeBundle.sectionLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                FeeStatusPill(
                  label: money(activeBundle.total),
                  color: const Color(0xFF2563EB),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 48),
      ],
    );
  }

  Widget _header() {
    return FeeHeader(
      title: 'Fees',
      subtitle: 'Manage fee structures, collections, and reports',
      leadingIcon: Icons.menu_rounded,
      onLeading: () => _scaffoldKey.currentState?.openDrawer(),
      trailing: IconButton(
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: _loadData,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isPendingRequest(Map<String, dynamic> r) {
    final s = textValue(r['status']).toLowerCase();
    return s == 'pending' ||
        s == 'pending_verification' ||
        s == 'clarification_required';
  }

  DateTime _sortDate(Object? v) => DateTime.tryParse('$v') ?? DateTime(2000);
}

// ── Internal types ──────────────────────────────────────────────────────────

class _FeeBundle {
  final String id,
      gradeId,
      sectionId,
      academicYearId,
      title,
      classLabel,
      sectionLabel,
      academicYearLabel;
  final double total;
  const _FeeBundle({
    required this.id,
    required this.gradeId,
    required this.sectionId,
    required this.academicYearId,
    required this.title,
    required this.classLabel,
    required this.sectionLabel,
    required this.academicYearLabel,
    required this.total,
  });
}

class _FeeStudentView {
  final String name, classLabel;
  final double total, paid, balance;
  const _FeeStudentView({
    required this.name,
    required this.classLabel,
    required this.total,
    required this.paid,
    required this.balance,
  });
}

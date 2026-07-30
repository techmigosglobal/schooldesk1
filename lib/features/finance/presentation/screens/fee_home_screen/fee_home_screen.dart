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
  List<Map<String, dynamic>> _paymentRequests = const [];
  List<Map<String, dynamic>> _reminderDeliveries = const [];
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

      List<Map<String, dynamic>> reminderDeliveries = const [];
      try {
        reminderDeliveries = await api.getRawList('/fees/reminders');
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
        _paymentRequests = prList;
        _reminderDeliveries = reminderDeliveries;
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

  List<Map<String, dynamic>> get _yearInvoices => _invoices.where((invoice) {
    if (_selectedAcademicYearId.isEmpty) return true;
    return textValue(invoice['academic_year_id']) == _selectedAcademicYearId;
  }).toList();

  List<Map<String, dynamic>> get _outstandingInvoices =>
      _yearInvoices
          .where((invoice) => numValue(invoice['balance']) > 0)
          .toList()
        ..sort(
          (a, b) => numValue(b['balance']).compareTo(numValue(a['balance'])),
        );

  List<Map<String, dynamic>> get _overdueInvoices {
    final today = DateTime.now();
    return _outstandingInvoices.where((invoice) {
      final due = DateTime.tryParse(textValue(invoice['due_date']));
      return due != null &&
          due.isBefore(DateTime(today.year, today.month, today.day));
    }).toList();
  }

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
    for (final inv in _yearInvoices) {
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
  double get _totalCollected => _yearInvoices
      .expand(normalizePayments)
      .fold(0.0, (sum, payment) => sum + numValue(payment['amount']));
  double get _totalExpected => _totalCollected + _totalDue;
  double get _collectionRate =>
      _totalExpected > 0 ? _totalCollected / _totalExpected : 0;
  int get _remindersAwaitingDelivery => _reminderDeliveries.where((delivery) {
    final event = delivery['notification_event'];
    return event is Map && event['processed'] != true;
  }).length;
  int get _remindersWithNoDevice => _reminderDeliveries.where((delivery) {
    final event = delivery['notification_event'];
    if (event is! Map) return false;
    final data = event['event_data'];
    return data is Map && data['_push_deferred_no_device'] == true;
  }).length;

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

        // ── Prominent operating actions ──────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;
            final actions = [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.feeCollect),
                  icon: const Icon(Icons.add_card_rounded),
                  label: const Text('Collect Payment'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF17834A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _showReminderReview,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Send Reminders'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ];
            return Row(children: actions);
          },
        ),
        const SizedBox(height: 18),

        // ── Live attention states ─────────────────────────────
        const FeeSectionTitle('Needs Attention'),
        const SizedBox(height: 10),
        FeeCard(
          child: Column(
            children: [
              _attentionRow(
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFDC2626),
                label: 'Overdue balances',
                detail: '${_overdueInvoices.length} invoice(s)',
                onTap: _overdueInvoices.isEmpty ? null : _showReminderReview,
              ),
              const Divider(height: 22),
              _attentionRow(
                icon: Icons.fact_check_outlined,
                color: const Color(0xFF7C3AED),
                label: 'Parent payment proofs',
                detail: '${_paymentRequests.length} awaiting review',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.principalPaymentRequests,
                ),
              ),
              const Divider(height: 22),
              _attentionRow(
                icon: Icons.qr_code_2_rounded,
                color: const Color(0xFF2563EB),
                label: 'Parent payment setup',
                detail: _paymentConfig.isEmpty ? 'Action needed' : 'Ready',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.feePaymentConfig),
              ),
              const Divider(height: 22),
              _attentionRow(
                icon: Icons.send_outlined,
                color: _remindersWithNoDevice > 0
                    ? const Color(0xFFEA580C)
                    : const Color(0xFF4F46E5),
                label: 'Reminder delivery',
                detail: _remindersWithNoDevice > 0
                    ? '$_remindersWithNoDevice parent device(s) unavailable'
                    : _remindersAwaitingDelivery > 0
                    ? '$_remindersAwaitingDelivery queued for push'
                    : 'No delivery issues',
                onTap: _showReminderReview,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

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
          subtitle: 'Choose a class and student, then record a payment',
          onTap: () => Navigator.pushNamed(context, AppRoutes.feeCollect),
        ),
        FeeActionRow(
          icon: Icons.schedule_rounded,
          iconColor: const Color(0xFF0F766E),
          title: 'Daycare Plans',
          subtitle: 'Set each child’s monthly amount and due day',
          onTap: _showDaycarePlans,
        ),
        FeeActionRow(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: const Color(0xFFEA580C),
          title: 'Student Ledger & Dues',
          subtitle:
              '${_studentAccounts.where((a) => a.balance > 0).length} students with outstanding balance',
          onTap: () => Navigator.pushNamed(context, AppRoutes.feeLedger),
        ),

        const SizedBox(height: 48),
      ],
    );
  }

  Widget _header() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(6, 12, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF176B43),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF176B43).withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Open menu',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fees',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Collection, follow-up, and family payments',
                  style: TextStyle(color: Color(0xFFD8F5E3), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh fee data',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _attentionRow({
    required IconData icon,
    required Color color,
    required String label,
    required String detail,
    required VoidCallback? onTap,
  }) {
    return Semantics(
      button: onTap != null,
      label: '$label: $detail',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.appTheme.muted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReminderReview() async {
    if (_outstandingInvoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There are no outstanding invoices to remind.'),
        ),
      );
      return;
    }
    final selected = _outstandingInvoices
        .map((invoice) => textValue(invoice['id']))
        .where((id) => id.isNotEmpty)
        .toSet();
    final messageController = TextEditingController();
    String query = '';
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final visibleInvoices = _outstandingInvoices.where((invoice) {
            final text =
                '${textValue(invoice['name'])} '
                        '${textValue(invoice['component'])} '
                        '${textValue(invoice['due_date'])}'
                    .toLowerCase();
            return text.contains(query.trim().toLowerCase());
          }).toList();
          return AlertDialog(
            title: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFEDE9FE),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFF5B21B6),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(child: Text('Reminder center')),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          color: Color(0xFF5B21B6),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${selected.length} families selected · ${money(_outstandingInvoices.fold<double>(0, (sum, invoice) => sum + numValue(invoice['balance'])))} outstanding',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search student or fee',
                      isDense: true,
                    ),
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: messageController,
                    maxLength: 180,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.edit_note_rounded),
                      labelText: 'Optional personal message',
                      hintText: 'Leave blank to use the school reminder',
                      isDense: true,
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: visibleInvoices.length,
                      itemBuilder: (context, index) {
                        final invoice = visibleInvoices[index];
                        final id = textValue(invoice['id']);
                        return Card(
                          elevation: 0,
                          color: selected.contains(id)
                              ? const Color(0xFFF5F3FF)
                              : null,
                          child: CheckboxListTile(
                            value: selected.contains(id),
                            onChanged: id.isEmpty
                                ? null
                                : (value) => setDialogState(() {
                                    if (value == true) {
                                      selected.add(id);
                                    } else {
                                      selected.remove(id);
                                    }
                                  }),
                            title: Text(
                              textValue(invoice['name'], fallback: 'Student'),
                            ),
                            subtitle: Text(
                              '${textValue(invoice['component'], fallback: 'Fee')} · ${money(numValue(invoice['balance']))} · due ${displayDate(invoice['due_date'])}',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: Text(
                  'Queue ${selected.length} invoice${selected.length == 1 ? '' : 's'}',
                ),
              ),
            ],
          );
        },
      ),
    );
    final customMessage = messageController.text.trim();
    messageController.dispose();
    if (approved != true || selected.isEmpty || !mounted) return;
    try {
      final summary = await BackendApiClient.instance
          .createRaw('/fees/reminders', {
            'invoice_ids': selected.toList(),
            if (customMessage.isNotEmpty) 'message': customMessage,
          });
      if (!mounted) return;
      final queued = numValue(summary['queued']).round();
      final skipped = numValue(summary['skipped_cooldown']).round();
      final unavailable = numValue(summary['unavailable_recipients']).round();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$queued queued${skipped > 0 ? ' · $skipped cooling down' : ''}${unavailable > 0 ? ' · $unavailable without a parent' : ''}',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to queue reminders: $error'),
          backgroundColor: context.appTheme.error,
        ),
      );
    }
  }

  Future<void> _showDaycarePlans() async {
    try {
      final plans = await BackendApiClient.instance.getRawList(
        '/fees/daycare-plans',
        queryParameters: const {'active': 'true'},
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Daycare plans',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _createDaycarePlan();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add plan'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Only children currently enrolled in Day Care sections can have a plan. Each child has an individual monthly amount; class fee structures are not used.',
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: plans.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text('No active daycare plans yet.'),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: plans.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, index) {
                            final plan = plans[index];
                            final student = plan['student'] is Map
                                ? Map<String, dynamic>.from(
                                    plan['student'] as Map,
                                  )
                                : const <String, dynamic>{};
                            final invoice =
                                plan['current_period_invoice'] is Map
                                ? Map<String, dynamic>.from(
                                    plan['current_period_invoice'] as Map,
                                  )
                                : const <String, dynamic>{};
                            final name =
                                '${textValue(student['first_name'])} ${textValue(student['last_name'])}'
                                    .trim();
                            final eligible =
                                plan['is_daycare_eligible'] == true;
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFDDF5EC),
                                child: Icon(
                                  Icons.schedule_rounded,
                                  color: Color(0xFF176B43),
                                ),
                              ),
                              title: Text(name.isEmpty ? 'Student' : name),
                              subtitle: Text(
                                '${money(numValue(plan['monthly_amount']))}/month · due on ${numValue(plan['due_day']).round()} · ${invoice.isEmpty ? 'Current invoice pending' : money(numValue(invoice['balance']))}',
                              ),
                              trailing: eligible
                                  ? null
                                  : const Chip(
                                      avatar: Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16,
                                      ),
                                      label: Text('Needs attention'),
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load daycare plans: $error')),
      );
    }
  }

  Future<void> _createDaycarePlan() async {
    try {
      final students = await BackendApiClient.instance.getRawList(
        '/fees/daycare-eligible-students',
      );
      if (!mounted) return;
      if (students.isEmpty) {
        throw StateError('No active Day Care students are available.');
      }
      String? studentId;
      final amountController = TextEditingController();
      final dueDayController = TextEditingController(text: '10');
      final created = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add daycare plan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: studentId,
                    decoration: const InputDecoration(labelText: 'Child'),
                    items: students
                        .map(
                          (student) => DropdownMenuItem(
                            value: textValue(student['id']),
                            child: Text(
                              '${textValue(student['first_name'])} ${textValue(student['last_name'])}'
                                  .trim(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => studentId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monthly amount (₹)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dueDayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Due day (1–28)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Create plan'),
              ),
            ],
          ),
        ),
      );
      final amount = double.tryParse(amountController.text) ?? 0;
      final dueDay = int.tryParse(dueDayController.text) ?? 0;
      amountController.dispose();
      dueDayController.dispose();
      if (created != true || studentId == null) return;
      if (amount <= 0 || dueDay < 1 || dueDay > 28) {
        throw StateError('Enter a monthly amount and a due day from 1 to 28.');
      }
      await BackendApiClient.instance.createRaw('/fees/daycare-plans', {
        'student_id': studentId,
        'academic_year_id': _selectedAcademicYearId,
        'monthly_amount': amount,
        'due_day': dueDay,
        'fee_label': 'Day Care',
        'effective_from': _todayIso(),
      });
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Daycare plan created and this month’s invoice is ready.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to create daycare plan: $error'),
          backgroundColor: context.appTheme.error,
        ),
      );
    }
  }

  String _todayIso() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _isPendingRequest(Map<String, dynamic> r) {
    final s = textValue(r['status']).toLowerCase();
    return s == 'pending' ||
        s == 'pending_verification' ||
        s == 'clarification_required';
  }
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

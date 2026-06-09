import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/academics/presentation/screens/academic_management_screen/academic_management_form_screens.dart';

const _academicBg = Color(0xFFF3F8FF);
const _academicInk = Color(0xFF08142F);
const _academicMuted = Color(0xFF65738D);
const _academicBlue = Color(0xFF176BEE);
const _academicGreen = Color(0xFF21B75B);
const _academicPurple = Color(0xFF7B4EF5);
const _academicBorder = Color(0xFFD9E5F4);
const _academicPanelShadow = Color(0x1A6E88A8);

bool _academicCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 390;

EdgeInsets _academicHorizontalPadding(BuildContext context, {double top = 0}) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontal = width < 370
      ? 16.0
      : width < 430
      ? 18.0
      : 22.0;
  return EdgeInsets.fromLTRB(horizontal, top, horizontal, 0);
}

EdgeInsets _academicListPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontal = width < 370
      ? 16.0
      : width < 430
      ? 18.0
      : 22.0;
  return EdgeInsets.fromLTRB(horizontal, 22, horizontal, 22);
}

class AcademicManagementScreen extends StatefulWidget {
  final String ownerRole;

  const AcademicManagementScreen({super.key, this.ownerRole = 'admin'});

  @override
  State<AcademicManagementScreen> createState() =>
      _AcademicManagementScreenState();
}

class _AcademicManagementScreenState extends State<AcademicManagementScreen>
    with SingleTickerProviderStateMixin {
  static const _principalAcademicWorkflowContract = [
    'Configure academic years',
  ];

  late TabController _tabController;
  BackendDataService? _storage;
  bool _loading = true;

  List<Map<String, dynamic>> _academicYears = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _curriculum = [];
  List<Map<String, dynamic>> _staff = [];
  NotificationService? _notificationService;
  int _unreadNotifications = 0;

  String get _role => widget.ownerRole.toLowerCase();
  bool get _isAdminOwner => widget.ownerRole.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadData();
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _notificationService?.removeListener(_onNotificationsChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadNotifications() async {
    try {
      final service = await NotificationService.getInstance();
      if (!mounted) return;
      _notificationService?.removeListener(_onNotificationsChanged);
      _notificationService = service;
      service.addListener(_onNotificationsChanged);
      _onNotificationsChanged();
    } catch (_) {
      // Notification dots should never block academic records from loading.
    }
  }

  void _onNotificationsChanged() {
    if (!mounted) return;
    setState(() {
      _unreadNotifications =
          _notificationService?.getUnreadCountForRole(_role) ?? 0;
    });
  }

  Future<void> _loadData() async {
    _storage = await BackendDataService.getInstance();
    await _storage!.ensureAcademicManagementLoaded();
    final academicYears = await _storage!.getList(
      BackendDataService.kAcademicYears,
    );
    final subjects = await _storage!.getList(
      BackendDataService.kAcademicSubjects,
    );
    final classes = await _storage!.getList(
      BackendDataService.kAcademicClasses,
    );
    final curriculum = await _storage!.getList(
      BackendDataService.kAcademicCurriculum,
    );
    final staff = await _storage!.getList(BackendDataService.kAdminTeachers);
    setState(() {
      _academicYears = academicYears;
      _subjects = subjects;
      _classes = classes;
      _curriculum = curriculum;
      _staff = staff;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    assert(_principalAcademicWorkflowContract.isNotEmpty);
    return Scaffold(
      backgroundColor: _academicBg,
      bottomNavigationBar: _AcademicBottomBar(role: _role),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: _academicHorizontalPadding(context, top: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      _AcademicHeader(
                        unreadNotifications: _unreadNotifications,
                        onMenu: _showAcademicMenu,
                        onNotifications: () => Navigator.pushNamed(
                          context,
                          AppRoutes.notificationCenter,
                          arguments: _role,
                        ),
                        onProfile: () => Navigator.pushNamed(
                          context,
                          AppRoutes.profileScreen,
                          arguments: _role,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AcademicTabStrip(
                        controller: _tabController,
                        onTap: _tabController.animateTo,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return _loading
        ? const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          )
        : TabBarView(
            controller: _tabController,
            children: [
              _AcademicYearsTab(
                years: _academicYears,
                classes: _classes,
                subjects: _subjects,
                storage: _storage!,
                onRefresh: _refresh,
                isAdminOwner: _isAdminOwner,
                ownerRole: widget.ownerRole,
              ),
              _SubjectsTab(
                subjects: _subjects,
                storage: _storage!,
                onRefresh: _refresh,
                isAdminOwner: _isAdminOwner,
                ownerRole: widget.ownerRole,
              ),
              _ClassesTab(
                classes: _classes,
                staff: _staff,
                storage: _storage!,
                onRefresh: _refresh,
                isAdminOwner: _isAdminOwner,
                ownerRole: widget.ownerRole,
              ),
              _CurriculumTab(
                curriculum: _curriculum,
                academicYears: _academicYears,
                classes: _classes,
                subjects: _subjects,
                storage: _storage!,
                onRefresh: _refresh,
                isAdminOwner: _isAdminOwner,
                ownerRole: widget.ownerRole,
              ),
            ],
          );
  }

  Future<void> _showAcademicMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AcademicActionSheet(
        title: 'Academic Management',
        actions: [
          _AcademicSheetAction(
            icon: Icons.refresh_rounded,
            label: 'Refresh data',
            onTap: () {
              Navigator.pop(context);
              _refresh();
            },
          ),
          _AcademicSheetAction(
            icon: Icons.calendar_month_outlined,
            label: 'Years',
            selected: _tabController.index == 0,
            onTap: () {
              Navigator.pop(context);
              _tabController.animateTo(0);
            },
          ),
          _AcademicSheetAction(
            icon: Icons.menu_book_outlined,
            label: 'Subjects',
            selected: _tabController.index == 1,
            onTap: () {
              Navigator.pop(context);
              _tabController.animateTo(1);
            },
          ),
          _AcademicSheetAction(
            icon: Icons.groups_outlined,
            label: 'Classes',
            selected: _tabController.index == 2,
            onTap: () {
              Navigator.pop(context);
              _tabController.animateTo(2);
            },
          ),
          _AcademicSheetAction(
            icon: Icons.layers_outlined,
            label: 'Curriculum',
            selected: _tabController.index == 3,
            onTap: () {
              Navigator.pop(context);
              _tabController.animateTo(3);
            },
          ),
        ],
      ),
    );
  }
}

class _AcademicHeader extends StatelessWidget {
  final int unreadNotifications;
  final VoidCallback onMenu;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  const _AcademicHeader({
    required this.unreadNotifications,
    required this.onMenu,
    required this.onNotifications,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _academicCompact(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AcademicIconButton(
          tooltip: 'Menu',
          icon: Icons.menu_rounded,
          onTap: onMenu,
        ),
        SizedBox(width: compact ? 10 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Academic Management',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: _academicInk,
                  fontSize: compact ? 15.5 : 17,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Configure academic structure',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: _academicMuted,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: compact ? 6 : 10),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _AcademicIconButton(
              tooltip: 'Notifications',
              icon: unreadNotifications > 0
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none_rounded,
              onTap: onNotifications,
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 8,
                top: 7,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4949),
                    shape: BoxShape.circle,
                    border: Border.all(color: _academicBg, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        _AcademicIconButton(
          tooltip: 'Profile',
          icon: Icons.account_circle_outlined,
          onTap: onProfile,
        ),
      ],
    );
  }
}

class _AcademicIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _AcademicIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _academicCompact(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: _academicInk, size: compact ? 25 : 28),
        ),
      ),
    );
  }
}

class _AcademicTabStrip extends StatelessWidget {
  final TabController controller;
  final ValueChanged<int> onTap;

  const _AcademicTabStrip({required this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      (label: 'Years', icon: Icons.calendar_month_outlined),
      (label: 'Subjects', icon: Icons.menu_book_outlined),
      (label: 'Classes', icon: Icons.groups_outlined),
      (label: 'Curriculum', icon: Icons.layers_outlined),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _academicBorder),
        boxShadow: [
          BoxShadow(
            color: _academicPanelShadow,
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: _AcademicTabButton(
                label: tabs[i].label,
                icon: tabs[i].icon,
                selected: controller.index == i,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _AcademicTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AcademicTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _academicCompact(context);
    final color = selected ? _academicBlue : const Color(0xFF536489);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: compact ? 74 : 84,
          padding: EdgeInsets.only(top: compact ? 10 : 13),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF2F7FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: compact ? 22 : 25),
              SizedBox(height: compact ? 6 : 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: color,
                  fontSize: compact ? 10.8 : 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: selected ? _academicBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcademicBottomBar extends StatelessWidget {
  final String role;

  const _AcademicBottomBar({required this.role});

  @override
  Widget build(BuildContext context) {
    final homeRoute = role == 'admin'
        ? AppRoutes.adminDashboard
        : AppRoutes.principalDashboard;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7186A3).withAlpha(36),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              _AcademicBottomNavItem(
                label: 'Home',
                icon: Icons.home_rounded,
                selected: true,
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  homeRoute,
                  (_) => false,
                ),
              ),
              _AcademicBottomNavItem(
                label: 'Search',
                icon: Icons.search_rounded,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.globalSearch,
                  arguments: role,
                ),
              ),
              _AcademicBottomNavItem(
                label: 'Alerts',
                icon: Icons.notifications_none_rounded,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.notificationCenter,
                  arguments: role,
                ),
              ),
              _AcademicBottomNavItem(
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.profileScreen,
                  arguments: role,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcademicBottomNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  const _AcademicBottomNavItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _academicCompact(context);
    final color = selected ? _academicBlue : _academicInk;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: BoxConstraints(minHeight: compact ? 62 : 68),
            padding: EdgeInsets.symmetric(vertical: compact ? 7 : 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEAF3FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: compact ? 23 : 26),
                SizedBox(height: compact ? 4 : 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: color,
                    fontSize: compact ? 11.8 : 13,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AcademicActionSheet extends StatelessWidget {
  final String title;
  final List<_AcademicSheetAction> actions;

  const _AcademicActionSheet({required this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: GoogleFonts.dmSans(
                color: _academicInk,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            for (final action in actions)
              ListTile(
                minVerticalPadding: 8,
                leading: Icon(
                  action.icon,
                  color: action.selected ? _academicBlue : _academicMuted,
                ),
                title: Text(
                  action.label,
                  style: GoogleFonts.dmSans(
                    color: _academicInk,
                    fontWeight: action.selected
                        ? FontWeight.w900
                        : FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                trailing: action.selected
                    ? const Icon(Icons.check_rounded, color: _academicBlue)
                    : null,
                onTap: action.onTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _AcademicSheetAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  const _AcademicSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
}

// ─── Academic Years Tab ──────────────────────────────────────────────────────

class _AcademicYearsTab extends StatelessWidget {
  final List<Map<String, dynamic>> years;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;
  final BackendDataService storage;
  final VoidCallback onRefresh;
  final bool isAdminOwner;
  final String ownerRole;

  const _AcademicYearsTab({
    required this.years,
    required this.classes,
    required this.subjects,
    required this.storage,
    required this.onRefresh,
    required this.isAdminOwner,
    required this.ownerRole,
  });

  @override
  Widget build(BuildContext context) {
    final canManageAcademicYears =
        isAdminOwner || ownerRole.toLowerCase() == 'principal';
    final studentTotal = classes.fold<int>(
      0,
      (sum, row) =>
          sum +
          _academicInt(
            row['student_count'] ??
                row['students_count'] ??
                row['total_students'] ??
                row['students'],
          ),
    );
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: _academicBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: _academicListPadding(context),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AcademicSectionHeader(
                    title: 'Academic Years',
                    subtitle:
                        '${years.length} ${years.length == 1 ? 'year' : 'years'} configured',
                    actionLabel: 'Add Year',
                    actionIcon: Icons.add_rounded,
                    onAction: canManageAcademicYears
                        ? () => _openYearForm(context)
                        : null,
                  ),
                  const SizedBox(height: 22),
                  if (years.isEmpty)
                    const _AcademicEmptyCard(
                      icon: Icons.calendar_month_outlined,
                      title: 'No academic years configured',
                      body: 'Add an academic year to unlock structure setup.',
                    )
                  else
                    for (final year in years)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _AcademicYearCard(
                          year: year,
                          classCount: classes.length,
                          subjectCount: subjects.length,
                          studentCount: studentTotal,
                          onActivate: canManageAcademicYears
                              ? () => _activateYear(context, year)
                              : null,
                          onEdit: canManageAcademicYears
                              ? () => _openYearForm(context, year: year)
                              : null,
                          onDelete: canManageAcademicYears
                              ? () => _deleteYear(context, year)
                              : null,
                        ),
                      ),
                  const SizedBox(height: 10),
                  const _AcademicTipCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _activateYear(
    BuildContext context,
    Map<String, dynamic> year,
  ) async {
    try {
      await BackendApiClient.instance.updateAcademicYear(
        '${year['id'] ?? ''}',
        yearLabel: _yearLabel(year),
        startDate: _yearStartDate(year),
        endDate: _yearEndDate(year),
        isCurrent: true,
      );
      onRefresh();
      _showAcademicSnack(
        context,
        '${year['name']} activated - visible to all modules',
      );
    } catch (error) {
      _showAcademicSnack(context, _academicError(error), isError: true);
    }
  }

  Future<void> _deleteYear(
    BuildContext context,
    Map<String, dynamic> year,
  ) async {
    final confirmed = await _confirmAcademicDelete(
      context,
      title: 'Delete Academic Year',
      message:
          'Delete "${year['name']}"? The backend will block this if classes, terms, fees, attendance, or events are linked.',
    );
    if (confirmed != true) return;
    try {
      await storage.deleteAcademicYearRecord('${year['id'] ?? ''}');
      onRefresh();
      _showAcademicSnack(context, 'Academic year deleted');
    } catch (error) {
      _showAcademicSnack(context, _academicError(error), isError: true);
    }
  }

  Future<void> _openYearForm(
    BuildContext context, {
    Map<String, dynamic>? year,
  }) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicYearForm,
      arguments: AcademicYearFormArgs(ownerRole: ownerRole, year: year),
    );
    if (!context.mounted || result is! AcademicFormResult) return;
    onRefresh();
    _showAcademicSnack(context, result.message, isWarning: result.isWarning);
  }

  String _yearLabel(Map<String, dynamic> year) =>
      '${year['name'] ?? year['year_label'] ?? year['year'] ?? ''}'.trim();

  String _yearStartDate(Map<String, dynamic> year) =>
      '${year['start_date'] ?? ''}'.split('T').first;

  String _yearEndDate(Map<String, dynamic> year) =>
      '${year['end_date'] ?? ''}'.split('T').first;
}

class _AcademicYearCard extends StatelessWidget {
  final Map<String, dynamic> year;
  final int classCount;
  final int subjectCount;
  final int studentCount;
  final VoidCallback? onActivate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _AcademicYearCard({
    required this.year,
    required this.classCount,
    required this.subjectCount,
    required this.studentCount,
    required this.onActivate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = year['status'] == 'active' || year['is_current'] == true;
    final label = _academicText(
      year['name'] ?? year['year_label'] ?? year['year'],
      fallback: 'Academic Year',
    );
    final start = _academicText(year['start'], fallback: '');
    final end = _academicText(year['end'], fallback: '');
    final dateLabel = [start, end].where((part) => part.isNotEmpty).join(' - ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _academicBorder),
        boxShadow: [
          BoxShadow(
            color: _academicPanelShadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _AcademicSoftIcon(
                icon: Icons.calendar_month_outlined,
                color: _academicBlue,
                background: const Color(0xFFEAF3FF),
                size: 60,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: _academicInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        if (isActive)
                          const _AcademicStatusPill(label: 'ACTIVE'),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      dateLabel.isEmpty ? 'Dates not configured' : dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: _academicMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null || onDelete != null || onActivate != null)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: _academicInk,
                  ),
                  tooltip: 'Academic year actions',
                  onSelected: (value) {
                    if (value == 'activate') onActivate?.call();
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (!isActive && onActivate != null)
                      const PopupMenuItem(
                        value: 'activate',
                        child: Text('Activate'),
                      ),
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _academicBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _AcademicStatBlock(
                    icon: Icons.school_outlined,
                    value: '$classCount',
                    label: 'Classes',
                    color: _academicBlue,
                  ),
                ),
                const _AcademicStatDivider(),
                Expanded(
                  child: _AcademicStatBlock(
                    icon: Icons.groups_outlined,
                    value: '$subjectCount',
                    label: 'Subjects',
                    color: _academicPurple,
                  ),
                ),
                const _AcademicStatDivider(),
                Expanded(
                  child: _AcademicStatBlock(
                    icon: Icons.person_outline_rounded,
                    value: '$studentCount',
                    label: 'Students',
                    color: const Color(0xFF4C5C83),
                  ),
                ),
              ],
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FBF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: _academicGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Current academic year is active',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF4D5B77),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AcademicTipCard extends StatelessWidget {
  const _AcademicTipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 138),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _academicBorder),
        boxShadow: [
          BoxShadow(
            color: _academicPanelShadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Tip: Start by adding an\nacademic year.',
                  style: GoogleFonts.dmSans(
                    color: _academicInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'You can add subjects, classes\nand map curriculum next.',
                  style: GoogleFonts.dmSans(
                    color: _academicMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _AcademicBooksIllustration(),
        ],
      ),
    );
  }
}

class _AcademicBooksIllustration extends StatelessWidget {
  const _AcademicBooksIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 98,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 26,
            top: 0,
            child: Transform.rotate(
              angle: -0.24,
              child: Container(
                width: 22,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF8BDFA6),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            top: 8,
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                width: 18,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF34C874),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Positioned(
            right: 19,
            top: 28,
            child: Container(
              width: 18,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF48CF7D),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            right: 15,
            top: 43,
            child: Container(
              width: 24,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFD7F4E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF64D88F), width: 2),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 13,
            child: Transform.rotate(
              angle: -0.28,
              child: _BookBlock(
                width: 58,
                color: const Color(0xFFFFB15B),
                stripe: const Color(0xFF4979E9),
              ),
            ),
          ),
          Positioned(
            left: 11,
            bottom: 0,
            child: Transform.rotate(
              angle: -0.05,
              child: _BookBlock(
                width: 68,
                color: const Color(0xFF7DC6FF),
                stripe: const Color(0xFFEB6A7C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookBlock extends StatelessWidget {
  final double width;
  final Color color;
  final Color stripe;

  const _BookBlock({
    required this.width,
    required this.color,
    required this.stripe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(width: 11, height: double.infinity, color: stripe),
      ),
    );
  }
}

// ─── Subjects Tab ────────────────────────────────────────────────────────────

class _SubjectsTab extends StatefulWidget {
  final List<Map<String, dynamic>> subjects;
  final BackendDataService storage;
  final VoidCallback onRefresh;
  final bool isAdminOwner;
  final String ownerRole;

  const _SubjectsTab({
    required this.subjects,
    required this.storage,
    required this.onRefresh,
    required this.isAdminOwner,
    required this.ownerRole,
  });

  @override
  State<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<_SubjectsTab> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSubjects;
    final coreCount = widget.subjects
        .where((subject) => _academicSubjectType(subject) == 'Core')
        .length;
    final electiveCount = widget.subjects
        .where((subject) => _academicSubjectType(subject) == 'Elective')
        .length;
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: _academicBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: _academicListPadding(context),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AcademicSectionHeader(
                    title: 'Subjects',
                    subtitle:
                        '${widget.subjects.length} ${widget.subjects.length == 1 ? 'subject' : 'subjects'} configured',
                    actionLabel: 'Add Subject',
                    actionIcon: Icons.add_rounded,
                    onAction: widget.isAdminOwner
                        ? () => _openSubjectForm(context)
                        : null,
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _AcademicFilterPill(
                        label: 'All (${widget.subjects.length})',
                        selected: _filter == 'All',
                        color: _academicBlue,
                        onTap: () => setState(() => _filter = 'All'),
                      ),
                      _AcademicFilterPill(
                        label: 'Core ($coreCount)',
                        selected: _filter == 'Core',
                        color: _academicGreen,
                        onTap: () => setState(() => _filter = 'Core'),
                      ),
                      _AcademicFilterPill(
                        label: 'Elective ($electiveCount)',
                        selected: _filter == 'Elective',
                        color: _academicPurple,
                        onTap: () => setState(() => _filter = 'Elective'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (widget.subjects.isEmpty)
                    const _AcademicEmptyCard(
                      icon: Icons.menu_book_outlined,
                      title: 'No subjects configured',
                      body: 'Create subjects to map curriculum and timetable.',
                    )
                  else if (filtered.isEmpty)
                    _AcademicEmptyCard(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No $_filter subjects',
                      body: 'Change the filter to view available subjects.',
                    )
                  else
                    for (final subject in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _AcademicSubjectCard(
                          subject: subject,
                          onTap: widget.isAdminOwner
                              ? () =>
                                    _openSubjectForm(context, subject: subject)
                              : null,
                          onEdit: widget.isAdminOwner
                              ? () =>
                                    _openSubjectForm(context, subject: subject)
                              : null,
                          onDelete: widget.isAdminOwner
                              ? () => _deleteSubject(context, subject)
                              : null,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredSubjects {
    if (_filter == 'All') return widget.subjects;
    return widget.subjects
        .where((subject) => _academicSubjectType(subject) == _filter)
        .toList();
  }

  Future<void> _deleteSubject(
    BuildContext context,
    Map<String, dynamic> subject,
  ) async {
    // Confirmation-only dialog: no user input is collected here.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Remove Subject',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove "${subject['name']}" from the subject list?',
          style: GoogleFonts.dmSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await widget.storage.deleteAcademicSubjectRecord(
          '${subject['id'] ?? ''}',
        );
        widget.onRefresh();
        _showAcademicSnack(context, 'Subject removed');
      } catch (error) {
        _showAcademicSnack(context, _academicError(error), isError: true);
      }
    }
  }

  Future<void> _openSubjectForm(
    BuildContext context, {
    Map<String, dynamic>? subject,
  }) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicSubjectForm,
      arguments: AcademicSubjectFormArgs(
        ownerRole: widget.ownerRole,
        subject: subject,
      ),
    );
    if (!context.mounted || result is! AcademicFormResult) return;
    widget.onRefresh();
    _showAcademicSnack(context, result.message, isWarning: result.isWarning);
  }
}

// ─── Classes Tab ─────────────────────────────────────────────────────────────

class _ClassesTab extends StatelessWidget {
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> staff;
  final BackendDataService storage;
  final VoidCallback onRefresh;
  final bool isAdminOwner;
  final String ownerRole;

  const _ClassesTab({
    required this.classes,
    required this.staff,
    required this.storage,
    required this.onRefresh,
    required this.isAdminOwner,
    required this.ownerRole,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: _academicBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: _academicListPadding(context),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AcademicSectionHeader(
                    title: 'Classes & Sections',
                    subtitle:
                        '${classes.length} ${classes.length == 1 ? 'class' : 'classes'} configured',
                    actionLabel: 'Add Class',
                    actionIcon: Icons.add_rounded,
                    onAction: isAdminOwner
                        ? () => _openClassForm(context)
                        : null,
                  ),
                  const SizedBox(height: 22),
                  if (classes.isEmpty)
                    const _AcademicEmptyCard(
                      icon: Icons.groups_outlined,
                      title: 'No classes configured',
                      body: 'Create classes and sections for this school.',
                    )
                  else
                    for (final classData in classes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _AcademicClassCard(
                          classData: classData,
                          ownerRole: ownerRole,
                          onEdit: isAdminOwner
                              ? () => _openClassForm(
                                  context,
                                  classData: classData,
                                )
                              : null,
                          onDelete: isAdminOwner
                              ? () => _deleteClass(context, classData)
                              : null,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openClassForm(
    BuildContext context, {
    Map<String, dynamic>? classData,
  }) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicClassForm,
      arguments: AcademicClassFormArgs(
        ownerRole: ownerRole,
        staff: staff,
        classData: classData,
      ),
    );
    if (!context.mounted || result is! AcademicFormResult) return;
    onRefresh();
    _showAcademicSnack(context, result.message, isWarning: result.isWarning);
  }

  Future<void> _deleteClass(
    BuildContext context,
    Map<String, dynamic> classData,
  ) async {
    final confirmed = await _confirmAcademicDelete(
      context,
      title: 'Delete Class',
      message:
          'Delete "${classData['name']}" and its sections? The backend will block this if students, timetable, attendance, homework, or meetings are linked.',
    );
    if (confirmed != true) return;
    try {
      await storage.deleteAcademicClassRecord(classData);
      onRefresh();
      _showAcademicSnack(context, 'Class deleted');
    } catch (error) {
      _showAcademicSnack(context, _academicError(error), isError: true);
    }
  }
}

// ─── Curriculum Tab ──────────────────────────────────────────────────────────

class _CurriculumTab extends StatefulWidget {
  final List<Map<String, dynamic>> curriculum;
  final List<Map<String, dynamic>> academicYears;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;
  final BackendDataService storage;
  final VoidCallback onRefresh;
  final bool isAdminOwner;
  final String ownerRole;

  const _CurriculumTab({
    required this.curriculum,
    required this.academicYears,
    required this.classes,
    required this.subjects,
    required this.storage,
    required this.onRefresh,
    required this.isAdminOwner,
    required this.ownerRole,
  });

  @override
  State<_CurriculumTab> createState() => _CurriculumTabState();
}

class _CurriculumTabState extends State<_CurriculumTab> {
  String _selectedYearId = '';

  @override
  void initState() {
    super.initState();
    _selectedYearId = _defaultYearId();
  }

  @override
  void didUpdateWidget(covariant _CurriculumTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedYearId.isEmpty ||
        !widget.academicYears.any(
          (year) => _academicYearKey(year) == _selectedYearId,
        )) {
      _selectedYearId = _defaultYearId();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredCurriculum;
    final isAdminOwner = widget.isAdminOwner;
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: _academicBlue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: _academicListPadding(context),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AcademicSectionHeader(
                    title: 'Curriculum Overview',
                    subtitle: 'Class-wise subject mapping',
                    actionLabel: 'Map',
                    actionIcon: Icons.add_rounded,
                    onAction: isAdminOwner
                        ? () => _openCurriculumForm(context)
                        : null,
                  ),
                  const SizedBox(height: 22),
                  _AcademicYearSelector(
                    years: widget.academicYears,
                    selectedYearId: _selectedYearId,
                    onChanged: (value) => setState(() {
                      _selectedYearId = value ?? '';
                    }),
                  ),
                  const SizedBox(height: 68),
                  if (widget.curriculum.isEmpty || rows.isEmpty)
                    const _AcademicCurriculumEmptyState()
                  else
                    for (final item in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CurriculumCard(
                          item: item,
                          onTogglePublish: isAdminOwner
                              ? () => _togglePublish(context, item)
                              : null,
                          onEdit: isAdminOwner
                              ? () => _openCurriculumForm(context, item: item)
                              : null,
                          onDelete: isAdminOwner
                              ? () => _deleteCurriculum(context, item)
                              : null,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _defaultYearId() {
    if (widget.academicYears.isEmpty) return '';
    final active = widget.academicYears.where(
      (year) => year['status'] == 'active' || year['is_current'] == true,
    );
    return _academicYearKey(
      active.isNotEmpty ? active.first : widget.academicYears.first,
    );
  }

  List<Map<String, dynamic>> get _filteredCurriculum {
    if (_selectedYearId.isEmpty) return widget.curriculum;
    return widget.curriculum.where((item) {
      final yearId = _academicText(
        item['academic_year_id'] ??
            item['year_id'] ??
            item['academicYearId'] ??
            item['year_label'] ??
            item['academic_year'],
      );
      if (yearId.isEmpty) return true;
      return yearId == _selectedYearId;
    }).toList();
  }

  Future<void> _togglePublish(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final isPublished = item['published'] == true;
    final updated = widget.curriculum.map((c) {
      if (c['id'] == item['id']) {
        return {...c, 'published': !isPublished};
      }
      return c;
    }).toList();
    final next = updated.firstWhere((c) => c['id'] == item['id']);
    try {
      await widget.storage.saveAcademicCurriculumRecord(next);
      widget.onRefresh();
      _showAcademicSnack(
        context,
        isPublished
            ? 'Curriculum unpublished'
            : 'Curriculum published - visible to Teachers & Parents',
        isWarning: isPublished,
      );
    } catch (error) {
      _showAcademicSnack(context, _academicError(error), isError: true);
    }
  }

  Future<void> _openCurriculumForm(
    BuildContext context, {
    Map<String, dynamic>? item,
  }) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicCurriculumForm,
      arguments: AcademicCurriculumFormArgs(
        ownerRole: widget.ownerRole,
        classes: widget.classes,
        subjects: widget.subjects,
        item: item,
      ),
    );
    if (!context.mounted || result is! AcademicFormResult) return;
    widget.onRefresh();
    _showAcademicSnack(context, result.message, isWarning: result.isWarning);
  }

  Future<void> _deleteCurriculum(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final confirmed = await _confirmAcademicDelete(
      context,
      title: 'Delete Curriculum Entry',
      message: 'Delete "${item['class']}" ${item['term'] ?? ''}?',
    );
    if (confirmed != true) return;
    try {
      await widget.storage.deleteAcademicCurriculumRecord(
        '${item['id'] ?? ''}',
      );
      widget.onRefresh();
      _showAcademicSnack(context, 'Curriculum entry deleted');
    } catch (error) {
      _showAcademicSnack(context, _academicError(error), isError: true);
    }
  }
}

class _CurriculumCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTogglePublish;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CurriculumCard({
    required this.item,
    required this.onTogglePublish,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPublished = item['published'] == true;
    final subjects =
        (item['subjects'] as List?)?.map((s) => s.toString()).toList() ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['class'] as String? ?? '',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item['term'] as String? ?? '',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onTogglePublish,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isPublished
                        ? AppTheme.successContainer
                        : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPublished
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_outlined,
                        size: 14,
                        color: isPublished ? AppTheme.success : AppTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPublished ? 'Published' : 'Draft',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPublished
                              ? AppTheme.success
                              : AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Edit curriculum',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppTheme.muted,
                  visualDensity: VisualDensity.compact,
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete curriculum',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppTheme.error,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: subjects
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AcademicSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  const _AcademicSectionHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 350;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: _academicInk,
                fontSize: compact ? 17 : 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: _academicMuted,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        );
        final action = onAction == null
            ? null
            : FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: compact ? 17 : 19),
                label: Text(actionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: _academicBlue,
                  foregroundColor: Colors.white,
                  elevation: 10,
                  shadowColor: _academicBlue.withAlpha(58),
                  minimumSize: Size(compact ? 96 : 112, compact ? 44 : 48),
                  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: GoogleFonts.dmSans(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: heading),
            if (action != null) ...[const SizedBox(width: 10), action],
          ],
        );
      },
    );
  }
}

class _AcademicSoftIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  const _AcademicSoftIcon({
    required this.icon,
    required this.color,
    required this.background,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class _AcademicStatusPill extends StatelessWidget {
  final String label;

  const _AcademicStatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F8EC),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          color: _academicGreen,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AcademicStatDivider extends StatelessWidget {
  const _AcademicStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 50, color: _academicBorder);
  }
}

class _AcademicStatBlock extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _AcademicStatBlock({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _academicInk,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            color: _academicMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _AcademicFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _AcademicFilterPill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _academicCompact(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: BoxConstraints(
            minHeight: compact ? 40 : 44,
            minWidth: compact ? 66 : 78,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 9 : 11,
          ),
          decoration: BoxDecoration(
            color: selected ? color : color.withAlpha(20),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: selected ? Colors.white : color,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _AcademicSubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _AcademicSubjectCard({
    required this.subject,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final type = _academicSubjectType(subject);
    final compact = _academicCompact(context);
    final name = _academicText(
      subject['name'] ?? subject['subject_name'],
      fallback: 'Subject',
    );
    final periods = _academicInt(
      subject['periodsPerWeek'] ?? subject['periods_per_week'],
      fallback: 0,
    );
    final teacher = _academicText(
      subject['teacher_name'] ??
          subject['teacher'] ??
          subject['assigned_teacher_name'],
      fallback: 'Teacher not assigned',
    );
    final colors = _academicSubjectColors(subject);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _academicBorder),
            boxShadow: [
              BoxShadow(
                color: _academicPanelShadow,
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: compact ? 52 : 58,
                height: compact ? 52 : 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _academicSubjectMark(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: colors.foreground,
                    fontSize: compact ? 19 : 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              SizedBox(width: compact ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: _academicInk,
                              fontSize: compact ? 14.5 : 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        _AcademicTypePill(type: type),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$periods periods / week',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: _academicMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 18),
                    Text(
                      teacher,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF52607D),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: _academicInk,
                  ),
                  tooltip: 'Subject actions',
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcademicTypePill extends StatelessWidget {
  final String type;

  const _AcademicTypePill({required this.type});

  @override
  Widget build(BuildContext context) {
    final isCore = type == 'Core';
    final color = isCore ? _academicGreen : _academicPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        type,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AcademicClassCard extends StatelessWidget {
  final Map<String, dynamic> classData;
  final String ownerRole;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _AcademicClassCard({
    required this.classData,
    required this.ownerRole,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final className = _academicText(
      classData['name'] ?? classData['grade_name'] ?? classData['class_name'],
      fallback: 'Class',
    );
    final sections = _academicStringList(classData['sections']);
    final sectionLabel = sections.isEmpty
        ? 'No section linked'
        : 'Section ${sections.first}';
    final strength = _academicInt(
      classData['student_count'] ??
          classData['students_count'] ??
          classData['total_students'] ??
          classData['strength'] ??
          classData['capacity'],
    );
    final classTeacher = _academicText(
      classData['classTeacher'] ??
          classData['class_teacher_name'] ??
          classData['teacher_name'],
      fallback: 'Teacher not assigned',
    );
    final stage = _academicText(
      classData['stage'] ??
          classData['category'] ??
          classData['level'] ??
          classData['school_stage'],
    );
    final args = _academicClassRouteArgs(classData);
    final role = ownerRole.toLowerCase();
    final compact = _academicCompact(context);
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _academicBorder),
        boxShadow: [
          BoxShadow(
            color: _academicPanelShadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _AcademicSoftIcon(
                icon: Icons.groups_rounded,
                color: _academicBlue,
                background: const Color(0xFFEAF3FF),
                size: compact ? 52 : 60,
              ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        className,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: _academicInk,
                          fontSize: compact ? 16.5 : 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (stage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2ECFF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          stage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: _academicPurple,
                            fontSize: compact ? 10 : 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: _academicInk,
                  ),
                  tooltip: 'Class actions',
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                ),
            ],
          ),
          SizedBox(height: compact ? 14 : 18),
          Container(
            padding: EdgeInsets.all(compact ? 12 : 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _academicBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3FF),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      sectionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: _academicBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: _academicBorder),
                const SizedBox(height: 14),
                _AcademicClassDetailLine(
                  icon: Icons.groups_outlined,
                  label: 'Strength',
                  value: '$strength Students',
                ),
                const SizedBox(height: 13),
                const Divider(height: 1, color: _academicBorder),
                const SizedBox(height: 13),
                _AcademicClassDetailLine(
                  icon: Icons.person_outline_rounded,
                  label: 'Class Teacher',
                  value: classTeacher,
                ),
                SizedBox(height: compact ? 14 : 16),
                Row(
                  children: [
                    Expanded(
                      child: _AcademicClassActionButton(
                        icon: Icons.menu_book_outlined,
                        label: 'Subjects',
                        color: _academicBlue,
                        onTap: () => Navigator.pushNamed(
                          context,
                          role == 'admin'
                              ? AppRoutes.academicManagement
                              : AppRoutes.principalSubjects,
                          arguments: role == 'admin' ? null : args,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: _AcademicClassActionButton(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Attendance',
                        color: _academicGreen,
                        onTap: () => Navigator.pushNamed(
                          context,
                          role == 'admin'
                              ? AppRoutes.adminAttendance
                              : AppRoutes.principalAttendance,
                          arguments: args,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Expanded(
                      child: _AcademicClassActionButton(
                        icon: Icons.calendar_month_outlined,
                        label: 'Timetable',
                        color: const Color(0xFFFF6E1F),
                        onTap: () => Navigator.pushNamed(
                          context,
                          role == 'admin'
                              ? AppRoutes.adminTimetable
                              : AppRoutes.principalTimetable,
                          arguments: args,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademicClassDetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AcademicClassDetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF54648B), size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: _academicMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: _academicInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AcademicClassActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AcademicClassActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = _academicCompact(context);

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 78 : 88),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 8,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _academicBorder),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: compact ? 23 : 27),
              SizedBox(height: compact ? 6 : 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: _academicInk,
                  fontSize: compact ? 10.5 : 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcademicYearSelector extends StatelessWidget {
  final List<Map<String, dynamic>> years;
  final String selectedYearId;
  final ValueChanged<String?> onChanged;

  const _AcademicYearSelector({
    required this.years,
    required this.selectedYearId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = years
        .map(
          (year) => DropdownMenuItem<String>(
            value: _academicYearKey(year),
            child: Text(
              _academicText(
                year['name'] ?? year['year_label'] ?? year['year'],
                fallback: 'Academic Year',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _academicBorder),
        boxShadow: [
          BoxShadow(
            color: _academicPanelShadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined, color: _academicMuted),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: items.any((item) => item.value == selectedYearId)
                    ? selectedYearId
                    : (items.isEmpty ? null : items.first.value),
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _academicInk,
                ),
                hint: Text(
                  'Select academic year',
                  style: GoogleFonts.dmSans(
                    color: _academicMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: GoogleFonts.dmSans(
                  color: _academicInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
                items: items,
                onChanged: years.isEmpty ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademicCurriculumEmptyState extends StatelessWidget {
  const _AcademicCurriculumEmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _CurriculumBookIllustration(),
        const SizedBox(height: 28),
        Text(
          'No curriculum mapped yet',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: _academicInk,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Map subjects to classes and define\nthe learning structure.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            color: _academicMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.35,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _CurriculumBookIllustration extends StatelessWidget {
  const _CurriculumBookIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 6,
            child: Container(
              width: 170,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFC6D5FF),
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: _academicBlue.withAlpha(26),
                    blurRadius: 28,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 34,
            child: Icon(
              Icons.menu_book_rounded,
              size: 118,
              color: _academicBlue.withAlpha(120),
            ),
          ),
          Positioned(
            left: 18,
            top: 40,
            child: _FloatingAcademicGlyph(
              icon: Icons.school_outlined,
              color: _academicPurple,
              bg: const Color(0xFFF2ECFF),
            ),
          ),
          Positioned(
            right: 16,
            top: 44,
            child: _FloatingAcademicGlyph(
              icon: Icons.assignment_turned_in_outlined,
              color: const Color(0xFF27B7E5),
              bg: const Color(0xFFEAF9FF),
            ),
          ),
          Positioned(
            top: 12,
            child: _FloatingAcademicGlyph(
              icon: Icons.account_balance_outlined,
              color: _academicBlue,
              bg: const Color(0xFFEAF3FF),
            ),
          ),
          Positioned(
            left: 52,
            bottom: 70,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: _academicPurple.withAlpha(75),
              size: 15,
            ),
          ),
          Positioned(
            right: 62,
            top: 26,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: _academicBlue.withAlpha(70),
              size: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingAcademicGlyph extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;

  const _FloatingAcademicGlyph({
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(24),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _AcademicEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _AcademicEmptyCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _academicBorder),
        boxShadow: [
          BoxShadow(
            color: _academicPanelShadow,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _AcademicSoftIcon(
            icon: icon,
            color: _academicBlue,
            background: const Color(0xFFEAF3FF),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: _academicInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    color: _academicMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

({Color background, Color foreground}) _academicSubjectColors(
  Map<String, dynamic> subject,
) {
  final raw = _academicText(subject['color'] ?? subject['subject_color']);
  final parsed = _tryColor(raw);
  if (parsed != null) {
    return (background: parsed.withAlpha(22), foreground: parsed);
  }
  final name = _academicText(subject['name'] ?? subject['subject_name']);
  final palettes = [
    (background: const Color(0xFFEAF3FF), foreground: _academicBlue),
    (background: const Color(0xFFEAF9EE), foreground: _academicGreen),
    (background: const Color(0xFFFFF3E5), foreground: Color(0xFFFF8B18)),
    (background: const Color(0xFFF2ECFF), foreground: _academicPurple),
    (background: const Color(0xFFFFECF4), foreground: Color(0xFFE95692)),
    (background: const Color(0xFFE8FAFC), foreground: Color(0xFF19BAC6)),
  ];
  final index = name.isEmpty
      ? 0
      : name.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
            palettes.length;
  return palettes[index];
}

Color? _tryColor(String raw) {
  final value = raw.replaceAll('#', '').trim();
  if (value.length != 6 && value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(value.length == 6 ? 0xFF000000 | parsed : parsed);
}

String _academicSubjectType(Map<String, dynamic> subject) {
  final value = _academicText(
    subject['type'] ?? subject['subject_type'],
    fallback: 'Core',
  );
  final normalized = value.toLowerCase();
  if (normalized.contains('elective')) return 'Elective';
  return 'Core';
}

String _academicSubjectMark(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'S';
  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length > 1) {
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
  return trimmed.characters.take(2).toString().toUpperCase();
}

Map<String, dynamic> _academicClassRouteArgs(Map<String, dynamic> classData) {
  final sections = _academicStringList(classData['sections']);
  final sectionName = sections.isEmpty ? '' : sections.first;
  final sectionIds = classData['sectionIds'];
  var sectionId = '';
  if (sectionIds is Map && sectionName.isNotEmpty) {
    sectionId = _academicText(sectionIds[sectionName]);
  }
  return {
    'class_id': _academicText(classData['grade_id'] ?? classData['id']),
    'classId': _academicText(classData['grade_id'] ?? classData['id']),
    'section_id': sectionId,
    'sectionId': sectionId,
    'class_name': _academicText(classData['name']),
    'className': _academicText(classData['name']),
    'section_name': sectionName,
    'sectionName': sectionName,
    'source': 'academic_management',
  };
}

List<String> _academicStringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => _academicText(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final text = _academicText(value);
  if (text.isEmpty) return const [];
  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _academicText(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}

int _academicInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  final parsed = int.tryParse(_academicText(value));
  return parsed ?? fallback;
}

String _academicYearKey(Map<String, dynamic> year) {
  return _academicText(
    year['id'] ?? year['year_label'] ?? year['name'] ?? year['year'],
  );
}

// ─── Shared Dialog Helpers ───────────────────────────────────────────────────

Future<bool?> _confirmAcademicDelete(
  BuildContext context, {
  required String title,
  required String message,
}) {
  // Confirmation-only dialog: deletion requires an explicit yes/no choice,
  // but no form input is collected.
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        title,
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
      ),
      content: Text(message, style: GoogleFonts.dmSans(fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete'),
        ),
      ],
    ),
  );
}

void _showAcademicSnack(
  BuildContext context,
  String message, {
  bool isError = false,
  bool isWarning = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: GoogleFonts.dmSans(fontSize: 13)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError
          ? AppTheme.error
          : isWarning
          ? AppTheme.warning
          : AppTheme.success,
    ),
  );
}

String _academicError(Object error) {
  final raw = error.toString();
  final server = RegExp(r'ServerException\([^)]*\):\s*(.*)').firstMatch(raw);
  if (server != null) return server.group(1)?.trim() ?? raw;
  final network = RegExp(r'NetworkException\([^)]*\):\s*(.*)').firstMatch(raw);
  if (network != null) return network.group(1)?.trim() ?? raw;
  return raw.replaceFirst('Exception: ', '').trim();
}

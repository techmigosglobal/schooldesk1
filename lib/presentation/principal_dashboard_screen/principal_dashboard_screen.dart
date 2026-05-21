import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../core/config/env_config.dart';
import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../widgets/erp_components.dart';

class PrincipalDashboardScreen extends StatefulWidget {
  const PrincipalDashboardScreen({super.key});

  @override
  State<PrincipalDashboardScreen> createState() =>
      _PrincipalDashboardScreenState();
}

class _PrincipalDashboardScreenState extends State<PrincipalDashboardScreen> {
  bool _loading = true;
  String? _error;
  int _selectedTab = 0;
  _PrincipalHomeData _data = _PrincipalHomeData.empty();

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getDashboard('principal'),
        api.getCurrentSchool(),
        api.getProfile(),
        api.getAcademicYears(),
        api.getGrades(),
        api.getSections(),
        api.getRawList('/subjects'),
        api.getStaff(page: 1, pageSize: 1),
        api.getStudents(page: 1, pageSize: 1),
        api.getFeeStructures(),
        api.getTimetableSlots(),
        api.getNotifications(),
      ]);

      final dashboard = Map<String, dynamic>.from(results[0] as Map);
      final school = Map<String, dynamic>.from(results[1] as Map);
      final profile = results[2] as UserResponse;
      final academicYears = results[3] as List<AcademicYearModel>;
      final grades = results[4] as List<GradeModel>;
      final sections = results[5] as List<SectionModel>;
      final subjects = results[6] as List<Map<String, dynamic>>;
      final staff = results[7] as PaginatedList<StaffModel>;
      final students = results[8] as PaginatedList<StudentModel>;
      final feeStructures = results[9] as List<Map<String, dynamic>>;
      final timetableSlots = results[10] as List<Map<String, dynamic>>;
      final notifications = results[11] as List<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        _data = _PrincipalHomeData.fromBackend(
          dashboard: dashboard,
          school: school,
          profile: profile,
          academicYears: academicYears,
          grades: grades,
          sections: sections,
          subjects: subjects,
          staffTotal: staff.total,
          studentsTotal: students.total,
          feeStructures: feeStructures,
          timetableSlots: timetableSlots,
          unreadNotifications: notifications
              .where((row) => row['is_read'] != true)
              .length,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FC),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _buildBody(context),
          ),
        ),
      ),
      bottomNavigationBar: _PrincipalBottomBar(
        selectedIndex: _selectedTab,
        onSelected: _handleBottomNav,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _PrincipalErrorState(message: _error!, onRetry: _loadDashboard);
    }

    final completedSetup = _data.setupSteps
        .where((step) => step.isComplete)
        .length;
    final setupTotal = _data.setupSteps.isEmpty ? 1 : _data.setupSteps.length;

    return Stack(
      children: [
        const Positioned.fill(child: _PrincipalHomePattern()),
        RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            children: [
              _PrincipalAppHeader(
                data: _data,
                onViewProfile: () => _open(AppRoutes.principalSchoolProfile),
                onNotifications: () =>
                    _open(AppRoutes.notificationCenter, arguments: 'principal'),
              ),
              const SizedBox(height: 18),
              _DashboardSearchBar(
                onTap: () =>
                    _open(AppRoutes.globalSearch, arguments: 'principal'),
              ),
              const SizedBox(height: 18),
              _SectionTitle('Academics'),
              const SizedBox(height: 12),
              _AcademicModuleGrid(
                items: [
                  _AcademicModuleItem(
                    label: 'Students',
                    route: AppRoutes.studentOversight,
                    illustration: SchoolDeskUiIllustrations.resources,
                    fallbackIcon: Icons.groups_rounded,
                    accent: const Color(0xFF60A5FA),
                  ),
                  _AcademicModuleItem(
                    label: 'Teachers',
                    route: AppRoutes.staffManagement,
                    illustration: SchoolDeskUiIllustrations.lessonPlanner,
                    fallbackIcon: Icons.co_present_rounded,
                    accent: const Color(0xFFF59E0B),
                  ),
                  _AcademicModuleItem(
                    label: 'Attendance',
                    route: AppRoutes.studentOversight,
                    illustration: SchoolDeskUiIllustrations.attendance,
                    fallbackIcon: Icons.fact_check_rounded,
                    accent: const Color(0xFF14B8A6),
                  ),
                  _AcademicModuleItem(
                    label: 'Classes',
                    route: AppRoutes.academicManagement,
                    illustration: SchoolDeskUiIllustrations.classRoutine,
                    fallbackIcon: Icons.meeting_room_rounded,
                    accent: const Color(0xFF818CF8),
                  ),
                  _AcademicModuleItem(
                    label: 'Subjects',
                    route: AppRoutes.academicManagement,
                    illustration: SchoolDeskUiIllustrations.homework,
                    fallbackIcon: Icons.menu_book_rounded,
                    accent: const Color(0xFF38BDF8),
                  ),
                  _AcademicModuleItem(
                    label: 'Timetable',
                    route: AppRoutes.timetableManagement,
                    illustration: SchoolDeskUiIllustrations.calendar,
                    fallbackIcon: Icons.calendar_month_rounded,
                    accent: const Color(0xFFF97316),
                  ),
                  _AcademicModuleItem(
                    label: 'Exams',
                    route: AppRoutes.examsResults,
                    illustration: SchoolDeskUiIllustrations.homework,
                    fallbackIcon: Icons.edit_document,
                    accent: const Color(0xFFEF4444),
                  ),
                  _AcademicModuleItem(
                    label: 'Results',
                    route: AppRoutes.examsResults,
                    illustration: SchoolDeskUiIllustrations.resources,
                    fallbackIcon: Icons.school_rounded,
                    accent: const Color(0xFF8B5CF6),
                  ),
                  _AcademicModuleItem(
                    label: 'Fees',
                    route: AppRoutes.feeMonitoring,
                    illustration: SchoolDeskUiIllustrations.fees,
                    fallbackIcon: Icons.payments_rounded,
                    accent: const Color(0xFF22C55E),
                  ),
                  _AcademicModuleItem(
                    label: 'Events',
                    route: AppRoutes.notificationCenter,
                    arguments: 'principal',
                    illustration: SchoolDeskUiIllustrations.calendar,
                    fallbackIcon: Icons.event_rounded,
                    accent: const Color(0xFFEC4899),
                  ),
                  _AcademicModuleItem(
                    label: 'Inbox',
                    route: AppRoutes.communicationCenter,
                    illustration: SchoolDeskUiIllustrations.chat,
                    fallbackIcon: Icons.mail_rounded,
                    accent: const Color(0xFF0EA5E9),
                  ),
                  _AcademicModuleItem(
                    label: 'Approvals',
                    route: AppRoutes.approvalCenter,
                    illustration: SchoolDeskUiIllustrations.notices,
                    fallbackIcon: Icons.approval_rounded,
                    accent: const Color(0xFFEF4444),
                    badge: _data.pendingApprovals,
                  ),
                ],
                onTap: (item) => _open(item.route, arguments: item.arguments),
              ),
              const SizedBox(height: 22),
              _SectionTitle('Today'),
              const SizedBox(height: 10),
              _TodaySnapshotRow(
                attendance: '${_data.attendancePct.round()}%',
                attendanceDetail:
                    '${_data.attendancePresent}/${_data.attendanceMarked}',
                fees: '${_data.collectionPct.round()}%',
                feesDetail: _data.money(_data.totalPaid),
                onAttendance: () => _open(AppRoutes.studentOversight),
                onFees: () => _open(AppRoutes.feeMonitoring),
              ),
              const SizedBox(height: 22),
              _SectionTitle('School Setup'),
              const SizedBox(height: 10),
              _SetupPreviewPanel(
                progress: completedSetup / setupTotal,
                completed: completedSetup,
                total: setupTotal,
                steps: _data.setupSteps,
                onStepTap: (step) {
                  if (step.route == null) {
                    _showGoLiveStatus();
                    return;
                  }
                  _open(step.route!);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleBottomNav(int index) {
    setState(() => _selectedTab = index);
    switch (index) {
      case 0:
        return;
      case 1:
        _open(AppRoutes.globalSearch, arguments: 'principal');
        return;
      case 2:
        _open(AppRoutes.notificationCenter, arguments: 'principal');
        return;
      case 3:
        _open(AppRoutes.profileScreen, arguments: 'principal');
        return;
    }
  }

  void _open(String route, {Object? arguments}) {
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  void _showGoLiveStatus() {
    final ready = _data.setupSteps.every((step) => step.isComplete);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            ready
                ? 'Go Live is ready. All required setup is complete.'
                : 'Complete the pending setup steps before Go Live.',
          ),
        ),
      );
  }
}

class _PrincipalHomeData {
  final String principalName;
  final String schoolName;
  final String schoolBoard;
  final String schoolLogoUrl;
  final String schoolBannerUrl;
  final int totalStudents;
  final int totalStaff;
  final int totalClasses;
  final int pendingApprovals;
  final double attendancePct;
  final int attendancePresent;
  final int attendanceMarked;
  final double collectionPct;
  final double totalPaid;
  final int unreadNotifications;
  final List<_SetupStep> setupSteps;

  const _PrincipalHomeData({
    required this.principalName,
    required this.schoolName,
    required this.schoolBoard,
    required this.schoolLogoUrl,
    required this.schoolBannerUrl,
    required this.totalStudents,
    required this.totalStaff,
    required this.totalClasses,
    required this.pendingApprovals,
    required this.attendancePct,
    required this.attendancePresent,
    required this.attendanceMarked,
    required this.collectionPct,
    required this.totalPaid,
    required this.unreadNotifications,
    required this.setupSteps,
  });

  factory _PrincipalHomeData.empty() {
    return const _PrincipalHomeData(
      principalName: 'School Principal',
      schoolName: 'School',
      schoolBoard: 'School setup',
      schoolLogoUrl: '',
      schoolBannerUrl: '',
      totalStudents: 0,
      totalStaff: 0,
      totalClasses: 0,
      pendingApprovals: 0,
      attendancePct: 0,
      attendancePresent: 0,
      attendanceMarked: 0,
      collectionPct: 0,
      totalPaid: 0,
      unreadNotifications: 0,
      setupSteps: [],
    );
  }

  factory _PrincipalHomeData.fromBackend({
    required Map<String, dynamic> dashboard,
    required Map<String, dynamic> school,
    required UserResponse profile,
    required List<AcademicYearModel> academicYears,
    required List<GradeModel> grades,
    required List<SectionModel> sections,
    required List<Map<String, dynamic>> subjects,
    required int staffTotal,
    required int studentsTotal,
    required List<Map<String, dynamic>> feeStructures,
    required List<Map<String, dynamic>> timetableSlots,
    required int unreadNotifications,
  }) {
    final metrics = Map<String, dynamic>.from(
      dashboard['metrics'] as Map? ?? {},
    );
    final fees = Map<String, dynamic>.from(dashboard['fees'] as Map? ?? {});
    final attendance = Map<String, dynamic>.from(
      dashboard['today_attendance'] as Map? ?? {},
    );
    final schoolName = _text(school['name'], fallback: 'School');
    final board = _schoolDescriptor(
      _text(school['affiliation_board']),
      _text(school['school_type']),
    );
    final registered =
        _text(school['id']).isNotEmpty ||
        _text(school['registration_number']).isNotEmpty;
    final profileReady =
        schoolName.trim().isNotEmpty &&
        _text(school['school_type']).isNotEmpty &&
        _text(school['principal_name']).isNotEmpty;
    final hasAcademicYear = academicYears.isNotEmpty;
    final hasClasses = grades.isNotEmpty || sections.isNotEmpty;
    final hasSubjects = subjects.isNotEmpty;
    final hasTeachers = staffTotal > 0;
    final hasStudents = studentsTotal > 0;
    final hasFees = feeStructures.isNotEmpty;
    final hasTimetable = timetableSlots.isNotEmpty;
    final goLiveReady = [
      registered,
      profileReady,
      hasAcademicYear,
      hasClasses,
      hasSubjects,
      hasTeachers,
      hasStudents,
      hasFees,
      hasTimetable,
    ].every((value) => value);

    return _PrincipalHomeData(
      principalName: profile.name.trim().isEmpty
          ? 'School Principal'
          : profile.name.trim(),
      schoolName: schoolName,
      schoolBoard: board.isEmpty ? 'School setup' : board,
      schoolLogoUrl: _assetUrl(_text(school['logo_url'])),
      schoolBannerUrl: _assetUrl(
        _text(
          school['banner_url'] ?? school['cover_url'] ?? school['image_url'],
        ),
      ),
      totalStudents: _intValue(metrics['total_students'], studentsTotal),
      totalStaff: _intValue(metrics['total_staff'], staffTotal),
      totalClasses: _intValue(metrics['total_classes'], sections.length),
      pendingApprovals: _intValue(metrics['pending_approvals'], 0),
      attendancePct: _doubleValue(attendance['attendance_pct']),
      attendancePresent: _doubleValue(attendance['present']).round(),
      attendanceMarked: _doubleValue(attendance['marked']).round(),
      collectionPct: _doubleValue(fees['collection_pct']),
      totalPaid: _doubleValue(fees['total_paid']),
      unreadNotifications: unreadNotifications,
      setupSteps: [
        _SetupStep(
          title: 'School Registration',
          route: AppRoutes.principalSchoolProfile,
          isComplete: registered,
        ),
        _SetupStep(
          title: 'School Profile Setup',
          route: AppRoutes.principalSchoolProfile,
          isComplete: profileReady,
        ),
        _SetupStep(
          title: 'Academic Year Setup',
          route: AppRoutes.academicManagement,
          isComplete: hasAcademicYear,
        ),
        _SetupStep(
          title: 'Classes & Sections Creation',
          route: AppRoutes.academicManagement,
          isComplete: hasClasses,
        ),
        _SetupStep(
          title: 'Subjects Setup',
          route: AppRoutes.academicManagement,
          isComplete: hasSubjects,
        ),
        _SetupStep(
          title: 'Teacher Creation',
          route: AppRoutes.staffManagement,
          isComplete: hasTeachers,
        ),
        _SetupStep(
          title: 'Student Admission Import',
          route: AppRoutes.studentOversight,
          isComplete: hasStudents,
        ),
        _SetupStep(
          title: 'Fee Structure Setup',
          route: AppRoutes.feeMonitoring,
          isComplete: hasFees,
        ),
        _SetupStep(
          title: 'Timetable Setup',
          route: AppRoutes.timetableManagement,
          isComplete: hasTimetable,
        ),
        _SetupStep(title: 'Go Live', isComplete: goLiveReady),
      ],
    );
  }

  String money(double value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(value);
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int _intValue(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _assetUrl(String path) {
    if (path.isEmpty || path.startsWith('http')) return path;
    return '${EnvConfig.apiOrigin}$path';
  }

  static String _schoolDescriptor(String board, String type) {
    final parts = <String>[];
    final seen = <String>{};
    for (final value in [board, type]) {
      final text = value.trim();
      final key = text.toLowerCase();
      if (text.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      parts.add(text.toUpperCase() == text ? text : _titleCase(text));
    }
    return parts.join(' · ');
  }

  static String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}

class _SetupStep {
  final String title;
  final String? route;
  final bool isComplete;

  const _SetupStep({required this.title, this.route, required this.isComplete});
}

class _PrincipalHomePattern extends StatelessWidget {
  const _PrincipalHomePattern();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xFFF3F7FC)),
      child: CustomPaint(painter: _PrincipalHomePatternPainter()),
    );
  }
}

class _PrincipalHomePatternPainter extends CustomPainter {
  const _PrincipalHomePatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final icons = <IconData>[
      Icons.calculate_outlined,
      Icons.menu_book_outlined,
      Icons.school_outlined,
      Icons.edit_note_outlined,
      Icons.science_outlined,
      Icons.event_note_outlined,
    ];
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    var iconIndex = 0;
    for (double y = 28; y < size.height; y += 118) {
      for (double x = 20; x < size.width; x += 128) {
        final icon = icons[iconIndex % icons.length];
        iconIndex++;
        textPainter.text = TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 28,
            color: const Color(0xFF94A3B8).withOpacity(0.08),
          ),
        );
        textPainter.layout();
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate((iconIndex.isEven ? -1 : 1) * 0.16);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PrincipalAppHeader extends StatelessWidget {
  final _PrincipalHomeData data;
  final VoidCallback onViewProfile;
  final VoidCallback onNotifications;

  const _PrincipalAppHeader({
    required this.data,
    required this.onViewProfile,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 370;
        final horizontal = compact ? 16.0 : 22.0;
        final headerHeight = compact ? 190.0 : 204.0;
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          elevation: 3,
          shadowColor: const Color(0x2A0F172A),
          child: Container(
            height: headerHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2A2E), Color(0xFF10262B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _PrincipalHeaderBackground(
                    bannerUrl: data.schoolBannerUrl,
                    logoUrl: data.schoolLogoUrl,
                  ),
                ),
                const Positioned.fill(child: _PrincipalHeaderScrim()),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    compact ? 18 : 22,
                    horizontal,
                    compact ? 16 : 22,
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, School Principal',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      (compact
                                              ? theme.textTheme.titleMedium
                                              : theme.textTheme.titleLarge)
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0,
                                            height: 1.05,
                                          ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Welcome back!',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: Colors.white.withOpacity(0.90),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                    height: 1.05,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _HeaderNotificationButton(
                            unreadCount: data.unreadNotifications,
                            onTap: onNotifications,
                          ),
                        ],
                      ),
                      const Spacer(),
                      _SchoolIdentityBanner(
                        data: data,
                        compact: compact,
                        onViewProfile: onViewProfile,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SchoolIdentityBanner extends StatelessWidget {
  final _PrincipalHomeData data;
  final bool compact;
  final VoidCallback onViewProfile;

  const _SchoolIdentityBanner({
    required this.data,
    required this.compact,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoSize = compact ? 48.0 : 54.0;
    return Row(
      children: [
        _HeaderSchoolLogo(imageUrl: data.schoolLogoUrl, size: logoSize),
        SizedBox(width: compact ? 10 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.schoolName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (compact
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.titleLarge)
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
              ),
              const SizedBox(height: 4),
              Text(
                data.schoolBoard,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.88),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: compact ? 8 : 12),
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: compact ? 104 : 118,
            maxWidth: compact ? 116 : 138,
          ),
          child: SizedBox(
            height: compact ? 50 : 54,
            child: FilledButton(
              onPressed: onViewProfile,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF111827),
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'View Profile',
                  maxLines: 1,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrincipalHeaderScrim extends StatelessWidget {
  const _PrincipalHeaderScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.34),
            Colors.black.withOpacity(0.18),
            Colors.black.withOpacity(0.46),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _HeaderNotificationButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _HeaderNotificationButton({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeText = unreadCount > 99 ? '99+' : '$unreadCount';
    return Tooltip(
      message: unreadCount > 0
          ? '$unreadCount unread notifications'
          : 'Notifications',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  badgeText,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderSchoolLogo extends StatelessWidget {
  final String imageUrl;
  final double size;

  const _HeaderSchoolLogo({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(
              Icons.account_balance_rounded,
              color: Color(0xFF587043),
              size: 31,
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.account_balance_rounded,
                color: Color(0xFF587043),
                size: 31,
              ),
            ),
    );
  }
}

class _PrincipalHeaderBackground extends StatelessWidget {
  final String bannerUrl;
  final String logoUrl;

  const _PrincipalHeaderBackground({
    required this.bannerUrl,
    required this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final banner = bannerUrl.trim();
    final logo = logoUrl.trim();
    return Stack(
      fit: StackFit.expand,
      children: [
        if (banner.isNotEmpty)
          Image.network(
            banner,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _FallbackPrincipalHeaderArt(),
          )
        else
          const _FallbackPrincipalHeaderArt(),
        if (banner.isEmpty && logo.isNotEmpty)
          Positioned(
            right: -18,
            bottom: -28,
            child: Opacity(
              opacity: 0.12,
              child: Image.network(
                logo,
                width: 138,
                height: 138,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}

class _FallbackPrincipalHeaderArt extends StatelessWidget {
  const _FallbackPrincipalHeaderArt();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PrincipalHeaderBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _PrincipalHeaderBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.08);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.34), 32, paint);
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.34),
      68,
      paint..color = Colors.white.withOpacity(0.04),
    );
    final path = Path()
      ..moveTo(size.width * 0.46, 0)
      ..lineTo(size.width * 0.70, 0)
      ..lineTo(size.width * 0.58, size.height)
      ..lineTo(size.width * 0.35, size.height)
      ..close();
    canvas.drawPath(path, paint..color = Colors.white.withOpacity(0.07));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashboardSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _DashboardSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: const Color(0x140F172A),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF64748B),
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: const Color(0xFF111827),
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _AcademicModuleGrid extends StatelessWidget {
  final List<_AcademicModuleItem> items;
  final ValueChanged<_AcademicModuleItem> onTap;

  const _AcademicModuleGrid({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        final spacing = compact ? 10.0 : 14.0;
        return GridView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: compact ? 2 : 3,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: compact ? 112 : 116,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _AcademicModuleTile(item: item, onTap: () => onTap(item));
          },
        );
      },
    );
  }
}

class _AcademicModuleItem {
  final String label;
  final String route;
  final Object? arguments;
  final String illustration;
  final IconData fallbackIcon;
  final Color accent;
  final int badge;

  const _AcademicModuleItem({
    required this.label,
    required this.route,
    this.arguments,
    required this.illustration,
    required this.fallbackIcon,
    required this.accent,
    this.badge = 0,
  });
}

class _AcademicModuleTile extends StatefulWidget {
  final _AcademicModuleItem item;
  final VoidCallback onTap;

  const _AcademicModuleTile({required this.item, required this.onTap});

  @override
  State<_AcademicModuleTile> createState() => _AcademicModuleTileState();
}

class _AcademicModuleTileState extends State<_AcademicModuleTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: _pressed ? 1 : 3,
          shadowColor: const Color(0x140F172A),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: item.accent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: SvgPicture.asset(
                                item.illustration,
                                fit: BoxFit.contain,
                                placeholderBuilder: (_) => Icon(
                                  item.fallbackIcon,
                                  color: item.accent,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 18,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: const Color(0xFF111827),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.badge > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.badge > 99 ? '99+' : '${item.badge}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
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

class _TodaySnapshotRow extends StatelessWidget {
  final String attendance;
  final String attendanceDetail;
  final String fees;
  final String feesDetail;
  final VoidCallback onAttendance;
  final VoidCallback onFees;

  const _TodaySnapshotRow({
    required this.attendance,
    required this.attendanceDetail,
    required this.fees,
    required this.feesDetail,
    required this.onAttendance,
    required this.onFees,
  });

  @override
  Widget build(BuildContext context) {
    final attendanceTile = _SnapshotTile(
      label: 'Attendance',
      value: attendance,
      detail: attendanceDetail,
      icon: Icons.how_to_reg_rounded,
      color: const Color(0xFF0EA5E9),
      onTap: onAttendance,
    );
    final feesTile = _SnapshotTile(
      label: 'Fees',
      value: fees,
      detail: feesDetail,
      icon: Icons.payments_rounded,
      color: const Color(0xFF22C55E),
      onTap: onFees,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            children: [attendanceTile, const SizedBox(height: 10), feesTile],
          );
        }
        return Row(
          children: [
            Expanded(child: attendanceTile),
            const SizedBox(width: 10),
            Expanded(child: feesTile),
          ],
        );
      },
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SnapshotTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: const Color(0x120F172A),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupPreviewPanel extends StatelessWidget {
  final double progress;
  final int completed;
  final int total;
  final List<_SetupStep> steps;
  final ValueChanged<_SetupStep> onStepTap;

  const _SetupPreviewPanel({
    required this.progress,
    required this.completed,
    required this.total,
    required this.steps,
    required this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = steps.where((step) => !step.isComplete).take(4).toList();
    final visibleSteps = pending.isEmpty ? steps.take(4).toList() : pending;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: const Color(0x140F172A),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFEFF8FF)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Go Live Progress',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$completed/$total setup steps complete',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress.clamp(0, 1) * 100).round()}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF2563EB),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress.clamp(0, 1),
                backgroundColor: const Color(0xFFE2E8F0),
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final step in visibleSteps)
                  _SetupStepChip(step: step, onTap: () => onStepTap(step)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStepChip extends StatelessWidget {
  final _SetupStep step;
  final VoidCallback onTap;

  const _SetupStepChip({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final complete = step.isComplete;
    final color = complete ? const Color(0xFF16A34A) : const Color(0xFF2563EB);
    return Material(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 72,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  complete
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 15,
                  color: color,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    step.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
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

class _PrincipalBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PrincipalBottomBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.home_rounded),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.search_rounded),
            icon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.mail_rounded),
            icon: Icon(Icons.mail_outline_rounded),
            label: 'Inbox',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person_rounded),
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _PrincipalErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PrincipalErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: Color(0xFFB91C1C),
            ),
            const SizedBox(height: 12),
            Text(
              'Dashboard unavailable',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

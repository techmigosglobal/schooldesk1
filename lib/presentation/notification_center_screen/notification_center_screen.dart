import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../routes/app_routes.dart';
import '../../services/notification_service.dart';
import '../../services/notification_route_resolver.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/parent_navigation.dart';
import '../../widgets/teacher_navigation.dart';

class NotificationCenterScreen extends StatefulWidget {
  final String role;
  const NotificationCenterScreen({super.key, required this.role});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NotificationService? _service;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _init();
  }

  Future<void> _init() async {
    try {
      _service = await NotificationService.getInstance();
    } catch (_) {
      // Keep the notification center usable even if the backend is temporarily unavailable.
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<AppNotification> _filtered(String? category) {
    final all = _service?.getNotificationsForRole(widget.role) ?? [];
    if (category == null) return all;
    return all.where((n) => n.category == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF151C26) : AppTheme.background;
    final surfaceColor = isDark ? const Color(0xFF1E2530) : AppTheme.surface;
    final onSurfaceColor = isDark
        ? const Color(0xFFE8EDF2)
        : AppTheme.onSurface;
    final mutedColor = isDark ? const Color(0xFF90A4AE) : AppTheme.muted;

    return SchoolDeskModuleScaffold(
      title: 'Notifications',
      subtitle: '${_roleLabel(widget.role)} alerts and updates',
      drawer: _drawerForRole(),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await _service?.markAllAsRead(widget.role);
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.done_all_rounded, size: 18),
          label: const Text('Mark all read'),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 12),
        labelColor: AppTheme.primary,
        unselectedLabelColor: mutedColor,
        indicatorColor: AppTheme.primary,
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Approvals'),
          Tab(text: 'Fees'),
          Tab(text: 'Exams'),
          Tab(text: 'Circulars'),
        ],
      ),
      body: ColoredBox(
        color: bgColor,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildList(
                    null,
                    bgColor,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                  ),
                  _buildList(
                    NotificationCategory.pendingApproval,
                    bgColor,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                  ),
                  _buildList(
                    NotificationCategory.feeDue,
                    bgColor,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                  ),
                  _buildList(
                    NotificationCategory.examReminder,
                    bgColor,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                  ),
                  _buildList(
                    NotificationCategory.general,
                    bgColor,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _drawerForRole() {
    switch (widget.role.trim().toLowerCase()) {
      case 'principal':
        return PrincipalDrawer(
          selectedIndex: 99,
          onDestinationSelected: (_) {},
        );
      case 'teacher':
        return TeacherDrawer(selectedIndex: 99, onDestinationSelected: (_) {});
      case 'parent':
        return ParentDrawer(selectedIndex: 99, onDestinationSelected: (_) {});
      case 'admin':
      default:
        return AdminDrawer(selectedIndex: 99, onDestinationSelected: (_) {});
    }
  }

  String _roleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'principal':
        return 'Principal';
      case 'teacher':
        return 'Teacher';
      case 'parent':
        return 'Parent';
      case 'admin':
      default:
        return 'Admin';
    }
  }

  Widget _buildList(
    String? category,
    Color bgColor,
    Color surfaceColor,
    Color onSurfaceColor,
    Color mutedColor,
  ) {
    final items = _filtered(category);
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 48, color: mutedColor),
            const SizedBox(height: 12),
            Text(
              'No notifications',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: mutedColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) =>
          _buildNotifCard(items[i], surfaceColor, onSurfaceColor, mutedColor),
    );
  }

  Widget _buildNotifCard(
    AppNotification notif,
    Color surfaceColor,
    Color onSurfaceColor,
    Color mutedColor,
  ) {
    final categoryIcon = _getCategoryIcon(notif.category);
    final categoryColor = _getCategoryColor(notif.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadBg = isDark
        ? const Color(0xFF1A3A5C)
        : AppTheme.primaryContainer;
    final outlineColor = isDark
        ? const Color(0xFF2D3748)
        : AppTheme.outlineVariant;

    return GestureDetector(
      onTap: () async {
        await _service?.markAsRead(notif.id);
        if (mounted) setState(() {});
        if (!mounted) return;
        final target = NotificationRouteResolver.resolve(
          data: notif.routingData,
          currentRole: widget.role,
        );
        if (target.route != AppRoutes.notificationCenter) {
          await Navigator.of(
            context,
          ).pushNamed(target.route, arguments: target.arguments);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? surfaceColor : unreadBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notif.isRead
                ? outlineColor
                : AppTheme.primaryLight.withAlpha(80),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: categoryColor.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(categoryIcon, color: categoryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: onSurfaceColor,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: categoryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: GoogleFonts.dmSans(fontSize: 12, color: mutedColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildPriorityChip(notif.priority),
                      const Spacer(),
                      Text(
                        _formatTime(notif.timestamp),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(NotificationPriority priority) {
    final label = priority == NotificationPriority.high
        ? 'High'
        : priority == NotificationPriority.medium
        ? 'Medium'
        : 'Low';
    final color = priority == NotificationPriority.high
        ? AppTheme.error
        : priority == NotificationPriority.medium
        ? AppTheme.warning
        : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case NotificationCategory.pendingApproval:
        return Icons.pending_actions_rounded;
      case NotificationCategory.feeDue:
        return Icons.account_balance_wallet_rounded;
      case NotificationCategory.examReminder:
        return Icons.quiz_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case NotificationCategory.pendingApproval:
        return AppTheme.warning;
      case NotificationCategory.feeDue:
        return AppTheme.error;
      case NotificationCategory.examReminder:
        return AppTheme.primary;
      default:
        return AppTheme.muted;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    // Handle future timestamps gracefully
    if (diff.isNegative) return 'Just now';
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }
}

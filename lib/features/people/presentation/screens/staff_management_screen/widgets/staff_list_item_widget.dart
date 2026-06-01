import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/status_badge_widget.dart';
import 'package:schooldesk1/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart';

class StaffListItemWidget extends StatefulWidget {
  final StaffModel staff;
  final int animationIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const StaffListItemWidget({
    super.key,
    required this.staff,
    required this.animationIndex,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<StaffListItemWidget> createState() => _StaffListItemWidgetState();
}

class _StaffListItemWidgetState extends State<StaffListItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    final delay = (widget.animationIndex * 50).clamp(0, 400);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  BadgeStatus _getStatusBadge() {
    switch (widget.staff.status) {
      case 'active':
        return BadgeStatus.active;
      case 'on_leave':
        return BadgeStatus.onLeave;
      case 'absent':
        return BadgeStatus.absent;
      default:
        return BadgeStatus.inactive;
    }
  }

  Color _getAvatarColor() {
    switch (widget.staff.status) {
      case 'active':
        return AppTheme.primary;
      case 'on_leave':
        return AppTheme.info;
      case 'absent':
        return AppTheme.error;
      default:
        return AppTheme.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Dismissible(
          key: Key(widget.staff.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                const SizedBox(height: 4),
                Text(
                  'Remove',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            widget.onDelete();
            return false;
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant, width: 1),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              children: [
                // Main row
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    splashColor: AppTheme.primary.withAlpha(15),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getAvatarColor(),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                widget.staff.avatarInitials,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.staff.name,
                                        style: GoogleFonts.ibmPlexSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    StatusBadgeWidget(
                                      status: _getStatusBadge(),
                                      compact: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      widget.staff.employeeId,
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.muted,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.muted,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.staff.designation,
                                      style: GoogleFonts.ibmPlexSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _buildMetaChip(
                                      Icons.class_rounded,
                                      widget.staff.assignedClasses
                                          .take(2)
                                          .join(', '),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildMetaChip(
                                      Icons.beach_access_rounded,
                                      '${widget.staff.leaveBalance} leaves',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildAttendanceChip(
                                      widget.staff.attendancePercent,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Actions
                          Column(
                            children: [
                              IconButton(
                                onPressed: widget.onEdit,
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                color: AppTheme.primary,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              Icon(
                                _isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppTheme.muted,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Expanded detail
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: _buildExpandedDetail(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDetail() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Designation', widget.staff.designation),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      'Subjects',
                      widget.staff.subjects.join(', '),
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      'Classes',
                      widget.staff.assignedClasses.join(', '),
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow('Joined', widget.staff.joinDate),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Phone', widget.staff.phone),
                    const SizedBox(height: 6),
                    _buildDetailRow('Email', widget.staff.email),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      'Attendance',
                      '${widget.staff.attendancePercent.toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      'Leave Balance',
                      '${widget.staff.leaveBalance} days remaining',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Attendance progress bar
          Row(
            children: [
              Text(
                'Attendance',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.muted,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.staff.attendancePercent.toStringAsFixed(1)}%',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: widget.staff.attendancePercent >= 90
                      ? AppTheme.success
                      : AppTheme.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.staff.attendancePercent / 100,
              backgroundColor: AppTheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.staff.attendancePercent >= 90
                    ? AppTheme.success
                    : AppTheme.warning,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppTheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.muted),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: AppTheme.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceChip(double percent) {
    final color = percent >= 90 ? AppTheme.success : AppTheme.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.bar_chart_rounded, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          '${percent.toStringAsFixed(1)}%',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

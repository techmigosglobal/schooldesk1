import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/people/presentation/screens/approval_center_screen/approval_center_screen.dart';

class ApprovalItemWidget extends StatefulWidget {
  final ApprovalModel approval;
  final VoidCallback onApprove;
  final Function(String remarks) onReject;
  final Function(String note) onRequestChanges;
  final bool isActionLoading;

  const ApprovalItemWidget({
    super.key,
    required this.approval,
    required this.onApprove,
    required this.onReject,
    required this.onRequestChanges,
    this.isActionLoading = false,
  });

  @override
  State<ApprovalItemWidget> createState() => _ApprovalItemWidgetState();
}

class _ApprovalItemWidgetState extends State<ApprovalItemWidget> {
  bool _isExpanded = false;

  Color _getTypeColor() {
    switch (widget.approval.type) {
      case ApprovalType.account:
        return AppTheme.primary;
      case ApprovalType.leave:
        return AppTheme.info;
      case ApprovalType.studentLeave:
        return AppTheme.info;
      case ApprovalType.admission:
        return AppTheme.success;
      case ApprovalType.feeConcession:
        return AppTheme.warning;
      case ApprovalType.fee:
        return AppTheme.warning;
      case ApprovalType.tc:
        return AppTheme.secondary;
      case ApprovalType.classApproval:
        return AppTheme.primary;
      case ApprovalType.student:
        return AppTheme.success;
      case ApprovalType.event:
        return AppTheme.primary;
      case ApprovalType.timetable:
        return AppTheme.error;
      case ApprovalType.exam:
        return AppTheme.secondary;
      case ApprovalType.document:
        return AppTheme.primary;
      case ApprovalType.communication:
        return AppTheme.info;
      case ApprovalType.helpdesk:
        return AppTheme.warning;
      case ApprovalType.academicInfo:
        return AppTheme.primary;
    }
  }

  IconData _getTypeIcon() {
    switch (widget.approval.type) {
      case ApprovalType.account:
        return Icons.manage_accounts_rounded;
      case ApprovalType.leave:
        return Icons.event_busy_rounded;
      case ApprovalType.studentLeave:
        return Icons.event_available_rounded;
      case ApprovalType.admission:
        return Icons.how_to_reg_rounded;
      case ApprovalType.feeConcession:
        return Icons.account_balance_wallet_rounded;
      case ApprovalType.fee:
        return Icons.payments_rounded;
      case ApprovalType.tc:
        return Icons.description_rounded;
      case ApprovalType.classApproval:
        return Icons.class_rounded;
      case ApprovalType.student:
        return Icons.school_rounded;
      case ApprovalType.event:
        return Icons.celebration_rounded;
      case ApprovalType.timetable:
        return Icons.schedule_rounded;
      case ApprovalType.exam:
        return Icons.quiz_rounded;
      case ApprovalType.document:
        return Icons.description_rounded;
      case ApprovalType.communication:
        return Icons.campaign_rounded;
      case ApprovalType.helpdesk:
        return Icons.support_agent_rounded;
      case ApprovalType.academicInfo:
        return Icons.auto_stories_rounded;
    }
  }

  String _getTypeLabel() {
    switch (widget.approval.type) {
      case ApprovalType.account:
        return 'Account';
      case ApprovalType.leave:
        return 'Leave';
      case ApprovalType.studentLeave:
        return 'Student Leave';
      case ApprovalType.admission:
        return 'Admission';
      case ApprovalType.feeConcession:
        return 'Fee Concession';
      case ApprovalType.fee:
        return 'Fee';
      case ApprovalType.tc:
        return 'TC Request';
      case ApprovalType.classApproval:
        return 'Class';
      case ApprovalType.student:
        return 'Student';
      case ApprovalType.event:
        return 'Event';
      case ApprovalType.timetable:
        return 'Timetable';
      case ApprovalType.exam:
        return 'Exam';
      case ApprovalType.document:
        return 'Document';
      case ApprovalType.communication:
        return 'Communication';
      case ApprovalType.helpdesk:
        return 'Helpdesk';
      case ApprovalType.academicInfo:
        return 'Academic Info';
    }
  }

  Future<void> _openRejectPage() async {
    final remarks = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _ApprovalRejectPage(approval: widget.approval),
      ),
    );
    if (remarks == null) return;
    widget.onReject(remarks);
  }

  Future<void> _openRequestChangesPage() async {
    final note = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _ApprovalRejectPage(
          approval: widget.approval,
          title: 'Request Changes',
          fieldLabel: 'Change request note',
          hintText: 'Tell Admin what needs to change...',
          actionLabel: 'Request changes',
          icon: Icons.edit_note_rounded,
          color: AppTheme.warning,
        ),
      ),
    );
    if (note == null) return;
    widget.onRequestChanges(note);
  }

  Widget _statusChip(bool isPending, bool isApproved, bool isChangesRequested) {
    final color = isPending || isChangesRequested
        ? AppTheme.warning
        : isApproved
        ? AppTheme.success
        : AppTheme.error;
    final containerColor = isPending || isChangesRequested
        ? AppTheme.warningContainer
        : isApproved
        ? AppTheme.successContainer
        : AppTheme.errorContainer;
    final icon = isPending
        ? Icons.hourglass_empty_rounded
        : isChangesRequested
        ? Icons.edit_note_rounded
        : isApproved
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;
    final label = isPending
        ? 'Pending'
        : isChangesRequested
        ? 'Changes requested'
        : isApproved
        ? 'Approved'
        : 'Rejected';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(Color typeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: typeColor.withAlpha(31),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _getTypeLabel(),
        style: GoogleFonts.ibmPlexSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: typeColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _metaPill({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.muted),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 230),
          child: Text(
            text,
            style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppTheme.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isBusy) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;
        final rejectButton = OutlinedButton.icon(
          onPressed: isBusy ? null : _openRejectPage,
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('Reject'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.error,
            side: const BorderSide(color: AppTheme.error, width: 1),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        final changesButton = OutlinedButton.icon(
          onPressed: isBusy ? null : _openRequestChangesPage,
          icon: const Icon(Icons.edit_note_rounded, size: 16),
          label: const Text('Request changes'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.warning,
            side: const BorderSide(color: AppTheme.warning, width: 1),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        final approveButton = ElevatedButton.icon(
          onPressed: isBusy ? null : widget.onApprove,
          icon: isBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 16),
          label: Text(isBusy ? 'Working…' : 'Approve'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: double.infinity, child: approveButton),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: changesButton),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: rejectButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: rejectButton),
            const SizedBox(width: 10),
            Expanded(child: changesButton),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: approveButton),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.approval.status == 'pending';
    final isApproved = widget.approval.status == 'approved';
    final isChangesRequested = widget.approval.status == 'changes_requested';
    final typeColor = _getTypeColor();
    final isBusy = widget.isActionLoading;
    final requesterMeta = [
      widget.approval.requesterRole.trim(),
      widget.approval.requesterClass.trim(),
    ].where((value) => value.isNotEmpty).join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isPending || isChangesRequested
            ? Border.all(color: AppTheme.warning.withAlpha(77), width: 1)
            : Border.all(color: AppTheme.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Left accent border + content
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left color accent
                Container(
                  width: 4,
                  color: isPending || isChangesRequested
                      ? AppTheme.warning
                      : isApproved
                      ? AppTheme.success
                      : AppTheme.error,
                ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      splashColor: typeColor.withAlpha(15),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: typeColor.withAlpha(31),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getTypeIcon(),
                                    color: typeColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          _typeChip(typeColor),
                                          _statusChip(
                                            isPending,
                                            isApproved,
                                            isChangesRequested,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        widget.approval.requesterName,
                                        style: GoogleFonts.ibmPlexSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.onSurface,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (requesterMeta.isNotEmpty)
                                        Text(
                                          requesterMeta,
                                          style: GoogleFonts.ibmPlexSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                            color: AppTheme.muted,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.approval.summary,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.onSurface,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 6,
                                    children: [
                                      _metaPill(
                                        icon: Icons.calendar_today_rounded,
                                        text:
                                            'Submitted ${widget.approval.submittedDate}',
                                      ),
                                      if (widget.approval.actionDate != null)
                                        _metaPill(
                                          icon: Icons.done_all_rounded,
                                          text:
                                              'Actioned ${widget.approval.actionDate}',
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                ),
              ],
            ),
          ),
          // Expanded detail
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedSection(),
          ),
          // Action buttons for pending
          if (isPending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.outlineVariant, width: 1),
                ),
              ),
              child: _buildActionButtons(isBusy),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'Request Details',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              widget.approval.details,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.onSurface,
                height: 1.6,
              ),
            ),
          ),
          if (widget.approval.remarks != null) ...[
            const SizedBox(height: 12),
            Text(
              'Principal\'s Remarks',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.approval.status == 'approved'
                    ? AppTheme.successContainer
                    : AppTheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.approval.status == 'approved'
                      ? AppTheme.success.withAlpha(77)
                      : AppTheme.error.withAlpha(77),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    widget.approval.status == 'approved'
                        ? Icons.check_circle_outline_rounded
                        : Icons.cancel_outlined,
                    size: 16,
                    color: widget.approval.status == 'approved'
                        ? AppTheme.success
                        : AppTheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.approval.remarks!,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: widget.approval.status == 'approved'
                            ? AppTheme.success
                            : AppTheme.error,
                        height: 1.5,
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

class _ApprovalRejectPage extends StatefulWidget {
  final ApprovalModel approval;
  final String title;
  final String fieldLabel;
  final String hintText;
  final String actionLabel;
  final IconData icon;
  final Color color;

  const _ApprovalRejectPage({
    required this.approval,
    this.title = 'Reject Request',
    this.fieldLabel = 'Rejection reason',
    this.hintText = 'Enter rejection reason...',
    this.actionLabel = 'Reject',
    this.icon = Icons.close_rounded,
    this.color = AppTheme.error,
  });

  @override
  State<_ApprovalRejectPage> createState() => _ApprovalRejectPageState();
}

class _ApprovalRejectPageState extends State<_ApprovalRejectPage> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, _remarksController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.approval.summary,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.approval.details,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _remarksController,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: widget.fieldLabel,
                  hintText: widget.hintText,
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: widget.color, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (value) {
                  final remarks = value?.trim() ?? '';
                  if (remarks.isEmpty) {
                    return 'Enter ${widget.fieldLabel.toLowerCase()}';
                  }
                  if (remarks.length < 8) return 'Add more detail';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submit,
                icon: Icon(widget.icon, size: 16),
                style: FilledButton.styleFrom(backgroundColor: widget.color),
                label: Text(widget.actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

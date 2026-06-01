import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

@immutable
class AccountChildAssignmentArgs {
  final String ownerRole;
  final String parentUserId;
  final String parentName;
  final String parentEmail;

  const AccountChildAssignmentArgs({
    required this.ownerRole,
    required this.parentUserId,
    required this.parentName,
    required this.parentEmail,
  });

  bool get isPrincipalOwner => ownerRole.toLowerCase() == 'principal';
}

class AccountChildAssignmentScreen extends StatefulWidget {
  final AccountChildAssignmentArgs args;

  const AccountChildAssignmentScreen({super.key, required this.args});

  @override
  State<AccountChildAssignmentScreen> createState() =>
      _AccountChildAssignmentScreenState();
}

class _AccountChildAssignmentScreenState
    extends State<AccountChildAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _admissionController = TextEditingController();
  bool _saving = false;
  String? _feedback;

  @override
  void dispose() {
    _admissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = widget.args.isPrincipalOwner
        ? PrincipalDrawer(selectedIndex: 1, onDestinationSelected: (_) {})
        : AdminDrawer(selectedIndex: 10, onDestinationSelected: (_) {});

    return SchoolDeskModuleScaffold(
      title: 'Assign Children',
      subtitle: 'Link parent login to student admission records',
      drawer: drawer,
      bodyIsScrollable: true,
      actions: [
        IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close_rounded),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        IconButton(
          tooltip: 'Assign children',
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          onPressed: _saving ? null : _assignChildren,
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildParentSummary(),
                  const SizedBox(height: 16),
                  if (_feedback != null) ...[
                    _buildFeedback(_feedback!),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.outlineVariant),
                    ),
                    child: TextFormField(
                      controller: _admissionController,
                      minLines: 5,
                      maxLines: 8,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Admission numbers *',
                        hintText: 'ADM001, ADM002\nADM003',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (value) {
                        if (_parseAdmissions().isEmpty) {
                          return 'Enter at least one admission number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _assignChildren,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.link_rounded),
                          label: const Text('Assign Children'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParentSummary() {
    final email = widget.args.parentEmail.trim();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.infoContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.info.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.family_restroom_rounded, color: AppTheme.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.args.parentName,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.muted,
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

  Widget _buildFeedback(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _parseAdmissions() {
    return _admissionController.text
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _assignChildren() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _feedback = null;
    });
    try {
      await BackendApiClient.instance.assignParentStudents(
        parentUserId: widget.args.parentUserId,
        admissionNumbers: _parseAdmissions(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _feedback = 'Assignment failed: $e';
      });
    }
  }
}

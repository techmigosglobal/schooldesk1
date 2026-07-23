import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

/// Role-gated branch selector. The backend validates membership on every
/// scoped request; this widget only changes the active presentation context.
class BranchSwitcher extends StatefulWidget {
  final bool canCreate;
  final Future<void> Function()? onChanged;

  const BranchSwitcher({super.key, this.canCreate = false, this.onChanged});

  @override
  State<BranchSwitcher> createState() => _BranchSwitcherState();
}

class _BranchSwitcherState extends State<BranchSwitcher> {
  List<Map<String, dynamic>> _branches = const [];
  bool _loading = true;
  bool _saving = false;

  // A dialog's Future completes as soon as it is popped, while its exit
  // animation can still rebuild the TextField. Disposing its controllers at
  // that point caused the branch dialog to crash after a successful save.
  void _disposeDialogControllers(Iterable<TextEditingController> controllers) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final branches = await BackendApiClient.instance.getBranches();
      if (mounted) setState(() => _branches = branches);
    } on Object catch (_) {
      // A single-branch deployment may not have the migration yet. Hide the
      // add-on rather than blocking the established dashboard workflow.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(String? id) async {
    if (id == null || id == BackendApiClient.instance.activeBranchId) return;
    await BackendApiClient.instance.setActiveBranchId(id);
    await widget.onChanged?.call();
    if (mounted) setState(() {});
  }

  Future<void> _createBranch() async {
    final name = TextEditingController();
    final code = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add branch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Branch name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              decoration: const InputDecoration(
                labelText: 'Branch code (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'name': name.text.trim(),
              'branch_code': code.text.trim(),
            }),
            child: const Text('Create branch'),
          ),
        ],
      ),
    );
    _disposeDialogControllers([name, code]);
    if (result == null || (result['name'] ?? '').isEmpty) return;
    try {
      final created = await BackendApiClient.instance.createBranch(result);
      await _load();
      await _select(created['id']?.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Branch created. All organization principals can now access it.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create branch: $error')),
        );
      }
    }
  }

  Future<void> _editBranch(Map<String, dynamic> branch) async {
    final branchId = branch['id']?.toString() ?? '';
    if (branchId.isEmpty) return;
    final name = TextEditingController(text: branch['name']?.toString() ?? '');
    final code = TextEditingController(
      text: branch['branch_code']?.toString() ?? '',
    );
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename branch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Branch name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Branch code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'name': name.text.trim(),
              'branch_code': code.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    _disposeDialogControllers([name, code]);
    if (result == null || (result['name'] ?? '').isEmpty || !mounted) return;
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.updateBranch(branchId, result);
      await _load();
      await widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branch details updated.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update branch: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteBranch(Map<String, dynamic> branch) async {
    if (_branches.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An organization must keep one branch.')),
      );
      return;
    }
    final branchId = branch['id']?.toString() ?? '';
    final branchName = branch['name']?.toString().trim() ?? 'Branch';
    if (branchId.isEmpty) return;
    final firstConfirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete branch and all its data?'),
        content: Text(
          'This permanently deletes $branchName and its students, staff, fees, classes, posts, notifications, and other branch-only data. Leadership accounts are moved to another branch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (firstConfirmation != true || !mounted) return;

    final confirmation = TextEditingController();
    final expected = 'DELETE $branchName';
    final finalConfirmation = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Final branch deletion confirmation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Type the following exactly to permanently delete this branch:',
              ),
              const SizedBox(height: 8),
              SelectableText(
                expected,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmation,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Confirmation text',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: confirmation.text.trim() == expected
                  ? () => Navigator.pop(context, confirmation.text.trim())
                  : null,
              child: const Text('Delete branch'),
            ),
          ],
        ),
      ),
    );
    _disposeDialogControllers([confirmation]);
    if (finalConfirmation != expected || !mounted) return;
    setState(() => _saving = true);
    try {
      final result = await BackendApiClient.instance.deleteBranch(
        branchId,
        confirmation: expected,
      );
      final replacementId = result['reassigned_to_branch_id']?.toString();
      if (BackendApiClient.instance.activeBranchId == branchId &&
          replacementId != null &&
          replacementId.isNotEmpty) {
        await BackendApiClient.instance.setActiveBranchId(replacementId);
      }
      await _load();
      await widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branch and its data were deleted.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete branch: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _branches.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final active = BackendApiClient.instance.activeBranchId;
    final selected = _branches.any((branch) => branch['id'] == active)
        ? active
        : _branches.first['id']?.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.schoolDesk.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.schoolDesk.panelBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.account_tree_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selected,
                onChanged: _select,
                items: _branches
                    .map(
                      (branch) => DropdownMenuItem(
                        value: branch['id']?.toString(),
                        child: Text(
                          branch['name']?.toString() ?? 'Branch',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          if (widget.canCreate) ...[
            PopupMenuButton<String>(
              tooltip: 'Branch actions',
              enabled: !_saving,
              onSelected: (action) {
                final branch = _branches.firstWhere(
                  (row) => row['id']?.toString() == selected,
                  orElse: () => _branches.first,
                );
                if (action == 'edit') {
                  _editBranch(branch);
                } else if (action == 'delete') {
                  _deleteBranch(branch);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 12),
                      Text('Rename branch'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: _branches.length > 1,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline_rounded, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete branch'),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Add branch',
              onPressed: _saving ? null : _createBranch,
              icon: const Icon(Icons.add_business_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

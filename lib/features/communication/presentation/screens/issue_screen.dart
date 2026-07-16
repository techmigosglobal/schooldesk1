import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/teacher_navigation.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';

enum IssueScreenRole { principal, teacher, parent, superAdmin }

class IssueScreen extends StatefulWidget {
  const IssueScreen({super.key, required this.role});
  final IssueScreenRole role;
  @override
  State<IssueScreen> createState() => _IssueScreenState();
}

class _IssueScreenState extends State<IssueScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _issues = const [];
  bool _loading = true;
  String? _error;
  bool get _isSuperAdmin => widget.role == IssueScreenRole.superAdmin;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) setState(() {});
      });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final issues = await BackendApiClient.instance.getIssues();
      if (mounted) setState(() => _issues = issues);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Issues are unavailable. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visible {
    if (_isSuperAdmin) {
      const statuses = ['pending', 'in_progress', 'resolved'];
      return _issues
          .where((issue) => '${issue['status']}' == statuses[_tabs.index])
          .toList();
    }
    if (_tabs.index == 0) {
      return _issues
          .where(
            (issue) =>
                ['pending', 'in_progress'].contains('${issue['status']}'),
          )
          .toList();
    }
    if (_tabs.index == 1) {
      return _issues
          .where((issue) => '${issue['status']}' == 'resolved')
          .toList();
    }
    return _issues;
  }

  Future<void> _raiseIssue() async {
    final draft = await showDialog<_IssueDraft>(
      context: context,
      builder: (_) => const _RaiseIssueDialog(),
    );
    if (draft == null) return;
    setState(() => _loading = true);
    try {
      await BackendApiClient.instance.createIssueWithAttachments(
        draft.payload,
        draft.files
            .map(
              (file) => {
                'name': file.name,
                'path': file.path,
                'bytes': file.bytes,
              },
            )
            .toList(),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue raised and sent to Super Admin.'),
          ),
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'The issue or one of its attachments could not be submitted. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(Map<String, dynamic> issue, String status) async {
    String note = '';
    if (status == 'resolved') {
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Resolve issue'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Resolution note'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Resolve'),
            ),
          ],
        ),
      );
      if (result == null || result.isEmpty) return;
      note = result;
    }
    try {
      await BackendApiClient.instance.updateIssue(
        '${issue['id']}',
        status: status,
        resolutionNote: note,
      );
      await _load();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update issue.')),
        );
      }
    }
  }

  Future<void> _openAttachment(
    Map<String, dynamic> issue,
    Map attachment,
  ) async {
    try {
      final url = await BackendApiClient.instance.issueAttachmentUrl(
        '${issue['id']}',
        '${attachment['id']}',
      );
      if (!mounted) return;
      final mime = '${attachment['mime_type'] ?? ''}';
      final item = EventPostMediaItem(
        url: url,
        name: '${attachment['file_name'] ?? 'Attachment'}',
        mimeType: mime,
        kind: EventPostMediaItem.fromUrl(
          '${attachment['file_name'] ?? ''}',
          mimeType: mime,
        ).kind,
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _IssueAttachmentPreviewScreen(item: item),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment is unavailable.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawer = switch (widget.role) {
      IssueScreenRole.principal => PrincipalDrawer(
        selectedIndex: PrincipalNav.guardians,
        onDestinationSelected: (_) {},
      ),
      IssueScreenRole.teacher => TeacherDrawer(
        selectedIndex: TeacherNav.complaints,
        onDestinationSelected: (_) {},
      ),
      IssueScreenRole.parent => ParentDrawer(
        selectedIndex: ParentNav.complaints,
        onDestinationSelected: (_) {},
      ),
      IssueScreenRole.superAdmin => SuperAdminDrawer(
        selectedIndex: SuperAdminNav.complaints,
        onDestinationSelected: (_) {},
      ),
    };
    final title = _isSuperAdmin ? 'Issue Management' : 'Raise an Issue';
    final labels = _isSuperAdmin
        ? const ['Pending', 'In Progress', 'Resolved']
        : const ['Pending', 'Resolved', 'Past'];
    return SchoolDeskModuleScaffold(
      title: title,
      subtitle: _isSuperAdmin
          ? 'Review and resolve issues raised by school users'
          : 'Submit and track issues with Super Admin',
      drawer: drawer,
      floatingActionButton: _isSuperAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: _raiseIssue,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Raise Issue'),
            ),
      bottom: TabBar(
        controller: _tabs,
        tabs: labels.map((label) => Tab(text: label)).toList(),
      ),
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: FilledButton(onPressed: _load, child: Text(_error!)),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _visible.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('No issues found.')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _IssueCard(
                        issue: _visible[index],
                        superAdmin: _isSuperAdmin,
                        onUpdate: _update,
                        onOpenAttachment: _openAttachment,
                      ),
                    ),
            ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({
    required this.issue,
    required this.superAdmin,
    required this.onUpdate,
    required this.onOpenAttachment,
  });
  final Map<String, dynamic> issue;
  final bool superAdmin;
  final Future<void> Function(Map<String, dynamic>, String) onUpdate;
  final Future<void> Function(Map<String, dynamic>, Map) onOpenAttachment;
  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse('${issue['created_at'] ?? ''}');
    final attachments = (issue['issue_attachments'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final status = '${issue['status'] ?? 'pending'}';
    final statusColor = switch (status) {
      'resolved' => Theme.of(context).colorScheme.primary,
      'in_progress' => Theme.of(context).colorScheme.tertiary,
      _ => Theme.of(context).colorScheme.secondary,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${issue['title']}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            Text('${issue['category']} · ${issue['priority']}'.toUpperCase()),
            const SizedBox(height: 8),
            Text('${issue['description']}'),
            if (superAdmin)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Raised by: ${issue['raised_by_role'] ?? 'user'}'),
              ),
            if (created != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  DateFormat('d MMM yyyy, h:mm a').format(created.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if ('${issue['resolution_note'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Resolution: ${issue['resolution_note']}'),
              ),
            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attachments (${attachments.length}/5)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: attachments
                          .map(
                            (attachment) => _IssueAttachmentThumbnail(
                              issueId: '${issue['id']}',
                              attachment: attachment,
                              onOpen: () => onOpenAttachment(issue, attachment),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            if (superAdmin && status != 'resolved')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (status == 'pending')
                      OutlinedButton(
                        onPressed: () => onUpdate(issue, 'in_progress'),
                        child: const Text('Start work'),
                      ),
                    FilledButton(
                      onPressed: () => onUpdate(issue, 'resolved'),
                      child: const Text('Resolve'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IssueDraft {
  const _IssueDraft(this.payload, this.files);
  final Map<String, dynamic> payload;
  final List<PlatformFile> files;
}

class _RaiseIssueDialog extends StatefulWidget {
  const _RaiseIssueDialog();
  @override
  State<_RaiseIssueDialog> createState() => _RaiseIssueDialogState();
}

class _RaiseIssueDialogState extends State<_RaiseIssueDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _category = 'technical';
  String _priority = 'medium';
  List<PlatformFile> _files = const [];
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx'],
      withData: true,
    );
    if (result == null) return;

    setState(() {
      final combined = [..._files, ...result.files];
      _files = combined.take(5).toList();
      final bytes = _files.fold<int>(0, (sum, file) => sum + file.size);
      _error = combined.length > 5 || bytes > 50 * 1024 * 1024
          ? 'Choose up to five files totaling 50 MB.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Raise an Issue'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            DropdownButtonFormField(
              value: _category,
              items: const [
                'technical',
                'facilities',
                'academic',
                'finance',
                'other',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            DropdownButtonFormField(
              value: _priority,
              items: const ['low', 'medium', 'high']
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(v.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _priority = v!),
            ),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.attachment_rounded),
              label: Text('Attachments (${_files.length}/5)'),
            ),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _files.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child:
                            (file.bytes == null ||
                                ![
                                  'jpg',
                                  'jpeg',
                                  'png',
                                  'webp',
                                  'gif',
                                ].contains(file.extension?.toLowerCase()))
                            ? const Icon(Icons.insert_drive_file_outlined)
                            : Image.memory(file.bytes!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Remove ${file.name}',
                          onPressed: () => setState(() {
                            _files = List.of(_files)..removeAt(index);
                            final total = _files.fold<int>(
                              0,
                              (sum, selected) => sum + selected.size,
                            );
                            _error = total > 50 * 1024 * 1024
                                ? 'Choose up to five files totaling 50 MB.'
                                : null;
                          }),
                          icon: const Icon(Icons.close_rounded, size: 16),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(
                '${_files.length} file${_files.length == 1 ? '' : 's'} ready to attach',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _error != null
            ? null
            : () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(
                    context,
                    _IssueDraft({
                      'title': _title.text.trim(),
                      'description': _description.text.trim(),
                      'category': _category,
                      'priority': _priority,
                    }, _files),
                  );
                }
              },
        child: const Text('Submit'),
      ),
    ],
  );
}

class _IssueAttachmentThumbnail extends StatelessWidget {
  const _IssueAttachmentThumbnail({
    required this.issueId,
    required this.attachment,
    required this.onOpen,
  });

  final String issueId;
  final Map attachment;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final name = '${attachment['file_name'] ?? 'Attachment'}';
    final mime = '${attachment['mime_type'] ?? ''}';
    final image = EventPostMediaItem.fromUrl(name, mimeType: mime).isImage;
    return Semantics(
      button: true,
      label: 'Preview $name',
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 92,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 72,
                width: 92,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: image
                    ? FutureBuilder<String>(
                        future: BackendApiClient.instance.issueAttachmentUrl(
                          issueId,
                          '${attachment['id']}',
                        ),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          return EventPostImagePreview(
                            snapshot.data!,
                            height: 72,
                            fallbackBuilder: () =>
                                const Icon(Icons.broken_image_outlined),
                          );
                        },
                      )
                    : const Icon(Icons.insert_drive_file_outlined),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueAttachmentPreviewScreen extends StatelessWidget {
  const _IssueAttachmentPreviewScreen({required this.item});
  final EventPostMediaItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          item.displayName.isEmpty ? 'Issue attachment' : item.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: item.isImage
            ? Center(
                child: InteractiveViewer(
                  child: EventPostImagePreview(
                    item.url,
                    fit: BoxFit.contain,
                    fallbackBuilder: () => const Center(
                      child: Text('Image preview is unavailable.'),
                    ),
                  ),
                ),
              )
            : EventPostMediaPreview(item: item, height: 360),
      ),
    );
  }
}

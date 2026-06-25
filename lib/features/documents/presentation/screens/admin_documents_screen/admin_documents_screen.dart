import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class AdminDocumentsScreen extends StatefulWidget {
  const AdminDocumentsScreen({super.key});

  @override
  State<AdminDocumentsScreen> createState() => _AdminDocumentsScreenState();
}

class _AdminDocumentsScreenState extends State<AdminDocumentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> get _docTypes => [
    {
      'type': 'Bonafide Certificate',
      'icon': Icons.verified_rounded,
      'color': Colors.blue,
      'desc': 'Confirms student enrollment',
    },
    {
      'type': 'Transfer Certificate',
      'icon': Icons.swap_horiz_rounded,
      'color': Colors.orange,
      'desc': 'For school transfers',
    },
    {
      'type': 'Marks Memo',
      'icon': Icons.grade_rounded,
      'color': Colors.green,
      'desc': 'Academic performance record',
    },
    {
      'type': 'ID Card',
      'icon': Icons.badge_rounded,
      'color': Color(0xFF6C3483),
      'desc': 'Student identity card',
    },
    {
      'type': 'Character Certificate',
      'icon': Icons.star_rounded,
      'color': context.appTheme.info,
      'desc': 'Conduct and character',
    },
    {
      'type': 'Migration Certificate',
      'icon': Icons.flight_rounded,
      'color': Colors.red,
      'desc': 'For board migration',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final results = await Future.wait([
        BackendApiClient.instance.getRawList('/documents/requests'),
        BackendApiClient.instance.getRawList('/certificates/transfer-requests'),
        BackendApiClient.instance.getRawList('/documents/templates'),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = [
          ...results[0].map(_mapDocumentRequest),
          ...results[1].map(_mapTransferRequest),
        ];
        _templates = results[2].map(_mapTemplate).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Map<String, dynamic> _mapDocumentRequest(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'resource': 'documents/requests',
      'student':
          row['student_name'] ??
          row['student'] ??
          row['student_id'] ??
          'Student',
      'class': row['class_name'] ?? row['class'] ?? '',
      'type': row['type'] ?? row['document_type'] ?? 'Document',
      'requestDate': '${row['created_at'] ?? row['requested_on'] ?? ''}'
          .split('T')
          .first,
      'status': row['status'] ?? 'Pending',
      'parent': row['parent_name'] ?? row['parent'] ?? '',
    };
  }

  Map<String, dynamic> _mapTransferRequest(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'resource': 'certificates/transfer-requests',
      'student':
          row['student_name'] ??
          row['student'] ??
          row['student_id'] ??
          'Student',
      'class': row['class_name'] ?? row['class'] ?? '',
      'type': 'Transfer Certificate',
      'requestDate': '${row['created_at'] ?? row['requested_on'] ?? ''}'
          .split('T')
          .first,
      'status': row['status'] ?? 'Pending',
      'parent': row['parent_name'] ?? row['parent'] ?? '',
    };
  }

  Map<String, dynamic> _mapTemplate(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'] ?? row['template_name'] ?? 'Template',
      'type':
          row['type'] ?? row['document_type'] ?? row['certificate_type'] ?? '',
      'status': row['status'] ?? 'active',
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = PrincipalDrawer(
      selectedIndex: PrincipalNav.documents,
      onDestinationSelected: (_) {},
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Documents & Certificates',
        subtitle: 'Approve requests, generate certificates, and track records',
        drawer: drawer,
        floatingActionButton: const DashboardFabWidget(
          role: DashboardRole.principal,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SchoolDeskModuleScaffold(
        title: 'Documents & Certificates',
        subtitle: 'Approve requests, generate certificates, and track records',
        drawer: drawer,
        floatingActionButton: const DashboardFabWidget(
          role: DashboardRole.principal,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Unable to load document requests: $_error'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadRequests,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Documents & Certificates',
      subtitle: 'Approve requests, generate certificates, and track records',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          tooltip: 'Create document request',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => _showNewRequestDialog(context),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Requests'),
          Tab(text: 'Generate'),
          Tab(text: 'Records'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRequests(), _buildGenerate(), _buildRecords()],
      ),
    );
  }

  Widget _buildRequests() {
    final pending = _requests.where((r) => r['status'] == 'Pending').length;
    return Column(
      children: [
        if (pending > 0)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appTheme.warningContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pending_actions_rounded,
                  size: 16,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  '$pending pending document request(s)',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: _requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildRequestCard(_requests[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r) {
    final statusColors = {
      'Pending': Colors.orange,
      'Approved': context.appTheme.info,
      'Issued': Colors.green,
    };
    final c = statusColors[r['status']] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: r['status'] == 'Pending'
              ? context.appTheme.warningContainer
              : context.appTheme.surfaceVariant,
        ),
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
                      r['student'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${r['class']} • ${r['parent']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  r['status'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: c,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.description_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                r['type'] as String,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                'Requested: ${r['requestDate']}',
                style: GoogleFonts.dmSans(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          if (r['status'] == 'Pending') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decideRequest(r, 'Rejected'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                    ),
                    child: Text(
                      'Reject',
                      style: GoogleFonts.dmSans(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _decideRequest(r, 'Approved'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: Text(
                      'Approve',
                      style: GoogleFonts.dmSans(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (r['status'] == 'Approved') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _decideRequest(r, 'Issued'),
                icon: const Icon(Icons.print_rounded, size: 14),
                label: Text(
                  'Issue & Print',
                  style: GoogleFonts.dmSans(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenerate() {
    return Column(
      children: [
        _buildTemplateStrip(),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
            ),
            itemCount: _docTypes.length,
            itemBuilder: (_, i) {
              final d = _docTypes[i];
              return GestureDetector(
                onTap: () => _showGenerateDialog(context, d['type'] as String),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.appTheme.surfaceVariant),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (d['color'] as Color).withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          d['icon'] as IconData,
                          size: 26,
                          color: d['color'] as Color,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        d['type'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d['desc'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Certificate templates: ${_templates.length}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _showTemplateDialog,
            icon: const Icon(Icons.post_add_rounded, size: 18),
            label: const Text('Template'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecords() {
    final issued = _requests.where((r) => r['status'] == 'Issued').toList();
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: issued.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = issued[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appTheme.surfaceVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.appTheme.successContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['student'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${r['type']} • ${r['class']} • ${r['requestDate']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _requestReprint(r),
                child: Text(
                  'Reprint',
                  style: GoogleFonts.dmSans(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showGenerateDialog(BuildContext context, String docType) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _DocumentRequestPage(
          title: 'Generate $docType',
          initialDocType: docType,
          docTypes: _docTypes,
          issueImmediately: true,
          submitLabel: 'Generate & Print',
        ),
      ),
    );
    if (!mounted || saved != true) return;
    await _loadRequests();
    if (!mounted) return;
    _showDocumentRequestSaved();
  }

  Future<void> _showNewRequestDialog(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _DocumentRequestPage(
          title: 'New Document Request',
          initialDocType: 'Bonafide Certificate',
          docTypes: _docTypes,
          submitLabel: 'Submit Request',
        ),
      ),
    );
    if (!mounted || saved != true) return;
    await _loadRequests();
    if (!mounted) return;
    _showDocumentRequestSaved();
  }

  Future<void> _decideRequest(
    Map<String, dynamic> request,
    String status,
  ) async {
    try {
      await BackendApiClient.instance.updateRaw(
        '/${request['resource'] ?? 'documents/requests'}/${request['id']}',
        {'status': status.toLowerCase()},
      );
      await _loadRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Document request $status')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document request update failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showTemplateDialog() async {
    final nameController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedType = 'Bonafide Certificate';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Certificate Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: const InputDecoration(labelText: 'Certificate type'),
              items: _docTypes
                  .map(
                    (doc) => DropdownMenuItem(
                      value: doc['type'] as String,
                      child: Text(doc['type'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) selectedType = value;
              },
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Template name'),
            ),
            TextField(
              controller: bodyController,
              decoration: const InputDecoration(labelText: 'Template body'),
              minLines: 3,
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    await BackendApiClient.instance.createRaw('/documents/templates', {
      'name': nameController.text.trim().isEmpty
          ? selectedType
          : nameController.text.trim(),
      'document_type': selectedType,
      'body': bodyController.text.trim(),
      'status': 'active',
    });
    await _loadRequests();
  }

  Future<void> _requestReprint(Map<String, dynamic> request) async {
    try {
      await BackendApiClient.instance.createRaw(
        '/documents/requests/${request['id']}/prints',
        {'action': 'reprint'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Document print requested')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document print request failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDocumentRequestSaved() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document request saved'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class _DocumentRequestPage extends StatefulWidget {
  final String title;
  final String initialDocType;
  final List<Map<String, dynamic>> docTypes;
  final bool issueImmediately;
  final String submitLabel;

  const _DocumentRequestPage({
    required this.title,
    required this.initialDocType,
    required this.docTypes,
    required this.submitLabel,
    this.issueImmediately = false,
  });

  @override
  State<_DocumentRequestPage> createState() => _DocumentRequestPageState();
}

class _DocumentRequestPageState extends State<_DocumentRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _studentCtrl = TextEditingController();
  late String _docType;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _docType = widget.initialDocType;
  }

  @override
  void dispose() {
    _studentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.createRaw('/documents/requests', {
        'student_name': _studentCtrl.text.trim(),
        'type': _docType,
        'status': widget.issueImmediately ? 'issued' : 'pending',
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Document request failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_error != null) ...[
                _InputErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _studentCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Student Name'),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the student name.'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _docType,
                decoration: const InputDecoration(labelText: 'Document Type'),
                items: widget.docTypes
                    .map(
                      (d) => DropdownMenuItem(
                        value: d['type'] as String,
                        child: Text(d['type'] as String),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _docType = v ?? _docType),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.submitLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputErrorBanner extends StatelessWidget {
  final String message;

  const _InputErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appTheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: GoogleFonts.dmSans(fontSize: 13, color: Colors.red),
      ),
    );
  }
}

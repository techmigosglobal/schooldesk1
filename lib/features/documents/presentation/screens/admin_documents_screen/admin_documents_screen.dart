import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';

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

  String? _selectedClass;
  final Map<String, List<Map<String, dynamic>>> _studentDocs = {};
  final Map<String, bool> _loadingStudentDocs = {};
  final Map<String, List<Map<String, dynamic>>> _teacherDocs = {};
  final Map<String, bool> _loadingTeacherDocs = {};

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
      'color': const Color(0xFF6C3483),
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

    final classes = RoleAccessService.adminAllClasses;
    if (classes.isNotEmpty) {
      _selectedClass = classes.first['name'] as String?;
    }
  }

  Future<void> _loadRequests() async {
    try {
      final results = await Future.wait([
        BackendApiClient.instance.getRawList('/documents/requests'),
        BackendApiClient.instance.getRawList('/documents/templates'),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = results[0].map(_mapDocumentRequest).toList();
        _templates = results[1].map(_mapTemplate).toList();
        _loading = false;
        _error = null;
      });
    } on Object catch (e) {
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

  Map<String, dynamic> _mapTemplate(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'] ?? row['template_name'] ?? 'Template',
      'type':
          row['type'] ?? row['document_type'] ?? row['certificate_type'] ?? '',
      'status': row['status'] ?? 'active',
    };
  }

  Future<void> _fetchStudentDocs(String studentId) async {
    setState(() {
      _loadingStudentDocs[studentId] = true;
    });
    try {
      final docs = await BackendApiClient.instance.getRawList(
        '/student-documents',
        queryParameters: {'student_id': studentId},
      );
      setState(() {
        _studentDocs[studentId] = docs;
        _loadingStudentDocs[studentId] = false;
      });
    } on Object catch (e) {
      setState(() {
        _loadingStudentDocs[studentId] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load documents: $e')));
      }
    }
  }

  Future<void> _fetchTeacherDocs(String staffId) async {
    setState(() {
      _loadingTeacherDocs[staffId] = true;
    });
    try {
      final docs = await BackendApiClient.instance.getRawList(
        '/staff-documents',
        queryParameters: {'staff_id': staffId},
      );
      setState(() {
        _teacherDocs[staffId] = docs;
        _loadingTeacherDocs[staffId] = false;
      });
    } on Object catch (e) {
      setState(() {
        _loadingTeacherDocs[staffId] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load documents: $e')));
      }
    }
  }

  Future<void> _deleteStudentDoc(String studentId, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await BackendApiClient.instance.deleteRaw('/student-documents/$docId');
      _fetchStudentDocs(studentId);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete document: $e')),
        );
      }
    }
  }

  Future<void> _uploadStudentDocDialog(String studentId) async {
    final titleCtrl = TextEditingController();
    String docType = 'Aadhar Card';
    PlatformFile? selectedFile;
    bool uploading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Upload Student Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Document Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: docType,
                decoration: const InputDecoration(labelText: 'Document Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'Aadhar Card',
                    child: Text('Aadhar Card'),
                  ),
                  DropdownMenuItem(
                    value: 'Birth Certificate',
                    child: Text('Birth Certificate'),
                  ),
                  DropdownMenuItem(
                    value: 'Transfer Certificate',
                    child: Text('Transfer Certificate'),
                  ),
                  DropdownMenuItem(
                    value: 'Report Card',
                    child: Text('Report Card'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      docType = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (selectedFile != null)
                Text(
                  'Selected: ${selectedFile!.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                        );
                        if (result != null && result.files.isNotEmpty) {
                          setDialogState(() {
                            selectedFile = result.files.first;
                          });
                        }
                      },
                icon: const Icon(Icons.attach_file),
                label: const Text('Select File'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (uploading || selectedFile == null)
                  ? null
                  : () async {
                      setDialogState(() {
                        uploading = true;
                      });
                      try {
                        final fileUrl = await BackendApiClient.instance
                            .uploadFile(
                              selectedFile!.path!,
                              filename: selectedFile!.name,
                              folder: 'student-documents',
                              entityType: 'student_document',
                              entityId: studentId,
                              private: true,
                            );
                        await BackendApiClient.instance
                            .createRaw('/student-documents', {
                              'student_id': studentId,
                              'doc_type': docType,
                              'title': titleCtrl.text.trim().isEmpty
                                  ? docType
                                  : titleCtrl.text.trim(),
                              'file_url': fileUrl,
                            });
                        Navigator.pop(context);
                        _fetchStudentDocs(studentId);
                      } on Object catch (e) {
                        setDialogState(() {
                          uploading = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Upload failed: $e')),
                        );
                      }
                    },
              child: uploading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Upload'),
            ),
          ],
        ),
      ),
    );
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
          Tab(text: 'Student Docs'),
          Tab(text: 'Teacher Docs'),
          Tab(text: 'Certificates'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStudentDocsTab(),
          _buildTeacherDocsTab(),
          _buildCertificatesTab(),
        ],
      ),
    );
  }

  Widget _buildStudentDocsTab() {
    final classes = RoleAccessService.adminAllClasses;
    if (classes.isEmpty) {
      return const Center(child: Text('No classes found'));
    }
    _selectedClass ??= classes.first['name'] as String?;
    final students = RoleAccessService.allStudents
        .where((s) => s['class'] == _selectedClass)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Select Class:  ',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedClass,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: classes.map((c) {
                    final name = c['name'] as String;
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedClass = val;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: students.isEmpty
              ? const Center(child: Text('No students in this class'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final studentId = student['id'] as String;
                    final isExpanded = _studentDocs.containsKey(studentId);
                    final docs = _studentDocs[studentId] ?? [];
                    final loading = _loadingStudentDocs[studentId] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        title: Text(
                          student['name'] as String? ?? 'Student',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Roll: ${student['roll'] ?? ''}',
                          style: GoogleFonts.dmSans(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        onExpansionChanged: (expanded) {
                          if (expanded && !isExpanded) {
                            _fetchStudentDocs(studentId);
                          }
                        },
                        children: [
                          if (loading)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            )
                          else ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Documents (${docs.length})',
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _uploadStudentDocDialog(studentId),
                                    icon: const Icon(
                                      Icons.upload_file_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Upload'),
                                  ),
                                ],
                              ),
                            ),
                            if (docs.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No documents uploaded for this student.',
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: docs.length,
                                itemBuilder: (context, docIndex) {
                                  final doc = docs[docIndex];
                                  final fileUrl =
                                      doc['file_url'] as String? ?? '';
                                  final docId = doc['id'] as String;
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.description_rounded,
                                      color: Colors.blue,
                                    ),
                                    title: Text(
                                      doc['title'] as String? ??
                                          doc['doc_type'] as String? ??
                                          'Document',
                                    ),
                                    subtitle: Text(
                                      doc['doc_type'] as String? ?? 'Other',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (fileUrl.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.visibility_outlined,
                                              color: Colors.green,
                                            ),
                                            onPressed: () {
                                              openEventPostMediaPreview(
                                                context,
                                                EventPostMediaItem.fromUrl(
                                                  fileUrl,
                                                  name:
                                                      doc['title'] ??
                                                      'Document',
                                                ),
                                              );
                                            },
                                          ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _deleteStudentDoc(
                                            studentId,
                                            docId,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTeacherDocsTab() {
    final teachers = RoleAccessService.principalAllTeachers;
    if (teachers.isEmpty) {
      return const Center(child: Text('No teachers found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: teachers.length,
      itemBuilder: (context, index) {
        final teacher = teachers[index];
        final staffId = teacher['id'] as String;
        final isExpanded = _teacherDocs.containsKey(staffId);
        final docs = _teacherDocs[staffId] ?? [];
        final loading = _loadingTeacherDocs[staffId] == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(
              teacher['name'] as String? ?? 'Teacher',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              teacher['subject'] as String? ?? 'General',
              style: GoogleFonts.dmSans(color: Colors.grey, fontSize: 12),
            ),
            onExpansionChanged: (expanded) {
              if (expanded && !isExpanded) {
                _fetchTeacherDocs(staffId);
              }
            },
            children: [
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Documents (${docs.length})',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No documents uploaded for this teacher.'),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, docIndex) {
                      final doc = docs[docIndex];
                      final fileUrl = doc['file_url'] as String? ?? '';
                      return ListTile(
                        leading: const Icon(
                          Icons.description_rounded,
                          color: Colors.orange,
                        ),
                        title: Text(
                          doc['title'] as String? ??
                              doc['doc_type'] as String? ??
                              'Document',
                        ),
                        subtitle: Text(doc['doc_type'] as String? ?? 'Other'),
                        trailing: fileUrl.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  openEventPostMediaPreview(
                                    context,
                                    EventPostMediaItem.fromUrl(
                                      fileUrl,
                                      name: doc['title'] ?? 'Document',
                                    ),
                                  );
                                },
                              )
                            : null,
                      );
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCertificatesTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: context.appTheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Requests'),
              Tab(text: 'Generate'),
              Tab(text: 'Records'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_buildRequests(), _buildGenerate(), _buildRecords()],
            ),
          ),
        ],
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
                const Icon(
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
              const Icon(
                Icons.description_rounded,
                size: 14,
                color: Colors.grey,
              ),
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
                      side: const BorderSide(color: Colors.red),
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
                child: const Icon(
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
    } on Object catch (e) {
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
    } on Object catch (e) {
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
      const SnackBar(
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
    } on Object catch (e) {
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class TeacherDocumentsScreen extends StatefulWidget {
  const TeacherDocumentsScreen({super.key});

  @override
  State<TeacherDocumentsScreen> createState() => _TeacherDocumentsScreenState();
}

class _TeacherDocumentsScreenState extends State<TeacherDocumentsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _documents = const [];
  List<Map<String, dynamic>> _myDocuments = const [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final seen = <String>{};
      final rows = <Map<String, dynamic>>[];
      for (final sectionId in RoleAccessService.teacherSectionIds) {
        final sectionRows = await BackendApiClient.instance.getRawList(
          '/student-documents',
          queryParameters: {'section_id': sectionId, 'page_size': 100},
        );
        for (final row in sectionRows) {
          final id = '${row['id'] ?? ''}';
          if (id.isNotEmpty && !seen.add(id)) continue;
          rows.add(Map<String, dynamic>.from(row));
        }
      }

      final myDocs = await BackendApiClient.instance.getRawList(
        '/staff-documents',
      );

      if (!mounted) return;
      setState(() {
        _documents = rows;
        _myDocuments = myDocs;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteMyDoc(String docId) async {
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
      await BackendApiClient.instance.deleteRaw('/staff-documents/$docId');
      _loadDocuments();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete document: $e')),
        );
      }
    }
  }

  Future<void> _uploadMyDocDialog() async {
    final titleCtrl = TextEditingController();
    String docType = 'Degree Certificate';
    PlatformFile? selectedFile;
    bool uploading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Upload Personal Document'),
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
                    value: 'Degree Certificate',
                    child: Text('Degree Certificate'),
                  ),
                  DropdownMenuItem(
                    value: 'Experience Letter',
                    child: Text('Experience Letter'),
                  ),
                  DropdownMenuItem(
                    value: 'Aadhar Card',
                    child: Text('Aadhar Card'),
                  ),
                  DropdownMenuItem(value: 'Resume', child: Text('Resume')),
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
                            );
                        await BackendApiClient.instance
                            .createRaw('/staff-documents', {
                              'doc_type': docType,
                              'title': titleCtrl.text.trim().isEmpty
                                  ? docType
                                  : titleCtrl.text.trim(),
                              'file_url': fileUrl,
                            });
                        Navigator.pop(context);
                        _loadDocuments();
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
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: TeacherFlowScaffold(
        title: 'Documents',
        subtitle: 'Class student documents and your own records',
        selectedIndex: TeacherNav.documents,
        loading: _loading,
        error: _error,
        onRefresh: _loadDocuments,
        child: Column(
          children: [
            TabBar(
              labelColor: context.appTheme.primary,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Student Documents'),
                Tab(text: 'My Documents'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [_buildStudentDocuments(), _buildMyDocuments()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentDocuments() {
    if (_documents.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.description_outlined, size: 48),
          SizedBox(height: 12),
          Center(child: Text('No class documents available')),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _documents.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final doc = _documents[index];
          final student = doc['student'];
          final studentName = student is Map
              ? '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
                    .trim()
              : '${doc['student_name'] ?? doc['student_id'] ?? ''}';
          final fileUrl = '${doc['file_url'] ?? ''}'.trim();
          return Card(
            child: ListTile(
              leading: Icon(
                EventPostMediaItem.fromUrl(fileUrl).isPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.description_outlined,
              ),
              title: Text('${doc['doc_type'] ?? 'Document'}'),
              subtitle: Text(
                studentName.isEmpty ? 'Assigned student' : studentName,
              ),
              trailing: IconButton(
                tooltip: 'Preview document',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: fileUrl.isEmpty
                    ? null
                    : () => openEventPostMediaPreview(
                        context,
                        EventPostMediaItem.fromUrl(
                          fileUrl,
                          name: '${doc['doc_type'] ?? 'Document'}',
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyDocuments() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Uploaded Documents (${_myDocuments.length})',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _uploadMyDocDialog,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Upload'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _myDocuments.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 120),
                    Icon(
                      Icons.folder_open_rounded,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Center(child: Text('No personal documents uploaded yet.')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _myDocuments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = _myDocuments[index];
                    final fileUrl = doc['file_url'] as String? ?? '';
                    final docId = doc['id'] as String;
                    return Card(
                      child: ListTile(
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
                                      name: doc['title'] ?? 'Document',
                                    ),
                                  );
                                },
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteMyDoc(docId),
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
}

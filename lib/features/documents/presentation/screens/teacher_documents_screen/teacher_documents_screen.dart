import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherDocumentsScreen extends StatefulWidget {
  const TeacherDocumentsScreen({super.key});

  @override
  State<TeacherDocumentsScreen> createState() => _TeacherDocumentsScreenState();
}

class _TeacherDocumentsScreenState extends State<TeacherDocumentsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _documents = const [];

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
      if (!mounted) return;
      setState(() => _documents = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'Documents',
      subtitle: 'Class student documents available to your assigned sections',
      selectedIndex: TeacherNav.documents,
      loading: _loading,
      error: _error,
      onRefresh: _loadDocuments,
      child: RefreshIndicator(
        onRefresh: _loadDocuments,
        child: _documents.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.description_outlined, size: 48),
                  SizedBox(height: 12),
                  Center(child: Text('No class documents available')),
                ],
              )
            : ListView.separated(
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
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text('${doc['doc_type'] ?? 'Document'}'),
                      subtitle: Text(
                        studentName.isEmpty ? 'Assigned student' : studentName,
                      ),
                      trailing: IconButton(
                        tooltip: 'Open document',
                        icon: const Icon(Icons.open_in_new_rounded),
                        onPressed: '${doc['file_url'] ?? ''}'.trim().isEmpty
                            ? null
                            : () => _openDocument('${doc['file_url']}'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

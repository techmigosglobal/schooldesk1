import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/teacher_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';

class TeacherResourcesScreen extends StatefulWidget {
  const TeacherResourcesScreen({super.key});

  @override
  State<TeacherResourcesScreen> createState() => _TeacherResourcesScreenState();
}

class _TeacherResourcesScreenState extends State<TeacherResourcesScreen> {
  int _selectedNavIndex = 7;
  String _filterClass = 'All';
  List<Map<String, dynamic>> _resources = [];
  late final List<String> _classFilters;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final assignedClass = RoleAccessService.teacherClassName;
    _classFilters = ['All', assignedClass];
    _loadData();
  }

  Future<void> _loadData() async {
    final rows = await BackendApiClient.instance.getRawList('/documents');
    setState(() {
      _resources = rows.where(_isTeacherResource).map(_mapResource).toList();
      _loading = false;
    });
  }

  bool _isTeacherResource(Map<String, dynamic> row) {
    final teacherId = row['teacher_id']?.toString() ?? '';
    final sectionId = row['section_id']?.toString() ?? '';
    return (teacherId.isEmpty ||
            teacherId == RoleAccessService.teacherStaffId) &&
        (sectionId.isEmpty || sectionId == RoleAccessService.teacherClassId);
  }

  Map<String, dynamic> _mapResource(Map<String, dynamic> row) {
    final created = DateTime.tryParse('${row['created_at'] ?? ''}');
    return {
      'id': row['id'],
      'title': row['title'] ?? '',
      'class': row['class'] ?? RoleAccessService.teacherClassName,
      'type': row['type'] ?? 'resource',
      'format': row['format'] ?? 'LINK',
      'size': row['size'] ?? '',
      'date': created == null
          ? ''
          : '${created.day}/${created.month}/${created.year}',
      'views': row['views'] ?? 0,
      'file_url': row['file_url'] ?? '',
    };
  }

  List<Map<String, dynamic>> get _filteredResources {
    if (_filterClass == 'All') return _resources;
    return _resources
        .where((r) => r['class'] == _filterClass || r['class'] == 'All')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Resources',
        subtitle: 'Organize class resources and backend-backed materials',
        drawer: TeacherDrawer(
          selectedIndex: _selectedNavIndex,
          onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Resources',
      subtitle: 'Organize class resources and backend-backed materials',
      drawer: TeacherDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DashboardFabWidget(role: DashboardRole.teacher),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: _showUploadSheet,
            backgroundColor: AppTheme.primary,
            icon: const Icon(Icons.upload_rounded, color: Colors.white),
            label: Text(
              'Upload',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredResources.length,
              itemBuilder: (context, i) =>
                  _buildResourceCard(_filteredResources[i], i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _classFilters.map((c) {
            final isSelected = _filterClass == c;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filterClass = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    c == 'All' ? 'All Classes' : 'Class $c',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildResourceCard(Map<String, dynamic> r, int index) {
    final typeColors = {
      'notes': AppTheme.primary,
      'worksheet': AppTheme.secondary,
      'video': AppTheme.error,
      'reference': AppTheme.accent,
    };
    final typeIcons = {
      'notes': Icons.description_rounded,
      'worksheet': Icons.assignment_rounded,
      'video': Icons.play_circle_rounded,
      'reference': Icons.book_rounded,
    };
    final color = typeColors[r['type']] ?? AppTheme.muted;
    final icon = typeIcons[r['type']] ?? Icons.folder_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['title'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Class ${r['class']}',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${r['format']} · ${r['size']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      size: 12,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${r['views']} views',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      r['date'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.share_rounded,
                  size: 18,
                  color: AppTheme.primary,
                ),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sharing: ${r['title']}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppTheme.error,
                ),
                onPressed: () async {
                  final id = r['id']?.toString() ?? '';
                  if (id.isNotEmpty) {
                    await BackendApiClient.instance.deleteRaw('/documents/$id');
                  }
                  await _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Resource deleted'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showUploadSheet() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _UploadResourcePage(classFilters: _classFilters),
      ),
    );
    if (!mounted || saved != true) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resource record saved; file upload is not wired yet'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _UploadResourcePage extends StatefulWidget {
  final List<String> classFilters;

  const _UploadResourcePage({required this.classFilters});

  @override
  State<_UploadResourcePage> createState() => _UploadResourcePageState();
}

class _UploadResourcePageState extends State<_UploadResourcePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  late String _selectedClass;
  String _resourceType = 'notes';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedClass = RoleAccessService.teacherClassName;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.createRaw('/documents', {
        'title': _titleCtrl.text.trim(),
        'class': _selectedClass,
        'type': _resourceType,
        'format': 'LINK',
        'size': '',
        'views': 0,
        'teacher_id': RoleAccessService.teacherStaffId,
        'section_id': RoleAccessService.teacherClassId,
        'description': '',
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Resource record could not be saved: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Resource')),
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
                controller: _titleCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a title.' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedClass,
                decoration: const InputDecoration(labelText: 'Class'),
                items: widget.classFilters
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c == 'All' ? 'All Classes' : 'Class $c'),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) =>
                          setState(() => _selectedClass = v ?? _selectedClass),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['notes', 'worksheet', 'video', 'reference']
                    .map(
                      (t) => ChoiceChip(
                        label: Text(t),
                        selected: _resourceType == t,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _resourceType = t),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              _InputErrorBanner(
                message:
                    'Backend file upload is not available on this screen. This saves only the existing document/resource record.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Resource Record'),
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
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.error),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/config/env_config.dart';
import '../../core/utils/image_cropper_helper.dart';
import '../../services/backend_api_client.dart' as api;
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';

class StudentModel {
  final String id;
  final String name;
  final String rollNumber;
  final String classSection;
  final String sectionId;
  final int classGrade;
  final String status;
  final String photoUrl;
  final String dateOfBirth;
  final String gender;
  final String guardianName;
  final String guardianPhone;
  final String avatarInitials;

  const StudentModel({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.classSection,
    required this.sectionId,
    required this.classGrade,
    required this.status,
    required this.photoUrl,
    required this.dateOfBirth,
    required this.gender,
    required this.guardianName,
    required this.guardianPhone,
    required this.avatarInitials,
  });

  String get directoryStatusLabel {
    switch (status.toLowerCase().trim()) {
      case 'inactive':
      case 'withdrawn':
        return 'Absent';
      case 'pending':
      case 'transfer':
      case 'transferred':
        return 'Late';
      case 'active':
      default:
        return 'Present';
    }
  }

  bool get hasAttendanceAlert => directoryStatusLabel != 'Present';
  bool get hasFeeAlert => false;
  double get attendancePercent => directoryStatusLabel == 'Present' ? 100 : 0;
  String get feeStatus => 'N/A';
  String get performanceGrade => 'N/A';
  double get performanceScore => 0;
}

class StudentOversightScreen extends StatefulWidget {
  const StudentOversightScreen({super.key});

  @override
  State<StudentOversightScreen> createState() => _StudentOversightScreenState();
}

class _StudentOversightScreenState extends State<StudentOversightScreen> {
  static const int _pageSize = 20;
  static const Color _background = Color(0xFFEFF8FD);

  final List<StudentModel> _allStudents = [];
  final List<StudentModel> _filteredStudents = [];
  final ScrollController _scrollController = ScrollController();

  List<StudentModel> _displayedStudents = [];
  List<String> _classOptions = const ['All'];
  List<api.SectionModel> _sections = const [];
  List<api.GradeModel> _grades = const [];
  List<api.UserAccountModel> _parents = const [];

  String _searchQuery = '';
  String _selectedClass = 'All';
  String _selectedStatus = 'All';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _loadError;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 160) {
      _loadMoreStudents();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final students = <api.StudentModel>[];
      var page = 1;
      while (true) {
        final res = await api.BackendApiClient.instance.getStudents(
          page: page,
          pageSize: 100,
        );
        students.addAll(res.data);
        if (!res.hasMore || res.data.isEmpty) break;
        page++;
      }

      final sections = await api.BackendApiClient.instance.getSections();
      final grades = await api.BackendApiClient.instance.getGrades();
      final parents = await _loadParentAccounts();
      final sectionMap = {for (final s in sections) s.id: s};
      final gradeMap = {for (final g in grades) g.id: g};

      final loaded = students
          .map((student) => _mapApiStudentToUi(student, sectionMap, gradeMap))
          .toList();
      final classes =
          loaded
              .map((student) => student.classSection)
              .where((value) => value.trim().isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      if (!mounted) return;
      setState(() {
        _sections = sections;
        _grades = grades;
        _parents = parents;
        _allStudents
          ..clear()
          ..addAll(loaded);
        _filteredStudents
          ..clear()
          ..addAll(loaded);
        _classOptions = ['All', ...classes];
        if (!_classOptions.contains(_selectedClass)) {
          _selectedClass = 'All';
        }
        _applyFilters(resetState: false);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<List<api.UserAccountModel>> _loadParentAccounts() async {
    try {
      final result = await api.BackendApiClient.instance.getUsers(
        role: 'Parent',
        status: 'active',
        page: 1,
        pageSize: 500,
      );
      return result.data;
    } catch (_) {
      return const [];
    }
  }

  StudentModel _mapApiStudentToUi(
    api.StudentModel student,
    Map<String, api.SectionModel> sectionMap,
    Map<String, api.GradeModel> gradeMap,
  ) {
    final section = student.currentSectionId == null
        ? null
        : sectionMap[student.currentSectionId!];
    final grade = section == null ? null : gradeMap[section.gradeId];
    final gradeName = _gradeLabel(grade, section);
    final sectionName = section?.sectionName.trim() ?? '';
    final classLabel = gradeName.isNotEmpty && sectionName.isNotEmpty
        ? 'Class $gradeName / Section $sectionName'
        : gradeName.isNotEmpty
        ? 'Class $gradeName'
        : sectionName.isNotEmpty
        ? 'Section $sectionName'
        : 'Class not assigned';
    final name = student.fullName.trim().isEmpty
        ? 'Unknown Student'
        : student.fullName.trim();

    return StudentModel(
      id: student.id,
      name: name,
      rollNumber: student.admissionNumber.trim().isNotEmpty
          ? student.admissionNumber.trim()
          : student.studentCode.trim(),
      classSection: classLabel,
      sectionId: student.currentSectionId ?? '',
      classGrade: grade?.gradeNumber ?? 0,
      status: student.status,
      photoUrl: student.photoUrl,
      dateOfBirth: student.dateOfBirth ?? '',
      gender: student.gender ?? '',
      guardianName: 'Not assigned',
      guardianPhone: '-',
      avatarInitials: _extractInitials(name),
    );
  }

  String _gradeLabel(api.GradeModel? grade, api.SectionModel? section) {
    final modelName = grade?.gradeName.trim() ?? '';
    if (modelName.isNotEmpty) return modelName;
    final sectionGradeName = section?.gradeName.trim() ?? '';
    if (sectionGradeName.isNotEmpty) return sectionGradeName;
    final number = grade?.gradeNumber ?? 0;
    return number > 0 ? number.toString() : '';
  }

  String _extractInitials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'NA';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _applyFilters({bool resetState = true}) {
    final query = _searchQuery.toLowerCase().trim();
    final next = _allStudents.where((student) {
      final matchesSearch =
          query.isEmpty ||
          student.name.toLowerCase().contains(query) ||
          student.rollNumber.toLowerCase().contains(query) ||
          student.classSection.toLowerCase().contains(query);
      final matchesClass =
          _selectedClass == 'All' || student.classSection == _selectedClass;
      final matchesStatus =
          _selectedStatus == 'All' ||
          student.directoryStatusLabel == _selectedStatus;
      return matchesSearch && matchesClass && matchesStatus;
    }).toList();

    void apply() {
      _filteredStudents
        ..clear()
        ..addAll(next);
      _resetPagination();
    }

    if (resetState) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _resetPagination() {
    _currentPage = 0;
    _loadingMore = false;
    _hasMore = _filteredStudents.length > _pageSize;
    _displayedStudents = _filteredStudents.take(_pageSize).toList();
  }

  void _loadMoreStudents() {
    if (_loadingMore || !_hasMore) return;
    final start = (_currentPage + 1) * _pageSize;
    if (start >= _filteredStudents.length) {
      setState(() => _hasMore = false);
      return;
    }
    setState(() {
      _loadingMore = true;
      final end = (start + _pageSize).clamp(0, _filteredStudents.length);
      _displayedStudents.addAll(_filteredStudents.sublist(start, end));
      _currentPage++;
      _loadingMore = false;
      _hasMore = end < _filteredStudents.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-student',
        onPressed: _openAddStudentForm,
        backgroundColor: const Color(0xFF0887F2),
        foregroundColor: Colors.white,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF0887F2),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildSearchAndFilters()),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_loadError != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.cloud_off_rounded,
                      title: 'Unable to load students',
                      description: _loadError!,
                      actionLabel: 'Retry',
                      onAction: _loadData,
                    ),
                  ),
                )
              else if (_filteredStudents.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.school_outlined,
                      title: 'No students found',
                      description:
                          'Adjust your search or filters to find students.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 96),
                  sliver: SliverList.builder(
                    itemCount: _displayedStudents.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _displayedStudents.length) {
                        return _buildLoadMoreButton();
                      }
                      final student = _displayedStudents[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: _StudentDirectoryCard(
                          student: student,
                          imageUrl: _absoluteImageUrl(student.photoUrl),
                          onTap: () => _openStudentDetail(student),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              tooltip: 'Back',
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'All Students Directory V1',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: GoogleFonts.dmSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A2A33),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child: Column(
        children: [
          _SearchBox(
            hint: 'Search students...',
            onChanged: (value) {
              _searchQuery = value;
              _applyFilters();
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _DirectoryChip(
                  label: 'All Students',
                  selected: _selectedClass == 'All' && _selectedStatus == 'All',
                  onTap: () {
                    _selectedClass = 'All';
                    _selectedStatus = 'All';
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                ..._classOptions
                    .where((value) => value != 'All')
                    .take(4)
                    .map(
                      (value) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _DirectoryChip(
                          label: _compactClassLabel(value),
                          selected: _selectedClass == value,
                          onTap: () {
                            _selectedClass = value;
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                ...['Present', 'Absent', 'Late'].map(
                  (value) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _DirectoryChip(
                      label: 'Status: $value',
                      selected: _selectedStatus == value,
                      onTap: () {
                        _selectedStatus = _selectedStatus == value
                            ? 'All'
                            : value;
                        _applyFilters();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: TextButton(
          onPressed: _loadMoreStudents,
          child: Text(
            _loadingMore ? 'Loading...' : 'Load more students',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  String _compactClassLabel(String value) {
    final classMatch = RegExp(r'Class\s+([^/]+)').firstMatch(value);
    final sectionMatch = RegExp(r'Section\s+(.+)$').firstMatch(value);
    final grade = classMatch?.group(1)?.trim();
    final section = sectionMatch?.group(1)?.trim();
    if ((grade ?? '').isNotEmpty && (section ?? '').isNotEmpty) {
      return '$grade $section';
    }
    return value;
  }

  String _absoluteImageUrl(String path) {
    final value = path.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('file://')) {
      return value;
    }
    if (value.startsWith('/')) return '${EnvConfig.apiOrigin}$value';
    return '${EnvConfig.apiOrigin}/$value';
  }

  Future<void> _openAddStudentForm() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _AddStudentPhotoFormPage(
          sections: _sections,
          grades: _grades,
          parents: _parents,
          onSubmit: _createStudentFromForm,
        ),
      ),
    );
  }

  Future<void> _createStudentFromForm(_AddStudentInput input) async {
    final parts = input.studentName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final firstName = parts.isEmpty ? input.studentName.trim() : parts.first;
    final lastName = parts.length > 1 ? parts.skip(1).join(' ') : '';

    final student = await api.BackendApiClient.instance.createStudent(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: input.backendDateOfBirth,
      gender: input.gender.toLowerCase(),
      admissionNumber: input.admissionNumber,
      studentCode: input.systemId,
      currentSectionId: input.sectionId,
      admissionDate: _backendDate(DateTime.now()),
      status: 'active',
    );

    if ((input.parentUserId ?? '').isNotEmpty) {
      await api.BackendApiClient.instance.setStudentParent(
        studentId: student.id,
        parentUserId: input.parentUserId,
      );
    }

    if ((input.photoPath ?? '').isNotEmpty) {
      await api.BackendApiClient.instance.uploadStudentPhoto(
        studentId: student.id,
        filePath: input.photoPath!,
      );
    }

    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${input.studentName.trim()} added')),
    );
  }

  Future<void> _openStudentDetail(StudentModel student) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _StudentDetailPage(
          student: student,
          imageUrl: _absoluteImageUrl(student.photoUrl),
          onRemove: (detailContext) =>
              _confirmAndRemoveStudent(detailContext, student),
        ),
      ),
    );
    if (removed != true) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${student.name} moved to inactive records')),
    );
  }

  Future<bool> _confirmAndRemoveStudent(
    BuildContext detailContext,
    StudentModel student,
  ) async {
    final confirmed = await showDialog<bool>(
      context: detailContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text(
          'Move ${student.name} to inactive records? Attendance, fee, exam, and audit history will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    try {
      await api.BackendApiClient.instance.deleteStudent(student.id);
      return true;
    } catch (error) {
      if (detailContext.mounted) {
        ScaffoldMessenger.of(detailContext).showSnackBar(
          SnackBar(content: Text('Failed to remove ${student.name}: $error')),
        );
      }
      return false;
    }
  }

  static String _backendDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _StudentDirectoryCard extends StatelessWidget {
  final StudentModel student;
  final String imageUrl;
  final VoidCallback onTap;

  const _StudentDirectoryCard({
    required this.student,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      shadowColor: const Color(0xFF8AAAC0).withAlpha(55),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withAlpha(180)),
          ),
          child: Row(
            children: [
              _StudentAvatar(
                imageUrl: imageUrl,
                initials: student.avatarInitials,
                size: 58,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E2A32),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      student.classSection,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5C6872),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(label: student.directoryStatusLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  final String imageUrl;
  final String initials;
  final double size;

  const _StudentAvatar({
    required this.imageUrl,
    required this.initials,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasImage
            ? null
            : const LinearGradient(
                colors: [Color(0xFFBFE7F6), Color(0xFFFFD7A8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7398B5).withAlpha(45),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _Initials(initials: initials),
            )
          : _Initials(initials: initials),
    );
  }
}

class _Initials extends StatelessWidget {
  final String initials;

  const _Initials({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.dmSans(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF17627A),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = switch (label) {
      'Absent' => (const Color(0xFFFFECEC), const Color(0xFFDD4646)),
      'Late' => (const Color(0xFFFFF2CE), const Color(0xFFB78412)),
      _ => (const Color(0xFFDFF8E7), const Color(0xFF3AB468)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: colors.$2,
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7FA6BD).withAlpha(45),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(
            color: const Color(0xFF798996),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF6E7D88),
            size: 24,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _DirectoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DirectoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE0F8FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF86C7D9) : const Color(0xFFD8E4EA),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF93B2C5).withAlpha(selected ? 45 : 28),
              blurRadius: selected ? 10 : 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF226A7E) : const Color(0xFF4E5C66),
          ),
        ),
      ),
    );
  }
}

class _AddStudentInput {
  final String studentName;
  final String backendDateOfBirth;
  final String gender;
  final String sectionId;
  final String systemId;
  final String admissionNumber;
  final String? parentUserId;
  final String? photoPath;

  const _AddStudentInput({
    required this.studentName,
    required this.backendDateOfBirth,
    required this.gender,
    required this.sectionId,
    required this.systemId,
    required this.admissionNumber,
    required this.parentUserId,
    required this.photoPath,
  });
}

class _AddStudentPhotoFormPage extends StatefulWidget {
  final List<api.SectionModel> sections;
  final List<api.GradeModel> grades;
  final List<api.UserAccountModel> parents;
  final Future<void> Function(_AddStudentInput input) onSubmit;

  const _AddStudentPhotoFormPage({
    required this.sections,
    required this.grades,
    required this.parents,
    required this.onSubmit,
  });

  @override
  State<_AddStudentPhotoFormPage> createState() =>
      _AddStudentPhotoFormPageState();
}

class _AddStudentPhotoFormPageState extends State<_AddStudentPhotoFormPage> {
  static const Color _background = Color(0xFFEFF8FD);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  late final TextEditingController _dobCtrl;
  late final TextEditingController _systemIdCtrl;
  late final TextEditingController _admissionCtrl;
  final ImagePicker _picker = ImagePicker();

  DateTime _dob = DateTime(2010);
  String _gender = 'Female';
  String? _sectionId;
  String? _parentUserId;
  XFile? _photoFile;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dobCtrl = TextEditingController(text: _displayDate(_dob));
    _systemIdCtrl = TextEditingController(text: _generateSystemId());
    _admissionCtrl = TextEditingController(text: _generateAdmissionNumber());
    _sectionId = widget.sections.isNotEmpty ? widget.sections.first.id : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _systemIdCtrl.dispose();
    _admissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (image == null || !mounted) return;
    final croppedPath = await SchoolDeskImageCropper.cropSquareImage(
      context: context,
      sourcePath: image.path,
      title: 'Crop Student Photo',
    );
    if (croppedPath == null || !mounted) return;
    setState(() => _photoFile = XFile(croppedPath));
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dob,
      firstDate: DateTime(1995),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _dob = selected;
      _dobCtrl.text = _displayDate(selected);
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (widget.sections.isEmpty || (_sectionId ?? '').isEmpty) {
      setState(
        () =>
            _error = 'Create a class / section before adding student accounts',
      );
      return;
    }
    if (_systemIdCtrl.text.trim().isEmpty ||
        _admissionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'System ID and admission number are required');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        _AddStudentInput(
          studentName: _nameCtrl.text.trim(),
          backendDateOfBirth: _backendDate(_dob),
          gender: _gender,
          sectionId: _sectionId ?? '',
          systemId: _systemIdCtrl.text.trim(),
          admissionNumber: _admissionCtrl.text.trim(),
          parentUserId: _parentUserId,
          photoPath: _photoFile?.path,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Add student failed: $error';
      });
    }
  }

  void _resetForm() {
    setState(() {
      _nameCtrl.clear();
      _dob = DateTime(2010);
      _dobCtrl.text = _displayDate(_dob);
      _gender = 'Female';
      _sectionId = widget.sections.isNotEmpty ? widget.sections.first.id : null;
      _parentUserId = null;
      _photoFile = null;
      _systemIdCtrl.text = _generateSystemId();
      _admissionCtrl.text = _generateAdmissionNumber();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                  children: [
                    _FormCard(
                      title: 'Personal Information',
                      children: [
                        Center(
                          child: InkWell(
                            onTap: _saving ? null : _pickPhoto,
                            borderRadius: BorderRadius.circular(54),
                            child: Column(
                              children: [
                                _PhotoUploadButton(photoFile: _photoFile),
                                const SizedBox(height: 8),
                                Text(
                                  'Upload Photo',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF307E92),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FieldLabel('Student Name'),
                        _TextInput(
                          controller: _nameCtrl,
                          hint: 'Ravali S.',
                          enabled: !_saving,
                          validator: _requiredFullName,
                        ),
                        const SizedBox(height: 12),
                        _ResponsiveFieldRow(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Date of Birth'),
                                _TextInput(
                                  controller: _dobCtrl,
                                  enabled: !_saving,
                                  readOnly: true,
                                  suffixIcon: Icons.calendar_today_outlined,
                                  onTap: _saving ? null : _pickDate,
                                  validator: (_) => _dob.isAfter(DateTime.now())
                                      ? 'Date cannot be in the future'
                                      : null,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Gender'),
                                _DropdownInput<String>(
                                  value: _gender,
                                  enabled: !_saving,
                                  items: const ['Female', 'Male', 'Other'],
                                  labelBuilder: (value) => value,
                                  onChanged: (value) => setState(
                                    () => _gender = value ?? _gender,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FormCard(
                      title: 'Academic & Account Details',
                      children: [
                        _ResponsiveFieldRow(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Class / Section'),
                                _DropdownInput<String>(
                                  value: _sectionId,
                                  enabled:
                                      !_saving && widget.sections.isNotEmpty,
                                  items: widget.sections
                                      .map((s) => s.id)
                                      .toList(),
                                  labelBuilder: _sectionLabel,
                                  onChanged: (value) =>
                                      setState(() => _sectionId = value),
                                  validator: (_) => widget.sections.isEmpty
                                      ? 'Create a class first'
                                      : (_sectionId ?? '').isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('System ID'),
                                _TextInput(
                                  controller: _systemIdCtrl,
                                  enabled: false,
                                  suffixIcon: Icons.lock_outline_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _ResponsiveFieldRow(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Admission / Roll Number'),
                                _TextInput(
                                  controller: _admissionCtrl,
                                  hint: 'ADM-100 / 100',
                                  enabled: !_saving,
                                  validator: (value) => _requiredIdentifier(
                                    value,
                                    'Admission / roll number',
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Parent Association'),
                                _DropdownInput<String?>(
                                  value: _parentUserId,
                                  enabled: !_saving,
                                  items: <String?>[
                                    null,
                                    ...widget.parents.map((p) => p.id),
                                  ],
                                  labelBuilder: _parentLabel,
                                  onChanged: (value) =>
                                      setState(() => _parentUserId = value),
                                  suffixIcon: Icons.search_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9F3FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF1687B2),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Data will be synchronized with the central academic server upon submission.',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF254354),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: GoogleFonts.dmSans(
                          color: AppTheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            tooltip: 'Back',
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Add Student with Photo Upload',
                maxLines: 1,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1C2A32),
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            enabled: !_saving,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'reset') _resetForm();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('Reset form')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
      decoration: BoxDecoration(
        color: _background.withAlpha(245),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7CA6BD).withAlpha(30),
            blurRadius: 12,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: _buildActionButtons(),
    );
  }

  Widget _buildActionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: _buildSubmitButton()),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: _buildCancelButton()),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _buildCancelButton()),
            const SizedBox(width: 12),
            Expanded(child: _buildSubmitButton()),
          ],
        );
      },
    );
  }

  Widget _buildCancelButton() {
    return OutlinedButton(
      onPressed: _saving ? null : () => Navigator.of(context).pop(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: Color(0xFF4E9AAE), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        'Cancel',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          fontWeight: FontWeight.w900,
          color: const Color(0xFF2F788B),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _saving ? null : _submit,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: const Color(0xFF0887F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: _saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              'Add Student',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
    );
  }

  String _sectionLabel(String id) {
    api.SectionModel? section;
    for (final item in widget.sections) {
      if (item.id == id) {
        section = item;
        break;
      }
    }
    if (section == null) return 'Select';
    api.GradeModel? grade;
    for (final item in widget.grades) {
      if (item.id == section.gradeId) {
        grade = item;
        break;
      }
    }
    final gradeName = (grade?.gradeName.trim().isNotEmpty ?? false)
        ? grade!.gradeName.trim()
        : section.gradeName.trim();
    if (gradeName.isNotEmpty) return '$gradeName ${section.sectionName}';
    return 'Section ${section.sectionName}';
  }

  String _parentLabel(String? id) {
    if (id == null || id.isEmpty) return 'Select parent';
    api.UserAccountModel? parent;
    for (final item in widget.parents) {
      if (item.id == id) {
        parent = item;
        break;
      }
    }
    if (parent == null) return 'Parent account';
    if (parent.name.trim().isNotEmpty) return parent.name.trim();
    if (parent.username.trim().isNotEmpty) return parent.username.trim();
    return parent.phone.trim().isNotEmpty ? parent.phone.trim() : parent.id;
  }

  static String _generateSystemId() {
    final suffix =
        DateTime.now().millisecondsSinceEpoch.remainder(90000) + 10000;
    return 'STD-$suffix';
  }

  static String _generateAdmissionNumber() {
    final suffix = DateTime.now().millisecondsSinceEpoch.remainder(90000) + 100;
    return 'ADM-$suffix';
  }

  static String _displayDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String _backendDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String? _requiredFullName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Student name is required';
    final parts = text.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.length < 2) return 'Enter first and last name';
    if (!RegExp(r"^[A-Za-z][A-Za-z .'-]{1,79}$").hasMatch(text)) {
      return 'Use letters, spaces, dots, hyphens, or apostrophes only';
    }
    return null;
  }

  static String? _requiredIdentifier(String? value, String field) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$field is required';
    if (text.length > 40) return '$field is too long';
    if (!RegExp(r'^[A-Za-z0-9 ./_-]+$').hasMatch(text)) {
      return '$field contains unsupported characters';
    }
    return null;
  }
}

class _PhotoUploadButton extends StatelessWidget {
  final XFile? photoFile;

  const _PhotoUploadButton({required this.photoFile});

  @override
  Widget build(BuildContext context) {
    final selected = photoFile != null;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FA),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFBFCBD3), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: selected
          ? FutureBuilder<Uint8List>(
              future: photoFile!.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              },
            )
          : const Icon(
              Icons.photo_camera_rounded,
              size: 38,
              color: Color(0xFF718392),
            ),
    );
  }
}

class _ResponsiveFieldRow extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  const _ResponsiveFieldRow({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FormCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7FA6BD).withAlpha(45),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF24323A),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF51616C),
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final bool enabled;
  final bool readOnly;
  final IconData? suffixIcon;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;

  const _TextInput({
    required this.controller,
    this.hint,
    this.enabled = true,
    this.readOnly = false,
    this.suffixIcon,
    this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF4F7F9),
        suffixIcon: suffixIcon == null ? null : Icon(suffixIcon, size: 17),
        suffixIconConstraints: const BoxConstraints(minWidth: 34),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD5DEE5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD5DEE5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0887F2), width: 1.4),
        ),
      ),
    );
  }
}

class _DropdownInput<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T value) labelBuilder;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final IconData? suffixIcon;
  final String? Function(T?)? validator;

  const _DropdownInput({
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.enabled = true,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      validator: validator,
      icon: Icon(suffixIcon ?? Icons.keyboard_arrow_down_rounded, size: 18),
      style: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1D2B34),
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF4F7F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD5DEE5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD5DEE5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0887F2), width: 1.4),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(
                labelBuilder(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _StudentDetailPage extends StatelessWidget {
  final StudentModel student;
  final String imageUrl;
  final Future<bool> Function(BuildContext context) onRemove;

  const _StudentDetailPage({
    required this.student,
    required this.imageUrl,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF8FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEFF8FD),
        elevation: 0,
        title: const Text('Student Details'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Student actions',
            onSelected: (value) async {
              if (value != 'remove') return;
              final removed = await onRemove(context);
              if (removed && context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Remove Student'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _FormCard(
              title: student.name,
              children: [
                Center(
                  child: _StudentAvatar(
                    imageUrl: imageUrl,
                    initials: student.avatarInitials,
                    size: 88,
                  ),
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  label: 'Class / Section',
                  value: student.classSection,
                ),
                _DetailRow(
                  label: 'Admission / Roll',
                  value: student.rollNumber,
                ),
                _DetailRow(
                  label: 'Status',
                  value: student.directoryStatusLabel,
                ),
                _DetailRow(
                  label: 'Date of Birth',
                  value: student.dateOfBirth.isEmpty
                      ? 'Not available'
                      : _formatStudentDate(student.dateOfBirth),
                ),
                _DetailRow(
                  label: 'Gender',
                  value: student.gender.isEmpty
                      ? 'Not available'
                      : _formatStudentGender(student.gender),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatStudentDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Not available';
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return trimmed;
  return DateFormat('dd MMM yyyy').format(parsed.toLocal());
}

String _formatStudentGender(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Not available';
  final lower = trimmed.toLowerCase();
  if (lower == 'male') return 'Male';
  if (lower == 'female') return 'Female';
  if (lower == 'other') return 'Other';
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelText = Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
            ),
          );
          final valueText = Text(
            value,
            textAlign: constraints.maxWidth < 280
                ? TextAlign.start
                : TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppTheme.onSurface,
            ),
          );

          if (constraints.maxWidth < 280) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, const SizedBox(height: 4), valueText],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: labelText),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: valueText),
            ],
          );
        },
      ),
    );
  }
}

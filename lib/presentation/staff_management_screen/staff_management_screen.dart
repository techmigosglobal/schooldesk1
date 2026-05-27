import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/env_config.dart';
import '../../core/utils/image_cropper_helper.dart';
import '../../services/backend_api_client.dart' as api;
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/empty_state_widget.dart';

class StaffModel {
  final String id;
  final String name;
  final String employeeId;
  final String department;
  final String designation;
  final List<String> assignedClasses;
  final List<String> subjects;
  final String status;
  final int leaveBalance;
  final double attendancePercent;
  final String avatarInitials;
  final String joinDate;
  final String dateOfBirth;
  final String gender;
  final String phone;
  final String email;
  final String password;
  final String accountRole;
  final String photoUrl;
  final String loginUsername;
  final String employmentType;
  final int documentCount;
  final List<Map<String, dynamic>> documents;

  StaffModel({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.department,
    required this.designation,
    required this.assignedClasses,
    required this.subjects,
    required this.status,
    required this.leaveBalance,
    required this.attendancePercent,
    required this.avatarInitials,
    required this.joinDate,
    required this.dateOfBirth,
    required this.gender,
    required this.phone,
    required this.email,
    required this.photoUrl,
    required this.loginUsername,
    required this.employmentType,
    required this.documentCount,
    this.documents = const [],
    this.password = '',
    this.accountRole = 'Teacher',
  });

  factory StaffModel.fromMap(Map<String, dynamic> map) {
    return StaffModel(
      id: map['id'] as String,
      name: map['name'] as String,
      employeeId: map['employeeId'] as String,
      department: map['department'] as String,
      designation: map['designation'] as String,
      assignedClasses: List<String>.from(map['assignedClasses'] as List),
      subjects: List<String>.from(map['subjects'] as List),
      status: map['status'] as String,
      leaveBalance: map['leaveBalance'] as int,
      attendancePercent: (map['attendancePercent'] as num).toDouble(),
      avatarInitials: map['avatarInitials'] as String,
      joinDate: map['joinDate'] as String? ?? '',
      dateOfBirth: map['dateOfBirth'] as String? ?? '',
      gender: map['gender'] as String? ?? '',
      phone: map['phone'] as String,
      email: map['email'] as String,
      photoUrl: map['photoUrl'] as String? ?? '',
      loginUsername: map['loginUsername'] as String? ?? '',
      employmentType: map['employmentType'] as String? ?? '',
      documentCount: map['documentCount'] as int? ?? 0,
      documents: List<Map<String, dynamic>>.from(
        map['documents'] as List? ?? const [],
      ),
      password: map['password'] as String? ?? '',
      accountRole: map['accountRole'] as String? ?? 'Teacher',
    );
  }

  String get directoryStatusLabel {
    switch (status.toLowerCase().trim()) {
      case 'in_class':
      case 'teaching':
        return 'In Class';
      case 'on_leave':
      case 'leave':
      case 'inactive':
      case 'pending_approval':
        return 'On Leave';
      case 'available':
      case 'active':
      default:
        return 'Available';
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'employeeId': employeeId,
    'department': department,
    'designation': designation,
    'assignedClasses': assignedClasses,
    'subjects': subjects,
    'status': status,
    'leaveBalance': leaveBalance,
    'attendancePercent': attendancePercent,
    'avatarInitials': avatarInitials,
    'joinDate': joinDate,
    'dateOfBirth': dateOfBirth,
    'gender': gender,
    'phone': phone,
    'email': email,
    'photoUrl': photoUrl,
    'loginUsername': loginUsername,
    'employmentType': employmentType,
    'documentCount': documentCount,
    'documents': documents,
    'password': password,
    'accountRole': accountRole,
  };
}

class _StaffSupportData {
  final List<api.GradeModel> grades;
  final List<api.SectionModel> sections;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> staffSubjects;
  final List<api.UserAccountModel> users;

  const _StaffSupportData({
    required this.grades,
    required this.sections,
    required this.subjects,
    required this.staffSubjects,
    required this.users,
  });
}

class _StaffAssignmentLabels {
  final List<String> classes;
  final List<String> subjects;

  const _StaffAssignmentLabels({required this.classes, required this.subjects});
}

class StaffManagementScreen extends StatefulWidget {
  final String ownerRole;

  const StaffManagementScreen({super.key, this.ownerRole = 'principal'});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  static const int _pageSize = 20;
  static const Color _background = Color(0xFFEFF8FD);

  final List<StaffModel> _allStaff = [];
  final List<StaffModel> _filteredStaff = [];
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selectedStaffIds = <String>{};

  List<StaffModel> _displayedStaff = [];
  List<String> _departmentOptions = const ['All'];
  List<String> _designationOptions = const ['All'];
  String _searchQuery = '';
  String _selectedDept = 'All';
  String _selectedDesignation = 'All';
  String _selectedStatus = 'All';
  List<api.GradeModel> _grades = const [];
  List<api.SectionModel> _sections = const [];
  List<Map<String, dynamic>> _subjects = const [];
  List<Map<String, dynamic>> _staffSubjects = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _loadError;
  int _currentPage = 0;

  bool get _isAdminOwner => widget.ownerRole.toLowerCase() == 'admin';
  bool get _selectionMode => _selectedStaffIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadStaffFromBackend();
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
      _loadMoreStaff();
    }
  }

  Future<void> _loadStaffFromBackend() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      var page = 1;
      final fetched = <api.StaffModel>[];
      while (true) {
        final res = await api.BackendApiClient.instance.getStaff(
          page: page,
          pageSize: 100,
        );
        fetched.addAll(res.data);
        if (!res.hasMore || res.data.isEmpty) break;
        page++;
      }

      final supportData = await _loadStaffSupportData();
      final uiStaff = fetched
          .map(
            (staff) => _mapApiStaffToUi(
              staff,
              grades: supportData.grades,
              sections: supportData.sections,
              subjects: supportData.subjects,
              staffSubjects: supportData.staffSubjects,
              users: supportData.users,
            ),
          )
          .toList();
      final departments =
          uiStaff
              .map((item) => item.department)
              .where((item) => item.isNotEmpty && item != 'General')
              .toSet()
              .toList()
            ..sort();
      final designations =
          uiStaff
              .map((item) => item.designation)
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      if (!mounted) return;
      setState(() {
        _allStaff
          ..clear()
          ..addAll(uiStaff);
        _filteredStaff
          ..clear()
          ..addAll(uiStaff);
        _grades = supportData.grades;
        _sections = supportData.sections;
        _subjects = supportData.subjects;
        _staffSubjects = supportData.staffSubjects;
        _departmentOptions = ['All', ...departments];
        _designationOptions = ['All', ...designations];
        if (!_departmentOptions.contains(_selectedDept)) _selectedDept = 'All';
        if (!_designationOptions.contains(_selectedDesignation)) {
          _selectedDesignation = 'All';
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

  Future<_StaffSupportData> _loadStaffSupportData() async {
    var grades = <api.GradeModel>[];
    var sections = <api.SectionModel>[];
    var subjects = <Map<String, dynamic>>[];
    var staffSubjects = <Map<String, dynamic>>[];
    var users = <api.UserAccountModel>[];

    try {
      grades = await api.BackendApiClient.instance.getGrades();
    } catch (_) {
      grades = const [];
    }
    try {
      sections = await api.BackendApiClient.instance.getSections();
    } catch (_) {
      sections = const [];
    }
    try {
      subjects = await api.BackendApiClient.instance.getRawList(
        '/subjects',
        queryParameters: const {'page_size': 500},
      );
    } catch (_) {
      subjects = const [];
    }
    try {
      staffSubjects = await api.BackendApiClient.instance.getRawList(
        '/staff-subjects',
        queryParameters: const {'page_size': 500},
      );
    } catch (_) {
      staffSubjects = const [];
    }
    try {
      users = (await api.BackendApiClient.instance.getUsers(
        pageSize: 500,
      )).data;
    } catch (_) {
      users = const [];
    }

    return _StaffSupportData(
      grades: grades,
      sections: sections,
      subjects: subjects,
      staffSubjects: staffSubjects,
      users: users,
    );
  }

  StaffModel _mapApiStaffToUi(
    api.StaffModel staff, {
    List<api.GradeModel> grades = const [],
    List<api.SectionModel> sections = const [],
    List<Map<String, dynamic>> subjects = const [],
    List<Map<String, dynamic>> staffSubjects = const [],
    List<api.UserAccountModel> users = const [],
  }) {
    final fullName = staff.fullName.trim().isEmpty
        ? 'Unknown Staff'
        : staff.fullName.trim();
    final employeeId = staff.staffCode.trim().isEmpty
        ? staff.id.substring(0, staff.id.length < 8 ? staff.id.length : 8)
        : staff.staffCode.trim();
    final assignments = _assignmentLabelsForStaff(
      staff.id,
      grades: grades,
      sections: sections,
      subjects: subjects,
      staffSubjects: staffSubjects,
    );
    final linkedUser = _linkedUserForStaff(staff.id, users);
    return StaffModel(
      id: staff.id,
      name: fullName,
      employeeId: employeeId,
      department: _normalizeDepartment(
        staff.departmentName ?? staff.departmentId,
      ),
      designation: (staff.designation ?? 'Teacher').trim().isEmpty
          ? 'Teacher'
          : staff.designation!.trim(),
      assignedClasses: assignments.classes,
      subjects: assignments.subjects,
      status: staff.status.toLowerCase(),
      leaveBalance: 0,
      attendancePercent: 0,
      avatarInitials: _extractInitials(fullName),
      joinDate: staff.joinDate ?? '',
      dateOfBirth: staff.dateOfBirth ?? '',
      gender: staff.gender ?? '',
      phone: (staff.phone ?? '').trim(),
      email: (staff.email ?? '').trim(),
      photoUrl: staff.photoUrl,
      loginUsername: linkedUser?.username ?? '',
      employmentType: staff.employmentType ?? '',
      documentCount: staff.documentCount,
      documents: staff.documents,
      accountRole: linkedUser?.roleName.trim().isNotEmpty == true
          ? linkedUser!.roleName
          : _roleFromDesignation(staff.designation),
    );
  }

  api.UserAccountModel? _linkedUserForStaff(
    String staffId,
    List<api.UserAccountModel> users,
  ) {
    for (final user in users) {
      if (user.linkedType.toLowerCase() == 'staff' &&
          user.linkedId == staffId) {
        return user;
      }
    }
    return null;
  }

  _StaffAssignmentLabels _assignmentLabelsForStaff(
    String staffId, {
    required List<api.GradeModel> grades,
    required List<api.SectionModel> sections,
    required List<Map<String, dynamic>> subjects,
    required List<Map<String, dynamic>> staffSubjects,
  }) {
    final classLabels = <String>{};
    final subjectLabels = <String>{};

    for (final section in sections) {
      if (section.classTeacherId != staffId) continue;
      classLabels.add(_sectionLabel(section, grades: grades));
    }

    for (final row in staffSubjects) {
      if (_stringValue(row['staff_id']) != staffId) continue;
      final gradeId = _stringValue(row['grade_id']);
      final sectionId = _stringValue(row['section_id']);
      final subjectId = _stringValue(row['subject_id']);
      final classLabel = sectionId.isNotEmpty
          ? _sectionLabelForAssignment(row, sectionId, sections, grades)
          : _gradeLabel(row, gradeId, grades);
      final subjectLabel = _subjectLabel(row, subjectId, subjects);
      if (classLabel.isNotEmpty) classLabels.add(classLabel);
      if (subjectLabel.isNotEmpty) subjectLabels.add(subjectLabel);
    }

    return _StaffAssignmentLabels(
      classes: classLabels.isEmpty
          ? const ['Not assigned']
          : classLabels.toList(),
      subjects: subjectLabels.toList(),
    );
  }

  String _sectionLabelForAssignment(
    Map<String, dynamic> row,
    String sectionId,
    List<api.SectionModel> sections,
    List<api.GradeModel> grades,
  ) {
    final nested = row['section'];
    if (nested is Map) {
      final sectionName = _stringValue(
        nested['section_name'] ?? nested['name'],
      );
      final nestedGrade = nested['grade'];
      var gradeName = '';
      if (nestedGrade is Map) {
        gradeName = _stringValue(
          nestedGrade['grade_name'] ?? nestedGrade['name'],
        );
      }
      if (gradeName.isEmpty) {
        final gradeId = _stringValue(nested['grade_id'] ?? row['grade_id']);
        gradeName = _gradeLabel(row, gradeId, grades);
      }
      if (sectionName.isNotEmpty) {
        return gradeName.isEmpty ? sectionName : '$gradeName - $sectionName';
      }
    }
    for (final section in sections) {
      if (section.id == sectionId) {
        return _sectionLabel(section, grades: grades);
      }
    }
    return '';
  }

  String _gradeLabel(
    Map<String, dynamic> row,
    String gradeId,
    List<api.GradeModel> grades,
  ) {
    final nested = row['grade'];
    if (nested is Map) {
      final value = _stringValue(nested['grade_name'] ?? nested['name']);
      if (value.isNotEmpty) return value;
    }
    for (final grade in grades) {
      if (grade.id == gradeId) return grade.gradeName;
    }
    return '';
  }

  String _sectionLabel(
    api.SectionModel section, {
    List<api.GradeModel> grades = const [],
  }) {
    var grade = _gradeNameForSection(section, grades: grades);
    if (grade.isEmpty) grade = 'Class';
    final sectionName = section.sectionName.trim();
    return sectionName.isEmpty ? grade : '$grade - $sectionName';
  }

  String _gradeNameForSection(
    api.SectionModel section, {
    List<api.GradeModel> grades = const [],
  }) {
    var grade = section.gradeName.trim();
    if (grade.isEmpty) {
      final candidates = grades.isEmpty ? _grades : grades;
      for (final item in candidates) {
        if (item.id == section.gradeId) {
          grade = item.gradeName;
          break;
        }
      }
    }
    return grade;
  }

  String _subjectLabel(
    Map<String, dynamic> row,
    String subjectId,
    List<Map<String, dynamic>> subjects,
  ) {
    final nested = row['subject'];
    if (nested is Map) {
      final value = _stringValue(
        nested['subject_name'] ?? nested['name'] ?? nested['title'],
      );
      if (value.isNotEmpty) return value;
    }
    for (final subject in subjects) {
      if (_stringValue(subject['id']) == subjectId) {
        return _stringValue(
          subject['subject_name'] ?? subject['name'] ?? subject['title'],
        );
      }
    }
    return '';
  }

  String _roleFromDesignation(String? designation) {
    final value = (designation ?? '').toLowerCase();
    if (value.contains('admin')) return 'Admin';
    return 'Teacher';
  }

  static String _stringValue(dynamic value) => (value ?? '').toString().trim();

  String _normalizeDepartment(String? department) {
    if (department == null || department.trim().isEmpty) return 'General';
    return department.trim();
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
    final next = _allStaff.where((staff) {
      final matchesSearch =
          query.isEmpty ||
          staff.name.toLowerCase().contains(query) ||
          staff.employeeId.toLowerCase().contains(query) ||
          staff.department.toLowerCase().contains(query) ||
          staff.designation.toLowerCase().contains(query);
      final matchesDept =
          _selectedDept == 'All' || staff.department == _selectedDept;
      final matchesDesignation =
          _selectedDesignation == 'All' ||
          staff.designation == _selectedDesignation;
      final matchesStatus =
          _selectedStatus == 'All' ||
          staff.directoryStatusLabel == _selectedStatus;
      return matchesSearch &&
          matchesDept &&
          matchesDesignation &&
          matchesStatus;
    }).toList();

    void apply() {
      _filteredStaff
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
    _hasMore = _filteredStaff.length > _pageSize;
    _displayedStaff = _filteredStaff.take(_pageSize).toList();
  }

  void _loadMoreStaff() {
    if (_loadingMore || !_hasMore) return;
    final start = (_currentPage + 1) * _pageSize;
    if (start >= _filteredStaff.length) {
      setState(() => _hasMore = false);
      return;
    }
    setState(() {
      _loadingMore = true;
      final end = (start + _pageSize).clamp(0, _filteredStaff.length);
      _displayedStaff.addAll(_filteredStaff.sublist(start, end));
      _currentPage++;
      _loadingMore = false;
      _hasMore = end < _filteredStaff.length;
    });
  }

  void _toggleStaffSelection(StaffModel staff) {
    setState(() {
      if (_selectedStaffIds.contains(staff.id)) {
        _selectedStaffIds.remove(staff.id);
      } else {
        _selectedStaffIds.add(staff.id);
      }
    });
  }

  void _clearStaffSelection() {
    setState(_selectedStaffIds.clear);
  }

  void _selectAllDisplayedStaff() {
    setState(() {
      _selectedStaffIds
        ..clear()
        ..addAll(_displayedStaff.map((staff) => staff.id));
    });
  }

  Future<void> _deleteSelectedStaff() async {
    final selected = _allStaff
        .where((staff) => _selectedStaffIds.contains(staff.id))
        .toList();
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Remove selected staff',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Remove ${selected.length} selected staff member${selected.length == 1 ? '' : 's'} from staff records?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    var removed = 0;
    final failures = <String>[];
    for (final staff in selected) {
      try {
        await api.BackendApiClient.instance.deleteStaff(staff.id);
        removed++;
      } catch (_) {
        failures.add(staff.name);
      }
    }
    if (!mounted) return;
    _selectedStaffIds.clear();
    await _loadStaffFromBackend();
    if (!mounted) return;
    _showStaffMessage(
      failures.isEmpty
          ? '$removed staff member${removed == 1 ? '' : 's'} removed'
          : '$removed removed, ${failures.length} failed',
      failures.isEmpty ? AppTheme.success : AppTheme.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton(
              heroTag: _isAdminOwner
                  ? 'add-admin-staff'
                  : 'add-principal-staff',
              onPressed: _openStaffProfileForm,
              backgroundColor: const Color(0xFF0887F2),
              foregroundColor: Colors.white,
              elevation: 8,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, size: 30),
            ),
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF0887F2),
          onRefresh: _loadStaffFromBackend,
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
                      title: 'Unable to load staff',
                      description: _loadError!,
                      actionLabel: 'Retry',
                      onAction: _loadStaffFromBackend,
                    ),
                  ),
                )
              else if (_filteredStaff.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.co_present_outlined,
                      title: 'No staff found',
                      description:
                          'Adjust your search or filters to find staff.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 96),
                  sliver: SliverList.builder(
                    itemCount: _displayedStaff.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _displayedStaff.length) {
                        return _buildLoadMoreButton();
                      }
                      final staff = _displayedStaff[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: _TeacherDirectoryCard(
                          staff: staff,
                          imageUrl: _absoluteImageUrl(staff.photoUrl),
                          selected: _selectedStaffIds.contains(staff.id),
                          onTap: () => _selectionMode
                              ? _toggleStaffSelection(staff)
                              : _openStaffDetail(staff),
                          onLongPress: () => _toggleStaffSelection(staff),
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
    if (_selectionMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              IconButton(
                onPressed: _clearStaffSelection,
                icon: const Icon(Icons.close_rounded, size: 22),
                tooltip: 'Clear selection',
              ),
              Expanded(
                child: Text(
                  '${_selectedStaffIds.length} selected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A2A33),
                  ),
                ),
              ),
              IconButton(
                onPressed: _selectAllDisplayedStaff,
                icon: const Icon(Icons.select_all_rounded, size: 22),
                tooltip: 'Select visible',
              ),
              IconButton(
                onPressed: _deleteSelectedStaff,
                icon: const Icon(Icons.delete_outline_rounded, size: 22),
                color: AppTheme.error,
                tooltip: 'Remove selected',
              ),
            ],
          ),
        ),
      );
    }
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
                  'All Staff Directory',
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final chipRowHeight = (34.0 * textScale).clamp(38.0, 56.0).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child: Column(
        children: [
          _SearchBox(
            hint: 'Search staff...',
            onChanged: (value) {
              _searchQuery = value;
              _applyFilters();
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: chipRowHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _DirectoryChip(
                  label: 'All Staff',
                  selected:
                      _selectedDept == 'All' &&
                      _selectedDesignation == 'All' &&
                      _selectedStatus == 'All',
                  onTap: () {
                    _selectedDept = 'All';
                    _selectedDesignation = 'All';
                    _selectedStatus = 'All';
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _DirectoryChip(
                  label: _selectedDept == 'All' ? 'Department' : _selectedDept,
                  selected: _selectedDept != 'All',
                  onTap: () => _chooseFilter(
                    title: 'Department',
                    options: _departmentOptions,
                    selected: _selectedDept,
                    onSelected: (value) {
                      _selectedDept = value;
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _DirectoryChip(
                  label: _selectedDesignation == 'All'
                      ? 'Designation'
                      : _selectedDesignation,
                  selected: _selectedDesignation != 'All',
                  onTap: () => _chooseFilter(
                    title: 'Designation',
                    options: _designationOptions,
                    selected: _selectedDesignation,
                    onSelected: (value) {
                      _selectedDesignation = value;
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _DirectoryChip(
                  label: _selectedStatus == 'All'
                      ? 'Status'
                      : 'Status: $_selectedStatus',
                  selected: _selectedStatus != 'All',
                  onTap: () => _chooseFilter(
                    title: 'Status',
                    options: const ['All', 'In Class', 'On Leave', 'Available'],
                    selected: _selectedStatus,
                    onSelected: (value) {
                      _selectedStatus = value;
                      _applyFilters();
                    },
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
          onPressed: _loadMoreStaff,
          child: Text(
            _loadingMore ? 'Loading...' : 'Load more staff',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseFilter({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map(
                    (option) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(option == 'All' ? 'All $title' : option),
                      trailing: option == selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF0887F2),
                            )
                          : null,
                      onTap: () => Navigator.pop(context, option),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    onSelected(picked);
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

  Future<void> _openStaffProfileForm([StaffModel? staff]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _StaffProfileFormPage(
          ownerRole: widget.ownerRole,
          initialStaff: staff,
          grades: _grades,
          sections: _sections,
          subjects: _subjects,
          initialAssignments: _existingAssignmentsForStaff(staff),
          onSubmit: _saveStaffProfile,
        ),
      ),
    );
  }

  Future<void> _saveStaffProfile(_StaffProfileInput input) async {
    final firstName = input.fullName.trim();
    const lastName = '';
    final password = input.createLogin ? input.password : null;
    var staffId = input.staffId ?? '';

    if (input.staffId == null) {
      final staff = await api.BackendApiClient.instance.createStaff(
        firstName: firstName,
        lastName: lastName,
        staffCode: input.employeeId,
        username: input.username,
        email: input.email,
        phone: input.phone,
        designation: input.designation,
        departmentId: input.department,
        password: password,
        accountRole: input.accountRole,
        gender: input.gender.toLowerCase(),
        employmentType: input.employmentType,
        joinDate: input.backendJoinDate,
        dateOfBirth: input.backendDateOfBirth,
        requestPrincipalApproval: _isAdminOwner,
      );
      staffId = staff.id;
    } else {
      await api.BackendApiClient.instance.updateStaff(
        staffId,
        firstName: firstName,
        lastName: lastName,
        staffCode: input.employeeId,
        username: input.createLogin ? input.username : null,
        email: input.email,
        phone: input.phone,
        designation: input.designation,
        departmentId: input.department,
        password: password,
        accountRole: input.accountRole,
        gender: input.gender.toLowerCase(),
        employmentType: input.employmentType,
        joinDate: input.backendJoinDate,
        dateOfBirth: input.backendDateOfBirth,
      );
    }

    if ((input.photoPath ?? '').isNotEmpty ||
        (input.photoBytes?.isNotEmpty ?? false)) {
      await api.BackendApiClient.instance.uploadStaffPhoto(
        staffId: staffId,
        filePath: input.photoPath,
        fileBytes: input.photoBytes,
        fileName: input.photoName,
      );
    }

    for (final document in input.documents) {
      await api.BackendApiClient.instance.uploadStaffDocument(
        staffId: staffId,
        filePath: document.filePath,
        fileBytes: document.fileBytes,
        fileName: document.fileName,
        documentType: document.documentType,
      );
    }

    await _syncStaffAssignments(staffId, input.assignments);
    await _loadStaffFromBackend();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          input.staffId == null
              ? '${input.fullName.trim()} added'
              : '${input.fullName.trim()} updated',
        ),
      ),
    );
  }

  Future<void> _syncStaffAssignments(
    String staffId,
    List<_StaffAssignmentInput> desired,
  ) async {
    final desiredClassTeacherSectionIds = desired
        .where((item) => item.sectionId.isNotEmpty && item.subjectId.isEmpty)
        .map((item) => item.sectionId)
        .toSet();
    final currentTeacherSections = _sections
        .where((section) => section.classTeacherId == staffId)
        .toList();

    for (final section in currentTeacherSections) {
      if (!desiredClassTeacherSectionIds.contains(section.id)) {
        await _updateSectionClassTeacher(section, null);
      }
    }

    for (final assignment in desired) {
      if (assignment.sectionId.isEmpty || assignment.subjectId.isNotEmpty) {
        continue;
      }
      final section = _sectionByIdInState(assignment.sectionId);
      if (section == null || section.classTeacherId == staffId) continue;
      await _updateSectionClassTeacher(section, staffId);
    }

    final existing = _staffSubjects
        .where((row) => _stringValue(row['staff_id']) == staffId)
        .toList();
    final desiredKeys = desired
        .where((item) => item.gradeId.isNotEmpty && item.subjectId.isNotEmpty)
        .map((item) => item.staffSubjectKey)
        .toSet();
    final existingKeys = existing.map(_assignmentKeyFromRow).toSet();

    for (final row in existing) {
      final id = _stringValue(row['id']);
      if (id.isEmpty) continue;
      if (!desiredKeys.contains(_assignmentKeyFromRow(row))) {
        await api.BackendApiClient.instance.deleteRaw('/staff-subjects/$id');
      }
    }

    for (final assignment in desired) {
      if (assignment.gradeId.isEmpty || assignment.subjectId.isEmpty) continue;
      if (existingKeys.contains(assignment.staffSubjectKey)) continue;
      final payload = <String, dynamic>{
        'staff_id': staffId,
        'grade_id': assignment.gradeId,
        'subject_id': assignment.subjectId,
        'is_primary': assignment.isPrimary,
      };
      if (assignment.sectionId.isNotEmpty) {
        payload['section_id'] = assignment.sectionId;
      }
      await api.BackendApiClient.instance.createRaw('/staff-subjects', payload);
    }
  }

  String _assignmentKeyFromRow(Map<String, dynamic> row) {
    final sectionId = _stringValue(row['section_id']);
    return '${sectionId.isEmpty ? _stringValue(row['grade_id']) : sectionId}|${_stringValue(row['subject_id'])}';
  }

  Future<void> _updateSectionClassTeacher(
    api.SectionModel section,
    String? staffId,
  ) async {
    await api.BackendApiClient.instance.updateRaw('/sections/${section.id}', {
      'grade_id': section.gradeId,
      'academic_year_id': section.academicYearId,
      'section_name': section.sectionName,
      'capacity': section.capacity,
      'class_teacher_id': staffId ?? '',
    });
  }

  api.SectionModel? _sectionByIdInState(String sectionId) {
    for (final section in _sections) {
      if (section.id == sectionId) return section;
    }
    return null;
  }

  List<_StaffAssignmentInput> _existingAssignmentsForStaff(StaffModel? staff) {
    if (staff == null) return const [];
    final assignments = <_StaffAssignmentInput>[];
    for (final section in _sections) {
      if (section.classTeacherId != staff.id) continue;
      assignments.add(
        _StaffAssignmentInput(
          gradeId: section.gradeId,
          gradeLabel: _gradeNameForSection(section),
          sectionId: section.id,
          sectionLabel: _sectionLabel(section),
          subjectId: '',
          subjectLabel: 'Class teacher',
        ),
      );
    }
    for (final row in _staffSubjects) {
      if (_stringValue(row['staff_id']) != staff.id) continue;
      final gradeId = _stringValue(row['grade_id']);
      final subjectId = _stringValue(row['subject_id']);
      if (gradeId.isEmpty || subjectId.isEmpty) continue;
      final sectionId = _stringValue(row['section_id']);
      final section = sectionId.isEmpty ? null : _sectionByIdInState(sectionId);
      assignments.add(
        _StaffAssignmentInput(
          gradeId: gradeId,
          gradeLabel: section == null
              ? _gradeLabel(row, gradeId, _grades)
              : _gradeNameForSection(section),
          sectionId: section?.id ?? sectionId,
          sectionLabel: section == null
              ? _sectionLabelForAssignment(row, sectionId, _sections, _grades)
              : _sectionLabel(section),
          subjectId: subjectId,
          subjectLabel: _subjectLabel(row, subjectId, _subjects),
          isPrimary: row['is_primary'] == true,
          recordId: _stringValue(row['id']),
        ),
      );
    }
    final deduped = <String, _StaffAssignmentInput>{};
    for (final assignment in assignments) {
      deduped[assignment.key] = assignment;
    }
    return deduped.values.toList();
  }

  Future<void> _openStaffDetail(StaffModel staff) async {
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _TeacherDetailPage(
          staff: staff,
          imageUrl: _absoluteImageUrl(staff.photoUrl),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _openStaffProfileForm(staff);
    } else if (action == 'delete') {
      await _deleteStaff(staff);
    }
  }

  Future<void> _deleteStaff(StaffModel staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Staff',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w900),
        ),
        content: Text('Remove ${staff.name} from staff records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await api.BackendApiClient.instance.deleteStaff(staff.id);
      if (!mounted) return;
      _showStaffMessage('${staff.name} removed', AppTheme.success);
      await _loadStaffFromBackend();
    } catch (error) {
      if (!mounted) return;
      _showStaffMessage(error.toString(), AppTheme.error);
    }
  }

  void _showStaffMessage(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }
}

class _TeacherDirectoryCard extends StatelessWidget {
  final StaffModel staff;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TeacherDirectoryCard({
    required this.staff,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE0F8FF) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      shadowColor: const Color(0xFF8AAAC0).withAlpha(55),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFF0887F2) : Colors.transparent,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              _TeacherAvatar(
                imageUrl: imageUrl,
                initials: staff.avatarInitials,
                size: 58,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      staff.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E2A32),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      staff.department,
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
              selected
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF0887F2),
                      size: 24,
                    )
                  : _TeacherStatusBadge(label: staff.directoryStatusLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherAvatar extends StatelessWidget {
  final String imageUrl;
  final String initials;
  final double size;

  const _TeacherAvatar({
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

class _TeacherStatusBadge extends StatelessWidget {
  final String label;

  const _TeacherStatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = switch (label) {
      'On Leave' => (const Color(0xFFFFECEC), const Color(0xFFBA4242)),
      'In Class' => (const Color(0xFFDFF8E7), const Color(0xFF2F9E5B)),
      _ => (const Color(0xFFFFF2CE), const Color(0xFFB78412)),
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

class _StaffProfileInput {
  final String? staffId;
  final String fullName;
  final String backendDateOfBirth;
  final String gender;
  final String phone;
  final String email;
  final String department;
  final String designation;
  final String employmentType;
  final String backendJoinDate;
  final String employeeId;
  final String username;
  final String accountRole;
  final String? password;
  final bool createLogin;
  final String? photoPath;
  final Uint8List? photoBytes;
  final String? photoName;
  final List<_StaffAssignmentInput> assignments;
  final List<_StaffDocumentInput> documents;

  const _StaffProfileInput({
    required this.staffId,
    required this.fullName,
    required this.backendDateOfBirth,
    required this.gender,
    required this.phone,
    required this.email,
    required this.department,
    required this.designation,
    required this.employmentType,
    required this.backendJoinDate,
    required this.employeeId,
    required this.username,
    required this.accountRole,
    required this.password,
    required this.createLogin,
    required this.photoPath,
    required this.photoBytes,
    required this.photoName,
    required this.assignments,
    required this.documents,
  });
}

class _StaffAssignmentInput {
  final String gradeId;
  final String gradeLabel;
  final String sectionId;
  final String sectionLabel;
  final String subjectId;
  final String subjectLabel;
  final bool isPrimary;
  final String? recordId;

  const _StaffAssignmentInput({
    required this.gradeId,
    required this.gradeLabel,
    this.sectionId = '',
    this.sectionLabel = '',
    required this.subjectId,
    required this.subjectLabel,
    this.isPrimary = false,
    this.recordId,
  });

  String get key =>
      '${sectionId.isEmpty ? gradeId : sectionId}|${subjectId.isEmpty ? 'class_teacher' : subjectId}';

  String get staffSubjectKey =>
      '${sectionId.isEmpty ? gradeId : sectionId}|$subjectId';

  String get displayLabel {
    final classLabel = sectionLabel.isNotEmpty ? sectionLabel : gradeLabel;
    return subjectId.isEmpty ? classLabel : '$classLabel - $subjectLabel';
  }
}

class _StaffDocumentInput {
  final String documentType;
  final String? filePath;
  final Uint8List? fileBytes;
  final String fileName;

  const _StaffDocumentInput({
    required this.documentType,
    required this.filePath,
    required this.fileBytes,
    required this.fileName,
  });
}

class _StaffProfileFormPage extends StatefulWidget {
  final String ownerRole;
  final StaffModel? initialStaff;
  final List<api.GradeModel> grades;
  final List<api.SectionModel> sections;
  final List<Map<String, dynamic>> subjects;
  final List<_StaffAssignmentInput> initialAssignments;
  final Future<void> Function(_StaffProfileInput input) onSubmit;

  const _StaffProfileFormPage({
    required this.ownerRole,
    required this.initialStaff,
    required this.grades,
    required this.sections,
    required this.subjects,
    required this.initialAssignments,
    required this.onSubmit,
  });

  @override
  State<_StaffProfileFormPage> createState() => _StaffProfileFormPageState();
}

class _StaffProfileFormPageState extends State<_StaffProfileFormPage> {
  static const Color _background = Color(0xFFEFF8FD);
  static const String _customDepartmentValue = '__custom_department__';
  static const String _customDesignationValue = '__custom_designation__';
  static const List<String> _departments = [
    'Teacher',
    'Co Teacher',
    'Admin',
    'Staff',
    'Support Staff',
    'PE',
  ];
  static const List<String> _designations = [
    'Teacher',
    'Co Teacher',
    'Admin',
    'Staff',
    'Support Staff',
    'PE',
  ];
  static const List<String> _employmentTypes = [
    'full_time',
    'part_time',
    'contract',
    'temporary',
  ];
  static const List<String> _documentTypes = [
    'identity_proof',
    'address_proof',
    'qualification_certificate',
    'experience_letter',
    'joining_document',
    'other_document',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _customDepartmentCtrl = TextEditingController();
  final _customDesignationCtrl = TextEditingController();
  late final TextEditingController _dobCtrl;
  late final TextEditingController _joiningCtrl;
  late final TextEditingController _employeeCtrl;
  final ImagePicker _picker = ImagePicker();

  DateTime? _dob;
  DateTime? _joiningDate;
  String? _gender;
  String? _department;
  String? _designation;
  String _employmentType = 'full_time';
  String _accountRole = 'Teacher';
  String _documentType = _documentTypes.first;
  String? _selectedSectionId;
  String? _selectedSubjectId;
  XFile? _photoFile;
  late List<_StaffAssignmentInput> _assignments;
  final List<_StaffDocumentInput> _documents = [];
  bool _loginEnabled = true;
  bool _passwordVisible = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initialStaff != null;

  bool get _isAdminOwner => widget.ownerRole.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    final staff = widget.initialStaff;
    _dobCtrl = TextEditingController();
    _joiningCtrl = TextEditingController();
    _employeeCtrl = TextEditingController(text: staff?.employeeId ?? '');
    _assignments = List<_StaffAssignmentInput>.from(widget.initialAssignments);
    if (staff != null) {
      _nameCtrl.text = staff.name;
      _phoneCtrl.text = staff.phone;
      _emailCtrl.text = staff.email;
      _usernameCtrl.text = staff.loginUsername;
      _setDepartmentFromValue(staff.department);
      _setDesignationFromValue(staff.designation);
      _employmentType = staff.employmentType.trim().isEmpty
          ? 'full_time'
          : staff.employmentType;
      _accountRole = staff.accountRole;
      _loginEnabled = false;
      _gender = _displayGender(staff.gender);
      _dob = _parseBackendDate(staff.dateOfBirth);
      _joiningDate = _parseBackendDate(staff.joinDate);
      if (_dob != null) _dobCtrl.text = _displayDate(_dob!);
      if (_joiningDate != null) {
        _joiningCtrl.text = _displayDate(_joiningDate!);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    _customDepartmentCtrl.dispose();
    _customDesignationCtrl.dispose();
    _dobCtrl.dispose();
    _joiningCtrl.dispose();
    _employeeCtrl.dispose();
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
      title: 'Crop Staff Photo',
    );
    if (croppedPath == null || !mounted) return;
    setState(() => _photoFile = XFile(croppedPath));
  }

  Future<void> _pickDate({required bool joining}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: joining
          ? (_joiningDate ?? DateTime.now())
          : (_dob ?? DateTime(1990)),
      firstDate: joining ? DateTime(2000) : DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (joining) {
        _joiningDate = selected;
        _joiningCtrl.text = _displayDate(selected);
      } else {
        _dob = selected;
        _dobCtrl.text = _displayDate(selected);
      }
    });
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: kIsWeb,
    );
    if (result == null || !mounted) return;
    final selected = result.files
        .where(
          (file) =>
              (file.path ?? '').trim().isNotEmpty ||
              (file.bytes?.isNotEmpty ?? false),
        )
        .map(
          (file) => _StaffDocumentInput(
            documentType: _documentType,
            filePath: (file.path ?? '').trim().isEmpty
                ? null
                : file.path!.trim(),
            fileBytes: file.bytes,
            fileName: file.name,
          ),
        )
        .toList();
    if (selected.isEmpty) return;
    setState(() => _documents.addAll(selected));
  }

  void _addAssignment() {
    final sectionId = _selectedSectionId;
    final subjectId = _selectedSubjectId;
    if (sectionId == null) {
      setState(() => _error = 'Select class and section before adding');
      return;
    }
    final section = _sectionById(sectionId);
    if (section == null) {
      setState(() => _error = 'Selected section is not available');
      return;
    }
    final assignmentKey = '$sectionId|${subjectId ?? 'class_teacher'}';
    if (_assignments.any((item) => item.key == assignmentKey)) {
      setState(() => _error = 'This section assignment already exists');
      return;
    }
    setState(() {
      _error = null;
      _assignments.add(
        _StaffAssignmentInput(
          gradeId: section.gradeId,
          gradeLabel: _gradeNameById(section.gradeId),
          sectionId: section.id,
          sectionLabel: _sectionNameById(section.id),
          subjectId: subjectId ?? '',
          subjectLabel: subjectId == null || subjectId.isEmpty
              ? 'Class teacher'
              : _subjectNameById(subjectId),
          isPrimary: _assignments.isEmpty,
        ),
      );
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null || _joiningDate == null) {
      setState(() => _error = 'Date of birth and joining date are required');
      return;
    }
    if (_joiningDate!.isBefore(_dob!)) {
      setState(() => _error = 'Joining date cannot be before date of birth');
      return;
    }
    if (_joiningDate!.difference(_dob!).inDays < 18 * 365) {
      setState(() => _error = 'Staff member must be at least 18 years old');
      return;
    }
    if (_loginEnabled && _emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Email is required when login access is enabled');
      return;
    }
    if (_loginEnabled && _usernameCtrl.text.trim().isEmpty) {
      setState(
        () => _error = 'Username is required when login access is enabled',
      );
      return;
    }
    if (_loginEnabled && _passwordCtrl.text.trim().length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    final department = _resolvedDepartment;
    final designation = _resolvedDesignation;
    if (department == null || designation == null) {
      setState(() => _error = 'Department and designation are required');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final photoBytes = _photoFile == null
          ? null
          : await _photoFile!.readAsBytes();
      await widget.onSubmit(
        _StaffProfileInput(
          staffId: widget.initialStaff?.id,
          fullName: _nameCtrl.text.trim(),
          backendDateOfBirth: _backendDate(_dob!),
          gender: _gender!,
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          department: department,
          designation: designation,
          employmentType: _employmentType,
          backendJoinDate: _backendDate(_joiningDate!),
          employeeId: _employeeCtrl.text.trim(),
          username: _usernameCtrl.text.trim(),
          accountRole: _accountRole,
          password: _passwordCtrl.text.trim(),
          createLogin: _loginEnabled,
          photoPath: _photoFile?.path,
          photoBytes: photoBytes,
          photoName: _photoFile?.name,
          assignments: List<_StaffAssignmentInput>.from(_assignments),
          documents: List<_StaffDocumentInput>.from(_documents),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            '${_isEdit ? 'Update' : 'Add'} staff failed: ${_friendlyError(error)}';
      });
    }
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
                    _personalDetailsCard(),
                    const SizedBox(height: 14),
                    _employmentDetailsCard(),
                    const SizedBox(height: 14),
                    _loginAccessCard(),
                    const SizedBox(height: 14),
                    _assignmentCard(),
                    const SizedBox(height: 14),
                    _documentCard(),
                    const SizedBox(height: 14),
                    _InlineNotice(
                      icon: Icons.verified_rounded,
                      text:
                          'Staff profile, login access, assignments, and documents will sync with the central academic server on submission.',
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

  Widget _personalDetailsCard() {
    return _FormCard(
      title: 'Personal Details',
      children: [
        Center(
          child: InkWell(
            onTap: _saving ? null : _pickPhoto,
            borderRadius: BorderRadius.circular(54),
            child: Column(
              children: [
                _PhotoUploadButton(
                  photoFile: _photoFile,
                  imageUrl: _absoluteImageUrl(
                    widget.initialStaff?.photoUrl ?? '',
                  ),
                ),
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
        _FieldLabel('Full Name'),
        _TextInput(
          controller: _nameCtrl,
          hint: 'Enter full name',
          enabled: !_saving,
          validator: _requiredFullName,
        ),
        const SizedBox(height: 12),
        _ResponsiveFieldRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(
              label: 'Date of Birth',
              child: _TextInput(
                controller: _dobCtrl,
                hint: 'Select date',
                enabled: !_saving,
                readOnly: true,
                suffixIcon: Icons.calendar_today_outlined,
                onTap: _saving ? null : () => _pickDate(joining: false),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
            ),
            _LabeledField(
              label: 'Gender',
              child: _DropdownInput<String>(
                value: _gender,
                enabled: !_saving,
                hint: 'Select gender',
                items: const ['Female', 'Male', 'Other'],
                labelBuilder: (value) => value,
                onChanged: (value) => setState(() => _gender = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ResponsiveFieldRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(
              label: 'Phone Number',
              child: _TextInput(
                controller: _phoneCtrl,
                hint: 'Enter phone number',
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                validator: _requiredPhone,
              ),
            ),
            _LabeledField(
              label: 'Email',
              child: _TextInput(
                controller: _emailCtrl,
                hint: 'staff@example.com',
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                validator: _optionalEmail,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _employmentDetailsCard() {
    return _FormCard(
      title: 'Employment Details',
      children: [
        _ResponsiveFieldRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(label: 'Department', child: _buildDepartmentInput()),
            _LabeledField(
              label: 'Designation',
              child: _buildDesignationInput(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ResponsiveFieldRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(
              label: 'Date of Joining',
              child: _TextInput(
                controller: _joiningCtrl,
                hint: 'Select date',
                enabled: !_saving,
                readOnly: true,
                suffixIcon: Icons.calendar_today_outlined,
                onTap: _saving ? null : () => _pickDate(joining: true),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
            ),
            _LabeledField(
              label: 'Employee ID',
              child: _TextInput(
                controller: _employeeCtrl,
                hint: 'Enter employee ID',
                enabled: !_saving,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FieldLabel('Employment Type'),
        _DropdownInput<String>(
          value: _employmentType,
          enabled: !_saving,
          hint: 'Select employment type',
          items: _employmentTypes,
          labelBuilder: _employmentLabel,
          onChanged: (value) =>
              setState(() => _employmentType = value ?? 'full_time'),
        ),
      ],
    );
  }

  Widget _loginAccessCard() {
    return _FormCard(
      title: 'Login Access',
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _loginEnabled,
          onChanged: _saving
              ? null
              : (value) => setState(() {
                  _loginEnabled = value;
                  if (!value) _passwordCtrl.clear();
                }),
          title: Text(
            _isEdit ? 'Reset login password' : 'Create staff login',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E2A32),
            ),
          ),
          subtitle: Text(
            _isEdit
                ? 'Use this when the staff member needs a new password.'
                : 'Email and password create access for admin or teacher roles.',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5D6C76),
            ),
          ),
        ),
        if (_loginEnabled) ...[
          const SizedBox(height: 10),
          _LabeledField(
            label: 'Login Username',
            child: _TextInput(
              controller: _usernameCtrl,
              hint: 'Enter username',
              enabled: !_saving,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
          ),
          const SizedBox(height: 10),
          _ResponsiveFieldRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LabeledField(
                label: 'Login Role',
                child: _DropdownInput<String>(
                  value: _accountRole,
                  enabled: !_saving,
                  hint: 'Select role',
                  items: _roleOptions,
                  labelBuilder: (value) => value,
                  onChanged: (value) =>
                      setState(() => _accountRole = value ?? 'Teacher'),
                ),
              ),
              _LabeledField(
                label: _isEdit ? 'New Password' : 'Password',
                child: _TextInput(
                  controller: _passwordCtrl,
                  hint: _isEdit ? 'Enter new password' : 'Create password',
                  enabled: !_saving,
                  obscureText: !_passwordVisible,
                  suffixIcon: _passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffixTap: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _assignmentCard() {
    return _FormCard(
      title: 'Teaching Assignment',
      children: [
        if (widget.sections.isEmpty)
          _InlineNotice(
            icon: Icons.info_outline_rounded,
            text:
                'Create classes and sections first to assign this staff member to a section.',
          )
        else ...[
          _ResponsiveFieldRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LabeledField(
                label: 'Class / Section',
                child: _DropdownInput<String>(
                  value: _selectedSectionId,
                  enabled: !_saving,
                  hint: 'Select section',
                  items: widget.sections.map((section) => section.id).toList(),
                  labelBuilder: _sectionNameById,
                  onChanged: (value) =>
                      setState(() => _selectedSectionId = value),
                ),
              ),
              _LabeledField(
                label: 'Subject',
                child: _DropdownInput<String>(
                  value: _selectedSubjectId,
                  enabled: !_saving && widget.subjects.isNotEmpty,
                  hint: widget.subjects.isEmpty
                      ? 'Optional subject unavailable'
                      : 'Optional subject',
                  items: [
                    '',
                    ...widget.subjects
                        .map((subject) => _mapId(subject))
                        .where((id) => id.isNotEmpty),
                  ],
                  labelBuilder: _subjectNameById,
                  onChanged: (value) => setState(
                    () => _selectedSubjectId = (value ?? '').isEmpty
                        ? null
                        : value,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _addAssignment,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Assignment'),
            ),
          ),
          if (_assignments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final assignment in _assignments)
                  InputChip(
                    label: Text(
                      assignment.displayLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: _saving
                        ? null
                        : () => setState(() => _assignments.remove(assignment)),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _documentCard() {
    return _FormCard(
      title: 'Upload Documents if any',
      children: [
        _ResponsiveFieldRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(
              label: 'Document Type',
              child: _DropdownInput<String>(
                value: _documentType,
                enabled: !_saving,
                hint: 'Select type',
                items: _documentTypes,
                labelBuilder: (value) => value,
                onChanged: (value) => setState(
                  () => _documentType = value ?? _documentTypes.first,
                ),
              ),
            ),
            _LabeledField(
              label: 'Document File',
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickDocuments,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: Text(
                  _documents.isEmpty
                      ? 'Choose PDF or image'
                      : '${_documents.length} selected',
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_documents.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final document in _documents)
            _DocumentSelectionTile(
              document: document,
              onRemove: _saving
                  ? null
                  : () => setState(() => _documents.remove(document)),
            ),
        ],
      ],
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
                _isEdit ? 'Edit Staff Profile' : 'Add Staff Profile',
                maxLines: 1,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1C2A32),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _saving ? null : _resetForm,
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Reset',
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
              _isEdit ? 'Save Staff' : 'Add Staff',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
    );
  }

  void _resetForm() {
    setState(() {
      final staff = widget.initialStaff;
      _nameCtrl.text = staff?.name ?? '';
      _phoneCtrl.text = staff?.phone ?? '';
      _emailCtrl.text = staff?.email ?? '';
      _usernameCtrl.text = staff?.loginUsername ?? '';
      _passwordCtrl.clear();
      _dob = staff == null ? null : _parseBackendDate(staff.dateOfBirth);
      _joiningDate = staff == null ? null : _parseBackendDate(staff.joinDate);
      _dobCtrl.text = _dob == null ? '' : _displayDate(_dob!);
      _joiningCtrl.text = _joiningDate == null
          ? ''
          : _displayDate(_joiningDate!);
      _gender = staff == null ? null : _displayGender(staff.gender);
      _setDepartmentFromValue(staff?.department);
      _setDesignationFromValue(staff?.designation);
      _employmentType = staff?.employmentType.trim().isNotEmpty == true
          ? staff!.employmentType
          : 'full_time';
      _accountRole = staff?.accountRole ?? 'Teacher';
      _selectedSectionId = null;
      _selectedSubjectId = null;
      _photoFile = null;
      _documents.clear();
      _assignments = List<_StaffAssignmentInput>.from(
        widget.initialAssignments,
      );
      _loginEnabled = !_isEdit;
      _employeeCtrl.text = staff?.employeeId ?? '';
      _error = null;
    });
  }

  List<String> get _departmentItems {
    final items = <String>[..._departments, _customDepartmentValue];
    final selected = (_department ?? '').trim();
    if (selected.isNotEmpty &&
        selected != _customDepartmentValue &&
        !_departments.contains(selected)) {
      return [selected, ...items];
    }
    return items;
  }

  List<String> get _designationItems {
    final items = <String>[..._designations, _customDesignationValue];
    final selected = (_designation ?? '').trim();
    if (selected.isNotEmpty &&
        selected != _customDesignationValue &&
        !_designations.contains(selected)) {
      return [selected, ...items];
    }
    return items;
  }

  bool get _isCustomDepartment => _department == _customDepartmentValue;

  bool get _isCustomDesignation => _designation == _customDesignationValue;

  String? get _resolvedDepartment {
    final value = _isCustomDepartment
        ? _customDepartmentCtrl.text.trim()
        : (_department ?? '').trim();
    return value.isEmpty ? null : value;
  }

  String? get _resolvedDesignation {
    final value = _isCustomDesignation
        ? _customDesignationCtrl.text.trim()
        : (_designation ?? '').trim();
    return value.isEmpty ? null : value;
  }

  void _setDepartmentFromValue(String? value) {
    final trimmed = (value ?? '').trim();
    _customDepartmentCtrl.clear();
    if (trimmed.isEmpty) {
      _department = null;
    } else if (_departments.contains(trimmed)) {
      _department = trimmed;
    } else {
      _department = _customDepartmentValue;
      _customDepartmentCtrl.text = trimmed;
    }
  }

  void _setDesignationFromValue(String? value) {
    final trimmed = (value ?? '').trim();
    _customDesignationCtrl.clear();
    if (trimmed.isEmpty) {
      _designation = null;
    } else if (_designations.contains(trimmed)) {
      _designation = trimmed;
    } else {
      _designation = _customDesignationValue;
      _customDesignationCtrl.text = trimmed;
    }
  }

  Widget _buildDepartmentInput() {
    return Column(
      children: [
        _DropdownInput<String>(
          value: _department,
          enabled: !_saving,
          hint: 'Select department',
          items: _departmentItems,
          labelBuilder: _departmentLabel,
          onChanged: (value) => setState(() => _department = value),
          validator: (value) => value == null ? 'Required' : null,
        ),
        if (_isCustomDepartment) ...[
          const SizedBox(height: 10),
          _TextInput(
            controller: _customDepartmentCtrl,
            hint: 'Enter custom department',
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            validator: (value) => _requiredCustomOption(value, 'Department'),
          ),
        ],
      ],
    );
  }

  Widget _buildDesignationInput() {
    return Column(
      children: [
        _DropdownInput<String>(
          value: _designation,
          enabled: !_saving,
          hint: 'Select designation',
          items: _designationItems,
          labelBuilder: _designationLabel,
          onChanged: (value) => setState(() => _designation = value),
          validator: (value) => value == null ? 'Required' : null,
        ),
        if (_isCustomDesignation) ...[
          const SizedBox(height: 10),
          _TextInput(
            controller: _customDesignationCtrl,
            hint: 'Enter custom designation',
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            validator: (value) => _requiredCustomOption(value, 'Designation'),
          ),
        ],
      ],
    );
  }

  static String _departmentLabel(String value) {
    return value == _customDepartmentValue ? 'Custom' : value;
  }

  static String _designationLabel(String value) {
    return value == _customDesignationValue ? 'Custom' : value;
  }

  static String? _requiredCustomOption(String? value, String label) {
    return value == null || value.trim().isEmpty ? '$label is required' : null;
  }

  List<String> get _roleOptions {
    final options = _isAdminOwner
        ? <String>['Teacher']
        : <String>['Teacher', 'Admin'];
    if (_accountRole.trim().isNotEmpty && !options.contains(_accountRole)) {
      options.add(_accountRole);
    }
    return options;
  }

  String _gradeNameById(String id) {
    for (final grade in widget.grades) {
      if (grade.id == id) return grade.gradeName;
    }
    return 'Class';
  }

  api.SectionModel? _sectionById(String id) {
    for (final section in widget.sections) {
      if (section.id == id) return section;
    }
    return null;
  }

  String _sectionNameById(String id) {
    final section = _sectionById(id);
    if (section == null) return 'Section';
    final grade = section.gradeName.trim().isNotEmpty
        ? section.gradeName.trim()
        : _gradeNameById(section.gradeId);
    final sectionName = section.sectionName.trim();
    return sectionName.isEmpty ? grade : '$grade - $sectionName';
  }

  String _subjectNameById(String id) {
    if (id.trim().isEmpty) return 'Class teacher only';
    for (final subject in widget.subjects) {
      if (_mapId(subject) == id) {
        return _mapLabel(subject, ['subject_name', 'name', 'title']);
      }
    }
    return 'Subject';
  }

  String _mapId(Map<String, dynamic> map) => '${map['id'] ?? ''}'.trim();

  String _mapLabel(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = '${map[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    return 'Unknown';
  }

  static String _employmentLabel(String type) {
    return type
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  static DateTime? _parseBackendDate(String value) {
    if (value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String? _displayGender(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized == 'male') return 'Male';
    if (normalized == 'female') return 'Female';
    return 'Other';
  }

  static String _absoluteImageUrl(String path) {
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

  static String _friendlyError(Object error) {
    return error.toString().replaceFirst('NotFoundException: ', '');
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
    if (text.isEmpty) return 'Full name is required';
    if (!RegExp(r"^[A-Za-z][A-Za-z .'-]{1,79}$").hasMatch(text)) {
      return 'Use letters, spaces, dots, hyphens, or apostrophes only';
    }
    return null;
  }

  static String? _requiredPhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Phone number is required';
    final normalized = text.replaceAll(RegExp(r'[\s()-]'), '');
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(normalized)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? _optionalEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Enter a valid email';
    }
    return null;
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_FieldLabel(label), child],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFE1F7FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1687A7)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2D5360),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentSelectionTile extends StatelessWidget {
  final _StaffDocumentInput document;
  final VoidCallback? onRemove;

  const _DocumentSelectionTile({
    required this.document,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 20,
            color: Color(0xFF647482),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              document.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E2A32),
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Remove document',
          ),
        ],
      ),
    );
  }
}

class _PhotoUploadButton extends StatelessWidget {
  final XFile? photoFile;
  final String imageUrl;

  const _PhotoUploadButton({required this.photoFile, this.imageUrl = ''});

  @override
  Widget build(BuildContext context) {
    final selected = photoFile != null || imageUrl.trim().isNotEmpty;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FA),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFBFCBD3), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoFile != null
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
          : selected
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.photo_camera_rounded,
                size: 38,
                color: Color(0xFF718392),
              ),
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
  final VoidCallback? onSuffixTap;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _TextInput({
    required this.controller,
    this.hint,
    this.enabled = true,
    this.readOnly = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.onTap,
    this.keyboardType,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
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
      keyboardType: keyboardType,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF4F7F9),
        suffixIcon: suffixIcon == null
            ? null
            : onSuffixTap == null
            ? Icon(suffixIcon, size: 17)
            : IconButton(
                onPressed: onSuffixTap,
                icon: Icon(suffixIcon, size: 17),
              ),
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
  final String hint;
  final List<T> items;
  final String Function(T value) labelBuilder;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final String? Function(T?)? validator;

  const _DropdownInput({
    required this.value,
    required this.hint,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      validator: validator,
      hint: Text(
        hint,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF687883),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
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

class _TeacherDetailPage extends StatelessWidget {
  final StaffModel staff;
  final String imageUrl;

  const _TeacherDetailPage({required this.staff, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF8FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEFF8FD),
        elevation: 0,
        title: const Text('Staff Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => Navigator.pop(context, value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit Staff')),
              PopupMenuItem(value: 'delete', child: Text('Remove Staff')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            _FormCard(
              title: staff.name,
              children: [
                Center(
                  child: _TeacherAvatar(
                    imageUrl: imageUrl,
                    initials: staff.avatarInitials,
                    size: 88,
                  ),
                ),
                const SizedBox(height: 18),
                _DetailRow(label: 'Department', value: staff.department),
                _DetailRow(label: 'Designation', value: staff.designation),
                _DetailRow(label: 'Employee ID', value: staff.employeeId),
                _DetailRow(
                  label: 'Login Username',
                  value: _detailValue(staff.loginUsername),
                ),
                _DetailRow(label: 'Role', value: staff.accountRole),
                _DetailRow(label: 'Status', value: staff.directoryStatusLabel),
                _DetailRow(
                  label: 'Employment Type',
                  value: _employmentLabel(staff.employmentType),
                ),
                _DetailRow(
                  label: 'Joining Date',
                  value: _dateLabel(staff.joinDate),
                ),
                _DetailRow(
                  label: 'Date of Birth',
                  value: _dateLabel(staff.dateOfBirth),
                ),
                _DetailRow(label: 'Gender', value: _detailValue(staff.gender)),
                _DetailRow(label: 'Phone', value: _detailValue(staff.phone)),
                _DetailRow(label: 'Email', value: _detailValue(staff.email)),
                _DetailRow(
                  label: 'Documents',
                  value: staff.documentCount == 0
                      ? 'No documents'
                      : '${staff.documentCount} uploaded',
                ),
                if (staff.documents.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DetailChipSection(
                    title: 'Uploaded Documents',
                    values: _documentLabels(staff.documents),
                    emptyText: 'No documents uploaded',
                  ),
                ],
                _DetailRow(
                  label: 'Attendance',
                  value: '${staff.attendancePercent.round()}%',
                ),
                _DetailRow(
                  label: 'Leave Balance',
                  value: '${staff.leaveBalance} days',
                ),
                const SizedBox(height: 10),
                _DetailChipSection(
                  title: 'Assigned Classes',
                  values: staff.assignedClasses,
                  emptyText: 'No classes assigned',
                ),
                const SizedBox(height: 10),
                _DetailChipSection(
                  title: 'Subjects',
                  values: staff.subjects,
                  emptyText: 'No subjects assigned',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _detailValue(String value) {
    final text = value.trim();
    return text.isEmpty ? 'Not available' : text;
  }

  static String _dateLabel(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Not available';
    return text.split('T').first;
  }

  static String _employmentLabel(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Not available';
    return text
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  static List<String> _documentLabels(List<Map<String, dynamic>> documents) {
    return documents
        .map((document) {
          final type = '${document['doc_type'] ?? 'document'}'.trim();
          final url = '${document['file_url'] ?? ''}'.trim();
          final parts = url
              .split('/')
              .where((part) => part.isNotEmpty)
              .toList();
          final filename = parts.isEmpty ? '' : parts.last;
          if (filename.isEmpty) return type;
          return '$type - $filename';
        })
        .where((label) => label.trim().isNotEmpty)
        .toList();
  }
}

class _DetailChipSection extends StatelessWidget {
  final String title;
  final List<String> values;
  final String emptyText;

  const _DetailChipSection({
    required this.title,
    required this.values,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final visibleValues = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(title),
        if (visibleValues.isEmpty)
          Text(
            emptyText,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleValues
                .map(
                  (value) => Chip(
                    label: Text(value, overflow: TextOverflow.ellipsis),
                    backgroundColor: AppTheme.primaryContainer.withAlpha(90),
                    side: BorderSide(color: AppTheme.primary.withAlpha(50)),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
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

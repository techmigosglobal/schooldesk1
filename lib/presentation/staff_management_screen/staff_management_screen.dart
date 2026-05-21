import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/env_config.dart';
import '../../core/utils/image_cropper_helper.dart';
import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart' as api;
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import 'staff_form_screen.dart';

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
    'password': password,
    'accountRole': accountRole,
  };
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

  List<StaffModel> _displayedStaff = [];
  List<String> _departmentOptions = const ['All'];
  List<String> _designationOptions = const ['All'];
  String _searchQuery = '';
  String _selectedDept = 'All';
  String _selectedDesignation = 'All';
  String _selectedStatus = 'All';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _loadError;
  int _currentPage = 0;

  bool get _isAdminOwner => widget.ownerRole.toLowerCase() == 'admin';

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

      final uiStaff = fetched.map(_mapApiStaffToUi).toList();
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

  StaffModel _mapApiStaffToUi(api.StaffModel staff) {
    final fullName = staff.fullName.trim().isEmpty
        ? 'Unknown Teacher'
        : staff.fullName.trim();
    final employeeId = staff.staffCode.trim().isEmpty
        ? staff.id.substring(0, staff.id.length < 8 ? staff.id.length : 8)
        : staff.staffCode.trim();
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
      assignedClasses: const ['N/A'],
      subjects: const [],
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
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      floatingActionButton: FloatingActionButton(
        heroTag: _isAdminOwner ? 'add-admin-teacher' : 'add-principal-teacher',
        onPressed: _openAddTeacherForm,
        backgroundColor: const Color(0xFF0887F2),
        foregroundColor: Colors.white,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
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
                      title: 'Unable to load teachers',
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
                      title: 'No teachers found',
                      description:
                          'Adjust your search or filters to find teachers.',
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
                          onTap: () => _openTeacherDetail(staff),
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
                  'All Teachers Directory',
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
            hint: 'Search teachers...',
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
                  label: 'All Teachers',
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
            _loadingMore ? 'Loading...' : 'Load more teachers',
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

  Future<void> _openAddTeacherForm() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _AddTeacherPhotoFormPage(onSubmit: _createTeacher),
      ),
    );
  }

  Future<void> _createTeacher(_AddTeacherInput input) async {
    final parts = input.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final firstName = parts.isEmpty ? input.fullName.trim() : parts.first;
    final lastName = parts.length > 1 ? parts.skip(1).join(' ') : '';

    final staff = await api.BackendApiClient.instance.createStaff(
      firstName: firstName,
      lastName: lastName,
      staffCode: input.employeeId,
      phone: input.contact,
      designation: input.designation,
      departmentId: input.department,
      accountRole: 'Teacher',
      gender: input.gender.toLowerCase(),
      joinDate: input.backendJoinDate,
      dateOfBirth: input.backendDateOfBirth,
      requestPrincipalApproval: false,
    );

    if ((input.photoPath ?? '').isNotEmpty) {
      await api.BackendApiClient.instance.uploadStaffPhoto(
        staffId: staff.id,
        filePath: input.photoPath!,
      );
    }

    await _loadStaffFromBackend();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${input.fullName.trim()} added')));
  }

  Future<void> _openTeacherDetail(StaffModel staff) async {
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
      await _openLegacyStaffForm(existingStaff: staff);
    } else if (action == 'delete') {
      await _deleteStaff(staff);
    }
  }

  Future<void> _openLegacyStaffForm({StaffModel? existingStaff}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.staffForm,
      arguments: StaffFormArgs(
        ownerRole: widget.ownerRole,
        existingStaff: existingStaff,
      ),
    );
    if (!mounted || result is! StaffFormResult) return;
    _showStaffMessage(
      result.created
          ? '${result.staffName} added'
          : '${result.staffName} updated',
      AppTheme.success,
    );
    await _loadStaffFromBackend();
  }

  Future<void> _deleteStaff(StaffModel staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Teacher',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w900),
        ),
        content: Text('Remove ${staff.name} from teacher records?'),
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
  final VoidCallback onTap;

  const _TeacherDirectoryCard({
    required this.staff,
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
              _TeacherStatusBadge(label: staff.directoryStatusLabel),
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

class _AddTeacherInput {
  final String fullName;
  final String backendDateOfBirth;
  final String gender;
  final String contact;
  final String department;
  final String designation;
  final String backendJoinDate;
  final String employeeId;
  final String? photoPath;

  const _AddTeacherInput({
    required this.fullName,
    required this.backendDateOfBirth,
    required this.gender,
    required this.contact,
    required this.department,
    required this.designation,
    required this.backendJoinDate,
    required this.employeeId,
    required this.photoPath,
  });
}

class _AddTeacherPhotoFormPage extends StatefulWidget {
  final Future<void> Function(_AddTeacherInput input) onSubmit;

  const _AddTeacherPhotoFormPage({required this.onSubmit});

  @override
  State<_AddTeacherPhotoFormPage> createState() =>
      _AddTeacherPhotoFormPageState();
}

class _AddTeacherPhotoFormPageState extends State<_AddTeacherPhotoFormPage> {
  static const Color _background = Color(0xFFEFF8FD);
  static const List<String> _departments = [
    'Mathematics',
    'Science',
    'English',
    'History',
    'Computer Science',
    'Physical Education',
    'Arts',
    'Administration',
  ];
  static const List<String> _designations = [
    'Teacher',
    'Senior Teacher',
    'Class Teacher',
    'HOD',
    'Coordinator',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  late final TextEditingController _dobCtrl;
  late final TextEditingController _joiningCtrl;
  late final TextEditingController _employeeCtrl;
  final ImagePicker _picker = ImagePicker();

  DateTime? _dob;
  DateTime? _joiningDate;
  String? _gender;
  String? _department;
  String? _designation;
  XFile? _photoFile;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dobCtrl = TextEditingController();
    _joiningCtrl = TextEditingController();
    _employeeCtrl = TextEditingController(text: _generateEmployeeId());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactCtrl.dispose();
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
      title: 'Crop Teacher Photo',
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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null || _joiningDate == null) {
      setState(() => _error = 'Date of birth and joining date are required');
      return;
    }
    if (_employeeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Employee ID is required');
      return;
    }
    if (_joiningDate!.isBefore(_dob!)) {
      setState(() => _error = 'Joining date cannot be before date of birth');
      return;
    }
    if (_joiningDate!.difference(_dob!).inDays < 18 * 365) {
      setState(() => _error = 'Teacher must be at least 18 years old');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        _AddTeacherInput(
          fullName: _nameCtrl.text.trim(),
          backendDateOfBirth: _backendDate(_dob!),
          gender: _gender!,
          contact: _contactCtrl.text.trim(),
          department: _department!,
          designation: _designation!,
          backendJoinDate: _backendDate(_joiningDate!),
          employeeId: _employeeCtrl.text.trim(),
          photoPath: _photoFile?.path,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Add teacher failed: $error';
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
                    _FormCard(
                      title: 'Personal Details',
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
                        _FieldLabel('Full Name'),
                        _TextInput(
                          controller: _nameCtrl,
                          hint: 'Enter Full Name',
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
                                  hint: 'Select Date',
                                  enabled: !_saving,
                                  readOnly: true,
                                  suffixIcon: Icons.calendar_today_outlined,
                                  onTap: _saving
                                      ? null
                                      : () => _pickDate(joining: false),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Required'
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
                                  hint: 'Select Gender',
                                  items: const ['Female', 'Male', 'Other'],
                                  labelBuilder: (value) => value,
                                  onChanged: (value) =>
                                      setState(() => _gender = value),
                                  validator: (value) =>
                                      value == null ? 'Required' : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _FieldLabel('Contact'),
                        _TextInput(
                          controller: _contactCtrl,
                          hint: 'Enter Contact Number',
                          enabled: !_saving,
                          keyboardType: TextInputType.phone,
                          validator: _requiredPhone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FormCard(
                      title: 'Professional Information',
                      children: [
                        _ResponsiveFieldRow(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Department'),
                                _DropdownInput<String>(
                                  value: _department,
                                  enabled: !_saving,
                                  hint: 'Select Departm.',
                                  items: _departments,
                                  labelBuilder: (value) => value,
                                  onChanged: (value) =>
                                      setState(() => _department = value),
                                  validator: (value) =>
                                      value == null ? 'Required' : null,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Designation'),
                                _DropdownInput<String>(
                                  value: _designation,
                                  enabled: !_saving,
                                  hint: 'Select Designati',
                                  items: _designations,
                                  labelBuilder: (value) => value,
                                  onChanged: (value) =>
                                      setState(() => _designation = value),
                                  validator: (value) =>
                                      value == null ? 'Required' : null,
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
                                _FieldLabel('Date of Joining'),
                                _TextInput(
                                  controller: _joiningCtrl,
                                  hint: 'Select Date',
                                  enabled: !_saving,
                                  readOnly: true,
                                  suffixIcon: Icons.calendar_today_outlined,
                                  onTap: _saving
                                      ? null
                                      : () => _pickDate(joining: true),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Employee ID'),
                                _TextInput(
                                  controller: _employeeCtrl,
                                  enabled: false,
                                  suffixIcon: Icons.lock_outline_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
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
                'Add Teacher with Photo Upload',
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
              'Add Teacher',
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
      _nameCtrl.clear();
      _contactCtrl.clear();
      _dob = null;
      _joiningDate = null;
      _dobCtrl.clear();
      _joiningCtrl.clear();
      _gender = null;
      _department = null;
      _designation = null;
      _photoFile = null;
      _employeeCtrl.text = _generateEmployeeId();
      _error = null;
    });
  }

  static String _generateEmployeeId() {
    final suffix =
        DateTime.now().millisecondsSinceEpoch.remainder(90000) + 10000;
    return 'TCH-$suffix';
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
    final parts = text.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.length < 2) return 'Enter first and last name';
    if (!RegExp(r"^[A-Za-z][A-Za-z .'-]{1,79}$").hasMatch(text)) {
      return 'Use letters, spaces, dots, hyphens, or apostrophes only';
    }
    return null;
  }

  static String? _requiredPhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Contact number is required';
    final normalized = text.replaceAll(RegExp(r'[\s()-]'), '');
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(normalized)) {
      return 'Enter a valid contact number';
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
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _TextInput({
    required this.controller,
    this.hint,
    this.enabled = true,
    this.readOnly = false,
    this.suffixIcon,
    this.onTap,
    this.keyboardType,
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
        title: const Text('Teacher Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => Navigator.pop(context, value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit Teacher')),
              PopupMenuItem(value: 'delete', child: Text('Remove Teacher')),
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
                _DetailRow(label: 'Status', value: staff.directoryStatusLabel),
                _DetailRow(
                  label: 'Joining Date',
                  value: staff.joinDate.isEmpty
                      ? 'Not available'
                      : staff.joinDate,
                ),
                _DetailRow(
                  label: 'Contact',
                  value: staff.phone.isEmpty ? 'Not available' : staff.phone,
                ),
              ],
            ),
          ],
        ),
      ),
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

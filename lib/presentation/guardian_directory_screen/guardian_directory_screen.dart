import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/env_config.dart';
import '../../core/utils/image_cropper_helper.dart';
import '../../services/backend_api_client.dart' as api;
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/empty_state_widget.dart';

class GuardianDirectoryScreen extends StatefulWidget {
  final String ownerRole;

  const GuardianDirectoryScreen({super.key, this.ownerRole = 'principal'});

  @override
  State<GuardianDirectoryScreen> createState() =>
      _GuardianDirectoryScreenState();
}

class _GuardianDirectoryScreenState extends State<GuardianDirectoryScreen> {
  static const Color _background = Color(0xFFEFF8FD);
  static const int _pageSize = 20;

  final _scrollController = ScrollController();
  final List<GuardianDirectoryEntry> _allGuardians = [];
  final List<GuardianDirectoryEntry> _filteredGuardians = [];
  final Set<String> _selectedGuardianIds = <String>{};
  List<GuardianDirectoryEntry> _displayedGuardians = [];
  List<api.StudentModel> _students = const [];
  List<Map<String, dynamic>> _guardianRows = const [];
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedRelationship = 'All';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _loadError;
  int _currentPage = 0;

  bool get _isAdminOwner => widget.ownerRole.toLowerCase() == 'admin';
  bool get _selectionMode => _selectedGuardianIds.isNotEmpty;

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
      _loadMoreGuardians();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final parents = await _loadParentAccounts();
      final students = await _loadStudents();
      final guardianRows = await _loadGuardianRows();
      final entries = <GuardianDirectoryEntry>[];

      for (final parent in parents) {
        final linkedRows = await _safeParentStudents(parent.id);
        final linkedStudents = _mapLinkedStudents(linkedRows, students);
        entries.add(
          _mapParentToEntry(
            parent,
            linkedStudents: linkedStudents,
            guardianRows: guardianRows,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _students = students;
        _guardianRows = guardianRows;
        _allGuardians
          ..clear()
          ..addAll(entries);
        _filteredGuardians
          ..clear()
          ..addAll(entries);
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
    final parents = <api.UserAccountModel>[];
    var page = 1;
    while (true) {
      final response = await api.BackendApiClient.instance.getUsers(
        role: 'Parent',
        page: page,
        pageSize: 100,
      );
      parents.addAll(response.data);
      if (!response.hasMore || response.data.isEmpty) break;
      page++;
    }
    return parents;
  }

  Future<List<api.StudentModel>> _loadStudents() async {
    final students = <api.StudentModel>[];
    var page = 1;
    while (true) {
      final response = await api.BackendApiClient.instance.getStudents(
        page: page,
        pageSize: 100,
      );
      students.addAll(response.data);
      if (!response.hasMore || response.data.isEmpty) break;
      page++;
    }
    return students;
  }

  Future<List<Map<String, dynamic>>> _loadGuardianRows() async {
    try {
      return await api.BackendApiClient.instance.getRawList(
        '/guardians',
        queryParameters: const {'page_size': 500},
      );
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _safeParentStudents(
    String parentUserId,
  ) async {
    try {
      return await api.BackendApiClient.instance.getParentStudents(
        parentUserId: parentUserId,
      );
    } catch (_) {
      return const [];
    }
  }

  List<GuardianStudentLink> _mapLinkedStudents(
    List<Map<String, dynamic>> rows,
    List<api.StudentModel> students,
  ) {
    final byAdmission = <String, api.StudentModel>{};
    for (final student in students) {
      final admission = student.admissionNumber.toLowerCase().trim();
      final code = student.studentCode.toLowerCase().trim();
      if (admission.isNotEmpty) byAdmission[admission] = student;
      if (code.isNotEmpty) byAdmission[code] = student;
    }
    final byId = {
      for (final student in students) student.id.toLowerCase().trim(): student,
    };
    return rows.map((row) {
      final id = _stringValue(row['student_id']);
      final admission = _stringValue(row['student_admission_number']);
      final student =
          byId[id.toLowerCase()] ?? byAdmission[admission.toLowerCase()];
      return GuardianStudentLink(
        studentId: student?.id ?? id,
        admissionNumber: _studentLookupCode(student) ?? admission,
        studentName: student?.fullName.trim().isNotEmpty == true
            ? student!.fullName.trim()
            : '${row['student_first_name'] ?? ''} ${row['student_last_name'] ?? ''}'
                  .trim(),
      );
    }).toList();
  }

  String? _studentLookupCode(api.StudentModel? student) {
    if (student == null) return null;
    final admission = student.admissionNumber.trim();
    if (admission.isNotEmpty) return admission;
    final code = student.studentCode.trim();
    if (code.isNotEmpty) return code;
    return student.id;
  }

  GuardianDirectoryEntry _mapParentToEntry(
    api.UserAccountModel parent, {
    required List<GuardianStudentLink> linkedStudents,
    required List<Map<String, dynamic>> guardianRows,
  }) {
    final name = parent.name.trim().isNotEmpty
        ? parent.name.trim()
        : (parent.username.trim().isNotEmpty
              ? parent.username.trim()
              : 'Parent');
    final metadata = _guardianMetadataFor(
      parent,
      linkedStudents: linkedStudents,
      guardianRows: guardianRows,
    );
    return GuardianDirectoryEntry(
      id: parent.id,
      name: name,
      username: parent.username,
      email: parent.email,
      phone: parent.phone,
      photoUrl: _mediaUrl(parent.avatar),
      relationship: metadata.relationship,
      occupation: metadata.occupation,
      annualIncome: metadata.annualIncome,
      canPickup: metadata.canPickup,
      isPrimary: metadata.isPrimary,
      isActive: parent.isActive,
      isVerified: parent.isVerified,
      linkedStudents: linkedStudents,
      initials: _initials(name),
    );
  }

  String _mediaUrl(String value) {
    final path = value.trim();
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '${EnvConfig.apiOrigin}$path';
    return path;
  }

  _GuardianMetadata _guardianMetadataFor(
    api.UserAccountModel parent, {
    required List<GuardianStudentLink> linkedStudents,
    required List<Map<String, dynamic>> guardianRows,
  }) {
    final parentEmail = parent.email.toLowerCase().trim();
    final parentPhone = parent.phone.trim();
    final parentName = parent.name.toLowerCase().trim();
    for (final link in linkedStudents) {
      for (final row in guardianRows) {
        if (_stringValue(row['student_id']) != link.studentId) continue;
        final emailMatches =
            parentEmail.isNotEmpty &&
            _stringValue(row['email']).toLowerCase() == parentEmail;
        final phoneMatches =
            parentPhone.isNotEmpty && _stringValue(row['phone']) == parentPhone;
        final nameMatches =
            parentName.isNotEmpty &&
            _stringValue(row['full_name']).toLowerCase() == parentName;
        if (!emailMatches && !phoneMatches && !nameMatches) continue;
        return _GuardianMetadata(
          relationship: _stringValue(row['relationship']).isEmpty
              ? 'Parent/Guardian'
              : _stringValue(row['relationship']),
          occupation: _stringValue(row['occupation']),
          annualIncome: double.tryParse('${row['annual_income'] ?? ''}') ?? 0,
          canPickup: row['can_pickup'] == true,
          isPrimary: row['is_primary'] == true,
        );
      }
    }
    return const _GuardianMetadata(
      relationship: 'Parent/Guardian',
      occupation: '',
      annualIncome: 0,
      canPickup: false,
      isPrimary: false,
    );
  }

  void _applyFilters({bool resetState = true}) {
    final query = _searchQuery.toLowerCase().trim();
    final next = _allGuardians.where((guardian) {
      final childText = guardian.linkedStudents
          .map((student) => '${student.studentName} ${student.admissionNumber}')
          .join(' ')
          .toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          guardian.name.toLowerCase().contains(query) ||
          guardian.username.toLowerCase().contains(query) ||
          guardian.phone.toLowerCase().contains(query) ||
          guardian.email.toLowerCase().contains(query) ||
          childText.contains(query);
      final matchesStatus =
          _selectedStatus == 'All' || guardian.statusLabel == _selectedStatus;
      final matchesRelationship =
          _selectedRelationship == 'All' ||
          guardian.relationship == _selectedRelationship;
      return matchesSearch && matchesStatus && matchesRelationship;
    }).toList();

    void apply() {
      _filteredGuardians
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
    _hasMore = _filteredGuardians.length > _pageSize;
    _displayedGuardians = _filteredGuardians.take(_pageSize).toList();
  }

  void _loadMoreGuardians() {
    if (_loadingMore || !_hasMore) return;
    final start = (_currentPage + 1) * _pageSize;
    if (start >= _filteredGuardians.length) {
      setState(() => _hasMore = false);
      return;
    }
    setState(() {
      _loadingMore = true;
      final end = (start + _pageSize).clamp(0, _filteredGuardians.length);
      _displayedGuardians.addAll(_filteredGuardians.sublist(start, end));
      _currentPage++;
      _loadingMore = false;
      _hasMore = end < _filteredGuardians.length;
    });
  }

  void _toggleGuardianSelection(GuardianDirectoryEntry guardian) {
    setState(() {
      if (_selectedGuardianIds.contains(guardian.id)) {
        _selectedGuardianIds.remove(guardian.id);
      } else {
        _selectedGuardianIds.add(guardian.id);
      }
    });
  }

  void _clearGuardianSelection() {
    setState(_selectedGuardianIds.clear);
  }

  void _selectAllDisplayedGuardians() {
    setState(() {
      _selectedGuardianIds
        ..clear()
        ..addAll(_displayedGuardians.map((guardian) => guardian.id));
    });
  }

  Future<void> _deleteSelectedGuardians() async {
    final selected = _allGuardians
        .where((guardian) => _selectedGuardianIds.contains(guardian.id))
        .toList();
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Remove selected guardians',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Permanently remove ${selected.length} selected guardian${selected.length == 1 ? '' : 's'}, their parent login, linked student assignments, and guardian profile rows?',
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
    for (final guardian in selected) {
      try {
        await _deleteGuardianRecord(guardian);
        removed++;
      } catch (_) {
        failures.add(guardian.name);
      }
    }
    if (!mounted) return;
    _selectedGuardianIds.clear();
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failures.isEmpty
              ? '$removed guardian${removed == 1 ? '' : 's'} removed'
              : '$removed removed, ${failures.length} failed',
        ),
        backgroundColor: failures.isEmpty ? AppTheme.success : AppTheme.warning,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-parent-guardian',
        onPressed: () => _openGuardianForm(),
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
          onRefresh: _loadData,
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
                      title: 'Unable to load guardians',
                      description: _loadError!,
                      actionLabel: 'Retry',
                      onAction: _loadData,
                    ),
                  ),
                )
              else if (_filteredGuardians.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.family_restroom_rounded,
                      title: 'No parents or guardians found',
                      description:
                          'Adjust your search or filters to find guardians.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 96),
                  sliver: SliverList.builder(
                    itemCount: _displayedGuardians.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _displayedGuardians.length) {
                        return _buildLoadMoreButton();
                      }
                      final guardian = _displayedGuardians[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: _GuardianDirectoryCard(
                          guardian: guardian,
                          selected: _selectedGuardianIds.contains(guardian.id),
                          onTap: () => _selectionMode
                              ? _toggleGuardianSelection(guardian)
                              : _openGuardianDetail(guardian),
                          onLongPress: () => _toggleGuardianSelection(guardian),
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
                onPressed: _clearGuardianSelection,
                icon: const Icon(Icons.close_rounded, size: 22),
                tooltip: 'Clear selection',
              ),
              Expanded(
                child: Text(
                  '${_selectedGuardianIds.length} selected',
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
                onPressed: _selectAllDisplayedGuardians,
                icon: const Icon(Icons.select_all_rounded, size: 22),
                tooltip: 'Select visible',
              ),
              IconButton(
                onPressed: _deleteSelectedGuardians,
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
                  'All Parents & Guardians Directory',
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
    final relationships =
        _allGuardians
            .map((entry) => entry.relationship)
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final chipRowHeight = (34.0 * textScale).clamp(38.0, 56.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
      child: Column(
        children: [
          _SearchBox(
            hint: 'Search parents, guardians, or students...',
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
                  label: 'All Guardians',
                  selected:
                      _selectedStatus == 'All' &&
                      _selectedRelationship == 'All',
                  onTap: () {
                    _selectedStatus = 'All';
                    _selectedRelationship = 'All';
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _DirectoryChip(
                  label: _selectedRelationship == 'All'
                      ? 'Relationship'
                      : _selectedRelationship,
                  selected: _selectedRelationship != 'All',
                  onTap: () => _chooseFilter(
                    title: 'Relationship',
                    options: ['All', ...relationships],
                    selected: _selectedRelationship,
                    onSelected: (value) {
                      _selectedRelationship = value;
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
                    options: const ['All', 'Active', 'Inactive'],
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
          onPressed: _loadMoreGuardians,
          child: Text(
            _loadingMore ? 'Loading...' : 'Load more guardians',
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

  Future<void> _openGuardianForm([GuardianDirectoryEntry? guardian]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _GuardianProfileFormPage(
          ownerRole: widget.ownerRole,
          initialGuardian: guardian,
          students: _students,
          onSubmit: _saveGuardian,
        ),
      ),
    );
  }

  Future<void> _saveGuardian(_GuardianProfileInput input) async {
    final client = api.BackendApiClient.instance;
    final bool isEdit = input.guardianId != null;
    late api.UserAccountModel parent;

    if (isEdit) {
      parent = await client.updateUser(
        input.guardianId!,
        username: input.username,
        password: input.password.trim().isEmpty ? null : input.password.trim(),
        role: 'Parent',
        fullName: input.fullName,
        email: input.email,
        phone: input.phone,
        isActive: input.isActive,
      );
    } else {
      parent = await client.createUser(
        username: input.username,
        password: input.password,
        role: 'Parent',
        fullName: input.fullName,
        email: input.email,
        phone: input.phone,
        isActive: input.isActive,
        requestPrincipalApproval: _isAdminOwner,
      );
    }

    if ((input.photoPath ?? '').isNotEmpty) {
      await client.uploadUserAvatar(
        userId: parent.id,
        filePath: input.photoPath!,
      );
    }

    await client.assignParentStudents(
      parentUserId: parent.id,
      studentIds: input.linkedStudents
          .map((student) => student.studentId)
          .toList(),
      admissionNumbers: input.linkedStudents
          .map((student) => student.admissionNumber)
          .toList(),
    );

    await _syncGuardianRows(input);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEdit ? 'Guardian updated' : 'Guardian added'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _syncGuardianRows(_GuardianProfileInput input) async {
    final payloadBase = {
      'full_name': input.fullName,
      'relationship': input.relationship,
      'phone': input.phone,
      'email': input.email,
      'occupation': input.occupation,
      'annual_income': input.annualIncome,
      'can_pickup': input.canPickup,
    };
    GuardianDirectoryEntry? existingEntry;
    if (input.guardianId != null) {
      for (final guardian in _allGuardians) {
        if (guardian.id == input.guardianId) {
          existingEntry = guardian;
          break;
        }
      }
    }
    final nextStudentIds = input.linkedStudents
        .map((student) => student.studentId)
        .where((id) => id.trim().isNotEmpty)
        .toSet();

    if (existingEntry != null) {
      for (final row in _guardianRowsForEntry(existingEntry)) {
        final rowStudentId = _stringValue(row['student_id']);
        final rowId = _stringValue(row['id']);
        if (rowId.isEmpty || nextStudentIds.contains(rowStudentId)) continue;
        await api.BackendApiClient.instance.deleteRaw('/guardians/$rowId');
      }
    }

    for (var i = 0; i < input.linkedStudents.length; i++) {
      final student = input.linkedStudents[i];
      final existing = _findGuardianRowFor(
        student.studentId,
        name: input.fullName,
        phone: input.phone,
        email: input.email,
      );
      final payload = {
        ...payloadBase,
        'student_id': student.studentId,
        'is_primary': i == 0 || input.isPrimary,
      };
      if (existing == null) {
        await api.BackendApiClient.instance.createRaw('/guardians', payload);
      } else {
        await api.BackendApiClient.instance.updateRaw(
          '/guardians/${existing['id']}',
          payload,
        );
      }
    }
  }

  List<Map<String, dynamic>> _guardianRowsForEntry(
    GuardianDirectoryEntry guardian,
  ) {
    final rows = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    for (final student in guardian.linkedStudents) {
      final row = _findGuardianRowFor(
        student.studentId,
        name: guardian.name,
        phone: guardian.phone,
        email: guardian.email,
      );
      final rowId = _stringValue(row?['id']);
      if (row == null || rowId.isEmpty || seenIds.contains(rowId)) continue;
      seenIds.add(rowId);
      rows.add(row);
    }
    return rows;
  }

  Future<void> _deleteGuardianRowsFor(GuardianDirectoryEntry guardian) async {
    for (final row in _guardianRowsForEntry(guardian)) {
      final rowId = _stringValue(row['id']);
      if (rowId.isEmpty) continue;
      await api.BackendApiClient.instance.deleteRaw('/guardians/$rowId');
    }
  }

  Map<String, dynamic>? _findGuardianRowFor(
    String studentId, {
    required String name,
    required String phone,
    required String email,
  }) {
    final cleanName = name.toLowerCase().trim();
    final cleanEmail = email.toLowerCase().trim();
    final cleanPhone = phone.trim();
    for (final row in _guardianRows) {
      if (_stringValue(row['student_id']) != studentId) continue;
      final nameMatches =
          cleanName.isNotEmpty &&
          _stringValue(row['full_name']).toLowerCase() == cleanName;
      final emailMatches =
          cleanEmail.isNotEmpty &&
          _stringValue(row['email']).toLowerCase() == cleanEmail;
      final phoneMatches =
          cleanPhone.isNotEmpty && _stringValue(row['phone']) == cleanPhone;
      if (nameMatches || emailMatches || phoneMatches) return row;
    }
    return null;
  }

  Future<void> _openGuardianDetail(GuardianDirectoryEntry guardian) async {
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _GuardianDetailPage(guardian: guardian),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _openGuardianForm(guardian);
    } else if (action == 'toggle') {
      await _setGuardianActive(guardian, !guardian.isActive);
    } else if (action == 'delete') {
      await _deleteGuardian(guardian);
    }
  }

  Future<void> _setGuardianActive(
    GuardianDirectoryEntry guardian,
    bool active,
  ) async {
    try {
      await api.BackendApiClient.instance.updateUser(
        guardian.id,
        isActive: active,
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(active ? 'Guardian activated' : 'Guardian deactivated'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    }
  }

  Future<void> _deleteGuardian(GuardianDirectoryEntry guardian) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Guardian',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Permanently remove ${guardian.name}, their parent login, linked student assignments, and guardian profile rows?',
        ),
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
      await _deleteGuardianRecord(guardian);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian permanently removed'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    }
  }

  Future<void> _deleteGuardianRecord(GuardianDirectoryEntry guardian) async {
    final client = api.BackendApiClient.instance;
    await _deleteGuardianRowsFor(guardian);
    await client.deleteUser(guardian.id);
    await client.deleteUser(guardian.id, permanent: true);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  static String _initials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'PG';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String _stringValue(dynamic value) => (value ?? '').toString().trim();
}

class GuardianDirectoryEntry {
  final String id;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String photoUrl;
  final String relationship;
  final String occupation;
  final double annualIncome;
  final bool canPickup;
  final bool isPrimary;
  final bool isActive;
  final bool isVerified;
  final List<GuardianStudentLink> linkedStudents;
  final String initials;

  const GuardianDirectoryEntry({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.relationship,
    required this.occupation,
    required this.annualIncome,
    required this.canPickup,
    required this.isPrimary,
    required this.isActive,
    required this.isVerified,
    required this.linkedStudents,
    required this.initials,
  });

  String get statusLabel => isActive ? 'Active' : 'Inactive';

  String get childSummary {
    if (linkedStudents.isEmpty) return 'No child linked';
    if (linkedStudents.length == 1) return linkedStudents.first.studentName;
    return '${linkedStudents.length} children linked';
  }
}

class GuardianStudentLink {
  final String studentId;
  final String admissionNumber;
  final String studentName;

  const GuardianStudentLink({
    required this.studentId,
    required this.admissionNumber,
    required this.studentName,
  });
}

class _GuardianMetadata {
  final String relationship;
  final String occupation;
  final double annualIncome;
  final bool canPickup;
  final bool isPrimary;

  const _GuardianMetadata({
    required this.relationship,
    required this.occupation,
    required this.annualIncome,
    required this.canPickup,
    required this.isPrimary,
  });
}

class _GuardianProfileInput {
  final String? guardianId;
  final String? photoPath;
  final String fullName;
  final String username;
  final String password;
  final String phone;
  final String email;
  final String relationship;
  final String occupation;
  final double annualIncome;
  final bool canPickup;
  final bool isPrimary;
  final bool isActive;
  final List<GuardianStudentLink> linkedStudents;

  const _GuardianProfileInput({
    required this.guardianId,
    required this.photoPath,
    required this.fullName,
    required this.username,
    required this.password,
    required this.phone,
    required this.email,
    required this.relationship,
    required this.occupation,
    required this.annualIncome,
    required this.canPickup,
    required this.isPrimary,
    required this.isActive,
    required this.linkedStudents,
  });
}

class _GuardianDirectoryCard extends StatelessWidget {
  final GuardianDirectoryEntry guardian;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GuardianDirectoryCard({
    required this.guardian,
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
              _GuardianAvatar(
                initials: guardian.initials,
                size: 58,
                imageUrl: guardian.photoUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      guardian.name,
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
                      '${guardian.relationship} - ${guardian.childSummary}',
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
                  : _StatusBadge(label: guardian.statusLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuardianAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final File? imageFile;
  final String imageUrl;

  const _GuardianAvatar({
    required this.initials,
    required this.size,
    this.imageFile,
    this.imageUrl = '',
  });

  @override
  Widget build(BuildContext context) {
    final remoteUrl = imageUrl.trim();
    final imageProvider = imageFile != null
        ? FileImage(imageFile!) as ImageProvider
        : remoteUrl.isNotEmpty
        ? NetworkImage(remoteUrl)
        : null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
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
      child: ClipOval(
        child: imageProvider == null
            ? _initialsFallback()
            : Image(
                image: imageProvider,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initialsFallback(),
              ),
      ),
    );
  }

  Widget _initialsFallback() {
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
    final colors = label == 'Inactive'
        ? (const Color(0xFFFFECEC), const Color(0xFFBA4242))
        : (const Color(0xFFDFF8E7), const Color(0xFF2F9E5B));
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

class _GuardianProfileFormPage extends StatefulWidget {
  final String ownerRole;
  final GuardianDirectoryEntry? initialGuardian;
  final List<api.StudentModel> students;
  final Future<void> Function(_GuardianProfileInput input) onSubmit;

  const _GuardianProfileFormPage({
    required this.ownerRole,
    required this.initialGuardian,
    required this.students,
    required this.onSubmit,
  });

  @override
  State<_GuardianProfileFormPage> createState() =>
      _GuardianProfileFormPageState();
}

class _GuardianProfileFormPageState extends State<_GuardianProfileFormPage> {
  static const Color _background = Color(0xFFEFF8FD);
  static const List<String> _relationships = [
    'Father',
    'Mother',
    'Guardian',
    'Grandparent',
    'Uncle',
    'Aunt',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();
  final _admissionCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _relationship = 'Parent/Guardian';
  String? _selectedStudentId;
  XFile? _photoFile;
  String _existingPhotoUrl = '';
  bool _passwordVisible = false;
  bool _resetPassword = false;
  bool _isActive = true;
  bool _canPickup = true;
  bool _isPrimary = true;
  bool _saving = false;
  String? _error;
  late List<GuardianStudentLink> _linkedStudents;

  bool get _isEdit => widget.initialGuardian != null;

  @override
  void initState() {
    super.initState();
    final guardian = widget.initialGuardian;
    _linkedStudents = List<GuardianStudentLink>.from(
      guardian?.linkedStudents ?? const [],
    );
    if (guardian != null) {
      _nameCtrl.text = guardian.name;
      _usernameCtrl.text = guardian.username;
      _phoneCtrl.text = guardian.phone;
      _emailCtrl.text = guardian.email;
      _occupationCtrl.text = guardian.occupation;
      _existingPhotoUrl = guardian.photoUrl;
      _incomeCtrl.text = guardian.annualIncome == 0
          ? ''
          : guardian.annualIncome.toStringAsFixed(0);
      _relationship = guardian.relationship;
      _isActive = guardian.isActive;
      _canPickup = guardian.canPickup;
      _isPrimary = guardian.isPrimary || guardian.linkedStudents.length == 1;
    } else {
      _usernameCtrl.text =
          'parent${DateTime.now().millisecondsSinceEpoch.remainder(90000)}';
      _passwordCtrl.text =
          'Parent@${DateTime.now().millisecondsSinceEpoch.remainder(9000) + 1000}';
    }
    _admissionCtrl.addListener(_onAdmissionChanged);
  }

  @override
  void dispose() {
    _admissionCtrl.removeListener(_onAdmissionChanged);
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _occupationCtrl.dispose();
    _incomeCtrl.dispose();
    _admissionCtrl.dispose();
    super.dispose();
  }

  void _onAdmissionChanged() {
    if (mounted) setState(() {});
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
      title: 'Crop Guardian Photo',
    );
    if (croppedPath == null || !mounted) return;
    setState(() => _photoFile = XFile(croppedPath));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_linkedStudents.isEmpty) {
      setState(() => _error = 'Assign at least one student');
      return;
    }
    if (!_isEdit && _passwordCtrl.text.trim().length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_isEdit && _resetPassword && _passwordCtrl.text.trim().length < 6) {
      setState(() => _error = 'New password must be at least 6 characters');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        _GuardianProfileInput(
          guardianId: widget.initialGuardian?.id,
          photoPath: _photoFile?.path,
          fullName: _nameCtrl.text.trim(),
          username: _usernameCtrl.text.trim(),
          password: _isEdit && !_resetPassword ? '' : _passwordCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          relationship: _relationship,
          occupation: _occupationCtrl.text.trim(),
          annualIncome: double.tryParse(_incomeCtrl.text.trim()) ?? 0,
          canPickup: _canPickup,
          isPrimary: _isPrimary,
          isActive: _isActive,
          linkedStudents: List<GuardianStudentLink>.from(_linkedStudents),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            '${_isEdit ? 'Update' : 'Add'} guardian failed: ${error.toString()}';
      });
    }
  }

  void _addSelectedStudent() {
    final selectedId = _selectedStudentId;
    if (selectedId == null) return;
    final student = widget.students.firstWhere((item) => item.id == selectedId);
    _addStudentLink(student);
  }

  void _addAdmissionStudent() {
    final admission = _admissionCtrl.text.trim().toLowerCase();
    if (admission.isEmpty) return;
    api.StudentModel? match;
    for (final student in widget.students) {
      final admissionNumber = student.admissionNumber.toLowerCase().trim();
      final studentCode = student.studentCode.toLowerCase().trim();
      if (admissionNumber == admission || studentCode == admission) {
        match = student;
        break;
      }
    }
    if (match == null) {
      setState(() => _error = 'Admission number not found');
      return;
    }
    _addStudentLink(match);
    _admissionCtrl.clear();
  }

  void _addStudentLink(api.StudentModel student) {
    if (_linkedStudents.any((item) => item.studentId == student.id)) {
      setState(() => _error = 'Student already assigned');
      return;
    }
    setState(() {
      _error = null;
      _selectedStudentId = null;
      _linkedStudents.add(
        GuardianStudentLink(
          studentId: student.id,
          admissionNumber: _studentLookupCode(student),
          studentName: student.fullName.trim(),
        ),
      );
    });
  }

  String _studentLookupCode(api.StudentModel student) {
    final admission = student.admissionNumber.trim();
    if (admission.isNotEmpty) return admission;
    final code = student.studentCode.trim();
    if (code.isNotEmpty) return code;
    return student.id;
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
                    _personalCard(),
                    const SizedBox(height: 14),
                    _loginCard(),
                    const SizedBox(height: 14),
                    _studentCard(),
                    const SizedBox(height: 14),
                    _InlineNotice(
                      icon: Icons.verified_rounded,
                      text:
                          'Guardian profile, parent login, and linked students will sync with the central academic server on submission.',
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

  Widget _personalCard() {
    final relationshipItems = {
      ..._relationships,
      if (_relationship.trim().isNotEmpty) _relationship,
    }.toList();
    return _FormCard(
      title: 'Guardian Details',
      children: [
        Center(
          child: InkWell(
            onTap: _saving ? null : _pickPhoto,
            borderRadius: BorderRadius.circular(54),
            child: Column(
              children: [
                _GuardianAvatar(
                  initials: _initialsPreview,
                  size: 86,
                  imageFile: _photoFile == null ? null : File(_photoFile!.path),
                  imageUrl: _photoFile == null ? _existingPhotoUrl : '',
                ),
                const SizedBox(height: 8),
                Text(
                  _existingPhotoUrl.isEmpty && _photoFile == null
                      ? 'Upload Photo'
                      : 'Change Photo',
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
              label: 'Relationship',
              child: _DropdownInput<String>(
                value: _relationship,
                enabled: !_saving,
                hint: 'Select relationship',
                items: relationshipItems,
                labelBuilder: (value) => value,
                onChanged: (value) =>
                    setState(() => _relationship = value ?? 'Guardian'),
              ),
            ),
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
          ],
        ),
        const SizedBox(height: 12),
        _FieldLabel('Email'),
        _TextInput(
          controller: _emailCtrl,
          hint: 'guardian@example.com',
          enabled: !_saving,
          keyboardType: TextInputType.emailAddress,
          validator: _optionalEmail,
        ),
        const SizedBox(height: 12),
        _ResponsiveFieldRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(
              label: 'Occupation',
              child: _TextInput(
                controller: _occupationCtrl,
                hint: 'Optional occupation',
                enabled: !_saving,
              ),
            ),
            _LabeledField(
              label: 'Annual Income',
              child: _TextInput(
                controller: _incomeCtrl,
                hint: '0',
                enabled: !_saving,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _canPickup,
          onChanged: _saving
              ? null
              : (value) => setState(() => _canPickup = value),
          title: Text(
            'Can Pickup',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _isPrimary,
          onChanged: _saving
              ? null
              : (value) => setState(() => _isPrimary = value),
          title: Text(
            'Primary Guardian',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _loginCard() {
    return _FormCard(
      title: 'Parent Login',
      children: [
        _ResponsiveFieldRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledField(
              label: 'Username',
              child: _TextInput(
                controller: _usernameCtrl,
                hint: 'parent-login-id',
                enabled: !_saving,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
            ),
            _LabeledField(
              label: _isEdit ? 'New Password' : 'Password',
              child: _TextInput(
                controller: _passwordCtrl,
                hint: _isEdit ? 'Enter only to reset' : 'Create password',
                enabled: !_saving && (!_isEdit || _resetPassword),
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
        if (_isEdit) ...[
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _resetPassword,
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    _resetPassword = value;
                    if (!value) _passwordCtrl.clear();
                  }),
            title: Text(
              'Reset Password',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _isActive,
          onChanged: _saving
              ? null
              : (value) => setState(() => _isActive = value),
          title: Text(
            'Active Login',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _studentCard() {
    final availableStudents = widget.students
        .where(
          (student) =>
              !_linkedStudents.any((link) => link.studentId == student.id),
        )
        .toList();
    return _FormCard(
      title: 'Linked Students',
      children: [
        if (widget.students.isEmpty)
          _InlineNotice(
            icon: Icons.info_outline_rounded,
            text: 'Create students first before linking parent accounts.',
          )
        else ...[
          _ResponsiveFieldRow(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LabeledField(
                label: 'Select Student',
                child: _DropdownInput<String>(
                  value: _selectedStudentId,
                  enabled: !_saving && availableStudents.isNotEmpty,
                  hint: 'Choose student',
                  items: availableStudents
                      .map((student) => student.id)
                      .toList(),
                  labelBuilder: _studentLabel,
                  onChanged: (value) =>
                      setState(() => _selectedStudentId = value),
                ),
              ),
              _LabeledField(
                label: 'Admission Number',
                child: _TextInput(
                  controller: _admissionCtrl,
                  hint: 'ADM001',
                  enabled: !_saving,
                  suffixIcon: Icons.add_rounded,
                  onSuffixTap: _saving ? null : _addAdmissionStudent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed:
                  _saving ||
                      (_selectedStudentId == null &&
                          _admissionCtrl.text.trim().isEmpty)
                  ? null
                  : (_selectedStudentId != null
                        ? _addSelectedStudent
                        : _addAdmissionStudent),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Student'),
            ),
          ),
          if (_linkedStudents.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final student in _linkedStudents)
                  InputChip(
                    backgroundColor: Colors.white,
                    selectedColor: Colors.white,
                    disabledColor: Colors.white,
                    labelStyle: GoogleFonts.dmSans(
                      color: const Color(0xFF1C2A32),
                      fontWeight: FontWeight.w700,
                    ),
                    deleteIconColor: const Color(0xFF566B78),
                    side: const BorderSide(color: Color(0xFFD4E2EA)),
                    label: Text(
                      '${student.studentName} - ${student.admissionNumber}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: _saving
                        ? null
                        : () => setState(() => _linkedStudents.remove(student)),
                  ),
              ],
            ),
          ],
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
                _isEdit ? 'Edit Guardian Profile' : 'Add Guardian Profile',
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
              _isEdit ? 'Save Guardian' : 'Add Guardian',
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
    final guardian = widget.initialGuardian;
    setState(() {
      _nameCtrl.text = guardian?.name ?? '';
      _usernameCtrl.text =
          guardian?.username ??
          'parent${DateTime.now().millisecondsSinceEpoch.remainder(90000)}';
      _passwordCtrl.text = guardian == null
          ? 'Parent@${DateTime.now().millisecondsSinceEpoch.remainder(9000) + 1000}'
          : '';
      _phoneCtrl.text = guardian?.phone ?? '';
      _emailCtrl.text = guardian?.email ?? '';
      _occupationCtrl.text = guardian?.occupation ?? '';
      _existingPhotoUrl = guardian?.photoUrl ?? '';
      _photoFile = null;
      _incomeCtrl.text = guardian?.annualIncome == 0 || guardian == null
          ? ''
          : guardian.annualIncome.toStringAsFixed(0);
      _relationship = guardian?.relationship ?? 'Parent/Guardian';
      _selectedStudentId = null;
      _resetPassword = false;
      _passwordVisible = false;
      _isActive = guardian?.isActive ?? true;
      _canPickup = guardian?.canPickup ?? true;
      _isPrimary = guardian?.isPrimary ?? true;
      _linkedStudents = List<GuardianStudentLink>.from(
        guardian?.linkedStudents ?? const [],
      );
      _error = null;
    });
  }

  String get _initialsPreview {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return 'PG';
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _studentLabel(String id) {
    for (final student in widget.students) {
      if (student.id == id) {
        final name = student.fullName.trim();
        return '$name - ${student.admissionNumber}';
      }
    }
    return 'Student';
  }

  static String? _requiredFullName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Full name is required';
    final parts = text.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.length < 2) return 'Enter first and last name';
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

class _GuardianDetailPage extends StatelessWidget {
  final GuardianDirectoryEntry guardian;

  const _GuardianDetailPage({required this.guardian});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF8FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEFF8FD),
        elevation: 0,
        title: const Text('Guardian Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => Navigator.pop(context, value),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Guardian')),
              PopupMenuItem(
                value: 'toggle',
                child: Text(guardian.isActive ? 'Deactivate' : 'Activate'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Remove Guardian'),
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
              title: guardian.name,
              children: [
                Center(
                  child: _GuardianAvatar(
                    initials: guardian.initials,
                    size: 88,
                    imageUrl: guardian.photoUrl,
                  ),
                ),
                const SizedBox(height: 18),
                _DetailRow(label: 'Relationship', value: guardian.relationship),
                _DetailRow(label: 'Phone', value: _fallback(guardian.phone)),
                _DetailRow(label: 'Email', value: _fallback(guardian.email)),
                _DetailRow(
                  label: 'Username',
                  value: _fallback(guardian.username),
                ),
                _DetailRow(label: 'Status', value: guardian.statusLabel),
                _DetailRow(
                  label: 'Linked Students',
                  value: guardian.linkedStudents.isEmpty
                      ? 'Not assigned'
                      : guardian.linkedStudents
                            .map(
                              (s) => '${s.studentName} (${s.admissionNumber})',
                            )
                            .join(', '),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fallback(String value) =>
      value.trim().isEmpty ? 'Not available' : value.trim();
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
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  const _TextInput({
    required this.controller,
    this.hint,
    this.enabled = true,
    this.suffixIcon,
    this.onSuffixTap,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
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

  const _DropdownInput({
    required this.value,
    required this.hint,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
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

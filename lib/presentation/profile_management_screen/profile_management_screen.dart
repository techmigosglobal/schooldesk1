import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/env_config.dart';
import '../../routes/app_routes.dart';
import '../../services/backend_api_client.dart';
import '../../services/logout_service.dart';
import '../../theme/app_theme.dart';

class ProfileManagementScreen extends StatefulWidget {
  final String role;
  const ProfileManagementScreen({super.key, required this.role});

  @override
  State<ProfileManagementScreen> createState() =>
      _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _schoolNameCtrl = TextEditingController();
  final _schoolTypeCtrl = TextEditingController();
  final _boardCtrl = TextEditingController();
  final _schoolEmailCtrl = TextEditingController();
  final _schoolPhoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _isEditing = false;
  String? _error;
  UserResponse? _profile;
  String _avatarPath = '';

  bool get _isPrincipal => widget.role.toLowerCase() == 'principal';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await BackendApiClient.instance.getProfile();
      Map<String, dynamic> school = {};
      if (_isPrincipal) {
        school = await BackendApiClient.instance.getCurrentSchool();
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nameCtrl.text = profile.name.isNotEmpty ? profile.name : profile.email;
        _emailCtrl.text = profile.email;
        _phoneCtrl.text = profile.phone;
        _avatarPath = profile.avatar;
        _schoolNameCtrl.text = '${school['name'] ?? ''}';
        _schoolTypeCtrl.text = '${school['school_type'] ?? ''}';
        _boardCtrl.text = '${school['affiliation_board'] ?? ''}';
        _schoolEmailCtrl.text = '${school['email'] ?? ''}';
        _schoolPhoneCtrl.text = '${school['phone'] ?? ''}';
        _cityCtrl.text = '${school['city'] ?? ''}';
        _stateCtrl.text = '${school['state'] ?? ''}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _schoolNameCtrl.dispose();
    _schoolTypeCtrl.dispose();
    _boardCtrl.dispose();
    _schoolEmailCtrl.dispose();
    _schoolPhoneCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnack('Name cannot be empty.', isError: true);
      return;
    }
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
      _showSnack('Enter a valid email address.', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = await BackendApiClient.instance.updateProfile({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });
      if (_isPrincipal) {
        await BackendApiClient.instance.updateCurrentSchool({
          'name': _schoolNameCtrl.text.trim(),
          'school_type': _schoolTypeCtrl.text.trim(),
          'affiliation_board': _boardCtrl.text.trim(),
          'email': _schoolEmailCtrl.text.trim(),
          'phone': _schoolPhoneCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'state': _stateCtrl.text.trim(),
        });
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isEditing = false;
        _saving = false;
      });
      _showSnack('Profile saved to backend.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Save failed: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans()),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _saving = true);
      final avatarPath = await BackendApiClient.instance.uploadProfileAvatar(
        picked.path,
      );
      final profile = await BackendApiClient.instance.getProfile();
      if (!mounted) return;
      setState(() {
        _avatarPath = avatarPath;
        _profile = profile;
        _saving = false;
      });
      _showSnack('Profile picture uploaded.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Profile picture upload failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawBottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final isCompactAndroid =
        Theme.of(context).platform == TargetPlatform.android &&
        MediaQuery.sizeOf(context).shortestSide < 600;
    final bottomSafePadding = isCompactAndroid && rawBottomPadding < 96
        ? 128.0
        : rawBottomPadding;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.surface,
        actions: [
          if (!_loading && _error == null)
            TextButton.icon(
              onPressed: _saving
                  ? null
                  : _isEditing
                  ? _save
                  : () => setState(() => _isEditing = true),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isEditing ? Icons.check_rounded : Icons.edit_rounded),
              label: Text(_isEditing ? 'Save' : 'Edit'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : Padding(
              padding: EdgeInsets.only(bottom: bottomSafePadding),
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildSection(
                      title: 'Personal Information',
                      children: [
                        _field('Full Name', _nameCtrl, Icons.person_rounded),
                        _field(
                          'Email Address',
                          _emailCtrl,
                          Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _field(
                          'Phone Number',
                          _phoneCtrl,
                          Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                        _avatarAttachmentControl(),
                      ],
                    ),
                    if (_isPrincipal) ...[
                      const SizedBox(height: 12),
                      _buildSection(
                        title: 'School Basic Details',
                        children: [
                          _field(
                            'School Name',
                            _schoolNameCtrl,
                            Icons.apartment_rounded,
                          ),
                          _field(
                            'School Type',
                            _schoolTypeCtrl,
                            Icons.category_rounded,
                          ),
                          _field(
                            'Affiliation Board',
                            _boardCtrl,
                            Icons.verified_rounded,
                          ),
                          _field(
                            'School Email',
                            _schoolEmailCtrl,
                            Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _field(
                            'School Phone',
                            _schoolPhoneCtrl,
                            Icons.call_rounded,
                            keyboardType: TextInputType.phone,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  'City',
                                  _cityCtrl,
                                  Icons.location_city_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  'State',
                                  _stateCtrl,
                                  Icons.map_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                    _buildAccountActions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppTheme.error,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Profile could not be loaded',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(color: AppTheme.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final avatar = _avatarPath.trim();
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : (_profile?.email ?? 'User');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white24,
            backgroundImage: avatar.isEmpty
                ? null
                : NetworkImage(_avatarUrl(avatar)),
            child: avatar.isEmpty
                ? Text(
                    name[0].toUpperCase(),
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profile?.roleName ?? widget.role,
                  style: GoogleFonts.dmSans(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _avatarUrl(String avatar) {
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }
    return '${EnvConfig.apiOrigin}$avatar';
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.muted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        enabled: _isEditing,
        keyboardType: keyboardType,
        style: GoogleFonts.dmSans(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          filled: true,
          fillColor: _isEditing ? AppTheme.surface : AppTheme.surfaceVariant,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _avatarAttachmentControl() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: OutlinedButton.icon(
        onPressed: _isEditing && !_saving ? _pickImage : null,
        icon: const Icon(Icons.attach_file_rounded, size: 18),
        label: Text(
          _avatarPath.trim().isEmpty
              ? 'Attach Profile Picture'
              : 'Replace Profile Picture',
        ),
      ),
    );
  }

  Widget _buildAccountActions() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : _isEditing
                      ? _save
                      : () => setState(() => _isEditing = true),
                  icon: Icon(
                    _isEditing ? Icons.check_rounded : Icons.edit_rounded,
                  ),
                  label: Text(_isEditing ? 'Save changes' : 'Edit profile'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Refresh profile',
                onPressed: _saving ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.settingsScreen,
                    arguments: widget.role,
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Settings'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => LogoutService.signOut(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

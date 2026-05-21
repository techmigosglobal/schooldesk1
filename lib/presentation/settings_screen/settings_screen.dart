import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/theme_provider.dart';
import '../../services/notification_service.dart';
import '../../services/backup_restore_service.dart';
import '../../services/backend_api_client.dart';
import '../../services/logout_service.dart';
import '../../services/token_storage_service.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';

class AppSettingsScreen extends StatefulWidget {
  final String role;
  const AppSettingsScreen({super.key, required this.role});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  NotificationService? _notifService;
  BackupRestoreService? _backupService;
  AppSettingsProvider? _settingsProvider;
  bool _loading = true;
  bool _backupInProgress = false;
  Map<String, dynamic>? _backupMeta;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _notifService = await NotificationService.getInstance();
    _backupService = await BackupRestoreService.getInstance();
    _backupMeta = _backupService?.getBackupMeta();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Use app-level ThemeProvider from Provider
    final themeProvider = context.watch<ThemeProvider>();
    _settingsProvider = context.watch<AppSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF151C26) : AppTheme.background;
    final surfaceColor = isDark ? const Color(0xFF1E2530) : AppTheme.surface;
    final onSurfaceColor = isDark
        ? const Color(0xFFE8EDF2)
        : AppTheme.onSurface;
    final mutedColor = isDark ? const Color(0xFF90A4AE) : AppTheme.muted;
    final outlineColor = isDark
        ? const Color(0xFF2D3748)
        : AppTheme.outlineVariant;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            color: onSurfaceColor,
          ),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: onSurfaceColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection(
                  'APPEARANCE',
                  surfaceColor,
                  outlineColor,
                  mutedColor,
                  [
                    _buildSwitchTile(
                      icon: Icons.dark_mode_outlined,
                      iconColor: const Color(0xFF5C6BC0),
                      title: 'Dark Mode',
                      subtitle: 'Switch between light and dark theme',
                      value: themeProvider.isDark,
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      onChanged: (v) async {
                        await themeProvider.toggleDarkMode();
                      },
                    ),
                    _buildDropdownTile(
                      icon: Icons.text_fields_rounded,
                      iconColor: AppTheme.primary,
                      title: 'App Text Size',
                      subtitle:
                          'Uses SchoolDesk sizing, not the phone display size',
                      value:
                          _settingsProvider?.getSetting(
                            'font_size',
                            'medium',
                          ) ??
                          'medium',
                      options: const ['small', 'medium', 'large'],
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      onChanged: (v) async {
                        await _settingsProvider?.setSetting('font_size', v);
                        if (mounted) setState(() {});
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.view_compact_rounded,
                      iconColor: AppTheme.secondary,
                      title: 'Compact View',
                      subtitle: 'Show more content with reduced spacing',
                      value:
                          _settingsProvider?.getSetting(
                            'compact_view',
                            false,
                          ) ??
                          false,
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      onChanged: (v) async {
                        await _settingsProvider?.setSetting('compact_view', v);
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  'NOTIFICATIONS',
                  surfaceColor,
                  outlineColor,
                  mutedColor,
                  [
                    _buildSwitchTile(
                      icon: Icons.pending_actions_rounded,
                      iconColor: AppTheme.warning,
                      title: 'Pending Approvals',
                      subtitle: 'Alerts for leave and document requests',
                      value:
                          _notifService?.getSetting('pending_approvals') ??
                          true,
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      onChanged: (v) async {
                        await _notifService?.updateSetting(
                          'pending_approvals',
                          v,
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: AppTheme.error,
                      title: 'Fee Reminders',
                      subtitle: 'Alerts for due and overdue fees',
                      value: _notifService?.getSetting('fee_reminders') ?? true,
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      onChanged: (v) async {
                        await _notifService?.updateSetting('fee_reminders', v);
                        if (mounted) setState(() {});
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.quiz_rounded,
                      iconColor: AppTheme.primary,
                      title: 'Exam Reminders',
                      subtitle: 'Alerts for upcoming exams and results',
                      value:
                          _notifService?.getSetting('exam_reminders') ?? true,
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      onChanged: (v) async {
                        await _notifService?.updateSetting('exam_reminders', v);
                        if (mounted) setState(() {});
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.how_to_reg_rounded,
                      iconColor: AppTheme.success,
                      title: 'Attendance Alerts',
                      subtitle: 'Alerts for low attendance warnings',
                      value:
                          _settingsProvider?.getSetting(
                            'show_attendance_alerts',
                            true,
                          ) ??
                          true,
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      onChanged: (v) async {
                        await _settingsProvider?.setSetting(
                          'show_attendance_alerts',
                          v,
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  'DATA & BACKUP',
                  surfaceColor,
                  outlineColor,
                  mutedColor,
                  [
                    _buildActionTile(
                      icon: Icons.backup_rounded,
                      iconColor: AppTheme.success,
                      title: 'Create Backup',
                      subtitle: _backupMeta != null
                          ? 'Last backup: ${_formatDate(_backupMeta!['lastBackup'] as String?)}'
                          : 'No backup created yet',
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      trailing: _backupInProgress
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.chevron_right_rounded,
                              color: mutedColor,
                            ),
                      onTap: _createBackup,
                    ),
                    _buildActionTile(
                      icon: Icons.restore_rounded,
                      iconColor: AppTheme.primary,
                      title: 'Restore Backup',
                      subtitle: 'Restore data from a previous backup',
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: mutedColor,
                      ),
                      onTap: _showRestoreDialog,
                    ),
                    _buildActionTile(
                      icon: Icons.delete_sweep_rounded,
                      iconColor: AppTheme.error,
                      title: 'Clear All Data',
                      subtitle: 'Reset app to factory defaults',
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: mutedColor,
                      ),
                      onTap: _showClearDataDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  'ACCOUNT',
                  surfaceColor,
                  outlineColor,
                  mutedColor,
                  [
                    _buildActionTile(
                      icon: Icons.person_outline_rounded,
                      iconColor: AppTheme.primary,
                      title: 'My Profile',
                      subtitle: 'View and edit your profile',
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: mutedColor,
                      ),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.profileScreen,
                        arguments: widget.role,
                      ),
                    ),
                    _buildActionTile(
                      icon: Icons.lock_outline_rounded,
                      iconColor: AppTheme.secondary,
                      title: 'Change Password',
                      subtitle: 'Update your login password',
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: mutedColor,
                      ),
                      onTap: _openChangePasswordPage,
                    ),
                    _buildActionTile(
                      icon: Icons.logout_rounded,
                      iconColor: AppTheme.error,
                      title: 'Sign Out',
                      subtitle: 'Log out from your account',
                      onSurfaceColor: onSurfaceColor,
                      mutedColor: mutedColor,
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: mutedColor,
                      ),
                      onTap: () => LogoutService.signOut(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection('ABOUT', surfaceColor, outlineColor, mutedColor, [
                  _buildInfoTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: mutedColor,
                    title: 'App Version',
                    value: '1.0.0',
                    onSurfaceColor: onSurfaceColor,
                    mutedColor: mutedColor,
                  ),
                  _buildInfoTile(
                    icon: Icons.school_rounded,
                    iconColor: AppTheme.primary,
                    title: 'Application',
                    value: 'Public School',
                    onSurfaceColor: onSurfaceColor,
                    mutedColor: mutedColor,
                  ),
                  _buildInfoTile(
                    icon: Icons.build_outlined,
                    iconColor: mutedColor,
                    title: 'Build',
                    value: 'Production',
                    onSurfaceColor: onSurfaceColor,
                    mutedColor: mutedColor,
                  ),
                ]),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSection(
    String title,
    Color surfaceColor,
    Color outlineColor,
    Color mutedColor,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: mutedColor,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: outlineColor),
          ),
          child: Column(
            children: children.asMap().entries.map((e) {
              final isLast = e.key == children.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast)
                    Divider(height: 1, indent: 56, color: outlineColor),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Color onSurfaceColor,
    required Color mutedColor,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: onSurfaceColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(fontSize: 12, color: mutedColor),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppTheme.primary,
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
    required List<String> options,
    required Color onSurfaceColor,
    required Color mutedColor,
    required ValueChanged<String> onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: onSurfaceColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(fontSize: 12, color: mutedColor),
      ),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.primary),
        items: options
            .map(
              (o) => DropdownMenuItem(
                value: o,
                child: Text(o[0].toUpperCase() + o.substring(1)),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required Color onSurfaceColor,
    required Color mutedColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: onSurfaceColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(fontSize: 12, color: mutedColor),
      ),
      trailing: trailing,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color onSurfaceColor,
    required Color mutedColor,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: onSurfaceColor,
        ),
      ),
      trailing: Text(
        value,
        style: GoogleFonts.dmSans(fontSize: 13, color: mutedColor),
      ),
    );
  }

  Future<void> _createBackup() async {
    if (_backupService == null) return;
    setState(() => _backupInProgress = true);
    try {
      final jsonStr = await _backupService!.exportBackup();
      final sizeBytes = jsonStr.length;
      final timestamp = DateTime.now().toIso8601String();
      await _backupService!.saveBackupMeta(timestamp, sizeBytes);
      _backupMeta = _backupService!.getBackupMeta();

      if (mounted) {
        setState(() => _backupInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup created successfully (${(sizeBytes / 1024).toStringAsFixed(1)} KB)',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _backupInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup failed. Please try again.',
              style: GoogleFonts.dmSans(),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showRestoreDialog() {
    final hasBackup = _backupMeta != null;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Restore Backup',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        content: Text(
          hasBackup
              ? 'Restore data from backup created on ${_formatDate(_backupMeta!['lastBackup'] as String?)}?\n\nThis will replace all current data. This action cannot be undone.'
              : 'No backup found. Please create a backup first before restoring.',
          style: GoogleFonts.dmSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: AppTheme.muted),
            ),
          ),
          if (hasBackup)
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (_backupService == null) return;
                try {
                  final jsonStr = await _backupService!.exportBackup();
                  final success = await _backupService!.restoreBackup(jsonStr);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Data restored successfully!'
                              : 'Restore failed. Backup may be corrupted.',
                          style: GoogleFonts.dmSans(),
                        ),
                        backgroundColor: success
                            ? AppTheme.success
                            : AppTheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Restore failed. Please try again.',
                          style: GoogleFonts.dmSans(),
                        ),
                        backgroundColor: AppTheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              child: Text('Restore', style: GoogleFonts.dmSans()),
            ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Clear All Data',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will permanently delete all app data and reset to defaults. This cannot be undone.',
          style: GoogleFonts.dmSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: AppTheme.muted),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await TokenStorageService.clear();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'All data cleared successfully.',
                        style: GoogleFonts.dmSans(),
                      ),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.landingPage,
                    (r) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to clear data.',
                        style: GoogleFonts.dmSans(),
                      ),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('Clear', style: GoogleFonts.dmSans()),
          ),
        ],
      ),
    );
  }

  void _openChangePasswordPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _ChangePasswordPage()),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown';
    try {
      return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(iso));
    } catch (_) {
      return 'Unknown';
    }
  }
}

class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage();

  @override
  State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<_ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _errorText;
  String? _successText;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _errorText = null;
      _successText = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await BackendApiClient.instance.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      setState(() {
        _submitting = false;
        _successText = 'Password updated successfully. Please sign in again.';
      });
      await TokenStorageService.clear();
      BackendApiClient.instance.clearAuthToken();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.landingPage,
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = _friendlyPasswordError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF151C26) : AppTheme.background;
    final surfaceColor = isDark ? const Color(0xFF1E2530) : AppTheme.surface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Change Password',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BackendGapBanner(
                icon: Icons.verified_user_outlined,
                message:
                    'Password changes are verified against the VPS backend for the current signed-in account.',
              ),
              const SizedBox(height: 16),
              _passwordField(
                controller: _currentCtrl,
                label: 'Current Password',
                obscure: _obscureCurrent,
                onToggle: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Enter current password';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _passwordField(
                controller: _newCtrl,
                label: 'New Password',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (value) {
                  final password = value ?? '';
                  if (password.isEmpty) return 'Enter new password';
                  if (password.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (password == _currentCtrl.text) {
                    return 'Use a different password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _passwordField(
                controller: _confirmCtrl,
                label: 'Confirm Password',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Confirm new password';
                  if (value != _newCtrl.text) {
                    return 'New passwords do not match';
                  }
                  return null;
                },
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 16),
                _InlineStateMessage(
                  message: _errorText!,
                  color: AppTheme.error,
                  icon: Icons.error_outline_rounded,
                ),
              ],
              if (_successText != null) ...[
                const SizedBox(height: 16),
                _InlineStateMessage(
                  message: _successText!,
                  color: AppTheme.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_submitting ? 'Checking...' : 'Update Password'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        suffixIcon: IconButton(
          tooltip: obscure ? 'Show password' : 'Hide password',
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  String _friendlyPasswordError(Object error) {
    final raw = error.toString();
    if (raw.contains('Current password is incorrect')) {
      return 'Current password is incorrect.';
    }
    if (raw.contains('new_password')) {
      return 'New password must be at least 8 characters.';
    }
    final server = RegExp(r'ServerException\([^)]*\):\s*(.*)').firstMatch(raw);
    final message = server?.group(1)?.trim();
    if (message != null && message.isNotEmpty) return message;
    return 'Password update failed. Please try again.';
  }
}

class _BackendGapBanner extends StatelessWidget {
  final IconData icon;
  final String message;

  const _BackendGapBanner({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.warning.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStateMessage extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;

  const _InlineStateMessage({
    required this.message,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

@immutable
class AccountAccessFormArgs {
  final String ownerRole;
  final Map<String, dynamic>? existing;
  final String? initialRole;

  const AccountAccessFormArgs({
    required this.ownerRole,
    this.existing,
    this.initialRole,
  });

  bool get isPrincipalOwner => ownerRole.toLowerCase() == 'principal';
  bool get isEdit => existing != null;
}

@immutable
class AccountAccessFormResult {
  final bool created;
  final String role;

  const AccountAccessFormResult({required this.created, required this.role});
}

class AccountAccessFormScreen extends StatefulWidget {
  final AccountAccessFormArgs args;

  const AccountAccessFormScreen({super.key, required this.args});

  @override
  State<AccountAccessFormScreen> createState() =>
      _AccountAccessFormScreenState();
}

class _AccountAccessFormScreenState extends State<AccountAccessFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _designationController;
  late final TextEditingController _passwordController;

  late String _role;
  bool _saving = false;
  bool _passwordVisible = false;
  String? _feedback;

  bool get _isPrincipalOwner => widget.args.isPrincipalOwner;
  bool get _isEdit => widget.args.isEdit;

  List<String> get _manageableRoles => _isPrincipalOwner
      ? const ['Admin', 'Teacher', 'Parent']
      : const ['Teacher', 'Parent'];

  bool _isStaffManagedRole(String role) =>
      role == 'Teacher' || (_isPrincipalOwner && role == 'Admin');

  @override
  void initState() {
    super.initState();
    final existing = widget.args.existing;
    final preferredRole =
        existing?['role']?.toString() ?? widget.args.initialRole;
    _role = _manageableRoles.contains(preferredRole)
        ? preferredRole!
        : _manageableRoles.first;

    _nameController = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    _usernameController = TextEditingController(
      text: existing?['username']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: existing?['email']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: existing?['phone']?.toString() ?? '',
    );
    _designationController = TextEditingController(
      text: _isStaffManagedRole(_role) ? _role : '',
    );
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit Account' : 'Create Account';
    final drawer = _isPrincipalOwner
        ? PrincipalDrawer(selectedIndex: 1, onDestinationSelected: (_) {})
        : AdminDrawer(selectedIndex: 10, onDestinationSelected: (_) {});

    return SchoolDeskModuleScaffold(
      title: title,
      subtitle: _isPrincipalOwner
          ? 'Principal-managed account provisioning'
          : 'Admin account request sent through Principal approval',
      drawer: drawer,
      bodyIsScrollable: true,
      actions: [
        IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close_rounded),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        IconButton(
          tooltip: _isEdit ? 'Save account' : 'Create account',
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          onPressed: _saving ? null : _save,
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  if (_feedback != null) ...[
                    _buildFeedback(_feedback!),
                    const SizedBox(height: 16),
                  ],
                  _buildPanel(
                    children: [
                      _buildResponsivePair(
                        first: _buildNameField(),
                        second: _buildUsernameField(),
                      ),
                      const SizedBox(height: 16),
                      _buildResponsivePair(
                        first: _buildEmailField(),
                        second: _buildPhoneField(),
                      ),
                      const SizedBox(height: 16),
                      _buildResponsivePair(
                        first: _buildRoleField(),
                        second: _isStaffManagedRole(_role)
                            ? _buildDesignationField()
                            : _buildPasswordField(),
                      ),
                      if (_isStaffManagedRole(_role)) ...[
                        const SizedBox(height: 16),
                        _buildPasswordField(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildActionBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final approvalText = _isPrincipalOwner
        ? 'Accounts created here are activated directly for this school.'
        : 'New accounts are created inactive until the Principal approves them.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.infoContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.info.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              approvalText,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildResponsivePair({required Widget first, required Widget second}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(children: [first, const SizedBox(height: 16), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      autofocus: !_isEdit,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Full name *',
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Full name is required';
        }
        return null;
      },
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      decoration: const InputDecoration(
        labelText: 'Username *',
        helperText: 'Use a short login ID without spaces',
        prefixIcon: Icon(Icons.alternate_email_rounded),
      ),
      validator: (value) {
        final username = value?.trim() ?? '';
        if (username.isEmpty) return 'Username is required';
        if (username.contains(RegExp(r'\s'))) {
          return 'Username cannot contain spaces';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        labelText: _isStaffManagedRole(_role) ? 'Email *' : 'Email',
        prefixIcon: const Icon(Icons.mail_outline_rounded),
      ),
      validator: (value) {
        final email = value?.trim() ?? '';
        if (_isStaffManagedRole(_role) && email.isEmpty) {
          return 'Email is required for staff-backed accounts';
        }
        if (email.isNotEmpty && !email.contains('@')) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.telephoneNumber],
      decoration: const InputDecoration(
        labelText: 'Phone',
        prefixIcon: Icon(Icons.phone_outlined),
      ),
    );
  }

  Widget _buildRoleField() {
    if (_isEdit) {
      return TextFormField(
        initialValue: _role,
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Role',
          helperText: 'Create a new account to change role type',
          prefixIcon: Icon(Icons.admin_panel_settings_outlined),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _role,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Role',
        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
      ),
      items: _manageableRoles
          .map((role) => DropdownMenuItem(value: role, child: Text(role)))
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _role = value;
          if (_isStaffManagedRole(_role) &&
              (_designationController.text.trim().isEmpty ||
                  _manageableRoles.contains(_designationController.text))) {
            _designationController.text = _role;
          }
          _feedback = null;
        });
      },
    );
  }

  Widget _buildDesignationField() {
    return TextFormField(
      controller: _designationController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Staff designation',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_passwordVisible,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: _isEdit ? 'New password' : 'Password *',
        helperText: _isEdit ? 'Leave blank to keep existing password' : null,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _passwordVisible ? 'Hide password' : 'Show password',
          icon: Icon(
            _passwordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
        ),
      ),
      validator: (value) {
        final password = value?.trim() ?? '';
        if (!_isEdit && password.isEmpty) return 'Password is required';
        if (password.isNotEmpty && password.length < 8) {
          return 'Password must be at least 8 characters';
        }
        return null;
      },
      onFieldSubmitted: (_) => _save(),
    );
  }

  Widget _buildFeedback(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_isEdit ? 'Save Account' : 'Create Account'),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _feedback = null;
    });

    try {
      if (_isEdit) {
        await _updateExistingAccount();
      } else {
        await _createAccount();
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        AccountAccessFormResult(created: !_isEdit, role: _role),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _feedback = 'Save failed: $e';
      });
    }
  }

  Future<void> _createAccount() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_isStaffManagedRole(_role)) {
      final name = _splitName(_nameController.text.trim());
      await BackendApiClient.instance.createStaff(
        firstName: name.firstName,
        lastName: name.lastName,
        staffCode: username,
        email: email,
        phone: _phoneController.text.trim(),
        designation: _designationController.text.trim().isEmpty
            ? _role
            : _designationController.text.trim(),
        password: password,
        accountRole: _role,
        requestPrincipalApproval: !_isPrincipalOwner,
      );
      return;
    }

    await BackendApiClient.instance.createUser(
      username: username,
      password: password,
      role: _role,
      fullName: _nameController.text.trim(),
      email: email,
      phone: _phoneController.text.trim(),
      requestPrincipalApproval: !_isPrincipalOwner,
    );
  }

  Future<void> _updateExistingAccount() async {
    final existing = widget.args.existing!;
    final password = _passwordController.text.trim();
    await BackendApiClient.instance.updateUser(
      existing['id'].toString(),
      username: _usernameController.text.trim(),
      password: password.isEmpty ? null : password,
      role: _role,
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    final staffId = '${existing['staffId'] ?? existing['linkedId'] ?? ''}';
    if (_isStaffManagedRole(_role) && staffId.isNotEmpty) {
      final name = _splitName(_nameController.text.trim());
      await BackendApiClient.instance.updateStaff(
        staffId,
        firstName: name.firstName,
        lastName: name.lastName,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        designation: _designationController.text.trim().isEmpty
            ? _role
            : _designationController.text.trim(),
        accountRole: _role,
      );
    }
  }

  ({String firstName, String lastName}) _splitName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final firstName = parts.isEmpty || parts.first.isEmpty
        ? 'Staff'
        : parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '.';
    return (firstName: firstName, lastName: lastName);
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart' as api;
import '../../theme/app_theme.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/erp_module_scaffold.dart';
import 'staff_management_screen.dart';

@immutable
class StaffFormArgs {
  final String ownerRole;
  final StaffModel? existingStaff;

  const StaffFormArgs({required this.ownerRole, this.existingStaff});

  bool get isAdminOwner => ownerRole.toLowerCase() == 'admin';
  bool get isEdit => existingStaff != null;
}

@immutable
class StaffFormResult {
  final bool created;
  final String staffName;

  const StaffFormResult({required this.created, required this.staffName});
}

class StaffFormScreen extends StatefulWidget {
  final StaffFormArgs args;

  const StaffFormScreen({super.key, required this.args});

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _employeeController;
  late final TextEditingController _usernameController;
  late final TextEditingController _designationController;
  late final TextEditingController _passwordController;
  late final TextEditingController _customDepartmentController;

  String _selectedDept = 'Teacher';
  String _accountRole = 'Teacher';
  bool _saving = false;
  bool _passwordVisible = false;
  String? _feedback;

  static const String _customDepartmentValue = '__custom_department__';
  static const List<String> _departments = [
    'Teacher',
    'Co Teacher',
    'Admin',
    'Staff',
    'Support Staff',
    'PE',
  ];

  bool get _isAdminOwner => widget.args.isAdminOwner;
  bool get _isEdit => widget.args.isEdit;

  List<String> get _allowedAccountRoles =>
      _isAdminOwner ? const ['Teacher'] : const ['Teacher', 'Admin'];

  List<String> get _departmentItems {
    final items = [..._departments, _customDepartmentValue];
    if (_selectedDept == _customDepartmentValue ||
        _departments.contains(_selectedDept)) {
      return items;
    }
    return [_selectedDept, ...items];
  }

  @override
  void initState() {
    super.initState();
    final staff = widget.args.existingStaff;
    _nameController = TextEditingController(text: staff?.name ?? '');
    _phoneController = TextEditingController(text: staff?.phone ?? '');
    _emailController = TextEditingController(text: staff?.email ?? '');
    _employeeController = TextEditingController(text: staff?.employeeId ?? '');
    _usernameController = TextEditingController(
      text: staff?.loginUsername ?? '',
    );
    _designationController = TextEditingController(
      text: staff?.designation ?? '',
    );
    _passwordController = TextEditingController();
    _customDepartmentController = TextEditingController();

    _accountRole = staff?.accountRole ?? _allowedAccountRoles.first;
    if (!_allowedAccountRoles.contains(_accountRole)) {
      _accountRole = _allowedAccountRoles.first;
    }
    final existingDepartment = staff?.department.trim();
    if (existingDepartment == null || existingDepartment.isEmpty) {
      _selectedDept = 'Teacher';
    } else if (_departments.contains(existingDepartment)) {
      _selectedDept = existingDepartment;
    } else {
      _selectedDept = _customDepartmentValue;
      _customDepartmentController.text = existingDepartment;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _employeeController.dispose();
    _usernameController.dispose();
    _designationController.dispose();
    _passwordController.dispose();
    _customDepartmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit Staff' : 'Add Staff';
    final drawer = _isAdminOwner
        ? AdminDrawer(selectedIndex: 2, onDestinationSelected: (_) {})
        : PrincipalDrawer(selectedIndex: 1, onDestinationSelected: (_) {});

    return SchoolDeskModuleScaffold(
      title: title,
      subtitle: _isAdminOwner
          ? 'Create staff profile and request Principal approval'
          : 'Create staff profile and role login',
      drawer: drawer,
      bodyIsScrollable: true,
      actions: [
        IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close_rounded),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        IconButton(
          tooltip: _isEdit ? 'Save staff' : 'Add staff',
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
                        second: _buildEmployeeField(),
                      ),
                      const SizedBox(height: 16),
                      _buildResponsivePair(
                        first: _buildDepartmentField(),
                        second: _buildDesignationField(),
                      ),
                      const SizedBox(height: 16),
                      _buildResponsivePair(
                        first: _buildPhoneField(),
                        second: _buildEmailField(),
                      ),
                      const SizedBox(height: 16),
                      _buildResponsivePair(
                        first: _buildUsernameField(),
                        second: _isEdit
                            ? _buildReadOnlyRoleField()
                            : _buildLoginRoleField(),
                      ),
                      if (!_isEdit) ...[
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
    final text = _isAdminOwner
        ? 'Admin-created staff accounts are submitted to Principal approval before login activation.'
        : 'Principal-created staff accounts are activated immediately when login credentials are supplied.';
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
              text,
              style: GoogleFonts.ibmPlexSans(
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
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Name is required' : null,
    );
  }

  Widget _buildDepartmentField() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedDept,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Department *',
            prefixIcon: Icon(Icons.apartment_rounded),
          ),
          items: _departmentItems
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(
                    value == _customDepartmentValue
                        ? 'Custom Department'
                        : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedDept = value;
              _feedback = null;
            });
          },
        ),
        if (_selectedDept == _customDepartmentValue) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _customDepartmentController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Custom department *',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
            validator: (value) {
              if (_selectedDept != _customDepartmentValue) return null;
              if (value == null || value.trim().isEmpty) {
                return 'Department is required';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildEmployeeField() {
    return TextFormField(
      controller: _employeeController,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Employee ID *',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Employee ID is required'
          : null,
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Login username *',
        prefixIcon: Icon(Icons.account_circle_outlined),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Username is required' : null,
    );
  }

  Widget _buildDesignationField() {
    return TextFormField(
      controller: _designationController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Designation *',
        prefixIcon: Icon(Icons.badge_rounded),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Required' : null,
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Phone *',
        prefixIcon: Icon(Icons.phone_rounded),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Phone is required' : null,
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(
        labelText: 'Email *',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (value) {
        final email = value?.trim() ?? '';
        if (email.isEmpty) return 'Email is required';
        if (!email.contains('@')) return 'Enter a valid email';
        return null;
      },
    );
  }

  Widget _buildLoginRoleField() {
    return DropdownButtonFormField<String>(
      initialValue: _accountRole,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Login role *',
        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
      ),
      items: _allowedAccountRoles
          .map((role) => DropdownMenuItem(value: role, child: Text(role)))
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _accountRole = value;
          _feedback = null;
        });
      },
    );
  }

  Widget _buildReadOnlyRoleField() {
    return TextFormField(
      initialValue: _accountRole,
      readOnly: true,
      decoration: const InputDecoration(
        labelText: 'Login role',
        helperText: 'Create a new staff login to change role type',
        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_passwordVisible,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Login password *',
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
        if (password.isEmpty) return 'Password is required';
        if (password.length < 8) return 'Minimum 8 characters';
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
              style: GoogleFonts.ibmPlexSans(
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
            label: Text(_isEdit ? 'Save Staff' : 'Add Staff'),
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
        await _updateStaff();
      } else {
        await _createStaff();
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        StaffFormResult(created: !_isEdit, staffName: _nameController.text),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _feedback = 'Save failed: $e';
      });
    }
  }

  Future<void> _createStaff() async {
    final name = _splitStaffName(_nameController.text.trim());
    await api.BackendApiClient.instance.createStaff(
      firstName: name.firstName,
      lastName: name.lastName,
      staffCode: _employeeController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      designation: _designationController.text.trim(),
      departmentId: _departmentValue(),
      password: _passwordController.text,
      accountRole: _accountRole,
      requestPrincipalApproval: _isAdminOwner,
    );
  }

  Future<void> _updateStaff() async {
    final name = _splitStaffName(_nameController.text.trim());
    await api.BackendApiClient.instance.updateStaff(
      widget.args.existingStaff!.id,
      firstName: name.firstName,
      lastName: name.lastName,
      staffCode: _employeeController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      designation: _designationController.text.trim(),
      departmentId: _departmentValue(),
      accountRole: _accountRole,
    );
  }

  String _departmentValue() {
    return _selectedDept == _customDepartmentValue
        ? _customDepartmentController.text.trim()
        : _selectedDept;
  }

  ({String firstName, String lastName}) _splitStaffName(String fullName) {
    return (firstName: fullName.trim(), lastName: '');
  }
}

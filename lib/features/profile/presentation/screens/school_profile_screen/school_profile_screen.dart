import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart' show CropStyle;
import 'package:image_picker/image_picker.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/utils/image_cropper_helper.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/image_upload_optimizer.dart';
import 'package:schooldesk1/core/utils/media_url.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

class SchoolProfileScreen extends StatefulWidget {
  const SchoolProfileScreen({super.key});

  @override
  State<SchoolProfileScreen> createState() => _SchoolProfileScreenState();
}

class _SchoolProfileScreenState extends State<SchoolProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _boardCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _registrationCtrl = TextEditingController();
  final _udiseCtrl = TextEditingController();
  final _establishedCtrl = TextEditingController();
  final _address1Ctrl = TextEditingController();
  final _address2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _timezoneCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _mottoCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  String? _error;
  String _logoPath = '';
  String _signatureUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _boardCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _principalCtrl.dispose();
    _registrationCtrl.dispose();
    _udiseCtrl.dispose();
    _establishedCtrl.dispose();
    _address1Ctrl.dispose();
    _address2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _postalCtrl.dispose();
    _timezoneCtrl.dispose();
    _currencyCtrl.dispose();
    _mottoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final school = await BackendApiClient.instance.getCurrentSchool();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = _text(school['name']);
        _typeCtrl.text = _text(school['school_type']);
        _boardCtrl.text = _text(school['affiliation_board']);
        _emailCtrl.text = _text(school['email']);
        _phoneCtrl.text = _text(school['phone']);
        _websiteCtrl.text = _text(school['website']);
        _principalCtrl.text = _text(school['principal_name']);
        _registrationCtrl.text = _text(school['registration_no']);
        _udiseCtrl.text = _text(school['udise_code']);
        _establishedCtrl.text = _text(school['established_year']);
        _address1Ctrl.text = _text(school['address_line1']);
        _address2Ctrl.text = _text(school['address_line2']);
        _cityCtrl.text = _text(school['city']);
        _stateCtrl.text = _text(school['state']);
        _postalCtrl.text = _text(school['postal_code']);
        _timezoneCtrl.text = _text(school['timezone']);
        _currencyCtrl.text = _text(school['currency']);
        _mottoCtrl.text = _text(school['motto']);
        _logoPath = _text(school['logo_url']);
        _signatureUrl = _text(school['authorized_signature_url']);
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnack(
        'Please correct the highlighted school profile fields.',
        isError: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.updateCurrentSchool({
        'name': _nameCtrl.text.trim(),
        'school_type': _typeCtrl.text.trim(),
        'affiliation_board': _boardCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'principal_name': _principalCtrl.text.trim(),
        'registration_no': _registrationCtrl.text.trim(),
        'udise_code': _udiseCtrl.text.trim(),
        'established_year': _establishedCtrl.text.trim(),
        'address_line1': _address1Ctrl.text.trim(),
        'address_line2': _address2Ctrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'postal_code': _postalCtrl.text.trim(),
        'timezone': _timezoneCtrl.text.trim(),
        'currency': _currencyCtrl.text.trim().toUpperCase(),
        'motto': _mottoCtrl.text.trim(),
        'logo_url': _logoPath.trim(),
      });
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
      _showSnack('School profile saved.');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Save failed: $e', isError: true);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      final croppedPath = await SchoolDeskImageCropper.cropSquareImage(
        context: context,
        sourcePath: picked.path,
        title: 'Crop School Logo',
        cropStyle: CropStyle.rectangle,
        maxSize: 900,
      );
      if (croppedPath == null || !mounted) return;
      final optimized = await ImageUploadOptimizer.fromPath(
        croppedPath,
        filename: croppedPath.split('/').last,
        preset: ImageUploadPreset.branding,
        mimeType: ImageUploadOptimizer.mimeTypeForFilename(croppedPath),
      );
      setState(() => _saving = true);
      final logoPath = await BackendApiClient.instance.uploadCurrentSchoolLogo(
        croppedPath,
        fileBytes: optimized.bytes,
        fileName: optimized.filename,
        mimeType: optimized.mimeType,
      );
      if (!mounted) return;
      setState(() {
        _logoPath = logoPath;
        _saving = false;
      });
      _showSnack('School logo uploaded.');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Logo upload failed: $e', isError: true);
    }
  }

  Future<void> _pickAuthorizationSignature() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (picked == null) return;
      final optimized = await ImageUploadOptimizer.fromXFile(
        picked,
        preset: ImageUploadPreset.branding,
      );
      setState(() => _saving = true);
      final signatureUrl = await BackendApiClient.instance
          .uploadCurrentSchoolSignature(
            picked.path,
            fileBytes: optimized.bytes,
            fileName: optimized.filename,
            mimeType: optimized.mimeType,
          );
      if (!mounted) return;
      setState(() {
        _signatureUrl = signatureUrl;
        _saving = false;
      });
      _showSnack('Authorization signature uploaded.');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Signature upload failed: $e', isError: true);
    }
  }

  String _text(Object? value) => value == null ? '' : value.toString();

  String _assetUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return resolveOriginalImageUrl(path);
    }
    return resolveOriginalImageUrl('${EnvConfig.apiOrigin}$path');
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans()),
        backgroundColor: isError
            ? context.appTheme.error
            : context.appTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final principalColor = context.appTheme.roleColor(SchoolDeskRole.principal);
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: principalColor,
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: principalColor),
      ),
      child: SchoolDeskModuleScaffold(
        title: 'School Profile',
        subtitle:
            'Maintain trusted institution identity, contacts, and branding',
        drawer: PrincipalDrawer(
          selectedIndex: PrincipalNav.schoolProfile,
          onDestinationSelected: (_) {},
        ),
        actions: [
          if (!_loading && _error == null)
            TextButton.icon(
              onPressed: _saving
                  ? null
                  : _editing
                  ? _save
                  : () => setState(() => _editing = true),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
              label: Text(_editing ? 'Save' : 'Edit'),
            ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _errorState()
            : RefreshIndicator(
                onRefresh: _load,
                child: Form(
                  key: _formKey,
                  autovalidateMode: _editing
                      ? _autovalidateMode
                      : AutovalidateMode.disabled,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _identityHeader(),
                      const SizedBox(height: 12),
                      _section('Receipt Authorization', [
                        _authorizationSignatureCard(),
                      ]),
                      _section('Basic Details', [
                        _field(
                          'School Name',
                          _nameCtrl,
                          Icons.apartment_rounded,
                          validator: (value) =>
                              _requiredText(value, 'School name', max: 120),
                        ),
                        _field(
                          'School Type',
                          _typeCtrl,
                          Icons.category_rounded,
                          validator: (value) =>
                              _requiredText(value, 'School type', max: 80),
                        ),
                        _field(
                          'Affiliation Board',
                          _boardCtrl,
                          Icons.verified_rounded,
                          validator: (value) => _requiredText(
                            value,
                            'Affiliation board',
                            max: 80,
                          ),
                        ),
                        _field(
                          'Established Year',
                          _establishedCtrl,
                          Icons.event_available_rounded,
                          keyboardType: TextInputType.number,
                          validator: _requiredEstablishedYear,
                        ),
                        _field(
                          'Principal Name',
                          _principalCtrl,
                          Icons.admin_panel_settings_rounded,
                          validator: (value) =>
                              _requiredText(value, 'Principal name', max: 120),
                        ),
                        _field(
                          'Motto',
                          _mottoCtrl,
                          Icons.format_quote_rounded,
                          validator: (value) =>
                              _optionalText(value, 'Motto', max: 180),
                        ),
                      ]),
                      _section('Contact', [
                        _field(
                          'School Email',
                          _emailCtrl,
                          Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: _requiredEmail,
                        ),
                        _field(
                          'School Phone',
                          _phoneCtrl,
                          Icons.call_rounded,
                          keyboardType: TextInputType.phone,
                          validator: _requiredPhone,
                        ),
                        _field(
                          'Website',
                          _websiteCtrl,
                          Icons.language_rounded,
                          keyboardType: TextInputType.url,
                          validator: _optionalWebsite,
                        ),
                      ]),
                      _section('Address', [
                        _field(
                          'Address Line 1',
                          _address1Ctrl,
                          Icons.location_on_rounded,
                          validator: (value) =>
                              _requiredText(value, 'Address line 1', max: 160),
                        ),
                        _field(
                          'Address Line 2',
                          _address2Ctrl,
                          Icons.add_location_alt_rounded,
                          validator: (value) =>
                              _optionalText(value, 'Address line 2', max: 160),
                        ),
                        _field(
                          'City',
                          _cityCtrl,
                          Icons.location_city_rounded,
                          validator: (value) =>
                              _requiredText(value, 'City', max: 80),
                        ),
                        _field(
                          'State',
                          _stateCtrl,
                          Icons.map_rounded,
                          validator: (value) =>
                              _requiredText(value, 'State', max: 80),
                        ),
                        _field(
                          'Postal Code',
                          _postalCtrl,
                          Icons.local_post_office_rounded,
                          keyboardType: TextInputType.text,
                          validator: _requiredPostalCode,
                        ),
                      ]),
                      _section('Regional Preferences', [
                        _field(
                          'Timezone',
                          _timezoneCtrl,
                          Icons.schedule_rounded,
                          validator: _requiredTimezone,
                        ),
                        _field(
                          'Currency',
                          _currencyCtrl,
                          Icons.currency_rupee_rounded,
                          validator: _requiredCurrency,
                        ),
                      ]),
                      _bottomActionPanel(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _identityHeader() {
    final principalColor = context.appTheme.roleColor(SchoolDeskRole.principal);
    final name = _nameCtrl.text.trim().isEmpty
        ? 'School Profile'
        : _nameCtrl.text.trim();
    final subtitle = [
      _boardCtrl.text.trim(),
      _typeCtrl.text.trim(),
      _cityCtrl.text.trim(),
    ].where((item) => item.isNotEmpty).join(' - ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: principalColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.appTheme.surface.withAlpha(36),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: _logoPath.trim().isEmpty
                ? const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white,
                    size: 34,
                  )
                : Image.network(
                    _assetUrl(_logoPath.trim()),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _editing && !_saving ? _pickLogo : null,
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: Text(
                    _logoPath.trim().isEmpty ? 'Upload Logo' : 'Replace Logo',
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: principalColor,
                    backgroundColor: Colors.white,
                    disabledForegroundColor: principalColor.withAlpha(128),
                    disabledBackgroundColor: Colors.white.withAlpha(180),
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
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

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.appTheme.muted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appTheme.outlineVariant),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _authorizationSignatureCard() {
    final hasSignature = _signatureUrl.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 112,
            height: 58,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appTheme.outlineVariant),
            ),
            child: hasSignature
                ? Image.network(
                    _assetUrl(_signatureUrl.trim()),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.draw_outlined, color: Colors.grey),
                  )
                : Icon(
                    Icons.draw_outlined,
                    color: context.appTheme.muted,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasSignature
                      ? 'Authorization signature ready'
                      : 'No authorization signature',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasSignature
                      ? 'Used on official fee receipts and fee reports.'
                      : 'Receipts will state that they are computer generated.',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.appTheme.muted,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _editing && !_saving
                      ? _pickAuthorizationSignature
                      : null,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text(hasSignature ? 'Replace' : 'Upload signature'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
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

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        enabled: _editing,
        keyboardType: keyboardType,
        validator: _editing ? validator : null,
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
          fillColor: _editing
              ? context.appTheme.surface
              : context.appTheme.surfaceVariant,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  String? _requiredText(String? value, String field, {int max = 120}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$field is required.';
    if (text.length > max) return '$field must be $max characters or less.';
    return null;
  }

  String? _optionalText(String? value, String field, {int max = 120}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > max) return '$field must be $max characters or less.';
    return null;
  }

  String? _requiredEmail(String? value) {
    final requiredError = _requiredText(value, 'School email', max: 160);
    if (requiredError != null) return requiredError;
    final text = value!.trim();
    final emailPattern = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );
    if (!emailPattern.hasMatch(text)) return 'Enter a valid school email.';
    return null;
  }

  String? _requiredPhone(String? value) {
    final requiredError = _requiredText(value, 'School phone', max: 24);
    if (requiredError != null) return requiredError;
    final normalized = value!.replaceAll(RegExp(r'[\s()-]'), '');
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(normalized)) {
      return 'Enter a valid school phone number.';
    }
    return null;
  }

  String? _optionalWebsite(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.trim().isEmpty) {
      return 'Enter a valid website URL starting with http:// or https://.';
    }
    return null;
  }

  String? _requiredPostalCode(String? value) {
    final requiredError = _requiredText(value, 'Postal code', max: 12);
    if (requiredError != null) return requiredError;
    if (!RegExp(r'^[A-Za-z0-9 -]{3,12}$').hasMatch(value!.trim())) {
      return 'Enter a valid postal code.';
    }
    return null;
  }

  String? _requiredEstablishedYear(String? value) {
    final requiredError = _requiredText(value, 'Established year', max: 4);
    if (requiredError != null) return requiredError;
    final year = int.tryParse(value!.trim());
    final currentYear = DateTime.now().year;
    if (year == null || year < 1800 || year > currentYear) {
      return 'Enter a year between 1800 and $currentYear.';
    }
    return null;
  }

  String? _requiredTimezone(String? value) {
    final requiredError = _requiredText(value, 'Timezone', max: 64);
    if (requiredError != null) return requiredError;
    if (!RegExp(r'^[A-Za-z_]+/[A-Za-z_]+$|^UTC$').hasMatch(value!.trim())) {
      return 'Use an IANA timezone like Asia/Kolkata or UTC.';
    }
    return null;
  }

  String? _requiredCurrency(String? value) {
    final requiredError = _requiredText(value, 'Currency', max: 3);
    if (requiredError != null) return requiredError;
    if (!RegExp(r'^[A-Za-z]{3}$').hasMatch(value!.trim())) {
      return 'Use a 3-letter currency code like INR.';
    }
    return null;
  }

  Widget _bottomActionPanel() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final message = Text(
          _editing
              ? 'Review changes, then save them to Supabase.'
              : 'School identity is synced from Supabase.',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: context.appTheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        );
        final action = FilledButton.icon(
          onPressed: _saving
              ? null
              : _editing
              ? _save
              : () => setState(() => _editing = true),
          icon: Icon(_editing ? Icons.check_rounded : Icons.edit_rounded),
          label: Text(_editing ? 'Save changes' : 'Edit profile'),
        );
        return Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appTheme.outlineVariant),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          color: context.appTheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: message),
                      ],
                    ),
                    const SizedBox(height: 12),
                    action,
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      color: context.appTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: message),
                    const SizedBox(width: 12),
                    action,
                  ],
                ),
        );
      },
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: context.appTheme.error,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'School profile could not be loaded',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(color: context.appTheme.muted),
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
}

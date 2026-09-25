import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/image_upload_optimizer.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';
import 'package:schooldesk1/modules/finance/data/api_payment_config_repository.dart';
import 'package:schooldesk1/modules/finance/domain/payment_config_repository.dart';

class PrincipalPaymentConfig extends StatefulWidget {
  const PrincipalPaymentConfig({super.key, this.repository});

  final PaymentConfigRepository? repository;

  @override
  State<PrincipalPaymentConfig> createState() => _PrincipalPaymentConfigState();
}

class _PrincipalPaymentConfigState extends State<PrincipalPaymentConfig> {
  PaymentConfigRepository get _repository =>
      widget.repository ?? ApiPaymentConfigRepository.legacyDefault;

  final _upiController = TextEditingController();
  final _payeeController = TextEditingController();
  final _noteController = TextEditingController();
  RepositoryState<Map<String, dynamic>> _repositoryState =
      const RepositoryState.loading();
  bool _saving = false;
  bool _uploading = false;
  Map<String, dynamic> _config = const {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _upiController.dispose();
    _payeeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final previous = _repositoryState;
    setState(() {
      _repositoryState = RepositoryState.loading(
        data: previous.data,
        source: previous.source,
        isStale: previous.isStale,
        isRefreshing: previous.hasData,
        lastUpdated: previous.lastUpdated,
      );
    });
    try {
      final config = await _repository.loadConfig(
        refreshNonce: DateTime.now().millisecondsSinceEpoch,
      );
      if (!mounted) return;
      setState(() {
        _config = config;
        _upiController.text = textValue(config['upi_id']);
        _payeeController.text = textValue(config['payee_name']);
        _noteController.text = textValue(config['qr_note']);
        _repositoryState = RepositoryState(
          data: Map<String, dynamic>.unmodifiable(config),
          source: RepositorySource.remote,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _repositoryState = previous.hasData
            ? RepositoryState(
                data: previous.data,
                source: RepositorySource.cache,
                isStale: true,
                error: error,
                lastUpdated: previous.lastUpdated,
              )
            : RepositoryState.error(error: error);
      });
    }
  }

  String get _qrUrl => textValue(_config['qr_image_url']);

  String _absoluteUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return '${EnvConfig.apiOrigin}$trimmed';
    return '${EnvConfig.apiOrigin}/$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.surface,
      appBar: AppBar(
        title: const Text(
          'Payment Config',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.appTheme.onSurface,
      ),
      body: SchoolDeskRepositoryStateView<Map<String, dynamic>>(
        state: _repositoryState,
        onRetry: _loadData,
        emptyTitle: 'Payment configuration unavailable',
        emptyMessage: 'No payment configuration exists for this school scope.',
        errorTitle: 'Payment configuration unavailable',
        data: (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.appTheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment QR Scanner',
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.appTheme.surfaceVariant.withOpacity(
                          0.2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.appTheme.outlineVariant,
                        ),
                      ),
                      child: _qrUrl.isEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner,
                                  size: 48,
                                  color: context.appTheme.muted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No QR code uploaded',
                                  style: TextStyle(
                                    color: context.appTheme.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _absoluteUrl(_qrUrl),
                                height: 180,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.broken_image_outlined,
                                  color: context.appTheme.error,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickQr,
                        icon: _uploading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(
                          _uploading
                              ? 'Uploading...'
                              : _qrUrl.isEmpty
                              ? 'Upload QR Code'
                              : 'Replace QR Code',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A6B4A),
                          side: const BorderSide(color: Color(0xFF1A6B4A)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.appTheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Payment Details',
                      style: GoogleFonts.ibmPlexSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _upiController,
                      decoration: InputDecoration(
                        labelText: 'UPI ID',
                        prefixIcon: const Icon(
                          Icons.account_balance_wallet_outlined,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _payeeController,
                      decoration: InputDecoration(
                        labelText: 'Payee Name',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Instructions for Parents',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _saveConfig,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save Configuration'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A6B4A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These details are displayed directly to parents in the Fee Hub payment scanner screens.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    final upiId = _upiController.text.trim();
    if (upiId.isEmpty && _qrUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a UPI ID or upload a QR code before saving.'),
        ),
      );
      return;
    }
    if (upiId.isNotEmpty && !_isValidUpiId(upiId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid UPI ID, for example name@bank.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final config = await _repository.updateConfig(
        upiId: upiId,
        payeeName: _payeeController.text,
        qrNote: _noteController.text,
        qrImageUrl: _qrUrl,
      );
      if (!mounted) return;
      setState(() {
        _config = config;
        _saving = false;
        _repositoryState = RepositoryState(
          data: Map<String, dynamic>.unmodifiable(config),
          source: RepositorySource.localMutation,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment configuration saved.')),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: context.appTheme.error,
        ),
      );
    }
  }

  bool _isValidUpiId(String value) {
    if (value.contains(RegExp(r'\s'))) return false;
    final separator = value.indexOf('@');
    return separator > 0 &&
        separator == value.lastIndexOf('@') &&
        separator < value.length - 1;
  }

  Future<void> _pickQr() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result.isEmpty) return;
    final file = result.single;
    final path = file.path ?? '';
    final fileBytes = await file.readAsBytes();
    final mimeType = ImageUploadOptimizer.mimeTypeForFilename(file.name);
    final optimized = fileBytes.isNotEmpty
        ? ImageUploadOptimizer.fromBytes(
            fileBytes,
            filename: file.name,
            mimeType: mimeType,
            preset: ImageUploadPreset.branding,
          )
        : await ImageUploadOptimizer.fromPath(
            path,
            filename: file.name,
            mimeType: mimeType,
            preset: ImageUploadPreset.branding,
          );
    if (path.isEmpty && fileBytes.isEmpty) return;
    setState(() => _uploading = true);
    try {
      final config = await _repository.uploadQr(
        path: path,
        fileName: optimized.filename,
        fileBytes: optimized.bytes,
        mimeType: optimized.mimeType,
      );
      if (!mounted) return;
      setState(() {
        _config = config;
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR code uploaded successfully.')),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }
}

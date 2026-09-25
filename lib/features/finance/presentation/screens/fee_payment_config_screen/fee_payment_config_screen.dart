/// Fee Payment Config — manage parent payment QR and UPI settings.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/image_upload_optimizer.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_widgets.dart';
import 'package:schooldesk1/modules/finance/data/api_payment_config_repository.dart';
import 'package:schooldesk1/modules/finance/domain/payment_config_repository.dart';

class FeePaymentConfigScreen extends StatefulWidget {
  const FeePaymentConfigScreen({super.key, this.repository});

  final PaymentConfigRepository? repository;

  @override
  State<FeePaymentConfigScreen> createState() => _FeePaymentConfigScreenState();
}

class _FeePaymentConfigScreenState extends State<FeePaymentConfigScreen> {
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Payment Config',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFF7FAFF),
        elevation: 0,
      ),
      body: SchoolDeskRepositoryStateView<Map<String, dynamic>>(
        state: _repositoryState,
        onRetry: _loadData,
        emptyTitle: 'Payment configuration unavailable',
        emptyMessage: 'No payment configuration exists for this school scope.',
        errorTitle: 'Payment configuration unavailable',
        data: (_) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // QR Preview
            FeeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FeeSectionTitle('QR Image'),
                  const SizedBox(height: 10),
                  Container(
                    height: 180,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.appTheme.surfaceVariant.withOpacity(0.3),
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
                                Icons.qr_code_2_rounded,
                                size: 56,
                                color: context.appTheme.muted,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No QR uploaded yet',
                                style: TextStyle(
                                  color: context.appTheme.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _absoluteUrl(_qrUrl),
                              height: 164,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.broken_image_outlined,
                                color: context.appTheme.error,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _pickQr,
                    icon: _uploading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(
                      _uploading ? 'Uploading...' : 'Upload QR Image',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Fields
            FeeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FeeSectionTitle('Payment Details'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _upiController,
                    decoration: const InputDecoration(
                      labelText: 'UPI ID',
                      prefixIcon: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _payeeController,
                    decoration: const InputDecoration(
                      labelText: 'Payee Name',
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Payment Note for Parents',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveConfig,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Saving...' : 'Save Payment Details',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Status
            const FeeInfoBanner(
              text:
                  'These settings are shown to parents when they submit UPI payment proofs. Make sure the QR image and UPI ID are correct.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    try {
      final config = await _repository.updateConfig(
        upiId: _upiController.text,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment details saved.')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QR uploaded for parents.')));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }
}

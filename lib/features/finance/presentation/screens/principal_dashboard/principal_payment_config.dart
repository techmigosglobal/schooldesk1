import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_shared/fee_models.dart';

class PrincipalPaymentConfig extends StatefulWidget {
  const PrincipalPaymentConfig({super.key});

  @override
  State<PrincipalPaymentConfig> createState() => _PrincipalPaymentConfigState();
}

class _PrincipalPaymentConfigState extends State<PrincipalPaymentConfig> {
  final _upiController = TextEditingController();
  final _payeeController = TextEditingController();
  final _noteController = TextEditingController();
  bool _loading = true;
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
    setState(() { _loading = true; });
    try {
      final config = await BackendApiClient.instance.getPaymentConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _upiController.text = textValue(config['upi_id']);
        _payeeController.text = textValue(config['payee_name']);
        _noteController.text = textValue(config['qr_note']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; });
    }
  }

  String get _qrUrl => textValue(_config['qr_image_url']);

  String _absoluteUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    if (trimmed.startsWith('/')) return '${EnvConfig.apiOrigin}$trimmed';
    return '${EnvConfig.apiOrigin}/$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.surface,
      appBar: AppBar(
        title: const Text('Payment Config', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.appTheme.onSurface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                          style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 200,
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.appTheme.surfaceVariant.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.appTheme.outlineVariant),
                          ),
                          child: _qrUrl.isEmpty
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.qr_code_scanner, size: 48, color: context.appTheme.muted),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No QR code uploaded',
                                      style: TextStyle(color: context.appTheme.muted, fontSize: 13),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _absoluteUrl(_qrUrl),
                                    height: 180,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: context.appTheme.error),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _uploading ? null : _pickQr,
                            icon: _uploading
                                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.upload_file),
                            label: Text(_uploading ? 'Uploading...' : 'Upload New QR Code'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1A6B4A),
                              side: const BorderSide(color: Color(0xFF1A6B4A)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                          style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _upiController,
                          decoration: InputDecoration(
                            labelText: 'UPI ID',
                            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _payeeController,
                          decoration: InputDecoration(
                            labelText: 'Payee Name',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _noteController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Instructions for Parents',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _saveConfig,
                          icon: _saving
                              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save),
                          label: const Text('Save Configuration'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A6B4A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                          style: TextStyle(fontSize: 12, color: context.appTheme.onSurface.withOpacity(0.8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    try {
      final config = await BackendApiClient.instance.updatePaymentConfig(
        upiId: _upiController.text,
        payeeName: _payeeController.text,
        qrNote: _noteController.text,
        qrImageUrl: _qrUrl,
      );
      if (!mounted) return;
      setState(() { _config = config; _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment configuration saved.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: context.appTheme.error));
    }
  }

  Future<void> _pickQr() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null || path.isEmpty) return;
    setState(() => _uploading = true);
    try {
      final config = await BackendApiClient.instance.uploadPaymentQr(path: path, fileName: file.name);
      if (!mounted) return;
      setState(() {
        _config = config;
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR code uploaded successfully.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }
}

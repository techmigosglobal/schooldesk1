import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_child_selector.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ParentDocumentsScreen extends StatefulWidget {
  const ParentDocumentsScreen({super.key});

  @override
  State<ParentDocumentsScreen> createState() => _ParentDocumentsScreenState();
}

class _ParentDocumentsScreenState extends State<ParentDocumentsScreen> {
  int _selectedNavIndex = ParentNav.documents;
  int _activeChildIndex = 0;
  bool _generatingPdf = false;
  String? _generatingDocName;

  List<Map<String, dynamic>> _children = [];
  final Map<String, List<Map<String, dynamic>>> _docsByStudent = {};
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _school = const {};
  String _parentName = '';
  NotificationService? _notificationService;
  String _lastNotificationSignal = '';

  String? get _activeStudentId => _children.isEmpty
      ? null
      : (_children[_activeChildIndex]['id'] ?? '').toString();

  List<Map<String, dynamic>> get _availableDocs =>
      _docsByStudent[_activeStudentId] ?? const [];

  Map<String, dynamic> get _activeChild =>
      _children.isEmpty ? const {} : _children[_activeChildIndex];

  String get _activeChildName =>
      '${_activeChild['name'] ?? '${_activeChild['first_name'] ?? ''} ${_activeChild['last_name'] ?? ''}'}'
          .trim();

  String get _activeClassName => parentChildClassAndSectionLabel(_activeChild);

  @override
  void initState() {
    super.initState();
    _loadData();
    unawaited(_bindDocumentNotifications());
  }

  @override
  void dispose() {
    _notificationService?.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  Future<void> _bindDocumentNotifications() async {
    final service = await NotificationService.getInstance();
    if (!mounted) return;
    _notificationService = service;
    _lastNotificationSignal = service.notifications.isEmpty
        ? ''
        : service.notifications.first.id;
    service.addListener(_onNotificationsChanged);
  }

  void _onNotificationsChanged() {
    final service = _notificationService;
    if (!mounted || service == null || service.notifications.isEmpty) return;
    final latest = service.notifications.first;
    if (latest.id == _lastNotificationSignal) return;
    _lastNotificationSignal = latest.id;
    if (latest.referenceType == 'student_document' ||
        latest.category == 'document') {
      unawaited(_loadData());
    }
  }

  Future<void> _loadData() async {
    try {
      final api = BackendApiClient.instance;
      final children = await api.getMyStudents(
        refreshNonce: DateTime.now().millisecondsSinceEpoch,
      );
      Map<String, dynamic> school = const {};
      String parentName = '';
      try {
        school = await api.getCurrentSchool();
      } on Object catch (_) {}
      try {
        parentName = (await api.getProfile()).name.trim();
      } on Object catch (_) {}
      final docs = <String, List<Map<String, dynamic>>>{};
      for (final child in children) {
        final studentId = (child['id'] ?? '').toString();
        if (studentId.isEmpty) continue;
        final rows = await BackendApiClient.instance.getRawList(
          '/student-documents',
          queryParameters: {'student_id': studentId},
        );
        docs[studentId] = rows
            .map(
              (row) => {
                'id': row['id'],
                'name': row['title'] ?? row['doc_type'] ?? 'Document',
                'type': row['doc_type'] ?? 'Document',
                'icon': Icons.description_rounded,
                'color': context.appTheme.primary,
                'available': true,
                'size': '',
                'docType': row['doc_type'] ?? 'document',
                'fileUrl': row['file_url'] ?? '',
                'amount': row['amount'] ?? 0,
                'receiptNo': row['receipt_number'] ?? row['receipt_no'],
                'paymentMethod':
                    row['payment_method'] ?? row['payment_mode'] ?? '',
                'paymentDate':
                    row['paid_at'] ?? row['payment_date'] ?? row['created_at'],
                'studentName':
                    child['name'] ??
                    '${child['first_name'] ?? ''} ${child['last_name'] ?? ''}'
                        .trim(),
              },
            )
            .toList();
      }
      final selectedIndex = await ParentChildSelectionService.indexFor(
        children,
        fallback: _activeChildIndex,
      );
      if (!mounted) return;
      setState(() {
        _children = children;
        _school = school;
        _parentName = parentName;
        _activeChildIndex = selectedIndex;
        _docsByStudent
          ..clear()
          ..addAll(docs);
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    final docType = doc['docType'] as String? ?? '';
    setState(() {
      _generatingPdf = true;
      _generatingDocName = doc['name'] as String;
    });

    try {
      final fileUrl = '${doc['fileUrl'] ?? ''}'.trim();
      if (docType == 'fee_receipt') {
        await _generateFeeReceiptPdf(doc);
      } else if (fileUrl.isNotEmpty) {
        if (mounted) {
          final item = EventPostMediaItem.fromUrl(
            fileUrl,
            name: '${doc['name'] ?? 'Document'}',
          );
          await openEventPostMediaPreview(context, item);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${doc['name']} is not available to preview yet.'),
            backgroundColor: context.appTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to generate document. Please try again.',
            ),
            backgroundColor: context.appTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _generatingPdf = false;
          _generatingDocName = null;
        });
      }
    }
  }

  Future<void> _generateFeeReceiptPdf(Map<String, dynamic> doc) async {
    final pdfService = PdfService.getInstance();
    final childName = _activeChildName.isEmpty ? 'Student' : _activeChildName;
    final amount = (doc['amount'] as num?)?.toDouble() ?? 0.0;
    final termLabel = doc['name'] as String? ?? 'Fee Receipt';
    final rollNo =
        '${_activeChild['rollNo'] ?? _activeChild['roll_number'] ?? _activeChild['admission_number'] ?? _activeChild['student_code'] ?? ''}'
            .trim();
    final schoolName = '${_school['name'] ?? 'School'}'.trim();
    final schoolAddress =
        [
              _school['address'],
              _school['address_line1'],
              _school['city'],
              _school['state'],
              _school['postal_code'],
            ]
            .map((value) => '${value ?? ''}'.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .join(', ');
    final paymentDate =
        DateTime.tryParse('${doc['paymentDate'] ?? ''}') ?? DateTime.now();

    final pdfBytes = await pdfService.generateFeeReceipt(
      receiptNo: doc['receiptNo'] as String? ?? '${doc['id'] ?? ''}',
      studentName: childName,
      className: _activeClassName,
      rollNo: rollNo,
      parentName: _parentName,
      feeItems: [
        {'description': termLabel, 'amount': amount},
      ],
      totalAmount: amount,
      paidAmount: amount,
      balance: 0.0,
      paymentMode: '${doc['paymentMethod'] ?? 'UPI'}'.trim(),
      paymentDate: paymentDate,
      schoolName: schoolName.isEmpty ? 'School' : schoolName,
      schoolAddress: schoolAddress,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(pdfBytes),
      name: 'FeeReceipt_${childName}_$termLabel',
    );
  }

  Future<void> _deleteStudentDoc(String studentId, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await BackendApiClient.instance.deleteRaw('/student-documents/$docId');
      _loadData();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete document: $e')),
        );
      }
    }
  }

  Future<void> _uploadStudentDocDialog(String studentId) async {
    final titleCtrl = TextEditingController();
    String docType = 'Aadhar Card';
    PlatformFile? selectedFile;
    bool uploading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Upload Student Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Document Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: docType,
                decoration: const InputDecoration(labelText: 'Document Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'Aadhar Card',
                    child: Text('Aadhar Card'),
                  ),
                  DropdownMenuItem(
                    value: 'Birth Certificate',
                    child: Text('Birth Certificate'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      docType = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (selectedFile != null)
                Text(
                  'Selected: ${selectedFile!.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                        );
                        if (result != null && result.files.isNotEmpty) {
                          setDialogState(() {
                            selectedFile = result.files.first;
                          });
                        }
                      },
                icon: const Icon(Icons.attach_file),
                label: const Text('Select File'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (uploading || selectedFile == null)
                  ? null
                  : () async {
                      setDialogState(() {
                        uploading = true;
                      });
                      try {
                        final fileUrl = await BackendApiClient.instance
                            .uploadFile(
                              selectedFile!.path!,
                              filename: selectedFile!.name,
                            );
                        await BackendApiClient.instance
                            .createRaw('/student-documents', {
                              'student_id': studentId,
                              'doc_type': docType,
                              'title': titleCtrl.text.trim().isEmpty
                                  ? docType
                                  : titleCtrl.text.trim(),
                              'file_url': fileUrl,
                            });
                        Navigator.pop(context);
                        _loadData();
                      } on Object catch (e) {
                        setDialogState(() {
                          uploading = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Upload failed: $e')),
                        );
                      }
                    },
              child: uploading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Documents',
      subtitle: 'Access child documents and generated records',
      drawer: ParentDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        if (_activeStudentId != null)
          IconButton(
            tooltip: 'Upload student document',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () => _uploadStudentDocDialog(_activeStudentId!),
          ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildStateMessage('Unable to load documents', _error!)
          : _children.isEmpty
          ? _buildStateMessage(
              'No linked students',
              'Ask the school admin to link students to this parent account.',
            )
          : Column(
              children: [
                _buildChildSelector(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: _buildDocumentsTab(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStateMessage(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: context.appTheme.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildSelector() {
    return Container(
      color: context.appTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ParentChildSelector(
        children: _children,
        selectedIndex: _activeChildIndex,
        onSelected: (index) {
          setState(() => _activeChildIndex = index);
          ParentChildSelectionService.saveIndex(_children, index);
        },
      ),
    );
  }

  Widget _buildDocumentsTab() {
    if (_availableDocs.isEmpty) {
      return _buildStateMessage(
        'No documents available',
        'Uploaded student documents and certificates will appear here.',
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _availableDocs.length,
      itemBuilder: (_, i) {
        final doc = _availableDocs[i];
        final isGenerating =
            _generatingPdf && _generatingDocName == doc['name'];
        final isFeeReceipt = doc['docType'] == 'fee_receipt';
        final hasFile = '${doc['fileUrl'] ?? ''}'.trim().isNotEmpty;
        final canGenerate = isFeeReceipt;
        final canPreview = hasFile && !isFeeReceipt;
        final canDelete = !isFeeReceipt;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: context.appTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.appTheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: (doc['color'] as Color).withAlpha(18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (doc['color'] as Color),
                        (doc['color'] as Color).withAlpha(200),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (doc['color'] as Color).withAlpha(50),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    doc['icon'] as IconData,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['name'],
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${doc['type']}${(doc['size'] as String).isNotEmpty ? ' • ${doc['size']}' : ''}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: context.appTheme.muted,
                        ),
                      ),
                      if (canGenerate)
                        Row(
                          children: [
                            Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 11,
                              color: (doc['color'] as Color),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'PDF receipt available',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: (doc['color'] as Color),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                isGenerating
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canDelete)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteStudentDoc(
                                _activeStudentId!,
                                doc['id'] as String,
                              ),
                            ),
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _generatingPdf
                                  ? null
                                  : () => _downloadDocument(doc),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: _generatingPdf
                                      ? null
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFF0F766E),
                                            Color(0xFF1A6B4A),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  color: _generatingPdf
                                      ? context.appTheme.surfaceVariant
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      canGenerate
                                          ? Icons.picture_as_pdf_rounded
                                          : (canPreview
                                                ? Icons.visibility_rounded
                                                : Icons.download_rounded),
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      canGenerate
                                          ? 'PDF'
                                          : (canPreview
                                                ? 'Preview'
                                                : 'Download'),
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

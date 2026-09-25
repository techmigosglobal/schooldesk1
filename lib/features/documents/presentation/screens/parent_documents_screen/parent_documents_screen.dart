import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';

import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_child_selector.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/parent/data/api_parent_documents_repository.dart';
import 'package:schooldesk1/roles/parent/domain/parent_documents_repository.dart';

final class _ParentDocumentsSnapshot {
  const _ParentDocumentsSnapshot({
    required this.children,
    required this.documentsByStudent,
  });

  final List<Map<String, dynamic>> children;
  final Map<String, List<Map<String, dynamic>>> documentsByStudent;
}

class ParentDocumentsScreen extends StatefulWidget {
  final ParentDocumentsRepository? repository;

  const ParentDocumentsScreen({super.key, this.repository});

  @override
  State<ParentDocumentsScreen> createState() => _ParentDocumentsScreenState();
}

class _ParentDocumentsScreenState extends State<ParentDocumentsScreen> {
  ParentDocumentsRepository get _repository =>
      widget.repository ?? ApiParentDocumentsRepository.legacyDefault;

  int _selectedNavIndex = ParentNav.documents;
  int _activeChildIndex = 0;
  bool _generatingPdf = false;
  String? _generatingDocName;

  List<Map<String, dynamic>> _children = [];
  final Map<String, List<Map<String, dynamic>>> _docsByStudent = {};
  RepositoryState<_ParentDocumentsSnapshot> _repositoryState =
      const RepositoryState.loading();
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
      final childrenResult = await _repository.loadChildren(
        refreshNonce: DateTime.now().millisecondsSinceEpoch,
      );
      _throwIfFailed(childrenResult, 'Unable to load linked students');
      final children = childrenResult.dataOrNull!;
      Map<String, dynamic> school = const {};
      String parentName = '';
      final schoolResult = await _repository.loadSchool();
      if (schoolResult.isSuccess) school = schoolResult.dataOrNull!;
      final profileResult = await _repository.loadProfile();
      if (profileResult.isSuccess) {
        parentName = profileResult.dataOrNull!.name.trim();
      }
      final docs = <String, List<Map<String, dynamic>>>{};
      for (final child in children) {
        final studentId = (child['id'] ?? '').toString();
        if (studentId.isEmpty) continue;
        final rowsResult = await _repository.loadStudentDocuments(studentId);
        if (rowsResult.isFailure) continue;
        final rows = rowsResult.dataOrNull!;
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
                'admissionNo':
                    row['admission_number'] ??
                    child['admission_number'] ??
                    child['student_id_number'],
                'academicYear':
                    row['academic_year_label'] ??
                    row['academic_year_name'] ??
                    row['academic_year'],
                'feePeriod':
                    row['fee_period'] ??
                    row['billing_period'] ??
                    row['installment'] ??
                    row['term'],
                'counterNo': row['counter_no'],
                'bankName': row['bank_name'],
                'transactionRef':
                    row['transaction_ref'] ??
                    row['transaction_id'] ??
                    row['reference_number'],
                'concessionAmount':
                    row['concession_amount'] ?? row['discount_amount'] ?? 0,
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
        _repositoryState = RepositoryState(
          data: _ParentDocumentsSnapshot(
            children: List.unmodifiable(children),
            documentsByStudent: Map.unmodifiable(docs),
          ),
          source: RepositorySource.remote,
          phase: children.isEmpty
              ? RepositoryPhase.empty
              : RepositoryPhase.ready,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _repositoryState = previous.hasData
            ? RepositoryState(
                data: previous.data,
                source: RepositorySource.cache,
                isStale: true,
                error: e,
                lastUpdated: previous.lastUpdated,
              )
            : RepositoryState.error(error: e);
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
              _school['address_line2'],
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
    final assets = await Future.wait([
      _networkImageBytes('${_school['logo_url'] ?? ''}'),
      _networkImageBytes('${_school['authorized_signature_url'] ?? ''}'),
    ]);

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
      schoolLogo: assets[0],
      authorizedSignature: assets[1],
      authorizedSignatoryName: '${_school['principal_name'] ?? ''}'.trim(),
      transactionReference: '${doc['transactionRef'] ?? ''}'.trim(),
      admissionNo: '${doc['admissionNo'] ?? rollNo}'.trim(),
      academicYear: '${doc['academicYear'] ?? ''}'.trim(),
      feePeriod: '${doc['feePeriod'] ?? ''}'.trim(),
      counterNo: '${doc['counterNo'] ?? ''}'.trim(),
      bankName: '${doc['bankName'] ?? ''}'.trim(),
      concessionAmount: (doc['concessionAmount'] as num?)?.toDouble() ?? 0,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(pdfBytes),
      name: 'FeeReceipt_${childName}_$termLabel',
    );
  }

  Future<Uint8List?> _networkImageBytes(String url) async {
    if (url.trim().isEmpty) return null;
    try {
      return (await NetworkAssetBundle(
        Uri.parse(url),
      ).load(url)).buffer.asUint8List();
    } on Object {
      return null;
    }
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
      final result = await _repository.deleteStudentDocument(docId);
      _throwIfFailed(result, 'Unable to delete document');
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
                        if (result.isNotEmpty) {
                          setDialogState(() {
                            selectedFile = result.first;
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
                        final uploadResult = await _repository.uploadDocument(
                          selectedFile!.path!,
                          filename: selectedFile!.name,
                        );
                        _throwIfFailed(
                          uploadResult,
                          'Unable to upload document',
                        );
                        final createResult = await _repository
                            .createStudentDocument(
                              type: docType,
                              title: titleCtrl.text.trim().isEmpty
                                  ? docType
                                  : titleCtrl.text.trim(),
                              fileUrl: uploadResult.dataOrNull!,
                              studentId: studentId,
                            );
                        _throwIfFailed(createResult, 'Unable to save document');
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

  void _throwIfFailed<T>(Result<T> result, String fallback) {
    if (result.isFailure) {
      throw StateError(result.failureOrNull?.message ?? fallback);
    }
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
      body: SchoolDeskRepositoryStateView<_ParentDocumentsSnapshot>(
        state: _repositoryState,
        onRetry: _loadData,
        emptyTitle: 'No linked students',
        emptyMessage:
            'Ask the school admin to link students to this parent account.',
        errorTitle: 'Unable to load documents',
        data: (_) => Column(
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

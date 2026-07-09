import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ParentDocumentsScreen extends StatefulWidget {
  const ParentDocumentsScreen({super.key});

  @override
  State<ParentDocumentsScreen> createState() => _ParentDocumentsScreenState();
}

class _ParentDocumentsScreenState extends State<ParentDocumentsScreen> {
  int _selectedNavIndex = ParentNav.documents;
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);
  bool _generatingPdf = false;
  String? _generatingDocName;

  List<Map<String, dynamic>> _children = [];
  final Map<String, List<Map<String, dynamic>>> _docsByStudent = {};
  bool _loading = true;
  String? _error;

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

  String get _activeClassName =>
      '${_activeChild['class'] ?? _activeChild['current_section_id'] ?? ''}';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final children = await BackendApiClient.instance.getMyStudents();
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
                'name': row['doc_type'] ?? 'Document',
                'type': row['doc_type'] ?? 'Document',
                'icon': Icons.description_rounded,
                'color': context.appTheme.primary,
                'available': true,
                'size': '',
                'docType': row['doc_type'] ?? 'document',
                'fileUrl': row['file_url'] ?? '',
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
        _activeChildIndex = selectedIndex;
        _docsByStudent
          ..clear()
          ..addAll(docs);
        _loading = false;
      });
    } catch (e) {
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
      if (docType == 'fee_receipt') {
        await _generateFeeReceiptPdf(doc);
      } else {
        // For ID cards and other docs, show a snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${doc['name']} downloaded successfully!'),
              backgroundColor: context.appTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate document. Please try again.'),
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

    final pdfBytes = await pdfService.generateFeeReceipt(
      receiptNo: doc['receiptNo'] as String? ?? '${doc['id'] ?? ''}',
      studentName: childName,
      className: _activeClassName,
      rollNo: '',
      parentName: '',
      feeItems: [
        {'description': termLabel, 'amount': amount},
      ],
      totalAmount: amount,
      paidAmount: amount,
      balance: 0.0,
      paymentMode: '',
      paymentDate: DateTime.now(),
      schoolName: '',
      schoolAddress: '',
    );

    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(pdfBytes),
      name: 'FeeReceipt_${childName}_$termLabel',
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
      child: Row(
        children: List.generate(_children.length, (i) {
          final isActive = i == _activeChildIndex;
          return GestureDetector(
            onTap: () {
              setState(() => _activeChildIndex = i);
              ParentChildSelectionService.saveIndex(_children, i);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? _headerColor
                    : context.appTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_children[i]['name'] ?? _children[i]['first_name'] ?? 'Student'}'
                    .split(' ')
                    .first,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : context.appTheme.onSurface,
                ),
              ),
            ),
          );
        }),
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
        final canGenerate = isFeeReceipt;

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
                    : Material(
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
                                      : Icons.download_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  canGenerate ? 'PDF' : 'Download',
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
          ),
        );
      },
    );
  }
}

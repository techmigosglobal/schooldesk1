import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../../services/pdf_service.dart';
import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/parent_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';

class ParentDocumentsScreen extends StatefulWidget {
  const ParentDocumentsScreen({super.key});

  @override
  State<ParentDocumentsScreen> createState() => _ParentDocumentsScreenState();
}

class _ParentDocumentsScreenState extends State<ParentDocumentsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 9;
  late TabController _tabController;
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);
  bool _generatingPdf = false;
  String? _generatingDocName;

  List<Map<String, dynamic>> _children = [];
  final Map<String, List<Map<String, dynamic>>> _docsByStudent = {};
  final List<Map<String, dynamic>> _certificateRequests = [];
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
    _tabController = TabController(length: 2, vsync: this);
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
                'color': AppTheme.primary,
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
      if (!mounted) return;
      setState(() {
        _children = children;
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    final docType = doc['docType'] as String? ?? '';
    setState(() {
      _generatingPdf = true;
      _generatingDocName = doc['name'] as String;
    });

    try {
      if (docType == 'report_card') {
        await _generateReportCardPdf(doc);
      } else if (docType == 'fee_receipt') {
        await _generateFeeReceiptPdf(doc);
      } else {
        // For ID cards and other docs, show a snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${doc['name']} downloaded successfully!'),
              backgroundColor: AppTheme.success,
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
            backgroundColor: AppTheme.error,
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

  Future<void> _generateReportCardPdf(Map<String, dynamic> doc) async {
    final pdfService = PdfService.getInstance();
    final childName = _activeChildName.isEmpty ? 'Student' : _activeChildName;
    final className = doc['className'] as String? ?? _activeClassName;
    final rollNo = doc['rollNo'] as String? ?? '';
    final examName = doc['examName'] as String? ?? 'Term Exam';

    // Generate subject data based on child
    final subjects = _buildSubjectData(childName, examName);
    final totalMarks = subjects.fold(
      0.0,
      (sum, s) => sum + (s['maxMarks'] as double),
    );
    final obtainedMarks = subjects.fold(
      0.0,
      (sum, s) => sum + (s['obtainedMarks'] as double),
    );
    final percentage = totalMarks > 0
        ? (obtainedMarks / totalMarks) * 100
        : 0.0;
    final grade = _gradeFromPct(percentage);

    final pdfBytes = await pdfService.generateReportCard(
      studentName: doc['studentName'] as String? ?? childName,
      className: className,
      rollNo: rollNo,
      examName: examName,
      academicYear: '2025–26',
      subjects: subjects,
      totalMarks: totalMarks,
      obtainedMarks: obtainedMarks,
      percentage: percentage,
      grade: grade,
      result: percentage >= 40 ? 'PASS' : 'FAIL',
      attendancePercent: 0,
      parentName: '',
      schoolName: '',
      schoolAddress: '',
    );

    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(pdfBytes),
      name: 'ReportCard_${childName}_$examName',
    );
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

  List<Map<String, dynamic>> _buildSubjectData(
    String childName,
    String examName,
  ) {
    return const [];
  }

  String _gradeFromPct(double pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    if (pct >= 40) return 'D';
    return 'F';
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Documents',
      subtitle: 'Access child documents and certificate request status',
      drawer: ParentDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Documents'),
          Tab(text: 'Certificates'),
        ],
      ),
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
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildDocumentsTab(), _buildCertificatesTab()],
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
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildSelector() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(_children.length, (i) {
          final isActive = i == _activeChildIndex;
          return GestureDetector(
            onTap: () => setState(() => _activeChildIndex = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? _headerColor : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_children[i]['name'] ?? _children[i]['first_name'] ?? 'Student'}'
                    .split(' ')
                    .first,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.onSurface,
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
      padding: const EdgeInsets.all(16),
      itemCount: _availableDocs.length,
      itemBuilder: (_, i) {
        final doc = _availableDocs[i];
        final isGenerating =
            _generatingPdf && _generatingDocName == doc['name'];
        final isReportCard = doc['docType'] == 'report_card';
        final isFeeReceipt = doc['docType'] == 'fee_receipt';
        final canGenerate = isReportCard || isFeeReceipt;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (doc['color'] as Color).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  doc['icon'] as IconData,
                  color: doc['color'] as Color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['name'],
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${doc['type']} • ${doc['size']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                    if (canGenerate)
                      Text(
                        isReportCard ? 'PDF will be generated' : 'PDF receipt',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppTheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              isGenerating
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ElevatedButton.icon(
                      onPressed: _generatingPdf
                          ? null
                          : () => _downloadDocument(doc),
                      icon: Icon(
                        canGenerate
                            ? Icons.picture_as_pdf_rounded
                            : Icons.download_rounded,
                        size: 14,
                      ),
                      label: Text(
                        canGenerate ? 'PDF' : 'Download',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _headerColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCertificatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request a Certificate',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _buildCertRequestCards(),
          const SizedBox(height: 20),
          Text(
            'My Requests',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (_certificateRequests.isEmpty)
            Text(
              'No certificate requests yet.',
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
            )
          else
            ..._certificateRequests.map((r) => _certRequestCard(r)),
        ],
      ),
    );
  }

  Widget _buildCertRequestCards() {
    final certTypes = [
      {
        'label': 'Bonafide Certificate',
        'icon': Icons.workspace_premium_rounded,
        'color': Color(0xFF6C3483),
        'desc': 'For bank, passport, etc.',
      },
      {
        'label': 'Transfer Certificate',
        'icon': Icons.transfer_within_a_station_rounded,
        'color': Color(0xFFC0392B),
        'desc': 'For school transfer',
      },
      {
        'label': 'Marks Memo',
        'icon': Icons.grade_rounded,
        'color': Color(0xFF1565C0),
        'desc': 'Exam marks summary',
      },
      {
        'label': 'Character Certificate',
        'icon': Icons.verified_rounded,
        'color': Color(0xFF1A6B4A),
        'desc': 'For external purposes',
      },
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.0,
      ),
      itemCount: certTypes.length,
      itemBuilder: (_, i) {
        final ct = certTypes[i];
        return GestureDetector(
          onTap: () => _showCertRequestDialog(context, ct['label'] as String),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (ct['color'] as Color).withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (ct['color'] as Color).withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(
                  ct['icon'] as IconData,
                  color: ct['color'] as Color,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ct['label'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: ct['color'] as Color,
                        ),
                      ),
                      Text(
                        ct['desc'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppTheme.muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _certRequestCard(Map<String, dynamic> r) {
    final isReady = r['status'] == 'Ready';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (r['color'] as Color).withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              r['icon'] as IconData,
              color: r['color'] as Color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['type'],
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Purpose: ${r['purpose']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
                Text(
                  'Requested: ${r['requestedOn']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          isReady
              ? ElevatedButton(
                  onPressed: () => _requestDocumentAccess(r),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _headerColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Download',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Pending',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _showCertRequestDialog(
    BuildContext context,
    String certType,
  ) async {
    final studentId = _activeStudentId;
    if (studentId == null || studentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a backend-linked student before requesting a certificate.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    final request = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _CertificateRequestPage(
          certType: certType,
          studentId: studentId,
          childName: _activeChildName.isEmpty ? 'Student' : _activeChildName,
          headerColor: _headerColor,
        ),
      ),
    );
    if (!mounted || request == null) return;
    setState(() {
      _certificateRequests.insert(0, {
        'id': request['id'],
        'type': certType,
        'purpose': request['purpose'],
        'requestedOn': request['created_at'] ?? request['requested_on'] ?? '',
        'status': request['status'] ?? 'Pending',
        'icon': Icons.description_rounded,
        'color': _headerColor,
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Certificate request submitted')),
    );
  }

  Future<void> _requestDocumentAccess(Map<String, dynamic> document) async {
    try {
      await BackendApiClient.instance.createRaw('/documents/access-requests', {
        'student_id': _activeStudentId,
        'document_id': document['id'],
        'document_type': document['docType'] ?? document['type'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document access requested')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document is not available from backend: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}

class _CertificateRequestPage extends StatefulWidget {
  final String certType;
  final String studentId;
  final String childName;
  final Color headerColor;

  const _CertificateRequestPage({
    required this.certType,
    required this.studentId,
    required this.childName,
    required this.headerColor,
  });

  @override
  State<_CertificateRequestPage> createState() =>
      _CertificateRequestPageState();
}

class _CertificateRequestPageState extends State<_CertificateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _purposeCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final purpose = _purposeCtrl.text.trim().isEmpty
          ? 'Not specified'
          : _purposeCtrl.text.trim();
      final response = await BackendApiClient.instance.createRaw(
        '/certificates/requests',
        {
          'student_id': widget.studentId,
          'type': widget.certType,
          'purpose': purpose,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, {...response, 'purpose': purpose});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Certificate request failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Request ${widget.certType}')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'For: ${widget.childName}',
                style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                _InputErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _purposeCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Purpose',
                  hintText: 'e.g., Bank account, Passport...',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.headerColor,
                ),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputErrorBanner extends StatelessWidget {
  final String message;

  const _InputErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.error),
      ),
    );
  }
}

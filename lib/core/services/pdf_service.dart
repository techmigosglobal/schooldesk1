import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// The two fee documents have deliberately different semantics. An account
/// statement describes a student's entire fee position; a payment receipt is
/// evidence for one finalized payment.
enum FeeDocumentKind { accountStatement, paymentReceipt, feeInvoice }

/// PDF generation service for receipts, marksheets, ID cards, and reports.
class PdfService {
  static PdfService? _instance;
  static Future<pw.ThemeData>? _pdfThemeFuture;

  static PdfService getInstance() {
    _instance ??= PdfService._();
    return _instance!;
  }

  PdfService._();

  // ─── Color constants ─────────────────────────────────────────────────────
  static const PdfColor _primaryColor = PdfColor.fromInt(0xFF1B4F72);
  static const PdfColor _accentColor = PdfColor.fromInt(0xFF1E8449);
  static const PdfColor _lightGray = PdfColor.fromInt(0xFFF4F6F8);
  static const PdfColor _darkText = PdfColor.fromInt(0xFF1A2332);
  static const PdfColor _mutedText = PdfColor.fromInt(0xFF718096);

  Future<pw.Document> _createDocument() async {
    final theme = await _loadPdfTheme();
    return pw.Document(theme: theme);
  }

  Future<pw.ThemeData> _loadPdfTheme() {
    return _pdfThemeFuture ??= () async {
      final regular = pw.Font.ttf(
        await rootBundle.load('assets/google_fonts/DMSans-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/google_fonts/DMSans-Bold.ttf'),
      );
      final italic = pw.Font.ttf(
        await rootBundle.load('assets/google_fonts/DMSans-Italic.ttf'),
      );
      final boldItalic = pw.Font.ttf(
        await rootBundle.load('assets/google_fonts/DMSans-BoldItalic.ttf'),
      );
      return pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: italic,
        boldItalic: boldItalic,
      );
    }();
  }

  // ─── Student Directory ───────────────────────────────────────────────────

  Future<Uint8List> generateStudentDirectoryReport({
    required String title,
    required List<Map<String, String>> students,
    Map<String, String> filters = const {},
    DateTime? generatedAt,
  }) async {
    final pdf = await _createDocument();
    final generated = generatedAt ?? DateTime.now();
    final tableRows = students.isEmpty
        ? <List<String>>[
            ['No students found', '', '', '', '', '', ''],
          ]
        : students
              .map(
                (student) => [
                  student['name'] ?? '',
                  student['admission'] ?? '',
                  student['systemId'] ?? '',
                  student['classSection'] ?? '',
                  student['gender'] ?? '',
                  student['dateOfBirth'] ?? '',
                  student['status'] ?? '',
                ],
              )
              .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(generated)}',
                    style: const pw.TextStyle(fontSize: 9, color: _mutedText),
                  ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: _lightGray,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  '${students.length} student${students.length == 1 ? '' : 's'}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkText,
                  ),
                ),
              ),
            ],
          ),
          if (filters.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Wrap(
              spacing: 8,
              runSpacing: 6,
              children: filters.entries
                  .map(
                    (entry) => pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _lightGray),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        '${entry.key}: ${entry.value}',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: _darkText,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: const [
              'Student',
              'Admission / Roll',
              'System ID',
              'Class / Section',
              'Gender',
              'DOB',
              'Status',
            ],
            data: tableRows,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerDecoration: const pw.BoxDecoration(color: _primaryColor),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8, color: _darkText),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 6,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: const {
              0: pw.FlexColumnWidth(2.1),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.3),
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1.2),
              6: pw.FlexColumnWidth(1),
            },
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─── Fee Receipt ─────────────────────────────────────────────────────────

  Future<Uint8List> generateFeeReceipt({
    FeeDocumentKind documentKind = FeeDocumentKind.paymentReceipt,
    required String receiptNo,
    required String studentName,
    required String className,
    required String rollNo,
    required String parentName,
    required List<Map<String, dynamic>> feeItems,
    required double totalAmount,
    required double paidAmount,
    required double balance,
    required String paymentMode,
    required DateTime paymentDate,
    String schoolName = '',
    String schoolAddress = '',
    Uint8List? schoolLogo,
    Uint8List? authorizedSignature,
    String authorizedSignatoryName = '',
    String transactionReference = '',
    double? thisPaymentAmount,
  }) async {
    final pdf = await _createDocument();
    final isAccountStatement = documentKind == FeeDocumentKind.accountStatement;
    final isInvoice = documentKind == FeeDocumentKind.feeInvoice;
    final documentTitle = isAccountStatement
        ? 'FEE ACCOUNT STATEMENT'
        : isInvoice
        ? 'FEE INVOICE'
        : 'FEE RECEIPT';
    final documentNumberLabel = isAccountStatement
        ? 'Statement No.'
        : isInvoice
        ? 'Invoice No.'
        : 'Receipt No.';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                _buildReceiptHeader(schoolName, schoolAddress, schoolLogo),
                pw.SizedBox(height: 16),
                _buildDivider(),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    documentTitle,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                _buildDivider(),
                pw.SizedBox(height: 16),
                // Receipt info row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoPair(documentNumberLabel, receiptNo),
                    _buildInfoPair(
                      'Date',
                      DateFormat('dd MMM yyyy').format(paymentDate),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                // Student info
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: _lightGray,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'STUDENT DETAILS',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _mutedText,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: _buildInfoPair('Name', studentName),
                          ),
                          pw.Expanded(
                            child: _buildInfoPair('Class', className),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: _buildInfoPair(
                              isAccountStatement
                                  ? 'Student ID / Roll No.'
                                  : 'Roll No.',
                              rollNo,
                            ),
                          ),
                          if (!isAccountStatement)
                            pw.Expanded(
                              child: _buildInfoPair('Parent', parentName),
                            )
                          else
                            pw.Spacer(),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                // Fee table
                pw.Text(
                  'FEE DETAILS',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _mutedText,
                  ),
                ),
                pw.SizedBox(height: 8),
                _buildFeeTable(
                  feeItems,
                  receiptLayout: !isAccountStatement && !isInvoice,
                ),
                pw.SizedBox(height: 12),
                // Totals
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: _lightGray,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      _buildAmountRow(
                        'Total Amount',
                        '₹${totalAmount.toStringAsFixed(2)}',
                      ),
                      pw.SizedBox(height: 4),
                      _buildAmountRow(
                        isInvoice ? 'Paid to Date' : 'Cumulative Paid',
                        '₹${paidAmount.toStringAsFixed(2)}',
                        color: _accentColor,
                      ),
                      pw.SizedBox(height: 4),
                      _buildDivider(),
                      pw.SizedBox(height: 4),
                      _buildAmountRow(
                        'Balance Due',
                        '₹${balance.toStringAsFixed(2)}',
                        isBold: true,
                        color: balance > 0 ? PdfColors.red : _accentColor,
                      ),
                    ],
                  ),
                ),
                if (!isAccountStatement && !isInvoice) ...[
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _primaryColor, width: 0.7),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PAYMENT INFORMATION',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: _buildInfoPair(
                                'Amount Received',
                                '₹${(thisPaymentAmount ?? paidAmount).toStringAsFixed(2)}',
                              ),
                            ),
                            pw.Expanded(
                              child: _buildInfoPair(
                                'Payment Method',
                                paymentMode,
                              ),
                            ),
                            if (transactionReference.trim().isNotEmpty)
                              pw.Expanded(
                                child: _buildInfoPair(
                                  'Reference / Cheque No.',
                                  transactionReference.trim(),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Amount in words: ${_amountInWords(thisPaymentAmount ?? paidAmount)} only.',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                ],
                pw.SizedBox(height: 24),
                _buildDivider(),
                pw.SizedBox(height: 8),
                if (authorizedSignature == null)
                  pw.Center(
                    child: pw.Text(
                      'This is a computer-generated receipt and does not require a physical signature.',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 9, color: _mutedText),
                    ),
                  )
                else
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'This is a computer-generated receipt.',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: _mutedText,
                        ),
                      ),
                      pw.Column(
                        children: [
                          pw.Image(
                            pw.MemoryImage(authorizedSignature),
                            width: 104,
                            height: 42,
                            fit: pw.BoxFit.contain,
                          ),
                          if (authorizedSignatoryName.trim().isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              authorizedSignatoryName.trim(),
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ],
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Authorised Signatory',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                if (!isAccountStatement && !isInvoice) ...[
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(
                      'Parent Copy • Keep this receipt for your records',
                      style: const pw.TextStyle(fontSize: 8, color: _mutedText),
                    ),
                  ),
                ],
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ─── Attendance Report ────────────────────────────────────────────────────

  Future<Uint8List> generateAttendanceReport({
    required String className,
    required String month,
    required List<Map<String, dynamic>> students,
    String schoolName = 'Public School',
  }) async {
    final pdf = await _createDocument();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildReceiptHeader(schoolName, ''),
              pw.SizedBox(height: 16),
              _buildDivider(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'ATTENDANCE REPORT - $month',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Class: $className',
                  style: const pw.TextStyle(fontSize: 12, color: _mutedText),
                ),
              ),
              pw.SizedBox(height: 16),
              _buildAttendanceTable(students),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generatePrincipalSummaryReport({
    required String reportTitle,
    required String period,
    required int totalStudents,
    required int totalStaff,
    required String attendanceAverage,
    required double totalBilled,
    required double totalCollected,
    required List<Map<String, dynamic>> staffRows,
    String schoolName = 'Public School',
  }) async {
    final pdf = await _createDocument();
    final pending = totalBilled - totalCollected;
    final collectionRate = totalBilled > 0
        ? (totalCollected / totalBilled * 100)
        : 0.0;
    final activeStaff = staffRows
        .where((s) => '${s['status'] ?? ''}'.toLowerCase() == 'active')
        .length;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildReceiptHeader(schoolName, ''),
              pw.SizedBox(height: 16),
              _buildDivider(),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  reportTitle.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  period,
                  style: const pw.TextStyle(fontSize: 12, color: _mutedText),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'School KPIs',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkText,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildPrincipalSummaryTable([
                ['Total students', totalStudents.toString()],
                ['Total staff', totalStaff.toString()],
                ['Avg attendance', attendanceAverage],
                ['Fee collection', '${collectionRate.toStringAsFixed(1)}%'],
              ]),
              pw.SizedBox(height: 16),
              pw.Text(
                'Fee Snapshot',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkText,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildPrincipalSummaryTable([
                ['Total billed', _formatInr(totalBilled)],
                ['Collected', _formatInr(totalCollected)],
                ['Pending', _formatInr(pending < 0 ? 0 : pending)],
              ]),
              pw.SizedBox(height: 16),
              pw.Text(
                'Staff Snapshot',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkText,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildPrincipalSummaryTable([
                ['Active staff', activeStaff.toString()],
                ['Inactive staff', (totalStaff - activeStaff).toString()],
              ]),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ─── ID Card ──────────────────────────────────────────────────────────────

  Future<Uint8List> generateIdCard({
    required String studentName,
    required String className,
    required String rollNo,
    required String admissionNo,
    required String parentName,
    required String contactNo,
    required String bloodGroup,
    required String academicYear,
    String schoolName = 'Public School',
    String schoolAddress = '123 Education Lane, Knowledge City',
    String schoolContact = '+91 98765 43210',
  }) async {
    final pdf = await _createDocument();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          85.6 * PdfPageFormat.mm,
          54 * PdfPageFormat.mm,
        ),
        margin: const pw.EdgeInsets.all(8),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _primaryColor, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                // Header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: _primaryColor,
                    borderRadius: pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(6),
                      topRight: pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        schoolName,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.Text(
                        'STUDENT ID CARD — $academicYear',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
                // Body
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Row(
                      children: [
                        // Photo placeholder
                        pw.Container(
                          width: 50,
                          height: 60,
                          decoration: pw.BoxDecoration(
                            color: _lightGray,
                            border: pw.Border.all(color: _primaryColor),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              studentName.isNotEmpty
                                  ? studentName[0].toUpperCase()
                                  : 'S',
                              style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        // Details
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text(
                                studentName,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _darkText,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              _buildIdRow('Class', className),
                              _buildIdRow('Roll No.', rollNo),
                              _buildIdRow('Adm. No.', admissionNo),
                              _buildIdRow('Blood Grp', bloodGroup),
                              _buildIdRow('Parent', parentName),
                              _buildIdRow('Contact', contactNo),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: _lightGray,
                    borderRadius: pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(6),
                      bottomRight: pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Text(
                    schoolAddress,
                    style: const pw.TextStyle(fontSize: 7, color: _mutedText),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // ─── Helper builders ─────────────────────────────────────────────────────

  pw.Widget _buildReceiptHeader(
    String schoolName,
    String address, [
    Uint8List? schoolLogo,
  ]) {
    return pw.Row(
      children: [
        pw.Container(
          width: 48,
          height: 48,
          decoration: pw.BoxDecoration(
            color: _primaryColor,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: schoolLogo == null
              ? pw.Center(
                  child: pw.Text(
                    'SD',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                )
              : pw.ClipRRect(
                  horizontalRadius: 8,
                  verticalRadius: 8,
                  child: pw.Image(
                    pw.MemoryImage(schoolLogo),
                    fit: pw.BoxFit.cover,
                  ),
                ),
        ),
        pw.SizedBox(width: 12),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              schoolName,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            if (address.isNotEmpty)
              pw.Text(
                address,
                style: const pw.TextStyle(fontSize: 9, color: _mutedText),
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildDivider() {
    return pw.Divider(color: _lightGray, thickness: 1);
  }

  pw.Widget _buildInfoPair(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: _mutedText),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _darkText,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFeeTable(
    List<Map<String, dynamic>> items, {
    bool receiptLayout = false,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: _lightGray),
      columnWidths: receiptLayout
          ? const {
              0: pw.FlexColumnWidth(0.55),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(1),
            }
          : const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
            },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _primaryColor),
          children: [
            if (receiptLayout) _tableCell('No.', isHeader: true),
            _tableCell(
              receiptLayout ? 'Fee Particulars' : 'Description',
              isHeader: true,
            ),
            _tableCell('Amount', isHeader: true),
            if (!receiptLayout) _tableCell('Status', isHeader: true),
          ],
        ),
        ...items.asMap().entries.map(
          (entry) => pw.TableRow(
            decoration: pw.BoxDecoration(
              color: entry.key.isOdd ? _lightGray : PdfColors.white,
            ),
            children: [
              if (receiptLayout) _tableCell('${entry.key + 1}'),
              _tableCell(entry.value['description'] as String? ?? ''),
              _tableCell('₹${entry.value['amount']}'),
              if (!receiptLayout)
                _tableCell(entry.value['status'] as String? ?? 'Paid'),
            ],
          ),
        ),
      ],
    );
  }

  String _amountInWords(double amount) {
    final rounded = amount.round();
    if (rounded == 0) return 'Zero rupees';
    const ones = [
      '',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen',
    ];
    const tens = [
      '',
      '',
      'twenty',
      'thirty',
      'forty',
      'fifty',
      'sixty',
      'seventy',
      'eighty',
      'ninety',
    ];
    String belowThousand(int value) {
      final parts = <String>[];
      if (value >= 100) {
        parts.add('${ones[value ~/ 100]} hundred');
        value %= 100;
      }
      if (value >= 20) {
        parts.add(tens[value ~/ 10]);
        value %= 10;
      }
      if (value > 0) parts.add(ones[value]);
      return parts.join(' ');
    }

    final parts = <String>[];
    var value = rounded;
    if (value >= 10000000) {
      parts.add('${belowThousand(value ~/ 10000000)} crore');
      value %= 10000000;
    }
    if (value >= 100000) {
      parts.add('${belowThousand(value ~/ 100000)} lakh');
      value %= 100000;
    }
    if (value >= 1000) {
      parts.add('${belowThousand(value ~/ 1000)} thousand');
      value %= 1000;
    }
    if (value > 0) parts.add(belowThousand(value));
    final words = parts.where((part) => part.isNotEmpty).join(' ');
    return '${words[0].toUpperCase()}${words.substring(1)} rupees';
  }

  pw.Widget _buildAttendanceTable(List<Map<String, dynamic>> students) {
    return pw.Table(
      border: pw.TableBorder.all(color: _lightGray),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _primaryColor),
          children: [
            _tableCell('#', isHeader: true),
            _tableCell('Student Name', isHeader: true),
            _tableCell('Present', isHeader: true),
            _tableCell('Absent', isHeader: true),
            _tableCell('Total', isHeader: true),
            _tableCell('%', isHeader: true),
          ],
        ),
        ...students.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final s = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i % 2 == 0 ? _lightGray : PdfColors.white,
            ),
            children: [
              _tableCell(i.toString()),
              _tableCell(s['name'] as String? ?? ''),
              _tableCell(s['present']?.toString() ?? '0'),
              _tableCell(s['absent']?.toString() ?? '0'),
              _tableCell(s['total']?.toString() ?? '0'),
              _tableCell('${s['percentage'] ?? 0}%'),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildPrincipalSummaryTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: _lightGray),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
      },
      children: rows
          .map(
            (row) =>
                pw.TableRow(children: [_tableCell(row[0]), _tableCell(row[1])]),
          )
          .toList(),
    );
  }

  String _formatInr(double value) {
    return 'INR ${NumberFormat.decimalPattern('en_IN').format(value.round())}';
  }

  pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : _darkText,
        ),
      ),
    );
  }

  pw.Widget _buildAmountRow(
    String label,
    String value, {
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: _darkText,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? _darkText,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildIdRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        children: [
          pw.Text(
            '$label: ',
            style: const pw.TextStyle(fontSize: 7, color: _mutedText),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _darkText,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Print / Preview ─────────────────────────────────────────────────────

  Future<void> printDocument(Uint8List pdfBytes, String title) async {
    await Printing.layoutPdf(onLayout: (_) async => pdfBytes, name: title);
  }

  Future<void> previewDocument(
    BuildContext context,
    Uint8List pdfBytes,
    String title,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF3F6FA),
          appBar: AppBar(
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                tooltip: 'Print',
                icon: const Icon(Icons.print_rounded),
                onPressed: () => Printing.layoutPdf(
                  onLayout: (_) async => pdfBytes,
                  name: title,
                ),
              ),
              IconButton(
                tooltip: 'Share PDF',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () => Printing.sharePdf(
                  bytes: pdfBytes,
                  filename: _safePdfFileName(title),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Printing.layoutPdf(
              onLayout: (_) async => pdfBytes,
              name: title,
            ),
            icon: const Icon(Icons.print_rounded),
            label: const Text('Print'),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PdfPreview(
                  build: (_) async => pdfBytes,
                  pdfFileName: _safePdfFileName(title),
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  allowPrinting: false,
                  allowSharing: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _safePdfFileName(String title) {
    final clean = title
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return '${clean.isEmpty ? 'document' : clean}.pdf';
  }
}

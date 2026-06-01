import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';

class BulkImportScreen extends StatefulWidget {
  final String ownerRole;
  
  const BulkImportScreen({super.key, this.ownerRole = 'admin'});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  String _selectedImportType = 'student';
  PlatformFile? _selectedFile;
  bool _loading = false;
  bool _dryRun = true;
  bool _showPreview = false;
  
  Map<String, dynamic>? _importResult;
  
  final List<Map<String, String>> _templates = [
    {
      'type': 'student',
      'label': 'Student Import',
      'description': 'Import students with basic information',
    },
    {
      'type': 'staff',
      'label': 'Staff Import',
      'description': 'Import staff members with employment details',
    },
    {
      'type': 'parent',
      'label': 'Parent Import',
      'description': 'Import parents and link to students',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e')),
        );
      }
    }
  }

  Future<void> _performImport({bool dryRun = true}) async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a CSV file')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _importResult = null;
    });

    try {
      final api = BackendApiClient.instance;
      final filePath = _selectedFile!.path;
      if (filePath == null) {
        throw Exception('Cannot read file path');
      }
      
      final result = await api.bulkImport(
        importType: _selectedImportType,
        filePath: filePath,
        dryRun: dryRun,
      );
      
      if (mounted) {
        setState(() {
          _importResult = result;
          _showPreview = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawer = widget.ownerRole == 'principal'
        ? PrincipalDrawer(selectedIndex: 2, onDestinationSelected: (_) {})
        : AdminDrawer(selectedIndex: 11, onDestinationSelected: (_) {});
    
    return SchoolDeskModuleScaffold(
      title: 'Bulk Import Users',
      subtitle: 'Upload CSV files to bulk import students, staff, and parents',
      drawer: drawer,
      floatingActionButton: DashboardFabWidget(
        role: widget.ownerRole == 'principal' 
            ? DashboardRole.principal 
            : DashboardRole.admin,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Main Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Import Type Selection
                  _buildImportTypeSelector(),
                  const SizedBox(height: 32),

                  // File Selection & Preview
                  if (!_showPreview)
                    _buildFileSelectionSection()
                  else
                    _buildPreviewSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Import Type',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _templates.length,
          itemBuilder: (context, index) {
            final template = _templates[index];
            final isSelected = _selectedImportType == template['type'];
            return _buildImportTypeCard(
              template['type']!,
              template['label']!,
              template['description']!,
              isSelected,
            );
          },
        ),
      ],
    );
  }

  Widget _buildImportTypeCard(
    String type,
    String label,
    String description,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedImportType = type;
          _showPreview = false;
          _selectedFile = null;
          _importResult = null;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppTheme.primaryContainer : AppTheme.surface,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isSelected ? AppTheme.primary : AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload CSV File',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _selectFile,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.outlineVariant,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.surfaceVariant,
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.cloud_upload, size: 48, color: AppTheme.primary),
                const SizedBox(height: 16),
                Text(
                  _selectedFile?.name ?? 'Select CSV file',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Drag and drop or click to select',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_selectedFile != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import Options',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _dryRun,
                onChanged: (value) {
                  setState(() {
                    _dryRun = value ?? true;
                  });
                },
                title: const Text('Dry Run (Preview only)'),
                subtitle: const Text('Validate without saving changes'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () => _performImport(dryRun: _dryRun),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(_dryRun ? 'Preview Import' : 'Perform Import'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    if (_importResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final success = _importResult!['success'] ?? false;
    final totalRecords = _importResult!['total_records'] ?? 0;
    final successCount = _importResult!['success_count'] ?? 0;
    final failureCount = _importResult!['failure_count'] ?? 0;
    final errors = _importResult!['errors'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results Summary
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: success ? AppTheme.successContainer : AppTheme.errorContainer,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    success ? Icons.check_circle : Icons.error_outline,
                    color: success ? AppTheme.success : AppTheme.error,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    success ? 'Import Successful' : 'Import Preview',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: success ? AppTheme.success : AppTheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Total: $totalRecords | Success: $successCount | Failed: $failureCount',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Error Details
        if (errors.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Errors (${errors.length})',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: errors.length.clamp(0, 10),
                itemBuilder: (context, index) {
                  final error = errors[index] as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                        color: AppTheme.errorContainer,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Row ${error['row_number'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppTheme.error,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            error['error_msg'] ?? 'Unknown error',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (errors.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '... and ${errors.length - 10} more errors',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showPreview = false;
                    _selectedFile = null;
                    _importResult = null;
                  });
                },
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _loading || _dryRun && failureCount > 0
                    ? null
                    : () => _performImport(dryRun: false),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(_dryRun ? 'Perform Import' : 'Confirm Import'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

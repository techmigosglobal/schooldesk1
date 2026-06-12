# Bulk Import Feature Documentation

## Overview
The Bulk Import feature allows School Principals to efficiently import large numbers of users (Students, Staff, and Parents) into SchoolDesk via CSV file uploads. This feature includes validation, duplicate detection, dry-run preview, and atomic transaction support to ensure data integrity.

## Features

### ✅ Import Types
1. **Student Import** - Import student records with enrollment details
2. **Staff Import** - Import staff members with employment information  
3. **Parent Import** - Import parents and link them to existing students

### ✅ Safety Features
- **Dry-Run Preview** - Preview changes before committing to database
- **Duplicate Detection** - Automatically detects and reports duplicates
- **Atomic Transactions** - All-or-nothing database commits ensure consistency
- **Comprehensive Validation** - Field-level and row-level validation
- **Detailed Error Reports** - Row-by-row error tracking with specific messages

### ✅ CSV Templates
Pre-built templates available for download within the application

## CSV Format Specifications

### Student Import CSV
```csv
first_name,last_name,email,phone,date_of_birth,gender,admission_number,admission_date,current_section_id,address,aadhar_number
John,Doe,john.doe@school.com,9876543210,2010-05-15,M,STU-001,2023-06-01,SEC-001,"123 Main Street, City",123456789012
Jane,Smith,jane.smith@school.com,9876543211,2011-03-20,F,STU-002,2023-06-01,SEC-001,"456 Oak Avenue, City",987654321098
```

**Required Fields:**
- first_name
- last_name
- email
- admission_number

**Optional Fields:**
- phone
- date_of_birth (format: YYYY-MM-DD)
- gender (M/F)
- admission_date (format: YYYY-MM-DD)
- current_section_id (UUID of section)
- address
- aadhar_number

### Staff Import CSV
```csv
first_name,last_name,email,phone,date_of_birth,gender,staff_code,department_id,designation,employment_type,join_date,basic_salary
Rajesh,Kumar,rajesh.kumar@school.com,9876543212,1990-01-15,M,STF-001,DEPT-001,Teacher,Permanent,2020-01-15,45000
Priya,Sharma,priya.sharma@school.com,9876543213,1992-06-20,F,STF-002,DEPT-002,HOD,Permanent,2019-03-01,65000
```

**Required Fields:**
- first_name
- last_name
- email
- staff_code

**Optional Fields:**
- phone
- date_of_birth (format: YYYY-MM-DD)
- gender (M/F)
- department_id (UUID)
- designation
- employment_type (Permanent/Contract/Temporary)
- join_date (format: YYYY-MM-DD)
- basic_salary (numeric value)

### Parent Import CSV
```csv
full_name,email,phone,relationship,occupation,student_admission_number
Mr. Rajesh Kumar,rajesh.kumar@email.com,9876543210,Father,Engineer,STU-001
Mrs. Anjali Kumar,anjali.kumar@email.com,9876543211,Mother,Doctor,STU-001
```

**Required Fields:**
- full_name
- email
- student_admission_number

**Optional Fields:**
- phone
- relationship (Father/Mother/Guardian/etc.)
- occupation

## How to Use

### Step 1: Access Bulk Import
1. Login as Principal
2. Navigate to Admin → Bulk Import

### Step 2: Select Import Type
- Choose between Student, Staff, or Parent import
- Download CSV template for reference

### Step 3: Prepare Your Data
1. Fill in your data following the CSV format
2. Ensure all required fields are present
3. Use correct date format (YYYY-MM-DD)
4. Save file as .csv

### Step 4: Upload File
1. Click "Select CSV File" or drag-drop your file
2. File must be .csv format, max 10MB
3. Max 10,000 records per import

### Step 5: Enable Dry-Run (Recommended)
1. Check "Dry Run (Preview Only)" checkbox
2. Click "Import Users"
3. Review the preview results
4. Check error count and row-by-row errors

### Step 6: Confirm Import
1. If dry-run shows valid data, uncheck "Dry Run"
2. Click "Import Users" to perform actual import
3. All changes committed atomically
4. View import job history

## Validation Rules

### Email Validation
- Must be valid email format
- Must be unique within school
- Cannot already exist in system

### Admission Number Validation (Students)
- Required and must be unique
- Cannot already exist in system

### Staff Code Validation
- Required and must be unique
- Cannot already exist in system

### Date Validation
- Must be in format: YYYY-MM-DD
- Optional field - skip if not needed

### Numeric Fields
- basic_salary: Must be numeric value (can include decimals)
- Invalid numbers will be rejected with specific error message

## API Endpoints

### POST /api/v1/admin/bulk-import
Upload and process bulk import

**Parameters:**
- import_type: "student" | "staff" | "parent"
- dry_run: boolean (true for preview)
- file: CSV file (multipart/form-data)

**Response:**
```json
{
  "success": true,
  "job_id": "job-uuid",
  "import_type": "student",
  "total_records": 100,
  "success_count": 98,
  "failure_count": 2,
  "is_dry_run": false,
  "message": "Successfully imported 98 students",
  "errors": [
    {
      "row_number": 5,
      "error_msg": "Email already exists: existing@school.com"
    }
  ]
}
```

### GET /api/v1/admin/bulk-import/template
Download CSV template

**Parameters:**
- import_type: "student" | "staff" | "parent"

**Response:** CSV file download

### GET /api/v1/admin/bulk-import/history
Fetch import job history

**Parameters:**
- page: integer (default: 1)
- page_size: integer (default: 20)

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "job-uuid",
      "import_type": "student",
      "status": "completed",
      "total_records": 50,
      "success_count": 50,
      "failure_count": 0,
      "initiated_by": "principal-user-id",
      "completed_at": "2024-06-01T10:30:00Z",
      "created_at": "2024-06-01T10:00:00Z"
    }
  ],
  "page": 1,
  "page_size": 20,
  "total": 15,
  "total_pages": 1
}
```

## Security & Permissions

- ✅ **Only Principal role** can perform bulk imports
- ✅ **School-scoped** - All imports limited to user's school
- ✅ **Rate-limited** - Max concurrent imports per user
- ✅ **Audit-logged** - All import operations tracked
- ✅ **Transaction-protected** - Atomic database commits

## Limitations

- Maximum file size: **10 MB**
- Maximum records per import: **10,000**
- Only CSV format supported
- Requires Principal role authentication
- One import type per request

## Troubleshooting

### "Email already exists"
**Solution:** Check for duplicate emails in CSV or already imported records

### "Admission number not found" (Parent Import)
**Solution:** Verify admission number matches existing student record exactly

### "Invalid email format"
**Solution:** Check email format - must be valid (e.g., user@domain.com)

### "Invalid date format"
**Solution:** Use YYYY-MM-DD format for all dates

### "Staff code already exists"
**Solution:** Check for duplicate staff codes in CSV or already imported records

### "File exceeds maximum size"
**Solution:** Split large files into multiple imports

## Best Practices

1. **Always use Dry-Run first** - Verify data before actual import
2. **Download template** - Use official template to ensure correct format
3. **Remove test rows** - Before importing, remove any test/sample data
4. **Backup data** - Keep backup of original data before importing
5. **Import during off-hours** - Schedule bulk imports during low-traffic periods
6. **Verify results** - Check import history and review imported records
7. **Handle errors carefully** - Fix errors and reimport only failed records

## Database Schema

### BulkImportJob Table
Tracks all bulk import operations

```sql
CREATE TABLE bulk_import_jobs (
  id UUID PRIMARY KEY,
  school_id UUID NOT NULL,
  import_type VARCHAR(50) NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  total_records INT,
  success_count INT,
  failure_count INT,
  initiated_by UUID,
  completed_at TIMESTAMP,
  failure_reason TEXT,
  report_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### BulkImportError Table
Tracks individual row errors

```sql
CREATE TABLE bulk_import_errors (
  id UUID PRIMARY KEY,
  import_job_id UUID NOT NULL REFERENCES bulk_import_jobs(id),
  row_number INT,
  error_msg TEXT,
  raw_data TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## Example Workflows

### Workflow 1: Basic Student Import
1. Download student template
2. Fill in student details (10 students)
3. Enable Dry-Run, upload file
4. Review preview - all valid
5. Disable Dry-Run, confirm import
6. 10 students created with auto-generated credentials

### Workflow 2: Staff Import with Errors
1. Download staff template
2. Fill in staff details (20 staff)
3. Enable Dry-Run, upload file
4. Preview shows 2 errors (duplicate emails)
5. Fix errors in CSV locally
6. Re-upload corrected file
7. All 20 staff members imported successfully

### Workflow 3: Parent Linking
1. Student records already in system
2. Download parent template
3. Fill in parent details with admission numbers
4. Dry-Run successful
5. Import parents
6. Parents automatically linked to students via admission number
7. Parent user accounts created with credentials

## Support & Contact

For issues or questions about bulk import:
1. Check troubleshooting section above
2. Review import history for detailed error messages
3. Contact system administrator for access issues
4. Check backend logs for technical errors

## Changelog

### Version 1.0.0 (2024-06-01)
- Initial release
- Support for Student, Staff, Parent bulk import
- Dry-run preview functionality
- Duplicate detection and validation
- Transaction-based import with rollback
- Audit logging
- Rate limiting
- CSV template download
- Import history tracking

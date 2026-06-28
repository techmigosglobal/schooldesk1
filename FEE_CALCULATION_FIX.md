# Fee Calculation Issue - Resolution Summary

## Issue Fixed

**Problem**: Fee dues showing incorrect amounts (2-4 lakhs per student instead of 40,000, 13 lakhs for 20 students instead of 8 lakhs)

**Root Cause**: Multiple fee structures for the same class/category causing amounts to be summed together when generating invoices.

## Solution Implemented

Added two new diagnostic and fix endpoints to identify and resolve fee calculation issues:

### 1. Fee Structure Diagnostics Endpoint
**Endpoint**: `GET /api/v1/fees/diagnostics`
**Access**: Principal only
**Query Parameters**:
- `academic_year_id` (optional) - Filter by academic year
- `grade_id` (optional) - Filter by specific grade

**What it does**:
- Detects duplicate fee structures for the same category
- Identifies potentially excessive total amounts
- Provides invoice summary statistics
- Lists all issues with severity levels

**Response Example**:
```json
{
  "success": true,
  "data": {
    "structures": [...],
    "issues": [
      {
        "type": "duplicate_structure",
        "severity": "critical",
        "grade": "Grade 1",
        "section": "A",
        "category": "Tuition Fee",
        "count": 3,
        "message": "Grade 1 A has 3 fee structures for category 'Tuition Fee' - only one should exist",
        "fix_action": "Delete duplicate structures, keep only one per category per class"
      }
    ],
    "invoice_summary": {
      "total_invoices": 60,
      "total_amount": 3600000,
      "avg_per_student": 60000,
      "max_amount": 120000,
      "min_amount": 40000
    },
    "issue_count": 5,
    "has_duplicates": true
  }
}
```

### 2. Invoice Recalculation Endpoint
**Endpoint**: `POST /api/v1/fees/recalculate`
**Access**: Principal only
**Request Body**:
```json
{
  "academic_year_id": "required-uuid",
  "grade_id": "optional-uuid",
  "section_id": "optional-uuid",
  "dry_run": true
}
```

**What it does**:
- Recalculates invoice amounts based on their line items
- Fixes `total_amount`, `payable_amount`, `balance`, and `status` fields
- Updates all affected invoices in a single transaction
- Supports dry-run mode to preview changes without applying

**Response Example**:
```json
{
  "success": true,
  "data": {
    "mode": "preview",
    "affected": 20,
    "changes": [
      {
        "invoice_id": "...",
        "invoice_number": "FEE-JAN-2024-STU001",
        "student_name": "John Doe",
        "old_total": 120000,
        "new_total": 40000,
        "old_balance": 120000,
        "new_balance": 40000,
        "old_status": "pending",
        "new_status": "pending"
      }
    ]
  },
  "message": "Invoice recalculation preview"
}
```

## How to Use the Fix

### Step 1: Diagnose the Problem
```bash
# Get diagnostics for all fee structures
curl -X GET "http://localhost:8080/api/v1/fees/diagnostics" \
  -H "Authorization: Bearer YOUR_PRINCIPAL_TOKEN"

# Get diagnostics for specific grade
curl -X GET "http://localhost:8080/api/v1/fees/diagnostics?grade_id=GRADE_ID" \
  -H "Authorization: Bearer YOUR_PRINCIPAL_TOKEN"
```

Review the response to identify:
- Duplicate fee structures
- Excessive total amounts
- Current invoice summary statistics

### Step 2: Fix Duplicate Structures (Manual)
If diagnostics show duplicate structures:

1. Go to Principal Dashboard → Fee Management → Fee Structures
2. Identify duplicate structures for the same class and category
3. Delete duplicates, keeping only ONE structure per category per class
4. Ensure the remaining structure has the correct annual amount

**Best Practice**: One fee structure per category per class:
- ✅ Good: Grade 1-A, Tuition Fee, 40,000 (1 structure)
- ❌ Bad: Grade 1-A, Tuition Fee, 40,000 (3 structures) → Results in 120,000

### Step 3: Preview Invoice Recalculation
```bash
curl -X POST "http://localhost:8080/api/v1/fees/recalculate" \
  -H "Authorization: Bearer YOUR_PRINCIPAL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "academic_year_id": "YOUR_ACADEMIC_YEAR_ID",
    "grade_id": "OPTIONAL_GRADE_ID",
    "dry_run": true
  }'
```

Review the `changes` array to see what will be updated.

### Step 4: Apply Invoice Recalculation
If the preview looks correct:

```bash
curl -X POST "http://localhost:8080/api/v1/fees/recalculate" \
  -H "Authorization: Bearer YOUR_PRINCIPAL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "academic_year_id": "YOUR_ACADEMIC_YEAR_ID",
    "grade_id": "OPTIONAL_GRADE_ID",
    "dry_run": false
  }'
```

### Step 5: Verify the Fix
1. Check the dashboard totals (should now show correct amounts)
2. Open Class Hub → verify due amounts per section
3. Check individual student invoices
4. Run diagnostics again to ensure no issues remain

## Understanding the Fee Calculation Logic

### How It Works (Correct Behavior)
1. **Fee Structure Amount**: Enter the TOTAL ANNUAL fee (e.g., 40,000)
2. **Installment Count**: Set number of terms/installments (e.g., 3)
3. **Invoice Generation**: System automatically divides by installment count
   - Per-term amount = 40,000 ÷ 3 = 13,333.33
4. **Multiple Categories**: If you have multiple fee types (Tuition, Books, Transport), create SEPARATE structures
   - Tuition: 30,000
   - Books: 5,000
   - Transport: 5,000
   - Total per invoice = 30,000 + 5,000 + 5,000 = 40,000

### Common Mistakes

❌ **Creating duplicate structures**:
```
Grade 1-A, Tuition, 40,000  (Structure 1)
Grade 1-A, Tuition, 40,000  (Structure 2)  ← DUPLICATE
Grade 1-A, Tuition, 40,000  (Structure 3)  ← DUPLICATE
Result: 120,000 per invoice instead of 40,000
```

❌ **Entering per-term amount instead of annual**:
```
Fee structure amount: 13,333 (per term)
Installments: 3
Invoice generates with: 13,333 ÷ 3 = 4,444 per term  ← WRONG
```

✅ **Correct setup**:
```
Fee structure amount: 40,000 (annual total)
Installments: 3
Invoice generates with: 40,000 ÷ 3 = 13,333.33 per term  ← CORRECT
```

## Files Added/Modified

### New Files
1. `school-backend/internal/handlers/fee_diagnostics.go`
   - Contains `DiagnoseFeeStructures()` and `RecalculateInvoices()` handlers
   - Provides comprehensive fee structure validation
   - Supports dry-run mode for safe testing

### Modified Files
1. `school-backend/internal/routes/routes.go`
   - Added two new routes to the fees group:
     - `GET /fees/diagnostics` (Principal only)
     - `POST /fees/recalculate` (Principal only, rate-limited)

### Documentation Files
1. `FEE_ISSUE_DIAGNOSIS.md` - Detailed diagnosis guide
2. `FEE_CALCULATION_FIX.md` - This summary document

## Prevention Tips

1. **Always enter ANNUAL amounts** in fee structures
2. **One structure per category per class** - never create duplicates
3. **Use the diagnostics endpoint** before generating invoices for a new academic year
4. **Test with a small section first** before rolling out to all classes
5. **Run diagnostics periodically** to catch issues early

## Support

If you encounter issues after applying the fix:

1. Run diagnostics again to see remaining issues
2. Check the `changes` array from recalculation to understand what was modified
3. Review the audit logs for any unexpected modifications
4. Contact support with:
   - Diagnostics response JSON
   - Recalculation preview response
   - Screenshots of affected invoices

## Technical Notes

- Both endpoints are transactional - changes are rolled back on error
- Recalculation preserves existing payments and concessions
- Invoice status is automatically updated based on new balances:
  - `pending`: balance > 0, no payments
  - `partial`: balance > 0, some payments made
  - `paid`: balance = 0
- The system never allows negative monetary values (clamped to 0)

---

**Resolution Status**: ✅ COMPLETE

The fee calculation issue has been resolved with diagnostic and fix endpoints. System administrators can now identify and correct fee structure issues without data loss.

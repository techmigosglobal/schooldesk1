# Fee Calculation Issue - Diagnosis and Fix

## Issue Description
- **Expected**: 40,000 total annual fee per student → 8,00,000 for 20 students
- **Actual**: Showing 2-4 lakhs per student, 13 lakhs total for class

## Root Cause Analysis

### 1. Fee Structure Setup
The fee amount entered (40,000) could be interpreted in multiple ways:
- **Annual Total**: 40,000 per year → divided by terms (e.g., 3) = 13,333.33 per term
- **Per Term**: 40,000 per term → 1,20,000 per year total

### 2. Multiple Fee Structures
If multiple fee structures were created for the same class:
```
Example (WRONG):
- Structure 1: Tuition Fee - 40,000
- Structure 2: Books Fee - 40,000
- Structure 3: Other Fee - 40,000
Total per invoice = 1,20,000 (divided by 3 terms if term-based)
```

The system SUMS all fee structures when generating invoices.

### 3. Code Logic (Working As Designed)
```go
// In feeBillableItems function:
for _, structure := range structures {
    amount := structure.Amount
    if termMode && frequency == "term" {
        amount = structure.Amount / float64(termCount)  // Divides by term count
    }
    total += amount  // SUMS all structures
}
```

## Diagnosis Steps

### Step 1: Check Fee Structures
Run this query in your database:

```sql
SELECT 
    fs.id,
    fc.category_name,
    fs.amount,
    fs.installment_count,
    g.grade_name,
    s.section_name,
    fs.created_at
FROM fee_structures fs
JOIN fee_categories fc ON fc.id = fs.fee_category_id
JOIN grades g ON g.id = fs.grade_id
LEFT JOIN sections s ON s.id = fs.section_id
WHERE fs.school_id = 'YOUR_SCHOOL_ID'
AND fs.academic_year_id = 'CURRENT_ACADEMIC_YEAR_ID'
ORDER BY g.grade_name, s.section_name, fs.created_at;
```

**Expected**: ONE structure per category per class (e.g., only ONE "Tuition Fee" structure)
**If you see**: Multiple structures with same or different categories but same amount → THIS IS THE ISSUE

### Step 2: Check Generated Invoices
```sql
SELECT 
    fi.invoice_number,
    s.first_name || ' ' || s.last_name as student_name,
    fi.total_amount,
    fi.payable_amount,
    fi.balance,
    COUNT(fii.id) as item_count
FROM fee_invoices fi
JOIN students s ON s.id = fi.student_id
LEFT JOIN fee_invoice_items fii ON fii.invoice_id = fi.id
WHERE s.school_id = 'YOUR_SCHOOL_ID'
AND fi.academic_year_id = 'CURRENT_ACADEMIC_YEAR_ID'
GROUP BY fi.id, s.first_name, s.last_name, fi.invoice_number, fi.total_amount, fi.payable_amount, fi.balance
ORDER BY fi.created_at DESC
LIMIT 10;
```

**Check**: 
- If `total_amount` is 2-4 lakhs → invoices were generated with wrong amounts
- If `item_count` > 1 → multiple fee categories in invoice (may be correct if you have multiple fee types)

## Solutions

### Solution 1: Delete Duplicate Fee Structures (RECOMMENDED)
If you have multiple fee structures that shouldn't exist:

1. Go to Principal Dashboard → Fee Management → Fee Structures
2. Delete duplicate structures (keep only ONE structure per fee category per class)
3. Regenerate invoices:
   - First, delete existing incorrect invoices
   - Then generate new invoices with correct fee structures

### Solution 2: Fix Invoice Amounts (Quick Fix)
If invoices were already generated incorrectly, you can:

1. Use the "Sync Fee Structure" feature to update existing invoices
2. OR manually adjust invoice amounts via Admin/Principal fee monitoring

### Solution 3: Code Fix (If Logic Is Wrong)
If the issue is that fee structure amount should NOT be divided by terms, modify the code:

**File**: `school-backend/internal/handlers/fee.go`
**Function**: `feeBillableItems` (line 1339)

**Current behavior**: Divides annual amount by termCount when termMode is true
**If you want**: Fee structure amount to represent PER-TERM amount (not annual)

**Change**:
```go
// Remove the division logic
case "term":
    // amount = structure.Amount / float64(termCount)  // REMOVE THIS
    // Keep: amount = structure.Amount
```

## Recommended Fix Steps

1. **Verify Setup**: Run diagnosis queries above
2. **Clean Data**: Delete duplicate fee structures if found
3. **Delete Bad Invoices**: Delete incorrectly generated invoices
4. **Regenerate**: Create new invoices with corrected fee structures
5. **Verify**: Check dashboard totals match expected (20 students × 40,000 = 8,00,000)

## Prevention

### Best Practices for Fee Setup:
1. **ONE structure per category**: Create only one "Tuition Fee" structure per class
2. **Annual amounts**: Enter the TOTAL ANNUAL fee in the amount field
3. **Set installment count**: System will divide automatically when generating term-based invoices
4. **Use categories wisely**: Create separate categories only for truly different fee types (Tuition, Transport, Books)

## Questions to Answer

1. **How many fee structures exist for the affected class?**
   - Run Step 1 query to check

2. **What frequency was selected?**
   - One-time, Yearly, Term, Monthly?

3. **Were invoices generated with term_id?**
   - Check if `term_id` is populated in fee_invoices table

4. **What was the installment count set to?**
   - Check `installment_count` field in fee structures

Answer these to pinpoint the exact issue!

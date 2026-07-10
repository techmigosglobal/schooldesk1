# Record Payment Screen Redesign Plan

## 📋 Executive Summary

This document outlines the comprehensive redesign of the **Record Payment Screen** in the Fees Feature Module. The goal is to implement a structured Class/Section → Student selection workflow with proper fee type handling (Books & Kit Fee, Tuition Fees), improved month selection UI, and enhanced theming.

---

## 🎯 Current State Analysis

### Existing Implementation
The current `PrincipalCollectFee` screen in `lib/features/finance/presentation/screens/principal_dashboard/principal_collect_fee.dart` has the following structure:

1. **Student Picker** - A flat list of all students with outstanding dues
2. **Payment Form** - Shows after selecting a student
3. **Month Selection** - Only visible for tuition fees
4. **Payment Mode** - Cash or Others
5. **Amount Entry** - Manual input

### Current Issues Identified

| Issue | Description |
|-------|-------------|
| **No Class/Section Filter** | Students are listed flat without class/section grouping |
| **Month UI Problems** | Months not visible properly, poor theming |
| **Fee Type Handling** | Books & Kit Fee not properly disabled when paid |
| **Workflow Complexity** | No guided step-by-step flow |

---

## 🔄 Proposed Workflow

### Step 1: Class/Section Selection
```
┌─────────────────────────────────────────────────────────┐
│  📚 Record Payment                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  SELECT CLASS & SECTION                         │   │
│  │                                                 │   │
│  │  Class/Section:  [──────────────────────▼]      │   │
│  │                   Class 5 - Section A           │   │
│  │                                                 │   │
│  │  Students with dues: 12 students                │   │
│  │  Total outstanding: ₹45,000                     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  ▼ Students in this section                     │   │
│  │                                                 │   │
│  │  👤 Aarav Sharma         ₹5,000  [Select →]    │   │
│  │  👤 Priya Patel          ₹4,200  [Select →]    │   │
│  │  👤 Rohan Singh          ₹3,800  [Select →]    │   │
│  │  ...                                            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Implementation Notes:**
- Add `DropdownButtonFormField` for Class/Section selection
- Filter students based on selected section
- Show summary stats (student count, total outstanding)

### Step 2: Student Selection
```
┌─────────────────────────────────────────────────────────┐
│  📚 Record Payment                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Selected: Class 5 - Section A                          │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  SELECT STUDENT                                 │   │
│  │                                                 │   │
│  │  🔍 Search student...                           │   │
│  │                                                 │   │
│  │  ┌─────────────────────────────────────────┐   │   │
│  │  │ 👤 Aarav Sharma                         │   │   │
│  │  │    Class 5-A | Roll: 12                 │   │   │
│  │  │    Outstanding: ₹5,000                  │   │   │
│  │  └─────────────────────────────────────────┘   │   │
│  │                                                 │   │
│  │  ┌─────────────────────────────────────────┐   │   │
│  │  │ 👤 Priya Patel                          │   │   │
│  │  │    Class 5-A | Roll: 8                  │   │   │
│  │  │    Outstanding: ₹4,200                  │   │   │
│  │  └─────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Implementation Notes:**
- Search functionality for student name
- Show student card with roll number and outstanding amount
- Card tap navigates to fee selection

### Step 3: Fee Type Selection
```
┌─────────────────────────────────────────────────────────┐
│  📚 Record Payment                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Student: Aarav Sharma | Class 5-A                      │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  SELECT FEE TYPE                                │   │
│  │                                                 │   │
│  │  ┌─────────────────────────────────────────┐   │   │
│  │  │ 📚 Books & Kit Fee                      │   │   │
│  │  │    Amount: ₹2,500                       │   │   │
│  │  │    Status: ✅ PAID                       │   │   │
│  │  │    [DISABLED - Already Paid]             │   │   │
│  │  └─────────────────────────────────────────┘   │   │
│  │                                                 │   │
│  │  ┌─────────────────────────────────────────┐   │   │
│  │  │ 🎓 Tuition Fee                          │   │   │
│  │  │    Monthly: ₹1,500/month                │   │   │
│  │  │    Status: ⏳ Partially Paid             │   │   │
│  │  │    [SELECT →]                            │   │   │
│  │  └─────────────────────────────────────────┘   │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Implementation Notes:**
- Display fee types as selectable cards
- **Books & Kit Fee**: Check payment status, disable if already paid
- **Tuition Fee**: Always available for selection
- Visual distinction between paid and unpaid statuses

### Step 4: Month Selection (Tuition Only)
```
┌─────────────────────────────────────────────────────────┐
│  📚 Record Payment                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Student: Aarav Sharma | Class 5-A                      │
│  Fee Type: Tuition Fee                                  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  SELECT MONTHS TO PAY                           │   │
│  │                                                 │   │
│  │  Monthly Rate: ₹1,500                          │   │
│  │                                                 │   │
│  │  ┌─────────────────────────────────────────┐   │   │
│  │  │ JAN │ FEB │ MAR │ APR │ MAY │ JUN       │   │   │
│  │  │  ✓  │  ✓  │  ✓  │  ◔  │  ○  │  ○       │   │   │
│  │  └─────────────────────────────────────────┘   │   │
│  │                                                 │   │
│  │  ┌─────────────────────────────────────────┐   │   │
│  │  │ JUL │ AUG │ SEP │ OCT │ NOV │ DEC       │   │   │
│  │  │  ○  │  ○  │  ○  │  ○  │  ○  │  ○       │   │   │
│  │  └─────────────────────────────────────────┘   │   │
│  │                                                 │   │
│  │  Legend:                                        │   │
│  │  ✓ = Paid (locked)                             │   │
│  │  ◔ = Selected                                  │   │
│  │  ○ = Available (unpaid)                         │   │
│  │                                                 │   │
│  │  ──────────────────────────────────────────     │   │
│  │  Selected: Apr, May                             │   │
│  │  Months to pay: 2                              │   │
│  │  Total: ₹3,000                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Implementation Notes:**
- **Month Grid Layout**: Use `Wrap` with `FilterChip` or custom month cards
- **Visual States**:
  - Paid months: Green checkmark, disabled, locked
  - Selected months: Blue highlight
  - Available months: Neutral, clickable
- **Continuous Selection**: Only allow selecting consecutive unpaid months
- **Amount Auto-calculation**: Update total based on selected months

### Step 5: Payment Details
```
┌─────────────────────────────────────────────────────────┐
│  📚 Record Payment                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Student: Aarav Sharma | Class 5-A                      │
│  Fee Type: Tuition Fee | Months: Apr-May                │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  PAYMENT DETAILS                                │   │
│  │                                                 │   │
│  │  ┌─────────────────────────────────────────┐   │   │
│  │  │ Invoice Summary                         │   │   │
│  │  │ ────────────────────────────────────     │   │   │
│  │  │ Total Invoiced:        ₹18,000          │   │   │
│  │  │ Total Paid:            ₹12,000  ✓       │   │   │
│  │  │ Balance Due:           ₹6,000   ⚠       │   │   │
│  │  └─────────────────────────────────────────┘   │   │
│  │                                                 │   │
│  │  Payment Amount:  ₹ [3,000              ]      │   │
│  │                                                 │   │
│  │  Payment Method:                               │   │
│  │  ┌──────────┐        ┌──────────┐              │   │
│  │  │ 💵 Cash  │        │ 🏦Others │              │   │
│  │  │  SELECTED │       │          │              │   │
│  │  └──────────┘        └──────────┘               │   │
│  │                                                 │   │
│  │  Reference/Receipt No: [RCP-20710-001(optional)    ]  │   │
│  │                                                 │   │
│  │  Payment Date: [10 Jul 2024               ▼]   │   │
│  │                                                 │   │
│  │  Administrative Notes:                         │   │
│  │  [                                        ]    │   │
│  │  [                                        ]    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  [              CONFIRM PAYMENT              ]  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [              BACK TO STUDENT LIST               ]   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Implementation Notes:**
- Invoice summary card with totals
- Amount field with currency prefix
- Payment method selector (Cash, Bank Transfer, UPI)
- Reference number and date fields
- Notes textarea
- Confirm button with loading state

---

## 🎨 Theming & Styling Guidelines

### Color Palette

| Element | Color | Usage |
|---------|-------|-------|
| Primary | `#1A6B4A` | Headers, primary buttons, selected states |
| Secondary | `#6366F1` | Secondary actions, UPI payment |
| Success | `#16A34A` | Paid status, confirmation |
| Warning | `#F59E0B` | Outstanding amounts, pending |
| Danger | `#EF4444` | Errors, overdue |
| Surface | `#FFFFFF` | Cards, backgrounds |
| Background | `#F0FDF4` | Screen background (green tint) |

### Month Selection Colors

| State | Background | Border | Text |
|-------|------------|--------|------|
| Paid | `#DCFCE7` | `#1A6B4A` | `#1A6B4A` |
| Selected | `#DBEAFE` | `#2563EB` | `#1E40AF` |
| Available | `#F3F4F6` | `#D1D5DB` | `#374151` |
| Disabled | `#F9FAFB` | `#E5E7EB` | `#9CA3AF` |

### Typography

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Headers | IBM Plex Sans | 16-18px | Bold (700) |
| Body | IBM Plex Sans | 14px | Regular (400) |
| Labels | IBM Plex Sans | 12px | Semi-Bold (600) |
| Amounts | IBM Plex Sans | 14-16px | Bold (700) |
| Captions | IBM Plex Sans | 11-12px | Regular (400) |

---

## 🔧 Technical Implementation

### Files to Modify

| File | Changes |
|------|---------|
| `lib/features/finance/presentation/screens/principal_dashboard/principal_collect_fee.dart` | Main redesign |
| `lib/features/finance/presentation/screens/fee_shared/fee_models.dart` | Add helper methods |
| `lib/features/finance/presentation/screens/fee_shared/fee_widgets.dart` | Reusable components |

### State Variables

```dart
// Selection state
String _selectedClassSectionId = '';
String _selectedStudentId = '';
String _selectedFeeType = ''; // 'tuition', 'books_kit'
final Set<String> _selectedMonths = {};

// Data
List<Map<String, dynamic>> _classes = [];
List<Map<String, dynamic>> _sections = [];
List<Map<String, dynamic>> _students = [];
List<Map<String, dynamic>> _invoices = [];
```

### Key Methods

```dart
// Load class/section data
Future<void> _loadClassSectionData() async {
  final api = BackendApiClient.instance;
  final grades = await api.getGrades();
  final sections = await api.getSections();
  // Process and filter
}

// Filter students by section
List<Map<String, dynamic>> get _filteredStudents {
  if (_selectedClassSectionId.isEmpty) return [];
  return _students.where((s) => 
    s['current_section_id'] == _selectedClassSectionId
  ).toList();
}

// Check if Books & Kit is paid
bool _isBooksKitPaid(Map<String, dynamic> invoice) {
  return invoice['fee_type'] == 'books_kit' && 
         invoice['balance'] <= 0;
}

// Validate month selection (continuous only)
bool _isValidMonthSelection(String month) {
  final unpaid = _unpaidMonths;
  final selected = _selectedMonths.toList();
  // Must be consecutive from the start
  final nextIndex = selected.length;
  return unpaid.indexOf(month) == nextIndex;
}
```

### API Integration

```dart
// Existing API calls (no backend changes needed)
- api.getInvoices() // Get all invoices
- api.recordPayment(PaymentRequest) // Record payment

// New helper methods
List<Map<String, dynamic>> get _invoicesBySection {
  return _dueInvoices.where((inv) {
    final sectionId = inv['current_section_id'];
    return sectionId == _selectedClassSectionId;
  }).toList();
}
```

---

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    USER INTERACTION FLOW                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐                                          │
│  │ Open Screen  │                                          │
│  └──────┬───────┘                                          │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────────────────────────────────────┐         │
│  │ 1. Select Class/Section                      │         │
│  │    - Load grades and sections                │         │
│  │    - Filter students by section              │         │
│  └──────────────┬───────────────────────────────┘         │
│                 │                                           │
│                 ▼                                           │
│  ┌──────────────────────────────────────────────┐         │
│  │ 2. Select Student                            │         │
│  │    - Show students with outstanding dues     │         │
│  │    - Search by name                          │         │
│  └──────────────┬───────────────────────────────┘         │
│                 │                                           │
│                 ▼                                           │
│  ┌──────────────────────────────────────────────┐         │
│  │ 3. Select Fee Type                           │         │
│  │    - Books & Kit Fee (disable if paid)       │         │
│  │    - Tuition Fee (always available)          │         │
│  └──────────────┬───────────────────────────────┘         │
│                 │                                           │
│         ┌───────┴───────┐                                   │
│         │               │                                   │
│         ▼               ▼                                   │
│  ┌─────────────┐  ┌─────────────────────┐                  │
│  │ Books & Kit │  │ Tuition Fee         │                  │
│  │ - One-time  │  │ - Monthly selection │                  │
│  │ - No months │  │ - Continuous months │                  │
│  └──────┬──────┘  └──────────┬──────────┘                  │
│         │                    │                               │
│         └────────┬───────────┘                               │
│                  │                                           │
│                  ▼                                           │
│  ┌──────────────────────────────────────────────┐         │
│  │ 4. Enter Payment Details                     │         │
│  │    - Amount (auto-calculated or manual)      │         │
│  │    - Payment method                          │         │
│  │    - Reference number                        │         │
│  │    - Date and notes                          │         │
│  └──────────────┬───────────────────────────────┘         │
│                 │                                           │
│                 ▼                                           │
│  ┌──────────────────────────────────────────────┐         │
│  │ 5. Confirm & Record                          │         │
│  │    - Validation                              │         │
│  │    - API call to record payment              │         │
│  │    - Success dialog                          │         │
│  │    - Refresh data                            │         │
│  └──────────────────────────────────────────────┘         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Implementation Checklist

### Phase 1: Core Structure
- [ ] Add Class/Section dropdown with grade-section filtering
- [ ] Implement student list filtered by selected section
- [ ] Create fee type selection cards (Books & Kit, Tuition)
- [ ] Add payment status checking for Books & Kit

### Phase 2: Month Selection
- [ ] Redesign month grid layout with proper theming
- [ ] Implement continuous month selection logic
- [ ] Add visual states (paid, selected, available)
- [ ] Auto-calculate amount based on selected months

### Phase 3: Payment Form
- [ ] Invoice summary card with totals
- [ ] Payment method selector with styling
- [ ] Form validation and error handling
- [ ] Success dialog and navigation

### Phase 4: Polish
- [ ] Loading states and error handling
- [ ] Empty state designs
- [ ] Responsive layout
- [ ] Accessibility (labels, semantics)

---

## 🧪 Testing Strategy

### Unit Tests
- Test month selection logic (continuous validation)
- Test fee type filtering (paid/unpaid)
- Test amount calculation

### Widget Tests
- Test Class/Section dropdown interaction
- Test student list filtering
- Test month chip selection/deselection
- Test payment form validation

### Integration Tests
- Complete payment recording flow
- Error handling scenarios
- State persistence during navigation

---

## 📝 Notes

1. **No Backend Changes Required**: All needed data is already available through existing API endpoints.

2. **Backward Compatibility**: The new implementation maintains the same API contract for recording payments.

3. **Existing Patterns**: Following established patterns from:
   - `admin_fee_form_screens.dart` for dropdowns
   - `parent_payment_request_form_screen.dart` for month selection
   - `fee_widgets.dart` for reusable components

4. **Theme Consistency**: Using the existing `context.appTheme` extensions for colors and styling.

---

## 🔗 Related Files

- `lib/core/network/api_modules/fees_api.dart` - Fee structure and invoice APIs
- `lib/core/network/api_modules/fee_payments_api.dart` - Payment recording APIs
- `lib/features/finance/presentation/screens/fee_shared/fee_models.dart` - Shared models
- `lib/features/finance/presentation/screens/fee_shared/fee_widgets.dart` - Shared widgets

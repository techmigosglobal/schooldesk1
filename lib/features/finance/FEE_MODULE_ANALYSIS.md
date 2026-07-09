# Fee Module — Complete Screen Analysis & Optimization Report

> **Date:** 2026-07-09  
> **Scope:** All fee-related screens for Principal and Parent roles  
> **Goal:** Document every screen, identify duplicates, remove redundancy, optimize UX, and verify backend alignment.

---

## Table of Contents

1. [Screen Inventory](#1-screen-inventory)
2. [Principal Role — Screens Deep Dive](#2-principal-role)
3. [Parent Role — Screens Deep Dive](#3-parent-role)
4. [Shared Components & Models](#4-shared-components)
5. [Backend API Verification](#5-backend-api-verification)
6. [Duplicate & Redundancy Audit](#6-duplicate-audit)
7. [Optimization Recommendations](#7-optimization)
8. [Proposed Simplified Navigation Map](#8-navigation-map)

---

## 1. Screen Inventory

### Principal Role (12 screens)

| # | Screen | File | Purpose |
|---|--------|------|---------|
| P1 | `FeeHomeScreen` | `fee_home_screen/fee_home_screen.dart` | **Unified hub** — metrics, quick actions, collection progress |
| P2 | `AdminFeesScreen` | `admin_fees_screen/admin_fees_screen.dart` | **Legacy workspace** — structures, invoices, payments, concessions, reports |
| P3 | `PrincipalFeeDashboard` | `principal_dashboard/principal_fee_dashboard.dart` | **Legacy dashboard** — KPI grid, quick actions, aging buckets |
| P4 | `FeeStructuresScreen` | `fee_structures_screen/fee_structures_screen.dart` | Manage fee structures per class/section |
| P5 | `PrincipalFeeStructures` | `principal_dashboard/principal_fee_structures.dart` | Duplicate of P4 (different styling) |
| P6 | `FeeCollectScreen` | `fee_collect_screen/fee_collect_screen.dart` | Record offline payments |
| P7 | `PrincipalCollectFee` | `principal_dashboard/principal_collect_fee.dart` | Duplicate of P6 (different styling) |
| P8 | `PrincipalInvoiceGenerate` | `principal_dashboard/principal_invoice_generate.dart` | Generate invoices for classes/sections |
| P9 | `FeePaymentConfigScreen` | `fee_payment_config_screen/fee_payment_config_screen.dart` | Configure UPI/QR settings |
| P10 | `PrincipalPaymentConfig` | `principal_dashboard/principal_payment_config.dart` | Duplicate of P9 (different styling) |
| P11 | `AdminPaymentRequestsScreen` | `admin_fees_screen/admin_payment_requests_screen.dart` | Review parent payment requests (list) |
| P12 | `AdminPaymentRequestDecisionScreen` | `admin_fees_screen/admin_payment_request_decision_screen.dart` | Approve/reject single payment request |
| P13 | `PrincipalPaymentRequests` | `principal_dashboard/principal_payment_requests.dart` | Duplicate of P11+P12 combined (inline decisions) |
| P14 | `FeeLedgerScreen` | `fee_ledger_screen/fee_ledger_screen.dart` | Student ledger & outstanding balances |
| P15 | `PrincipalReports` | `principal_dashboard/principal_reports_v2.dart` | Fee reports + PDF export |
| P16 | `AdminFeeStructureFormScreens` | `admin_fees_screen/admin_fee_form_screens.dart` | Create/edit fee structure form |

### Parent Role (9 screens)

| # | Screen | File | Purpose |
|---|--------|------|---------|
| Pa1 | `ParentFeesScreen` | `parent_fees_screen/parent_fees_screen.dart` | **Tabbed hub** — Fees, Payments, Fee Types tabs |
| Pa2 | `ParentFeeHub` | `parent_hub/parent_fee_hub.dart` | **Alternative hub** — single-page layout with hero card |
| Pa3 | `ParentPaymentRequestFormScreen` | `parent_fees_screen/parent_payment_request_form_screen.dart` | UPI payment form with QR + proof upload |
| Pa4 | `ParentPaymentFlow` | `parent_hub/parent_payment_flow.dart` | Alternative payment flow (3-step wizard) |
| Pa5 | `ParentPaymentSelectionScreen` | `parent_payment_screens/parent_payment_selection_screen.dart` | Select fee installments before paying |
| Pa6 | `ParentPaymentHistoryScreen` | `parent_payment_screens/parent_payment_history_screen.dart` | Payment history (datasource-based) |
| Pa7 | `ParentPaymentHistoryV2` | `parent_hub/parent_payment_history_v2.dart` | Alternative payment history (API-based) |
| Pa8 | `ParentPaymentSuccessScreen` | `parent_payment_screens/parent_payment_success_screen.dart` | Post-payment confirmation |
| Pa9 | `ReceiptViewScreen` | `parent_payment_screens/receipt_view_screen.dart` | View receipt details |

---

## 2. Principal Role — Screens Deep Dive

### P1: FeeHomeScreen (Unified Hub)
**File:** `fee_home_screen/fee_home_screen.dart` (~350 lines)  
**UI Framework:** Uses shared `FeeCard`, `FeeMetricTile`, `FeeActionRow` widgets from `fee_shared/fee_widgets.dart`

**Layout:**
```
┌─────────────────────────────────┐
│ Header: "Fees" + Menu + Refresh │
├─────────────────────────────────┤
│ Academic Year Dropdown           │
├─────────────────────────────────┤
│ ┌──────┐ ┌──────┐              │
│ │Struct│ │Collec│ (2x2 grid)  │
│ │──────│ │──────│              │
│ │Outst │ │Studnt│              │
│ └──────┘ └──────┘              │
├─────────────────────────────────┤
│ Collection Progress (donut)      │
├─────────────────────────────────┤
│ Parent Payment QR action row     │
│ Payment Requests badge row       │
├─────────────────────────────────┤
│ Quick Actions:                   │
│  - Fee Structures               │
│  - Collect Fee                  │
│  - Student Ledger & Dues        │
│  - Reports                      │
├─────────────────────────────────┤
│ Active Structure summary card    │
└─────────────────────────────────┘
```

**Data Loading:** 5 parallel API calls (structures, invoices, academic years, grades, sections)

**Strengths:**
- Clean, modern UI with shared widgets
- Single entry point for all fee operations
- Good use of computed metrics
- Skeleton loading state

**Issues:**
- ⚠️ Overlaps significantly with `AdminFeesScreen` (P2) and `PrincipalFeeDashboard` (P3)
- No concession management (only in P2)
- No inline payment request review (separate screen needed)

---

### P2: AdminFeesScreen (Legacy Workspace)
**File:** `admin_fees_screen/admin_fees_screen.dart` (~1,400 lines)  
**UI Framework:** Uses `SchoolDeskModuleScaffold`, `OpsWorkspace`, `OpsPanel` (operations-style UI)

**Layout:** Tabbed workspace with 5 sub-views:
1. **Structures** — List with create/edit/delete
2. **Invoices** — Outstanding with record payment, PDF preview, reminders
3. **Payments** — Filterable list with receipt preview/export
4. **Concessions** — Approve/reject with status filters
5. **Reports** — Aging summary + PDF export + server-side exports

**Also contains:**
- Payment QR Settings (inline, ~100 lines of code)
- Payment config save/upload logic

**Strengths:**
- Most comprehensive single screen — handles everything
- Good filter/search on payments
- Concession approval inline
- Aging summary card

**Issues:**
- ⚠️ **Massive monolith** — ~1,400 lines, 5+ responsibilities
- ⚠️ Duplicates functionality from P4 (structures), P6 (collect), P9 (config)
- ⚠️ Contains payment config UI inline (should be separate or delegated)
- Local helper methods (`_numValue`, `_textValue`, `_money`) duplicate `fee_models.dart` exports
- `normalizeFeeStructure` and `normalizeInvoice` are re-implemented locally instead of using shared `fee_models.dart`

---

### P3: PrincipalFeeDashboard (Legacy Dashboard)
**File:** `principal_dashboard/principal_fee_dashboard.dart` (~350 lines)  
**UI Framework:** Uses `SchoolDeskModuleScaffold` with `GoogleFonts.ibmPlexSans`

**Layout:**
```
┌─────────────────────────────────┐
│ Header: "Fee Operations"        │
├─────────────────────────────────┤
│ KPI Grid (2x2):                 │
│  Outstanding / Collected /      │
│  Structures / Concessions       │
├─────────────────────────────────┤
│ Needs Attention card (if any)   │
├─────────────────────────────────┤
│ Quick Actions (2x2 grid):       │
│  Structures / Gen Invoices /    │
│  Collect Fee / Reports          │
├─────────────────────────────────┤
│ Collection Progress bar         │
├─────────────────────────────────┤
│ Aging Buckets (0-30/31-60/61+) │
└─────────────────────────────────┘
```

**Issues:**
- ⚠️ **Exact duplicate of P1** with different styling (IBM Plex Sans vs shared widgets)
- Same data loading pattern
- Same KPI tiles, same quick actions
- Should be DELETED — P1 is the canonical version

---

### P4: FeeStructuresScreen
**File:** `fee_structures_screen/fee_structures_screen.dart` (~200 lines)  
**UI Framework:** Uses shared `FeeCard`, `FeeSearchBox`, `FeeEmptyState` widgets

**Layout:** Academic year filter → Search → Structure cards with amount/frequency/due day + delete button

**Strengths:**
- Clean, focused on single responsibility
- Uses shared widgets consistently
- Search + year filter

**Issues:**
- ⚠️ No inline edit — must navigate to form screen
- ⚠️ Delete only, no "edit" button visible (though form supports editing)

---

### P5: PrincipalFeeStructures (Duplicate of P4)
**File:** `principal_dashboard/principal_fee_structures.dart` (~200 lines)  
**UI Framework:** `Card` with `GoogleFonts.ibmPlexSans` (NOT shared widgets)

**Issues:**
- ⚠️ **1:1 duplicate of P4** — same data loading, same logic, same CRUD
- Different styling (manual Card + BorderSide vs shared FeeCard)
- Should be DELETED — P4 is the canonical version

---

### P6: FeeCollectScreen
**File:** `fee_collect_screen/fee_collect_screen.dart` (~350 lines)  
**UI Framework:** Uses shared `FeeCard`, `FeeSearchBox`, `FeeSectionTitle`, `FeeAmountRow`

**Flow:**
1. Student picker (search + due list)
2. Payment form (amount, months, mode, reference, date, notes)
3. Confirmation dialog → record payment

**Strengths:**
- Tuition month selector (continuous selection logic)
- Payment mode chips with icons
- Clean confirmation flow

**Issues:**
- ⚠️ Amount auto-calculation from month selection works both ways (months↔amount)
- Notes field not sent to backend (comment says optional but never used)

---

### P7: PrincipalCollectFee (Duplicate of P6)
**File:** `principal_dashboard/principal_collect_fee.dart` (~350 lines)  
**UI Framework:** `Card` with `GoogleFonts.ibmPlexSans` (NOT shared widgets)

**Issues:**
- ⚠️ **1:1 duplicate of P6** — same flow, same logic, same API call
- Different styling only
- Should be DELETED — P6 is the canonical version

---

### P8: PrincipalInvoiceGenerate
**File:** `principal_dashboard/principal_invoice_generate.dart` (~350 lines)  
**UI Framework:** `Card` with `GoogleFonts.ibmPlexSans`

**3-Step Form:**
1. **Scope** — Year, Grade, Section/Student, Scope selector
2. **Settings** — Term, Label, Due date, Installment count, One-time/Yearly toggles
3. **Preview** — Estimated amount per student + Generate button

**Strengths:**
- Clean step-by-step wizard
- Estimated amount preview
- Term loading from backend
- Notification on generation

**Issues:**
- ⚠️ No shared widget usage — manual Card styling
- Due date field is raw text input, not a date picker

---

### P9: FeePaymentConfigScreen
**File:** `fee_payment_config_screen/fee_payment_config_screen.dart` (~200 lines)  
**UI Framework:** Uses shared `FeeCard`, `FeeSectionTitle`, `FeeInfoBanner`

**Layout:** QR preview → Upload QR → UPI/Payee/Note fields → Save

**Strengths:**
- Clean, focused
- Uses shared widgets
- Info banner explaining parent visibility

**Issues:**
- Clean — no major issues

---

### P10: PrincipalPaymentConfig (Duplicate of P9)
**File:** `principal_dashboard/principal_payment_config.dart` (~200 lines)  
**UI Framework:** `Card` with `GoogleFonts.ibmPlexSans`

**Issues:**
- ⚠️ **1:1 duplicate of P9** — same functionality, different styling
- Should be DELETED — P9 is the canonical version

---

### P11: AdminPaymentRequestsScreen
**File:** `admin_fees_screen/admin_payment_requests_screen.dart` (~350 lines)  
**UI Framework:** `SchoolDeskModuleScaffold` with `SchoolDeskKpiCard`

**Layout:** Summary KPIs → Status filter chips → Request cards with detail rows → Review button

**Strengths:**
- Good status-based filtering (pending, clarification, approved, rejected)
- Proof preview capability
- KPI summary row

**Issues:**
- ⚠️ Requires navigating to separate decision screen (P12)
- `GoogleFonts.dmSans` inconsistency (other screens use `ibmPlexSans`)

---

### P12: AdminPaymentRequestDecisionScreen
**File:** `admin_fees_screen/admin_payment_request_decision_screen.dart` (~350 lines)  
**UI Framework:** `SchoolDeskModuleScaffold`

**Layout:** Request details → Decision selector (Approve/Clarify/Reject) → Remarks → Submit

**Strengths:**
- Clean decision flow
- Proof preview (image + PDF)
- Confirmation dialog on approval

**Issues:**
- ⚠️ Separate screen from list (P11) adds navigation friction
- Could be inlined like P13 does

---

### P13: PrincipalPaymentRequests (Combined P11+P12)
**File:** `principal_dashboard/principal_payment_requests.dart` (~450 lines)  
**UI Framework:** `Card` with `GoogleFonts.ibmPlexSans`

**Layout:** Summary → Filter chips → Request cards with INLINE decision controls

**Strengths:**
- Inline approve/reject without navigation — better UX
- Decision radio buttons per card
- Remarks field per card

**Issues:**
- ⚠️ **Duplicates P11+P12** — same data, same API calls
- Different styling
- Should be DELETED — P11+P12 is the canonical pair (or P13 could be merged into P11)

---

### P14: FeeLedgerScreen
**File:** `fee_ledger_screen/fee_ledger_screen.dart` (~300 lines)  
**UI Framework:** Uses shared `FeeCard`, `FeeSearchBox`, `FeeMetricTile`, `FeeSectionTitle`

**Layout:** Metrics → Search → Filter (All/Unpaid/Partial/Paid) → Student cards → Ledger bottom sheet

**Strengths:**
- Bottom sheet with invoices + payment history per student
- PDF export per student
- Good filter options

**Issues:**
- ⚠️ `_StudentAccount` class duplicates `FeeStudentAccount` from `fee_models.dart`
- Could use shared model instead

---

### P15: PrincipalReports
**File:** `principal_dashboard/principal_reports_v2.dart` (~250 lines)  
**UI Framework:** `Card` with `GoogleFonts.ibmPlexSans`

**Layout:** Live summary card (Expected/Collected/Outstanding/Templates/Invoices/Rate) → PDF download → Server-side exports list

**Strengths:**
- Both in-app PDF and server-side export options
- Good summary metrics

**Issues:**
- ⚠️ `_ReportDef` class duplicates `FeeReportDefinition` from `fee_models.dart`
- PDF generation uses `generateFeeReceipt` (receipt template for reports — should use a dedicated report generator)

---

### P16: AdminFeeStructureFormScreens
**File:** `admin_fees_screen/admin_fee_form_screens.dart`  
**Purpose:** Create/edit fee structure form (used by P4, P5)

**This is a form screen, not a standalone page — properly shared.**

---

## 3. Parent Role — Screens Deep Dive

### Pa1: ParentFeesScreen (Tabbed Hub)
**File:** `parent_fees_screen/parent_fees_screen.dart` (~900 lines)  
**UI Framework:** `SchoolDeskModuleScaffold` with `TabBar` + `GoogleFonts.ibmPlexSans`

**Layout:**
```
┌─────────────────────────────────┐
│ Header: "My Fees"               │
├─────────────────────────────────┤
│ Child selector chips             │
├──────┬──────┬───────────────────┤
│ Fees │Paymts│Fee Types (tabs)   │
├──────┴──────┴───────────────────┤
│ Tab 1: Student card + Due summary│
│         + Workflow action card   │
│         + Fee item cards         │
│ Tab 2: Payment history list      │
│ Tab 3: Fee type breakdown        │
└─────────────────────────────────┘
```

**Data Loading:** 4+ API calls (students, fees, invoices, payment requests)

**Strengths:**
- Multi-child support with selector
- Auto-refresh every 2 minutes
- Workflow action card (context-aware: needs action / under review / ready to pay / all clear)
- Installment progress bars on fee items
- Tabbed navigation for different views

**Issues:**
- ⚠️ **~900 lines** — too much logic in one file
- ⚠️ **Duplicates Pa2** (ParentFeeHub) — same data loading, same child selector
- Fee type breakdown tab duplicates information available in fee items
- Status label mapping is repeated in multiple parent screens

---

### Pa2: ParentFeeHub (Alternative Hub)
**File:** `parent_hub/parent_fee_hub.dart` (~600 lines)  
**UI Framework:** `SchoolDeskModuleScaffold` + `GoogleFonts.ibmPlexSans`

**Layout:**
```
┌─────────────────────────────────┐
│ Header: "My Fees"               │
├─────────────────────────────────┤
│ Child selector chips             │
├─────────────────────────────────┤
│ Hero Balance Card (gradient)     │
│  - Balance Due                   │
│  - Next due date                 │
│  - Pay Now button                │
├─────────────────────────────────┤
│ Clarification banner (if any)    │
├─────────────────────────────────┤
│ Fee Items (cards with progress)  │
├─────────────────────────────────┤
│ Quick Access: Payment History    │
└─────────────────────────────────┘
```

**Strengths:**
- Beautiful hero card with gradient
- Cleaner single-page layout
- Quick access to payment history

**Issues:**
- ⚠️ **Exact duplicate of Pa1** with different layout
- Same data loading, same child selector, same fee item logic
- Less information density (no tabs = more scrolling)
- Should be DELETED — Pa1 is the canonical version

---

### Pa3: ParentPaymentRequestFormScreen
**File:** `parent_fees_screen/parent_payment_request_form_screen.dart` (~750 lines)  
**UI Framework:** `SchoolDeskModuleScaffold` with panels

**Layout:**
```
┌─────────────────────────────────┐
│ Student summary panel            │
├─────────────────────────────────┤
│ Fee breakdown panel              │
├─────────────────────────────────┤
│ Tuition month selector           │
├─────────────────────────────────┤
│ Payment mode selector            │
├─────────────────────────────────┤
│ UPI Panel:                       │
│  - Create Payment Reference      │
│  - QR Code (image or generated)  │
│  - UPI ID + Copy button          │
├─────────────────────────────────┤
│ Reference fields (UTR, Date)     │
├─────────────────────────────────┤
│ Proof upload (image/PDF)         │
├─────────────────────────────────┤
│ Notes for school                 │
├─────────────────────────────────┤
│ Verification notice              │
├─────────────────────────────────┤
│ Submit button                    │
└─────────────────────────────────┘
```

**Strengths:**
- Most comprehensive payment form
- Payment intent creation (reference tracking)
- UPI URI sanitization
- Clarification resubmission support
- Proof thumbnail with full-size preview
- Confirmation dialog before submit

**Issues:**
- ⚠️ **~750 lines** — very long
- ⚠️ **Duplicates Pa4** (ParentPaymentFlow) — same payment logic
- UPI note sanitization is good but could be shared utility
- `_panel()` widget helper duplicated

---

### Pa4: ParentPaymentFlow (3-Step Wizard)
**File:** `parent_hub/parent_payment_flow.dart` (~550 lines)  
**UI Framework:** `Scaffold` with step indicator

**Layout:**
```
Step Indicator: Confirm → Pay → Done
┌─────────────────────────────────┐
│ Step 1: Confirm                  │
│  - Fee details + amount          │
│  - Month selection               │
│  - Continue button               │
├─────────────────────────────────┤
│ Step 2: Pay                      │
│  - QR code + UPI ID              │
│  - Copy UPI ID                   │
│  - UTR field                     │
│  - Proof upload                  │
│  - Submit button                 │
├─────────────────────────────────┤
│ Step 3: Done                     │
│  - Success checkmark             │
│  - Reference ID                  │
│  - Back to Fees / History btns   │
└─────────────────────────────────┘
```

**Strengths:**
- Step indicator is excellent UX
- Cleaner flow separation
- Success state with clear next actions

**Issues:**
- ⚠️ **Duplicates Pa3** — same payment intent, same proof upload, same submit
- Different UX pattern (wizard vs single form) — user preference needed
- UTR field is "Optional" here but "Required" in Pa3 — **inconsistency**
- No confirmation dialog before submit (Pa3 has one)

---

### Pa5: ParentPaymentSelectionScreen
**File:** `parent_payment_screens/parent_payment_selection_screen.dart` (~250 lines)  
**UI Framework:** `SchoolDeskModuleScaffold`

**Purpose:** Select which fee installment to pay before proceeding to payment form.

**Layout:** Radio selection list → Bottom bar with total + Continue button

**Strengths:**
- Clean selection UI
- Shows installment number, due date, paid/unpaid months
- Bottom bar with running total

**Issues:**
- Clean — properly focused on selection step

---

### Pa6: ParentPaymentHistoryScreen
**File:** `parent_payment_screens/parent_payment_history_screen.dart` (~250 lines)  
**UI Framework:** `SchoolDeskModuleScaffold` with `FutureBuilder`

**Purpose:** View payment history using `ParentFeesRemoteDataSource`.

**Issues:**
- ⚠️ **Duplicates Pa7** (ParentPaymentHistoryV2)
- Uses different data source (`ParentFeesRemoteDataSource` vs `BackendApiClient`)
- Different UI pattern (FutureBuilder vs setState)

---

### Pa7: ParentPaymentHistoryV2
**File:** `parent_hub/parent_payment_history_v2.dart` (~350 lines)  
**UI Framework:** `SchoolDeskModuleScaffold` + `GoogleFonts.ibmPlexSans`

**Purpose:** Alternative payment history using `BackendApiClient` directly.

**Issues:**
- ⚠️ **Duplicate of Pa6** — same data, different source
- More features (child selector, clarification resubmit)
- Should be DELETED — Pa6 should be enhanced with child selector instead

---

### Pa8: ParentPaymentSuccessScreen
**File:** `parent_payment_screens/parent_payment_success_screen.dart` (~200 lines)  
**Purpose:** Post-payment confirmation with receipt link.

**Strengths:**
- Beautiful gradient checkmark
- Transaction details card
- View Receipt + Return to Dashboard buttons

**Issues:**
- Clean — properly scoped

---

### Pa9: ReceiptViewScreen
**File:** `parent_payment_screens/receipt_view_screen.dart` (~250 lines)  
**Purpose:** View receipt details with school branding.

**Strengths:**
- School header with name
- Clean receipt layout
- Computer-generated receipt notice

**Issues:**
- Clean — properly scoped

---

## 4. Shared Components & Models

### `fee_shared/fee_models.dart`
**Exports:**
- `normalizeFeeStructure()` — ✅ Well-used by P1, P4, P6, P14
- `normalizeInvoice()` — ✅ Well-used by P1, P6, P14
- `normalizePayments()` — ✅ Well-used by P1, P14
- `FeeStructureBundle`, `FeeComponent`, `FeeStudentAccount`, `FeePaymentResult`, `FeeReportDefinition` — ⚠️ Partially used
- `textValue()`, `numValue()`, `money()`, `displayDate()` — ⚠️ Some screens re-implement these locally

### `fee_shared/fee_widgets.dart`
**Exports:**
- `FeePage`, `FeeHeader`, `FeeCard`, `FeeSearchBox`, `FeeEmptyState`, `FeeMetricTile`, `FeeActionRow`, `FeeStatusPill`, `FeeIconBadge`, `FeeSectionTitle`, `FeeInfoTile`, `FeeAmountRow`, `FeeInfoBanner`

**Usage:**
- ✅ P1, P4, P6, P9, P14 — use shared widgets
- ❌ P2, P3, P5, P7, P8, P10, P13, P15 — use manual Card/styling
- ❌ Pa1, Pa3 — use SchoolDeskModuleScaffold widgets
- ❌ Pa2, Pa4 — use manual Card/styling

---

## 5. Backend API Verification

### API Endpoints Used

| Endpoint | Method | Frontend Callers | Status |
|----------|--------|------------------|--------|
| `/fees/structures` | GET | P1, P2, P3, P4, P5, P6, P7, P8, P14, P15 | ✅ Working |
| `/fees/structures` | POST | P16 (form) | ✅ Working |
| `/fees/structures/:id` | PUT | P16 (form) | ✅ Working |
| `/fees/structures/:id` | DELETE | P4, P5 | ✅ Working |
| `/fees/structures/rollover` | POST | — (stub) | ⚠️ Returns empty result |
| `/fees/structures/:id/invoice-sync/preview` | POST | — (stub) | ⚠️ Returns empty result |
| `/fees/structures/:id/invoice-sync/apply` | POST | — (stub) | ⚠️ Returns empty result |
| `/fees/categories` | GET | P2, P16 | ✅ Working |
| `/fees/invoices` | GET | P1, P2, P6, P7, P8, P14, Pa1, Pa2, Pa6, Pa7 | ✅ Working |
| `/fees/invoices` | POST | P2 | ✅ Working |
| `/fees/invoices/:id` | GET | P2 | ✅ Working |
| `/fees/invoices/:id` | PUT | P2 | ✅ Working |
| `/fees/invoices/generate` | POST | P8 | ✅ Working |
| `/fees/invoices/late-fines/apply` | POST | P2 | ⚠️ Returns empty (no-op) |
| `/fees/payments` | GET | P2 | ✅ Working |
| `/fees/payments` | POST | P6, P7 | ✅ Working |
| `/fees/payments/intent` | POST | Pa3, Pa4 | ✅ Working |
| `/fees/payments/submit` | POST | Pa3, Pa4 | ✅ Working |
| `/fees/payments/:id/resubmit` | PATCH | Pa3, Pa4 | ✅ Working |
| `/fees/payment-requests` | GET | P1, P11, P13, Pa1, Pa2, Pa6, Pa7 | ✅ Working |
| `/fees/payment-requests` | POST | Pa3 | ✅ Working |
| `/fees/payment-requests/:id/decision` | PUT | P12, P13 | ✅ Working |
| `/fees/payment-config` | GET | P9, P10, Pa3, Pa4 | ✅ Working |
| `/fees/payment-config` | PUT | P9, P10 | ✅ Working |
| `/fees/payment-config/qr` | POST | P9, P10 | ✅ Working |
| `/fees/payment-configs` | GET | P2 | ✅ Working |
| `/fees/concessions` | GET | P2, P3 | ✅ Working |
| `/fees/concessions` | POST | P2 | ✅ Working |
| `/fees/concessions/:id` | PATCH | P2 | ✅ Working |
| `/fees/reminders` | POST | P2 | ✅ Working |
| `/fees/reports/exports` | POST | P2, P15 | ✅ Working |
| `/parent/students/:id/fees` | GET | Pa1, Pa2 | ✅ Working |

### Backend Strengths
- ✅ All core CRUD operations work correctly
- ✅ Payment intent + proof submission flow is solid
- ✅ Tuition month validation on backend prevents fraud
- ✅ Scoped payment config (school → grade → section fallback)
- ✅ Notification events fire correctly for approvals/rejections
- ✅ Parent access verification via `parent_student_links`

### Backend Issues
- ⚠️ `/fees/structures/rollover` is a stub (returns 0)
- ⚠️ `/fees/structures/:id/invoice-sync/*` are stubs
- ⚠️ `/fees/invoices/late-fines/apply` is a no-op
- ⚠️ `/fees/payments` POST (offline recording) does full month validation but principal doesn't select months in UI (P6/P7 only allow amount entry)

---

## 6. Duplicate & Redundancy Audit

### 🔴 CRITICAL DUPLICATES (Delete Immediately)

| Keep | Delete | Reason |
|------|--------|--------|
| **P1** (FeeHomeScreen) | P3 (PrincipalFeeDashboard) | P1 is the canonical hub with shared widgets |
| **P4** (FeeStructuresScreen) | P5 (PrincipalFeeStructures) | Same logic, P4 uses shared widgets |
| **P6** (FeeCollectScreen) | P7 (PrincipalCollectFee) | Same logic, P6 uses shared widgets |
| **P9** (FeePaymentConfigScreen) | P10 (PrincipalPaymentConfig) | Same logic, P9 uses shared widgets |
| **P11+P12** (AdminPaymentRequests+Decision) | P13 (PrincipalPaymentRequests) | P13 is inline version; P11+P12 is more modular |
| **Pa1** (ParentFeesScreen) | Pa2 (ParentFeeHub) | Pa1 has tabs, better information density |
| **Pa3** (ParentPaymentRequestFormScreen) | Pa4 (ParentPaymentFlow) | Same logic; Pa3 is more feature-complete |
| **Pa6** (ParentPaymentHistoryScreen) | Pa7 (ParentPaymentHistoryV2) | Same data; Pa6 is canonical datasource |

### 🟡 REDUNDANT CODE PATTERNS

| Pattern | Where | Fix |
|---------|-------|-----|
| Local `_numValue()`, `_textValue()`, `_money()` | P2, P13, Pa1, Pa2 | Use `fee_models.dart` exports |
| Local `normalizeFeeStructure()` | P2 | Use shared `normalizeFeeStructure()` |
| Local `normalizeInvoice()` | P2 | Use shared `normalizeInvoice()` |
| Local `_StudentAccount` class | P14 | Use `FeeStudentAccount` from models |
| Local `_ReportDef` class | P15 | Use `FeeReportDefinition` from models |
| `_statusFromFeeRow()` mapping | Pa1, Pa2 | Extract to shared utility |
| `_paymentStatusLabel()` mapping | Pa1, Pa2, Pa7 | Extract to shared utility |
| `_absoluteMediaUrl()` helper | P2, P10, P12, P13, Pa3 | Extract to shared utility |
| `_panel()` widget helper | Pa3, Pa4 | Extract to shared widget |
| Child selector widget | Pa1, Pa2, Pa7 | Extract to shared widget |

### 🟢 PROPERLY SHARED (No Issues)

- `AdminFeeStructureFormScreens` (P16) — used by P4 and P5
- `ReceiptViewScreen` (Pa9) — used by Pa6, Pa8
- `ParentPaymentSelectionScreen` (Pa5) — entry point for Pa3
- `fee_models.dart` normalization functions — used by P1, P4, P6, P14
- `fee_widgets.dart` — used by P1, P4, P6, P9, P14

---

## 7. Optimization Recommendations

### Phase 1: Delete Duplicates (Save ~2,500 lines)

1. **Delete P3** (PrincipalFeeDashboard) — redirect routes to P1
2. **Delete P5** (PrincipalFeeStructures) — redirect routes to P4
3. **Delete P7** (PrincipalCollectFee) — redirect routes to P6
4. **Delete P10** (PrincipalPaymentConfig) — redirect routes to P9
5. **Delete P13** (PrincipalPaymentRequests) — redirect routes to P11+P12
6. **Delete Pa2** (ParentFeeHub) — redirect routes to Pa1
7. **Delete Pa4** (ParentPaymentFlow) — redirect routes to Pa3
8. **Delete Pa7** (ParentPaymentHistoryV2) — redirect routes to Pa6

### Phase 2: Extract Shared Utilities (Save ~500 lines of duplication)

1. **Extract `statusFromFeeRow()`** → `fee_models.dart`
2. **Extract `paymentStatusLabel()`** → `fee_models.dart`
3. **Extract `absoluteMediaUrl()`** → `fee_models.dart`
4. **Extract child selector widget** → `fee_widgets.dart`
5. **Extract panel widget** → `fee_widgets.dart`

### Phase 3: Refactor P2 (AdminFeesScreen) into Focused Screens

P2 is the biggest monolith (~1,400 lines). Split into:
- `AdminFeeStructuresTab` — reuse P4
- `AdminInvoicesTab` — focused invoice management
- `AdminPaymentsTab` — focused payment list
- `AdminConcessionsTab` — focused concession management
- `AdminReportsTab` — reuse P15
- Move payment config to P9

### Phase 4: Route Consolidation

Update `app_routes.dart` to:
- Remove routes for deleted screens
- Point all fee routes to canonical screens
- Ensure `route_access_guard.dart` matches

### Phase 5: UI Consistency

Standardize on ONE font family across all fee screens:
- **Option A:** `GoogleFonts.ibmPlexSans` (used by Pa1, Pa2, P3, P8, P13, P15)
- **Option B:** Default Material theme (used by P1, P4, P6, P9, P14)
- **Recommendation:** Use the app's design system (`context.appTheme`) consistently

### Phase 6: Backend Stub Completion

Complete the stub endpoints:
- `rollover` — implement academic year rollover
- `invoice-sync` — implement structure→invoice sync
- `late-fines/apply` — implement late fine calculation

---

## 8. Proposed Simplified Navigation Map

### Principal Role (6 screens after cleanup)

```
FeeHomeScreen (P1) — HUB
├── FeeStructuresScreen (P4) — CRUD structures
├── FeeCollectScreen (P6) — Record offline payments
├── FeeLedgerScreen (P14) — Student ledger & balances
├── FeePaymentConfigScreen (P9) — UPI/QR settings
├── AdminPaymentRequestsScreen (P11) — List payment requests
│   └── AdminPaymentRequestDecisionScreen (P12) — Decide on request
├── AdminFeesScreen (P2) — Workspace (structures/invoices/payments/concessions/reports)
└── PrincipalReports (P15) — Fee reports & exports
```

### Parent Role (5 screens after cleanup)

```
ParentFeesScreen (Pa1) — HUB (3 tabs: Fees, Payments, Fee Types)
├── ParentPaymentSelectionScreen (Pa5) — Select installment
│   └── ParentPaymentRequestFormScreen (Pa3) — Pay with UPI + proof
├── ParentPaymentHistoryScreen (Pa6) — Payment timeline
├── ReceiptViewScreen (Pa9) — View receipt
└── ParentPaymentSuccessScreen (Pa8) — Post-payment confirmation
```

---

## Summary

| Metric | Before | After (Proposed) |
|--------|--------|-------------------|
| Principal screens | 12 | 7 |
| Parent screens | 9 | 5 |
| Total screens | 21 | 12 |
| Lines of code (est.) | ~8,500 | ~5,500 |
| Duplicate screens | 8 | 0 |
| Shared widget coverage | 40% | 90% |

**Key Actions:**
1. Delete 8 duplicate screens immediately
2. Extract 5 shared utilities
3. Refactor AdminFeesScreen monolith
4. Standardize UI styling
5. Complete 3 backend stubs

# Fees Module — Optimized Screen Design

> **Date:** July 8, 2026  
> **Purpose:** Redesigned fees screens for both Parent and Principal roles  
> **Goal:** Ease of access, reduced cognitive load, faster payment flows, unified navigation

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [Optimized Parent Role Screens](#parent-role)
3. [Optimized Principal Role Screens](#principal-role)
4. [Unified Component System](#unified-components)
5. [Navigation Architecture](#navigation)
6. [Implementation Roadmap](#roadmap)

---

## 1. Design Principles

### Core UX Goals

| Principle | Current State | Target State |
|---|---|---|
| **Time to Pay** | 4 screens, 12+ taps | 2 screens, 4-5 taps |
| **Info Density** | Monolithic 900-line screens | Focused 200-300 line screens |
| **Decision Making** | Status labels without context | Color + icon + contextual guidance |
| **Error Recovery** | Dead-end errors | Inline retry with state preservation |
| **Navigation Depth** | 4-5 levels deep | 2-3 levels max |

### Design System Tokens

```
Primary:       #1A6B4A (green-700)  — actions, active states
Success:       #16A34A (green-600)  — paid, confirmed
Warning:       #F59E0B (amber-500)  — pending, due
Error:         #EF4444 (red-500)    — overdue, rejected
Info:          #3B82F6 (blue-500)   — clarification, in-progress
Surface:       #FFFFFF              — cards, backgrounds
SurfaceVar:    #F1F5F9              — secondary surfaces
Muted:         #64748B              — labels, timestamps
Border:        #E2E8F0             — dividers, outlines
```

---

## 2. Optimized Parent Role Screens

### Screen 1: ParentFeeHub (Replaces ParentFeesScreen)

**Lines:** ~350 (down from ~900)  
**Concept:** Single-scroll hub with clear visual hierarchy

#### Wireframe

```
┌─────────────────────────────────────────┐
│  My Fees                                │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │  👦 Aarav  👧 Priya  👦 Rohan   │   │  ← Horizontal child pills
│  │  (●)       (○)       (○)        │   │     (compact, tappable)
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │  💳 Balance Due                  │   │  ← HERO CARD (full-width)
│  │  ₹16,500                        │   │     Primary CTA here
│  │  Next due: Jul 15 (7 days)      │   │
│  │                                 │   │
│  │  ┌──────────────────────────┐   │   │
│  │  │  ▶ Pay Now — ₹4,000     │   │   │  ← Single CTA button
│  │  └──────────────────────────┘   │   │     (primary color, large)
│  └──────────────────────────────────┘   │
│                                         │
│  ── Fee Items ──────────────────────    │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ ⏱ Tuition Fee          ₹12,000  │   │  ← Pending item
│  │   Due Jul 15 · 1/3 installments │   │
│  │   ████░░░░░░ 33%               │   │
│  │                     [ Pay → ]   │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ ✓ Book & Kit Fee       ₹3,500   │   │  ← Paid item
│  │   Paid May 01                   │   │
│  │                     [ Receipt ] │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ── Recent Activity ────────────────    │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ ⚠ Clarification Needed          │   │  ← Action required banner
│  │ Principal asked for clearer      │   │     (only shows when relevant)
│  │ proof on INV-002                 │   │
│  │              [ Resubmit → ]     │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ── Quick Access ───────────────────    │
│                                         │
│  [ 📋 Payment History ]  [ 📄 Fee Types ]│  ← Two-column shortcuts
│                                         │
└─────────────────────────────────────────┘
```

#### Key Improvements
1. **Hero balance card** replaces the complex DueSummaryCard — shows balance + CTA in one glance
2. **Pay Now button** goes directly to payment form (skips SelectionScreen when only 1 pending invoice)
3. **Action banner** only appears when clarification/pending — not always visible
4. **Quick access** replaces tabs — less cognitive overhead, still reaches all sub-screens
5. **Fee items** show inline pay/receipt buttons — no need to navigate away

#### Data Flow (Simplified)
```dart
// Instead of loading 4+ API calls sequentially:
Future<void> _loadData() async {
  final children = await api.getMyStudents();
  final child = children[_activeChildIndex];
  final studentId = child['id'];
  
  // Parallel fetch with single error boundary
  final [feeRows, invoices, requests] = await Future.wait([
    api.getParentStudentFees(studentId),
    api.getInvoices(studentId: studentId),
    api.getParentPaymentRequests(studentId: studentId),
  ]);
  
  // Normalize once, expose as computed properties
  _invoices = feeRows.map(normalizeInvoice).toList();
  _payments = _buildPaymentHistory(invoices, requests);
  _actionBanner = _computeActionBanner(_payments);
}
```

---

### Screen 2: ParentPaymentFlow (Replaces Selection + Form + Success)

**Lines:** ~500 (spread across 3 logical sections, not 3 screens)  
**Concept:** Single-screen progressive payment form with step indicator

#### Wireframe — Step 1: Confirm & Select Months

```
┌─────────────────────────────────────────┐
│  × Pay Fee                              │
│                                         │
│  ┌──●─────○─────○──┐                   │  ← Step indicator
│  │ Confirm  Pay  Done│                    │     (3 steps)
│  └───────────────────┘                   │
│                                         │
│  Tuition Fee — Class 5-A               │
│  ┌──────────────────────────────────┐   │
│  │ Amount Due        ₹12,000       │   │
│  │ Monthly Rate      ₹4,000/month  │   │
│  │ Paid (Jan-Jun)    ₹24,000 ✓     │   │
│  └──────────────────────────────────┘   │
│                                         │
│  Select months to pay:                  │
│  [Jun✓] [Jul●] [Aug] [Sep] [Oct]        │
│  [Nov] [Dec] [Jan] [Feb] [Mar]          │
│                                         │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ Paying: 1 month (July)          │   │
│  │ Total:  ₹4,000                  │   │
│  └──────────────────────────────────┘   │
│                                         │
│  [ ████████ Continue to Pay ████████ ]  │
└─────────────────────────────────────────┘
```

#### Wireframe — Step 2: UPI & Upload

```
┌─────────────────────────────────────────┐
│  × Pay Fee                              │
│                                         │
│  ┌──────○─────●─────○──┐                │
│  │Confirm  Pay   Done  │                │
│  └──────────────────────┘               │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │  ┌────────────┐                  │   │
│  │  │   QR CODE  │  school@upi      │   │  ← QR + UPI side by side
│  │  │   (200px)  │  Payee: School   │   │     (responsive layout)
│  │  └────────────┘  [Copy UPI ID]   │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ After scanning, enter:           │   │
│  │                                  │   │
│  │ UTR Reference (optional)         │   │
│  │ [ __________________________ ]   │   │
│  │                                  │   │
│  │ Payment Screenshot *             │   │
│  │ [ 📎 Upload Screenshot      ]    │   │
│  │ 📷 preview.png ✓                 │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ ℹ Submit to Principal(to verify) │   │  ← Inline note
│  └──────────────────────────────────┘   │
│                                         │
│  [ ███████ Submit ₹4,000 ████████ ]     │
└─────────────────────────────────────────┘
```

#### Wireframe — Step 3: Confirmation

```
┌─────────────────────────────────────────┐
│  × Pay Fee                              │
│                                         │
│  ┌──────○─────○─────●──┐                │
│  │Confirm  Pay   Done  │                │
│  └─────────────────────┘                │
│                                         │
│         ┌──────────────┐                │
│         │  ✓ (large)   │                │  ← Success animation
│         └──────────────┘                │
│                                         │
│     Payment Submitted!                  │
│  ₹4,000 for July tuition                │
│  Reference: REQ-001                     │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ ⏱ Status: Pending Verification │    │  ← Status card
│  │ Principal will review your      │    │
│  │ proof and notify you.           │    │
│  │                                 │    │
│  │ You can track this in           │    │
│  │ Payment History.                │    │
│  └─────────────────────────────────┘    │
│                                         │
│  [ View Payment History ]  [ Done ]     │
└─────────────────────────────────────────┘
```

#### Key Improvements
1. **3 steps in 1 screen** — no navigation between Selection → Form → Success
2. **Step indicator** shows progress clearly
3. **Month selection** is Step 1 — parent confirms what they're paying first
4. **UTR + Upload** are on the same screen — less scrolling, clearer context
5. **Success state** is in-screen, not a separate screen — natural flow back

#### Smart Navigation Logic
```dart
void _startPayment(Map<String, dynamic> fee) {
  final pendingFees = _getPendingFees();
  
  if (pendingFees.length == 1) {
    // Skip selection — go straight to payment flow
    _openPaymentFlow(pendingFees.first);
  } else {
    // Show minimal selection (bottom sheet, not full screen)
    _showFeeSelectionSheet(pendingFees);
  }
}
```

---

### Screen 3: ParentPaymentHistory (Cleaned Up)

**Lines:** ~150  
**Concept:** Timeline-style payment history with clear status indicators

#### Wireframe

```
┌─────────────────────────────────────────┐
│  ← Payment History                      │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ ✓  ₹4,000 — July Tuition        │   │  ← Timeline item (verified)
│  │    08 Jul 2026 · UPI             │   │
│  │    Ref: REQ-001                  │   │
│  │    [ View Receipt ]              │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ ⏱  ₹12,000 — Jun Tuition       │   │  ← Timeline item (pending)
│  │    01 Jul 2026 · UPI             │   │
│  │    Status: Pending Verification  │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ ⚠  ₹8,000 — May Tuition        │   │  ← Timeline item (clarification)
│  │    15 Jun 2026 · UPI             │   │
│  │    Status: Clarification Needed  │   │
│  │    [ Resubmit Proof ]            │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ── older ──────────────────────────    │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ ✓  ₹3,500 — Book & Kit          │   │  ← Timeline item (paid)
│  │    01 May 2026 · UPI             │   │
│  │    [ View Receipt ]              │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

#### Key Improvements
1. **Timeline layout** — visual hierarchy with status icons on the left
2. **No duplicate history** — standalone screen only, removed from main hub tabs
3. **Inline actions** — "Resubmit" and "View Receipt" directly on the card
4. **Date grouping** — "older" divider for scannability

---

### Screen 4: ParentReceiptView (Minor Polish)

**Lines:** ~120  
**Concept:** Cleaner receipt with share/print CTA

#### Wireframe

```
┌─────────────────────────────────────────┐
│  ← Receipt                              │
├─────────────────────────────────────────┤
│  ┌──────────────────────────────────┐   │
│  │ 🏫 ABC School                    │   │  ← Header
│  │ Payment Receipt                  │   │
│  └──────────────────────────────────┘   │
│                                         │
│  Receipt No     RCP-001                 │
│  Transaction    TXN-123456              │
│  Date           08 Jul 2026             │
│  Mode           UPI                     │
│  Status         ✓ Successful            │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ Tuition Fee (July)     ₹4,000    │   │  ← Line items
│  └──────────────────────────────────┘   │
│                                         │
│  Total Paid               ₹4,000        │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ Computer generated receipt       │   │
│  └──────────────────────────────────┘   │
│                                         │
│  [ 📤 Share ]  [ 🖨 Print ]  [ Done ]   │  ← Action buttons
└─────────────────────────────────────────┘
```

---

### Parent Role — Screen Count Comparison

| Before | After |
|---|---|
| ParentFeesScreen (900 lines) | ParentFeeHub (~350 lines) |
| PaymentSelectionScreen (~180 lines) | ParentPaymentFlow (~500 lines) |
| PaymentRequestFormScreen (~600 lines) | (merged into PaymentFlow) |
| PaymentSuccessScreen (~140 lines) | (merged into PaymentFlow) |
| PaymentHistoryScreen (~190 lines) | ParentPaymentHistory (~150 lines) |
| ReceiptViewScreen (~200 lines) | ParentReceiptView (~120 lines) |
| **Total: 6 screens, ~2,210 lines** | **Total: 4 screens, ~1,120 lines** |

---

## 3. Optimized Principal Role Screens

### Screen 1: PrincipalFeeDashboard (Replaces AdminFeesScreen)

**Lines:** ~400 (down from ~900)  
**Concept:** Dashboard with metrics + quick actions + pending items

#### Wireframe

```
┌─────────────────────────────────────────┐
│  ☰  Fees                        [↻]    │
│                                         │
│  ┌──────┬──────┬──────┬──────┐          │
│  │₹2.4L │₹8.6L │  12  │  5   │          │  ← 4 KPI tiles
│  │Due   │Collec│Struct│Conces│         │     (2x2 grid)
│  └──────┴──────┴──────┴──────┘          │
│                                         │
│  ── Needs Attention ────────────────    │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ ⚠ 5 Payment Requests Pending     │   │  ← Action card
│  │ Parents waiting for review       │   │     (tappable, badge)
│  │                    [ Review → ]  │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ── Quick Actions ──────────────────    │
│                                         │
│  [ 📋 Fee Structures  ]  [ 📄 Generate ]│  ← 2x2 action grid
│  [ 💰 Collect Fee     ]  [ 📊 Reports  ]│
│                                         │
│  ── Payment QR ─────────────────────    │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ QR: Active (school@upi)    [→]   │   │  ← Compact QR status
│  └──────────────────────────────────┘   │
│                                         │
│  ── Outstanding Aging ──────────────    │
│                                         │
│  [0-30d: 5] [31-60d: 3] [61+: 2]        │  ← Aging buckets
│                                         │
│  ── Collection Progress ────────────    │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │  ████████████░░░░ 69%            │   │  ← Progress bar
│  │  ₹8.6L collected of ₹12.4L       │   │
│  └──────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

#### Key Improvements
1. **Dashboard-first approach** — no sub-view tabs, just actionable metrics
2. **Needs Attention section** — surfaces payment requests immediately
3. **QR config** is compact — just shows status, tap to edit
4. **Quick actions** are grid-based — faster to scan than a mode selector

---

### Screen 2: PrincipalFeeStructures (Dedicated)

**Lines:** ~250  
**Concept:** Dedicated structures screen with inline create/edit

#### Wireframe

```
┌─────────────────────────────────────────┐
│  ← Fee Structures                [+]    │
│                                         │
│  [ 2025-2026 ▼ ]  🔍 [Search...]        │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 💰 Tuition Fee — Class 5-A       │   │  ← Structure card
│  │ ₹12,000 · yearly · due day 10    │   │
│  │                                  │   │
│  │ 14 students · 12 invoices        │   │  ← Usage stats
│  │                                  │   │
│  │ [ Edit ]  [ Delete ]             │   │  ← Actions
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 💰 Book & Kit — Class 5          │   │
│  │ ₹3,500 · one_time · due day 5    │   │
│  │ 14 students · 14 invoices        │   │
│  │ [ Edit ]  [ Delete ]             │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ── Class Summary ──────────────────    │
│                                         │
│  Class 5: ₹15,500 total (2 components)  │  ← Summary row
│  Class 3: ₹14,000 total (2 components)  │
│  Class 1: ₹12,000 total (1 component)   │
│                                         │
└─────────────────────────────────────────┘
```

---

### Screen 3: PrincipalInvoiceGenerate (Streamlined)

**Lines:** ~300  
**Concept:** Focused invoice generation wizard

#### Wireframe

```
┌─────────────────────────────────────────┐
│  ← Generate Invoices                    │
│                                         │
│  Step 1: Scope                          │
│  ┌──────────────────────────────────┐   │
│  │ Year: [2025-2026 ▼]              │   │
│  │ Class: [Class 5 ▼]               │   │
│  │ Scope: [Class] [Section][Student]│   │
│  └──────────────────────────────────┘   │
│                                         │
│  Step 2: Settings                       │
│  ┌──────────────────────────────────┐   │
│  │ Label: [July 2026           ]    │   │
│  │ Due:   [2026-07-15          ]    │   │
│  │ Installments: [3 ▼]              │   │
│  │ [ ] Include one-time             │   │
│  │ [ ] Include yearly               │   │
│  └──────────────────────────────────┘   │
│                                         │
│  Step 3: Preview                        │
│  ┌──────────────────────────────────┐   │
│  │ 📊 Will generate 14 invoices     │   │
│  │ Estimated: ₹4,000/student        │   │
│  │ Total: ₹56,000                   │   │
│  └──────────────────────────────────┘   │
│                                         │
│  [ ████ Generate Invoices reports ████ ]│
└─────────────────────────────────────────┘
```

---

### Screen 4: PrincipalCollectFee (Streamlined)

**Lines:** ~350  
**Concept:** Quick payment recording — 2-step flow

#### Wireframe

```
┌─────────────────────────────────────────┐
│  ← Collect Fee                          │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 🔍 [Search student...        ]   │   │  ← Search-first
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 👤 Aarav Kumar — Class 5-A       │   │  ← Selected student
│  │ Due: ₹18,000                      │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ Tuition months:                  │   │
│  │ [Jun✓] [Jul●] [Aug] [Sep] [Oct]  │   │  ← Month picker
│  │ [Nov] [Dec] [Jan] [Feb] [Mar]    │   │
│  │                                  │   │
│  │ Amount: [ ₹6,000   ]             │   │  ← Auto-calculated
│  │                                  │   │
│  │ Mode: [Cash]                     │   │  ← Mode selector
│  │ Date: [08 Jul 2026 📅]           │   │
│  │ Ref:  [              ]           │   │
│  └──────────────────────────────────┘   │
│                                         │
│  [ ███████ Record ₹6,000 ████████ ]    │
└─────────────────────────────────────────┘
```

---

### Screen 5: PrincipalPaymentRequests (Optimized)

**Lines:** ~350  
**Concept:** Kanban-style or list with swipe actions

#### Wireframe

```
┌─────────────────────────────────────────┐
│  ← Payment Requests              [↻]    │
│                                         │
│  ┌───────┬────────┬────────┬──────┐     │
│  │ ⏱ 5  │ ❓ 2   │ ✓ 12   │ ✗ 1 │     │  ← KPI strip
│  │Pending│Clarif  │Approved│Rej.  │     │
│  └───────┴────────┴────────┴──────┘     │
│                                         │
│  Filter: [All pending ▼]                │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 👤 Aarav Kumar · ₹4,000          │   │
│  │ UPI · REQ-001 · Jul 08           │   │
│  │                                  │   │
│  │ [ View Proof ]  [ Review → ]     │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 👤 Priya Sharma · ₹3,000         │   │
│  │ UPI · REQ-002 · Jul 07           │   │
│  │                                  │   │
│  │ [ View Proof ]  [ Review → ]     │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ... (auto-load more on scroll)         │
└─────────────────────────────────────────┘
```

---

### Screen 6: PrincipalPaymentDecision (Compact)

**Lines:** ~200  
**Concept:** Bottom sheet modal (not full screen)

#### Wireframe — Bottom Sheet

```
┌─────────────────────────────────────────┐
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━    │  ← Drag handle
│                                         │
│  Payment Decision                       │
│                                         │
│  👤 Aarav Kumar · ₹4,000                │
│  UPI · REQ-001 · Jul 08                 │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 📷 (proof image preview)         │   │  ← Tap to expand
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────┐ ┌──────────┐ ┌──────────┐     │
│  │ ✓OK  │ │? Clarify │ │\✗ Reject│     │  ← Decision buttons
│  └──────┘ └──────────┘ └──────────┘     │
│                                         │
│  Remarks (required for reject/clarify): │
│  ┌──────────────────────────────────┐   │
│  │ [                           ]    │   │
│  └──────────────────────────────────┘   │
│                                         │
│  [ ███████ Submit Decision ███████ ]    │
└─────────────────────────────────────────┘
```

#### Key Improvements
1. **Bottom sheet** — doesn't leave the list context
2. **Compact decision buttons** — visual, not radio buttons
3. **Inline proof preview** — no need to open separate image viewer
4. **Swipe to dismiss** — natural mobile interaction

---

### Screen 7: PrincipalReports (Simplified)

**Lines:** ~200  
**Concept:** Report cards with one-tap generation

#### Wireframe

```
┌─────────────────────────────────────────┐
│  ← Reports                        [↻]   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 📊 Collection Summary            │   │  ← Report card
│  │ Total: ₹12.4L · Collected: ₹8.6L │   │
│  │ Outstanding: ₹3.8L               │   │
│  │ Rate: 69%                        │   │
│  │                                  │   │
│  │ [ 📥 PDF ]  [ 📊 CSV ]           │   │  ← Format buttons
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 📋 Class Wise Breakdown          │   │
│  │ Class 5: ₹8.6L collected         │   │
│  │ Class 3: ₹5.2L collected         │   │
│  │ [ 📥 PDF ]  [ 📊 CSV ]           │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 👤 Student Wise Report           │   │
│  │ 120 students · 5 with dues       │   │
│  │ [ 📥 PDF ]  [ 📊 CSV ]           │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ ⏰ Outstanding Aging             │   │
│  │ 0-30d: 5 · 31-60d: 3 · 61+: 2    │   │
│  │ [ 📥 PDF ]  [ 📊 CSV ]           │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 📅 Daily Collection              │   │
│  │ Today: ₹12,000 · Week: ₹85,000   │   │
│  │ [ 📥 PDF ]  [ 📊 CSV ]           │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

---

### Screen 8: PrincipalPaymentConfig (Focused)

**Lines:** ~150  
**Concept:** Clean config with live preview

#### Wireframe

```
┌─────────────────────────────────────────┐
│  ← Payment Config                       │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ QR Image                         │   │
│  │ ┌──────────────────────────┐     │   │
│  │ │    (uploaded QR image)   │     │   │  ← Live preview
│  │ └──────────────────────────┘     │   │
│  │ [ Change QR ]                    │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ UPI ID    [ school@upi      ]    │   │
│  │ Payee     [ ABC School      ]    │   │
│  │ Note      [ School fee...   ]    │   │
│  │                                  │   │
│  │ [ Save Changes ]                 │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │ 👀 Preview (as parent sees it)   │   │  ← Live preview
│  │ ┌──────────────────────────┐     │   │     of what parents see
│  │ │   QR Code + UPI ID       │     │   │
│  │ └──────────────────────────┘     │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

---

### Principal Role — Screen Count Comparison

| Before | After |
|---|---|
| AdminFeesScreen (~900 lines) | PrincipalFeeDashboard (~400 lines) |
| AdminFeeStructureFormScreen (~250 lines) | (inline in FeeStructures) |
| AdminInvoiceGenerationFormScreen (~200 lines) | PrincipalInvoiceGenerate (~300 lines) |
| AdminPaymentRecordFormScreen (~180 lines) | PrincipalCollectFee (~350 lines) |
| AdminPaymentRequestsScreen (~300 lines) | PrincipalPaymentRequests (~350 lines) |
| AdminPaymentRequestDecisionScreen (~220 lines) | PrincipalPaymentDecision (~200 lines) |
| FeeStructuresScreen (~170 lines) | PrincipalFeeStructures (~250 lines) |
| FeeReportsScreen (~170 lines) | PrincipalReports (~200 lines) |
| FeePaymentConfigScreen (~150 lines) | PrincipalPaymentConfig (~150 lines) |
| **Total: 9 screens, ~2,540 lines** | **Total: 8 screens, ~2,200 lines** |

---

## 4. Unified Component System

### New Shared Components to Add

| Component | Purpose | Replaces |
|---|---|---|
| `FeeHeroCard` | Balance + CTA card (parent) | DueSummaryCard |
| `FeeKpiStrip` | Horizontal KPI metrics | OpsMetricCard (inline) |
| `FeeActionCard` | Tappable card with icon + badge | FeeActionRow (modified) |
| `FeeTimelineItem` | History timeline entry | Payment tile (inline) |
| `FeeProofPreview` | Image/PDF proof viewer | Duplicated across screens |
| `FeeStepIndicator` | Step progress indicator | (new) |
| `FeeMonthPicker` | Reusable month selector | Duplicated in 3 places |
| `FeeSearchDropdown` | Searchable student picker | Basic DropdownButton |

### Component Usage Matrix

```
                    FeeHeroCard  FeeKpiStrip  FeeMonthPicker  FeeProofPreview
ParentFeeHub            ✓
ParentPaymentFlow                    ✓           ✓
ParentPaymentHistory                              ✓
PrincipalDashboard      ✓           ✓
PrincipalCollectFee                  ✓           ✓
PrincipalPaymentRequests              ✓                       ✓
PrincipalPaymentDecision                                  ✓
```

---

## 5. Navigation Architecture

### Parent Role — Navigation Tree

```
ParentFeeHub
├── [Pay Now] → ParentPaymentFlow (3 steps, single screen)
├── [Pay fee on item] → ParentPaymentFlow (pre-filled)
├── [View Receipt] → ParentReceiptView
├── [Payment History] → ParentPaymentHistory
├── [Resubmit Proof] → ParentPaymentFlow (clarification variant)
└── [Fee Types] → (inline section in hub, not separate screen)
```

### Principal Role — Navigation Tree

```
PrincipalFeeDashboard
├── [Review Requests] → PrincipalPaymentRequests
│   └── [Review] → PrincipalPaymentDecision (bottom sheet)
├── [Fee Structures] → PrincipalFeeStructures
│   └── [+] → FeeStructureFormScreen (full screen)
├── [Generate Invoices] → PrincipalInvoiceGenerate
├── [Collect Fee] → PrincipalCollectFee
├── [Reports] → PrincipalReports
└── [Payment Config] → PrincipalPaymentConfig
```

### Route Map (New)

```dart
// Parent routes
'/parent/fee-hub'                    // Main hub
'/parent/payment-flow'               // 3-step payment form
'/parent/payment-history'            // Timeline history
'/parent/receipt'                    // Receipt view

// Principal routes
'/principal/fee-dashboard'           // Main dashboard
'/principal/fee-structures'          // Structures list
'/principal/fee-structure-form'      // Create/edit form
'/principal/invoice-generate'        // Invoice generation
'/principal/collect-fee'             // Payment recording
'/principal/payment-requests'        // Request list
'/principal/payment-decision'        // Decision (can be bottom sheet)
'/principal/fee-reports'             // Reports
'/principal/payment-config'          // UPI/QR config
```

---

## 6. Implementation Roadmap

### Phase 1: Parent Role (Week 1-2)

| Task | Effort | Priority |
|---|---|---|
| Create `ParentFeeHub` screen | 3 days | P0 |
| Create `ParentPaymentFlow` (3-step form) | 4 days | P0 |
| Refactor `ParentPaymentHistory` to timeline | 1 day | P1 |
| Add `FeeMonthPicker` shared component | 1 day | P1 |
| Add `FeeHeroCard` shared component | 0.5 day | P1 |
| Update routes and navigation | 1 day | P0 |
| Integration testing | 2 days | P0 |

### Phase 2: Principal Role (Week 3-4)

| Task | Effort | Priority |
|---|---|---|
| Create `PrincipalFeeDashboard` | 3 days | P0 |
| Refactor `FeeStructuresScreen` | 2 days | P1 |
| Create `PrincipalCollectFee` (streamlined) | 2 days | P1 |
| Create `PrincipalPaymentRequests` (optimized) | 2 days | P1 |
| Convert decision to bottom sheet | 1 day | P2 |
| Create `PrincipalReports` | 1 day | P2 |
| Update routes and navigation | 1 day | P0 |

### Phase 3: Polish & Testing (Week 5)

| Task | Effort | Priority |
|---|---|---|
| Add `FeeKpiStrip` component | 0.5 day | P2 |
| Add `FeeProofPreview` component | 1 day | P2 |
| Add `FeeSearchDropdown` component | 0.5 day | P2 |
| Performance optimization (caching, lazy loading) | 2 days | P1 |
| End-to-end testing | 2 days | P0 |
| Accessibility audit | 1 day | P2 |

### Migration Strategy

1. **Don't break existing screens** — build new screens alongside old ones
2. **Feature flag** — toggle between old and new via `FeatureFlagService`
3. **Gradual rollout** — start with parent role (higher user volume)
4. **Keep shared widgets** — fee_widgets.dart and fee_models.dart stay as-is
5. **Deprecate old screens** — remove after 2 release cycles

---

## Appendix: Migration Checklist

### Files to Create
- [ ] `lib/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart`
- [ ] `lib/features/finance/presentation/screens/parent_hub/parent_payment_flow.dart`
- [ ] `lib/features/finance/presentation/screens/parent_hub/parent_payment_history_v2.dart`
- [ ] `lib/features/finance/presentation/screens/parent_hub/parent_receipt_view_v2.dart`
- [ ] `lib/features/finance/presentation/screens/principal_dashboard/principal_fee_dashboard.dart`
- [ ] `lib/features/finance/presentation/screens/principal_dashboard/principal_collect_fee.dart`
- [ ] `lib/features/finance/presentation/screens/principal_dashboard/principal_payment_requests_v2.dart`
- [ ] `lib/features/finance/presentation/screens/principal_dashboard/principal_payment_decision_sheet.dart`
- [ ] `lib/features/finance/presentation/screens/principal_dashboard/principal_reports_v2.dart`

### Files to Update
- [ ] `lib/routes/app_routes.dart` — add new routes
- [ ] `lib/routes/route_access_guard.dart` — add route permissions
- [ ] `lib/routes/schooldesk_screen_registry.dart` — register new screens
- [ ] `lib/app/module_registry.dart` — add module routes

### Files to Deprecate (After Migration)
- [ ] `lib/features/finance/presentation/screens/parent_fees_screen/parent_fees_screen.dart`
- [ ] `lib/features/finance/presentation/screens/parent_payment_screens/parent_payment_selection_screen.dart`
- [ ] `lib/features/finance/presentation/screens/parent_fees_screen/parent_payment_request_form_screen.dart`
- [ ] `lib/features/finance/presentation/screens/parent_payment_screens/parent_payment_success_screen.dart`
- [ ] `lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart`
- [ ] `lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_request_decision_screen.dart`

---

*End of Optimized Design Document*

# 💳 SchoolDesk Fees — Manual UPI Payment UX Design

> **Design Philosophy:** No payment gateway SDK, no UPI intent/URL launching. Parents pay manually via their installed UPI apps (Google Pay, PhonePe, Paytm, BHIM, etc.). The app simply shows which UPI apps are installed — the parent taps one, enters the amount themselves, makes the payment, returns to SchoolDesk, and uploads proof for principal verification. Principal manages fees manually from time to time.

---

## 📋 Table of Contents

1. [Current State Analysis](#-current-state-analysis)
2. [Design Goals](#-design-goals)
3. [App Store / Play Store Policy Notes](#-app-store--play-store-policy-notes)
4. [Architecture Overview](#-architecture-upi-app-picker--manual-payment)
5. [Screen-by-Screen Wireframes (Parent)](#-parent-role--screen-by-screen-wireframes)
6. [Screen-by-Screen Wireframes (Principal)](#-principal-role--screen-by-screen-wireframes)
7. [Payment Flow Diagrams](#-payment-flow-diagrams)
8. [File Changes Required](#-files-to-modify--create)
9. [Implementation Planning](#-implementation-planning)
10. [Design Tokens](#-design-tokens-to-follow)

---

## 📋 Current State Analysis

### What Already Works

| Component | Status | Notes |
|-----------|--------|-------|
| Parent fees dashboard | ✅ Working | Tab-based: Fees, Payments, Fee Types |
| Payment request form | ✅ Working | QR display, UTR input, screenshot upload, tuition month select |
| Payment history | ✅ Working | Lists all payments with status |
| Receipt generation | ✅ Working | PDF receipts via PdfService |
| Principal admin fees screen | ✅ Working | Structures, invoices, payments, concessions, reports |
| Principal payment requests | ✅ Working | Lists parent-submitted payment requests |
| Principal payment decision | ✅ Working | Approve/reject/clarify with proof preview |
| Payment config (UPI ID, QR) | ✅ Working | Principal sets UPI ID + QR image for parents |
| Backend API | ✅ Working | `submitFeePaymentProof`, `resubmitFeePaymentProof`, `decideParentPaymentRequest` |

### What Needs Enhancement

| Gap | Current State | Target State |
|-----|--------------|--------------|
| UPI app access | ❌ Parent must manually copy UPI ID, leave app, find UPI app | ✅ Shows installed UPI apps as a grid — parent taps one to open |
| Payment method clarity | ⚠️ Single "Pay fee" button, no method choice | ✅ Clear screen showing available UPI apps + manual option |
| Principal fee updates | ⚠️ Fee structures exist but manual updates are cumbersome | ✅ Streamlined manual fee update flow |
| Payment proof flow | ⚠️ Works but has friction points | ✅ Simplified proof submission with guided steps |

### What Stays Exactly As-Is

- Tuition month selection logic (continuous unpaid month range)
- Payment intent creation (`createFeePaymentIntent`)
- Proof upload + UTR submission (`submitFeePaymentProof`)
- Principal approve/reject/clarify flow
- Receipt PDF generation
- Fee structure CRUD
- Invoice generation
- All existing backend APIs
- QR code display for manual scanning (existing QR image + Copy UPI ID)

---

## 🎯 Design Goals

| Goal | How We Solve It |
|------|----------------|
| Easy UPI app access | Show grid of installed UPI apps — parent taps one to open it |
| Simple payment | Parent enters amount in UPI app manually (no deep links, no pre-fill) |
| Proof submission | Parent returns to app, uploads screenshot + enters UTR |
| Principal manual updates | Existing fee structure form + quick-edit on pending invoices |
| Receipt on approval | Existing PDF receipt generation, no changes needed |

---

## 📱 App Store / Play Store Policy Notes

### Is this approach allowed on app stores?

**✅ YES — fully allowed on both Google Play Store and Apple App Store.**

This is the simplest possible approach — we're not even opening the UPI app programmatically. We just detect which UPI apps are installed and show them to the user. The parent taps one and the OS opens it. This is identical to how a contacts app shows "Open in WhatsApp" or "Open in Telegram".

1. **No payment processing:** Our app never handles payment credentials, amounts, or UPI payloads.
2. **No deep links:** We don't construct `upi://pay` URIs or use `url_launcher` for payments.
3. **No QR generation for payment:** We only show the school's QR image for reference.
4. **App Store review:** Simply state "This app lists installed UPI payment apps for user convenience. All payment processing happens entirely within the third-party UPI app."

### What if no UPI app is installed?

- Show a message: "No UPI app found. Please install Google Pay, PhonePe, Paytm, or BHIM."
- Still allow manual UPI ID copy + payment proof upload as fallback

---

## 🏗️ Architecture: UPI App Picker + Manual Payment

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   PARENT APP │    │   BACKEND    │    │  UPI APP     │
│  (Flutter)   │    │  (Server)    │    │  (External)  │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
  1. Select fee/invoice   │                   │
  2. Choose tuition months│                   │
       │                   │                   │
  3. Create payment       │                   │
     reference (intent)   │                   │
       │──────────────────>│                   │
       │<──────────────────│                   │
       │                   │                   │
  4. Show UPI apps grid   │                   │
  5. Parent taps an app   │                   │
  6. OS opens UPI app ───────────────────────>│
       │                   │                   │
  7. Parent enters amount ────────────────────>│
     and pays manually     │                   │
       │                   │                   │
  8. Parent returns to app │                   │
  9. Enter UTR number     │                   │
  10. Upload screenshot   │                   │
  11. Submit proof ──────>│                   │
       │                   │                   │
       │                   │  12. Notification │
       │                   │──────────────────>│ Principal
       │                   │                   │
  13. Principal reviews   │                   │
  14. Approves/Rejects    │                   │
       │<──────────────────│                   │
  15. Receipt generated   │                   │
```

### Key Packages

| Package | Purpose | Already in project? |
|---------|---------|-------------------|
| `device_apps` | Detects installed UPI apps on the device | ❌ Need to add |
| `qr_flutter` | Generates QR codes for display | ✅ Yes |
| `clipboard` | Copies UPI ID to clipboard | ✅ Built-in |

**NOT needed:**
- ❌ `url_launcher` — NOT used for UPI payments
- ❌ `mobile_scanner` — NOT needed (no QR scanning)
- ❌ Any UPI SDK — NOT integrated

---

## 📱 Parent Role — Screen-by-Screen Wireframes

### SCREEN 1: Parent Fees Dashboard (Current — Minimal Changes)

```
┌─────────────────────────────────────┐
│ ← My Fees                     ☰    │
│ Fee overview, installments & pay    │
├─────────────────────────────────────┤
│                                     │
│  ┌─────┐ ┌─────┐ ┌─────┐          │
│  │Arjun│ │Priya│ │+ Add│ ← Child  │
│  └──●──┘ └─────┘ └─────┘   Selector│
│                                     │
│  ── Fees Tab ───────────────────    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 💰 Tuition & Fees           │    │
│  │ Next Fee Due: ₹5,000        │    │
│  │ Due by 15 Jul 2026          │    │
│  │                    [Pay fee]│    │
│  └─────────────────────────────┘    │
│                                     │
│  ── Fee Items ──────────────────    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 📋 Tuition Fee - Jul 2026   │    │
│  │ Due: 15 Jul 2026            │    │
│  │ Amount: ₹5,000    [Pay fee]│    │
│  ├─────────────────────────────┤    │
│  │ 📋 Annual Library Fee       │    │
│  │ Due: 01 Aug 2026            │    │
│  │ Amount: ₹2,000    [Pay fee]│    │
│  └─────────────────────────────┘    │
│                                     │
│  ── Payments Tab ───────────────    │
│   ✅ Tuition Jun · ₹5,000 · Paid  │
│   🔄 Tuition Jul · ₹5,000 · Pending│
│                                     │
│  ── Fee Types Tab ──────────────    │
│   Tuition · ₹5,000/mo              │
│   Library · ₹2,000 one-time        │
│                                     │
│  [🏠 Home] [📅 Cal] [👤 Profile]    │
└─────────────────────────────────────┘
```

**Changes:** Minimal — only the "Pay fee" button behavior changes (navigates to new payment screen with UPI app grid).

---

### SCREEN 2: Choose Payment Method (NEW)

```
┌─────────────────────────────────────┐
│ ← Pay Fee                           │
│ Choose how to pay                   │
├─────────────────────────────────────┤
│                                     │
│  Tuition Fee — Jul 2026             │
│  Student: Arjun Kumar · Class 5A    │
│  Amount Due: ₹5,000                 │
│                                     │
│  ── Tuition Month Selection ───     │
│  (Existing chip-based selector)     │
│  [May Paid] [Jun Paid] [● Jul]     │
│  [Aug] [Sep] [Oct]                 │
│                                     │
│  Selected: 1 month · ₹5,000        │
│                                     │
│  ── Select a UPI App to Pay ───    │
│                                     │
│  ┌─────┐  ┌─────┐  ┌─────┐       │
│  │     │  │     │  │     │       │
│  │ GPay│  │Phone│  │Paytm│       │
│  │     │  │ Pe  │  │     │       │
│  └─────┘  └─────┘  └─────┘       │
│                                     │
│  ┌─────┐  ┌─────┐  ┌─────┐       │
│  │     │  │     │  │     │       │
│  │ BHIM│  │Other│  │     │       │
│  │     │  │ UPI │  │     │       │
│  └─────┘  └─────┘  └─────┘       │
│                                     │
│  (Only apps installed on your       │
│   device are shown above)           │
│                                     │
│  ── Or Pay Manually ────────────   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📋 Copy UPI ID & Pay        │   │
│  │                             │   │
│  │ View QR code and copy the   │   │
│  │ school UPI ID to pay in any │   │
│  │ UPI app of your choice      │   │
│  │                        [→]  │   │
│  └─────────────────────────────┘   │
│                                     │
│  ⚠️ After payment, upload your     │
│  payment screenshot and UTR for    │
│  principal verification.           │
│                                     │
└─────────────────────────────────────┘
```

**Key Design Decisions:**
- Grid of installed UPI apps with recognizable icons
- Only apps actually installed on the device are shown
- "Other UPI" option for apps not detected
- "Copy UPI ID & Pay" fallback shows existing QR + copy flow
- Tuition month selection is preserved exactly as-is above the app grid
- No deep links, no intent launching — parent taps an app and it opens normally

---

### SCREEN 3: UPI App Opened — Reminder (NEW)

```
┌─────────────────────────────────────┐
│ ← Paying with PhonePe               │
│ Remember these details              │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │  ⚠️ Payment Reminder        │   │
│  │                             │   │
│  │  Your UPI app is opening.   │   │
│  │  When paying, please note:  │   │
│  │                             │   │
│  │  Amount: ₹5,000             │   │
│  │  Payee: Greenwood Academy   │   │
│  │  UPI ID: school@upi         │   │
│  │  Reference: FPR-2026-0042   │   │
│  │                             │   │
│  │  After payment, come back   │   │
│  │  and upload your proof.     │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  💡 Tips:                           │
│  • Note the UTR/transaction ID     │
│  • Take a screenshot of success    │
│  • Enter the exact amount ₹5,000   │
│                                     │
│  ┌───────────────────────────┐     │
│  │  OPEN PHONEPE             │     │
│  └───────────────────────────┘     │
│                                     │
│  ┌───────────────────────────┐     │
│  │  I've completed payment   │     │
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

**Key Design Decisions:**
- Shows BEFORE opening the UPI app so parent knows what to pay
- Displays amount, payee name, UPI ID, and reference number
- Tips section reminds parent to note UTR and take screenshot
- "OPEN [APP]" button simply opens the UPI app (using `device_apps` or standard app launch)
- "I've completed payment" navigates to proof upload screen
- Parent can also just press back to return to proof upload

---

### SCREEN 4: Upload Payment Proof (Existing — Streamlined)

```
┌─────────────────────────────────────┐
│ ← Upload Payment Proof              │
│ Submit proof for verification        │
├─────────────────────────────────────┤
│                                     │
│  Tuition Fee — Jul 2026             │
│  Student: Arjun Kumar · ₹5,000     │
│  Reference: FPR-2026-0042           │
│                                     │
│  Step 1: UPI Transaction ID (UTR)   │
│  ┌─────────────────────────────┐   │
│  │ Enter the UTR from your     │   │
│  │ UPI app payment screen      │   │
│  │ ┌───────────────────────┐   │   │
│  │ │ 123456789012           │   │   │
│  │ └───────────────────────┘   │   │
│  └─────────────────────────────┘   │
│                                     │
│  Step 2: Payment Date               │
│  ┌─────────────────────────────┐   │
│  │ 2026-07-06                  │   │
│  └─────────────────────────────┘   │
│                                     │
│  Step 3: Upload Screenshot          │
│  Take a screenshot of the UPI      │
│  payment success screen and         │
│  upload it below.                   │
│  ┌─────────────────────────────┐   │
│  │  📷 Tap to upload screenshot │   │
│  └─────────────────────────────┘   │
│  (jpg, png, or pdf)                │
│                                     │
│  Step 4: Notes (optional)           │
│  ┌─────────────────────────────┐   │
│  │ Notes for school office      │   │
│  └─────────────────────────────┘   │
│                                     │
│  ⚠️ Your payment will be verified   │
│  by the principal.                  │
│                                     │
│  ┌───────────────────────────┐     │
│  │  SUBMIT PROOF ₹5,000      │     │
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

**Changes from current:**
- Cleaner step-by-step layout (1, 2, 3, 4)
- Reference number pre-filled from payment intent
- Same UTR + screenshot flow, but with better guidance
- Existing tuition month selection + amount calculation preserved

---

### SCREEN 5: Manual UPI Payment (Existing — QR + Copy ID)

```
┌─────────────────────────────────────┐
│ ← Manual UPI Payment                │
│ Scan QR or copy UPI ID              │
├─────────────────────────────────────┤
│                                     │
│  Tuition Fee — Jul 2026             │
│  Amount: ₹5,000                     │
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │      ┌──────────────┐       │   │
│  │      │              │       │   │
│  │      │   [QR CODE]  │       │   │
│  │      │              │       │   │
│  │      └──────────────┘       │   │
│  │                             │   │
│  │  UPI ID: school@upi        │   │
│  │  Name: Greenwood Academy   │   │
│  │                             │   │
│  │  [📋 Copy UPI ID]          │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  After paying, come back here to    │
│  enter UTR and upload proof.        │
│                                     │
│  ┌───────────────────────────┐     │
│  │  I'VE COMPLETED PAYMENT   │     │
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

**Changes from current:**
- "I've completed payment" button replaces the inline form
- Navigates to Step 2 (UTR + screenshot) after tap
- Cleaner separation: payment info screen → proof upload screen

---

### SCREEN 6: Proof Upload After Manual Payment (Existing — Same as Screen 4)

Same as Screen 4 above — parent enters UTR, uploads screenshot, submits proof.

---

### SCREEN 7: Payment History (Current — No Changes)

```
┌─────────────────────────────────────┐
│ ← Payment History                   │
│ All transactions for Arjun          │
├─────────────────────────────────────┤
│                                     │
│  ── July 2026 ────────────────      │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ ✅ Tuition Fee - Jul       │   │
│  │ ₹5,000 · UPI               │   │
│  │ 06 Jul 2026 · Verified      │   │
│  │ Ref: FPR-2026-0042         │   │
│  └─────────────────────────────┘   │
│                                     │
│  ── May 2026 ────────────────       │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🔄 Tuition Fee - May       │   │
│  │ ₹5,000 · UPI               │   │
│  │ 15 May 2026 · 🔍 Pending   │   │
│  │ Awaiting principal review   │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**No changes** — payment history already works correctly.

---

### SCREEN 8: Receipt (Current — No Changes)

```
┌─────────────────────────────────────┐
│ ← Receipt                    ⬇️ 📤  │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │    🏫 GREENWOOD ACADEMY     │   │
│  │    Fee Payment Receipt      │   │
│  │                             │   │
│  │  Receipt No: RCP-2026-0042 │   │
│  │  Date: 06 July 2026        │   │
│  │  Student: Arjun Kumar       │   │
│  │  Class: 5A                  │   │
│  │  Fee Type: Tuition Fee      │   │
│  │  Period: July 2026          │   │
│  │  Amount Paid: ₹5,000       │   │
│  │  Payment Method: UPI        │   │
│  │  Status: ✅ Paid & Verified│   │
│  └─────────────────────────────┘   │
│                                     │
│  [⬇️ Download PDF]  [📤 Share]      │
│                                     │
└─────────────────────────────────────┘
```

**No changes.**

---

## 📱 Principal Role — Screen-by-Screen Wireframes

### SCREEN 9: Principal Fee Home (Current — No Changes)

```
┌─────────────────────────────────────┐
│ ← Fees Management              ⚙️  │
│ Overview & management               │
├─────────────────────────────────────┤
│                                     │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ │
│  │Struct│ │Collect│ │Outst.│ │Reports│
│  │  12  │ │₹3L  │ │₹1L  │ │     │  │
│  └──────┘ └─────┘ └─────┘ └─────┘  │
│                                     │
│  ── Quick Actions ─────────────     │
│  📋 Fee Structures                  │
│  💰 Collect Fee                     │
│  📄 Student Ledger & Dues           │
│  📊 Reports                         │
│                                     │
│  ── Pending Payment Requests ──     │
│  🟡 3 request(s) waiting review     │
│                                     │
│  ── Payment QR Settings ────────    │
│  UPI: school@upi · Active           │
│                                     │
└─────────────────────────────────────┘
```

**No changes.**

---

### SCREEN 10: Principal Payment Requests (Current — No Changes)

```
┌─────────────────────────────────────┐
│ ← Payment Requests                  │
│ Pending parent payment submissions  │
├─────────────────────────────────────┤
│                                     │
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │Pending│ │Clarif.│ │All   │       │
│  │  3   │ │  1   │ │  6   │       │
│  └──────┘ └──────┘ └──────┘       │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 👤 Rahul Sharma             │   │
│  │ Class 3B · Tuition Fee Jun  │   │
│  │ ₹5,000 · UTR: 987654321012 │   │
│  │                             │   │
│  │ 📷 [View Screenshot]       │   │
│  │ [✅ Approve] [❌ Reject]   │   │
│  │ [💬 Ask Clarification]     │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**No changes.**

---

### SCREEN 11: Principal Fee Structure Form (Current — No Changes)

Fee structure CRUD, invoice generation, and manual payment recording are all unchanged.

---

### SCREEN 12: Principal Quick Fee Update (NEW — Streamlined)

```
┌─────────────────────────────────────┐
│ ← Quick Fee Update                  │
│ Adjust amounts for pending invoices │
├─────────────────────────────────────┤
│                                     │
│  Select Class: [5A           ▼]    │
│  Fee Type: [Tuition Fee      ▼]    │
│  Month: [July 2026           ▼]    │
│                                     │
│  ── Affected Students ─────────    │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 👤 Arjun Kumar              │   │
│  │ Current: ₹5,000  New: [    ]│   │
│  │                     [Update]│   │
│  ├─────────────────────────────┤   │
│  │ 👤 Priya Singh              │   │
│  │ Current: ₹5,000  New: [    ]│   │
│  │                     [Update]│   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌───────────────────────────┐     │
│  │  UPDATE ALL SELECTED       │     │
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

**Key Design Decisions:**
- Quick-edit form for adjusting amounts on existing invoices
- Filters by class + fee type + month
- Uses existing `updateRaw` backend API

---

## 🔄 Payment Flow Diagrams

### Flow 1: Pay via UPI App (Primary Flow)

```
Parent                App                Backend             UPI App
 │                    │                    │                    │
 │── Select fee ────>│                    │                    │
 │── Choose months ─>│                    │                    │
 │                    │                    │                    │
 │                    │── Create Intent ──>│                    │
 │                    │<─ reference ──────│                    │
 │                    │                    │                    │
 │── See UPI app     │                    │                    │
 │   grid            │                    │                    │
 │── Tap "PhonePe" ─>│                    │                    │
 │                    │                    │                    │
 │<── Show reminder  │                    │                    │
 │   (amount, payee, │                    │                    │
 │    UPI ID)        │                    │                    │
 │                    │                    │                    │
 │── Tap "Open       │                    │                    │
 │   PhonePe"        │── OS opens ────────────────────────────>│
 │                    │                    │                    │
 │<── UPI app opens ─│────────────────────────────────────────>│
 │── Enter amount ────────────────────────────────────────────>│
 │── Enter UPI PIN ──────────────────────────────────────────>│
 │── Payment success ─│───────────────────────────────────────>│
 │                    │                    │                    │
 │── Return to app ─>│                    │                    │
 │<── Proof upload   │                    │                    │
 │   form            │                    │                    │
 │                    │                    │                    │
 │── Enter UTR ─────>│                    │                    │
 │── Upload proof ──>│                    │                    │
 │── Submit ────────>│── Submit Proof ───>│                    │
 │<── Pending ───────│                    │                    │
 │                    │                    │── Notification ──>│
 │                    │                    │                    │
 │                    │                    │<── Approve ───────│
 │<── Receipt ───────│                    │                    │
```

### Flow 2: Manual UPI Payment (Copy UPI ID)

```
Parent                App                Backend             Principal
 │                    │                    │                    │
 │── Tap "Manual" ──>│                    │                    │
 │<── Show QR + ID ──│                    │                    │
 │── Copy UPI ID ───>│                    │                    │
 │── Open own UPI ──>│                    │                    │
 │── Paste + amount ─>│                    │                    │
 │── Pay ───────────>│                    │                    │
 │── Screenshot ────>│                    │                    │
 │                    │                    │                    │
 │── Return ─────────>│                    │                    │
 │── Tap "I've done" >│                    │                    │
 │<── UTR + proof    │                    │                    │
 │   form            │                    │                    │
 │                    │                    │                    │
 │── Enter UTR ─────>│                    │                    │
 │── Upload proof ──>│── Submit Proof ──>│                    │
 │<── Pending ───────│                    │── Notification ──>│
 │                    │                    │<── Approve ───────│
 │<── Receipt ───────│                    │                    │
```

### Flow 3: Principal Manual Fee Update

```
Principal             App                Backend
 │                    │                    │
 │── Open Fees ─────>│                    │
 │── Tap "Quick     >│                    │
 │   Fee Update"     │                    │
 │                    │                    │
 │── Select class ──>│                    │
 │── Select type ───>│                    │
 │── Select month ──>│                    │
 │                    │── Load invoices ──>│
 │                    │<─ invoice list ───│
 │                    │                    │
 │── Edit amounts ──>│                    │
 │── Tap "Update" ──>│── PATCH invoices ─>│
 │<── Confirmation ──│                    │
```

---

## 📁 Files to Modify / Create

### New Files

| File | Purpose |
|------|---------|
| `lib/features/finance/presentation/screens/parent_payment_screens/parent_payment_method_screen.dart` | NEW — Payment method screen with UPI app grid + manual option |
| `lib/features/finance/presentation/screens/parent_payment_screens/parent_upi_reminder_screen.dart` | NEW — Shows amount/payee/reference reminder before opening UPI app |
| `lib/features/finance/presentation/screens/parent_payment_screens/parent_proof_upload_screen.dart` | NEW — Dedicated UTR + screenshot upload screen (extracted from existing form) |
| `lib/features/finance/presentation/screens/parent_payment_screens/upi_app_detector_service.dart` | NEW — Detects installed UPI apps on device |

### Files to Modify

| File | Changes |
|------|---------|
| `lib/features/finance/presentation/screens/parent_fees_screen/parent_fees_screen.dart` | "Pay fee" button navigates to new Payment Method screen |
| `lib/features/finance/presentation/screens/parent_fees_screen/parent_payment_request_form_screen.dart` | Simplify: split into payment info + proof upload steps |
| `lib/routes/app_routes.dart` | Add routes for new screens |
| `lib/routes/schooldesk_screen_registry.dart` | Register new screens |
| `lib/routes/route_access_guard.dart` | Add route permissions |

---

## 📋 Implementation Planning

### Phase 1: UPI App Grid + Payment Flow (Week 1)

**Goal:** Parent sees installed UPI apps, taps one, gets a reminder, opens it, pays, returns, uploads proof.

| Task | Effort |
|------|--------|
| Create `UpiAppDetectorService` — detect installed UPI apps using `device_apps` package | 2 hours |
| Create `ParentPaymentMethodScreen` — grid of UPI apps + manual fallback | 3 hours |
| Create `ParentUpiReminderScreen` — shows amount, payee, UPI ID, reference before opening UPI app | 2 hours |
| Create `ParentProofUploadScreen` — dedicated UTR + screenshot upload (cleaner step-by-step) | 3 hours |
| Modify `ParentFeesScreen` — "Pay fee" button navigates to new flow | 1 hour |
| Add routes and screen registration | 1 hour |
| Test on Android with Google Pay, PhonePe, Paytm | 2 hours |

**Total: ~14 hours**

### Phase 2: Principal Quick Fee Update (Week 2)

**Goal:** Principal can quickly adjust fee amounts on existing invoices.

| Task | Effort |
|------|--------|
| Add "Quick Fee Update" action to `AdminFeesScreen` | 2 hours |
| Create inline editing UI for invoice amounts (class/type/month filter) | 3 hours |
| Wire to existing `updateRaw` backend API | 1 hour |
| Test bulk update + individual update | 1 hour |

**Total: ~7 hours**

### Phase 3: Polish & Testing (Week 3)

| Task | Effort |
|------|--------|
| Handle edge cases: no UPI app installed, network errors | 2 hours |
| UI polish: animations, loading states, error states | 2 hours |
| Write unit tests for UpiAppDetectorService | 2 hours |
| Write widget tests for payment method screen | 2 hours |
| Full regression test on existing payment flows | 2 hours |

**Total: ~10 hours**

---

## 📊 Summary: What Changes, What Stays

| Component | Change Level | Notes |
|-----------|-------------|-------|
| Tuition month selector | **NO CHANGE** | Preserved exactly as-is |
| UPI app grid | **NEW** | Shows installed apps, parent taps to open |
| UPI reminder screen | **NEW** | Shows amount/payee before opening UPI app |
| Proof upload screen | **NEW** | Clean step-by-step UTR + screenshot upload |
| Manual UPI (QR + Copy ID) | **MINOR** | Split into info screen → proof upload screen |
| Payment history | **NO CHANGE** | Already works |
| Receipt generation | **NO CHANGE** | Already works |
| Principal fee structures | **NO CHANGE** | CRUD already works |
| Principal payment requests | **NO CHANGE** | Approve/reject/clarify already works |
| Principal quick fee update | **NEW** | Quick-edit invoice amounts |
| Backend API | **NO CHANGE** | All endpoints already exist |
| Database schema | **NO CHANGE** | No new tables needed |
| PhonePe SDK | **REMOVED** | Never existed in codebase |
| UPI deep links | **NOT USED** | Parent opens UPI app manually |
| QR code scanning | **NOT USED** | Only QR display for reference |

---

## 🎨 Design Tokens to Follow

| Token | Value | Usage |
|-------|-------|-------|
| Success Green | `context.appTheme.success` | Verified payments, paid status |
| Primary Green | `#1A6B4A` | Header color, primary actions |
| Warning Orange | `context.appTheme.warning` | Pending status |
| Error Red | `context.appTheme.error` | Rejected status, errors |
| Info Blue | `context.appTheme.info` | Clarification status |
| Font (Parent) | `IBM Plex Sans` | Body text, cards |
| Font (Forms) | `DM Sans` | Form inputs, buttons |
| Border Radius (Cards) | `12px` | Fee cards, payment cards |
| Border Radius (Buttons) | `8px` | CTA buttons |
| Border Radius (Chips) | `16px` | Status badges, filters |

---

*Document generated for SchoolDesk Fees Manual UPI Payment UX Design*
*Date: July 6, 2026*
*Approach: UPI app picker + manual payment — no SDK, no deep links, no intent launching*

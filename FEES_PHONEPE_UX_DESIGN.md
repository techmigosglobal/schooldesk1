# 💳 SchoolDesk Fees — Manual UPI Payment UX Redesign

> **Design Philosophy:** No payment gateway SDK. Parents pay manually via their installed UPI apps (Google Pay, PhonePe, Paytm, BHIM, etc.) using a one-tap deep link. Principal manages fees manually from time to time. Parents submit payment proof as attachment for principal verification.

---

## 📋 Table of Contents

1. [Current State Analysis](#-current-state-analysis)
2. [Design Goals](#-design-goals)
3. [App Store / Play Store Policy Notes](#-app-store--play-store-policy-notes)
4. [Architecture Overview](#-architecture-manual-upi-with-deep-link)
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
| UPI URI generation | ✅ Working | `upi://pay?pa=...&pn=...&am=...&cu=INR` already generated |
| Backend API | ✅ Working | `submitFeePaymentProof`, `resubmitFeePaymentProof`, `decideParentPaymentRequest` |

### What Needs Enhancement

| Gap | Current State | Target State |
|-----|--------------|--------------|
| UPI app launch | ❌ Parent must manually copy UPI ID and switch apps | ✅ One-tap "Pay via UPI" opens installed UPI app with pre-filled data |
| QR scanning | ❌ Parent must use external QR scanner | ✅ In-app camera-based QR scanner |
| Payment method clarity | ⚠️ Single "Pay fee" button, no method choice | ✅ Clear "Pay via UPI App" + "Scan & Pay" options |
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

---

## 🎯 Design Goals

| Goal | How We Solve It |
|------|----------------|
| One-tap UPI payment | `url_launcher` opens `upi://pay?pa=...&pn=...&am=...` — parent just enters PIN |
| In-app QR scanning | `mobile_scanner` or `qr_code_scanner` package scans school QR from camera |
| Correct amounts | Pre-filled in UPI deep link and QR payload |
| Principal manual updates | Existing fee structure form + quick-edit on pending invoices |
| Parent proof submission | Existing screenshot upload + UTR entry, streamlined UI |
| Receipt on approval | Existing PDF receipt generation, no changes needed |

---

## 📱 App Store / Play Store Policy Notes

### Is it allowed to launch third-party UPI apps from within our app?

**✅ YES — fully allowed on both Google Play Store and Apple App Store.**

Here's why:

1. **Not a payment aggregator:** Our app never processes, stores, or handles card/bank credentials. We simply open a UPI deep link (`upi://pay://...`) which the OS routes to an installed UPI app.

2. **Standard deep linking pattern:** Thousands of apps (Amazon, Flipkart, Zomato, MakeMyTrip) use this exact pattern. They open UPI apps via intent/deep link without being payment aggregators.

3. **How it works technically:**
   - Android: `Intent.ACTION_VIEW` with `upi://pay?pa=...&pn=...&am=...&cu=INR`
   - iOS: `UIApplication.shared.open(URL(string: "upi://pay?...")!)`
   - The OS shows a chooser dialog if multiple UPI apps are installed

4. **No compliance required:** Since we don't touch payment credentials:
   - ❌ No PCI-DSS compliance needed
   - ❌ No RBI payment aggregator license needed
   - ❌ No KYC integration needed
   - ✅ Just a standard URL launch via `url_launcher`

5. **App Store review notes:**
   - Add a note in App Store/Play Store submission: "This app uses standard UPI deep links to open installed payment apps. No payment credentials are collected or processed by this app."
   - Apple may ask: "Does your app process payments?" → Answer: "No, we launch the user's installed UPI app via standard deep link. Payment happens entirely within the third-party UPI app."

### What if no UPI app is installed?

- Show a fallback message: "No UPI app found. Please install Google Pay, PhonePe, Paytm, or BHIM."
- Still allow manual QR copy + UTR entry as fallback
- The existing manual proof upload flow handles this case

---

## 🏗️ Architecture: Manual UPI with Deep Link

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
  4a. Tap "Pay via UPI"   │                   │
  5. url_launcher opens ──────────────────────>│
     upi://pay?pa=...&am=...  (OS chooser)    │
       │                   │                   │
  6. User enters PIN ─────────────────────────>│
  7. UPI app processes    │                   │
  8. Success screen       │                   │
       │                   │                   │
  9. Return to app        │                   │
  10. Enter UTR number    │                   │
  11. Upload screenshot   │                   │
  12. Submit proof ──────>│                   │
       │                   │                   │
       │                   │  13. Notification  │
       │                   │──────────────────>│ Principal
       │                   │                   │
  14. Principal reviews   │                   │
  15. Approves/Rejects    │                   │
       │<──────────────────│                   │
  16. Receipt generated   │                   │
```

### Key Packages

| Package | Purpose | Already in project? |
|---------|---------|-------------------|
| `url_launcher` | Opens UPI deep links (`upi://pay?...`) | ✅ Yes |
| `mobile_scanner` | In-app QR code scanning from camera | ❌ Need to add |
| `qr_flutter` | Generates QR codes for display | ✅ Yes |
| `clipboard` | Copies UPI ID to clipboard | ✅ Built-in |

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

**Changes:** Minimal — only the "Pay fee" button behavior changes (now opens UPI method selection instead of directly going to form).

---

### SCREEN 2: Payment Method Selection (NEW — Replaces Direct Form Navigation)

```
┌─────────────────────────────────────┐
│ ← Pay Fee                           │
│ Choose how to pay                   │
├─────────────────────────────────────┤
│                                     │
│  Tuition Fee — Jul 2026             │
│  Student: Arjun Kumar · Class 5A    │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Amount Due                   │   │
│  │ ₹5,000                      │   │
│  └─────────────────────────────┘   │
│                                     │
│  ── Tuition Month Selection ───     │
│  (Existing chip-based selector)     │
│  [May Paid] [Jun Paid] [● Jul]     │
│  [Aug] [Sep] [Oct]                 │
│                                     │
│  Selected: 1 month · ₹5,000        │
│                                     │
│  ── How would you like to pay? ──  │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ ⚡ Pay via UPI App           │   │
│  │                             │   │
│  │ Opens Google Pay, PhonePe,  │   │
│  │ Paytm, or BHIM directly     │   │
│  │ with ₹5,000 pre-filled      │   │
│  │                             │   │
│  │ Just enter your UPI PIN     │   │
│  │                        [→]  │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📱 Scan School QR            │   │
│  │                             │   │
│  │ Open camera to scan the     │   │
│  │ school's payment QR code    │   │
│  │                        [→]  │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📋 Manual UPI Payment        │   │
│  │                             │   │
│  │ Copy UPI ID, pay manually,  │   │
│  │ then upload proof screenshot│   │
│  │                        [→]  │   │
│  └─────────────────────────────┘   │
│                                     │
│  All methods require proof upload   │
│  for principal verification         │
│                                     │
└─────────────────────────────────────┘
```

**Key Design Decisions:**
- Three clear paths: UPI App (recommended), Scan QR, Manual
- UPI App path is highlighted as the fastest option
- All paths still require proof upload + principal verification
- Tuition month selection is preserved exactly as-is above the method picker

---

### SCREEN 3A: Pay via UPI App — Confirmation (NEW)

```
┌─────────────────────────────────────┐
│ ← Pay via UPI App                   │
│ Confirm and open your UPI app       │
├─────────────────────────────────────┤
│                                     │
│  Tuition Fee — Jul 2026             │
│  Student: Arjun Kumar · Class 5A    │
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │  Amount to Pay              │   │
│  │  ₹5,000                     │   │
│  │                             │   │
│  │  Pay to: Greenwood Academy  │   │
│  │  UPI: school@upi            │   │
│  │  Reference: FPR-2026-0042   │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │      PAY ₹5,000 NOW         │   │
│  └─────────────────────────────┘   │
│                                     │
│  ⚠️ After payment, you'll return   │
│  here to upload proof screenshot   │
│  and enter UTR for verification.   │
│                                     │
│  ┌───────────────────────────┐     │
│  │  💡 Tip: Note down the    │     │
│  │  UTR/transaction ID from  │     │
│  │  your UPI app after       │     │
│  │  payment. You'll need it. │     │
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

**Flow after tap "PAY NOW":**
1. `url_launcher` opens `upi://pay?pa=school@upi&pn=Greenwood+Academy&am=5000.00&cu=INR&tn=School+fee`
2. OS shows UPI app chooser (if multiple installed)
3. User selects their UPI app → enters PIN → payment completes
4. User returns to SchoolDesk app
5. App detects return and shows proof upload screen

---

### SCREEN 3B: Scan School QR (NEW)

```
┌─────────────────────────────────────┐
│ ← Scan QR Code                      │
│ Point camera at school QR           │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │      ┌──────────────┐       │   │
│  │      │              │       │   │
│  │      │  [CAMERA     │       │   │
│  │      │   VIEWFINDER]│       │   │
│  │      │              │       │   │
│  │      └──────────────┘       │   │
│  │                             │   │
│  │  Scanning...                │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  ── Or enter UPI ID manually ──    │
│  ┌─────────────────────────────┐   │
│  │ UPI ID: [school@upi      ]  │   │
│  │              [Scan & Pay →] │   │
│  └─────────────────────────────┘   │
│                                     │
│  ── School Payment Details ────    │
│  UPI: school@upi                   │
│  Name: Greenwood Academy           │
│  [📋 Copy UPI ID]                  │
│                                     │
└─────────────────────────────────────┘
```

**Key Design Decisions:**
- Camera-based QR scanner using `mobile_scanner` package
- Fallback: manual UPI ID entry if camera unavailable
- School payment details shown below for reference
- After scan: opens UPI app with scanned data pre-filled

---

### SCREEN 3C: Manual UPI Payment (Current — Streamlined)

```
┌─────────────────────────────────────┐
│ ← Manual UPI Payment                │
│ Pay via UPI and submit proof        │
├─────────────────────────────────────┤
│                                     │
│  Tuition Fee — Jul 2026             │
│  Amount: ₹5,000                     │
│                                     │
│  Step 1: Pay via UPI                │
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
│  │  [⚡ Open in UPI App]      │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  Step 2: Enter Payment Details      │
│  ┌─────────────────────────────┐   │
│  │ UPI Transaction ID (UTR)    │   │
│  │ ┌───────────────────────┐   │   │
│  │ │ 123456789012           │   │   │
│  │ └───────────────────────┘   │   │
│  │                             │   │
│  │ Payment Date                │   │
│  │ ┌───────────────────────┐   │   │
│  │ │ 2026-07-06             │   │   │
│  │ └───────────────────────┘   │   │
│  └─────────────────────────────┘   │
│                                     │
│  Step 3: Upload Proof               │
│  ┌─────────────────────────────┐   │
│  │ Payment Screenshot          │   │
│  │ ┌───────────────────────┐   │   │
│  │ │  📷 Tap to upload      │   │   │
│  │ └───────────────────────┘   │   │
│  │                             │   │
│  │ (jpg, png, or pdf)         │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌───────────────────────────┐     │
│  │    SUBMIT FOR VERIFICATION│     │
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

**Changes from current:**
- Added "Open in UPI App" button (uses same deep link as Screen 3A)
- Clearer step-by-step layout
- Existing UTR + screenshot flow preserved

---

### SCREEN 4: Proof Upload After UPI App Payment (NEW)

```
┌─────────────────────────────────────┐
│ ← Upload Payment Proof              │
│ Complete your payment submission     │
├─────────────────────────────────────┤
│                                     │
│  ✅ Payment Initiated               │
│  Tuition Fee — Jul 2026 · ₹5,000   │
│  Reference: FPR-2026-0042           │
│                                     │
│  ── Enter Payment Details ──────    │
│                                     │
│  UPI Transaction ID (UTR)           │
│  ┌─────────────────────────────┐   │
│  │ Enter the 12-digit UTR from │   │
│  │ your UPI app payment screen │   │
│  └─────────────────────────────┘   │
│                                     │
│  Payment Date                       │
│  ┌─────────────────────────────┐   │
│  │ 2026-07-06                  │   │
│  └─────────────────────────────┘   │
│                                     │
│  ── Upload Screenshot ─────────    │
│                                     │
│  Take a screenshot of the UPI      │
│  payment success screen and         │
│  upload it below.                   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  📷 Tap to upload screenshot │   │
│  └─────────────────────────────┘   │
│                                     │
│  ── Optional Notes ────────────    │
│  ┌─────────────────────────────┐   │
│  │ Notes for school office      │   │
│  │ (optional)                   │   │
│  └─────────────────────────────┘   │
│                                     │
│  ⚠️ Your payment will be verified   │
│  by the principal after submission. │
│                                     │
│  ┌───────────────────────────┐     │
│  │  SUBMIT PROOF ₹5,000      │     │
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

**Key Design Decisions:**
- Shown after user returns from UPI app
- Pre-filled reference number from payment intent
- UTR input + screenshot upload (same as manual flow)
- Clear success state at top ("Payment Initiated")

---

### SCREEN 5: Payment History (Current — Minimal Changes)

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
│  ── June 2026 ────────────────      │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ ✅ Tuition Fee - Jun       │   │
│  │ ₹5,000 · UPI               │   │
│  │ 05 Jun 2026 · Verified      │   │
│  │ Ref: FPR-2026-0038         │   │
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

**Changes:** Minimal — "PhonePe" badge removed, all payments show as "UPI" method.

---

### SCREEN 6: Receipt (Current — No Changes)

```
┌─────────────────────────────────────┐
│ ← Receipt                    ⬇️ 📤  │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │    🏫 GREENWOOD ACADEMY     │   │
│  │    Fee Payment Receipt      │   │
│  │                             │   │
│  │  Receipt No: RCP-2026-0042 │   │
│  │  Date: 06 July 2026        │   │
│  │                             │   │
│  │  Student: Arjun Kumar       │   │
│  │  Class: 5A                  │   │
│  │                             │   │
│  │  Fee Type: Tuition Fee      │   │
│  │  Period: July 2026          │   │
│  │                             │   │
│  │  Amount Paid: ₹5,000       │   │
│  │                             │   │
│  │  Payment Method: UPI        │   │
│  │  Transaction ID:           │   │
│  │  TXN-2026-07-0042          │   │
│  │                             │   │
│  │  Status: ✅ Paid & Verified│   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  [⬇️ Download PDF]  [📤 Share]      │
│                                     │
└─────────────────────────────────────┘
```

**No changes** — receipt already works correctly.

---

## 📱 Principal Role — Screen-by-Screen Wireframes

### SCREEN 7: Principal Fee Home (Current — No Changes)

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
│                                     │
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

**No changes** — principal fee home already works.

---

### SCREEN 8: Principal Payment Requests (Current — Minimal Changes)

```
┌─────────────────────────────────────┐
│ ← Payment Requests                  │
│ Pending parent payment submissions  │
├─────────────────────────────────────┤
│                                     │
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │Pending│ │Clarif.│ │All   │ ← Tabs│
│  │  3   │ │  1   │ │  6   │       │
│  └──────┘ └──────┘ └──────┘       │
│                                     │
│  ── Pending Review ─────────────    │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 👤 Rahul Sharma             │   │
│  │ Class 3B · Tuition Fee Jun  │   │
│  │ ₹5,000                      │   │
│  │                             │   │
│  │ UTR: 987654321012          │   │
│  │ Submitted: 05 Jul 2026     │   │
│  │                             │   │
│  │ 📷 [View Screenshot]       │   │
│  │                             │   │
│  │ [✅ Approve] [❌ Reject]   │   │
│  │ [💬 Ask Clarification]     │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 👤 Meera Patel              │   │
│  │ Class 7A · Library Fee      │   │
│  │ ₹2,000                      │   │
│  │                             │   │
│  │ UTR: 112233445566          │   │
│  │ Submitted: 04 Jul 2026     │   │
│  │                             │   │
│  │ 📷 [View Screenshot]       │   │
│  │                             │   │
│  │ [✅ Approve] [❌ Reject]   │   │
│  │ [💬 Ask Clarification]     │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

**No changes** — principal payment request review already works.

---

### SCREEN 9: Principal Fee Structure Form (Current — No Changes)

```
┌─────────────────────────────────────┐
│ ← Fee Structure Form                │
│ Create or edit fee structure         │
├─────────────────────────────────────┤
│                                     │
│  Academic Year: 2026-27             │
│  ┌─────────────────────────────┐   │
│  │ Class: [5A           ▼]    │   │
│  └─────────────────────────────┘   │
│                                     │
│  Fee Components:                    │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Tuition Fee                 │   │
│  │ Type: [Monthly        ▼]   │   │
│  │ Amount: [₹5,000      ]    │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ Library Fee                 │   │
│  │ Type: [One-time       ▼]   │   │
│  │ Amount: [₹2,000       ]   │   │
│  └─────────────────────────────┘   │
│                                     │
│  [+ Add Fee Component]              │
│                                     │
│  ┌───────────────────────────┐     │
│  │    SAVE FEE STRUCTURE     │     │
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

**No changes** — principal can already create/edit fee structures and generate invoices.

---

### SCREEN 10: Principal Quick Fee Update (NEW — Streamlined)

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
│  │ Current: ₹5,000             │   │
│  │ New:     [₹5,000      ]    │   │
│  │                     [Update]│   │
│  ├─────────────────────────────┤   │
│  │ 👤 Priya Singh              │   │
│  │ Current: ₹5,000             │   │
│  │ New:     [₹4,500      ]    │   │
│  │                     [Update]│   │
│  ├─────────────────────────────┤   │
│  │ 👤 Rahul Sharma             │   │
│  │ Current: ₹5,000             │   │
│  │ New:     [₹5,500      ]    │   │
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
- Bulk update or individual update
- Uses existing `updateRaw` backend API

---

### SCREEN 11: Principal Manual Payment Recording (Current — No Changes)

```
┌─────────────────────────────────────┐
│ ← Record Payment                    │
│ Log cash/offline payment            │
├─────────────────────────────────────┤
│                                     │
│  Student: [Arjun Kumar       ▼]    │
│  Invoice: [Tuition Jul 2026  ▼]    │
│  Amount:  [₹5,000            ]    │
│  Mode:    [Cash              ▼]    │
│  Date:    [2026-07-06        ]    │
│  Notes:   [Cash payment received]  │
│                                     │
│  ┌───────────────────────────┐     │
│  │    RECORD PAYMENT          │     │
│  └───────────────────────────┘     │
│                                     │
└─────────────────────────────────────┘
```

**No changes** — principal can already record manual/cash payments.

---

## 🔄 Payment Flow Diagrams

### Flow 1: One-Tap UPI App Payment

```
Parent                App                Backend              UPI App
 │                    │                    │                    │
 │── Select fee ────>│                    │                    │
 │── Choose months ─>│                    │                    │
 │── Tap "Pay via   >│                    │                    │
 │   UPI App"        │                    │                    │
 │                    │── Create Intent ──>│                    │
 │                    │   (amount, invoice)│                    │
 │                    │<─ reference ──────│                    │
 │                    │                    │                    │
 │── Tap "PAY NOW" ─>│                    │                    │
 │                    │── url_launcher ───────────────────────>│
 │                    │   upi://pay?pa=... │                    │
 │<── UPI app opens ─│────────────────────────────────────────>│
 │── Enter PIN ──────────────────────────────────────────────>│
 │── Payment success ─│───────────────────────────────────────>│
 │                    │                    │                    │
 │── Return to app ─>│                    │                    │
 │<── Show proof     │                    │                    │
 │   upload form     │                    │                    │
 │                    │                    │                    │
 │── Enter UTR ─────>│                    │                    │
 │── Upload proof ──>│                    │                    │
 │── Submit ────────>│── Submit Proof ───>│                    │
 │<── Pending status ─│                    │                    │
 │                    │                    │── Notification ──>│ Principal
 │                    │                    │                    │
 │                    │                    │<── Approve ───────│
 │<── Receipt ───────│                    │                    │
```

### Flow 2: Scan QR Code Payment

```
Parent                App                Backend              UPI App
 │                    │                    │                    │
 │── Tap "Scan QR" ─>│                    │                    │
 │<── Camera opens ──│                    │                    │
 │── Scan QR ───────>│                    │                    │
 │   (decodes UPI    │                    │                    │
 │    payload)       │                    │                    │
 │                    │── Create Intent ──>│                    │
 │                    │<─ reference ──────│                    │
 │                    │                    │                    │
 │── Confirm & Pay ─>│                    │                    │
 │                    │── url_launcher ───────────────────────>│
 │<── UPI app opens ─│────────────────────────────────────────>│
 │── Enter PIN ──────────────────────────────────────────────>│
 │── Success ────────────────────────────────────────────────>│
 │                    │                    │                    │
 │── Return to app ─>│                    │                    │
 │── Upload proof ──>│── Submit Proof ───>│                    │
 │<── Pending ───────│                    │                    │
```

### Flow 3: Manual UPI Payment (Copy + Paste)

```
Parent                App                Backend             Principal
 │                    │                    │                    │
 │── Tap "Manual" ──>│                    │                    │
 │<── Show QR + ID ──│                    │                    │
 │── Copy UPI ID ───>│                    │                    │
 │── Open UPI app ──>│                    │                    │
 │── Paste UPI ID ──>│                    │                    │
 │── Enter amount ──>│                    │                    │
 │── Pay ───────────>│                    │                    │
 │── Screenshot ────>│                    │                    │
 │                    │                    │                    │
 │── Return to app ─>│                    │                    │
 │── Enter UTR ─────>│                    │                    │
 │── Upload proof ──>│── Submit Proof ──>│                    │
 │<── Pending ───────│                    │── Notification ──>│
 │                    │                    │<── Approve ───────│
 │<── Receipt ───────│                    │                    │
```

### Flow 4: Principal Manual Fee Update

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
| `lib/features/finance/presentation/screens/parent_payment_screens/parent_payment_method_screen.dart` | NEW — Payment method selection (UPI App / Scan QR / Manual) |
| `lib/features/finance/presentation/screens/parent_payment_screens/parent_upi_app_payment_screen.dart` | NEW — UPI app payment confirmation + proof upload after return |
| `lib/features/finance/presentation/screens/parent_payment_screens/parent_qr_scanner_screen.dart` | NEW — In-app QR code scanner |
| `lib/features/finance/presentation/screens/parent_payment_screens/upi_app_launcher_service.dart` | NEW — Service to detect installed UPI apps and launch via deep link |

### Files to Modify

| File | Changes |
|------|---------|
| `lib/features/finance/presentation/screens/parent_fees_screen/parent_fees_screen.dart` | Change "Pay fee" button to navigate to new Payment Method Selection screen |
| `lib/features/finance/presentation/screens/parent_fees_screen/parent_payment_request_form_screen.dart` | Add "Open in UPI App" button in UPI panel; preserve tuition month selection |
| `lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart` | Add "Quick Fee Update" action in fee structures view |
| `lib/routes/app_routes.dart` | Add routes for new screens |
| `lib/routes/schooldesk_screen_registry.dart` | Register new screens |
| `lib/routes/route_access_guard.dart` | Add route permissions |

### Files to Remove/Archive

| File | Reason |
|------|--------|
| None | No PhonePe files exist in codebase — only the MD document references them |

---

## 📋 Implementation Planning

### Phase 1: UPI App Launch (Week 1)

**Goal:** Parents can tap one button to open their UPI app with pre-filled payment data.

| Task | Effort | Files |
|------|--------|-------|
| Create `UpiAppLauncherService` — detect installed UPI apps, build `upi://pay` URI, launch via `url_launcher` | 2 hours | New file |
| Create `ParentPaymentMethodScreen` — three-option picker (UPI App / Scan QR / Manual) | 3 hours | New file |
| Modify `ParentFeesScreen` — "Pay fee" button navigates to new method selection | 1 hour | Existing file |
| Add "Open in UPI App" button to existing `ParentPaymentRequestFormScreen` UPI panel | 1 hour | Existing file |
| Handle app lifecycle — detect return from UPI app, show proof upload form | 2 hours | New + existing files |
| Test on Android (Google Pay, PhonePe, Paytm, BHIM) | 2 hours | Manual testing |

**Total: ~11 hours**

### Phase 2: In-App QR Scanner (Week 2)

**Goal:** Parents can scan school QR code from within the app.

| Task | Effort | Files |
|------|--------|-------|
| Add `mobile_scanner` package dependency | 0.5 hours | pubspec.yaml |
| Create `ParentQrScannerScreen` — camera viewfinder, decode UPI payload, fallback to manual entry | 4 hours | New file |
| Handle camera permissions (Android + iOS) | 1 hour | New file |
| Connect scanner output to UPI app launch flow | 1 hour | New + existing files |
| Test on physical devices (camera permission, QR decode accuracy) | 2 hours | Manual testing |

**Total: ~8.5 hours**

### Phase 3: Principal Quick Fee Update (Week 3)

**Goal:** Principal can quickly adjust fee amounts on existing invoices.

| Task | Effort | Files |
|------|--------|-------|
| Add "Quick Fee Update" action to `AdminFeesScreen` fee structures view | 2 hours | Existing file |
| Create inline editing UI for invoice amounts (class/type/month filter) | 3 hours | Existing file |
| Wire to existing `updateRaw` backend API | 1 hour | Existing file |
| Test bulk update + individual update | 1 hour | Manual testing |

**Total: ~7 hours**

### Phase 4: Polish & Testing (Week 4)

| Task | Effort | Files |
|------|--------|-------|
| Handle edge cases: no UPI app installed, camera unavailable, network errors | 3 hours | Multiple files |
| Add analytics events for payment method selection, UPI launch, proof upload | 2 hours | Multiple files |
| UI polish: animations, loading states, error states | 2 hours | Multiple files |
| Write unit tests for UpiAppLauncherService | 2 hours | Test files |
| Write widget tests for payment method selection screen | 2 hours | Test files |
| Full regression test on existing payment flows | 2 hours | Manual testing |

**Total: ~13 hours**

---

## 📊 Summary: What Changes, What Stays

| Component | Change Level | Notes |
|-----------|-------------|-------|
| Tuition month selector | **NO CHANGE** | Preserved exactly as-is |
| UPI deep link launch | **NEW** | One-tap opens installed UPI app |
| QR code scanning | **NEW** | In-app camera scanner |
| Payment method selection | **NEW** | Three clear paths before payment |
| Proof upload flow | **MINOR** | Added "Open in UPI App" button, clearer steps |
| Principal fee structures | **NO CHANGE** | CRUD already works |
| Principal payment requests | **NO CHANGE** | Approve/reject/clarify already works |
| Principal fee collection | **NO CHANGE** | Manual payment recording already works |
| Principal quick fee update | **NEW** | Quick-edit invoice amounts |
| Receipt generation | **NO CHANGE** | PDF receipts already work |
| Backend API | **NO CHANGE** | All endpoints already exist |
| Database schema | **NO CHANGE** | No new tables needed |
| PhonePe SDK | **REMOVED** | Never existed in codebase |

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

*Document generated for SchoolDesk Fees Manual UPI Payment UX Redesign*
*Date: July 6, 2026*
*Approach: Manual UPI with deep link launch — no payment gateway SDK*

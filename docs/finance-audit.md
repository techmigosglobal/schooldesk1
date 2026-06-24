# Fees Module — Principal Audit Report

## Executive Summary

The principal's fees module is **partially implemented** with significant gaps. The principal has **read-only access** to fee structures, invoices, and concessions, but **cannot create, update, or delete** fee structures, concessions, or UPI QR codes directly — these are gated behind an "admin-only" approval workflow. The UPI QR feature exists but is **global per school only**, not class/section-scoped, and the principal cannot enable/disable individual QR codes. Student fee assignments are **class-level only** with no section-level granularity, and no auto-propagation occurs when fee structures change. Academic year rollover requires manual re-entry. The backend routes enforce `Principal` role on most fee endpoints, but the `DecideParentPaymentRequest` handler has a special `admin` branch that forces Principal approval via a separate approval-request workflow rather than direct action.

## Methodology

Files read (primary sources):
- `lib/routes/app_routes.dart` — route constants and screen mappings
- `lib/routes/route_access_guard.dart` — frontend role guards
- `lib/routes/schooldesk_screen_registry.dart` — screen metadata
- `lib/core/network/api_modules/fees_api.dart` — frontend API facade
- `school-backend/internal/handlers/fee.go` (~1748 lines) — fee handlers
- `school-backend/internal/handlers/parent_fees.go` — parent fee handlers
- `school-backend/internal/routes/routes.go` — backend route registrations
- `school-backend/internal/routes/principal_routes.go` — principal-specific routes
- `school-backend/internal/models/fee.go` — fee data models
- `school-backend/internal/models/payment.go` — payment/receipt models
- `school-backend/internal/models/student.go` — ParentStudentLink model
- `lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart` — admin/principal finance workspace
- `lib/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart` — fee structure/invoice/payment forms
- `lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_requests_screen.dart` — payment request review
- `lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_request_decision_screen.dart` — payment decision UI
- `lib/features/finance/presentation/screens/fee_monitoring_screen/fee_monitoring_screen.dart` — principal fee monitoring
- `lib/features/finance/presentation/screens/parent_fees_screen/parent_fees_screen.dart` — parent fees UI
- `lib/features/finance/presentation/screens/parent_fees_screen/parent_payment_request_form_screen.dart` — parent UPI payment flow

Search commands used:
- `grep` for UPI/QR, concessions, section_id, ParentStudentLink, RBACMiddleware, FeeHandler methods
- `find` for screen file locations

**Not covered**: Full test suite, database migrations, frontend PDF generation, push notifications.

## 1. CRUD Completeness Matrix

| Entity | Create | Read | Update | Delete | Principal access? | Evidence (file:line) |
| --- | --- | --- | --- | --- | --- | --- |
| Fee structures (per class / per academic year) | No direct create | Yes | No direct update | No direct delete | **Blocked** — Admin only; Principal can only "prepare requests" via admin screens that submit to backend `/fees/structures` (Principal role allowed but UI says "Prepare ... Request") | `routes.go:325-331` (RBACMiddleware "Principal" on POST/PUT/DELETE `/fees/structures`), `admin_fees_screen.dart:17` label "Prepare Fee Structure Request", `admin_fee_form_screens.dart:172` "Submit Fee Structure for Approval" |
| Fee components / heads (categories) | No | Yes | No | No | **Blocked** — Admin only | `routes.go:322-324` (RBACMiddleware "Principal" on POST/DELETE `/fees/categories`), `fee.go:45-70` CreateFeeCategory, `fee.go:72-96` DeleteFeeCategory |
| Student fee assignments / invoices | Via GenerateInvoices | Yes | No | No | **Partial** — Principal can trigger generation (`/fees/invoices/generate`) but cannot edit individual invoices | `routes.go:334` (RBACMiddleware "Principal" on POST `/fees/invoices/generate`), `fee.go:637-876` GenerateInvoices, `admin_fees_screen.dart:18` label "Submit Invoice Request" |
| Fee discounts / concessions / waivers | Via frontend records | Yes | Via decision endpoint | No | **Partial** — Concessions stored as `frontend_records` resource "fees/concessions"; Principal can list/create/decide but no dedicated handler | `routes.go:338-343` (RBACMiddleware "Principal" on concessions), `fee.go:1531-1544` GetConcessions, `fee.go:1001-1049` concession logic |
| Late fees / fines | Via fee structure | Yes | Via fee structure update | No | **Partial** — `LateFinePerDay` field on FeeStructure; no standalone CRUD | `fee.go:42` FeeCategory.IsRefundable, `fee.go:164` LateFinePerDay in CreateFeeStructure, `fee.go:275-276` update |
| Payment receipts / records | RecordPayment | Yes | No | No | **Partial** — Principal can record payments (`/fees/payments`) but cannot modify existing receipts | `routes.go:336` (RBACMiddleware "Principal" on POST `/fees/payments`), `fee.go:1143-1200` RecordPayment |
| Payment modes / UPI QR codes | Update config | Yes | Update config | No | **Partial** — Principal can update UPI ID, payee name, QR image via `/fees/payment-config` and upload QR via `/fees/payment-config/qr` | `routes.go:345-348` (RBACMiddleware "Principal" on PUT/POST payment-config), `fee.go:1630-1719` UpdatePaymentConfig/UploadPaymentQR |
| Payment-request decisions | No direct decide | Yes | Via approval workflow | No | **Partial** — Principal reviews but `DecideParentPaymentRequest` forces `admin` role into approval workflow; non-admin (Principal) path exists but unclear if reachable | `routes.go:337` (RBACMiddleware "Principal" on PUT `/fees/payment-requests/:id/decision`), `fee.go:1202-1318` DecideParentPaymentRequest with `currentRole(c)=="admin"` branch |
| Refunds | No | No | No | No | **None** — No refund endpoint or model | Not found in fee.go, payment.go, routes.go |

**Key finding**: The Principal role is allowed on backend routes (RBACMiddleware "Principal") but the frontend screens (`AdminFeesScreen`, `AdminFeeFormScreens`) are explicitly labeled "Prepare ... Request" and "Submit ... for Approval", implying the principal's actions create approval requests rather than direct mutations. The `DecideParentPaymentRequest` handler has a special branch for `admin` role that creates an approval request for Principal review, while the non-admin path (which would be Principal) directly approves/rejects — but the frontend routes map `principalPaymentRequestDecision` to `AdminPaymentRequestDecisionScreen` which submits to the same endpoint.

## 2. Linkage Analysis

### Student ↔ Fee assignment
- **Mechanism**: Fee invoices are generated per student via `GenerateInvoices` which queries students by `grade_id` and optional `section_id` (fee.go:752-755). The student's `current_section_id` links them to a section → grade.
- **Granularity**: Class-level (grade_id) with optional section filter. Fee structures are defined per `grade_id` + optional `section_id` (fee.go:128, `Where("(section_id = ? OR section_id IS NULL)", sectionID)`).
- **Uniqueness**: One fee structure per class/year/section combination. Student invoices generated from structures matching their grade/section.

### Class ↔ Fee structure
- **Link**: `FeeStructure.GradeID` (required) + `FeeStructure.SectionID` (optional, nullable). Created/updated via `CreateFeeStructure`/`UpdateFeeStructure` (fee.go:145-180, 230-264).
- **Principal-editable**: Backend allows Principal role, but frontend only "prepares requests".
- **Propagation**: **No auto-propagation**. When a fee structure is updated, existing invoices are **not** updated. `GenerateInvoices` only creates new invoices for students without existing invoice for that label (fee.go:831-836). No "re-sync" endpoint exists.

### Parent ↔ Student
- **Table**: `ParentStudentLink` (student.go:167-176) with `school_id`, `parent_user_id`, `student_id`, `student_admission_number`.
- **Fee module join**: `scopedFeeInvoiceQuery` joins `parent_student_links` for parent role (fee.go:489-497). `CreateParentPaymentRequest` verifies link (fee.go:1233-1240).
- **End-to-end**: Works — parent sees only their linked students' invoices; payment requests scoped to linked students.

### UPI QR code ↔ Payment ↔ Student/Parent
- **Storage**: `SchoolPaymentSetting` model (fee.go:163-173) — one per school (`school_id` unique). Fields: `upi_id`, `payee_name`, `merchant_code`, `qr_note`, `qr_image_url`, `upi_enabled`.
- **QR upload**: Stored at `uploads/payment_qr/{schoolID}/fee_qr_{timestamp}.{ext}` (fee.go:1695-1703). URL saved as `/uploads/payment_qr/{schoolID}/...`.
- **Receipt linkage**: **QR code ID NOT stored on receipt**. `Payment` model (payment.go:12-25) has `PaymentMode`, `TransactionID` but no `qr_image_url` or `payment_config_id`. `ParentPaymentRequest` has `ProofURL` (screenshot from parent) but not the QR used.
- **Traceability**: **Cannot trace payment back to source QR** — only global school QR config exists.

### Class → Section → Student → Fee invoice
- **Granularity**: **Class-level primarily**. Fee structures can have `SectionID` (nullable) for section-specific fees (fee.go:128, 383-396). Invoice generation accepts `section_id` filter (fee.go:754-755).
- **Mismatch**: Student's `CurrentSectionID` links to section → grade. Fee structures without `SectionID` apply to all sections in the grade. Section-specific structures only apply to that section.
- **Gap**: No UI for section-level fee structure management; `AdminFeesScreen` shows class-level bundles only (`_FeeStructureBundle` groups by grade+year).

## 3. Principal vs Admin Role Gap

| Endpoint | Method | Path | Role in RBAC | Issue |
| --- | --- | --- | --- | --- |
| CreateFeeCategory | POST | `/fees/categories` | Principal | Principal allowed but no dedicated UI; admin-only in practice |
| DeleteFeeCategory | DELETE | `/fees/categories/:id` | Principal | Same |
| CreateFeeStructure | POST | `/fees/structures` | Principal | Frontend says "Prepare Request" — implies approval workflow but backend allows direct create |
| UpdateFeeStructure | PUT/PATCH | `/fees/structures/:id` | Principal | Same |
| DeleteFeeStructure | DELETE | `/fees/structures/:id` | Principal | Same |
| GenerateInvoices | POST | `/fees/invoices/generate` | Principal | Principal allowed — correct |
| RecordPayment | POST | `/fees/payments` | Principal | Principal allowed — correct |
| DecideParentPaymentRequest | PUT/PATCH | `/fees/payment-requests/:id/decision` | Principal | **Critical**: Handler checks `currentRole(c) == "admin"` and forces approval workflow; Principal path exists but unclear if frontend uses it |
| UpdatePaymentConfig | PUT/PATCH | `/fees/payment-config` | Principal | Principal allowed — correct |
| UploadPaymentQR | POST | `/fees/payment-config/qr` | Principal | Principal allowed — correct |
| Concessions (frontend records) | POST/PUT/DELETE | `/fees/concessions` | Principal | Uses generic frontend records; no approval workflow |

**Endpoints that should be principal-accessible but are admin-gated**:
- None explicitly — backend RBAC allows Principal on all fee endpoints. The gap is **frontend labeling** ("Prepare Request", "Submit for Approval") suggesting an approval layer that doesn't exist in backend for most operations.

**Endpoints that are principal-accessible but should be admin-only**:
- None found.

**Special case**: `DecideParentPaymentRequest` has an `admin` branch that creates approval request for Principal. This is **inverted** — admin submits, Principal approves. But frontend route `principalPaymentRequestDecision` maps to `AdminPaymentRequestDecisionScreen` which calls the same endpoint. If Principal uses it, they hit the non-admin path (direct decide). If Admin uses it, they hit approval workflow.

## 4. UPI QR Code Feature

| Aspect | Finding | Evidence |
| --- | --- | --- |
| Dedicated CRUD UI for UPI QR (principal-side) | **Yes, partial** — Payment QR Settings panel in `AdminFeesScreen` (lines 199-315) and `FeeMonitoringScreen` (lines 1679-1790) show QR preview, UPI ID, payee name, note fields, and Upload QR button. No enable/disable toggle per QR (only global `upi_enabled`). |
| Parent payment flow exposes QR | **Yes** — `ParentPaymentRequestFormScreen` (lines 332-385) shows QR image (uploaded QR or generated from UPI URI) and UPI ID copy button. Single QR per school. |
| QR selection logic | **Global only** — One `SchoolPaymentSetting` per school (fee.go:1725-1735). No class/grade/section scoping. All parents see same QR. |
| Principal enable/disable QR | **Partial** — `UPIEnabled` field derived from `upi_id` or `qr_image_url` presence (fee.go:1668, 1741). No explicit disable toggle in UI; clearing fields disables. |
| QR storage & receipt linkage | **Disk**: `uploads/payment_qr/{schoolID}/fee_qr_{timestamp}.{ext}` (fee.go:1695-1703). **Receipt**: `Payment` model has no QR reference. `SchoolPaymentSetting.QRImageURL` stores path but not linked to individual payments. Cannot trace which QR was used for a payment. |

## 5. Class Linkage Integrity

| Scenario | Behavior | Evidence |
| --- | --- | --- |
| Fee structure change propagation | **No propagation** — Existing invoices unchanged. `GenerateInvoices` skips students with existing invoice for same label (fee.go:831-836). No "re-sync" or "re-generate for all" endpoint. |
| Section-level fees supported | **Yes, in model** — `FeeStructure.SectionID` nullable, `FeeInstallment.SectionID` nullable (fee.go:110, 444). Query filters by `(section_id = ? OR section_id IS NULL)` (fee.go:128). **No dedicated UI** — `AdminFeesScreen` groups by grade+year only. |
| Student transfers between sections | **Unpaid invoices unchanged** — Student's `current_section_id` updates, but existing invoices retain original `grade_id`/`section_id` at generation time. No automatic invoice adjustment. |
| Academic year rollover | **Manual re-entry required** — No auto-rollover logic found. Fee structures tied to `AcademicYearID`. New year requires new structures. `GenerateInvoices` requires explicit `academic_year_id`. |

## 6. Prioritized Issues

| # | Severity | File:Line | Description |
| --- | --- | --- | --- |
| 1 | High | `fee.go:1202-1318` | `DecideParentPaymentRequest` has inverted role logic: `admin` role forced into approval workflow; Principal direct path exists but frontend routes both roles to same screen. |
| 2 | High | `fee.go:163-173`, `fee.go:1695-1703` | UPI QR stored globally per school; no linkage to `Payment` or `ParentPaymentRequest`; cannot audit which QR used for a payment. |
| 3 | High | `fee.go:831-836` | No fee structure propagation to existing invoices — data drift when structures change mid-year. |
| 4 | Medium | `routes.go:338-343` | Concessions use generic `FrontendRecordHandler` ("fees/concessions") — no validation, no approval workflow, no typed model. |
| 5 | Medium | `admin_fees_screen.dart:17`, `admin_fee_form_screens.dart:172` | Frontend labels all principal actions as "Prepare Request" / "Submit for Approval" but backend allows direct mutations — misleading UX. |
| 6 | Medium | `fee.go:752-755`, `fee.go:128` | Section-level fee structures supported in backend but no UI for managing section-specific fees. |
| 7 | Low | `payment.go:56-70` | `FeeReceipt` many-to-many with invoices but no QR code reference; receipt generation doesn't capture payment config snapshot. |
| 8 | Low | `fee.go:1001-1049` | Concession logic only applies at invoice generation time; no retroactive application to existing invoices. |

## 7. Open Questions / Things I could not confirm

1. **Approval workflow for fee structures**: The frontend says "Prepare Request" and "Submit for Approval" but the backend `CreateFeeStructure`/`UpdateFeeStructure` handlers (fee.go:145-220, 230-310) have no approval logic — they directly create/update. Is there a separate approval-request mechanism not visible in fee.go?

2. **Principal vs Admin in DecideParentPaymentRequest**: The handler checks `currentRole(c) == "admin"` (fee.go:1218). What is the actual role name for principal in JWT? `route_access_guard.dart:125` normalizes "admin" → "principal". Is "admin" a separate role or alias?

3. **Concession approval flow**: `FeeConcession.ApprovedBy` field exists (fee.go:104) but no handler sets it. The frontend concessions endpoint uses generic CRUD. How are concessions actually approved?

4. **Payment mode enum**: `Payment.PaymentMode` is free text (payment.go:18). Frontend uses 'cash', 'online', 'cheque', 'dd', 'upi' (admin_fee_form_screens.dart:466, parent_payment_request_form_screen.dart:625). No validation/enum in backend.

5. **Late fine application**: `FeeStructure.LateFinePerDay` stored but no handler found that calculates/applies fines to overdue invoices. Is this computed at query time or via scheduled job?

6. **Refund model**: `FeeCategory.IsRefundable` exists (fee.go:42) but no refund endpoint, no refund transaction type in `Payment` model.

7. **Multi-school QR**: `SchoolPaymentSetting` has unique `school_id` (fee.go:166). Confirmed single QR per school.

8. **Fee receipt PDF QR**: `PdfService.generateFeeReceipt` (parent_fees_screen.dart:730) doesn't embed QR code — only shows payment details.

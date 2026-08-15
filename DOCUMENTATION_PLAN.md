# PRIORITY 8: DOCUMENTATION & KNOWLEDGE BASE

**Status:** Gap analysis complete, templates ready  
**Duration:** 3-5 days to fill critical gaps  
**Impact:** Reduces bus factor, improves onboarding, enables independent debugging  

---

## Current Documentation Inventory

✓ **Exists (Good State)**
- `PRD.md` — Product requirements (comprehensive, role definitions)
- `TEST_STRATEGY.md` — Test pyramid, coverage goals
- `TESTING.md` — Test folder structure
- `LOCAL_SETUP.md` — Dev environment setup
- `IMPLEMENTATION_TRACKER.md` — Feature tracking (error reporting implementation)
- `docs/APP_STORE_RELEASE.md` — Release checklist
- `docs/ARCHITECTURE_DECISIONS.md` — Routing, code structure decisions

❌ **Missing (Critical Gaps)**
- No canonical API reference (40+ endpoints are not documented in one place)
- No RLS policy guide (authorization is spread across migrations and handlers)
- No database schema/ERD guide
- No complete deployment runbook (a release checklist exists)
- No troubleshooting guide
- No security hardening guide
- No contributing guidelines
- No module architecture guide

The audit charter documents in the repository describe the work and its
templates; they do not close these implementation-documentation gaps.

---

## 1. API Reference Documentation

### 1.1 Template: Endpoint Reference

**File to Create:** `docs/API_REFERENCE.md`

~~~markdown
# SchoolDesk API Reference

## Auth Module

### POST /auth/login
**Purpose:** Authenticate user with email and password

**Authentication:** None (public)

**Request:**
```json
{
  "email": "principal@school.edu",
  "password": "Principal@12345"
}
```

**Response (Success):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "user-uuid",
      "email": "principal@school.edu",
      "app_metadata": {
        "role_name": "principal",
        "school_id": "school-uuid"
      }
    },
    "session": {
      "access_token": "eyJ0eXAiOiJKV1QiLC...",
      "refresh_token": "...",
      "expires_in": 3600
    },
    "profile": {
      "id": "user-uuid",
      "school_id": "school-uuid",
      "role_name": "principal",
      "is_active": true,
      "first_name": "John",
      "last_name": "Doe",
      "email": "principal@school.edu"
    }
  }
}
```

**Response (Failure):**
```json
{
  "success": false,
  "error": "invalid_credentials"
}
```

**Error Codes:**
- `invalid_credentials` — Email/password incorrect
- `user_not_found` — Email not registered
- `user_not_active` — Account disabled by admin
- `email_not_confirmed` — Email verification pending

**Authorization Model:**
- Frontend must use returned JWT for all subsequent requests
- JWT contains: role_name, school_id (source of truth)
- Token valid for 1 hour, refresh token valid for 1 week

**Example Curl:**
```bash
curl -X POST http://localhost:54321/functions/v1/api/auth/login \
  -H "Content-Type: application/json" \
  -d'{
    "email": "principal@school.edu",
    "password": "Principal@12345"
  }'
```

---

### GET /dashboard
**Purpose:** Get role-specific dashboard data

**Authentication:** Required (JWT with role_name)

**Query Parameters:**
- `role` (optional) — Dashboard role to fetch (must match JWT role)
  - Values: `principal`, `coordinator`, `teacher`, `parent`
  - If omitted, uses authenticated role

**Response (Principal Dashboard):**
```json
{
  "success": true,
  "data": {
    "role": "principal",
    "stats": {
      "total_students": 450,
      "total_staff": 25,
      "total_classes": 15,
      "pending_approvals": 3
    },
    "invoices": {
      "pending": 45,
      "paid": 120,
      "total_outstanding": 250000
    },
    "today_highlights": {
      "birthdays": [...],
      "leave_requests": [...],
      "announcements": [...]
    }
  }
}
```

**Authorization:**
- Principal: Can request own dashboard or any dashboard
- Coordinator: Can request own dashboard only
- Teacher: Can request own dashboard only
- Parent: Can request own dashboard only

**RLS Check:** Role/school_id verified server-side

**Cost:** ~5 Supabase queries

---

### POST /fees/payments
**Purpose:** Record a payment (Principal only)

**Authentication:** Required (JWT with role='principal')

**Request:**
```json
{
  "invoice_id": "invoice-uuid",
  "amount": 15000,
  "payment_method": "bank_transfer",
  "reference": "UTR12345",
  "received_date": "2026-08-10T10:30:00Z",
  "notes": "Online payment received"
}
```

**Response (Success):**
```json
{
  "success": true,
  "data": {
    "payment_id": "payment-uuid",
    "invoice_id": "invoice-uuid",
    "amount": 15000,
    "status": "confirmed",
    "receipt_id": "receipt-uuid",
    "new_balance": 5000
  }
}
```

**Authorization:**
- Principal: ✓ Can create/update/delete payments
- Coordinator: ✗ Forbidden (403)
- Teacher: ✗ Forbidden (403)
- Parent: ✗ Forbidden (403)
- Unauthenticated: ✗ Unauthorized (401)

**Error Cases:**
- `payment_not_found` (404) — Invoice doesn't exist
- `insufficient_permissions` (403) — Not Principal
- `invalid_amount` (400) — Amount > balance
- `duplicate_payment` (409) — Exact amount just recorded

**Audit Trail:** Recorded in audit_logs table

---

### (Generate for all 40+ endpoints)
~~~

### 1.2 Endpoint Summary Table

**File:** `docs/API_ENDPOINTS_MATRIX.md`

~~~markdown
# API Endpoints Matrix

| Module | Endpoint | Method | Public | Auth Required | Roles Allowed | Status |
|--------|----------|--------|--------|-------------------|---------------|--------|
| Auth | `/auth/login` | POST | ✓ | No | All | ✓ |
| Auth | `/auth/refresh` | POST | ✗ | Yes | All | ✓ |
| Auth | `/auth/logout` | POST | ✗ | Yes | All | ✓ |
| Auth | `/auth/profile` | GET | ✗ | Yes | All | ✓ |
| Auth | `/auth/profile` | PATCH | ✗ | Yes | All | ✓ |
| Schools | `/schools` | GET | ✗ | Yes | All | ✓ |
| Schools | `/schools/current` | GET | ✗ | Yes | All | ✓ |
| Schools | `/schools/current` | PATCH | ✗ | Yes | Principal, Super Admin | ✓ |
| Academics | `/academic-years` | GET | ✗ | Yes | Principal, Coordinator | ✓ |
| Academics | `/academic-years` | POST | ✗ | Yes | Principal, Super Admin | ✓ |
| ... (60+ rows) | | | | | | |
| Fees | `/fees/categories` | GET | ✗ | Yes | Principal | ✓ |
| Fees | `/fees/payments` | POST | ✗ | Yes | Principal | ✓ |
| Fees | `/fees/payments/:id` | DELETE | ✗ | Yes | ❌ BLOCKED | ✗ |
~~~

---

## 2. RLS Policy Documentation

**File to Create:** `docs/RLS_POLICIES_GUIDE.md`

~~~markdown
# RLS (Row-Level Security) Policy Guide

## What is RLS?

RLS enforces data access at the database layer. Even if an API endpoint has a bug,
RLS prevents unauthorized data retrieval.

## Authorization Model

Every row in every table has:
- `school_id` — Scope to school (required)
- Optional: `branch_id`, `role_restriction`

Every authenticated user has:
- `school_id` (from JWT app_metadata)
- `role_name` (from JWT app_metadata)
- `user_id` (from JWT sub field)

## School Scope Policy (Applied to ALL Tables)

```sql
CREATE POLICY "Users see only their school data" ON <table>
  FOR SELECT
  USING (school_id = (auth.jwt()->>'school_id')::UUID);
```

This prevents Principal@School1 from reading School2 data.

## Role-Specific Policies

### Fees Access (Principal Only)

**Table:** fee_invoices, payments, fee_receipts

```sql
-- Only Principal can insert/read/update
CREATE POLICY "Fees visible to Principal only" ON fee_invoices
  FOR SELECT USING (
    (auth.jwt()->>'role') = 'principal' 
    AND school_id = (auth.jwt()->>'school_id')::UUID
  );

CREATE POLICY "Fees mutable by Principal only" ON fee_invoices
  FOR UPDATE USING (
    (auth.jwt()->>'role') = 'principal'
    AND school_id = (auth.jwt()->>'school_id')::UUID
  );

-- Explicitly deny deletion
CREATE POLICY "No payment deletion" ON payments
  FOR DELETE USING (false);
```

### Student Access (Teacher + Parent)

**Table:** students, enrollments

```sql
-- Teacher sees students in assigned classes
CREATE POLICY "Teachers see assigned class students" ON students
  FOR SELECT USING (
    school_id = (auth.jwt()->>'school_id')::UUID
    AND EXISTS (
      SELECT 1 FROM enrollments
      WHERE enrollments.student_id = students.id
      AND enrollments.section_id = ANY(
        (SELECT section_id FROM staff_subjects WHERE staff_id = auth.uid())
      )
    )
  );

-- Parent sees only linked children
CREATE POLICY "Parents see own children" ON students
  FOR SELECT USING (
    school_id = (auth.jwt()->>'school_id')::UUID
    AND EXISTS (
      SELECT 1 FROM parent_student_links
      WHERE parent_student_links.student_id = students.id
      AND parent_student_links.parent_id = auth.uid()
    )
  );
```
~~~

---

## 3. Database Schema Guide

**File to Create:** `docs/DATABASE_SCHEMA.md`

### 3.1 Entity Relationship Diagram (Conceptual)

```
schools (1) ──┬── academic_years (many)
              ├── grades (many)
              ├── sections (many)
              ├── students (many)
              ├── staff (many)
              └── users (many)

academic_years (1) ──┬── terms (many)
                     └── enrollments (?)

students (1) ──┬── enrollments (many)
               ├── student_guardians (many)
               ├── student_attendances (many)
               ├── fee_invoices (many)
               └── medical_records (many)

staff (1) ──┬── staff_subjects (many)
            ├── staff_qualifications (many)
            └── staff_attendances (many)

fee_invoices (1) ──┬── payments (many)
                   ├── fee_receipts (many)
                   └── finance_document_snapshots (many)
```

### 3.2 Key Tables Reference

| Table | Purpose | Key Columns | School Scope | Role Scope |
|-------|---------|-------------|--------------|-----------|
| schools | Org unit | id, name, organization_id | - | - |
| users | App users | id, email, role_name, school_id | ✓ | ✓ (role) |
| students | Student records | id, school_id, is_active, status | ✓ | (teacher/parent-scoped) |
| staff | Staff records | id, school_id, designation | ✓ | (teacher only, self) |
| fee_invoices | Billing | id, school_id, student_id, status | ✓ | ✓ (principal) |
| payments | Cash in | id, school_id, invoice_id, amount | ✓ | ✓ (principal) |
| attendance_sessions | Mark sessions | id, school_id, session_date | ✓ | (teacher-scoped) |
| audit_logs | Change history | id, school_id, action, user_id | ✓ | ✓ (super_admin) |

---

## 4. Deployment Runbook

**File to Create:** `docs/DEPLOYMENT_GUIDE.md`

### 4.1 Pre-Release Checklist

```markdown
## Pre-Deployment Checklist (1 week before release)

### Code Quality
- [ ] `flutter analyze --no-pub` passes
- [ ] `dart format --set-exit-if-changed .` passes
- [ ] All tests pass: `flutter test`
- [ ] Integration tests pass: `flutter test integration_test`
- [ ] Static Dart analysis: `dart analyze --fatal-warnings`

### Security
- [ ] No hardcoded secrets in source
- [ ] `git log` redaction complete (no exposed tokens)
- [ ] Supabase security advisor warnings addressed
- [ ] Dependency scan passed (no CVEs)
- [ ] RLS policies reviewed

### Backend
- [ ] `deno check supabase/functions/api/index.ts` passes
- [ ] All Edge Function tests pass
- [ ] Database migrations applied on staging
- [ ] Production backup verified

### Staging Verification (48 hours before release)
- [ ] APK deployed to staging
- [ ] QA sign-off on all critical paths
- [ ] Analytics capture working
- [ ] Push notifications working
- [ ] Storage uploads working
- [ ] All 6 roles tested
- [ ] Both old + new devices tested

### Release
- [ ] Git tag created: `release-v1.2.3`
- [ ] Build artifacts signed
- [ ] Google Play Store submission prepared
- [ ] Release notes published
- [ ] Customer communication sent
```

### 4.2 Production Deployment Steps

```bash
#!/bin/bash
# scripts/deploy-production.sh

# 1. Pre-flight checks
echo "Running pre-flight checks..."
flutter analyze --no-pub
dart format --set-exit-if-changed .
flutter test

# 2. Build release APK
echo "Building release APK..."
flutter build apk --release \
  --dart-define-from-file=env.supabase.json \
  --split-debug-info=build/debug-info

# 3. Sign APK
echo "Signing APK..."
jarsigner -verbose -keystore ~/.android/release-keystore.jks \
  build/app/outputs/apk/release/app-release.apk android-release

# 4. Verify signature
echo "Verifying signature..."
apksigner verify -v build/app/outputs/apk/release/app-release.apk

# 5. Upload symbols
echo "Uploading debug symbols..."
upload-symbols.sh build/debug-info

# 6. Submit to Play Store (manual)
echo "Ready for Play Store submission"
echo "APK location: build/app/outputs/apk/release/app-release.apk"
```

---

## 5. Troubleshooting Guide

**File to Create:** `docs/TROUBLESHOOTING.md`

~~~markdown
# Troubleshooting Guide

## Login Issues

### "Invalid credentials" error
**Symptoms:** User gets "invalid_credentials" after entering correct password

**Diagnosis:**
1. Check username in `public.username_aliases` table
2. Verify user in `auth.users`
3. Check if user is marked `is_active = true` in `public.users`

**Fix:**
```sql
-- Enable user if disabled
UPDATE public.users SET is_active = true WHERE email = 'user@school.edu';
```

### Login works but dashboard shows empty
**Symptoms:** User logs in, but dashboard loads infinitely or shows no data

**Diagnosis:**
1. Check RLS policy: user should match school_id
2. Check if school_id in JWT matches actual school
3. Check Branch validation (branch header vs assigned branch)

**Fix:**
```sql
-- Verify JWT contains school_id
SELECT school_id FROM public.users WHERE id = 'user-uuid';
```

## Attendance Issues

### "Session not found" error when marking attendance
**Symptoms:** Attendance mark fails with "session not found" (404)

**Diagnosis:**
1. Session may be closed (status != 'open')
2. Session may be cancelled
3. Requesting user not assigned to this class

**Fix:**
```sql
-- Verify session is open
SELECT id, status FROM attendance_sessions 
WHERE id = 'session-uuid';

-- Check teacher assignment
SELECT * FROM staff_subjects 
WHERE section_id = 'section-uuid' AND staff_id = 'teacher-uuid';
```

~~~

---

## 6. Contributing Guidelines

**File to Create:** `docs/CONTRIBUTING.md`

~~~markdown
# Contributing to SchoolDesk

## Development Workflow

1. **Clone and setup**
   ```bash
   git clone <repo>
   cd schooldesk
   scripts/local_supabase.sh prepare
   flutter pub get
   ```

2. **Create feature branch**
   ```bash
   git checkout -b fix/ISSUE-123-brief-description
   ```

3. **Make changes**
   - Follow Dart style guide
   - Write tests for new code
   - Update related documentation

4. **Test locally**
   ```bash
   dart format .
   flutter analyze
   flutter test
   flutter test integration_test
   ```

5. **Commit and push**
   ```bash
   git add .
   git commit -m "fix: Brief description (ISSUE-123)"
   git push origin fix/ISSUE-123-brief-description
   ```

6. **Create Pull Request**
   - Title: `[PRIORITY-#] Issue title`
   - Checklist: Fill PR template
   - Labels: Add priority, category

7. **Code Review**
   - Wait for approval
   - Address review comments
   - Merge after approval

~~~

---

## 7. Security Hardening Guide

**File to Create:** `docs/SECURITY_HARDENING.md`

~~~markdown
# Security Hardening Guide

## Secrets Management

### Never commit secrets to git
❌ DO NOT:
```dart
const apiKey = "sk_live_abc123xyz...";  // DON"T!
```

✓ DO:
```dart
final apiKey = String.fromEnvironment('API_KEY');  // Use --dart-define
```

### Rotate secrets regularly
- API keys: Quarterly
- Database passwords: Semi-annually
- JWT secrets: On any suspected compromise

### Audit trail
```bash
# Find all commits with potential secrets
git log --all -p | grep -iE "password|secret|token|key" | head -20

# Clean history (after rotating secrets)
git filter-branch -f --tree-filter '
  grep -r "old_secret" . && git rm -f --cached $(grep -r "old_secret" . | cut -d: -f1)
' -- --all
```

~~~

---

## 8. Module Architecture Guide

**File to Create:** `docs/FLUTTER_ARCHITECTURE.md`

~~~markdown
# Flutter App Architecture

## Folder Structure

```
lib/
├── main.dart          — App entry point
├── app/               — Global providers, services
│   ├── providers/     — Riverpod providers (repository layer)
│   └── services/      — Business logic (no UI)
├── core/              — Shared utilities
│   ├── network/       — API client
│   ├── storage/       — Local persistence
│   └── utils/         — Helpers
├── features/          — Feature modules
│   ├── auth/          — Login, session
│   ├── dashboard/     — Dashboard screens
│   ├── fees/          — Finance module
│   └── ...
├── presentation/      — Shared UI components
│   ├── screens/       — Page-level widgets
│   ├── widgets/       — Reusable components
│   └── styles/        — Theme, colors, fonts
└── routes/            — Navigation
    ├── app_routes.dart
    ├── route_access_guard.dart
    └── schooldesk_screen_registry.dart
```

## Data Flow

```
UI Layer (Screens, Widgets)
           ↓
Provider Layer (Riverpod, Controller)
           ↓
Service Layer (Business logic)
           ↓
Repository Layer (API + Local storage)
           ↓
Data Layer (Supabase, Hive, Shared preferences)
```

## Adding a New Feature

1. Create feature directory: `lib/features/my_feature/`
2. Add model: `lib/features/my_feature/models/my_model.dart`
3. Add repository: `lib/features/my_feature/repositories/my_repository.dart`
4. Add providers: `lib/app/providers/schooldesk_providers.dart` (or feature-scoped)
5. Add UI: `lib/features/my_feature/screens/`, `lib/features/my_feature/widgets/`
6. Add navigation: `lib/routes/app_routes.dart` + `lib/routes/route_access_guard.dart`
7. Add tests: `test/unit/`, `test/widget/`, `integration_test/`
~~~

---

## 9. Documentation Publishing

### 9.1 Generate Markdown TOC
```bash
# Install: npm install -g markdown-toc
markdown-toc -i docs/API_REFERENCE.md
markdown-toc -i docs/RLS_POLICIES_GUIDE.md
# ... etc
```

### 9.2 Create Documentation Index

The links in the example below are planned target files. They are not claims
that those files already exist; create and verify each file before publishing
the index.
**File:** `docs/README.md`

```markdown
# SchoolDesk Documentation

## Quick Start
- Local Setup: `../LOCAL_SETUP.md`
- PR Template: `.github/pull_request_template.md`

## Architecture & Design
- Architecture Decisions: `ARCHITECTURE_DECISIONS.md`
- Flutter Architecture: `FLUTTER_ARCHITECTURE.md`
- Database Schema: `DATABASE_SCHEMA.md`

## API & Integration
- API Reference: `API_REFERENCE.md`
- API Endpoints Matrix: `API_ENDPOINTS_MATRIX.md`
- RLS Policies: `RLS_POLICIES_GUIDE.md`

## Operations
- Deployment Guide: `DEPLOYMENT_GUIDE.md`
- Troubleshooting: `TROUBLESHOOTING.md`
- Security Hardening: `SECURITY_HARDENING.md`

## Contributing
- Contributing Guidelines: `CONTRIBUTING.md`
- Pull Request Process: `.github/pull_request_template.md`
- Code of Conduct: `.github/CODE_OF_CONDUCT.md`

## Product
- Product Requirements: `../PRD.md`
- Release Checklist: `APP_STORE_RELEASE.md`
```

---

## 10. Documentation Implementation Timeline

### Week 1: Critical Docs
- [ ] API Reference (endpoints only, 4 hours)
- [ ] RLS Policies Guide (2 hours)
- [ ] Deployment Runbook (2 hours)

### Week 2: Support Docs
- [ ] Database Schema (1 hour)
- [ ] Troubleshooting Guide (2 hours)
- [ ] Contributing Guidelines (1 hour)

### Week 3: Polish
- [ ] Module Architecture (2 hours)
- [ ] Security Hardening (1 hour)
- [ ] Documentation index (1 hour)
- [ ] Link checks + publishing (1 hour)

---

## 11. Success Criteria

- [ ] New developer can clone and run locally in <30 minutes
- [ ] New developer can deploy to staging without asking questions
- [ ] All 40+ API endpoints documented
- [ ] RLS policies explained for each sensitive table
- [ ] Troubleshooting guide answers 90% of common issues
- [ ] Contributing guide followed by all PRs
- [ ] Documentation builds on CI and publishes to README

---

**Next Step:** Start with API Reference (highest value, fastest payoff)

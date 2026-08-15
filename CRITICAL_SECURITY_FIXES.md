# CRITICAL SECURITY FINDINGS — Priority 2 Remediation Plan

**Status:** Remediation in progress; findings are evidence-based against the
current working tree  
**Risk Level:** 🔴 CRITICAL (payment deletion remains an active blocker)  
**Estimated Effort:** 3-4 days  

---

## Summary of Findings

| Issue | Location | Risk | Fix Effort |
|-------|----------|------|-----------|
| **Former hardcoded privilege escalation token** | `supabase/functions/api/index.ts:395-401` | 🔴 CRITICAL exposure; rotation/history work open | 2 hours |
| **Dashboard response fields not role-scoped** | `supabase/functions/api/handlers/dashboard.ts:503-645` | 🔴 CRITICAL data exposure risk | 4 hours |
| **Payment delete violates financial immutability** | `supabase/functions/api/handlers/fees.ts:2742-2790` | 🔴 CRITICAL | 8 hours |
| **Supabase security advisor warnings** | Database schema + RLS policies | 🟠 HIGH | 1 day |
| **Public storage + private records** | `public.school-assets` bucket | 🟠 HIGH | 1 day |
| **Backend failure → empty state collapse** | `lib/app/providers/`, `lib/routes/` | 🟠 HIGH | 1 day |

---

## Finding 1: Former Hardcoded Privilege Escalation Token

### Details
**File:** `/supabase/functions/api/index.ts` (Lines 391-404)

```typescript
// Current working-tree code: both accepted credentials come from deployment
// environment variables; no credential literal is stored in source.
const fallbackToken = Deno.env.get("SHEETS_WEBHOOK_TOKEN") || "";
const isServiceRole = token.length > 0 && (
  token === serviceKey ||
  (fallbackToken && token === fallbackToken)
);
```

**Current assessment:**
- The hardcoded fallback is absent from the current working tree.
- The former credential is still present in commit `a70af07`, so it must be
  treated as exposed until production rotation is confirmed.
- The optional `SHEETS_WEBHOOK_TOKEN` fallback must be separately managed and
  rotated; it must never be a default or a value committed to source.

**Historical impact:**
- Anyone with the former credential could bypass authentication for all Sheets
  endpoints.
- Sheets endpoints create users, sync students, sync timetables
- Allows privilege escalation to service role

### Fix Strategy

#### Step 1: Audit Repository History (FIRST - blocking)
```bash
# Search repository history for the former credential using the value held by
# the incident owner. Do not paste the credential into Markdown, tickets, or
# shell transcripts.
git log -p --all -S "<former credential value>"
git log --all --oneline -S "<former credential value>"
```

#### Step 2: Revoke Current Token (IMMEDIATE)
- [ ] Log into GitHub
- [ ] Settings → Developer Settings → Personal Access Tokens → regenerate if this is one
- [ ] OR if this is Supabase-specific: Supabase Dashboard → API → Rotate keys
- [ ] Document rotation time/date in security log

#### Step 3: Remove from Source (current working tree)
- [x] Delete the hardcoded token from `index.ts` in the current working tree.
- [x] Use environment variables only (`SUPABASE_SERVICE_ROLE_KEY` and the
  separately managed `SHEETS_WEBHOOK_TOKEN` fallback).
- [ ] Verify the deployed Edge Function uses the changed source.
- [ ] Commit the security fix after focused checks pass.

#### Step 4: Redact from History (NEXT)
- [ ] Run `git filter-branch` or BFG Repo-Cleaner to purge from all branches
- [ ] Force-push to main (will require branch protection override)
- [ ] Notify all developers to re-clone
- [ ] Check GitHub for exposed secrets scan

#### Step 5: Investigate Origin (PARALLEL)
- [ ] Who added this token? Check git blame.
- [ ] Why was it added? Check commit message.
- [ ] Was it ever used in production? Check deployment logs.
- [ ] Who has access to the token? Security audit.

### Recommended Implementation Shape
```typescript
const fallbackToken = Deno.env.get("SHEETS_WEBHOOK_TOKEN") || "";
const isServiceRole = Boolean(token.length > 0 && (
  token === serviceKey || 
  (fallbackToken.length > 0 && token === fallbackToken)
));
```

**Tests:**
- [ ] Service role token works
- [ ] Former credential rejected after deployment and rotation
- [ ] Env var fallback works (if needed)
- [ ] Unauthenticated request rejected

---

## Finding 2: Dashboard Response Fields Not Role-Scoped

### Details
**File:** `/supabase/functions/api/handlers/dashboard.ts` (Lines 501-645)

```typescript
// Current code rejects an explicitly requested role that differs from the JWT.
const requestedRole = text(
  url.searchParams.get("role") ?? path.split("/").filter(Boolean)[1],
).toLowerCase();
if (requestedRole && requestedRole !== role) {
  return fail("dashboard role does not match session", 403);
}
```

**The Problem:**
- The requested-role mismatch check is present and works for `/dashboard` paths.
- `/principal/...` is a separate API family guarded by `isSchoolLeader`; it is
  not an alternate dashboard route.
- The default `/dashboard` response builds finance fields for roles that fall
  through the teacher/parent branches. The response must be reviewed so a
  coordinator cannot receive principal-only finance data.

### Vulnerability Scenarios
1. Coordinator: `GET /dashboard?role=principal` → rejected ✓
2. Coordinator: `GET /dashboard` → response field scope requires verification ❌
3. Teacher: `GET /dashboard` → teacher-specific response ✓
4. Teacher: `GET /dashboard/parent` → rejected by role mismatch ✓

### Fix Strategy

#### Step 1: Map All Dashboard Routes
Check route registry for dashboard paths:
```bash
grep -r "dashboard\|principal.*dashboard" lib/routes/
```

#### Step 2: Enforce Role Match at Handler Entry
```typescript
// FIXED CODE:
const dashRole = role;

// Keep the existing requested-role check, then scope response fields.
const includeFinance = ["principal", "admin", "super_admin"].includes(dashRole);
// Do not add fees, treasury, or school-wide finance totals when false.
if (dashRole === "teacher") {
  return teacherDashboardResponse(svc, school, user);
}
if (dashRole === "parent") {
  return parentDashboardResponse(svc, school, user);
}
```

#### Step 3: Audit Dashboard Response Fields
**Principal Dashboard Fields** (Principal only):
- Fees overview (paid_amount, balance, status, unpaid count)
- Finance summary
- Treasury data
- Staff directory (all staff)
- Student directory (all students)

**Coordinator Dashboard Fields** (omit Fees, treasury):
- Attendance overview
- Announcements
- Staff directory (assigned branch only)
- Student directory (assigned branch only)
- Leave approvals
- Academic metrics

**Implementation:**
```typescript
// Conditional field selection based on role
if (dashRole === "principal" || dashRole === "coordinator") {
  const includeFinance = dashRole === "principal";
  
  if (includeFinance) {
    // Fetch fees data
  }
  // ... rest of dashboard
}
```

#### Step 4: Test Matrix
```dart
/// Test cases to add to integration tests:
void testPrincipalDashboardAccess() {
  // Principal: GET /dashboard → 200 (principal dashboard)
  // Principal: GET /dashboard → 200 with finance fields
  // Coordinator: GET /dashboard → 200 without principal-only finance fields
  // Coordinator: GET /dashboard?role=principal → 403
  // Teacher: GET /dashboard → 200 with assigned-class data
  // Parent: GET /dashboard → 200 with linked-child data
}

void testDashboardRoleFields() {
  // Principal dashboard includes: fees_summary, all_staff, all_students
  // Coordinator dashboard excludes: fees_summary, treasury
  // Teacher dashboard includes only: assigned_classes, attendance
  // Parent dashboard includes only: child_data
}

void testDashboardBranchIsolation() {
  // Principal@Branch1 cannot read Branch2 students/staff/fees
  // Coordinator can only see assigned branch
}
```

**Tests to Modify:**
- [ ] Add dashboard role/field tests to the existing API contract suite
- [ ] Create `test/unit/dashboard_auth_test.dart`

---

## Finding 3: Payment Delete Violates Financial Immutability

### Details
**File:** `/supabase/functions/api/handlers/fees.ts` (Lines 2742-2790)

```typescript
// DELETE /fees/payments/:id
// This endpoint PHYSICALLY DELETES payment rows, violating immutable financial history

const { error: delErr } = await svc.from("payments")
  .delete().eq("id", seg).eq("school_id", school);
```

**The Problem:**
- Financial records must NEVER be physically deleted per PRD Section 4.3
- Deletion breaks audit trail and compliance
- Reconciliation becomes impossible
- Creates legal liability

**Impact:**
- Users can hide payments from audit logs
- Invoice balance calculations become unreliable
- School cannot prove fund received/spent

### Fix Strategy: Convert to Audited Reversal

#### Option A: Payment Reversal (RECOMMENDED)
```typescript
// DELETE /fees/payments/:id → becomes PATCH with reversal logic
// New endpoint: POST /fees/payments/:id/reverse

interface PaymentReversal {
  reversal_type: "full" | "partial"; // full = entire payment, partial = custom amount
  reversal_amount?: number;           // only for partial
  reason: string;                      // "duplicate", "fraud", "user_error", etc.
  notes?: string;
  reversed_by?: string;               // user email for audit
}

// Implementation:
// 1. Create new row: reverse_payments table
//    - original_payment_id, reversal_amount, reason, reversed_at, reversed_by
// 2. Create receipt: fee_receipts with amount=-X, type='reversal'
// 3. Recompute invoice: paid_amount -= reversal_amount, balance = net - paid
// 4. Log to audit_logs: user, action, payment_id, amount, timestamp
// 5. Return immutable snapshot (not deletable)
```

**Database Changes:**
```sql
-- Add reversal tracking
ALTER TABLE payments ADD COLUMN is_reversed BOOLEAN DEFAULT false;
ALTER TABLE payments ADD COLUMN reversed_at TIMESTAMP;
ALTER TABLE payments ADD COLUMN reversal_reason TEXT;

-- Create reversal table (append-only)
CREATE TABLE payment_reversals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  original_payment_id UUID NOT NULL REFERENCES payments(id),
  reversal_amount DECIMAL(10,2) NOT NULL,
  reason TEXT NOT NULL,
  notes TEXT,
  reversed_by TEXT NOT NULL,
  reversed_at TIMESTAMP DEFAULT NOW(),
  school_id UUID NOT NULL REFERENCES schools(id),
  UNIQUE(original_payment_id) -- one reversal per payment
);

-- Audit trigger
CREATE TRIGGER payment_reversal_audit
AFTER INSERT ON payment_reversals
FOR EACH ROW
EXECUTE FUNCTION audit_log_trigger();
```

**API Changes:**
```typescript
// OLD: DELETE /fees/payments/:id (remove immediately)
// NEW: POST /fees/payments/:id/reverse
{
  "reversal_type": "full",
  "reason": "duplicate",
  "notes": "Accidentally recorded twice",
  "reversed_by": "principal@school.edu"
}

// Response:
{
  "success": true,
  "payment_id": "...",
  "reversed": true,
  "new_invoice_balance": 45000,
  "reversal_receipt_id": "..."
}
```

#### Option B: Payment Status Flag (FASTER, ACCEPTABLE)
```typescript
// Instead of DELETE, update status
const { error } = await svc.from("payments")
  .update({
    status: "reversed",
    reversal_reason: body.reason,
    reversed_at: new Date().toISOString(),
    reversed_by: user.id
  })
  .eq("id", seg)
  .eq("school_id", school);

// Hide from normal queries: WHERE status != 'reversed'
// Visible in audit/history views
```

#### Step 1: Choose Approach
- [ ] Recommend: **Option A** (Payment Reversal with receipts, more compliant)
- [ ] Faster path: **Option B** (Status flag, acceptable for v1)

#### Step 2: Remove DELETE Endpoint
```typescript
// REMOVE from fees.ts:
// if (seg && method === "DELETE") { ... }

// IF reversal not yet implemented:
if (seg && method === "DELETE") {
  return fail("Payment deletion is not permitted. Use POST /fees/payments/:id/reverse to record a reversal.", 405);
}
```

#### Step 3: Add Reversal Route
```typescript
// handlers/fees.ts
if (path === `/fees/payments/${seg}/reverse` && method === "POST") {
  // Implement reversal logic
}
```

#### Step 4: Update Flutter App
```dart
// Remove payment delete UI button
// Add reversal workflow: User → confirmation dialog → reason picker → submit

// Update:
- lib/features/finance/views/payment_detail_view.dart (remove delete button)
- lib/features/finance/controllers/payment_controller.dart (remove deletePayment)
- Add: lib/features/finance/controllers/payment_reversal_controller.dart (new)
```

#### Step 5: Migration & Testing
```bash
# Run migration:
supabase migration new add_payment_reversals

# Run locally:
scripts/local_supabase.sh reset

# Test:
flutter test test/unit/payment_reversal_test.dart
flutter test integration_test/fees_workflow_test.dart
```

**Tests:**
- [ ] Reversal creates receipt (amount = -X)
- [ ] Invoice totals recalculate
- [ ] Audit log records reversal
- [ ] Original payment marked reversed
- [ ] DELETE endpoint returns 405

---

## Finding 4: Supabase Security Advisor Warnings

**Location:** Supabase Dashboard → Settings → Security

### Warning Categories

#### 4.1 SECURITY DEFINER Permissions (Executable)
**Issue:** Functions with SECURITY DEFINER can escalate privileges

**Required Investigation:**
```sql
-- Find all SECURITY DEFINER functions
SELECT routine_name, routine_definition 
FROM information_schema.routines 
WHERE routine_body ILIKE '%SECURITY DEFINER%'
AND routine_schema NOT IN ('pg_catalog', 'information_schema');
```

**Disposition Options:**
[ ] Remove SECURITY DEFINER and use RLS instead
[ ] Document why DEFINER is required
[ ] Restrict function access to specific roles
[ ] Add audit trigger

#### 4.2 Mutable Search Paths
**Issue:** Functions can access any schema if search_path is not locked

**Fix:**
```sql
-- Set search path in all functions:
CREATE FUNCTION ... SET search_path = public
```

#### 4.3 Public Storage Listing
**Issue:** `public.school-assets` bucket allows listing all files

**Fix:**
```sql
-- Disable public listing:
UPDATE storage.buckets 
SET public = false, file_size_limit = 52428800
WHERE name = 'school-assets';

-- Use signed URLs for all access
```

#### 4.4 Disabled Leaked Password Protection
**Issue:** Supabase security features not fully enabled

**Fix:**
[ ] Enable in dashboard

#### 4.5 RLS Initialization Plans
**Issue:** Some policies may not finalize correctly

**Audit per table:**
```sql
SELECT tablename FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename NOT LIKE 'pg_%';
-- Check that EACH table has RLS enabled and policies defined
```

#### 4.6 Permissive Policy Overlap
**Issue:** Multiple permissive policies may grant unintended access

**Review all:**
```sql
SELECT * FROM pg_policies 
ORDER BY schemaname, tablename, policyname;
```

**Disposition:**
[ ] Consolidate overlapping policies
[ ] Add restrictive policies
[ ] Document policy intent

#### 4.7 Duplicate Indexes
**Issue:** Redundant indexes waste storage + slow writes

**Find:**
```sql
SELECT indexrelname, idx_scan FROM pg_stat_user_indexes 
GROUP BY indexrelname, idx_scan
HAVING COUNT(*) > 1;
```

**Remove duplicates:**
```sql
DROP INDEX IF EXISTS duplicate_index_name;
```

### Implementation Timeline
- [ ] Week 1: Audit SECURITY DEFINER functions
- [ ] Week 2: Fix search_path issues
- [ ] Week 3: Harden storage permissions
- [ ] Week 4: Consolidate RLS policies

---

## Finding 5: Public Storage + Private Records

**Issue:** School documents, student photos, and payment proofs are in public bucket

### Scope
- `public.school-assets` used by:
  - Student profile photos (private)
  - Staff profile photos (private)
  - Student documents (private)
  - Event posts (can be public)

### Solution: Private Bucket Strategy

```sql
-- Create private bucket (v2)
INSERT INTO storage.buckets (id, name, public)
VALUES ('school-assets-private', 'school-assets-private', false);

-- Create signed-access helper function
CREATE FUNCTION public.get_signed_url(
  bucket_name TEXT,
  file_path TEXT,
  expires_in_seconds INT DEFAULT 3600
) RETURNS TEXT AS $$
BEGIN
  -- Generate signed URL using service role
  -- Return to client for download
END;
$$ LANGUAGE plpgsql;
```

### Implementation
1. [ ] Create private bucket
2. [ ] Write migration script to move existing files
3. [ ] Update Flutter upload routes to use private bucket
4. [ ] Add signed URL generation
5. [ ] Update image widgets to fetch signed URLs

---

## Remediation Timeline

### Week 1 (Critical Path)
- [x] **Monday:** Remove hardcoded token from the current working tree
- [ ] **Monday:** Rotate credentials and verify the deployed environment
- [ ] **Tuesday:** Redact from git history
- [ ] **Wednesday:** Fix dashboard response field scope + add tests
- [ ] **Thursday:** Implement payment reversal (Option A or B)
- [ ] **Friday:** Security review + merge to staging

### Week 2 (High Priority)
- [ ] **Monday–Friday:** Supabase advisor warning audits
- [ ] **Friday:** Create storage migration plan

### Week 3 (Follow-up)
- [ ] **Monday–Friday:** Storage separation + backend state fixes
- [ ] **Friday:** Full security regression test

---

## Sign-Off Checklist

- [ ] All three security/compliance remediation tracks remediated
- [ ] No hardcoded tokens in source
- [ ] Git history redacted
- [ ] Dashboard response fields role-scoped
- [ ] Payment operations reversible
- [ ] All Supabase warnings dispositioned
- [ ] Security regression tests pass
- [ ] Code review approved by 2+ senior developers
- [ ] Release notes updated

---

**Document Status:** Ready for review  
**Next Step:** Verify credential rotation/deployment, then implement payment reversal

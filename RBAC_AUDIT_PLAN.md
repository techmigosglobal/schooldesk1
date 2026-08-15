# PRIORITY 4: RBAC AUDIT & ROLE DATA ISOLATION TEST Plan

**Status:** Ready for execution  
**Duration:** 3 days  
**Risk Level:** 🔴 CRITICAL (data leak risk)  
**Scope:** All 40+ tables, 6 roles, branch isolation  

---

## Executive Summary

Role-Based Access Control (RBAC) is enforced through:
1. **Supabase RLS Policies** (database level) — source of truth
2. **Route Guards** (Flutter app) — UX enforcement
3. **API Authorization** (Edge Functions) — business logic

**Goal:** Verify all 3 layers are consistent and prevent cross-role/cross-branch data leakage.

---

## 1. RLS Policy Audit

### 1.1 Current RLS Status

| Table | School Scope | Branch Scope | Role Policy | Status |
|-------|--------------|--------------|-------------|--------|
| schools | ✓ | - | - | ✓ |
| academic_years | ✓ | Principal-all, Coord-assigned | ✓ | ✓ |
| terms | ✓ | ✓ | ✓ | ✓ |
| students | ✓ | ✓ | ✓ | ? (needs audit) |
| staff | ✓ | ✓ | ✓ | ? |
| fee_invoices | ✓ | ✓ | Principal-only | ? |
| payments | ✓ | ✓ | Principal-only | ? |
| attendance_sessions | ✓ | ✓ | ✓ | ? |
| timetable_slots | ✓ | ✓ | ✓ | ? |
| ... (40+ tables) | | | | ? |

**Task 1.1:** Run RLS audit query
```sql
-- Generate RLS policy report
SELECT
  schemaname,
  tablename,
  COUNT(*) as policy_count,
  STRING_AGG(policyname, ', ') as policies,
  string_agg(DISTINCT permissive, ', ') as policy_types
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY schemaname, tablename
ORDER BY tablename;

-- Check tables missing RLS
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
AND tablename NOT IN (SELECT tablename FROM pg_policies WHERE schemaname = 'public')
AND NOT tablename LIKE 'pg_%'
ORDER BY tablename;
```

**Task 1.2:** For each sensitive table, document:
- [ ] Who can insert? (role + condition)
- [ ] Who can read? (role + condition)
- [ ] Who can update? (role + condition)
- [ ] Who can delete? (role + condition)

**Sensitive tables (high priority):**
- `fee_*` (all fees tables) — Principal only
- `payments`, `fee_receipts` — Principal only
- `students` — Principal/Coord/Parent (scoped)
- `staff` — Principal/Coord/Teacher (scoped)
- `enrollment` — Student record (immutable)
- `users` — Own profile + authd only
- `audit_logs` — Super Admin only

**Example RLS Policy (MUST HAVE):**
```sql
-- For fee_invoices table
CREATE POLICY "Invoices visible to Principal only" ON fee_invoices
  FOR SELECT USING (
    auth.jwt()->>'role' = 'principal'
    AND school_id = (auth.jwt()->>'school_id')::UUID
  );

CREATE POLICY "Invoices updatable by Principal only" ON fee_invoices
  FOR UPDATE USING (
    auth.jwt()->>'role' = 'principal'
    AND school_id = (auth.jwt()->>'school_id')::UUID
  );

CREATE POLICY "No deletion of invoices" ON fee_invoices
  FOR DELETE USING (false);  -- Explicitly deny DELETE
```

### 1.3 RLS Testing Queries

For each role, test:
```sql
-- Switch user context
SET LOCAL session.jwt_claims = '{
  "sub": "user-id",
  "role": "authenticated",
  "app_metadata": {"role_name": "principal", "school_id": "school-1"}
}';

-- Test SELECT (should succeed)
SELECT COUNT(*) FROM fee_invoices WHERE school_id = 'school-1';

-- Test INSERT (should fail if restricted)
INSERT INTO payments (...) VALUES (...);  -- Should error if not Principal

-- Test DELETE (should fail)
DELETE FROM payments WHERE id = '...';  -- Should error with RLS policy
```

**Tests to write:**
```bash
supabase/tests/rbac_isolation_test.sql
```

---

## 2. Route Guard Audit

### 2.1 Current Route Protection

**File:** `lib/routes/route_access_guard.dart`

The current guard uses `RouteAccessGuard.isRoleAllowedFor` and
`RouteAccessGuard.allowedRolesFor`; the `canAccess` function below is only
illustrative pseudocode and is not a repository API. Flutter dashboard routes
are `/principal-dashboard-screen`, `/coordinator-dashboard-screen`,
`/teacher-dashboard-screen`, and `/parent-dashboard-screen`. The API dashboard
endpoint is `/dashboard`.

**Audit Focus:**
- Verify the existing `admin` to `principal` normalization against every
  sensitive route.
- Verify branch selection in the API and repository calls; the Flutter route
  guard itself does not receive a branch argument.
- Generate a complete route inventory from the screen registry.

### 2.2 Route Guard Test Matrix

**Create:** `test/unit/route_access_guard_test.dart`

```dart
void main() {
  group('Route Access Guard', () {
    // Principal routes
    test('Principal can access the API dashboard', () {
      expect(canAccess('/dashboard', 'principal', 'branch-1'), true);
    });
    
    test('Principal can access the principal dashboard route', () {
      expect(canAccess('/principal-dashboard-screen', 'principal', 'branch-1'), true);
    });
    
    test('Principal can access the fee home route', () {
      expect(canAccess('/fee-home-screen', 'principal', 'branch-1'), true);
    });
    
    // Coordinator routes
    test('Coordinator can access /dashboard', () {
      expect(canAccess('/dashboard', 'coordinator', 'branch-1'), true);
    });
    
    test('Coordinator cannot access principal fee routes', () {
      expect(canAccess('/fee-home-screen', 'coordinator', 'branch-1'), false);
    });
    
    test('Coordinator cannot access the principal dashboard route', () {
      expect(canAccess('/principal-dashboard-screen', 'coordinator', 'branch-1'), false);
    });
    
    // Teacher routes
    test('Teacher can access /dashboard/teacher', () {
      expect(canAccess('/dashboard/teacher', 'teacher', 'branch-1'), true);
    });
    
    test('Teacher cannot access the principal dashboard route', () {
      expect(canAccess('/principal-dashboard-screen', 'teacher', 'branch-1'), false);
    });
    
    test('Teacher cannot access principal fee routes', () {
      expect(canAccess('/fee-home-screen', 'teacher', 'branch-1'), false);
    });
    
    // Parent routes
    test('Parent can access /dashboard/parent', () {
      expect(canAccess('/dashboard/parent', 'parent', 'branch-1'), true);
    });
    
    test('Parent cannot access any staff routes', () {
      expect(canAccess('/staff', 'parent', 'branch-1'), false);
    });
    
    // Branch switching
    test('Coordinator cannot switch to other branch', () {
      // Coordinator@branch-1 trying to access branch-2
      expect(canAccess('/dashboard', 'coordinator', 'branch-2'), false);
    });
    
    test('Principal can switch branches', () {
      expect(canAccess('/dashboard', 'principal', 'branch-1'), true);
      expect(canAccess('/dashboard', 'principal', 'branch-2'), true);
    });
  });
}
```

### 2.3 Complete Route Inventory

**File:** Generate from `lib/routes/schooldesk_screen_registry.dart`

Expected format:
```
Route: /dashboard
  Method: GET
  Auth: All (role-specific dashboard returned)
  Roles: principal, coordinator, teacher, parent, kiosk
  Branch: Own (Coordinator) or All (Principal)
  
Flutter route: /principal-dashboard-screen
  Auth: Yes
  Roles: principal

API route: /dashboard
  Method: GET
  Auth: Yes
  Roles: authenticated roles; response is role-specific
  Branch: Verify in the handler and RLS policies

API route: /dashboard/:role
  Method: GET
  Auth: Yes
  Roles: the authenticated role must match `:role`
  Sensitive: response fields require role-scope tests
  
... (50+ routes)
```

**Task 2.3:** Generate route guard test coverage report
```bash
grep -r "AppRoute\." lib/routes/schooldesk_screen_registry.dart | wc -l
# Should show ~50-70 routes

# For each route, verify guard is defined
grep -r "canAccess" test/unit/route_access_guard_test.dart | wc -l
# Target: Coverage for all critical routes
```

---

## 3. API Authorization Audit

### 3.1 Edge Function Authorization

**File:** `supabase/functions/api/index.ts`

Authorization currently happens at:
1. **Route level** (hardcoded checks per endpoint)
2. **Handler level** (within each handler module)
3. **Database level** (RLS policies)

**Current Gaps:**
- ⚠️ No centralized auth decorator/middleware
- ⚠️ Different error messages per handler (info leakage)
- ⚠️ Some handlers bypass RLS with serviceClient()

**Current dashboard behavior to verify:**
```typescript
// handlers/dashboard.ts
const requestedRole = text(
  url.searchParams.get("role") ?? path.split("/").filter(Boolean)[1],
).toLowerCase();
if (requestedRole && requestedRole !== role) {
  return fail("dashboard role does not match session", 403);
}
// The remaining audit is response-field scope, especially finance fields for
// coordinator-like roles.
```

### 3.2 API Authorization Test Matrix

**File:** Create `test/api_authorization_test.dart`

```dart
void main() {
  group('API Authorization', () {
    late SupabaseClient client;
    
    setUp(() {
      // Use local Supabase
    });
    
    // Fee endpoints (Principal only)
    test('Principal can GET /fees/categories', () async {
      final response = await client.principal.get('/fees/categories');
      expect(response.statusCode, 200);
    });
    
    test('Coordinator cannot GET /fees/categories', () async {
      final response = await client.coordinator.get('/fees/categories');
      expect(response.statusCode, 403);
    });
    
    test('Coordinator error message is generic', () async {
      // ✓ Error: "access denied" (generic)
      // ✗ Error: "fees not available for your role" (information leak)
      final response = await client.coordinator.get('/fees/categories');
      expect(response.body['error'], 'access_denied');
      expect(response.body['error'], isNot(contains('coordinator')));
    });
    
    // Dashboard endpoints
    test('Teacher GET /dashboard returns Teacher dashboard', () async {
      final response = await client.teacher.get('/dashboard');
      expect(response.statusCode, 200);
      expect(response.body['data']['role'], 'teacher');
    });
    
    test('Teacher requesting a principal dashboard role returns 403', () async {
      final response = await client.teacher.get('/dashboard?role=principal');
      expect(response.statusCode, 403);
    });

    test('Coordinator dashboard excludes principal-only finance fields', () async {
      final response = await client.coordinator.get('/dashboard');
      expect(response.statusCode, 200);
      expect(response.body['data']['fees'], isNull);
    });
    
    // Branch isolation
    test('Coordinator@B1 cannot read Branch2 students', () async {
      final response = await client.coordinator
        .get('/students', headers: {'x-schooldesk-branch-id': 'branch-2'});
      expect(response.statusCode, 403);  // Branch validation fails
    });
    
    test('Principal can switch branches', () async {
      final b1 = await client.principal
        .get('/students', headers: {'x-schooldesk-branch-id': 'branch-1'});
      final b2 = await client.principal
        .get('/students', headers: {'x-schooldesk-branch-id': 'branch-2'});
      expect(b1.statusCode, 200);
      expect(b2.statusCode, 200);
    });
  });
}
```

### 3.3 Critical Authorization Rules (Reference)

```
RULE 1: Fees access
  ├─ Principal: ✓ (all branches)
  ├─ Coordinator: ❌
  ├─ Teacher: ❌
  ├─ Parent: ⚠️ (only own child's invoices via /parent/students/:id/fees)
  └─ API: POST /fees/* → 403 unless role=principal

RULE 2: Dashboard access
  ├─ Principal: ✓ (shows all staff, students, fees)
  ├─ Coordinator: ✓ (shows assigned branch only, no principal-only fees)
  ├─ Teacher: ✓ (shows assigned classes only)
  ├─ Parent: ✓ (shows own child data only)
  └─ API: Role mismatch → 403; response error wording should be reviewed for consistency

RULE 3: Branch scope
  ├─ Principal: Can access all branches (via x-schooldesk-branch-id header)
  ├─ Coordinator: Locked to assigned branch, no switching
  ├─ Teacher: Locked to school branch
  ├─ Parent: Locked to school branch
  └─ API: Invalid branch ID → 403 or 404

RULE 4: Document access
  ├─ Staff documents: Staff only (or Principal)
  ├─ Student documents: Student + Parent + Teacher + Principal
  ├─ Private finance docs: Principal only
  └─ API: Non-matching user → 404 (not "forbidden", but "not found")
```

---

## 4. Test Data Strategy

### 4.1 Seed Data Structure

**File:** `supabase/seed.sql`

```sql
-- School + structure
INSERT INTO schools (id, name, organization_id) VALUES ('school-1', 'Test School', 'org-1');
INSERT INTO academic_years (...) VALUES (...);
INSERT INTO terms (...) VALUES (...);
INSERT INTO grades (...) VALUES (...);
INSERT INTO sections (...) VALUES (...);

-- Users
INSERT INTO users (id, email, role_name, school_id, is_active) VALUES
  ('principal-id', 'principal@school.edu', 'principal', 'school-1', true),
  ('coordinator-id', 'coord@school.edu', 'coordinator', 'school-1', true),
  ('teacher-id', 'teacher@school.edu', 'teacher', 'school-1', true),
  ('parent-id', 'parent@school.edu', 'parent', 'school-1', true),
  ('kiosk-id', '**kiosk**', 'kiosk', 'school-1', true);

-- Auth users (for Supabase Auth)
-- Create via API: scripts/seed_kiosk_user.ts

-- People
INSERT INTO staff (...) VALUES (...);
INSERT INTO students (...) VALUES (...);
INSERT INTO guardians (...) VALUES (...);
INSERT INTO parent_student_links (...) VALUES (...);

-- Academics
INSERT INTO enrollments (...) VALUES (...);
INSERT INTO staff_subjects (...) VALUES (...);

-- Finance (Principal only, sensitive)
INSERT INTO fee_categories (...) VALUES (...);
INSERT INTO fee_structures (...) VALUES (...);
INSERT INTO fee_invoices (...) VALUES (...);
INSERT INTO payments (...) VALUES (...);

-- Attendance
INSERT INTO attendance_sessions (...) VALUES (...);
INSERT INTO student_attendances (...) VALUES (...);
```

### 4.2 Multi-Role Test Fixtures

```bash
# Create test clients for each role
const adminClient = supabase.auth.signInWithPassword('principal@school.edu', 'Principal@12345');
const coordClient = supabase.auth.signInWithPassword('coord@school.edu', 'Coordinator@12345');
const teacherClient = supabase.auth.signInWithPassword('teacher@school.edu', 'Teacher@12345');
const parentClient = supabase.auth.signInWithPassword('parent@school.edu', 'Parent@12345');

# Each client carries its own JWT with role_name and school_id
```

---

## 5. Data Isolation Test Cases

### 5.1 Principal-Coordinator Cross-Branch Protection

```
Test: Principal creates Branch1, Branch2
      Coordinator1 assigned to Branch1
      Coordinator2 assigned to Branch2
      
✓ Coordinator1 CAN see Branch1 data
✗ Coordinator1 CANNOT see Branch2 data
✓ Coordinator1 CANNOT switch to Branch2
✓ Principal CAN see both branches
```

### 5.2 Parent-Child Isolation

```
Test: Parent has 2 children: Child1, Child2
      Another Parent has Child3
      
✓ Parent CAN see Child1, Child2 data
✗ Parent CANNOT see Child3 data
✓ Parent CANNOT see staff data
✓ Parent CANNOT see other student records
```

### 5.3 Teacher Class Access

```
Test: Teacher assigned to Class1, Class2
      Another Teacher assigned to Class3
      
✓ Teacher CAN see Class1, Class2 students
✗ Teacher CANNOT see Class3 students
✓ Teacher CANNOT see attendance outside assigned classes
✓ Teacher CANNOT modify grades outside assigned classes
```

### 5.4 Financial Data Isolation

```
Test: All roles attempt fee access
      
✓ Principal CAN: GET/POST/PATCH /fees/*
✗ Coordinator CANNOT: GET /fees/* (403)
✗ Teacher CANNOT: GET /fees/* (403)
⚠️ Parent CAN: GET /parent/students/:id/fees (child's fees only)
✗ Parent CANNOT: GET /fees (school-wide) (403)
```

### 5.5 Audit Log Access

```
Test: All roles attempt audit log access
      
✓ Super Admin: Full audit log access
✗ Principal: No access to system audit logs (403)
✗ Others: No access (403)
✓ Activity logs visible per role (own actions only)
```

---

## 6. Execution Plan

### Week 1: Tuesday-Friday
- **Tuesday:** RLS policy audit (1.1, 1.2, 1.3)
- **Wednesday:** Route guard audit (2.1, 2.2, 2.3)
- **Thursday:** API authorization audit (3.1, 3.2, 3.3)
- **Friday:** Write all test cases (5.1-5.5)

### Week 2: Monday-Tuesday
- **Monday:** Run all tests, document failures
- **Tuesday:** Implement fixes for all findings

### Week 2: Wednesday-Friday
- **Wednesday:** Regression testing
- **Thursday:** Security review
- **Friday:** Merge to staging, prepare release notes

---

## 7. Expected Findings

### 7.1 Common RLS Issues
- [ ] Tables missing RLS entirely
- [ ] RLS policies that don't check school_id
- [ ] RLS policies using deprecated fields
- [ ] DELETE policies missing (should be "FOR DELETE USING (false)")
- [ ] SECURITY DEFINER functions bypassing RLS

### 7.2 Common Route Guard Issues
- [ ] Routes missing from access guard
- [ ] "admin" role not normalized to "principal"
- [ ] Branch context ignored in guards
- [ ] Parent routes allowing access to other family data

### 7.3 Common API Issues
- [ ] Inconsistent error messages revealing role info
- [ ] No validation of branch header
- [ ] Fee endpoints accessible without auth
- [ ] Dashboard endpoints returning wrong role's data

---

## 8. Sign-Off Checklist

- [ ] All 40+ tables have RLS policies
- [ ] All sensitive tables have DELETE policies = false
- [ ] All routes tested for each role
- [ ] No cross-branch data leakage detected
- [ ] No cross-family data leakage (Parent role)
- [ ] Fee access verified Principal-only
- [ ] Error messages are generic (no role info leak)
- [ ] All tests pass on local Supabase
- [ ] Code review approved

---

**Document Status:** Ready for execution  
**Next Step:** Run `supabase/tests/rbac_isolation_test.sql` diagnostic

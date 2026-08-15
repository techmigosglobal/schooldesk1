# SchoolDesk System Audit Report
**Generated:** August 13, 2026  
**Status:** Discovery complete; remediation in progress  
**Scope:** Full system audit addressing 8 critical priorities

---

## Executive Summary

This audit addresses feature freeze, system stability, cost optimization, security hardening, backend consistency, testing infrastructure, release safety, and documentation completeness.

---

## 1. PRIORITY 1: FEATURE FREEZE ✓ INITIATED

### 1.1 Current Status
- **Branch Status:** `main` is checked out; the remote also contains the Android
  signing workflow branch.
- **Working Tree:** The Sheets-token remediation is present in the local API
  diff, the audit documents are untracked, and generated Gradle cache files are
  modified. This is not a clean audit baseline.
- **In-Flight Features:** No new product feature was identified.

### 1.2 Feature Freeze Policy (RECOMMENDED)
1. **Branch Protection Rule:** Only hotfixes to main after this audit begins
2. **Commit Gating:** All commits require audit approval tag
3. **Review Scope:** Every PR must reference which priority it addresses
4. **Duration:** Until all Priority 2-4 audits complete

### 1.3 Known Incomplete Work (From PRD Section 11)
| Issue | Impact | Category |
|-------|--------|----------|
| Former hardcoded Sheets privilege token; rotation/history cleanup pending | **🔴 CRITICAL** | Security |
| Dashboard response fields not role-scoped | **🔴 CRITICAL** | RBAC |
| Supabase security advisor warnings | **🟠 HIGH** | Security |
| Public storage + private records | **🟠 HIGH** | Security |
| Backend failure → empty state collapse | **🟠 HIGH** | Reliability |
| Web branch-switch silent failure | **🟠 HIGH** | UX |
| Integration test stubs | **🟠 HIGH** | Testing |
| Payment delete path | **🔴 CRITICAL** | Compliance |
| Missing visual QA | **🟠 HIGH** | QA |

---

## 2. PRIORITY 2: FULL SYSTEM AUDIT ⏳ IN PROGRESS

### 2.1 Architecture Snapshot
- **Backend:** Supabase + Deno Edge Functions (788-line index.ts)
- **API Handlers:** 40 modules covering auth, academics, people, attendance, fees, communications, monitoring
- **Frontend:** Flutter (feature-first, Riverpod + Provider)
- **Web:** Next.js (limited leadership portal)
- **Database:** 40+ tables with RLS policies
- **Roles:** Principal, Coordinator (Admin), Teacher, Parent, Student, Kiosk, SuperAdmin

### 2.2 API Handler Inventory
```
✓ auth.ts          ✓ academics.ts     ✓ calendar.ts      ✓ communications.ts
✓ schools.ts       ✓ branches.ts      ✓ dashboard.ts     ✓ staff.ts
✓ students.ts      ✓ guardians.ts     ✓ users.ts         ✓ approvals.ts
✓ attendance.ts    ✓ fees.ts          ✓ leave.ts         ✓ timetable.ts
✓ documents.ts     ✓ uploads.ts       ✓ events.ts        ✓ communications.ts
✓ parent.ts        ✓ reports.ts       ✓ monitoring.ts    ✓ homework.ts
✓ medical.ts       ✓ health_reminders.ts    ✓ birthday_alerts.ts    ✓ notifications.ts
✓ sheets_sync.ts   ✓ sheets_pull.ts   ✓ help.ts          ✓ access.ts
✓ issues.ts        ✓ website.ts       ✓ demo.ts          ✓ activity.ts
✓ principal.ts     ✓ daily_claims.ts
```

### 2.3 Known Issues (To Be Resolved)
#### 2.3.1 Security Issues
- [ ] Former hardcoded Sheets fallback was removed from the working tree, but
  production rotation and history remediation for commit `a70af07` are not
  verified.
- [ ] Dashboard role mismatch is rejected, but the default dashboard response
  still needs a role-field audit so coordinator responses cannot include
  principal-only finance data.
- [ ] Supabase security advisor warnings: SECURITY DEFINER permission, mutable search paths, public storage, RLS policies, duplicate indexes

#### 2.3.2 Reliability Issues
- [ ] Backend failure handling collapses into empty states
- [ ] Web branch-switch error shows no feedback
- [ ] Demo-role selection may bypass authorization

#### 2.3.3 Compliance Issues
- [ ] Payment delete operations violate immutable financial history rule
- [ ] Storage mixing public + private records

#### 2.3.4 Testing Issues
- [ ] Integration test stubs with TODO comments
- [ ] No student dashboard route (seed data exists)
- [ ] Missing visual/responsive QA evidence

---

## 3. PRIORITY 3: SUPABASE AUDIT ⏳ IN PROGRESS

### 3.1 API Call Patterns (To Analyze)
- [ ] Identify all SELECT queries hitting public tables
- [ ] Find N+1 query patterns
- [ ] Detect redundant RLS policy fetches
- [ ] Measure branch filter overhead
- [ ] Analyze pagination efficiency

### 3.2 Compute Optimization
- [ ] Identify unused database functions
- [ ] Find heavy triggers or stored procedures
- [ ] Audit Edge Function cold starts
- [ ] Review authentication latency

### 3.3 Storage Audit
- [ ] Measure school-assets bucket usage
- [ ] Identify unused files
- [ ] Verify private storage implementation
- [ ] Check CDN cache effectiveness

### 3.4 Egress Audit
- [ ] Measure outbound data per feature module
- [ ] Identify streaming/pagination misalignment
- [ ] Review file export size optimization

---

## 4. PRIORITY 4: RBAC AUDIT ⏳ IN PROGRESS

### 4.1 RLS Policy Review (To Execute)
- [ ] Verify all 40 tables have appropriate RLS policies
- [ ] Check school_id scope enforcement
- [ ] Verify branch isolation per role
- [ ] Test Principal cross-branch read/write attempts
- [ ] Verify Coordinator single-branch restriction
- [ ] Test Teacher data scope
- [ ] Test Parent child-link scope

### 4.2 Route Guard Audit
- [ ] Verify `route_access_guard.dart` covers all routes
- [ ] Test role spoofing attempts
- [ ] Verify demo role doesn't bypass authorization
- [ ] Check branch context during navigation

### 4.3 Dashboard Authorization and Field Scope
- [x] Requested dashboard roles are rejected when they do not match the
  authenticated role (`dashboard.ts:503-507`).
- [ ] Verify only authenticated-role fields are returned; the default response
  currently includes finance fields and needs coordinator-specific filtering.
- [ ] Add regression tests for `/dashboard`, `/dashboard/teacher`, and
  `/dashboard/parent`.

### 4.4 Test Cases (To Create)
```dart
// Role isolation tests
- Principal can view all branches
- Principal cannot mutate other branch data  
- Coordinator sees only assigned branch
- Coordinator cannot switch branches
- Teacher cannot see other classes
- Parent cannot see other families
- Fees hidden from non-Principal roles
```

---

## 5. PRIORITY 5: BACKEND/API AUDIT ⏳ IN PROGRESS

### 5.1 API Endpoint Mapping
- [ ] Map all 40+ handler modules to routes
- [ ] Document HTTP method per endpoint
- [ ] Identify duplicate implementations
- [ ] Find unused API paths

### 5.2 Repository Consolidation
- [ ] Current Status: Multiple RLS-checked queries across handlers
- [ ] Target: Centralized data access layer with consistent error handling
- [ ] Risk: Breaking changes in API contracts

### 5.3 Duplicate Request Detection
- [ ] Identify redundant queries in fees module
- [ ] Check attendance session creation duplicates
- [ ] Audit student/guardian relationship queries
- [ ] Find repeated branch context lookups

### 5.4 API Contract Consistency
- [ ] Verify error envelope uniformity
- [ ] Check success response shape standardization
- [ ] Review HTTP status codes
- [ ] Validate request/response logging

---

## 6. PRIORITY 6: TESTING SYSTEM ⏳ IN PROGRESS

### 6.1 Current Test Coverage
```
✓ Unit tests:    test/unit
✓ Widget tests:  test/widget
✓ Integration:   integration_test (3 files)
✗ API tests:     Need comprehensive matrix
✗ Golden tests:  Baseline generation blocked
✗ Patrol E2E:    Basic flow only
```

### 6.2 Test Pyramid (Target)
1. **Unit** (40%): validators, route guards, RLS logic, model transforms
2. **Widget** (35%): components, responsive, empty/loading/error states
3. **Integration** (15%): auth, workflows, branch isolation
4. **E2E** (10%): user journeys, native interactions

### 6.3 Regression Detection Gates
- [ ] Implement CI-gated Flask/pytest server for API contract regression
- [ ] Add database state assertions before/after tests
- [ ] Create role-isolation matrix tests
- [ ] Add financial history mutation detection

### 6.4 Test Data Strategy
- [ ] Deterministic seed in `supabase/seed.sql` ✓ (exists)
- [ ] Automated fixture reset per test
- [ ] Contract-based mocking for unit tests
- [ ] Integration test isolation per role

---

## 7. PRIORITY 7: RELEASE PIPELINE ⏳ IN PROGRESS

### 7.1 Current CI/CD
- **Build Step:** Manual or Codemagic
- **Testing:** One GitHub Actions workflow exists for signed APK dispatch; a
  general lint/test gate is still missing.
- **Deployment:** Push to Play Store is testing point (❌ ANTI-PATTERN)
- **Web:** Next.js with implied Vercel or manual deploy

### 7.2 Target Pipeline
```
PR → (lint + format) 
   → (unit tests) 
   → (widget tests) 
   → (integration tests with local Supabase)
   → (E2E smoke tests)
   → Build APK/AAB (staging)
   → (QA verification on staging)
   → Merge + Release Build
   → Store deployment
```

### 7.3 Pre-Release Gates
- [ ] `flutter analyze --no-pub` passes
- [ ] `deno check supabase/functions/api/index.ts` passes
- [ ] All test suites pass
- [ ] Security scan (dependency audit)
- [ ] Visual QA checklist

### 7.4 Artifact Management
- [ ] Split debug symbols ✓ (implemented)
- [ ] Symbol server upload (required for crash debugging)
- [ ] Pre-release staging APK testing

---

## 8. PRIORITY 8: DOCUMENTATION ⏳ IN PROGRESS

### 8.1 Existing Documentation
✓ PRD.md (product definition + known issues)  
✓ ARCHITECTURE_DECISIONS.md (in docs/, routing + symbols)  
✓ TEST_STRATEGY.md (test pyramid + execution order)  
✓ TESTING.md (test folders + current gaps)  
✓ LOCAL_SETUP.md (dev environment)  
✓ IMPLEMENTATION_TRACKER.md (monitoring feature)  

### 8.2 Critical Gaps (To Fill)
- [ ] **API Documentation:** No endpoint reference exists. Need: route, method, auth, payload, response, error cases per handler
- [ ] **RLS Policy Documentation:** Policies exist but not documented. Need: scope rules per role/table
- [ ] **Database Schema Guide:** Tables exist but no ERD or guide. Need: entity relationships, design decisions
- [ ] **Deployment Guide:** A release checklist exists in
  `docs/APP_STORE_RELEASE.md`, but there is no complete production deployment
  runbook.
- [ ] **Troubleshooting Guide:** Error patterns, common issues, recovery procedures
- [ ] **Security Audit Checklist:** No formalized security review process
- [ ] **Contributing Guidelines:** No workflow for new contributors
- [ ] **Release Checklist:** No pre-release verification list

### 8.3 Documentation Locations
- Source of truth: Product and verification docs in the root; architecture
  decisions live in `docs/ARCHITECTURE_DECISIONS.md`.
- Internal: docs/ folder (APP_STORE_RELEASE.md, ARCHITECTURE_DECISIONS.md)
- Dev setup: LOCAL_SETUP.md + TESTING.md
- **Gap:** No centralized API reference, RLS guide, schema guide, or runbooks

---

## 9. AUDIT SUMMARY & NEXT STEPS

### 9.1 Critical Path (Blocking Release)
1. **Security:** Rotate and history-remediate the former Sheets credential exposure (Priority 2.3.1)
2. **RBAC:** Fix dashboard response field scope (Priority 4.3)
3. **Compliance:** Resolve payment delete path (Priority 2.3.3)
4. **Testing:** Create regression detection gates (Priority 6.3)

### 9.2 High Priority (After Critical Path)
- Supabase security warnings disposition
- Storage public/private separation
- Backend failure → empty state fix
- Integration test coverage
- Release pipeline gating

### 9.3 Medium Priority (Quality & Scale)
- API duplicate elimination
- Repository consolidation
- Comprehensive test coverage
- Documentation gap closure

### 9.4 Estimated Effort
| Priority | Effort | Risk | Blocking |
|----------|--------|------|----------|
| 1: Feature Freeze | 1 day | Low | No |
| 2: System Audit | 3 days | Medium | Security items |
| 3: Supabase Audit | 2 days | Low | No |
| 4: RBAC Audit | 3 days | High | Critical |
| 5: Backend Audit | 2 days | Low | No |
| 6: Testing | 5 days | Medium | Release |
| 7: Pipeline | 2 days | Medium | Release |
| 8: Documentation | 3 days | Low | Scale |

**Total: ~21 days** (sequenced for risk)

---

## 10. AUDIT EXECUTION LOG

### Phase 1: Discovery (This Document)
- [x] Read PRD, known issues, architecture
- [x] Inventory API handlers (40 modules)
- [x] Check for in-flight work
- [ ] Next: Detailed security audit

### Phase 2: Security Hardening (Starting)
- [x] Locate and remove the hardcoded Sheets token from the current working tree
- [ ] Rotate credentials and remediate the exposed history
- [ ] Fix dashboard response field scope
- [ ] Audit Supabase security warnings

### Phase 3: RBAC Verification
- [ ] Map RLS policies per table
- [ ] Create role isolation tests

### Phase 4: Backend Consistency
- [ ] Map all API endpoints
- [ ] Find and eliminate duplicates

### Phase 5: Testing Infrastructure
- [ ] Expand test coverage
- [ ] Add regression detection

### Phase 6: Release & Docs
- [ ] Harden CI/CD pipeline
- [ ] Fill documentation gaps

---

*Last Updated: August 13, 2026; status reflects the current working tree*

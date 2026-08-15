# SCHOOLDESK AUDIT — Quick Reference Card

**Print This & Post It** 💡

---

## 🚨 FEATURE FREEZE IN EFFECT

### What's Frozen:
- ❌ New features (Flutter or backend)
- ❌ Major UI changes
- ❌ Database schema changes
- ❌ Dependency upgrades

### What's Allowed:
- ✅ Bugfixes (with audit approval)
- ✅ Security patches
- ✅ Test improvements
- ✅ Audit-assigned work
- ✅ Documentation

### The Process:
```
You Create PR
    ↓
Add: priority-N, security-* labels
    ↓
Wait for Audit Approval
    ↓
24-hour hold
    ↓
Code owner approves
    ↓
MERGE
```

**Duration:** ~21 days (until Priorities 2-7 complete)

---

## 🔴 CRITICAL ISSUES TO FIX

### 1. Former Hardcoded Token Exposure
**File:** `supabase/functions/api/index.ts:395`

**Current state:** The credential literal is removed from the working tree, but
the former value remains in git history and must be treated as exposed until
rotation and history remediation are verified.

**What You Must Do:**
1. Verify the current environment-based implementation
2. Rotate production credentials immediately
3. Remediate the exposed history through the incident process

**Status:** Source fix present locally; rotation and history cleanup pending.

---

### 2. Dashboard Response Scope
**Files:**
- `supabase/functions/api/handlers/dashboard.ts:507`
- `lib/routes/route_access_guard.dart`

**Current state:** Explicit dashboard role mismatches are rejected, but the
default response still needs a field audit so coordinator responses exclude
principal-only finance data.

**What You Must Do:**
- Keep role validation on `/dashboard` paths
- Add tests for role-specific response fields
- Ensure error messages do not leak role information

---

### 3. Payment Delete Violates Compliance
**File:** `supabase/functions/api/handlers/fees.ts:2742`

**The Problem:**
- Endpoint physically deletes payments
- Violates immutable financial history rule
- Creates audit trail gaps

**What You Must Do:**
- Replace DELETE with payment reversal
- Create fee_reversals table
- Update Flutter app to use reversal workflow
- Ensure original payment marked as reversed

---

## 📚 Core Documents

| Document | Read It | Purpose |
|----------|---------|---------|
| [AUDIT_EXECUTIVE_SUMMARY.md](AUDIT_EXECUTIVE_SUMMARY.md) | ⭐⭐⭐ | **START HERE** — Overview of all 8 priorities |
| [FEATURE_FREEZE_POLICY.md](FEATURE_FREEZE_POLICY.md) | ⭐⭐ | PR workflow, labels, approval process |
| [CRITICAL_SECURITY_FIXES.md](CRITICAL_SECURITY_FIXES.md) | ⭐⭐⭐ | Evidence-based findings and remediation |
| [RBAC_AUDIT_PLAN.md](RBAC_AUDIT_PLAN.md) | ⭐⭐ | Testing role isolation + data access |
| [DOCUMENTATION_PLAN.md](DOCUMENTATION_PLAN.md) | ⭐ | Doc roadmap (lower priority) |

---

## 📊 The 8 Priorities

```
1️⃣  FEATURE FREEZE           ✅ Complete (freeze policy documented)
2️⃣  SYSTEM AUDIT             🟠 In progress (critical fixes in progress)
3️⃣  SUPABASE AUDIT           ⏳ Queued (cost optimization)
4️⃣  RBAC AUDIT               ⏳ Queued (role isolation testing)
5️⃣  BACKEND AUDIT            ⏳ Queued (duplicate removal)
6️⃣  TESTING                  ⏳ Queued (regression detection)
7️⃣  RELEASE PIPELINE         ⏳ Queued (automation)
8️⃣  DOCUMENTATION            ⏳ Queued (knowledge base)
```

---

## 🎯 This Week (Aug 13-17)

### Monday (Today)
- [ ] Read AUDIT_EXECUTIVE_SUMMARY.md
- [ ] Implement GitHub branch protection
- [ ] Find the former credential in git history

### Tuesday
- [x] Remove hardcoded token from the current working tree
- [ ] Plan secret rotation strategy

### Wednesday
- [ ] Execute secret rotation
- [ ] Redact token from git history
- [ ] Security review of findings

### Thursday
- [ ] Start dashboard response field-scope fix
- [ ] Begin RBAC audit

### Friday
- [ ] Merge fixes to staging
- [ ] Weekly report + demo to team

---

## 💻 Common Commands

### Check for Secrets in Code
```bash
git log --all -p | grep -iE "password|secret|token|key" | head -30
```

### Find Former Token Commit
```bash
git log --all --oneline -S "<former credential value>"
```

### Run Local Supabase
```bash
scripts/local_supabase.sh prepare
scripts/local_supabase.sh start
flutter run --dart-define-from-file=env.local.json
```

### Run All Tests Locally
```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test --dart-define-from-file=env.local.json
scripts/qa_verify.sh
```

### Quick Security Check
```bash
deno check supabase/functions/api/index.ts
# Look for SECURITY DEFINER functions
SELECT routine_name FROM information_schema.routines WHERE routine_body ILIKE '%SECURITY DEFINER%';
```

---

## ⚠️ DO's and DON'Ts

### DO ✅
- Do read the freeze policy before committing
- Do add labels to every PR
- Do run tests before pushing
- Do ask for help if blocked
- Do escalate if you find new issues

### DON'T ❌
- Don't merge without audit approval
- Don't hardcode secrets (ever!)
- Don't make backward-incompatible API changes
- Don't ignore test failures
- Don't hide problems

---

## 📞 Getting Help

### I have a question:
1. Search docs in main folder
2. Check [AUDIT_EXECUTIVE_SUMMARY.md](AUDIT_EXECUTIVE_SUMMARY.md)
3. Ask in daily standup (9:30 AM)

### I found a bug:
1. Create GitHub issue with label `security-*` or `bug-known`
2. Link to relevant audit document
3. Escalate to audit lead

### I'm blocked:
1. Post in team chat
2. Mention `@audit-lead`
3. Expected response: < 1 hour

---

## 📅 Timeline

```
Week 1 (Aug 13-17): Critical fixes (credential rotation, dashboard fields, payments)
Week 2 (Aug 20-24): RBAC testing, backend consolidation
Week 3 (Aug 27-31): Testing expansion, release pipeline
Week 4 (Sep 3-7):   Documentation, final QA, production release
```

**Total Duration:** ~21 days (can compress with full team)

---

## 🎓 Audit Learning Path

### For Backend Engineers:
1. Read: [CRITICAL_SECURITY_FIXES.md](CRITICAL_SECURITY_FIXES.md) (2 hours)
2. Fix: Verify token removal + rotate secrets (4 hours)
3. Test: Create RBAC test suite (8 hours)
4. Review: [RBAC_AUDIT_PLAN.md](RBAC_AUDIT_PLAN.md) (2 hours)

### For Frontend Engineers:
1. Read: [FEATURE_FREEZE_POLICY.md](FEATURE_FREEZE_POLICY.md) (1 hour)
2. Fix: Dashboard response field scope and route coverage (4 hours)
3. Add: Test cases to route guard tests (4 hours)
4. Review: Payment reversal UI workflow (4 hours)

### For QA:
1. Read: [AUDIT_EXECUTIVE_SUMMARY.md](AUDIT_EXECUTIVE_SUMMARY.md) (2 hours)
2. Create: Test matrices for all roles (8 hours)
3. Test: Local Supabase RBAC isolation (8 hours)
4. Review: [RBAC_AUDIT_PLAN.md](RBAC_AUDIT_PLAN.md) (2 hours)

### For DevOps:
1. Read: [DOCUMENTATION_PLAN.md](DOCUMENTATION_PLAN.md) section "Release Pipeline" (1 hour)
2. Set up: GitHub Actions CI/CD pipeline (4 hours)
3. Test: Staging deployment workflow (4 hours)
4. Automate: Pre-release checks (4 hours)

---

## 🚀 Quick Win (First PR)

### Verify Token Remediation (2 hours)

**Step 1:** Confirm the current source contains no credential literal
```bash
rg -n "SHEETS_WEBHOOK_TOKEN|SUPABASE_SERVICE_ROLE_KEY" \
  supabase/functions/api/index.ts
```
Expected: only environment-variable reads and comparisons.

**Step 2:** Keep the environment-only implementation
```typescript
const fallbackToken = Deno.env.get("SHEETS_WEBHOOK_TOKEN") || "";
const isServiceRole = token.length > 0 && (
  token === serviceKey ||
  (fallbackToken && token === fallbackToken)
);
```

**Step 3:** Test
```bash
deno check supabase/functions/api/index.ts
```

**Step 4:** Commit
```bash
git add -A
git commit -m "security: Remove hardcoded Sheets token (#priority-2)"
git push origin security/remove-token
```

**Step 5:** Create PR
- Title: `[PRIORITY-2] Remove hardcoded Sheets token`
- Label: `security-critical`
- Wait for approval

**Duration:** 2 hours  
**Impact:** 🔴 CRITICAL until rotation, deployment verification, and history remediation are complete

---

## 📋 Daily Checklist

- [ ] Read priority emails
- [ ] Check GitHub for audit-related PRs
- [ ] Run local tests and security checks
- [ ] Attend 9:30 AM standup
- [ ] Post progress update
- [ ] No new feature commits (freeze!)

---

## 🎯 Success = Release Ready (Targets)

When all these are done:
- [ ] Zero hardcoded secrets in source and history
- [ ] Dashboard fields scoped by role
- [ ] Payments immutable + reversible
- [ ] RLS policies verified
- [ ] 80%+ test coverage
- [ ] CI/CD pipeline automated
- [ ] Documentation published

Then: **Deploy to production = Zero surprises**

---

**Last Updated:** August 13, 2026  
**Next Review:** Friday, August 17, 5 PM  
**Questions?** Ask your team lead or audit owner  
**Status:** 🟠 ACTIVE — Charter delivered; remediation is underway

# FEATURE FREEZE & CHANGE CONTROL POLICY

**Effective:** Immediately (August 13, 2026)  
**Duration:** Until all Priority 2-4 audits complete (~21 days)  
**Scope:** All branches, all environments  
**Status:** Active

---

## 1. Feature Freeze Directive

### 1.1 What is Frozen
- ❌ New features (Flutter or backend)
- ❌ Backward-incompatible API changes
- ❌ UI/UX redesigns
- ❌ Database schema changes (except emergency migrations)
- ❌ Authentication/authorization changes
- ❌ Dependency upgrades (except security patches)

### 1.2 What is Permitted
- ✓ Bugfixes (with priority audit approval)
- ✓ Security patches
- ✓ Test coverage improvements
- ✓ Documentation updates
- ✓ Error handling improvements
- ✓ Performance optimizations (non-breaking)
- ✓ Audit-assigned remediation work

### 1.3 Exception Process
**All changes require:** Audit approval + 24-hour review window

```
Developer → Create PR → Request Audit Review → Wait 24h → Merge
```

---

## 2. Version Control & Branching

### 2.1 Branch Rules
```
main (production)
  └─ Only: audit-approved commits, security fixes, tagged releases
     
staging (pre-production)
  └─ Only: audit-approved PRs merged from feature/* after approval
     
feature/* (feature branches, FROZEN)
  └─ Status: No new branches. Existing branches require audit approval to merge.
  
agent/* (CI/CD automation, allowed)
  └─ CI build scripts: android, iOS, web builds only
```

### 2.2 Main Branch Protection
- [ ] Require 2 approvals for merge (audit + tech lead)
- [ ] Require passing CI (lint, format, tests)
- [ ] Require commit message prefix: `audit:`, `security:`, `fix:`, `docs:`, `test:`
- [ ] Require linked PR description mentioning which priority it addresses

### 2.3 Commit Hygiene
**Format:** `<tag>: <message> (#priority)`

```
audit: Remove hardcoded Sheets token (#priority-2)
security: Rotate API keys after token exposure (#priority-2)
fix: Prevent double-debit in fee payment (#priority-2)
test: Add RBAC isolation tests (#priority-6)
docs: Update API reference for fees endpoints (#priority-8)
```

**What NOT Allowed:**
- `wip:`, `temp:`, `debug:`, `zzz:` (temporary commits)
- No message = auto-reject
- Commits with `TODO`, `FIXME` in body

---

## 3. Audit Approval Workflow

### 3.1 Before Merge
Every PR must include:
```markdown
## Audit Checklist
- [ ] This PR addresses Priority #___ (1-8)
- [ ] Does not add new features
- [ ] Does not introduce new dependencies
- [ ] All tests pass locally
- [ ] No hardcoded secrets or tokens
- [ ] No backward-incompatible changes
```

### 3.2 Review Layers
```
Tier 1: Automatic Checks (CI/CD)
├─ `dart format --set-exit-if-changed .` ✓
├─ `flutter analyze` ✓
├─ `deno check` ✓
├─ `bun run typecheck` ✓
└─ All tests pass ✓

Tier 2: Human Review (Code owner)
├─ Commit message matches format
├─ No feature additions
├─ Security concerns addressed
└─ Approve/request changes

Tier 3: Audit Sign-Off (Audit lead)
├─ Verify PR aligns with priority
├─ No hidden security issues
├─ Broader impact assessment
└─ Final approval tag: @audit-approved
```

### 3.3 Approval Tags
- `@audit-approved` = Ready to merge after 24-hour hold
- `@audit-rejected` = Full rewrite required
- `@audit-conditional` = Approved with specific changes required

---

## 4. Issue Tracking

### 4.1 PR/Issue Labels (MANDATORY)
```
priority-1  Priority 1: Feature Freeze
priority-2  Priority 2: System Audit
priority-3  Priority 3: Supabase Audit
priority-4  Priority 4: RBAC Audit
priority-5  Priority 5: Backend Audit
priority-6  Priority 6: Testing
priority-7  Priority 7: Release Pipeline
priority-8  Priority 8: Documentation

security-critical   🔴 Must fix before release
security-high       🟠 Fix after critical path
bug-known           Issue from PRD Section 11
bug-regression      New bug introduced in audit

blocked             Waiting on another task
in-review           Under audit review
audit-approved      Ready to merge
```

### 4.2 GitHub Issues
Every known issue must have:
```
Title: [PRIORITY-#] [CATEGORY] Brief description

Labels:
- priority-N
- security-* OR bug-* OR feature-*
- status

Description:
## Issue
What is the problem?

## Impact
Why does it matter?

## Acceptance Criteria
How do we know it's fixed?

## Depends On
Blocks: (if any)
Blocked By: (if any)
```

---

## 5. Stakeholder Communication

### 5.1 Daily Sync (9:30 AM)
- Blockers from previous day
- Plan for today
- Security findings requiring escalation

### 5.2 Weekly Report (Friday 5 PM; template)
```
PRIORITY 1: Feature Freeze Status
  ✓ Policy is active; verify enforcement in repository settings
  - Security fixes merged: <verified count>
  - PRs pending audit: <verified count>
  
PRIORITY 2: System Audit
  📊 Progress: <verified percentage>
  ⚠️ Blockers: Credential rotation/history remediation and payment reversal
  
PRIORITY 3-8: [Similar format]

RISKS:
- Former credential exposure (in git history)
- Payment delete path (compliance)
- Supabase warnings (5 unaddressed)

NEXT WEEK:
- Rotate all secrets
- Fix dashboard response field scope
- Begin RBAC testing
```

### 5.3 Escalation Path
```
Developer → Code Owner → Audit Lead → Tech Lead → Founder
                                    ↑
                              24-hour hold
```

---

## 6. Release Freeze Policy

### 6.1 Freeze Until
- ✓ Priority 1 policy is documented
- [ ] Priority 2 critical path complete and verified
- [ ] Priority 6 gates implemented (regression detection)
- [ ] Priority 7 pipeline hardened (CI/CD gating)

### 6.2 Staging Deployments Allowed
- ✓ Deploy audit fixes to staging for testing
- ✓ Do NOT deploy to production
- ✓ Store builds do not reflect staging (production only)

### 6.3 Production Holds
- ❌ No APK building (except for internal audit testing)
- ❌ No Play Store releases
- ❌ No web deployment to production
- ✓ GitHub continuous integration runs (safe)

---

## 7. Documentation Requirements

All PRs must update:
- [ ] SYSTEM_AUDIT_REPORT.md (audit progress)
- [ ] CRITICAL_SECURITY_FIXES.md (if security-related)
- [ ] API docs (if backend changes)
- [ ] Changelog (user-facing fixes only)
- [ ] Test documentation (if test changes)

---

## 8. Rollback Policy

### 8.1 When to Rollback
- Critical security bug merged to main
- Test suite breaks unexpectedly
- Audit approval bypassed

### 8.2 Rollback Procedure
```bash
git revert <commit-hash>  # Create new commit (preserve history)
git push origin main
# Do NOT use: git reset --hard (destroys audit trail)
```

---

## 9. Exceptions & Waiver Process

### 9.1 Situations Requiring Exception
- Production outage (fire-fighting)
- Customer-blocking bug (escalated)
- Regulatory requirement (legal hold)

### 9.2 Waiver Approval
```
Requestor → Provide justification → Audit lead → Wait 48h → Founder approval
            Include: Business impact, risk, duration, rollback plan
```

### 9.3 Waiver Logging
All waivers recorded in `FREEZE_EXCEPTIONS.log`:
```
DATE: 2026-08-14
ISSUE: Production outage: login broken in region
DURATION: 12 hours
APPROVED_BY: Founder
RATIONALE: Firebase auth outage affecting users
CHANGES_DEPLOYED: Hotfix to fallback auth endpoint
LESSONS_LEARNED: Need regional failover
```

---

## 10. Transition to Normal Development

### 10.1 Exit Criteria
- All Priority 1-4 complete
- Zero known critical security issues
- Regression tests passing
- Code review clean
- Stakeholders approve

### 10.2 Gradual Thaw
```
Day 1: Reopen feature branches (bugfixes only)
Day 2: Allow safe new features (with audit review)
Day 3: Remove 24-hour hold requirement
Day 4: Return to normal development process
```

---

## 11. Change Log

| Date | Status | Notes |
|------|--------|-------|
| 2026-08-13 | Active | Feature freeze initiated, 8 priorities assigned |
| TBD | Review | Audit progress review (weekly) |
| TBD | Partial Thaw | Priority 2-4 complete, some development resumes |
| TBD | Full Thaw | All priorities complete, normal development resumes |

---

## 12. Appendix: Audit-Era Dos & Don'ts

### DO ✓
- Do submit PRs with audit labels
- Do write tests for your fixes
- Do document security changes
- Do ask for help if blocked
- Do escalate if you find new issues

### DON'T ❌
- Don't merge without audit approval
- Don't commit hardcoded secrets
- Don't make backward-incompatible changes
- Don't assume your fix doesn't need tests
- Don't hide problems (they compound)

---

**Policy Owner:** Audit Lead  
**Review Date:** Every Friday (or as needed)  
**Last Updated:** August 13, 2026; progress values are evidence-driven

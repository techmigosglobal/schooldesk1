# Leadership Desktop UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify existing desktop workflows for Principal and Coordinator, preserve navigation context, reconcile collection figures, and retain Principal-only finance access.

**Architecture:** Retain the Next.js portal and existing module components. Introduce a small navigation/state layer, shared page controls, and a typed adapter over the existing `fees/summary` endpoint. Reuse existing authenticated APIs and backend authorisation; changes default to `schooldesk-web` only.

**Tech Stack:** Existing Next.js 16 / React 19 / TypeScript / Bun tests / current CSS and dialog components. Browser checks use available Playwright or browser automation tooling. No new UI framework or dependency is required.

**Spec:** [Leadership desktop UX requirements](2026-10-16-leadership-desktop-ux-requirements.md).

## Global constraints

- "Keep the existing features; remove duplication and confusing presentation."
- "Principal and Coordinator share non-finance functionality."
- "Finance is Principal-only, including the Fees module, finance metrics, payment verification, finance search results, finance report generation, exports and downloads."
- "Coordinator remains limited to the assigned branch under existing backend authorisation. Do not grant cross-branch access."
- "Keep Flutter source/builds, shared backend contracts, database schema, existing unrelated edits, and public SEO intact."
- No production mutations for testing; local isolated fixtures may exercise saves, payment verification, fines and publication.
- No commits, push, deployment or external issue edits during plan preparation. During implementation, use scoped review checkpoints; commit only if authorised.
- Do not store credentials, tokens, signed report URLs, financial records or full profile objects in navigation persistence.

---

## Baseline, dependencies and known constraints

1. Read the spec, current `AGENTS.md`, relevant ADRs and prior audit. Save a manifest of pre-existing dirty paths before implementation. This checkout already contains unrelated Flutter/backend attendance edits and substantial earlier web changes; do not reset them or accidentally attribute them to this work.
2. The codebase-memory skill has been read. Its graph tools are unavailable in this planning turn. The previous audit's graph located the relevant components but reported changed metadata; this plan uses direct current-source verification. At implementation start, use graph status/search/coverage if available and verify changed ranges against source.
3. Existing `GET fees/summary` calls `fee_dashboard_summary` and returns `billed`, `collected`, `outstanding`, `overdue`, `invoice_count`, `student_count`, `overdue_count`, `pending_request_count`. Reuse it; do not create a parallel financial aggregation or change the shared RPC as a UI shortcut.
4. The RPC excludes cancelled/void invoices and uses invoice `paid_amount`; Fees currently sums payment rows. This establishes different calculation paths, not the exact cause of the observed delta.
5. Existing export endpoints return arrays without an explicit pagination envelope. Paginate the returned list in the UI; use endpoint pagination only if its deployed contract proves necessary. Do not change backend contracts pre-emptively.
6. The current disk inspection showed about 2.1 GB free. Recheck before production builds; do not delete unrelated files to create space. This does not block document preparation.
7. These are one coordinated portal improvement, so use one plan with independently reviewable tasks. Dependencies: Task 1 → 2; Task 3 → 4 and 7; Task 5 → 6, 7, 8, 9; Task 10 validates the complete result.

## Intended user experience

**Shared visible navigation:** Overview; Students; Parent accounts; Teachers & staff; Classes & subjects; Timetables; Reports; Admission inquiries; Public Website. Principal additionally sees Fees between Timetables and Reports. Keep these directly visible; no mandatory nested sidebar menus.

**Shared header:** one page title, current branch context, Quick Search, one active-view Refresh action, Sign out. Principal retains its authorised branch picker. Coordinator sees its assigned branch context without a new cross-branch selector.

**Overview order:** compact heading → up to three genuine task shortcuts → compact counts → actual pending work; Principal additionally has one fee summary. Remove the large welcome hero, duplicate collection visualisation and generic media promotional panel.

**Principal fee tabs:** Student fees; Payments; Verification; Fee structures; Concessions; Payment settings. Place existing financial exports in the Finance group of Reports; the outstanding follow-up list belongs in Student fees. No separate Gateway Config catch-all remains.

**Website tabs for both roles:** Media library; Homepage copy; News ticker. Open the existing upload form in an on-demand dialog/panel. The library remains the primary area.

**Reports:** Academic report group for both roles, Finance group for Principal only; scope controls beside the applicable group; paginated export history.

## File responsibility map

Existing paths below are relative to `schooldesk-web/` unless explicitly marked root.

| File(s) | Responsibility |
|---|---|
| `lib/roles.ts`, `components/portal/types.ts`, `components/portal/report-catalog.ts` | Authoritative web module IDs, display labels, role capabilities, report groups |
| New `lib/portal-navigation.ts` | Pure URL parsing/serialisation and role-safe target validation |
| New `components/portal/PortalStateProvider.tsx` | Branch/session-scoped view state; stores UI state, not API records |
| `lib/session.ts`, `app/api/auth/login/route.ts`, `app/api/auth/logout/route.ts`, `app/portal/[role]/page.tsx` | Opaque UI-session namespace, lifecycle/reset and server-to-client scope metadata |
| `components/portal-client.tsx`, `ResourceModule.tsx`, `QuickSearchModal.tsx` | Shared shell, all navigation entry points, Coordinator website parity, state wiring |
| New `lib/fee-summary.ts` | Typed validation and display mapping for existing summary response |
| `DashboardPanel.tsx`, `FeesWorkspace.tsx`, `ReportsWorkspace.tsx` | Consume common finance summary only for Principal; simplify view hierarchy |
| New `components/portal/PortalPageHeader.tsx`, `use-portal-refresh.ts` | Single title/toolbar and one registered active-view refresh handler |
| New `components/portal/RecordActions.tsx` | Shared labelled secondary action popover using existing buttons/focus patterns |
| `StudentDirectory.tsx`, `ParentDirectory.tsx`, `TeacherDirectory.tsx`, `ClassesWorkspace.tsx`, `TimetableWorkspace.tsx`, `AdmissionInquiriesWorkspace.tsx` | Persist relevant view state, simplify tables, retain existing forms and details |
| `WebsiteManager.tsx`, `TickerManager.tsx`, `Dialog.tsx` | On-demand upload, concise media cards, tab-specific refresh and unsaved-work protection |
| New `components/portal/FinanceReportTools.tsx` | Existing CSV/follow-up export actions presented inside Principal Finance reports |
| `app/globals.css` | Scoped portal density, table sizing, sticky actions, desktop layout and focus styles |
| `tests/role-policy.test.ts`, new `tests/portal-navigation.test.ts`, new `tests/fee-summary.test.ts`, new `tests/portal-attention.test.ts` | Behavioural rules: authorisation, navigation, financial mapping, attention conditions |
| `tests/leadership-portal.test.ts`, `tests/desktop-seo.test.ts`, `README.md` | Update obsolete assertions; preserve regression coverage; document verified behaviour |

## Task 1: Establish consistent non-finance capabilities for both roles

**Files:** `lib/roles.ts`, `components/portal/types.ts`, `components/portal-client.tsx`, `QuickSearchModal.tsx`, `report-catalog.ts`, `tests/role-policy.test.ts`.

**Interfaces:** `visibleModules(role)` remains the source of allowed module IDs. Add `canManageFinance(role: PortalRole): boolean`; website management is available to both declared portal roles. Backend identity/school checks remain authoritative.

- [ ] Extend role tests with exact module parity and Principal-only finance checks:

```ts
const principal = visibleModules("principal");
const coordinator = visibleModules("coordinator");
expect(principal.filter(id => id !== "fees")).toEqual(coordinator);
expect(canManageFinance("principal")).toBe(true);
expect(canManageFinance("coordinator")).toBe(false);
expect(reportsForRole("coordinator").some(isFinanceReport)).toBe(false);
```

- [ ] Run `bun test tests/role-policy.test.ts`; confirm new assertions identify the missing capability helper, then implement it. Replace the ticker-only Coordinator render with the same `WebsiteManager` used by Principal.
- [ ] Derive Quick Search navigation labels from the shared module definitions. Include Public Website and Admission inquiries for both roles; exclude all invoice/finance entries for Coordinator.
- [ ] Keep existing finance proxy/download protections; test direct calls, not just hidden sidebar items. Verify website reads/saves with a local Coordinator session under existing backend rules. Do not change a production password or broaden backend permissions to make a browser test pass.
- [ ] Review checkpoint: both roles have matching non-finance destinations and controls. Coordinator has no finance UI, requests, downloads or leaked totals. Record that authenticated deployed Coordinator validation is still outstanding if no usable session exists.

## Task 2: Preserve navigation, tabs and branch-scoped working context

**Files:** new `lib/portal-navigation.ts`, new `PortalStateProvider.tsx`, `portal-client.tsx`, `ResourceModule.tsx`, relevant directory/workspace components, session/login/logout/page paths from the map; new `tests/portal-navigation.test.ts`.

**Interfaces:**

```ts
type PortalTarget = { module: string; tab?: string; sectionId?: string };
function parsePortalTarget(search: string, role: PortalRole): PortalTarget;
function serializePortalTarget(target: PortalTarget, role: PortalRole): string;
type DirectoryView = { search: string; status: string; classId: string; page: number };
```

`parsePortalTarget` defaults to Overview, validates modules with `visibleModules(role)`, and validates tabs against per-module allowlists. `serializePortalTarget` returns a query beginning `?module=...`. No secret/token or person name enters the URL.

- [ ] Add behavioural tests for valid bookmarks, malformed values, disallowed finance and tab validation:

```ts
expect(parsePortalTarget("?module=fees&tab=requests", "principal"))
  .toMatchObject({ module: "fees", tab: "requests" });
expect(parsePortalTarget("?module=fees&tab=requests", "coordinator"))
  .toEqual({ module: "overview" });
expect(parsePortalTarget("?module=website&tab=unknown", "coordinator"))
  .toMatchObject({ module: "website", tab: "gallery" });
```

- [ ] Run the targeted test, implement pure parsing/serialisation, then use Next navigation for sidebar, dashboard, Quick Search and tab actions. User destination changes push history; filter/page normalisation replaces history. Keep tab IDs separate from human labels.
- [ ] Introduce a provider scoped by opaque successful-login namespace + role + effective branch. Add a server-managed opaque namespace cookie for UI persistence only; never use it for authorisation. Rotate it on successful login, clear on signout, and scope provider storage by active branch; never expose access/refresh tokens to client props. A validated school identity or server-issued scope must supply Coordinator's effective branch.
- [ ] Preserve directory filters/page, class/subject tab, timetable class, website tab/filter/page, report scope/history page and fee tab/class/student selection. Session storage holds only bounded, versioned UI values; API rows, forms, upload blobs and signed URLs stay out. Validate persisted IDs against newly loaded scoped records.
- [ ] On branch change abort/ignore old requests, clear record selections/data, reset invalid URL section IDs, and remount the active data view. Never show cached previous-branch records while loading.
- [ ] Protect unsaved forms/timetable/copy/news changes before module/branch changes or in-app refresh. During an active save, block navigation until its outcome is known. Do not silently restore or submit unsaved form contents.
- [ ] Browser checkpoint: Students filter → Reports → Back restores Students/filter/page; Forward returns Reports; reload and copied module/tab URL restore the destination; new login and branch changes cannot resurrect another scope's state. Invalid Coordinator fee URL yields a safe non-finance view without making finance requests.

## Task 3: Reconcile finance and use the existing authoritative summary

**Files:** new `lib/fee-summary.ts`, `components/portal/types.ts`, `DashboardPanel.tsx`, `FeesWorkspace.tsx`, `ReportsWorkspace.tsx`; new `tests/fee-summary.test.ts`.

**Interfaces:**

```ts
type FeeSummary = {
  billed: number; collected: number; outstanding: number; overdue: number;
  invoiceCount: number; overdueCount: number; pendingRequestCount: number;
  collectionPercent: number | null;
};
function readFeeSummary(value: unknown): FeeSummary;
```

Map snake_case keys from existing `GET fees/summary`. Require finite numeric values, retain legitimate zero, and reject missing/invalid totals. Compute percentage from collected / (collected + outstanding), matching the current dashboard definition for positive denominators; return null for an empty/zero denominator, rendered as an explicit no-collection-target state. Do not silently clamp unexplained credits/refunds into apparently normal figures.

- [ ] Re-read the deployed summary, dashboard and all pages of invoices/payments for the same branch and all-academic-years scope. Record amounts and aggregate discrepancy categories without retaining student names or credentials. Compare payment invoice linkage, invoice status, school/year scope, reversal/refund/approval status and invoice paid amounts; do not infer the ₹40,000 cause from matching differences alone.
- [ ] Add a fixture that distinguishes invoice-based collection from raw payment totals:

```ts
const summary = readFeeSummary({ billed: 3349000, collected: 1566000,
  outstanding: 1783000, overdue: 0, invoice_count: 127,
  overdue_count: 0, pending_request_count: 1 });
expect(summary.collected).toBe(1566000);
expect(summary.collectionPercent).toBe(47);
expect(summary.pendingRequestCount).toBe(1);
```

Also test zero target, missing totals and invalid numeric values. Run `bun test tests/fee-summary.test.ts` before/after implementation.
- [ ] Load `fees/summary` only for Principal and use the same adapter across fee/overview/finance-report summaries. Remove the competing raw-payment KPI calculation. Receipt history remains a historical ledger and is not deleted or filtered merely to force totals to match.
- [ ] Display the scope, e.g. current branch / all academic years. Refresh the summary after successful payment, verification, concession or fine mutations and mark other mounted/cached finance consumers stale. Distinguish refresh-in-progress from confirmed data; failures retain a visibly stale last successful value instead of zeroing it.
- [ ] Review checkpoint: two pages fetched for the same scope agree on collection amount, balance and percentage; the delta investigation is documented. If the existing backend contract/data is wrong, isolate that as a separate compatible backend repair with the repository migration/deployment safeguards. Do not change shared accounting rules or mobile-facing responses inside this UI task.

## Task 4: Simplify Overview and show truthful pending work

**Files:** `DashboardPanel.tsx`, `types.ts`, new `lib/portal-attention.ts`, new `tests/portal-attention.test.ts`, portal-scoped CSS.

**Interfaces:** `buildAttentionItems({role, pendingVerificationCount, inquiryCount})` returns only existing-action targets. Inquiry count is informational unless a real pending status exists.

- [ ] Implement the following decision table as a pure helper and test it with Bun before wiring UI:

```text
Principal + pendingVerificationCount=1 => Fees / requests / count 1
Principal or Coordinator + inquiryCount=0 => no inquiry attention row
Principal or Coordinator + inquiryCount>0 => informational 'Admission inquiries'
Configured classes count > 0 => never an attention item
Coordinator => no finance attention item, regardless of supplied input
```

- [ ] Replace the greeting hero with a compact heading/subtitle; use neutral time-independent greeting text. Put Add student and View timetable near the top. Add Review payments only for Principal when a pending verification exists, deep-linking to the Verification tab. Keep no generic media shortcut panel.
- [ ] Retain compact Students, Parent accounts, Teachers & staff and Classes summaries. Avoid a fake zero or 'View directory' styled as a numeric parent count; use a truthful navigation link if the API has no count.
- [ ] Principal receives exactly one fee collection summary linked to the fee workspace; remove the duplicate collection ring, duplicated fee attention percentage and generic Fee reminders shortcut. Actual payment verification remains a separate actionable item.
- [ ] Use 'No pending actions' when none exist. Keep errors/retry explicit and do not render an empty successful summary after a failed load.
- [ ] Browser checkpoint: routine shortcuts visible without scrolling at 1366×768; zero inquiries/configured classes do not appear urgent; selecting Review payments opens the correct tab; Coordinator sees the same non-finance layout without finance gaps/cards.

## Task 5: Standardise page titles, active-view refresh and terminology

**Files:** new `PortalPageHeader.tsx`, `portal-client.tsx`, `use-portal-refresh.ts`, all listed workspace headings, `QuickSearchModal.tsx`, `types.ts`, `app/globals.css`.

**Interface:** `PortalPageHeader({title, description?, actions?})` supplies the single h1 inside the shell. Module section headings use h2/h3. Replace broad event subscriptions with one active-view refresh registration through the provider.

- [ ] Apply the exact shared names in Intended user experience to sidebar, search results, heading, dialog descriptions and breadcrumbs. Keep Students separate from Parent accounts because linking and credential management have a distinct purpose.
- [ ] Register exactly one refresh callback for the active module/tab. The Website parent must not also reload gallery/copy when the News ticker callback runs. Refresh retains filters/selections, shows a busy state and timestamp, and follows the unsaved-work rule from Task 2.
- [ ] Keep branch context, Quick Search, Refresh and Sign out in the topbar. Remove repeated module Refresh buttons and repeated page title/kicker blocks. Keep module-specific primary actions near relevant filters.
- [ ] Use one top-level action per active task where possible: Add student, Add parent, Add staff, Add class section or Add subject according to tab. Delete/reset/fine controls are secondary actions, not the main call to action.
- [ ] Verify in browser that each page has one h1 and one refresh action, focus order is logical, keyboard activation works and errors appear close to the action. Check request counts per tab; a refresh must not duplicate a resource load through parent/child subscriptions.

## Task 6: Fit directory work to desktop width

**Files:** Students/Parents/Teachers/Classes directories, new `RecordActions.tsx`, existing profile dialogs, `app/globals.css`.

- [ ] Use these essential columns: Students — identity/admission, class, parent/contact, status, actions; Parent accounts — parent/contact, linked children, account status, actions; Teachers & staff — identity/designation, assignments, contact, status, actions; Classes — class/section, enrollment/capacity, teacher assignments, room, actions.
- [ ] Keep DOB, gender, extra identifiers and long assignment detail in the existing profile view. Preserve their data and editing fields. Do not shrink text until unreadable to keep every old column.
- [ ] Remove the blanket 1100px minimum from these directory tables; apply table-specific widths, wrap long names, and keep the action column visible. Constrain long linked-child/assignment text with a clearly labelled existing details action.
- [ ] Keep View/Edit obvious. Put Link children, Reset credentials and Delete in a labelled secondary action popover with button semantics, keyboard support, Escape/return-focus behaviour and existing confirmations. Keep destructive commands visually distinct.
- [ ] Retain existing pagination and contextual counts; add an explicit reset-filters control only when filters are active. Preserve query/page through Task 2 state. Clamp page after deletion/filter changes so users never land on a blank non-existent page.
- [ ] Browser checkpoint at 1366×768 and 1440×1000: normal directory tables need no horizontal scrolling; long test names/contacts do not cover actions; controls and dialogs work by keyboard; save/refetch/cancel retain correct context. Use isolated fixtures for destructive/reset paths.

## Task 7: Make fee work task-oriented and move exports to Reports

**Files:** `FeesWorkspace.tsx`, new `FinanceReportTools.tsx`, `ReportsWorkspace.tsx`, `report-catalog.ts`, existing fee dialogs.

- [ ] Keep the tab order and names listed in Intended user experience. Payment settings contains only the existing UPI/bank configuration and its save action.
- [ ] Move existing outstanding-report PDF and receipt-register CSV actions into `FinanceReportTools` in the Principal Finance report group. Retain current endpoint/file formats; this is relocation, not a new export engine. Link any fee-page export shortcut directly to that group rather than duplicate full panels.
- [ ] Keep the existing class → student → invoice/payment flow. Show a concise breadcrumb and use Task 2 state to preserve selections. Routine payment recording remains in student context; Fee structures shows New fee structure as its primary action.
- [ ] Place the existing outstanding follow-up list under Student fees. Call it Outstanding balances unless due_date proves an invoice overdue; compute date-only due comparisons against the school's calendar day. Missing/future due dates are not overdue. Retain export rows and display their real status.
- [ ] Move Apply late fines into secondary actions and add a confirmation naming the current branch and existing backend action scope. Do not imply it affects only a selected student/year if the endpoint operates more broadly. Disable double submission and retain existing payment idempotency handling.
- [ ] Validate with isolated fixtures: navigation to Verification, successful/rejected verification, partial payments, concessions, fine confirmation/cancel, fee structure save and bank settings save. Production checks remain read-only.

## Task 8: Simplify media browsing for both roles

**Files:** `WebsiteManager.tsx`, `TickerManager.tsx`, `Dialog.tsx`, portal CSS.

- [ ] Make Upload the library's main action; place the unchanged upload fields in an on-demand dialog/panel with focus management and cancel/reset behaviour. Preserve file types, size limits, descriptions and public-photo-only rules.
- [ ] Keep one status badge per item and one count-bearing filter row. Remove the duplicate summary count cards, repeated lower status pill and per-item boilerplate app/web explanation; keep one short shared explanation where needed.
- [ ] Video cards retain preview; replace the disabled Display action with clear 'Library video' text because the public gallery supports photos. Keep photo Hide/Display actions, publication distinction, edit/delete restrictions and event-post provenance.
- [ ] Continue page size 24 and video preload none. Do not load all media bytes or hidden upload previews when opening the library. Retain search/filter/page when leaving and returning; after updates keep the current valid page rather than always resetting it to 1.
- [ ] Apply the same tabs/forms to Coordinator; verify GET and local fixture PUT/POST/DELETE behaviour with its assigned school. Use existing backend denials for foreign-school IDs. If deployed behaviour differs from source, report the precise route/status and keep parity unverified until corrected; never substitute a Principal/service-role token.
- [ ] Browser checkpoint: preview, hide/display, upload validation, cancel and publication confirmation work for both permitted roles in isolated data. One visibility status per card; more width devoted to browsing. Never delete media because titles match.

## Task 9: Organise reports and expose complete history

**Files:** `ReportsWorkspace.tsx`, `report-catalog.ts`, new `FinanceReportTools.tsx`, `app/api/reports/download/route.ts` only if lookup pagination requires it, portal state and CSS.

- [ ] Present the existing eight academic reports under Academic and six finance reports under Finance. Coordinator has only Academic; no disabled Finance teaser, hidden finance data or finance network calls.
- [ ] Remove repeated overview counts from Reports. Academic year/class/section filters sit with Academic and preserve current scope. Finance explicitly states current branch / all academic years unless its existing endpoint supports and actually uses additional filters.
- [ ] Include the relocated fee export tools under Finance without conflating CSV receipt history with PDF report definitions. Name each action by report context for accessible button labels.
- [ ] Replace `history.slice(0, 12)` with stable client pagination, 12 entries per page. Sort by actual timestamp with ID as tie-breaker; keep category/title/status/date and applicable download/re-generate action. Preserve selected page across navigation and clamp when list size changes.
- [ ] Add a deterministic history test using 25 fixture records: pages contain 12, 12 and 1, every ID is reachable exactly once, and finance records never enter Coordinator history. Extract a pure history selection helper if needed rather than testing HTML/source-string implementation details.
- [ ] Preserve missing legacy-file messages and Generate current PDF. Never present a broken URL as a working download. If upstream exports become paginated, update listing and authorised download-record lookup together; do not remove branch/role/object-origin checks.
- [ ] Browser checkpoint: generate/download current academic and finance PDFs using isolated fixtures; inspect rendered PDF content/scope, pagination and old-file recovery messaging. Read-only production review may verify existing downloadable files, without generating new exports.

## Task 10: Verify desktop delivery and prepare a reviewable release

**Files:** behavioural tests named above, existing test updates, `schooldesk-web/README.md`, separate evidence report. No default backend/mobile edits.

- [ ] Run focused behavioural tests as each task lands. Update old source-string assertions only where the old markup is intentionally replaced; do not delete meaningful permission, pagination, session or receipt coverage.
- [ ] Run the complete web checks from `schooldesk-web` after sufficient disk space is available:

```sh
bun test
npm run typecheck
npm run build
```

- [ ] Check whitespace with `git diff --check -- schooldesk-web docs/superpowers/plans`. Review the final diff against the baseline manifest; no Flutter or shared backend change may be attributed to this work accidentally.
- [ ] Desktop acceptance matrix: both roles × Overview/Students/Parent accounts/Teachers & staff/Classes/Timetables/Reports/Admissions/Website; Principal additionally Fees. Viewports 1366×768, 1440×1000, 1920×1080. Check keyboard navigation, dialog focus, 200% zoom, long text, empty/error/loading/stale states, and slow/failed requests. These are desktop tests, not a mobile implementation project.
- [ ] Navigation acceptance: direct link, reload, Back/Forward, module switch, filter/page/class restoration, branch change and signout/new login. Verify that the same section ID or search does not leak across accounts/branches and that old async results cannot overwrite current data.
- [ ] Role acceptance: Coordinator non-finance parity; direct finance endpoint/export/download attempts denied; no principal impersonation or reset of real Coordinator credentials. If no working Coordinator session exists, use local fixture accounts and state explicitly that deployed authenticated Coordinator proof is outstanding.
- [ ] Finance acceptance: reconcile live same-scope figures and document the exact delta categories; no data repair performed merely to make cards agree. Assert a cancelled/void invoice fixture does not inflate current summary, and historical receipt rows remain available under truthful labels.
- [ ] Performance/public regression: measure desktop production-build page transitions and media request volume, compare existing desktop Lighthouse baseline under identical conditions, check no portal-driven regression in public title/canonical/noindex rules. No mobile benchmark is required. Avoid a claimed score guarantee; record actual run conditions and results.
- [ ] Prepare a before/after desktop walkthrough, test results, remaining limitations and rollback instructions. Keep credentials and real family information out of saved screenshots/reports.
- [ ] Release handoff: local build + tests + Principal browser proof + Coordinator proof status → concrete review → separately authorised deployment → read-only hosted smoke for role boundaries, navigation, summaries and public SEO. Rollback is restoring the prior web deployment; do not roll back unrelated backend/mobile work.

## Completion criteria

- All eight audited areas have corresponding implementation and browser evidence.
- Both roles share existing non-finance functionality, with finance blocked at UI and API boundaries.
- Reload/Back/Forward/bookmarking and preserved scoped context work.
- Collection totals agree for a defined scope; the original difference is explained, not hidden.
- Overview shows actual pending work and routine actions above the fold on the target desktop size.
- One title and active-view refresh, clear labels, usable directory columns/actions.
- Media browsing is less repetitive; upload is available on demand; no records lost.
- All returned export history is reachable and existing report generation/download behaviour is retained.
- Web checks pass; verified and outstanding live evidence are clearly distinguished; Flutter is untouched.

## Plan self-review

Coverage: Overview/attention → Task 4; navigation → Task 2; finance consistency → Task 3; labels/refresh → Task 5; desktop directories → Task 6; fee discoverability → Task 7; media → Task 8; reports → Task 9; Coordinator parity → Tasks 1/8/10. Tests and release boundaries → Task 10. No extra business module is proposed. Backend source references explain existing contracts; they are not authorisation to alter shared backend behaviour.

# SchoolDesk Product Requirements Document

**Status:** Canonical product definition
**Product:** SchoolDesk
**Business model:** One school with multiple branches
**Primary clients:** Flutter mobile application, limited leadership web portal, public school website

## 1. Product definition

SchoolDesk is a backend-backed school ERP for operating one school across multiple branches. It manages school governance, people, academics, attendance, communication, fees, documents, reports, admissions, and the public school website.

The Flutter application is the complete operational product. The web application is intentionally limited to Principal and Coordinator leadership workflows; it is not expected to mirror every mobile feature. Teacher and Parent workflows remain mobile-first in the current scope.

Supabase is the system of record and active backend. The UI must never present mock data as live school data, silently hide backend failures, or grant access based only on a client-selected role or branch.

## 2. Product principles

- **Backend authority:** Supabase data and server-side authorization are authoritative.
- **Branch isolation:** Every school-data read, write, export, upload, and report is scoped to the active branch.
- **Explicit states:** Loading, empty, error, retry, success, conflict, and permission-denied states are visible.
- **Role clarity:** The user sees only workflows allowed for the authenticated role and branch.
- **Mobile completeness:** Existing mobile workflows are documented even when no web equivalent exists.
- **Safe operations:** Financial history, identity data, documents, and access changes require auditable, recoverable operations.

## 3. Roles and ownership

| Role | Current scope | Mobile | Web |
| --- | --- | --- | --- |
| Principal | Operates the whole school; selects one branch at a time; owns fees and governance | Full leadership operations, including Fees | Full limited leadership portal, including Fees |
| Coordinator | One Coordinator per branch; operates independently like Principal within the assigned branch; no Principal approval required for ordinary operations | Same leadership operations as Principal except Fees | Same leadership modules as Principal except Fees |
| Teacher | Assigned classes and teaching responsibilities | Yes | No |
| Parent | Linked child and family workflows | Yes | No |
| Super Admin | Platform-level school, access, monitoring, issue, and audit administration | Yes, system scope | No current school portal |
| Kiosk user | Attendance kiosk operation | QR attendance kiosk | No |

Coordinator is the current product name for the former Admin role. “Admin” must not be presented as a separate operational role in new UI, documentation, or permissions. Legacy data and API values may be normalized for compatibility, but the effective product role is Coordinator.

### 3.1 Branch access

- A Principal can access all branches but must select one active branch before viewing or mutating branch data.
- A Coordinator is assigned to one branch and cannot switch to another branch.
- All branch-sensitive operations use the active branch from the authenticated server-side context, not a trusted URL or client-only parameter.
- Current scope is one branch at a time. Cross-branch roll-up dashboards and reports are future scope.
- A Coordinator may perform website and admission operations for the assigned branch without Principal approval.
- The Principal may perform the same operations for the selected branch.

## 4. Mobile application scope

The following is the complete current mobile product inventory. A feature may be mobile-only even when it is not listed in the web portal.

### 4.1 Public, authentication, and shared tools

- Public landing and school discovery.
- Onboarding, sign-in, logout, session recovery, and role-aware routing.
- Principal, Teacher, Parent, and Kiosk sign-in flows.
- Demo-role selection for controlled QA only; it must not bypass production authorization.
- Profile, settings, notifications, global search, Help & Tutorials, loading, empty, error, and retry surfaces.
- School gallery and shared media viewing.

### 4.2 Principal and Coordinator leadership operations

Principal and Coordinator share this operational surface, subject to branch scope. Fees are Principal-only.

- Role dashboard and branch context.
- School profile and operational settings.
- User management, account creation/editing, activation, access permissions, and parent-child assignment.
- Staff and teacher directory, forms, profiles, documents, and staff oversight.
- Student directory, admissions/student oversight, student profiles, guardians, linked parent accounts, documents, photos, and lifecycle status.
- Admission inquiries and admission operations.
- Approval Center and approval history.
- Class Hub, grades, sections, subjects, curriculum, rooms, academic years, terms, and class/subject mappings.
- Class-first timetable creation, editing, preview, publishing, copy-day, class/teacher/room views, and export.
- Attendance oversight, attendance sessions, corrections, reopen/reminder actions, history, audit trail, and exports.
- Lesson planners and academic planning.
- Reports, analytics, academic exports, classwise exports, users-wise exports, and supported document generation.
- Documents, school records, ID-card generation, and report exports.
- Communications, messages, complaints, event posts, school feed posts, school-post approvals, calendar/events, and gallery workflows.
- Notifications and operational activity visibility.
- System monitoring and audit logs where permitted by the role.
- Manual student spreadsheet pull/push and CSV fallback import within the active branch.

### 4.3 Principal-only Finance

The Coordinator must not see, navigate to, query, or mutate the Fees feature.

- Fee categories, structures, installments, academic-year setup, and payment configuration.
- Student fee ledger, invoices, balances, concessions, reminders, receipts, and reports.
- Cash/offline payment recording and payment history.
- Parent payment proofs and payment-request review/decision.
- Private finance documents and signed document access.

Financial history is immutable. A correction or reversal must be an auditable, atomic operation; physical deletion of payments, receipts, or finance snapshots is not an acceptable product workflow.

### 4.4 Teacher mobile portal

- Teacher dashboard.
- Assigned classes and class roster.
- Teacher timetable and academic calendar.
- Student attendance, attendance history, and personal staff attendance.
- Teacher documents.
- Communication, parent interaction, complaints, and event posts.
- Leave balance, leave request, and leave status.
- Homework creation, editing, assignment, attachments, submissions, and feedback.
- Teacher lesson planner.

### 4.5 Parent mobile portal

- Parent dashboard and linked-child selection.
- Child attendance and attendance history.
- Homework, submission, attachments, feedback visibility, and lesson planner.
- Health updates and health reminders.
- Teacher chat, communications, complaints, PTM availability, and PTM booking.
- Fees, invoice/balance visibility, payment request, payment proof, payment history, receipt, and payment status.
- Student leave request and status.
- Academic calendar, events, documents, and child timetable.

### 4.6 Super Admin and kiosk

Super Admin mobile workflows include platform dashboard, school management, access and permissions, audit logs, system monitor, issues, error-event retention, and supported recovery/maintenance operations.

Kiosk workflows include kiosk sign-in and QR-based attendance capture. Kiosk secrets must be configured through deployment secrets and must fail closed when missing; development fallback secrets must never be accepted in production.

## 5. Web application scope

### 5.1 Public website

The public website is part of this PRD and includes the school’s public-facing content and lead-generation experience:

- Home/landing.
- About, mission, programs, and campus/safety information.
- Admissions information and admission inquiries.
- Gallery and media.
- News, events, and public posts/ticker content.
- Contact and enquiry submission.

Public content must distinguish school-wide content from branch-scoped content. Principal manages content for the selected branch; Coordinator manages content for the assigned branch. Public enquiry submissions must be protected from unauthenticated data modification and must enter the operational admission workflow.

### 5.2 Leadership portal

The web portal supports only Principal and Coordinator. Both use the same limited module set:

- Overview.
- Students.
- Parents.
- Teachers.
- Classes & Subjects.
- Timetables.
- Reports.
- Admission Inquiries.
- Public Website.

Principal additionally sees Fees. Coordinator does not see Fees anywhere in navigation, direct routes, dashboard actions, reports, or API responses.

The web portal provides branch selection to Principal and a fixed assigned-branch context to Coordinator. It must provide visible feedback when branch loading, switching, or backend requests fail.

### 5.3 Deliberate web exclusions

Teacher and Parent web portals, web attendance, web communications/chat, web homework, web leave, web health, web PTM, and full mobile-feature parity are not current-scope requirements. They belong in the future roadmap unless explicitly promoted later.

## 6. Core workflows

### 6.1 Authentication and session

- Authenticate against Supabase through the active Edge API.
- Resolve role and branch membership from server-controlled data.
- Route the user to the correct dashboard after login.
- Reject inactive users, invalid memberships, expired sessions, and unauthorized role/branch requests.
- Provide visible recovery for failed profile, branch, and dashboard requests.

### 6.2 Student lifecycle

- Create, view, update, search, filter, and manage student records.
- Link parents and guardians through explicit relationships, never name-based guessing.
- Manage class/section placement, status, documents, photos, and admission information.
- Normalize status values consistently across Flutter, web, API, database, imports, and reports.
- Exclude QA/test accounts from operational totals unless an authorized diagnostic explicitly opts in.

### 6.3 Academics and timetable

The timetable is class-first. A class teacher is shown once for the selected class; period editing covers subject, time, room, and slot type. Teaching, break, and free slots are supported. Break/free slots do not require a subject. Manual changes require preview before publish. Copy Day requires target selection and confirmation. Exports remain available from the class workflow.

### 6.4 Attendance

- Principal/Coordinator oversee branch attendance, corrections, reopen actions, reminders, history, audit, and exports.
- Teachers mark attendance only for permitted classes and sessions.
- Parents view only linked-child attendance.
- Kiosk QR attendance is a separate restricted workflow.
- Attendance mutation and correction events must be auditable.

### 6.5 Communications and notifications

Communications, chat, announcements, complaints, PTM, diary, lesson planners, event posts, and notification preferences are mobile-first in the current scope. In-app and push notification behavior must respect role, branch, class, parent-child, and conversation membership. Email, WhatsApp, and other external channels are future scope unless separately approved.

### 6.6 Finance

Principal is the sole school finance operator. Parent payment requests and proofs flow to Principal review. Fee balances are calculated from authoritative invoices and finalized payments. Payment recording must be idempotent, atomic, auditable, and secure. Finance documents are private and served through authorized signed URLs.

## 7. Manual student spreadsheet exchange

Google Sheets is a controlled fallback/import-export tool for **Students only**. It is not a second system of record and is not an automatic integration in the current scope.

### Required sequence

1. Select exactly one active branch.
2. Pull the latest student data from SchoolDesk for that branch into the sheet.
3. Edit the sheet using the supported template and identifiers.
4. Push the edited sheet back to SchoolDesk.
5. The server validates the branch, student identifiers, baseline version, required fields, and relationships.
6. Successful rows are created or updated; rejected rows remain available with actionable errors.

### Safety rules

- SchoolDesk wins conflicts.
- A push must include the baseline captured by the preceding pull, such as backend update timestamp or equivalent version/fingerprint.
- If SchoolDesk changed a row after the pull, the push must not overwrite it; return a stale-conflict result for manual review.
- Never delete a student automatically because a row is missing or blank in the sheet.
- Use explicit student and branch identifiers; do not resolve a class or section from an ambiguous section name alone.
- Process one branch per operation.
- Provide preview/validation, row-level results, retryable failures, import/export history, and an audit record.
- Parent/guardian fields may be included only as supporting data for the student workflow; Parents are not a separate synced entity.
- No automatic cron, webhook, background polling, or unattended push/pull is current scope.

Existing service-authenticated Sheets endpoints are implementation details that must be brought into this manual pull-first contract before being presented as production functionality.

## 8. Data, security, and privacy requirements

- Enforce role and branch authorization in Edge Functions and database policies; never trust a role or branch supplied only by query string, path, or client state.
- Never ship service-role keys, webhook secrets, QR secrets, Google private keys, or password defaults in Flutter, web bundles, migrations, or source fallbacks.
- Rotate any privileged credential that has appeared in source or migration history before production use.
- Keep student, staff, parent, payment-proof, finance, and school documents private unless the specific asset is intentionally public.
- Use signed, time-limited URLs for private documents.
- Review SECURITY DEFINER functions, execute grants, fixed search paths, storage policies, RLS policies, and public bucket listing.
- Record security-sensitive actions, finance operations, branch changes, imports, exports, approvals, and account changes in audit logs.
- Do not expose password values in logs, exports, notifications, or browser storage.
- Enable leaked-password protection and maintain secure authentication policy.

## 9. UX and accessibility requirements

- Dashboard is the first authenticated screen.
- Navigation is role- and branch-scoped.
- Mobile layouts work on small Android phones, tablets, and supported iOS sizes.
- Web layouts work at desktop and narrow responsive widths without hiding actions or data.
- Forms provide labels, validation, focus visibility, keyboard access, and clear success/error feedback.
- Tables provide search, filters, empty states, loading skeletons, and recoverable errors.
- Destructive or irreversible actions require confirmation and explain consequences.
- Complex workflows use a full-screen or clearly scoped surface.
- Visual QA must use current rendered mobile and web evidence; source inspection alone cannot certify visual quality.

## 10. Current scope versus future scope

### Current scope

- Complete existing Flutter mobile role inventory.
- Principal and Coordinator leadership operations.
- Principal-only Fees.
- One-school, multi-branch operation with one active branch at a time.
- Limited Principal/Coordinator web portal.
- Public website and admission enquiries.
- Manual, pull-first, student-only Google Sheets exchange.
- CSV fallback import where already implemented.
- Backend-backed security, branch isolation, auditability, and visible failure states.

### Future scope

- Web portals for Teacher and Parent.
- Web attendance, communications, homework, leave, health, PTM, and full mobile parity.
- Automatic or scheduled Google Sheets synchronization.
- Two-way automatic conflict resolution beyond the manual pull-first workflow.
- Multi-school tenancy.
- Cross-branch aggregate dashboards and reports.
- Email, WhatsApp, and other external communication channels.

## 11. Known issues and release gates from the current audit

These are not hidden by the PRD and must be tracked separately from feature scope:

1. A hardcoded privileged fallback token remains in the Sheets route authorization and must be removed, rotated, and checked in repository history.
2. Dashboard authorization must reject a lower-privileged user requesting another role’s dashboard path and must return only the authenticated role’s permitted fields.
3. The linked Supabase project has security-advisor warnings involving executable SECURITY DEFINER wrappers, mutable search paths, public storage listing, disabled leaked-password protection, RLS initialization plans, permissive-policy overlap, and a duplicate index. Each warning needs a disposition and evidence.
4. The public `school-assets` bucket is used by student documents, avatars, exports, and other assets; private records must be moved behind private storage and signed access.
5. Shared mobile role-access loading currently risks collapsing backend failures into empty data; failure and empty states must remain distinguishable and retryable.
6. Web branch-switch failure must show an actionable error instead of silently returning to the previous state.
7. The current integration suites contain manual/TODO stubs. Static checks do not prove real login, branch isolation, role handoffs, CRUD, payment, import, or device workflows.
8. The current worktree contains a payment-delete path that physically deletes payment-related rows through separate operations. This conflicts with the immutable-financial-history requirement and must become an audited atomic reversal or be removed.
9. A current browser/device walkthrough or screenshot set is still required for final responsive, accessibility, and visual QA sign-off.

## 12. Acceptance criteria

### Functional

- Principal can select each branch and operate only within the selected branch.
- Coordinator is restricted to the assigned branch and cannot access Fees.
- Teacher and Parent can access only their permitted mobile workflows and linked data.
- Principal-only finance paths reject Coordinator, Teacher, Parent, and unauthenticated requests.
- Student, parent, staff, class, timetable, attendance, admission, website, and report workflows use live backend data.
- Spreadsheet pull-first, stale-conflict, no-delete, one-branch, preview, and row-result behavior is proven.

### Security and data

- No privileged secrets or predictable production fallbacks remain in source or client artifacts.
- Role spoofing, branch spoofing, cross-branch reads/writes, public document access, and unauthorized RPC execution are denied.
- Storage, RLS, function grants, search paths, and authentication settings have passing reviewed evidence.
- Finance operations preserve immutable history and produce auditable reversals.

### Verification

- `flutter analyze --no-pub` passes.
- `deno check supabase/functions/api/index.ts` and all touched Deno tests/checks pass.
- `bun run typecheck` and `bun test` pass for the web portal.
- Flutter tests run serially where required by the workspace.
- Supabase migration lint passes and advisor findings are dispositioned.
- Live smoke tests cover Principal, Coordinator, Teacher, Parent, Kiosk, mobile, web, branch switching, Fees restrictions, website editing, admissions, and manual student spreadsheet exchange.
- Current rendered screenshots or device walkthrough evidence is attached for responsive and accessibility review.

## 13. Source-of-truth implementation locations

- Flutter application: `lib/`
- Flutter route inventory: `lib/routes/schooldesk_screen_registry.dart`
- Flutter API facade: `lib/core/network/`
- Web application: `schooldesk-web/`
- Supabase Edge API: `supabase/functions/api/`
- Supabase schema and policies: `supabase/migrations/`
- Automated and integration verification: `test/`, `integration_test/`, and `schooldesk-web/tests/`

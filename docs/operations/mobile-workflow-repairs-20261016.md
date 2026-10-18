# Mobile workflow repairs — 16 October 2026

The delivery covers the thirteen reported items and the additional teacher attendance request. Existing website work and the scoped attendance-reopening changes are preserved.

| Request | Implementation |
| --- | --- |
| 1. Dark mode | Themed parent background, cards and text; gallery menus and surfaces; shared leadership cards and navigation surfaces. |
| 2. Gallery visibility | Separate Manage visibility action; independent Parent Home, Teacher Home, School Gallery and Public Landing destinations; public media rules remain enforced. |
| 3. Settings destination | Bottom Profile action replaced with Settings; account editing accessible inside Settings. |
| 4. Password wording | Account-security wording without VPS terminology. |
| 5. Sidebar duplicates | Removed personal Profile and Notifications from role drawer footers; retained School Profile and notification bell access. |
| 6. Optional profile details | Blank descriptive fields accepted and hidden in view mode; supplied values retain format validation; internal identity/regional defaults preserved. |
| 7. School name | Optional school-facing display_name; ArishVille PreSchool configured for the affected production school separately from organization/branch identities. |
| 8. Parent issues | Parent/coordinator reporter constraint fixed; nested pagination and list refresh fixed; saved ticket identifier; transactional Super Admin inbox/outbox and resolution updates. |
| 9. Co-teacher diary reviews | Assigned co-teachers can review; saved feedback and Submitted status preserved; refresh on resume/return/invalidation; transactional parent inbox/outbox. |
| 10. Birthday highlights | Date-based highlights independent of inbox pages; assigned-class scope for teachers/co-teachers and school scope for leadership. |
| 11. Notification subjects | Shared recipient scope for list/count/read; refresh on entry and inbox updates; explicit item/bulk read behavior; foreground refresh independent of toast support. |
| 12. Parent attendance | Authoritative school-day attendance DTO and status on mobile/desktop; unsubmitted drafts distinguished; legacy percentage aggregated in PostgreSQL. |
| 13. Health reminders | Transactional principal/coordinator/class-team inbox/outbox; school-date highlights; parent and teacher read isolation; withdrawals cancel pending alerts. |
| Additional attendance | Current-academic-year date selection through today; date-aware roster without REST pagination truncation; saved-register membership preserved; finalized registers require leadership reopening; unsaved changes protected. |

## Code-level evidence

- Complete synthetic Docker migration replay completed.
- Local workflow script passed issue creation/resolution, principal health delivery, birthday/health highlights beyond the first inbox page, distinct co-teacher review and parent retrieval, a roster over 120 students, attendance more than 30 days back, date bounds, finalization, and forced outbox-failure rollback.
- Existing attendance-reopening script passed transferred-student correction, rollback, authorization and preserved-history checks.
- Nine new/updated paging, API parsing and parent-dashboard widget tests passed.
- Eleven profile, attendance-reopening, teacher-diary and teacher-dashboard widget tests passed.
- Flutter analyzer and Deno checks were run. The final handoff reports the resulting status.

The user requested code-level verification and will perform device acceptance. No Android device interaction or actual phone push-delivery result is claimed.

## Deployment and recovery

Only the fifteen backend files in the deployment manifest and the two new forward SQL migrations belong to this repair deployment. The production target is the existing self-hosted Functions mount, not the retired managed project. Database and complete Functions backups were captured before promotion. Backend files are hash-verified after copying.

Host systemd timers process pending notifications every two minutes, run birthday windows at 09:00 and 15:00 Asia/Kolkata, and run the scheduled health reminder job at 16:00. New persistent timer timestamps avoid replaying missed windows at installation. Historical inbox reconciliation does not enqueue historical pushes; the worker skips obsolete birthday/health alerts.

For rollback, stop the four `schooldesk-notification-*.timer` units and restore the prior Functions tree from the captured archive. The additive database migration can remain for an application rollback. Disable the new workflow triggers only as part of a reviewed rollback because they provide durable inbox/outbox persistence. The database dump is the full recovery checkpoint, not a routine rollback command.

Production deployment evidence and the APK build log are in the private, ignored `.local/repair-evidence/` directory. Backups contain private data and must not be committed or shared with the APK.

The follow-up migration `20261016174305_attendance_roster_saved_membership.sql` guarantees one roster row per student, preserves saved enrollment references, and uses dated enrollment when an older saved mark has no enrollment reference. The local workflow regression also verifies this case. Both migrations and all fifteen backend files are deployed. Notification jobs use the private Docker gateway to avoid external proxy restrictions.

Final checks: Flutter analysis reports no issues; the final Deno handler check passes. All fifteen deployed Functions files match source hashes, authenticated production reads pass for all five roles, all four notification timers are active, and the processor service reports success. The local migration history includes both repair migrations.

Signed production APK: `artifacts/android/SchoolDesk-1.0.32+45-repairs.apk` (version 1.0.32+45). Signature verification passes and the certificate matches the previous release. Package identity, version, and embedded production API hostname are verified. SHA-256: `d13537c614bdd2b53304f832b803e19490e1856e4608212e5bdf76199083633c`. No device execution or real push-delivery acceptance is claimed.

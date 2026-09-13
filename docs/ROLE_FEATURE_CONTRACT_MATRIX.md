# SchoolDesk role and workflow contract matrix

This matrix records the code-level integration boundary for the paging and
workflow pass. It is a contract map, not a claim of live-backend or device
delivery verification.

| Role | Allowed core surfaces | Explicit restrictions | Code-level enforcement |
| --- | --- | --- | --- |
| Principal | Branch, people, attendance, academics, fees, approvals, reports, communications, audit, push | Must stay inside the selected school/branch | Server school scope, branch-sensitive cache invalidation, dashboard aggregates, unified approval feed |
| Coordinator | One-branch operations, people, attendance, academics, leave, communications, approvals | No fees, fee reports, payment approvals, or branch switching | Coordinator bootstrap omits fee requests; fee routes and dashboard RPCs remain principal/finance-leader scoped |
| Teacher | Assigned sections/subjects, attendance, homework, diary, lesson planning, leave, communications, event submission | No unrelated class/student data; no finance administration | Teacher scope resolves assigned class/co-teacher/subject relationships in backend queries |
| Co-Teacher | Shared assigned-class student access, attendance, homework, diary, communications | Same class/subject scope as assignment; no inherited school-wide access | `resolveActiveTeacherScope` and section/subject checks are used before list and mutation paths |
| Parent | Linked children, attendance, homework, fees, payment proof, receipts, leave, documents, chat, child-scoped notifications | No access to another child or school-wide records | Parent-child links are checked server-side for list, detail, mutation, notification, and chat routes |
| Kiosk | QR attendance flow | No directory, fees, reports, communications, or administration | Kiosk token validation and route-level authorization remain isolated from school operations |
| Super Admin | Platform/system monitoring, issues, audit, system administration | Must not accidentally inherit school operational workflows | Super-admin routing is explicit; school-level handlers still require school scope and role checks |

## Cross-role event contracts

The following event chains have backend producers, durable in-app log rows, and
push-event creation paths. Each producer carries a route/reference identifier
and is deduplicated or guarded by the relevant workflow mutation.

| Workflow | Source | Recipient/decision boundary |
| --- | --- | --- |
| Homework assignment/submission/feedback | Homework handler | Linked parent or assigned teacher |
| Event post | Teacher submission | Principal/coordinator approval, then school feed |
| Student leave | Parent submission | Principal/coordinator decision, then linked parent |
| Payment proof | Parent submission | Principal/finance decision, then receipt and parent |
| Complaint/issue | Parent or teacher issue | Leadership/super-admin escalation |
| Admission inquiry | Public inquiry | Correct school leadership queue |
| Health/birthday/attendance alert | Scheduled or attendance producer | Linked parent and assigned teacher where applicable |
| Chat/message | Conversation mutation | Other authorized participant |

## Verification boundary

Static Dart analysis, focused contract tests, changed-handler checks, and SQL
static inspection are in scope for this pass. Docker boot, live Supabase data,
hosted migrations, physical-device FCM delivery, and production role-session
acceptance remain explicit follow-up gates.

# SchoolDesk FastAPI Testing Checklist

## Automated Backend Tests

- Principal login and permissions.
- Unknown/unimplemented routes return FastAPI `404`; there is no Go gateway fallback.
- Principal creates, activates, updates, archives goals.
- Principal creates goal-linked and standalone tasks.
- Assigned Teacher and Class Teacher can see and update scoped tasks.
- Unrelated Teacher cannot see scoped tasks.
- Parent/Guardian cannot access task endpoints.
- Progress, evidence URL, blocker note, checklist, comments, complete, reopen, and archive flows.
- Audit logs are written for important actions.
- Notification logs are created for task assignments.
- Task completion does not create approval requests or auto-apply sensitive actions.
- Local Flutter first-screen compatibility endpoints return backend empty states without mock rows.
- School catalog endpoints return seeded structural rows from DB tables.
- Principal can update school profile, create rooms, create staff login accounts, create/update/delete students, and read student enrollments.
- Admin can create and submit approval requests; Parent/Guardian is denied; Principal can request changes, approve, reject, and mark approved requests as applied.
- Approval detail, PATCH compatibility, wrong-school denial, required reject reason, required change-request note, and repeat-apply rejection are covered.
- Applying an approval request does not auto-create sensitive class/student/fee records without a module-specific applicator.
- Leave compatibility endpoints are DB-backed: staff leave list/types/balances, Teacher self-submit, Principal-only staff leave decision, Parent student-leave submit, Principal-only student-leave decision, reject-reason requirement, and duplicate decision rejection.

## Runtime Verification

- Stop the Go API service before FastAPI smoke verification.
- Confirm `GET http://127.0.0.1:8090/health` returns FastAPI health.
- Confirm `GET http://127.0.0.1:8090/api/v1/docs` opens FastAPI docs.
- Confirm `GET http://127.0.0.1:8090/api/v1/unported-module` returns `404`.
- Confirm authenticated `GET /api/v1/leave/applications` and `GET /api/v1/student-leave/applications` return backend data/empty states without UI fallback rows.
- Rendered Flutter web smoke passes for Principal, Admin, Teacher, and Parent with zero bad `/api/` responses.

## Future Flutter Tests

- Route guards for Principal/Admin/Teacher task screens.
- Principal create/assign flow.
- My Tasks progress update.
- Empty/loading/error states.
- No overflow at 360x640, 393x873, 412x915, 375x667, 390x844, 430x932, and 768x1024.

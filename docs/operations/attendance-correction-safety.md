# Attendance correction safety

The student-detail actions must use the student's attendance record for the
selected date, never the first school-wide attendance session. Records retain
their original class after transfers. Fetch each matching session by ID so
pagination cannot hide the correct register; require a choice for multiple
registers and show an unavailable state when no record exists.

Reopen requests send `section_id`, `date`, `reason`, and, when opened from a
student detail, `student_id`. The API validates these against the selected
session. The service-only `reopen_attendance_session_scoped` database function
checks the active school leadership actor, school boundaries, and historical
student membership. It reopens the session and its exact academic-year daily
claim in one transaction. Correction history is retained on the session in
`reopen_history`; this does not restore the retired general audit-log product.
An already reopened session retains its original actor, reason and timestamp
when retried.

## Existing app versions

Reason-only reopen requests are rejected with HTTP 409 and an explanation to
update SchoolDesk or contact the school administrator. This deliberately
blocks all context-free reopen requests, including those from otherwise correct
class menus, because the server cannot infer the intended student/class from
an unrelated session ID. Listing, teacher marking, and correction requests keep
their existing contracts. Reopening a verified register through authorized
support lets its teacher submit corrections using the existing app.

The wrong menu on an installed old app still requires a client update. Do not
reorder global session responses, rename classes, or change teacher assignments
to disguise the client bug. The current reminder menu is disabled because its
previous callback only displayed a success message without queueing delivery.
Class-register exports use the selected session's class, date and saved marks.

## Validation

Use only the synthetic local project:

```sh
scripts/local_supabase.sh reset
scripts/local_supabase.sh functions
# In a separate terminal:
python3 scripts/local_attendance_reopen_smoke.py
flutter test --no-pub test/widget/principal_attendance_reopen_test.dart
```

The smoke checks reject legacy requests, mismatched class/date/student,
cross-school access, teacher reopens, malformed inputs, and nonexistent sessions
without mutations. It also checks rollback on claim failure, retry semantics,
historical records after transfers, RPC grants, and correction submission through
the unchanged teacher marking endpoint. Temporary fixtures and failure triggers
are removed afterwards.

## VPS promotion and support repairs

Back up the live database and original handler to protected storage. Compare
the live handler with the source version used to create the patch; stop if it
has changed. Apply only `20261010163911_scoped_attendance_reopen.sql`, in a
transaction, to the verified self-hosted database. This is separate from the
managed Supabase CLI promotion workflow; do not link or push to the former
managed project. Verify RPC grants and schema-cache reload before replacing
the handler and restarting the self-hosted functions container. Check live
health and rejection behavior afterwards.

For an authorized one-time support reopen, lock the exact session and daily
claim, assert school/class/date/status and the previously observed modification
timestamps, preserve all student marks, and update both rows atomically.
Retain the support reason and previous state in `reopen_history`. Mark support
execution explicitly rather than attributing it to a school user's login.
Compare the school's sessions, claims and student marks before/after. Do not
reverse an unrelated class reopen unless its intent has been established.

Rollback retains the added column and function so correction history is not
lost. Preserve the handler backup for emergencies, but restoring the old handler
also restores the unsafe legacy reopen behavior. Do not restore the full database
over subsequent attendance submissions to undo a single reopen; use an exact,
reviewed compensating transaction instead.

Phone verification and Play Store publication are separate delivery gates. A
backend deployment cannot change a menu in an already installed Flutter build.

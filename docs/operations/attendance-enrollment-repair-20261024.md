# Attendance enrollment repair — 24 October 2026

## Cause and live repair

Miyapur's active student assignments existed in `students.current_section_id`,
but their dated `enrollments` rows were absent. The attendance roster uses dated
membership, with saved marks preserving membership only on an already recorded
day. A class could therefore have students in the directory and return an empty
roster on a new date. Account authorization was working.

A reviewed, guarded transaction created **63** real-student memberships and
deactivated one explicitly approved duplicate test student. It retained the real
duplicate-name student and left the unassigned student untouched, as requested.
The exact pupil manifest and support decisions are private incident evidence.

Current Miyapur rosters verified through the real teacher/co-teacher identities:

| Class | Students |
| --- | ---: |
| LKG A | 12 |
| Nursery A | 15 |
| Nursery B | 18 |
| Play Group A | 17 |
| Day Care A | 1 |

The confirmed Nursery B transfer has membership effective on the repair date;
the precise historical transfer date was not supplied. Its 23 saved Nursery A
records remain readable by the new class teacher and co-teacher. Earlier class
changes with dated current-class evidence use that evidence, without relabelling
old registers. Existing pre-admission date anomalies were preserved.

## Transfers, promotions and history

`20261024102635_student_assignment_enrollment_continuity.sql` updates the existing
student trigger. Active changes to another section, including a new current
academic year's section, create dated membership in the same transaction.
Earlier enrollment rows remain intact. Retried ordinary saves do not duplicate
membership or silently infer missing legacy history. Invalid school/year scope,
future-dated membership and ambiguous latest membership abort the assignment.
Enrollment failures roll back the student change too.

The student's ID remains stable through a transfer or promotion. Both student
attendance history routes authorize the current teacher against that student,
then return school-scoped history across original classes and academic years.
They include original class/year labels, fetch every database page, and filter
monthly requests by the actual register date. A failed page is an error rather
than partial success. They do not expose an entire former class to the new
teacher or let a former teacher read a student's private current history.

The Android update adds **My Classes → Attendance history** on each student.
Past registers keep their original class/date; new marking uses the student's
new class from its effective date. Do not move old marks into another class's
sessions, duplicate marks, or rewrite completed class totals.

## Validation and recovery

- Pinned Supabase CLI 2.116.0: complete synthetic local migration/seed replay and
  grant sanity check passed. No managed-project link, history repair or hosted
  `db push` was used.
- Local SQL and API checks passed admission boundaries, duplicate/changed-row
  repair guards, transactional rollback, same-day transfers, reactivation,
  promotion, teacher/co-teacher marking, claims, finalization and foreign scope.
- Eight Deno tests passed history pagination, date bounds, incomplete-page
  failure and school-calendar behavior; API type checking passed.
- Twelve Flutter tests passed history labels, retry/empty/loading states,
  student-switch races, enlarged text, current roster recovery and dirty marks.
  Full Flutter analysis passed.
- Production authenticated GET checks passed all 11 real assignment contexts
  across Miyapur and Madhapur, including the transferred student's full history
  and cross-class/cross-school denials. No production attendance was marked,
  submitted, reopened, moved or deleted for testing.
- Before/after hashes preserved existing attendance, claims, finance, school
  settings, assignments and prior enrollments. All other students were unchanged.

Run the read-only diagnostic after an import or when class lists disagree:

```sh
psql -v school_id='<school UUID>' -f scripts/student_enrollment_integrity.sql
```

After this repair it reports 63 healthy assigned real students, no active test
accounts, and only the explicitly untouched unassigned pupil. This is a manual
diagnostic; no recurring job was added.

Protected evidence is under `.local/attendance-enrollment-20261024/` and
`/data/schooldesk/repairs/20261024-attendance-enrollment/` on the VPS. It includes
two readable database backups, exact reviewed manifests, row snapshots,
pre/post hashes, source backups and authenticated check logs. Do not publish it.

For a history-handler rollback restore the two backed-up handlers, retain the
additive membership repair, and restart only the SchoolDesk Functions container.
The previous trigger definition is also backed up, but restoring it reintroduces
the class-change membership gap. Never restore the whole database over later
attendance or delete repaired memberships after real marks start using them.
Phone appearance and interaction require separate device verification.

## Android handoff

Verified release APK: `artifacts/android/SchoolDesk-1.0.37+50-attendance/SchoolDesk-1.0.37+50-attendance.apk`.
Embedded package `com.techmigos.schooldesk1`, versionName `1.0.37`, versionCode
`50`, 146,162,556 bytes. SHA-256:
`6b3b87aa7556c04040bda8f8c4d96ed6daf55cebf54d06e11d91ea1ed635c079`.

Release signature and the existing certificate, archive integrity, 16 KB ZIP
alignment, production VPS endpoint, three stripped native libraries and all 582
frozen source files passed verification. R8 mapping and Dart symbols are retained
with the versioned artifact. No Play Store publication or phone test was done.

# SchoolDesk Step 2 Completion And Step 3 Database Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish canonical RBAC and relationship policy, then add safe database integrity constraints for SchoolDesk's local Docker Go/Postgres backend.

**Architecture:** Keep the existing Flutter `BackendApiClient`, Go API, GORM models, route names, IDs, and payload contracts stable. Centralize role relationship checks in backend policy helpers first, then add database constraints only after API behavior and seed data prove the relationships are clean.

**Tech Stack:** Flutter frontend, Go Gin API, GORM, Postgres in Docker, Redis sessions, SQLite-backed Go API suite for regression tests.

---

## Current State

Step 1 inventory exists at `docs/backend-step1-role-module-linkage-inventory.md`.

Step 2 implementation is partially complete:

- Added shared relationship policy helpers in `school-backend/internal/handlers/policy.go`.
- Added focused relationship tests in `school-backend/internal/handlers/relationship_policy_test.go`.
- Targeted handler tests pass:

```bash
cd school-backend
go test ./internal/handlers -run 'TestParentStudentLinkListIsScopedToAuthenticatedParent|TestTeacherStudentListIsScopedToAssignedSections|TestTeacherCannotCreateAttendanceSessionForUnassignedSection|TestAttendanceMarkRejectsStudentOutsideSessionSection|TestParentHomeworkAndDiaryListsAreScopedToLinkedStudents|TestParentMessagingAndPTMAreParticipantScoped' -count=1
```

Expected:

```text
ok  	school-backend/internal/handlers
```

Full API suite is not green yet:

```bash
cd school-backend
go test ./...
```

Current failing cases:

```text
Teacher blocked from outside class fees: got 200, expected 403
Teacher blocked from outside class attendance: got 200, expected 403
Teacher blocked from outside class marks: got 200, expected 403
Teacher blocked from outside class transport: got 200, expected 403
```

The next step is to finish Step 2 before Step 3. Database constraints should not be added while app-level ownership rules still leak through compatibility routes.

## Files

- Modify: `school-backend/internal/handlers/policy.go`
- Modify: `school-backend/internal/handlers/student.go`
- Modify: `school-backend/internal/handlers/compat.go`
- Modify: `school-backend/internal/handlers/relationship_policy_test.go`
- Modify: `school-backend/tests/api_suite_test.go` only if a missing regression case is discovered
- Create: `docs/backend-step2-rbac-relationship-policy.md`
- Create later: `school-backend/internal/database/constraints.go`
- Create later: `school-backend/internal/database/constraints_test.go`
- Modify later: `school-backend/internal/database/database.go`

## Task 1: Finish Teacher Subresource Denial

**Files:**
- Modify: `school-backend/internal/handlers/relationship_policy_test.go`
- Modify: `school-backend/internal/handlers/student.go`
- Modify: `school-backend/internal/handlers/compat.go`
- Modify: `school-backend/internal/handlers/policy.go`

- [ ] **Step 1: Add a focused failing regression test**

Add a test that proves a teacher cannot read outside-section student subresources through both direct and compatibility handlers.

```go
func TestTeacherStudentSubresourcesRejectOutsideSection(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	studentHandler := NewStudentHandler()
	compatHandler := NewCompatibilityHandler()

	router.GET("/students/:id/attendance", studentHandler.GetStudentAttendance)
	router.GET("/students/:id/fees", studentHandler.GetStudentFees)
	router.GET("/students/:id/marks", studentHandler.GetStudentMarks)
	router.GET("/students/:id/transport", studentHandler.GetStudentTransport)
	router.GET("/compat/students/:id/marks", compatHandler.GetStudentGrades)

	for _, tc := range []struct {
		name string
		path string
	}{
		{"attendance", "/students/" + f.otherStudentID + "/attendance"},
		{"fees", "/students/" + f.otherStudentID + "/fees"},
		{"marks", "/students/" + f.otherStudentID + "/marks"},
		{"transport", "/students/" + f.otherStudentID + "/transport"},
		{"compat marks", "/compat/students/" + f.otherStudentID + "/marks"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			response := httptest.NewRecorder()
			router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, tc.path, nil))
			if response.Code != http.StatusForbidden {
				t.Fatalf("status=%d body=%s", response.Code, response.Body.String())
			}
		})
	}
}
```

- [ ] **Step 2: Run the focused test and confirm it fails**

```bash
cd school-backend
go test ./internal/handlers -run TestTeacherStudentSubresourcesRejectOutsideSection -count=1
```

Expected before the fix:

```text
FAIL
```

- [ ] **Step 3: Route every student subresource through `canAccessStudent`**

In `student.go`, keep the existing access check as the first branch in:

```go
GetStudentAttendance
GetStudentFees
GetStudentMarks
GetStudentTransport
```

In `compat.go`, add the same check to compatibility student data aliases before querying grades, attendance, or fees:

```go
if !canAccessStudent(c, studentID) {
	fail(c, http.StatusForbidden, "student access denied")
	return
}
```

Do this before any query returns an empty data list, because an empty 200 still leaks that the request path was allowed.

- [ ] **Step 4: Fix teacher section logic only in the shared policy helper**

Keep teacher access limited to sections they own as class teacher or timetable teacher:

```go
func teacherSectionSubquery(staffID, schoolID string) *gorm.DB {
	return database.DB.Model(&models.Section{}).
		Select("sections.id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ?", schoolID).
		Where(`
			sections.class_teacher_id = ?
			OR EXISTS (
				SELECT 1 FROM timetable_slots
				WHERE timetable_slots.section_id = sections.id
					AND timetable_slots.staff_id = ?
			)
		`, staffID, staffID)
}
```

Do not grant student read access from grade-level `staff_subjects`; that is too broad for fees, transport, marks, attendance, and parent-visible records.

- [ ] **Step 5: Verify targeted policy tests**

```bash
cd school-backend
go test ./internal/handlers -run 'TestTeacherStudentSubresourcesRejectOutsideSection|TestTeacherStudentListIsScopedToAssignedSections|TestParentHomeworkAndDiaryListsAreScopedToLinkedStudents|TestParentMessagingAndPTMAreParticipantScoped' -count=1
```

Expected:

```text
ok  	school-backend/internal/handlers
```

- [ ] **Step 6: Verify full backend suite**

```bash
cd school-backend
go test ./...
```

Expected:

```text
ok  	school-backend/tests
```

## Task 2: Document Canonical RBAC And Relationship Policy

**Files:**
- Create: `docs/backend-step2-rbac-relationship-policy.md`
- Modify: `docs/role-feature-backend-call-matrix.md`
- Modify: `docs/role-module-test-cases.md`

- [ ] **Step 1: Create Step 2 status doc**

Document the canonical role policy:

| Role | Allowed ownership |
| --- | --- |
| Principal | Oversight, approvals, analytics, audit logs, academic supervision. No default CRUD ownership for Admin operational modules. |
| School Admin | Operational CRUD for students, staff, classes, timetable, syllabus, exams, fees, documents, parent linking. |
| Teacher | Assigned sections, subjects, timetable slots, attendance sessions, homework, diary, marks entry, parent communication. |
| Parent | Linked students only: attendance, fees, homework, diary, marks, documents, notifications, PTM/messages. |

Record implemented Step 2 checks:

```text
parent_student_links parent-scoped
teacher student list/detail scoped
student update school-scoped
enrollment school validation and current_section sync
attendance session list/create/mark ownership validation
homework and diary parent/teacher scope
conversation, message, and PTM participant scope
student subresource denial for outside teacher/parent access
```

- [ ] **Step 2: Update existing QA docs**

Add a short Step 2 status section to:

```text
docs/role-feature-backend-call-matrix.md
docs/role-module-test-cases.md
```

The update must say whether `go test ./...` passed and list any still-manual verification gaps.

## Task 3: Prepare Database Constraint Pass

**Files:**
- Create: `school-backend/internal/database/constraints.go`
- Create: `school-backend/internal/database/constraints_test.go`
- Modify: `school-backend/internal/database/database.go`

- [x] **Step 1: Write SQL idempotency tests first**

Create `constraints_test.go` with tests that assert generated SQL contains:

```text
ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY
CREATE UNIQUE INDEX IF NOT EXISTS
DO $$ BEGIN ... EXCEPTION WHEN duplicate_object THEN NULL; END $$;
```

Minimum constraints to cover:

```text
students.school_id -> schools.id
students.current_section_id -> sections.id
guardians.student_id -> students.id
medical_records.student_id -> students.id
student_documents.student_id -> students.id
enrollments.student_id -> students.id
enrollments.section_id -> sections.id
enrollments.academic_year_id -> academic_years.id
parent_student_links.parent_user_id -> users.id
parent_student_links.student_id -> students.id
attendance_sessions.section_id -> sections.id
attendance_sessions.subject_id -> subjects.id
attendance_sessions.staff_id -> staff.id
student_attendances.session_id -> attendance_sessions.id
student_attendances.student_id -> students.id
student_attendances.enrollment_id -> enrollments.id
fee_invoices.student_id -> students.id
fee_invoices.academic_year_id -> academic_years.id
payments.invoice_id -> fee_invoices.id
```

- [x] **Step 2: Add data cleanup probes before enabling constraints**

Add functions that count unsafe rows before constraint installation:

```go
func integrityProbeQueries() map[string]string {
	return map[string]string{
		"student_current_section_school_mismatch": `
			SELECT COUNT(*)
			FROM students
			JOIN sections ON sections.id = students.current_section_id
			JOIN grades ON grades.id = sections.grade_id
			WHERE students.school_id <> grades.school_id
		`,
		"parent_student_link_cross_school": `
			SELECT COUNT(*)
			FROM parent_student_links
			JOIN users ON users.id = parent_student_links.parent_user_id
			JOIN students ON students.id = parent_student_links.student_id
			WHERE users.school_id <> parent_student_links.school_id
				OR students.school_id <> parent_student_links.school_id
		`,
	}
}
```

If any probe count is greater than zero, fail startup in migration mode with the exact probe name. Do not silently delete or rewrite data.

- [x] **Step 3: Add constraints only after probes pass**

Use an explicit function called from database initialization:

```go
func ApplyRelationshipConstraints(db *gorm.DB) error {
	if err := assertRelationshipIntegrity(db); err != nil {
		return err
	}
	for _, statement := range relationshipConstraintStatements() {
		if err := db.Exec(statement).Error; err != nil {
			return err
		}
	}
	return nil
}
```

Keep it gated behind an environment variable first:

```text
ENABLE_RELATIONSHIP_CONSTRAINTS=true
```

Default it off until local Docker data is probed cleanly.

## Task 4: Local Docker Verification

**Files:**
- No code files unless verification finds defects.

- [ ] **Step 1: Start or verify local Docker target**

```bash
docker --context desktop-linux compose ps || docker ps
curl -sS http://127.0.0.1:8080/health
```

Expected health response:

```json
{"status":"healthy"}
```

- [ ] **Step 2: Run backend gates**

```bash
cd school-backend
go test ./...
```

Expected:

```text
PASS
```

- [ ] **Step 3: Run Flutter static gate**

```bash
flutter analyze
```

Expected:

```text
No issues found
```

- [ ] **Step 4: Run role smoke checks manually**

Use the existing QA docs:

```text
docs/role-feature-backend-call-matrix.md
docs/role-module-test-cases.md
docs/foundation-manual-test-cases.md
```

Smoke order:

```text
Principal -> Admin -> Teacher -> Parent
```

Acceptance:

```text
Principal can observe and approve, not perform Admin-only CRUD.
Admin can manage operational school records.
Teacher sees only assigned classroom data.
Parent sees only linked child data.
No fake/demo data is shown as backend truth.
```

## Task 5: Hostinger Readiness Gate

**Files:**
- Modify later only if deployment config drift is found.

- [ ] **Step 1: Do not deploy until local Step 2 and Step 3 pass**

Required local gates:

```text
go test ./...
flutter analyze
local Docker health
role smoke checks
relationship probe counts all zero
```

- [ ] **Step 2: Prepare VPS deployment checklist**

Before Hostinger KVM1:

```text
backup Postgres volume
backup .env and compose files
record current image tags
deploy with rollback path
verify /health
verify login for Principal, Admin, Teacher, Parent
verify parent/teacher cross-access denial
```

## Self-Review

Spec coverage:

- Step 2 RBAC and relationship policy is completed before database constraints.
- Parent/student, teacher/section/subject, Principal/Admin ownership, attendance, homework, diary, messages, PTM, fees, marks, and transport are covered.
- Local Docker remains the primary verification target.
- Hostinger is kept as the later deployment target.

Placeholder scan:

- No TBD or unspecified implementation steps remain.

Type consistency:

- Policy helpers remain in `handlers`.
- Database constraints remain in `database`.
- Flutter contracts remain unchanged.

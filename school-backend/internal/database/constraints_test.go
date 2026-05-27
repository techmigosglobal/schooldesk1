package database

import (
	"strings"
	"testing"
	"time"

	"school-backend/internal/models"
)

func TestRelationshipConstraintStatementsCoverCriticalForeignKeysAndIndexes(t *testing.T) {
	statements := relationshipConstraintStatements()
	if len(statements) < 20 {
		t.Fatalf("expected broad relationship coverage, got %d statements", len(statements))
	}

	sql := strings.Join(statements, "\n")
	expectedFragments := []string{
		"DO $$",
		"EXCEPTION WHEN duplicate_object THEN NULL",
		"ALTER TABLE students ADD CONSTRAINT fk_students_school FOREIGN KEY (school_id) REFERENCES schools(id)",
		"ALTER TABLE students ADD CONSTRAINT fk_students_current_section FOREIGN KEY (current_section_id) REFERENCES sections(id) ON DELETE SET NULL",
		"ALTER TABLE guardians ADD CONSTRAINT fk_guardians_student FOREIGN KEY (student_id) REFERENCES students(id)",
		"ALTER TABLE enrollments ADD CONSTRAINT fk_enrollments_section FOREIGN KEY (section_id) REFERENCES sections(id)",
		"ALTER TABLE parent_student_links ADD CONSTRAINT fk_parent_student_links_parent_user FOREIGN KEY (parent_user_id) REFERENCES users(id)",
		"ALTER TABLE attendance_sessions ADD CONSTRAINT fk_attendance_sessions_staff FOREIGN KEY (staff_id) REFERENCES staffs(id)",
		"ALTER TABLE staff_subjects ADD CONSTRAINT fk_staff_subjects_section FOREIGN KEY (section_id) REFERENCES sections(id)",
		"ALTER TABLE student_attendances ADD CONSTRAINT fk_student_attendances_enrollment FOREIGN KEY (enrollment_id) REFERENCES enrollments(id)",
		"ALTER TABLE fee_invoices ADD CONSTRAINT fk_fee_invoices_student FOREIGN KEY (student_id) REFERENCES students(id)",
		"ALTER TABLE payments ADD CONSTRAINT fk_payments_invoice FOREIGN KEY (invoice_id) REFERENCES fee_invoices(id)",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_students_school_admission_number",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_school_staff_code",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_parent_student_links_school_parent_student",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_enrollments_student_section_year",
		"CREATE INDEX IF NOT EXISTS idx_student_attendances_session_student",
	}
	for _, fragment := range expectedFragments {
		if !strings.Contains(sql, fragment) {
			t.Fatalf("expected relationship SQL to contain %q\nSQL:\n%s", fragment, sql)
		}
	}
}

func TestIntegrityProbeQueriesCoverRelationshipRisks(t *testing.T) {
	probes := integrityProbeQueries()
	expectedProbeNames := []string{
		"students_school_orphan",
		"student_current_section_school_mismatch",
		"enrollment_school_mismatch",
		"parent_student_link_cross_school",
		"parent_student_link_school_orphan",
		"attendance_session_school_mismatch",
		"student_attendance_session_section_mismatch",
		"fee_invoice_school_mismatch",
		"payment_invoice_orphan",
		"student_documents_orphan",
		"medical_records_orphan",
		"guardian_school_orphan",
		"student_guardian_school_mismatch",
		"student_admission_number_duplicate",
		"student_code_duplicate",
		"staff_code_duplicate",
		"staff_subject_school_mismatch",
		"parent_student_link_duplicate",
		"enrollment_student_section_year_duplicate",
	}

	for _, name := range expectedProbeNames {
		query, ok := probes[name]
		if !ok {
			t.Fatalf("missing integrity probe %q", name)
		}
		if !strings.Contains(strings.ToUpper(query), "SELECT COUNT(*)") {
			t.Fatalf("probe %q should be count based, got %s", name, query)
		}
	}
}

func TestAssertRelationshipIntegrityFailsWithProbeName(t *testing.T) {
	if err := SetupTestDB(); err != nil {
		t.Fatalf("setup test db: %v", err)
	}

	create := func(value any) {
		t.Helper()
		if err := DB.Create(value).Error; err != nil {
			t.Fatalf("seed corrupt fixture: %v", err)
		}
	}

	schoolA := models.School{BaseModel: models.BaseModel{ID: "school-a"}, Name: "School A", SchoolType: "cbse"}
	schoolB := models.School{BaseModel: models.BaseModel{ID: "school-b"}, Name: "School B", SchoolType: "cbse"}
	yearB := models.AcademicYear{
		BaseModel: models.BaseModel{ID: "year-b"},
		SchoolID:  schoolB.ID,
		YearLabel: "2026-2027",
		StartDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		EndDate:   time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC),
	}
	gradeB := models.Grade{
		BaseModel:   models.BaseModel{ID: "grade-b"},
		SchoolID:    schoolB.ID,
		GradeNumber: 1,
		GradeName:   "Grade 1",
	}
	sectionB := models.Section{
		BaseModel:      models.BaseModel{ID: "section-b"},
		GradeID:        gradeB.ID,
		AcademicYearID: yearB.ID,
		SectionName:    "A",
	}
	studentA := models.Student{
		BaseModel:        models.BaseModel{ID: "student-a"},
		SchoolID:         schoolA.ID,
		StudentCode:      "S-A-001",
		AdmissionNumber:  "ADM-A-001",
		FirstName:        "Asha",
		LastName:         "Rao",
		CurrentSectionID: &sectionB.ID,
	}

	create(&schoolA)
	create(&schoolB)
	create(&yearB)
	create(&gradeB)
	create(&sectionB)
	create(&studentA)

	err := assertRelationshipIntegrity(DB)
	if err == nil {
		t.Fatal("expected relationship integrity failure")
	}
	if !strings.Contains(err.Error(), "student_current_section_school_mismatch") {
		t.Fatalf("expected exact probe name in error, got %v", err)
	}
}

func TestApplyRelationshipConstraintsSkipsNonPostgresDialectors(t *testing.T) {
	if err := SetupTestDB(); err != nil {
		t.Fatalf("setup test db: %v", err)
	}

	if err := ApplyRelationshipConstraints(DB); err != nil {
		t.Fatalf("expected sqlite test database to skip Postgres constraint SQL, got %v", err)
	}
}

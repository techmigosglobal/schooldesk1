package database

import (
	"fmt"

	"gorm.io/gorm"
)

type integrityProbe struct {
	name  string
	query string
}

func ApplyRelationshipConstraints(db *gorm.DB) error {
	if db == nil {
		return fmt.Errorf("database handle is nil")
	}
	if db.Dialector.Name() != "postgres" {
		return nil
	}

	if err := assertRelationshipIntegrity(db); err != nil {
		return err
	}

	for _, statement := range relationshipConstraintStatements() {
		if err := db.Exec(statement).Error; err != nil {
			return fmt.Errorf("apply relationship constraint failed: %w", err)
		}
	}
	return nil
}

func assertRelationshipIntegrity(db *gorm.DB) error {
	if db == nil {
		return fmt.Errorf("database handle is nil")
	}

	for _, probe := range integrityProbes() {
		var count int64
		if err := db.Raw(probe.query).Scan(&count).Error; err != nil {
			return fmt.Errorf("relationship integrity probe %s failed: %w", probe.name, err)
		}
		if count > 0 {
			return fmt.Errorf("relationship integrity probe %s found %d invalid rows", probe.name, count)
		}
	}
	return nil
}

func integrityProbeQueries() map[string]string {
	probes := integrityProbes()
	out := make(map[string]string, len(probes))
	for _, probe := range probes {
		out[probe.name] = probe.query
	}
	return out
}

func integrityProbes() []integrityProbe {
	return []integrityProbe{
		{
			name: "students_school_orphan",
			query: `
				SELECT COUNT(*)
				FROM students
				LEFT JOIN schools ON schools.id = students.school_id
				WHERE schools.id IS NULL
			`,
		},
		{
			name: "student_current_section_school_mismatch",
			query: `
				SELECT COUNT(*)
				FROM students
				LEFT JOIN sections ON sections.id = students.current_section_id
				LEFT JOIN grades ON grades.id = sections.grade_id
				WHERE students.current_section_id IS NOT NULL
					AND (
						sections.id IS NULL
						OR grades.id IS NULL
						OR students.school_id <> grades.school_id
					)
			`,
		},
		{
			name: "enrollment_school_mismatch",
			query: `
				SELECT COUNT(*)
				FROM enrollments
				LEFT JOIN students ON students.id = enrollments.student_id
				LEFT JOIN sections ON sections.id = enrollments.section_id
				LEFT JOIN grades ON grades.id = sections.grade_id
				LEFT JOIN academic_years ON academic_years.id = enrollments.academic_year_id
				WHERE students.id IS NULL
					OR sections.id IS NULL
					OR grades.id IS NULL
					OR academic_years.id IS NULL
					OR students.school_id <> grades.school_id
					OR students.school_id <> academic_years.school_id
			`,
		},
		{
			name: "parent_student_link_cross_school",
			query: `
				SELECT COUNT(*)
				FROM parent_student_links
				LEFT JOIN users ON users.id = parent_student_links.parent_user_id
				LEFT JOIN students ON students.id = parent_student_links.student_id
				WHERE users.id IS NULL
					OR students.id IS NULL
					OR parent_student_links.school_id <> users.school_id
					OR parent_student_links.school_id <> students.school_id
			`,
		},
		{
			name: "parent_student_link_school_orphan",
			query: `
				SELECT COUNT(*)
				FROM parent_student_links
				LEFT JOIN schools ON schools.id = parent_student_links.school_id
				WHERE schools.id IS NULL
			`,
		},
		{
			name: "attendance_session_school_mismatch",
			query: `
				SELECT COUNT(*)
				FROM attendance_sessions
				LEFT JOIN sections ON sections.id = attendance_sessions.section_id
				LEFT JOIN grades ON grades.id = sections.grade_id
				LEFT JOIN subjects ON subjects.id = attendance_sessions.subject_id
				LEFT JOIN staff ON staff.id = attendance_sessions.staff_id
				WHERE sections.id IS NULL
					OR grades.id IS NULL
					OR subjects.id IS NULL
					OR staff.id IS NULL
					OR subjects.school_id <> grades.school_id
					OR staff.school_id <> grades.school_id
			`,
		},
		{
			name: "student_attendance_session_section_mismatch",
			query: `
				SELECT COUNT(*)
				FROM student_attendances
				LEFT JOIN attendance_sessions ON attendance_sessions.id = student_attendances.session_id
				LEFT JOIN students ON students.id = student_attendances.student_id
				LEFT JOIN enrollments ON enrollments.id = student_attendances.enrollment_id
				WHERE attendance_sessions.id IS NULL
					OR students.id IS NULL
					OR enrollments.id IS NULL
					OR enrollments.student_id <> student_attendances.student_id
					OR enrollments.section_id <> attendance_sessions.section_id
			`,
		},
		{
			name: "fee_invoice_school_mismatch",
			query: `
				SELECT COUNT(*)
				FROM fee_invoices
				LEFT JOIN students ON students.id = fee_invoices.student_id
				LEFT JOIN academic_years ON academic_years.id = fee_invoices.academic_year_id
				WHERE students.id IS NULL
					OR academic_years.id IS NULL
					OR students.school_id <> academic_years.school_id
			`,
		},
		{
			name: "payment_invoice_orphan",
			query: `
				SELECT COUNT(*)
				FROM payments
				LEFT JOIN fee_invoices ON fee_invoices.id = payments.invoice_id
				WHERE fee_invoices.id IS NULL
			`,
		},
		{
			name: "student_documents_orphan",
			query: `
				SELECT COUNT(*)
				FROM student_documents
				LEFT JOIN students ON students.id = student_documents.student_id
				WHERE students.id IS NULL
			`,
		},
		{
			name: "medical_records_orphan",
			query: `
				SELECT COUNT(*)
				FROM medical_records
				LEFT JOIN students ON students.id = medical_records.student_id
				WHERE students.id IS NULL
			`,
		},
		{
			name: "guardians_orphan",
			query: `
				SELECT COUNT(*)
				FROM guardians
				LEFT JOIN students ON students.id = guardians.student_id
				WHERE students.id IS NULL
			`,
		},
		{
			name: "student_admission_number_duplicate",
			query: `
				SELECT COUNT(*)
				FROM (
					SELECT school_id, admission_number
					FROM students
					WHERE admission_number IS NOT NULL
						AND admission_number <> ''
					GROUP BY school_id, admission_number
					HAVING COUNT(*) > 1
				) AS duplicates
			`,
		},
		{
			name: "student_code_duplicate",
			query: `
				SELECT COUNT(*)
				FROM (
					SELECT school_id, student_code
					FROM students
					WHERE student_code IS NOT NULL
						AND student_code <> ''
					GROUP BY school_id, student_code
					HAVING COUNT(*) > 1
				) AS duplicates
			`,
		},
		{
			name: "parent_student_link_duplicate",
			query: `
				SELECT COUNT(*)
				FROM (
					SELECT school_id, parent_user_id, student_id
					FROM parent_student_links
					GROUP BY school_id, parent_user_id, student_id
					HAVING COUNT(*) > 1
				) AS duplicates
			`,
		},
		{
			name: "enrollment_student_section_year_duplicate",
			query: `
				SELECT COUNT(*)
				FROM (
					SELECT student_id, section_id, academic_year_id
					FROM enrollments
					GROUP BY student_id, section_id, academic_year_id
					HAVING COUNT(*) > 1
				) AS duplicates
			`,
		},
	}
}

func relationshipConstraintStatements() []string {
	return []string{
		addForeignKeyConstraint("students", "fk_students_school", "school_id", "schools", "id", "ON DELETE RESTRICT"),
		addForeignKeyConstraint("students", "fk_students_current_section", "current_section_id", "sections", "id", "ON DELETE SET NULL"),
		addForeignKeyConstraint("guardians", "fk_guardians_student", "student_id", "students", "id", "ON DELETE CASCADE"),
		addForeignKeyConstraint("medical_records", "fk_medical_records_student", "student_id", "students", "id", "ON DELETE CASCADE"),
		addForeignKeyConstraint("student_documents", "fk_student_documents_student", "student_id", "students", "id", "ON DELETE CASCADE"),
		addForeignKeyConstraint("enrollments", "fk_enrollments_student", "student_id", "students", "id", "ON DELETE CASCADE"),
		addForeignKeyConstraint("enrollments", "fk_enrollments_section", "section_id", "sections", "id", "ON DELETE RESTRICT"),
		addForeignKeyConstraint("enrollments", "fk_enrollments_academic_year", "academic_year_id", "academic_years", "id", "ON DELETE RESTRICT"),
		addForeignKeyConstraint("parent_student_links", "fk_parent_student_links_school", "school_id", "schools", "id", "ON DELETE CASCADE"),
		addForeignKeyConstraint("parent_student_links", "fk_parent_student_links_parent_user", "parent_user_id", "users", "id", "ON DELETE CASCADE"),
		addForeignKeyConstraint("parent_student_links", "fk_parent_student_links_student", "student_id", "students", "id", "ON DELETE CASCADE"),
		addForeignKeyConstraint("attendance_sessions", "fk_attendance_sessions_section", "section_id", "sections", "id", "ON DELETE RESTRICT"),
		addForeignKeyConstraint("attendance_sessions", "fk_attendance_sessions_subject", "subject_id", "subjects", "id", "ON DELETE RESTRICT"),
		addForeignKeyConstraint("attendance_sessions", "fk_attendance_sessions_staff", "staff_id", "staff", "id", "ON DELETE RESTRICT"),
		addForeignKeyConstraint("student_attendances", "fk_student_attendances_session", "session_id", "attendance_sessions", "id", "ON DELETE CASCADE"),
		addForeignKeyConstraint("student_attendances", "fk_student_attendances_student", "student_id", "students", "id", "ON DELETE CASCADE"),
		addForeignKeyConstraint("student_attendances", "fk_student_attendances_enrollment", "enrollment_id", "enrollments", "id", "ON DELETE CASCADE"),
		addForeignKeyConstraint("fee_invoices", "fk_fee_invoices_student", "student_id", "students", "id", "ON DELETE RESTRICT"),
		addForeignKeyConstraint("fee_invoices", "fk_fee_invoices_academic_year", "academic_year_id", "academic_years", "id", "ON DELETE RESTRICT"),
		addForeignKeyConstraint("payments", "fk_payments_invoice", "invoice_id", "fee_invoices", "id", "ON DELETE CASCADE"),
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_students_school_admission_number ON students (school_id, admission_number) WHERE admission_number <> '';",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_students_school_student_code ON students (school_id, student_code) WHERE student_code <> '';",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_parent_student_links_school_parent_student ON parent_student_links (school_id, parent_user_id, student_id);",
		"CREATE UNIQUE INDEX IF NOT EXISTS idx_enrollments_student_section_year ON enrollments (student_id, section_id, academic_year_id);",
		"CREATE INDEX IF NOT EXISTS idx_student_attendances_session_student ON student_attendances (session_id, student_id);",
		"CREATE INDEX IF NOT EXISTS idx_attendance_sessions_section_date_period ON attendance_sessions (section_id, date, period_number);",
	}
}

func addForeignKeyConstraint(table, constraintName, column, referenceTable, referenceColumn, onDelete string) string {
	if onDelete != "" {
		onDelete = " " + onDelete
	}
	return fmt.Sprintf(
		"DO $$ BEGIN ALTER TABLE %s ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES %s(%s)%s; EXCEPTION WHEN duplicate_object THEN NULL; END $$;",
		table,
		constraintName,
		column,
		referenceTable,
		referenceColumn,
		onDelete,
	)
}

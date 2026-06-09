package database

func ensureSupplementalSchema() error {
	switch DB.Dialector.Name() {
	case "postgres":
		return ensurePostgresSupplementalSchema()
	case "sqlite":
		return ensureSQLiteSupplementalSchema()
	default:
		return nil
	}
}

func ensurePreAutoMigrateSchema() error {
	if DB == nil || DB.Dialector.Name() != "postgres" {
		return nil
	}
	return ensurePostgresAcademicScopeColumns()
}

func ensurePostgresAcademicScopeColumns() error {
	statements := []string{
		`DO $$
		BEGIN
			IF to_regclass('public.sections') IS NOT NULL THEN
				ALTER TABLE sections ADD COLUMN IF NOT EXISTS school_id text;
			END IF;
		END $$;`,
		`DO $$
		BEGIN
			IF to_regclass('public.sections') IS NOT NULL AND to_regclass('public.grades') IS NOT NULL THEN
				UPDATE sections
				SET school_id = grades.school_id
				FROM grades
				WHERE sections.grade_id = grades.id
					AND COALESCE(BTRIM(sections.school_id), '') = '';
			END IF;
		END $$;`,
		`DO $$
		BEGIN
			IF to_regclass('public.grade_subjects') IS NOT NULL THEN
				ALTER TABLE grade_subjects ADD COLUMN IF NOT EXISTS school_id text;
				ALTER TABLE grade_subjects ADD COLUMN IF NOT EXISTS academic_year_id text;
			END IF;
		END $$;`,
		`DO $$
		BEGIN
			IF to_regclass('public.grade_subjects') IS NOT NULL AND to_regclass('public.grades') IS NOT NULL THEN
				UPDATE grade_subjects
				SET school_id = grades.school_id
				FROM grades
				WHERE grade_subjects.grade_id = grades.id
					AND COALESCE(BTRIM(grade_subjects.school_id), '') = '';
			END IF;
		END $$;`,
		`DO $$
		BEGIN
			IF to_regclass('public.grade_subjects') IS NOT NULL AND to_regclass('public.academic_years') IS NOT NULL THEN
				UPDATE grade_subjects
				SET academic_year_id = current_year.id
				FROM (
					SELECT DISTINCT ON (school_id) id, school_id
					FROM academic_years
					ORDER BY school_id, is_current DESC, created_at DESC
				) current_year
				WHERE grade_subjects.school_id = current_year.school_id
					AND COALESCE(BTRIM(grade_subjects.academic_year_id), '') = '';
			END IF;
		END $$;`,
		`DO $$
		BEGIN
			IF to_regclass('public.staff_subjects') IS NOT NULL THEN
				ALTER TABLE staff_subjects ADD COLUMN IF NOT EXISTS school_id text;
				ALTER TABLE staff_subjects ADD COLUMN IF NOT EXISTS academic_year_id text;
			END IF;
		END $$;`,
		`DO $$
		BEGIN
			IF to_regclass('public.staff_subjects') IS NOT NULL AND to_regclass('public.staffs') IS NOT NULL THEN
				UPDATE staff_subjects
				SET school_id = staffs.school_id
				FROM staffs
				WHERE staff_subjects.staff_id = staffs.id
					AND COALESCE(BTRIM(staff_subjects.school_id), '') = '';
			END IF;
		END $$;`,
		`DO $$
		BEGIN
			IF to_regclass('public.staff_subjects') IS NOT NULL AND to_regclass('public.sections') IS NOT NULL THEN
				UPDATE staff_subjects
				SET academic_year_id = sections.academic_year_id
				FROM sections
				WHERE staff_subjects.section_id = sections.id
					AND COALESCE(BTRIM(staff_subjects.academic_year_id), '') = '';
			END IF;
		END $$;`,
		`DO $$
		BEGIN
			IF to_regclass('public.staff_subjects') IS NOT NULL AND to_regclass('public.academic_years') IS NOT NULL THEN
				UPDATE staff_subjects
				SET academic_year_id = current_year.id
				FROM (
					SELECT DISTINCT ON (school_id) id, school_id
					FROM academic_years
					ORDER BY school_id, is_current DESC, created_at DESC
				) current_year
				WHERE staff_subjects.school_id = current_year.school_id
					AND COALESCE(BTRIM(staff_subjects.academic_year_id), '') = '';
			END IF;
		END $$;`,
	}
	for _, statement := range statements {
		if err := DB.Exec(statement).Error; err != nil {
			return err
		}
	}
	return nil
}

func ensurePostgresSupplementalSchema() error {
	statements := []string{
		`DO $$ BEGIN CREATE TYPE school_role AS ENUM ('super_admin','admin','teacher','student','parent','principal'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;`,
		`DO $$ BEGIN CREATE TYPE attendance_status AS ENUM ('present','absent','late','half_day','leave'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;`,
		`DO $$ BEGIN CREATE TYPE exam_type AS ENUM ('unit_test','mid_term','final','assignment'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;`,
		`DO $$ BEGIN CREATE TYPE fee_status AS ENUM ('pending','paid','overdue','partial'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;`,
		`ALTER TABLE users ADD COLUMN IF NOT EXISTS name text;`,
		`ALTER TABLE users ADD COLUMN IF NOT EXISTS username text;`,
		`ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar text;`,
		`ALTER TABLE users ADD COLUMN IF NOT EXISTS role text;`,
		`ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at timestamptz;`,
		`UPDATE users
			SET username = CASE
				WHEN LOWER(email) = 'principal@schooldesk.local' THEN 'principal'
				WHEN POSITION('@' IN email) > 1 THEN split_part(email, '@', 1)
				ELSE email
			END
			WHERE COALESCE(BTRIM(username), '') = '';`,
		`ALTER TABLE students ADD COLUMN IF NOT EXISTS user_id text;`,
		`ALTER TABLE students ADD COLUMN IF NOT EXISTS parent_id text;`,
		`ALTER TABLE students ADD COLUMN IF NOT EXISTS address text;`,
		`ALTER TABLE academic_years ADD COLUMN IF NOT EXISTS year text;`,
		`ALTER TABLE sections ADD COLUMN IF NOT EXISTS school_id text;`,
		`UPDATE sections
			SET school_id = grades.school_id
			FROM grades
			WHERE sections.grade_id = grades.id
				AND COALESCE(BTRIM(sections.school_id), '') = '';`,
		`ALTER TABLE grade_subjects ADD COLUMN IF NOT EXISTS school_id text;`,
		`ALTER TABLE grade_subjects ADD COLUMN IF NOT EXISTS academic_year_id text;`,
		`UPDATE grade_subjects
			SET school_id = grades.school_id
			FROM grades
			WHERE grade_subjects.grade_id = grades.id
				AND COALESCE(BTRIM(grade_subjects.school_id), '') = '';`,
		`UPDATE grade_subjects
			SET academic_year_id = current_year.id
			FROM (
				SELECT DISTINCT ON (school_id) id, school_id
				FROM academic_years
				ORDER BY school_id, is_current DESC, created_at DESC
			) current_year
			WHERE grade_subjects.school_id = current_year.school_id
				AND COALESCE(BTRIM(grade_subjects.academic_year_id), '') = '';`,
		`ALTER TABLE staff_subjects ADD COLUMN IF NOT EXISTS school_id text;`,
		`ALTER TABLE staff_subjects ADD COLUMN IF NOT EXISTS academic_year_id text;`,
		`UPDATE staff_subjects
			SET school_id = staffs.school_id
			FROM staffs
			WHERE staff_subjects.staff_id = staffs.id
				AND COALESCE(BTRIM(staff_subjects.school_id), '') = '';`,
		`UPDATE staff_subjects
			SET academic_year_id = sections.academic_year_id
			FROM sections
			WHERE staff_subjects.section_id = sections.id
				AND COALESCE(BTRIM(staff_subjects.academic_year_id), '') = '';`,
		`UPDATE staff_subjects
			SET academic_year_id = current_year.id
			FROM (
				SELECT DISTINCT ON (school_id) id, school_id
				FROM academic_years
				ORDER BY school_id, is_current DESC, created_at DESC
			) current_year
			WHERE staff_subjects.school_id = current_year.school_id
				AND COALESCE(BTRIM(staff_subjects.academic_year_id), '') = '';`,
		`ALTER TABLE attendance_sessions ADD COLUMN IF NOT EXISTS academic_year_id text;`,
		`UPDATE attendance_sessions
			SET academic_year_id = sections.academic_year_id
			FROM sections
			WHERE attendance_sessions.section_id = sections.id
				AND COALESCE(BTRIM(attendance_sessions.academic_year_id), '') = '';`,
		`CREATE TABLE IF NOT EXISTS teachers (
			id text PRIMARY KEY,
			user_id text,
			employee_id text,
			qualification text,
			joining_date timestamptz,
			created_at timestamptz DEFAULT now()
		);`,
		`CREATE TABLE IF NOT EXISTS classes (
			id text PRIMARY KEY,
			name text NOT NULL,
			section text,
			class_teacher_id text,
			academic_year_id text,
			created_at timestamptz DEFAULT now()
		);`,
		`CREATE TABLE IF NOT EXISTS attendance (
			id text PRIMARY KEY,
			student_id text,
			class_id text,
			date date,
			status text,
			marked_by_id text,
			created_at timestamptz DEFAULT now()
		);`,
		`CREATE TABLE IF NOT EXISTS timetable (
			id text PRIMARY KEY,
			class_id text,
			subject_id text,
			teacher_id text,
			day_of_week integer,
			start_time text,
			end_time text
		);`,
		`CREATE TABLE IF NOT EXISTS fees (
			id text PRIMARY KEY,
			student_id text,
			fee_type text,
			amount numeric,
			due_date date,
			paid_date date,
			status text,
			created_at timestamptz DEFAULT now()
		);`,
		`CREATE TABLE IF NOT EXISTS notices (
			id text PRIMARY KEY,
			title text NOT NULL,
			content text,
			target_role text,
			published_by_id text,
			is_active boolean DEFAULT true,
			created_at timestamptz DEFAULT now()
		);`,
		`CREATE TABLE IF NOT EXISTS notifications (
			id text PRIMARY KEY,
			user_id text,
			title text,
			body text,
			is_read boolean DEFAULT false,
			type text,
			created_at timestamptz DEFAULT now()
		);`,
	}
	for _, statement := range statements {
		if err := DB.Exec(statement).Error; err != nil {
			return err
		}
	}
	return nil
}

func ensureSQLiteSupplementalSchema() error {
	statements := []string{
		`ALTER TABLE users ADD COLUMN name text;`,
		`ALTER TABLE users ADD COLUMN username text;`,
		`ALTER TABLE users ADD COLUMN avatar text;`,
		`ALTER TABLE users ADD COLUMN role text;`,
		`ALTER TABLE users ADD COLUMN updated_at datetime;`,
		`UPDATE users
			SET username = CASE
				WHEN LOWER(email) = 'principal@schooldesk.local' THEN 'principal'
				WHEN instr(email, '@') > 1 THEN substr(email, 1, instr(email, '@') - 1)
				ELSE email
			END
			WHERE COALESCE(TRIM(username), '') = '';`,
		`ALTER TABLE students ADD COLUMN user_id text;`,
		`ALTER TABLE students ADD COLUMN parent_id text;`,
		`ALTER TABLE students ADD COLUMN address text;`,
		`ALTER TABLE academic_years ADD COLUMN year text;`,
		`ALTER TABLE sections ADD COLUMN school_id text;`,
		`UPDATE sections SET school_id = (SELECT grades.school_id FROM grades WHERE grades.id = sections.grade_id) WHERE COALESCE(TRIM(school_id), '') = '';`,
		`ALTER TABLE grade_subjects ADD COLUMN school_id text;`,
		`ALTER TABLE grade_subjects ADD COLUMN academic_year_id text;`,
		`UPDATE grade_subjects SET school_id = (SELECT grades.school_id FROM grades WHERE grades.id = grade_subjects.grade_id) WHERE COALESCE(TRIM(school_id), '') = '';`,
		`UPDATE grade_subjects SET academic_year_id = (SELECT academic_years.id FROM academic_years WHERE academic_years.school_id = grade_subjects.school_id ORDER BY academic_years.is_current DESC, academic_years.created_at DESC LIMIT 1) WHERE COALESCE(TRIM(academic_year_id), '') = '';`,
		`ALTER TABLE staff_subjects ADD COLUMN school_id text;`,
		`ALTER TABLE staff_subjects ADD COLUMN academic_year_id text;`,
		`UPDATE staff_subjects SET school_id = (SELECT staffs.school_id FROM staffs WHERE staffs.id = staff_subjects.staff_id) WHERE COALESCE(TRIM(school_id), '') = '';`,
		`UPDATE staff_subjects SET academic_year_id = (SELECT sections.academic_year_id FROM sections WHERE sections.id = staff_subjects.section_id) WHERE COALESCE(TRIM(academic_year_id), '') = '';`,
		`UPDATE staff_subjects SET academic_year_id = (SELECT academic_years.id FROM academic_years WHERE academic_years.school_id = staff_subjects.school_id ORDER BY academic_years.is_current DESC, academic_years.created_at DESC LIMIT 1) WHERE COALESCE(TRIM(academic_year_id), '') = '';`,
		`ALTER TABLE attendance_sessions ADD COLUMN academic_year_id text;`,
		`UPDATE attendance_sessions SET academic_year_id = (SELECT sections.academic_year_id FROM sections WHERE sections.id = attendance_sessions.section_id) WHERE COALESCE(TRIM(academic_year_id), '') = '';`,
		`CREATE TABLE IF NOT EXISTS teachers (id text PRIMARY KEY, user_id text, employee_id text, qualification text, joining_date datetime, created_at datetime);`,
		`CREATE TABLE IF NOT EXISTS classes (id text PRIMARY KEY, name text NOT NULL, section text, class_teacher_id text, academic_year_id text, created_at datetime);`,
		`CREATE TABLE IF NOT EXISTS attendance (id text PRIMARY KEY, student_id text, class_id text, date datetime, status text, marked_by_id text, created_at datetime);`,
		`CREATE TABLE IF NOT EXISTS timetable (id text PRIMARY KEY, class_id text, subject_id text, teacher_id text, day_of_week integer, start_time text, end_time text);`,
		`CREATE TABLE IF NOT EXISTS fees (id text PRIMARY KEY, student_id text, fee_type text, amount decimal, due_date datetime, paid_date datetime, status text, created_at datetime);`,
		`CREATE TABLE IF NOT EXISTS notices (id text PRIMARY KEY, title text NOT NULL, content text, target_role text, published_by_id text, is_active boolean DEFAULT true, created_at datetime);`,
		`CREATE TABLE IF NOT EXISTS notifications (id text PRIMARY KEY, user_id text, title text, body text, is_read boolean DEFAULT false, type text, created_at datetime);`,
	}
	for _, statement := range statements {
		if err := DB.Exec(statement).Error; err != nil {
			// SQLite has no ADD COLUMN IF NOT EXISTS. Duplicate-column errors are
			// harmless when tests initialize several databases in one process.
			continue
		}
	}
	return nil
}

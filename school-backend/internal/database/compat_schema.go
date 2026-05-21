package database

func ensureCompatibilitySchema() error {
	switch DB.Dialector.Name() {
	case "postgres":
		return ensurePostgresCompatibilitySchema()
	case "sqlite":
		return ensureSQLiteCompatibilitySchema()
	default:
		return nil
	}
}

func ensurePostgresCompatibilitySchema() error {
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

func ensureSQLiteCompatibilitySchema() error {
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

package database

import (
	"fmt"
	"log"
)

// backfillTablesMDLegacy copies rows from deprecated duplicate tables into Tables.md
// canonical tables. Safe to run on every startup (idempotent inserts).
func backfillTablesMDLegacy() error {
	if DB == nil {
		return nil
	}
	if err := backfillHomeworksToHomework(); err != nil {
		return err
	}
	if err := backfillEventCalendarsToEvents(); err != nil {
		return err
	}
	return nil
}

func backfillHomeworksToHomework() error {
	if !DB.Migrator().HasTable("homeworks") || !DB.Migrator().HasTable("homework") {
		return nil
	}
	if !DB.Migrator().HasColumn("homeworks", "id") {
		return nil
	}
	studentSelect := "''"
	if DB.Migrator().HasColumn("homeworks", "student_id") {
		studentSelect = "COALESCE(h.student_id, '')"
	}
	sql := `
		INSERT INTO homework (
			homework_id, school_id, title, description, class_id, section_id,
			subject_id, staff_id, student_id, submission_date, status, created_at, updated_at
		)
		SELECT
			h.id,
			h.school_id,
			h.title,
			COALESCE(h.description, ''),
			COALESCE(h.class_name, ''),
			COALESCE(h.section_id, ''),
			COALESCE(h.subject, ''),
			COALESCE(h.teacher_id, ''),
			` + studentSelect + `,
			CASE
				WHEN h.due_date IS NULL OR h.due_date = '' THEN NULL
				ELSE date(h.due_date)
			END,
			COALESCE(NULLIF(h.status, ''), 'pending'),
			COALESCE(h.created_at, CURRENT_TIMESTAMP),
			COALESCE(h.updated_at, CURRENT_TIMESTAMP)
		FROM homeworks h
		WHERE NOT EXISTS (
			SELECT 1 FROM homework c WHERE c.homework_id = h.id
		)
	`
	if DB.Dialector.Name() == "postgres" {
		sql = `
			INSERT INTO homework (
				homework_id, school_id, title, description, class_id, section_id,
				subject_id, staff_id, student_id, submission_date, status, created_at, updated_at
			)
			SELECT
				h.id,
				h.school_id,
				h.title,
				COALESCE(h.description, ''),
				COALESCE(h.class_name, ''),
				COALESCE(h.section_id, ''),
				COALESCE(h.subject, ''),
				COALESCE(h.teacher_id, ''),
				` + studentSelect + `,
				h.due_date::date,
				COALESCE(NULLIF(h.status, ''), 'pending'),
				COALESCE(h.created_at, NOW()),
				COALESCE(h.updated_at, NOW())
			FROM homeworks h
			WHERE NOT EXISTS (
				SELECT 1 FROM homework c WHERE c.homework_id = h.id
			)
			ON CONFLICT (homework_id) DO NOTHING
		`
	}
	if err := DB.Exec(sql).Error; err != nil {
		return fmt.Errorf("backfill homeworks→homework: %w", err)
	}
	log.Println("Tables.md migration: homeworks → homework backfill complete")
	return nil
}

func backfillEventCalendarsToEvents() error {
	if !DB.Migrator().HasTable("event_calendars") || !DB.Migrator().HasTable("events") {
		return nil
	}
	sql := `
		INSERT INTO events (
			event_id, school_id, event_name, event_type, description,
			start_date, end_date, start_time, end_time, venue, organizer_id,
			is_holiday, academic_year_id, status, created_at, updated_at
		)
		SELECT
			e.id,
			e.school_id,
			e.event_title,
			COALESCE(e.event_type, 'general'),
			COALESCE(e.description, ''),
			date(e.start_datetime),
			date(e.end_datetime),
			time(e.start_datetime),
			time(e.end_datetime),
			COALESCE(e.location, ''),
			COALESCE(e.created_by, ''),
			CASE WHEN e.is_holiday THEN 1 ELSE 0 END,
			COALESCE(e.academic_year_id, ''),
			'scheduled',
			COALESCE(e.created_at, CURRENT_TIMESTAMP),
			COALESCE(e.updated_at, CURRENT_TIMESTAMP)
		FROM event_calendars e
		WHERE NOT EXISTS (
			SELECT 1 FROM events c WHERE c.event_id = e.id
		)
	`
	if DB.Dialector.Name() == "postgres" {
		sql = `
			INSERT INTO events (
				event_id, school_id, event_name, event_type, description,
				start_date, end_date, start_time, end_time, venue, organizer_id,
				is_holiday, academic_year_id, status, created_at, updated_at
			)
			SELECT
				e.id,
				e.school_id,
				e.event_title,
				COALESCE(e.event_type, 'general'),
				COALESCE(e.description, ''),
				e.start_datetime::date,
				e.end_datetime::date,
				e.start_datetime::time,
				e.end_datetime::time,
				COALESCE(e.location, ''),
				COALESCE(e.created_by, ''),
				COALESCE(e.is_holiday, false),
				COALESCE(e.academic_year_id, ''),
				'scheduled',
				COALESCE(e.created_at, NOW()),
				COALESCE(e.updated_at, NOW())
			FROM event_calendars e
			WHERE NOT EXISTS (
				SELECT 1 FROM events ev WHERE ev.event_id = e.id
			)
			ON CONFLICT (event_id) DO NOTHING
		`
	}
	if err := DB.Exec(sql).Error; err != nil {
		return fmt.Errorf("backfill event_calendars→events: %w", err)
	}
	log.Println("Tables.md migration: event_calendars → events backfill complete")
	return nil
}

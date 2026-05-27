package database

import (
	"fmt"
	"strings"
)

type tablesMDColumn struct {
	Name string
	Type string
}

type tablesMDTable struct {
	Name       string
	PrimaryKey string
	Columns    []tablesMDColumn
	Aliases    map[string]string
}

func ensureTablesMDSchema() error {
	for _, table := range tablesMDTables() {
		if err := ensureTablesMDTable(table); err != nil {
			return err
		}
		if err := backfillTablesMDCompatibilityColumns(table); err != nil {
			return err
		}
	}
	return nil
}

func ensureTablesMDTable(table tablesMDTable) error {
	if !DB.Migrator().HasTable(table.Name) {
		if err := DB.Exec(createTablesMDTableSQL(table)).Error; err != nil {
			return err
		}
	}
	for _, column := range table.Columns {
		if !DB.Migrator().HasColumn(table.Name, column.Name) {
			statement := fmt.Sprintf(
				"ALTER TABLE %s ADD COLUMN %s %s",
				quoteSQLIdentifier(table.Name),
				quoteSQLIdentifier(column.Name),
				column.Type,
			)
			if err := DB.Exec(statement).Error; err != nil {
				return err
			}
		}
	}
	return nil
}

func createTablesMDTableSQL(table tablesMDTable) string {
	definitions := make([]string, 0, len(table.Columns))
	for _, column := range table.Columns {
		definition := quoteSQLIdentifier(column.Name) + " " + column.Type
		if column.Name == table.PrimaryKey {
			definition += " PRIMARY KEY"
		}
		definitions = append(definitions, definition)
	}
	return fmt.Sprintf(
		"CREATE TABLE IF NOT EXISTS %s (%s)",
		quoteSQLIdentifier(table.Name),
		strings.Join(definitions, ", "),
	)
}

func backfillTablesMDCompatibilityColumns(table tablesMDTable) error {
	if !DB.Migrator().HasColumn(table.Name, table.PrimaryKey) {
		return nil
	}
	if DB.Migrator().HasColumn(table.Name, "id") {
		if err := DB.Exec(fmt.Sprintf(
			"UPDATE %s SET %s = id WHERE (%s IS NULL OR %s = '') AND id IS NOT NULL AND id != ''",
			quoteSQLIdentifier(table.Name),
			quoteSQLIdentifier(table.PrimaryKey),
			quoteSQLIdentifier(table.PrimaryKey),
			quoteSQLIdentifier(table.PrimaryKey),
		)).Error; err != nil {
			return err
		}
	}
	for source, target := range table.Aliases {
		if !DB.Migrator().HasColumn(table.Name, source) || !DB.Migrator().HasColumn(table.Name, target) {
			continue
		}
		if err := DB.Exec(fmt.Sprintf(
			"UPDATE %s SET %s = %s WHERE %s IS NULL AND %s IS NOT NULL",
			quoteSQLIdentifier(table.Name),
			quoteSQLIdentifier(target),
			quoteSQLIdentifier(source),
			quoteSQLIdentifier(target),
			quoteSQLIdentifier(source),
		)).Error; err != nil {
			return err
		}
	}
	return nil
}

func quoteSQLIdentifier(identifier string) string {
	return `"` + strings.ReplaceAll(identifier, `"`, `""`) + `"`
}

func tablesMDTables() []tablesMDTable {
	text := "text"
	integer := "integer"
	boolean := "boolean"
	numeric := "numeric"
	date := "date"
	timeType := "text"
	timestamp := "datetime"
	if DB != nil && DB.Dialector.Name() == "postgres" {
		timeType = "time"
		timestamp = "timestamptz"
	}

	return []tablesMDTable{
		{
			Name:       "classes",
			PrimaryKey: "class_id",
			Columns: []tablesMDColumn{
				{"class_id", text}, {"school_id", text}, {"academic_year_id", text},
				{"class_name", text}, {"class_code", text}, {"section_id", text},
				{"class_teacher_id", text}, {"room_id", text}, {"medium", text},
				{"sort_order", integer}, {"is_active", boolean}, {"created_at", timestamp},
				{"updated_at", timestamp},
			},
			Aliases: map[string]string{"name": "class_name"},
		},
		{
			Name:       "attendance",
			PrimaryKey: "attendance_id",
			Columns: []tablesMDColumn{
				{"attendance_id", text}, {"school_id", text}, {"academic_year_id", text},
				{"attendance_type", text}, {"student_id", text}, {"staff_id", text},
				{"class_id", text}, {"section_id", text}, {"attendance_date", date},
				{"status", text}, {"check_in_time", timeType}, {"check_out_time", timeType},
				{"remarks", text}, {"marked_by", text}, {"created_at", timestamp},
				{"updated_at", timestamp},
			},
			Aliases: map[string]string{"date": "attendance_date", "marked_by_id": "marked_by"},
		},
		{
			Name:       "fees",
			PrimaryKey: "fee_id",
			Columns: []tablesMDColumn{
				{"fee_id", text}, {"school_id", text}, {"academic_year_id", text},
				{"student_id", text}, {"class_id", text}, {"section_id", text},
				{"fee_type_id", text}, {"invoice_no", text}, {"receipt_no", text},
				{"due_date", date}, {"amount", numeric}, {"discount_amount", numeric},
				{"fine_amount", numeric}, {"paid_amount", numeric}, {"balance_amount", numeric},
				{"payment_mode", text}, {"payment_status", text}, {"transaction_id", text},
				{"remarks", text}, {"created_at", timestamp}, {"updated_at", timestamp},
			},
			Aliases: map[string]string{"fee_type": "fee_type_id", "status": "payment_status"},
		},
		// Legacy exam campaigns + schedules use GORM models on table `exams` (see ExamHandler).
		{
			Name:       "homework",
			PrimaryKey: "homework_id",
			Columns: []tablesMDColumn{
				{"homework_id", text}, {"school_id", text}, {"academic_year_id", text},
				{"class_id", text}, {"section_id", text}, {"subject_id", text},
				{"staff_id", text}, {"student_id", text}, {"title", text}, {"description", text},
				{"assigned_date", date}, {"submission_date", date}, {"attachment_url", text},
				{"submission_mode", text}, {"status", text}, {"created_at", timestamp},
				{"updated_at", timestamp},
			},
			Aliases: map[string]string{"teacher_id": "staff_id", "due_date": "submission_date"},
		},
		{
			Name:       "leaves",
			PrimaryKey: "leave_id",
			Columns: []tablesMDColumn{
				{"leave_id", text}, {"school_id", text}, {"user_type", text},
				{"student_id", text}, {"staff_id", text}, {"leave_type_id", text},
				{"from_date", date}, {"to_date", date}, {"total_days", numeric},
				{"reason", text}, {"document_url", text}, {"approval_status", text},
				{"approved_by", text}, {"approved_at", timestamp}, {"remarks", text},
				{"created_at", timestamp}, {"updated_at", timestamp},
			},
		},
		{
			Name:       "notifications",
			PrimaryKey: "notification_id",
			Columns: []tablesMDColumn{
				{"notification_id", text}, {"school_id", text}, {"title", text},
				{"message", text}, {"notification_type", text}, {"target_role", text},
				{"target_user_id", text}, {"priority", text}, {"delivery_mode", text},
				{"is_read", boolean}, {"read_at", timestamp}, {"sent_by", text},
				{"sent_at", timestamp}, {"expiry_date", date}, {"created_at", timestamp},
				{"updated_at", timestamp},
			},
			Aliases: map[string]string{"body": "message", "type": "notification_type", "user_id": "target_user_id"},
		},
		{
			Name:       "holidays",
			PrimaryKey: "holiday_id",
			Columns: []tablesMDColumn{
				{"holiday_id", text}, {"school_id", text}, {"holiday_name", text},
				{"holiday_type", text}, {"start_date", date}, {"end_date", date},
				{"description", text}, {"is_optional", boolean}, {"applicable_for", text},
				{"created_by", text}, {"status", text}, {"created_at", timestamp},
				{"updated_at", timestamp},
			},
			Aliases: map[string]string{"type": "holiday_type", "from_date": "start_date", "to_date": "end_date"},
		},
		{
			Name:       "events",
			PrimaryKey: "event_id",
			Columns: []tablesMDColumn{
				{"event_id", text}, {"school_id", text}, {"event_name", text},
				{"event_type", text}, {"description", text}, {"start_date", date},
				{"end_date", date}, {"start_time", timeType}, {"end_time", timeType},
				{"venue", text}, {"organizer_id", text}, {"audience_type", text},
				{"attachment_url", text}, {"status", text}, {"is_holiday", boolean},
				{"academic_year_id", text}, {"created_at", timestamp}, {"updated_at", timestamp},
			},
			Aliases: map[string]string{"event_title": "event_name", "location": "venue"},
		},
		{
			Name:       "approval_requests",
			PrimaryKey: "approval_id",
			Columns: []tablesMDColumn{
				{"approval_id", text}, {"school_id", text}, {"academic_year_id", text},
				{"request_type", text}, {"module_name", text}, {"reference_table", text},
				{"reference_id", text}, {"requested_by", text}, {"requested_role", text},
				{"assigned_to", text}, {"approval_level", integer}, {"priority", text},
				{"title", text}, {"description", text}, {"old_value_json", text},
				{"new_value_json", text}, {"attachment_url", text}, {"remarks_by_requester", text},
				{"approval_status", text}, {"approved_by", text}, {"approved_at", timestamp},
				{"rejection_reason", text}, {"action_taken", text}, {"notification_sent", boolean},
				{"deadline_date", date}, {"created_at", timestamp}, {"updated_at", timestamp},
			},
		},
		{
			Name:       "communications",
			PrimaryKey: "message_id",
			Columns: []tablesMDColumn{
				{"message_id", text}, {"school_id", text}, {"sender_id", text},
				{"sender_role", text}, {"receiver_id", text}, {"receiver_role", text},
				{"student_id", text}, {"message_type", text}, {"message_content", text},
				{"attachment_url", text}, {"priority", text}, {"is_read", boolean},
				{"read_at", timestamp}, {"reply_to_message_id", text},
				{"is_deleted_by_sender", boolean}, {"is_deleted_by_receiver", boolean},
				{"sent_at", timestamp}, {"created_at", timestamp}, {"updated_at", timestamp},
			},
		},
		{
			Name:       "principal_reports",
			PrimaryKey: "report_id",
			Columns: []tablesMDColumn{
				{"report_id", text}, {"school_id", text}, {"academic_year_id", text},
				{"report_name", text}, {"report_type", text}, {"module_name", text},
				{"generated_by", text}, {"generated_role", text}, {"class_id", text},
				{"section_id", text}, {"student_id", text}, {"staff_id", text},
				{"date_from", date}, {"date_to", date}, {"report_parameters_json", text},
				{"report_summary_json", text}, {"chart_data_json", text},
				{"total_records", integer}, {"report_file_url", text}, {"report_status", text},
				{"is_scheduled", boolean}, {"schedule_frequency", text},
				{"last_generated_at", timestamp}, {"remarks", text}, {"created_at", timestamp},
				{"updated_at", timestamp},
			},
		},
	}
}

package database

import "testing"

func TestTablesMDSchemaHasTargetColumns(t *testing.T) {
	if err := SetupTestDB(); err != nil {
		t.Fatalf("setup test db: %v", err)
	}

	tables := map[string][]string{
		"classes": {
			"class_id", "school_id", "academic_year_id", "class_name", "class_code",
			"section_id", "class_teacher_id", "room_id", "medium", "sort_order",
			"is_active", "created_at", "updated_at",
		},
		"attendance": {
			"attendance_id", "school_id", "academic_year_id", "attendance_type",
			"student_id", "staff_id", "class_id", "section_id", "attendance_date",
			"status", "check_in_time", "check_out_time", "remarks", "marked_by",
			"created_at", "updated_at",
		},
		"fees": {
			"fee_id", "school_id", "academic_year_id", "student_id", "class_id",
			"section_id", "fee_type_id", "invoice_no", "receipt_no", "due_date",
			"amount", "discount_amount", "fine_amount", "paid_amount",
			"balance_amount", "payment_mode", "payment_status", "transaction_id",
			"remarks", "created_at", "updated_at",
		},
		"homework": {
			"homework_id", "school_id", "academic_year_id", "class_id", "section_id",
			"subject_id", "staff_id", "student_id", "title", "description", "assigned_date",
			"submission_date", "attachment_url", "submission_mode", "status",
			"created_at", "updated_at",
		},
		"leaves": {
			"leave_id", "school_id", "user_type", "student_id", "staff_id",
			"leave_type_id", "from_date", "to_date", "total_days", "reason",
			"document_url", "approval_status", "approved_by", "approved_at",
			"remarks", "created_at", "updated_at",
		},
		"notifications": {
			"notification_id", "school_id", "title", "message", "notification_type",
			"target_role", "target_user_id", "priority", "delivery_mode", "is_read",
			"read_at", "sent_by", "sent_at", "expiry_date", "created_at", "updated_at",
		},
		"holidays": {
			"holiday_id", "school_id", "holiday_name", "holiday_type", "start_date",
			"end_date", "description", "is_optional", "applicable_for", "created_by",
			"status", "created_at", "updated_at",
		},
		"events": {
			"event_id", "school_id", "event_name", "event_type", "description",
			"start_date", "end_date", "start_time", "end_time", "venue",
			"organizer_id", "audience_type", "attachment_url", "status", "is_holiday",
			"academic_year_id", "created_at", "updated_at",
		},
		"approval_requests": {
			"approval_id", "school_id", "academic_year_id", "request_type",
			"module_name", "reference_table", "reference_id", "requested_by",
			"requested_role", "assigned_to", "approval_level", "priority", "title",
			"description", "old_value_json", "new_value_json", "attachment_url",
			"remarks_by_requester", "approval_status", "approved_by", "approved_at",
			"rejection_reason", "action_taken", "notification_sent", "deadline_date",
			"created_at", "updated_at",
		},
		"communications": {
			"message_id", "school_id", "sender_id", "sender_role", "receiver_id",
			"receiver_role", "student_id", "message_type", "message_content",
			"attachment_url", "priority", "is_read", "read_at", "reply_to_message_id",
			"is_deleted_by_sender", "is_deleted_by_receiver", "sent_at", "created_at",
			"updated_at",
		},
		"principal_reports": {
			"report_id", "school_id", "academic_year_id", "report_name", "report_type",
			"module_name", "generated_by", "generated_role", "class_id", "section_id",
			"student_id", "staff_id", "date_from", "date_to", "report_parameters_json",
			"report_summary_json", "chart_data_json", "total_records", "report_file_url",
			"report_status", "is_scheduled", "schedule_frequency", "last_generated_at",
			"remarks", "created_at", "updated_at",
		},
	}

	for table, columns := range tables {
		if !DB.Migrator().HasTable(table) {
			t.Fatalf("table %s was not migrated", table)
		}
		for _, column := range columns {
			if !DB.Migrator().HasColumn(table, column) {
				t.Fatalf("table %s missing column %s", table, column)
			}
		}
	}
}

-- Reconstructed from the verified hosted schema backup.
-- These indexes were already present on the hosted project under this
-- migration version. IF NOT EXISTS keeps local application idempotent while
-- preserving the hosted migration history during promotion.

CREATE INDEX IF NOT EXISTS "idx_announcements_school_status_published"
  ON "public"."announcements" USING "btree" ("school_id", "status", "published_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_attendance_sessions_academic_year"
  ON "public"."attendance_sessions" USING "btree" ("academic_year_id");
CREATE INDEX IF NOT EXISTS "idx_attendance_sessions_reopened_by"
  ON "public"."attendance_sessions" USING "btree" ("reopened_by");
CREATE INDEX IF NOT EXISTS "idx_attendance_sessions_school_date_status"
  ON "public"."attendance_sessions" USING "btree" ("school_id", "date", "status");
CREATE INDEX IF NOT EXISTS "idx_attendance_sessions_subject"
  ON "public"."attendance_sessions" USING "btree" ("subject_id");
CREATE INDEX IF NOT EXISTS "idx_attendance_summaries_academic_year"
  ON "public"."attendance_summaries" USING "btree" ("academic_year_id");
CREATE INDEX IF NOT EXISTS "idx_attendance_summaries_school"
  ON "public"."attendance_summaries" USING "btree" ("school_id");
CREATE INDEX IF NOT EXISTS "idx_attendance_summaries_student"
  ON "public"."attendance_summaries" USING "btree" ("student_id");
CREATE INDEX IF NOT EXISTS "idx_attendance_summaries_term"
  ON "public"."attendance_summaries" USING "btree" ("term_id");
CREATE INDEX IF NOT EXISTS "idx_branch_memberships_user_school_active"
  ON "public"."branch_memberships" USING "btree" ("user_id", "school_id", "is_active");

CREATE INDEX IF NOT EXISTS "idx_fee_invoices_academic_year"
  ON "public"."fee_invoices" USING "btree" ("academic_year_id");
CREATE INDEX IF NOT EXISTS "idx_fee_invoices_daycare_plan"
  ON "public"."fee_invoices" USING "btree" ("daycare_plan_id");
CREATE INDEX IF NOT EXISTS "idx_fee_invoices_fee_structure"
  ON "public"."fee_invoices" USING "btree" ("fee_structure_id");
CREATE INDEX IF NOT EXISTS "idx_fee_invoices_school_status_amounts"
  ON "public"."fee_invoices" USING "btree" ("school_id", "status")
  INCLUDE ("balance", "paid_amount", "net_amount");
CREATE INDEX IF NOT EXISTS "idx_fee_invoices_school_student_status_amounts"
  ON "public"."fee_invoices" USING "btree" ("school_id", "student_id", "status")
  INCLUDE ("balance", "net_amount", "paid_amount");
CREATE INDEX IF NOT EXISTS "idx_fee_invoices_voided_by"
  ON "public"."fee_invoices" USING "btree" ("voided_by");

CREATE INDEX IF NOT EXISTS "idx_fee_structures_academic_year"
  ON "public"."fee_structures" USING "btree" ("academic_year_id");
CREATE INDEX IF NOT EXISTS "idx_fee_structures_archived_by"
  ON "public"."fee_structures" USING "btree" ("archived_by");
CREATE INDEX IF NOT EXISTS "idx_fee_structures_category"
  ON "public"."fee_structures" USING "btree" ("category_id");
CREATE INDEX IF NOT EXISTS "idx_fee_structures_fee_category"
  ON "public"."fee_structures" USING "btree" ("fee_category_id");
CREATE INDEX IF NOT EXISTS "idx_fee_structures_grade"
  ON "public"."fee_structures" USING "btree" ("grade_id");
CREATE INDEX IF NOT EXISTS "idx_fee_structures_section"
  ON "public"."fee_structures" USING "btree" ("section_id");
CREATE INDEX IF NOT EXISTS "idx_frontend_records_school_table_updated"
  ON "public"."frontend_records" USING "btree" ("school_id", "table_name", "updated_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_leave_applications_school_status"
  ON "public"."leave_applications" USING "btree" ("school_id", "status");
CREATE INDEX IF NOT EXISTS "idx_notification_events_queue"
  ON "public"."notification_events" USING "btree" ("processed", "retry_count", "next_retry_at", "created_at");
CREATE INDEX IF NOT EXISTS "idx_parent_payment_requests_school_status"
  ON "public"."parent_payment_requests" USING "btree" ("school_id", "status");
CREATE INDEX IF NOT EXISTS "idx_parent_student_links_student"
  ON "public"."parent_student_links" USING "btree" ("student_id");

CREATE INDEX IF NOT EXISTS "idx_sections_academic_year"
  ON "public"."sections" USING "btree" ("academic_year_id");
CREATE INDEX IF NOT EXISTS "idx_sections_class_teacher_school"
  ON "public"."sections" USING "btree" ("class_teacher_id", "school_id");
CREATE INDEX IF NOT EXISTS "idx_sections_co_teacher_school"
  ON "public"."sections" USING "btree" ("co_teacher_id", "school_id");
CREATE INDEX IF NOT EXISTS "idx_sections_room"
  ON "public"."sections" USING "btree" ("room_id");
CREATE INDEX IF NOT EXISTS "idx_student_attendances_session_status_created"
  ON "public"."student_attendances" USING "btree" ("session_id", "status", "created_at");
CREATE INDEX IF NOT EXISTS "idx_students_school_active_section_not_test"
  ON "public"."students" USING "btree" ("school_id", "status", "current_section_id")
  WHERE ("is_test_account" = false);

CREATE INDEX IF NOT EXISTS "idx_timetable_slots_academic_year"
  ON "public"."timetable_slots" USING "btree" ("academic_year_id");
CREATE INDEX IF NOT EXISTS "idx_timetable_slots_room"
  ON "public"."timetable_slots" USING "btree" ("room_id");
CREATE INDEX IF NOT EXISTS "idx_timetable_slots_school_section_day"
  ON "public"."timetable_slots" USING "btree" ("school_id", "section_id", "academic_year_id", "day_of_week");
CREATE INDEX IF NOT EXISTS "idx_timetable_slots_school_staff_day"
  ON "public"."timetable_slots" USING "btree" ("school_id", "staff_id", "academic_year_id", "day_of_week");
CREATE INDEX IF NOT EXISTS "idx_timetable_slots_staff"
  ON "public"."timetable_slots" USING "btree" ("staff_id");
CREATE INDEX IF NOT EXISTS "idx_timetable_slots_subject"
  ON "public"."timetable_slots" USING "btree" ("subject_id");

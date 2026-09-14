-- P0/P1 paging support: keep interactive filters index-backed and expose the
-- finance dashboard aggregates without loading the invoice ledger into the UI.

CREATE INDEX IF NOT EXISTS idx_students_school_status_section_admission
  ON public.students (school_id, status, current_section_id, admission_number, id)
  WHERE is_test_account = false;

CREATE INDEX IF NOT EXISTS idx_staff_school_active_name
  ON public.staff (school_id, is_active, last_name, first_name, id);

CREATE INDEX IF NOT EXISTS idx_users_school_role_active_name
  ON public.users (school_id, role_name, is_active, name, id);

CREATE INDEX IF NOT EXISTS idx_account_approvals_school_status_created
  ON public.account_approvals (school_id, status, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_approval_requests_school_status_created
  ON public.approval_requests (school_id, status, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_leave_applications_school_status_created
  ON public.leave_applications (school_id, status, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_student_leave_school_status_created
  ON public.student_leave_applications (school_id, status, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_payment_requests_school_status_created
  ON public.parent_payment_requests (school_id, status, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_conversations_school_updated
  ON public.message_conversations (school_id, updated_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_messages_school_conversation_created
  ON public.messages (school_id, conversation_id, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_messages_school_conversation_sent
  ON public.messages (school_id, conversation_id, sent_at ASC, id);

CREATE INDEX IF NOT EXISTS idx_attendance_sessions_school_date
  ON public.attendance_sessions (school_id, date DESC, id);

CREATE INDEX IF NOT EXISTS idx_frontend_records_school_table_updated
  ON public.frontend_records (school_id, table_name, updated_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_diary_entries_school_date
  ON public.diary_entries (school_id, date DESC, id);

CREATE INDEX IF NOT EXISTS idx_event_posts_school_status_created
  ON public.event_posts (school_id, status, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_issues_school_status_created
  ON public.issues (school_id, status, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read_created
  ON public.notification_logs (user_id, is_read, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_admissions_school_submitted
  ON public.admission_inquiries (school_id, submitted_at DESC, id);

CREATE OR REPLACE FUNCTION public.fee_dashboard_summary(
  p_school_id uuid,
  p_academic_year_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH invoices AS (
    SELECT
      fi.student_id,
      fi.net_amount,
      fi.paid_amount,
      fi.balance,
      fi.due_date
    FROM public.fee_invoices fi
    WHERE fi.school_id = p_school_id
      AND (p_academic_year_id IS NULL OR fi.academic_year_id = p_academic_year_id)
      AND lower(coalesce(fi.status, '')) NOT IN ('cancelled', 'void', 'voided')
  ), totals AS (
    SELECT
      coalesce(sum(net_amount), 0) AS billed,
      coalesce(sum(paid_amount), 0) AS collected,
      coalesce(sum(balance), 0) AS outstanding,
      coalesce(sum(CASE WHEN balance > 0 AND due_date < current_date THEN balance ELSE 0 END), 0) AS overdue,
      count(*) AS invoice_count,
      count(*) FILTER (WHERE balance > 0 AND due_date < current_date) AS overdue_count
    FROM invoices
  ), requests AS (
    SELECT count(*) AS pending_count
    FROM public.parent_payment_requests pr
    WHERE pr.school_id = p_school_id
      AND lower(coalesce(pr.status, '')) IN ('pending', 'pending_verification', 'resubmitted', 'submitted')
  )
  SELECT jsonb_build_object(
    'billed', totals.billed,
    'collected', totals.collected,
    'outstanding', totals.outstanding,
      'overdue', totals.overdue,
      'invoice_count', totals.invoice_count,
      'student_count', (SELECT count(DISTINCT student_id) FROM invoices),
      'overdue_count', totals.overdue_count,
    'pending_request_count', requests.pending_count
  )
  FROM totals CROSS JOIN requests;
$$;

REVOKE ALL ON FUNCTION public.fee_dashboard_summary(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fee_dashboard_summary(uuid, uuid) TO service_role;

-- Keep approval decisions in the existing tenant-scoped activity ledger.
-- The trigger runs in the same transaction as the decision, so a decision
-- cannot silently succeed without its audit entry.
ALTER TABLE public.fee_concessions
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES public.users(id);

ALTER TABLE public.event_posts
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES public.users(id);

CREATE INDEX IF NOT EXISTS audit_logs_approval_actor_recent_idx
  ON public.audit_logs (school_id, user_id, created_at DESC)
  WHERE module = 'approvals';

CREATE OR REPLACE FUNCTION public.record_approval_decision_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  previous_row jsonb;
  current_row jsonb;
  previous_status text;
  current_status text;
  school uuid;
  actor uuid;
  actor_display_name text;
  actor_display_role text;
  reviewer_note text;
  audit_details jsonb;
BEGIN
  current_row := to_jsonb(NEW);
  IF TG_OP = 'UPDATE' THEN
    previous_row := to_jsonb(OLD);
    previous_status := lower(coalesce(previous_row ->> 'status', ''));
  END IF;
  current_status := lower(coalesce(current_row ->> 'status', ''));

  IF current_status NOT IN (
    'approved', 'rejected', 'changes_requested', 'clarification_required'
  ) THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND previous_status = current_status THEN
    RETURN NEW;
  END IF;

  school := nullif(current_row ->> 'school_id', '')::uuid;
  actor := coalesce(
    nullif(current_row ->> TG_ARGV[0], '')::uuid,
    nullif(current_row ->> 'approved_by', '')::uuid,
    nullif(current_row ->> 'created_by', '')::uuid
  );
  IF school IS NULL OR actor IS NULL THEN
    RAISE EXCEPTION 'Approval audit requires school and reviewer identity (table %, row %)',
      TG_TABLE_NAME, current_row ->> 'id'
      USING ERRCODE = '23502';
  END IF;

  SELECT coalesce(nullif(u.name, ''), nullif(u.username, '')),
         nullif(u.role_name, '')
    INTO actor_display_name, actor_display_role
    FROM public.users AS u
   WHERE u.id = actor AND u.school_id = school;

  actor_display_name := coalesce(actor_display_name, left(actor::text, 8));
  actor_display_role := coalesce(actor_display_role, 'unknown');
  reviewer_note := nullif(left(coalesce(current_row ->> TG_ARGV[1], ''), 1000), '');
  audit_details := jsonb_build_object(
    'from_status', nullif(previous_status, ''),
    'to_status', current_status,
    'source_table', TG_TABLE_NAME
  );
  IF current_row ? 'module' THEN
    audit_details := audit_details || jsonb_build_object(
      'approval_module', current_row ->> 'module'
    );
  END IF;
  IF current_row ? 'operation_type' THEN
    audit_details := audit_details || jsonb_build_object(
      'operation_type', current_row ->> 'operation_type'
    );
  END IF;
  IF reviewer_note IS NOT NULL THEN
    audit_details := audit_details || jsonb_build_object('review_note', reviewer_note);
  END IF;

  INSERT INTO public.audit_logs (
    school_id, user_id, action, entity_type, entity_id, details,
    module, event_type, summary, actor_role, actor_name
  ) VALUES (
    school,
    actor,
    'approval.' || current_status,
    TG_TABLE_NAME,
    current_row ->> 'id',
    audit_details,
    'approvals',
    'approval_' || current_status,
    format('%s %s %s', actor_display_name, replace(current_status, '_', ' '),
      initcap(replace(TG_TABLE_NAME, '_', ' '))),
    actor_display_role,
    actor_display_name
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE LOG 'approval_audit_write_failed table=% row_id=% sqlstate=% error=%',
    TG_TABLE_NAME, coalesce(current_row ->> 'id', '<unknown>'), SQLSTATE, SQLERRM;
  RAISE EXCEPTION USING
    MESSAGE = 'approval_audit_write_failed: ' || SQLERRM,
    ERRCODE = SQLSTATE;
END;
$$;

REVOKE ALL ON FUNCTION public.record_approval_decision_audit()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER approval_requests_audit_decision
  AFTER INSERT OR UPDATE OF status ON public.approval_requests
  FOR EACH ROW EXECUTE FUNCTION public.record_approval_decision_audit('reviewed_by', 'review_note');

CREATE TRIGGER account_approvals_audit_decision
  AFTER INSERT OR UPDATE OF status ON public.account_approvals
  FOR EACH ROW EXECUTE FUNCTION public.record_approval_decision_audit('reviewed_by', '');

CREATE TRIGGER leave_applications_audit_decision
  AFTER INSERT OR UPDATE OF status ON public.leave_applications
  FOR EACH ROW EXECUTE FUNCTION public.record_approval_decision_audit('reviewed_by', 'review_note');

CREATE TRIGGER student_leave_applications_audit_decision
  AFTER INSERT OR UPDATE OF status ON public.student_leave_applications
  FOR EACH ROW EXECUTE FUNCTION public.record_approval_decision_audit('reviewed_by', 'rejection_reason');

CREATE TRIGGER fee_concessions_audit_decision
  AFTER INSERT OR UPDATE OF status ON public.fee_concessions
  FOR EACH ROW EXECUTE FUNCTION public.record_approval_decision_audit('reviewed_by', '');

CREATE TRIGGER parent_payment_requests_audit_decision
  AFTER INSERT OR UPDATE OF status ON public.parent_payment_requests
  FOR EACH ROW EXECUTE FUNCTION public.record_approval_decision_audit('reviewed_by', 'admin_remarks');

CREATE TRIGGER event_posts_audit_decision
  AFTER INSERT OR UPDATE OF status ON public.event_posts
  FOR EACH ROW EXECUTE FUNCTION public.record_approval_decision_audit('reviewed_by', 'rejection_reason');

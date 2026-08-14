-- Legacy initiated drafts are "Awaiting Proof" history, not principal-reviewable
-- approvals. Do not let a stranded initiated draft block the new atomic proof
-- submission endpoint from creating a reviewable request.

drop index if exists public.parent_payment_requests_active_invoice_parent_key;

create unique index parent_payment_requests_active_invoice_parent_key
  on public.parent_payment_requests(school_id, invoice_id, parent_user_id)
  where parent_user_id is not null
    and status in (
      'pending', 'pending_verification',
      'submitted', 'clarification_required', 'resubmitted'
    );

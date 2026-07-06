-- ============================================================
-- Migration 0024: Orphaned Fee Data Cleanup
-- Reconciles all existing orphaned fee data across all schools.
--
-- Problem: Invoices created through the payment request flow may
-- not have a fee_structure_id link. When fee structures are
-- deleted, these orphaned invoices remain and inflate collected
-- and outstanding totals.
--
-- This migration deletes all unpaid/partially-paid invoices that
-- have fee_structure_id IS NULL along with their associated
-- workflow rows (payments, receipts, parent_payment_requests,
-- fee_invoice_items).
-- ============================================================

-- 1. Collect IDs of orphaned unpaid invoices (fee_structure_id IS NULL, status != 'paid')
-- 2. Delete child rows first, then the invoices themselves
-- 3. Use a DO block so we can report what was cleaned up

DO $$
DECLARE
  orphan_ids uuid[];
  deleted_invoices int := 0;
  deleted_payments int := 0;
  deleted_receipts int := 0;
  deleted_requests int := 0;
  deleted_items int := 0;
BEGIN
  -- Collect orphaned invoice IDs
  SELECT array_agg(fi.id) INTO orphan_ids
  FROM public.fee_invoices fi
  WHERE fi.fee_structure_id IS NULL
    AND fi.status NOT IN ('paid', 'cancelled');

  -- If no orphaned invoices, nothing to do
  IF orphan_ids IS NULL OR array_length(orphan_ids, 1) = 0 THEN
    RAISE NOTICE 'No orphaned fee invoices found. Nothing to clean up.';
    RETURN;
  END IF;

  RAISE NOTICE 'Found % orphaned unpaid fee invoices to clean up', array_length(orphan_ids, 1);

  -- Delete fee_receipts linked to payments of these invoices
  DELETE FROM public.fee_receipts
  WHERE payment_id IN (
    SELECT p.id FROM public.payments p
    WHERE p.invoice_id = ANY(orphan_ids)
  );
  GET DIAGNOSTICS deleted_receipts = ROW_COUNT;
  RAISE NOTICE 'Deleted % fee_receipts', deleted_receipts;

  -- Delete parent_payment_requests linked to these invoices
  DELETE FROM public.parent_payment_requests
  WHERE invoice_id = ANY(orphan_ids);
  GET DIAGNOSTICS deleted_requests = ROW_COUNT;
  RAISE NOTICE 'Deleted % parent_payment_requests', deleted_requests;

  -- Delete payments linked to these invoices
  DELETE FROM public.payments
  WHERE invoice_id = ANY(orphan_ids);
  GET DIAGNOSTICS deleted_payments = ROW_COUNT;
  RAISE NOTICE 'Deleted % payments', deleted_payments;

  -- Delete fee_invoice_items linked to these invoices
  DELETE FROM public.fee_invoice_items
  WHERE invoice_id = ANY(orphan_ids);
  GET DIAGNOSTICS deleted_items = ROW_COUNT;
  RAISE NOTICE 'Deleted % fee_invoice_items', deleted_items;

  -- Finally delete the orphaned invoices themselves
  DELETE FROM public.fee_invoices
  WHERE id = ANY(orphan_ids);
  GET DIAGNOSTICS deleted_invoices = ROW_COUNT;
  RAISE NOTICE 'Deleted % orphaned fee_invoices', deleted_invoices;

  RAISE NOTICE 'Orphaned fee data cleanup complete: % invoices, % payments, % receipts, % requests, % items removed',
    deleted_invoices, deleted_payments, deleted_receipts, deleted_requests, deleted_items;
END $$;

-- Migration 0025: Promote staff_attendances check_in/check_out from time to timestamptz
-- Previously these columns were PostgreSQL `time` (time-of-day only), which caused
-- the Flutter client to lose the date component.  Changing to `timestamptz` preserves
-- the full datetime so the time persists across day boundaries.

-- Combine date + time into a proper timestamptz in a single ALTER.
-- The USING clause handles the conversion atomically: it takes the existing
-- `time` value, combines it with the `date` column, and interprets the result
-- as UTC to produce a timestamptz.
ALTER TABLE public.staff_attendances
  ALTER COLUMN check_in  TYPE timestamptz USING (date + check_in)  AT TIME ZONE 'UTC',
  ALTER COLUMN check_out TYPE timestamptz USING (date + check_out) AT TIME ZONE 'UTC';

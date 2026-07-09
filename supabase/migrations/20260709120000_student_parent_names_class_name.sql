-- ============================================================
-- Migration: Add class_name and parent name columns to students
-- Supports the new Google Sheets parameter scheme:
--   class_name, father_first_name, father_last_name,
--   mother_first_name, mother_last_name
-- ============================================================

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS class_name        text,
  ADD COLUMN IF NOT EXISTS father_first_name text,
  ADD COLUMN IF NOT EXISTS father_last_name  text,
  ADD COLUMN IF NOT EXISTS mother_first_name text,
  ADD COLUMN IF NOT EXISTS mother_last_name  text;

COMMENT ON COLUMN public.students.class_name IS
  'Grade/class label (e.g. "Grade 5") from Google Sheets sync or manual entry.';
COMMENT ON COLUMN public.students.father_first_name IS
  'Father first name — used for guardian records and Google Sheets sync.';
COMMENT ON COLUMN public.students.father_last_name IS
  'Father last name — used for guardian records and Google Sheets sync.';
COMMENT ON COLUMN public.students.mother_first_name IS
  'Mother first name — used for guardian records and Google Sheets sync.';
COMMENT ON COLUMN public.students.mother_last_name IS
  'Mother last name — used for guardian records and Google Sheets sync.';

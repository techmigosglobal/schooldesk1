-- ============================================================
-- Migration: Rename student_code to student_id_number
-- ============================================================

ALTER TABLE public.students 
  RENAME COLUMN student_code TO student_id_number;

COMMENT ON COLUMN public.students.student_id_number IS 
  'Unique code or ID number representing the student, synchronized from external systems or Google Sheets.';

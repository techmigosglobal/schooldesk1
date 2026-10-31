import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

// Callers must authorize the individual student first. Keep both routes on the
// same school-scoped, student-scoped history, including previous classes/years.
export async function studentAttendanceHistory(
  svc: SupabaseClient,
  school: string,
  student: string,
  year: string | null,
  month: string | null,
): Promise<{ data: Record<string, unknown>[]; error: { message: string } | null }> {
  let from = "";
  let to = "";
  if (year || month) {
    const yyyy = Number(year);
    const mm = Number(month);
    if (!/^\d{4}$/.test(year ?? "") || !/^\d{1,2}$/.test(month ?? "") ||
      yyyy < 1900 || mm < 1 || mm > 12) {
      return { data: [], error: { message: "Choose a valid attendance year and month" } };
    }
    from = `${year}-${String(mm).padStart(2, "0")}-01`;
    to = `${year}-${String(mm).padStart(2, "0")}-${new Date(Date.UTC(yyyy, mm, 0)).getUTCDate()}`;
  }
  const data: Record<string, unknown>[] = [];
  const batchSize = 1000;
  for (let offset = 0;; offset += batchSize) {
    let query = svc.from("student_attendances").select(
      "*, session:attendance_sessions!inner(*, section:sections(id, section_name, grade:grades(id, grade_name)), academic_year:academic_years(id, year_label))",
    ).eq("student_id", student).eq("session.school_id", school);
    if (from) query = query.gte("session.date", from).lte("session.date", to);
    const result = await query.order("created_at", { ascending: false })
      .order("id", { ascending: false }).range(offset, offset + batchSize - 1);
    if (result.error) return { data: [], error: result.error };
    const rows = result.data ?? [];
    data.push(...rows);
    if (rows.length < batchSize) return { data, error: null };
  }
}

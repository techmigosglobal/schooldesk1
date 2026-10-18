import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
export function dateInZone(zone: string, now = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: zone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const part = (kind: string) =>
    parts.find((value) => value.type === kind)?.value;
  return `${part("year")}-${part("month")}-${part("day")}`;
}
export function validSchoolDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T12:00:00Z`);
  return !Number.isNaN(parsed.getTime()) &&
    parsed.toISOString().slice(0, 10) === value;
}

export type AttendanceYearDates = {
  id: string;
  start_date: string | null;
  end_date: string | null;
  is_current: boolean;
};

/** Date-only values are school calendar dates, never device-local instants. */
export function attendanceDateContext(
  year: AttendanceYearDates | null,
  today: string,
) {
  const base = {
    academic_year_id: year?.id ?? null,
    academic_year_start: year?.start_date ?? null,
    academic_year_end: year?.end_date ?? null,
    school_date: today,
    min_date: null as string | null,
    max_date: null as string | null,
    configuration_status: "missing_year",
    message: null as string | null,
  };
  if (!year) {
    return {
      ...base,
      message:
        "Ask school leadership to configure the academic year for this class.",
    };
  }
  if (
    !year.is_current || !year.start_date || !validSchoolDate(year.start_date) ||
    (year.end_date != null &&
      (!validSchoolDate(year.end_date) || year.end_date < year.start_date))
  ) {
    return {
      ...base,
      configuration_status: "invalid_year",
      message:
        "Ask school leadership to check this class's current academic year and dates.",
    };
  }
  if (year.start_date > today) {
    return {
      ...base,
      configuration_status: "not_started",
      message:
        `This academic year starts on ${year.start_date}. Attendance cannot be marked yet.`,
    };
  }
  const ended = Boolean(year.end_date && year.end_date < today);
  return {
    ...base,
    min_date: year.start_date,
    max_date: ended ? year.end_date : today,
    configuration_status: ended ? "ended" : "ready",
    message: ended
      ? `This academic year ended on ${year.end_date}. Choose an earlier date or ask school leadership to update the academic year.`
      : null,
  };
}
export async function schoolDay(svc: SupabaseClient, school: string) {
  const { data, error } = await svc.from("schools").select(
    "timezone,name,display_name",
  ).eq("id", school).single();
  if (error) throw new Error(error.message);
  return {
    date: dateInZone(data.timezone || "Asia/Kolkata"),
    name: String(data.display_name || data.name || "School"),
  };
}
export async function validateTeacherAttendanceDate(
  svc: SupabaseClient,
  school: string,
  yearId: string,
  date: string,
) {
  if (!validSchoolDate(date)) return "Choose a valid attendance date";
  const [{ data: year, error }, day] = await Promise.all([
    svc.from("academic_years").select("start_date,end_date,is_current").eq(
      "school_id",
      school,
    ).eq("id", yearId).maybeSingle(),
    schoolDay(svc, school),
  ]);
  if (error) throw new Error(error.message);
  const context = attendanceDateContext(
    year ? { ...year, id: yearId } : null,
    day.date,
  );
  if (!context.min_date || !context.max_date) return context.message;
  if (date < context.min_date || date > context.max_date) {
    return "Choose a date within the current academic year through today";
  }
  return null;
}

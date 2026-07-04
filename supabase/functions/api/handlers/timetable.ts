// handlers/timetable.ts
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}

function textValue(value: unknown, fallback = ""): string {
  const text = `${value ?? ""}`.trim();
  return text || fallback;
}

function intValue(value: unknown, fallback: number): number {
  const parsed = Number.parseInt(`${value ?? ""}`, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function addMinutes(time: string, minutes: number): string {
  const [hoursText, minutesText] = textValue(time, "08:30").split(":");
  const baseHours = intValue(hoursText, 8);
  const baseMinutes = intValue(minutesText, 30);
  const total = baseHours * 60 + baseMinutes + minutes;
  const hours = Math.floor(total / 60) % 24;
  const mins = total % 60;
  return `${`${hours}`.padStart(2, "0")}:${`${mins}`.padStart(2, "0")}`;
}

async function resolveSectionDefaultStaffId(
  svc: SupabaseClient,
  school: string,
  sectionId: string,
): Promise<string> {
  if (!sectionId) return "";
  const { data: section, error } = await svc.from("sections").select(
    "class_teacher_id, co_teacher_id",
  ).eq("id", sectionId).eq("school_id", school).maybeSingle();
  if (error) throw error;
  return textValue(section?.class_teacher_id) || textValue(section?.co_teacher_id);
}

type Assignment = {
  subject_id: string | null;
  subject_name: string;
};

type BreakDraft = {
  name: string;
  start_time: string;
  end_time: string;
  days: number[];
};

async function buildClassSubjectAssignments(
  svc: SupabaseClient,
  school: string,
  sectionId: string,
  academicYearId: string,
): Promise<Assignment[]> {
  const { data: section, error: sectionError } = await svc.from("sections")
    .select("id, grade_id").eq("id", sectionId).eq("school_id", school)
    .maybeSingle();
  if (sectionError) throw sectionError;

  const gradeId = textValue(section?.grade_id);
  if (!gradeId) return [];

  const { data: gradeSubjectRows, error: gradeSubjectError } = await svc.from(
    "grade_subjects",
  ).select("subject_id, subject:subjects(subject_name)").eq("school_id", school)
    .eq("grade_id", gradeId).or(`section_id.eq.${sectionId},section_id.is.null`)
    .or(`academic_year_id.eq.${academicYearId},academic_year_id.is.null`);
  if (gradeSubjectError) throw gradeSubjectError;

  const seen = new Set<string>();
  return (gradeSubjectRows ?? []).map((row: Record<string, unknown>) => {
    const subject = row.subject && typeof row.subject === "object"
      ? row.subject as Record<string, unknown>
      : {};
    const subjectId = textValue(row.subject_id);
    if (!subjectId || seen.has(subjectId)) return null;
    seen.add(subjectId);
    return {
      subject_id: subjectId,
      subject_name: textValue(subject.subject_name, "General"),
    };
  }).filter(Boolean) as Assignment[];
}

function parseBreaks(value: unknown, defaultDays: number[]): BreakDraft[] {
  if (!Array.isArray(value)) return [];
  return value.map((raw) => {
    const row = (raw ?? {}) as Record<string, unknown>;
    const days = Array.isArray(row.days) && row.days.length > 0
      ? row.days.map((day) => intValue(day, 0)).filter((day) =>
        day >= 1 && day <= 7
      )
      : defaultDays;
    return {
      name: textValue(row.name || row.label, "Break"),
      start_time: textValue(row.start_time),
      end_time: textValue(row.end_time),
      days,
    };
  }).filter((row) => row.start_time && row.end_time);
}

function minutesOf(time: string): number | null {
  const match = textValue(time).match(/^(\d{1,2}):(\d{2})/);
  if (!match) return null;
  const hours = intValue(match[1], -1);
  const mins = intValue(match[2], -1);
  if (hours < 0 || hours > 23 || mins < 0 || mins > 59) return null;
  return hours * 60 + mins;
}

function distributeSubjectsBalancedWeekly(
  assignments: Assignment[],
  index: number,
): Assignment {
  if (assignments.length === 0) {
    return {
      subject_id: null,
      subject_name: "Study Period",
    };
  }
  return assignments[index % assignments.length];
}

async function generateSlots(
  svc: SupabaseClient,
  school: string,
  body: Record<string, unknown>,
) {
  const sectionId = textValue(body.section_id);
  const academicYearId = textValue(body.academic_year_id);
  if (!sectionId || !academicYearId) {
    throw new Error("section_id and academic_year_id required");
  }

  const days = Array.isArray(body.days) && body.days.length > 0
    ? body.days.map((value) => intValue(value, 1)).filter((value) =>
      value >= 1 && value <= 7
    )
    : [intValue(body.day_of_week, 1)];
  const periodsPerDay = Math.max(1, intValue(body.periods_per_day, 7));
  const startTime = textValue(body.start_time, "08:30");
  const defaultStaffId = await resolveSectionDefaultStaffId(svc, school, sectionId);
  const periodDuration = Math.max(
    20,
    intValue(body.period_duration_minutes, 40),
  );
  const gapMinutes = Math.max(0, intValue(body.gap_minutes, 5));
  const assignments = await buildClassSubjectAssignments(svc, school, sectionId, academicYearId);
  const endTime = textValue(body.end_time);
  const breaks = parseBreaks(body.breaks, days);
  const startMinutes = minutesOf(startTime);
  const endMinutes = minutesOf(endTime);
  const useEndBound = startMinutes !== null && endMinutes !== null &&
    endMinutes > startMinutes;
  const breaksByDay = new Map<number, BreakDraft[]>();
  for (const day of days) breaksByDay.set(day, []);
  for (const item of breaks) {
    for (const day of item.days) {
      if (!breaksByDay.has(day)) continue;
      breaksByDay.get(day)!.push(item);
    }
  }
  for (const dayBreaks of breaksByDay.values()) {
    dayBreaks.sort((a, b) =>
      (minutesOf(a.start_time) ?? 0) - (minutesOf(b.start_time) ?? 0)
    );
  }

  const generated = [];
  let assignmentIndex = 0;
  for (const day of days) {
    let cursor = startTime;
    let period = 1;
    const dayBreaks = breaksByDay.get(day) ?? [];
    let breakIndex = 0;
    while (period <= periodsPerDay) {
      const cursorMinutes = minutesOf(cursor);
      const nextBreak = dayBreaks[breakIndex];
      const nextBreakStart = nextBreak ? minutesOf(nextBreak.start_time) : null;
      if (
        nextBreak &&
        cursorMinutes !== null &&
        nextBreakStart !== null &&
        cursorMinutes >= nextBreakStart
      ) {
        generated.push({
          school_id: school,
          section_id: sectionId,
          academic_year_id: academicYearId,
          term_id: textValue(body.term_id) || null,
          subject_id: null,
          staff_id: null,
          room_id: textValue(body.room_id) || null,
          day_of_week: day,
          period_number: period,
          start_time: nextBreak.start_time,
          end_time: nextBreak.end_time,
          slot_type: "break",
          subject_name: nextBreak.name,
        });
        cursor = addMinutes(nextBreak.end_time, gapMinutes);
        period += 1;
        breakIndex += 1;
        continue;
      }
      const start = cursor;
      const end = addMinutes(start, periodDuration);
      const endMinutesForSlot = minutesOf(end);
      if (useEndBound && endMinutesForSlot !== null && endMinutesForSlot > endMinutes!) {
        break;
      }
      const assignment = distributeSubjectsBalancedWeekly(assignments, assignmentIndex);
      generated.push({
        school_id: school,
        section_id: sectionId,
        academic_year_id: academicYearId,
        term_id: textValue(body.term_id) || null,
        subject_id: assignment.subject_id,
        staff_id: defaultStaffId || null,
        room_id: textValue(body.room_id) || null,
        day_of_week: day,
        period_number: period,
        start_time: start,
        end_time: end,
        slot_type: "regular",
        subject_name: assignment.subject_name,
      });
      assignmentIndex += 1;
      cursor = addMinutes(end, gapMinutes);
      period += 1;
    }
  }
  return generated;
}

export async function handleTimetable(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const body = method !== "GET" ? await req.json().catch(() => ({})) : {};

  if (path === "/timetable/slots" || path === "/timetable") {
    if (method === "GET") {
      let q = svc.from("timetable_slots").select(
        "*, section:sections(*, grade:grades(*)), subject:subjects(*), staff:staff(*), room:rooms(*)",
      ).eq("school_id", school);
      if (url.searchParams.get("section_id")) q = q.eq("section_id", url.searchParams.get("section_id")!);
      if (url.searchParams.get("staff_id")) q = q.eq("staff_id", url.searchParams.get("staff_id")!);
      if (url.searchParams.get("academic_year_id")) q = q.eq("academic_year_id", url.searchParams.get("academic_year_id")!);
      const { data, error } = await q.order("day_of_week").order("start_time");
      if (error) return fail(error.message);
      return ok(data ?? []);
    }
    if (method === "DELETE") {
      let q = svc.from("timetable_slots").delete().eq("school_id", school);
      if (url.searchParams.get("section_id")) q = q.eq("section_id", url.searchParams.get("section_id")!);
      if (url.searchParams.get("academic_year_id")) q = q.eq("academic_year_id", url.searchParams.get("academic_year_id")!);
      const { error } = await q;
      if (error) return fail(error.message);
      return ok({ success: true });
    }
    if (method === "POST") {
      const { term_id: _ignoredTermId, ...payload } = body as Record<
        string,
        unknown
      >;
      const sectionId = textValue(payload.section_id);
      const slotType = textValue(payload.slot_type, "regular");
      const resolvedStaffId = textValue(payload.staff_id);
      const defaultStaffId = await resolveSectionDefaultStaffId(svc, school, sectionId);
      const finalStaffId = slotType === "break" || slotType === "free" || !textValue(payload.subject_id)
        ? null
        : resolvedStaffId || defaultStaffId || null;
      const { data, error } = await svc.from("timetable_slots").insert({
        ...payload,
        staff_id: finalStaffId,
        school_id: school,
      }).select(
        "*, subject:subjects(*), staff:staff(*), section:sections(*, grade:grades(*)), room:rooms(*)",
      ).single();
      if (error) return fail(error.message);
      return ok(data);
    }
  }

  const slotMatch = path.match(/^\/timetable\/slots\/([^/]+)$/);
  if (slotMatch) {
    if (method === "PATCH" || method === "PUT") {
      const { term_id: _ignoredTermId, ...payload } = body as Record<
        string,
        unknown
      >;
      const sectionId = textValue(payload.section_id);
      const slotType = textValue(payload.slot_type, "regular");
      const resolvedStaffId = textValue(payload.staff_id);
      const defaultStaffId = await resolveSectionDefaultStaffId(svc, school, sectionId);
      const finalStaffId = slotType === "break" || slotType === "free" || !textValue(payload.subject_id)
        ? null
        : resolvedStaffId || defaultStaffId || null;
      const { data, error } = await svc.from("timetable_slots").update({
        ...payload,
        staff_id: finalStaffId,
        updated_at: new Date().toISOString(),
      }).eq("id", slotMatch[1]).eq("school_id", school).select(
        "*, subject:subjects(*), staff:staff(*), section:sections(*, grade:grades(*)), room:rooms(*)",
      ).single();
      if (error) return fail(error.message);
      return ok(data);
    }
    if (method === "DELETE") {
      await svc.from("timetable_slots").delete().eq("id", slotMatch[1]).eq(
        "school_id",
        school,
      );
      return ok({ success: true });
    }
  }

  if (path === "/timetable/overview") {
    const { data, error } = await svc.from("timetable_slots").select(
      "*, section:sections(*, grade:grades(*)), subject:subjects(*), staff:staff(*)",
    ).eq("school_id", school);
    if (error) return fail(error.message);
    return ok({ slots: data ?? [] });
  }

  if (path === "/timetable/templates" && method === "GET") {
    const { data, error } = await svc.from("timetable_templates").select("*")
      .eq("school_id", school).order("created_at", { ascending: false });
    if (error) return fail(error.message);
    return ok((data ?? []).map((row: Record<string, unknown>) => ({
      id: row.id,
      name: row.name,
      ...((row.config as Record<string, unknown> | null) ?? {}),
    })));
  }

  if (path === "/timetable/templates" && method === "PUT") {
    const id = textValue(body.id);
    const payload = {
      school_id: school,
      name: textValue(body.name, "Class setup smart timetable"),
      config: {
        academic_year_id: textValue(body.academic_year_id),
        working_days: body.working_days ?? [1, 2, 3, 4, 5, 6],
        periods_per_day: intValue(body.periods_per_day, 8),
        period_duration_minutes: intValue(body.period_duration_minutes, 40),
        gap_minutes: intValue(body.gap_minutes, 5),
        start_time: textValue(body.start_time, "08:30"),
        end_time: textValue(body.end_time),
        breaks: body.breaks ?? [],
        is_default: body.is_default ?? true,
      },
    };
    if (id) {
      const { data, error } = await svc.from("timetable_templates").update(
        payload,
      ).eq("id", id).eq("school_id", school).select().single();
      if (error) return fail(error.message);
      return ok({
        id: data.id,
        name: data.name,
        ...((data.config as Record<string, unknown> | null) ?? {}),
      });
    }
    const { data, error } = await svc.from("timetable_templates").insert(
      payload,
    ).select().single();
    if (error) return fail(error.message);
    return ok({
      id: data.id,
      name: data.name,
      ...((data.config as Record<string, unknown> | null) ?? {}),
    });
  }

  if (
    path === "/timetable/suggestions" || path === "/timetable/slots/generate" ||
    path === "/timetable/smart/preview" || path === "/timetable/smart/generate"
  ) {
    try {
      const generated = await generateSlots(
        svc,
        school,
        body as Record<string, unknown>,
      );
      if (
        path === "/timetable/slots/generate" ||
        path === "/timetable/smart/generate"
      ) {
        const sectionId = textValue(body.section_id);
        const academicYearId = textValue(body.academic_year_id);
        const days = [...new Set(generated.map((slot) => slot.day_of_week))];
        await svc.from("timetable_slots").delete().eq("school_id", school).eq(
          "section_id",
          sectionId,
        ).eq("academic_year_id", academicYearId).in("day_of_week", days);
        const rows = generated.map(
          ({
            subject_name: _ignoredSubject,
            term_id: _ignoredTerm,
            ...slot
          }) => slot,
        );
        const { data, error } = await svc.from("timetable_slots").insert(rows)
          .select(
            "*, section:sections(*, grade:grades(*)), subject:subjects(*), staff:staff(*), room:rooms(*)",
          );
        if (error) return fail(error.message);
        return ok({
          generated_count: data?.length ?? 0,
          slots: data ?? [],
        });
      }
      return ok({
        generated_count: generated.length,
        slots: generated,
      });
    } catch (error) {
      return fail(error instanceof Error ? error.message : "failed to generate timetable");
    }
  }

  if (path === "/timetable/pre-primary/apply" && method === "POST") {
    try {
      const scheduleType = textValue(body.schedule_type, "nursery");
      const periodsPerDay = scheduleType === "nursery"
        ? 6
        : scheduleType === "lkg"
        ? 7
        : 8;
      const generated = await generateSlots(svc, school, {
        ...body,
        days: [1, 2, 3, 4, 5],
        periods_per_day: periodsPerDay,
        start_time: "08:30",
        period_duration_minutes: 35,
        gap_minutes: 5,
      });
      const sectionId = textValue(body.section_id);
      const academicYearId = textValue(body.academic_year_id);
      await svc.from("timetable_slots").delete().eq("school_id", school).eq(
        "section_id",
        sectionId,
      ).eq("academic_year_id", academicYearId).in("day_of_week", [1, 2, 3, 4, 5]);
      const rows = generated.map(
        ({
           subject_name: _ignoredSubject,
          term_id: _ignoredTerm,
          ...slot
        }) => slot,
      );
      const { data, error } = await svc.from("timetable_slots").insert(rows)
        .select(
          "*, section:sections(*, grade:grades(*)), subject:subjects(*), staff:staff(*), room:rooms(*)",
        );
      if (error) return fail(error.message);
      return ok({
        generated_count: data?.length ?? 0,
        slots: data ?? [],
        schedule_type: scheduleType,
      });
    } catch (error) {
      return fail(error instanceof Error ? error.message : "failed to apply pre-primary timetable");
    }
  }

  const prePrimaryMatch = path.match(/^\/timetable\/pre-primary\/section\/([^/]+)$/);
  if (prePrimaryMatch && method === "GET") {
    const { data, error } = await svc.from("timetable_slots").select(
      "*, subject:subjects(*), staff:staff(*), room:rooms(*)",
    ).eq("school_id", school).eq("section_id", prePrimaryMatch[1]).order(
      "day_of_week",
    ).order("period_number");
    if (error) return fail(error.message);
    return ok({
      section_id: prePrimaryMatch[1],
      slots: data ?? [],
    });
  }

  if (path === "/timetable/substitutions" && method === "GET") {
    return ok([]);
  }

  return fail("not found", 404);
}

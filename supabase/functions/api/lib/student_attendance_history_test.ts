import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { studentAttendanceHistory } from "./student_attendance_history.ts";

function fake(rows: Record<string, unknown>[], failSecond = false) {
  const calls: Array<[string, ...unknown[]]> = [];
  const svc = {
    from(table: string) {
      calls.push(["from", table]);
      const q = {
        select(value: string) { calls.push(["select", value]); return q; },
        eq(key: string, value: string) { calls.push(["eq", key, value]); return q; },
        gte(key: string, value: string) { calls.push(["gte", key, value]); return q; },
        lte(key: string, value: string) { calls.push(["lte", key, value]); return q; },
        order(key: string, value: unknown) { calls.push(["order", key, value]); return q; },
        range(start: number, end: number) {
          calls.push(["range", start, end]);
          return Promise.resolve(failSecond && start > 0
            ? { data: null, error: { message: "History unavailable" } }
            : { data: rows.slice(start, end + 1), error: null });
        },
      };
      return q;
    },
  } as unknown as SupabaseClient;
  return { svc, calls };
}

Deno.test("student history retains classes and years and reads beyond the server row cap", async () => {
  const rows = Array.from({ length: 1001 }, (_, i) => ({ id: `${i}`, session: { section_id: i ? "old" : "new", academic_year_id: i ? "previous" : "current" } }));
  const { svc, calls } = fake(rows);
  const result = await studentAttendanceHistory(svc, "school", "student", null, null);
  assertEquals(result.data, rows);
  assertEquals(calls.filter((c) => c[0] === "range"), [["range", 0, 999], ["range", 1000, 1999]]);
  assertEquals(calls.filter((c) => c[0] === "eq"), [["eq", "student_id", "student"], ["eq", "session.school_id", "school"], ["eq", "student_id", "student"], ["eq", "session.school_id", "school"]]);
  assertStringIncludes(String(calls.find((c) => c[0] === "select")?.[1]), "section:sections");
  assertEquals(calls.some((c) => c[0] === "eq" && c[1] === "session.section_id"), false);
});

Deno.test("monthly history filters the attendance date with correct February bounds", async () => {
  for (const [year, end] of [["2026", "28"], ["2028", "29"]]) {
    const { svc, calls } = fake([]);
    await studentAttendanceHistory(svc, "school", "student", year, "2");
    assertEquals(calls.filter((c) => c[0] === "gte" || c[0] === "lte"), [["gte", "session.date", `${year}-02-01`], ["lte", "session.date", `${year}-02-${end}`]]);
  }
});

Deno.test("invalid monthly filters do not issue queries", async () => {
  for (const [year, month] of [["2026", "13"], ["2026", null], [null, "2"], ["bad", "2"], ["2026", "2x"]]) {
    const { svc, calls } = fake([]);
    const result = await studentAttendanceHistory(svc, "school", "student", year, month);
    assertEquals(Boolean(result.error), true);
    assertEquals(calls, []);
  }
});

Deno.test("a failed history page does not return misleading partial attendance", async () => {
  const { svc } = fake(Array.from({ length: 1001 }, (_, id) => ({ id })), true);
  const result = await studentAttendanceHistory(svc, "school", "student", null, null);
  assertEquals(result.data, []);
  assertEquals(result.error?.message, "History unavailable");
});

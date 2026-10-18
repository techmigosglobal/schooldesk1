import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  attendanceDateContext,
  dateInZone,
  validSchoolDate,
} from "./school_day.ts";

const year = {
  id: "current",
  start_date: "2026-06-01",
  end_date: "2027-04-30",
  is_current: true,
};
Deno.test("attendance range includes current school day and academic year boundaries", () => {
  assertEquals(attendanceDateContext(year, "2026-10-18"), {
    academic_year_id: "current",
    academic_year_start: "2026-06-01",
    academic_year_end: "2027-04-30",
    school_date: "2026-10-18",
    min_date: "2026-06-01",
    max_date: "2026-10-18",
    configuration_status: "ready",
    message: null,
  });
  assertEquals(
    attendanceDateContext(year, "2026-06-01").max_date,
    "2026-06-01",
  );
  assertEquals(
    attendanceDateContext(year, "2027-04-30").configuration_status,
    "ready",
  );
});
Deno.test("ended academic year permits bounded history without requesting a future register", () => {
  const result = attendanceDateContext(
    { ...year, end_date: "2026-10-16" },
    "2026-10-18",
  );
  assertEquals(result.configuration_status, "ended");
  assertEquals(result.max_date, "2026-10-16");
  assertEquals(result.min_date, "2026-06-01");
});
Deno.test("missing, future, noncurrent or reversed years return actionable nonselectable context", () => {
  for (
    const [value, status] of [
      [null, "missing_year"],
      [{ ...year, is_current: false }, "invalid_year"],
      [{ ...year, start_date: "2027-01-01" }, "not_started"],
      [{ ...year, end_date: "2025-01-01" }, "invalid_year"],
      [{ ...year, start_date: "2026-02-30" }, "invalid_year"],
    ] as const
  ) {
    const result = attendanceDateContext(value, "2026-10-18");
    assertEquals(result.configuration_status, status);
    assertEquals(result.min_date, null);
    assertEquals(result.max_date, null);
    assertEquals(Boolean(result.message), true);
  }
});
Deno.test("school midnight differs from device UTC calendar and invalid dates reject", () => {
  const instant = new Date("2026-10-17T20:00:00Z");
  assertEquals(dateInZone("Asia/Kolkata", instant), "2026-10-18");
  assertEquals(dateInZone("America/Los_Angeles", instant), "2026-10-17");
  assertEquals(validSchoolDate("2026-02-30"), false);
  assertEquals(validSchoolDate("2028-02-29"), true);
});

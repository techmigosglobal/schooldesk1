import {
  assert,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { homeworkOperationDate, isIsoDate, isUuid } from "./homework_legacy.ts";

Deno.test("homework legacy validation rejects unsafe database inputs", () => {
  assertFalse(isUuid(""));
  assertFalse(isUuid("not-a-uuid"));
  assertFalse(isUuid("00000000-0000-0000-0000-00000000000"));
  assert(isUuid("19c0fa63-4ff1-4cc5-87e4-3460dac10920"));

  assertFalse(isIsoDate(""));
  assertFalse(isIsoDate("2026-8-7"));
  assert(isIsoDate("2026-08-07"));
});

Deno.test("legacy homework dates normalize timestamps without inventing dates", () => {
  assert(
    homeworkOperationDate({ assigned_date: "2026-08-07T09:30:00Z" }) ===
      "2026-08-07",
  );
  assert(homeworkOperationDate({ created_at: "2026-08-06" }) === "2026-08-06");
  assert(homeworkOperationDate({ assigned_date: "" }) === "");
});

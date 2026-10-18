import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  normalizeEventDestinations,
  validatePlacementDestinations,
} from "./event_destinations.ts";
import {
  readAllApprovalRows,
  uniqueGenericApprovals,
} from "./approval_feed_utils.ts";

Deno.test("explicit empty destinations stay hidden; only missing legacy values use a fallback", () => {
  assertEquals(normalizeEventDestinations([], "public"), []);
  assertEquals(
    normalizeEventDestinations(["SCHOOL_GALLERY", "SCHOOL_GALLERY"], "school"),
    ["SCHOOL_GALLERY"],
  );
  assertEquals(normalizeEventDestinations(null, "gallery"), ["SCHOOL_GALLERY"]);
  assertEquals(normalizeEventDestinations(undefined, "school"), [
    "PARENTS_HOME",
  ]);
  assertEquals(validatePlacementDestinations([]), null);
  assertEquals(
    validatePlacementDestinations(["PARENTS_HOME", "SCHOOL_GALLERY"]),
    null,
  );
  assertEquals(typeof validatePlacementDestinations(["UNKNOWN"]), "string");
  assertEquals(typeof validatePlacementDestinations(null), "string");
});
Deno.test("approval aggregation reads every page and propagates errors", async () => {
  const all = Array.from({ length: 1125 }, (_, id) => ({ id: String(id) }));
  let reads = 0;
  const result = await readAllApprovalRows(() => ({
    range: (from, to) => {
      reads++;
      return Promise.resolve({ data: all.slice(from, to + 1), error: null });
    },
  }));
  assertEquals(reads, 3);
  assertEquals(result.data?.length, 1125);
  const failure = await readAllApprovalRows(() => ({
    range: () => Promise.resolve({ data: null, error: { message: "offline" } }),
  }));
  assertEquals(failure.data, null);
  assertEquals(failure.error?.message, "offline");
});
Deno.test("mirrored approvals are deduplicated while separate operations remain actionable", () => {
  const rows = [
    { id: "mirror-event", entity_type: "event_post", entity_id: "event-one" },
    {
      id: "mirror-leave",
      entity_type: "leave_application",
      entity_id: "leave-one",
    },
    {
      id: "mirror-payment",
      entity_type: "parent_payment_request",
      entity_id: "pay-one",
    },
    { id: "staff-edit", entity_type: "staff", entity_id: "staff-one" },
    { id: "staff-delete", entity_type: "staff", entity_id: "staff-one" },
  ];
  assertEquals(
    uniqueGenericApprovals(rows, {
      event: [{ id: "event-one" }],
      leave: [{ id: "leave-one" }],
      payment: [{ id: "pay-one" }],
    }).map((row) => row.id),
    ["staff-edit", "staff-delete"],
  );
});

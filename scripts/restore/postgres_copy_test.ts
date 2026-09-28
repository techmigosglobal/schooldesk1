import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { parseCopyRow } from "./postgres_copy.ts";

Deno.test("decodes PostgreSQL text COPY escapes without converting null text", () => {
  assertEquals(
    parseCopyRow(
      "plain\t\\N\tline\\nbreak\ttab\\tvalue\tbackslash\\\\value\t\\141",
      6,
    ),
    ["plain", null, "line\nbreak", "tab\tvalue", "backslash\\value", "a"],
  );
});

Deno.test("rejects malformed COPY field counts", () => {
  assertThrows(() => parseCopyRow("one\ttwo", 3), Error, "expected 3");
});

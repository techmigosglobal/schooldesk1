import { expect, test } from "bun:test";
import { buildAttentionItems } from "../lib/portal-attention";
test("pending verification leads Principal directly to Verification", () => expect(buildAttentionItems({ role: "principal", pendingVerificationCount: 1, inquiryCount: 0 })).toEqual([expect.objectContaining({ target: "fees", tab: "requests", count: 1, pending: true })]));
test("zero inquiries and configured classes never fabricate work", () => expect(buildAttentionItems({ role: "principal", pendingVerificationCount: 0, inquiryCount: 0 })).toEqual([]));
test("inquiries are informational for both roles", () => {
  for (const role of ["principal", "coordinator"] as const) expect(buildAttentionItems({ role, pendingVerificationCount: 0, inquiryCount: 3 })).toEqual([expect.objectContaining({ target: "admission_inquiries", pending: false, count: 3 })]);
});
test("Coordinator never receives finance attention", () => expect(buildAttentionItems({ role: "coordinator", pendingVerificationCount: 99, inquiryCount: 0 })).toEqual([]));

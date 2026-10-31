import type { PortalRole } from "./roles";

export type AttentionItem = { id: string; title: string; detail: string; count: number; target: string; tab?: string; pending: boolean };
export function buildAttentionItems({ role, pendingVerificationCount, inquiryCount }: { role: PortalRole; pendingVerificationCount: number; inquiryCount: number }): AttentionItem[] {
  const items: AttentionItem[] = [];
  if (role === "principal" && Number.isFinite(pendingVerificationCount) && pendingVerificationCount > 0) {
    items.push({ id: "verification", title: "Payment verification", detail: "Parent payment submissions awaiting a decision", count: pendingVerificationCount, target: "fees", tab: "requests", pending: true });
  }
  if (Number.isFinite(inquiryCount) && inquiryCount > 0) {
    items.push({ id: "inquiries", title: "Admission inquiries", detail: "Total inquiries in the admissions inbox", count: inquiryCount, target: "admission_inquiries", pending: false });
  }
  return items;
}

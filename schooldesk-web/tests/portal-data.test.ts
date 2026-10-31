import { expect, test } from "bun:test";
import { collectPages } from "../lib/pagination";
import { receiptRegisterRows } from "../lib/receipt-register";
import { normalizeMediaUrls, publicMediaUrl } from "../lib/media-urls";

test("loads every capped page and retains the original filters", async () => {
  const calls: string[] = [];
  const rows = await collectPages("fees/invoices?page_size=2000&student_id=learner", async (path) => {
    calls.push(path);
    const page = Number(new URL(path, "http://test").searchParams.get("page"));
    return { success: true, data: [{ id: String(page) }], page, page_size: 1, total: 3, has_more: page < 3 };
  });
  expect(rows.map((row) => row.id)).toEqual(["1", "2", "3"]);
  expect(calls.every((path) => path.includes("student_id=learner"))).toBe(true);
});

test("understands the nested admissions pagination contract", async () => {
  const rows = await collectPages("admission-inquiries", async (path) => {
    const page = Number(new URL(path, "http://test").searchParams.get("page"));
    return { success: true, data: { data: [{ id: String(page) }], page, has_more: page < 2 } };
  });
  expect(rows).toHaveLength(2);
});

test("does not return a partial ledger when a subsequent page fails", async () => {
  let count = 0;
  await expect(collectPages("fees/payments", async () => {
    if (++count === 2) throw new Error("Connection lost");
    return { data: [{ id: "first" }], has_more: true };
  })).rejects.toThrow("Connection lost");
});

test("rejects a broken pagination contract instead of looping or dropping rows", async () => {
  await expect(collectPages("students", async () => ({ data: [], has_more: true }))).rejects.toThrow();
});

test("receipt CSV maps the actual deployed payment fields and retains zero amounts", () => {
  expect(receiptRegisterRows([{ invoice_id: "i", amount: 0, payment_method: "cash", paid_at: "2026-10-16", reference_number: "RCP42" }])[0]).toEqual({
    receipt_number: "RCP42", invoice_id: "i", amount_paid: 0,
    payment_mode: "cash", payment_date: "2026-10-16", transaction_id: "RCP42",
  });
});

test("normalizes internal media origins without changing signatures or external URLs", () => {
  const url = "http://supabase-kong:8000/storage/v1/object/sign/bucket/photo.jpg?token=unchanged";
  expect(publicMediaUrl(url, "https://api.arishville.com")).toBe("https://api.arishville.com/storage/v1/object/sign/bucket/photo.jpg?token=unchanged");
  expect(normalizeMediaUrls({ data: [{ media_url: url }] }, "https://api.arishville.com")).toEqual({ data: [{ media_url: publicMediaUrl(url, "https://api.arishville.com") }] });
  expect(publicMediaUrl("https://other.example/photo.jpg", "https://api.arishville.com")).toBe("https://other.example/photo.jpg");
});

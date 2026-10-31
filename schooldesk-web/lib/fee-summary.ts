/** The invoice-ledger contract returned by GET fees/summary, for the active branch. */
export type FeeSummary = {
  billed: number;
  collected: number;
  outstanding: number;
  overdue: number;
  invoiceCount: number;
  overdueCount: number;
  pendingRequestCount: number;
  collectionPercent: number | null;
};

export function readFeeSummary(value: unknown): FeeSummary {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Fee summary is unavailable.");
  const source = value as Record<string, unknown>;
  function amount(key: string): number {
    const result = source[key];
    if (typeof result !== "number" || !Number.isFinite(result)) throw new Error(`Fee summary contains an invalid ${key}.`);
    return result;
  }
  function count(key: string): number {
    const result = amount(key);
    if (!Number.isSafeInteger(result) || result < 0) throw new Error(`Fee summary contains an invalid ${key}.`);
    return result;
  }
  const billed = amount("billed"), collected = amount("collected"), outstanding = amount("outstanding");
  const denominator = collected + outstanding;
  return {
    billed, collected, outstanding, overdue: amount("overdue"),
    invoiceCount: count("invoice_count"), overdueCount: count("overdue_count"), pendingRequestCount: count("pending_request_count"),
    collectionPercent: denominator > 0 ? Math.round(collected / denominator * 100) : null,
  };
}

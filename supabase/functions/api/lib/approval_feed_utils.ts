type Row = Record<string, unknown>;
type ReadResult = { data: Row[] | null; error: { message: string } | null };
type PagedQuery = { range(from: number, to: number): PromiseLike<ReadResult> };

/** Stable ID order is supplied by the caller. Never silently truncate counts. */
export async function readAllApprovalRows(
  build: () => PagedQuery,
): Promise<ReadResult> {
  const data: Row[] = [];
  const size = 500;
  for (let from = 0;; from += size) {
    const result = await build().range(from, from + size - 1);
    if (result.error) return { data: null, error: result.error };
    const rows = result.data ?? [];
    data.push(...rows);
    if (rows.length < size) return { data, error: null };
  }
}

/** Prefer the source record's working decision route over its generic mirror. */
export function uniqueGenericApprovals(
  generic: Row[],
  sources: Record<string, Row[]>,
): Row[] {
  const aliases: Record<string, string> = {
    account_approval: "account",
    account_approvals: "account",
    event: "event",
    event_post: "event",
    event_posts: "event",
    leave: "leave",
    leave_application: "leave",
    leave_applications: "leave",
    student_leave: "student_leave",
    student_leave_application: "student_leave",
    student_leave_applications: "student_leave",
    fee_concession: "fee_concession",
    fee_concessions: "fee_concession",
    fee_payment_proof: "payment",
    payment_proof: "payment",
    parent_payment_request: "payment",
    parent_payment_requests: "payment",
  };
  const ids = new Map(
    Object.entries(sources).map((
      [type, rows],
    ) => [type, new Set(rows.map((row) => `${row.id}`))]),
  );
  const seen = new Set<string>();
  return generic.filter((row) => {
    const entity = `${row.entity_type ?? ""}`.trim().toLowerCase();
    const type = aliases[entity];
    const id = `${row.entity_id ?? ""}`.trim();
    if (type && id && ids.get(type)?.has(id)) return false;
    // Different operations on the same entity are separate actionable requests.
    const key = `${row.id}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

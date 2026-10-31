type Payload = Record<string, unknown>;

/** Read complete existing lists even when the API caps the requested page size. */
export async function collectPages(
  path: string,
  request: (path: string) => Promise<Payload>,
): Promise<Payload[]> {
  const url = new URL(path, "http://schooldesk.local/");
  url.searchParams.set("page_size", "100");
  const result: Payload[] = [];
  for (let page = 1; page <= 1000; page++) {
    url.searchParams.set("page", String(page));
    const envelope = await request(`${url.pathname.slice(1)}${url.search}`);
    if (envelope.success === false) throw new Error(String(envelope.error || "Unable to load records"));
    const payload = envelope.data;
    const nested = payload && typeof payload === "object" && !Array.isArray(payload) ? payload as Payload : null;
    const metadata = nested && ("has_more" in nested || "total" in nested) ? nested : envelope;
    const rows = Array.isArray(payload) ? payload : nested && ["data", "classes", "slots", "users", "staff", "students"].map((key) => nested[key]).find(Array.isArray);
    if (!Array.isArray(rows)) throw new Error("The server returned an unexpected record list. Please refresh and try again.");
    result.push(...rows);
    const more = typeof metadata.has_more === "boolean" ? metadata.has_more :
      typeof metadata.total === "number" ? result.length < metadata.total : false;
    if (!more) return result;
    if (!rows.length || (typeof metadata.page === "number" && metadata.page !== page)) {
      throw new Error("The server could not load the complete list. Please refresh and try again.");
    }
  }
  throw new Error("The list is too large to load completely. Please narrow the selected scope.");
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

export function isUuid(value: unknown): boolean {
  return UUID_PATTERN.test(`${value ?? ""}`.trim());
}

export function isIsoDate(value: unknown): boolean {
  return ISO_DATE_PATTERN.test(`${value ?? ""}`.trim());
}

export function homeworkOperationDate(row: Record<string, unknown>): string {
  return `${row.assigned_date ?? row.created_at ?? ""}`.trim().split("T")[0];
}

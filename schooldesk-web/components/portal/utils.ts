import type { Row } from "./types";

export async function api(path: string, init: RequestInit = {}) {
  const response = await fetch(`/api/backend/${path}`, {
    ...init,
    headers: {
      ...(init.body instanceof FormData ? {} : { "Content-Type": "application/json" }),
      ...(init.headers ?? {}),
    },
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || body.success === false) {
    throw new Error(body.error || "Request failed");
  }
  return body.data;
}

export async function apiRaw(path: string, init: RequestInit = {}) {
  const response = await fetch(`/api/backend/${path}`, {
    ...init,
    headers: {
      ...(init.body instanceof FormData ? {} : { "Content-Type": "application/json" }),
      ...(init.headers ?? {}),
    },
  });
  const body = await response.json().catch(() => ({}));
  return { ok: response.ok && body.success !== false, status: response.status, body };
}

export async function apiFirst(paths: string[], init?: RequestInit) {
  let lastError = "Request failed";
  for (const path of paths) {
    const response = await apiRaw(path, init);
    if (response.ok) return response.body.data;
    lastError = response.body.error || lastError;
    if (response.status !== 404) break;
  }
  throw new Error(lastError);
}

export function rowsFrom(data: unknown): Row[] {
  if (Array.isArray(data)) return data as Row[];
  if (data && typeof data === "object") {
    const row = data as Row;
    for (const key of ["data", "classes", "slots", "users", "staff", "students"]) {
      if (Array.isArray(row[key])) return row[key] as Row[];
    }
  }
  return [];
}

export function stringValue(value: unknown): string {
  if (value === null || value === undefined) return "";
  return String(value);
}

export function nested(row: Row, key: string): Row {
  const value = row[key];
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Row;
  }
  return {};
}

export function rowText(row: Row, key: string): string {
  if (key === "current_section") {
    const section = nested(row, "current_section");
    const grade = nested(section, "grade");
    return (
      [
        stringValue(grade.grade_name ?? grade.name),
        stringValue(section.section_name ?? section.name),
      ]
        .filter(Boolean)
        .join(" · ") || "—"
    );
  }
  if (key === "grade_name") {
    return (
      stringValue(
        nested(row, "grade").grade_name ??
          nested(row, "grade").name ??
          row[key]
      ) || "—"
    );
  }
  if (key === "subject_name") {
    return (
      stringValue(
        nested(row, "subject").subject_name ??
          nested(row, "subject").name ??
          row[key]
      ) || "—"
    );
  }
  return stringValue(row[key]) || "—";
}

export function money(value: unknown): string {
  const amount = typeof value === "number" ? value : Number(value || 0);
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(Number.isNaN(amount) ? 0 : amount);
}

export function formatDate(value: unknown, fallback = "—"): string {
  const text = stringValue(value);
  if (!text) return fallback;
  const date = new Date(text);
  if (Number.isNaN(date.getTime())) return text.slice(0, 10) || fallback;
  return new Intl.DateTimeFormat("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(date);
}

export function formatDateTime(value: unknown, fallback = "—"): string {
  const text = stringValue(value);
  if (!text) return fallback;
  const date = new Date(text);
  if (Number.isNaN(date.getTime())) return text || fallback;
  return new Intl.DateTimeFormat("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

export function downloadCsv(filename: string, rows: Array<Record<string, unknown>>) {
  const headers = Array.from(new Set(rows.flatMap((row) => Object.keys(row))));
  const escape = (value: unknown) =>
    `"${stringValue(value).replaceAll('"', '""')}"`;
  const csv = [
    headers.join(","),
    ...rows.map((row) => headers.map((header) => escape(row[header])).join(",")),
  ].join("\n");
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export function splitName(name: string): { first_name: string; last_name: string } {
  const parts = name.trim().split(/\s+/);
  return {
    first_name: parts[0] || "",
    last_name: parts.slice(1).join(" "),
  };
}

export function displayName(row: Row): string {
  const first = stringValue(row.first_name);
  const last = stringValue(row.last_name);
  const combined = [first, last].filter(Boolean).join(" ");
  return combined || stringValue(row.name) || stringValue(row.username) || "—";
}

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

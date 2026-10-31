/** Restore only bounded UI values. Nullable persisted IDs are strings, never API rows. */
export function restorePortalValue<T>(json: string | null, fallback: T): T {
  if (!json || json.length >= 4096) return fallback;
  try {
    const parsed: unknown = JSON.parse(json);
    const matches = (value: unknown, shape: unknown): boolean => {
      if (shape === null) return value === null || typeof value === "string";
      if (typeof shape === "number") return typeof value === "number" && Number.isFinite(value);
      if (typeof shape === "string") return typeof value === "string";
      if (typeof shape === "boolean") return typeof value === "boolean";
      if (Array.isArray(shape)) return Array.isArray(value) && value.length <= 200 && value.every(item => typeof item === "string" && item.length < 256);
      if (shape && typeof shape === "object" && !Array.isArray(shape)) {
        if (!value || typeof value !== "object" || Array.isArray(value)) return false;
        const keys = Object.keys(shape);
        return Object.keys(value).length === keys.length && keys.every(key => matches((value as Record<string, unknown>)[key], (shape as Record<string, unknown>)[key]));
      }
      return false;
    };
    return matches(parsed, fallback) ? parsed as T : fallback;
  } catch { return fallback; }
}

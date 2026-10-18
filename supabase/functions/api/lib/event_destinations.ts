export const EVENT_DESTINATIONS = [
  "PARENTS_HOME",
  "TEACHERS_HOME",
  "SCHOOL_GALLERY",
  "SCHOOL_LANDING",
] as const;

export function validatePlacementDestinations(value: unknown): string | null {
  if (
    !Array.isArray(value) || value.some((entry) =>
      typeof entry !== "string" ||
      !(EVENT_DESTINATIONS as readonly string[]).includes(entry)
    )
  ) return "destinations must be an array of supported destinations";
  return null;
}

export function normalizeEventDestinations(
  value: unknown,
  visibility: unknown,
): string[] {
  // An explicit empty array means hidden everywhere. Only legacy missing
  // values use visibility to infer a destination.
  if (Array.isArray(value)) {
    return [
      ...new Set(
        value.filter((entry): entry is string =>
          typeof entry === "string" && entry.length > 0
        ),
      ),
    ];
  }
  const legacy = `${visibility ?? ""}`.trim().toLowerCase();
  if (legacy === "public") return ["SCHOOL_LANDING"];
  if (legacy === "gallery") return ["SCHOOL_GALLERY"];
  return ["PARENTS_HOME"];
}

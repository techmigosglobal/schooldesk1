#!/usr/bin/env python3
"""Verify the executable QA questionnaire against the current route registry."""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "test_cases.csv"
REGISTRY_PATH = ROOT / "lib/routes/schooldesk_screen_registry.dart"

REQUIRED_COLUMNS = {
    "Test ID",
    "Question / Test Condition",
    "Evidence Required",
    "Evidence Link/Attachment",
    "Test Type",
    "Execution Method",
    "Granularity",
    "Atomic Subcases",
    "Environment",
    "Priority",
    "Severity",
    "Execution Date",
    "Tester",
    "Build/Commit",
    "Backend/Migration",
    "School/Branch/Fixture",
    "Account/Device/Browser",
    "Network/Locale",
    "Actual Result",
    "Status",
    "Defect ID",
    "Notes",
}

ALLOWED_TYPES = {
    "Functional",
    "Security",
    "Cross-role",
    "API/RLS",
    "Offline",
    "Resilience",
    "Data Integrity",
    "Performance",
    "Accessibility",
    "Compatibility",
    "Release",
    "Authorization",
    "Scope",
    "Audit",
    "Notifications",
    "UX",
    "Localization",
    "Boundary",
    "Risk",
    "Web",
}

ALLOWED_METHODS = {
    "Automated",
    "Static",
    "API",
    "RLS",
    "Database",
    "Manual",
    "Browser",
    "Device",
    "Artifact",
    "Live",
    "Security",
    "Performance",
    "Process",
    "UX",
}

ALLOWED_STATUS = {"Not Run", "Passed", "Failed", "Blocked", "Not Applicable"}


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if not CSV_PATH.exists():
        fail(f"missing {CSV_PATH}")
    if not REGISTRY_PATH.exists():
        fail(f"missing {REGISTRY_PATH}")

    with CSV_PATH.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        columns = set(reader.fieldnames or [])
        missing_columns = REQUIRED_COLUMNS - columns
        if missing_columns:
            fail(f"missing columns: {sorted(missing_columns)}")
        rows = list(reader)

    if not rows:
        fail("questionnaire has no cases")

    ids = [row["Test ID"] for row in rows]
    duplicates = sorted({case_id for case_id in ids if ids.count(case_id) > 1})
    if duplicates:
        fail(f"duplicate test IDs: {duplicates}")

    for row in rows:
        case_id = row["Test ID"]
        if row["Status"] not in ALLOWED_STATUS:
            fail(f"{case_id}: invalid status {row['Status']!r}")
        if row["Test Type"] not in ALLOWED_TYPES:
            fail(f"{case_id}: invalid test type {row['Test Type']!r}")
        methods = {value for value in row["Execution Method"].split(";") if value}
        invalid_methods = methods - ALLOWED_METHODS
        if invalid_methods:
            fail(f"{case_id}: invalid execution methods {sorted(invalid_methods)}")
        if not row["Evidence Required"].strip():
            fail(f"{case_id}: evidence requirement is empty")
        if row["Granularity"].startswith("Composite") and not row["Atomic Subcases"].strip():
            fail(f"{case_id}: composite case has no atomic subcase guidance")
        if row["Status"] == "Passed":
            required = [
                "Evidence Link/Attachment",
                "Execution Date",
                "Tester",
                "Build/Commit",
                "Actual Result",
            ]
            missing = [field for field in required if not row[field].strip()]
            if missing:
                fail(f"{case_id}: passed case missing execution fields {missing}")

    registry_text = REGISTRY_PATH.read_text(encoding="utf-8")
    routes = list(dict.fromkeys(re.findall(r"route:\s*'([^']+)'", registry_text)))
    route_text = "\n".join(row["Route"] for row in rows)
    missing_routes = [route for route in routes if route != "/" and route not in route_text]
    if missing_routes:
        fail(f"routes missing from questionnaire: {missing_routes}")
    if not any(row["Route"].strip() == "/" for row in rows):
        fail("root route '/' is not represented as an explicit route field")

    for case_id in ("NFR-001", "NFR-002", "NFR-003"):
        row = next((item for item in rows if item["Test ID"] == case_id), None)
        if row is None or not re.search(r"\d", row["Expected Result"]):
            fail(f"{case_id}: measurable numeric threshold is missing")

    expected_roles = {"Principal", "Coordinator", "Class Teacher", "Co-Teacher", "Parent", "Super Admin", "Kiosk User"}
    role_text = "\n".join(row["Role"] for row in rows)
    missing_roles = [role for role in expected_roles if role not in role_text]
    if missing_roles:
        fail(f"canonical roles missing: {missing_roles}")

    print(f"PASS: {len(rows)} questionnaire cases validated")
    print(f"PASS: {len(routes)} registered routes represented")
    print("PASS: execution metadata, evidence, taxonomy, granularity, and numeric NFR checks passed")


if __name__ == "__main__":
    main()

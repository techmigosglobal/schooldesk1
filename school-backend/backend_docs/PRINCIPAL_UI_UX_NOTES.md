# Principal UI/UX Notes

This file tracks observations noticed while reviewing the Principal role module against the backend documentation. These notes are intended for future UI/UX and integration improvements.

## 1. Terms Table Exists In Backend But Is Not Visible In Principal UI

### Observation

The backend schema includes a `terms` table linked to `academic_years`.

Relationship:

```text
schools
  -> academic_years
      -> terms
```

The `terms` table represents subdivisions inside an academic year, such as Term 1, Term 2, or Term 3.

However, while reviewing the Principal UI/API mapping, there was no clear Principal screen or feature that directly displays or manages terms.

The Principal Academic Info screen currently maps to:

```text
GET /academic-years
GET /grades
GET /sections
GET /subjects
GET /departments
```

No Principal UI mapping was noticed for:

```text
GET /terms
POST /terms
PUT /terms/{id}
DELETE /terms/{id}
```

### Why This Matters

Terms may be optional depending on the school's academic structure, but they are still important for Principal-level academic planning and review.

They can support:

- term-wise exams
- term-wise report cards
- syllabus progress by term
- attendance summaries by term
- fee period planning
- academic performance analytics

### Suggested UI/UX Improvement

The Principal UI should display terms somewhere in the academic setup or academic information area.

Possible placements:

- Principal Academic Info screen
- Principal School Profile / Academic Settings
- Principal Academics module
- Exam and Results setup screens

The UI does not necessarily need to make terms mandatory, but if the backend supports them, the Principal should at least be able to view them and understand how the academic year is divided.

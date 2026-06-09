# SchoolDesk FastAPI Frontend Structure

Flutter integration is intentionally deferred until the FastAPI backend module is verified.

When integration starts, add the Goal & Task screens through the existing role-scoped API client layer instead of direct widget API calls.

## Planned Screens

- Principal Goals & Tasks workspace
- Admin My Tasks
- Teacher My Tasks
- Class Teacher section task view inside `TeacherShell`

## State And UI Rules

- Use the centralized backend API client.
- Do not show Parent/Guardian routes for this module.
- Keep homework/assignments separate from operational tasks.
- Show explicit loading, empty, error, blocked, submitted, completed, and archived states.
- Support small Android, iPhone SE, standard iPhone, Pro Max, and tablet layouts without overflow.


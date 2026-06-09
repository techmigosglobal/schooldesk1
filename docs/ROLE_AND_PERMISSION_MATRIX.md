# SchoolDesk FastAPI Role And Permission Matrix

## Goal & Task MVP

| Role | Goal permissions | Task permissions | Visibility |
| --- | --- | --- | --- |
| Principal | `goals.read`, `goals.manage` | `tasks.read`, `tasks.manage`, `tasks.update_own` | All school goals and tasks |
| Admin | `goals.read` | `tasks.read`, `tasks.update_own` | Assigned or role-scoped tasks only |
| Teacher | `goals.read` | `tasks.read`, `tasks.update_own` | Assigned staff tasks and class-teacher section tasks |
| Parent/Guardian | None | None | No access |

Class Teacher is still not a base login role. A Teacher becomes Class Teacher when `sections.class_teacher_id` matches the teacher staff ID.

Sensitive school actions remain separate from tasks. Completing a task cannot publish timetable, fee structure, results, or any other sensitive module action.


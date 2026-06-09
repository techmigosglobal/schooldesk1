# SchoolDesk FastAPI API Endpoints

This document tracks the new independent `schooldesk-fastapi-backend/` API. FastAPI is the migration runtime; the Go backend may be used only as a reference while contracts are ported natively. Do not add Go proxy fallbacks for missing routes.

## Health

- `GET /health`
- `GET /health/db`
- `GET /health/redis`
- `GET /docs`
- `GET /api/docs`
- `GET /api/v1/docs`

## Auth

- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/auth/profile`
- `PATCH /api/v1/auth/profile`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`

## School Catalog And Directory

- `GET /api/v1/dashboard/{role}`
- `GET /api/v1/schools`
- `GET /api/v1/schools/current`
- `PATCH /api/v1/schools/current`
- `POST /api/v1/schools/current/logo`
- `GET /api/v1/announcements`
- `GET /api/v1/notifications`
- `GET /api/v1/me/students`
- `GET /api/v1/students`
- `POST /api/v1/students`
- `GET /api/v1/students/{id}`
- `PUT /api/v1/students/{id}`
- `DELETE /api/v1/students/{id}`
- `GET /api/v1/students/{id}/enrollments`
- `GET /api/v1/staff`
- `POST /api/v1/staff`
- `GET /api/v1/staff/{id}`
- `PUT /api/v1/staff/{id}`
- `DELETE /api/v1/staff/{id}`
- `GET /api/v1/academic-years`
- `POST /api/v1/academic-years`
- `PUT /api/v1/academic-years/{id}`
- `GET /api/v1/academic-years/{id}/terms`
- `GET /api/v1/grades`
- `GET /api/v1/sections`
- `GET /api/v1/subjects`
- `GET /api/v1/rooms`
- `POST /api/v1/rooms`
- `GET /api/v1/fees/structures`
- `GET /api/v1/fees/invoices`
- `GET /api/v1/timetable/slots`
- `GET /api/v1/attendance/staff/me/today`

The listed catalog and directory endpoints are native FastAPI endpoints backed by PostgreSQL/SQLite models. File upload routes currently persist URL fields only where implemented; the shared file/document pipeline still needs a later native slice.

## Leave Compatibility

- `GET /api/v1/leave/types`
- `GET /api/v1/leave/balances`
- `GET /api/v1/leave/applications`
- `POST /api/v1/leave/applications`
- `PUT /api/v1/leave/applications/{id}/approve`
- `GET /api/v1/student-leave/applications`
- `POST /api/v1/student-leave/applications`
- `PUT /api/v1/student-leave/applications/{id}/decision`

Staff leave is internal only. Teachers can submit their own leave requests; Principal is the final decision authority. Parent/Guardian can submit student leave requests, but cannot access staff leave endpoints.

## Goals

- `POST /api/v1/goals`
- `GET /api/v1/goals`
- `GET /api/v1/goals/{id}`
- `PATCH /api/v1/goals/{id}`
- `POST /api/v1/goals/{id}/activate`
- `POST /api/v1/goals/{id}/archive`
- `POST /api/v1/goals/{id}/tasks`

## Tasks

- `POST /api/v1/tasks`
- `GET /api/v1/tasks`
- `GET /api/v1/tasks/my`
- `GET /api/v1/tasks/{id}`
- `PATCH /api/v1/tasks/{id}`
- `PATCH /api/v1/tasks/{id}/progress`
- `POST /api/v1/tasks/{id}/comments`
- `PATCH /api/v1/tasks/{id}/checklist/{item_id}`
- `POST /api/v1/tasks/{id}/complete`
- `POST /api/v1/tasks/{id}/reopen`
- `POST /api/v1/tasks/{id}/archive`

`POST /api/v1/tasks` and task archive are included so Principal can create/archive standalone tasks as required by the MVP assumptions.

## Approval Workflow

- `GET /api/v1/approvals`
- `POST /api/v1/approvals`
- `GET /api/v1/approvals/{id}`
- `PUT /api/v1/approvals/{id}`
- `PATCH /api/v1/approvals/{id}`
- `POST /api/v1/approvals/{id}/submit`
- `POST /api/v1/approvals/{id}/approve`
- `POST /api/v1/approvals/{id}/reject`
- `POST /api/v1/approvals/{id}/request-changes`
- `POST /api/v1/approvals/{id}/cancel`
- `POST /api/v1/approvals/{id}/apply`
- `GET|POST /api/v1/account-approvals`
- `GET|POST /api/v1/class-approvals`
- `GET|POST /api/v1/student-approvals`
- `PUT /api/v1/account-approvals/{id}`
- `PUT /api/v1/class-approvals/{id}`
- `PUT /api/v1/student-approvals/{id}`

`apply` records that the Principal marked an approved request as applied, but does not auto-mutate sensitive school records. Concrete applicators must be implemented per module with their own tests.

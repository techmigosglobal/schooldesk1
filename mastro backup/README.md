# SchoolDesk Maestro E2E

These flows target the wireless Moto G85 (`moto_g85_5G`) and cover the Teacher ↔ Principal workflows end to end:

- principal login and dashboard queue
- principal teacher account provisioning via Access & Permissions
- principal and teacher navigation boundaries
- teacher attendance draft/final submit
- teacher correction request → principal attendance monitor/reopen
- teacher homework, lesson planner, event post → principal lesson/event review
- teacher leave request → principal approval center review
- teacher communication → principal message oversight

All selectors use accessibility labels and visible text. Coordinate taps and `optional: true` steps are not used.

## Layout

- `config.yaml` — suite order for local runs and Maestro Cloud
- `subflows/` — reusable login and drawer helpers
- `*.yaml` — one journey per Teacher ↔ Principal workflow

## Run on the G85

```bash
Maestro/run_g85.sh
```

Override credentials when your seeded teacher account differs:

```bash
TEACHER_USERNAME=teacher01 TEACHER_PASSWORD=Teacher@12345 Maestro/run_g85.sh
```

Run one flow manually:

```bash
ANDROID_SERIAL=adb-ZA2235WH4K-c1n0iS._adb-tls-connect._tcp \
maestro test \
  -e PRINCIPAL_USERNAME=principal \
  -e PRINCIPAL_PASSWORD=Principal@12345 \
  -e TEACHER_USERNAME=teacher01 \
  -e TEACHER_PASSWORD=Teacher@12345 \
  Maestro/teacher_attendance_marking.yaml
```

## Maestro Studio ENV1

Select `ENV1` in Maestro Studio and add these environment variables:

- `PRINCIPAL_USERNAME`: `principal`
- `PRINCIPAL_PASSWORD`: `Principal@12345`
- `TEACHER_USERNAME`: `teacher01`
- `TEACHER_PASSWORD`: `Teacher@12345`

The flows use the same names everywhere. Each credential expression also has a
default fallback, so Maestro will not type `undefined` if `ENV1` is missing a
variable.

## Selector conventions

- Landing page: tap the `Sign in` accessibility label (not screen coordinates).
- Forms: tap field labels such as `Username`, `Password`, `Reason`, and `Full name *`.
- Dashboard tiles and action queue rows expose their title as the accessibility label.
- Drawer destinations are opened with `Open navigation`, then the drawer item label.

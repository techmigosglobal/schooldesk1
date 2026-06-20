# SchoolDesk Maestro E2E

These flows target the wireless Moto G85 (`moto_g85_5G`) and cover the Teacher ↔ Principal workflows:

- principal login and dashboard queue
- principal teacher/account creation smoke
- principal and teacher navigation boundaries
- teacher attendance draft/final submit
- teacher correction request → principal attendance monitor/reopen
- teacher homework, lesson planner, event post → principal lesson/event review
- teacher leave request → principal approval surface
- teacher communication → principal message oversight

Run on the G85:

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

## Maestro Cloud through GitHub Actions

The GitHub Actions workflow lives at `.github/workflows/maestro-cloud.yml`.
It builds a Flutter debug APK with a public HTTPS backend URL, uploads the APK to
Maestro Cloud, and runs every flow in this `Maestro/` directory.

Configure these GitHub Actions secrets before running it:

- `MAESTRO_CLOUD_API_KEY`
- `MAESTRO_PROJECT_ID`
- `MAESTRO_PRINCIPAL_USERNAME`
- `MAESTRO_PRINCIPAL_PASSWORD`
- `MAESTRO_TEACHER_USERNAME`
- `MAESTRO_TEACHER_PASSWORD`

Configure `SCHOOLDESK_API_BASE_URL` as either a repository variable or secret.
It must be an HTTPS backend URL reachable from Maestro Cloud, for example
`https://example.com/api`.

Optional repository variables:

- `MAESTRO_DEVICE_MODEL`, defaults to `pixel_6`
- `MAESTRO_DEVICE_OS`, defaults to `android-34`
- `MAESTRO_TIMEOUT_MINUTES`, defaults to `90`

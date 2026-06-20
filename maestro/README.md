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
maestro/run_g85.sh
```

Override credentials when your seeded teacher account differs:

```bash
TEACHER_USERNAME=teacher01 TEACHER_PASSWORD=Teacher@12345 maestro/run_g85.sh
```

Run one flow manually:

```bash
ANDROID_SERIAL=adb-ZA2235WH4K-c1n0iS._adb-tls-connect._tcp \
maestro test \
  -e PRINCIPAL_USERNAME=principal \
  -e PRINCIPAL_PASSWORD=Principal@12345 \
  -e TEACHER_USERNAME=teacher01 \
  -e TEACHER_PASSWORD=Teacher@12345 \
  maestro/teacher_attendance_marking.yaml
```

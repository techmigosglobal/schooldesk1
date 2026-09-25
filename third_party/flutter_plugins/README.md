# Flutter plugin compatibility copies

These copies contain the exact resolved plugin versions used by SchoolDesk.
They are vendored only because Flutter 3.47 statically flags the legacy
`apply plugin: 'kotlin-android'` text in the upstream Android scripts, even
when the scripts correctly skip KGP on AGP 9 built-in Kotlin.

Only the conditional Gradle application syntax is changed for:

- `firebase_core` 4.15.0
- `firebase_crashlytics` 5.4.0
- `workmanager_android` 0.10.9

The copies remain under their upstream licenses. Re-check upstream releases
before removing these overrides.

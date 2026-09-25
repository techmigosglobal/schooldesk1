# ADR-0002: Frontend rewrite route, repository, and role contracts

## Status

Accepted

## Decision

SchoolDesk remains one Flutter application with an explicit composition root:

```text
bootstrap -> Riverpod providers -> typed GoRouter -> role shell
          -> capability repository -> Drift cache / API transport
          -> scoped outbox and ordered sync
```

- Every registered location is created by `TypedAppRouteRegistry` and enters
  GoRouter through a typed argument parser. Legacy named-navigation calls are
  permitted only inside the navigation adapter's isolated test fallback.
  Compatibility fee aliases are explicit typed entries and share the canonical
  screen contracts until external links are migrated.
- Role shells are isolated for Principal, Coordinator, Teacher, Parent, Kiosk,
  and Super Admin. Capability repositories do not grant authority; backend
  authorization remains authoritative.
- `RepositoryState<T>` is the common UI contract. Each screen manifest declares
  loading, stale, offline, error, empty, and retry coverage. Cached reads remain
  visible while refresh is stale; online-only mutations show an explicit
  connection-required state.
- Drift is the authoritative local cache. Cache rows and outbox work items are
  scoped by account, school, branch, and role. Safe writes use durable
  idempotency keys, ordered replay, retry backoff, upload dependencies, and
  visible permanent/conflict failures. Approvals, finance decisions, account
  administration, branch changes, password changes, and destructive actions
  remain online-only.
- Production runtime uses real API data and scoped local cache data. Demo
  backend, fixture stores, demo interceptors, and demo role selection are not
  production dependencies.

## Package and Android policy

The resolvable upgrade set is recorded in `pubspec.yaml` and `pubspec.lock`.
Drift, Riverpod, GoRouter, Freezed, build generators, Retrofit, Firebase,
media, PDF, sharing, and desktop packages were upgraded where compatible with
the current Flutter SDK. Freezed 4.0.2 remains blocked by the SDK's test/analyzer
constraints; 4.0.1 is the newest resolvable version.

Android uses AGP 9.0.1, KGP 2.3.20, built-in Kotlin, and typed Kotlin compiler
options. The app module no longer applies the external Kotlin Android plugin.
Flutter's static KGP detector also scans plugin source, so exact resolved local
compatibility copies of `firebase_core` 4.15.0, `firebase_crashlytics` 5.4.0,
and `workmanager_android` 0.10.9 are maintained under
`third_party/flutter_plugins/`. They retain upstream code and licenses and only
replace the legacy Kotlin plugin application expression with the equivalent
plugin-manager call. This keeps runtime behavior on the resolved pub versions
while allowing AGP 9 built-in Kotlin builds to complete without the warning.

## Verification consequences

- Route, role, capability, repository-state, offline database, outbox, and
  generated-code checks run on the host.
- Docker-local API checks validate real GET/PATCH/PUT/role-boundary behavior
  without using an emulator.
- APK and AAB validation is artifact-only. iOS validation is configuration-only
  on Linux. Device, browser, live iOS, and notification walkthroughs are not
  part of this frontend-only validation scope.

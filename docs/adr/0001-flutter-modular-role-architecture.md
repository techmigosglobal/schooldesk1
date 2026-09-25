# ADR-0001: Modular role architecture and offline repository boundary

## Status

Accepted

## Context

SchoolDesk is one installable Flutter application serving multiple roles with
different tenant, branch, and capability boundaries. The previous frontend
allowed widgets to reach transport clients and a generic shared feature layer
directly. It also maintained a second durable HTTP cache beside the Drift
offline store, which made scope and stale-data behavior harder to reason about.

## Decision

- Riverpod is the composition-root dependency boundary for new and migrated
  modules.
- `go_router` owns typed, role-aware navigation. Compatibility aliases remain
  until their consumers are migrated.
- Roles are isolated modules: Principal, Coordinator, Teacher, Parent, Kiosk,
  and Super Admin. Business capabilities are separate from role shells.
- Repositories expose `RepositoryState<T>` and keep Drift as the authoritative
  durable local cache. API transport is a refresh source, not a widget API.
- Every local record and queued mutation is scoped by account, school, branch,
  and role. Only explicitly safe writes may queue offline.
- Backend authorization remains authoritative; client policy is navigation and
  user-experience guidance only.
- Production runtime uses live API responses and scoped Drift data only. Demo
  account creation, fixture stores, demo interceptors, and demo role selection
  are excluded from the Flutter client.
- Android is pinned to the current Flutter-supported AGP/KGP thresholds
  (AGP 9.0.1 and KGP 2.3.20). Built-in Kotlin is enabled with
  `android.builtInKotlin=true`; the app module uses typed Kotlin compiler
  options without applying the external Kotlin plugin. Flutter still emits a
  forward-compatibility warning for upstream Firebase and Workmanager plugin
  build scripts, tracked as an upstream dependency gate.

## Consequences

Positive:

- Role boundaries and offline scope are explicit and testable.
- Cached reads, stale status, retries, and queued mutations have one durable
  boundary.
- New screens can be migrated without importing legacy service-locator code.

Trade-offs:

- The migration is staged and temporarily contains adapters for legacy routes
  and Provider-based screens.
- Generated API clients remain until all consumers cross the repository seam.
- More explicit contracts are required for small features.
- The Android build is successful without app-level KGP application, but still
  emits Flutter's forward-compatibility warning until those upstream plugins
  stop applying KGP in their build scripts.

## Rejected alternatives

- A global generic `features/shared` business layer was rejected because it
  obscures role ownership and makes authorization drift likely.
- A second Hive HTTP cache was rejected because Drift already provides scoped,
  durable cache and offline fallback semantics.

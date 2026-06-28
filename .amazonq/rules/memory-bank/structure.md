# Project Structure — Arish Ville

## Top-Level Layout
```
schooldesk1/
├── lib/                        # Flutter app source
├── school-backend/             # Go REST API backend
├── android/ / ios/ / web/      # Platform-specific configs
├── assets/                     # Images, fonts, SVGs
├── test/ / integration_test/   # Dart tests
├── monitoring/                 # Prometheus + Grafana configs
├── deploy/                     # Hostinger/Traefik env examples
├── scripts/                    # Build and deploy shell scripts
├── docs/                       # PRD, SPEC, runbooks
├── Maestro/                    # Mobile E2E test flows (YAML)
└── docker-compose*.yml         # Various compose targets
```

## Flutter App — `lib/`

### Architecture: Feature-First + Clean Architecture
```
lib/
├── main.dart                   # App entry point, DI init, error handlers
├── app/
│   ├── module_registry.dart    # Declares all feature modules with routes
│   └── providers/
│       └── schooldesk_providers.dart
├── core/                       # Shared infrastructure (no business logic)
│   ├── config/env_config.dart  # API URL, timeout, logging flags from --dart-define
│   ├── constants/              # App constants, glossary, storage keys
│   ├── di/service_locator.dart # Manual singleton DI; AppProviders widget
│   ├── errors/                 # Exceptions, Failures, ErrorHandler
│   ├── navigation/role_nav_indices.dart  # Role-specific nav drawer indices
│   ├── network/
│   │   ├── backend_api_client.dart       # Central Dio HTTP client (singleton)
│   │   ├── api_modules/                  # Part files: auth, fees, staff, etc.
│   │   ├── generated/                    # Retrofit-generated API models
│   │   └── schooldesk_api.dart
│   ├── services/               # App-wide services (push notifications, PDF, theme)
│   ├── theme/                  # AppTheme + DesignTokens
│   ├── utils/                  # Extensions, validators, result type, helpers
│   └── widgets/                # Shared UI: ERP scaffold, navigation, skeletons
├── features/                   # Feature modules (one folder per domain)
│   ├── academics/
│   ├── attendance/
│   ├── auth/
│   ├── calendar/
│   ├── communication/
│   ├── dashboard/
│   ├── documents/
│   ├── finance/
│   ├── homework/
│   ├── leave/
│   ├── monitoring/
│   ├── operations/
│   ├── people/
│   ├── profile/
│   ├── reports/
│   ├── shared/                 # Cross-feature domain models, repositories
│   └── shell/                  # Landing page, onboarding
└── routes/
    ├── app_routes.dart          # All named routes and route builder
    ├── route_access_guard.dart  # Auth + role redirect logic
    └── schooldesk_screen_registry.dart  # Screen metadata registry
```

### Feature Module Internal Structure
Each feature follows this layered layout:
```
features/<module>/
├── <module>.dart              # Barrel export file
├── data/                      # API repositories (implements domain interfaces)
├── domain/                    # Entities, repository interfaces, use cases
└── presentation/
    ├── controllers/           # ChangeNotifier controllers
    └── screens/               # Flutter screen widgets
```

### Key Architectural Patterns (Flutter)
- `BackendApiClient` is a singleton Dio client; part files split by API domain
- `ServiceLocator` provides manual static DI; `AppProviders` wraps widget tree
- `flutter_riverpod` (ProviderScope) + `provider` (MultiProvider) coexist
- `SchoolDeskModuleRegistry` declares all modules and their owned routes
- `RouteAccessGuard` enforces authentication and role redirects
- `SchoolDeskRouteFrame` wraps each screen with role-aware drawer/nav
- Responsive design via `sizer` package (`50.w`, `20.h`, etc.)
- HTTP caching via `dio_cache_interceptor` with Hive store (5-min TTL)
- Error boundary via `CustomErrorWidget`, global error capture in `main()`

## Go Backend — `school-backend/`

### Structure
```
school-backend/
├── main.go                      # Server bootstrap
├── cmd/
│   ├── local-api-verify/main.go # Dev: smoke-test all API endpoints
│   └── seed/main.go             # DB seed with demo data
├── internal/
│   ├── config/config.go         # Env-based config struct
│   ├── database/
│   │   ├── database.go          # GORM DB init + migration runner
│   │   ├── tables_md_schema.go  # Dynamic "tables_md" schema (EAV tables)
│   │   └── constraints.go       # DB constraint helpers
│   ├── handlers/                # HTTP handlers (one file per domain)
│   ├── middleware/              # Auth JWT, cache, rate limit, metrics, request ID
│   ├── models/                  # GORM model structs + DTOs
│   ├── platform/redis_client.go # Redis connection
│   ├── policy/                  # JSON-based ownership policy matrix
│   ├── repositories/            # Data access layer (academic domain)
│   ├── routes/
│   │   ├── routes.go            # Main router setup (Gin)
│   │   ├── auth_routes.go
│   │   ├── dashboard_routes.go
│   │   ├── principal_routes.go
│   │   └── operational.go
│   ├── services/                # Business logic services
│   │   ├── smart_timetable.go   # Timetable conflict detection engine
│   │   ├── cache.go             # Redis cache wrapper
│   │   ├── push_notifications.go
│   │   └── job_queue.go
│   └── worker/                  # Background jobs: notifications, scheduled reports
└── tests/api_suite_test.go      # Integration test suite
```

### Key Backend Patterns
- **Gin** router with middleware chain: request ID → auth JWT → rate limit → metrics → handler
- **GORM** ORM with PostgreSQL; auto-migrate on startup
- **Dynamic EAV tables** (`tables_md_*`) for flexible per-school schema extension
- `policy/admin_principal_ownership_matrix.json` drives row-level ownership checks
- Redis for session store, job queue, and response caching
- Firebase Admin SDK for push notifications
- Background worker goroutines for scheduled reports and notification delivery

## Infrastructure
- `docker-compose.yml` — dev: app + PostgreSQL + Redis
- `docker-compose.hostinger-traefik.yml` — prod: Traefik TLS termination
- `docker-compose.observability.yml` — Prometheus + Grafana overlay
- `monitoring/prometheus/` — scrape config + alert rules
- `monitoring/grafana/` — provisioned dashboard "Arish Ville API Overview"

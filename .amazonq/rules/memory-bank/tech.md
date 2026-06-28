# Technology Stack — Arish Ville

## Flutter App

### Languages & Runtime
- **Dart** SDK `^3.9.0`
- **Flutter** SDK `^3.38.4` (Material Design, uses-material-design: true)
- App version: `1.0.9+17`

### Core Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `sizer` | ^2.0.15 | Responsive design (`50.w`, `20.h`) |
| `flutter_svg` | ^2.0.9 | SVG asset rendering |
| `google_fonts` | ^6.1.0 | Typography (bundled locally, no runtime fetch) |
| `shared_preferences` | ^2.2.2 | Local key-value storage |
| `dio` | ^5.4.0 | HTTP client |
| `dio_cache_interceptor` | ^3.5.1 | HTTP response caching |
| `dio_cache_interceptor_hive_store` | ^4.0.0 | Hive-backed cache store |
| `provider` | ^6.1.5+1 | State management (ChangeNotifier) |
| `flutter_riverpod` | ^3.3.1 | Reactive state management |
| `freezed_annotation` | ^3.1.0 | Immutable data classes |
| `json_annotation` | ^4.12.0 | JSON serialization |
| `retrofit` | ^4.9.2 | Type-safe HTTP client generator |
| `firebase_core` | ^4.7.0 | Firebase initialization |
| `firebase_messaging` | ^16.2.0 | FCM push notifications |
| `flutter_local_notifications` | ^21.0.0 | Local notification display |
| `pdf` | ^3.12.0 | PDF generation |
| `printing` | ^5.14.3 | PDF printing/sharing (local override) |
| `image_picker` | ^1.1.2 | Camera/gallery image selection |
| `image_cropper` | ^11.0.0 | Image cropping |
| `file_picker` | ^11.0.2 | Document file selection |
| `qr_flutter` | ^4.1.0 | QR code display |
| `mobile_scanner` | ^7.2.0 | QR code scanning |
| `share_plus` | ^12.0.2 | Share/export content |
| `auto_size_text` | ^3.0.0 | Auto-scaling text |
| `intl` | ^0.19.0 | Internationalization/date formatting |
| `url_launcher` | ^6.3.2 | Open URLs |
| `package_info_plus` | ^9.0.1 | App version info |
| `flutter_secure_storage` | ^10.3.1 | Secure token storage |
| `cached_network_image` | ^3.3.1 | Network image caching |
| `path_provider` | ^2.1.6 | File system paths |

### Dev Dependencies
| Package | Purpose |
|---------|---------|
| `build_runner` | Code generation runner |
| `freezed` | Immutable class generation |
| `json_serializable` | JSON serialization codegen |
| `retrofit_generator` | API client generation |
| `flutter_lints` | Lint rules |
| `integration_test` | Flutter integration tests |
| `patrol` | Enhanced integration testing |

### Environment Configuration
All runtime config is injected via `--dart-define-from-file=env.json`:
- `API_BASE_URL` — Backend URL (overrides default)
- `APP_ENV` — `development` | `staging` | `production`
- `API_TIMEOUT` — HTTP timeout in seconds (default: 30)
- `ENABLE_LOGGING` — Debug logging toggle
- `ENABLE_ANALYTICS` — Analytics toggle
- `FIREBASE_*` — Firebase project credentials
- `LOCAL_API_HOST` — Custom Android emulator host

**Default production URL**: `https://schooldesk1-production.up.railway.app/api`
**Local dev Android**: `http://10.0.2.2:8080/api` (or `adb reverse tcp:8080 tcp:8080`)

### Analysis & Linting
- `analysis_options.yaml` at project root
- `flutter_lints` enforced

### Code Generation
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
Generates: `*.freezed.dart`, `*.g.dart` (JSON serialization, Retrofit clients)

---

## Go Backend

### Language & Runtime
- **Go** `1.26`
- Module: `school-backend`

### Core Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `github.com/gin-gonic/gin` | v1.12.0 | HTTP router/framework |
| `gorm.io/gorm` | v1.30.0 | ORM |
| `gorm.io/driver/postgres` | v1.6.0 | PostgreSQL driver |
| `github.com/redis/go-redis/v9` | v9.18.0 | Redis client |
| `github.com/golang-jwt/jwt/v5` | v5.2.0 | JWT authentication |
| `github.com/google/uuid` | v1.6.0 | UUID generation |
| `golang.org/x/crypto` | v0.48.0 | Password hashing (bcrypt) |
| `firebase.google.com/go/v4` | v4.19.0 | Firebase Admin SDK (FCM) |
| `github.com/stretchr/testify` | v1.11.1 | Test assertions |
| `gorm.io/datatypes` | v1.2.7 | GORM JSON/datatypes support |
| `github.com/glebarez/sqlite` | v1.11.0 | SQLite (for local dev/test) |

### Database
- **Primary**: PostgreSQL (via GORM + pgx driver)
- **Dev/Test**: SQLite (glebarez/go-sqlite)
- Migrations run automatically on startup via `database.Initialize(cfg)`
- Dynamic EAV schema via `tables_md_*` for flexible data extension

### Caching & Messaging
- **Redis** for: session store, job queue, rate limiting, response cache
- **Firebase FCM** for push notification delivery

### Observability
- **Prometheus** metrics exposed at `/metrics` endpoint
- **Grafana** dashboard: "Arish Ville API Overview"
- Alert rules in `monitoring/prometheus/rules/schooldesk-alerts.yml`
- Custom middleware: `MetricsMiddleware` records request counts/latencies

### Configuration (Environment Variables)
```
DATABASE_URL          PostgreSQL connection string
REDIS_URL             Redis connection string
JWT_SECRET            JWT signing secret
ALLOWED_ORIGINS       CORS allowed origins
PORT                  HTTP server port (default from config)
ENVIRONMENT           development | production
APP_MODE              server | worker
ENABLE_FCM_PUSH       Enable Firebase push notifications
FIREBASE_PROJECT_ID   Firebase project
FIREBASE_SERVICE_ACCOUNT_JSON  Firebase service account JSON
```

### Dev Tooling
- **Air** (`school-backend/.air.toml`) — hot reload during development
- **Docker** — `Dockerfile` (production) + `Dockerfile.dev` (development)
- `cmd/seed/main.go` — seed database with demo users/data
- `cmd/local-api-verify/main.go` — smoke test all endpoints locally

---

## Infrastructure & DevOps

### Docker Compose Targets
| File | Purpose |
|------|---------|
| `docker-compose.yml` | Dev: app + PostgreSQL + Redis |
| `docker-compose.prod.yml` | Production without Traefik |
| `docker-compose.hostinger-traefik.yml` | Prod with Traefik TLS |
| `docker-compose.observability.yml` | Add-on: Prometheus + Grafana |

### Build & Deploy Scripts (`scripts/`)
```bash
scripts/build-android-vps.sh apk   # Build release APK
scripts/build-android-vps.sh aab   # Build release AAB
scripts/deploy-hostinger-backend.sh  # Deploy to Hostinger VPS
scripts/verify-local-docker-api.sh   # Verify local Docker API
scripts/verify-observability.sh      # Verify Prometheus/Grafana stack
```

### CI / Testing
- Flutter unit tests: `flutter test`
- Flutter integration tests: `flutter test integration_test/`
- Go unit tests: `go test ./...` (from `school-backend/`)
- Maestro E2E flows: `maestro test Maestro/`
- Patrol integration tests: `patrol test`

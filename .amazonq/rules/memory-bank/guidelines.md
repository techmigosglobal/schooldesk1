# Development Guidelines — Arish Ville

## Go Backend Patterns

### Handler Structure
All handlers follow a consistent struct-based pattern:

```go
type FeeHandler struct{}

func NewFeeHandler() *FeeHandler {
    return &FeeHandler{}
}

func (h *FeeHandler) GetFeeCategories(c *gin.Context) {
    schoolID := scopedSchoolID(c)
    // ... handler logic
    c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: result})
}
```

- Every handler is a zero-value struct with a `New<Name>Handler()` constructor
- Handlers are instantiated once in `routes.go` and reused across routes
- Methods receive `*gin.Context` only — no global state in handlers

### Response Conventions
All responses use one of two helper functions or `c.JSON` directly:

```go
// Success with data and optional message
success(c, http.StatusOK, data, "Optional message")
success(c, http.StatusCreated, entity, "Entity created")

// Error shorthand
fail(c, http.StatusBadRequest, "Descriptive error message")
fail(c, http.StatusNotFound, "Resource not found")

// Direct JSON (legacy, still used in some handlers)
c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: result})
c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
```

All successful list responses use `paginationResult(page, pageSize, total, rows)`.

### Request Binding Pattern
All handlers use `c.ShouldBindJSON(&req)` with inline anonymous structs for request bodies:

```go
var req struct {
    CategoryName string `json:"category_name" binding:"required"`
    Frequency    string `json:"frequency" binding:"required"`
    IsRefundable bool   `json:"is_refundable"`
}
if err := c.ShouldBindJSON(&req); err != nil {
    c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
    return
}
```

- Always check `ShouldBindJSON` error immediately and return on failure
- Use `binding:"required"` tags for mandatory fields
- Use pointer types (`*string`, `*float64`) for optional update fields

### School Scoping (Multi-Tenant Security)
Every handler scopes data to the authenticated school:

```go
schoolID := scopedSchoolID(c)   // always use this, not raw from request
currentRole(c)                  // "Principal", "Teacher", "Parent"
currentUserID(c)                // authenticated user's UUID
```

Never trust school_id from the request body — always use `scopedSchoolID(c)`.

### Transactions Pattern
Use `database.DB.Transaction(func(tx *gorm.DB) error { ... })` for all multi-step writes:

```go
err = database.DB.Transaction(func(tx *gorm.DB) error {
    if err := tx.Create(&entity).Error; err != nil {
        return err
    }
    return tx.Create(&relatedEntity).Error
})
if err != nil {
    c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save"})
    return
}
```

- Return error from within the transaction closure to trigger rollback
- Check `err == gorm.ErrRecordNotFound` for 404 vs 500 distinction after transactions

### GORM Query Patterns
```go
// Standard scoped query
database.DB.Where("school_id = ? AND id = ?", schoolID, id).First(&entity)

// Conditional filter building
query := database.DB.Model(&models.Entity{})
if filter != "" {
    query = query.Where("column = ?", filter)
}
query.Find(&results)

// Preloading related data
database.DB.Preload("Student").Preload("Student.CurrentSection").First(&invoice)

// Pagination
database.DB.Offset((page - 1) * pageSize).Limit(pageSize).Find(&rows)

// Count before paginating (using same query builder)
query.Count(&total)
```

### Input Normalization
All string inputs are normalized before use:

```go
strings.TrimSpace(value)
strings.ToLower(strings.TrimSpace(value))
strings.ToUpper(strings.TrimSpace(value))
```

Enumerated string values use `switch` normalization functions:
```go
func normalizeInstallmentMethod(value string) string {
    text := strings.ToLower(strings.TrimSpace(value))
    text = strings.ReplaceAll(text, "-", "_")
    switch text {
    case "percentage", "percentage_division":
        return "percentage"
    default:
        return "equal"
    }
}
```

### Audit Logging
Every write operation calls `auditAction` after success:

```go
id := entity.ID
auditAction(c, "fees", "create", "fee_categories", &id)
auditAction(c, "fees", "update", "fee_structures", &id)
auditAction(c, "fees", "delete", "fee_categories", &id)
```

Arguments: `(ctx, module, action, table, &entityID)`.

### Middleware Chain (routes.go)
Routes are always grouped with `Use()` before registering handlers:

```go
group := api.Group("/fees")
group.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
{
    group.GET("/categories", feeHandler.GetFeeCategories)
    group.POST("/categories",
        middleware.RBACMiddleware("Principal"),
        middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, ...),
        feeHandler.CreateFeeCategory,
    )
}
```

- All routes require `AuthMiddleware()` + `SchoolScopeMiddleware()`
- Write operations always add `RBACMiddleware(roles...)` + `RateLimitMiddleware(key, ...)`
- Read operations may omit rate limiting but still require RBAC where sensitive
- Both PUT and PATCH are registered on the same handler for all update operations

### RBAC Role Names
Role strings are PascalCase: `"Principal"`, `"Teacher"`, `"Parent"`, `"Kiosk"`.

### Service Layer Pattern
Business logic services use constructor injection:

```go
type SmartTimetableEngine struct {
    db *gorm.DB
}

func NewSmartTimetableEngine(db *gorm.DB) *SmartTimetableEngine {
    return &SmartTimetableEngine{db: db}
}
```

- Services accept `context.Context` as the first parameter for DB calls
- Use `e.db.WithContext(ctx)` on every DB call in services (not `database.DB` directly)
- Service methods return `(ResultType, error)` — never `gin.Context`

### Conflict Detection Pattern
Conflict checks use three-level nested map: `map[entityID]map[day]map[period]bool`

```go
markBusy(state.StaffBusy, staffID, day, period)
isBusy(state.StaffBusy, staffID, day, period)
```

### Utility Functions
Frequently reused small helpers defined at package level:

```go
firstNonEmpty(values ...string) string   // returns first non-blank/non-<nil> value
roundMoney(amount float64) float64       // math.Round(x*100)/100
countRows(query *gorm.DB) int64          // helper for existence checks
```

### Database Initialization (database.go)
- `database.DB` is a package-level `*gorm.DB` singleton
- Auto-migration runs in 3 phases (foundation → staff/student/auth → operational)
- Postgres-specific DDL fixes are applied inline after AutoMigrate with `EXCEPTION WHEN others THEN NULL` guards
- Connection pool configured from config: `DBMaxOpenConns`, `DBMaxIdleConns`, `DBConnMaxLifetimeMinutes`
- Startup retries use `retryStartup()` with configurable attempts + delay

### Money Arithmetic
Always round to 2 decimal places using `roundMoney()`:

```go
newPayable := roundMoney(total - concessionAmount + fineAmount)
if newPayable < 0 {
    newPayable = 0
}
```

Never allow negative monetary values — always clamp to 0 after calculation.

---

## Flutter App Patterns

### State Management
- `ChangeNotifier` controllers for screen-level state (`extends ChangeNotifier`)
- `flutter_riverpod` (ProviderScope) for reactive cross-widget state
- `provider` (MultiProvider + ChangeNotifierProvider) for app-wide services
- Dashboard controllers are screen-local; `AuthController` is shared globally via `ServiceLocator`

### API Client Usage
All API calls go through `BackendApiClient.instance`:

```dart
final response = await BackendApiClient.instance.getFeeInvoices(
  studentId: studentId,
);
```

- Never create new `Dio` instances — always use the singleton
- The client handles token injection, caching, and error interception automatically
- Cache invalidation: call `BackendApiClient.instance.invalidateStudentCache()` after writes

### Route Navigation
Use named routes with typed args objects:

```dart
Navigator.pushNamed(
  context,
  AppRoutes.teacherLeaveRequestForm,
  arguments: TeacherLeaveRequestFormArgs(
    staffId: staffId,
    staffName: staffName,
    leaveTypes: leaveTypes,
    balances: balances,
  ),
);
```

- All routes are defined as constants in `AppRoutes`
- Route args are strongly typed classes with `const` constructors
- In `app_routes.dart`, args are extracted via `ModalRoute.of(context)?.settings.arguments` with type checking and safe defaults

### Responsive Design
Use `sizer` package for all layout dimensions:

```dart
Container(
  width: 50.w,     // percentage of screen width
  height: 20.h,    // percentage of screen height
  padding: EdgeInsets.all(2.w),
)
```

- Never use hardcoded pixel values for layout dimensions
- Use `auto_size_text` for text that must fit within constrained containers
- Clamp text scale factor (set in `main.dart`) — do not override `MediaQuery.textScaler` locally

### Theme Usage
Always use theme tokens, never hardcoded colors or text styles:

```dart
final theme = Theme.of(context);
final primary = theme.colorScheme.primary;
final surface = theme.colorScheme.surface;
final bodyText = theme.textTheme.bodyMedium;
```

### Error Handling
- Global error boundary via `CustomErrorWidget` — set in `main.dart`
- Service-level errors use the `Result<T>` type from `lib/core/utils/result.dart`
- Never swallow errors silently in feature code — use `ErrorReportingService.instance.recordError()`

### Environment Config
Never hardcode URLs or API keys:

```dart
// Correct
final url = EnvConfig.apiBaseUrl;

// Wrong
final url = 'https://api.example.com/api/v1';
```

All config comes from `--dart-define-from-file=env.json` at build time.

### Asset References
Only use asset paths that are declared in `pubspec.yaml`:
```dart
// Correct
Image.asset('assets/images/ui/empty-state.svg')
SvgPicture.asset('assets/images/ui/illustration-attendance.svg')

// Wrong — path not declared in pubspec.yaml
Image.asset('assets/other/image.png')
```

Font loading must use `GoogleFonts` with local bundled files — never enable runtime font fetching:
```dart
// main.dart — already set globally, do not override
GoogleFonts.config.allowRuntimeFetching = false;
```

### Module Barrel Exports
Each feature module exports its public surface via a barrel file:
```dart
// features/finance/finance.dart
export 'presentation/screens/fee_monitoring_screen.dart';
export 'presentation/controllers/fee_controller.dart';
```

Import from the barrel file, not directly from internal paths.

---

## Code Quality Standards

### Go
- All user-provided string inputs are sanitized with `strings.TrimSpace` before use
- Enumerated values (status, frequency, scope) use lowercase snake_case strings
- `gorm.ErrRecordNotFound` is always explicitly checked to distinguish 404 from 500
- File uploads validate extension against an explicit allowlist (`map[string]bool`)
- Passwords are hashed with `bcrypt.DefaultCost` via `HashPassword()`
- JWT secrets and credentials never appear in source code — always from environment

### Dart/Flutter
- `const` constructors used wherever possible for widgets and args objects
- `super.key` pattern used in all widget constructors
- `unawaited()` wraps fire-and-forget futures to suppress lint warnings
- No hardcoded strings for routes — always use `AppRoutes.*` constants
- Semantic accessibility is initialized in `main()` via `SemanticsBinding.instance.ensureSemantics()`
- Release builds enforce HTTPS via `EnvConfig.validate()` at startup

### Testing
- Go: handler tests use `database.Initialize()` with SQLite in-memory; test helpers in `helpers_test.go`
- Dart: unit tests in `test/unit/`, widget tests in `test/widget/`
- Contract tests (many files in `test/unit/`) verify frontend-backend API shape consistency
- Integration tests in `integration_test/` use `patrol` for full app flows
- E2E flows in `Maestro/` use YAML-based Maestro scripts for cross-role workflows

### Naming Conventions
| Context | Convention | Example |
|---------|-----------|---------|
| Go packages | lowercase | `handlers`, `services` |
| Go types | PascalCase | `FeeHandler`, `SmartTimetableEngine` |
| Go functions | camelCase | `scopedSchoolID`, `roundMoney` |
| Go JSON tags | snake_case | `fee_category_id`, `is_refundable` |
| Dart classes | PascalCase | `BackendApiClient`, `AppRoutes` |
| Dart variables | camelCase | `schoolID`, `feeHandler` |
| Dart constants | camelCase | `AppRoutes.feeMonitoring` |
| Route paths | kebab-case | `/fee-monitoring-screen` |
| API endpoints | kebab-case | `/fees/payment-requests` |
| DB tables | snake_case | `fee_invoice_items`, `parent_payment_requests` |

### Security Checklist
- All mutation routes require `RBACMiddleware` with explicit role list
- School scope isolation enforced via `SchoolScopeMiddleware` + `scopedSchoolID(c)` in every query
- Rate limiting applied on all write operations
- Sensitive fields (`token`, `password`, `authorization`) are redacted in logs/reports
- File uploads validate MIME type by extension allowlist before saving
- Parent payment requests validate `ParentStudentLink` ownership before allowing access
- Release builds: `EnvConfig.validate()` throws if API URL is not HTTPS

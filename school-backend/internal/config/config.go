package config

import (
	"errors"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	Port                          string
	AppMode                       string
	DatabaseURL                   string
	DatabaseDSN                   string
	JWTSecret                     string
	Environment                   string
	AllowedOrigins                []string
	RedisURL                      string
	RedisPassword                 string
	RedisDB                       int
	DBMaxOpenConns                int
	DBMaxIdleConns                int
	DBConnMaxLifetimeMinutes      int
	StartupRetryAttempts          int
	StartupRetryDelaySeconds      int
	CacheTTLSeconds               int
	RateLimitWindowSeconds        int
	RateLimitMaxLogin             int
	RateLimitMaxAPI               int
	DisablePublicRegistration     bool
	MigrateOnStart                bool
	SeedOnStart                   bool
	UsePostgresOnly               bool
	RequireHTTPSAPIBaseURL        bool
	EnableRelationshipConstraints bool
	EnableFCMPush                 bool
	FirebaseProjectID             string
}

func Load() *Config {
	env := getEnv("ENVIRONMENT", "development")
	isProd := env == "production"
	origins := parseCSV(getEnv("ALLOWED_ORIGINS", ""))
	if !isProd && len(origins) == 0 {
		origins = []string{
			"http://localhost:3000",
			"http://localhost:8080",
			"http://localhost:45123",
			"http://127.0.0.1:3000",
			"http://127.0.0.1:8080",
			"http://127.0.0.1:45123",
		}
	}
	return &Config{
		Port:                          getEnv("PORT", "8080"),
		AppMode:                       getEnv("APP_MODE", "api"),
		DatabaseURL:                   strings.TrimSpace(getEnv("DATABASE_URL", "")),
		DatabaseDSN:                   getEnv("DATABASE_DSN", "school.db"),
		JWTSecret:                     getEnv("JWT_SECRET", "dev-insecure-secret-change-me"),
		Environment:                   env,
		AllowedOrigins:                origins,
		RedisURL:                      strings.TrimSpace(getEnv("REDIS_URL", "")),
		RedisPassword:                 getEnv("REDIS_PASSWORD", ""),
		RedisDB:                       getEnvAsInt("REDIS_DB", 0),
		DBMaxOpenConns:                getEnvAsInt("DB_MAX_OPEN_CONNS", 25),
		DBMaxIdleConns:                getEnvAsInt("DB_MAX_IDLE_CONNS", 10),
		DBConnMaxLifetimeMinutes:      getEnvAsInt("DB_CONN_MAX_LIFETIME_MINUTES", 30),
		StartupRetryAttempts:          getEnvAsInt("STARTUP_RETRY_ATTEMPTS", 30),
		StartupRetryDelaySeconds:      getEnvAsInt("STARTUP_RETRY_DELAY_SECONDS", 2),
		CacheTTLSeconds:               getEnvAsInt("CACHE_TTL_SECONDS", 120),
		RateLimitWindowSeconds:        getEnvAsInt("RATE_LIMIT_WINDOW_SECONDS", 60),
		RateLimitMaxLogin:             getEnvAsInt("RATE_LIMIT_MAX_LOGIN", 5),
		RateLimitMaxAPI:               getEnvAsInt("RATE_LIMIT_MAX_API", 120),
		DisablePublicRegistration:     getEnvAsBool("DISABLE_PUBLIC_REGISTRATION", isProd),
		MigrateOnStart:                getEnvAsBool("MIGRATE_ON_START", !isProd),
		SeedOnStart:                   getEnvAsBool("SEED_ON_START", false),
		UsePostgresOnly:               getEnvAsBool("USE_POSTGRES_ONLY", isProd),
		RequireHTTPSAPIBaseURL:        getEnvAsBool("REQUIRE_HTTPS_API_BASE_URL", isProd),
		EnableRelationshipConstraints: getEnvAsBool("ENABLE_RELATIONSHIP_CONSTRAINTS", false),
		EnableFCMPush:                 getEnvAsBool("ENABLE_FCM_PUSH", false),
		FirebaseProjectID:             strings.TrimSpace(getEnv("FIREBASE_PROJECT_ID", "")),
	}
}

func (c *Config) Validate() error {
	if c.Environment != "production" {
		return nil
	}

	if strings.TrimSpace(c.JWTSecret) == "" {
		return errors.New("missing JWT_SECRET in production")
	}
	if len(c.JWTSecret) < 32 {
		return errors.New("JWT_SECRET must be at least 32 characters in production")
	}
	if c.DatabaseURL == "" {
		return errors.New("missing DATABASE_URL in production")
	}
	if c.RedisURL == "" {
		return errors.New("missing REDIS_URL in production")
	}
	if strings.TrimSpace(c.RedisPassword) == "" {
		return errors.New("missing REDIS_PASSWORD in production")
	}
	if len(c.AllowedOrigins) == 0 {
		return errors.New("missing ALLOWED_ORIGINS in production")
	}
	if c.EnableFCMPush && strings.TrimSpace(c.FirebaseProjectID) == "" {
		return errors.New("missing FIREBASE_PROJECT_ID when ENABLE_FCM_PUSH=true")
	}
	return nil
}

func parseCSV(value string) []string {
	if strings.TrimSpace(value) == "" {
		return []string{}
	}
	parts := strings.Split(value, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		clean := strings.TrimSpace(p)
		if clean != "" {
			out = append(out, clean)
		}
	}
	return out
}

func getEnvAsInt(key string, defaultValue int) int {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return defaultValue
	}
	parsed, err := strconv.Atoi(raw)
	if err != nil {
		return defaultValue
	}
	return parsed
}

func getEnvAsBool(key string, defaultValue bool) bool {
	raw := strings.TrimSpace(strings.ToLower(os.Getenv(key)))
	if raw == "" {
		return defaultValue
	}
	return raw == "1" || raw == "true" || raw == "yes" || raw == "on"
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

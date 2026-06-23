package config

import "testing"

func TestValidateProductionRequiresCriticalFields(t *testing.T) {
	cfg := &Config{
		Environment: "production",
	}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected validation error for missing required fields")
	}
}

func TestValidateProductionSuccess(t *testing.T) {
	cfg := &Config{
		Environment:    "production",
		JWTSecret:      "12345678901234567890123456789012",
		DatabaseURL:    "postgres://user:pass@db:5432/app",
		RedisURL:       "redis://:pass@redis:6379/0",
		RedisPassword:  "pass",
		AllowedOrigins: []string{"https://app.example.com"},
	}
	if err := cfg.Validate(); err != nil {
		t.Fatalf("expected no validation error, got %v", err)
	}
}

func TestValidateProductionAllowsMissingOptionalUPIConfig(t *testing.T) {
	cfg := &Config{
		Environment:    "production",
		JWTSecret:      "12345678901234567890123456789012",
		DatabaseURL:    "postgres://user:pass@db:5432/app",
		RedisURL:       "redis://:pass@redis:6379/0",
		RedisPassword:  "pass",
		AllowedOrigins: []string{"https://app.example.com"},
	}
	if err := cfg.Validate(); err != nil {
		t.Fatalf("expected no validation error, got %v", err)
	}
}

func TestLoadReadsRelationshipConstraintFlag(t *testing.T) {
	t.Setenv("ENABLE_RELATIONSHIP_CONSTRAINTS", "true")

	cfg := Load()
	if !cfg.EnableRelationshipConstraints {
		t.Fatal("expected ENABLE_RELATIONSHIP_CONSTRAINTS=true to enable relationship constraints")
	}
}

func TestValidateProductionFCMPushRequiresFirebaseCredentials(t *testing.T) {
	cfg := &Config{
		Environment:    "production",
		JWTSecret:      "12345678901234567890123456789012",
		DatabaseURL:    "postgres://user:pass@db:5432/app",
		RedisURL:       "redis://:pass@redis:6379/0",
		RedisPassword:  "pass",
		AllowedOrigins: []string{"https://app.example.com"},
		EnableFCMPush:  true,
	}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected validation error when FCM push is enabled without Firebase project")
	}

	cfg.FirebaseProjectID = "schooldesk1-509e0"
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected validation error when FCM push is enabled without Firebase credentials")
	}

	cfg.FirebaseServiceAccountJSON = `{"type":"service_account","project_id":"schooldesk1-509e0"}`
	if err := cfg.Validate(); err != nil {
		t.Fatalf("expected Firebase service account JSON to satisfy FCM validation, got %v", err)
	}
}

func TestLoadReadsFirebaseServiceAccountJSON(t *testing.T) {
	t.Setenv("FIREBASE_SERVICE_ACCOUNT_JSON", `{"type":"service_account"}`)

	cfg := Load()
	if cfg.FirebaseServiceAccountJSON == "" {
		t.Fatal("expected FIREBASE_SERVICE_ACCOUNT_JSON to be loaded")
	}
}

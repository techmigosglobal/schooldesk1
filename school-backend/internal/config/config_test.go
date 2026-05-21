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

func TestLoadReadsRelationshipConstraintFlag(t *testing.T) {
	t.Setenv("ENABLE_RELATIONSHIP_CONSTRAINTS", "true")

	cfg := Load()
	if !cfg.EnableRelationshipConstraints {
		t.Fatal("expected ENABLE_RELATIONSHIP_CONSTRAINTS=true to enable relationship constraints")
	}
}

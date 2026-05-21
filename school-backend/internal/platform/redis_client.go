package platform

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"school-backend/internal/config"

	"github.com/redis/go-redis/v9"
)

func NewRedisClient(cfg *config.Config) (*redis.Client, error) {
	if strings.TrimSpace(cfg.RedisURL) == "" {
		return nil, errors.New("REDIS_URL is required")
	}

	opts, err := redis.ParseURL(cfg.RedisURL)
	if err != nil {
		return nil, fmt.Errorf("invalid REDIS_URL: %w", err)
	}
	if cfg.RedisPassword != "" {
		opts.Password = cfg.RedisPassword
	}
	opts.DB = cfg.RedisDB
	opts.ReadTimeout = 2 * time.Second
	opts.WriteTimeout = 2 * time.Second
	opts.DialTimeout = 2 * time.Second

	client := redis.NewClient(opts)
	attempts := cfg.StartupRetryAttempts
	if attempts < 1 {
		attempts = 1
	}
	delay := time.Duration(cfg.StartupRetryDelaySeconds) * time.Second
	if delay <= 0 {
		delay = time.Second
	}
	var lastErr error
	for attempt := 1; attempt <= attempts; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		err := client.Ping(ctx).Err()
		cancel()
		if err == nil {
			return client, nil
		}
		lastErr = err
		if attempt < attempts {
			time.Sleep(delay)
		}
	}
	_ = client.Close()
	return nil, fmt.Errorf("failed redis ping: %w", lastErr)
}

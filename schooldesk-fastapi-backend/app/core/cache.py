from __future__ import annotations

import json
from functools import wraps
from typing import Any, Callable, TypeVar, ParamSpec

import redis

T = TypeVar("T")
P = ParamSpec("P")


class Cache:
    """Redis cache client with graceful fallback when Redis is unavailable."""

    def __init__(self, redis_url: str):
        self._redis_url = redis_url
        self._client: redis.Redis | None = None
        self._available: bool = False
        # Lazy import to avoid structlog not being configured at module load time
        from app.core.logging_config import get_logger
        self._logger = get_logger(__name__)
        self._connect()

    def _connect(self) -> None:
        """Establish Redis connection with error handling."""
        try:
            self._client = redis.from_url(self._redis_url, decode_responses=True, socket_connect_timeout=5)
            self._client.ping()
            self._available = True
            self._logger.info("redis_cache_connected", url=self._redis_url)
        except redis.RedisError as exc:
            self._logger.warning("redis_cache_unavailable", url=self._redis_url, error=str(exc))
            self._available = False

    @property
    def is_available(self) -> bool:
        return self._available and self._client is not None

    def get(self, key: str) -> Any | None:
        """Get value from cache. Returns None if cache unavailable."""
        if not self.is_available:
            return None
        try:
            val = self._client.get(key)
            if val:
                self._logger.debug("cache_hit", key=key)
                return json.loads(val)
            self._logger.debug("cache_miss", key=key)
            return None
        except redis.RedisError as exc:
            self._logger.warning("cache_get_error", key=key, error=str(exc))
            self._available = False
            return None

    def set(self, key: str, value: Any, ttl: int = 120) -> None:
        """Set value in cache with TTL. Silently ignores errors."""
        if not self.is_available:
            return
        try:
            self._client.setex(key, ttl, json.dumps(value, default=str))
            self._logger.debug("cache_set", key=key, ttl=ttl)
        except redis.RedisError as exc:
            self._logger.warning("cache_set_error", key=key, error=str(exc))
            self._available = False

    def delete(self, key: str) -> None:
        """Delete a single key from cache."""
        if not self.is_available:
            return
        try:
            self._client.delete(key)
            self._logger.debug("cache_delete", key=key)
        except redis.RedisError as exc:
            self._logger.warning("cache_delete_error", key=key, error=str(exc))
            self._available = False

    def delete_pattern(self, pattern: str) -> None:
        """Delete all keys matching pattern."""
        if not self.is_available:
            return
        try:
            keys = list(self._client.keys(pattern))
            if keys:
                self._client.delete(*keys)
                self._logger.debug("cache_delete_pattern", pattern=pattern, count=len(keys))
        except redis.RedisError as exc:
            self._logger.warning("cache_delete_pattern_error", pattern=pattern, error=str(exc))
            self._available = False


# Global cache instance (initialized lazily)
_cache: Cache | None = None


def get_cache(redis_url: str = "redis://localhost:6380/0") -> Cache:
    """Get or create the global cache instance."""
    global _cache
    if _cache is None:
        _cache = Cache(redis_url)
    return _cache


def cached(key_prefix: str, ttl: int = 120):
    """Decorator to cache function results."""
    def decorator(func: Callable[P, T]) -> Callable[P, T]:
        @wraps(func)
        def wrapper(*args: P.args, **kwargs: P.kwargs) -> T:
            cache = get_cache()
            cache_key = f"{key_prefix}:{str(args)}:{str(kwargs)}"
            cached_value = cache.get(cache_key)
            if cached_value is not None:
                return cached_value
            result = func(*args, **kwargs)
            cache.set(cache_key, result, ttl=ttl)
            return result
        return wrapper
    return decorator
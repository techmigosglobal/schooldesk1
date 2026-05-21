package services

var (
	Cache    *CacheService
	Rate     *RateLimitService
	Sessions *SessionStore
	Queue    *JobQueue
	Push     PushSender
)

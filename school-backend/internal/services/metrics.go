package services

import "sync/atomic"

var notificationWorkerFailures atomic.Uint64

func RecordNotificationWorkerFailure() {
	notificationWorkerFailures.Add(1)
}

func NotificationWorkerFailures() uint64 {
	return notificationWorkerFailures.Load()
}

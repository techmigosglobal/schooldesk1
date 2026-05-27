package handlers

import (
	"testing"
	"time"
)

func mustTimetableTestClock(t testing.TB, value string) *time.Time {
	t.Helper()
	parsed, err := timetableClockPointer(value)
	if err != nil {
		t.Fatalf("parse timetable clock %q: %v", value, err)
	}
	return parsed
}

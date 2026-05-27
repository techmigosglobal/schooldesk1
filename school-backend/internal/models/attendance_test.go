package models

import (
	"encoding/json"
	"testing"
	"time"
)

func TestTimetableSlotMarshalJSONUsesClockStrings(t *testing.T) {
	start := time.Date(2000, 1, 1, 9, 5, 0, 0, time.UTC)
	end := time.Date(2000, 1, 1, 9, 45, 0, 0, time.UTC)
	slot := TimetableSlot{
		StartTime: &start,
		EndTime:   &end,
	}

	var payload map[string]any
	if err := json.Unmarshal(mustMarshalJSON(t, slot), &payload); err != nil {
		t.Fatalf("unmarshal timetable JSON: %v", err)
	}

	if payload["start_time"] != "09:05" {
		t.Fatalf("start_time = %v, want 09:05", payload["start_time"])
	}
	if payload["end_time"] != "09:45" {
		t.Fatalf("end_time = %v, want 09:45", payload["end_time"])
	}
}

func mustMarshalJSON(t *testing.T, value any) []byte {
	t.Helper()
	data, err := json.Marshal(value)
	if err != nil {
		t.Fatalf("marshal JSON: %v", err)
	}
	return data
}

package models

import (
	"context"
	"encoding/json"
	"fmt"
	"reflect"
	"strings"
	"time"

	"gorm.io/gorm/schema"
)

func init() {
	schema.RegisterSerializer("clocktime", clockTimeSerializer{})
}

type clockTimeSerializer struct{}

func (clockTimeSerializer) Scan(ctx context.Context, field *schema.Field, dst reflect.Value, dbValue interface{}) error {
	fieldValue := field.ReflectValueOf(ctx, dst)
	if dbValue == nil {
		fieldValue.Set(reflect.Zero(field.FieldType))
		return nil
	}

	clock, err := parseDBClockTime(dbValue)
	if err != nil {
		return err
	}
	if field.FieldType.Kind() == reflect.Ptr {
		fieldValue.Set(reflect.ValueOf(&clock))
		return nil
	}
	fieldValue.Set(reflect.ValueOf(clock))
	return nil
}

func (clockTimeSerializer) Value(_ context.Context, _ *schema.Field, _ reflect.Value, fieldValue interface{}) (interface{}, error) {
	switch value := fieldValue.(type) {
	case nil:
		return nil, nil
	case *time.Time:
		if value == nil || value.IsZero() {
			return nil, nil
		}
		return value.Format("15:04:05"), nil
	case time.Time:
		if value.IsZero() {
			return nil, nil
		}
		return value.Format("15:04:05"), nil
	default:
		rv := reflect.ValueOf(fieldValue)
		if rv.Kind() == reflect.Ptr {
			if rv.IsNil() {
				return nil, nil
			}
			if clock, ok := rv.Elem().Interface().(time.Time); ok {
				return clock.Format("15:04:05"), nil
			}
		}
		return nil, fmt.Errorf("unsupported clock time value %T", fieldValue)
	}
}

func parseDBClockTime(value interface{}) (time.Time, error) {
	switch v := value.(type) {
	case time.Time:
		return normalizeClockTime(v), nil
	case string:
		return parseClockTimeString(v)
	case []byte:
		return parseClockTimeString(string(v))
	default:
		return time.Time{}, fmt.Errorf("unsupported clock time database value %T", value)
	}
}

func parseClockTimeString(value string) (time.Time, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return time.Time{}, nil
	}
	formats := []string{
		"15:04:05",
		"15:04",
		time.RFC3339Nano,
		"2006-01-02 15:04:05.999999999-07:00",
		"2006-01-02 15:04:05.999999999Z07:00",
		"2006-01-02 15:04:05-07:00",
		"2006-01-02 15:04:05Z07:00",
		"2006-01-02 15:04:05",
	}
	var lastErr error
	for _, layout := range formats {
		parsed, err := time.Parse(layout, value)
		if err == nil {
			return normalizeClockTime(parsed), nil
		}
		lastErr = err
	}
	return time.Time{}, fmt.Errorf("parse clock time %q: %w", value, lastErr)
}

func normalizeClockTime(value time.Time) time.Time {
	return time.Date(2000, 1, 1, value.Hour(), value.Minute(), value.Second(), value.Nanosecond(), time.UTC)
}

type TimetableSlot struct {
	BaseModel
	SectionID      string         `gorm:"type:text;not null" json:"section_id"`
	AcademicYearID string         `gorm:"type:text;not null" json:"academic_year_id"`
	TermID         string         `gorm:"type:text;not null" json:"term_id"`
	DayOfWeek      int            `gorm:"not null" json:"day_of_week"`
	PeriodNumber   int            `gorm:"not null" json:"period_number"`
	StartTime      *time.Time     `gorm:"column:start_time;type:time without time zone;serializer:clocktime" json:"start_time"`
	EndTime        *time.Time     `gorm:"column:end_time;type:time without time zone;serializer:clocktime" json:"end_time"`
	SubjectID      string         `gorm:"type:text;not null" json:"subject_id"`
	StaffID        string         `gorm:"type:text" json:"staff_id"`
	RoomID         *string        `gorm:"type:text" json:"room_id"`
	SlotType       string         `gorm:"type:text;default:'regular'" json:"slot_type"`
	Section        *Section       `gorm:"foreignKey:SectionID" json:"section,omitempty"`
	AcademicYear   *AcademicYear  `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
	Term           *Term          `gorm:"foreignKey:TermID" json:"term,omitempty"`
	Subject        *Subject       `gorm:"foreignKey:SubjectID" json:"subject,omitempty"`
	Staff          *Staff         `gorm:"foreignKey:StaffID" json:"staff,omitempty"`
	Room           *Room          `gorm:"foreignKey:RoomID" json:"room,omitempty"`
	Substitutions  []Substitution `gorm:"foreignKey:TimetableSlotID" json:"substitutions,omitempty"`
}

func (slot TimetableSlot) MarshalJSON() ([]byte, error) {
	type timetableSlotJSON struct {
		BaseModel
		SectionID      string         `json:"section_id"`
		AcademicYearID string         `json:"academic_year_id"`
		TermID         string         `json:"term_id"`
		DayOfWeek      int            `json:"day_of_week"`
		PeriodNumber   int            `json:"period_number"`
		StartTime      *string        `json:"start_time"`
		EndTime        *string        `json:"end_time"`
		SubjectID      string         `json:"subject_id"`
		StaffID        string         `json:"staff_id"`
		RoomID         *string        `json:"room_id"`
		SlotType       string         `json:"slot_type"`
		Section        *Section       `json:"section,omitempty"`
		AcademicYear   *AcademicYear  `json:"academic_year,omitempty"`
		Term           *Term          `json:"term,omitempty"`
		Subject        *Subject       `json:"subject,omitempty"`
		Staff          *Staff         `json:"staff,omitempty"`
		Room           *Room          `json:"room,omitempty"`
		Substitutions  []Substitution `json:"substitutions,omitempty"`
	}

	return json.Marshal(timetableSlotJSON{
		BaseModel:      slot.BaseModel,
		SectionID:      slot.SectionID,
		AcademicYearID: slot.AcademicYearID,
		TermID:         slot.TermID,
		DayOfWeek:      slot.DayOfWeek,
		PeriodNumber:   slot.PeriodNumber,
		StartTime:      clockTimeString(slot.StartTime),
		EndTime:        clockTimeString(slot.EndTime),
		SubjectID:      slot.SubjectID,
		StaffID:        slot.StaffID,
		RoomID:         slot.RoomID,
		SlotType:       slot.SlotType,
		Section:        slot.Section,
		AcademicYear:   slot.AcademicYear,
		Term:           slot.Term,
		Subject:        slot.Subject,
		Staff:          slot.Staff,
		Room:           slot.Room,
		Substitutions:  slot.Substitutions,
	})
}

func clockTimeString(value *time.Time) *string {
	if value == nil || value.IsZero() {
		return nil
	}
	formatted := value.Format("15:04")
	return &formatted
}

type Substitution struct {
	BaseModel
	TimetableSlotID   string         `gorm:"type:text;not null" json:"timetable_slot_id"`
	Date              time.Time      `json:"date"`
	OriginalStaffID   string         `gorm:"type:text;not null" json:"original_staff_id"`
	SubstituteStaffID string         `gorm:"type:text;not null" json:"substitute_staff_id"`
	Reason            string         `gorm:"type:text" json:"reason"`
	ApprovedBy        *string        `gorm:"type:text" json:"approved_by"`
	CreatedAt         time.Time      `json:"created_at"`
	TimetableSlot     *TimetableSlot `gorm:"foreignKey:TimetableSlotID" json:"timetable_slot,omitempty"`
	OriginalStaff     *Staff         `gorm:"foreignKey:OriginalStaffID" json:"original_staff,omitempty"`
	SubstituteStaff   *Staff         `gorm:"foreignKey:SubstituteStaffID" json:"substitute_staff,omitempty"`
}

type AttendanceSession struct {
	BaseModel
	SectionID          string              `gorm:"type:text;not null" json:"section_id"`
	TimetableSlotID    *string             `gorm:"type:text" json:"timetable_slot_id"`
	SubjectID          string              `gorm:"type:text;not null" json:"subject_id"`
	StaffID            string              `gorm:"type:text;not null" json:"staff_id"`
	Date               time.Time           `json:"date"`
	PeriodNumber       int                 `json:"period_number"`
	TotalStudents      int                 `json:"total_students"`
	PresentCount       int                 `json:"present_count"`
	IsFinalized        bool                `gorm:"default:false" json:"is_finalized"`
	CreatedAt          time.Time           `json:"created_at"`
	Section            *Section            `gorm:"foreignKey:SectionID" json:"section,omitempty"`
	Subject            *Subject            `gorm:"foreignKey:SubjectID" json:"subject,omitempty"`
	Staff              *Staff              `gorm:"foreignKey:StaffID" json:"staff,omitempty"`
	StudentAttendances []StudentAttendance `gorm:"foreignKey:SessionID" json:"student_attendances,omitempty"`
}

type StudentAttendance struct {
	BaseModel
	SessionID    string             `gorm:"type:text;not null" json:"session_id"`
	StudentID    string             `gorm:"type:text;not null" json:"student_id"`
	EnrollmentID string             `gorm:"type:text;not null" json:"enrollment_id"`
	Status       string             `gorm:"type:text;not null" json:"status"`
	Reason       string             `gorm:"type:text" json:"reason"`
	MarkedAt     time.Time          `json:"marked_at"`
	MarkedBy     *string            `gorm:"type:text" json:"marked_by"`
	Session      *AttendanceSession `gorm:"foreignKey:SessionID" json:"session,omitempty"`
	Student      *Student           `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	Enrollment   *Enrollment        `gorm:"foreignKey:EnrollmentID" json:"enrollment,omitempty"`
}

type StaffAttendance struct {
	BaseModel
	StaffID     string     `gorm:"type:text;not null" json:"staff_id"`
	Date        time.Time  `json:"date"`
	CheckIn     *time.Time `json:"check_in"`
	CheckOut    *time.Time `json:"check_out"`
	Status      string     `gorm:"type:text;not null" json:"status"`
	BiometricID string     `gorm:"type:text" json:"biometric_id"`
	ApprovedBy  *string    `gorm:"type:text" json:"approved_by"`
	Source      string     `gorm:"type:text;default:'manual'" json:"source"`
	MarkedBy    *string    `gorm:"type:text" json:"marked_by"`
	Staff       *Staff     `gorm:"foreignKey:StaffID" json:"staff,omitempty"`
}

type AttendanceSummary struct {
	BaseModel
	StudentID      string        `gorm:"type:text;not null" json:"student_id"`
	SectionID      string        `gorm:"type:text;not null" json:"section_id"`
	AcademicYearID string        `gorm:"type:text;not null" json:"academic_year_id"`
	TermID         *string       `gorm:"type:text" json:"term_id"`
	TotalDays      int           `json:"total_days"`
	PresentDays    int           `json:"present_days"`
	AbsentDays     int           `json:"absent_days"`
	LateCount      int           `json:"late_count"`
	AttendancePct  float64       `json:"attendance_pct"`
	UpdatedAt      time.Time     `json:"updated_at"`
	Student        *Student      `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	Section        *Section      `gorm:"foreignKey:SectionID" json:"section,omitempty"`
	AcademicYear   *AcademicYear `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
	Term           *Term         `gorm:"foreignKey:TermID" json:"term,omitempty"`
}

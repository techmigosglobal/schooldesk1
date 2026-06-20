package models

import "time"

type ErrorEvent struct {
	BaseModel
	SchoolID       string     `gorm:"type:text;index" json:"school_id"`
	UserID         string     `gorm:"type:text;index" json:"user_id"`
	Role           string     `gorm:"type:text;index" json:"role"`
	Source         string     `gorm:"type:text;not null;index" json:"source"`
	Severity       string     `gorm:"type:text;not null;index" json:"severity"`
	Status         string     `gorm:"type:text;not null;default:'open';index" json:"status"`
	RequestID      string     `gorm:"type:text;index" json:"request_id"`
	ErrorID        string     `gorm:"type:text;uniqueIndex" json:"error_id"`
	Method         string     `gorm:"type:text" json:"method"`
	Path           string     `gorm:"type:text" json:"path"`
	RouteName      string     `gorm:"type:text" json:"route_name"`
	Screen         string     `gorm:"type:text" json:"screen"`
	Message        string     `gorm:"type:text" json:"message"`
	ErrorType      string     `gorm:"type:text" json:"error_type"`
	StackTrace     string     `gorm:"type:text" json:"stack_trace"`
	StatusCode     int        `gorm:"index" json:"status_code"`
	MetadataJSON   string     `gorm:"type:text" json:"metadata_json"`
	AppVersion     string     `gorm:"type:text" json:"app_version"`
	DeviceInfo     string     `gorm:"type:text" json:"device_info"`
	OccurredAt     time.Time  `gorm:"index" json:"occurred_at"`
	ResolvedAt     *time.Time `json:"resolved_at,omitempty"`
	ResolvedBy     *string    `gorm:"type:text" json:"resolved_by,omitempty"`
	ResolutionNote string     `gorm:"type:text" json:"resolution_note,omitempty"`
}

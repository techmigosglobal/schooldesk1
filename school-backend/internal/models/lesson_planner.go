package models

import (
	"time"
)

type LessonPlannerStatus string

const (
	LessonPlannerStatusUploaded  LessonPlannerStatus = "uploaded"
	LessonPlannerStatusCompleted LessonPlannerStatus = "completed"
)

type LessonPlanner struct {
	BaseModel
	SchoolID       string              `gorm:"type:text;not null" json:"school_id"`
	TeacherID      string              `gorm:"type:text;not null" json:"teacher_id"`
	GradeID        string              `gorm:"type:text;not null" json:"grade_id"`
	SectionID      string              `gorm:"type:text;not null" json:"section_id"`
	WeekStartDate  time.Time           `json:"week_start_date"`
	WeekEndDate    time.Time           `json:"week_end_date"`
	AttachmentURL  string              `gorm:"type:text" json:"attachment_url"`
	Note           *string             `gorm:"type:text" json:"note,omitempty"`
	Status         LessonPlannerStatus `gorm:"type:text;not null;default:'uploaded'" json:"status"`
	CompletedAt    *time.Time          `json:"completed_at,omitempty"`

	School    *School  `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	Teacher   *Staff   `gorm:"foreignKey:TeacherID" json:"teacher,omitempty"`
	Grade     *Grade   `gorm:"foreignKey:GradeID" json:"grade,omitempty"`
	Section   *Section `gorm:"foreignKey:SectionID" json:"section,omitempty"`
}

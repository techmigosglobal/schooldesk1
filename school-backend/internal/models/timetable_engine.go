package models

import "time"

type TimetableTemplate struct {
	BaseModel
	SchoolID              string        `gorm:"type:text;not null;index" json:"school_id"`
	AcademicYearID        string        `gorm:"type:text;index" json:"academic_year_id"`
	Name                  string        `gorm:"type:text;not null" json:"name"`
	WorkingDays           string        `gorm:"type:text" json:"working_days"`
	PeriodsPerDay         int           `json:"periods_per_day"`
	PeriodDurationMinutes int           `json:"period_duration_minutes"`
	GapMinutes            int           `json:"gap_minutes"`
	StartTime             string        `gorm:"type:text" json:"start_time"`
	EndTime               string        `gorm:"type:text" json:"end_time"`
	Breaks                string        `gorm:"type:text" json:"breaks"`
	IsDefault             bool          `gorm:"default:false" json:"is_default"`
	School                *School       `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	AcademicYear          *AcademicYear `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
}

type TimetableConstraint struct {
	BaseModel
	SchoolID       string        `gorm:"type:text;not null;index" json:"school_id"`
	AcademicYearID string        `gorm:"type:text;index" json:"academic_year_id"`
	SectionID      *string       `gorm:"type:text;index" json:"section_id"`
	StaffID        *string       `gorm:"type:text;index" json:"staff_id"`
	SubjectID      *string       `gorm:"type:text;index" json:"subject_id"`
	RoomID         *string       `gorm:"type:text;index" json:"room_id"`
	ConstraintType string        `gorm:"type:text;not null;index" json:"constraint_type"`
	Priority       string        `gorm:"type:text;default:'normal'" json:"priority"`
	Weight         int           `json:"weight"`
	Payload        string        `gorm:"type:text" json:"payload"`
	IsActive       bool          `gorm:"default:true" json:"is_active"`
	School         *School       `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	AcademicYear   *AcademicYear `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
	Section        *Section      `gorm:"foreignKey:SectionID" json:"section,omitempty"`
	Staff          *Staff        `gorm:"foreignKey:StaffID" json:"staff,omitempty"`
	Subject        *Subject      `gorm:"foreignKey:SubjectID" json:"subject,omitempty"`
	Room           *Room         `gorm:"foreignKey:RoomID" json:"room,omitempty"`
}

type TimetableGenerationJob struct {
	BaseModel
	SchoolID       string                   `gorm:"type:text;not null;index" json:"school_id"`
	AcademicYearID string                   `gorm:"type:text;index" json:"academic_year_id"`
	TermID         string                   `gorm:"type:text;index" json:"term_id"`
	Scope          string                   `gorm:"type:text" json:"scope"`
	Status         string                   `gorm:"type:text;not null;index;default:'pending'" json:"status"`
	ProgressStage  string                   `gorm:"type:text" json:"progress_stage"`
	RequestedBy    string                   `gorm:"type:text" json:"requested_by"`
	RequestedRole  string                   `gorm:"type:text" json:"requested_role"`
	Summary        string                   `gorm:"type:text" json:"summary"`
	ErrorMessage   string                   `gorm:"type:text" json:"error_message"`
	StartedAt      *time.Time               `json:"started_at,omitempty"`
	CompletedAt    *time.Time               `json:"completed_at,omitempty"`
	School         *School                  `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	AcademicYear   *AcademicYear            `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
	Term           *Term                    `gorm:"foreignKey:TermID" json:"term,omitempty"`
	Logs           []TimetableGenerationLog `gorm:"foreignKey:JobID" json:"logs,omitempty"`
}

type TimetableGenerationLog struct {
	BaseModel
	JobID      string                  `gorm:"type:text;not null;index" json:"job_id"`
	Stage      string                  `gorm:"type:text;index" json:"stage"`
	Severity   string                  `gorm:"type:text;default:'info'" json:"severity"`
	Message    string                  `gorm:"type:text;not null" json:"message"`
	EntityType string                  `gorm:"type:text" json:"entity_type"`
	EntityID   string                  `gorm:"type:text" json:"entity_id"`
	Payload    string                  `gorm:"type:text" json:"payload"`
	Job        *TimetableGenerationJob `gorm:"foreignKey:JobID" json:"job,omitempty"`
}

type TimetableOverride struct {
	BaseModel
	SchoolID        string         `gorm:"type:text;not null;index" json:"school_id"`
	SlotID          string         `gorm:"type:text;not null;index" json:"slot_id"`
	OverrideType    string         `gorm:"type:text;not null" json:"override_type"`
	OriginalPayload string         `gorm:"type:text" json:"original_payload"`
	NewPayload      string         `gorm:"type:text" json:"new_payload"`
	Reason          string         `gorm:"type:text" json:"reason"`
	CreatedBy       string         `gorm:"type:text" json:"created_by"`
	CreatedRole     string         `gorm:"type:text" json:"created_role"`
	School          *School        `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	Slot            *TimetableSlot `gorm:"foreignKey:SlotID" json:"slot,omitempty"`
}

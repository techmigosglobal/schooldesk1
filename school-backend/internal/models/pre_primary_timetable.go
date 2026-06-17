package models


// PrePrimaryTimetableTemplate represents the base template (e.g., "Playgroup Template").
type PrePrimaryTimetableTemplate struct {
	BaseModel
	SchoolID       string `gorm:"type:text;not null;index" json:"school_id"`
	AcademicYearID string `gorm:"type:text;not null;index" json:"academic_year_id"`
	Name           string `gorm:"type:text;not null" json:"name"`

	School       *School       `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	AcademicYear *AcademicYear `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`

	Days []PrePrimaryTimetableDay `gorm:"foreignKey:TemplateID" json:"days,omitempty"`
}

// PrePrimaryTimetableDay represents a day in the template.
type PrePrimaryTimetableDay struct {
	BaseModel
	TemplateID string `gorm:"type:text;not null;index" json:"template_id"`
	DayOfWeek  int    `gorm:"type:int;not null" json:"day_of_week"` // 1=Monday...6=Saturday

	Template *PrePrimaryTimetableTemplate `gorm:"foreignKey:TemplateID" json:"template,omitempty"`

	Slots []PrePrimaryTimetableSlot `gorm:"foreignKey:DayID" json:"slots,omitempty"`
}

// PrePrimaryTimetableSlot represents an activity period within a template day.
type PrePrimaryTimetableSlot struct {
	BaseModel
	DayID        string    `gorm:"type:text;not null;index" json:"day_id"`
	StartTime    string `gorm:"type:text;not null" json:"start_time"`
	EndTime      string `gorm:"type:text;not null" json:"end_time"`
	ActivityName string    `gorm:"type:text;not null" json:"activity_name"`
	IsBreak      bool      `gorm:"type:boolean;default:false" json:"is_break"`

	Day *PrePrimaryTimetableDay `gorm:"foreignKey:DayID" json:"day,omitempty"`
}

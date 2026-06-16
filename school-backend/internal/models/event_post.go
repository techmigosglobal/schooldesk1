package models

import (
	"time"
)

type ApprovalStatus string

const (
	ApprovalStatusDraft    ApprovalStatus = "draft"
	ApprovalStatusPending  ApprovalStatus = "pending"
	ApprovalStatusApproved ApprovalStatus = "approved"
	ApprovalStatusRejected ApprovalStatus = "rejected"
)

type EventPostDestination string

const (
	DestinationParentsHome  EventPostDestination = "PARENTS_HOME"
	DestinationSchoolGallery EventPostDestination = "SCHOOL_GALLERY"
	DestinationSchoolLanding EventPostDestination = "SCHOOL_LANDING"
)

type EventPost struct {
	BaseModel
	SchoolID              string         `gorm:"type:text;not null" json:"school_id"`
	Title                 string         `gorm:"type:text;not null" json:"title"`
	Description           string         `gorm:"type:text" json:"description"`
	EventDate             time.Time      `json:"event_date"`
	CreatedByTeacherID    string         `gorm:"type:text;not null" json:"created_by_teacher_id"`
	GradeID               *string        `gorm:"type:text" json:"grade_id,omitempty"`
	SectionID             *string        `gorm:"type:text" json:"section_id,omitempty"`
	MediaUrls             string         `gorm:"type:text" json:"media_urls"`   // comma separated or JSON string
	Destinations          string         `gorm:"type:text;not null" json:"destinations"` // comma separated PARENTS_HOME, SCHOOL_GALLERY, SCHOOL_LANDING
	ApprovalStatus        ApprovalStatus `gorm:"type:text;not null;default:'draft'" json:"approval_status"`
	RejectionReason       *string        `gorm:"type:text" json:"rejection_reason,omitempty"`
	ApprovedByPrincipalID *string        `gorm:"type:text" json:"approved_by_principal_id,omitempty"`
	ApprovedAt            *time.Time     `json:"approved_at,omitempty"`
	PublishedAt           *time.Time     `json:"published_at,omitempty"`

	School              *School  `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	CreatedByTeacher    *Staff   `gorm:"foreignKey:CreatedByTeacherID" json:"created_by_teacher,omitempty"`
	ApprovedByPrincipal *Staff   `gorm:"foreignKey:ApprovedByPrincipalID" json:"approved_by_principal,omitempty"`
	Grade               *Grade   `gorm:"foreignKey:GradeID" json:"grade,omitempty"`
	Section             *Section `gorm:"foreignKey:SectionID" json:"section,omitempty"`
}

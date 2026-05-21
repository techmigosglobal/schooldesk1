package models

import "time"

type ReportExport struct {
	BaseModel
	SchoolID      string     `gorm:"type:text;not null;index" json:"school_id"`
	Category      string     `gorm:"type:text;not null;index" json:"category"`
	ReportTitle   string     `gorm:"type:text;not null" json:"report_title"`
	ReportType    string     `gorm:"type:text" json:"report_type"`
	Format        string     `gorm:"type:text;not null" json:"format"`
	Scope         string     `gorm:"type:text" json:"scope"`
	Parameters    string     `gorm:"type:text" json:"parameters"`
	Status        string     `gorm:"type:text;not null;default:'pending'" json:"status"`
	ArtifactPath  string     `gorm:"type:text" json:"artifact_path"`
	DownloadURL   string     `gorm:"type:text" json:"download_url"`
	ErrorMessage  string     `gorm:"type:text" json:"error_message"`
	RequestedBy   string     `gorm:"type:text;not null" json:"requested_by"`
	RequestedRole string     `gorm:"type:text" json:"requested_role"`
	RequestedAt   time.Time  `json:"requested_at"`
	CompletedAt   *time.Time `json:"completed_at,omitempty"`
}

type ReportExportRequest struct {
	ReportTitle string                 `json:"report_title"`
	Report      string                 `json:"report"`
	Title       string                 `json:"title"`
	ReportType  string                 `json:"report_type"`
	Format      string                 `json:"format" binding:"required"`
	Scope       string                 `json:"scope"`
	Parameters  map[string]interface{} `json:"parameters"`
}

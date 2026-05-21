package models

// FrontendRecord stores workflow records for UI modules whose permanent domain
// tables are not yet specialized. The resource key is the API path segment,
// for example "documents/requests" or "fees/reports/exports".
type FrontendRecord struct {
	BaseModel
	SchoolID  string `gorm:"type:text;not null;index" json:"school_id"`
	Resource  string `gorm:"type:text;not null;index" json:"resource"`
	Payload   string `gorm:"type:text;not null" json:"payload"`
	CreatedBy string `gorm:"type:text" json:"created_by"`
}

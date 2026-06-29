package models

type UploadedFile struct {
	BaseModel
	SchoolID     string `gorm:"type:text;not null;index" json:"school_id"`
	Path         string `gorm:"type:text;not null;uniqueIndex" json:"path"`
	OriginalName string `gorm:"type:text" json:"original_name"`
	ContentType  string `gorm:"type:text" json:"content_type"`
	Size         int64  `json:"size"`
	Data         []byte `gorm:"not null" json:"-"`
}

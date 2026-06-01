package models

import "time"

// BulkImportType defines the type of bulk import operation
type BulkImportType string

const (
	BulkImportTypeStudent BulkImportType = "student"
	BulkImportTypeStaff   BulkImportType = "staff"
	BulkImportTypeParent  BulkImportType = "parent"
)

// BulkImportStatus defines the status of a bulk import job
type BulkImportStatus string

const (
	BulkImportStatusPending   BulkImportStatus = "pending"
	BulkImportStatusProcessing BulkImportStatus = "processing"
	BulkImportStatusCompleted BulkImportStatus = "completed"
	BulkImportStatusFailed    BulkImportStatus = "failed"
)

// BulkImportJob tracks bulk import operations
type BulkImportJob struct {
	BaseModel
	SchoolID      string           `gorm:"type:uuid;not null" json:"school_id"`
	ImportType    string           `gorm:"type:text;not null" json:"import_type"`
	Status        string           `gorm:"type:text;default:'pending'" json:"status"`
	TotalRecords  int              `json:"total_records"`
	SuccessCount  int              `json:"success_count"`
	FailureCount  int              `json:"failure_count"`
	InitiatedBy   string           `gorm:"type:uuid" json:"initiated_by"`
	CompletedAt   *time.Time       `json:"completed_at"`
	FailureReason string           `gorm:"type:text" json:"failure_reason"`
	ReportURL     string           `gorm:"type:text" json:"report_url"`
	School        *School          `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	Errors        []BulkImportError `gorm:"foreignKey:ImportJobID" json:"errors,omitempty"`
}

// BulkImportError tracks individual row errors during import
type BulkImportError struct {
	BaseModel
	ImportJobID string `gorm:"type:uuid;not null" json:"import_job_id"`
	RowNumber   int    `json:"row_number"`
	ErrorMsg    string `gorm:"type:text" json:"error_msg"`
	RawData     string `gorm:"type:text" json:"raw_data"`
	ImportJob   *BulkImportJob `gorm:"foreignKey:ImportJobID" json:"import_job,omitempty"`
}

// BulkImportRequest represents the request for bulk import
type BulkImportRequest struct {
	ImportType string `form:"import_type" binding:"required,oneof=student staff parent"`
	DryRun     bool   `form:"dry_run"`
}

// StudentBulkImportRecord represents a single student record from CSV
type StudentBulkImportRecord struct {
	FirstName        string `csv:"first_name"`
	LastName         string `csv:"last_name"`
	Email            string `csv:"email"`
	Phone            string `csv:"phone"`
	DateOfBirth      string `csv:"date_of_birth"`
	Gender           string `csv:"gender"`
	AdmissionNumber  string `csv:"admission_number"`
	AdmissionDate    string `csv:"admission_date"`
	CurrentSectionID string `csv:"current_section_id"`
	Address          string `csv:"address"`
	AadharNumber     string `csv:"aadhar_number"`
}

// StaffBulkImportRecord represents a single staff record from CSV
type StaffBulkImportRecord struct {
	FirstName      string `csv:"first_name"`
	LastName       string `csv:"last_name"`
	Email          string `csv:"email"`
	Phone          string `csv:"phone"`
	DateOfBirth    string `csv:"date_of_birth"`
	Gender         string `csv:"gender"`
	StaffCode      string `csv:"staff_code"`
	DepartmentID   string `csv:"department_id"`
	Designation    string `csv:"designation"`
	EmploymentType string `csv:"employment_type"`
	JoinDate       string `csv:"join_date"`
	BasicSalary    string `csv:"basic_salary"`
}

// ParentBulkImportRecord represents a single parent record from CSV
type ParentBulkImportRecord struct {
	FullName               string `csv:"full_name"`
	Email                  string `csv:"email"`
	Phone                  string `csv:"phone"`
	Relationship           string `csv:"relationship"`
	Occupation             string `csv:"occupation"`
	StudentAdmissionNumber string `csv:"student_admission_number"`
}

// BulkImportResponse represents the response after import
type BulkImportResponse struct {
	Success      bool                     `json:"success"`
	JobID        string                   `json:"job_id"`
	ImportType   string                   `json:"import_type"`
	TotalRecords int                      `json:"total_records"`
	SuccessCount int                      `json:"success_count"`
	FailureCount int                      `json:"failure_count"`
	IsDryRun     bool                     `json:"is_dry_run"`
	Errors       []BulkImportErrorDetail  `json:"errors,omitempty"`
	Message      string                   `json:"message"`
}

// BulkImportErrorDetail represents a detailed error for a row
type BulkImportErrorDetail struct {
	RowNumber int    `json:"row_number"`
	ErrorMsg  string `json:"error_msg"`
	RawData   string `json:"raw_data,omitempty"`
}

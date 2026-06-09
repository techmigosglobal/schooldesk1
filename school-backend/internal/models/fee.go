package models

import (
	"time"
)

type FeeCategory struct {
	BaseModel
	SchoolID     string           `gorm:"type:uuid;not null" json:"school_id"`
	CategoryName string           `gorm:"size:255;not null" json:"category_name"`
	Frequency    string           `gorm:"type:text;not null" json:"frequency"`
	IsRefundable bool             `gorm:"default:false" json:"is_refundable"`
	School       *School          `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	Structures   []FeeStructure   `gorm:"foreignKey:FeeCategoryID" json:"structures,omitempty"`
	Concessions  []FeeConcession  `gorm:"foreignKey:FeeCategoryID" json:"concessions,omitempty"`
	InvoiceItems []FeeInvoiceItem `gorm:"foreignKey:FeeCategoryID" json:"invoice_items,omitempty"`
}

type FeeStructure struct {
	BaseModel
	SchoolID       string        `gorm:"type:uuid;not null" json:"school_id"`
	AcademicYearID string        `gorm:"type:uuid;not null" json:"academic_year_id"`
	GradeID        string        `gorm:"type:uuid;not null" json:"grade_id"`
	FeeCategoryID  string        `gorm:"type:uuid;not null" json:"fee_category_id"`
	Amount         float64       `json:"amount"`
	DueDay         int           `json:"due_day"`
	LateFinePerDay float64       `json:"late_fine_per_day"`
	School         *School       `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	AcademicYear   *AcademicYear `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
	Grade          *Grade        `gorm:"foreignKey:GradeID" json:"grade,omitempty"`
	FeeCategory    *FeeCategory  `gorm:"foreignKey:FeeCategoryID" json:"fee_category,omitempty"`
}

type FeeConcession struct {
	BaseModel
	StudentID      string        `gorm:"type:uuid;not null" json:"student_id"`
	FeeCategoryID  string        `gorm:"type:uuid;not null" json:"fee_category_id"`
	AcademicYearID string        `gorm:"type:uuid;not null" json:"academic_year_id"`
	ConcessionType string        `gorm:"type:text;not null" json:"concession_type"`
	Value          float64       `json:"value"`
	Reason         string        `gorm:"type:text" json:"reason"`
	ApprovedBy     *string       `gorm:"type:uuid" json:"approved_by"`
	Student        *Student      `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	FeeCategory    *FeeCategory  `gorm:"foreignKey:FeeCategoryID" json:"fee_category,omitempty"`
	AcademicYear   *AcademicYear `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
}

type FeeInvoice struct {
	BaseModel
	StudentID       string                 `gorm:"type:uuid;not null" json:"student_id"`
	AcademicYearID  string                 `gorm:"type:uuid;not null" json:"academic_year_id"`
	TermID          *string                `gorm:"type:text;index" json:"term_id,omitempty"`
	InvoiceNumber   string                 `gorm:"size:100;unique" json:"invoice_number"`
	InvoiceDate     time.Time              `json:"invoice_date"`
	DueDate         time.Time              `json:"due_date"`
	TotalAmount     float64                `json:"total_amount"`
	DiscountAmount  float64                `json:"discount_amount"`
	NetAmount       float64                `json:"net_amount"`
	PaidAmount      float64                `json:"paid_amount"`
	Balance         float64                `json:"balance"`
	Status          string                 `gorm:"type:text;default:'pending'" json:"status"`
	Student         *Student               `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	AcademicYear    *AcademicYear          `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
	Term            *Term                  `gorm:"foreignKey:TermID" json:"term,omitempty"`
	Items           []FeeInvoiceItem       `gorm:"foreignKey:InvoiceID" json:"items,omitempty"`
	Payments        []Payment              `gorm:"foreignKey:InvoiceID" json:"payments,omitempty"`
	PaymentRequests []ParentPaymentRequest `gorm:"foreignKey:InvoiceID" json:"payment_requests,omitempty"`
}

type FeeInvoiceItem struct {
	BaseModel
	InvoiceID     string       `gorm:"type:uuid;not null" json:"invoice_id"`
	FeeCategoryID string       `gorm:"type:uuid;not null" json:"fee_category_id"`
	Amount        float64      `json:"amount"`
	Description   string       `gorm:"size:255" json:"description"`
	Invoice       *FeeInvoice  `gorm:"foreignKey:InvoiceID" json:"invoice,omitempty"`
	FeeCategory   *FeeCategory `gorm:"foreignKey:FeeCategoryID" json:"fee_category,omitempty"`
}

type Payment struct {
	BaseModel
	InvoiceID     string      `gorm:"type:uuid;not null" json:"invoice_id"`
	ReceiptNumber string      `gorm:"size:100;unique" json:"receipt_number"`
	AmountPaid    float64     `json:"amount_paid"`
	PaymentDate   time.Time   `json:"payment_date"`
	PaymentMode   string      `gorm:"type:text;not null" json:"payment_mode"`
	TransactionID string      `gorm:"size:255" json:"transaction_id"`
	ReceivedBy    *string     `gorm:"type:uuid" json:"received_by"`
	CreatedAt     time.Time   `json:"created_at"`
	Invoice       *FeeInvoice `gorm:"foreignKey:InvoiceID" json:"invoice,omitempty"`
}

type ParentPaymentRequest struct {
	BaseModel
	SchoolID         string      `gorm:"type:text;not null;index" json:"school_id"`
	InvoiceID        string      `gorm:"type:text;not null;index" json:"invoice_id"`
	StudentID        string      `gorm:"type:text;not null;index" json:"student_id"`
	ParentUserID     string      `gorm:"type:text;not null;index" json:"parent_user_id"`
	PaymentID        *string     `gorm:"type:text" json:"payment_id,omitempty"`
	RequestReference string      `gorm:"size:100;uniqueIndex" json:"request_reference"`
	Amount           float64     `json:"amount"`
	PaymentDate      time.Time   `json:"payment_date"`
	PaymentMode      string      `gorm:"type:text;not null" json:"payment_mode"`
	TransactionID    string      `gorm:"size:255" json:"transaction_id"`
	Status           string      `gorm:"type:text;default:'pending';index" json:"status"`
	Remarks          string      `gorm:"type:text" json:"remarks"`
	AdminRemarks     string      `gorm:"type:text" json:"admin_remarks"`
	DecidedBy        *string     `gorm:"type:text" json:"decided_by,omitempty"`
	DecidedAt        *time.Time  `json:"decided_at,omitempty"`
	Invoice          *FeeInvoice `gorm:"foreignKey:InvoiceID" json:"invoice,omitempty"`
	Student          *Student    `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	ParentUser       *User       `gorm:"foreignKey:ParentUserID" json:"parent_user,omitempty"`
	Payment          *Payment    `gorm:"foreignKey:PaymentID" json:"payment,omitempty"`
}

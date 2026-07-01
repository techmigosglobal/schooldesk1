package models

import (
	"time"

	"gorm.io/gorm"
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
	SchoolID          string           `gorm:"type:uuid;not null" json:"school_id"`
	AcademicYearID    string           `gorm:"type:uuid;not null" json:"academic_year_id"`
	GradeID           string           `gorm:"type:uuid;not null" json:"grade_id"`
	SectionID         *string          `gorm:"type:uuid;index" json:"section_id,omitempty"`
	FeeCategoryID     string           `gorm:"type:uuid;not null" json:"fee_category_id"`
	Amount            float64          `json:"amount"`
	FeeType           string           `gorm:"type:text;default:'tuition';index" json:"fee_type"`
	BillingMode       string           `gorm:"type:text;default:'term_wise';index" json:"billing_mode"`
	Priority          int              `gorm:"default:2;index" json:"priority"`
	IsActive          bool             `gorm:"default:true;index" json:"is_active"`
	DueDay            int              `json:"due_day"`
	LateFinePerDay    float64          `json:"late_fine_per_day"`
	InstallmentCount  int              `gorm:"default:3" json:"installment_count"`
	InstallmentMethod string           `gorm:"type:text;default:'equal'" json:"installment_method"`
	EffectiveFrom     *time.Time       `json:"effective_from,omitempty"`
	School            *School          `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	AcademicYear      *AcademicYear    `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
	Grade             *Grade           `gorm:"foreignKey:GradeID" json:"grade,omitempty"`
	Section           *Section         `gorm:"foreignKey:SectionID" json:"section,omitempty"`
	FeeCategory       *FeeCategory     `gorm:"foreignKey:FeeCategoryID" json:"fee_category,omitempty"`
	Installments      []FeeInstallment `gorm:"foreignKey:FeeStructureID" json:"installments,omitempty"`
}

type FeeInstallment struct {
	BaseModel
	SchoolID          string        `gorm:"type:uuid;not null;index" json:"school_id"`
	AcademicYearID    string        `gorm:"type:uuid;not null;index" json:"academic_year_id"`
	GradeID           string        `gorm:"type:uuid;not null;index" json:"grade_id"`
	SectionID         *string       `gorm:"type:uuid;index" json:"section_id,omitempty"`
	FeeStructureID    *string       `gorm:"type:uuid;index" json:"fee_structure_id,omitempty"`
	Method            string        `gorm:"type:text;not null;default:'equal';index" json:"method"`
	InstallmentName   string        `gorm:"type:text;not null" json:"installment_name"`
	InstallmentNumber int           `gorm:"not null;index" json:"installment_number"`
	Amount            float64       `json:"amount"`
	Percentage        float64       `json:"percentage"`
	DueDate           time.Time     `json:"due_date"`
	Status            string        `gorm:"type:text;default:'upcoming';index" json:"status"`
	School            *School       `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	AcademicYear      *AcademicYear `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
	Grade             *Grade        `gorm:"foreignKey:GradeID" json:"grade,omitempty"`
	Section           *Section      `gorm:"foreignKey:SectionID" json:"section,omitempty"`
	FeeStructure      *FeeStructure `gorm:"foreignKey:FeeStructureID" json:"fee_structure,omitempty"`
}

type SchoolPaymentSetting struct {
	BaseModel
	SchoolID     string  `gorm:"type:text;not null;uniqueIndex" json:"school_id"`
	UPIID        string  `gorm:"type:text" json:"upi_id"`
	PayeeName    string  `gorm:"type:text" json:"payee_name"`
	MerchantCode string  `gorm:"type:text" json:"merchant_code"`
	QRNote       string  `gorm:"type:text" json:"qr_note"`
	QRImageURL   string  `gorm:"type:text" json:"qr_image_url"`
	UPIEnabled   bool    `gorm:"default:false" json:"upi_enabled"`
	UpdatedBy    *string `gorm:"type:text" json:"updated_by,omitempty"`
	School       *School `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
}

type ScopedPaymentSetting struct {
	BaseModel
	SchoolID     string   `gorm:"type:text;not null;index" json:"school_id"`
	GradeID      *string  `gorm:"type:text;index" json:"grade_id,omitempty"`
	SectionID    *string  `gorm:"type:text;index" json:"section_id,omitempty"`
	Scope        string   `gorm:"type:text;not null;default:'school';index" json:"scope"`
	UPIID        string   `gorm:"type:text" json:"upi_id"`
	PayeeName    string   `gorm:"type:text" json:"payee_name"`
	MerchantCode string   `gorm:"type:text" json:"merchant_code"`
	QRNote       string   `gorm:"type:text" json:"qr_note"`
	QRImageURL   string   `gorm:"type:text" json:"qr_image_url"`
	UPIEnabled   bool     `gorm:"default:false" json:"upi_enabled"`
	UpdatedBy    *string  `gorm:"type:text" json:"updated_by,omitempty"`
	School       *School  `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	Grade        *Grade   `gorm:"foreignKey:GradeID" json:"grade,omitempty"`
	Section      *Section `gorm:"foreignKey:SectionID" json:"section,omitempty"`
}

type FeeConcession struct {
	BaseModel
	SchoolID       string        `gorm:"type:text;index" json:"school_id"`
	StudentID      string        `gorm:"type:uuid;not null" json:"student_id"`
	FeeCategoryID  string        `gorm:"type:uuid;not null" json:"fee_category_id"`
	AcademicYearID string        `gorm:"type:uuid;not null" json:"academic_year_id"`
	ConcessionType string        `gorm:"type:text;not null" json:"concession_type"`
	Value          float64       `json:"value"`
	Reason         string        `gorm:"type:text" json:"reason"`
	Status         string        `gorm:"type:text;default:'pending';index" json:"status"`
	RequestedBy    *string       `gorm:"type:text" json:"requested_by,omitempty"`
	ApprovedBy     *string       `gorm:"type:uuid" json:"approved_by"`
	DecidedBy      *string       `gorm:"type:text" json:"decided_by,omitempty"`
	DecidedAt      *time.Time    `json:"decided_at,omitempty"`
	AdminRemarks   string        `gorm:"type:text" json:"admin_remarks"`
	Student        *Student      `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	FeeCategory    *FeeCategory  `gorm:"foreignKey:FeeCategoryID" json:"fee_category,omitempty"`
	AcademicYear   *AcademicYear `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
}

type FeeInvoice struct {
	BaseModel
	StudentID         string                 `gorm:"type:uuid;not null" json:"student_id"`
	AcademicYearID    string                 `gorm:"type:uuid;not null" json:"academic_year_id"`
	TermID            *string                `gorm:"type:text;index" json:"term_id,omitempty"`
	InvoiceNumber     string                 `gorm:"size:100;unique" json:"invoice_number"`
	InvoiceDate       time.Time              `json:"invoice_date"`
	DueDate           time.Time              `json:"due_date"`
	TotalAmount       float64                `json:"total_amount"`
	DiscountAmount    float64                `json:"discount_amount"`
	ConcessionAmount  float64                `gorm:"default:0" json:"concession_amount"`
	FineAmount        float64                `gorm:"default:0" json:"fine_amount"`
	PayableAmount     float64                `json:"payable_amount"`      // TotalAmount - DiscountAmount - ConcessionAmount + FineAmount
	NetAmount         float64                `gorm:"-" json:"net_amount"` // Alias for PayableAmount (backward compatibility)
	InstallmentNumber int                    `gorm:"-" json:"installment_number,omitempty"`
	InstallmentCount  int                    `gorm:"-" json:"installment_count,omitempty"`
	TotalInstallments int                    `gorm:"-" json:"total_installments,omitempty"`
	LateFinePerDay    float64                `gorm:"-" json:"late_fine_per_day,omitempty"`
	PaidAmount        float64                `json:"paid_amount"`
	Balance           float64                `json:"balance"`
	Status            string                 `gorm:"type:text;default:'pending';index" json:"status"` // unpaid, partially_paid, paid, overdue, cancelled
	StudentParentID   *string                `gorm:"type:uuid" json:"student_parent_id,omitempty"`    // Denormalized parent ID for quick lookup
	Student           *Student               `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	AcademicYear      *AcademicYear          `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
	Term              *Term                  `gorm:"foreignKey:TermID" json:"term,omitempty"`
	Items             []FeeInvoiceItem       `gorm:"foreignKey:InvoiceID" json:"items,omitempty"`
	Payments          []Payment              `gorm:"foreignKey:InvoiceID" json:"payments,omitempty"`
	PaymentRequests   []ParentPaymentRequest `gorm:"foreignKey:InvoiceID" json:"payment_requests,omitempty"`
	Receipts          []FeeReceipt           `gorm:"many2many:fee_receipt_invoice_map;" json:"receipts,omitempty"`
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
	InvoiceID         string      `gorm:"type:uuid;not null" json:"invoice_id"`
	ReceiptNumber     string      `gorm:"size:100;unique" json:"receipt_number"`
	AmountPaid        float64     `json:"amount_paid"`
	PaymentDate       time.Time   `json:"payment_date"`
	PaymentMode       string      `gorm:"type:text;not null" json:"payment_mode"`
	TransactionID     string      `gorm:"size:255" json:"transaction_id"`
	Remarks           string      `gorm:"type:text" json:"remarks"`
	PaymentConfigID   *string     `gorm:"type:text" json:"payment_config_id,omitempty"`
	PaymentUPIID      string      `gorm:"type:text" json:"payment_upi_id"`
	PaymentPayeeName  string      `gorm:"type:text" json:"payment_payee_name"`
	PaymentQRImageURL string      `gorm:"type:text" json:"payment_qr_image_url"`
	PaymentQRNote     string      `gorm:"type:text" json:"payment_qr_note"`
	ReceivedBy        *string     `gorm:"type:uuid" json:"received_by"`
	CreatedAt         time.Time   `json:"created_at"`
	Invoice           *FeeInvoice `gorm:"foreignKey:InvoiceID" json:"invoice,omitempty"`
}

type ParentPaymentRequest struct {
	BaseModel
	SchoolID          string      `gorm:"type:text;not null;index" json:"school_id"`
	InvoiceID         string      `gorm:"type:text;not null;index" json:"invoice_id"`
	StudentID         string      `gorm:"type:text;not null;index" json:"student_id"`
	ParentUserID      string      `gorm:"type:text;not null;index" json:"parent_user_id"`
	PaymentID         *string     `gorm:"type:text" json:"payment_id,omitempty"`
	ReceiptID         *string     `gorm:"type:text" json:"receipt_id,omitempty"`
	RequestReference  string      `gorm:"size:100;uniqueIndex" json:"request_reference"`
	Amount            float64     `json:"amount"`
	PaymentDate       time.Time   `json:"payment_date"`
	PaymentMode       string      `gorm:"type:text;not null" json:"payment_mode"`
	TransactionID     string      `gorm:"size:255" json:"transaction_id"`
	ProofURL          *string     `gorm:"type:text" json:"proof_url,omitempty"`
	SelectedMonths    int         `json:"selected_months"`
	SelectedTerms     int         `json:"selected_terms"`
	Status            string      `gorm:"type:text;default:'pending';index" json:"status"`
	Remarks           string      `gorm:"type:text" json:"remarks"`
	AdminRemarks      string      `gorm:"type:text" json:"admin_remarks"`
	PaymentConfigID   *string     `gorm:"type:text" json:"payment_config_id,omitempty"`
	PaymentUPIID      string      `gorm:"type:text" json:"payment_upi_id"`
	PaymentPayeeName  string      `gorm:"type:text" json:"payment_payee_name"`
	PaymentQRImageURL string      `gorm:"type:text" json:"payment_qr_image_url"`
	PaymentQRNote     string      `gorm:"type:text" json:"payment_qr_note"`
	DecidedBy         *string     `gorm:"type:text" json:"decided_by,omitempty"`
	DecidedAt         *time.Time  `json:"decided_at,omitempty"`
	Invoice           *FeeInvoice `gorm:"foreignKey:InvoiceID" json:"invoice,omitempty"`
	Student           *Student    `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	ParentUser        *User       `gorm:"foreignKey:ParentUserID" json:"parent_user,omitempty"`
	Payment           *Payment    `gorm:"foreignKey:PaymentID" json:"payment,omitempty"`
}

// AfterFind populates NetAmount from PayableAmount (backward compatibility).
func (fi *FeeInvoice) AfterFind(tx *gorm.DB) error {
	fi.NetAmount = fi.PayableAmount
	return nil
}

// BeforeSave hook to update PayableAmount if NetAmount is set
func (fi *FeeInvoice) BeforeSave(tx *gorm.DB) error {
	if fi.NetAmount != 0 {
		fi.PayableAmount = fi.NetAmount
	}
	return nil
}

package models

import (
	"database/sql/driver"
	"encoding/json"
	"time"

	"gorm.io/datatypes"
)

// PaymentOrder represents a payment order created for fee payment
type PaymentOrder struct {
	BaseModel
	ParentID         string         `gorm:"type:uuid;not null;index" json:"parent_id"`
	StudentID        string         `gorm:"type:uuid;not null;index" json:"student_id"`
	Amount           float64        `json:"amount"`
	Currency         string         `gorm:"default:INR" json:"currency"`
	Gateway          string         `gorm:"default:razorpay" json:"gateway"`
	RazorpayOrderID  string         `gorm:"size:255;index" json:"razorpay_order_id"`
	ReceiptNo        string         `gorm:"size:100;unique" json:"receipt_no"`
	Status           string         `gorm:"type:text;default:'created';index" json:"status"` // created, attempted, paid, failed, expired, cancelled
	InvoiceIDs       datatypes.JSON `gorm:"type:jsonb" json:"invoice_ids"`                    // JSON array of invoice IDs
	Notes            datatypes.JSON `gorm:"type:jsonb" json:"notes"`                          // Metadata/notes
	CreatedAt        time.Time      `json:"created_at"`
	UpdatedAt        time.Time      `json:"updated_at"`
	Parent           *User          `gorm:"foreignKey:ParentID" json:"parent,omitempty"`
	Student          *Student       `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	Transactions     []PaymentTransaction `gorm:"foreignKey:PaymentOrderID" json:"transactions,omitempty"`
	OrderInvoiceMaps []PaymentOrderInvoiceMap `gorm:"foreignKey:PaymentOrderID" json:"order_invoice_maps,omitempty"`
}

// PaymentTransaction represents a payment transaction (verification)
type PaymentTransaction struct {
	BaseModel
	PaymentOrderID  string         `gorm:"type:uuid;not null;index" json:"payment_order_id"`
	ParentID        string         `gorm:"type:uuid;not null;index" json:"parent_id"`
	StudentID       string         `gorm:"type:uuid;not null;index" json:"student_id"`
	RazorpayOrderID string         `gorm:"size:255;index" json:"razorpay_order_id"`
	RazorpayPaymentID string        `gorm:"size:255;index" json:"razorpay_payment_id"`
	RazorpaySignature string        `gorm:"size:255" json:"razorpay_signature"`
	Amount          float64        `json:"amount"`
	Currency        string         `gorm:"default:INR" json:"currency"`
	PaymentMethod   *string        `gorm:"type:text" json:"payment_method"` // upi, card, netbanking, etc.
	Status          string         `gorm:"type:text;default:'pending';index" json:"status"` // pending, success, failed
	GatewayResponse datatypes.JSON `gorm:"type:jsonb" json:"gateway_response"`
	VerifiedAt      *time.Time     `json:"verified_at"`
	CreatedAt       time.Time      `json:"created_at"`
	UpdatedAt       time.Time      `json:"updated_at"`
	PaymentOrder    *PaymentOrder  `gorm:"foreignKey:PaymentOrderID" json:"payment_order,omitempty"`
	Parent          *User          `gorm:"foreignKey:ParentID" json:"parent,omitempty"`
	Student         *Student       `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	Receipt         *FeeReceipt    `gorm:"foreignKey:PaymentTransactionID" json:"receipt,omitempty"`
}

// FeeReceipt represents a payment receipt
type FeeReceipt struct {
	BaseModel
	ReceiptNo           string         `gorm:"size:100;unique" json:"receipt_no"`
	StudentID           string         `gorm:"type:uuid;not null;index" json:"student_id"`
	ParentID            string         `gorm:"type:uuid;not null;index" json:"parent_id"`
	PaymentTransactionID string         `gorm:"type:uuid;not null;index" json:"payment_transaction_id"`
	Amount              float64        `json:"amount"`
	PaymentMode         string         `gorm:"type:text" json:"payment_mode"` // upi, card, etc.
	PaidAt              time.Time      `json:"paid_at"`
	ReceiptPDFURL       *string        `gorm:"type:text" json:"receipt_pdf_url"`
	CreatedAt           time.Time      `json:"created_at"`
	UpdatedAt           time.Time      `json:"updated_at"`
	Student             *Student       `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	Parent              *User          `gorm:"foreignKey:ParentID" json:"parent,omitempty"`
	Transaction         *PaymentTransaction `gorm:"foreignKey:PaymentTransactionID" json:"transaction,omitempty"`
	PaidInvoices        []FeeInvoice   `gorm:"many2many:fee_receipt_invoice_map;" json:"paid_invoices,omitempty"`
}

// PaymentOrderInvoiceMap represents the mapping between payment orders and invoices
type PaymentOrderInvoiceMap struct {
	BaseModel
	PaymentOrderID string      `gorm:"type:uuid;not null;index" json:"payment_order_id"`
	FeeInvoiceID   string      `gorm:"type:uuid;not null;index" json:"fee_invoice_id"`
	AmountAllocated float64    `json:"amount_allocated"`
	CreatedAt      time.Time   `json:"created_at"`
	PaymentOrder   *PaymentOrder `gorm:"foreignKey:PaymentOrderID" json:"payment_order,omitempty"`
	Invoice        *FeeInvoice   `gorm:"foreignKey:FeeInvoiceID" json:"invoice,omitempty"`
}

// PaymentWebhookEvent stores raw webhook events for audit
type PaymentWebhookEvent struct {
	BaseModel
	EventID         string         `gorm:"size:255;unique" json:"event_id"`
	EventType       string         `gorm:"type:text;index" json:"event_type"`
	PaymentOrderID  *string        `gorm:"type:uuid" json:"payment_order_id"`
	RazorpayOrderID *string        `gorm:"size:255" json:"razorpay_order_id"`
	PaymentID       *string        `gorm:"size:255" json:"payment_id"`
	Payload         datatypes.JSON `gorm:"type:jsonb" json:"payload"`
	Processed       bool           `gorm:"default:false" json:"processed"`
	ProcessedAt     *time.Time     `json:"processed_at"`
	CreatedAt       time.Time      `json:"created_at"`
	UpdatedAt       time.Time      `json:"updated_at"`
}

// TableName specifies table names for GORM
func (PaymentOrder) TableName() string {
	return "payment_orders"
}

func (PaymentTransaction) TableName() string {
	return "payment_transactions"
}

func (FeeReceipt) TableName() string {
	return "fee_receipts"
}

func (PaymentOrderInvoiceMap) TableName() string {
	return "payment_order_invoice_map"
}

func (PaymentWebhookEvent) TableName() string {
	return "payment_webhook_events"
}

// Add these to the existing FeeInvoice model (in fee.go)
// PaidAmount and DueAmount should be updated when payment is verified
// Status values: unpaid, partially_paid, paid, overdue, cancelled

// JSON helpers for PaymentOrder.InvoiceIDs
func (p *PaymentOrder) GetInvoiceIDs() []string {
	var ids []string
	if p.InvoiceIDs != nil {
		_ = json.Unmarshal(p.InvoiceIDs, &ids)
	}
	return ids
}

func (p *PaymentOrder) SetInvoiceIDs(ids []string) error {
	data, err := json.Marshal(ids)
	if err != nil {
		return err
	}
	p.InvoiceIDs = data
	return nil
}

// JSON helpers for PaymentOrder.Notes
func (p *PaymentOrder) GetNotes() map[string]interface{} {
	notes := make(map[string]interface{})
	if p.Notes != nil {
		_ = json.Unmarshal(p.Notes, &notes)
	}
	return notes
}

func (p *PaymentOrder) SetNotes(notes map[string]interface{}) error {
	data, err := json.Marshal(notes)
	if err != nil {
		return err
	}
	p.Notes = data
	return nil
}

// JSON helpers for PaymentTransaction.GatewayResponse
func (t *PaymentTransaction) GetGatewayResponse() map[string]interface{} {
	response := make(map[string]interface{})
	if t.GatewayResponse != nil {
		_ = json.Unmarshal(t.GatewayResponse, &response)
	}
	return response
}

func (t *PaymentTransaction) SetGatewayResponse(response map[string]interface{}) error {
	data, err := json.Marshal(response)
	if err != nil {
		return err
	}
	t.GatewayResponse = data
	return nil
}

// Ensure datatypes.JSON implements Valuer and Scanner
var _ driver.Valuer = (*datatypes.JSON)(nil)

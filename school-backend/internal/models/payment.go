package models

import "time"

// PaymentOrder represents an overarching Razorpay order that might cover multiple invoices.
type PaymentOrder struct {
	BaseModel
	SchoolID        string    `gorm:"type:text;not null;index" json:"school_id"`
	ParentUserID    string    `gorm:"type:text;not null;index" json:"parent_user_id"`
	RazorpayOrderID string    `gorm:"size:255;uniqueIndex" json:"razorpay_order_id"`
	Amount          float64   `json:"amount"` // Total amount in original currency
	Currency        string    `gorm:"size:10;default:'INR'" json:"currency"`
	Status          string    `gorm:"type:text;default:'created';index" json:"status"` // created, paid, failed
	InvoiceIDs      string    `gorm:"type:text" json:"invoice_ids"`                    // comma-separated or JSON array of invoice IDs
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`

	School     *School `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	ParentUser *User   `gorm:"foreignKey:ParentUserID" json:"parent_user,omitempty"`
}

type PaymentWebhookEvent struct {
	BaseModel
	SchoolID          string    `gorm:"type:text;not null;index" json:"school_id"`
	RazorpayPaymentID string    `gorm:"size:255;index" json:"razorpay_payment_id"`
	RazorpayOrderID   string    `gorm:"size:255;index" json:"razorpay_order_id"`
	EventType         string    `gorm:"size:255" json:"event_type"` // payment.captured, payment.failed
	Payload           string    `gorm:"type:text" json:"payload"`   // raw JSON
	Processed         bool      `gorm:"default:false" json:"processed"`
	CreatedAt         time.Time `json:"created_at"`
}

// PaymentTransaction represents an individual payment attempt via Razorpay for a PaymentOrder.
type PaymentTransaction struct {
	BaseModel
	PaymentOrderID    string        `gorm:"type:text;not null;index" json:"payment_order_id"`
	RazorpayPaymentID string        `gorm:"size:255;uniqueIndex" json:"razorpay_payment_id"`
	Amount            float64       `json:"amount"`
	Currency          string        `gorm:"size:10;default:'INR'" json:"currency"`
	Status            string        `gorm:"type:text;default:'created';index" json:"status"` // captured, failed
	Method            string        `gorm:"type:text" json:"method"`                         // upi, card, netbanking, etc.
	CreatedAt         time.Time     `json:"created_at"`
	UpdatedAt         time.Time     `json:"updated_at"`
	PaymentOrder      *PaymentOrder `gorm:"foreignKey:PaymentOrderID" json:"payment_order,omitempty"`
}

// FeeReceipt represents the finalized receipt generated after a successful Razorpay payment transaction.
type FeeReceipt struct {
	BaseModel
	PaymentTransactionID string              `gorm:"type:text;not null;index" json:"payment_transaction_id"`
	ReceiptNumber        string              `gorm:"size:100;uniqueIndex" json:"receipt_number"`
	AmountPaid           float64             `json:"amount_paid"`
	PaymentDate          time.Time           `json:"payment_date"`
	CreatedAt            time.Time           `json:"created_at"`
	PaymentTransaction   *PaymentTransaction `gorm:"foreignKey:PaymentTransactionID" json:"payment_transaction,omitempty"`
}

package payments

import (
	"encoding/json"
	"fmt"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// WebhookEvent represents a Razorpay webhook event
type WebhookEvent struct {
	ID        string                 `json:"id"`
	Event     string                 `json:"event"`
	Payload   map[string]interface{} `json:"payload"`
	CreatedAt int64                  `json:"created_at"`
}

// WebhookHandler handles Razorpay webhook events
type WebhookHandler struct {
	razorpayClient *RazorpayClient
	paymentService *PaymentService
}

// NewWebhookHandler creates a new webhook handler
func NewWebhookHandler(razorpayClient *RazorpayClient, paymentService *PaymentService) *WebhookHandler {
	return &WebhookHandler{
		razorpayClient: razorpayClient,
		paymentService: paymentService,
	}
}

// ProcessWebhook processes a webhook event from Razorpay
func (wh *WebhookHandler) ProcessWebhook(payload []byte, signature string) error {
	// Verify webhook signature
	if !VerifyWebhookSignature(string(payload), signature, wh.razorpayClient.GetWebhookSignature()) {
		return fmt.Errorf("invalid webhook signature")
	}

	// Parse webhook event
	var event WebhookEvent
	if err := json.Unmarshal(payload, &event); err != nil {
		return fmt.Errorf("failed to parse webhook payload: %w", err)
	}

	// Check if event already processed
	var existingEvent models.PaymentWebhookEvent
	err := database.DB.Where("event_id = ?", event.ID).First(&existingEvent).Error
	if err == nil {
		// Event already processed, return idempotently
		return nil
	}

	// Store webhook event for audit
	now := time.Now()
	eventPayloadJSON, _ := json.Marshal(event.Payload)

	webhookEvent := &models.PaymentWebhookEvent{
		BaseModel:   models.BaseModel{ID: uuid.New().String()},
		EventID:     event.ID,
		EventType:   event.Event,
		Payload:     eventPayloadJSON,
		Processed:   false,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	// Start transaction for webhook processing
	tx := database.DB.Begin()
	if tx.Error != nil {
		return fmt.Errorf("failed to start transaction: %w", tx.Error)
	}

	// Create webhook event record
	if err := tx.Create(webhookEvent).Error; err != nil {
		tx.Rollback()
		return fmt.Errorf("failed to create webhook event: %w", err)
	}

	// Process based on event type
	switch event.Event {
	case "payment.captured":
		if err := wh.handlePaymentCaptured(tx, webhookEvent, event.Payload); err != nil {
			tx.Rollback()
			return err
		}
	case "payment.failed":
		if err := wh.handlePaymentFailed(tx, webhookEvent, event.Payload); err != nil {
			tx.Rollback()
			return err
		}
	case "order.paid":
		if err := wh.handleOrderPaid(tx, webhookEvent, event.Payload); err != nil {
			tx.Rollback()
			return err
		}
	}

	// Mark webhook as processed
	if err := tx.Model(webhookEvent).Updates(map[string]interface{}{
		"processed":    true,
		"processed_at": now,
	}).Error; err != nil {
		tx.Rollback()
		return fmt.Errorf("failed to mark webhook as processed: %w", err)
	}

	tx.Commit()
	return nil
}

// handlePaymentCaptured handles payment.captured webhook events
func (wh *WebhookHandler) handlePaymentCaptured(tx *gorm.DB, webhookEvent *models.PaymentWebhookEvent, payload map[string]interface{}) error {
	// Extract order and payment information
	orderData, _ := payload["order"].(map[string]interface{})
	paymentData, _ := payload["payment"].(map[string]interface{})

	orderID, _ := orderData["id"].(string)
	paymentID, _ := paymentData["id"].(string)

	if orderID == "" || paymentID == "" {
		return fmt.Errorf("invalid payment.captured payload")
	}

	// Find payment order by Razorpay order ID
	var paymentOrder models.PaymentOrder
	if err := tx.Where("razorpay_order_id = ?", orderID).First(&paymentOrder).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil // Order not found, just ignore
		}
		return err
	}

	// Check if transaction already exists for this payment
	var existingTransaction models.PaymentTransaction
	errCheck := database.DB.Where("razorpay_payment_id = ?", paymentID).First(&existingTransaction).Error
	if errCheck == nil {
		// Transaction already processed
		return nil
	}

	// Extract notes from order to get invoice IDs
	notes := paymentOrder.GetNotes()
	studentID, _ := notes["student_id"].(string)
	parentID, _ := notes["parent_id"].(string)

	// Update payment order status
	if err := tx.Model(&paymentOrder).Update("status", "paid").Error; err != nil {
		return err
	}

	// Update invoices
	invoiceIDs := paymentOrder.GetInvoiceIDs()
	amount, _ := paymentData["amount"].(float64)
	amountInRupees := amount / 100

	for _, invoiceID := range invoiceIDs {
		var invoice models.FeeInvoice
		if err := tx.Where("id = ?", invoiceID).First(&invoice).Error; err != nil {
			continue // Skip if invoice not found
		}

		invoice.PaidAmount += amountInRupees
		invoice.Balance = invoice.PayableAmount - invoice.PaidAmount

		if invoice.Balance <= 0 {
			invoice.Status = "paid"
		} else {
			invoice.Status = "partially_paid"
		}

		if err := tx.Save(&invoice).Error; err != nil {
			return err
		}
	}

	// Create receipt if not already created
	receipt := &models.FeeReceipt{
		BaseModel:   models.BaseModel{ID: uuid.New().String()},
		ReceiptNo:   paymentOrder.ReceiptNo,
		StudentID:   studentID,
		ParentID:    parentID,
		Amount:      amountInRupees,
		PaymentMode: "online",
		PaidAt:      time.Now(),
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if err := tx.Create(receipt).Error; err != nil {
		return err
	}

	return nil
}

// handlePaymentFailed handles payment.failed webhook events
func (wh *WebhookHandler) handlePaymentFailed(tx *gorm.DB, webhookEvent *models.PaymentWebhookEvent, payload map[string]interface{}) error {
	// Extract order and payment information
	orderData, _ := payload["order"].(map[string]interface{})
	paymentData, _ := payload["payment"].(map[string]interface{})

	orderID, _ := orderData["id"].(string)
	paymentID, _ := paymentData["id"].(string)

	if orderID == "" || paymentID == "" {
		return fmt.Errorf("invalid payment.failed payload")
	}

	// Find payment order by Razorpay order ID
	var paymentOrder models.PaymentOrder
	if err := tx.Where("razorpay_order_id = ?", orderID).First(&paymentOrder).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil
		}
		return err
	}

	// Update payment order status
	return tx.Model(&paymentOrder).Update("status", "failed").Error
}

// handleOrderPaid handles order.paid webhook events
func (wh *WebhookHandler) handleOrderPaid(tx *gorm.DB, webhookEvent *models.PaymentWebhookEvent, payload map[string]interface{}) error {
	// Extract order information
	order, _ := payload["order"].(map[string]interface{})
	orderID, _ := order["id"].(string)

	if orderID == "" {
		return fmt.Errorf("invalid order.paid payload")
	}

	// Find payment order by Razorpay order ID
	var paymentOrder models.PaymentOrder
	if err := tx.Where("razorpay_order_id = ?", orderID).First(&paymentOrder).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil
		}
		return err
	}

	// Mark as paid if not already
	if paymentOrder.Status != "paid" {
		return tx.Model(&paymentOrder).Update("status", "paid").Error
	}

	return nil
}


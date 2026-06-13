package payments

import (
	"encoding/json"
	"fmt"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// PaymentService handles business logic for payments
type PaymentService struct {
	razorpayClient *RazorpayClient
}

// NewPaymentService creates a new payment service
func NewPaymentService(razorpayClient *RazorpayClient) *PaymentService {
	return &PaymentService{
		razorpayClient: razorpayClient,
	}
}

// CreatePaymentOrder creates a new payment order and Razorpay order
func (ps *PaymentService) CreatePaymentOrder(
	parentID string,
	studentID string,
	invoiceIDs []string,
	payableAmount float64,
	schoolID string,
) (*models.PaymentOrder, error) {
	if payableAmount <= 0 {
		return nil, fmt.Errorf("invalid payable amount: %f", payableAmount)
	}

	// Convert rupees to paise (multiply by 100)
	amountInPaise := int64(payableAmount * 100)

	// Generate receipt number
	receiptNo := fmt.Sprintf("RCPT-%d-%s", time.Now().Unix(), uuid.New().String()[:8])

	// Create notes
	notes := map[string]interface{}{
		"student_id": studentID,
		"parent_id":  parentID,
		"school_id":  schoolID,
		"created_at": time.Now().Format(time.RFC3339),
	}

	// Create Razorpay order
	razorpayOrder, err := ps.razorpayClient.CreateOrder(amountInPaise, receiptNo, notes)
	if err != nil {
		return nil, fmt.Errorf("failed to create Razorpay order: %w", err)
	}

	razorpayOrderID, ok := razorpayOrder["id"].(string)
	if !ok {
		return nil, fmt.Errorf("invalid Razorpay order response")
	}

	// Create local payment order record
	invoiceIDsJSON, _ := json.Marshal(invoiceIDs)
	notesJSON, _ := json.Marshal(notes)

	paymentOrder := &models.PaymentOrder{
		BaseModel:       models.BaseModel{ID: uuid.New().String()},
		ParentID:        parentID,
		StudentID:       studentID,
		Amount:          payableAmount,
		Currency:        ps.razorpayClient.cfg.RazorpayCurrency,
		Gateway:         "razorpay",
		RazorpayOrderID: razorpayOrderID,
		ReceiptNo:       receiptNo,
		Status:          "created",
		InvoiceIDs:      invoiceIDsJSON,
		Notes:           notesJSON,
		CreatedAt:       time.Now(),
		UpdatedAt:       time.Now(),
	}

	if err := database.DB.Create(paymentOrder).Error; err != nil {
		return nil, fmt.Errorf("failed to create payment order: %w", err)
	}

	// Create mapping records for each invoice
	for _, invoiceID := range invoiceIDs {
		mapping := &models.PaymentOrderInvoiceMap{
			BaseModel:       models.BaseModel{ID: uuid.New().String()},
			PaymentOrderID:  paymentOrder.ID,
			FeeInvoiceID:    invoiceID,
			AmountAllocated: 0, // Will be updated when payment is verified
			CreatedAt:       time.Now(),
		}
		if err := database.DB.Create(mapping).Error; err != nil {
			return nil, fmt.Errorf("failed to create invoice mapping: %w", err)
		}
	}

	return paymentOrder, nil
}

// VerifyPaymentSignature verifies the payment signature and creates transaction record
func (ps *PaymentService) VerifyPaymentSignature(
	paymentOrderID string,
	razorpayOrderID string,
	razorpayPaymentID string,
	razorpaySignature string,
) (*models.PaymentTransaction, error) {
	// Verify signature
	if !VerifyRazorpaySignature(razorpayOrderID, razorpayPaymentID, razorpaySignature, ps.razorpayClient.cfg.RazorpayKeySecret) {
		return nil, fmt.Errorf("invalid payment signature")
	}

	// Fetch payment order
	var paymentOrder models.PaymentOrder
	if err := database.DB.First(&paymentOrder, "id = ?", paymentOrderID).Error; err != nil {
		return nil, fmt.Errorf("payment order not found: %w", err)
	}

	// Verify order ID matches
	if paymentOrder.RazorpayOrderID != razorpayOrderID {
		return nil, fmt.Errorf("razorpay order ID mismatch")
	}

	// Fetch payment details from Razorpay
	razorpayPayment, err := ps.razorpayClient.FetchPayment(razorpayPaymentID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Razorpay payment: %w", err)
	}

	// Extract payment details
	amount, _ := razorpayPayment["amount"].(float64)
	status, _ := razorpayPayment["status"].(string)
	method, _ := razorpayPayment["method"].(string)

	// Create payment transaction record
	now := time.Now()
	gatewayResponseJSON, _ := json.Marshal(razorpayPayment)

	transaction := &models.PaymentTransaction{
		BaseModel:         models.BaseModel{ID: uuid.New().String()},
		PaymentOrderID:    paymentOrderID,
		ParentID:          paymentOrder.ParentID,
		StudentID:         paymentOrder.StudentID,
		RazorpayOrderID:   razorpayOrderID,
		RazorpayPaymentID: razorpayPaymentID,
		RazorpaySignature: razorpaySignature,
		Amount:            amount / 100, // Convert from paise to rupees
		Currency:          ps.razorpayClient.cfg.RazorpayCurrency,
		PaymentMethod:     &method,
		Status:            "pending",
		GatewayResponse:   gatewayResponseJSON,
		CreatedAt:         now,
		UpdatedAt:         now,
	}

	// Start transaction
	tx := database.DB.Begin()
	if tx.Error != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", tx.Error)
	}

	// Create transaction record
	if err := tx.Create(transaction).Error; err != nil {
		tx.Rollback()
		return nil, fmt.Errorf("failed to create transaction record: %w", err)
	}

	// If payment is captured, update invoice records
	if status == "captured" {
		transaction.Status = "success"
		transaction.VerifiedAt = &now

		// Fetch and update all invoices linked to this payment order
		invoiceIDs := paymentOrder.GetInvoiceIDs()

		if len(invoiceIDs) > 0 {
			invoices := make([]models.FeeInvoice, 0, len(invoiceIDs))
			balances := make([]float64, 0, len(invoiceIDs))
			for _, invoiceID := range invoiceIDs {
				var invoice models.FeeInvoice
				if err := tx.First(&invoice, "id = ?", invoiceID).Error; err != nil {
					tx.Rollback()
					return nil, fmt.Errorf("invoice not found: %w", err)
				}
				invoices = append(invoices, invoice)
				balances = append(balances, invoice.Balance)
			}

			allocations := allocatePaymentAcrossBalances(transaction.Amount, balances)
			for i := range invoices {
				invoice := invoices[i]
				allocated := allocations[i]
				if allocated <= 0 {
					continue
				}

				// Update payment amount
				invoice.PaidAmount += allocated
				invoice.Balance = invoice.PayableAmount - invoice.PaidAmount
				if invoice.Balance < 0 {
					invoice.Balance = 0
				}

				// Update status
				if invoice.Balance <= 0 {
					invoice.Status = "paid"
				} else {
					invoice.Status = "partially_paid"
				}

				if err := tx.Save(&invoice).Error; err != nil {
					tx.Rollback()
					return nil, fmt.Errorf("failed to update invoice: %w", err)
				}

				// Update mapping allocation
				if err := tx.Model(&models.PaymentOrderInvoiceMap{}).
					Where("payment_order_id = ? AND fee_invoice_id = ?", paymentOrderID, invoice.ID).
					Update("amount_allocated", allocated).Error; err != nil {
					tx.Rollback()
					return nil, fmt.Errorf("failed to update invoice mapping: %w", err)
				}
			}

			// Update payment order status
			if err := tx.Model(&paymentOrder).Update("status", "paid").Error; err != nil {
				tx.Rollback()
				return nil, fmt.Errorf("failed to update payment order: %w", err)
			}

			// Create receipt
			receipt := &models.FeeReceipt{
				BaseModel:            models.BaseModel{ID: uuid.New().String()},
				ReceiptNo:            fmt.Sprintf("RCPT-%d-%s", time.Now().Unix(), uuid.New().String()[:8]),
				StudentID:            paymentOrder.StudentID,
				ParentID:             paymentOrder.ParentID,
				PaymentTransactionID: transaction.ID,
				Amount:               transaction.Amount,
				PaymentMode:          method,
				PaidAt:               now,
				CreatedAt:            now,
				UpdatedAt:            now,
			}

			if err := tx.Create(receipt).Error; err != nil {
				tx.Rollback()
				return nil, fmt.Errorf("failed to create receipt: %w", err)
			}
		}

		if err := tx.Save(transaction).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("failed to save transaction: %w", err)
		}
	} else {
		transaction.Status = "failed"
		if err := tx.Save(transaction).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("failed to save failed transaction: %w", err)
		}
	}

	tx.Commit()
	return transaction, nil
}

// CheckDuplicateReceipt checks if a receipt already exists for a transaction
func (ps *PaymentService) CheckDuplicateReceipt(paymentTransactionID string) bool {
	var receipt models.FeeReceipt
	err := database.DB.Where("payment_transaction_id = ?", paymentTransactionID).First(&receipt).Error
	return err == nil
}

func allocatePaymentAcrossBalances(amount float64, balances []float64) []float64 {
	allocations := make([]float64, len(balances))
	remaining := amount
	for i, balance := range balances {
		if remaining <= 0 {
			break
		}
		if balance <= 0 {
			continue
		}
		allocated := balance
		if remaining < balance {
			allocated = remaining
		}
		allocations[i] = allocated
		remaining -= allocated
	}
	return allocations
}

// CreateReceiptIfNotExists creates a receipt if it doesn't already exist
func (ps *PaymentService) CreateReceiptIfNotExists(transaction *models.PaymentTransaction) (*models.FeeReceipt, error) {
	if ps.CheckDuplicateReceipt(transaction.ID) {
		// Fetch existing receipt
		var receipt models.FeeReceipt
		if err := database.DB.First(&receipt, "payment_transaction_id = ?", transaction.ID).Error; err == nil {
			return &receipt, nil
		}
	}

	now := time.Now()
	receipt := &models.FeeReceipt{
		BaseModel:            models.BaseModel{ID: uuid.New().String()},
		ReceiptNo:            fmt.Sprintf("RCPT-%d-%s", now.Unix(), uuid.New().String()[:8]),
		StudentID:            transaction.StudentID,
		ParentID:             transaction.ParentID,
		PaymentTransactionID: transaction.ID,
		Amount:               transaction.Amount,
		PaymentMode:          *transaction.PaymentMethod,
		PaidAt:               now,
		CreatedAt:            now,
		UpdatedAt:            now,
	}

	if err := database.DB.Create(receipt).Error; err != nil {
		return nil, fmt.Errorf("failed to create receipt: %w", err)
	}

	return receipt, nil
}

// GetPaymentOrderByID fetches a payment order by ID
func (ps *PaymentService) GetPaymentOrderByID(paymentOrderID string) (*models.PaymentOrder, error) {
	var order models.PaymentOrder
	if err := database.DB.Preload("Transactions").First(&order, "id = ?", paymentOrderID).Error; err != nil {
		return nil, err
	}
	return &order, nil
}

// GetReceiptByID fetches a receipt by ID
func (ps *PaymentService) GetReceiptByID(receiptID string) (*models.FeeReceipt, error) {
	var receipt models.FeeReceipt
	if err := database.DB.
		Preload("Student").
		Preload("Parent").
		Preload("Transaction").
		Preload("PaidInvoices", func(db *gorm.DB) *gorm.DB {
			return db.Joins("JOIN fee_receipt_invoice_map ON fee_invoices.id = fee_receipt_invoice_map.fee_invoice_id").
				Where("fee_receipt_invoice_map.receipt_id = ?", receiptID)
		}).
		First(&receipt, "id = ?", receiptID).Error; err != nil {
		return nil, err
	}
	return &receipt, nil
}

// ListPaymentsByParent fetches all payments for a parent
func (ps *PaymentService) ListPaymentsByParent(parentID string, limit int, offset int) ([]models.FeeReceipt, int64, error) {
	var receipts []models.FeeReceipt
	var total int64

	query := database.DB.
		Preload("Student").
		Preload("Parent").
		Preload("Transaction").
		Where("parent_id = ?", parentID).
		Order("paid_at DESC")

	if err := query.Model(&models.FeeReceipt{}).Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Limit(limit).Offset(offset).Find(&receipts).Error; err != nil {
		return nil, 0, err
	}

	return receipts, total, nil
}

// ListPaymentsByStudent fetches all payments for a student
func (ps *PaymentService) ListPaymentsByStudent(studentID string, limit int, offset int) ([]models.FeeReceipt, int64, error) {
	var receipts []models.FeeReceipt
	var total int64

	query := database.DB.
		Preload("Student").
		Preload("Parent").
		Preload("Transaction").
		Where("student_id = ?", studentID).
		Order("paid_at DESC")

	if err := query.Model(&models.FeeReceipt{}).Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Limit(limit).Offset(offset).Find(&receipts).Error; err != nil {
		return nil, 0, err
	}

	return receipts, total, nil
}

// GetPaymentOrderStatus fetches current status of a payment order
func (ps *PaymentService) GetPaymentOrderStatus(paymentOrderID string) (string, error) {
	var order models.PaymentOrder
	if err := database.DB.Select("status").First(&order, "id = ?", paymentOrderID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return "", fmt.Errorf("payment order not found")
		}
		return "", err
	}
	return order.Status, nil
}

// ConflictOnClause returns a conflict clause for upsert operations
func ConflictOnClause(column string) clause.OnConflict {
	return clause.OnConflict{
		UpdateAll: true,
	}
}

// internal/handlers/parent_fees.go
// Handles parent fee-related endpoints for online payments

package handlers

import (
	"net/http"
	"strconv"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/payments"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// ParentFeeHandler handles parent fee-related endpoints
type ParentFeeHandler struct {
	paymentService *payments.PaymentService
}

// NewParentFeeHandler creates a new parent fee handler
func NewParentFeeHandler(paymentService *payments.PaymentService) *ParentFeeHandler {
	return &ParentFeeHandler{
		paymentService: paymentService,
	}
}

// GetMyStudents fetches students linked to authenticated parent
// GET /api/v1/parents/me/students
func (h *ParentFeeHandler) GetMyStudents(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var links []models.ParentStudentLink
	if err := database.DB.
		Preload("Student").
		Where("parent_user_id = ?", userID).
		Find(&links).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch students"})
		return
	}

	type StudentInfo struct {
		StudentID   string `json:"student_id"`
		Name        string `json:"name"`
		ClassId     string `json:"class_id"`
		SectionID   string `json:"section_id"`
	}

	students := make([]StudentInfo, 0)
	for _, link := range links {
		if link.Student == nil {
			continue
		}
		student := link.Student
		classID := ""
		sectionID := ""

		if student.CurrentSectionID != nil {
			sectionID = *student.CurrentSectionID
		}

		students = append(students, StudentInfo{
			StudentID:  student.ID,
			Name:       student.FirstName + " " + student.LastName,
			ClassId:    classID,
			SectionID:  sectionID,
		})
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"students": students,
		},
	})
}

// GetStudentFeeSummary fetches fee summary for a specific student
// GET /api/v1/parents/students/{student_id}/fees/summary
func (h *ParentFeeHandler) GetStudentFeeSummary(c *gin.Context) {
	userID := c.GetString("user_id")
	studentID := c.Param("student_id")

	if userID == "" || studentID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	// Verify parent-student relationship
	var link models.ParentStudentLink
	if err := database.DB.Where("parent_user_id = ? AND student_id = ?", userID, studentID).First(&link).Error; err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "unauthorized access to student"})
		return
	}

	// Fetch unpaid/partially paid invoices for this student
	var invoices []models.FeeInvoice
	if err := database.DB.
		Where("student_id = ? AND (status = 'unpaid' OR status = 'partially_paid')", studentID).
		Find(&invoices).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch invoices"})
		return
	}

	type InvoiceInfo struct {
		InvoiceID     string `json:"invoice_id"`
		Title         string `json:"title"`
		PayableAmount int64  `json:"payable_amount"`
		PaidAmount    int64  `json:"paid_amount"`
		DueAmount     int64  `json:"due_amount"`
		DueDate       string `json:"due_date"`
		Status        string `json:"status"`
	}

	var totalDue int64
	var totalPaid int64
	invoiceList := make([]InvoiceInfo, 0)

	for _, inv := range invoices {
		payable := int64(inv.PayableAmount * 100)
		paid := int64(inv.PaidAmount * 100)
		due := payable - paid

		totalDue += due
		totalPaid += paid

		invoiceList = append(invoiceList, InvoiceInfo{
			InvoiceID:     inv.ID,
			Title:         inv.InvoiceNumber,
			PayableAmount: payable,
			PaidAmount:    paid,
			DueAmount:     due,
			DueDate:       inv.DueDate.Format("2006-01-02"),
			Status:        inv.Status,
		})
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"student_id":   studentID,
			"total_due":    totalDue,
			"total_paid":   totalPaid,
			"currency":     "INR",
			"invoices":     invoiceList,
		},
	})
}

// CreatePaymentOrder creates a Razorpay payment order
// POST /api/v1/parents/fees/payment-orders
func (h *ParentFeeHandler) CreatePaymentOrder(c *gin.Context) {
	userID := c.GetString("user_id")
	schoolID := scopedSchoolID(c)

	if userID == "" || schoolID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req struct {
		StudentID  string   `json:"student_id" binding:"required"`
		InvoiceIDs []string `json:"invoice_ids" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Verify parent-student relationship
	var link models.ParentStudentLink
	if err := database.DB.Where("parent_user_id = ? AND student_id = ?", userID, req.StudentID).First(&link).Error; err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "unauthorized access to student"})
		return
	}

	// Fetch unpaid/partially paid invoices for this student
	var invoices []models.FeeInvoice
	if err := database.DB.
		Where("student_id = ? AND (status = 'unpaid' OR status = 'partially_paid')", req.StudentID).
		Find(&invoices).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch invoices"})
		return
	}

	// Filter to requested invoice IDs
	var selectedInvoices []models.FeeInvoice
	for _, inv := range invoices {
		for _, reqID := range req.InvoiceIDs {
			if inv.ID == reqID {
				selectedInvoices = append(selectedInvoices, inv)
				break
			}
		}
	}

	if len(selectedInvoices) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "no valid invoices found"})
		return
	}

	// Calculate total payable amount
	var totalPayable float64
	for _, inv := range selectedInvoices {
		totalPayable += inv.PayableAmount - inv.PaidAmount
	}

	if totalPayable <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "no amount due"})
		return
	}

	// Get parent ID from link
	var parent models.User
	if err := database.DB.Where("id = ?", userID).First(&parent).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch parent"})
		return
	}

	// Create payment order through payment service
	response, err := h.paymentService.CreatePaymentOrder(
		parent.ID,
		req.StudentID,
		req.InvoiceIDs,
		totalPayable,
		schoolID,
	)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    response,
	})
}

// VerifyPayment verifies a Razorpay payment
// POST /api/v1/parents/fees/verify-payment
func (h *ParentFeeHandler) VerifyPayment(c *gin.Context) {
	userID := c.GetString("user_id")

	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req struct {
		PaymentOrderID   string `json:"payment_order_id" binding:"required"`
		RazorpayOrderID  string `json:"razorpay_order_id" binding:"required"`
		RazorpayPaymentID string `json:"razorpay_payment_id" binding:"required"`
		RazorpaySignature string `json:"razorpay_signature" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Verify payment through payment service
	_, err := h.paymentService.VerifyPaymentSignature(
		req.PaymentOrderID,
		req.RazorpayOrderID,
		req.RazorpayPaymentID,
		req.RazorpaySignature,
	)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Fetch receipt to return details
	var receipt models.FeeReceipt
	if err := database.DB.
		Where("payment_transaction_id IN (SELECT id FROM payment_transactions WHERE razorpay_payment_id = ?)", req.RazorpayPaymentID).
		First(&receipt).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch receipt"})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"status":   "success",
			"message":  "Payment verified successfully",
			"receipt": gin.H{
				"receipt_id": receipt.ID,
				"receipt_no": receipt.ReceiptNo,
				"amount":     receipt.Amount,
				"paid_at":    receipt.PaidAt.Format("2006-01-02T15:04:05Z"),
			},
		},
	})
}

// GetPaymentHistory fetches payment history for parent
// GET /api/v1/parents/fees/payments
func (h *ParentFeeHandler) GetPaymentHistory(c *gin.Context) {
	userID := c.GetString("user_id")

	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	page := 1
	pageSize := 10

	if p := c.Query("page"); p != "" {
		if parsed, err := strconv.Atoi(p); err == nil && parsed > 0 {
			page = parsed
		}
	}

	if ps := c.Query("page_size"); ps != "" {
		if parsed, err := strconv.Atoi(ps); err == nil && parsed > 0 && parsed <= 100 {
			pageSize = parsed
		}
	}

	var receipts []models.FeeReceipt
	if err := database.DB.
		Where("parent_id IN (SELECT student_id FROM parent_student_links WHERE parent_user_id = ?)", userID).
		Order("paid_at DESC").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Find(&receipts).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch payment history"})
		return
	}

	type PaymentInfo struct {
		ReceiptID   string `json:"receipt_id"`
		ReceiptNo   string `json:"receipt_no"`
		StudentName string `json:"student_name"`
		Amount      int64  `json:"amount"`
		PaymentMode string `json:"payment_mode"`
		PaidAt      string `json:"paid_at"`
		Status      string `json:"status"`
	}

	payments := make([]PaymentInfo, 0)
	for _, receipt := range receipts {
		payments = append(payments, PaymentInfo{
			ReceiptID:   receipt.ID,
			ReceiptNo:   receipt.ReceiptNo,
			StudentName: "",
			Amount:      int64(receipt.Amount * 100),
			PaymentMode: receipt.PaymentMode,
			PaidAt:      receipt.PaidAt.Format("2006-01-02T15:04:05Z"),
			Status:      "success",
		})
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"payments": payments,
		},
	})
}

// GetReceipt fetches receipt details
// GET /api/v1/parents/fees/receipts/{receipt_id}
func (h *ParentFeeHandler) GetReceipt(c *gin.Context) {
	userID := c.GetString("user_id")
	receiptID := c.Param("receipt_id")

	if userID == "" || receiptID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	var receipt models.FeeReceipt
	if err := database.DB.
		Preload("Student").
		Where("id = ?", receiptID).
		First(&receipt).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "receipt not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch receipt"})
		}
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"receipt_no":  receipt.ReceiptNo,
			"amount":      receipt.Amount,
			"payment_mode": receipt.PaymentMode,
			"paid_at":     receipt.PaidAt.Format("2006-01-02T15:04:05Z"),
		},
	})
}

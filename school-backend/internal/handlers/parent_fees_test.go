package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"

	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

func TestParentFeeSummaryUsesCanonicalInvoiceStatuses(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.ParentStudentLink{}, &models.FeeInvoice{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	if err := db.Create(&models.ParentStudentLink{
		BaseModel:              models.BaseModel{ID: "link-summary"},
		SchoolID:               "school-summary",
		ParentUserID:           "parent-current",
		StudentID:              "student-current",
		StudentAdmissionNumber: "ADM-1",
	}).Error; err != nil {
		t.Fatalf("seed parent link: %v", err)
	}
	dueDate := time.Date(2026, 7, 10, 0, 0, 0, 0, time.UTC)
	invoices := []models.FeeInvoice{
		{BaseModel: models.BaseModel{ID: "invoice-pending"}, StudentID: "student-current", InvoiceNumber: "INV-PENDING", DueDate: dueDate, PayableAmount: 1000, PaidAmount: 0, Balance: 1000, Status: "pending"},
		{BaseModel: models.BaseModel{ID: "invoice-partial"}, StudentID: "student-current", InvoiceNumber: "INV-PARTIAL", DueDate: dueDate, PayableAmount: 1500, PaidAmount: 500, Balance: 1000, Status: "partial"},
		{BaseModel: models.BaseModel{ID: "invoice-overdue"}, StudentID: "student-current", InvoiceNumber: "INV-OVERDUE", DueDate: dueDate, PayableAmount: 800, PaidAmount: 0, Balance: 800, Status: "overdue"},
		{BaseModel: models.BaseModel{ID: "invoice-paid"}, StudentID: "student-current", InvoiceNumber: "INV-PAID", DueDate: dueDate, PayableAmount: 900, PaidAmount: 900, Balance: 0, Status: "paid"},
	}
	if err := db.Create(&invoices).Error; err != nil {
		t.Fatalf("seed invoices: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("user_id", "parent-current")
		c.Next()
	})
	router.GET("/parents/students/:student_id/fees/summary", NewParentFeeHandler().GetStudentFeeSummary)

	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, httptest.NewRequest(
		http.MethodGet,
		"/parents/students/student-current/fees/summary",
		nil,
	))

	if resp.Code != http.StatusOK {
		t.Fatalf("summary status=%d body=%s", resp.Code, resp.Body.String())
	}
	var body struct {
		Data struct {
			TotalDue int64 `json:"total_due"`
			Invoices []struct {
				InvoiceID string `json:"invoice_id"`
				Status    string `json:"status"`
			} `json:"invoices"`
		} `json:"data"`
	}
	if err := json.Unmarshal(resp.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode summary body: %v", err)
	}
	if len(body.Data.Invoices) != 3 {
		t.Fatalf("expected 3 unpaid invoices, got %+v", body.Data.Invoices)
	}
	if body.Data.TotalDue != 280000 {
		t.Fatalf("total_due=%d, want 280000", body.Data.TotalDue)
	}
}

func TestParentPaymentHistoryUsesReceiptParentID(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.ParentStudentLink{}, &models.FeeReceipt{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	if err := db.Create(&models.ParentStudentLink{
		BaseModel:              models.BaseModel{ID: "link-history"},
		SchoolID:               "school-history",
		ParentUserID:           "parent-current",
		StudentID:              "student-current",
		StudentAdmissionNumber: "ADM-2",
	}).Error; err != nil {
		t.Fatalf("seed parent link: %v", err)
	}
	paidAt := time.Date(2026, 7, 11, 9, 0, 0, 0, time.UTC)
	receipts := []models.FeeReceipt{
		{BaseModel: models.BaseModel{ID: "receipt-current-parent"}, ReceiptNo: "RCP-CURRENT", StudentID: "student-current", ParentID: "parent-current", PaymentTransactionID: "txn-current", Amount: 500, PaymentMode: "upi", PaidAt: paidAt},
		{BaseModel: models.BaseModel{ID: "receipt-other-parent"}, ReceiptNo: "RCP-OTHER", StudentID: "student-current", ParentID: "parent-other", PaymentTransactionID: "txn-other", Amount: 700, PaymentMode: "upi", PaidAt: paidAt},
	}
	if err := db.Create(&receipts).Error; err != nil {
		t.Fatalf("seed receipts: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("user_id", "parent-current")
		c.Next()
	})
	router.GET("/parents/fees/payments", NewParentFeeHandler().GetPaymentHistory)

	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, httptest.NewRequest(http.MethodGet, "/parents/fees/payments", nil))

	if resp.Code != http.StatusOK {
		t.Fatalf("history status=%d body=%s", resp.Code, resp.Body.String())
	}
	var body struct {
		Data struct {
			Payments []struct {
				ReceiptID string `json:"receipt_id"`
				ReceiptNo string `json:"receipt_no"`
			} `json:"payments"`
		} `json:"data"`
	}
	if err := json.Unmarshal(resp.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode history body: %v", err)
	}
	if len(body.Data.Payments) != 1 || body.Data.Payments[0].ReceiptID != "receipt-current-parent" {
		t.Fatalf("unexpected parent payments: %+v", body.Data.Payments)
	}
}

func TestParentReceiptRejectsOtherParentReceipt(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.FeeReceipt{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	if err := db.Create(&models.FeeReceipt{
		BaseModel:            models.BaseModel{ID: "receipt-other-parent"},
		ReceiptNo:            "RCP-OTHER",
		StudentID:            "student-other",
		ParentID:             "parent-other",
		PaymentTransactionID: "txn-other",
		Amount:               500,
		PaymentMode:          "upi",
	}).Error; err != nil {
		t.Fatalf("seed receipt: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("user_id", "parent-current")
		c.Next()
	})
	router.GET("/parents/fees/receipts/:receipt_id", NewParentFeeHandler().GetReceipt)

	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, httptest.NewRequest(
		http.MethodGet,
		"/parents/fees/receipts/receipt-other-parent",
		nil,
	))

	if resp.Code != http.StatusNotFound {
		t.Fatalf("receipt status=%d body=%s, want 404", resp.Code, resp.Body.String())
	}
}

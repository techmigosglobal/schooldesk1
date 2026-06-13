package handlers

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

func TestParentVerifyPaymentRejectsOtherParentOrder(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.PaymentOrder{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	if err := db.Create(&models.PaymentOrder{
		BaseModel:       models.BaseModel{ID: "order-other-parent"},
		ParentID:        "parent-other",
		StudentID:       "student-owned-by-other",
		Amount:          1000,
		Currency:        "INR",
		Gateway:         "razorpay",
		RazorpayOrderID: "order_razorpay_other",
		Status:          "created",
	}).Error; err != nil {
		t.Fatalf("seed order: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("user_id", "parent-current")
		c.Next()
	})
	router.POST("/parents/fees/verify-payment", NewParentFeeHandler(nil).VerifyPayment)

	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, httptest.NewRequest(
		http.MethodPost,
		"/parents/fees/verify-payment",
		strings.NewReader(`{"payment_order_id":"order-other-parent","razorpay_order_id":"order_razorpay_other","razorpay_payment_id":"pay_test","razorpay_signature":"sig"}`),
	))

	if resp.Code != http.StatusForbidden {
		t.Fatalf("verify status=%d body=%s, want 403", resp.Code, resp.Body.String())
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
	router.GET("/parents/fees/receipts/:receipt_id", NewParentFeeHandler(nil).GetReceipt)

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

package handlers

import (
	"net/http"
	"net/http/httptest"

	"testing"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)


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

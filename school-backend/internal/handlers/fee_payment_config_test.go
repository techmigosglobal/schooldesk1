package handlers

import (
	"encoding/json"
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

func TestPaymentConfigCanBeManagedByPrincipalAndReadByParent(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.SchoolPaymentSetting{}, &models.AuditLog{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	handler := NewFeeHandler()
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-payment-config")
		c.Set("user_id", "principal-payment-config")
		c.Set("role_name", "Principal")
		c.Next()
	})
	router.GET("/fees/payment-config", handler.GetPaymentConfig)
	router.PUT("/fees/payment-config", handler.UpdatePaymentConfig)

	updateReq := httptest.NewRequest(
		http.MethodPut,
		"/fees/payment-config",
		strings.NewReader(`{"upi_id":"school@upi","payee_name":"School Desk","merchant_code":"1234","qr_note":"Fee payment","qr_image_url":"/uploads/shared/school-payment-config/test-qr.png","upi_enabled":true}`),
	)
	updateReq.Header.Set("Content-Type", "application/json")
	updateResp := httptest.NewRecorder()
	router.ServeHTTP(updateResp, updateReq)
	if updateResp.Code != http.StatusOK {
		t.Fatalf("update status=%d body=%s", updateResp.Code, updateResp.Body.String())
	}

	readResp := httptest.NewRecorder()
	router.ServeHTTP(readResp, httptest.NewRequest(http.MethodGet, "/fees/payment-config", nil))
	if readResp.Code != http.StatusOK {
		t.Fatalf("read status=%d body=%s", readResp.Code, readResp.Body.String())
	}
	var body struct {
		Data map[string]any `json:"data"`
	}
	if err := json.Unmarshal(readResp.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode config: %v", err)
	}
	if body.Data["upi_id"] != "school@upi" || body.Data["qr_image_url"] != "/uploads/shared/school-payment-config/test-qr.png" || body.Data["upi_enabled"] != true {
		t.Fatalf("unexpected payment config: %+v", body.Data)
	}
}

package handlers

import (
	"io"
	"net/http"

	"school-backend/internal/payments"

	"github.com/gin-gonic/gin"
)

// PaymentWebhookHandler handles Razorpay webhooks
type PaymentWebhookHandler struct {
	webhookHandler *payments.WebhookHandler
}

// NewPaymentWebhookHandler creates a new webhook handler
func NewPaymentWebhookHandler(webhookHandler *payments.WebhookHandler) *PaymentWebhookHandler {
	return &PaymentWebhookHandler{
		webhookHandler: webhookHandler,
	}
}

// HandleWebhook processes Razorpay webhooks
// POST /api/v1/payments/razorpay/webhook
func (h *PaymentWebhookHandler) HandleWebhook(c *gin.Context) {
	// Read raw body
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to read request body"})
		return
	}

	// Get signature from header
	signature := c.GetHeader("X-Razorpay-Signature")
	if signature == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing webhook signature"})
		return
	}

	// Process webhook
	if err := h.webhookHandler.ProcessWebhook(body, signature); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "webhook processing failed", "details": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

package payments

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"os"
	"testing"
)

func TestVerifyWebhookSignature(t *testing.T) {
	secret := "test_webhook_secret"
	os.Setenv("RAZORPAY_WEBHOOK_SECRET", secret)
	defer os.Unsetenv("RAZORPAY_WEBHOOK_SECRET")

	payloadBody := []byte(`{"event":"payment.captured"}`)
	
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payloadBody)
	validSignature := hex.EncodeToString(mac.Sum(nil))

	if err := VerifyWebhookSignature(payloadBody, validSignature); err != nil {
		t.Errorf("Expected nil error for valid signature, got %v", err)
	}

	if err := VerifyWebhookSignature(payloadBody, "invalid_signature"); err == nil {
		t.Errorf("Expected error for invalid signature, got nil")
	}

	os.Unsetenv("RAZORPAY_WEBHOOK_SECRET")
	if err := VerifyWebhookSignature(payloadBody, validSignature); err == nil {
		t.Errorf("Expected error when secret is not set, got nil")
	}
}

func TestVerifyPaymentSignature(t *testing.T) {
	secret := "test_key_secret"
	os.Setenv("RAZORPAY_KEY_SECRET", secret)
	defer os.Unsetenv("RAZORPAY_KEY_SECRET")

	orderID := "order_123"
	paymentID := "pay_123"
	payload := orderID + "|" + paymentID

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(payload))
	validSignature := hex.EncodeToString(mac.Sum(nil))

	if err := VerifyPaymentSignature(orderID, paymentID, validSignature); err != nil {
		t.Errorf("Expected nil error for valid signature, got %v", err)
	}

	if err := VerifyPaymentSignature(orderID, paymentID, "invalid_signature"); err == nil {
		t.Errorf("Expected error for invalid signature, got nil")
	}

	os.Unsetenv("RAZORPAY_KEY_SECRET")
	if err := VerifyPaymentSignature(orderID, paymentID, validSignature); err == nil {
		t.Errorf("Expected error when secret is not set, got nil")
	}
}

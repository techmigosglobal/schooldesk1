package payments

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
)

// VerifyWebhookSignature verifies the Razorpay webhook signature
func VerifyWebhookSignature(payloadBody []byte, signature string) error {
	secret := os.Getenv("RAZORPAY_WEBHOOK_SECRET")
	if secret == "" {
		return errors.New("RAZORPAY_WEBHOOK_SECRET not set")
	}

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payloadBody)
	expectedSignature := hex.EncodeToString(mac.Sum(nil))

	if !hmac.Equal([]byte(expectedSignature), []byte(signature)) {
		return errors.New("invalid webhook signature")
	}

	return nil
}

// VerifyPaymentSignature verifies the signature returned by the frontend after a payment
func VerifyPaymentSignature(orderID, paymentID, signature string) error {
	secret := os.Getenv("RAZORPAY_KEY_SECRET")
	if secret == "" {
		return errors.New("RAZORPAY_KEY_SECRET not set")
	}

	payload := orderID + "|" + paymentID

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(payload))
	expectedSignature := hex.EncodeToString(mac.Sum(nil))

	if !hmac.Equal([]byte(expectedSignature), []byte(signature)) {
		return errors.New("invalid payment signature")
	}

	return nil
}

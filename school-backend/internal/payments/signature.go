package payments

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
)

// VerifyRazorpaySignature verifies the Razorpay payment signature
// This is used to verify that a payment callback from Razorpay is legitimate
func VerifyRazorpaySignature(orderID string, paymentID string, razorpaySignature string, secret string) bool {
	data := orderID + "|" + paymentID
	h := hmac.New(sha256.New, []byte(secret))
	h.Write([]byte(data))
	generatedSignature := hex.EncodeToString(h.Sum(nil))
	return hmac.Equal([]byte(generatedSignature), []byte(razorpaySignature))
}

// VerifyWebhookSignature verifies the webhook signature from Razorpay
func VerifyWebhookSignature(payload string, signature string, secret string) bool {
	h := hmac.New(sha256.New, []byte(secret))
	h.Write([]byte(payload))
	generatedSignature := hex.EncodeToString(h.Sum(nil))
	return hmac.Equal([]byte(generatedSignature), []byte(signature))
}

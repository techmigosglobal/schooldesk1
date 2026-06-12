package payments

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"

	razorpay "github.com/razorpay/razorpay-go"
)

var client *razorpay.Client

// InitRazorpayClient initializes the legacy package-level Razorpay client.
func InitRazorpayClient() error {
	keyID := os.Getenv("RAZORPAY_KEY_ID")
	keySecret := os.Getenv("RAZORPAY_KEY_SECRET")
	if keyID == "" || keySecret == "" {
		return errors.New("RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET must be set")
	}
	client = razorpay.NewClient(keyID, keySecret)
	return nil
}

// GetClient returns the package-level Razorpay client used by legacy fee routes.
func GetClient() *razorpay.Client {
	return client
}

// GetKeyID returns the public Razorpay key id.
func GetKeyID() string {
	return os.Getenv("RAZORPAY_KEY_ID")
}

// CreateOrderRequest describes a legacy Razorpay order request.
type CreateOrderRequest struct {
	Amount   float64
	Currency string
	Receipt  string
	Notes    map[string]interface{}
}

// CreateOrder creates a Razorpay order through the legacy package client.
func CreateOrder(req CreateOrderRequest) (map[string]interface{}, error) {
	if client == nil {
		if err := InitRazorpayClient(); err != nil {
			return nil, err
		}
	}
	amountInSubunits := int(req.Amount * 100)
	return client.Order.Create(map[string]interface{}{
		"amount":   amountInSubunits,
		"currency": req.Currency,
		"receipt":  req.Receipt,
		"notes":    req.Notes,
	}, nil)
}

// VerifyRazorpaySignature verifies the Razorpay payment signature
// This is used to verify that a payment callback from Razorpay is legitimate
func VerifyRazorpaySignature(orderID string, paymentID string, razorpaySignature string, secret string) bool {
	data := orderID + "|" + paymentID
	h := hmac.New(sha256.New, []byte(secret))
	h.Write([]byte(data))
	generatedSignature := hex.EncodeToString(h.Sum(nil))
	return hmac.Equal([]byte(generatedSignature), []byte(razorpaySignature))
}

// VerifyPaymentSignature validates a Razorpay payment callback using RAZORPAY_KEY_SECRET.
func VerifyPaymentSignature(orderID string, paymentID string, razorpaySignature string) error {
	secret := os.Getenv("RAZORPAY_KEY_SECRET")
	if secret == "" {
		return errors.New("RAZORPAY_KEY_SECRET must be set")
	}
	if !VerifyRazorpaySignature(orderID, paymentID, razorpaySignature, secret) {
		return errors.New("invalid payment signature")
	}
	return nil
}

// VerifyWebhookSignature verifies the webhook signature from Razorpay
func VerifyWebhookSignature(payload []byte, signature string) error {
	secret := os.Getenv("RAZORPAY_WEBHOOK_SECRET")
	if secret == "" {
		return errors.New("RAZORPAY_WEBHOOK_SECRET must be set")
	}
	if !verifyWebhookSignatureWithSecret(payload, signature, secret) {
		return errors.New("invalid webhook signature")
	}
	return nil
}

func verifyWebhookSignatureWithSecret(payload []byte, signature string, secret string) bool {
	h := hmac.New(sha256.New, []byte(secret))
	h.Write(payload)
	generatedSignature := hex.EncodeToString(h.Sum(nil))
	return hmac.Equal([]byte(generatedSignature), []byte(signature))
}

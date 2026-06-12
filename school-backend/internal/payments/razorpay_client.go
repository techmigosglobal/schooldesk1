package payments

import (
	"errors"
	"fmt"
	"os"

	razorpay "github.com/razorpay/razorpay-go"
)

var client *razorpay.Client

// InitRazorpayClient initializes the Razorpay client with the provided keys
func InitRazorpayClient() error {
	keyID := os.Getenv("RAZORPAY_KEY_ID")
	keySecret := os.Getenv("RAZORPAY_KEY_SECRET")

	if keyID == "" || keySecret == "" {
		return errors.New("RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET must be set")
	}

	client = razorpay.NewClient(keyID, keySecret)
	return nil
}

// GetClient returns the initialized Razorpay client
func GetClient() *razorpay.Client {
	return client
}

// GetKeyID returns the Razorpay public key ID (safe to expose to frontend).
func GetKeyID() string {
	return os.Getenv("RAZORPAY_KEY_ID")
}

// CreateOrder payload for razorpay order creation
type CreateOrderRequest struct {
	Amount   float64 // Amount in INR (e.g. 100.50)
	Currency string  // "INR"
	Receipt  string  // Internal receipt or reference id
	Notes    map[string]interface{}
}

// CreateOrder creates a new order in Razorpay
func CreateOrder(req CreateOrderRequest) (map[string]interface{}, error) {
	if client == nil {
		return nil, errors.New("razorpay client not initialized")
	}

	// Razorpay expects amount in the smallest subunit (e.g., paise for INR)
	amountInSubunits := int(req.Amount * 100)

	data := map[string]interface{}{
		"amount":   amountInSubunits,
		"currency": req.Currency,
		"receipt":  req.Receipt,
		"notes":    req.Notes,
	}

	body, err := client.Order.Create(data, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create razorpay order: %w", err)
	}

	return body, nil
}

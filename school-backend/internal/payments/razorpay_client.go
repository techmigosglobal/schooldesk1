package payments

import (
	"school-backend/internal/config"

	"github.com/razorpay/razorpay-go"
)

// RazorpayClient wraps the Razorpay API client
type RazorpayClient struct {
	client *razorpay.Client
	cfg    *config.Config
}

// NewRazorpayClient creates a new Razorpay client
func NewRazorpayClient(cfg *config.Config) *RazorpayClient {
	client := razorpay.NewClient(cfg.RazorpayKeyID, cfg.RazorpayKeySecret)
	return &RazorpayClient{
		client: client,
		cfg:    cfg,
	}
}

// CreateOrder creates a Razorpay order
func (rc *RazorpayClient) CreateOrder(amount int64, receiptNo string, notes map[string]interface{}) (map[string]interface{}, error) {
	params := map[string]interface{}{
		"amount":   amount, // in paise
		"currency": rc.cfg.RazorpayCurrency,
		"receipt":  receiptNo,
		"notes":    notes,
	}

	order, err := rc.client.Order.Create(params, map[string]string{})
	if err != nil {
		return nil, err
	}

	return order, nil
}

// FetchOrder fetches an order from Razorpay
func (rc *RazorpayClient) FetchOrder(orderID string) (map[string]interface{}, error) {
	order, err := rc.client.Order.Fetch(orderID, map[string]interface{}{}, map[string]string{})
	if err != nil {
		return nil, err
	}
	return order, nil
}

// FetchPayment fetches a payment from Razorpay
func (rc *RazorpayClient) FetchPayment(paymentID string) (map[string]interface{}, error) {
	payment, err := rc.client.Payment.Fetch(paymentID, map[string]interface{}{}, map[string]string{})
	if err != nil {
		return nil, err
	}
	return payment, nil
}

// CapturePayment captures a payment (for authorized payments)
func (rc *RazorpayClient) CapturePayment(paymentID string, amount int64) (map[string]interface{}, error) {
	params := map[string]interface{}{
		"amount": amount,
	}
	payment, err := rc.client.Payment.Capture(paymentID, int(amount), params, map[string]string{})
	if err != nil {
		return nil, err
	}
	return payment, nil
}

// RefundPayment initiates a refund for a payment
func (rc *RazorpayClient) RefundPayment(paymentID string, amount int64, notes map[string]interface{}) (map[string]interface{}, error) {
	params := map[string]interface{}{
		"notes": notes,
	}

	refund, err := rc.client.Payment.Refund(paymentID, int(amount), params, map[string]string{})
	if err != nil {
		return nil, err
	}
	return refund, nil
}

// GetWebhookSignature returns the webhook secret for signature verification
func (rc *RazorpayClient) GetWebhookSignature() string {
	return rc.cfg.RazorpayWebhookSecret
}

// GetKeyID returns the public key ID
func (rc *RazorpayClient) GetKeyID() string {
	return rc.cfg.RazorpayKeyID
}

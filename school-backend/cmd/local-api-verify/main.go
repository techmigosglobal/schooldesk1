package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"html"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type config struct {
	baseURL   string
	healthURL string
	mode      string
	delay     time.Duration
}

type report struct {
	GeneratedAt string        `json:"generated_at"`
	Target      string        `json:"target"`
	Mode        string        `json:"mode"`
	Total       int           `json:"total_tests"`
	Passed      int           `json:"passed"`
	Warnings    int           `json:"warnings"`
	Failed      int           `json:"failed"`
	SuccessPct  float64       `json:"success_percent"`
	Tests       []reportEntry `json:"tests"`
}

type reportEntry struct {
	Name               string `json:"test_name"`
	Endpoint           string `json:"endpoint"`
	Role               string `json:"role"`
	Status             string `json:"status"`
	ExpectedStatusCode string `json:"expected_status_code"`
	StatusCode         int    `json:"status_code"`
	ResponseTime       string `json:"response_time"`
	Notes              string `json:"notes,omitempty"`
	Error              string `json:"error_message,omitempty"`
	ResponseBody       string `json:"response_body,omitempty"`
}

type verifier struct {
	client    *http.Client
	baseURL   string
	healthURL string
	mode      string
	delay     time.Duration
	suffix    string
	counter   int
	tokens    map[string]string
	ids       map[string]string
	rows      []reportEntry
}

func main() {
	cfg := loadConfig()
	if err := requireLocalURL(cfg.baseURL); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(64)
	}
	if err := requireLocalURL(cfg.healthURL); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(64)
	}

	v := &verifier{
		client:    &http.Client{Timeout: 15 * time.Second},
		baseURL:   strings.TrimRight(cfg.baseURL, "/"),
		healthURL: cfg.healthURL,
		mode:      cfg.mode,
		delay:     cfg.delay,
		suffix:    "qa" + strconv.FormatInt(time.Now().Unix(), 10),
		tokens:    map[string]string{},
		ids:       map[string]string{},
	}
	v.run()

	rep := v.buildReport()
	if err := writeReports(rep); err != nil {
		fmt.Fprintln(os.Stderr, "write reports:", err)
		os.Exit(1)
	}
	fmt.Printf("Local Docker API verification: %d total, %d passed, %d warnings, %d failed\n", rep.Total, rep.Passed, rep.Warnings, rep.Failed)
	fmt.Println("Reports: school-backend/test-report/local-docker-api-report.json and .html")
	if rep.Failed > 0 {
		os.Exit(1)
	}
}

func loadConfig() config {
	delayMS := envInt("RATE_LIMIT_DELAY_MS", 350)
	mode := strings.ToLower(strings.TrimSpace(envOr("VERIFY_MODE", "safe")))
	if mode != "safe" && mode != "mutating" {
		mode = "safe"
	}
	return config{
		baseURL:   envOr("API_BASE_URL", "http://127.0.0.1:8080/api/v1"),
		healthURL: envOr("HEALTH_URL", "http://127.0.0.1:8080/health"),
		mode:      mode,
		delay:     time.Duration(delayMS) * time.Millisecond,
	}
}

func requireLocalURL(raw string) error {
	parsed, err := url.Parse(raw)
	if err != nil {
		return fmt.Errorf("invalid URL %q: %w", raw, err)
	}
	host := parsed.Hostname()
	switch strings.ToLower(host) {
	case "127.0.0.1", "localhost", "go-api", "schooldesk-go-api":
		return nil
	default:
		return fmt.Errorf("refusing non-local API target %q; this verifier is local-Docker only", raw)
	}
}

func envOr(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}

func envInt(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 0 {
		return fallback
	}
	return parsed
}

func (v *verifier) run() {
	v.waitForHealth()

	principalIdentity := envOr("QA_PRINCIPAL_USERNAME", envOr("QA_PRINCIPAL_EMAIL", "principal@schooldesk.local"))
	principalPassword := envOr("QA_PRINCIPAL_PASSWORD", "Principal@12345")
	if !v.login("Principal", principalIdentity, principalPassword, http.StatusOK) {
		v.addFail("Principal session is required", "local verifier", "Principal", "Cannot continue without a Principal token")
		return
	}
	v.expect("Principal profile restore", http.MethodGet, "/auth/profile", "Principal", "Principal", nil, http.StatusOK)
	v.expect("Principal current school profile", http.MethodGet, "/schools/current", "Principal", "Principal", nil, http.StatusOK)
	v.expect("Principal dashboard", http.MethodGet, "/dashboard/principal", "Principal", "Principal", nil, http.StatusOK)
	v.expect("Principal registers notification device token", http.MethodPost, "/notifications/device-tokens", "Principal", "Principal", map[string]any{
		"token":       "local-verifier-" + v.suffix,
		"platform":    "android",
		"device_id":   "local-verifier",
		"app_version": "verification",
	}, http.StatusOK)
	v.expect("Principal revokes notification device token", http.MethodDelete, "/notifications/device-tokens", "Principal", "Principal", map[string]any{
		"token": "local-verifier-" + v.suffix,
	}, http.StatusOK)

	if v.mode == "mutating" {
		v.runMutating()
		return
	}
	v.runSafe()
}

func (v *verifier) waitForHealth() {
	deadline := time.Now().Add(30 * time.Second)
	for time.Now().Before(deadline) {
		start := time.Now()
		resp, err := v.client.Get(v.healthURL)
		elapsed := time.Since(start)
		if err == nil {
			_, _ = io.Copy(io.Discard, resp.Body)
			_ = resp.Body.Close()
			entry := reportEntry{
				Name:               "Local Docker health",
				Endpoint:           "GET " + v.healthURL,
				Role:               "Anonymous",
				ExpectedStatusCode: "200",
				StatusCode:         resp.StatusCode,
				ResponseTime:       elapsed.String(),
			}
			if resp.StatusCode == http.StatusOK {
				entry.Status = "PASS"
				v.rows = append(v.rows, entry)
				return
			}
		}
		time.Sleep(500 * time.Millisecond)
	}
	v.addFail("Local Docker health", "GET "+v.healthURL, "Anonymous", "Health endpoint did not return HTTP 200 within 30s")
}

func (v *verifier) runSafe() {
	v.expect("Anonymous protected route is rejected", http.MethodGet, "/students", "", "Anonymous", nil, http.StatusUnauthorized)
	v.expect("Principal can list users", http.MethodGet, "/users?page_size=5", "Principal", "Principal", nil, http.StatusOK)

	roleCredentials := []struct {
		role     string
		userKey  string
		passKey  string
		dashPath string
	}{
		{"Teacher", "QA_TEACHER_USERNAME", "QA_TEACHER_PASSWORD", "/dashboard/teacher"},
		{"Parent", "QA_PARENT_USERNAME", "QA_PARENT_PASSWORD", "/dashboard/parent"},
	}
	for _, item := range roleCredentials {
		identity := strings.TrimSpace(os.Getenv(item.userKey))
		password := strings.TrimSpace(os.Getenv(item.passKey))
		if identity == "" || password == "" {
			v.addWarn("Safe mode "+item.role+" credentials missing", "env "+item.userKey, item.role, "Provide credentials or run VERIFY_MODE=mutating against local Docker")
			continue
		}
		if v.login(item.role, identity, password, http.StatusOK) {
			v.expect(item.role+" dashboard", http.MethodGet, item.dashPath, item.role, item.role, nil, http.StatusOK)
		}
	}
	v.runNegativeAndGapChecks()
}

func (v *verifier) runMutating() {
	teacherEmail := v.suffix + "_teacher@schooldesk.local"
	teacherPass := "Teacher@" + v.suffix + "!"
	parentUser := v.suffix + "_parent"
	parentEmail := v.suffix + "_parent@schooldesk.local"
	parentPass := "Parent@" + v.suffix + "!"

	v.expectDataID("Principal creates Teacher staff login", http.MethodPost, "/staff", "Principal", "Principal", map[string]any{
		"staff_code":      strings.ToUpper(v.suffix) + "-TCH",
		"username":        v.suffix + "_teacher_staff",
		"first_name":      "QA",
		"last_name":       "Teacher " + v.suffix,
		"email":           teacherEmail,
		"password":        teacherPass,
		"account_role":    "Teacher",
		"designation":     "Teacher",
		"gender":          "unspecified",
		"employment_type": "full_time",
		"join_date":       "2026-01-01",
		"date_of_birth":   "1990-01-01",
	}, http.StatusCreated, "teacher_staff")
	v.login("Teacher", teacherEmail, teacherPass, http.StatusOK)

	v.expectDataID("Principal creates Parent login", http.MethodPost, "/users", "Principal", "Principal", map[string]any{
		"name":     "QA Parent " + v.suffix,
		"username": parentUser,
		"email":    parentEmail,
		"password": parentPass,
		"role":     "Parent",
	}, http.StatusCreated, "parent_user")
	v.login("Parent", parentUser, parentPass, http.StatusOK)
	v.runParentPaymentRequestFlow()
	v.runPrincipalManualPaymentFlow()
	v.runFeeStructureDeletePropagationFlow()
	v.runAttendanceFlow()
	v.runStudentLeaveFlow()
	v.runTeacherHomeworkFlow()
	v.runReportExportFlow()
	v.runParentCalendarReadFlow()

	v.expect("Teacher dashboard", http.MethodGet, "/dashboard/teacher", "Teacher", "Teacher", nil, http.StatusOK)
	v.expect("Parent dashboard", http.MethodGet, "/dashboard/parent", "Parent", "Parent", nil, http.StatusOK)
	v.expect("Principal can list staff", http.MethodGet, "/staff?page_size=20", "Principal", "Principal", nil, http.StatusOK)

	v.expect("Principal can list academic years", http.MethodGet, "/academic-years?page_size=20", "Principal", "Principal", nil, http.StatusOK)
	v.expect("Principal can list grades", http.MethodGet, "/grades?page_size=20", "Principal", "Principal", nil, http.StatusOK)
	v.expect("Principal can list sections", http.MethodGet, "/sections?page_size=20", "Principal", "Principal", nil, http.StatusOK)
	v.expect("Principal can list timetable slots", http.MethodGet, "/timetable/slots?page_size=20", "Principal", "Principal", nil, http.StatusOK)
	v.expect("Principal can list events", http.MethodGet, "/events?page_size=20", "Principal", "Principal", nil, http.StatusOK)
	v.expect("Principal can list fee invoices", http.MethodGet, "/fees/invoices?page_size=20", "Principal", "Principal", nil, http.StatusOK)
	v.expect("Parent can read linked students", http.MethodGet, "/me/students", "Parent", "Parent", nil, http.StatusOK)

	v.runNegativeAndGapChecks()
}

func (v *verifier) runNegativeAndGapChecks() {
	v.expect("Anonymous protected route is rejected", http.MethodGet, "/students", "", "Anonymous", nil, http.StatusUnauthorized)
	if v.tokens["Parent"] != "" {
		v.expect("Parent forbidden from Principal dashboard", http.MethodGet, "/dashboard/principal", "Parent", "Parent", nil, http.StatusForbidden)
		v.expect("Parent forbidden from direct payment settlement", http.MethodPost, "/fees/payments", "Parent", "Parent", map[string]any{
			"invoice_id":     "local-verifier-placeholder",
			"receipt_number": "LOCAL-VERIFY",
			"amount_paid":    1,
			"payment_date":   "2026-05-16",
			"payment_mode":   "upi",
		}, http.StatusForbidden)
		v.expect("Parent cannot submit leave for an unlinked student", http.MethodPost, "/student-leave/applications", "Parent", "Parent", map[string]any{
			"student_id": "local-verifier-placeholder",
			"leave_type": "Sick Leave",
			"from_date":  "2026-05-16",
			"to_date":    "2026-05-16",
			"reason":     "Local Docker verifier negative check",
		}, http.StatusForbidden)
	}
	if v.tokens["Teacher"] != "" {
		v.expect("Teacher forbidden from user administration", http.MethodGet, "/users?page_size=5", "Teacher", "Teacher", nil, http.StatusForbidden)
	}
}

func (v *verifier) runParentPaymentRequestFlow() {
	if v.tokens["Principal"] == "" || v.tokens["Parent"] == "" || v.ids["parent_user"] == "" {
		v.addFail("Parent payment request fixture", "local verifier", "Principal/Parent", "Principal token, Parent token, or Parent ID missing")
		return
	}
	v.loadAcademicFixtureIDs()
	admissionNumber := strings.ToUpper(v.suffix) + "-FEE"
	v.expectDataID("Principal creates fee category for Parent payment", http.MethodPost, "/fees/categories", "Principal", "Principal", map[string]any{
		"category_name": "Local Verification Tuition " + v.suffix,
		"frequency":     "one_time",
	}, http.StatusCreated, "fee_category")
	v.expectDataID("Principal creates student for Parent payment", http.MethodPost, "/students", "Principal", "Principal", map[string]any{
		"first_name":         "Fee",
		"last_name":          "Child " + v.suffix,
		"date_of_birth":      "2015-01-01",
		"gender":             "female",
		"admission_number":   admissionNumber,
		"student_code":       admissionNumber,
		"current_section_id": v.ids["default_section"],
	}, http.StatusCreated, "payment_student")
	if v.ids["payment_student"] == "" || v.ids["fee_category"] == "" {
		return
	}
	v.expect("Principal links Parent to fee student", http.MethodPost, "/parents/"+v.ids["parent_user"]+"/students", "Principal", "Principal", map[string]any{
		"admission_numbers": []string{admissionNumber},
	}, http.StatusOK)
	v.expectDataID("Principal creates invoice for Parent payment", http.MethodPost, "/fees/invoices", "Principal", "Principal", map[string]any{
		"student_id":       v.ids["payment_student"],
		"academic_year_id": "academic-year-default",
		"invoice_number":   "INV-" + strings.ToUpper(v.suffix),
		"invoice_date":     "2026-05-16",
		"due_date":         "2026-05-30",
		"total_amount":     500,
		"discount_amount":  0,
		"net_amount":       500,
		"items": []map[string]any{{
			"fee_category_id": v.ids["fee_category"],
			"amount":          500,
			"description":     "Local verification fee",
		}},
	}, http.StatusCreated, "payment_invoice")
	if v.ids["payment_invoice"] == "" {
		return
	}
	v.expect("Principal updates parent payment QR config", http.MethodPut, "/fees/payment-config", "Principal", "Principal", map[string]any{
		"upi_id":       "schooldesk-local@upi",
		"payee_name":   "SchoolDesk Local Verification",
		"qr_note":      "Verifier payment " + v.suffix,
		"qr_image_url": "/uploads/payment_proofs/local-verifier/qr-" + v.suffix + ".png",
	}, http.StatusOK)
	_, paymentConfig := v.expectAny("Parent reads configured payment QR", http.MethodGet, "/fees/payment-config?invoice_id="+v.ids["payment_invoice"], "Parent", "Parent", nil, http.StatusOK)
	if upiID, ok := getString(paymentConfig, "upi_id"); !ok || !strings.Contains(upiID, "@upi") {
		v.addFail("Parent reads configured payment QR content", "GET /fees/payment-config", "Parent", "UPI ID missing from payment config response")
		return
	}
	if qrImage, ok := getString(paymentConfig, "qr_image_url"); !ok || !strings.Contains(qrImage, "/uploads/") {
		v.addFail("Parent reads configured payment QR image", "GET /fees/payment-config", "Parent", "QR image URL missing from payment config response")
		return
	}
	if updatedAt, ok := getString(paymentConfig, "updated_at"); !ok {
		v.addFail("Parent reads configured payment QR freshness", "GET /fees/payment-config", "Parent", "updated_at missing from payment config response")
		return
	} else if strings.TrimSpace(updatedAt) == "" || strings.HasPrefix(updatedAt, "0001-01-01") {
		v.addFail("Parent reads configured payment QR freshness", "GET /fees/payment-config", "Parent", "updated_at did not reflect a real QR/config update")
		return
	}

	v.expect("Parent reads linked fee invoice", http.MethodGet, "/fees/invoices?student_id="+v.ids["payment_student"], "Parent", "Parent", nil, http.StatusOK)
	_, parentFeesBefore := v.expectAny("Parent reads fee status before payment proof", http.MethodGet, "/parent/students/"+v.ids["payment_student"]+"/fees", "Parent", "Parent", nil, http.StatusOK)
	if findRowString(parentFeesBefore, v.ids["payment_invoice"], "request_status") != "" {
		v.addFail("Parent fee status before payment proof", "GET /parent/students/:studentId/fees", "Parent", "Expected no live request status before creating a payment intent")
		return
	}

	v.expectDataID("Parent creates payment intent", http.MethodPost, "/fees/payments/intent", "Parent", "Parent", map[string]any{
		"invoice_id":      v.ids["payment_invoice"],
		"payment_method":  "upi",
		"selected_months": 0,
		"selected_terms":  0,
		"remarks":         "Local verifier proof workflow",
	}, http.StatusCreated, "payment_request")
	if v.ids["payment_request"] == "" {
		return
	}
	intentReference := ""
	if _, intentData := v.expectAny("Parent fetches payment intent details", http.MethodGet, "/fees/payment-requests?invoice_id="+v.ids["payment_invoice"], "Parent", "Parent", nil, http.StatusOK); intentData != nil {
		if rows, ok := asList(intentData); ok && len(rows) > 0 {
			intentReference = strings.TrimSpace(fmt.Sprint(rows[0]["request_reference"]))
		}
	}
	if intentReference == "" {
		v.addFail("Parent payment intent reference", "GET /fees/payment-requests", "Parent", "Payment intent reference missing")
		return
	}

	v.expectMultipartDataID("Parent submits payment proof", http.MethodPost, "/fees/payments/submit", "Parent", "Parent", map[string]string{
		"payment_request_id": v.ids["payment_request"],
		"request_reference":  intentReference,
		"student_fee_id":     v.ids["payment_invoice"],
		"amount":             "500.00",
		"payment_method":     "upi",
		"transaction_ref":    "LOCAL-" + strings.ToUpper(v.suffix),
		"remarks":            "Initial proof from local verifier",
	}, "screenshot", "payment-proof.png", []byte("png"), http.StatusCreated, "payment_request")

	_, parentFeesPending := v.expectAny("Parent sees pending verification fee status", http.MethodGet, "/parent/students/"+v.ids["payment_student"]+"/fees", "Parent", "Parent", nil, http.StatusOK)
	if findRowString(parentFeesPending, v.ids["payment_invoice"], "request_status") != "pending_verification" {
		v.addFail("Parent sees pending verification fee status content", "GET /parent/students/:studentId/fees", "Parent", "Expected request_status=pending_verification after proof submit")
		return
	}
	v.expect("Principal lists payment requests for review", http.MethodGet, "/fees/payment-requests?status=pending_verification", "Principal", "Principal", nil, http.StatusOK)
	v.expect("Principal requests clarification for parent payment proof", http.MethodPut, "/fees/payment-requests/"+v.ids["payment_request"]+"/decision", "Principal", "Principal", map[string]any{
		"status":        "clarification_required",
		"admin_remarks": "Please upload a clearer screenshot",
	}, http.StatusOK)
	_, parentHistoryClarify := v.expectAny("Parent sees clarification-required request history", http.MethodGet, "/fees/payments/history?student_id="+v.ids["payment_student"], "Parent", "Parent", nil, http.StatusOK)
	if !listContainsStatus(parentHistoryClarify, "clarification_required") {
		v.addFail("Parent sees clarification-required request history content", "GET /fees/payments/history", "Parent", "Expected clarification_required entry after principal decision")
		return
	}

	v.expectMultipart("Parent resubmits payment proof after clarification", http.MethodPatch, "/fees/payments/"+v.ids["payment_request"]+"/resubmit", "Parent", "Parent", map[string]string{
		"transaction_ref": "LOCAL-RESUBMIT-" + strings.ToUpper(v.suffix),
		"remarks":         "Resubmitted proof from local verifier",
	}, "screenshot", "payment-proof-fixed.png", []byte("png-fixed"), http.StatusOK)
	v.expect("Principal approves parent payment request", http.MethodPut, "/fees/payment-requests/"+v.ids["payment_request"]+"/decision", "Principal", "Principal", map[string]any{
		"status":        "approved",
		"admin_remarks": "Verified by local Docker API verifier",
	}, http.StatusOK)

	_, parentFeesApproved := v.expectAny("Parent sees fee cleared after approval", http.MethodGet, "/parent/students/"+v.ids["payment_student"]+"/fees", "Parent", "Parent", nil, http.StatusOK)
	if findRowString(parentFeesApproved, v.ids["payment_invoice"], "status") != "paid" {
		v.addFail("Parent sees fee cleared after approval content", "GET /parent/students/:studentId/fees", "Parent", "Expected invoice status=paid after approval")
		return
	}
	_, parentDashboard := v.expectAny("Parent dashboard reflects approved fee", http.MethodGet, "/dashboard/parent", "Parent", "Parent", nil, http.StatusOK)
	if pendingBalance := nestedString(parentDashboard, "metrics", "pending_fee_balance"); pendingBalance != "0" && pendingBalance != "0.0" && pendingBalance != "0.00" {
		v.addFail("Parent dashboard reflects approved fee content", "GET /dashboard/parent", "Parent", "Expected pending_fee_balance to be cleared after approval, got "+pendingBalance)
		return
	}
}

func (v *verifier) runPrincipalManualPaymentFlow() {
	if v.tokens["Principal"] == "" || v.tokens["Parent"] == "" || v.ids["payment_student"] == "" || v.ids["fee_category"] == "" {
		v.addFail("Principal manual payment fixture", "local verifier", "Principal/Parent", "Missing payment fixture IDs for manual payment flow")
		return
	}

	v.expectDataID("Principal creates manual-update invoice", http.MethodPost, "/fees/invoices", "Principal", "Principal", map[string]any{
		"student_id":       v.ids["payment_student"],
		"academic_year_id": "academic-year-default",
		"invoice_number":   "INV-MANUAL-" + strings.ToUpper(v.suffix),
		"invoice_date":     "2026-06-01",
		"due_date":         "2026-06-10",
		"total_amount":     300,
		"discount_amount":  0,
		"net_amount":       300,
		"items": []map[string]any{{
			"fee_category_id": v.ids["fee_category"],
			"amount":          300,
			"description":     "Manual cash carry-over fee",
		}},
	}, http.StatusCreated, "manual_payment_invoice")
	if v.ids["manual_payment_invoice"] == "" {
		return
	}

	_, parentFeesBefore := v.expectAny("Parent sees manual-update invoice before principal settlement", http.MethodGet, "/parent/students/"+v.ids["payment_student"]+"/fees", "Parent", "Parent", nil, http.StatusOK)
	if findRowString(parentFeesBefore, v.ids["manual_payment_invoice"], "status") == "" {
		v.addFail("Parent sees manual-update invoice before principal settlement content", "GET /parent/students/:studentId/fees", "Parent", "Expected unpaid invoice to be visible before manual settlement")
		return
	}

	v.expect("Principal records offline manual fee payment with optional fields omitted", http.MethodPost, "/fees/payments", "Principal", "Principal", map[string]any{
		"invoice_id":     v.ids["manual_payment_invoice"],
		"receipt_number": "RCPT-MANUAL-" + strings.ToUpper(v.suffix),
		"amount_paid":    300,
		"payment_date":   "2026-06-11",
		"payment_mode":   "cash",
	}, http.StatusOK)

	_, parentFeesAfter := v.expectAny("Parent sees manual payment reflected in fee status", http.MethodGet, "/parent/students/"+v.ids["payment_student"]+"/fees", "Parent", "Parent", nil, http.StatusOK)
	if findRowString(parentFeesAfter, v.ids["manual_payment_invoice"], "status") != "paid" {
		v.addFail("Parent sees manual payment reflected in fee status content", "GET /parent/students/:studentId/fees", "Parent", "Expected manual-settled invoice status=paid")
		return
	}

	_, parentDashboard := v.expectAny("Parent dashboard reflects manual fee update", http.MethodGet, "/dashboard/parent", "Parent", "Parent", nil, http.StatusOK)
	if pendingBalance := nestedString(parentDashboard, "metrics", "pending_fee_balance"); pendingBalance != "0" && pendingBalance != "0.0" && pendingBalance != "0.00" {
		v.addFail("Parent dashboard reflects manual fee update content", "GET /dashboard/parent", "Parent", "Expected pending_fee_balance to be cleared after manual payment, got "+pendingBalance)
		return
	}

	_, parentInvoices := v.expectAny("Parent invoice history includes manual cash payment", http.MethodGet, "/fees/invoices?student_id="+v.ids["payment_student"], "Parent", "Parent", nil, http.StatusOK)
	if !invoiceHasPaymentMode(parentInvoices, v.ids["manual_payment_invoice"], "cash") {
		v.addFail("Parent invoice history includes manual cash payment content", "GET /fees/invoices", "Parent", "Expected manual invoice payments list to include cash payment")
		return
	}
}

func (v *verifier) runFeeStructureDeletePropagationFlow() {
	if v.tokens["Principal"] == "" || v.tokens["Parent"] == "" || v.ids["payment_student"] == "" || v.ids["default_year"] == "" || v.ids["default_grade"] == "" || v.ids["default_section"] == "" {
		v.addFail("Fee structure delete propagation fixture", "local verifier", "Principal/Parent", "Missing fixture IDs for delete propagation flow")
		return
	}

	v.expectDataID("Principal creates fee category for delete propagation", http.MethodPost, "/fees/categories", "Principal", "Principal", map[string]any{
		"category_name": "Delete Propagation Fee " + v.suffix,
		"frequency":     "one_time",
	}, http.StatusCreated, "delete_fee_category")
	if v.ids["delete_fee_category"] == "" {
		return
	}
	v.expectDataID("Principal creates fee structure for delete propagation", http.MethodPost, "/fees/structures", "Principal", "Principal", map[string]any{
		"academic_year_id":  v.ids["default_year"],
		"grade_id":          v.ids["default_grade"],
		"section_id":        v.ids["default_section"],
		"fee_category_id":   v.ids["delete_fee_category"],
		"amount":            275,
		"due_day":           12,
		"late_fine_per_day": 0,
	}, http.StatusCreated, "delete_fee_structure")
	if v.ids["delete_fee_structure"] == "" {
		return
	}
	v.expectDataID("Principal creates unpaid invoice for delete propagation", http.MethodPost, "/fees/invoices", "Principal", "Principal", map[string]any{
		"student_id":       v.ids["payment_student"],
		"academic_year_id": v.ids["default_year"],
		"invoice_number":   "INV-DELETE-" + strings.ToUpper(v.suffix),
		"invoice_date":     "2026-07-01",
		"due_date":         "2026-07-12",
		"total_amount":     275,
		"discount_amount":  0,
		"net_amount":       275,
		"items": []map[string]any{{
			"fee_category_id": v.ids["delete_fee_category"],
			"amount":          275,
			"description":     "Delete propagation fee",
		}},
	}, http.StatusCreated, "delete_fee_invoice")
	if v.ids["delete_fee_invoice"] == "" {
		return
	}

	_, parentFeesBefore := v.expectAny("Parent sees delete-target fee before structure removal", http.MethodGet, "/parent/students/"+v.ids["payment_student"]+"/fees", "Parent", "Parent", nil, http.StatusOK)
	if findRowString(parentFeesBefore, v.ids["delete_fee_invoice"], "status") == "" {
		v.addFail("Parent sees delete-target fee before structure removal content", "GET /parent/students/:studentId/fees", "Parent", "Expected delete-target invoice to be visible before fee structure removal")
		return
	}
	_, parentStudentsBefore := v.expectAny("Parent linked students show delete-target fee before structure removal", http.MethodGet, "/me/students?refresh_nonce="+strconv.FormatInt(time.Now().UnixNano(), 10), "Parent", "Parent", nil, http.StatusOK)
	beforeStudentBalance := studentFeeBalance(parentStudentsBefore, v.ids["payment_student"])
	_, parentDashboardBefore := v.expectAny("Parent dashboard child summary shows delete-target fee before structure removal", http.MethodGet, "/dashboard/parent?refresh_nonce="+strconv.FormatInt(time.Now().UnixNano(), 10), "Parent", "Parent", nil, http.StatusOK)
	beforeDashboardBalance := dashboardChildFeeBalance(parentDashboardBefore, v.ids["payment_student"])
	_, principalClassesBefore := v.expectAny("Principal class overview shows delete-target fee before structure removal", http.MethodGet, "/principal/classes?refresh_nonce="+strconv.FormatInt(time.Now().UnixNano(), 10), "Principal", "Principal", nil, http.StatusOK)
	beforeClassBalance := classFeeBalance(principalClassesBefore, v.ids["default_section"])

	v.expectDataID("Parent creates payment intent for delete-target fee", http.MethodPost, "/fees/payments/intent", "Parent", "Parent", map[string]any{
		"invoice_id":      v.ids["delete_fee_invoice"],
		"payment_method":  "upi",
		"selected_months": 0,
		"selected_terms":  0,
		"remarks":         "Delete propagation pending request",
	}, http.StatusCreated, "delete_fee_request")
	if v.ids["delete_fee_request"] == "" {
		return
	}

	v.expect("Principal deletes fee structure and clears unpaid propagation targets", http.MethodDelete, "/fees/structures/"+v.ids["delete_fee_structure"]+"?remove_pending=true", "Principal", "Principal", nil, http.StatusOK)

	_, parentFeesAfter := v.expectAny("Parent fee list clears deleted structure invoice", http.MethodGet, "/parent/students/"+v.ids["payment_student"]+"/fees", "Parent", "Parent", nil, http.StatusOK)
	if findRowString(parentFeesAfter, v.ids["delete_fee_invoice"], "status") != "" {
		v.addFail("Parent fee list clears deleted structure invoice content", "GET /parent/students/:studentId/fees", "Parent", "Expected deleted structure invoice to be removed from parent fee list")
		return
	}

	_, principalInvoices := v.expectAny("Principal invoice list clears deleted structure invoice", http.MethodGet, "/fees/invoices?student_id="+v.ids["payment_student"], "Principal", "Principal", nil, http.StatusOK)
	if invoiceExists(principalInvoices, v.ids["delete_fee_invoice"]) {
		v.addFail("Principal invoice list clears deleted structure invoice content", "GET /fees/invoices", "Principal", "Expected deleted structure invoice to be removed from principal invoice list")
		return
	}
	_, parentStudentsAfter := v.expectAny("Parent linked students clear deleted structure balance", http.MethodGet, "/me/students?refresh_nonce="+strconv.FormatInt(time.Now().UnixNano(), 10), "Parent", "Parent", nil, http.StatusOK)
	afterStudentBalance := studentFeeBalance(parentStudentsAfter, v.ids["payment_student"])
	if beforeStudentBalance-afterStudentBalance < 274.99 {
		v.addFail("Parent linked students clear deleted structure balance content", "GET /me/students", "Parent", fmt.Sprintf("Expected fee_summary.balance to drop by about 275.00, before=%.2f after=%.2f", beforeStudentBalance, afterStudentBalance))
		return
	}
	_, parentDashboardAfter := v.expectAny("Parent dashboard child summary clears deleted structure balance", http.MethodGet, "/dashboard/parent?refresh_nonce="+strconv.FormatInt(time.Now().UnixNano(), 10), "Parent", "Parent", nil, http.StatusOK)
	afterDashboardBalance := dashboardChildFeeBalance(parentDashboardAfter, v.ids["payment_student"])
	if beforeDashboardBalance-afterDashboardBalance < 274.99 {
		v.addFail("Parent dashboard child summary clears deleted structure balance content", "GET /dashboard/parent", "Parent", fmt.Sprintf("Expected child pending_fee_balance to drop by about 275.00, before=%.2f after=%.2f", beforeDashboardBalance, afterDashboardBalance))
		return
	}
	_, principalClassesAfter := v.expectAny("Principal class overview clears deleted structure dues", http.MethodGet, "/principal/classes?refresh_nonce="+strconv.FormatInt(time.Now().UnixNano(), 10), "Principal", "Principal", nil, http.StatusOK)
	afterClassBalance := classFeeBalance(principalClassesAfter, v.ids["default_section"])
	if beforeClassBalance-afterClassBalance < 274.99 {
		v.addFail("Principal class overview clears deleted structure dues content", "GET /principal/classes", "Principal", fmt.Sprintf("Expected fees_due_amount to drop by about 275.00, before=%.2f after=%.2f", beforeClassBalance, afterClassBalance))
		return
	}

	_, parentRequests := v.expectAny("Parent payment requests clear deleted structure request", http.MethodGet, "/fees/payment-requests?invoice_id="+v.ids["delete_fee_invoice"], "Parent", "Parent", nil, http.StatusOK)
	if invoiceExists(parentRequests, v.ids["delete_fee_request"]) {
		v.addFail("Parent payment requests clear deleted structure request content", "GET /fees/payment-requests", "Parent", "Expected delete-target payment request to be removed after structure delete")
		return
	}
}

func (v *verifier) loadAcademicFixtureIDs() bool {
	if v.ids["default_section"] != "" && v.ids["default_year"] != "" && v.ids["default_term"] != "" && v.ids["default_subject"] != "" {
		return true
	}
	if v.tokens["Principal"] == "" {
		v.addFail("Academic fixture lookup", "local verifier", "Principal", "Principal token missing")
		return false
	}
	if v.ids["default_section"] == "" {
		_, sections := v.expectAny("Principal loads section for homework fixture", http.MethodGet, "/sections?page_size=1", "Principal", "Principal", nil, http.StatusOK)
		v.ids["default_section"] = firstID(sections)
		v.ids["default_grade"] = firstString(sections, "grade_id")
	}
	if v.ids["default_year"] == "" {
		_, years := v.expectAny("Principal loads academic year for homework fixture", http.MethodGet, "/academic-years?page_size=1", "Principal", "Principal", nil, http.StatusOK)
		v.ids["default_year"] = firstID(years)
	}
	if v.ids["default_subject"] == "" {
		_, subjects := v.expectAny("Principal loads subject for homework fixture", http.MethodGet, "/subjects?page_size=1", "Principal", "Principal", nil, http.StatusOK)
		v.ids["default_subject"] = firstID(subjects)
	}
	if v.ids["default_term"] == "" && v.ids["default_year"] != "" {
		_, terms := v.expectAny("Principal loads term for homework fixture", http.MethodGet, "/academic-years/"+v.ids["default_year"]+"/terms?page_size=1", "Principal", "Principal", nil, http.StatusOK)
		v.ids["default_term"] = firstID(terms)
	}
	missing := []string{}
	for _, key := range []string{"default_section", "default_year", "default_term", "default_subject"} {
		if v.ids[key] == "" {
			missing = append(missing, key)
		}
	}
	if len(missing) > 0 {
		v.addFail("Academic fixture lookup", "local verifier", "Principal", "Missing "+strings.Join(missing, ", "))
		return false
	}
	return true
}

func (v *verifier) ensureTeacherSubjectAssignment() bool {
	if v.ids["teacher_subject"] != "" {
		return true
	}
	if v.tokens["Principal"] == "" || v.ids["teacher_staff"] == "" {
		v.addFail("Teacher subject assignment fixture", "local verifier", "Principal", "Principal token or teacher staff ID missing")
		return false
	}
	if !v.loadAcademicFixtureIDs() {
		return false
	}
	if v.ids["grade_subject"] == "" {
		v.expectDataID("Principal maps default subject to attendance grade", http.MethodPost, "/grade-subjects", "Principal", "Principal", map[string]any{
			"academic_year_id": v.ids["default_year"],
			"grade_id":         v.ids["default_grade"],
			"subject_id":       v.ids["default_subject"],
			"is_mandatory":     true,
		}, http.StatusCreated, "grade_subject")
		if v.ids["grade_subject"] == "" {
			return false
		}
	}
	v.expectDataID("Principal maps Teacher to default class subject", http.MethodPost, "/staff-subjects", "Principal", "Principal", map[string]any{
		"academic_year_id": v.ids["default_year"],
		"staff_id":         v.ids["teacher_staff"],
		"subject_id":       v.ids["default_subject"],
		"grade_id":         v.ids["default_grade"],
		"section_id":       v.ids["default_section"],
		"is_primary":       true,
	}, http.StatusCreated, "teacher_subject")
	return v.ids["teacher_subject"] != ""
}

func (v *verifier) runAttendanceFlow() {
	if v.tokens["Principal"] == "" || v.tokens["Teacher"] == "" || v.tokens["Parent"] == "" || v.ids["teacher_staff"] == "" || v.ids["payment_student"] == "" {
		v.addFail("Attendance fixture", "local verifier", "All roles", "Principal, Teacher, Parent, teacher staff, or linked student missing")
		return
	}
	if !v.ensureTeacherSubjectAssignment() {
		return
	}
	v.expect("Principal assigns Teacher as class teacher for attendance", http.MethodPut, "/sections/"+v.ids["default_section"], "Principal", "Principal", map[string]any{
		"grade_id":         v.ids["default_grade"],
		"academic_year_id": v.ids["default_year"],
		"section_name":     "A",
		"capacity":         40,
		"class_teacher_id": v.ids["teacher_staff"],
	}, http.StatusOK)

	_, students := v.expectAny("Teacher lists attendance class roster", http.MethodGet, "/students?section_id="+v.ids["default_section"]+"&page_size=100", "Teacher", "Teacher", nil, http.StatusOK)
	enrollmentID := findRowString(students, v.ids["payment_student"], "active_enrollment_id")
	if enrollmentID == "" {
		v.addFail("Attendance roster enrollment lookup", "GET /students", "Teacher", "Could not find active enrollment for local verifier student")
		return
	}
	v.ids["payment_student_enrollment"] = enrollmentID

	periodNumber := 200000 + int(time.Now().UnixNano()%700000)
	v.expectDataID("Teacher creates attendance session", http.MethodPost, "/attendance/sessions", "Teacher", "Teacher", map[string]any{
		"academic_year_id": v.ids["default_year"],
		"section_id":       v.ids["default_section"],
		"subject_id":       v.ids["default_subject"],
		"staff_id":         v.ids["teacher_staff"],
		"date":             "2026-06-20",
		"period_number":    periodNumber,
	}, http.StatusCreated, "attendance_session")
	if v.ids["attendance_session"] == "" {
		return
	}

	attendanceRows := []map[string]any{{
		"student_id":    v.ids["payment_student"],
		"enrollment_id": v.ids["payment_student_enrollment"],
		"status":        "present",
	}}
	v.expect("Teacher saves attendance draft", http.MethodPost, "/attendance/sessions/"+v.ids["attendance_session"]+"/mark", "Teacher", "Teacher", map[string]any{
		"finalize":    false,
		"attendances": attendanceRows,
	}, http.StatusOK)
	v.expect("Teacher submits final attendance", http.MethodPost, "/attendance/sessions/"+v.ids["attendance_session"]+"/mark", "Teacher", "Teacher", map[string]any{
		"finalize":    true,
		"attendances": attendanceRows,
	}, http.StatusOK)
	v.expect("Teacher cannot edit locked attendance", http.MethodPost, "/attendance/sessions/"+v.ids["attendance_session"]+"/mark", "Teacher", "Teacher", map[string]any{
		"finalize":    true,
		"attendances": attendanceRows,
	}, http.StatusForbidden)
	v.expect("Teacher requests attendance correction", http.MethodPost, "/attendance/sessions/"+v.ids["attendance_session"]+"/correction-request", "Teacher", "Teacher", map[string]any{
		"reason": "Local Docker verifier correction request",
	}, http.StatusOK)
	v.expect("Principal reopens attendance correction", http.MethodPost, "/attendance/sessions/"+v.ids["attendance_session"]+"/reopen", "Principal", "Principal", map[string]any{
		"reason": "Local Docker verifier approved correction",
	}, http.StatusOK)
	v.expect("Principal reads attendance monitor sessions", http.MethodGet, "/attendance/sessions?section_id="+v.ids["default_section"], "Principal", "Principal", nil, http.StatusOK)
	v.expect("Parent reads linked child attendance summary", http.MethodGet, "/attendance/summary?student_id="+v.ids["payment_student"], "Parent", "Parent", nil, http.StatusOK)
	v.expect("Parent reads linked child attendance records", http.MethodGet, "/students/"+v.ids["payment_student"]+"/attendance?month=6&year=2026", "Parent", "Parent", nil, http.StatusOK)

	_, tokenData := v.expectAny("Principal creates staff attendance QR token", http.MethodGet, "/attendance/staff/qr-token", "Principal", "Principal", nil, http.StatusOK)
	token, ok := getString(tokenData, "token")
	if !ok {
		v.addFail("Staff attendance QR token lookup", "GET /attendance/staff/qr-token", "Principal", "QR token missing")
		return
	}
	v.expect("Teacher scans staff attendance QR", http.MethodPost, "/attendance/staff/qr-scan", "Teacher", "Teacher", map[string]any{
		"token": token,
	}, http.StatusOK)
	v.expect("Teacher reads own staff attendance today", http.MethodGet, "/attendance/staff/me/today", "Teacher", "Teacher", nil, http.StatusOK)
	v.expect("Principal reads staff attendance monitor", http.MethodGet, "/attendance/staff?date=2026-06-20", "Principal", "Principal", nil, http.StatusOK)
	v.expect("Principal exports staff QR daily logs", http.MethodGet, "/attendance/staff/qr-logs/export?date=2026-06-20", "Principal", "Principal", nil, http.StatusOK)
}

func (v *verifier) runTeacherHomeworkFlow() {
	if v.tokens["Principal"] == "" || v.tokens["Teacher"] == "" || v.tokens["Parent"] == "" || v.ids["teacher_staff"] == "" || v.ids["payment_student"] == "" {
		v.addFail("Teacher homework fixture", "local verifier", "Principal/Teacher/Parent", "Principal, Teacher, Parent, teacher staff, or linked student missing")
		return
	}
	if !v.ensureTeacherSubjectAssignment() {
		return
	}
	periodNumber := 100000 + int(time.Now().UnixNano()%900000)
	v.expectDataID("Principal links Teacher to default class timetable", http.MethodPost, "/timetable/slots", "Principal", "Principal", map[string]any{
		"section_id":       v.ids["default_section"],
		"academic_year_id": v.ids["default_year"],
		"term_id":          v.ids["default_term"],
		"day_of_week":      7,
		"period_number":    periodNumber,
		"subject_id":       v.ids["default_subject"],
		"staff_id":         v.ids["teacher_staff"],
		"start_time":       "18:00",
		"end_time":         "18:40",
	}, http.StatusCreated, "teacher_homework_slot")
	v.expectDataID("Teacher creates homework assignment", http.MethodPost, "/homework", "Teacher", "Teacher", map[string]any{
		"title":       "Local Docker Homework " + v.suffix,
		"subject":     "Mathematics",
		"class":       "PP1 A",
		"section_id":  v.ids["default_section"],
		"teacher_id":  v.ids["teacher_staff"],
		"student_id":  v.ids["payment_student"],
		"description": "Complete the local Docker homework workflow",
		"due_date":    "2026-05-30T00:00:00Z",
		"status":      "pending",
		"created_by":  v.ids["teacher_staff"],
	}, http.StatusCreated, "homework")
	if v.ids["homework"] == "" {
		return
	}
	v.expectNotification("Parent sees homework notification", "Parent", "homework", v.ids["homework"])
	v.expect("Teacher updates homework assignment", http.MethodPut, "/homework/"+v.ids["homework"], "Teacher", "Teacher", map[string]any{
		"title":       "Local Docker Homework Updated " + v.suffix,
		"subject":     "Mathematics",
		"class":       "PP1 A",
		"section_id":  v.ids["default_section"],
		"teacher_id":  v.ids["teacher_staff"],
		"student_id":  v.ids["payment_student"],
		"description": "Updated local Docker homework workflow",
		"due_date":    "2026-05-31T00:00:00Z",
		"status":      "pending",
		"created_by":  v.ids["teacher_staff"],
	}, http.StatusOK)
	v.expect("Parent lists linked homework", http.MethodGet, "/homework?student_id="+v.ids["payment_student"], "Parent", "Parent", nil, http.StatusOK)
	v.expectDataID("Parent submits homework", http.MethodPost, "/homework/"+v.ids["homework"]+"/submissions", "Parent", "Parent", map[string]any{
		"student_id":  v.ids["payment_student"],
		"answer_text": "Completed by local Docker verifier",
	}, http.StatusCreated, "homework_submission")
	if v.ids["homework_submission"] == "" {
		return
	}
	v.expect("Teacher lists homework submissions", http.MethodGet, "/homework/"+v.ids["homework"]+"/submissions", "Teacher", "Teacher", nil, http.StatusOK)
	v.expect("Teacher reviews homework submission", http.MethodPut, "/homework/"+v.ids["homework"]+"/submissions/"+v.ids["homework_submission"]+"/review", "Teacher", "Teacher", map[string]any{
		"status":  "reviewed",
		"grade":   "A",
		"remarks": "Verified by local Docker API verifier",
	}, http.StatusOK)
	v.expect("Parent sees reviewed homework submission", http.MethodGet, "/homework/"+v.ids["homework"]+"/submissions?student_id="+v.ids["payment_student"], "Parent", "Parent", nil, http.StatusOK)
}

func (v *verifier) runStudentLeaveFlow() {
	if v.tokens["Principal"] == "" || v.tokens["Parent"] == "" || v.ids["payment_student"] == "" {
		v.addFail("Student leave fixture", "local verifier", "Principal/Parent", "Principal token, Parent token, or linked student ID missing")
		return
	}
	v.expect("Parent reads linked students before leave", http.MethodGet, "/me/students", "Parent", "Parent", nil, http.StatusOK)
	v.expectDataID("Parent submits student leave request", http.MethodPost, "/student-leave/applications", "Parent", "Parent", map[string]any{
		"student_id": v.ids["payment_student"],
		"leave_type": "Sick Leave",
		"from_date":  "2026-05-18",
		"to_date":    "2026-05-19",
		"reason":     "Local Docker verifier student leave flow",
	}, http.StatusCreated, "student_leave")
	if v.ids["student_leave"] == "" {
		return
	}
	v.expect("Parent lists own student leave requests", http.MethodGet, "/student-leave/applications?student_id="+v.ids["payment_student"], "Parent", "Parent", nil, http.StatusOK)
	v.expect("Principal lists student leave requests", http.MethodGet, "/student-leave/applications?student_id="+v.ids["payment_student"], "Principal", "Principal", nil, http.StatusOK)
	v.expect("Teacher approves linked student leave request", http.MethodPut, "/student-leave/applications/"+v.ids["student_leave"]+"/decision", "Teacher", "Teacher", map[string]any{
		"status": "approved",
	}, http.StatusOK)
	v.expect("Parent sees approved student leave request", http.MethodGet, "/student-leave/applications?student_id="+v.ids["payment_student"]+"&status=approved", "Parent", "Parent", nil, http.StatusOK)
}

func (v *verifier) runReportExportFlow() {
	if v.tokens["Principal"] == "" || v.tokens["Teacher"] == "" || v.tokens["Parent"] == "" {
		v.addFail("Report export fixture", "local verifier", "All roles", "Principal, Teacher, or Parent token missing")
		return
	}
	v.expectDataID("Principal creates general report export", http.MethodPost, "/reports/exports", "Principal", "Principal", map[string]any{
		"report_title": "Local Docker Principal Summary",
		"format":       "pdf",
		"scope":        "principal",
		"parameters":   map[string]any{"month": "2026-05"},
	}, http.StatusCreated, "general_report_export")
	if v.ids["general_report_export"] != "" {
		v.expect("Principal fetches generated report export", http.MethodGet, "/reports/exports/"+v.ids["general_report_export"], "Principal", "Principal", nil, http.StatusOK)
	}
	v.expectDataID("Principal creates fee report export", http.MethodPost, "/fees/reports/exports", "Principal", "Principal", map[string]any{
		"report_title": "Local Docker Fee Summary",
		"format":       "csv",
		"scope":        "principal",
	}, http.StatusCreated, "fee_report_export")
	v.expectDataID("Principal creates attendance report export", http.MethodPost, "/attendance/reports/exports", "Principal", "Principal", map[string]any{
		"report_title": "Local Docker Attendance Summary",
		"format":       "csv",
		"scope":        "principal",
	}, http.StatusCreated, "attendance_report_export")
	v.expectDataID("Principal creates student report export", http.MethodPost, "/student-reports/exports", "Principal", "Principal", map[string]any{
		"report_title": "Local Docker Student Oversight",
		"format":       "pdf",
		"scope":        "principal",
	}, http.StatusCreated, "student_report_export")
	v.expect("Parent blocked from general report export", http.MethodPost, "/reports/exports", "Parent", "Parent", map[string]any{
		"report_title": "Blocked parent export",
		"format":       "pdf",
	}, http.StatusForbidden)
}

func (v *verifier) runParentCalendarReadFlow() {
	if v.tokens["Parent"] == "" {
		v.addFail("Parent calendar fixture", "local verifier", "Parent", "Parent token missing")
		return
	}
	v.expect("Parent reads calendar events", http.MethodGet, "/events", "Parent", "Parent", nil, http.StatusOK)
	v.expect("Parent reads PTM calendar rows", http.MethodGet, "/parent-teacher-meetings", "Parent", "Parent", nil, http.StatusOK)
	_, years := v.expectAny("Parent lists academic years for holidays", http.MethodGet, "/academic-years", "Parent", "Parent", nil, http.StatusOK)
	yearID := firstID(years)
	if yearID == "" {
		v.addFail("Parent holiday academic year detail", "GET /academic-years/:id", "Parent", "No academic year ID returned for holiday detail check")
		return
	}
	v.expect("Parent reads academic year holiday detail", http.MethodGet, "/academic-years/"+yearID, "Parent", "Parent", nil, http.StatusOK)
}

func (v *verifier) login(role, identity, password string, want int) bool {
	body := map[string]any{"password": password}
	if strings.Contains(identity, "@") {
		body["email"] = identity
	} else {
		body["username"] = identity
	}
	entry, data := v.request("Login "+role, http.MethodPost, "/auth/login", "", role, body, []int{want}, "PASS", "")
	if entry.Status == "PASS" && want == http.StatusOK {
		if token, ok := getString(data, "token"); ok {
			v.tokens[role] = token
			return true
		}
		v.rows[len(v.rows)-1].Status = "FAIL"
		v.rows[len(v.rows)-1].Error = "login response data.token missing"
		return false
	}
	return entry.Status == "PASS"
}

func (v *verifier) expect(name, method, path, tokenRole, role string, body any, want int) {
	v.request(name, method, path, tokenRole, role, body, []int{want}, "PASS", "")
}

func (v *verifier) expectAny(name, method, path, tokenRole, role string, body any, want int) (reportEntry, any) {
	return v.request(name, method, path, tokenRole, role, body, []int{want}, "PASS", "")
}

func (v *verifier) expectNotification(name, role, referenceType, referenceID string) {
	_, data := v.expectAny(name, http.MethodGet, "/notifications", role, role, nil, http.StatusOK)
	if !hasNotification(data, referenceType, referenceID) {
		v.addFail(name+" content", "GET /notifications", role, "Notification with reference_type="+referenceType+" and reference_id="+referenceID+" not found")
	}
}

func (v *verifier) expectKnownGap(name, method, path, tokenRole, role string, body any, wants []int, notes string) {
	v.request(name, method, path, tokenRole, role, body, wants, "WARN", notes)
}

func (v *verifier) expectDataID(name, method, path, tokenRole, role string, body any, want int, key string) {
	entry, data := v.request(name, method, path, tokenRole, role, body, []int{want}, "PASS", "")
	if entry.Status != "PASS" {
		return
	}
	if id, ok := getString(data, "id"); ok {
		v.ids[key] = id
		return
	}
	v.rows[len(v.rows)-1].Status = "FAIL"
	v.rows[len(v.rows)-1].Error = "response data.id missing"
}

func (v *verifier) expectMultipart(name, method, path, tokenRole, role string, fields map[string]string, fileField, filename string, content []byte, want int) {
	v.requestMultipart(name, method, path, tokenRole, role, fields, fileField, filename, content, []int{want}, "PASS", "")
}

func (v *verifier) expectMultipartDataID(name, method, path, tokenRole, role string, fields map[string]string, fileField, filename string, content []byte, want int, key string) {
	entry, data := v.requestMultipart(name, method, path, tokenRole, role, fields, fileField, filename, content, []int{want}, "PASS", "")
	if entry.Status != "PASS" {
		return
	}
	if id, ok := getString(data, "id"); ok {
		v.ids[key] = id
		return
	}
	v.rows[len(v.rows)-1].Status = "FAIL"
	v.rows[len(v.rows)-1].Error = "response data.id missing"
}

func (v *verifier) request(name, method, path, tokenRole, role string, body any, wants []int, expectedStatus, notes string) (reportEntry, any) {
	if v.delay > 0 {
		defer time.Sleep(v.delay)
	}
	var payload []byte
	if body != nil {
		payload, _ = json.Marshal(body)
	}
	endpoint := method + " " + path
	if tokenRole != "" && v.tokens[tokenRole] == "" {
		entry := reportEntry{
			Name:               name,
			Endpoint:           endpoint,
			Role:               role,
			Status:             "FAIL",
			ExpectedStatusCode: formatExpected(wants),
			Error:              "missing token for role " + tokenRole,
			Notes:              notes,
		}
		v.rows = append(v.rows, entry)
		return entry, nil
	}

	req, err := http.NewRequest(method, v.baseURL+path, bytes.NewReader(payload))
	if err != nil {
		entry := reportEntry{Name: name, Endpoint: endpoint, Role: role, Status: "FAIL", Error: err.Error(), Notes: notes}
		v.rows = append(v.rows, entry)
		return entry, nil
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Forwarded-For", v.nextClientIP())
	if tokenRole != "" {
		req.Header.Set("Authorization", "Bearer "+v.tokens[tokenRole])
	}

	start := time.Now()
	resp, err := v.client.Do(req)
	elapsed := time.Since(start)
	entry := reportEntry{
		Name:               name,
		Endpoint:           endpoint,
		Role:               role,
		ExpectedStatusCode: formatExpected(wants),
		ResponseTime:       elapsed.String(),
		Notes:              notes,
	}
	if err != nil {
		entry.Status = "FAIL"
		entry.Error = err.Error()
		v.rows = append(v.rows, entry)
		return entry, nil
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	entry.StatusCode = resp.StatusCode
	entry.ResponseBody = truncate(redactJSON(raw), 1200)

	if containsStatus(wants, resp.StatusCode) {
		entry.Status = expectedStatus
	} else {
		entry.Status = "FAIL"
		entry.Error = fmt.Sprintf("expected HTTP %s, got %d", formatExpected(wants), resp.StatusCode)
	}
	data := extractData(raw)
	v.rows = append(v.rows, entry)
	return entry, data
}

func (v *verifier) requestMultipart(name, method, path, tokenRole, role string, fields map[string]string, fileField, filename string, content []byte, wants []int, expectedStatus, notes string) (reportEntry, any) {
	if v.delay > 0 {
		defer time.Sleep(v.delay)
	}
	endpoint := method + " " + path
	if tokenRole != "" && v.tokens[tokenRole] == "" {
		entry := reportEntry{
			Name:               name,
			Endpoint:           endpoint,
			Role:               role,
			Status:             "FAIL",
			ExpectedStatusCode: formatExpected(wants),
			Error:              "missing token for role " + tokenRole,
			Notes:              notes,
		}
		v.rows = append(v.rows, entry)
		return entry, nil
	}

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	for key, value := range fields {
		_ = writer.WriteField(key, value)
	}
	part, err := writer.CreateFormFile(fileField, filename)
	if err == nil {
		_, err = part.Write(content)
	}
	if err == nil {
		err = writer.Close()
	}
	if err != nil {
		entry := reportEntry{Name: name, Endpoint: endpoint, Role: role, Status: "FAIL", Error: err.Error(), Notes: notes}
		v.rows = append(v.rows, entry)
		return entry, nil
	}

	req, err := http.NewRequest(method, v.baseURL+path, &body)
	if err != nil {
		entry := reportEntry{Name: name, Endpoint: endpoint, Role: role, Status: "FAIL", Error: err.Error(), Notes: notes}
		v.rows = append(v.rows, entry)
		return entry, nil
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("X-Forwarded-For", v.nextClientIP())
	if tokenRole != "" {
		req.Header.Set("Authorization", "Bearer "+v.tokens[tokenRole])
	}

	start := time.Now()
	resp, err := v.client.Do(req)
	elapsed := time.Since(start)
	entry := reportEntry{
		Name:               name,
		Endpoint:           endpoint,
		Role:               role,
		ExpectedStatusCode: formatExpected(wants),
		ResponseTime:       elapsed.String(),
		Notes:              notes,
	}
	if err != nil {
		entry.Status = "FAIL"
		entry.Error = err.Error()
		v.rows = append(v.rows, entry)
		return entry, nil
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	entry.StatusCode = resp.StatusCode
	entry.ResponseBody = truncate(redactJSON(raw), 1200)
	if containsStatus(wants, resp.StatusCode) {
		entry.Status = expectedStatus
	} else {
		entry.Status = "FAIL"
		entry.Error = fmt.Sprintf("expected HTTP %s, got %d", formatExpected(wants), resp.StatusCode)
	}
	data := extractData(raw)
	v.rows = append(v.rows, entry)
	return entry, data
}

func (v *verifier) nextClientIP() string {
	v.counter++
	return fmt.Sprintf("10.90.%d.%d", (v.counter/250)%250, (v.counter%250)+1)
}

func (v *verifier) addFail(name, endpoint, role, message string) {
	v.rows = append(v.rows, reportEntry{Name: name, Endpoint: endpoint, Role: role, Status: "FAIL", Error: message})
}

func (v *verifier) addWarn(name, endpoint, role, message string) {
	v.rows = append(v.rows, reportEntry{Name: name, Endpoint: endpoint, Role: role, Status: "WARN", Notes: message})
}

func containsStatus(wants []int, got int) bool {
	for _, want := range wants {
		if want == got {
			return true
		}
	}
	return false
}

func formatExpected(wants []int) string {
	parts := make([]string, 0, len(wants))
	for _, want := range wants {
		parts = append(parts, strconv.Itoa(want))
	}
	return strings.Join(parts, "/")
}

func extractData(raw []byte) any {
	var parsed map[string]any
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return nil
	}
	return parsed["data"]
}

func getString(data any, key string) (string, bool) {
	row, ok := data.(map[string]any)
	if !ok {
		return "", false
	}
	value, ok := row[key].(string)
	if !ok || strings.TrimSpace(value) == "" {
		return "", false
	}
	return value, true
}

func asList(data any) ([]map[string]any, bool) {
	rows, ok := data.([]any)
	if !ok {
		return nil, false
	}
	out := make([]map[string]any, 0, len(rows))
	for _, item := range rows {
		row, ok := item.(map[string]any)
		if !ok {
			continue
		}
		out = append(out, row)
	}
	return out, true
}

func firstID(data any) string {
	rows, ok := data.([]any)
	if !ok || len(rows) == 0 {
		return ""
	}
	row, ok := rows[0].(map[string]any)
	if !ok {
		return ""
	}
	id, _ := row["id"].(string)
	return strings.TrimSpace(id)
}

func firstString(data any, key string) string {
	rows, ok := data.([]any)
	if !ok || len(rows) == 0 {
		return ""
	}
	row, ok := rows[0].(map[string]any)
	if !ok {
		return ""
	}
	value, ok := row[key]
	if !ok || value == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(value))
}

func findRowString(data any, id, key string) string {
	rows, ok := data.([]any)
	if !ok {
		return ""
	}
	for _, item := range rows {
		row, ok := item.(map[string]any)
		if !ok {
			continue
		}
		if strings.TrimSpace(fmt.Sprint(row["id"])) != strings.TrimSpace(id) {
			continue
		}
		value, ok := row[key]
		if !ok || value == nil {
			return ""
		}
		return strings.TrimSpace(fmt.Sprint(value))
	}
	return ""
}

func invoiceExists(data any, id string) bool {
	rows, ok := data.([]any)
	if !ok {
		return false
	}
	for _, item := range rows {
		row, ok := item.(map[string]any)
		if !ok {
			continue
		}
		if strings.TrimSpace(fmt.Sprint(row["id"])) == strings.TrimSpace(id) {
			return true
		}
	}
	return false
}

func invoiceHasPaymentMode(data any, invoiceID, paymentMode string) bool {
	rows, ok := data.([]any)
	if !ok {
		return false
	}
	for _, item := range rows {
		row, ok := item.(map[string]any)
		if !ok || strings.TrimSpace(fmt.Sprint(row["id"])) != strings.TrimSpace(invoiceID) {
			continue
		}
		payments, ok := row["payments"].([]any)
		if !ok {
			return false
		}
		for _, payment := range payments {
			paymentRow, ok := payment.(map[string]any)
			if !ok {
				continue
			}
			if strings.EqualFold(strings.TrimSpace(fmt.Sprint(paymentRow["payment_mode"])), paymentMode) {
				return true
			}
		}
	}
	return false
}

func listContainsStatus(data any, status string) bool {
	rows, ok := asList(data)
	if !ok {
		return false
	}
	for _, row := range rows {
		if strings.EqualFold(strings.TrimSpace(fmt.Sprint(row["status"])), status) {
			return true
		}
	}
	return false
}

func nestedString(data any, parentKey, key string) string {
	row, ok := data.(map[string]any)
	if !ok {
		return ""
	}
	parent, ok := row[parentKey].(map[string]any)
	if !ok {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(parent[key]))
}

func studentFeeBalance(data any, studentID string) float64 {
	rows, ok := asList(data)
	if !ok {
		return 0
	}
	for _, row := range rows {
		if strings.TrimSpace(fmt.Sprint(row["id"])) != strings.TrimSpace(studentID) {
			continue
		}
		feeSummary, ok := row["fee_summary"].(map[string]any)
		if !ok {
			return 0
		}
		return floatValue(feeSummary["balance"])
	}
	return 0
}

func dashboardChildFeeBalance(data any, studentID string) float64 {
	row, ok := data.(map[string]any)
	if !ok {
		return 0
	}
	children, ok := row["children"].([]any)
	if !ok {
		return 0
	}
	for _, item := range children {
		child, ok := item.(map[string]any)
		if !ok {
			continue
		}
		if strings.TrimSpace(fmt.Sprint(child["id"])) != strings.TrimSpace(studentID) {
			continue
		}
		return floatValue(child["pending_fee_balance"])
	}
	return 0
}

func classFeeBalance(data any, sectionID string) float64 {
	row, ok := data.(map[string]any)
	if !ok {
		return 0
	}
	classes, ok := row["classes"].([]any)
	if !ok {
		return 0
	}
	for _, item := range classes {
		classRow, ok := item.(map[string]any)
		if !ok {
			continue
		}
		if strings.TrimSpace(fmt.Sprint(classRow["section_id"])) != strings.TrimSpace(sectionID) {
			continue
		}
		return floatValue(classRow["fees_due_amount"])
	}
	return 0
}

func floatValue(value any) float64 {
	switch typed := value.(type) {
	case float64:
		return typed
	case float32:
		return float64(typed)
	case int:
		return float64(typed)
	case int64:
		return float64(typed)
	case int32:
		return float64(typed)
	case json.Number:
		parsed, _ := typed.Float64()
		return parsed
	default:
		parsed, _ := strconv.ParseFloat(strings.TrimSpace(fmt.Sprint(value)), 64)
		return parsed
	}
}

func hasNotification(data any, referenceType, referenceID string) bool {
	rows, ok := data.([]any)
	if !ok {
		return false
	}
	referenceType = strings.TrimSpace(referenceType)
	referenceID = strings.TrimSpace(referenceID)
	for _, item := range rows {
		row, ok := item.(map[string]any)
		if !ok {
			continue
		}
		if strings.TrimSpace(fmt.Sprint(row["reference_type"])) != referenceType {
			continue
		}
		if referenceID == "" || strings.TrimSpace(fmt.Sprint(row["reference_id"])) == referenceID {
			return true
		}
	}
	return false
}

func findApprovalID(data any, targetEmail string) string {
	rows, ok := data.([]any)
	if !ok {
		return ""
	}
	for _, item := range rows {
		row, ok := item.(map[string]any)
		if !ok {
			continue
		}
		if strings.EqualFold(fmt.Sprint(row["target_email"]), targetEmail) && strings.EqualFold(fmt.Sprint(row["status"]), "pending") {
			return fmt.Sprint(row["id"])
		}
	}
	return ""
}

func redactJSON(raw []byte) string {
	var value any
	if err := json.Unmarshal(raw, &value); err != nil {
		return string(raw)
	}
	value = redactValue(value)
	encoded, err := json.Marshal(value)
	if err != nil {
		return string(raw)
	}
	return string(encoded)
}

func redactValue(value any) any {
	switch typed := value.(type) {
	case map[string]any:
		out := make(map[string]any, len(typed))
		for key, child := range typed {
			lower := strings.ToLower(key)
			if strings.Contains(lower, "token") || strings.Contains(lower, "password") || lower == "authorization" {
				out[key] = "[redacted]"
				continue
			}
			out[key] = redactValue(child)
		}
		return out
	case []any:
		for i := range typed {
			typed[i] = redactValue(typed[i])
		}
		return typed
	default:
		return value
	}
}

func truncate(value string, max int) string {
	value = strings.TrimSpace(value)
	if len(value) <= max {
		return value
	}
	return value[:max] + "...[truncated]"
}

func (v *verifier) buildReport() report {
	rep := report{
		GeneratedAt: time.Now().UTC().Format(time.RFC3339),
		Target:      v.baseURL,
		Mode:        v.mode,
		Tests:       v.rows,
	}
	rep.Total = len(v.rows)
	for _, row := range v.rows {
		switch row.Status {
		case "PASS":
			rep.Passed++
		case "WARN":
			rep.Warnings++
		default:
			rep.Failed++
		}
	}
	if rep.Total > 0 {
		rep.SuccessPct = float64(rep.Passed+rep.Warnings) * 100 / float64(rep.Total)
	}
	return rep
}

func writeReports(rep report) error {
	dir := filepath.Join("test-report")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	raw, _ := json.MarshalIndent(rep, "", "  ")
	if err := os.WriteFile(filepath.Join(dir, "local-docker-api-report.json"), raw, 0o644); err != nil {
		return err
	}

	var b strings.Builder
	b.WriteString("<!doctype html><html><head><meta charset='utf-8'><title>Local Docker API Verification</title>")
	b.WriteString("<style>body{font-family:Arial,sans-serif;margin:24px}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ddd;padding:8px;vertical-align:top}th{background:#f4f4f4}.PASS{color:#0a7a2f;font-weight:bold}.WARN{color:#8a5a00;font-weight:bold}.FAIL{color:#b00020;font-weight:bold}pre{white-space:pre-wrap;max-width:520px}</style>")
	b.WriteString("</head><body>")
	b.WriteString(fmt.Sprintf("<h1>SchoolDesk Local Docker API Verification</h1><p>Target: %s | Mode: %s</p>", html.EscapeString(rep.Target), html.EscapeString(rep.Mode)))
	b.WriteString(fmt.Sprintf("<p>Total: %d | Passed: %d | Warnings: %d | Failed: %d | Non-failing: %.2f%%</p>", rep.Total, rep.Passed, rep.Warnings, rep.Failed, rep.SuccessPct))
	b.WriteString("<table><thead><tr><th>Test Name</th><th>Endpoint</th><th>Role</th><th>Status</th><th>Expected</th><th>Status Code</th><th>Response Time</th><th>Notes/Error</th><th>Response Body</th></tr></thead><tbody>")
	for _, row := range rep.Tests {
		b.WriteString("<tr>")
		b.WriteString("<td>" + html.EscapeString(row.Name) + "</td>")
		b.WriteString("<td>" + html.EscapeString(row.Endpoint) + "</td>")
		b.WriteString("<td>" + html.EscapeString(row.Role) + "</td>")
		b.WriteString("<td class='" + row.Status + "'>" + row.Status + "</td>")
		b.WriteString("<td>" + html.EscapeString(row.ExpectedStatusCode) + "</td>")
		b.WriteString(fmt.Sprintf("<td>%d</td>", row.StatusCode))
		b.WriteString("<td>" + html.EscapeString(row.ResponseTime) + "</td>")
		b.WriteString("<td>" + html.EscapeString(strings.TrimSpace(row.Notes+" "+row.Error)) + "</td>")
		b.WriteString("<td><pre>" + html.EscapeString(row.ResponseBody) + "</pre></td>")
		b.WriteString("</tr>")
	}
	b.WriteString("</tbody></table></body></html>")
	return os.WriteFile(filepath.Join(dir, "local-docker-api-report.html"), []byte(b.String()), 0o644)
}

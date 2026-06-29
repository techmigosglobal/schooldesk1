package handlers

import (
	"bytes"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

func TestFeesWorkflowAliasesAutoSplitTuitionAndKeepBookKitOneTime(t *testing.T) {
	gin.SetMode(gin.TestMode)
	t.Cleanup(func() { _ = os.RemoveAll("uploads") })
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(
		&models.School{},
		&models.AcademicYear{},
		&models.Term{},
		&models.Grade{},
		&models.Section{},
		&models.Student{},
		&models.User{},
		&models.ParentStudentLink{},
		&models.FeeCategory{},
		&models.FeeStructure{},
		&models.FeeInstallment{},
		&models.FeeInvoice{},
		&models.FeeInvoiceItem{},
		&models.Payment{},
		&models.ParentPaymentRequest{},
		&models.SchoolPaymentSetting{},
		&models.ScopedPaymentSetting{},
		&models.AuditLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	school := models.School{BaseModel: models.BaseModel{ID: "school-fee-workflow"}, Name: "Workflow School", SchoolType: "cbse"}
	year := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-fee-workflow"}, SchoolID: school.ID, YearLabel: "2026-2027", StartDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), EndDate: time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC), IsCurrent: true}
	terms := []models.Term{
		{BaseModel: models.BaseModel{ID: "term-fw-1"}, AcademicYearID: year.ID, TermNumber: 1, TermName: "Term 1", StartDate: year.StartDate, EndDate: year.StartDate.AddDate(0, 3, 0)},
		{BaseModel: models.BaseModel{ID: "term-fw-2"}, AcademicYearID: year.ID, TermNumber: 2, TermName: "Term 2", StartDate: year.StartDate.AddDate(0, 3, 1), EndDate: year.StartDate.AddDate(0, 6, 0)},
		{BaseModel: models.BaseModel{ID: "term-fw-3"}, AcademicYearID: year.ID, TermNumber: 3, TermName: "Term 3", StartDate: year.StartDate.AddDate(0, 6, 1), EndDate: year.StartDate.AddDate(0, 9, 0)},
		{BaseModel: models.BaseModel{ID: "term-fw-4"}, AcademicYearID: year.ID, TermNumber: 4, TermName: "Term 4", StartDate: year.StartDate.AddDate(0, 9, 1), EndDate: year.EndDate},
	}
	grade := models.Grade{BaseModel: models.BaseModel{ID: "grade-fee-workflow"}, SchoolID: school.ID, GradeName: "C1", GradeNumber: 1}
	section := models.Section{BaseModel: models.BaseModel{ID: "section-fee-workflow"}, GradeID: grade.ID, AcademicYearID: year.ID, SectionName: "A", Capacity: 40}
	bookCategory := models.FeeCategory{BaseModel: models.BaseModel{ID: "cat-book-kit"}, SchoolID: school.ID, CategoryName: "Book & Kit Fee", Frequency: "one_time"}
	tuitionCategory := models.FeeCategory{BaseModel: models.BaseModel{ID: "cat-tuition-workflow"}, SchoolID: school.ID, CategoryName: "Tuition Fee", Frequency: "yearly"}
	bookStructure := models.FeeStructure{BaseModel: models.BaseModel{ID: "structure-book-kit"}, SchoolID: school.ID, AcademicYearID: year.ID, GradeID: grade.ID, FeeCategoryID: bookCategory.ID, Amount: 3000, DueDay: 5, FeeType: "book_kit", BillingMode: "one_time", Priority: 1, IsActive: true}
	tuitionStructure := models.FeeStructure{BaseModel: models.BaseModel{ID: "structure-tuition-workflow"}, SchoolID: school.ID, AcademicYearID: year.ID, GradeID: grade.ID, FeeCategoryID: tuitionCategory.ID, Amount: 12000, DueDay: 10, FeeType: "tuition", BillingMode: "term_wise", Priority: 2, IsActive: true}
	student := models.Student{BaseModel: models.BaseModel{ID: "student-fee-workflow"}, SchoolID: school.ID, StudentCode: "FW-001", AdmissionNumber: "FW-001", FirstName: "Fee", LastName: "Student", DateOfBirth: time.Date(2018, 1, 1, 0, 0, 0, 0, time.UTC), AdmissionDate: time.Now(), CurrentSectionID: &section.ID, Status: "active"}
	parent := models.User{BaseModel: models.BaseModel{ID: "parent-fee-workflow"}, SchoolID: school.ID, Username: "parent-fw", Email: "parent-fw@example.test", IsActive: true, IsVerified: true}
	principal := models.User{BaseModel: models.BaseModel{ID: "principal-fee-workflow"}, SchoolID: school.ID, Username: "principal-fw", Email: "principal-fw@example.test", IsActive: true, IsVerified: true}
	link := models.ParentStudentLink{SchoolID: school.ID, ParentUserID: parent.ID, StudentID: student.ID, StudentAdmissionNumber: student.AdmissionNumber}
	paymentSetting := models.SchoolPaymentSetting{BaseModel: models.BaseModel{ID: "school-payment-fw"}, SchoolID: school.ID, UPIID: "school@upi", PayeeName: "Workflow School", UPIEnabled: true}
	for _, seed := range []any{&school, &year, &grade, &section, &bookCategory, &tuitionCategory, &bookStructure, &tuitionStructure, &student, &parent, &principal, &link, &paymentSetting} {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed %T: %v", seed, err)
		}
	}
	for i := range terms {
		if err := db.Create(&terms[i]).Error; err != nil {
			t.Fatalf("seed term: %v", err)
		}
	}

	handler := NewFeeHandler()
	principalRouter := gin.New()
	principalRouter.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("user_id", principal.ID)
		c.Set("role_name", "Principal")
		c.Next()
	})
	principalRouter.POST("/fees/structures/:id/generate-student-fees", handler.GenerateStudentFeesForStructure)
	principalRouter.GET("/fees/dashboard", handler.GetFeesDashboard)
	principalRouter.GET("/fees/payments/pending", handler.GetPendingFeePayments)
	principalRouter.POST("/fees/payments/:id/approve", handler.ApproveFeePayment)
	principalRouter.POST("/fees/payments/:id/reject", handler.RejectFeePayment)

	for _, structureID := range []string{bookStructure.ID, tuitionStructure.ID} {
		resp := httptest.NewRecorder()
		principalRouter.ServeHTTP(resp, httptest.NewRequest(http.MethodPost, "/fees/structures/"+structureID+"/generate-student-fees", nil))
		if resp.Code != http.StatusCreated {
			t.Fatalf("generate %s status=%d body=%s", structureID, resp.Code, resp.Body.String())
		}
	}
	duplicate := httptest.NewRecorder()
	principalRouter.ServeHTTP(duplicate, httptest.NewRequest(http.MethodPost, "/fees/structures/"+tuitionStructure.ID+"/generate-student-fees", nil))
	if duplicate.Code != http.StatusCreated {
		t.Fatalf("duplicate generate status=%d body=%s", duplicate.Code, duplicate.Body.String())
	}
	var duplicateBody struct {
		Data struct {
			Created int `json:"created"`
			Skipped int `json:"skipped"`
		} `json:"data"`
	}
	if err := json.Unmarshal(duplicate.Body.Bytes(), &duplicateBody); err != nil {
		t.Fatalf("decode duplicate: %v", err)
	}
	if duplicateBody.Data.Created != 0 || duplicateBody.Data.Skipped != 1 {
		t.Fatalf("duplicate generation should skip existing student fee, got %+v", duplicateBody.Data)
	}

	parentRouter := gin.New()
	parentRouter.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("user_id", parent.ID)
		c.Set("role_name", "Parent")
		c.Next()
	})
	parentRouter.GET("/parent/students/:studentId/fees", handler.GetParentStudentFees)
	parentRouter.POST("/fees/payments/submit", handler.SubmitFeePayment)
	parentRouter.GET("/fees/payments/history", handler.GetFeePaymentHistory)

	feesResp := httptest.NewRecorder()
	parentRouter.ServeHTTP(feesResp, httptest.NewRequest(http.MethodGet, "/parent/students/"+student.ID+"/fees", nil))
	if feesResp.Code != http.StatusOK {
		t.Fatalf("parent fees status=%d body=%s", feesResp.Code, feesResp.Body.String())
	}
	var feesBody struct {
		Data []map[string]any `json:"data"`
	}
	if err := json.Unmarshal(feesResp.Body.Bytes(), &feesBody); err != nil {
		t.Fatalf("decode fees: %v", err)
	}
	if len(feesBody.Data) != 2 || feesBody.Data[0]["fee_type"] != "book_kit" || feesBody.Data[1]["fee_type"] != "tuition" {
		t.Fatalf("fees should be ordered book kit then tuition, got %+v", feesBody.Data)
	}
	if feesBody.Data[0]["monthly_amount"] != nil || feesBody.Data[0]["term_amount"] != nil {
		t.Fatalf("book kit should not expose split amounts: %+v", feesBody.Data[0])
	}
	if feesBody.Data[1]["monthly_amount"] != float64(1000) || feesBody.Data[1]["term_amount"] != float64(3000) {
		t.Fatalf("tuition should expose automatic split amounts, got %+v", feesBody.Data[1])
	}

	tuitionInvoiceID := feesBody.Data[1]["id"].(string)
	bookInvoiceID := feesBody.Data[0]["id"].(string)
	invalidBookSplit := multipartPaymentRequest(t, map[string]string{
		"student_fee_id":  bookInvoiceID,
		"amount":          "1000",
		"payment_method":  "upi",
		"transaction_ref": "UTR-BOOK-SPLIT",
		"selected_months": "1",
	}, "proof.png", []byte("png-data"))
	invalidBookResp := httptest.NewRecorder()
	parentRouter.ServeHTTP(invalidBookResp, invalidBookSplit)
	if invalidBookResp.Code != http.StatusBadRequest {
		t.Fatalf("book kit split should fail status=%d body=%s", invalidBookResp.Code, invalidBookResp.Body.String())
	}

	monthlyReq := multipartPaymentRequest(t, map[string]string{
		"student_fee_id":  tuitionInvoiceID,
		"amount":          "2000",
		"payment_method":  "upi",
		"transaction_ref": "UTR-TUITION-M2",
		"selected_months": "2",
	}, "proof.png", []byte("png-data"))
	monthlyResp := httptest.NewRecorder()
	parentRouter.ServeHTTP(monthlyResp, monthlyReq)
	if monthlyResp.Code != http.StatusCreated {
		t.Fatalf("monthly submit status=%d body=%s", monthlyResp.Code, monthlyResp.Body.String())
	}
	var submitBody struct {
		Data models.ParentPaymentRequest `json:"data"`
	}
	if err := json.Unmarshal(monthlyResp.Body.Bytes(), &submitBody); err != nil {
		t.Fatalf("decode submit: %v", err)
	}
	if submitBody.Data.Amount != 2000 || submitBody.Data.Status != "pending" || submitBody.Data.ProofURL == nil || !strings.Contains(*submitBody.Data.ProofURL, "/uploads/payment_proofs/") {
		t.Fatalf("unexpected submit data: %+v", submitBody.Data)
	}
	var tuitionInvoice models.FeeInvoice
	if err := db.First(&tuitionInvoice, "id = ?", tuitionInvoiceID).Error; err != nil {
		t.Fatalf("reload tuition invoice: %v", err)
	}
	if tuitionInvoice.PaidAmount != 0 || tuitionInvoice.Balance != 12000 {
		t.Fatalf("pending proof must not update invoice: %+v", tuitionInvoice)
	}

	pendingResp := httptest.NewRecorder()
	principalRouter.ServeHTTP(pendingResp, httptest.NewRequest(http.MethodGet, "/fees/payments/pending", nil))
	if pendingResp.Code != http.StatusOK {
		t.Fatalf("pending status=%d body=%s", pendingResp.Code, pendingResp.Body.String())
	}

	approveResp := httptest.NewRecorder()
	principalRouter.ServeHTTP(approveResp, httptest.NewRequest(http.MethodPost, "/fees/payments/"+submitBody.Data.ID+"/approve", strings.NewReader(`{"rejection_reason":""}`)))
	if approveResp.Code != http.StatusOK {
		t.Fatalf("approve status=%d body=%s", approveResp.Code, approveResp.Body.String())
	}
	if err := db.First(&tuitionInvoice, "id = ?", tuitionInvoiceID).Error; err != nil {
		t.Fatalf("reload approved invoice: %v", err)
	}
	if tuitionInvoice.PaidAmount != 2000 || tuitionInvoice.Balance != 10000 || tuitionInvoice.Status != "partial" {
		t.Fatalf("approval should update tuition invoice, got %+v", tuitionInvoice)
	}

	termReq := multipartPaymentRequest(t, map[string]string{
		"student_fee_id":  tuitionInvoiceID,
		"amount":          "6000",
		"payment_method":  "upi",
		"transaction_ref": "UTR-TUITION-T2",
		"selected_terms":  "2",
	}, "proof.pdf", []byte("%PDF-1.4"))
	termResp := httptest.NewRecorder()
	parentRouter.ServeHTTP(termResp, termReq)
	if termResp.Code != http.StatusCreated {
		t.Fatalf("term submit status=%d body=%s", termResp.Code, termResp.Body.String())
	}
	if err := json.Unmarshal(termResp.Body.Bytes(), &submitBody); err != nil {
		t.Fatalf("decode term submit: %v", err)
	}
	rejectResp := httptest.NewRecorder()
	principalRouter.ServeHTTP(rejectResp, httptest.NewRequest(http.MethodPost, "/fees/payments/"+submitBody.Data.ID+"/reject", strings.NewReader(`{"rejection_reason":"wrong proof"}`)))
	if rejectResp.Code != http.StatusOK {
		t.Fatalf("reject status=%d body=%s", rejectResp.Code, rejectResp.Body.String())
	}
	if err := db.First(&tuitionInvoice, "id = ?", tuitionInvoiceID).Error; err != nil {
		t.Fatalf("reload rejected invoice: %v", err)
	}
	if tuitionInvoice.PaidAmount != 2000 || tuitionInvoice.Balance != 10000 {
		t.Fatalf("rejection should not change invoice balance: %+v", tuitionInvoice)
	}

	dashboardResp := httptest.NewRecorder()
	principalRouter.ServeHTTP(dashboardResp, httptest.NewRequest(http.MethodGet, "/fees/dashboard?class_id="+grade.ID, nil))
	if dashboardResp.Code != http.StatusOK {
		t.Fatalf("dashboard status=%d body=%s", dashboardResp.Code, dashboardResp.Body.String())
	}
	var dashboardBody struct {
		Data map[string]any `json:"data"`
	}
	if err := json.Unmarshal(dashboardResp.Body.Bytes(), &dashboardBody); err != nil {
		t.Fatalf("decode dashboard: %v", err)
	}
	if dashboardBody.Data["total_expected_amount"] != float64(15000) || dashboardBody.Data["total_collected_amount"] != float64(2000) || dashboardBody.Data["pending_amount"] != float64(13000) {
		t.Fatalf("dashboard totals mismatch: %+v", dashboardBody.Data)
	}

	historyResp := httptest.NewRecorder()
	parentRouter.ServeHTTP(historyResp, httptest.NewRequest(http.MethodGet, "/fees/payments/history?student_id="+student.ID, nil))
	if historyResp.Code != http.StatusOK {
		t.Fatalf("history status=%d body=%s", historyResp.Code, historyResp.Body.String())
	}
}

func multipartPaymentRequest(t *testing.T, fields map[string]string, filename string, content []byte) *http.Request {
	t.Helper()
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	for key, value := range fields {
		if err := writer.WriteField(key, value); err != nil {
			t.Fatalf("write field: %v", err)
		}
	}
	part, err := writer.CreateFormFile("screenshot", filename)
	if err != nil {
		t.Fatalf("create form file: %v", err)
	}
	if _, err := part.Write(content); err != nil {
		t.Fatalf("write file: %v", err)
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close multipart: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, "/fees/payments/submit", &body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	return req
}

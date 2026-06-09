package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

func TestFeeStructureCRUDUsesScopedSchoolAndSupportsManagement(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(
		&models.School{},
		&models.AcademicYear{},
		&models.Grade{},
		&models.FeeCategory{},
		&models.FeeStructure{},
		&models.AuditLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	school := models.School{BaseModel: models.BaseModel{ID: "school-fees"}, Name: "Fee School", SchoolType: "cbse"}
	year := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-fees"}, SchoolID: school.ID, YearLabel: "2026-2027", StartDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), EndDate: time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC), IsCurrent: true}
	grade := models.Grade{BaseModel: models.BaseModel{ID: "grade-fees"}, SchoolID: school.ID, GradeName: "Class 5", GradeNumber: 5}
	category := models.FeeCategory{BaseModel: models.BaseModel{ID: "cat-fees"}, SchoolID: school.ID, CategoryName: "Tuition", Frequency: "monthly"}
	for _, seed := range []any{&school, &year, &grade, &category} {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed: %v", err)
		}
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("user_id", "principal-fees")
		c.Set("role", "Principal")
		c.Next()
	})
	handler := NewFeeHandler()
	router.POST("/fees/structures", handler.CreateFeeStructure)
	router.PUT("/fees/structures/:id", handler.UpdateFeeStructure)
	router.DELETE("/fees/structures/:id", handler.DeleteFeeStructure)

	create := httptest.NewRecorder()
	router.ServeHTTP(
		create,
		httptest.NewRequest(
			http.MethodPost,
			"/fees/structures",
			strings.NewReader(`{"academic_year_id":"year-fees","grade_id":"grade-fees","fee_category_id":"cat-fees","amount":2500,"due_day":10,"late_fine_per_day":25}`),
		),
	)
	if create.Code != http.StatusCreated {
		t.Fatalf("create status=%d body=%s", create.Code, create.Body.String())
	}

	otherYear := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-other-fees"}, SchoolID: "other-school", YearLabel: "2026-2027", StartDate: year.StartDate, EndDate: year.EndDate}
	if err := db.Create(&otherYear).Error; err != nil {
		t.Fatalf("create other year: %v", err)
	}
	rejectOtherYear := httptest.NewRecorder()
	router.ServeHTTP(
		rejectOtherYear,
		httptest.NewRequest(
			http.MethodPost,
			"/fees/structures",
			strings.NewReader(`{"academic_year_id":"year-other-fees","grade_id":"grade-fees","fee_category_id":"cat-fees","amount":2500}`),
		),
	)
	if rejectOtherYear.Code != http.StatusBadRequest {
		t.Fatalf("cross-school year status=%d body=%s", rejectOtherYear.Code, rejectOtherYear.Body.String())
	}
	if !strings.Contains(rejectOtherYear.Body.String(), "academic year must belong to this school") {
		t.Fatalf("cross-school response should explain academic year: %s", rejectOtherYear.Body.String())
	}

	var structure models.FeeStructure
	if err := db.Where("school_id = ? AND grade_id = ?", school.ID, grade.ID).First(&structure).Error; err != nil {
		t.Fatalf("structure not scoped/created: %v", err)
	}

	update := httptest.NewRecorder()
	router.ServeHTTP(
		update,
		httptest.NewRequest(
			http.MethodPut,
			"/fees/structures/"+structure.ID,
			strings.NewReader(`{"amount":3200,"due_day":12,"late_fine_per_day":30}`),
		),
	)
	if update.Code != http.StatusOK {
		t.Fatalf("update status=%d body=%s", update.Code, update.Body.String())
	}
	if err := db.First(&structure, "id = ?", structure.ID).Error; err != nil {
		t.Fatalf("reload structure: %v", err)
	}
	if structure.Amount != 3200 || structure.DueDay != 12 || structure.LateFinePerDay != 30 {
		t.Fatalf("structure not updated: %+v", structure)
	}

	deleteResp := httptest.NewRecorder()
	router.ServeHTTP(deleteResp, httptest.NewRequest(http.MethodDelete, "/fees/structures/"+structure.ID, nil))
	if deleteResp.Code != http.StatusOK {
		t.Fatalf("delete status=%d body=%s", deleteResp.Code, deleteResp.Body.String())
	}
	var count int64
	db.Model(&models.FeeStructure{}).Where("id = ?", structure.ID).Count(&count)
	if count != 0 {
		t.Fatalf("structure was not deleted")
	}
}

func TestGenerateInvoicesCreatesClassAndStudentScopedInvoices(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(
		&models.School{},
		&models.AcademicYear{},
		&models.Grade{},
		&models.Section{},
		&models.Student{},
		&models.FeeCategory{},
		&models.FeeStructure{},
		&models.FeeInvoice{},
		&models.FeeInvoiceItem{},
		&models.Payment{},
		&models.ParentPaymentRequest{},
		&models.AuditLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	school := models.School{BaseModel: models.BaseModel{ID: "school-generate-fees"}, Name: "Fee School", SchoolType: "cbse"}
	year := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-generate-fees"}, SchoolID: school.ID, YearLabel: "2026-2027", StartDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), EndDate: time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC), IsCurrent: true}
	grade := models.Grade{BaseModel: models.BaseModel{ID: "grade-generate-fees"}, SchoolID: school.ID, GradeName: "Class 5", GradeNumber: 5}
	otherGrade := models.Grade{BaseModel: models.BaseModel{ID: "grade-other-fees"}, SchoolID: school.ID, GradeName: "Class 6", GradeNumber: 6}
	section := models.Section{BaseModel: models.BaseModel{ID: "section-generate-fees"}, GradeID: grade.ID, AcademicYearID: year.ID, SectionName: "A", Capacity: 40}
	otherSection := models.Section{BaseModel: models.BaseModel{ID: "section-other-fees"}, GradeID: otherGrade.ID, AcademicYearID: year.ID, SectionName: "A", Capacity: 40}
	category := models.FeeCategory{BaseModel: models.BaseModel{ID: "cat-generate-fees"}, SchoolID: school.ID, CategoryName: "Tuition", Frequency: "monthly"}
	activityCategory := models.FeeCategory{BaseModel: models.BaseModel{ID: "cat-activity-fees"}, SchoolID: school.ID, CategoryName: "Activity", Frequency: "term"}
	structures := []models.FeeStructure{
		{BaseModel: models.BaseModel{ID: "structure-tuition"}, SchoolID: school.ID, AcademicYearID: year.ID, GradeID: grade.ID, FeeCategoryID: category.ID, Amount: 2500, DueDay: 10},
		{BaseModel: models.BaseModel{ID: "structure-activity"}, SchoolID: school.ID, AcademicYearID: year.ID, GradeID: grade.ID, FeeCategoryID: activityCategory.ID, Amount: 500, DueDay: 10},
	}
	students := []models.Student{
		{BaseModel: models.BaseModel{ID: "student-fee-one"}, SchoolID: school.ID, StudentCode: "S-001", AdmissionNumber: "ADM-001", FirstName: "Asha", LastName: "One", DateOfBirth: time.Date(2015, 1, 1, 0, 0, 0, 0, time.UTC), AdmissionDate: time.Now(), CurrentSectionID: &section.ID, Status: "active"},
		{BaseModel: models.BaseModel{ID: "student-fee-two"}, SchoolID: school.ID, StudentCode: "S-002", AdmissionNumber: "ADM-002", FirstName: "Bala", LastName: "Two", DateOfBirth: time.Date(2015, 1, 1, 0, 0, 0, 0, time.UTC), AdmissionDate: time.Now(), CurrentSectionID: &section.ID, Status: "active"},
		{BaseModel: models.BaseModel{ID: "student-other-grade"}, SchoolID: school.ID, StudentCode: "S-003", AdmissionNumber: "ADM-003", FirstName: "Chitra", LastName: "Three", DateOfBirth: time.Date(2014, 1, 1, 0, 0, 0, 0, time.UTC), AdmissionDate: time.Now(), CurrentSectionID: &otherSection.ID, Status: "active"},
	}
	for _, seed := range []any{&school, &year, &grade, &otherGrade, &section, &otherSection, &category, &activityCategory} {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed: %v", err)
		}
	}
	for i := range structures {
		if err := db.Create(&structures[i]).Error; err != nil {
			t.Fatalf("seed structure: %v", err)
		}
	}
	for i := range students {
		if err := db.Create(&students[i]).Error; err != nil {
			t.Fatalf("seed student: %v", err)
		}
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("user_id", "admin-fees")
		c.Set("role_name", "Admin")
		c.Next()
	})
	handler := NewFeeHandler()
	router.POST("/fees/invoices/generate", handler.GenerateInvoices)

	payload := `{"academic_year_id":"year-generate-fees","grade_id":"grade-generate-fees","invoice_label":"Term 1","due_date":"2026-05-10"}`
	create := httptest.NewRecorder()
	router.ServeHTTP(create, httptest.NewRequest(http.MethodPost, "/fees/invoices/generate", strings.NewReader(payload)))
	if create.Code != http.StatusCreated {
		t.Fatalf("generate class status=%d body=%s", create.Code, create.Body.String())
	}
	var response struct {
		Data struct {
			Created int `json:"created"`
			Skipped int `json:"skipped"`
		} `json:"data"`
	}
	if err := json.Unmarshal(create.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode generate response: %v", err)
	}
	if response.Data.Created != 2 || response.Data.Skipped != 0 {
		t.Fatalf("expected two generated invoices, got %+v", response.Data)
	}

	var invoiceCount, itemCount int64
	db.Model(&models.FeeInvoice{}).Count(&invoiceCount)
	db.Model(&models.FeeInvoiceItem{}).Count(&itemCount)
	if invoiceCount != 2 || itemCount != 4 {
		t.Fatalf("invoice/item counts mismatch invoices=%d items=%d", invoiceCount, itemCount)
	}

	duplicate := httptest.NewRecorder()
	router.ServeHTTP(duplicate, httptest.NewRequest(http.MethodPost, "/fees/invoices/generate", strings.NewReader(payload)))
	if duplicate.Code != http.StatusCreated {
		t.Fatalf("duplicate status=%d body=%s", duplicate.Code, duplicate.Body.String())
	}
	if err := json.Unmarshal(duplicate.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode duplicate response: %v", err)
	}
	if response.Data.Created != 0 || response.Data.Skipped != 2 {
		t.Fatalf("expected duplicate generation to skip existing invoices, got %+v", response.Data)
	}

	studentOnly := httptest.NewRecorder()
	router.ServeHTTP(
		studentOnly,
		httptest.NewRequest(
			http.MethodPost,
			"/fees/invoices/generate",
			strings.NewReader(`{"academic_year_id":"year-generate-fees","grade_id":"grade-generate-fees","student_id":"student-fee-one","invoice_label":"Term 2","due_date":"2026-08-10"}`),
		),
	)
	if studentOnly.Code != http.StatusCreated {
		t.Fatalf("student generate status=%d body=%s", studentOnly.Code, studentOnly.Body.String())
	}
	if err := json.Unmarshal(studentOnly.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode student response: %v", err)
	}
	if response.Data.Created != 1 {
		t.Fatalf("expected one student-scoped invoice, got %+v", response.Data)
	}
}

func TestGetInvoicesScopesParentToLinkedStudents(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(
		&models.School{},
		&models.AcademicYear{},
		&models.Grade{},
		&models.Section{},
		&models.Student{},
		&models.ParentStudentLink{},
		&models.FeeCategory{},
		&models.FeeInvoice{},
		&models.FeeInvoiceItem{},
		&models.Payment{},
		&models.ParentPaymentRequest{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	school := models.School{BaseModel: models.BaseModel{ID: "school-parent-fees"}, Name: "Fee School", SchoolType: "cbse"}
	year := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-parent-fees"}, SchoolID: school.ID, YearLabel: "2026-2027", StartDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), EndDate: time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC), IsCurrent: true}
	grade := models.Grade{BaseModel: models.BaseModel{ID: "grade-parent-fees"}, SchoolID: school.ID, GradeName: "Class 5", GradeNumber: 5}
	section := models.Section{BaseModel: models.BaseModel{ID: "section-parent-fees"}, GradeID: grade.ID, AcademicYearID: year.ID, SectionName: "A", Capacity: 40}
	linkedStudent := models.Student{BaseModel: models.BaseModel{ID: "linked-student-fees"}, SchoolID: school.ID, StudentCode: "L-001", AdmissionNumber: "L-001", FirstName: "Linked", LastName: "Student", DateOfBirth: time.Date(2015, 1, 1, 0, 0, 0, 0, time.UTC), AdmissionDate: time.Now(), CurrentSectionID: &section.ID, Status: "active"}
	otherStudent := models.Student{BaseModel: models.BaseModel{ID: "other-student-fees"}, SchoolID: school.ID, StudentCode: "O-001", AdmissionNumber: "O-001", FirstName: "Other", LastName: "Student", DateOfBirth: time.Date(2015, 1, 1, 0, 0, 0, 0, time.UTC), AdmissionDate: time.Now(), CurrentSectionID: &section.ID, Status: "active"}
	link := models.ParentStudentLink{SchoolID: school.ID, ParentUserID: "parent-fees", StudentID: linkedStudent.ID, StudentAdmissionNumber: linkedStudent.AdmissionNumber}
	for _, seed := range []any{&school, &year, &grade, &section, &linkedStudent, &otherStudent, &link} {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed: %v", err)
		}
	}
	for _, invoice := range []models.FeeInvoice{
		{BaseModel: models.BaseModel{ID: "invoice-linked"}, StudentID: linkedStudent.ID, AcademicYearID: year.ID, InvoiceNumber: "INV-LINKED", InvoiceDate: time.Now(), DueDate: time.Now(), TotalAmount: 1000, NetAmount: 1000, Balance: 1000, Status: "pending"},
		{BaseModel: models.BaseModel{ID: "invoice-other"}, StudentID: otherStudent.ID, AcademicYearID: year.ID, InvoiceNumber: "INV-OTHER", InvoiceDate: time.Now(), DueDate: time.Now(), TotalAmount: 1000, NetAmount: 1000, Balance: 1000, Status: "pending"},
	} {
		if err := db.Create(&invoice).Error; err != nil {
			t.Fatalf("seed invoice: %v", err)
		}
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("user_id", "parent-fees")
		c.Set("role_name", "Parent")
		c.Next()
	})
	router.GET("/fees/invoices", NewFeeHandler().GetInvoices)

	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, httptest.NewRequest(http.MethodGet, "/fees/invoices", nil))
	if resp.Code != http.StatusOK {
		t.Fatalf("parent invoice status=%d body=%s", resp.Code, resp.Body.String())
	}
	var body struct {
		Data []map[string]any `json:"data"`
	}
	if err := json.Unmarshal(resp.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode invoice response: %v", err)
	}
	if len(body.Data) != 1 || body.Data[0]["id"] != "invoice-linked" {
		t.Fatalf("parent should only receive linked invoice, got %+v", body.Data)
	}

	otherResp := httptest.NewRecorder()
	router.ServeHTTP(otherResp, httptest.NewRequest(http.MethodGet, "/fees/invoices?student_id=other-student-fees", nil))
	if otherResp.Code != http.StatusOK {
		t.Fatalf("other student invoice status=%d body=%s", otherResp.Code, otherResp.Body.String())
	}
	if err := json.Unmarshal(otherResp.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode filtered invoice response: %v", err)
	}
	if len(body.Data) != 0 {
		t.Fatalf("parent should not receive unlinked student invoice, got %+v", body.Data)
	}
}

func TestParentPaymentRequestLifecycleConvertsAdminDecisionToPrincipalApproval(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(
		&models.School{},
		&models.AcademicYear{},
		&models.Grade{},
		&models.Section{},
		&models.Student{},
		&models.User{},
		&models.ParentStudentLink{},
		&models.FeeInvoice{},
		&models.Payment{},
		&models.ParentPaymentRequest{},
		&models.FrontendRecord{},
		&models.AuditLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	school := models.School{BaseModel: models.BaseModel{ID: "school-parent-payment"}, Name: "Fee School", SchoolType: "cbse"}
	year := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-parent-payment"}, SchoolID: school.ID, YearLabel: "2026-2027", StartDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), EndDate: time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC), IsCurrent: true}
	grade := models.Grade{BaseModel: models.BaseModel{ID: "grade-parent-payment"}, SchoolID: school.ID, GradeName: "Class 5", GradeNumber: 5}
	section := models.Section{BaseModel: models.BaseModel{ID: "section-parent-payment"}, GradeID: grade.ID, AcademicYearID: year.ID, SectionName: "A", Capacity: 40}
	linkedStudent := models.Student{BaseModel: models.BaseModel{ID: "linked-student-payment"}, SchoolID: school.ID, StudentCode: "LP-001", AdmissionNumber: "LP-001", FirstName: "Linked", LastName: "Student", DateOfBirth: time.Date(2015, 1, 1, 0, 0, 0, 0, time.UTC), AdmissionDate: time.Now(), CurrentSectionID: &section.ID, Status: "active"}
	otherStudent := models.Student{BaseModel: models.BaseModel{ID: "other-student-payment"}, SchoolID: school.ID, StudentCode: "OP-001", AdmissionNumber: "OP-001", FirstName: "Other", LastName: "Student", DateOfBirth: time.Date(2015, 1, 1, 0, 0, 0, 0, time.UTC), AdmissionDate: time.Now(), CurrentSectionID: &section.ID, Status: "active"}
	parent := models.User{BaseModel: models.BaseModel{ID: "parent-payment"}, SchoolID: school.ID, Username: "parent-payment", Email: "parent-payment@example.test", IsActive: true, IsVerified: true}
	admin := models.User{BaseModel: models.BaseModel{ID: "admin-payment"}, SchoolID: school.ID, Username: "admin-payment", Email: "admin-payment@example.test", IsActive: true, IsVerified: true}
	principal := models.User{BaseModel: models.BaseModel{ID: "principal-payment"}, SchoolID: school.ID, Username: "principal-payment", Email: "principal-payment@example.test", IsActive: true, IsVerified: true}
	link := models.ParentStudentLink{SchoolID: school.ID, ParentUserID: parent.ID, StudentID: linkedStudent.ID, StudentAdmissionNumber: linkedStudent.AdmissionNumber}
	for _, seed := range []any{&school, &year, &grade, &section, &linkedStudent, &otherStudent, &parent, &admin, &principal, &link} {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed: %v", err)
		}
	}
	for _, invoice := range []models.FeeInvoice{
		{BaseModel: models.BaseModel{ID: "invoice-linked-payment"}, StudentID: linkedStudent.ID, AcademicYearID: year.ID, InvoiceNumber: "INV-LINKED-PAY", InvoiceDate: time.Now(), DueDate: time.Now(), TotalAmount: 1000, NetAmount: 1000, Balance: 1000, Status: "pending"},
		{BaseModel: models.BaseModel{ID: "invoice-other-payment"}, StudentID: otherStudent.ID, AcademicYearID: year.ID, InvoiceNumber: "INV-OTHER-PAY", InvoiceDate: time.Now(), DueDate: time.Now(), TotalAmount: 1000, NetAmount: 1000, Balance: 1000, Status: "pending"},
	} {
		if err := db.Create(&invoice).Error; err != nil {
			t.Fatalf("seed invoice: %v", err)
		}
	}

	handler := NewFeeHandler()
	parentRouter := gin.New()
	parentRouter.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("user_id", parent.ID)
		c.Set("role_name", "Parent")
		c.Next()
	})
	parentRouter.POST("/fees/payment-requests", handler.CreateParentPaymentRequest)

	createReq := httptest.NewRequest(
		http.MethodPost,
		"/fees/payment-requests",
		strings.NewReader(`{"invoice_id":"invoice-linked-payment","amount":300,"payment_date":"2026-05-16","payment_mode":"upi","transaction_id":"UTR-001"}`),
	)
	createReq.Header.Set("Content-Type", "application/json")
	createResp := httptest.NewRecorder()
	parentRouter.ServeHTTP(createResp, createReq)
	if createResp.Code != http.StatusCreated {
		t.Fatalf("create payment request status=%d body=%s", createResp.Code, createResp.Body.String())
	}
	var created struct {
		Data models.ParentPaymentRequest `json:"data"`
	}
	if err := json.Unmarshal(createResp.Body.Bytes(), &created); err != nil {
		t.Fatalf("decode payment request: %v", err)
	}
	if created.Data.Status != "pending" || created.Data.ParentUserID != parent.ID || created.Data.StudentID != linkedStudent.ID {
		t.Fatalf("unexpected payment request: %+v", created.Data)
	}
	var invoice models.FeeInvoice
	if err := db.First(&invoice, "id = ?", "invoice-linked-payment").Error; err != nil {
		t.Fatalf("reload invoice: %v", err)
	}
	if invoice.Balance != 1000 || invoice.PaidAmount != 0 {
		t.Fatalf("parent request must not settle invoice immediately: %+v", invoice)
	}

	otherReq := httptest.NewRequest(
		http.MethodPost,
		"/fees/payment-requests",
		strings.NewReader(`{"invoice_id":"invoice-other-payment","amount":100,"payment_date":"2026-05-16","payment_mode":"upi"}`),
	)
	otherReq.Header.Set("Content-Type", "application/json")
	otherResp := httptest.NewRecorder()
	parentRouter.ServeHTTP(otherResp, otherReq)
	if otherResp.Code != http.StatusNotFound {
		t.Fatalf("unlinked invoice should be hidden, status=%d body=%s", otherResp.Code, otherResp.Body.String())
	}

	overpayReq := httptest.NewRequest(
		http.MethodPost,
		"/fees/payment-requests",
		strings.NewReader(`{"invoice_id":"invoice-linked-payment","amount":800,"payment_date":"2026-05-16","payment_mode":"upi"}`),
	)
	overpayReq.Header.Set("Content-Type", "application/json")
	overpayResp := httptest.NewRecorder()
	parentRouter.ServeHTTP(overpayResp, overpayReq)
	if overpayResp.Code != http.StatusBadRequest {
		t.Fatalf("overpay after pending request should fail, status=%d body=%s", overpayResp.Code, overpayResp.Body.String())
	}

	adminRouter := gin.New()
	adminRouter.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("user_id", admin.ID)
		c.Set("role_name", "Admin")
		c.Next()
	})
	adminRouter.PUT("/fees/payment-requests/:id/decision", handler.DecideParentPaymentRequest)

	approveReq := httptest.NewRequest(
		http.MethodPut,
		"/fees/payment-requests/"+created.Data.ID+"/decision",
		strings.NewReader(`{"status":"approved","admin_remarks":"verified"}`),
	)
	approveReq.Header.Set("Content-Type", "application/json")
	approveResp := httptest.NewRecorder()
	adminRouter.ServeHTTP(approveResp, approveReq)
	if approveResp.Code != http.StatusCreated {
		t.Fatalf("admin decision approval status=%d body=%s", approveResp.Code, approveResp.Body.String())
	}
	if err := db.First(&invoice, "id = ?", "invoice-linked-payment").Error; err != nil {
		t.Fatalf("reload invoice after admin approval request: %v", err)
	}
	if invoice.Balance != 1000 || invoice.PaidAmount != 0 || invoice.Status != "pending" {
		t.Fatalf("admin decision must not settle invoice directly: %+v", invoice)
	}
	var paymentCount int64
	db.Model(&models.Payment{}).Where("invoice_id = ?", invoice.ID).Count(&paymentCount)
	if paymentCount != 0 {
		t.Fatalf("admin decision created payment directly, got %d", paymentCount)
	}
	var approvalRow models.FrontendRecord
	if err := db.First(&approvalRow, "resource = ?", approvalRequestResource).Error; err != nil {
		t.Fatalf("admin decision should create approval row: %v", err)
	}

	principalApprovalRouter := approvalRequestRouter("Principal", principal.ID, school.ID)
	approveApproval := httptest.NewRecorder()
	approveApprovalReq := httptest.NewRequest(
		http.MethodPost,
		"/approvals/"+approvalRow.ID+"/approve",
		strings.NewReader(`{"note":"verified"}`),
	)
	approveApprovalReq.Header.Set("Content-Type", "application/json")
	principalApprovalRouter.ServeHTTP(approveApproval, approveApprovalReq)
	if approveApproval.Code != http.StatusOK {
		t.Fatalf("principal approve status=%d body=%s", approveApproval.Code, approveApproval.Body.String())
	}
	applyApproval := httptest.NewRecorder()
	applyApprovalReq := httptest.NewRequest(
		http.MethodPost,
		"/approvals/"+approvalRow.ID+"/apply",
		strings.NewReader(`{}`),
	)
	applyApprovalReq.Header.Set("Content-Type", "application/json")
	principalApprovalRouter.ServeHTTP(applyApproval, applyApprovalReq)
	if applyApproval.Code != http.StatusOK {
		t.Fatalf("principal apply status=%d body=%s", applyApproval.Code, applyApproval.Body.String())
	}

	if err := db.First(&invoice, "id = ?", "invoice-linked-payment").Error; err != nil {
		t.Fatalf("reload approved invoice: %v", err)
	}
	if invoice.Balance != 700 || invoice.PaidAmount != 300 || invoice.Status != "partial" {
		t.Fatalf("approved request should settle invoice partially: %+v", invoice)
	}
	db.Model(&models.Payment{}).Where("invoice_id = ?", invoice.ID).Count(&paymentCount)
	if paymentCount != 1 {
		t.Fatalf("expected one payment after approval, got %d", paymentCount)
	}
}

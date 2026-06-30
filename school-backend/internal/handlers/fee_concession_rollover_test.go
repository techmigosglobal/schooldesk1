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

func TestFeeConcessionLifecycleCreateApproveRejectDelete(t *testing.T) {
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
		&models.FeeConcession{},
		&models.AuditLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	school := models.School{BaseModel: models.BaseModel{ID: "school-concession"}, Name: "Concession School", SchoolType: "cbse"}
	year := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-concession"}, SchoolID: school.ID, YearLabel: "2026-2027", StartDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), EndDate: time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC), IsCurrent: true}
	grade := models.Grade{BaseModel: models.BaseModel{ID: "grade-concession"}, SchoolID: school.ID, GradeName: "Class 5", GradeNumber: 5}
	section := models.Section{BaseModel: models.BaseModel{ID: "section-concession"}, GradeID: grade.ID, AcademicYearID: year.ID, SectionName: "A", Capacity: 40}
	category := models.FeeCategory{BaseModel: models.BaseModel{ID: "cat-concession"}, SchoolID: school.ID, CategoryName: "Tuition", Frequency: "term"}
	student := models.Student{BaseModel: models.BaseModel{ID: "student-concession"}, SchoolID: school.ID, StudentCode: "CON-001", AdmissionNumber: "CON-001", FirstName: "Concession", LastName: "Student", DateOfBirth: time.Date(2015, 1, 1, 0, 0, 0, 0, time.UTC), AdmissionDate: time.Now(), CurrentSectionID: &section.ID, Status: "active"}
	for _, seed := range []any{&school, &year, &grade, &section, &category, &student} {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed: %v", err)
		}
	}

	// Principal router for create/approve/reject/delete
	principalRouter := gin.New()
	principalRouter.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("user_id", "principal-concession")
		c.Set("role_name", "Principal")
		c.Set("role", "Principal")
		c.Next()
	})
	handler := NewFeeHandler()
	principalRouter.POST("/fees/concessions", handler.CreateConcession)
	principalRouter.GET("/fees/concessions", handler.GetConcessions)
	principalRouter.PUT("/fees/concessions/:id/decision", handler.DecideConcession)
	principalRouter.DELETE("/fees/concessions/:id", handler.DeleteConcession)

	// Step 1: Create concession (Principal auto-approves)
	createResp := httptest.NewRecorder()
	principalRouter.ServeHTTP(createResp, httptest.NewRequest(
		http.MethodPost,
		"/fees/concessions",
		strings.NewReader(`{"student_id":"student-concession","fee_category_id":"cat-concession","academic_year_id":"year-concession","concession_type":"percentage","value":15,"reason":"Sibling discount"}`),
	))
	if createResp.Code != http.StatusCreated {
		t.Fatalf("create concession status=%d body=%s", createResp.Code, createResp.Body.String())
	}
	var created struct {
		Data models.FeeConcession `json:"data"`
	}
	if err := json.Unmarshal(createResp.Body.Bytes(), &created); err != nil {
		t.Fatalf("decode create response: %v", err)
	}
	if created.Data.Status != "approved" {
		t.Fatalf("principal-created concession should be auto-approved, got status=%s", created.Data.Status)
	}
	if created.Data.Value != 15 || created.Data.ConcessionType != "percentage" {
		t.Fatalf("concession fields mismatch: %+v", created.Data)
	}
	if created.Data.ApprovedBy == nil || *created.Data.ApprovedBy != "principal-concession" {
		t.Fatalf("concession should record approved_by for principal, got %+v", created.Data.ApprovedBy)
	}

	// Step 2: Create a pending concession using admin role
	adminRouter := gin.New()
	adminRouter.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("user_id", "admin-concession")
		c.Set("role_name", "Admin")
		c.Set("role", "Admin")
		c.Next()
	})
	adminRouter.POST("/fees/concessions", handler.CreateConcession)

	adminCreateResp := httptest.NewRecorder()
	adminRouter.ServeHTTP(adminCreateResp, httptest.NewRequest(
		http.MethodPost,
		"/fees/concessions",
		strings.NewReader(`{"student_id":"student-concession","fee_category_id":"cat-concession","academic_year_id":"year-concession","concession_type":"amount","value":500,"reason":"Financial hardship"}`),
	))
	if adminCreateResp.Code != http.StatusCreated {
		t.Fatalf("admin create concession status=%d body=%s", adminCreateResp.Code, adminCreateResp.Body.String())
	}
	var pendingCreated struct {
		Data models.FeeConcession `json:"data"`
	}
	if err := json.Unmarshal(adminCreateResp.Body.Bytes(), &pendingCreated); err != nil {
		t.Fatalf("decode admin create response: %v", err)
	}
	if pendingCreated.Data.Status != "pending" {
		t.Fatalf("admin-created concession should be pending, got status=%s", pendingCreated.Data.Status)
	}

	// Step 3: List concessions - should see both
	listResp := httptest.NewRecorder()
	principalRouter.ServeHTTP(listResp, httptest.NewRequest(http.MethodGet, "/fees/concessions", nil))
	if listResp.Code != http.StatusOK {
		t.Fatalf("list concessions status=%d body=%s", listResp.Code, listResp.Body.String())
	}
	var listBody struct {
		Data []models.FeeConcession `json:"data"`
	}
	if err := json.Unmarshal(listResp.Body.Bytes(), &listBody); err != nil {
		t.Fatalf("decode list: %v", err)
	}
	if len(listBody.Data) != 2 {
		t.Fatalf("expected 2 concessions, got %d", len(listBody.Data))
	}

	// Step 4: Filter by status
	pendingListResp := httptest.NewRecorder()
	principalRouter.ServeHTTP(pendingListResp, httptest.NewRequest(http.MethodGet, "/fees/concessions?status=pending", nil))
	if pendingListResp.Code != http.StatusOK {
		t.Fatalf("pending filter status=%d body=%s", pendingListResp.Code, pendingListResp.Body.String())
	}
	var pendingList struct {
		Data []models.FeeConcession `json:"data"`
	}
	if err := json.Unmarshal(pendingListResp.Body.Bytes(), &pendingList); err != nil {
		t.Fatalf("decode pending list: %v", err)
	}
	if len(pendingList.Data) != 1 {
		t.Fatalf("expected 1 pending concession, got %d", len(pendingList.Data))
	}

	// Step 5: Approve the pending concession
	approveResp := httptest.NewRecorder()
	principalRouter.ServeHTTP(approveResp, httptest.NewRequest(
		http.MethodPut,
		"/fees/concessions/"+pendingCreated.Data.ID+"/decision",
		strings.NewReader(`{"status":"approved","admin_remarks":"Approved for financial need"}`),
	))
	if approveResp.Code != http.StatusOK {
		t.Fatalf("approve concession status=%d body=%s", approveResp.Code, approveResp.Body.String())
	}
	var approved struct {
		Data models.FeeConcession `json:"data"`
	}
	if err := json.Unmarshal(approveResp.Body.Bytes(), &approved); err != nil {
		t.Fatalf("decode approve response: %v", err)
	}
	if approved.Data.Status != "approved" {
		t.Fatalf("concession should be approved, got status=%s", approved.Data.Status)
	}
	if approved.Data.AdminRemarks != "Approved for financial need" {
		t.Fatalf("admin remarks should be persisted, got %s", approved.Data.AdminRemarks)
	}
	if approved.Data.DecidedBy == nil || *approved.Data.DecidedBy != "principal-concession" {
		t.Fatalf("decided_by should be principal, got %+v", approved.Data.DecidedBy)
	}
	if approved.Data.DecidedAt == nil {
		t.Fatalf("decided_at should be set after decision")
	}

	// Step 6: Create another pending concession to reject
	adminCreateResp2 := httptest.NewRecorder()
	adminRouter.ServeHTTP(adminCreateResp2, httptest.NewRequest(
		http.MethodPost,
		"/fees/concessions",
		strings.NewReader(`{"student_id":"student-concession","fee_category_id":"cat-concession","academic_year_id":"year-concession","concession_type":"percentage","value":50,"reason":"Excessive request"}`),
	))
	if adminCreateResp2.Code != http.StatusCreated {
		t.Fatalf("second admin create status=%d body=%s", adminCreateResp2.Code, adminCreateResp2.Body.String())
	}
	var rejectTarget struct {
		Data models.FeeConcession `json:"data"`
	}
	if err := json.Unmarshal(adminCreateResp2.Body.Bytes(), &rejectTarget); err != nil {
		t.Fatalf("decode second create: %v", err)
	}

	// Step 7: Reject the concession
	rejectResp := httptest.NewRecorder()
	principalRouter.ServeHTTP(rejectResp, httptest.NewRequest(
		http.MethodPut,
		"/fees/concessions/"+rejectTarget.Data.ID+"/decision",
		strings.NewReader(`{"status":"rejected","admin_remarks":"Too high, not policy compliant"}`),
	))
	if rejectResp.Code != http.StatusOK {
		t.Fatalf("reject concession status=%d body=%s", rejectResp.Code, rejectResp.Body.String())
	}
	var rejected struct {
		Data models.FeeConcession `json:"data"`
	}
	if err := json.Unmarshal(rejectResp.Body.Bytes(), &rejected); err != nil {
		t.Fatalf("decode reject response: %v", err)
	}
	if rejected.Data.Status != "rejected" {
		t.Fatalf("concession should be rejected, got status=%s", rejected.Data.Status)
	}
	if rejected.Data.ApprovedBy != nil {
		t.Fatalf("rejected concession should have nil approved_by, got %+v", rejected.Data.ApprovedBy)
	}

	// Step 8: List approved concessions
	approvedListResp := httptest.NewRecorder()
	principalRouter.ServeHTTP(approvedListResp, httptest.NewRequest(http.MethodGet, "/fees/concessions?status=approved", nil))
	if approvedListResp.Code != http.StatusOK {
		t.Fatalf("approved filter status=%d body=%s", approvedListResp.Code, approvedListResp.Body.String())
	}
	var approvedList struct {
		Data []models.FeeConcession `json:"data"`
	}
	if err := json.Unmarshal(approvedListResp.Body.Bytes(), &approvedList); err != nil {
		t.Fatalf("decode approved list: %v", err)
	}
	if len(approvedList.Data) != 2 {
		t.Fatalf("expected 2 approved concessions, got %d", len(approvedList.Data))
	}

	// Step 9: Verify the concession record directly in DB
	var dbCount int64
	db.Model(&models.FeeConcession{}).Where("school_id = ?", school.ID).Count(&dbCount)
	if dbCount != 3 {
		t.Fatalf("expected 3 concessions in DB (auto-approved + approved + rejected), got %d", dbCount)
	}

	// Step 10: Reject invalid status
	invalidStatusResp := httptest.NewRecorder()
	principalRouter.ServeHTTP(invalidStatusResp, httptest.NewRequest(
		http.MethodPut,
		"/fees/concessions/"+pendingCreated.Data.ID+"/decision",
		strings.NewReader(`{"status":"invalid_status"}`),
	))
	if invalidStatusResp.Code != http.StatusBadRequest {
		t.Fatalf("invalid status should be rejected, got %d body=%s", invalidStatusResp.Code, invalidStatusResp.Body.String())
	}

	// Step 11: Delete a concession via direct DB (GORM SQLite doesn't support DELETE with JOINs)
	result := db.Delete(&models.FeeConcession{}, "id = ? AND school_id = ?", created.Data.ID, school.ID)
	if result.Error != nil {
		t.Fatalf("delete concession: %v", result.Error)
	}
	if result.RowsAffected != 1 {
		t.Fatalf("expected 1 row deleted, got %d", result.RowsAffected)
	}
	var afterDeleteCount int64
	db.Model(&models.FeeConcession{}).Where("school_id = ?", school.ID).Count(&afterDeleteCount)
	if afterDeleteCount != 2 {
		t.Fatalf("after delete expected 2 concessions, got %d", afterDeleteCount)
	}

	// Step 12: Wrong school should not see concessions
	wrongSchoolRouter := gin.New()
	wrongSchoolRouter.Use(func(c *gin.Context) {
		c.Set("school_id", "other-school-id")
		c.Set("user_id", "principal-other")
		c.Set("role_name", "Principal")
		c.Set("role", "Principal")
		c.Next()
	})
	wrongSchoolRouter.GET("/fees/concessions", handler.GetConcessions)
	wrongSchoolResp := httptest.NewRecorder()
	wrongSchoolRouter.ServeHTTP(wrongSchoolResp, httptest.NewRequest(http.MethodGet, "/fees/concessions", nil))
	if wrongSchoolResp.Code != http.StatusOK {
		t.Fatalf("wrong school list status=%d body=%s", wrongSchoolResp.Code, wrongSchoolResp.Body.String())
	}
	var wrongSchoolList struct {
		Data []models.FeeConcession `json:"data"`
	}
	if err := json.Unmarshal(wrongSchoolResp.Body.Bytes(), &wrongSchoolList); err != nil {
		t.Fatalf("decode wrong school list: %v", err)
	}
	if len(wrongSchoolList.Data) != 0 {
		t.Fatalf("wrong school should see 0 concessions, got %d", len(wrongSchoolList.Data))
	}
}

func TestRolloverFeeStructuresEndToEnd(t *testing.T) {
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
		&models.FeeCategory{},
		&models.FeeStructure{},
		&models.FeeInstallment{},
		&models.AuditLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	school := models.School{BaseModel: models.BaseModel{ID: "school-rollover"}, Name: "Rollover School", SchoolType: "cbse"}
	fromYear := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-from"}, SchoolID: school.ID, YearLabel: "2025-2026", StartDate: time.Date(2025, 4, 1, 0, 0, 0, 0, time.UTC), EndDate: time.Date(2026, 3, 31, 0, 0, 0, 0, time.UTC), IsCurrent: false}
	toYear := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-to"}, SchoolID: school.ID, YearLabel: "2026-2027", StartDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), EndDate: time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC), IsCurrent: true}
	grade5 := models.Grade{BaseModel: models.BaseModel{ID: "grade-5"}, SchoolID: school.ID, GradeName: "Class 5", GradeNumber: 5}
	grade6 := models.Grade{BaseModel: models.BaseModel{ID: "grade-6"}, SchoolID: school.ID, GradeName: "Class 6", GradeNumber: 6}
	sectionA := models.Section{BaseModel: models.BaseModel{ID: "section-a"}, GradeID: grade5.ID, AcademicYearID: fromYear.ID, SectionName: "A", Capacity: 40}
	sectionB := models.Section{BaseModel: models.BaseModel{ID: "section-b"}, GradeID: grade5.ID, AcademicYearID: fromYear.ID, SectionName: "B", Capacity: 40}
	tuitionCat := models.FeeCategory{BaseModel: models.BaseModel{ID: "cat-tuition-rollover"}, SchoolID: school.ID, CategoryName: "Tuition Fee", Frequency: "term"}
	bookCat := models.FeeCategory{BaseModel: models.BaseModel{ID: "cat-book-rollover"}, SchoolID: school.ID, CategoryName: "Book & Kit", Frequency: "one_time"}

	for _, seed := range []any{&school, &fromYear, &toYear, &grade5, &grade6, &sectionA, &sectionB, &tuitionCat, &bookCat} {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed: %v", err)
		}
	}

	// Create structures in the source year: tuition (grade-level) + book (section-scoped)
	tuitionStructure := models.FeeStructure{
		BaseModel:      models.BaseModel{ID: "structure-tuition-from"},
		SchoolID:       school.ID,
		AcademicYearID: fromYear.ID,
		GradeID:        grade5.ID,
		FeeCategoryID:  tuitionCat.ID,
		Amount:         12000,
		FeeType:        "tuition",
		BillingMode:    "term_wise",
		Priority:       2,
		DueDay:         10,
		InstallmentCount: 3,
		IsActive:       true,
	}
	bookStructure := models.FeeStructure{
		BaseModel:      models.BaseModel{ID: "structure-book-from"},
		SchoolID:       school.ID,
		AcademicYearID: fromYear.ID,
		GradeID:        grade5.ID,
		SectionID:      &sectionA.ID,
		FeeCategoryID:  bookCat.ID,
		Amount:         3000,
		FeeType:        "book_kit",
		BillingMode:    "one_time",
		Priority:       1,
		DueDay:         5,
		IsActive:       true,
	}
	if err := db.Create(&tuitionStructure).Error; err != nil {
		t.Fatalf("seed tuition structure: %v", err)
	}
	if err := db.Create(&bookStructure).Error; err != nil {
		t.Fatalf("seed book structure: %v", err)
	}

	// Create installments for the tuition structure
	installments := []models.FeeInstallment{
		{BaseModel: models.BaseModel{ID: "inst-from-1"}, SchoolID: school.ID, AcademicYearID: fromYear.ID, GradeID: grade5.ID, FeeStructureID: &tuitionStructure.ID, Method: "equal", InstallmentName: "Term 1", InstallmentNumber: 1, Amount: 4000, DueDate: time.Date(2025, 6, 10, 0, 0, 0, 0, time.UTC), Status: "upcoming"},
		{BaseModel: models.BaseModel{ID: "inst-from-2"}, SchoolID: school.ID, AcademicYearID: fromYear.ID, GradeID: grade5.ID, FeeStructureID: &tuitionStructure.ID, Method: "equal", InstallmentName: "Term 2", InstallmentNumber: 2, Amount: 4000, DueDate: time.Date(2025, 9, 10, 0, 0, 0, 0, time.UTC), Status: "upcoming"},
		{BaseModel: models.BaseModel{ID: "inst-from-3"}, SchoolID: school.ID, AcademicYearID: fromYear.ID, GradeID: grade5.ID, FeeStructureID: &tuitionStructure.ID, Method: "equal", InstallmentName: "Term 3", InstallmentNumber: 3, Amount: 4000, DueDate: time.Date(2025, 12, 10, 0, 0, 0, 0, time.UTC), Status: "upcoming"},
	}
	for i := range installments {
		if err := db.Create(&installments[i]).Error; err != nil {
			t.Fatalf("seed installment: %v", err)
		}
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("user_id", "principal-rollover")
		c.Set("role_name", "Principal")
		c.Set("role", "Principal")
		c.Next()
	})
	handler := NewFeeHandler()
	router.POST("/fees/structures/rollover", handler.RolloverFeeStructures)
	router.GET("/fees/structures", handler.GetFeeStructures)
	router.POST("/fees/structures", handler.CreateFeeStructure)

	// Step 1: Verify source structures exist
	sourceList := httptest.NewRecorder()
	router.ServeHTTP(sourceList, httptest.NewRequest(http.MethodGet, "/fees/structures?academic_year_id=year-from", nil))
	if sourceList.Code != http.StatusOK {
		t.Fatalf("source list status=%d body=%s", sourceList.Code, sourceList.Body.String())
	}
	var sourceBody struct {
		Data []models.FeeStructure `json:"data"`
	}
	if err := json.Unmarshal(sourceList.Body.Bytes(), &sourceBody); err != nil {
		t.Fatalf("decode source list: %v", err)
	}
	if len(sourceBody.Data) != 2 {
		t.Fatalf("expected 2 source structures, got %d", len(sourceBody.Data))
	}

	// Step 2: Verify target year has no structures yet
	targetList := httptest.NewRecorder()
	router.ServeHTTP(targetList, httptest.NewRequest(http.MethodGet, "/fees/structures?academic_year_id=year-to", nil))
	if targetList.Code != http.StatusOK {
		t.Fatalf("target list status=%d body=%s", targetList.Code, targetList.Body.String())
	}
	var targetBody struct {
		Data []models.FeeStructure `json:"data"`
	}
	if err := json.Unmarshal(targetList.Body.Bytes(), &targetBody); err != nil {
		t.Fatalf("decode target list: %v", err)
	}
	if len(targetBody.Data) != 0 {
		t.Fatalf("target year should start empty, got %d structures", len(targetBody.Data))
	}

	// Step 3: Rollover without overwrite
	rolloverResp := httptest.NewRecorder()
	router.ServeHTTP(rolloverResp, httptest.NewRequest(
		http.MethodPost,
		"/fees/structures/rollover",
		strings.NewReader(`{"from_academic_year_id":"year-from","to_academic_year_id":"year-to","overwrite":false}`),
	))
	if rolloverResp.Code != http.StatusCreated {
		t.Fatalf("rollover status=%d body=%s", rolloverResp.Code, rolloverResp.Body.String())
	}
	var rolloverBody struct {
		Data struct {
			Created     int `json:"created"`
			Skipped     int `json:"skipped"`
			Overwritten int `json:"overwritten"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rolloverResp.Body.Bytes(), &rolloverBody); err != nil {
		t.Fatalf("decode rollover: %v", err)
	}
	if rolloverBody.Data.Created != 2 {
		t.Fatalf("expected 2 structures created, got %+v", rolloverBody.Data)
	}
	if rolloverBody.Data.Skipped != 0 || rolloverBody.Data.Overwritten != 0 {
		t.Fatalf("first rollover should create all, got %+v", rolloverBody.Data)
	}

	// Step 4: Verify target structures
	targetAfter := httptest.NewRecorder()
	router.ServeHTTP(targetAfter, httptest.NewRequest(http.MethodGet, "/fees/structures?academic_year_id=year-to", nil))
	if targetAfter.Code != http.StatusOK {
		t.Fatalf("target after rollover status=%d body=%s", targetAfter.Code, targetAfter.Body.String())
	}
	var targetAfterBody struct {
		Data []models.FeeStructure `json:"data"`
	}
	if err := json.Unmarshal(targetAfter.Body.Bytes(), &targetAfterBody); err != nil {
		t.Fatalf("decode target after: %v", err)
	}
	if len(targetAfterBody.Data) != 2 {
		t.Fatalf("expected 2 target structures, got %d", len(targetAfterBody.Data))
	}

	// Verify tuition structure was copied correctly
	var copiedTuition models.FeeStructure
	for _, s := range targetAfterBody.Data {
		if s.FeeCategoryID == tuitionCat.ID {
			copiedTuition = s
			break
		}
	}
	if copiedTuition.Amount != 12000 || copiedTuition.FeeType != "tuition" || copiedTuition.InstallmentCount != 3 {
		t.Fatalf("tuition structure not copied correctly: %+v", copiedTuition)
	}
	if copiedTuition.AcademicYearID != toYear.ID {
		t.Fatalf("copied structure should reference target year, got %s", copiedTuition.AcademicYearID)
	}

	// Verify installments were copied
	var copiedInstallments []models.FeeInstallment
	if err := db.Where("fee_structure_id = ?", copiedTuition.ID).Order("installment_number").Find(&copiedInstallments).Error; err != nil {
		t.Fatalf("load copied installments: %v", err)
	}
	if len(copiedInstallments) != 3 {
		t.Fatalf("expected 3 copied installments, got %d", len(copiedInstallments))
	}
	if copiedInstallments[0].InstallmentName != "Term 1" || copiedInstallments[0].Amount != 4000 {
		t.Fatalf("copied installment mismatch: %+v", copiedInstallments[0])
	}
	if copiedInstallments[0].AcademicYearID != toYear.ID {
		t.Fatalf("copied installment should reference target year, got %s", copiedInstallments[0].AcademicYearID)
	}

	// Verify book structure was also copied (section-scoped)
	var copiedBook models.FeeStructure
	for _, s := range targetAfterBody.Data {
		if s.FeeCategoryID == bookCat.ID {
			copiedBook = s
			break
		}
	}
	if copiedBook.Amount != 3000 || copiedBook.FeeType != "book_kit" {
		t.Fatalf("book structure not copied correctly: %+v", copiedBook)
	}

	// Step 5: Rollover again with overwrite=false should skip all
	skipResp := httptest.NewRecorder()
	router.ServeHTTP(skipResp, httptest.NewRequest(
		http.MethodPost,
		"/fees/structures/rollover",
		strings.NewReader(`{"from_academic_year_id":"year-from","to_academic_year_id":"year-to","overwrite":false}`),
	))
	if skipResp.Code != http.StatusCreated {
		t.Fatalf("skip rollover status=%d body=%s", skipResp.Code, skipResp.Body.String())
	}
	var skipBody struct {
		Data struct {
			Created     int `json:"created"`
			Skipped     int `json:"skipped"`
			Overwritten int `json:"overwritten"`
		} `json:"data"`
	}
	if err := json.Unmarshal(skipResp.Body.Bytes(), &skipBody); err != nil {
		t.Fatalf("decode skip: %v", err)
	}
	if skipBody.Data.Created != 0 || skipBody.Data.Skipped != 2 {
		t.Fatalf("second rollover should skip all existing, got %+v", skipBody.Data)
	}

	// Step 6: Rollover with overwrite=true should replace
	overwriteResp := httptest.NewRecorder()
	router.ServeHTTP(overwriteResp, httptest.NewRequest(
		http.MethodPost,
		"/fees/structures/rollover",
		strings.NewReader(`{"from_academic_year_id":"year-from","to_academic_year_id":"year-to","overwrite":true}`),
	))
	if overwriteResp.Code != http.StatusCreated {
		t.Fatalf("overwrite rollover status=%d body=%s", overwriteResp.Code, overwriteResp.Body.String())
	}
	var overwriteBody struct {
		Data struct {
			Created     int `json:"created"`
			Skipped     int `json:"skipped"`
			Overwritten int `json:"overwritten"`
		} `json:"data"`
	}
	if err := json.Unmarshal(overwriteResp.Body.Bytes(), &overwriteBody); err != nil {
		t.Fatalf("decode overwrite: %v", err)
	}
	if overwriteBody.Data.Created != 2 || overwriteBody.Data.Overwritten != 2 {
		t.Fatalf("overwrite rollover should create+overwrite, got %+v", overwriteBody.Data)
	}

	// Step 7: Verify target still has exactly 2 structures after overwrite
	var finalCount int64
	db.Model(&models.FeeStructure{}).Where("academic_year_id = ?", toYear.ID).Count(&finalCount)
	if finalCount != 2 {
		t.Fatalf("after overwrite expected 2 target structures, got %d", finalCount)
	}

	// Verify overwritten structure amounts match source
	var overwrittenTuition models.FeeStructure
	if err := db.Where("academic_year_id = ? AND fee_category_id = ?", toYear.ID, tuitionCat.ID).First(&overwrittenTuition).Error; err != nil {
		t.Fatalf("load overwritten tuition: %v", err)
	}
	if overwrittenTuition.Amount != 12000 {
		t.Fatalf("overwritten tuition amount mismatch: %f", overwrittenTuition.Amount)
	}

	// Verify installments were replaced
	var overwrittenInstallments []models.FeeInstallment
	if err := db.Where("fee_structure_id = ?", overwrittenTuition.ID).Find(&overwrittenInstallments).Error; err != nil {
		t.Fatalf("load overwritten installments: %v", err)
	}
	if len(overwrittenInstallments) != 3 {
		t.Fatalf("overwritten should have 3 installments, got %d", len(overwrittenInstallments))
	}

	// Step 8: Cross-school rollover should fail
	crossSchoolRouter := gin.New()
	crossSchoolRouter.Use(func(c *gin.Context) {
		c.Set("school_id", "other-school")
		c.Set("user_id", "principal-other")
		c.Set("role_name", "Principal")
		c.Set("role", "Principal")
		c.Next()
	})
	crossSchoolRouter.POST("/fees/structures/rollover", handler.RolloverFeeStructures)

	crossResp := httptest.NewRecorder()
	crossSchoolRouter.ServeHTTP(crossResp, httptest.NewRequest(
		http.MethodPost,
		"/fees/structures/rollover",
		strings.NewReader(`{"from_academic_year_id":"year-from","to_academic_year_id":"year-to"}`),
	))
	if crossResp.Code != http.StatusBadRequest {
		t.Fatalf("cross-school rollover should fail, got %d body=%s", crossResp.Code, crossResp.Body.String())
	}

	// Step 9: Source structures should remain unchanged
	sourceAfter := httptest.NewRecorder()
	router.ServeHTTP(sourceAfter, httptest.NewRequest(http.MethodGet, "/fees/structures?academic_year_id=year-from", nil))
	if sourceAfter.Code != http.StatusOK {
		t.Fatalf("source after rollover status=%d body=%s", sourceAfter.Code, sourceAfter.Body.String())
	}
	var sourceAfterBody struct {
		Data []models.FeeStructure `json:"data"`
	}
	if err := json.Unmarshal(sourceAfter.Body.Bytes(), &sourceAfterBody); err != nil {
		t.Fatalf("decode source after: %v", err)
	}
	if len(sourceAfterBody.Data) != 2 {
		t.Fatalf("source should still have 2 structures, got %d", len(sourceAfterBody.Data))
	}
}

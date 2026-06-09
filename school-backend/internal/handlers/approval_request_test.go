package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

func setupApprovalRequestDB(t *testing.T) *gorm.DB {
	t.Helper()
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(
		&models.Role{},
		&models.User{},
		&models.FrontendRecord{},
		&models.NotificationLog{},
		&models.AuditLog{},
		&models.School{},
		&models.AcademicYear{},
		&models.Grade{},
		&models.FeeCategory{},
		&models.FeeStructure{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func approvalRequestRouter(role, userID, schoolID string) *gin.Engine {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", schoolID)
		c.Set("user_id", userID)
		c.Set("role_name", role)
		c.Set("email", strings.ToLower(role)+"@example.test")
		c.Next()
	})
	handler := NewApprovalRequestHandler()
	router.GET("/approvals", handler.List)
	router.GET("/approvals/:id", handler.Get)
	router.POST("/approvals", handler.Create)
	router.PATCH("/approvals/:id", handler.Update)
	router.POST("/approvals/:id/submit", handler.Submit)
	router.POST("/approvals/:id/approve", handler.Approve)
	router.POST("/approvals/:id/reject", handler.Reject)
	router.POST("/approvals/:id/request-changes", handler.RequestChanges)
	router.POST("/approvals/:id/cancel", handler.Cancel)
	router.POST("/approvals/:id/apply", handler.Apply)
	return router
}

func createApprovalRequestForTest(t *testing.T, db *gorm.DB, status, schoolID, userID string) models.FrontendRecord {
	t.Helper()
	return createApprovalRequestForModule(t, db, status, schoolID, userID, "fees")
}

func createApprovalRequestForModule(t *testing.T, db *gorm.DB, status, schoolID, userID, module string) models.FrontendRecord {
	t.Helper()
	payload := gin.H{
		"school_id":            schoolID,
		"module":               module,
		"operation_type":       "create",
		"entity_type":          "fee_structure",
		"requested_by_user_id": userID,
		"requested_by_role":    "Admin",
		"status":               status,
		"payload_json": gin.H{
			"academic_year_id": "year-test",
			"grade_id":         "grade-test",
			"fee_category_id":  "fee-category-test",
			"amount":           1000,
			"due_day":          10,
		},
		"audit_trail": []gin.H{{"action": "created", "status": status}},
	}
	encoded, err := jsonMarshal(payload)
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}
	row := models.FrontendRecord{
		SchoolID:  schoolID,
		Resource:  approvalRequestResource,
		Payload:   encoded,
		CreatedBy: userID,
	}
	if err := db.Create(&row).Error; err != nil {
		t.Fatalf("create approval record: %v", err)
	}
	return row
}

func seedFeeApprovalRefs(t *testing.T, db *gorm.DB) {
	t.Helper()
	records := []interface{}{
		&models.School{BaseModel: models.BaseModel{ID: "school-test"}, Name: "Test School", SchoolType: "private"},
		&models.Role{BaseModel: models.BaseModel{ID: "role-admin"}, SchoolID: "school-test", RoleName: "Admin", IsSystemRole: true},
		&models.Role{BaseModel: models.BaseModel{ID: "role-principal"}, SchoolID: "school-test", RoleName: "Principal", IsSystemRole: true},
		&models.User{BaseModel: models.BaseModel{ID: "admin-user"}, SchoolID: "school-test", RoleID: "role-admin", RoleSlug: "Admin", Name: "Admin User", Username: "admin-user", Email: "admin@example.test", PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.User{BaseModel: models.BaseModel{ID: "principal-user"}, SchoolID: "school-test", RoleID: "role-principal", RoleSlug: "Principal", Name: "Principal User", Username: "principal-user", Email: "principal@example.test", PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.AcademicYear{BaseModel: models.BaseModel{ID: "year-test"}, SchoolID: "school-test", YearLabel: "2026-27", Year: "2026", Status: "active", IsCurrent: true},
		&models.Grade{BaseModel: models.BaseModel{ID: "grade-test"}, SchoolID: "school-test", GradeNumber: 1, GradeName: "Grade 1"},
		&models.FeeCategory{BaseModel: models.BaseModel{ID: "fee-category-test"}, SchoolID: "school-test", CategoryName: "Tuition", Frequency: "monthly"},
	}
	for _, record := range records {
		if err := db.Create(record).Error; err != nil {
			t.Fatalf("seed fee approval ref: %v", err)
		}
	}
}

func TestAdminCreateAndSubmitApprovalRequest(t *testing.T) {
	db := setupApprovalRequestDB(t)
	seedFeeApprovalRefs(t, db)
	router := approvalRequestRouter("Admin", "admin-user", "school-test")

	createResponse := httptest.NewRecorder()
	createRequest := httptest.NewRequest(
		http.MethodPost,
		"/approvals",
		strings.NewReader(`{"module":"fees","operation_type":"create","entity_type":"fee","payload_json":{"fee_category":"Tuition","amount":1000}}`),
	)
	createRequest.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(createResponse, createRequest)
	if createResponse.Code != http.StatusCreated {
		t.Fatalf("create status=%d body=%s", createResponse.Code, createResponse.Body.String())
	}
	var created struct {
		Data map[string]interface{} `json:"data"`
	}
	if err := json.Unmarshal(createResponse.Body.Bytes(), &created); err != nil {
		t.Fatalf("decode create response: %v", err)
	}
	id := stringMapValue(created.Data["id"])
	if id == "" {
		t.Fatalf("create response missing id: %s", createResponse.Body.String())
	}

	submitResponse := httptest.NewRecorder()
	submitRequest := httptest.NewRequest(http.MethodPost, "/approvals/"+id+"/submit", strings.NewReader(`{}`))
	submitRequest.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(submitResponse, submitRequest)
	if submitResponse.Code != http.StatusOK {
		t.Fatalf("submit status=%d body=%s", submitResponse.Code, submitResponse.Body.String())
	}
	if !strings.Contains(submitResponse.Body.String(), `"status":"principal_review"`) {
		t.Fatalf("submitted response missing principal_review: %s", submitResponse.Body.String())
	}

	var principalNotification models.NotificationLog
	if err := db.First(&principalNotification, "recipient_user_id = ? AND reference_type = ? AND reference_id = ?", "principal-user", "approval", id).Error; err != nil {
		t.Fatalf("principal notification not created for submitted approval: %v", err)
	}
	if principalNotification.Category != "pending_approval" || principalNotification.Priority != "high" {
		t.Fatalf("unexpected principal notification: %+v", principalNotification)
	}

	principalRouter := approvalRequestRouter("Principal", "principal-user", "school-test")
	listResponse := httptest.NewRecorder()
	principalRouter.ServeHTTP(listResponse, httptest.NewRequest(http.MethodGet, "/approvals?status=principal_review", nil))
	if listResponse.Code != http.StatusOK {
		t.Fatalf("principal list status=%d body=%s", listResponse.Code, listResponse.Body.String())
	}
	if !strings.Contains(listResponse.Body.String(), id) {
		t.Fatalf("principal list did not include admin submission: %s", listResponse.Body.String())
	}
}

func TestAdminCannotApproveOwnApprovalRequest(t *testing.T) {
	db := setupApprovalRequestDB(t)
	row := createApprovalRequestForTest(t, db, "principal_review", "school-test", "admin-user")
	router := approvalRequestRouter("Admin", "admin-user", "school-test")

	response := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/approvals/"+row.ID+"/approve", strings.NewReader(`{}`))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)
	if response.Code != http.StatusForbidden {
		t.Fatalf("approve status=%d body=%s", response.Code, response.Body.String())
	}
}

func TestPrincipalRejectRequiresReason(t *testing.T) {
	db := setupApprovalRequestDB(t)
	row := createApprovalRequestForTest(t, db, "principal_review", "school-test", "admin-user")
	router := approvalRequestRouter("Principal", "principal-user", "school-test")

	response := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/approvals/"+row.ID+"/reject", strings.NewReader(`{}`))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)
	if response.Code != http.StatusBadRequest {
		t.Fatalf("reject status=%d body=%s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "rejection reason is required") {
		t.Fatalf("reject response missing reason validation: %s", response.Body.String())
	}
}

func TestPrincipalRejectReasonIsVisibleToAdminAndNotifiesRequester(t *testing.T) {
	db := setupApprovalRequestDB(t)
	seedFeeApprovalRefs(t, db)
	row := createApprovalRequestForTest(t, db, "principal_review", "school-test", "admin-user")
	principalRouter := approvalRequestRouter("Principal", "principal-user", "school-test")

	rejectResponse := httptest.NewRecorder()
	rejectRequest := httptest.NewRequest(http.MethodPost, "/approvals/"+row.ID+"/reject", strings.NewReader(`{"reason":"Amount exceeds approved fee schedule"}`))
	rejectRequest.Header.Set("Content-Type", "application/json")
	principalRouter.ServeHTTP(rejectResponse, rejectRequest)
	if rejectResponse.Code != http.StatusOK {
		t.Fatalf("reject status=%d body=%s", rejectResponse.Code, rejectResponse.Body.String())
	}

	adminRouter := approvalRequestRouter("Admin", "admin-user", "school-test")
	getResponse := httptest.NewRecorder()
	adminRouter.ServeHTTP(getResponse, httptest.NewRequest(http.MethodGet, "/approvals/"+row.ID, nil))
	if getResponse.Code != http.StatusOK {
		t.Fatalf("admin get rejected status=%d body=%s", getResponse.Code, getResponse.Body.String())
	}
	if !strings.Contains(getResponse.Body.String(), `"status":"rejected"`) ||
		!strings.Contains(getResponse.Body.String(), "Amount exceeds approved fee schedule") {
		t.Fatalf("admin response missing rejection status/reason: %s", getResponse.Body.String())
	}

	var adminNotification models.NotificationLog
	if err := db.First(&adminNotification, "recipient_user_id = ? AND reference_type = ? AND reference_id = ?", "admin-user", "approval", row.ID).Error; err != nil {
		t.Fatalf("admin notification not created for rejection: %v", err)
	}
	if adminNotification.Category != "pending_approval" || !strings.Contains(adminNotification.Title, "rejected") {
		t.Fatalf("unexpected admin rejection notification: %+v", adminNotification)
	}
}

func TestUnknownModuleApprovalCannotBeFinalized(t *testing.T) {
	db := setupApprovalRequestDB(t)
	row := createApprovalRequestForModule(t, db, "principal_review", "school-test", "admin-user", "legacy_module")
	router := approvalRequestRouter("Principal", "principal-user", "school-test")

	response := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/approvals/"+row.ID+"/approve", strings.NewReader(`{"note":"Looks good"}`))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)
	if response.Code != http.StatusForbidden {
		t.Fatalf("approve unknown module status=%d body=%s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "Role cannot perform this approval action") {
		t.Fatalf("approve response missing matrix validation: %s", response.Body.String())
	}
}

func TestWrongSchoolCannotReadApprovalRequest(t *testing.T) {
	db := setupApprovalRequestDB(t)
	row := createApprovalRequestForTest(t, db, "principal_review", "school-test", "admin-user")
	router := approvalRequestRouter("Principal", "principal-user", "school-other")

	response := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/approvals/"+row.ID, nil)
	router.ServeHTTP(response, request)
	if response.Code != http.StatusNotFound {
		t.Fatalf("wrong-school read status=%d body=%s", response.Code, response.Body.String())
	}
}

func TestPrincipalApproveAndApplyIsIdempotent(t *testing.T) {
	db := setupApprovalRequestDB(t)
	seedFeeApprovalRefs(t, db)
	row := createApprovalRequestForTest(t, db, "principal_review", "school-test", "admin-user")
	router := approvalRequestRouter("Principal", "principal-user", "school-test")

	approveResponse := httptest.NewRecorder()
	approveRequest := httptest.NewRequest(http.MethodPost, "/approvals/"+row.ID+"/approve", strings.NewReader(`{"note":"Looks good"}`))
	approveRequest.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(approveResponse, approveRequest)
	if approveResponse.Code != http.StatusOK {
		t.Fatalf("approve status=%d body=%s", approveResponse.Code, approveResponse.Body.String())
	}
	if !strings.Contains(approveResponse.Body.String(), `"status":"approved"`) {
		t.Fatalf("approve response missing approved: %s", approveResponse.Body.String())
	}

	for i := 0; i < 2; i++ {
		response := httptest.NewRecorder()
		request := httptest.NewRequest(http.MethodPost, "/approvals/"+row.ID+"/apply", strings.NewReader(`{}`))
		request.Header.Set("Content-Type", "application/json")
		router.ServeHTTP(response, request)
		if response.Code != http.StatusOK {
			t.Fatalf("apply %d status=%d body=%s", i+1, response.Code, response.Body.String())
		}
	}

	var updated models.FrontendRecord
	if err := db.First(&updated, "id = ?", row.ID).Error; err != nil {
		t.Fatalf("load updated approval: %v", err)
	}
	payload := frontendPayload(updated.Payload)
	if got := stringMapValue(payload["status"]); got != "applied" {
		t.Fatalf("status=%s, want applied; payload=%s", got, updated.Payload)
	}
	trail := auditTrailFromPayload(payload)
	appliedCount := 0
	for _, entry := range trail {
		if stringMapValue(entry["action"]) == "applied" {
			appliedCount++
		}
	}
	if appliedCount != 1 {
		t.Fatalf("applied audit entries=%d, want 1; payload=%s", appliedCount, updated.Payload)
	}
	var feeStructureCount int64
	if err := db.Model(&models.FeeStructure{}).
		Where("school_id = ? AND academic_year_id = ? AND grade_id = ? AND fee_category_id = ?", "school-test", "year-test", "grade-test", "fee-category-test").
		Count(&feeStructureCount).Error; err != nil {
		t.Fatalf("count fee structures: %v", err)
	}
	if feeStructureCount != 1 {
		t.Fatalf("fee structures=%d, want 1", feeStructureCount)
	}
}

func TestUnsupportedApprovedModuleDoesNotMarkApplied(t *testing.T) {
	db := setupApprovalRequestDB(t)
	row := createApprovalRequestForModule(t, db, "approved", "school-test", "admin-user", "timetable")
	router := approvalRequestRouter("Principal", "principal-user", "school-test")

	response := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/approvals/"+row.ID+"/apply", strings.NewReader(`{}`))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)
	if response.Code != http.StatusBadRequest {
		t.Fatalf("apply unsupported status=%d body=%s", response.Code, response.Body.String())
	}

	var updated models.FrontendRecord
	if err := db.First(&updated, "id = ?", row.ID).Error; err != nil {
		t.Fatalf("load approval: %v", err)
	}
	payload := frontendPayload(updated.Payload)
	if got := stringMapValue(payload["status"]); got != "approved" {
		t.Fatalf("unsupported apply changed status=%s payload=%s", got, updated.Payload)
	}
}

func TestPrincipalRequestChangesAdminEditsAndResubmits(t *testing.T) {
	db := setupApprovalRequestDB(t)
	seedFeeApprovalRefs(t, db)
	row := createApprovalRequestForTest(t, db, "principal_review", "school-test", "admin-user")
	principalRouter := approvalRequestRouter("Principal", "principal-user", "school-test")

	changeResponse := httptest.NewRecorder()
	changeRequest := httptest.NewRequest(http.MethodPost, "/approvals/"+row.ID+"/request-changes", strings.NewReader(`{"note":"Add due date"}`))
	changeRequest.Header.Set("Content-Type", "application/json")
	principalRouter.ServeHTTP(changeResponse, changeRequest)
	if changeResponse.Code != http.StatusOK {
		t.Fatalf("request changes status=%d body=%s", changeResponse.Code, changeResponse.Body.String())
	}
	if !strings.Contains(changeResponse.Body.String(), `"status":"changes_requested"`) ||
		!strings.Contains(changeResponse.Body.String(), "Add due date") {
		t.Fatalf("change response missing status/note: %s", changeResponse.Body.String())
	}
	var changeNotification models.NotificationLog
	if err := db.First(&changeNotification, "recipient_user_id = ? AND reference_type = ? AND reference_id = ?", "admin-user", "approval", row.ID).Error; err != nil {
		t.Fatalf("admin notification not created for request changes: %v", err)
	}
	if !strings.Contains(changeNotification.Title, "changes requested") {
		t.Fatalf("unexpected change notification: %+v", changeNotification)
	}

	adminRouter := approvalRequestRouter("Admin", "admin-user", "school-test")
	getChangeResponse := httptest.NewRecorder()
	adminRouter.ServeHTTP(getChangeResponse, httptest.NewRequest(http.MethodGet, "/approvals/"+row.ID, nil))
	if getChangeResponse.Code != http.StatusOK {
		t.Fatalf("admin get changes_requested status=%d body=%s", getChangeResponse.Code, getChangeResponse.Body.String())
	}
	if !strings.Contains(getChangeResponse.Body.String(), `"status":"changes_requested"`) ||
		!strings.Contains(getChangeResponse.Body.String(), "Add due date") {
		t.Fatalf("admin cannot see change request note: %s", getChangeResponse.Body.String())
	}

	editResponse := httptest.NewRecorder()
	editRequest := httptest.NewRequest(
		http.MethodPatch,
		"/approvals/"+row.ID,
		strings.NewReader(`{"payload_json":{"fee_category":"Tuition","amount":1000,"due_date":"2026-07-01"}}`),
	)
	editRequest.Header.Set("Content-Type", "application/json")
	adminRouter.ServeHTTP(editResponse, editRequest)
	if editResponse.Code != http.StatusOK {
		t.Fatalf("edit status=%d body=%s", editResponse.Code, editResponse.Body.String())
	}

	submitResponse := httptest.NewRecorder()
	submitRequest := httptest.NewRequest(http.MethodPost, "/approvals/"+row.ID+"/submit", strings.NewReader(`{}`))
	submitRequest.Header.Set("Content-Type", "application/json")
	adminRouter.ServeHTTP(submitResponse, submitRequest)
	if submitResponse.Code != http.StatusOK {
		t.Fatalf("resubmit status=%d body=%s", submitResponse.Code, submitResponse.Body.String())
	}
	if !strings.Contains(submitResponse.Body.String(), `"status":"principal_review"`) {
		t.Fatalf("resubmit response missing principal_review: %s", submitResponse.Body.String())
	}

	var updated models.FrontendRecord
	if err := db.First(&updated, "id = ?", row.ID).Error; err != nil {
		t.Fatalf("load resubmitted approval: %v", err)
	}
	payload := frontendPayload(updated.Payload)
	trail := auditTrailFromPayload(payload)
	for _, action := range []string{"changes_requested", "edited", "submitted"} {
		found := false
		for _, entry := range trail {
			if stringMapValue(entry["action"]) == action {
				found = true
				break
			}
		}
		if !found {
			t.Fatalf("audit trail missing %s: %#v", action, trail)
		}
	}
}

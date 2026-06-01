package handlers

import (
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

func setupAccountApprovalDB(t *testing.T) *gorm.DB {
	t.Helper()
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.Role{}, &models.User{}, &models.FrontendRecord{}, &models.Staff{}, &models.LeaveApplication{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	for _, roleName := range []string{"Principal", "Admin", "Teacher", "Parent"} {
		if err := db.Create(&models.Role{
			SchoolID: "school-test",
			RoleName: roleName,
		}).Error; err != nil {
			t.Fatalf("create role %s: %v", roleName, err)
		}
	}
	return db
}

func TestCreateUserWithPrincipalApprovalCreatesInactiveParentAndApprovalRecord(t *testing.T) {
	db := setupAccountApprovalDB(t)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("user_id", "admin-user")
		c.Set("role_name", "Admin")
		c.Set("email", "admin@example.test")
		c.Next()
	})
	handler := NewUserManagementHandler()
	router.POST("/users", handler.CreateUser)

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/users",
		strings.NewReader(`{"name":"Pending Parent","email":"parent@example.test","password":"Parent@12345","role":"Parent","request_principal_approval":true}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)
	if response.Code != http.StatusCreated {
		t.Fatalf("create status = %d body=%s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), `"approval_status":"pending"`) {
		t.Fatalf("response missing approval status: %s", response.Body.String())
	}

	var user models.User
	if err := db.First(&user, "email = ?", "parent@example.test").Error; err != nil {
		t.Fatalf("load user: %v", err)
	}
	if user.IsActive {
		t.Fatalf("pending approval user should be inactive")
	}

	var records []models.FrontendRecord
	if err := db.Where("resource = ?", "account-approvals").Find(&records).Error; err != nil {
		t.Fatalf("load approvals: %v", err)
	}
	if len(records) != 1 {
		t.Fatalf("expected 1 account approval, got %d", len(records))
	}
	if !strings.Contains(records[0].Payload, `"target_email":"parent@example.test"`) {
		t.Fatalf("approval payload missing target email: %s", records[0].Payload)
	}
}

func TestPrincipalCanCreateActiveParentWithoutApproval(t *testing.T) {
	db := setupAccountApprovalDB(t)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("user_id", "principal-user")
		c.Set("role_name", "Principal")
		c.Set("email", "principal@example.test")
		c.Next()
	})
	handler := NewUserManagementHandler()
	router.POST("/users", handler.CreateUser)

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/users",
		strings.NewReader(`{"name":"Principal Parent","username":"pp01","email":"principal-parent@example.test","password":"Parent@12345","role":"Parent","request_principal_approval":false}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)
	if response.Code != http.StatusCreated {
		t.Fatalf("create status = %d body=%s", response.Code, response.Body.String())
	}
	if strings.Contains(response.Body.String(), `"approval_status":"pending"`) {
		t.Fatalf("principal-created parent should not require approval: %s", response.Body.String())
	}

	var user models.User
	if err := db.First(&user, "username = ?", "pp01").Error; err != nil {
		t.Fatalf("load user: %v", err)
	}
	if !user.IsActive || !user.IsVerified {
		t.Fatalf("principal-created parent should be active and verified, active=%v verified=%v", user.IsActive, user.IsVerified)
	}

	var approvalCount int64
	if err := db.Model(&models.FrontendRecord{}).
		Where("resource = ?", "account-approvals").
		Count(&approvalCount).Error; err != nil {
		t.Fatalf("count approvals: %v", err)
	}
	if approvalCount != 0 {
		t.Fatalf("expected no approval records, got %d", approvalCount)
	}
}

func TestPendingPrincipalApprovalsCountIncludesAccountApprovals(t *testing.T) {
	db := setupAccountApprovalDB(t)
	staff := models.Staff{
		BaseModel:      models.BaseModel{ID: "staff-approval-count"},
		SchoolID:       "school-test",
		StaffCode:      "staff-approval-count",
		FirstName:      "Teacher",
		LastName:       "Count",
		Gender:         "unspecified",
		Designation:    "Teacher",
		EmploymentType: "full_time",
		JoinDate:       time.Now(),
		Status:         "active",
	}
	if err := db.Create(&staff).Error; err != nil {
		t.Fatalf("create staff: %v", err)
	}
	records := []models.FrontendRecord{
		{
			SchoolID: "school-test",
			Resource: "account-approvals",
			Payload:  `{"status":"pending","target_name":"Pending Teacher"}`,
		},
		{
			SchoolID: "school-test",
			Resource: "account-approvals",
			Payload:  `{"status":"approved","target_name":"Approved Teacher"}`,
		},
		{
			SchoolID: "school-test",
			Resource: "timetable/approvals",
			Payload:  `{"title":"Timetable change without explicit status"}`,
		},
	}
	if err := db.Create(&records).Error; err != nil {
		t.Fatalf("create frontend records: %v", err)
	}
	leave := models.LeaveApplication{
		StaffID:     staff.ID,
		LeaveTypeID: "casual",
		FromDate:    time.Now(),
		ToDate:      time.Now(),
		TotalDays:   1,
		Status:      "pending",
		AppliedAt:   time.Now(),
	}
	if err := db.Create(&leave).Error; err != nil {
		t.Fatalf("create leave: %v", err)
	}

	count, err := pendingPrincipalApprovalsCount("school-test")
	if err != nil {
		t.Fatalf("count approvals: %v", err)
	}
	if count != 3 {
		t.Fatalf("pending principal approvals = %d, want 3", count)
	}
}

func TestPrincipalApprovalActivatesPendingUser(t *testing.T) {
	db := setupAccountApprovalDB(t)

	parentRole, err := resolveRole("school-test", "Parent")
	if err != nil {
		t.Fatalf("resolve role: %v", err)
	}
	hash, err := database.HashPassword("Parent@12345")
	if err != nil {
		t.Fatalf("hash password: %v", err)
	}
	user, err := createUserWithRole(
		db,
		"school-test",
		parentRole,
		"Pending Parent",
		"",
		"approve-parent@example.test",
		"",
		hash,
		"",
		nil,
		false,
	)
	if err != nil {
		t.Fatalf("create user: %v", err)
	}
	row := models.FrontendRecord{
		SchoolID:  "school-test",
		Resource:  "account-approvals",
		CreatedBy: "admin-user",
		Payload:   `{"type":"account","action":"create","status":"pending","user_id":"` + user.ID + `","target_name":"Pending Parent","target_email":"approve-parent@example.test","target_role":"Parent","requester_name":"Pending Parent","requester_role":"Parent Account"}`,
	}
	if err := db.Create(&row).Error; err != nil {
		t.Fatalf("create approval row: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("user_id", "principal-user")
		c.Set("role_name", "Principal")
		c.Set("email", "principal@example.test")
		c.Next()
	})
	handler := NewAccountApprovalHandler()
	router.PUT("/account-approvals/:id", handler.Decide)

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPut,
		"/account-approvals/"+row.ID,
		strings.NewReader(`{"status":"approved","remarks":"Looks good"}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("approve status = %d body=%s", response.Code, response.Body.String())
	}

	var reloaded models.User
	if err := db.First(&reloaded, "id = ?", user.ID).Error; err != nil {
		t.Fatalf("reload user: %v", err)
	}
	if !reloaded.IsActive || !reloaded.IsVerified {
		t.Fatalf("approved user should be active and verified, active=%v verified=%v", reloaded.IsActive, reloaded.IsVerified)
	}

	var updated models.FrontendRecord
	if err := db.First(&updated, "id = ?", row.ID).Error; err != nil {
		t.Fatalf("reload approval row: %v", err)
	}
	if !strings.Contains(updated.Payload, `"status":"approved"`) {
		t.Fatalf("approval payload should be updated: %s", updated.Payload)
	}
}

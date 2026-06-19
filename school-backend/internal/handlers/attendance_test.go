package handlers

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func TestCreateAttendanceSession(t *testing.T) {
	gin.SetMode(gin.TestMode)
	assert.NoError(t, database.SetupTestDB())

	school := models.School{BaseModel: models.BaseModel{ID: "school-attendance-test"}, Name: "Attendance School", SchoolType: "cbse"}
	year := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-attendance-test"}, SchoolID: school.ID, YearLabel: "2024-2025", StartDate: time.Date(2024, 4, 1, 0, 0, 0, 0, time.UTC), EndDate: time.Date(2025, 3, 31, 0, 0, 0, 0, time.UTC), IsCurrent: true, Status: "active"}
	grade := models.Grade{BaseModel: models.BaseModel{ID: "grade-attendance-test"}, SchoolID: school.ID, GradeNumber: 1, GradeName: "Class 1"}
	section := models.Section{BaseModel: models.BaseModel{ID: "test-section-id"}, SchoolID: school.ID, GradeID: grade.ID, AcademicYearID: year.ID, SectionName: "A"}
	department := models.Department{BaseModel: models.BaseModel{ID: "dept-attendance-test"}, SchoolID: school.ID, DepartmentName: "Academics"}
	subject := models.Subject{BaseModel: models.BaseModel{ID: "test-subject-id"}, SchoolID: school.ID, DepartmentID: department.ID, SubjectName: "Math"}
	staff := models.Staff{BaseModel: models.BaseModel{ID: "test-staff-id"}, SchoolID: school.ID, StaffCode: "T-ATT", FirstName: "Test", LastName: "Teacher", Status: "active"}
	gradeSubject := models.GradeSubject{BaseModel: models.BaseModel{ID: "grade-subject-attendance-test"}, SchoolID: school.ID, AcademicYearID: year.ID, GradeID: grade.ID, SubjectID: subject.ID, IsMandatory: true}
	staffSubject := models.StaffSubject{BaseModel: models.BaseModel{ID: "staff-subject-attendance-test"}, SchoolID: school.ID, AcademicYearID: year.ID, StaffID: staff.ID, GradeID: grade.ID, SubjectID: subject.ID, SectionID: &section.ID, IsPrimary: true}
	for _, seed := range []any{&school, &year, &grade, &section, &department, &subject, &staff, &gradeSubject, &staffSubject} {
		assert.NoError(t, database.DB.Create(seed).Error)
	}

	reqBody := map[string]interface{}{
		"academic_year_id": year.ID,
		"section_id":       section.ID,
		"subject_id":       subject.ID,
		"staff_id":         staff.ID,
		"date":             "2024-04-30",
		"period_number":    1,
	}
	body, _ := json.Marshal(reqBody)

	req, _ := http.NewRequest("POST", "/attendance/sessions", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r := gin.Default()
	r.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("role_name", "Admin")
		c.Next()
	})
	r.POST("/attendance/sessions", func(c *gin.Context) {
		h := NewAttendanceHandler()
		h.CreateAttendanceSession(c)
	})

	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusCreated, w.Code)

	var response models.APIResponse
	json.Unmarshal(w.Body.Bytes(), &response)
	assert.True(t, response.Success)

	session := response.Data.(map[string]interface{})
	assert.Equal(t, "test-section-id", session["section_id"])
	assert.Equal(t, "2024-04-30T00:00:00Z", session["date"]) // Assuming UTC
}

func TestMarkStaffAttendance(t *testing.T) {
	gin.SetMode(gin.TestMode)
	assert.NoError(t, database.SetupTestDB())

	reqBody := map[string]interface{}{
		"staff_id":     "test-staff-id",
		"date":         "2024-04-30",
		"status":       "present",
		"check_in":     "09:00:00",
		"check_out":    "17:00:00",
		"biometric_id": "bio123",
	}
	body, _ := json.Marshal(reqBody)

	req, _ := http.NewRequest("POST", "/attendance/staff", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r := gin.Default()
	r.POST("/attendance/staff", func(c *gin.Context) {
		h := NewAttendanceHandler()
		h.MarkStaffAttendance(c)
	})

	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)

	var response models.APIResponse
	json.Unmarshal(w.Body.Bytes(), &response)
	assert.True(t, response.Success)

	attendance := response.Data.(map[string]interface{})
	assert.Equal(t, "test-staff-id", attendance["staff_id"])
	assert.Equal(t, "2024-04-30T00:00:00Z", attendance["date"])
	assert.Equal(t, "2024-04-30T09:00:00Z", attendance["check_in"])
	assert.Equal(t, "2024-04-30T17:00:00Z", attendance["check_out"])
}

func TestTeacherAttendanceLocksUntilPrincipalReopens(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	session := models.AttendanceSession{
		BaseModel:      models.BaseModel{ID: "attendance-lock-session"},
		SectionID:      f.sectionID,
		AcademicYearID: f.yearID,
		SubjectID:      f.subjectID,
		StaffID:        f.teacherStaffID,
		Date:           time.Date(2026, 6, 12, 0, 0, 0, 0, time.UTC),
		PeriodNumber:   1,
	}
	if err := database.DB.Create(&session).Error; err != nil {
		t.Fatalf("seed attendance session: %v", err)
	}

	handler := NewAttendanceHandler()
	teacherRouter := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	teacherRouter.POST("/attendance/sessions/:session_id/mark", handler.MarkStudentAttendance)
	principalRouter := scopedPolicyRouter("Principal", "user-policy-principal", "", "", "principal@policy.test", f.schoolID)
	principalRouter.POST("/attendance/sessions/:session_id/reopen", handler.ReopenAttendanceSession)

	body := `{"attendances":[{"student_id":"` + f.studentID + `","enrollment_id":"` + f.enrollmentID + `","status":"present"}]}`
	first := httptest.NewRecorder()
	teacherRouter.ServeHTTP(first, httptest.NewRequest(http.MethodPost, "/attendance/sessions/"+session.ID+"/mark", strings.NewReader(body)))
	if first.Code != http.StatusOK {
		t.Fatalf("first mark status=%d body=%s", first.Code, first.Body.String())
	}

	second := httptest.NewRecorder()
	teacherRouter.ServeHTTP(second, httptest.NewRequest(http.MethodPost, "/attendance/sessions/"+session.ID+"/mark", strings.NewReader(body)))
	if second.Code != http.StatusForbidden {
		t.Fatalf("locked mark status=%d body=%s", second.Code, second.Body.String())
	}

	reopen := httptest.NewRecorder()
	principalRouter.ServeHTTP(reopen, httptest.NewRequest(http.MethodPost, "/attendance/sessions/"+session.ID+"/reopen", strings.NewReader(`{"reason":"Correction requested"}`)))
	if reopen.Code != http.StatusOK {
		t.Fatalf("reopen status=%d body=%s", reopen.Code, reopen.Body.String())
	}

	third := httptest.NewRecorder()
	teacherRouter.ServeHTTP(third, httptest.NewRequest(http.MethodPost, "/attendance/sessions/"+session.ID+"/mark", strings.NewReader(body)))
	if third.Code != http.StatusOK {
		t.Fatalf("mark after reopen status=%d body=%s", third.Code, third.Body.String())
	}
}

func TestTeacherCanSaveDraftThenSubmitFinalAttendance(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	session := models.AttendanceSession{
		BaseModel:      models.BaseModel{ID: "attendance-draft-session"},
		SectionID:      f.sectionID,
		AcademicYearID: f.yearID,
		SubjectID:      f.subjectID,
		StaffID:        f.teacherStaffID,
		Date:           time.Date(2026, 6, 12, 0, 0, 0, 0, time.UTC),
		PeriodNumber:   1,
		Status:         "not_started",
	}
	assert.NoError(t, database.DB.Create(&session).Error)

	handler := NewAttendanceHandler()
	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	router.POST("/attendance/sessions/:session_id/mark", handler.MarkStudentAttendance)

	draftBody := `{"finalize":false,"attendances":[{"student_id":"` + f.studentID + `","enrollment_id":"` + f.enrollmentID + `","status":"present"}]}`
	draft := httptest.NewRecorder()
	router.ServeHTTP(draft, httptest.NewRequest(http.MethodPost, "/attendance/sessions/"+session.ID+"/mark", strings.NewReader(draftBody)))
	if draft.Code != http.StatusOK {
		t.Fatalf("draft mark status=%d body=%s", draft.Code, draft.Body.String())
	}

	var savedDraft models.AttendanceSession
	assert.NoError(t, database.DB.First(&savedDraft, "id = ?", session.ID).Error)
	assert.False(t, savedDraft.IsFinalized)
	assert.Equal(t, "draft", savedDraft.Status)

	finalBody := `{"finalize":true,"attendances":[{"student_id":"` + f.studentID + `","enrollment_id":"` + f.enrollmentID + `","status":"present"}]}`
	final := httptest.NewRecorder()
	router.ServeHTTP(final, httptest.NewRequest(http.MethodPost, "/attendance/sessions/"+session.ID+"/mark", strings.NewReader(finalBody)))
	if final.Code != http.StatusOK {
		t.Fatalf("final mark status=%d body=%s", final.Code, final.Body.String())
	}

	var submitted models.AttendanceSession
	assert.NoError(t, database.DB.First(&submitted, "id = ?", session.ID).Error)
	assert.True(t, submitted.IsFinalized)
	assert.Equal(t, "submitted", submitted.Status)
	assert.NotNil(t, submitted.SubmittedAt)
}

func TestAttendanceRequiresReasonForNonPresentStatuses(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	session := models.AttendanceSession{
		BaseModel:      models.BaseModel{ID: "attendance-reason-session"},
		SectionID:      f.sectionID,
		AcademicYearID: f.yearID,
		SubjectID:      f.subjectID,
		StaffID:        f.teacherStaffID,
		Date:           time.Date(2026, 6, 12, 0, 0, 0, 0, time.UTC),
		PeriodNumber:   1,
		Status:         "draft",
	}
	assert.NoError(t, database.DB.Create(&session).Error)

	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	router.POST("/attendance/sessions/:session_id/mark", NewAttendanceHandler().MarkStudentAttendance)

	body := `{"finalize":false,"attendances":[{"student_id":"` + f.studentID + `","enrollment_id":"` + f.enrollmentID + `","status":"absent"}]}`
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, httptest.NewRequest(http.MethodPost, "/attendance/sessions/"+session.ID+"/mark", strings.NewReader(body)))

	assert.Equal(t, http.StatusBadRequest, resp.Code)
	assert.Contains(t, resp.Body.String(), "reason is required")
}

func TestTeacherRequestsCorrectionAndPrincipalReopenStoresReason(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	submittedAt := time.Date(2026, 6, 12, 8, 30, 0, 0, time.UTC)
	session := models.AttendanceSession{
		BaseModel:      models.BaseModel{ID: "attendance-correction-session"},
		SectionID:      f.sectionID,
		AcademicYearID: f.yearID,
		SubjectID:      f.subjectID,
		StaffID:        f.teacherStaffID,
		Date:           time.Date(2026, 6, 12, 0, 0, 0, 0, time.UTC),
		PeriodNumber:   1,
		TotalStudents:  1,
		PresentCount:   1,
		IsFinalized:    true,
		Status:         "submitted",
		SubmittedAt:    &submittedAt,
	}
	assert.NoError(t, database.DB.Create(&session).Error)

	handler := NewAttendanceHandler()
	teacherRouter := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	teacherRouter.POST("/attendance/sessions/:session_id/correction-request", handler.RequestAttendanceCorrection)
	principalRouter := scopedPolicyRouter("Principal", "user-policy-principal", "", "", "principal@policy.test", f.schoolID)
	principalRouter.POST("/attendance/sessions/:session_id/reopen", handler.ReopenAttendanceSession)

	request := httptest.NewRecorder()
	teacherRouter.ServeHTTP(request, httptest.NewRequest(http.MethodPost, "/attendance/sessions/"+session.ID+"/correction-request", strings.NewReader(`{"reason":"One child arrived late"}`)))
	if request.Code != http.StatusOK {
		t.Fatalf("correction request status=%d body=%s", request.Code, request.Body.String())
	}

	var needsReview models.AttendanceSession
	assert.NoError(t, database.DB.First(&needsReview, "id = ?", session.ID).Error)
	assert.True(t, needsReview.IsFinalized)
	assert.Equal(t, "needs_review", needsReview.Status)
	assert.Equal(t, "One child arrived late", needsReview.CorrectionReason)

	reopen := httptest.NewRecorder()
	principalRouter.ServeHTTP(reopen, httptest.NewRequest(http.MethodPost, "/attendance/sessions/"+session.ID+"/reopen", strings.NewReader(`{"reason":"Approved correction window"}`)))
	if reopen.Code != http.StatusOK {
		t.Fatalf("reopen status=%d body=%s", reopen.Code, reopen.Body.String())
	}

	var reopened models.AttendanceSession
	assert.NoError(t, database.DB.First(&reopened, "id = ?", session.ID).Error)
	assert.False(t, reopened.IsFinalized)
	assert.Equal(t, "reopened", reopened.Status)
	assert.Equal(t, "Approved correction window", reopened.ReopenReason)
	assert.NotNil(t, reopened.ReopenedAt)
}

func TestStaffQRScanRecordsOneCheckInPerDay(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	h := NewAttendanceHandler()

	adminRouter := scopedPolicyRouter("Admin", "user-policy-admin", "", "", "admin@policy.test", f.schoolID)
	adminRouter.GET("/attendance/staff/qr-token", h.GetStaffQRToken)

	tokenReq, _ := http.NewRequest(http.MethodGet, "/attendance/staff/qr-token", nil)
	tokenResp := httptest.NewRecorder()
	adminRouter.ServeHTTP(tokenResp, tokenReq)
	assert.Equal(t, http.StatusOK, tokenResp.Code)

	var tokenBody struct {
		Success bool           `json:"success"`
		Data    map[string]any `json:"data"`
	}
	assert.NoError(t, json.Unmarshal(tokenResp.Body.Bytes(), &tokenBody))
	token, _ := tokenBody.Data["token"].(string)
	if token == "" {
		t.Fatalf("expected staff QR token in response: %s", tokenResp.Body.String())
	}

	teacherRouter := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	teacherRouter.POST("/attendance/staff/qr-scan", h.ScanStaffQR)

	scanBody, _ := json.Marshal(map[string]string{"token": token})
	scanReq, _ := http.NewRequest(http.MethodPost, "/attendance/staff/qr-scan", bytes.NewBuffer(scanBody))
	scanReq.Header.Set("Content-Type", "application/json")
	scanResp := httptest.NewRecorder()
	teacherRouter.ServeHTTP(scanResp, scanReq)
	assert.Equal(t, http.StatusOK, scanResp.Code)

	duplicateReq, _ := http.NewRequest(http.MethodPost, "/attendance/staff/qr-scan", bytes.NewBuffer(scanBody))
	duplicateReq.Header.Set("Content-Type", "application/json")
	duplicateResp := httptest.NewRecorder()
	teacherRouter.ServeHTTP(duplicateResp, duplicateReq)
	assert.Equal(t, http.StatusOK, duplicateResp.Code)

	var count int64
	assert.NoError(t, database.DB.Model(&models.StaffAttendance{}).
		Where("staff_id = ?", f.teacherStaffID).
		Count(&count).Error)
	assert.Equal(t, int64(1), count)
}

func TestStaffQRDailyLogExportIncludesOnlyQRRowsForDate(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	h := NewAttendanceHandler()
	date := time.Date(2026, 6, 13, 0, 0, 0, 0, time.UTC)
	checkIn := time.Date(2026, 6, 13, 9, 15, 0, 0, time.UTC)
	otherDateCheckIn := time.Date(2026, 6, 12, 9, 30, 0, 0, time.UTC)

	rows := []models.StaffAttendance{
		{
			BaseModel: models.BaseModel{ID: "qr-export-row"},
			StaffID:   f.teacherStaffID,
			Date:      date,
			CheckIn:   &checkIn,
			Status:    "present",
			Source:    "qr",
		},
		{
			BaseModel: models.BaseModel{ID: "manual-export-row"},
			StaffID:   f.teacherStaffID,
			Date:      date,
			CheckIn:   &checkIn,
			Status:    "present",
			Source:    "manual",
		},
		{
			BaseModel: models.BaseModel{ID: "other-date-qr-export-row"},
			StaffID:   f.teacherStaffID,
			Date:      date.AddDate(0, 0, -1),
			CheckIn:   &otherDateCheckIn,
			Status:    "present",
			Source:    "qr",
		},
	}
	for _, row := range rows {
		if err := database.DB.Create(&row).Error; err != nil {
			t.Fatalf("seed staff attendance: %v", err)
		}
	}

	router := scopedPolicyRouter("Principal", "user-policy-principal", "", "", "principal@policy.test", f.schoolID)
	router.GET("/attendance/staff/qr-logs/export", h.ExportStaffQRDailyLogs)

	resp := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/attendance/staff/qr-logs/export?date=2026-06-13", nil)
	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusOK {
		t.Fatalf("export status=%d body=%s", resp.Code, resp.Body.String())
	}
	assert.Equal(t, "text/csv; charset=utf-8", resp.Header().Get("Content-Type"))
	assert.Contains(t, resp.Header().Get("Content-Disposition"), "staff_qr_logs_2026-06-13.csv")
	body := resp.Body.String()
	assert.Contains(t, body, "date,staff_id,staff_name,status,check_in,source")
	assert.Contains(t, body, "2026-06-13,"+f.teacherStaffID)
	assert.Contains(t, body, ",qr")
	assert.NotContains(t, body, "manual-export-row")
	assert.NotContains(t, body, "other-date-qr-export-row")
}

func TestKioskQRScanRecordsStaffFromSubmittedStaffID(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	h := NewAttendanceHandler()
	now := time.Now().UTC()
	_, dateText := staffAttendanceDate(now)
	token := signedStaffQRTokenForTest(t, staffQRPayload{
		SchoolID:  f.schoolID,
		Date:      dateText,
		IssuedAt:  now.Unix(),
		ExpiresAt: now.Add(time.Minute).Unix(),
		Nonce:     "kiosk-token",
	})

	router := scopedPolicyRouter("Kiosk", "user-policy-kiosk", "", "", "kiosk@policy.test", f.schoolID)
	router.POST("/attendance/staff/qr-scan", h.ScanStaffQR)

	body, _ := json.Marshal(map[string]string{
		"token":    token,
		"staff_id": f.teacherStaffID,
	})
	req, _ := http.NewRequest(http.MethodPost, "/attendance/staff/qr-scan", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, req)

	assert.Equal(t, http.StatusOK, resp.Code, resp.Body.String())
	var count int64
	assert.NoError(t, database.DB.Model(&models.StaffAttendance{}).
		Where("staff_id = ?", f.teacherStaffID).
		Count(&count).Error)
	assert.Equal(t, int64(1), count)
}

func TestStaffQRScanRejectsExpiredWrongSchoolAndUnlinkedTeacher(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	h := NewAttendanceHandler()
	now := time.Now().UTC()
	_, dateText := staffAttendanceDate(now)

	expiredToken := signedStaffQRTokenForTest(t, staffQRPayload{
		SchoolID:  f.schoolID,
		Date:      dateText,
		IssuedAt:  now.Add(-2 * time.Minute).Unix(),
		ExpiresAt: now.Add(-time.Minute).Unix(),
		Nonce:     "expired-token",
	})
	validWrongSchoolToken := signedStaffQRTokenForTest(t, staffQRPayload{
		SchoolID:  "school-other",
		Date:      dateText,
		IssuedAt:  now.Unix(),
		ExpiresAt: now.Add(time.Minute).Unix(),
		Nonce:     "wrong-school-token",
	})
	validToken := signedStaffQRTokenForTest(t, staffQRPayload{
		SchoolID:  f.schoolID,
		Date:      dateText,
		IssuedAt:  now.Unix(),
		ExpiresAt: now.Add(time.Minute).Unix(),
		Nonce:     "unlinked-token",
	})

	teacherRouter := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	teacherRouter.POST("/attendance/staff/qr-scan", h.ScanStaffQR)
	assert.Equal(t, http.StatusBadRequest, postStaffQRForTest(teacherRouter, expiredToken).Code)
	assert.Equal(t, http.StatusForbidden, postStaffQRForTest(teacherRouter, validWrongSchoolToken).Code)

	unlinkedRouter := scopedPolicyRouter("Teacher", "user-unlinked", "", "", "", f.schoolID)
	unlinkedRouter.POST("/attendance/staff/qr-scan", h.ScanStaffQR)
	assert.Equal(t, http.StatusForbidden, postStaffQRForTest(unlinkedRouter, validToken).Code)
}

func signedStaffQRTokenForTest(t *testing.T, payload staffQRPayload) string {
	t.Helper()
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal qr payload: %v", err)
	}
	encodedPayload := base64.RawURLEncoding.EncodeToString(payloadBytes)
	return encodedPayload + "." + signStaffQRPayload(encodedPayload)
}

func postStaffQRForTest(router *gin.Engine, token string) *httptest.ResponseRecorder {
	body, _ := json.Marshal(map[string]string{"token": token})
	req, _ := http.NewRequest(http.MethodPost, "/attendance/staff/qr-scan", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, req)
	return resp
}

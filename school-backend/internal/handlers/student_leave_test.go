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
)

func TestParentStudentLeaveCreateAndListIsLinkedStudentScoped(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	handler := NewLeaveHandler()
	router := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	router.POST("/student-leave/applications", handler.CreateStudentLeaveApplication)
	router.GET("/student-leave/applications", handler.GetStudentLeaveApplications)

	create := httptest.NewRecorder()
	router.ServeHTTP(
		create,
		httptest.NewRequest(
			http.MethodPost,
			"/student-leave/applications",
			strings.NewReader(`{"student_id":"`+f.studentID+`","leave_type":"Sick Leave","from_date":"2026-05-18","to_date":"2026-05-19","reason":"Fever and doctor advised rest"}`),
		),
	)
	if create.Code != http.StatusCreated {
		t.Fatalf("create status=%d body=%s", create.Code, create.Body.String())
	}
	var created struct {
		Data models.StudentLeaveApplication `json:"data"`
	}
	if err := json.Unmarshal(create.Body.Bytes(), &created); err != nil {
		t.Fatalf("decode create: %v", err)
	}
	if created.Data.StudentID != f.studentID || created.Data.Status != "pending" || created.Data.TotalDays != 2 {
		t.Fatalf("unexpected created row: %+v", created.Data)
	}

	list := httptest.NewRecorder()
	router.ServeHTTP(list, httptest.NewRequest(http.MethodGet, "/student-leave/applications", nil))
	if list.Code != http.StatusOK {
		t.Fatalf("list status=%d body=%s", list.Code, list.Body.String())
	}
	rows := decodePolicyList(t, list.Body.String())
	if len(rows) != 1 || rows[0]["student_id"] != f.studentID {
		t.Fatalf("parent should see only linked student leave rows, rows=%v", rows)
	}

	otherCreate := httptest.NewRecorder()
	router.ServeHTTP(
		otherCreate,
		httptest.NewRequest(
			http.MethodPost,
			"/student-leave/applications",
			strings.NewReader(`{"student_id":"`+f.otherStudentID+`","leave_type":"Personal","from_date":"2026-05-20","to_date":"2026-05-20","reason":"Family work"}`),
		),
	)
	if otherCreate.Code != http.StatusForbidden {
		t.Fatalf("parent should not create leave for unlinked student: status=%d body=%s", otherCreate.Code, otherCreate.Body.String())
	}
}

func TestTeacherStudentLeaveListAndDecisionAreSectionScoped(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	now := time.Date(2026, 5, 16, 9, 0, 0, 0, time.UTC)
	ownRow := models.StudentLeaveApplication{
		BaseModel:    models.BaseModel{ID: "leave-owned"},
		SchoolID:     f.schoolID,
		StudentID:    f.studentID,
		ParentUserID: f.parentUserID,
		LeaveType:    "Sick Leave",
		FromDate:     now.AddDate(0, 0, 2),
		ToDate:       now.AddDate(0, 0, 2),
		TotalDays:    1,
		Reason:       "Fever",
		Status:       "pending",
		AppliedAt:    now,
	}
	otherRow := models.StudentLeaveApplication{
		BaseModel:    models.BaseModel{ID: "leave-other"},
		SchoolID:     f.schoolID,
		StudentID:    f.otherStudentID,
		ParentUserID: f.otherParentUserID,
		LeaveType:    "Personal",
		FromDate:     now.AddDate(0, 0, 3),
		ToDate:       now.AddDate(0, 0, 3),
		TotalDays:    1,
		Reason:       "Family work",
		Status:       "pending",
		AppliedAt:    now,
	}
	if err := database.DB.Create(&ownRow).Error; err != nil {
		t.Fatalf("seed own leave: %v", err)
	}
	if err := database.DB.Create(&otherRow).Error; err != nil {
		t.Fatalf("seed other leave: %v", err)
	}

	handler := NewLeaveHandler()
	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	router.GET("/student-leave/applications", handler.GetStudentLeaveApplications)
	router.PUT("/student-leave/applications/:id/decision", handler.DecideStudentLeaveApplication)

	list := httptest.NewRecorder()
	router.ServeHTTP(list, httptest.NewRequest(http.MethodGet, "/student-leave/applications", nil))
	if list.Code != http.StatusOK {
		t.Fatalf("list status=%d body=%s", list.Code, list.Body.String())
	}
	rows := decodePolicyList(t, list.Body.String())
	if len(rows) != 1 || rows[0]["id"] != ownRow.ID {
		t.Fatalf("teacher should see only assigned-section leave rows, rows=%v", rows)
	}

	approve := httptest.NewRecorder()
	router.ServeHTTP(
		approve,
		httptest.NewRequest(http.MethodPut, "/student-leave/applications/"+ownRow.ID+"/decision", strings.NewReader(`{"status":"approved"}`)),
	)
	if approve.Code != http.StatusOK {
		t.Fatalf("approve status=%d body=%s", approve.Code, approve.Body.String())
	}

	otherApprove := httptest.NewRecorder()
	router.ServeHTTP(
		otherApprove,
		httptest.NewRequest(http.MethodPut, "/student-leave/applications/"+otherRow.ID+"/decision", strings.NewReader(`{"status":"approved"}`)),
	)
	if otherApprove.Code != http.StatusNotFound {
		t.Fatalf("teacher should not decide other-section leave: status=%d body=%s", otherApprove.Code, otherApprove.Body.String())
	}
}

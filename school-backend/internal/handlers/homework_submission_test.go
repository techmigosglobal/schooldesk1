package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"school-backend/internal/models"
)

func TestHomeworkSubmissionLifecycleIsRoleScoped(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	handler := NewHomeworkSubmissionHandler()

	parentRouter := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	parentRouter.POST("/homework/:id/submissions", handler.Submit)

	createResp := httptest.NewRecorder()
	parentRouter.ServeHTTP(createResp, httptest.NewRequest(
		http.MethodPost,
		"/homework/homework-linked/submissions",
		strings.NewReader(`{"student_id":"`+f.studentID+`","answer_text":"Completed from home"}`),
	))
	if createResp.Code != http.StatusCreated {
		t.Fatalf("parent submit status=%d body=%s", createResp.Code, createResp.Body.String())
	}
	var createBody struct {
		Data models.HomeworkSubmission `json:"data"`
	}
	if err := json.Unmarshal(createResp.Body.Bytes(), &createBody); err != nil {
		t.Fatalf("decode submit body: %v", err)
	}
	if createBody.Data.ID == "" || createBody.Data.Status != "submitted" {
		t.Fatalf("unexpected submission row: %+v", createBody.Data)
	}

	teacherRouter := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	teacherRouter.GET("/homework/:id/submissions", handler.List)
	teacherRouter.PUT("/homework/:id/submissions/:submission_id/review", handler.Review)

	listResp := httptest.NewRecorder()
	teacherRouter.ServeHTTP(listResp, httptest.NewRequest(http.MethodGet, "/homework/homework-linked/submissions", nil))
	if listResp.Code != http.StatusOK {
		t.Fatalf("teacher list status=%d body=%s", listResp.Code, listResp.Body.String())
	}
	var listBody struct {
		Data struct {
			Submissions []models.HomeworkSubmission `json:"submissions"`
			Summary     map[string]float64          `json:"summary"`
		} `json:"data"`
	}
	if err := json.Unmarshal(listResp.Body.Bytes(), &listBody); err != nil {
		t.Fatalf("decode list body: %v body=%s", err, listResp.Body.String())
	}
	if len(listBody.Data.Submissions) != 1 {
		t.Fatalf("teacher should see one submission, got %+v", listBody.Data.Submissions)
	}
	if listBody.Data.Summary["submitted"] != 1 || listBody.Data.Summary["total"] != 1 {
		t.Fatalf("unexpected submission summary: %+v", listBody.Data.Summary)
	}

	reviewResp := httptest.NewRecorder()
	teacherRouter.ServeHTTP(reviewResp, httptest.NewRequest(
		http.MethodPut,
		"/homework/homework-linked/submissions/"+createBody.Data.ID+"/review",
		strings.NewReader(`{"status":"reviewed","grade":"A","remarks":"Good work"}`),
	))
	if reviewResp.Code != http.StatusOK {
		t.Fatalf("teacher review status=%d body=%s", reviewResp.Code, reviewResp.Body.String())
	}
}

func TestHomeworkSubmissionRejectsUnlinkedParent(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	handler := NewHomeworkSubmissionHandler()
	router := scopedPolicyRouter("Parent", f.otherParentUserID, "", "", "other.parent@policy.test", f.schoolID)
	router.POST("/homework/:id/submissions", handler.Submit)

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(
		http.MethodPost,
		"/homework/homework-linked/submissions",
		strings.NewReader(`{"student_id":"`+f.studentID+`","answer_text":"Should not pass"}`),
	))
	if response.Code != http.StatusForbidden {
		t.Fatalf("unlinked parent status=%d body=%s", response.Code, response.Body.String())
	}
}

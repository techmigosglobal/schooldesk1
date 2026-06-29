package handlers

import (
	"bytes"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
)

func TestTeacherEventPostUpdateDeleteAndResubmitWorkflow(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	handler := NewEventPostHandler()

	teacherRouter := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	teacherRouter.PUT("/event-posts/:id", handler.UpdateEventPost)
	teacherRouter.DELETE("/event-posts/:id", handler.DeleteEventPost)
	otherTeacherRouter := scopedPolicyRouter("Teacher", "user-policy-teacher-other", "staff", f.otherStaffID, "other.teacher@policy.test", f.schoolID)
	otherTeacherRouter.PUT("/event-posts/:id", handler.UpdateEventPost)

	draft := seedEventPostForWorkflow(t, f.schoolID, f.teacherStaffID, models.ApprovalStatusDraft, "Draft title")
	updateDraft := httptest.NewRecorder()
	teacherRouter.ServeHTTP(updateDraft, httptest.NewRequest(
		http.MethodPut,
		"/event-posts/"+draft.ID,
		strings.NewReader(`{"title":"Edited draft","description":"Updated","event_date":"2026-08-01T09:00:00Z","destinations":["PARENTS_HOME"],"media":[{"url":"/uploads/shared/school/video.mp4","name":"video.mp4","mime_type":"video/mp4","kind":"video","size":1234}],"is_submit":false}`),
	))
	if updateDraft.Code != http.StatusOK {
		t.Fatalf("update draft status=%d body=%s", updateDraft.Code, updateDraft.Body.String())
	}
	var updatedDraft models.EventPost
	if err := database.DB.First(&updatedDraft, "id = ?", draft.ID).Error; err != nil {
		t.Fatalf("load updated draft: %v", err)
	}
	if updatedDraft.Title != "Edited draft" || updatedDraft.ApprovalStatus != models.ApprovalStatusDraft {
		t.Fatalf("updated draft title/status=%q/%q", updatedDraft.Title, updatedDraft.ApprovalStatus)
	}
	if !strings.Contains(updatedDraft.MediaUrls, `"kind":"video"`) {
		t.Fatalf("structured media not stored as JSON: %s", updatedDraft.MediaUrls)
	}

	rejected := seedEventPostForWorkflow(t, f.schoolID, f.teacherStaffID, models.ApprovalStatusRejected, "Rejected title")
	reason := "Need better photos"
	rejected.RejectionReason = &reason
	if err := database.DB.Save(&rejected).Error; err != nil {
		t.Fatalf("seed rejection reason: %v", err)
	}
	resubmit := httptest.NewRecorder()
	teacherRouter.ServeHTTP(resubmit, httptest.NewRequest(
		http.MethodPut,
		"/event-posts/"+rejected.ID,
		strings.NewReader(`{"title":"Resubmitted title","description":"Ready","event_date":"2026-08-02T09:00:00Z","destinations":["SCHOOL_GALLERY"],"media_urls":["/uploads/shared/school/photo.jpg"],"is_submit":true}`),
	))
	if resubmit.Code != http.StatusOK {
		t.Fatalf("resubmit rejected status=%d body=%s", resubmit.Code, resubmit.Body.String())
	}
	var resubmitted models.EventPost
	if err := database.DB.First(&resubmitted, "id = ?", rejected.ID).Error; err != nil {
		t.Fatalf("load resubmitted post: %v", err)
	}
	if resubmitted.ApprovalStatus != models.ApprovalStatusPending || resubmitted.RejectionReason != nil || resubmitted.ApprovedAt != nil || resubmitted.PublishedAt != nil {
		t.Fatalf("resubmitted approval fields status=%q reason=%v approved_at=%v published_at=%v", resubmitted.ApprovalStatus, resubmitted.RejectionReason, resubmitted.ApprovedAt, resubmitted.PublishedAt)
	}
	var principalLog models.NotificationLog
	if err := database.DB.Where("reference_type = ? AND reference_id = ? AND route = ?", "event_post", rejected.ID, "/principal-event-approvals-screen").First(&principalLog).Error; err != nil {
		t.Fatalf("resubmit should create principal approval notification: %v", err)
	}

	wrongTeacher := httptest.NewRecorder()
	otherTeacherRouter.ServeHTTP(wrongTeacher, httptest.NewRequest(
		http.MethodPut,
		"/event-posts/"+draft.ID,
		strings.NewReader(`{"title":"Wrong owner","event_date":"2026-08-01T09:00:00Z","destinations":["PARENTS_HOME"],"is_submit":false}`),
	))
	if wrongTeacher.Code != http.StatusNotFound {
		t.Fatalf("wrong teacher update status=%d body=%s", wrongTeacher.Code, wrongTeacher.Body.String())
	}

	pending := seedEventPostForWorkflow(t, f.schoolID, f.teacherStaffID, models.ApprovalStatusPending, "Pending title")
	updatePending := httptest.NewRecorder()
	teacherRouter.ServeHTTP(updatePending, httptest.NewRequest(
		http.MethodPut,
		"/event-posts/"+pending.ID,
		strings.NewReader(`{"title":"Nope","event_date":"2026-08-01T09:00:00Z","destinations":["PARENTS_HOME"],"is_submit":false}`),
	))
	if updatePending.Code != http.StatusBadRequest {
		t.Fatalf("pending update status=%d body=%s", updatePending.Code, updatePending.Body.String())
	}
	deletePending := httptest.NewRecorder()
	teacherRouter.ServeHTTP(deletePending, httptest.NewRequest(http.MethodDelete, "/event-posts/"+pending.ID, nil))
	if deletePending.Code != http.StatusBadRequest {
		t.Fatalf("pending delete status=%d body=%s", deletePending.Code, deletePending.Body.String())
	}

	deletable := seedEventPostForWorkflow(t, f.schoolID, f.teacherStaffID, models.ApprovalStatusDraft, "Delete me")
	deleteDraft := httptest.NewRecorder()
	teacherRouter.ServeHTTP(deleteDraft, httptest.NewRequest(http.MethodDelete, "/event-posts/"+deletable.ID, nil))
	if deleteDraft.Code != http.StatusOK {
		t.Fatalf("delete draft status=%d body=%s", deleteDraft.Code, deleteDraft.Body.String())
	}
	var remaining int64
	if err := database.DB.Model(&models.EventPost{}).Where("id = ?", deletable.ID).Count(&remaining).Error; err != nil {
		t.Fatalf("count deleted draft: %v", err)
	}
	if remaining != 0 {
		t.Fatalf("deleted draft rows=%d, want 0", remaining)
	}
}

func TestEventPostUploadAcceptsVideosAndRejectsOversizedFiles(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	handler := NewUploadHandler()
	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	router.POST("/uploads", handler.UploadFile)

	video := httptest.NewRecorder()
	videoReq := multipartUploadRequest(t, "/uploads", "clip.mp4", bytes.Repeat([]byte("v"), 1024))
	router.ServeHTTP(video, videoReq)
	if video.Code != http.StatusOK {
		t.Fatalf("video upload status=%d body=%s", video.Code, video.Body.String())
	}
	if !strings.Contains(video.Body.String(), ".mp4") {
		t.Fatalf("video upload response should include mp4 path: %s", video.Body.String())
	}

	oversized := httptest.NewRecorder()
	oversizedReq := multipartUploadRequest(t, "/uploads", "huge.pdf", bytes.Repeat([]byte("p"), 15*1024*1024+1))
	router.ServeHTTP(oversized, oversizedReq)
	if oversized.Code != http.StatusBadRequest {
		t.Fatalf("oversized upload status=%d body=%s", oversized.Code, oversized.Body.String())
	}
	if !strings.Contains(strings.ToLower(oversized.Body.String()), "too large") {
		t.Fatalf("oversized response should explain size: %s", oversized.Body.String())
	}
}

func TestLandingEventsReturnPublicEventPostDTOOnly(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	handler := NewEventPostHandler()
	post := seedEventPostForWorkflow(t, f.schoolID, f.teacherStaffID, models.ApprovalStatusApproved, "Public title")
	post.Destinations = string(models.DestinationSchoolLanding)
	now := time.Date(2026, 8, 3, 9, 0, 0, 0, time.UTC)
	post.PublishedAt = &now
	reason := "private"
	post.RejectionReason = &reason
	if err := database.DB.Save(&post).Error; err != nil {
		t.Fatalf("save landing post: %v", err)
	}

	router := scopedPolicyRouter("", "", "", "", "", f.schoolID)
	router.GET("/landing/events", handler.ListLandingEvents)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/landing/events?school_id="+f.schoolID, nil))
	if response.Code != http.StatusOK {
		t.Fatalf("landing status=%d body=%s", response.Code, response.Body.String())
	}
	var body struct {
		Data []map[string]any `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode landing response: %v", err)
	}
	if len(body.Data) == 0 {
		t.Fatalf("landing response missing seeded post")
	}
	row := body.Data[0]
	for _, privateKey := range []string{"id", "school_id", "created_by_teacher_id", "approval_status", "rejection_reason", "approved_by_principal_id", "approved_at"} {
		if _, ok := row[privateKey]; ok {
			t.Fatalf("landing response leaked %s in %+v", privateKey, row)
		}
	}
	if row["title"] != "Public title" || row["media_urls"] == nil {
		t.Fatalf("landing response missing public fields: %+v", row)
	}
}

func seedEventPostForWorkflow(t *testing.T, schoolID, teacherID string, status models.ApprovalStatus, title string) models.EventPost {
	t.Helper()
	post := models.EventPost{
		SchoolID:           schoolID,
		Title:              title,
		Description:        "Workflow test",
		EventDate:          time.Date(2026, 8, 1, 9, 0, 0, 0, time.UTC),
		CreatedByTeacherID: teacherID,
		MediaUrls:          "/uploads/shared/school/photo.jpg",
		Destinations:       string(models.DestinationParentsHome),
		ApprovalStatus:     status,
	}
	if err := database.DB.Create(&post).Error; err != nil {
		t.Fatalf("seed event post: %v", err)
	}
	return post
}

func multipartUploadRequest(t *testing.T, path, filename string, content []byte) *http.Request {
	t.Helper()
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, err := writer.CreateFormFile("file", filename)
	if err != nil {
		t.Fatalf("create multipart file: %v", err)
	}
	if _, err := part.Write(content); err != nil {
		t.Fatalf("write multipart file: %v", err)
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close multipart writer: %v", err)
	}
	req := httptest.NewRequest(http.MethodPost, path, body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	return req
}

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

func TestAnnouncementCreatesScopedNotificationsAndFiltersAudience(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	handler := NewAnnouncementHandler()

	principalRouter := scopedPolicyRouter("Principal", "user-policy-principal", "", "", "principal@policy.test", f.schoolID)
	principalRouter.POST("/announcements", handler.CreateAnnouncement)

	createParent := httptest.NewRecorder()
	principalRouter.ServeHTTP(createParent, httptest.NewRequest(
		http.MethodPost,
		"/announcements",
		strings.NewReader(`{"title":"Parent notice","content":"For parents","target_audience":"parents"}`),
	))
	if createParent.Code != http.StatusCreated {
		t.Fatalf("create parent announcement status=%d body=%s", createParent.Code, createParent.Body.String())
	}

	createTeacher := httptest.NewRecorder()
	principalRouter.ServeHTTP(createTeacher, httptest.NewRequest(
		http.MethodPost,
		"/announcements",
		strings.NewReader(`{"title":"Teacher notice","content":"For teachers","target_audience":"teachers"}`),
	))
	if createTeacher.Code != http.StatusCreated {
		t.Fatalf("create teacher announcement status=%d body=%s", createTeacher.Code, createTeacher.Body.String())
	}

	var parentNotifications int64
	if err := database.DB.Model(&models.NotificationLog{}).
		Where("recipient_user_id = ? AND title = ?", f.parentUserID, "Parent notice").
		Count(&parentNotifications).Error; err != nil {
		t.Fatalf("count parent notifications: %v", err)
	}
	if parentNotifications != 1 {
		t.Fatalf("parent notifications=%d, want 1", parentNotifications)
	}
	var parentNotification models.NotificationLog
	if err := database.DB.
		Where("recipient_user_id = ? AND title = ?", f.parentUserID, "Parent notice").
		First(&parentNotification).Error; err != nil {
		t.Fatalf("load parent notification: %v", err)
	}
	if parentNotification.Route != "/parent-notices-screen" {
		t.Fatalf("parent notification route=%q, want /parent-notices-screen", parentNotification.Route)
	}
	if parentNotification.Category != "general" {
		t.Fatalf("parent notification category=%q, want general", parentNotification.Category)
	}
	if parentNotification.Priority != "medium" {
		t.Fatalf("parent notification priority=%q, want medium", parentNotification.Priority)
	}
	var teacherParentNotice int64
	if err := database.DB.Model(&models.NotificationLog{}).
		Where("recipient_user_id = ? AND title = ?", "user-policy-teacher", "Parent notice").
		Count(&teacherParentNotice).Error; err != nil {
		t.Fatalf("count teacher notifications: %v", err)
	}
	if teacherParentNotice != 0 {
		t.Fatalf("teacher received parent-only notice count=%d", teacherParentNotice)
	}

	parentRouter := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	parentRouter.GET("/announcements", handler.GetAnnouncements)
	list := httptest.NewRecorder()
	parentRouter.ServeHTTP(list, httptest.NewRequest(http.MethodGet, "/announcements", nil))
	if list.Code != http.StatusOK {
		t.Fatalf("parent list status=%d body=%s", list.Code, list.Body.String())
	}
	rows := decodePolicyList(t, list.Body.String())
	for _, row := range rows {
		if row["title"] == "Teacher notice" {
			t.Fatalf("parent should not see teacher-only announcement: %v", rows)
		}
	}
}

func TestDeleteNoticeRemovesAnnouncementNotifications(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	notice := models.Announcement{
		BaseModel:      models.BaseModel{ID: "announcement-delete-notice"},
		SchoolID:       f.schoolID,
		Title:          "Delete me",
		Content:        "Temporary notice",
		TargetAudience: "all",
		CreatedBy:      "user-policy-admin",
	}
	if err := database.DB.Create(&notice).Error; err != nil {
		t.Fatalf("seed notice: %v", err)
	}
	refID := notice.ID
	logs := []models.NotificationLog{
		{SchoolID: f.schoolID, RecipientUserID: f.parentUserID, Channel: notificationChannelInApp, Title: notice.Title, ReferenceType: "notice", ReferenceID: &refID, DeliveryStatus: "delivered"},
		{SchoolID: f.schoolID, RecipientUserID: "user-policy-teacher", Channel: notificationChannelInApp, Title: notice.Title, ReferenceType: "announcement", ReferenceID: &refID, DeliveryStatus: "delivered"},
	}
	if err := database.DB.Create(&logs).Error; err != nil {
		t.Fatalf("seed notification logs: %v", err)
	}

	router := scopedPolicyRouter("Admin", "user-policy-admin", "", "", "admin@policy.test", f.schoolID)
	router.DELETE("/notices/:id", NewCompatibilityHandler().DeleteNotice)
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, httptest.NewRequest(http.MethodDelete, "/notices/"+notice.ID, nil))
	if resp.Code != http.StatusOK {
		t.Fatalf("delete notice status=%d body=%s", resp.Code, resp.Body.String())
	}

	var announcements int64
	if err := database.DB.Model(&models.Announcement{}).Where("id = ?", notice.ID).Count(&announcements).Error; err != nil {
		t.Fatalf("count announcements: %v", err)
	}
	if announcements != 0 {
		t.Fatalf("announcements=%d, want 0", announcements)
	}
	var notifications int64
	if err := database.DB.Model(&models.NotificationLog{}).Where("reference_id = ?", notice.ID).Count(&notifications).Error; err != nil {
		t.Fatalf("count notification logs: %v", err)
	}
	if notifications != 0 {
		t.Fatalf("notification logs=%d, want 0", notifications)
	}
}

func TestMessageCreateNormalizesSenderAndNotifiesRecipient(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	handler := NewCRUDHandler[models.Message]("messages", "messages", []string{"conversation_id", "sender_id", "sender_role", "body"}, false)
	router.POST("/messages", handler.Create)

	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, httptest.NewRequest(
		http.MethodPost,
		"/messages",
		strings.NewReader(`{"conversation_id":"`+f.conversationID+`","sender_id":"spoof","sender_role":"Teacher","sender_name":"Suite Parent","body":"Please review","sent_at":"2026-05-01T00:01:00Z"}`),
	))
	if resp.Code != http.StatusCreated {
		t.Fatalf("message create status=%d body=%s", resp.Code, resp.Body.String())
	}
	var payload struct {
		Data models.Message `json:"data"`
	}
	if err := json.Unmarshal(resp.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v body=%s", err, resp.Body.String())
	}
	if payload.Data.SenderRole != "parent" {
		t.Fatalf("sender_role=%q, want parent", payload.Data.SenderRole)
	}
	if payload.Data.SenderID != f.parentUserID {
		t.Fatalf("sender_id=%q, want current parent", payload.Data.SenderID)
	}

	var notifications int64
	if err := database.DB.Model(&models.NotificationLog{}).
		Where("recipient_user_id = ? AND reference_type = ?", "user-policy-teacher", "message").
		Count(&notifications).Error; err != nil {
		t.Fatalf("count message notifications: %v", err)
	}
	if notifications != 1 {
		t.Fatalf("message notifications=%d, want 1", notifications)
	}
	var notification models.NotificationLog
	if err := database.DB.
		Where("recipient_user_id = ? AND reference_type = ?", "user-policy-teacher", "message").
		First(&notification).Error; err != nil {
		t.Fatalf("load message notification: %v", err)
	}
	if notification.Route != "/teacher-communication-screen" {
		t.Fatalf("message notification route=%q, want /teacher-communication-screen", notification.Route)
	}

	var conversation models.MessageConversation
	if err := database.DB.First(&conversation, "id = ?", f.conversationID).Error; err != nil {
		t.Fatalf("load conversation: %v", err)
	}
	if conversation.LastMessage != "Please review" {
		t.Fatalf("last_message=%q, want Please review", conversation.LastMessage)
	}
}

func TestHomeworkCreateNotifiesLinkedParent(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	resource, ok := TablesMDResourceFor("homework")
	if !ok {
		t.Fatal("homework tables.md resource missing")
	}
	handler := NewTablesMDCRUDHandler(resource)
	router.POST("/homework", handler.Create)

	resp := httptest.NewRecorder()
	req := httptest.NewRequest(
		http.MethodPost,
		"/homework",
		strings.NewReader(`{"title":"Fractions worksheet","subject_id":"`+f.subjectID+`","class_id":"Grade 8 A","section_id":"`+f.sectionID+`","staff_id":"`+f.teacherStaffID+`","description":"Complete exercise 3","submission_date":"2026-05-30","status":"pending"}`),
	)
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(resp, req)
	if resp.Code != http.StatusCreated {
		t.Fatalf("homework create status=%d body=%s", resp.Code, resp.Body.String())
	}

	var notification models.NotificationLog
	if err := database.DB.
		Where("recipient_user_id = ? AND reference_type = ?", f.parentUserID, "homework").
		First(&notification).Error; err != nil {
		t.Fatalf("load parent homework notification: %v", err)
	}
	if notification.Route != "/parent-homework-screen" {
		t.Fatalf("homework notification route=%q, want /parent-homework-screen", notification.Route)
	}
	if notification.Category != "homework" {
		t.Fatalf("homework notification category=%q, want homework", notification.Category)
	}
	var otherParentNotifications int64
	if err := database.DB.Model(&models.NotificationLog{}).
		Where("recipient_user_id = ? AND reference_type = ?", f.otherParentUserID, "homework").
		Count(&otherParentNotifications).Error; err != nil {
		t.Fatalf("count other parent homework notifications: %v", err)
	}
	if otherParentNotifications != 0 {
		t.Fatalf("other parent received homework notification count=%d", otherParentNotifications)
	}
}

func TestCreateExamScheduleNotifiesLinkedParentAndAssignedTeacher(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	examType := models.ExamType{
		BaseModel:        models.BaseModel{ID: "exam-type-notify"},
		SchoolID:         f.schoolID,
		Name:             "Term Test",
		WeightagePercent: 20,
	}
	exam := models.Exam{
		BaseModel:      models.BaseModel{ID: "exam-notify"},
		SchoolID:       f.schoolID,
		AcademicYearID: f.yearID,
		TermID:         f.termID,
		ExamTypeID:     examType.ID,
		ExamName:       "Term 1",
		StartDate:      time.Date(2026, 5, 30, 0, 0, 0, 0, time.UTC),
		EndDate:        time.Date(2026, 5, 31, 0, 0, 0, 0, time.UTC),
		IsPublished:    true,
	}
	if err := database.DB.Create(&examType).Error; err != nil {
		t.Fatalf("seed exam type: %v", err)
	}
	if err := database.DB.Create(&exam).Error; err != nil {
		t.Fatalf("seed exam: %v", err)
	}
	var section models.Section
	if err := database.DB.First(&section, "id = ?", f.sectionID).Error; err != nil {
		t.Fatalf("load section: %v", err)
	}

	router := scopedPolicyRouter("Admin", "user-policy-admin", "", "", "admin@policy.test", f.schoolID)
	router.POST("/exams/schedules", NewExamHandler().CreateExamSchedule)
	resp := httptest.NewRecorder()
	req := httptest.NewRequest(
		http.MethodPost,
		"/exams/schedules",
		strings.NewReader(`{"exam_id":"`+exam.ID+`","grade_id":"`+section.GradeID+`","section_id":"`+f.sectionID+`","subject_id":"`+f.subjectID+`","exam_date":"2026-05-30","start_time":"09:00","end_time":"10:00","max_marks":100,"pass_marks":35}`),
	)
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(resp, req)
	if resp.Code != http.StatusCreated {
		t.Fatalf("exam schedule create status=%d body=%s", resp.Code, resp.Body.String())
	}

	var parentNotification models.NotificationLog
	if err := database.DB.
		Where("recipient_user_id = ? AND reference_type = ?", f.parentUserID, "exam_schedule").
		First(&parentNotification).Error; err != nil {
		t.Fatalf("load parent exam notification: %v", err)
	}
	if parentNotification.Route != "/parent-calendar-screen" {
		t.Fatalf("parent exam route=%q, want /parent-calendar-screen", parentNotification.Route)
	}
	if parentNotification.Category != "exam_reminder" {
		t.Fatalf("parent exam category=%q, want exam_reminder", parentNotification.Category)
	}

	var teacherNotification models.NotificationLog
	if err := database.DB.
		Where("recipient_user_id = ? AND reference_type = ?", "user-policy-teacher", "exam_schedule").
		First(&teacherNotification).Error; err != nil {
		t.Fatalf("load teacher exam notification: %v", err)
	}
	if teacherNotification.Route != "/teacher-performance-screen" {
		t.Fatalf("teacher exam route=%q, want /teacher-performance-screen", teacherNotification.Route)
	}

	var otherParentNotifications int64
	if err := database.DB.Model(&models.NotificationLog{}).
		Where("recipient_user_id = ? AND reference_type = ?", f.otherParentUserID, "exam_schedule").
		Count(&otherParentNotifications).Error; err != nil {
		t.Fatalf("count other parent exam notifications: %v", err)
	}
	if otherParentNotifications != 0 {
		t.Fatalf("other parent received exam notification count=%d", otherParentNotifications)
	}
}

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

func TestCreateEventValidatesAcademicYearScopeAndDates(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	handler := NewAnnouncementHandler()

	router := scopedPolicyRouter("Principal", "user-policy-principal", "", "", "principal@policy.test", f.schoolID)
	router.POST("/events", handler.CreateEvent)

	rejectYear := httptest.NewRecorder()
	router.ServeHTTP(rejectYear, httptest.NewRequest(
		http.MethodPost,
		"/events",
		strings.NewReader(`{"academic_year_id":"external-year","event_title":"Sports Day","event_type":"event","start_datetime":"2026-08-01T09:00:00Z","end_datetime":"2026-08-01T12:00:00Z"}`),
	))
	if rejectYear.Code != http.StatusBadRequest {
		t.Fatalf("cross-school year status=%d body=%s", rejectYear.Code, rejectYear.Body.String())
	}
	if !strings.Contains(rejectYear.Body.String(), "academic year must belong to this school") {
		t.Fatalf("cross-school response should explain academic year: %s", rejectYear.Body.String())
	}

	rejectDates := httptest.NewRecorder()
	router.ServeHTTP(rejectDates, httptest.NewRequest(
		http.MethodPost,
		"/events",
		strings.NewReader(`{"academic_year_id":"`+f.yearID+`","event_title":"Sports Day","event_type":"event","start_datetime":"2026-08-01T12:00:00Z","end_datetime":"2026-08-01T09:00:00Z"}`),
	))
	if rejectDates.Code != http.StatusBadRequest {
		t.Fatalf("invalid dates status=%d body=%s", rejectDates.Code, rejectDates.Body.String())
	}
	if !strings.Contains(rejectDates.Body.String(), "end_datetime cannot be before start_datetime") {
		t.Fatalf("date response should explain ordering: %s", rejectDates.Body.String())
	}

	create := httptest.NewRecorder()
	router.ServeHTTP(create, httptest.NewRequest(
		http.MethodPost,
		"/events",
		strings.NewReader(`{"academic_year_id":"`+f.yearID+`","event_title":"Sports Day","event_type":"event","start_datetime":"2026-08-01T09:00:00Z","end_datetime":"2026-08-01T12:00:00Z"}`),
	))
	if create.Code != http.StatusCreated {
		t.Fatalf("create event status=%d body=%s", create.Code, create.Body.String())
	}
}

func TestTablesMDEventsValidateAcademicYearScopeAndDates(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	externalSchool := models.School{
		BaseModel:  models.BaseModel{ID: "external-school"},
		Name:       "External School",
		SchoolType: "cbse",
	}
	externalYear := models.AcademicYear{
		BaseModel: models.BaseModel{ID: "external-year"},
		SchoolID:  externalSchool.ID,
		YearLabel: "2026-2027",
		StartDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		EndDate:   time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC),
		IsCurrent: true,
		Status:    "active",
	}
	if err := database.DB.Create(&externalSchool).Error; err != nil {
		t.Fatalf("seed external school: %v", err)
	}
	if err := database.DB.Create(&externalYear).Error; err != nil {
		t.Fatalf("seed external year: %v", err)
	}
	resource, ok := TablesMDResourceFor("events")
	if !ok {
		t.Fatal("events tables.md resource missing")
	}
	handler := NewTablesMDCRUDHandler(resource)
	router := scopedPolicyRouter("Principal", "user-policy-principal", "", "", "principal@policy.test", f.schoolID)
	router.POST("/events", handler.Create)

	rejectYear := httptest.NewRecorder()
	router.ServeHTTP(rejectYear, httptest.NewRequest(
		http.MethodPost,
		"/events",
		strings.NewReader(`{"academic_year_id":"external-year","event_name":"Sports Day","event_type":"event","start_date":"2026-08-01","end_date":"2026-08-01","start_time":"09:00","end_time":"12:00"}`),
	))
	if rejectYear.Code != http.StatusBadRequest {
		t.Fatalf("cross-school year status=%d body=%s", rejectYear.Code, rejectYear.Body.String())
	}
	if !strings.Contains(rejectYear.Body.String(), "academic year must belong to this school") {
		t.Fatalf("cross-school response should explain academic year: %s", rejectYear.Body.String())
	}

	rejectDates := httptest.NewRecorder()
	router.ServeHTTP(rejectDates, httptest.NewRequest(
		http.MethodPost,
		"/events",
		strings.NewReader(`{"academic_year_id":"`+f.yearID+`","event_name":"Sports Day","event_type":"event","start_date":"2026-08-01","end_date":"2026-08-01","start_time":"12:00","end_time":"09:00"}`),
	))
	if rejectDates.Code != http.StatusBadRequest {
		t.Fatalf("invalid dates status=%d body=%s", rejectDates.Code, rejectDates.Body.String())
	}
	if !strings.Contains(rejectDates.Body.String(), "end_date cannot be before start_date") {
		t.Fatalf("date response should explain ordering: %s", rejectDates.Body.String())
	}

	rejectDatetimes := httptest.NewRecorder()
	router.ServeHTTP(rejectDatetimes, httptest.NewRequest(
		http.MethodPost,
		"/events",
		strings.NewReader(`{"academic_year_id":"`+f.yearID+`","event_title":"Sports Day","event_type":"event","start_datetime":"2026-08-01T12:00:00Z","end_datetime":"2026-08-01T09:00:00Z"}`),
	))
	if rejectDatetimes.Code != http.StatusBadRequest {
		t.Fatalf("invalid datetimes status=%d body=%s", rejectDatetimes.Code, rejectDatetimes.Body.String())
	}
	if !strings.Contains(rejectDatetimes.Body.String(), "end_date cannot be before start_date") {
		t.Fatalf("datetime response should explain ordering: %s", rejectDatetimes.Body.String())
	}

	create := httptest.NewRecorder()
	router.ServeHTTP(create, httptest.NewRequest(
		http.MethodPost,
		"/events",
		strings.NewReader(`{"academic_year_id":"`+f.yearID+`","event_name":"Sports Day","event_type":"event","start_date":"2026-08-01","end_date":"2026-08-01","start_time":"09:00","end_time":"12:00"}`),
	))
	if create.Code != http.StatusCreated {
		t.Fatalf("create event status=%d body=%s", create.Code, create.Body.String())
	}
}

func TestCommunicationsDirectMessagesValidateScopeNotifyAndRead(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	resource, ok := TablesMDResourceFor("communications")
	if !ok {
		t.Fatal("communications tables.md resource missing")
	}
	handler := NewTablesMDCRUDHandler(resource)
	principalRouter := scopedPolicyRouter("Principal", "user-policy-principal", "", "", "principal@policy.test", f.schoolID)
	principalRouter.POST("/communications", handler.Create)
	principalRouter.GET("/communications", handler.List)

	rejectSender := httptest.NewRecorder()
	principalRouter.ServeHTTP(rejectSender, httptest.NewRequest(
		http.MethodPost,
		"/communications",
		strings.NewReader(`{"sender_id":"spoof-user","receiver_id":"user-policy-teacher","message_content":"Meet after assembly"}`),
	))
	if rejectSender.Code != http.StatusBadRequest {
		t.Fatalf("spoof sender status=%d body=%s", rejectSender.Code, rejectSender.Body.String())
	}

	rejectReceiverRole := httptest.NewRecorder()
	principalRouter.ServeHTTP(rejectReceiverRole, httptest.NewRequest(
		http.MethodPost,
		"/communications",
		strings.NewReader(`{"receiver_id":"user-policy-teacher","receiver_role":"Parent","message_content":"Meet after assembly"}`),
	))
	if rejectReceiverRole.Code != http.StatusBadRequest {
		t.Fatalf("spoof receiver role status=%d body=%s", rejectReceiverRole.Code, rejectReceiverRole.Body.String())
	}

	create := httptest.NewRecorder()
	principalRouter.ServeHTTP(create, httptest.NewRequest(
		http.MethodPost,
		"/communications",
		strings.NewReader(`{"receiver_id":"user-policy-teacher","message_content":"Meet after assembly"}`),
	))
	if create.Code != http.StatusCreated {
		t.Fatalf("create communication status=%d body=%s", create.Code, create.Body.String())
	}
	var created struct {
		Data map[string]any `json:"data"`
	}
	if err := json.Unmarshal(create.Body.Bytes(), &created); err != nil {
		t.Fatalf("decode created communication: %v body=%s", err, create.Body.String())
	}
	messageID, _ := created.Data["message_id"].(string)
	if messageID == "" {
		t.Fatalf("created communication missing message_id: %+v", created.Data)
	}
	if created.Data["sender_id"] != "user-policy-principal" || created.Data["sender_role"] != "principal" {
		t.Fatalf("sender should be auth derived, got %+v", created.Data)
	}
	if created.Data["receiver_role"] != "teacher" || created.Data["is_read"] != false {
		t.Fatalf("receiver/defaults mismatch: %+v", created.Data)
	}

	var teacherNotification models.NotificationLog
	if err := database.DB.
		Where("recipient_user_id = ? AND reference_type = ?", "user-policy-teacher", "communication").
		First(&teacherNotification).Error; err != nil {
		t.Fatalf("load teacher communication notification: %v", err)
	}
	if teacherNotification.Route != "/teacher-communication-screen" {
		t.Fatalf("teacher communication route=%q, want /teacher-communication-screen", teacherNotification.Route)
	}

	teacherRouter := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	teacherRouter.GET("/communications", handler.List)
	teacherRouter.PATCH("/communications/:id", handler.Update)
	teacherRouter.POST("/communications", handler.Create)

	teacherList := httptest.NewRecorder()
	teacherRouter.ServeHTTP(teacherList, httptest.NewRequest(http.MethodGet, "/communications", nil))
	if teacherList.Code != http.StatusOK {
		t.Fatalf("teacher list status=%d body=%s", teacherList.Code, teacherList.Body.String())
	}
	if findCommunicationRow(decodePolicyList(t, teacherList.Body.String()), messageID) == nil {
		t.Fatalf("teacher should see principal direct message: %s", teacherList.Body.String())
	}

	otherParentRouter := scopedPolicyRouter("Parent", f.otherParentUserID, "", "", "other.parent@policy.test", f.schoolID)
	otherParentRouter.GET("/communications", handler.List)
	otherParentList := httptest.NewRecorder()
	otherParentRouter.ServeHTTP(otherParentList, httptest.NewRequest(http.MethodGet, "/communications", nil))
	if otherParentList.Code != http.StatusOK {
		t.Fatalf("other parent list status=%d body=%s", otherParentList.Code, otherParentList.Body.String())
	}
	if findCommunicationRow(decodePolicyList(t, otherParentList.Body.String()), messageID) != nil {
		t.Fatalf("unrelated parent should not see teacher message: %s", otherParentList.Body.String())
	}

	markRead := httptest.NewRecorder()
	teacherRouter.ServeHTTP(markRead, httptest.NewRequest(
		http.MethodPatch,
		"/communications/"+messageID,
		strings.NewReader(`{"is_read":true}`),
	))
	if markRead.Code != http.StatusOK {
		t.Fatalf("mark read status=%d body=%s", markRead.Code, markRead.Body.String())
	}
	var readRow map[string]any
	if err := database.DB.Table("communications").Where("message_id = ?", messageID).Take(&readRow).Error; err != nil {
		t.Fatalf("load read communication: %v", err)
	}
	if readRow["is_read"] != true || readRow["read_at"] == nil {
		t.Fatalf("read status not persisted: %+v", readRow)
	}

	reply := httptest.NewRecorder()
	teacherRouter.ServeHTTP(reply, httptest.NewRequest(
		http.MethodPost,
		"/communications",
		strings.NewReader(`{"receiver_id":"user-policy-principal","message_content":"Noted, will join."}`),
	))
	if reply.Code != http.StatusCreated {
		t.Fatalf("teacher reply status=%d body=%s", reply.Code, reply.Body.String())
	}
	var principalNotification models.NotificationLog
	if err := database.DB.
		Where("recipient_user_id = ? AND reference_type = ?", "user-policy-principal", "communication").
		First(&principalNotification).Error; err != nil {
		t.Fatalf("load principal communication notification: %v", err)
	}
	if principalNotification.Route != "/communication-center-screen" {
		t.Fatalf("principal communication route=%q, want /communication-center-screen", principalNotification.Route)
	}
}

func findCommunicationRow(rows []map[string]any, messageID string) map[string]any {
	for _, row := range rows {
		if row["message_id"] == messageID || row["id"] == messageID {
			return row
		}
	}
	return nil
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
	router.DELETE("/notices/:id", NewOperationalAliasHandler().DeleteNotice)
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

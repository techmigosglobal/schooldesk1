package handlers

import (
	"context"
	"fmt"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

const notificationChannelInApp = "in_app"

func filterAnnouncementsForUser(c *gin.Context, rows []models.Announcement) []models.Announcement {
	role := currentRole(c)
	if role == "" || role == "admin" || role == "principal" {
		return rows
	}
	filtered := make([]models.Announcement, 0, len(rows))
	for _, row := range rows {
		if announcementVisibleToRole(c, row, role) {
			filtered = append(filtered, row)
		}
	}
	return filtered
}

func announcementVisibleToRole(c *gin.Context, row models.Announcement, role string) bool {
	if !audienceAllowsRole(row.TargetAudience, role) {
		return false
	}
	if row.TargetSectionID != nil && strings.TrimSpace(*row.TargetSectionID) != "" {
		if !canAccessSection(c, strings.TrimSpace(*row.TargetSectionID)) {
			return false
		}
	}
	if row.TargetGradeID != nil && strings.TrimSpace(*row.TargetGradeID) != "" {
		if !canAccessGrade(c, strings.TrimSpace(*row.TargetGradeID)) {
			return false
		}
	}
	return true
}

func audienceAllowsRole(audience string, role string) bool {
	roles := audienceTargetRoles(audience)
	if len(roles) == 0 {
		return true
	}
	role = strings.ToLower(strings.TrimSpace(role))
	for _, allowed := range roles {
		if allowed == role {
			return true
		}
	}
	return false
}

func audienceTargetRoles(audience string) []string {
	switch normalizeAudience(audience) {
	case "", "all", "everyone", "general", "notice", "circular", "academic", "exam", "exams", "event", "events", "holiday", "holidays", "finance", "fee", "fees", "meeting", "emergency", "urgent":
		return nil
	case "parent", "parents", "all-parents", "guardian", "guardians":
		return []string{"parent"}
	case "teacher", "teachers", "all-teachers", "staff":
		return []string{"teacher"}
	case "student", "students":
		return []string{"student", "parent"}
	case "admin", "admins":
		return []string{"admin"}
	case "principal", "principle", "principals":
		return []string{"principal"}
	default:
		return nil
	}
}

func normalizeAudience(value string) string {
	replacer := strings.NewReplacer("_", "-", " ", "-")
	return replacer.Replace(strings.ToLower(strings.TrimSpace(value)))
}

func createAnnouncementNotifications(row models.Announcement, referenceType string) {
	if strings.TrimSpace(row.SchoolID) == "" || strings.TrimSpace(row.ID) == "" {
		return
	}
	users := usersForAnnouncement(row)
	if len(users) == 0 {
		return
	}
	refID := row.ID
	now := time.Now().UTC()
	logs := make([]models.NotificationLog, 0, len(users))
	for _, user := range users {
		if strings.TrimSpace(user.ID) == "" {
			continue
		}
		logs = append(logs, models.NotificationLog{
			SchoolID:        row.SchoolID,
			RecipientUserID: user.ID,
			Channel:         notificationChannelInApp,
			Title:           row.Title,
			Body:            row.Content,
			Category:        notificationCategory(row.TargetAudience, referenceType),
			Priority:        notificationPriority(row.IsUrgent),
			Route:           notificationRoute(referenceType, userNotificationRole(user)),
			ReferenceType:   referenceType,
			ReferenceID:     &refID,
			IsRead:          false,
			SentAt:          now,
			DeliveryStatus:  "delivered",
			PushStatus:      "pending",
		})
	}
	if len(logs) > 0 {
		if err := database.DB.Create(&logs).Error; err == nil {
			enqueuePushNotifications(logs)
		}
	}
}

func createEventNotifications(row models.EventCalendar) {
	if strings.TrimSpace(row.SchoolID) == "" || strings.TrimSpace(row.ID) == "" {
		return
	}
	body := strings.TrimSpace(row.Description)
	if body == "" {
		body = "A school calendar event has been scheduled."
	}
	logs, err := createNotificationLogsForRolesTx(
		database.DB,
		row.SchoolID,
		nil,
		strings.TrimSpace(row.CreatedBy),
		row.EventTitle,
		body,
		"general",
		"medium",
		"event",
		row.ID,
	)
	if err == nil {
		enqueuePushNotifications(logs)
	}
}

func notifyHomeworkCreatedFromRecord(row HomeworkRecord) {
	schoolID := strings.TrimSpace(row.SchoolID)
	homeworkID := strings.TrimSpace(row.ID)
	if schoolID == "" || homeworkID == "" {
		return
	}
	users, err := parentUsersForHomeworkRecordTx(database.DB, row)
	if err != nil || len(users) == 0 {
		return
	}
	title := strings.TrimSpace(row.Title)
	if title == "" {
		title = "New homework assigned"
	} else {
		title = "Homework: " + title
	}
	body := strings.TrimSpace(row.Description)
	if body == "" {
		body = "A homework assignment has been posted."
	}
	if !row.DueDate.IsZero() {
		body = strings.TrimSpace(body + " Due " + row.DueDate.Format("2 Jan 2006") + ".")
	}
	logs, err := createNotificationLogsForUsersTx(
		database.DB,
		schoolID,
		users,
		title,
		body,
		"homework",
		"medium",
		"homework",
		homeworkID,
	)
	if err == nil {
		enqueuePushNotifications(logs)
	}
}

func notifyCommunicationCreatedFromRecord(row map[string]interface{}) {
	schoolID := communicationRecordString(row, "school_id")
	messageID := communicationRecordString(row, "message_id")
	receiverID := communicationRecordString(row, "receiver_id")
	if schoolID == "" || messageID == "" || receiverID == "" {
		return
	}
	senderName := communicationSenderName(schoolID, communicationRecordString(row, "sender_id"))
	title := "New direct message"
	if senderName != "" {
		title = "Message from " + senderName
	}
	body := communicationRecordString(row, "message_content")
	if body == "" {
		body = "A direct message has been sent."
	}
	priority := strings.ToLower(communicationRecordString(row, "priority"))
	if priority == "" {
		priority = "medium"
	}
	logs, err := createNotificationLogsForUserIDsTx(
		database.DB,
		schoolID,
		[]string{receiverID},
		title,
		body,
		"message",
		priority,
		"communication",
		messageID,
	)
	if err == nil {
		enqueuePushNotifications(logs)
	}
}

func notifyHomeworkCreated(row models.Homework) {
	schoolID := strings.TrimSpace(row.SchoolID)
	homeworkID := strings.TrimSpace(row.ID)
	if schoolID == "" || homeworkID == "" {
		return
	}
	users, err := parentUsersForHomeworkTx(database.DB, row)
	if err != nil || len(users) == 0 {
		return
	}
	title := strings.TrimSpace(row.Title)
	if title == "" {
		title = "New homework assigned"
	} else {
		title = "Homework: " + title
	}
	body := strings.TrimSpace(row.Description)
	if body == "" {
		body = "A homework assignment has been posted."
	}
	if !row.DueDate.IsZero() {
		body = strings.TrimSpace(body + " Due " + row.DueDate.Format("2 Jan 2006") + ".")
	}
	logs, err := createNotificationLogsForUsersTx(
		database.DB,
		schoolID,
		users,
		title,
		body,
		"homework",
		"medium",
		"homework",
		homeworkID,
	)
	if err == nil {
		enqueuePushNotifications(logs)
	}
}

func createExamScheduleNotifications(row models.ExamSchedule) {
	scheduleID := strings.TrimSpace(row.ID)
	if scheduleID == "" {
		return
	}
	var schedule models.ExamSchedule
	if err := database.DB.
		Preload("Exam").
		Preload("Subject").
		First(&schedule, "id = ?", scheduleID).Error; err == nil {
		row = schedule
	}
	schoolID := ""
	examName := ""
	if row.Exam != nil {
		schoolID = strings.TrimSpace(row.Exam.SchoolID)
		examName = strings.TrimSpace(row.Exam.ExamName)
	}
	if schoolID == "" && strings.TrimSpace(row.ExamID) != "" {
		var exam models.Exam
		if err := database.DB.First(&exam, "id = ?", strings.TrimSpace(row.ExamID)).Error; err == nil {
			schoolID = strings.TrimSpace(exam.SchoolID)
			examName = strings.TrimSpace(exam.ExamName)
		}
	}
	if schoolID == "" {
		return
	}
	parents, parentErr := parentUsersForSectionTx(database.DB, schoolID, row.SectionID)
	teachers, teacherErr := teacherUsersForSectionSubjectTx(database.DB, schoolID, row.SectionID, row.SubjectID)
	users := mergeNotificationUsers(parents, teachers)
	if (parentErr != nil && teacherErr != nil) || len(users) == 0 {
		return
	}
	title := "Exam schedule published"
	if examName != "" {
		title = "Exam: " + examName
	}
	subject := ""
	if row.Subject != nil {
		subject = strings.TrimSpace(row.Subject.SubjectName)
	}
	body := "An exam schedule has been added."
	if !row.ExamDate.IsZero() {
		body = "Exam date: " + row.ExamDate.Format("2 Jan 2006") + "."
	}
	if subject != "" {
		body = subject + " - " + body
	}
	logs, err := createNotificationLogsForUsersTx(
		database.DB,
		schoolID,
		users,
		title,
		body,
		"exam_reminder",
		"medium",
		"exam_schedule",
		scheduleID,
	)
	if err == nil {
		enqueuePushNotifications(logs)
	}
}

func createApprovalRequestedNotificationsTx(tx *gorm.DB, c *gin.Context, referenceID, title, body string) ([]models.NotificationLog, error) {
	body = strings.TrimSpace(body)
	if body == "" {
		body = "A new approval request is waiting for review."
	}
	return createNotificationLogsForRolesTx(
		tx,
		scopedSchoolID(c),
		[]string{"principal"},
		c.GetString("user_id"),
		title,
		body,
		"pending_approval",
		"high",
		"approval",
		referenceID,
	)
}

func createApprovalDecisionNotificationsTx(tx *gorm.DB, c *gin.Context, requesterUserID, referenceID, title, body string) ([]models.NotificationLog, error) {
	return createNotificationLogsForUserIDsTx(
		tx,
		scopedSchoolID(c),
		[]string{requesterUserID},
		title,
		body,
		"pending_approval",
		"medium",
		"approval",
		referenceID,
	)
}

func createNotificationLogsForRolesTx(
	tx *gorm.DB,
	schoolID string,
	roles []string,
	excludeUserID string,
	title string,
	body string,
	category string,
	priority string,
	referenceType string,
	referenceID string,
) ([]models.NotificationLog, error) {
	schoolID = strings.TrimSpace(schoolID)
	if schoolID == "" {
		return nil, nil
	}
	normalizedRoles := make([]string, 0, len(roles))
	for _, role := range roles {
		clean := strings.ToLower(strings.TrimSpace(role))
		if clean != "" {
			normalizedRoles = append(normalizedRoles, clean)
		}
	}
	var users []models.User
	query := tx.Preload("Role").
		Where("users.school_id = ? AND users.is_active = ?", schoolID, true)
	if len(normalizedRoles) > 0 {
		query = query.Joins("LEFT JOIN roles ON roles.id = users.role_id").
			Where("(LOWER(roles.role_name) IN ? OR LOWER(users.role) IN ?)", normalizedRoles, normalizedRoles)
	}
	if excludeUserID = strings.TrimSpace(excludeUserID); excludeUserID != "" {
		query = query.Where("users.id <> ?", excludeUserID)
	}
	if err := query.Find(&users).Error; err != nil {
		return nil, err
	}
	return createNotificationLogsForUsersTx(tx, schoolID, users, title, body, category, priority, referenceType, referenceID)
}

func createNotificationLogsForUserIDsTx(
	tx *gorm.DB,
	schoolID string,
	userIDs []string,
	title string,
	body string,
	category string,
	priority string,
	referenceType string,
	referenceID string,
) ([]models.NotificationLog, error) {
	ids := make([]string, 0, len(userIDs))
	seen := map[string]bool{}
	for _, id := range userIDs {
		clean := strings.TrimSpace(id)
		if clean == "" || seen[clean] {
			continue
		}
		seen[clean] = true
		ids = append(ids, clean)
	}
	if len(ids) == 0 || strings.TrimSpace(schoolID) == "" {
		return nil, nil
	}
	var users []models.User
	if err := tx.Preload("Role").
		Where("school_id = ? AND is_active = ? AND id IN ?", strings.TrimSpace(schoolID), true, ids).
		Find(&users).Error; err != nil {
		return nil, err
	}
	return createNotificationLogsForUsersTx(tx, schoolID, users, title, body, category, priority, referenceType, referenceID)
}

func createNotificationLogsForUsersTx(
	tx *gorm.DB,
	schoolID string,
	users []models.User,
	title string,
	body string,
	category string,
	priority string,
	referenceType string,
	referenceID string,
) ([]models.NotificationLog, error) {
	if len(users) == 0 {
		return nil, nil
	}
	title = strings.TrimSpace(title)
	if title == "" {
		title = "SchoolDesk notification"
	}
	body = strings.TrimSpace(body)
	if category = strings.TrimSpace(category); category == "" {
		category = "general"
	}
	if priority = strings.TrimSpace(priority); priority == "" {
		priority = "medium"
	}
	refType := strings.TrimSpace(referenceType)
	refID := strings.TrimSpace(referenceID)
	now := time.Now().UTC()
	logs := make([]models.NotificationLog, 0, len(users))
	for _, user := range users {
		if strings.TrimSpace(user.ID) == "" {
			continue
		}
		role := userNotificationRole(user)
		var ref *string
		if refID != "" {
			value := refID
			ref = &value
		}
		logs = append(logs, models.NotificationLog{
			SchoolID:        strings.TrimSpace(schoolID),
			RecipientUserID: user.ID,
			Channel:         notificationChannelInApp,
			Title:           title,
			Body:            body,
			Category:        category,
			Priority:        priority,
			Route:           notificationRoute(refType, role),
			ReferenceType:   refType,
			ReferenceID:     ref,
			IsRead:          false,
			SentAt:          now,
			DeliveryStatus:  "delivered",
			PushStatus:      "pending",
		})
	}
	if len(logs) == 0 {
		return nil, nil
	}
	if err := tx.Create(&logs).Error; err != nil {
		return nil, err
	}
	return logs, nil
}

func deleteAnnouncementNotifications(schoolID, announcementID string) error {
	return database.DB.
		Where("school_id = ? AND reference_type IN ? AND reference_id = ?", schoolID, []string{"announcement", "notice"}, announcementID).
		Delete(&models.NotificationLog{}).Error
}

func usersForAnnouncement(row models.Announcement) []models.User {
	var users []models.User
	query := database.DB.Preload("Role").
		Where("users.school_id = ? AND users.is_active = ?", row.SchoolID, true)
	if err := query.Find(&users).Error; err != nil {
		return nil
	}
	filtered := make([]models.User, 0, len(users))
	for _, user := range users {
		role := ""
		if user.Role != nil {
			role = user.Role.RoleName
		}
		if role == "" {
			role = user.RoleSlug
		}
		if !audienceAllowsRole(row.TargetAudience, role) {
			continue
		}
		if !userMatchesAnnouncementScope(user, row) {
			continue
		}
		filtered = append(filtered, user)
	}
	return filtered
}

func parentUsersForHomeworkRecordTx(tx *gorm.DB, row HomeworkRecord) ([]models.User, error) {
	schoolID := strings.TrimSpace(row.SchoolID)
	if schoolID == "" {
		return nil, nil
	}
	var groups [][]models.User
	if studentID := strings.TrimSpace(row.StudentID); studentID != "" {
		users, err := parentUsersForStudentIDsTx(tx, schoolID, []string{studentID})
		if err != nil {
			return nil, err
		}
		groups = append(groups, users)
	}
	if sectionID := strings.TrimSpace(row.SectionID); sectionID != "" {
		users, err := parentUsersForSectionTx(tx, schoolID, sectionID)
		if err != nil {
			return nil, err
		}
		groups = append(groups, users)
	}
	return mergeNotificationUsers(groups...), nil
}

func parentUsersForHomeworkTx(tx *gorm.DB, row models.Homework) ([]models.User, error) {
	schoolID := strings.TrimSpace(row.SchoolID)
	if schoolID == "" {
		return nil, nil
	}
	var groups [][]models.User
	if studentID := strings.TrimSpace(row.StudentID); studentID != "" {
		users, err := parentUsersForStudentIDsTx(tx, schoolID, []string{studentID})
		if err != nil {
			return nil, err
		}
		groups = append(groups, users)
	}
	if sectionID := strings.TrimSpace(row.SectionID); sectionID != "" {
		users, err := parentUsersForSectionTx(tx, schoolID, sectionID)
		if err != nil {
			return nil, err
		}
		groups = append(groups, users)
	}
	return mergeNotificationUsers(groups...), nil
}

func parentUsersForStudentIDsTx(tx *gorm.DB, schoolID string, studentIDs []string) ([]models.User, error) {
	ids := uniqueTrimmedStrings(studentIDs)
	if strings.TrimSpace(schoolID) == "" || len(ids) == 0 {
		return nil, nil
	}
	var users []models.User
	err := tx.Model(&models.User{}).
		Select("DISTINCT users.*").
		Joins("LEFT JOIN roles ON roles.id = users.role_id").
		Joins("JOIN parent_student_links ON parent_student_links.parent_user_id = users.id AND parent_student_links.school_id = users.school_id").
		Where("users.school_id = ? AND users.is_active = ?", strings.TrimSpace(schoolID), true).
		Where("(LOWER(users.role) = ? OR LOWER(roles.role_name) = ?)", "parent", "parent").
		Where("parent_student_links.student_id IN ?", ids).
		Find(&users).Error
	return users, err
}

func parentUsersForSectionTx(tx *gorm.DB, schoolID, sectionID string) ([]models.User, error) {
	schoolID = strings.TrimSpace(schoolID)
	sectionID = strings.TrimSpace(sectionID)
	if schoolID == "" || sectionID == "" {
		return nil, nil
	}
	var users []models.User
	err := tx.Model(&models.User{}).
		Select("DISTINCT users.*").
		Joins("LEFT JOIN roles ON roles.id = users.role_id").
		Joins("JOIN parent_student_links ON parent_student_links.parent_user_id = users.id AND parent_student_links.school_id = users.school_id").
		Joins("JOIN students ON students.id = parent_student_links.student_id").
		Joins("LEFT JOIN enrollments ON enrollments.student_id = students.id").
		Where("users.school_id = ? AND users.is_active = ?", schoolID, true).
		Where("(LOWER(users.role) = ? OR LOWER(roles.role_name) = ?)", "parent", "parent").
		Where("(students.current_section_id = ? OR enrollments.section_id = ?)", sectionID, sectionID).
		Find(&users).Error
	return users, err
}

func teacherUsersForSectionSubjectTx(tx *gorm.DB, schoolID, sectionID, subjectID string) ([]models.User, error) {
	schoolID = strings.TrimSpace(schoolID)
	sectionID = strings.TrimSpace(sectionID)
	subjectID = strings.TrimSpace(subjectID)
	if schoolID == "" || sectionID == "" {
		return nil, nil
	}
	query := tx.Model(&models.User{}).
		Select("DISTINCT users.*").
		Joins("LEFT JOIN roles ON roles.id = users.role_id").
		Joins("LEFT JOIN timetable_slots ON timetable_slots.staff_id = users.linked_id").
		Joins("LEFT JOIN sections ON sections.class_teacher_id = users.linked_id").
		Where("users.school_id = ? AND users.is_active = ?", schoolID, true).
		Where("(LOWER(users.role) = ? OR LOWER(roles.role_name) = ?)", "teacher", "teacher").
		Where("LOWER(users.linked_type) = ?", "staff").
		Where("(timetable_slots.section_id = ? OR sections.id = ?)", sectionID, sectionID)
	if subjectID != "" {
		query = query.Where("(timetable_slots.subject_id = ? OR sections.id = ?)", subjectID, sectionID)
	}
	var users []models.User
	err := query.Find(&users).Error
	return users, err
}

func uniqueTrimmedStrings(values []string) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(values))
	for _, value := range values {
		clean := strings.TrimSpace(value)
		if clean == "" || seen[clean] {
			continue
		}
		seen[clean] = true
		out = append(out, clean)
	}
	return out
}

func mergeNotificationUsers(groups ...[]models.User) []models.User {
	seen := map[string]bool{}
	out := []models.User{}
	for _, users := range groups {
		for _, user := range users {
			id := strings.TrimSpace(user.ID)
			if id == "" || seen[id] {
				continue
			}
			seen[id] = true
			out = append(out, user)
		}
	}
	return out
}

func userMatchesAnnouncementScope(user models.User, row models.Announcement) bool {
	sectionID := ""
	gradeID := ""
	if row.TargetSectionID != nil {
		sectionID = strings.TrimSpace(*row.TargetSectionID)
	}
	if row.TargetGradeID != nil {
		gradeID = strings.TrimSpace(*row.TargetGradeID)
	}
	if sectionID == "" && gradeID == "" {
		return true
	}
	role := ""
	if user.Role != nil {
		role = strings.ToLower(strings.TrimSpace(user.Role.RoleName))
	}
	if role == "" {
		role = strings.ToLower(strings.TrimSpace(user.RoleSlug))
	}
	switch role {
	case "admin", "principal":
		return true
	case "parent":
		return parentUserMatchesAnnouncementScope(user.SchoolID, user.ID, sectionID, gradeID)
	case "teacher":
		linkedID := ""
		if user.LinkedID != nil {
			linkedID = strings.TrimSpace(*user.LinkedID)
		}
		return teacherUserMatchesAnnouncementScope(user.SchoolID, linkedID, sectionID, gradeID)
	default:
		return true
	}
}

func parentUserMatchesAnnouncementScope(schoolID, userID, sectionID, gradeID string) bool {
	query := database.DB.Model(&models.ParentStudentLink{}).
		Joins("JOIN students ON students.id = parent_student_links.student_id").
		Joins("LEFT JOIN sections current_sections ON current_sections.id = students.current_section_id").
		Joins("LEFT JOIN enrollments ON enrollments.student_id = students.id").
		Joins("LEFT JOIN sections enrollment_sections ON enrollment_sections.id = enrollments.section_id").
		Where("parent_student_links.school_id = ? AND parent_student_links.parent_user_id = ?", schoolID, userID)
	if sectionID != "" {
		query = query.Where("(students.current_section_id = ? OR enrollments.section_id = ?)", sectionID, sectionID)
	}
	if gradeID != "" {
		query = query.Where("(current_sections.grade_id = ? OR enrollment_sections.grade_id = ?)", gradeID, gradeID)
	}
	return countRows(query) > 0
}

func teacherUserMatchesAnnouncementScope(schoolID, staffID, sectionID, gradeID string) bool {
	if staffID == "" {
		return false
	}
	query := database.DB.Model(&models.Section{}).
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ?", schoolID).
		Where(`
			(
				sections.class_teacher_id = ?
				OR EXISTS (
					SELECT 1 FROM timetable_slots
					WHERE timetable_slots.section_id = sections.id
						AND timetable_slots.staff_id = ?
				)
			)
		`, staffID, staffID)
	if sectionID != "" {
		query = query.Where("sections.id = ?", sectionID)
	}
	if gradeID != "" {
		query = query.Where("sections.grade_id = ?", gradeID)
	}
	return countRows(query) > 0
}

func normalizeMessageForCreate(c *gin.Context, message *models.Message) {
	role := currentRole(c)
	if role != "" {
		message.SenderRole = role
	}
	message.SenderRole = strings.ToLower(strings.TrimSpace(message.SenderRole))
	if userID := currentUserID(c); userID != "" {
		message.SenderID = userID
	}
	if message.SentAt.IsZero() {
		message.SentAt = time.Now().UTC()
	}
}

func notifyMessageCreated(message models.Message) {
	conversationID := strings.TrimSpace(message.ConversationID)
	if conversationID == "" {
		return
	}
	var conversation models.MessageConversation
	if err := database.DB.First(&conversation, "id = ?", conversationID).Error; err != nil {
		return
	}
	sentAt := message.SentAt
	if sentAt.IsZero() {
		sentAt = time.Now().UTC()
	}
	_ = database.DB.Model(&models.MessageConversation{}).
		Where("id = ?", conversation.ID).
		Updates(map[string]interface{}{
			"last_message":      message.Body,
			"last_message_time": sentAt,
		}).Error

	recipientID := messageRecipientUserID(conversation, message)
	if recipientID == "" || recipientID == message.SenderID {
		return
	}
	refID := message.ID
	title := "New message"
	if strings.TrimSpace(message.SenderName) != "" {
		title = "New message from " + strings.TrimSpace(message.SenderName)
	}
	body := strings.TrimSpace(message.Body)
	if len(body) > 180 {
		body = body[:180]
	}
	log := models.NotificationLog{
		SchoolID:        conversation.SchoolID,
		RecipientUserID: recipientID,
		Channel:         notificationChannelInApp,
		Title:           title,
		Body:            body,
		Category:        "general",
		Priority:        "medium",
		Route:           notificationRoute("message", messageRecipientRole(conversation, message)),
		ReferenceType:   "message",
		ReferenceID:     &refID,
		IsRead:          false,
		SentAt:          sentAt,
		DeliveryStatus:  "delivered",
		PushStatus:      "pending",
	}
	if err := database.DB.Create(&log).Error; err == nil {
		enqueuePushNotification(log)
	}
}

func messageRecipientUserID(conversation models.MessageConversation, message models.Message) string {
	switch strings.ToLower(strings.TrimSpace(message.SenderRole)) {
	case "parent":
		var user models.User
		err := database.DB.
			Where("school_id = ? AND linked_type = ? AND linked_id = ? AND is_active = ?", conversation.SchoolID, "staff", conversation.TeacherID, true).
			First(&user).Error
		if err != nil {
			return ""
		}
		return user.ID
	case "teacher":
		return strings.TrimSpace(conversation.ParentID)
	default:
		return ""
	}
}

func userNotificationRole(user models.User) string {
	if user.Role != nil && strings.TrimSpace(user.Role.RoleName) != "" {
		return strings.ToLower(strings.TrimSpace(user.Role.RoleName))
	}
	return strings.ToLower(strings.TrimSpace(user.RoleSlug))
}

func messageRecipientRole(_ models.MessageConversation, message models.Message) string {
	switch strings.ToLower(strings.TrimSpace(message.SenderRole)) {
	case "parent":
		return "teacher"
	case "teacher":
		return "parent"
	default:
		return ""
	}
}

func notificationCategory(audience, referenceType string) string {
	switch normalizeAudience(audience) {
	case "fee", "fees", "finance":
		return "fee_due"
	case "exam", "exams":
		return "exam_reminder"
	default:
		if strings.EqualFold(referenceType, "approval") {
			return "pending_approval"
		}
		return "general"
	}
}

func notificationPriority(isUrgent bool) string {
	if isUrgent {
		return "high"
	}
	return "medium"
}

func notificationRoute(referenceType, role string) string {
	role = strings.ToLower(strings.TrimSpace(role))
	switch strings.ToLower(strings.TrimSpace(referenceType)) {
	case "attendance", "staff_attendance":
		if role == "admin" {
			return "/admin-attendance-screen"
		}
		if role == "teacher" {
			return "/teacher-my-attendance-screen"
		}
		return "/principal-attendance-screen"
	case "announcement", "notice":
		switch role {
		case "parent":
			return "/parent-notices-screen"
		case "teacher":
			return "/teacher-communication-screen"
		case "admin":
			return "/admin-communication-screen"
		case "principal":
			return "/communication-center-screen"
		}
	case "message":
		if role == "parent" {
			return "/parent-teacher-chat-screen"
		}
		if role == "teacher" {
			return "/teacher-communication-screen"
		}
	case "communication":
		if role == "parent" {
			return "/parent-teacher-chat-screen"
		}
		if role == "teacher" {
			return "/teacher-communication-screen"
		}
		if role == "principal" {
			return "/communication-center-screen"
		}
		if role == "admin" {
			return "/admin-communication-screen"
		}
	case "homework":
		if role == "parent" {
			return "/parent-homework-screen"
		}
		if role == "teacher" {
			return "/teacher-homework-screen"
		}
	case "exam", "exam_schedule":
		if role == "parent" {
			return "/parent-calendar-screen"
		}
		if role == "teacher" {
			return "/teacher-performance-screen"
		}
		if role == "admin" {
			return "/admin-exams-screen"
		}
		if role == "principal" {
			return "/exams-results-screen"
		}
	case "event":
		if role == "parent" {
			return "/parent-calendar-screen"
		}
		return "/events-calendar-screen"
	case "fee":
		if role == "parent" {
			return "/parent-fees-screen"
		}
		if role == "admin" {
			return "/admin-fees-screen"
		}
		return "/fee-monitoring-screen"
	case "approval":
		return "/approval-center-screen"
	case "leave":
		if role == "parent" {
			return "/parent-leave-screen"
		}
		if role == "teacher" {
			return "/teacher-leave-screen"
		}
		return "/approval-center-screen"
	}
	return "/notification-center-screen"
}

func communicationRecordString(row map[string]interface{}, key string) string {
	if row == nil {
		return ""
	}
	switch value := row[key].(type) {
	case nil:
		return ""
	case string:
		return strings.TrimSpace(value)
	case []byte:
		return strings.TrimSpace(string(value))
	default:
		out := strings.TrimSpace(fmt.Sprint(value))
		if out == "<nil>" {
			return ""
		}
		return out
	}
}

func communicationSenderName(schoolID, senderID string) string {
	schoolID = strings.TrimSpace(schoolID)
	senderID = strings.TrimSpace(senderID)
	if schoolID == "" || senderID == "" {
		return ""
	}
	var user models.User
	if err := database.DB.First(&user, "id = ? AND school_id = ?", senderID, schoolID).Error; err != nil {
		return ""
	}
	if name := strings.TrimSpace(user.Name); name != "" {
		return name
	}
	if username := strings.TrimSpace(user.Username); username != "" {
		return username
	}
	if email := strings.TrimSpace(user.Email); email != "" {
		return email
	}
	return ""
}

func enqueuePushNotifications(logs []models.NotificationLog) {
	for _, log := range logs {
		enqueuePushNotification(log)
	}
}

func enqueuePushNotification(log models.NotificationLog) {
	if services.Queue == nil || strings.TrimSpace(log.ID) == "" {
		return
	}
	_ = services.Queue.Enqueue(context.Background(), "notifications", map[string]interface{}{
		"type":              "notification_push",
		"notification_id":   log.ID,
		"school_id":         log.SchoolID,
		"recipient_user_id": log.RecipientUserID,
	})
}

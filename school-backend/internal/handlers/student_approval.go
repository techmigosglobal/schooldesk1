package handlers

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

const studentApprovalResource = "student-approvals"

type StudentApprovalHandler struct{}

func NewStudentApprovalHandler() *StudentApprovalHandler {
	return &StudentApprovalHandler{}
}

func (h *StudentApprovalHandler) List(c *gin.Context) {
	var rows []models.FrontendRecord
	query := database.DB.
		Where("school_id = ? AND resource = ?", scopedSchoolID(c), studentApprovalResource).
		Order("created_at DESC")
	if strings.EqualFold(c.GetString("role_name"), "Admin") {
		query = query.Where("created_by = ?", c.GetString("user_id"))
	}
	if err := query.Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load student approvals")
		return
	}
	data := make([]gin.H, 0, len(rows))
	for _, row := range rows {
		payload := frontendRecordResponse(row)
		if payload["status"] == nil {
			payload["status"] = "pending"
		}
		payload["type"] = "student"
		if strings.TrimSpace(stringMapValue(payload["decisionPath"])) == "" {
			payload["decisionPath"] = "/" + studentApprovalResource + "/" + row.ID
		}
		data = append(data, payload)
	}
	success(c, http.StatusOK, data, "")
}

func (h *StudentApprovalHandler) Create(c *gin.Context) {
	var raw map[string]interface{}
	if err := c.ShouldBindJSON(&raw); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	if raw == nil {
		raw = map[string]interface{}{}
	}
	action := strings.ToLower(strings.TrimSpace(firstNonEmpty(stringMapValue(raw["action"]), "create")))
	if action != "create" && action != "update" && action != "delete" {
		fail(c, http.StatusBadRequest, "action must be create, update, or delete")
		return
	}
	studentPayload := mapFromInterface(raw["student"])
	if len(studentPayload) == 0 {
		studentPayload = raw
	}
	studentID := firstNonEmpty(stringMapValue(raw["student_id"]), stringMapValue(studentPayload["id"]))
	parentUserID := strings.TrimSpace(stringMapValue(raw["parent_user_id"]))

	var existing models.Student
	if action != "create" {
		if studentID == "" {
			fail(c, http.StatusBadRequest, "student_id is required")
			return
		}
		if err := database.DB.First(&existing, "id = ? AND school_id = ?", studentID, scopedSchoolID(c)).Error; err != nil {
			fail(c, http.StatusNotFound, "Student not found")
			return
		}
	}
	if parentUserID != "" {
		if err := validateParentUser(database.DB, scopedSchoolID(c), parentUserID); err != nil {
			fail(c, http.StatusBadRequest, err.Error())
			return
		}
	}
	if action == "create" {
		req := studentRequestFromMap(studentPayload)
		if strings.TrimSpace(req.FirstName) == "" || strings.TrimSpace(req.LastName) == "" ||
			strings.TrimSpace(req.DateOfBirth) == "" || strings.TrimSpace(req.Gender) == "" {
			fail(c, http.StatusBadRequest, "first_name, last_name, date_of_birth, and gender are required")
			return
		}
	}

	titleName := studentNameForApproval(action, studentPayload, existing)
	payload := gin.H{
		"type":               "student",
		"status":             "pending",
		"action":             action,
		"title":              studentApprovalTitle(action, titleName),
		"summary":            studentApprovalSummary(action, titleName, studentPayload),
		"details":            studentApprovalDetails(action, titleName, studentPayload, parentUserID),
		"requester_name":     firstNonEmpty(c.GetString("email"), "School Admin"),
		"requester_role":     "Admin",
		"requesterClass":     stringMapValue(studentPayload["class_label"]),
		"student_id":         studentID,
		"student":            studentPayload,
		"parent_user_id":     parentUserID,
		"submitted_at":       time.Now().UTC().Format(time.RFC3339),
		"decisionPath":       "",
		"created_by_user_id": c.GetString("user_id"),
	}
	encoded, err := jsonMarshal(payload)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid student approval payload")
		return
	}
	row := models.FrontendRecord{
		SchoolID:  scopedSchoolID(c),
		Resource:  studentApprovalResource,
		Payload:   encoded,
		CreatedBy: c.GetString("user_id"),
	}
	if err := database.DB.Create(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create student approval")
		return
	}
	payload["id"] = row.ID
	payload["school_id"] = row.SchoolID
	payload["resource"] = row.Resource
	payload["created_at"] = row.CreatedAt
	payload["updated_at"] = row.UpdatedAt
	payload["created_by"] = row.CreatedBy
	payload["decisionPath"] = "/" + studentApprovalResource + "/" + row.ID
	auditAction(c, studentApprovalResource, "create", "frontend_records", &row.ID)
	if logs, err := createApprovalRequestedNotificationsTx(
		database.DB,
		c,
		row.ID,
		"Student approval pending",
		fmt.Sprintf("%s requested %s for Principal approval.", c.GetString("role_name"), titleName),
	); err == nil {
		enqueuePushNotifications(logs)
	}
	success(c, http.StatusCreated, payload, "Student request sent for principal approval")
}

func (h *StudentApprovalHandler) Decide(c *gin.Context) {
	var row models.FrontendRecord
	if err := database.DB.First(&row, "id = ? AND school_id = ? AND resource = ?", c.Param("id"), scopedSchoolID(c), studentApprovalResource).Error; err != nil {
		fail(c, http.StatusNotFound, "Student approval not found")
		return
	}
	var req struct {
		Status  string `json:"status" binding:"required"`
		Remarks string `json:"remarks"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	status := strings.ToLower(strings.TrimSpace(req.Status))
	if status != "approved" && status != "rejected" {
		fail(c, http.StatusBadRequest, "status must be approved or rejected")
		return
	}
	payload := frontendPayload(row.Payload)
	currentStatus := strings.ToLower(strings.TrimSpace(stringMapValue(payload["status"])))
	if currentStatus != "" && currentStatus != "pending" {
		fail(c, http.StatusBadRequest, "Student approval has already been actioned")
		return
	}

	var decisionLogs []models.NotificationLog
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if status == "approved" {
			studentID, err := applyStudentApproval(tx, scopedSchoolID(c), payload)
			if err != nil {
				return err
			}
			if studentID != "" {
				payload["student_id"] = studentID
				payload["applied_student_id"] = studentID
			}
		}
		payload["status"] = status
		payload["remarks"] = strings.TrimSpace(req.Remarks)
		payload["action_date"] = time.Now().UTC().Format(time.RFC3339)
		payload["decision_by_id"] = c.GetString("user_id")
		payload["decision_by"] = c.GetString("email")
		encoded, err := jsonMarshal(payload)
		if err != nil {
			return err
		}
		row.Payload = encoded
		if err := tx.Save(&row).Error; err != nil {
			return err
		}
		logs, err := createApprovalDecisionNotificationsTx(
			tx,
			c,
			row.CreatedBy,
			row.ID,
			"Student approval "+status,
			fmt.Sprintf("Your student request for %s was %s.", studentNameForApproval(stringMapValue(payload["action"]), mapFromInterface(payload["student"]), models.Student{}), status),
		)
		if err != nil {
			return nil
		}
		decisionLogs = logs
		return nil
	}); err != nil {
		fail(c, statusForApprovalApplyError(err), err.Error())
		return
	}

	auditAction(c, studentApprovalResource, status, "frontend_records", &row.ID)
	enqueuePushNotifications(decisionLogs)
	success(c, http.StatusOK, frontendRecordResponse(row), "Student approval updated")
}

type approvalApplyError struct {
	status int
	err    error
}

func (e approvalApplyError) Error() string {
	if e.err == nil {
		return ""
	}
	return e.err.Error()
}

func statusForApprovalApplyError(err error) int {
	if typed, ok := err.(approvalApplyError); ok && typed.status > 0 {
		return typed.status
	}
	return http.StatusInternalServerError
}

func applyStudentApproval(tx *gorm.DB, schoolID string, payload gin.H) (string, error) {
	action := strings.ToLower(strings.TrimSpace(stringMapValue(payload["action"])))
	studentPayload := mapFromInterface(payload["student"])
	parentUserID := strings.TrimSpace(stringMapValue(payload["parent_user_id"]))
	switch action {
	case "create":
		req := studentRequestFromMap(studentPayload)
		student, status, err := createStudentForSchool(tx, schoolID, req)
		if err != nil {
			return "", approvalApplyError{status: status, err: err}
		}
		if err := replaceStudentParentLink(tx, schoolID, student, parentUserID); err != nil {
			return "", approvalApplyError{status: http.StatusBadRequest, err: err}
		}
		return student.ID, nil
	case "update":
		studentID := firstNonEmpty(stringMapValue(payload["student_id"]), stringMapValue(studentPayload["id"]))
		if studentID == "" {
			return "", fmt.Errorf("student_id is required")
		}
		req := studentRequestFromMap(studentPayload)
		student, status, err := updateStudentForSchool(tx, schoolID, studentID, req)
		if err != nil {
			return "", approvalApplyError{status: status, err: err}
		}
		if _, hasParentKey := payload["parent_user_id"]; hasParentKey {
			if err := replaceStudentParentLink(tx, schoolID, student, parentUserID); err != nil {
				return "", approvalApplyError{status: http.StatusBadRequest, err: err}
			}
		}
		return student.ID, nil
	case "delete":
		studentID := firstNonEmpty(stringMapValue(payload["student_id"]), stringMapValue(studentPayload["id"]))
		if studentID == "" {
			return "", fmt.Errorf("student_id is required")
		}
		var student models.Student
		if err := tx.First(&student, "id = ? AND school_id = ?", studentID, schoolID).Error; err != nil {
			return "", fmt.Errorf("student not found")
		}
		if err := tx.Model(&models.Student{}).
			Where("id = ? AND school_id = ?", studentID, schoolID).
			Update("status", "inactive").Error; err != nil {
			return "", fmt.Errorf("failed to deactivate student")
		}
		if err := replaceStudentParentLink(tx, schoolID, student, ""); err != nil {
			return "", err
		}
		return studentID, nil
	default:
		return "", fmt.Errorf("unsupported student approval action")
	}
}

func studentRequestFromMap(values map[string]interface{}) models.CreateStudentRequest {
	return models.CreateStudentRequest{
		StudentCode:      stringMapValue(values["student_code"]),
		AdmissionNumber:  stringMapValue(values["admission_number"]),
		FirstName:        stringMapValue(values["first_name"]),
		LastName:         stringMapValue(values["last_name"]),
		DateOfBirth:      stringMapValue(values["date_of_birth"]),
		Gender:           stringMapValue(values["gender"]),
		AdmissionDate:    firstNonEmpty(stringMapValue(values["admission_date"]), time.Now().UTC().Format("2006-01-02")),
		CurrentSectionID: stringMapValue(values["current_section_id"]),
		Status:           firstNonEmpty(stringMapValue(values["status"]), "active"),
	}
}

func mapFromInterface(value interface{}) map[string]interface{} {
	switch typed := value.(type) {
	case gin.H:
		return map[string]interface{}(typed)
	case map[string]interface{}:
		return typed
	case map[string]string:
		out := make(map[string]interface{}, len(typed))
		for k, v := range typed {
			out[k] = v
		}
		return out
	default:
		return map[string]interface{}{}
	}
}

func validateParentUser(db *gorm.DB, schoolID, parentUserID string) error {
	var parent models.User
	if err := db.Preload("Role").
		Where("id = ? AND school_id = ?", parentUserID, schoolID).
		First(&parent).Error; err != nil {
		return fmt.Errorf("parent user not found")
	}
	if parent.Role == nil || !strings.EqualFold(strings.TrimSpace(parent.Role.RoleName), "parent") {
		return fmt.Errorf("provided user is not a parent")
	}
	return nil
}

func studentNameForApproval(action string, studentPayload map[string]interface{}, existing models.Student) string {
	name := strings.TrimSpace(strings.Join([]string{
		stringMapValue(studentPayload["first_name"]),
		stringMapValue(studentPayload["last_name"]),
	}, " "))
	if name != "" {
		return name
	}
	if action != "create" && strings.TrimSpace(existing.ID) != "" {
		return strings.TrimSpace(strings.Join([]string{existing.FirstName, existing.LastName}, " "))
	}
	return "student"
}

func studentApprovalTitle(action, name string) string {
	switch action {
	case "update":
		return "Update " + name
	case "delete":
		return "Remove " + name
	default:
		return "Create " + name
	}
}

func studentApprovalSummary(action, name string, studentPayload map[string]interface{}) string {
	classLabel := firstNonEmpty(stringMapValue(studentPayload["class_label"]), stringMapValue(studentPayload["current_section_id"]), "Unassigned")
	switch action {
	case "update":
		return fmt.Sprintf("Update %s in %s", name, classLabel)
	case "delete":
		return fmt.Sprintf("Move %s to inactive student records", name)
	default:
		return fmt.Sprintf("Create %s in %s", name, classLabel)
	}
}

func studentApprovalDetails(action, name string, studentPayload map[string]interface{}, parentUserID string) string {
	lines := []string{
		"Action: " + action,
		"Student: " + name,
	}
	if admission := stringMapValue(studentPayload["admission_number"]); admission != "" {
		lines = append(lines, "Admission number: "+admission)
	}
	if classLabel := stringMapValue(studentPayload["class_label"]); classLabel != "" {
		lines = append(lines, "Class / Section: "+classLabel)
	}
	if parentUserID != "" {
		lines = append(lines, "Linked parent user: "+parentUserID)
	}
	return strings.Join(lines, "\n")
}

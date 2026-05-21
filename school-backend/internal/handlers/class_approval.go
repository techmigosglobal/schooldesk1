package handlers

import (
	"fmt"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

const classApprovalResource = "class-approvals"

type ClassApprovalHandler struct{}

func NewClassApprovalHandler() *ClassApprovalHandler {
	return &ClassApprovalHandler{}
}

func (h *ClassApprovalHandler) List(c *gin.Context) {
	var rows []models.FrontendRecord
	query := database.DB.
		Where("school_id = ? AND resource = ?", scopedSchoolID(c), classApprovalResource).
		Order("created_at DESC")
	if strings.EqualFold(c.GetString("role_name"), "Admin") {
		query = query.Where("created_by = ?", c.GetString("user_id"))
	}
	if err := query.Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load class approvals")
		return
	}
	data := make([]gin.H, 0, len(rows))
	for _, row := range rows {
		payload := frontendRecordResponse(row)
		if payload["status"] == nil {
			payload["status"] = "pending"
		}
		payload["type"] = "class"
		if strings.TrimSpace(stringMapValue(payload["decisionPath"])) == "" {
			payload["decisionPath"] = "/" + classApprovalResource + "/" + row.ID
		}
		data = append(data, payload)
	}
	success(c, http.StatusOK, data, "")
}

func (h *ClassApprovalHandler) Create(c *gin.Context) {
	var req struct {
		ClassName      string   `json:"class_name"`
		Name           string   `json:"name"`
		Sections       []string `json:"sections"`
		Section        string   `json:"section"`
		Strength       int      `json:"strength"`
		Capacity       int      `json:"capacity"`
		GradeNumber    int      `json:"grade_number"`
		AcademicYearID string   `json:"academic_year_id"`
		ClassTeacherID string   `json:"class_teacher_id"`
		Details        string   `json:"details"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	className := strings.TrimSpace(firstNonEmpty(req.ClassName, req.Name))
	if className == "" {
		fail(c, http.StatusBadRequest, "class_name is required")
		return
	}
	sections := cleanSections(req.Sections)
	if len(sections) == 0 && strings.TrimSpace(req.Section) != "" {
		sections = cleanSections(strings.Split(req.Section, ","))
	}
	if len(sections) == 0 {
		sections = []string{"A"}
	}
	capacity := req.Capacity
	if capacity <= 0 {
		capacity = req.Strength
	}
	if capacity <= 0 {
		capacity = 40
	}
	gradeNumber := req.GradeNumber
	if gradeNumber <= 0 {
		gradeNumber = gradeNumberFromName(className)
	}
	payload := gin.H{
		"type":               "class",
		"status":             "pending",
		"title":              "Create " + className,
		"summary":            fmt.Sprintf("%s with sections %s", className, strings.Join(sections, ", ")),
		"details":            firstNonEmpty(req.Details, fmt.Sprintf("Capacity per section: %d", capacity)),
		"requester_name":     firstNonEmpty(c.GetString("email"), "School Admin"),
		"requester_role":     "Admin",
		"class_name":         className,
		"sections":           sections,
		"capacity":           capacity,
		"grade_number":       gradeNumber,
		"academic_year_id":   strings.TrimSpace(req.AcademicYearID),
		"class_teacher_id":   strings.TrimSpace(req.ClassTeacherID),
		"submitted_at":       time.Now().UTC().Format(time.RFC3339),
		"decisionPath":       "",
		"created_by_user_id": c.GetString("user_id"),
	}
	encoded, err := jsonMarshal(payload)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid class approval payload")
		return
	}
	row := models.FrontendRecord{
		SchoolID:  scopedSchoolID(c),
		Resource:  classApprovalResource,
		Payload:   encoded,
		CreatedBy: c.GetString("user_id"),
	}
	if err := database.DB.Create(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create class approval")
		return
	}
	payload["id"] = row.ID
	payload["school_id"] = row.SchoolID
	payload["resource"] = row.Resource
	payload["created_at"] = row.CreatedAt
	payload["updated_at"] = row.UpdatedAt
	payload["created_by"] = row.CreatedBy
	payload["decisionPath"] = "/" + classApprovalResource + "/" + row.ID
	auditAction(c, classApprovalResource, "create", "frontend_records", &row.ID)
	if logs, err := createApprovalRequestedNotificationsTx(
		database.DB,
		c,
		row.ID,
		"Class approval pending",
		fmt.Sprintf("%s requested %s for Principal approval.", c.GetString("role_name"), className),
	); err == nil {
		enqueuePushNotifications(logs)
	}
	success(c, http.StatusCreated, payload, "Class request sent for principal approval")
}

func (h *ClassApprovalHandler) Decide(c *gin.Context) {
	var row models.FrontendRecord
	if err := database.DB.First(&row, "id = ? AND school_id = ? AND resource = ?", c.Param("id"), scopedSchoolID(c), classApprovalResource).Error; err != nil {
		fail(c, http.StatusNotFound, "Class approval not found")
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
		fail(c, http.StatusBadRequest, "Class approval has already been actioned")
		return
	}

	var decisionLogs []models.NotificationLog
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if status == "approved" {
			gradeID, sectionIDs, err := createApprovedClass(tx, scopedSchoolID(c), payload)
			if err != nil {
				return err
			}
			payload["grade_id"] = gradeID
			payload["section_ids"] = sectionIDs
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
			"Class approval "+status,
			fmt.Sprintf("Your class request for %s was %s.", stringMapValue(payload["class_name"]), status),
		)
		if err != nil {
			return nil
		}
		decisionLogs = logs
		return nil
	}); err != nil {
		fail(c, http.StatusInternalServerError, err.Error())
		return
	}

	auditAction(c, classApprovalResource, status, "frontend_records", &row.ID)
	enqueuePushNotifications(decisionLogs)
	success(c, http.StatusOK, frontendRecordResponse(row), "Class approval updated")
}

func createApprovedClass(tx *gorm.DB, schoolID string, payload gin.H) (string, []string, error) {
	className := strings.TrimSpace(firstNonEmpty(stringMapValue(payload["class_name"]), stringMapValue(payload["name"])))
	if className == "" {
		return "", nil, fmt.Errorf("approval is missing class_name")
	}
	gradeNumber := intFromInterface(payload["grade_number"])
	if gradeNumber <= 0 {
		gradeNumber = gradeNumberFromName(className)
	}
	grade := models.Grade{
		SchoolID:    schoolID,
		GradeNumber: gradeNumber,
		GradeName:   className,
	}
	if err := tx.Where("school_id = ? AND LOWER(grade_name) = ?", schoolID, strings.ToLower(className)).
		FirstOrCreate(&grade, models.Grade{
			SchoolID:    schoolID,
			GradeNumber: gradeNumber,
			GradeName:   className,
		}).Error; err != nil {
		return "", nil, err
	}
	yearID := strings.TrimSpace(stringMapValue(payload["academic_year_id"]))
	if yearID == "" {
		var year models.AcademicYear
		if err := tx.Where("school_id = ? AND is_current = ?", schoolID, true).First(&year).Error; err != nil {
			if err == gorm.ErrRecordNotFound {
				return "", nil, fmt.Errorf("current academic year is required before approving class")
			}
			return "", nil, err
		}
		yearID = year.ID
	}
	if err := tx.First(&models.AcademicYear{}, "id = ? AND school_id = ?", yearID, schoolID).Error; err != nil {
		return "", nil, fmt.Errorf("academic year not found for this school")
	}
	sections := sectionsFromPayload(payload["sections"])
	if len(sections) == 0 {
		sections = []string{"A"}
	}
	capacity := intFromInterface(payload["capacity"])
	if capacity <= 0 {
		capacity = intFromInterface(payload["strength"])
	}
	if capacity <= 0 {
		capacity = 40
	}
	classTeacherID := strings.TrimSpace(stringMapValue(payload["class_teacher_id"]))
	sectionIDs := make([]string, 0, len(sections))
	for _, sectionName := range sections {
		section := models.Section{
			GradeID:        grade.ID,
			AcademicYearID: yearID,
			SectionName:    sectionName,
			Capacity:       capacity,
		}
		attrs := models.Section{Capacity: capacity}
		if classTeacherID != "" {
			section.ClassTeacherID = &classTeacherID
			attrs.ClassTeacherID = &classTeacherID
		}
		if err := tx.Where("grade_id = ? AND academic_year_id = ? AND LOWER(section_name) = ?", grade.ID, yearID, strings.ToLower(sectionName)).
			FirstOrCreate(&section, attrs).Error; err != nil {
			return "", nil, err
		}
		sectionIDs = append(sectionIDs, section.ID)
	}
	return grade.ID, sectionIDs, nil
}

func cleanSections(values []string) []string {
	seen := map[string]bool{}
	sections := make([]string, 0, len(values))
	for _, value := range values {
		section := strings.TrimSpace(value)
		if section == "" {
			continue
		}
		key := strings.ToLower(section)
		if seen[key] {
			continue
		}
		seen[key] = true
		sections = append(sections, section)
	}
	return sections
}

func sectionsFromPayload(value interface{}) []string {
	switch typed := value.(type) {
	case []string:
		return cleanSections(typed)
	case []interface{}:
		values := make([]string, 0, len(typed))
		for _, item := range typed {
			values = append(values, fmt.Sprint(item))
		}
		return cleanSections(values)
	case string:
		return cleanSections(strings.Split(typed, ","))
	default:
		return nil
	}
}

func gradeNumberFromName(name string) int {
	match := regexp.MustCompile(`\d+`).FindString(name)
	if match == "" {
		return 1
	}
	parsed, err := strconv.Atoi(match)
	if err != nil || parsed <= 0 {
		return 1
	}
	return parsed
}

func intFromInterface(value interface{}) int {
	switch typed := value.(type) {
	case int:
		return typed
	case int64:
		return int(typed)
	case float64:
		return int(typed)
	case float32:
		return int(typed)
	case string:
		parsed, _ := strconv.Atoi(strings.TrimSpace(typed))
		return parsed
	default:
		return 0
	}
}

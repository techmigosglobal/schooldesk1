package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"reflect"
	"strings"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type CRUDHandler[T any] struct {
	Module       string
	TableName    string
	Required     []string
	SchoolScoped bool
	Preloads     []string
}

func NewCRUDHandler[T any](module, tableName string, required []string, schoolScoped bool, preloads ...string) *CRUDHandler[T] {
	return &CRUDHandler[T]{
		Module:       module,
		TableName:    tableName,
		Required:     required,
		SchoolScoped: schoolScoped,
		Preloads:     preloads,
	}
}

func (h *CRUDHandler[T]) List(c *gin.Context) {
	page, pageSize := parsePagination(c)
	offset := (page - 1) * pageSize

	var rows []T
	var total int64
	query := h.scopedQuery(c).Model(new(T))
	query = h.applyListFilters(c, query)
	for _, preload := range h.Preloads {
		query = query.Preload(preload)
	}
	if err := query.Count(&total).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to count "+h.Module)
		return
	}
	if err := query.Offset(offset).Limit(pageSize).Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to list "+h.Module)
		return
	}
	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, rows))
}

func (h *CRUDHandler[T]) Get(c *gin.Context) {
	var row T
	query := h.scopedQuery(c)
	for _, preload := range h.Preloads {
		query = query.Preload(preload)
	}
	if err := query.First(&row, h.idCondition(), c.Param("id")).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			fail(c, http.StatusNotFound, h.Module+" not found")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to load "+h.Module)
		return
	}
	success(c, http.StatusOK, row, "")
}

func (h *CRUDHandler[T]) Create(c *gin.Context) {
	var row T
	if err := h.bindAndValidate(c, &row, true); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	h.prepareCreate(c, &row)
	h.applySchoolScope(c, &row)
	if err := h.validateRelationshipPolicy(c, &row); err != nil {
		fail(c, http.StatusForbidden, err.Error())
		return
	}
	if err := database.DB.Create(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create "+h.Module)
		return
	}
	id := modelID(&row)
	auditAction(c, h.Module, "create", h.TableName, &id)
	h.afterCreate(c, &row)
	success(c, http.StatusCreated, row, "")
}

func (h *CRUDHandler[T]) Update(c *gin.Context) {
	id := c.Param("id")
	var row T
	if err := h.scopedQuery(c).First(&row, h.idCondition(), id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			fail(c, http.StatusNotFound, h.Module+" not found")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to load "+h.Module)
		return
	}
	if h.TableName == "messages" {
		if message, ok := any(&row).(*models.Message); ok {
			h.updateMessageReadReceipt(c, message)
			return
		}
	}
	if err := h.bindAndValidate(c, &row, false); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	setStringField(&row, "ID", id)
	h.applySchoolScope(c, &row)
	if err := h.validateRelationshipPolicy(c, &row); err != nil {
		fail(c, http.StatusForbidden, err.Error())
		return
	}
	if err := database.DB.Save(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update "+h.Module)
		return
	}
	auditAction(c, h.Module, "update", h.TableName, &id)
	success(c, http.StatusOK, row, "")
}

func (h *CRUDHandler[T]) updateMessageReadReceipt(c *gin.Context, message *models.Message) {
	var payload map[string]interface{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	if len(payload) != 1 {
		fail(c, http.StatusBadRequest, "Only is_read can be updated for messages")
		return
	}
	value, ok := payload["is_read"].(bool)
	if !ok || !value {
		fail(c, http.StatusBadRequest, "is_read must be true")
		return
	}
	if message.SenderID == currentUserID(c) && !isSchoolOperator(c) {
		fail(c, http.StatusForbidden, "sender cannot mark own message as read")
		return
	}
	if err := database.DB.Model(message).Update("is_read", true).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to mark message as read")
		return
	}
	message.IsRead = true
	id := message.ID
	auditAction(c, h.Module, "read", h.TableName, &id)
	success(c, http.StatusOK, message, "")
}

func (h *CRUDHandler[T]) Delete(c *gin.Context) {
	id := c.Param("id")
	result := h.scopedQuery(c).Delete(new(T), h.idCondition(), id)
	if result.Error != nil {
		fail(c, http.StatusInternalServerError, "Failed to delete "+h.Module)
		return
	}
	if result.RowsAffected == 0 {
		fail(c, http.StatusNotFound, h.Module+" not found")
		return
	}
	auditAction(c, h.Module, "delete", h.TableName, &id)
	success(c, http.StatusOK, nil, h.Module+" deleted successfully")
}

func (h *CRUDHandler[T]) scopedQuery(c *gin.Context) *gorm.DB {
	query := database.DB
	if h.SchoolScoped {
		query = query.Where("school_id = ?", scopedSchoolID(c))
	}
	query = h.applyRoleRelationshipScope(c, query)
	return query
}

func (h *CRUDHandler[T]) idCondition() string {
	switch h.actualTableName() {
	case "messages", "parent_teacher_meetings", "terms", "staff_subjects":
		return h.actualTableName() + ".id = ?"
	default:
		return "id = ?"
	}
}

func (h *CRUDHandler[T]) actualTableName() string {
	return h.TableName
}

func (h *CRUDHandler[T]) applyListFilters(c *gin.Context, query *gorm.DB) *gorm.DB {
	switch h.TableName {
	case "homework":
		return h.applyHomeworkListFilters(c, query)
	case "staff_subjects":
		return h.applyStaffSubjectListFilters(c, query)
	case "grade_subjects":
		return h.applyGradeSubjectListFilters(c, query)
	default:
		return query
	}
}

func (h *CRUDHandler[T]) applyGradeSubjectListFilters(c *gin.Context, query *gorm.DB) *gorm.DB {
	for _, field := range []string{"grade_id", "subject_id"} {
		if value := strings.TrimSpace(c.Query(field)); value != "" {
			query = query.Where("grade_subjects."+field+" = ?", value)
		}
	}
	return query
}

func (h *CRUDHandler[T]) applyStaffSubjectListFilters(c *gin.Context, query *gorm.DB) *gorm.DB {
	for _, field := range []string{"staff_id", "subject_id", "grade_id", "section_id"} {
		if value := strings.TrimSpace(c.Query(field)); value != "" {
			query = query.Where("staff_subjects."+field+" = ?", value)
		}
	}
	return query
}

func (h *CRUDHandler[T]) applyHomeworkListFilters(c *gin.Context, query *gorm.DB) *gorm.DB {
	table := h.actualTableName()
	if studentID := strings.TrimSpace(c.Query("student_id")); studentID != "" {
		if !canAccessStudent(c, studentID) {
			return query.Where("1 = 0")
		}
		studentCurrentSection := database.DB.Model(&models.Student{}).
			Select("students.current_section_id").
			Where("students.id = ? AND students.school_id = ?", studentID, currentSchoolID(c)).
			Where("students.current_section_id IS NOT NULL AND students.current_section_id != ''")
		studentEnrollmentSections := database.DB.Model(&models.Enrollment{}).
			Select("enrollments.section_id").
			Joins("JOIN students ON students.id = enrollments.student_id").
			Where("students.school_id = ? AND enrollments.student_id = ?", currentSchoolID(c), studentID)
		query = query.Where(fmt.Sprintf(`
			(
				%s.student_id = ?
				OR (
					(%s.student_id = '' OR %s.student_id IS NULL)
					AND (
						%s.section_id IN (?)
						OR %s.section_id IN (?)
					)
				)
			)
		`, table, table, table, table, table), studentID, studentCurrentSection, studentEnrollmentSections)
	}
	if sectionID := strings.TrimSpace(c.Query("section_id")); sectionID != "" {
		query = query.Where(table+".section_id = ?", sectionID)
	}
	if teacherID := strings.TrimSpace(c.Query("teacher_id")); teacherID != "" {
		query = query.Where(table+".teacher_id = ?", teacherID)
	}
	if status := strings.TrimSpace(c.Query("status")); status != "" {
		query = query.Where("LOWER("+table+".status) = ?", strings.ToLower(status))
	}
	return query
}

func (h *CRUDHandler[T]) applyRoleRelationshipScope(c *gin.Context, query *gorm.DB) *gorm.DB {
	role := currentRole(c)
	if role == "" {
		return query
	}
	schoolID := currentSchoolID(c)
	switch h.TableName {
	case "terms":
		return query.
			Joins("JOIN academic_years ON academic_years.id = terms.academic_year_id").
			Where("academic_years.school_id = ?", schoolID)
	case "parent_student_links":
		if role == "parent" {
			return query.Where("parent_user_id = ?", currentUserID(c))
		}
	case "staff_subjects":
		query = query.
			Where("staff_subjects.staff_id IN (?)", database.DB.Model(&models.Staff{}).Select("id").Where("school_id = ?", schoolID)).
			Where("staff_subjects.subject_id IN (?)", database.DB.Model(&models.Subject{}).Select("id").Where("school_id = ?", schoolID)).
			Where("staff_subjects.grade_id IN (?)", database.DB.Model(&models.Grade{}).Select("id").Where("school_id = ?", schoolID))
		switch role {
		case "admin", "principal":
			return query
		case "teacher":
			staffID := currentStaffID(c)
			if staffID == "" {
				return query.Where("1 = 0")
			}
			return query.Where("staff_subjects.staff_id = ?", staffID)
		default:
			return query.Where("1 = 0")
		}
	case "grade_subjects":
		query = query.
			Where("grade_subjects.grade_id IN (?)", database.DB.Model(&models.Grade{}).Select("id").Where("school_id = ?", schoolID)).
			Where("grade_subjects.subject_id IN (?)", database.DB.Model(&models.Subject{}).Select("id").Where("school_id = ?", schoolID))
		switch role {
		case "admin", "principal":
			return query
		default:
			return query.Where("1 = 0")
		}
	case "homework":
		switch role {
		case "parent":
			return query.Where(`
				(
				student_id IN (?)
				OR section_id IN (?)
				)
			`, linkedStudentSubquery(c), linkedSectionSubquery(c))
		case "teacher":
			staffID := currentStaffID(c)
			if staffID == "" {
				return query.Where("1 = 0")
			}
			return query.Where("(teacher_id = ? OR section_id IN (?))", staffID, teacherSectionSubquery(staffID, schoolID))
		}
	case "diary_entries":
		switch role {
		case "parent":
			return query.Where(`
				(
				student_id IN (?)
				OR section_id IN (?)
				)
			`, linkedStudentSubquery(c), linkedSectionSubquery(c))
		case "teacher":
			staffID := currentStaffID(c)
			if staffID == "" {
				return query.Where("1 = 0")
			}
			return query.Where("(teacher_id = ? OR section_id IN (?))", staffID, teacherSectionSubquery(staffID, schoolID))
		}
	case "message_conversations":
		switch role {
		case "parent":
			return query.Where("parent_id = ? AND (student_id = '' OR student_id IN (?))", currentUserID(c), linkedStudentSubquery(c))
		case "teacher":
			staffID := currentStaffID(c)
			if staffID == "" {
				return query.Where("1 = 0")
			}
			return query.Where("teacher_id = ?", staffID)
		}
	case "messages":
		query = query.Joins("JOIN message_conversations ON message_conversations.id = messages.conversation_id").
			Where("message_conversations.school_id = ?", schoolID)
		switch role {
		case "admin", "principal":
			return query
		case "parent":
			return query.Where("message_conversations.parent_id = ? AND (message_conversations.student_id = '' OR message_conversations.student_id IN (?))", currentUserID(c), linkedStudentSubquery(c))
		case "teacher":
			staffID := currentStaffID(c)
			if staffID == "" {
				return query.Where("1 = 0")
			}
			return query.Where("message_conversations.teacher_id = ?", staffID)
		default:
			return query.Where("1 = 0")
		}
	case "parent_teacher_meetings":
		query = query.Joins(`JOIN events ON events.event_id = parent_teacher_meetings.event_id`).
			Where("events.school_id = ?", schoolID)
		switch role {
		case "admin", "principal":
			return query
		case "parent":
			return query.Where("parent_teacher_meetings.student_id IN (?)", linkedStudentSubquery(c))
		case "teacher":
			staffID := currentStaffID(c)
			if staffID == "" {
				return query.Where("1 = 0")
			}
			return query.Where("parent_teacher_meetings.teacher_id = ?", staffID)
		default:
			return query.Where("1 = 0")
		}
	}
	return query
}

func (h *CRUDHandler[T]) validateRelationshipPolicy(c *gin.Context, row *T) error {
	role := currentRole(c)
	if role == "" {
		return nil
	}
	switch h.TableName {
	case "terms":
		if !academicYearBelongsToSchool(getStringField(row, "AcademicYearID"), currentSchoolID(c)) {
			return errors.New("academic year access denied")
		}
	case "homework", "diary_entries":
		return validateHomeworkDiaryPolicy(c, row)
	case "message_conversations":
		return validateConversationPolicy(c, row)
	case "messages":
		if !canAccessConversation(c, getStringField(row, "ConversationID")) {
			return errors.New("conversation access denied")
		}
	case "parent_teacher_meetings":
		return validatePTMPolicy(c, row)
	case "parent_student_links":
		parentID := getStringField(row, "ParentUserID")
		studentID := getStringField(row, "StudentID")
		if role == "parent" {
			return errors.New("parents cannot manage student links")
		}
		if !canAccessParentStudentLink(c, parentID, studentID) && !isSchoolOperator(c) {
			return errors.New("parent-student link access denied")
		}
	case "staff_subjects":
		return validateStaffSubjectPolicy(c, row)
	case "grade_subjects":
		return validateGradeSubjectPolicy(c, row)
	}
	return nil
}

func validateGradeSubjectPolicy[T any](c *gin.Context, row *T) error {
	if !isSchoolOperator(c) {
		return errors.New("grade subject access denied")
	}
	schoolID := currentSchoolID(c)
	if !gradeBelongsToSchool(getStringField(row, "GradeID"), schoolID) {
		return errors.New("grade access denied")
	}
	if !subjectBelongsToSchool(getStringField(row, "SubjectID"), schoolID) {
		return errors.New("subject access denied")
	}
	return nil
}

func validateStaffSubjectPolicy[T any](c *gin.Context, row *T) error {
	if !isSchoolOperator(c) {
		return errors.New("staff subject access denied")
	}
	schoolID := currentSchoolID(c)
	staffID := getStringField(row, "StaffID")
	subjectID := getStringField(row, "SubjectID")
	gradeID := getStringField(row, "GradeID")
	sectionID := getStringField(row, "SectionID")
	if !staffBelongsToSchool(staffID, schoolID) {
		return errors.New("staff access denied")
	}
	if !subjectBelongsToSchool(subjectID, schoolID) {
		return errors.New("subject access denied")
	}
	if !gradeBelongsToSchool(gradeID, schoolID) {
		return errors.New("grade access denied")
	}
	if sectionID != "" &&
		(!sectionBelongsToGrade(sectionID, gradeID) ||
			!sectionBelongsToSchool(sectionID, schoolID)) {
		return errors.New("section access denied")
	}
	return nil
}

func validateHomeworkDiaryPolicy[T any](c *gin.Context, row *T) error {
	switch currentRole(c) {
	case "admin", "principal":
		return nil
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" {
			return errors.New("teacher staff link missing")
		}
		teacherID := getStringField(row, "TeacherID")
		if teacherID == "" {
			setStringField(row, "TeacherID", staffID)
			teacherID = staffID
		}
		if teacherID != staffID {
			return errors.New("teacher ownership denied")
		}
		sectionID := getStringField(row, "SectionID")
		if sectionID != "" && !canAccessSection(c, sectionID) {
			return errors.New("section access denied")
		}
		studentID := getStringField(row, "StudentID")
		if studentID != "" && !canAccessStudent(c, studentID) {
			return errors.New("student access denied")
		}
		return nil
	case "parent":
		return errors.New("parents cannot write classroom records")
	default:
		return errors.New("access denied")
	}
}

func validateConversationPolicy[T any](c *gin.Context, row *T) error {
	switch currentRole(c) {
	case "admin", "principal":
		return nil
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" || getStringField(row, "TeacherID") != staffID {
			return errors.New("teacher conversation access denied")
		}
	case "parent":
		if getStringField(row, "ParentID") != currentUserID(c) {
			return errors.New("parent conversation access denied")
		}
	default:
		return errors.New("access denied")
	}
	studentID := getStringField(row, "StudentID")
	if studentID != "" && !canAccessStudent(c, studentID) {
		return errors.New("student access denied")
	}
	return nil
}

func validatePTMPolicy[T any](c *gin.Context, row *T) error {
	switch currentRole(c) {
	case "admin", "principal":
		return nil
	case "teacher":
		if getStringField(row, "TeacherID") != currentStaffID(c) {
			return errors.New("teacher PTM access denied")
		}
	case "parent":
		if !canAccessStudent(c, getStringField(row, "StudentID")) {
			return errors.New("student access denied")
		}
	default:
		return errors.New("access denied")
	}
	return nil
}

func (h *CRUDHandler[T]) bindAndValidate(c *gin.Context, row *T, requireAll bool) error {
	raw, err := c.GetRawData()
	if err != nil {
		return errors.New("Invalid request body")
	}
	if len(raw) == 0 {
		return errors.New("Request body is required")
	}
	var payload map[string]interface{}
	if err := json.Unmarshal(raw, &payload); err != nil {
		return errors.New("Invalid JSON body")
	}
	if requireAll {
		for _, field := range h.Required {
			if isEmptyJSONValue(payload[field]) {
				return fmt.Errorf("%s is required", field)
			}
		}
	}
	if err := json.Unmarshal(raw, row); err != nil {
		return errors.New("Invalid request fields")
	}
	return nil
}

func (h *CRUDHandler[T]) applySchoolScope(c *gin.Context, row *T) {
	if h.SchoolScoped {
		setStringField(row, "SchoolID", scopedSchoolID(c))
	}
}

func (h *CRUDHandler[T]) prepareCreate(c *gin.Context, row *T) {
	if h.TableName != "messages" {
		return
	}
	if message, ok := any(row).(*models.Message); ok {
		normalizeMessageForCreate(c, message)
	}
}

func (h *CRUDHandler[T]) afterCreate(c *gin.Context, row *T) {
	switch h.TableName {
	case "messages":
		if message, ok := any(row).(*models.Message); ok {
			notifyMessageCreated(*message)
		}
	case "homework":
		if homework, ok := any(row).(*models.Homework); ok {
			notifyHomeworkCreated(*homework)
		}
	}
}

func isEmptyJSONValue(value interface{}) bool {
	if value == nil {
		return true
	}
	switch v := value.(type) {
	case string:
		return strings.TrimSpace(v) == ""
	default:
		return false
	}
}

func setStringField(row interface{}, name, value string) {
	v := reflect.ValueOf(row)
	if v.Kind() != reflect.Pointer || v.IsNil() {
		return
	}
	elem := v.Elem()
	if elem.Kind() != reflect.Struct {
		return
	}
	field := elem.FieldByName(name)
	if field.IsValid() && field.CanSet() && field.Kind() == reflect.String {
		field.SetString(value)
	}
}

func modelID(row interface{}) string {
	v := reflect.ValueOf(row)
	if v.Kind() == reflect.Pointer {
		v = v.Elem()
	}
	if v.Kind() != reflect.Struct {
		return ""
	}
	field := v.FieldByName("ID")
	if field.IsValid() && field.Kind() == reflect.String {
		return field.String()
	}
	return ""
}

func NewAuditLogHandler() *AuditLogHandler {
	return &AuditLogHandler{}
}

type AuditLogHandler struct{}

func (h *AuditLogHandler) List(c *gin.Context) {
	page, pageSize := parsePagination(c)
	offset := (page - 1) * pageSize
	var rows []models.AuditLog
	var total int64
	query := database.DB.Preload("User").Where(
		"user_id IN (?)",
		database.DB.Model(&models.User{}).Select("id").Where("school_id = ?", scopedSchoolID(c)),
	).Order("created_at DESC")
	if userID := c.Query("user_id"); userID != "" {
		query = query.Where("user_id = ?", userID)
	}
	if module := c.Query("module"); module != "" {
		query = query.Where("module = ?", module)
	}
	if err := query.Model(&models.AuditLog{}).Count(&total).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to count audit logs")
		return
	}
	if err := query.Offset(offset).Limit(pageSize).Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to list audit logs")
		return
	}
	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, rows))
}

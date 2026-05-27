package handlers

import (
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type TablesMDResource struct {
	Module       string
	Table        string
	PrimaryKey   string
	SchoolScoped bool
	Required     []string
	Columns      []string
	Aliases      map[string]string
}

type TablesMDCRUDHandler struct {
	resource  TablesMDResource
	columnSet map[string]bool
}

var TablesMDColumns = map[string][]string{
	"classes": {
		"class_id", "school_id", "academic_year_id", "class_name", "class_code",
		"section_id", "class_teacher_id", "room_id", "medium", "sort_order",
		"is_active", "created_at", "updated_at",
	},
	"attendance": {
		"attendance_id", "school_id", "academic_year_id", "attendance_type",
		"student_id", "staff_id", "class_id", "section_id", "attendance_date",
		"status", "check_in_time", "check_out_time", "remarks", "marked_by",
		"created_at", "updated_at",
	},
	"fees": {
		"fee_id", "school_id", "academic_year_id", "student_id", "class_id",
		"section_id", "fee_type_id", "invoice_no", "receipt_no", "due_date",
		"amount", "discount_amount", "fine_amount", "paid_amount", "balance_amount",
		"payment_mode", "payment_status", "transaction_id", "remarks", "created_at",
		"updated_at",
	},
	"homework": {
		"homework_id", "school_id", "academic_year_id", "class_id", "section_id",
		"subject_id", "staff_id", "student_id", "title", "description", "assigned_date",
		"submission_date", "attachment_url", "submission_mode", "status",
		"created_at", "updated_at",
	},
	"leaves": {
		"leave_id", "school_id", "user_type", "student_id", "staff_id",
		"leave_type_id", "from_date", "to_date", "total_days", "reason",
		"document_url", "approval_status", "approved_by", "approved_at", "remarks",
		"created_at", "updated_at",
	},
	"notifications": {
		"notification_id", "school_id", "title", "message", "notification_type",
		"target_role", "target_user_id", "priority", "delivery_mode", "is_read",
		"read_at", "sent_by", "sent_at", "expiry_date", "created_at", "updated_at",
	},
	"holidays": {
		"holiday_id", "school_id", "holiday_name", "holiday_type", "start_date",
		"end_date", "description", "is_optional", "applicable_for", "created_by",
		"status", "created_at", "updated_at",
	},
	"events": {
		"event_id", "school_id", "event_name", "event_type", "description",
		"start_date", "end_date", "start_time", "end_time", "venue",
		"organizer_id", "audience_type", "attachment_url", "status", "is_holiday",
		"academic_year_id", "created_at", "updated_at",
	},
	"approval_requests": {
		"approval_id", "school_id", "academic_year_id", "request_type", "module_name",
		"reference_table", "reference_id", "requested_by", "requested_role",
		"assigned_to", "approval_level", "priority", "title", "description",
		"old_value_json", "new_value_json", "attachment_url", "remarks_by_requester",
		"approval_status", "approved_by", "approved_at", "rejection_reason",
		"action_taken", "notification_sent", "deadline_date", "created_at",
		"updated_at",
	},
	"communications": {
		"message_id", "school_id", "sender_id", "sender_role", "receiver_id",
		"receiver_role", "student_id", "message_type", "message_content",
		"attachment_url", "priority", "is_read", "read_at", "reply_to_message_id",
		"is_deleted_by_sender", "is_deleted_by_receiver", "sent_at", "created_at",
		"updated_at",
	},
	"principal_reports": {
		"report_id", "school_id", "academic_year_id", "report_name", "report_type",
		"module_name", "generated_by", "generated_role", "class_id", "section_id",
		"student_id", "staff_id", "date_from", "date_to", "report_parameters_json",
		"report_summary_json", "chart_data_json", "total_records", "report_file_url",
		"report_status", "is_scheduled", "schedule_frequency", "last_generated_at",
		"remarks", "created_at", "updated_at",
	},
}

func TablesMDResourceFor(table string) (TablesMDResource, bool) {
	resources := map[string]TablesMDResource{
		"classes": {
			Module: "classes", Table: "classes", PrimaryKey: "class_id", SchoolScoped: true,
			Required: []string{"class_name"}, Columns: TablesMDColumns["classes"],
		},
		"attendance": {
			Module: "attendance", Table: "attendance", PrimaryKey: "attendance_id", SchoolScoped: true,
			Required: []string{"attendance_date", "status"}, Columns: TablesMDColumns["attendance"],
		},
		"fees": {
			Module: "fees", Table: "fees", PrimaryKey: "fee_id", SchoolScoped: true,
			Required: []string{"student_id", "amount"}, Columns: TablesMDColumns["fees"],
		},
		"homework": {
			Module: "homework", Table: "homework", PrimaryKey: "homework_id", SchoolScoped: true,
			Required: []string{"title"}, Columns: TablesMDColumns["homework"],
			Aliases: map[string]string{"teacher_id": "staff_id", "due_date": "submission_date", "subject": "subject_id", "class": "class_id"},
		},
		"leaves": {
			Module: "leaves", Table: "leaves", PrimaryKey: "leave_id", SchoolScoped: true,
			Required: []string{"from_date", "to_date", "reason"}, Columns: TablesMDColumns["leaves"],
		},
		"notifications": {
			Module: "notifications", Table: "notifications", PrimaryKey: "notification_id", SchoolScoped: true,
			Required: []string{"title", "message"}, Columns: TablesMDColumns["notifications"],
			Aliases: map[string]string{"body": "message", "type": "notification_type", "user_id": "target_user_id"},
		},
		"holidays": {
			Module: "holidays", Table: "holidays", PrimaryKey: "holiday_id", SchoolScoped: true,
			Required: []string{"holiday_name", "start_date", "end_date"}, Columns: TablesMDColumns["holidays"],
		},
		"events": {
			Module: "events", Table: "events", PrimaryKey: "event_id", SchoolScoped: true,
			Required: []string{"event_name"}, Columns: TablesMDColumns["events"],
			Aliases: map[string]string{"event_title": "event_name", "location": "venue", "created_by": "organizer_id"},
		},
		"approval_requests": {
			Module: "approval_requests", Table: "approval_requests", PrimaryKey: "approval_id", SchoolScoped: true,
			Required: []string{"request_type", "module_name", "title"}, Columns: TablesMDColumns["approval_requests"],
		},
		"communications": {
			Module: "communications", Table: "communications", PrimaryKey: "message_id", SchoolScoped: true,
			Required: []string{"sender_id", "receiver_id", "message_content"}, Columns: TablesMDColumns["communications"],
		},
		"principal_reports": {
			Module: "principal_reports", Table: "principal_reports", PrimaryKey: "report_id", SchoolScoped: true,
			Required: []string{"report_name", "report_type"}, Columns: TablesMDColumns["principal_reports"],
		},
	}
	resource, ok := resources[table]
	return resource, ok
}

func NewTablesMDCRUDHandler(resource TablesMDResource) *TablesMDCRUDHandler {
	columnSet := make(map[string]bool, len(resource.Columns))
	for _, column := range resource.Columns {
		columnSet[column] = true
	}
	if database.DB != nil {
		if database.DB.Migrator().HasColumn(resource.Table, "id") {
			columnSet["id"] = true
		}
	}
	return &TablesMDCRUDHandler{resource: resource, columnSet: columnSet}
}

func (h *TablesMDCRUDHandler) List(c *gin.Context) {
	page, pageSize := parsePagination(c)
	offset := (page - 1) * pageSize

	query := h.applyListFilters(c, h.scopedQuery(c))
	var total int64
	if err := query.Count(&total).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to count "+h.resource.Module)
		return
	}

	var rows []map[string]interface{}
	if err := query.Order(quoteHandlerIdentifier(h.resource.PrimaryKey)).
		Offset(offset).
		Limit(pageSize).
		Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to list "+h.resource.Module)
		return
	}
	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, rows))
}

func (h *TablesMDCRUDHandler) Get(c *gin.Context) {
	row, ok := h.loadByID(c, c.Param("id"))
	if !ok {
		return
	}
	success(c, http.StatusOK, row, "")
}

func (h *TablesMDCRUDHandler) Create(c *gin.Context) {
	payload, err := h.bindPayload(c)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	if id := strings.TrimSpace(fmt.Sprint(payload[h.resource.PrimaryKey])); id == "" || id == "<nil>" {
		if legacyID := strings.TrimSpace(fmt.Sprint(payload["id"])); legacyID != "" && legacyID != "<nil>" {
			payload[h.resource.PrimaryKey] = legacyID
		} else {
			payload[h.resource.PrimaryKey] = uuid.New().String()
		}
	}
	h.mirrorLegacyID(payload)
	h.applyWriteDefaults(c, payload, true)
	if err := h.validateRequired(payload); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	if err := database.DB.Table(h.resource.Table).Create(payload).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create "+h.resource.Module)
		return
	}
	id := fmt.Sprint(payload[h.resource.PrimaryKey])
	auditAction(c, h.resource.Module, "create", h.resource.Table, &id)
	row, ok := h.loadByID(c, id)
	if !ok {
		return
	}
	if h.resource.Table == "homework" {
		notifyHomeworkCreatedFromRecord(homeworkRecordFromMap(row))
	}
	success(c, http.StatusCreated, row, "")
}

func (h *TablesMDCRUDHandler) Update(c *gin.Context) {
	id := c.Param("id")
	if _, ok := h.loadByID(c, id); !ok {
		return
	}
	payload, err := h.bindPayload(c)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	delete(payload, h.resource.PrimaryKey)
	delete(payload, "id")
	delete(payload, "created_at")
	h.applyWriteDefaults(c, payload, false)
	if len(payload) == 0 {
		fail(c, http.StatusBadRequest, "No valid fields supplied")
		return
	}

	query := h.scopedQuery(c).Where(quoteHandlerIdentifier(h.resource.PrimaryKey)+" = ?", id)
	if err := query.Updates(payload).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update "+h.resource.Module)
		return
	}
	auditAction(c, h.resource.Module, "update", h.resource.Table, &id)
	row, ok := h.loadByID(c, id)
	if !ok {
		return
	}
	success(c, http.StatusOK, row, "")
}

func (h *TablesMDCRUDHandler) Delete(c *gin.Context) {
	id := c.Param("id")
	query := h.scopedQuery(c).Where(quoteHandlerIdentifier(h.resource.PrimaryKey)+" = ?", id)
	result := query.Delete(map[string]interface{}{})
	if result.Error != nil {
		fail(c, http.StatusInternalServerError, "Failed to delete "+h.resource.Module)
		return
	}
	if result.RowsAffected == 0 {
		fail(c, http.StatusNotFound, h.resource.Module+" not found")
		return
	}
	auditAction(c, h.resource.Module, "delete", h.resource.Table, &id)
	success(c, http.StatusOK, nil, h.resource.Module+" deleted successfully")
}

func (h *TablesMDCRUDHandler) bindPayload(c *gin.Context) (map[string]interface{}, error) {
	var raw map[string]interface{}
	if err := c.ShouldBindJSON(&raw); err != nil {
		return nil, err
	}
	payload := make(map[string]interface{})
	for key, value := range raw {
		key = strings.TrimSpace(key)
		if h.columnSet[key] {
			payload[key] = value
			if target := h.resource.Aliases[key]; target != "" && h.columnSet[target] {
				payload[target] = value
			}
			continue
		}
		if database.DB != nil && database.DB.Migrator().HasColumn(h.resource.Table, key) {
			payload[key] = value
			if target := h.resource.Aliases[key]; target != "" && h.columnSet[target] {
				payload[target] = value
			}
			continue
		}
		if target := h.resource.Aliases[key]; target != "" && h.columnSet[target] {
			payload[target] = value
		}
	}
	if len(payload) == 0 {
		return nil, errors.New("No valid fields supplied")
	}
	return payload, nil
}

func (h *TablesMDCRUDHandler) validateRequired(payload map[string]interface{}) error {
	for _, field := range h.resource.Required {
		value, ok := payload[field]
		if !ok || value == nil || strings.TrimSpace(fmt.Sprint(value)) == "" {
			return fmt.Errorf("%s is required", field)
		}
	}
	return nil
}

func (h *TablesMDCRUDHandler) applyWriteDefaults(c *gin.Context, payload map[string]interface{}, create bool) {
	now := time.Now().UTC()
	if h.resource.SchoolScoped && h.columnSet["school_id"] {
		payload["school_id"] = scopedSchoolID(c)
	}
	if create && h.columnSet["created_at"] {
		if _, ok := payload["created_at"]; !ok {
			payload["created_at"] = now
		}
	}
	if h.columnSet["updated_at"] {
		payload["updated_at"] = now
	}
	if create && h.resource.Table == "communications" && h.columnSet["sent_at"] {
		if _, ok := payload["sent_at"]; !ok {
			payload["sent_at"] = now
		}
	}
}

func (h *TablesMDCRUDHandler) mirrorLegacyID(payload map[string]interface{}) {
	if !h.columnSet["id"] {
		return
	}
	if strings.TrimSpace(fmt.Sprint(payload["id"])) == "" || fmt.Sprint(payload["id"]) == "<nil>" {
		payload["id"] = payload[h.resource.PrimaryKey]
	}
}

func (h *TablesMDCRUDHandler) loadByID(c *gin.Context, id string) (map[string]interface{}, bool) {
	var row map[string]interface{}
	err := h.scopedQuery(c).
		Where(quoteHandlerIdentifier(h.resource.PrimaryKey)+" = ?", id).
		Take(&row).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			fail(c, http.StatusNotFound, h.resource.Module+" not found")
			return nil, false
		}
		fail(c, http.StatusInternalServerError, "Failed to load "+h.resource.Module)
		return nil, false
	}
	if _, ok := row["id"]; !ok {
		row["id"] = row[h.resource.PrimaryKey]
	}
	return row, true
}

func (h *TablesMDCRUDHandler) scopedQuery(c *gin.Context) *gorm.DB {
	query := database.DB.Table(h.resource.Table)
	if h.resource.SchoolScoped && h.columnSet["school_id"] {
		query = query.Where(quoteHandlerIdentifier("school_id")+" = ?", scopedSchoolID(c))
	}
	return h.applyRoleScope(c, query)
}

func (h *TablesMDCRUDHandler) applyListFilters(c *gin.Context, query *gorm.DB) *gorm.DB {
	if h.resource.Table == "homework" {
		query = h.applyHomeworkListFilters(c, query)
	}
	keys := make([]string, 0, len(c.Request.URL.Query()))
	for key := range c.Request.URL.Query() {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		if h.resource.Table == "homework" && key == "student_id" {
			continue
		}
		if !h.columnSet[key] {
			continue
		}
		value := strings.TrimSpace(c.Query(key))
		if value != "" {
			query = query.Where(quoteHandlerIdentifier(key)+" = ?", value)
		}
	}
	return query
}

func (h *TablesMDCRUDHandler) applyHomeworkListFilters(c *gin.Context, query *gorm.DB) *gorm.DB {
	studentID := strings.TrimSpace(c.Query("student_id"))
	if studentID == "" {
		return query
	}
	if !canAccessStudent(c, studentID) {
		return query.Where("1 = 0")
	}
	schoolID := scopedSchoolID(c)
	currentSection := database.DB.Model(&models.Student{}).
		Select("students.current_section_id").
		Where("students.id = ? AND students.school_id = ?", studentID, schoolID).
		Where("students.current_section_id IS NOT NULL AND students.current_section_id != ''")
	enrollmentSections := database.DB.Model(&models.Enrollment{}).
		Select("enrollments.section_id").
		Joins("JOIN students ON students.id = enrollments.student_id").
		Where("students.school_id = ? AND enrollments.student_id = ?", schoolID, studentID)
	return query.Where(`
		(
			"student_id" = ?
			OR (
				("student_id" IS NULL OR "student_id" = '')
				AND (
					"section_id" IN (?)
					OR "section_id" IN (?)
				)
			)
		)
	`, studentID, currentSection, enrollmentSections)
}

func (h *TablesMDCRUDHandler) applyRoleScope(c *gin.Context, query *gorm.DB) *gorm.DB {
	switch currentRole(c) {
	case "", "admin", "principal":
		return query
	case "parent":
		return h.applyParentScope(c, query)
	case "teacher":
		return h.applyTeacherScope(c, query)
	default:
		return query.Where("1 = 0")
	}
}

func (h *TablesMDCRUDHandler) applyParentScope(c *gin.Context, query *gorm.DB) *gorm.DB {
	switch h.resource.Table {
	case "communications":
		return query.Where(
			"(sender_id = ? OR receiver_id = ? OR student_id IN (?))",
			currentUserID(c),
			currentUserID(c),
			linkedStudentSubquery(c),
		)
	case "notifications":
		return query.Where(
			"(target_user_id = ? OR LOWER(COALESCE(target_role, '')) IN ('parent', 'parents', 'all', 'everyone'))",
			currentUserID(c),
		)
	case "homework":
		return query.Where(
			`section_id IN (
				SELECT DISTINCT COALESCE(students.current_section_id, enrollments.section_id)
				FROM students
				LEFT JOIN enrollments ON enrollments.student_id = students.id AND enrollments.status = 'enrolled'
				WHERE students.id IN (?)
			)`,
			linkedStudentSubquery(c),
		)
	}
	if h.columnSet["student_id"] {
		return query.Where("student_id IN (?)", linkedStudentSubquery(c))
	}
	return query
}

func (h *TablesMDCRUDHandler) applyTeacherScope(c *gin.Context, query *gorm.DB) *gorm.DB {
	staffID := currentStaffID(c)
	switch h.resource.Table {
	case "communications":
		return query.Where("(sender_id = ? OR receiver_id = ?)", currentUserID(c), currentUserID(c))
	case "notifications":
		return query.Where(
			"(target_user_id = ? OR LOWER(COALESCE(target_role, '')) IN ('teacher', 'teachers', 'staff', 'all', 'everyone'))",
			currentUserID(c),
		)
	}
	if staffID != "" {
		switch {
		case h.columnSet["staff_id"]:
			return query.Where("staff_id = ?", staffID)
		case h.columnSet["class_teacher_id"]:
			return query.Where("class_teacher_id = ?", staffID)
		case h.columnSet["invigilator_id"]:
			return query.Where("invigilator_id = ?", staffID)
		}
	}
	if h.columnSet["marked_by"] {
		return query.Where("marked_by = ?", currentUserID(c))
	}
	return query
}

func quoteHandlerIdentifier(identifier string) string {
	return `"` + strings.ReplaceAll(identifier, `"`, `""`) + `"`
}

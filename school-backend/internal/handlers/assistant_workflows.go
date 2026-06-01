package handlers

import (
	"bytes"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type assistantWorkflowDefinition struct {
	Type         string                  `json:"type"`
	Title        string                  `json:"title"`
	Description  string                  `json:"description"`
	Category     string                  `json:"category"`
	TargetRoute  string                  `json:"target_route"`
	Execution    string                  `json:"execution"`
	Dependencies []string                `json:"dependencies"`
	Steps        []assistantWorkflowStep `json:"steps"`
}

type assistantWorkflowStep struct {
	ID          string   `json:"id"`
	Title       string   `json:"title"`
	Prompt      string   `json:"prompt"`
	Fields      []string `json:"fields"`
	Suggestions []string `json:"suggestions"`
}

type workflowIssue struct {
	Severity string `json:"severity"`
	StepID   string `json:"step_id"`
	Field    string `json:"field"`
	Message  string `json:"message"`
}

type workflowValidationResult struct {
	Valid       bool            `json:"valid"`
	Issues      []workflowIssue `json:"issues"`
	Suggestions []string        `json:"suggestions"`
}

// AssistantWorkflowHandler provides a deterministic guided workflow layer.
type AssistantWorkflowHandler struct {
	store        *services.WorkflowSessionStore
	staffHandler *StaffHandler
}

// NewAssistantWorkflowHandler creates the additive assistant workflow handler.
func NewAssistantWorkflowHandler() *AssistantWorkflowHandler {
	return &AssistantWorkflowHandler{
		store:        services.NewWorkflowSessionStore(database.DB),
		staffHandler: NewStaffHandler(),
	}
}

func (h *AssistantWorkflowHandler) Catalog(c *gin.Context) {
	defs := assistantWorkflowDefinitions()
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"message":      "Good Morning, What would you like to do today?",
			"action_cards": assistantActionCards(defs, currentRole(c)),
			"workflows":    defs,
			"readiness":    assistantCatalogReadiness(scopedSchoolID(c)),
			"guardrails": []string{
				"Guided steps only",
				"Draft autosave before execution",
				"Validation and review required",
				"Existing ERP screens remain available",
			},
		},
	})
}

func (h *AssistantWorkflowHandler) DetectIntent(c *gin.Context) {
	var req struct {
		Command string `json:"command"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	workflowType, initialData, suggestions := detectAssistantIntent(req.Command)
	success(c, http.StatusOK, gin.H{
		"workflow_type": workflowType,
		"initial_data":  initialData,
		"suggestions":   suggestions,
	}, "")
}

func (h *AssistantWorkflowHandler) ListSessions(c *gin.Context) {
	statuses := compactWorkflowStrings(strings.Split(c.Query("status"), ","))
	if len(statuses) == 0 && c.Query("all") != "true" {
		statuses = []string{"draft", "validated", "in_review", "executing"}
	}
	rows, err := h.store.List(c.Request.Context(), scopedSchoolID(c), currentUserID(c), statuses)
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load assistant sessions")
		return
	}
	payload := make([]gin.H, 0, len(rows))
	for _, row := range rows {
		payload = append(payload, h.sessionResponse(row))
	}
	success(c, http.StatusOK, payload, "")
}

func (h *AssistantWorkflowHandler) CreateSession(c *gin.Context) {
	var req struct {
		WorkflowType string                 `json:"workflow_type"`
		Title        string                 `json:"title"`
		Command      string                 `json:"command"`
		InitialData  map[string]interface{} `json:"initial_data"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	workflowType := strings.TrimSpace(req.WorkflowType)
	initialData := copyWorkflowMap(req.InitialData)
	if workflowType == "" && strings.TrimSpace(req.Command) != "" {
		detected, detectedData, _ := detectAssistantIntent(req.Command)
		workflowType = detected
		mergeWorkflowMap(initialData, detectedData)
	}
	def, ok := assistantDefinitionByType(workflowType)
	if !ok {
		fail(c, http.StatusBadRequest, "Unknown assistant workflow")
		return
	}
	pending := assistantStepIDs(def)
	title := strings.TrimSpace(req.Title)
	if title == "" {
		title = def.Title
	}
	row, err := h.store.Create(c.Request.Context(), services.WorkflowSessionInput{
		SchoolID:       scopedSchoolID(c),
		UserID:         currentUserID(c),
		UserRole:       currentRole(c),
		WorkflowType:   def.Type,
		Title:          title,
		Status:         "draft",
		CurrentStepID:  firstStepID(def),
		CompletedSteps: []string{},
		PendingSteps:   pending,
		DraftData:      initialData,
		SourceCommand:  req.Command,
	})
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create assistant workflow")
		return
	}
	_ = h.log(c, row.ID, "created", "", "Assistant workflow draft created", initialData)
	success(c, http.StatusCreated, h.sessionResponse(row), "Assistant workflow created")
}

func (h *AssistantWorkflowHandler) GetSession(c *gin.Context) {
	row, err := h.store.Get(c.Request.Context(), scopedSchoolID(c), c.Param("id"))
	if err != nil {
		fail(c, http.StatusNotFound, "Assistant workflow not found")
		return
	}
	success(c, http.StatusOK, h.sessionResponse(row), "")
}

func (h *AssistantWorkflowHandler) SaveStep(c *gin.Context) {
	row, err := h.store.Get(c.Request.Context(), scopedSchoolID(c), c.Param("id"))
	if err != nil {
		fail(c, http.StatusNotFound, "Assistant workflow not found")
		return
	}
	def, ok := assistantDefinitionByType(row.WorkflowType)
	if !ok {
		fail(c, http.StatusBadRequest, "Unknown assistant workflow")
		return
	}
	stepID := strings.TrimSpace(c.Param("step_id"))
	if !assistantStepExists(def, stepID) {
		fail(c, http.StatusBadRequest, "Unknown assistant workflow step")
		return
	}
	var req struct {
		StepData      map[string]interface{} `json:"step_data"`
		DraftData     map[string]interface{} `json:"draft_data"`
		Completed     bool                   `json:"completed"`
		CurrentStepID string                 `json:"current_step_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	draft := services.DecodeWorkflowMap(row.DraftData)
	if req.DraftData != nil {
		mergeWorkflowMap(draft, req.DraftData)
	}
	if req.StepData != nil {
		draft[stepID] = req.StepData
	}
	completed := services.DecodeWorkflowStringSlice(row.CompletedSteps)
	if req.Completed {
		completed = addWorkflowString(completed, stepID)
	}
	pending := pendingWorkflowSteps(def, completed)
	current := firstNonEmpty(req.CurrentStepID, stepID)
	updated, err := h.store.Patch(c.Request.Context(), row.ID, services.WorkflowSessionPatch{
		Status:         "draft",
		CurrentStepID:  current,
		CompletedSteps: completed,
		PendingSteps:   pending,
		DraftData:      draft,
	})
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save assistant draft")
		return
	}
	_ = h.log(c, row.ID, "step_saved", stepID, "Assistant workflow step saved", req.StepData)
	success(c, http.StatusOK, h.sessionResponse(updated), "Draft saved")
}

func (h *AssistantWorkflowHandler) ValidateSession(c *gin.Context) {
	row, err := h.store.Get(c.Request.Context(), scopedSchoolID(c), c.Param("id"))
	if err != nil {
		fail(c, http.StatusNotFound, "Assistant workflow not found")
		return
	}
	def, ok := assistantDefinitionByType(row.WorkflowType)
	if !ok {
		fail(c, http.StatusBadRequest, "Unknown assistant workflow")
		return
	}
	draft := services.DecodeWorkflowMap(row.DraftData)
	result := h.validateWorkflow(c, def, draft)
	review := h.reviewSummary(def, draft, result)
	status := "in_review"
	if result.Valid {
		status = "validated"
	}
	updated, err := h.store.Patch(c.Request.Context(), row.ID, services.WorkflowSessionPatch{
		Status:            status,
		ValidationSummary: workflowStructMap(result),
		ReviewSummary:     review,
	})
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save validation result")
		return
	}
	_ = h.log(c, row.ID, "validated", row.CurrentStepID, "Assistant workflow validated", workflowStructMap(result))
	success(c, http.StatusOK, gin.H{
		"session":    h.sessionResponse(updated),
		"validation": result,
		"review":     review,
	}, "")
}

func (h *AssistantWorkflowHandler) ExecuteSession(c *gin.Context) {
	row, err := h.store.Get(c.Request.Context(), scopedSchoolID(c), c.Param("id"))
	if err != nil {
		fail(c, http.StatusNotFound, "Assistant workflow not found")
		return
	}
	var req struct {
		Confirm bool `json:"confirm"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	switch strings.ToLower(strings.TrimSpace(row.Status)) {
	case "executed":
		fail(c, http.StatusConflict, "Assistant workflow is already executed")
		return
	case "executing":
		fail(c, http.StatusConflict, "Assistant workflow is already executing")
		return
	case "canceled":
		fail(c, http.StatusConflict, "Canceled assistant workflow cannot be executed")
		return
	}
	if !req.Confirm {
		fail(c, http.StatusBadRequest, "Explicit confirmation is required before execution")
		return
	}
	def, ok := assistantDefinitionByType(row.WorkflowType)
	if !ok {
		fail(c, http.StatusBadRequest, "Unknown assistant workflow")
		return
	}
	draft := services.DecodeWorkflowMap(row.DraftData)
	validation := h.validateWorkflow(c, def, draft)
	if !validation.Valid {
		fail(c, http.StatusBadRequest, "Resolve assistant validation errors before execution")
		return
	}
	now := time.Now().UTC()
	_, _ = h.store.Patch(c.Request.Context(), row.ID, services.WorkflowSessionPatch{
		Status:        "executing",
		RollbackState: "transaction_open",
		ConfirmedAt:   &now,
	})

	result, execErr := h.executeWorkflow(c, def, draft)
	if execErr != nil {
		_, _ = h.store.Patch(c.Request.Context(), row.ID, services.WorkflowSessionPatch{
			Status:        "failed",
			RollbackState: "rolled_back",
			LastError:     execErr.Error(),
		})
		_ = h.log(c, row.ID, "rollback", "", "Assistant workflow rolled back after execution failure", gin.H{"error": execErr.Error()})
		fail(c, workflowExecutionStatus(execErr), execErr.Error())
		return
	}
	executedAt := time.Now().UTC()
	review := h.reviewSummary(def, draft, validation)
	review["execution_result"] = result
	updated, err := h.store.Patch(c.Request.Context(), row.ID, services.WorkflowSessionPatch{
		Status:        "executed",
		RollbackState: "committed",
		ExecutedAt:    &executedAt,
		ReviewSummary: review,
	})
	if err != nil {
		fail(c, http.StatusInternalServerError, "Workflow executed but session status could not be updated")
		return
	}
	_ = h.log(c, row.ID, "executed", "", "Assistant workflow executed safely", result)
	auditAction(c, "assistant/workflows", "execute", "workflow_sessions", &row.ID)
	success(c, http.StatusCreated, gin.H{
		"session": h.sessionResponse(updated),
		"result":  result,
	}, "Assistant workflow executed")
}

func (h *AssistantWorkflowHandler) CancelSession(c *gin.Context) {
	row, err := h.store.Get(c.Request.Context(), scopedSchoolID(c), c.Param("id"))
	if err != nil {
		fail(c, http.StatusNotFound, "Assistant workflow not found")
		return
	}
	if strings.EqualFold(row.Status, "executed") {
		fail(c, http.StatusConflict, "Executed assistant workflow cannot be canceled")
		return
	}
	now := time.Now().UTC()
	updated, err := h.store.Patch(c.Request.Context(), row.ID, services.WorkflowSessionPatch{
		Status:        "canceled",
		RollbackState: "not_started",
		CanceledAt:    &now,
	})
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to cancel assistant workflow")
		return
	}
	_ = h.log(c, row.ID, "canceled", row.CurrentStepID, "Assistant workflow canceled", nil)
	success(c, http.StatusOK, h.sessionResponse(updated), "Assistant workflow canceled")
}

func (h *AssistantWorkflowHandler) ExportTemplate(c *gin.Context) {
	workflowType := strings.TrimSpace(c.Param("workflow_type"))
	def, ok := assistantDefinitionByType(workflowType)
	if !ok {
		fail(c, http.StatusBadRequest, "Unknown assistant workflow")
		return
	}
	headers := assistantTemplateHeaders(workflowType)
	success(c, http.StatusOK, gin.H{
		"workflow_type": def.Type,
		"title":         def.Title,
		"csv_headers":   headers,
		"csv_template":  strings.Join(headers, ",") + "\n",
		"txt_format":    assistantTextTemplate(workflowType),
	}, "")
}

func (h *AssistantWorkflowHandler) ImportPreview(c *gin.Context) {
	row, err := h.store.Get(c.Request.Context(), scopedSchoolID(c), c.Param("id"))
	if err != nil {
		fail(c, http.StatusNotFound, "Assistant workflow not found")
		return
	}
	var req struct {
		Format  string `json:"format"`
		Content string `json:"content"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	parsed, err := parseAssistantBulkContent(row.WorkflowType, req.Format, req.Content)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	draft := services.DecodeWorkflowMap(row.DraftData)
	mergeWorkflowMap(draft, parsed)
	updated, err := h.store.Patch(c.Request.Context(), row.ID, services.WorkflowSessionPatch{DraftData: draft})
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save imported assistant data")
		return
	}
	_ = h.log(c, row.ID, "bulk_import", "", "Assistant bulk input parsed into draft", parsed)
	success(c, http.StatusOK, gin.H{
		"session": h.sessionResponse(updated),
		"parsed":  parsed,
	}, "Bulk input parsed")
}

func (h *AssistantWorkflowHandler) validateWorkflow(c *gin.Context, def assistantWorkflowDefinition, data map[string]interface{}) workflowValidationResult {
	result := workflowValidationResult{Valid: true, Issues: []workflowIssue{}, Suggestions: []string{}}
	addIssue := func(severity, stepID, field, message string) {
		if severity == "error" {
			result.Valid = false
		}
		result.Issues = append(result.Issues, workflowIssue{Severity: severity, StepID: stepID, Field: field, Message: message})
	}
	require := func(stepID, field, message string) {
		if workflowString(data, stepID, field) == "" {
			addIssue("error", stepID, field, message)
		}
	}

	switch def.Type {
	case "create_class":
		if workflowString(data, "class_details", "academic_year_id") == "" && workflowString(data, "class_details", "academic_year_label") == "" {
			addIssue("error", "class_details", "academic_year_label", "Select an academic year or enter a new academic year label")
		}
		className := firstNonEmpty(workflowString(data, "class_details", "class_name"), workflowString(data, "class_details", "grade_name"))
		if className == "" && workflowString(data, "class_details", "grade_id") == "" {
			addIssue("error", "class_details", "class_name", "Class name or existing grade is required")
		}
		if workflowInt(data, "class_details", "capacity") <= 0 && !workflowHasSectionCapacity(data) {
			addIssue("error", "sections", "capacity", "Every section capacity must be greater than zero")
		}
		if ay := workflowString(data, "class_details", "academic_year_id"); ay != "" && !academicYearBelongsToSchool(ay, scopedSchoolID(c)) {
			addIssue("error", "class_details", "academic_year_id", "Academic year must belong to this school")
		}
		sections := workflowList(data, "sections")
		if len(sections) == 0 && workflowInt(data, "class_details", "section_count") <= 0 {
			addIssue("warning", "sections", "sections", "No section names were supplied; Section A will be generated")
		}
		if workflowList(data, "subjects") == nil || len(workflowList(data, "subjects")) == 0 {
			addIssue("warning", "subjects", "subjects", "Add subjects now to avoid a second setup pass")
		}
		if workflowString(data, "class_teacher", "class_teacher_id") == "" {
			addIssue("warning", "class_teacher", "class_teacher_id", "Class teacher is not assigned yet")
		} else if !staffBelongsToSchool(workflowString(data, "class_teacher", "class_teacher_id"), scopedSchoolID(c)) {
			addIssue("error", "class_teacher", "class_teacher_id", "Class teacher must be active staff in this school")
		}
		if len(workflowList(data, "fee_structure")) == 0 {
			addIssue("warning", "fee_structure", "fees", "Fee structure is incomplete")
		}
		h.validateDuplicateClassSections(c, data, addIssue)
		if workflowBool(data, "timetable", "auto_generate") && len(workflowList(data, "subject_teachers")) == 0 {
			addIssue("warning", "timetable", "subject_teachers", "Timetable generation works best after subject teachers are assigned")
		}
	case "student_onboarding":
		require("student_details", "first_name", "Student first name is required")
		require("student_details", "date_of_birth", "Student date of birth is required")
		require("student_details", "gender", "Student gender is required")
		if workflowString(data, "student_details", "current_section_id") == "" {
			addIssue("warning", "student_details", "current_section_id", "Assign a class section during admission")
		}
		if workflowString(data, "guardian_details", "full_name") == "" {
			addIssue("warning", "guardian_details", "full_name", "Parent or guardian details are missing")
		}
	case "teacher_onboarding":
		require("staff_details", "first_name", "Teacher first name is required")
		require("staff_details", "last_name", "Teacher last name is required")
		if workflowString(data, "staff_details", "staff_code") == "" {
			addIssue("warning", "staff_details", "staff_code", "Employee ID will be generated if omitted")
		}
		if len(workflowList(data, "subject_mapping")) == 0 {
			addIssue("warning", "subject_mapping", "subjects", "Map the teacher to subjects/classes")
		}
	case "fee_setup":
		if workflowString(data, "fee_details", "academic_year_id") == "" && workflowString(data, "fee_details", "academic_year_label") == "" {
			addIssue("error", "fee_details", "academic_year_label", "Academic year is required")
		}
		if workflowString(data, "fee_details", "grade_id") == "" && workflowString(data, "fee_details", "grade_name") == "" {
			addIssue("error", "fee_details", "grade_id", "Class or grade is required")
		}
		if len(workflowList(data, "fee_items")) == 0 {
			addIssue("error", "fee_items", "fees", "At least one fee item is required")
		}
	case "timetable_setup":
		require("timetable_details", "section_id", "Section is required")
		require("timetable_details", "academic_year_id", "Academic year is required")
		if workflowString(data, "timetable_details", "term_id") == "" {
			addIssue("warning", "timetable_details", "term_id", "First term in the academic year will be used")
		}
	}
	result.Suggestions = assistantRuleSuggestions(def.Type, result.Issues)
	return result
}

func (h *AssistantWorkflowHandler) validateDuplicateClassSections(c *gin.Context, data map[string]interface{}, addIssue func(string, string, string, string)) {
	schoolID := scopedSchoolID(c)
	academicYearID := workflowString(data, "class_details", "academic_year_id")
	gradeID := workflowString(data, "class_details", "grade_id")
	gradeName := firstNonEmpty(workflowString(data, "class_details", "grade_name"), workflowString(data, "class_details", "class_name"))
	if gradeID == "" && gradeName != "" {
		var grade models.Grade
		if err := database.DB.First(&grade, "school_id = ? AND LOWER(grade_name) = ?", schoolID, strings.ToLower(gradeName)).Error; err == nil {
			gradeID = grade.ID
		}
	}
	if gradeID == "" || academicYearID == "" {
		return
	}
	for _, section := range normalizedWorkflowSections(data) {
		name := strings.ToLower(workflowRawString(section["section_name"]))
		if name == "" {
			continue
		}
		var count int64
		_ = database.DB.Model(&models.Section{}).
			Where("grade_id = ? AND academic_year_id = ? AND LOWER(section_name) = ?", gradeID, academicYearID, name).
			Count(&count).Error
		if count > 0 {
			addIssue("error", "sections", "section_name", "Class section "+strings.ToUpper(name)+" already exists")
		}
	}
}

func (h *AssistantWorkflowHandler) executeWorkflow(c *gin.Context, def assistantWorkflowDefinition, data map[string]interface{}) (gin.H, error) {
	switch def.Type {
	case "create_class":
		return h.executeCreateClass(c, data)
	case "student_onboarding":
		return h.executeStudentOnboarding(c, data)
	case "teacher_onboarding":
		return h.executeTeacherOnboarding(c, data)
	case "fee_setup":
		return h.executeFeeSetup(c, data)
	case "timetable_setup":
		return h.executeTimetableSetup(c, data)
	default:
		return nil, errors.New("workflow execution is not configured")
	}
}

func (h *AssistantWorkflowHandler) executeCreateClass(c *gin.Context, data map[string]interface{}) (gin.H, error) {
	schoolID := scopedSchoolID(c)
	gradeID := workflowString(data, "class_details", "grade_id")
	gradeName := firstNonEmpty(workflowString(data, "class_details", "grade_name"), workflowString(data, "class_details", "class_name"))
	gradeNumber := workflowInt(data, "class_details", "grade_number")
	capacity := workflowInt(data, "class_details", "capacity")
	classTeacherID := workflowString(data, "class_teacher", "class_teacher_id")
	sectionsInput := normalizedWorkflowSections(data)
	if len(sectionsInput) == 0 {
		sectionsInput = []map[string]interface{}{{"section_name": "A", "capacity": capacity}}
	}
	var createdSections []models.Section
	var createdSubjects []models.Subject
	var createdFeeStructures []models.FeeStructure
	var timetableCreated int
	var warnings []string

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		academicYear, err := resolveAssistantAcademicYear(tx, schoolID, workflowNestedMap(data, "class_details"))
		if err != nil {
			return err
		}
		academicYearID := academicYear.ID
		grade, err := resolveAssistantGrade(tx, schoolID, gradeID, gradeName, gradeNumber)
		if err != nil {
			return err
		}
		feeStructures, err := applyAssistantFeeItems(tx, schoolID, grade.ID, academicYearID, workflowList(data, "fee_structure"))
		if err != nil {
			return err
		}
		createdFeeStructures = feeStructures
		subjects, err := applyAssistantSubjects(tx, schoolID, grade.ID, workflowList(data, "subjects"))
		if err != nil {
			return err
		}
		createdSubjects = subjects
		for _, input := range sectionsInput {
			name := workflowRawString(input["section_name"])
			if name == "" {
				return errors.New("section_name is required")
			}
			sectionCapacity := int(workflowInt64(input["capacity"]))
			if sectionCapacity <= 0 {
				sectionCapacity = capacity
			}
			if sectionCapacity <= 0 {
				return errors.New("capacity must be greater than zero")
			}
			var existing models.Section
			err := tx.Where("grade_id = ? AND academic_year_id = ? AND LOWER(section_name) = ?", grade.ID, academicYearID, strings.ToLower(name)).First(&existing).Error
			if err == nil {
				return fmt.Errorf("class section %s already exists", name)
			}
			if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
				return err
			}
			var classTeacher *string
			if classTeacherID != "" {
				if err := tx.First(&models.Staff{}, "id = ? AND school_id = ? AND status = ?", classTeacherID, schoolID, "active").Error; err != nil {
					return errors.New("class teacher must be active staff in this school")
				}
				classTeacher = &classTeacherID
			}
			var roomID *string
			if roomValue := workflowRawString(input["room_id"]); roomValue != "" {
				if err := tx.First(&models.Room{}, "id = ? AND school_id = ?", roomValue, schoolID).Error; err != nil {
					return errors.New("room must belong to this school")
				}
				roomID = &roomValue
			}
			section := models.Section{
				GradeID:        grade.ID,
				AcademicYearID: academicYearID,
				SectionName:    name,
				ClassTeacherID: classTeacher,
				RoomID:         roomID,
				Capacity:       sectionCapacity,
			}
			if err := tx.Create(&section).Error; err != nil {
				return err
			}
			if err := applyAssistantSubjectTeachers(tx, schoolID, grade.ID, section.ID, workflowList(data, "subject_teachers"), createdSubjects); err != nil {
				return err
			}
			createdSections = append(createdSections, section)
		}
		if workflowBool(data, "timetable", "auto_generate") {
			sectionIDs := make([]string, 0, len(createdSections))
			for _, section := range createdSections {
				sectionIDs = append(sectionIDs, section.ID)
			}
			created, logs, err := generateAssistantTimetable(tx, schoolID, sectionIDs, data)
			if err != nil {
				return err
			}
			timetableCreated = created
			warnings = append(warnings, logs...)
		}
		if workflowBool(data, "notifications", "notify_staff") {
			title := "Class setup completed"
			content := fmt.Sprintf("%s setup is ready for %d section(s)", grade.GradeName, len(createdSections))
			if err := tx.Create(&models.Announcement{
				SchoolID:       schoolID,
				Title:          title,
				Content:        content,
				TargetAudience: "staff",
				CreatedBy:      currentUserID(c),
				PublishedAt:    time.Now().UTC(),
			}).Error; err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	sectionIDs := make([]string, 0, len(createdSections))
	for _, section := range createdSections {
		sectionIDs = append(sectionIDs, section.ID)
	}
	return gin.H{
		"created_entities": gin.H{
			"sections":         sectionIDs,
			"subjects":         len(createdSubjects),
			"fee_structures":   len(createdFeeStructures),
			"timetable_slots":  timetableCreated,
			"teacher_mappings": len(workflowList(data, "subject_teachers")),
		},
		"warnings": warnings,
	}, nil
}

func (h *AssistantWorkflowHandler) executeStudentOnboarding(c *gin.Context, data map[string]interface{}) (gin.H, error) {
	schoolID := scopedSchoolID(c)
	details := workflowNestedMap(data, "student_details")
	var createdStudent models.Student
	var guardianID string
	var invoiceID string
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		student, _, err := createStudentForSchool(tx, schoolID, models.CreateStudentRequest{
			FirstName:        workflowRawString(details["first_name"]),
			LastName:         workflowRawString(details["last_name"]),
			DateOfBirth:      workflowRawString(details["date_of_birth"]),
			Gender:           workflowRawString(details["gender"]),
			AdmissionNumber:  workflowRawString(details["admission_number"]),
			StudentCode:      workflowRawString(details["student_code"]),
			CurrentSectionID: workflowRawString(details["current_section_id"]),
			AdmissionDate:    firstNonEmpty(workflowRawString(details["admission_date"]), time.Now().UTC().Format("2006-01-02")),
			Status:           "active",
		})
		if err != nil {
			return err
		}
		createdStudent = student
		guardian := workflowNestedMap(data, "guardian_details")
		if workflowRawString(guardian["full_name"]) != "" {
			row := models.Guardian{
				SchoolID:     schoolID,
				StudentID:    student.ID,
				FullName:     workflowRawString(guardian["full_name"]),
				Relationship: firstNonEmpty(workflowRawString(guardian["relationship"]), "Parent"),
				Phone:        workflowRawString(guardian["phone"]),
				Email:        workflowRawString(guardian["email"]),
				Occupation:   workflowRawString(guardian["occupation"]),
				IsPrimary:    true,
				CanPickup:    workflowBool(data, "guardian_details", "can_pickup"),
			}
			if err := tx.Create(&row).Error; err != nil {
				return err
			}
			guardianID = row.ID
		}
		if workflowBool(data, "fee_assignment", "create_invoice") {
			invoice, err := createAssistantStudentInvoice(tx, schoolID, student)
			if err != nil {
				return err
			}
			invoiceID = invoice.ID
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return gin.H{"created_entities": gin.H{"student_id": createdStudent.ID, "guardian_id": guardianID, "invoice_id": invoiceID}}, nil
}

func (h *AssistantWorkflowHandler) executeTeacherOnboarding(c *gin.Context, data map[string]interface{}) (gin.H, error) {
	schoolID := scopedSchoolID(c)
	details := workflowNestedMap(data, "staff_details")
	var staff models.Staff
	var userID string
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		staffCode := workflowRawString(details["staff_code"])
		if staffCode == "" {
			staffCode = fmt.Sprintf("EMP-%d", time.Now().UTC().Unix())
		}
		if err := ensureStaffCodeAvailable(tx, schoolID, staffCode, ""); err != nil {
			return err
		}
		dob, _ := time.Parse("2006-01-02", firstNonEmpty(workflowRawString(details["date_of_birth"]), "1990-01-01"))
		joinDate, _ := time.Parse("2006-01-02", firstNonEmpty(workflowRawString(details["join_date"]), time.Now().UTC().Format("2006-01-02")))
		staff = models.Staff{
			SchoolID:       schoolID,
			StaffCode:      staffCode,
			FirstName:      workflowRawString(details["first_name"]),
			LastName:       workflowRawString(details["last_name"]),
			Email:          workflowRawString(details["email"]),
			Phone:          workflowRawString(details["phone"]),
			DateOfBirth:    dob,
			Gender:         firstNonEmpty(workflowRawString(details["gender"]), "unspecified"),
			Designation:    firstNonEmpty(workflowRawString(details["designation"]), "Teacher"),
			EmploymentType: firstNonEmpty(workflowRawString(details["employment_type"]), "full_time"),
			JoinDate:       joinDate,
			Status:         "active",
		}
		if err := tx.Create(&staff).Error; err != nil {
			return err
		}
		if password := workflowRawString(details["password"]); password != "" {
			user, err := h.staffHandler.createStaffUser(tx, schoolID, staff, workflowRawString(details["username"]), password, "Teacher", true)
			if err != nil {
				return err
			}
			userID = user.ID
		}
		for _, item := range workflowList(data, "subject_mapping") {
			subjectID := workflowRawString(item["subject_id"])
			gradeID := workflowRawString(item["grade_id"])
			if subjectID == "" || gradeID == "" {
				continue
			}
			if !subjectBelongsToSchool(subjectID, schoolID) || countRows(tx.Model(&models.Grade{}).Where("id = ? AND school_id = ?", gradeID, schoolID)) == 0 {
				return errors.New("teacher subject mapping must belong to this school")
			}
			var sectionID *string
			if v := workflowRawString(item["section_id"]); v != "" {
				if !sectionBelongsToSchool(v, schoolID) {
					return errors.New("teacher section mapping must belong to this school")
				}
				sectionID = &v
			}
			if err := tx.Create(&models.StaffSubject{
				StaffID:   staff.ID,
				SubjectID: subjectID,
				GradeID:   gradeID,
				SectionID: sectionID,
				IsPrimary: true,
			}).Error; err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return gin.H{"created_entities": gin.H{"staff_id": staff.ID, "user_id": userID, "subject_mappings": len(workflowList(data, "subject_mapping"))}}, nil
}

func (h *AssistantWorkflowHandler) executeFeeSetup(c *gin.Context, data map[string]interface{}) (gin.H, error) {
	schoolID := scopedSchoolID(c)
	details := workflowNestedMap(data, "fee_details")
	var structures []models.FeeStructure
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		academicYear, err := resolveAssistantAcademicYear(tx, schoolID, details)
		if err != nil {
			return err
		}
		grade, err := resolveAssistantGrade(tx, schoolID, workflowRawString(details["grade_id"]), workflowRawString(details["grade_name"]), int(workflowInt64(details["grade_number"])))
		if err != nil {
			return err
		}
		structures, err = applyAssistantFeeItems(tx, schoolID, grade.ID, academicYear.ID, workflowList(data, "fee_items"))
		return err
	})
	if err != nil {
		return nil, err
	}
	return gin.H{"created_entities": gin.H{"fee_structures": len(structures)}}, nil
}

func (h *AssistantWorkflowHandler) executeTimetableSetup(c *gin.Context, data map[string]interface{}) (gin.H, error) {
	schoolID := scopedSchoolID(c)
	details := workflowNestedMap(data, "timetable_details")
	sectionID := workflowRawString(details["section_id"])
	created := 0
	var logs []string
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		var err error
		created, logs, err = generateAssistantTimetable(tx, schoolID, []string{sectionID}, data)
		return err
	})
	if err != nil {
		return nil, err
	}
	return gin.H{"created_entities": gin.H{"timetable_slots": created}, "warnings": logs}, nil
}

func resolveAssistantAcademicYear(tx *gorm.DB, schoolID string, details map[string]interface{}) (models.AcademicYear, error) {
	academicYearID := workflowRawString(details["academic_year_id"])
	if academicYearID != "" {
		var year models.AcademicYear
		if err := tx.First(&year, "id = ? AND school_id = ?", academicYearID, schoolID).Error; err != nil {
			return models.AcademicYear{}, errors.New("academic year must belong to this school")
		}
		if err := ensureAssistantDefaultTerm(tx, year); err != nil {
			return models.AcademicYear{}, err
		}
		return year, nil
	}

	label := firstNonEmpty(
		workflowRawString(details["academic_year_label"]),
		workflowRawString(details["year_label"]),
		workflowRawString(details["academic_year"]),
	)
	if label == "" {
		return models.AcademicYear{}, errors.New("academic year is required")
	}

	var existing models.AcademicYear
	err := tx.Where("school_id = ? AND LOWER(year_label) = ?", schoolID, strings.ToLower(label)).First(&existing).Error
	if err == nil {
		if err := ensureAssistantDefaultTerm(tx, existing); err != nil {
			return models.AcademicYear{}, err
		}
		return existing, nil
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return models.AcademicYear{}, err
	}

	startDate, endDate := assistantAcademicYearDates(label, workflowRawString(details["start_date"]), workflowRawString(details["end_date"]))
	if err := tx.Model(&models.AcademicYear{}).Where("school_id = ?", schoolID).Update("is_current", false).Error; err != nil {
		return models.AcademicYear{}, err
	}
	year := models.AcademicYear{
		SchoolID:  schoolID,
		YearLabel: label,
		Year:      label,
		StartDate: startDate,
		EndDate:   endDate,
		IsCurrent: true,
		Status:    "active",
	}
	if err := tx.Create(&year).Error; err != nil {
		return models.AcademicYear{}, err
	}
	if err := ensureAssistantDefaultTerm(tx, year); err != nil {
		return models.AcademicYear{}, err
	}
	return year, nil
}

func assistantAcademicYearDates(label, startDateRaw, endDateRaw string) (time.Time, time.Time) {
	startDate, startErr := time.Parse("2006-01-02", startDateRaw)
	endDate, endErr := time.Parse("2006-01-02", endDateRaw)
	if startErr == nil && endErr == nil && endDate.After(startDate) {
		return startDate, endDate
	}
	yearPattern := regexp.MustCompile(`(20\d{2})`)
	match := yearPattern.FindStringSubmatch(label)
	startYear := time.Now().UTC().Year()
	if len(match) > 1 {
		if parsed, err := strconv.Atoi(match[1]); err == nil {
			startYear = parsed
		}
	}
	return time.Date(startYear, 4, 1, 0, 0, 0, 0, time.UTC), time.Date(startYear+1, 3, 31, 0, 0, 0, 0, time.UTC)
}

func ensureAssistantDefaultTerm(tx *gorm.DB, year models.AcademicYear) error {
	if year.ID == "" {
		return errors.New("academic year is required")
	}
	if countRows(tx.Model(&models.Term{}).Where("academic_year_id = ?", year.ID)) > 0 {
		return nil
	}
	term := models.Term{
		AcademicYearID: year.ID,
		TermNumber:     1,
		TermName:       "Term 1",
		StartDate:      year.StartDate,
		EndDate:        year.EndDate,
		IsCurrent:      true,
	}
	return tx.Create(&term).Error
}

func resolveAssistantGrade(tx *gorm.DB, schoolID, gradeID, gradeName string, gradeNumber int) (models.Grade, error) {
	gradeID = strings.TrimSpace(gradeID)
	gradeName = strings.TrimSpace(gradeName)
	if gradeID != "" {
		var grade models.Grade
		if err := tx.First(&grade, "id = ? AND school_id = ?", gradeID, schoolID).Error; err != nil {
			return models.Grade{}, errors.New("grade must belong to this school")
		}
		return grade, nil
	}
	if gradeName == "" {
		return models.Grade{}, errors.New("grade_name is required")
	}
	if gradeNumber <= 0 {
		gradeNumber = 1
	}
	var grade models.Grade
	err := tx.Where("school_id = ? AND LOWER(grade_name) = ?", schoolID, strings.ToLower(gradeName)).First(&grade).Error
	if err == nil {
		return grade, nil
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return models.Grade{}, err
	}
	grade = models.Grade{SchoolID: schoolID, GradeNumber: gradeNumber, GradeName: gradeName}
	if err := tx.Create(&grade).Error; err != nil {
		return models.Grade{}, err
	}
	return grade, nil
}

func applyAssistantFeeItems(tx *gorm.DB, schoolID, gradeID, academicYearID string, items []map[string]interface{}) ([]models.FeeStructure, error) {
	if academicYearID == "" || countRows(tx.Model(&models.AcademicYear{}).Where("id = ? AND school_id = ?", academicYearID, schoolID)) == 0 {
		return nil, errors.New("academic year must belong to this school")
	}
	structures := []models.FeeStructure{}
	for _, item := range items {
		amount := workflowFloat64(item["amount"])
		if amount <= 0 {
			continue
		}
		categoryID, err := resolveAssistantFeeCategory(tx, schoolID, item)
		if err != nil {
			return nil, err
		}
		dueDay := int(workflowInt64(item["due_day"]))
		if dueDay <= 0 {
			dueDay = 10
		}
		var row models.FeeStructure
		err = tx.Where("school_id = ? AND academic_year_id = ? AND grade_id = ? AND fee_category_id = ?", schoolID, academicYearID, gradeID, categoryID).First(&row).Error
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, err
		}
		row.SchoolID = schoolID
		row.AcademicYearID = academicYearID
		row.GradeID = gradeID
		row.FeeCategoryID = categoryID
		row.Amount = amount
		row.DueDay = dueDay
		row.LateFinePerDay = workflowFloat64(item["late_fine_per_day"])
		if row.ID == "" {
			if err := tx.Create(&row).Error; err != nil {
				return nil, err
			}
		} else if err := tx.Save(&row).Error; err != nil {
			return nil, err
		}
		structures = append(structures, row)
	}
	return structures, nil
}

func resolveAssistantFeeCategory(tx *gorm.DB, schoolID string, item map[string]interface{}) (string, error) {
	categoryID := workflowRawString(item["fee_category_id"])
	if categoryID != "" {
		var category models.FeeCategory
		if err := tx.First(&category, "id = ? AND school_id = ?", categoryID, schoolID).Error; err != nil {
			return "", errors.New("fee category must belong to this school")
		}
		return category.ID, nil
	}
	categoryName := firstNonEmpty(workflowRawString(item["category_name"]), workflowRawString(item["name"]))
	if categoryName == "" {
		return "", errors.New("fee category is required")
	}
	frequency := firstNonEmpty(strings.ToLower(workflowRawString(item["frequency"])), "term")
	var category models.FeeCategory
	err := tx.Where("school_id = ? AND LOWER(category_name) = ?", schoolID, strings.ToLower(categoryName)).First(&category).Error
	if err == nil {
		return category.ID, nil
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return "", err
	}
	category = models.FeeCategory{SchoolID: schoolID, CategoryName: categoryName, Frequency: frequency}
	if err := tx.Create(&category).Error; err != nil {
		return "", err
	}
	return category.ID, nil
}

func applyAssistantSubjects(tx *gorm.DB, schoolID, gradeID string, items []map[string]interface{}) ([]models.Subject, error) {
	subjects := []models.Subject{}
	for _, item := range items {
		subject, err := resolveAssistantSubject(tx, schoolID, item)
		if err != nil {
			return nil, err
		}
		if subject.ID == "" {
			continue
		}
		periods := int(workflowInt64(item["periods_per_week"]))
		if periods <= 0 {
			periods = 5
		}
		var gradeSubject models.GradeSubject
		err = tx.Where("grade_id = ? AND subject_id = ?", gradeID, subject.ID).First(&gradeSubject).Error
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, err
		}
		gradeSubject.GradeID = gradeID
		gradeSubject.SubjectID = subject.ID
		gradeSubject.PeriodsPerWeek = periods
		gradeSubject.MaxMarks = int(firstPositiveInt(workflowInt64(item["max_marks"]), 100))
		gradeSubject.PassMarks = int(firstPositiveInt(workflowInt64(item["pass_marks"]), 35))
		gradeSubject.IsMandatory = !workflowBool(item, "", "is_elective")
		if gradeSubject.ID == "" {
			if err := tx.Create(&gradeSubject).Error; err != nil {
				return nil, err
			}
		} else if err := tx.Save(&gradeSubject).Error; err != nil {
			return nil, err
		}
		subjects = append(subjects, subject)
	}
	return subjects, nil
}

func resolveAssistantSubject(tx *gorm.DB, schoolID string, item map[string]interface{}) (models.Subject, error) {
	subjectID := workflowRawString(item["subject_id"])
	if subjectID != "" {
		var subject models.Subject
		if err := tx.First(&subject, "id = ? AND school_id = ?", subjectID, schoolID).Error; err != nil {
			return models.Subject{}, errors.New("subject must belong to this school")
		}
		return subject, nil
	}
	name := firstNonEmpty(workflowRawString(item["subject_name"]), workflowRawString(item["name"]))
	if name == "" {
		return models.Subject{}, nil
	}
	deptID, err := resolveAssistantDepartment(tx, schoolID, workflowRawString(item["department_id"]), workflowRawString(item["department_name"]))
	if err != nil {
		return models.Subject{}, err
	}
	code := workflowRawString(item["subject_code"])
	var subject models.Subject
	query := tx.Where("school_id = ? AND LOWER(subject_name) = ?", schoolID, strings.ToLower(name))
	if code != "" {
		query = tx.Where("school_id = ? AND LOWER(subject_code) = ?", schoolID, strings.ToLower(code))
	}
	err = query.First(&subject).Error
	if err == nil {
		return subject, nil
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return models.Subject{}, err
	}
	subject = models.Subject{
		SchoolID:     schoolID,
		DepartmentID: deptID,
		SubjectName:  name,
		SubjectCode:  code,
		SubjectType:  firstNonEmpty(workflowRawString(item["subject_type"]), "core"),
	}
	if err := tx.Create(&subject).Error; err != nil {
		return models.Subject{}, err
	}
	return subject, nil
}

func resolveAssistantDepartment(tx *gorm.DB, schoolID, departmentID, departmentName string) (string, error) {
	if departmentID != "" {
		var row models.Department
		if err := tx.First(&row, "id = ? AND school_id = ?", departmentID, schoolID).Error; err == nil {
			return row.ID, nil
		}
	}
	name := firstNonEmpty(departmentName, "Academics")
	var row models.Department
	err := tx.Where("school_id = ? AND LOWER(department_name) = ?", schoolID, strings.ToLower(name)).First(&row).Error
	if err == nil {
		return row.ID, nil
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return "", err
	}
	row = models.Department{SchoolID: schoolID, DepartmentName: name, Description: "Created by guided assistant"}
	if err := tx.Create(&row).Error; err != nil {
		return "", err
	}
	return row.ID, nil
}

func applyAssistantSubjectTeachers(tx *gorm.DB, schoolID, gradeID, sectionID string, mappings []map[string]interface{}, createdSubjects []models.Subject) error {
	subjectByName := map[string]string{}
	for _, subject := range createdSubjects {
		subjectByName[strings.ToLower(subject.SubjectName)] = subject.ID
	}
	for _, mapping := range mappings {
		teacherID := workflowRawString(mapping["teacher_id"])
		if teacherID == "" {
			continue
		}
		if err := tx.First(&models.Staff{}, "id = ? AND school_id = ? AND status = ?", teacherID, schoolID, "active").Error; err != nil {
			return errors.New("subject teacher must be active staff in this school")
		}
		subjectID := workflowRawString(mapping["subject_id"])
		if subjectID == "" {
			subjectID = subjectByName[strings.ToLower(workflowRawString(mapping["subject_name"]))]
		}
		if subjectID == "" {
			continue
		}
		var row models.StaffSubject
		err := tx.Where("staff_id = ? AND subject_id = ? AND grade_id = ? AND section_id = ?", teacherID, subjectID, gradeID, sectionID).First(&row).Error
		if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		row.StaffID = teacherID
		row.SubjectID = subjectID
		row.GradeID = gradeID
		row.SectionID = &sectionID
		row.IsPrimary = true
		if row.ID == "" {
			if err := tx.Create(&row).Error; err != nil {
				return err
			}
		} else if err := tx.Save(&row).Error; err != nil {
			return err
		}
	}
	return nil
}

func generateAssistantTimetable(tx *gorm.DB, schoolID string, sectionIDs []string, data map[string]interface{}) (int, []string, error) {
	details := workflowNestedMap(data, "timetable")
	if len(details) == 0 {
		details = workflowNestedMap(data, "timetable_details")
	}
	academicYearID := firstNonEmpty(workflowRawString(details["academic_year_id"]), workflowString(data, "class_details", "academic_year_id"))
	if academicYearID == "" && len(sectionIDs) > 0 {
		var section models.Section
		if err := tx.First(&section, "id = ?", sectionIDs[0]).Error; err == nil {
			academicYearID = section.AcademicYearID
		}
	}
	if academicYearID == "" {
		return 0, nil, errors.New("academic year is required before generating timetable")
	}
	termID := workflowRawString(details["term_id"])
	if termID == "" {
		var term models.Term
		if err := tx.First(&term, "academic_year_id = ?", academicYearID).Error; err != nil {
			var year models.AcademicYear
			if loadErr := tx.First(&year, "id = ? AND school_id = ?", academicYearID, schoolID).Error; loadErr != nil {
				return 0, nil, errors.New("term_id is required before generating timetable")
			}
			if createErr := ensureAssistantDefaultTerm(tx, year); createErr != nil {
				return 0, nil, createErr
			}
			if retryErr := tx.First(&term, "academic_year_id = ?", academicYearID).Error; retryErr != nil {
				return 0, nil, errors.New("term_id is required before generating timetable")
			}
		}
		termID = term.ID
	}
	days := workflowIntList(details["days"])
	if len(days) == 0 {
		days = []int{1, 2, 3, 4, 5}
	}
	periodsPerDay := int(firstPositiveInt(workflowInt64(details["periods_per_day"]), 7))
	duration := int(firstPositiveInt(workflowInt64(details["period_duration_minutes"]), 40))
	gap := int(firstPositiveInt(workflowInt64(details["gap_minutes"]), 5))
	startTime := firstNonEmpty(workflowRawString(details["start_time"]), "09:00")
	created := 0
	warnings := []string{}
	for _, sectionID := range sectionIDs {
		var assignments []models.StaffSubject
		if err := tx.Preload("Subject").Where("section_id = ?", sectionID).Find(&assignments).Error; err != nil {
			return created, warnings, err
		}
		if len(assignments) == 0 {
			warnings = append(warnings, "No subject teacher assignments for section "+sectionID)
			continue
		}
		sort.SliceStable(assignments, func(i, j int) bool {
			return assignments[i].CreatedAt.Before(assignments[j].CreatedAt)
		})
		index := 0
		for _, day := range days {
			for period := 1; period <= periodsPerDay; period++ {
				assignment := assignments[index%len(assignments)]
				index++
				if timetableSlotConflict(tx, academicYearID, termID, day, period, sectionID, assignment.StaffID) {
					continue
				}
				start, end := assistantPeriodTime(startTime, period, duration, gap)
				slot := models.TimetableSlot{
					SectionID:      sectionID,
					AcademicYearID: academicYearID,
					TermID:         termID,
					DayOfWeek:      day,
					PeriodNumber:   period,
					StartTime:      &start,
					EndTime:        &end,
					SubjectID:      assignment.SubjectID,
					StaffID:        assignment.StaffID,
					SlotType:       "regular",
				}
				if err := tx.Create(&slot).Error; err != nil {
					return created, warnings, err
				}
				created++
			}
		}
	}
	return created, warnings, nil
}

func timetableSlotConflict(tx *gorm.DB, academicYearID, termID string, day, period int, sectionID, staffID string) bool {
	return countRows(tx.Model(&models.TimetableSlot{}).
		Where("academic_year_id = ? AND term_id = ? AND day_of_week = ? AND period_number = ?", academicYearID, termID, day, period).
		Where("(section_id = ? OR staff_id = ?)", sectionID, staffID)) > 0
}

func assistantPeriodTime(startTime string, period, duration, gap int) (time.Time, time.Time) {
	start, err := time.Parse("15:04", startTime)
	if err != nil {
		start, _ = time.Parse("15:04", "09:00")
	}
	start = start.Add(time.Duration((period-1)*(duration+gap)) * time.Minute)
	end := start.Add(time.Duration(duration) * time.Minute)
	return normalizeClockDate(start), normalizeClockDate(end)
}

func normalizeClockDate(value time.Time) time.Time {
	return time.Date(2000, 1, 1, value.Hour(), value.Minute(), 0, 0, time.UTC)
}

func createAssistantStudentInvoice(tx *gorm.DB, schoolID string, student models.Student) (models.FeeInvoice, error) {
	if student.CurrentSectionID == nil || *student.CurrentSectionID == "" {
		return models.FeeInvoice{}, nil
	}
	var section models.Section
	if err := tx.First(&section, "id = ?", *student.CurrentSectionID).Error; err != nil {
		return models.FeeInvoice{}, err
	}
	var structures []models.FeeStructure
	if err := tx.Where("school_id = ? AND grade_id = ? AND academic_year_id = ?", schoolID, section.GradeID, section.AcademicYearID).Find(&structures).Error; err != nil {
		return models.FeeInvoice{}, err
	}
	if len(structures) == 0 {
		return models.FeeInvoice{}, nil
	}
	total := 0.0
	for _, item := range structures {
		total += item.Amount
	}
	now := time.Now().UTC()
	invoice := models.FeeInvoice{
		StudentID:      student.ID,
		AcademicYearID: section.AcademicYearID,
		InvoiceNumber:  fmt.Sprintf("INV-%d", now.UnixNano()),
		InvoiceDate:    now,
		DueDate:        now.AddDate(0, 1, 0),
		TotalAmount:    total,
		NetAmount:      total,
		Balance:        total,
		Status:         "pending",
	}
	if err := tx.Create(&invoice).Error; err != nil {
		return models.FeeInvoice{}, err
	}
	for _, structure := range structures {
		if err := tx.Create(&models.FeeInvoiceItem{
			InvoiceID:     invoice.ID,
			FeeCategoryID: structure.FeeCategoryID,
			Amount:        structure.Amount,
			Description:   "Admission fee assignment",
		}).Error; err != nil {
			return models.FeeInvoice{}, err
		}
	}
	return invoice, nil
}

func (h *AssistantWorkflowHandler) reviewSummary(def assistantWorkflowDefinition, data map[string]interface{}, validation workflowValidationResult) gin.H {
	return gin.H{
		"workflow":      def.Title,
		"workflow_type": def.Type,
		"steps":         len(def.Steps),
		"valid":         validation.Valid,
		"issues":        validation.Issues,
		"preview": gin.H{
			"class":             firstNonEmpty(workflowString(data, "class_details", "class_name"), workflowString(data, "class_details", "grade_name")),
			"student":           strings.TrimSpace(workflowString(data, "student_details", "first_name") + " " + workflowString(data, "student_details", "last_name")),
			"staff":             strings.TrimSpace(workflowString(data, "staff_details", "first_name") + " " + workflowString(data, "staff_details", "last_name")),
			"sections":          normalizedWorkflowSections(data),
			"subjects":          workflowList(data, "subjects"),
			"fees":              len(workflowList(data, "fee_structure")) + len(workflowList(data, "fee_items")),
			"timetable_enabled": workflowBool(data, "timetable", "auto_generate"),
		},
	}
}

func (h *AssistantWorkflowHandler) sessionResponse(row models.WorkflowSession) gin.H {
	def, _ := assistantDefinitionByType(row.WorkflowType)
	logs := make([]gin.H, 0, len(row.Logs))
	for _, log := range row.Logs {
		logs = append(logs, gin.H{
			"id": log.ID, "event_type": log.EventType, "step_id": log.StepID,
			"message": log.Message, "created_at": log.CreatedAt,
			"payload": services.DecodeWorkflowMap(log.Payload),
		})
	}
	return gin.H{
		"id":                 row.ID,
		"workflow_type":      row.WorkflowType,
		"title":              row.Title,
		"status":             row.Status,
		"current_step_id":    row.CurrentStepID,
		"completed_steps":    services.DecodeWorkflowStringSlice(row.CompletedSteps),
		"pending_steps":      services.DecodeWorkflowStringSlice(row.PendingSteps),
		"draft_data":         services.DecodeWorkflowMap(row.DraftData),
		"validation_summary": services.DecodeWorkflowMap(row.ValidationSummary),
		"review_summary":     services.DecodeWorkflowMap(row.ReviewSummary),
		"rollback_state":     row.RollbackState,
		"last_error":         row.LastError,
		"source_command":     row.SourceCommand,
		"created_at":         row.CreatedAt,
		"updated_at":         row.UpdatedAt,
		"confirmed_at":       row.ConfirmedAt,
		"executed_at":        row.ExecutedAt,
		"canceled_at":        row.CanceledAt,
		"definition":         def,
		"logs":               logs,
	}
}

func (h *AssistantWorkflowHandler) log(c *gin.Context, sessionID, eventType, stepID, message string, payload interface{}) error {
	encoded, _ := json.Marshal(payload)
	return h.store.Log(c.Request.Context(), models.WorkflowLog{
		SchoolID:  scopedSchoolID(c),
		SessionID: sessionID,
		UserID:    currentUserID(c),
		EventType: eventType,
		StepID:    stepID,
		Message:   message,
		Payload:   string(encoded),
	})
}

func assistantWorkflowDefinitions() []assistantWorkflowDefinition {
	return []assistantWorkflowDefinition{
		{
			Type: "create_class", Title: "Create Class", Category: "Academics", TargetRoute: "/principal-classes-screen", Execution: "transactional",
			Description:  "Create a class with sections, subjects, teachers, fees, timetable, settings, and notifications.",
			Dependencies: []string{"academic_years", "grades", "sections", "subjects", "staff", "fees", "timetable", "notifications", "audit_logs"},
			Steps: []assistantWorkflowStep{
				{ID: "class_details", Title: "Class details", Prompt: "Capture class name, academic year, sections, and capacity.", Fields: []string{"class_name", "academic_year_id", "academic_year_label", "start_date", "end_date", "section_count", "capacity"}},
				{ID: "sections", Title: "Sections", Prompt: "Create sections and assign rooms.", Fields: []string{"section_name", "room_id", "capacity"}},
				{ID: "subjects", Title: "Subjects", Prompt: "Choose or add compulsory and elective subjects.", Fields: []string{"subject_name", "subject_type", "periods_per_week"}},
				{ID: "class_teacher", Title: "Class teacher", Prompt: "Assign class teacher and check workload.", Fields: []string{"class_teacher_id"}},
				{ID: "subject_teachers", Title: "Subject teachers", Prompt: "Assign teachers for each subject.", Fields: []string{"subject_id", "teacher_id"}},
				{ID: "fee_structure", Title: "Fee structure", Prompt: "Add tuition, books, transport, and miscellaneous fees.", Fields: []string{"category_name", "amount", "due_day", "frequency"}},
				{ID: "timetable", Title: "Timetable", Prompt: "Generate or skip timetable with conflict checks.", Fields: []string{"auto_generate", "term_id", "days", "periods_per_day"}},
				{ID: "notifications", Title: "Settings", Prompt: "Configure attendance, grading, and notification preferences.", Fields: []string{"attendance_rule", "grading_system", "notify_staff"}},
				{ID: "review", Title: "Review & confirmation", Prompt: "Review all operations before execution.", Fields: []string{"confirm"}},
			},
		},
		{Type: "student_onboarding", Title: "Add Students", Category: "Admissions", TargetRoute: "/student-oversight-screen", Execution: "transactional", Description: "Student admission with guardian, class enrollment, and optional fee assignment.", Dependencies: []string{"students", "guardians", "enrollments", "fees"}, Steps: []assistantWorkflowStep{{ID: "student_details", Title: "Student details", Prompt: "Capture admission and class details.", Fields: []string{"first_name", "last_name", "date_of_birth", "gender", "current_section_id"}}, {ID: "guardian_details", Title: "Parent or guardian", Prompt: "Capture parent or guardian details.", Fields: []string{"full_name", "relationship", "phone", "email"}}, {ID: "fee_assignment", Title: "Fee assignment", Prompt: "Assign existing class fee structure if needed.", Fields: []string{"create_invoice"}}, {ID: "review", Title: "Review & confirmation", Prompt: "Review student onboarding before execution.", Fields: []string{"confirm"}}}},
		{Type: "teacher_onboarding", Title: "Staff Management", Category: "People", TargetRoute: "/staff-management-screen", Execution: "transactional", Description: "Teacher creation with login and subject/class mapping.", Dependencies: []string{"staff", "users", "subjects", "grades", "sections"}, Steps: []assistantWorkflowStep{{ID: "staff_details", Title: "Teacher details", Prompt: "Capture teacher profile and optional login.", Fields: []string{"staff_code", "first_name", "last_name", "email", "phone"}}, {ID: "subject_mapping", Title: "Subject mapping", Prompt: "Assign subjects, grades, and sections.", Fields: []string{"subject_id", "grade_id", "section_id"}}, {ID: "review", Title: "Review & confirmation", Prompt: "Review teacher onboarding before execution.", Fields: []string{"confirm"}}}},
		{Type: "fee_setup", Title: "Fees", Category: "Finance", TargetRoute: "/fee-monitoring-screen", Execution: "transactional", Description: "Create class fee structures with due schedules.", Dependencies: []string{"fee_categories", "fee_structures", "academic_years", "grades"}, Steps: []assistantWorkflowStep{{ID: "fee_details", Title: "Fee scope", Prompt: "Choose or create academic year and class.", Fields: []string{"academic_year_id", "academic_year_label", "start_date", "end_date", "grade_id", "grade_name"}}, {ID: "fee_items", Title: "Fee items", Prompt: "Add amount, frequency, and due day.", Fields: []string{"category_name", "amount", "frequency", "due_day"}}, {ID: "review", Title: "Review & confirmation", Prompt: "Review fee setup before execution.", Fields: []string{"confirm"}}}},
		{Type: "timetable_setup", Title: "Timetable", Category: "Academics", TargetRoute: "/principal-timetable-screen", Execution: "transactional", Description: "Generate timetable slots from subject-teacher mappings.", Dependencies: []string{"sections", "staff_subjects", "terms", "timetable_slots"}, Steps: []assistantWorkflowStep{{ID: "timetable_details", Title: "Timetable scope", Prompt: "Choose section, academic year, and term.", Fields: []string{"section_id", "academic_year_id", "term_id"}}, {ID: "timetable", Title: "Generation rules", Prompt: "Set days, periods, and timings.", Fields: []string{"days", "periods_per_day", "start_time"}}, {ID: "review", Title: "Review & confirmation", Prompt: "Review timetable before execution.", Fields: []string{"confirm"}}}},
	}
}

func assistantActionCards(defs []assistantWorkflowDefinition, role string) []gin.H {
	cards := []gin.H{}
	for _, def := range defs {
		cards = append(cards, gin.H{"title": def.Title, "workflow_type": def.Type, "category": def.Category, "target_route": def.TargetRoute})
	}
	for _, card := range connectedAssistantCards(role) {
		cards = append(cards, card)
	}
	return cards
}

func connectedAssistantCards(role string) []gin.H {
	principal := strings.EqualFold(role, "principal")
	attendanceRoute := "/admin-attendance-screen"
	examsRoute := "/admin-exams-screen"
	reportsRoute := "/admin-reports-screen"
	if principal {
		attendanceRoute = "/principal-attendance-screen"
		examsRoute = "/principal-exams-screen"
		reportsRoute = "/principal-results-screen"
	}
	return []gin.H{
		{"title": "Attendance", "workflow_type": "attendance", "category": "Connected ERP", "target_route": attendanceRoute},
		{"title": "Exams", "workflow_type": "exams", "category": "Connected ERP", "target_route": examsRoute},
		{"title": "Notifications", "workflow_type": "notifications", "category": "Connected ERP", "target_route": "/notification-center-screen"},
		{"title": "Reports", "workflow_type": "reports", "category": "Connected ERP", "target_route": reportsRoute},
	}
}

func assistantCatalogReadiness(schoolID string) gin.H {
	count := func(model interface{}, query string, args ...interface{}) int64 {
		db := database.DB.Model(model)
		if query != "" {
			db = db.Where(query, args...)
		}
		var total int64
		_ = db.Count(&total).Error
		return total
	}
	stats := gin.H{
		"academic_years": count(&models.AcademicYear{}, "school_id = ?", schoolID),
		"classes":        count(&models.Section{}, "academic_year_id IN (SELECT id FROM academic_years WHERE school_id = ?)", schoolID),
		"students":       count(&models.Student{}, "school_id = ?", schoolID),
		"staff":          count(&models.Staff{}, "school_id = ? AND status = ?", schoolID, "active"),
		"subjects":       count(&models.Subject{}, "school_id = ?", schoolID),
		"fee_structures": count(&models.FeeStructure{}, "school_id = ?", schoolID),
		"timetable":      count(&models.TimetableSlot{}, "section_id IN (SELECT id FROM sections WHERE academic_year_id IN (SELECT id FROM academic_years WHERE school_id = ?))", schoolID),
	}
	suggestions := []string{}
	if stats["academic_years"].(int64) == 0 {
		suggestions = append(suggestions, "Start with Create Class; the assistant can create the first academic year and term during the workflow.")
	}
	if stats["staff"].(int64) <= 1 {
		suggestions = append(suggestions, "Onboard teachers before assigning class teachers or generating a complete timetable.")
	}
	if stats["classes"].(int64) == 0 {
		suggestions = append(suggestions, "Create the first class with sections, subjects, fees, and timetable in one guided review.")
	}
	if stats["fee_structures"].(int64) == 0 {
		suggestions = append(suggestions, "Add fee items during class creation so student admission can generate invoices later.")
	}
	if len(suggestions) == 0 {
		suggestions = append(suggestions, "Your setup has the core data needed for connected assistant workflows.")
	}
	return gin.H{"stats": stats, "suggestions": suggestions}
}

func assistantDefinitionByType(workflowType string) (assistantWorkflowDefinition, bool) {
	for _, def := range assistantWorkflowDefinitions() {
		if def.Type == strings.TrimSpace(workflowType) {
			return def, true
		}
	}
	return assistantWorkflowDefinition{}, false
}

func detectAssistantIntent(command string) (string, map[string]interface{}, []string) {
	lower := strings.ToLower(strings.TrimSpace(command))
	data := map[string]interface{}{}
	switch {
	case strings.Contains(lower, "student") || strings.Contains(lower, "admission"):
		return "student_onboarding", data, []string{"Open student onboarding"}
	case strings.Contains(lower, "teacher") || strings.Contains(lower, "staff"):
		return "teacher_onboarding", data, []string{"Open teacher onboarding"}
	case strings.Contains(lower, "fee"):
		return "fee_setup", data, []string{"Open fee setup"}
	case strings.Contains(lower, "timetable"):
		return "timetable_setup", data, []string{"Open timetable setup"}
	default:
		if strings.Contains(lower, "class") || strings.Contains(lower, "grade") || strings.Contains(lower, "create") {
			name := extractClassName(command)
			if name != "" {
				data["class_details"] = map[string]interface{}{"class_name": name, "grade_name": name, "section_count": 1}
			}
			return "create_class", data, []string{"Open create class workflow", "Review detected class name before execution"}
		}
	}
	return "create_class", data, []string{"Start with Create Class or choose another action card"}
}

func extractClassName(command string) string {
	clean := strings.TrimSpace(command)
	patterns := []*regexp.Regexp{
		regexp.MustCompile(`(?i)create\s+(.+?)\s+class`),
		regexp.MustCompile(`(?i)class\s+(.+)$`),
		regexp.MustCompile(`(?i)grade\s+(.+)$`),
	}
	for _, pattern := range patterns {
		match := pattern.FindStringSubmatch(clean)
		if len(match) > 1 {
			return strings.TrimSpace(match[1])
		}
	}
	return ""
}

func parseAssistantBulkContent(workflowType, format, content string) (map[string]interface{}, error) {
	format = strings.ToLower(strings.TrimSpace(format))
	if format == "" {
		format = "csv"
	}
	if strings.TrimSpace(content) == "" {
		return nil, errors.New("content is required")
	}
	if format == "txt" {
		result := map[string]interface{}{}
		for _, line := range strings.Split(content, "\n") {
			parts := strings.SplitN(line, ":", 2)
			if len(parts) != 2 {
				continue
			}
			result[strings.TrimSpace(parts[0])] = strings.TrimSpace(parts[1])
		}
		return normalizeImportedAssistantData(workflowType, result), nil
	}
	reader := csv.NewReader(bytes.NewBufferString(content))
	rows, err := reader.ReadAll()
	if err != nil {
		return nil, err
	}
	if len(rows) < 2 {
		return nil, errors.New("csv requires headers and one data row")
	}
	raw := map[string]interface{}{}
	for idx, header := range rows[0] {
		if idx < len(rows[1]) {
			raw[strings.TrimSpace(header)] = strings.TrimSpace(rows[1][idx])
		}
	}
	return normalizeImportedAssistantData(workflowType, raw), nil
}

func normalizeImportedAssistantData(workflowType string, raw map[string]interface{}) map[string]interface{} {
	switch workflowType {
	case "create_class":
		result := map[string]interface{}{
			"class_details": map[string]interface{}{
				"class_name":          raw["class_name"],
				"grade_name":          raw["class_name"],
				"academic_year_id":    raw["academic_year_id"],
				"academic_year_label": raw["academic_year_label"],
				"start_date":          raw["start_date"],
				"end_date":            raw["end_date"],
				"section_count":       workflowInt64(raw["section_count"]),
				"capacity":            workflowInt64(raw["capacity"]),
			},
		}
		if names := workflowRawString(raw["section_names"]); names != "" {
			sections := []map[string]interface{}{}
			for _, name := range strings.Split(names, "|") {
				if strings.TrimSpace(name) != "" {
					sections = append(sections, map[string]interface{}{"section_name": strings.TrimSpace(name), "capacity": workflowInt64(raw["capacity"])})
				}
			}
			result["sections"] = sections
		}
		if subjects := pipeList(raw["subjects"]); len(subjects) > 0 {
			rows := []map[string]interface{}{}
			for _, subject := range subjects {
				rows = append(rows, map[string]interface{}{"subject_name": subject, "subject_type": "core", "periods_per_week": 5})
			}
			result["subjects"] = rows
		}
		if fees := parseAssistantFeePairs(raw["fees"]); len(fees) > 0 {
			result["fee_structure"] = fees
		}
		return result
	case "student_onboarding":
		return map[string]interface{}{
			"student_details": map[string]interface{}{
				"first_name":         raw["first_name"],
				"last_name":          raw["last_name"],
				"date_of_birth":      raw["date_of_birth"],
				"gender":             raw["gender"],
				"current_section_id": raw["current_section_id"],
				"admission_number":   raw["admission_number"],
				"student_code":       raw["student_code"],
			},
			"guardian_details": map[string]interface{}{
				"full_name":    firstNonEmpty(workflowRawString(raw["guardian_name"]), workflowRawString(raw["guardian_full_name"])),
				"relationship": raw["guardian_relationship"],
				"phone":        raw["guardian_phone"],
				"email":        raw["guardian_email"],
			},
			"fee_assignment": map[string]interface{}{"create_invoice": workflowBool(raw, "", "create_invoice")},
		}
	case "teacher_onboarding":
		mappings := []map[string]interface{}{}
		subjectIDs := pipeList(raw["subject_ids"])
		gradeIDs := pipeList(raw["grade_ids"])
		for i, subjectID := range subjectIDs {
			gradeID := ""
			if i < len(gradeIDs) {
				gradeID = gradeIDs[i]
			}
			mappings = append(mappings, map[string]interface{}{"subject_id": subjectID, "grade_id": gradeID})
		}
		return map[string]interface{}{
			"staff_details": map[string]interface{}{
				"staff_code":  raw["staff_code"],
				"first_name":  raw["first_name"],
				"last_name":   raw["last_name"],
				"email":       raw["email"],
				"phone":       raw["phone"],
				"username":    raw["username"],
				"password":    raw["password"],
				"designation": raw["designation"],
			},
			"subject_mapping": mappings,
		}
	case "fee_setup":
		return map[string]interface{}{
			"fee_details": map[string]interface{}{
				"academic_year_id":    raw["academic_year_id"],
				"academic_year_label": raw["academic_year_label"],
				"start_date":          raw["start_date"],
				"end_date":            raw["end_date"],
				"grade_id":            raw["grade_id"],
				"grade_name":          raw["grade_name"],
			},
			"fee_items": []map[string]interface{}{{
				"category_name": raw["category_name"],
				"amount":        workflowFloat64(raw["amount"]),
				"frequency":     raw["frequency"],
				"due_day":       workflowInt64(raw["due_day"]),
			}},
		}
	case "timetable_setup":
		return map[string]interface{}{
			"timetable_details": map[string]interface{}{
				"section_id":       raw["section_id"],
				"academic_year_id": raw["academic_year_id"],
				"term_id":          raw["term_id"],
			},
			"timetable": map[string]interface{}{
				"days":            raw["days"],
				"periods_per_day": workflowInt64(raw["periods_per_day"]),
				"start_time":      raw["start_time"],
				"auto_generate":   true,
			},
		}
	default:
		return raw
	}
}

func pipeList(value interface{}) []string {
	text := strings.TrimSpace(fmt.Sprint(value))
	if text == "" || text == "<nil>" {
		return []string{}
	}
	parts := strings.FieldsFunc(text, func(r rune) bool { return r == '|' || r == ',' })
	result := []string{}
	for _, part := range parts {
		if item := strings.TrimSpace(part); item != "" {
			result = append(result, item)
		}
	}
	return result
}

func parseAssistantFeePairs(value interface{}) []map[string]interface{} {
	rows := []map[string]interface{}{}
	for _, pair := range pipeList(value) {
		parts := strings.SplitN(pair, "=", 2)
		if len(parts) != 2 {
			continue
		}
		rows = append(rows, map[string]interface{}{
			"category_name": strings.TrimSpace(parts[0]),
			"amount":        workflowFloat64(strings.TrimSpace(parts[1])),
			"frequency":     "term",
			"due_day":       10,
		})
	}
	return rows
}

func assistantTemplateHeaders(workflowType string) []string {
	switch workflowType {
	case "create_class":
		return []string{"class_name", "academic_year_id", "academic_year_label", "start_date", "end_date", "section_count", "capacity", "section_names", "subjects", "fees"}
	case "student_onboarding":
		return []string{"first_name", "last_name", "date_of_birth", "gender", "current_section_id", "admission_number", "guardian_name", "guardian_relationship", "guardian_phone", "guardian_email", "create_invoice"}
	case "teacher_onboarding":
		return []string{"staff_code", "first_name", "last_name", "email", "phone", "username", "password", "designation", "subject_ids", "grade_ids"}
	case "fee_setup":
		return []string{"academic_year_id", "academic_year_label", "start_date", "end_date", "grade_id", "grade_name", "category_name", "amount", "frequency", "due_day"}
	case "timetable_setup":
		return []string{"section_id", "academic_year_id", "term_id", "days", "periods_per_day", "start_time"}
	default:
		return []string{"key", "value"}
	}
}

func assistantTextTemplate(workflowType string) string {
	lines := []string{}
	for _, header := range assistantTemplateHeaders(workflowType) {
		lines = append(lines, header+": ")
	}
	return strings.Join(lines, "\n")
}

func workflowString(data map[string]interface{}, stepID, field string) string {
	value := workflowValue(data, stepID, field)
	return workflowRawString(value)
}

func workflowRawString(value interface{}) string {
	text := strings.TrimSpace(fmt.Sprint(value))
	if text == "<nil>" {
		return ""
	}
	return text
}

func workflowInt(data map[string]interface{}, stepID, field string) int {
	return int(workflowInt64(workflowValue(data, stepID, field)))
}

func workflowInt64(value interface{}) int64 {
	switch typed := value.(type) {
	case string:
		parsed, _ := strconv.ParseInt(strings.TrimSpace(typed), 10, 64)
		return parsed
	default:
		return int64FromAny(typed)
	}
}

func workflowFloat64(value interface{}) float64 {
	switch typed := value.(type) {
	case string:
		parsed, _ := strconv.ParseFloat(strings.TrimSpace(typed), 64)
		return parsed
	default:
		return float64FromAny(typed)
	}
}

func workflowBool(data map[string]interface{}, stepID, field string) bool {
	value := workflowValue(data, stepID, field)
	switch typed := value.(type) {
	case bool:
		return typed
	case string:
		return strings.EqualFold(typed, "true") || strings.EqualFold(typed, "yes") || strings.EqualFold(typed, "1")
	default:
		return workflowInt64(typed) == 1
	}
}

func workflowValue(data map[string]interface{}, stepID, field string) interface{} {
	if stepID != "" {
		if nested := workflowNestedMap(data, stepID); len(nested) > 0 {
			if value, ok := nested[field]; ok {
				return value
			}
		}
	}
	return data[field]
}

func workflowNestedMap(data map[string]interface{}, stepID string) map[string]interface{} {
	if data == nil {
		return map[string]interface{}{}
	}
	value, ok := data[stepID]
	if !ok {
		return map[string]interface{}{}
	}
	if typed, ok := value.(map[string]interface{}); ok {
		return typed
	}
	if typed, ok := value.(map[string]string); ok {
		result := map[string]interface{}{}
		for key, value := range typed {
			result[key] = value
		}
		return result
	}
	return map[string]interface{}{}
}

func workflowList(data map[string]interface{}, key string) []map[string]interface{} {
	value, ok := data[key]
	if !ok {
		if nested := workflowNestedMap(data, key); len(nested) > 0 {
			if items, ok := nested["items"]; ok {
				value = items
			}
		}
	}
	switch typed := value.(type) {
	case []map[string]interface{}:
		return typed
	case []interface{}:
		result := []map[string]interface{}{}
		for _, item := range typed {
			if row, ok := item.(map[string]interface{}); ok {
				result = append(result, row)
			}
		}
		return result
	default:
		return []map[string]interface{}{}
	}
}

func workflowIntList(value interface{}) []int {
	switch typed := value.(type) {
	case []int:
		return typed
	case []interface{}:
		result := []int{}
		for _, item := range typed {
			if v := int(workflowInt64(item)); v > 0 {
				result = append(result, v)
			}
		}
		return result
	case string:
		result := []int{}
		for _, part := range strings.Split(typed, ",") {
			if v, err := strconv.Atoi(strings.TrimSpace(part)); err == nil && v > 0 {
				result = append(result, v)
			}
		}
		return result
	default:
		return []int{}
	}
}

func normalizedWorkflowSections(data map[string]interface{}) []map[string]interface{} {
	sections := workflowList(data, "sections")
	if len(sections) > 0 {
		return sections
	}
	count := workflowInt(data, "class_details", "section_count")
	capacity := workflowInt(data, "class_details", "capacity")
	if count <= 0 {
		return []map[string]interface{}{}
	}
	result := []map[string]interface{}{}
	for i := 0; i < count; i++ {
		result = append(result, map[string]interface{}{"section_name": string(rune('A' + i)), "capacity": capacity})
	}
	return result
}

func workflowHasSectionCapacity(data map[string]interface{}) bool {
	for _, section := range normalizedWorkflowSections(data) {
		if workflowInt64(section["capacity"]) > 0 {
			return true
		}
	}
	return false
}

func firstPositiveInt(values ...int64) int64 {
	for _, value := range values {
		if value > 0 {
			return value
		}
	}
	return 0
}

func compactWorkflowStrings(values []string) []string {
	result := []string{}
	seen := map[string]bool{}
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" || seen[value] {
			continue
		}
		seen[value] = true
		result = append(result, value)
	}
	return result
}

func addWorkflowString(values []string, value string) []string {
	return compactWorkflowStrings(append(values, value))
}

func copyWorkflowMap(input map[string]interface{}) map[string]interface{} {
	result := map[string]interface{}{}
	for key, value := range input {
		result[key] = value
	}
	return result
}

func mergeWorkflowMap(dst, src map[string]interface{}) {
	for key, value := range src {
		dst[key] = value
	}
}

func assistantStepIDs(def assistantWorkflowDefinition) []string {
	ids := make([]string, 0, len(def.Steps))
	for _, step := range def.Steps {
		ids = append(ids, step.ID)
	}
	return ids
}

func firstStepID(def assistantWorkflowDefinition) string {
	if len(def.Steps) == 0 {
		return ""
	}
	return def.Steps[0].ID
}

func assistantStepExists(def assistantWorkflowDefinition, stepID string) bool {
	for _, step := range def.Steps {
		if step.ID == stepID {
			return true
		}
	}
	return false
}

func pendingWorkflowSteps(def assistantWorkflowDefinition, completed []string) []string {
	done := map[string]bool{}
	for _, id := range completed {
		done[id] = true
	}
	pending := []string{}
	for _, step := range def.Steps {
		if !done[step.ID] {
			pending = append(pending, step.ID)
		}
	}
	return pending
}

func assistantRuleSuggestions(workflowType string, issues []workflowIssue) []string {
	suggestions := []string{"Review and confirm before execution"}
	for _, issue := range issues {
		if issue.Severity == "warning" {
			suggestions = append(suggestions, issue.Message)
		}
	}
	if workflowType == "create_class" {
		suggestions = append(suggestions, "Create subjects, fee setup, and timetable from one review screen to avoid missing dependencies")
	}
	return compactWorkflowStrings(suggestions)
}

func workflowStructMap(value interface{}) map[string]interface{} {
	encoded, _ := json.Marshal(value)
	result := map[string]interface{}{}
	_ = json.Unmarshal(encoded, &result)
	return result
}

func workflowExecutionStatus(err error) int {
	if err == nil {
		return http.StatusInternalServerError
	}
	message := strings.ToLower(err.Error())
	if strings.Contains(message, "required") || strings.Contains(message, "belong") || strings.Contains(message, "exists") || strings.Contains(message, "conflict") {
		return http.StatusBadRequest
	}
	return http.StatusInternalServerError
}

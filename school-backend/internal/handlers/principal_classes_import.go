package handlers

import (
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type principalClassCsvImportRequest struct {
	CSVText string `json:"csv_text"`
	Content string `json:"content"`
}

type principalClassCsvImportIssue struct {
	Row     int    `json:"row"`
	Field   string `json:"field"`
	Message string `json:"message"`
}

type principalClassCsvImportPreviewRow struct {
	RowNumber      int      `json:"row_number"`
	Mode           string   `json:"mode"`
	GradeName      string   `json:"grade_name"`
	GradeNumber    int      `json:"grade_number"`
	SectionName    string   `json:"section_name"`
	AcademicYearID string   `json:"academic_year_id"`
	YearLabel      string   `json:"year_label"`
	ClassTeacherID string   `json:"class_teacher_id"`
	RoomNumber     string   `json:"room_number"`
	SubjectCount   int      `json:"subject_count"`
	FeeItemCount   int      `json:"fee_item_count"`
	Warnings       []string `json:"warnings"`
}

type principalClassCsvImportResponse struct {
	CanImport bool                                `json:"can_import"`
	Imported  bool                                `json:"imported"`
	Summary   gin.H                               `json:"summary"`
	Rows      []principalClassCsvImportPreviewRow `json:"rows"`
	Errors    []principalClassCsvImportIssue      `json:"errors"`
	Warnings  []principalClassCsvImportIssue      `json:"warnings"`
	Entities  gin.H                               `json:"entities"`
}

type principalClassCsvImportPlan struct {
	Preview principalClassCsvImportPreviewRow
	Request principalClassSetupRequest
}

type classImportStaffRef struct {
	ID        string
	StaffCode string
	Email     string
}

type classCsvRow struct {
	headers []string
	values  []string
	aliases map[string][]string
}

var principalClassCsvAliases = map[string][]string{
	"grade_id":                    {"grade_id"},
	"grade_name":                  {"grade_name", "class", "class_name", "grade"},
	"grade_number":                {"grade_number", "class_number"},
	"section_name":                {"section_name", "section"},
	"capacity":                    {"capacity"},
	"academic_year_id":            {"academic_year_id", "year_id"},
	"year_label":                  {"year_label", "academic_year", "year"},
	"class_teacher_id":            {"class_teacher_id"},
	"class_teacher_staff_code":    {"class_teacher_staff_code", "teacher_code"},
	"class_teacher_email":         {"class_teacher_email", "teacher_email"},
	"room_id":                     {"room_id"},
	"room_number":                 {"room_number", "room_name", "classroom", "class_room"},
	"room_type":                   {"room_type", "classroom_type"},
	"room_capacity":               {"room_capacity", "classroom_capacity"},
	"subject_names":               {"subject_names", "subjects", "subject_name"},
	"subject_codes":               {"subject_codes", "subject_code"},
	"subject_types":               {"subject_types", "subject_type"},
	"subject_departments":         {"subject_departments", "department_names"},
	"subject_teacher_staff_codes": {"subject_teacher_staff_codes", "subject_teacher_codes", "teacher_staff_codes"},
	"subject_teacher_emails":      {"subject_teacher_emails", "teacher_emails"},
	"periods_per_week":            {"periods_per_week", "periods"},
	"max_marks":                   {"max_marks"},
	"pass_marks":                  {"pass_marks"},
	"fee_categories":              {"fee_categories", "fee_category_names", "fees"},
	"fee_amounts":                 {"fee_amounts", "amounts"},
	"fee_frequencies":             {"fee_frequencies", "fee_frequency"},
	"fee_due_days":                {"fee_due_days", "due_days"},
	"fee_late_fines":              {"fee_late_fines", "late_fines"},
}

func (h *PrincipalClassesHandler) DryRunClassCsvImport(c *gin.Context) {
	h.handleClassCsvImport(c, false)
}

func (h *PrincipalClassesHandler) ImportClassCsv(c *gin.Context) {
	h.handleClassCsvImport(c, true)
}

func (h *PrincipalClassesHandler) handleClassCsvImport(c *gin.Context, commit bool) {
	schoolID := scopedSchoolID(c)
	var req principalClassCsvImportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	csvText := strings.TrimSpace(firstNonEmpty(req.CSVText, req.Content))
	if csvText == "" {
		fail(c, http.StatusBadRequest, "csv_text is required")
		return
	}

	response, plans := h.classCsvImportPlan(database.DB, schoolID, csvText)
	if !commit {
		success(c, http.StatusOK, response, "Class Hub CSV dry-run completed")
		return
	}
	if !response.CanImport {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Code:    "CSV_IMPORT_VALIDATION_FAILED",
			Message: "Class Hub CSV failed validation",
			Error: models.APIError{
				Code:    "CSV_IMPORT_VALIDATION_FAILED",
				Details: response.Errors,
			},
			Data:      response,
			RequestID: c.GetString("request_id"),
		})
		return
	}

	created := 0
	updated := 0
	affectedSections := make([]string, 0, len(plans))
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		for _, plan := range plans {
			sectionID, mode, err := h.applyClassCsvImportPlan(tx, schoolID, plan)
			if err != nil {
				return fmt.Errorf("row %d: %w", plan.Preview.RowNumber, err)
			}
			affectedSections = append(affectedSections, sectionID)
			if mode == "update" {
				updated++
			} else {
				created++
			}
		}
		return nil
	}); err != nil {
		response.CanImport = false
		response.Errors = append(response.Errors, principalClassCsvImportIssue{
			Row:     0,
			Field:   "transaction",
			Message: err.Error(),
		})
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Code:    "CSV_IMPORT_TRANSACTION_FAILED",
			Message: "Class Hub CSV import failed and no rows were committed",
			Error: models.APIError{
				Code:    "CSV_IMPORT_TRANSACTION_FAILED",
				Details: response.Errors,
			},
			Data:      response,
			RequestID: c.GetString("request_id"),
		})
		return
	}

	response.Imported = true
	response.Summary["created_classes"] = created
	response.Summary["updated_classes"] = updated
	response.Summary["affected_section_ids"] = affectedSections
	auditAction(c, "principal/classes", "bulk-import", "sections", nil)
	success(c, http.StatusOK, response, "Class Hub CSV imported successfully")
}

func (h *PrincipalClassesHandler) classCsvImportPlan(db *gorm.DB, schoolID, csvText string) (principalClassCsvImportResponse, []principalClassCsvImportPlan) {
	response := principalClassCsvImportResponse{
		CanImport: false,
		Summary: gin.H{
			"total_rows":        0,
			"valid_rows":        0,
			"invalid_rows":      0,
			"classes_to_create": 0,
			"classes_to_update": 0,
			"subject_mappings":  0,
			"fee_items":         0,
			"duplicate_rows":    0,
		},
		Rows:     []principalClassCsvImportPreviewRow{},
		Errors:   []principalClassCsvImportIssue{},
		Warnings: []principalClassCsvImportIssue{},
		Entities: gin.H{
			"classes": []gin.H{},
		},
	}

	records, err := readPrincipalClassCsv(csvText)
	if err != nil {
		response.Errors = append(response.Errors, principalClassCsvImportIssue{Row: 0, Field: "csv_text", Message: err.Error()})
		response.Summary["invalid_rows"] = 1
		return response, nil
	}
	if len(records) < 2 {
		response.Errors = append(response.Errors, principalClassCsvImportIssue{Row: 0, Field: "csv_text", Message: "CSV must include headers and at least one data row"})
		response.Summary["invalid_rows"] = 1
		return response, nil
	}

	headers := make([]string, 0, len(records[0]))
	for _, header := range records[0] {
		headers = append(headers, normalizePrincipalClassCsvHeader(header))
	}
	for _, required := range []string{"grade_name", "section_name"} {
		if !classCsvHeadersContain(headers, required) {
			response.Errors = append(response.Errors, principalClassCsvImportIssue{
				Row:     1,
				Field:   required,
				Message: required + " header is required",
			})
		}
	}
	if len(response.Errors) > 0 {
		response.Summary["invalid_rows"] = len(records) - 1
		response.Summary["total_rows"] = len(records) - 1
		return response, nil
	}

	seenKeys := map[string]int{}
	plans := make([]principalClassCsvImportPlan, 0, len(records)-1)
	invalidRows := map[int]bool{}
	for index := 1; index < len(records); index++ {
		rowNumber := index + 1
		values := records[index]
		if classCsvRowEmpty(values) {
			continue
		}
		response.Summary["total_rows"] = response.Summary["total_rows"].(int) + 1
		row := classCsvRow{headers: headers, values: values, aliases: principalClassCsvAliases}
		plan, rowIssues, rowWarnings := h.planClassCsvRow(db, schoolID, rowNumber, row)
		key := strings.ToLower(strings.TrimSpace(plan.Request.AcademicYearID)) + "|" + strings.ToLower(strings.TrimSpace(plan.Request.GradeName)) + "|" + strings.ToLower(strings.TrimSpace(plan.Request.SectionName))
		if key != "||" {
			if firstRow, exists := seenKeys[key]; exists {
				rowIssues = append(rowIssues, principalClassCsvImportIssue{
					Row:     rowNumber,
					Field:   "section_name",
					Message: fmt.Sprintf("duplicate class setup row in this CSV; row %d already defines this grade, section, and academic year", firstRow),
				})
				response.Summary["duplicate_rows"] = response.Summary["duplicate_rows"].(int) + 1
			} else {
				seenKeys[key] = rowNumber
			}
		}
		if len(rowIssues) > 0 {
			invalidRows[rowNumber] = true
			plan.Preview.Mode = "invalid"
		} else {
			plans = append(plans, plan)
			if plan.Preview.Mode == "update" {
				response.Summary["classes_to_update"] = response.Summary["classes_to_update"].(int) + 1
			} else {
				response.Summary["classes_to_create"] = response.Summary["classes_to_create"].(int) + 1
			}
			response.Summary["subject_mappings"] = response.Summary["subject_mappings"].(int) + plan.Preview.SubjectCount
			response.Summary["fee_items"] = response.Summary["fee_items"].(int) + plan.Preview.FeeItemCount
		}
		response.Rows = append(response.Rows, plan.Preview)
		response.Errors = append(response.Errors, rowIssues...)
		response.Warnings = append(response.Warnings, rowWarnings...)
		response.Entities["classes"] = append(response.Entities["classes"].([]gin.H), gin.H{
			"row":              rowNumber,
			"mode":             plan.Preview.Mode,
			"grade_name":       plan.Preview.GradeName,
			"section_name":     plan.Preview.SectionName,
			"academic_year_id": plan.Preview.AcademicYearID,
			"room_number":      plan.Preview.RoomNumber,
			"subject_count":    plan.Preview.SubjectCount,
			"fee_item_count":   plan.Preview.FeeItemCount,
		})
	}
	response.Summary["valid_rows"] = len(plans)
	response.Summary["invalid_rows"] = len(invalidRows)
	response.CanImport = len(response.Errors) == 0 && len(plans) > 0
	return response, plans
}

func (h *PrincipalClassesHandler) planClassCsvRow(db *gorm.DB, schoolID string, rowNumber int, row classCsvRow) (principalClassCsvImportPlan, []principalClassCsvImportIssue, []principalClassCsvImportIssue) {
	issues := []principalClassCsvImportIssue{}
	warnings := []principalClassCsvImportIssue{}
	gradeName := row.required("grade_name", &issues, rowNumber)
	sectionName := row.required("section_name", &issues, rowNumber)
	gradeNumber, err := parseClassImportInt(row.value("grade_number"), gradeNumberFromClassCsvName(gradeName), 1, "grade_number")
	if err != nil {
		issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: "grade_number", Message: err.Error()})
	}
	capacity, err := parseClassImportInt(row.value("capacity"), 40, 1, "capacity")
	if err != nil {
		issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: "capacity", Message: err.Error()})
	}
	academicYearID, yearLabel, err := resolveClassImportAcademicYear(db, schoolID, row.value("academic_year_id"), row.value("year_label"))
	if err != nil {
		issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: "academic_year_id", Message: err.Error()})
	}
	classTeacherID, classTeacherRef, classTeacherWillCreate, err := planClassImportStaff(db, schoolID, row.value("class_teacher_id"), row.value("class_teacher_staff_code"), row.value("class_teacher_email"))
	if err != nil {
		issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: "class_teacher", Message: err.Error()})
	}
	if classTeacherWillCreate {
		warnings = append(warnings, principalClassCsvImportIssue{Row: rowNumber, Field: "class_teacher", Message: "missing class teacher " + classTeacherRef.label() + " will be created as active staff"})
	}
	roomID, roomNumber, roomType, roomCapacity, roomIssues, roomWarnings := classImportRoomFields(db, schoolID, rowNumber, row, capacity)
	issues = append(issues, roomIssues...)
	warnings = append(warnings, roomWarnings...)

	subjectMappings, subjectIssues, subjectWarnings := h.classImportSubjectMappings(db, schoolID, rowNumber, row)
	issues = append(issues, subjectIssues...)
	warnings = append(warnings, subjectWarnings...)
	feeItems, feeIssues := classImportFeeItems(rowNumber, row)
	issues = append(issues, feeIssues...)

	mode := "create"
	if academicYearID != "" && strings.TrimSpace(gradeName) != "" && strings.TrimSpace(sectionName) != "" {
		existing, err := classImportExistingSection(db, schoolID, row.value("grade_id"), gradeName, academicYearID, sectionName)
		if err != nil {
			issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: "section_name", Message: err.Error()})
		} else if existing.ID != "" {
			mode = "update"
			warning := "existing class section will be updated instead of duplicated"
			warnings = append(warnings, principalClassCsvImportIssue{Row: rowNumber, Field: "section_name", Message: warning})
		}
	}

	previewWarnings := make([]string, 0, len(warnings))
	for _, warning := range warnings {
		previewWarnings = append(previewWarnings, warning.Message)
	}
	plan := principalClassCsvImportPlan{
		Preview: principalClassCsvImportPreviewRow{
			RowNumber:      rowNumber,
			Mode:           mode,
			GradeName:      gradeName,
			GradeNumber:    gradeNumber,
			SectionName:    sectionName,
			AcademicYearID: academicYearID,
			YearLabel:      yearLabel,
			ClassTeacherID: classTeacherID,
			RoomNumber:     roomNumber,
			SubjectCount:   len(subjectMappings),
			FeeItemCount:   len(feeItems),
			Warnings:       previewWarnings,
		},
		Request: principalClassSetupRequest{
			GradeID:         row.value("grade_id"),
			GradeName:       gradeName,
			GradeNumber:     gradeNumber,
			AcademicYearID:  academicYearID,
			SectionName:     sectionName,
			Capacity:        capacity,
			ClassTeacherID:  classTeacherID,
			ClassTeacherRef: classTeacherRef,
			RoomID:          optionalStringPointer(roomID),
			RoomNumber:      optionalStringPointer(roomNumber),
			RoomType:        roomType,
			RoomCapacity:    roomCapacity,
			FeeItems:        feeItems,
			SubjectMappings: subjectMappings,
		},
	}
	return plan, issues, warnings
}

func (h *PrincipalClassesHandler) classImportSubjectMappings(db *gorm.DB, schoolID string, rowNumber int, row classCsvRow) ([]principalClassSubjectMapping, []principalClassCsvImportIssue, []principalClassCsvImportIssue) {
	names := splitClassCsvList(row.value("subject_names"))
	codes := splitClassCsvList(row.value("subject_codes"))
	types := splitClassCsvList(row.value("subject_types"))
	departments := splitClassCsvList(row.value("subject_departments"))
	teacherCodes := splitClassCsvList(row.value("subject_teacher_staff_codes"))
	teacherEmails := splitClassCsvList(row.value("subject_teacher_emails"))
	periods := splitClassCsvList(row.value("periods_per_week"))
	maxMarks := splitClassCsvList(row.value("max_marks"))
	passMarks := splitClassCsvList(row.value("pass_marks"))

	mappings := make([]principalClassSubjectMapping, 0, len(names))
	issues := []principalClassCsvImportIssue{}
	warnings := []principalClassCsvImportIssue{}
	for index, name := range names {
		subjectName := strings.TrimSpace(name)
		if subjectName == "" {
			continue
		}
		teacherID, teacherRef, teacherWillCreate, err := planClassImportStaff(db, schoolID, "", classCsvListAt(teacherCodes, index), classCsvListAt(teacherEmails, index))
		if err != nil {
			issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: fmt.Sprintf("subject_teacher_%d", index+1), Message: err.Error()})
		}
		if teacherWillCreate {
			warnings = append(warnings, principalClassCsvImportIssue{Row: rowNumber, Field: fmt.Sprintf("subject_teacher_%d", index+1), Message: "missing subject teacher " + teacherRef.label() + " will be created as active staff"})
		}
		periodValue, err := parseClassImportInt(classCsvListAt(periods, index), 5, 0, "periods_per_week")
		if err != nil {
			issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: fmt.Sprintf("periods_per_week_%d", index+1), Message: err.Error()})
		}
		maxValue, err := parseClassImportInt(classCsvListAt(maxMarks, index), 100, 1, "max_marks")
		if err != nil {
			issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: fmt.Sprintf("max_marks_%d", index+1), Message: err.Error()})
		}
		passValue, err := parseClassImportInt(classCsvListAt(passMarks, index), 35, 0, "pass_marks")
		if err != nil {
			issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: fmt.Sprintf("pass_marks_%d", index+1), Message: err.Error()})
		}
		if passValue > maxValue {
			issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: fmt.Sprintf("pass_marks_%d", index+1), Message: "pass_marks cannot exceed max_marks"})
		}
		mappings = append(mappings, principalClassSubjectMapping{
			SubjectName:    subjectName,
			SubjectCode:    classCsvListAt(codes, index),
			SubjectType:    firstNonEmpty(classCsvListAt(types, index), "core"),
			DepartmentName: firstNonEmpty(classCsvListAt(departments, index), "Academics"),
			TeacherID:      teacherID,
			TeacherRef:     teacherRef,
			PeriodsPerWeek: periodValue,
			MaxMarks:       maxValue,
			PassMarks:      passValue,
			IsMandatory:    boolPointer(true),
			IsPrimary:      boolPointer(true),
		})
	}
	return mappings, issues, warnings
}

func classImportFeeItems(rowNumber int, row classCsvRow) ([]principalClassFeeItem, []principalClassCsvImportIssue) {
	categories := splitClassCsvList(row.value("fee_categories"))
	amounts := splitClassCsvList(row.value("fee_amounts"))
	frequencies := splitClassCsvList(row.value("fee_frequencies"))
	dueDays := splitClassCsvList(row.value("fee_due_days"))
	lateFines := splitClassCsvList(row.value("fee_late_fines"))

	items := make([]principalClassFeeItem, 0, len(categories))
	issues := []principalClassCsvImportIssue{}
	for index, category := range categories {
		name := strings.TrimSpace(category)
		if name == "" {
			continue
		}
		amount, err := parseClassImportFloat(classCsvListAt(amounts, index), -1, 0, "fee_amounts")
		if err != nil || amount < 0 {
			issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: fmt.Sprintf("fee_amounts_%d", index+1), Message: "fee amount is required and cannot be negative"})
		}
		dueDay, err := parseClassImportInt(classCsvListAt(dueDays, index), 10, 1, "fee_due_days")
		if err != nil || dueDay > 31 {
			issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: fmt.Sprintf("fee_due_days_%d", index+1), Message: "fee due day must be between 1 and 31"})
		}
		lateFine, err := parseClassImportFloat(classCsvListAt(lateFines, index), 0, 0, "fee_late_fines")
		if err != nil {
			issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: fmt.Sprintf("fee_late_fines_%d", index+1), Message: err.Error()})
		}
		items = append(items, principalClassFeeItem{
			CategoryName:   name,
			Frequency:      strings.ToLower(firstNonEmpty(classCsvListAt(frequencies, index), "term")),
			Amount:         amount,
			DueDay:         dueDay,
			LateFinePerDay: lateFine,
		})
	}
	return items, issues
}

func classImportRoomFields(db *gorm.DB, schoolID string, rowNumber int, row classCsvRow, classCapacity int) (string, string, string, int, []principalClassCsvImportIssue, []principalClassCsvImportIssue) {
	issues := []principalClassCsvImportIssue{}
	warnings := []principalClassCsvImportIssue{}
	roomID := strings.TrimSpace(row.value("room_id"))
	roomNumber := strings.TrimSpace(row.value("room_number"))
	roomType := strings.TrimSpace(row.value("room_type"))
	if roomType == "" && roomNumber != "" {
		roomType = "classroom"
	}
	roomCapacity := classCapacity
	if value := strings.TrimSpace(row.value("room_capacity")); value != "" {
		parsed, err := parseClassImportInt(value, classCapacity, 1, "room_capacity")
		if err != nil {
			issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: "room_capacity", Message: err.Error()})
		} else {
			roomCapacity = parsed
		}
	}
	if roomID != "" {
		var room models.Room
		if err := db.First(&room, "id = ? AND school_id = ?", roomID, schoolID).Error; err != nil {
			issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: "room_id", Message: "room must belong to this school"})
		} else if roomNumber == "" {
			roomNumber = room.RoomNumber
		}
	}
	if roomID == "" && roomNumber != "" {
		var room models.Room
		err := db.Where("school_id = ? AND LOWER(room_number) = ?", schoolID, strings.ToLower(roomNumber)).First(&room).Error
		if err == nil {
			roomID = room.ID
			roomNumber = room.RoomNumber
		} else if errors.Is(err, gorm.ErrRecordNotFound) {
			warnings = append(warnings, principalClassCsvImportIssue{Row: rowNumber, Field: "room_number", Message: "room " + roomNumber + " will be created if missing"})
		} else {
			issues = append(issues, principalClassCsvImportIssue{Row: rowNumber, Field: "room_number", Message: err.Error()})
		}
	}
	return roomID, roomNumber, roomType, roomCapacity, issues, warnings
}

func (h *PrincipalClassesHandler) applyClassCsvImportPlan(tx *gorm.DB, schoolID string, plan principalClassCsvImportPlan) (string, string, error) {
	req := plan.Request
	grade, err := h.resolveClassGrade(tx, schoolID, req.GradeID, req.GradeName, req.GradeNumber)
	if err != nil {
		return "", "", err
	}
	classTeacherIDValue := strings.TrimSpace(req.ClassTeacherID)
	if classTeacherIDValue == "" {
		ensuredID, err := ensureClassImportStaff(tx, schoolID, req.ClassTeacherRef)
		if err != nil {
			return "", "", fmt.Errorf("class teacher: %w", err)
		}
		classTeacherIDValue = ensuredID
		req.ClassTeacherID = ensuredID
	} else {
		var staff models.Staff
		if err := tx.First(&staff, "id = ? AND school_id = ? AND status = ?", classTeacherIDValue, schoolID, "active").Error; err != nil {
			return "", "", errors.New("class teacher must be active staff in this school")
		}
	}
	for index := range req.SubjectMappings {
		if strings.TrimSpace(req.SubjectMappings[index].TeacherID) != "" {
			continue
		}
		ensuredID, err := ensureClassImportStaff(tx, schoolID, req.SubjectMappings[index].TeacherRef)
		if err != nil {
			return "", "", fmt.Errorf("subject teacher %d: %w", index+1, err)
		}
		req.SubjectMappings[index].TeacherID = ensuredID
	}
	var classTeacherID *string
	if classTeacherIDValue != "" {
		classTeacherID = &classTeacherIDValue
	}
	var section models.Section
	mode := "create"
	err = tx.
		Where("grade_id = ? AND academic_year_id = ? AND LOWER(section_name) = ?", grade.ID, req.AcademicYearID, strings.ToLower(req.SectionName)).
		First(&section).Error
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return "", "", err
	}
	roomID, err := resolvePrincipalClassRoom(tx, schoolID, req, req.Capacity, section.RoomID)
	if err != nil {
		return "", "", err
	}
	if section.ID != "" {
		mode = "update"
		section.SchoolID = schoolID
		section.GradeID = grade.ID
		section.AcademicYearID = req.AcademicYearID
		section.SectionName = req.SectionName
		section.Capacity = req.Capacity
		section.ClassTeacherID = classTeacherID
		section.RoomID = roomID
		if err := tx.Save(&section).Error; err != nil {
			return "", "", err
		}
	} else {
		section = models.Section{
			SchoolID:       schoolID,
			GradeID:        grade.ID,
			AcademicYearID: req.AcademicYearID,
			SectionName:    req.SectionName,
			Capacity:       req.Capacity,
			ClassTeacherID: classTeacherID,
			RoomID:         roomID,
		}
		if err := tx.Create(&section).Error; err != nil {
			return "", "", err
		}
	}
	if err := h.applyClassSetupBundle(tx, schoolID, &section, req); err != nil {
		return "", "", err
	}
	return section.ID, mode, nil
}

func readPrincipalClassCsv(csvText string) ([][]string, error) {
	reader := csv.NewReader(strings.NewReader(csvText))
	reader.TrimLeadingSpace = true
	reader.FieldsPerRecord = -1
	records, err := reader.ReadAll()
	if err != nil && !errors.Is(err, io.EOF) {
		return nil, fmt.Errorf("invalid CSV: %w", err)
	}
	return records, nil
}

func classCsvHeadersContain(headers []string, key string) bool {
	for _, alias := range principalClassCsvAliases[key] {
		normalized := normalizePrincipalClassCsvHeader(alias)
		for _, header := range headers {
			if header == normalized {
				return true
			}
		}
	}
	return false
}

func (row classCsvRow) value(key string) string {
	aliases := row.aliases[key]
	if len(aliases) == 0 {
		aliases = []string{key}
	}
	for _, alias := range aliases {
		normalized := normalizePrincipalClassCsvHeader(alias)
		for index, header := range row.headers {
			if header != normalized || index >= len(row.values) {
				continue
			}
			return strings.TrimSpace(row.values[index])
		}
	}
	return ""
}

func (row classCsvRow) required(key string, issues *[]principalClassCsvImportIssue, rowNumber int) string {
	value := row.value(key)
	if strings.TrimSpace(value) == "" {
		*issues = append(*issues, principalClassCsvImportIssue{Row: rowNumber, Field: key, Message: key + " is required"})
	}
	return value
}

func optionalStringPointer(value string) *string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}

func normalizePrincipalClassCsvHeader(value string) string {
	var builder strings.Builder
	lastUnderscore := false
	for _, r := range strings.ToLower(strings.TrimSpace(value)) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			builder.WriteRune(r)
			lastUnderscore = false
			continue
		}
		if !lastUnderscore {
			builder.WriteByte('_')
			lastUnderscore = true
		}
	}
	return strings.Trim(builder.String(), "_")
}

func classCsvRowEmpty(values []string) bool {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return false
		}
	}
	return true
}

func resolveClassImportAcademicYear(db *gorm.DB, schoolID, academicYearID, yearLabel string) (string, string, error) {
	id := strings.TrimSpace(academicYearID)
	label := strings.TrimSpace(yearLabel)
	var year models.AcademicYear
	if id != "" {
		if err := db.First(&year, "id = ? AND school_id = ?", id, schoolID).Error; err != nil {
			return "", "", errors.New("academic year must belong to this school")
		}
		return year.ID, year.YearLabel, nil
	}
	query := db.Where("school_id = ?", schoolID)
	if label != "" {
		err := query.Where("LOWER(year_label) = ? OR LOWER(year) = ?", strings.ToLower(label), strings.ToLower(label)).First(&year).Error
		if err != nil {
			return "", "", errors.New("year_label must match an academic year in this school")
		}
		return year.ID, year.YearLabel, nil
	}
	if err := query.Where("is_current = ?", true).Order("created_at DESC").First(&year).Error; err != nil {
		return "", "", errors.New("academic_year_id or year_label is required because no current academic year was found")
	}
	return year.ID, year.YearLabel, nil
}

func (ref classImportStaffRef) label() string {
	if strings.TrimSpace(ref.StaffCode) != "" {
		return strings.TrimSpace(ref.StaffCode)
	}
	if strings.TrimSpace(ref.Email) != "" {
		return strings.TrimSpace(ref.Email)
	}
	if strings.TrimSpace(ref.ID) != "" {
		return strings.TrimSpace(ref.ID)
	}
	return "teacher"
}

func planClassImportStaff(db *gorm.DB, schoolID, id, staffCode, email string) (string, classImportStaffRef, bool, error) {
	ref := classImportStaffRef{
		ID:        strings.TrimSpace(id),
		StaffCode: strings.TrimSpace(staffCode),
		Email:     strings.TrimSpace(email),
	}
	if ref.ID == "" && ref.StaffCode == "" && ref.Email == "" {
		return "", ref, false, nil
	}
	var staff models.Staff
	if ref.ID != "" {
		if err := db.First(&staff, "id = ? AND school_id = ? AND status = ?", ref.ID, schoolID, "active").Error; err != nil {
			return "", ref, false, errors.New("teacher must reference active staff in this school")
		}
		return staff.ID, ref, false, nil
	}
	if ref.StaffCode != "" {
		err := db.Where("school_id = ? AND LOWER(staff_code) = ?", schoolID, strings.ToLower(ref.StaffCode)).First(&staff).Error
		if err == nil {
			if strings.EqualFold(strings.TrimSpace(staff.Status), "active") {
				return staff.ID, ref, false, nil
			}
			return "", ref, false, fmt.Errorf("teacher %s exists but is %s; restore it before importing", ref.label(), firstNonEmpty(strings.TrimSpace(staff.Status), "inactive"))
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return "", ref, false, err
		}
		if ref.Email != "" {
			emailID, emailErr := activeClassImportStaffByEmail(db, schoolID, ref.Email)
			if emailErr != nil {
				return "", ref, false, emailErr
			}
			if emailID != "" {
				return "", ref, false, fmt.Errorf("teacher email %s already belongs to active staff; use the existing staff code or remove the email", ref.Email)
			}
		}
		return "", ref, true, nil
	}
	if ref.Email != "" {
		emailID, err := activeClassImportStaffByEmail(db, schoolID, ref.Email)
		if err != nil {
			return "", ref, false, err
		}
		if emailID != "" {
			return emailID, ref, false, nil
		}
		return "", ref, false, errors.New("teacher email must reference active staff in this school or include a staff code to create a teacher")
	}
	return "", ref, false, nil
}

func activeClassImportStaffByEmail(db *gorm.DB, schoolID, email string) (string, error) {
	email = strings.TrimSpace(email)
	if email == "" {
		return "", nil
	}
	var staff models.Staff
	err := db.Where("school_id = ? AND LOWER(email) = ?", schoolID, strings.ToLower(email)).First(&staff).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	if strings.EqualFold(strings.TrimSpace(staff.Status), "active") {
		return staff.ID, nil
	}
	return "", fmt.Errorf("teacher email %s belongs to %s staff; restore it before importing", email, firstNonEmpty(strings.TrimSpace(staff.Status), "inactive"))
}

func ensureClassImportStaff(tx *gorm.DB, schoolID string, ref classImportStaffRef) (string, error) {
	id, plannedRef, willCreate, err := planClassImportStaff(tx, schoolID, ref.ID, ref.StaffCode, ref.Email)
	if err != nil {
		return "", err
	}
	if id != "" || !willCreate {
		return id, nil
	}
	staffCode := strings.TrimSpace(plannedRef.StaffCode)
	if staffCode == "" {
		return "", errors.New("staff code is required to create a teacher")
	}
	if err := ensureStaffCodeAvailable(tx, schoolID, staffCode, ""); err != nil {
		return "", err
	}
	now := time.Now().UTC()
	staff := models.Staff{
		SchoolID:       schoolID,
		StaffCode:      staffCode,
		FirstName:      "Teacher",
		LastName:       staffCode,
		Email:          strings.TrimSpace(plannedRef.Email),
		DateOfBirth:    time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
		Gender:         "unspecified",
		Designation:    "Teacher",
		EmploymentType: "full_time",
		JoinDate:       now,
		Status:         "active",
	}
	if err := tx.Create(&staff).Error; err != nil {
		return "", fmt.Errorf("failed to create teacher %s: %w", staffCode, err)
	}
	return staff.ID, nil
}

func classImportExistingSection(db *gorm.DB, schoolID, gradeID, gradeName, academicYearID, sectionName string) (models.Section, error) {
	var grade models.Grade
	id := strings.TrimSpace(gradeID)
	if id != "" {
		if err := db.First(&grade, "id = ? AND school_id = ?", id, schoolID).Error; err != nil {
			return models.Section{}, errors.New("grade_id must belong to this school")
		}
	} else if err := db.Where("school_id = ? AND LOWER(grade_name) = ?", schoolID, strings.ToLower(strings.TrimSpace(gradeName))).First(&grade).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return models.Section{}, nil
		}
		return models.Section{}, err
	}
	var section models.Section
	err := db.
		Where("grade_id = ? AND academic_year_id = ? AND LOWER(section_name) = ?", grade.ID, academicYearID, strings.ToLower(strings.TrimSpace(sectionName))).
		First(&section).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return models.Section{}, nil
	}
	return section, err
}

func parseClassImportInt(value string, fallback, min int, field string) (int, error) {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return fallback, nil
	}
	parsed, err := strconv.Atoi(trimmed)
	if err != nil {
		return fallback, fmt.Errorf("%s must be a number", field)
	}
	if parsed < min {
		return parsed, fmt.Errorf("%s must be at least %d", field, min)
	}
	return parsed, nil
}

func parseClassImportFloat(value string, fallback, min float64, field string) (float64, error) {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return fallback, nil
	}
	parsed, err := strconv.ParseFloat(trimmed, 64)
	if err != nil {
		return fallback, fmt.Errorf("%s must be a number", field)
	}
	if parsed < min {
		return parsed, fmt.Errorf("%s must be at least %.0f", field, min)
	}
	return parsed, nil
}

func splitClassCsvList(value string) []string {
	parts := strings.FieldsFunc(value, func(r rune) bool {
		return r == ';' || r == '|'
	})
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}

func classCsvListAt(values []string, index int) string {
	if index < 0 || index >= len(values) {
		return ""
	}
	return strings.TrimSpace(values[index])
}

func gradeNumberFromClassCsvName(value string) int {
	for _, part := range strings.FieldsFunc(value, func(r rune) bool { return r < '0' || r > '9' }) {
		if parsed, err := strconv.Atoi(part); err == nil && parsed > 0 {
			return parsed
		}
	}
	return 1
}

func boolPointer(value bool) *bool {
	return &value
}

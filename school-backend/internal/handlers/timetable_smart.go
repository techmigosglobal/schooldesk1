package handlers

import (
	"archive/zip"
	"bytes"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
)

func (h *TimetableHandler) GetTimetableTemplates(c *gin.Context) {
	var rows []models.TimetableTemplate
	query := database.DB.Where("school_id = ?", scopedSchoolID(c)).Order("is_default DESC, created_at DESC")
	if yearID := strings.TrimSpace(c.Query("academic_year_id")); yearID != "" {
		query = query.Where("academic_year_id = '' OR academic_year_id = ?", yearID)
	}
	if err := query.Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load timetable templates")
		return
	}
	success(c, http.StatusOK, rows, "")
}

func (h *TimetableHandler) SaveTimetableTemplate(c *gin.Context) {
	var req struct {
		ID                    string                   `json:"id"`
		AcademicYearID        string                   `json:"academic_year_id"`
		Name                  string                   `json:"name"`
		WorkingDays           []int                    `json:"working_days"`
		PeriodsPerDay         int                      `json:"periods_per_day"`
		PeriodDurationMinutes int                      `json:"period_duration_minutes"`
		GapMinutes            int                      `json:"gap_minutes"`
		StartTime             string                   `json:"start_time"`
		EndTime               string                   `json:"end_time"`
		Breaks                []map[string]interface{} `json:"breaks"`
		IsDefault             bool                     `json:"is_default"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	if req.Name == "" {
		req.Name = "Default smart timetable"
	}
	if req.PeriodsPerDay <= 0 {
		req.PeriodsPerDay = 8
	}
	if req.PeriodDurationMinutes <= 0 {
		req.PeriodDurationMinutes = 40
	}
	if req.GapMinutes <= 0 {
		req.GapMinutes = 5
	}
	if req.StartTime == "" {
		req.StartTime = "09:00"
	}
	if len(req.WorkingDays) == 0 {
		req.WorkingDays = []int{1, 2, 3, 4, 5, 6}
	}
	days, _ := json.Marshal(req.WorkingDays)
	breaks, _ := json.Marshal(req.Breaks)
	row := models.TimetableTemplate{}
	if strings.TrimSpace(req.ID) != "" {
		if err := database.DB.First(&row, "id = ? AND school_id = ?", req.ID, scopedSchoolID(c)).Error; err != nil {
			fail(c, http.StatusNotFound, "Timetable template not found")
			return
		}
	} else {
		row.SchoolID = scopedSchoolID(c)
	}
	row.AcademicYearID = strings.TrimSpace(req.AcademicYearID)
	row.Name = strings.TrimSpace(req.Name)
	row.WorkingDays = string(days)
	row.PeriodsPerDay = req.PeriodsPerDay
	row.PeriodDurationMinutes = req.PeriodDurationMinutes
	row.GapMinutes = req.GapMinutes
	row.StartTime = strings.TrimSpace(req.StartTime)
	row.EndTime = strings.TrimSpace(req.EndTime)
	row.Breaks = string(breaks)
	row.IsDefault = req.IsDefault || row.ID == ""
	if row.IsDefault {
		database.DB.Model(&models.TimetableTemplate{}).Where("school_id = ?", scopedSchoolID(c)).Update("is_default", false)
	}
	if err := database.DB.Save(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save timetable template")
		return
	}
	id := row.ID
	auditAction(c, "timetable", "save_template", "timetable_templates", &id)
	success(c, http.StatusOK, row, "Timetable template saved")
}

func (h *TimetableHandler) GetTimetableConstraints(c *gin.Context) {
	var rows []models.TimetableConstraint
	query := database.DB.Where("school_id = ?", scopedSchoolID(c)).Order("constraint_type, created_at DESC")
	if yearID := strings.TrimSpace(c.Query("academic_year_id")); yearID != "" {
		query = query.Where("academic_year_id = '' OR academic_year_id = ?", yearID)
	}
	if err := query.Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load timetable constraints")
		return
	}
	success(c, http.StatusOK, rows, "")
}

func (h *TimetableHandler) CreateTimetableConstraint(c *gin.Context) {
	h.saveTimetableConstraint(c, "")
}

func (h *TimetableHandler) UpdateTimetableConstraint(c *gin.Context) {
	h.saveTimetableConstraint(c, c.Param("id"))
}

func (h *TimetableHandler) DeleteTimetableConstraint(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	var row models.TimetableConstraint
	if err := database.DB.First(&row, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		fail(c, http.StatusNotFound, "Timetable constraint not found")
		return
	}
	if err := database.DB.Delete(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to delete timetable constraint")
		return
	}
	auditAction(c, "timetable", "delete_constraint", "timetable_constraints", &id)
	success(c, http.StatusOK, gin.H{"id": id}, "Timetable constraint deleted")
}

func (h *TimetableHandler) saveTimetableConstraint(c *gin.Context, id string) {
	payload := map[string]interface{}{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	constraintType := strings.TrimSpace(fmt.Sprint(payload["constraint_type"]))
	if constraintType == "" {
		fail(c, http.StatusBadRequest, "constraint_type is required")
		return
	}
	row := models.TimetableConstraint{}
	if id != "" {
		if err := database.DB.First(&row, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
			fail(c, http.StatusNotFound, "Timetable constraint not found")
			return
		}
	} else {
		row.SchoolID = scopedSchoolID(c)
	}
	row.AcademicYearID = textMapValue(payload, "academic_year_id")
	row.SectionID = timetableOptionalString(textMapValue(payload, "section_id"))
	row.StaffID = timetableOptionalString(textMapValue(payload, "staff_id"))
	row.SubjectID = timetableOptionalString(textMapValue(payload, "subject_id"))
	row.RoomID = timetableOptionalString(textMapValue(payload, "room_id"))
	row.ConstraintType = constraintType
	row.Priority = firstNonEmpty(textMapValue(payload, "priority"), "normal")
	row.Weight = int(int64FromAny(payload["weight"]))
	row.IsActive = payload["is_active"] != false
	rawPayload := payload
	if nested, ok := payload["payload"].(map[string]interface{}); ok {
		rawPayload = nested
	}
	encoded, _ := json.Marshal(rawPayload)
	row.Payload = string(encoded)
	if err := database.DB.Save(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save timetable constraint")
		return
	}
	rowID := row.ID
	auditAction(c, "timetable", "save_constraint", "timetable_constraints", &rowID)
	success(c, http.StatusOK, row, "Timetable constraint saved")
}

func (h *TimetableHandler) SmartTimetablePreview(c *gin.Context) {
	var req services.SmartTimetableRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	plan, err := services.NewSmartTimetableEngine(database.DB).Preview(c.Request.Context(), scopedSchoolID(c), req)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	success(c, http.StatusOK, plan, "Smart timetable preview ready")
}

func (h *TimetableHandler) SmartTimetableGenerate(c *gin.Context) {
	var req services.SmartTimetableRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	result, err := services.NewSmartTimetableEngine(database.DB).Generate(c.Request.Context(), scopedSchoolID(c), currentUserID(c), currentRole(c), req)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	id := result.JobID
	auditAction(c, "timetable", "smart_generate", "timetable_generation_jobs", &id)
	success(c, http.StatusCreated, result, "Smart timetable generated")
}

func (h *TimetableHandler) GetSmartTimetableJob(c *gin.Context) {
	var job models.TimetableGenerationJob
	if err := database.DB.Preload("Logs").First(&job, "id = ? AND school_id = ?", c.Param("id"), scopedSchoolID(c)).Error; err != nil {
		fail(c, http.StatusNotFound, "Smart timetable job not found")
		return
	}
	success(c, http.StatusOK, job, "")
}

func (h *TimetableHandler) SmartTimetableValidate(c *gin.Context) {
	var req struct {
		Slots []services.SmartTimetableSlotInput `json:"slots"`
		Slot  services.SmartTimetableSlotInput   `json:"slot"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	slots := req.Slots
	if len(slots) == 0 && strings.TrimSpace(req.Slot.SectionID) != "" {
		slots = []services.SmartTimetableSlotInput{req.Slot}
	}
	if len(slots) == 0 {
		fail(c, http.StatusBadRequest, "slots are required")
		return
	}
	conflicts, logs, err := services.NewSmartTimetableEngine(database.DB).ValidateSlots(c.Request.Context(), scopedSchoolID(c), slots)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	success(c, http.StatusOK, gin.H{"valid": len(conflicts) == 0, "conflicts": conflicts, "logs": logs}, "")
}

func (h *TimetableHandler) SwapTimetableSlots(c *gin.Context) {
	var req struct {
		SlotAID string `json:"slot_a_id" binding:"required"`
		SlotBID string `json:"slot_b_id" binding:"required"`
		Reason  string `json:"reason"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	var a, b models.TimetableSlot
	if err := scopedTimetableSlotQuery(c).First(&a, "timetable_slots.id = ?", req.SlotAID).Error; err != nil {
		fail(c, http.StatusNotFound, "First timetable slot not found")
		return
	}
	if err := scopedTimetableSlotQuery(c).First(&b, "timetable_slots.id = ?", req.SlotBID).Error; err != nil {
		fail(c, http.StatusNotFound, "Second timetable slot not found")
		return
	}
	inputs := []services.SmartTimetableSlotInput{
		slotInputAfterMove(a, b.DayOfWeek, b.PeriodNumber, b.StartTime, b.EndTime),
		slotInputAfterMove(b, a.DayOfWeek, a.PeriodNumber, a.StartTime, a.EndTime),
	}
	conflicts, _, err := services.NewSmartTimetableEngine(database.DB).ValidateSlots(c.Request.Context(), scopedSchoolID(c), inputs)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	if len(conflicts) > 0 {
		success(c, http.StatusConflict, gin.H{"valid": false, "conflicts": conflicts}, "Swap has timetable conflicts")
		return
	}
	originalA := timetableSlotJSON(a)
	originalB := timetableSlotJSON(b)
	a.DayOfWeek, b.DayOfWeek = b.DayOfWeek, a.DayOfWeek
	a.PeriodNumber, b.PeriodNumber = b.PeriodNumber, a.PeriodNumber
	a.StartTime, b.StartTime = b.StartTime, a.StartTime
	a.EndTime, b.EndTime = b.EndTime, a.EndTime
	if err := database.DB.Save(&a).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save first swapped slot")
		return
	}
	if err := database.DB.Save(&b).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save second swapped slot")
		return
	}
	saveTimetableOverride(c, a.ID, "swap", originalA, timetableSlotJSON(a), req.Reason)
	saveTimetableOverride(c, b.ID, "swap", originalB, timetableSlotJSON(b), req.Reason)
	auditAction(c, "timetable", "swap_slots", "timetable_slots", &a.ID)
	success(c, http.StatusOK, gin.H{"slot_a": a, "slot_b": b}, "Timetable periods swapped")
}

func (h *TimetableHandler) OverrideTimetableSlot(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	var slot models.TimetableSlot
	if err := scopedTimetableSlotQuery(c).First(&slot, "timetable_slots.id = ?", id).Error; err != nil {
		fail(c, http.StatusNotFound, "Timetable slot not found")
		return
	}
	payload := map[string]interface{}{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	reason := strings.TrimSpace(fmt.Sprint(payload["reason"]))
	force := payload["force"] == true
	next := slotInputFromPayload(slot, payload)
	conflicts, _, err := services.NewSmartTimetableEngine(database.DB).ValidateSlots(c.Request.Context(), scopedSchoolID(c), []services.SmartTimetableSlotInput{next})
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	if len(conflicts) > 0 && (!force || reason == "") {
		success(c, http.StatusConflict, gin.H{"valid": false, "conflicts": conflicts, "requires_reason": true}, "Override has blocking conflicts")
		return
	}
	original := timetableSlotJSON(slot)
	if err := applySlotInput(&slot, next); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := database.DB.Save(&slot).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save timetable override")
		return
	}
	saveTimetableOverride(c, slot.ID, "manual_override", original, timetableSlotJSON(slot), reason)
	auditAction(c, "timetable", "override_slot", "timetable_slots", &slot.ID)
	success(c, http.StatusOK, gin.H{"slot": slot, "conflicts": conflicts}, "Timetable override saved")
}

func (h *TimetableHandler) CreateTimetableExport(c *gin.Context) {
	payload := map[string]interface{}{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	format := strings.ToLower(strings.TrimSpace(textMapValue(payload, "format")))
	if format == "" {
		format = "pdf"
	}
	if format != "pdf" && format != "csv" && format != "xlsx" {
		fail(c, http.StatusBadRequest, "format must be pdf, csv, or xlsx")
		return
	}
	title := firstNonEmpty(textMapValue(payload, "report_title"), textMapValue(payload, "title"), "Smart timetable export")
	slots := timetableExportSlots(c, payload)
	now := time.Now().UTC()
	params, _ := json.Marshal(payload)
	row := models.ReportExport{
		SchoolID: scopedSchoolID(c), Category: "timetable_reports", ReportTitle: title,
		ReportType: firstNonEmpty(textMapValue(payload, "report_type"), "timetable"),
		Format:     format, Scope: textMapValue(payload, "scope"), Parameters: string(params),
		Status: "processing", RequestedBy: currentUserID(c), RequestedRole: currentRole(c), RequestedAt: now,
	}
	if err := database.DB.Create(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create timetable export")
		return
	}
	artifactPath, downloadURL, err := writeTimetableArtifact(row, slots)
	completedAt := time.Now().UTC()
	row.CompletedAt = &completedAt
	if err != nil {
		row.Status = "failed"
		row.ErrorMessage = err.Error()
		_ = database.DB.Save(&row).Error
		fail(c, http.StatusInternalServerError, "Failed to write timetable export")
		return
	}
	row.Status = "completed"
	row.ArtifactPath = artifactPath
	row.DownloadURL = downloadURL
	if err := database.DB.Save(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update timetable export")
		return
	}
	auditAction(c, "timetable", "export", "report_exports", &row.ID)
	success(c, http.StatusCreated, row, "Timetable export generated")
}

func slotInputAfterMove(slot models.TimetableSlot, day, period int, start, end *time.Time) services.SmartTimetableSlotInput {
	roomID := ""
	if slot.RoomID != nil {
		roomID = *slot.RoomID
	}
	return services.SmartTimetableSlotInput{
		SlotID: slot.ID, SectionID: slot.SectionID, AcademicYearID: slot.AcademicYearID, TermID: slot.TermID,
		DayOfWeek: day, PeriodNumber: period, SubjectID: slot.SubjectID, StaffID: slot.StaffID, RoomID: roomID,
		StartTime: clockString(start), EndTime: clockString(end),
	}
}

func slotInputFromPayload(slot models.TimetableSlot, payload map[string]interface{}) services.SmartTimetableSlotInput {
	input := slotInputAfterMove(slot, slot.DayOfWeek, slot.PeriodNumber, slot.StartTime, slot.EndTime)
	if value := textMapValue(payload, "section_id"); value != "" {
		input.SectionID = value
	}
	if value := textMapValue(payload, "academic_year_id"); value != "" {
		input.AcademicYearID = value
	}
	if value := textMapValue(payload, "term_id"); value != "" {
		input.TermID = value
	}
	if value := textMapValue(payload, "subject_id"); value != "" {
		input.SubjectID = value
	}
	if value := textMapValue(payload, "staff_id"); value != "" {
		input.StaffID = value
	}
	if _, ok := payload["room_id"]; ok {
		input.RoomID = textMapValue(payload, "room_id")
	}
	if value := int64FromAny(payload["day_of_week"]); value > 0 {
		input.DayOfWeek = int(value)
	}
	if value := int64FromAny(payload["period_number"]); value > 0 {
		input.PeriodNumber = int(value)
	}
	if value := textMapValue(payload, "start_time"); value != "" {
		input.StartTime = value
	}
	if value := textMapValue(payload, "end_time"); value != "" {
		input.EndTime = value
	}
	return input
}

func applySlotInput(slot *models.TimetableSlot, input services.SmartTimetableSlotInput) error {
	start, err := timetableClockPointer(input.StartTime)
	if err != nil {
		return fmt.Errorf("start_time must be HH:MM")
	}
	end, err := timetableClockPointer(input.EndTime)
	if err != nil {
		return fmt.Errorf("end_time must be HH:MM")
	}
	slot.SectionID = input.SectionID
	slot.AcademicYearID = input.AcademicYearID
	slot.TermID = input.TermID
	slot.DayOfWeek = input.DayOfWeek
	slot.PeriodNumber = input.PeriodNumber
	slot.SubjectID = input.SubjectID
	slot.StaffID = input.StaffID
	slot.StartTime = start
	slot.EndTime = end
	if strings.TrimSpace(input.RoomID) == "" {
		slot.RoomID = nil
	} else {
		roomID := strings.TrimSpace(input.RoomID)
		slot.RoomID = &roomID
	}
	return nil
}

func saveTimetableOverride(c *gin.Context, slotID, overrideType, original, next, reason string) {
	_ = database.DB.Create(&models.TimetableOverride{
		SchoolID: scopedSchoolID(c), SlotID: slotID, OverrideType: overrideType,
		OriginalPayload: original, NewPayload: next, Reason: strings.TrimSpace(reason),
		CreatedBy: currentUserID(c), CreatedRole: currentRole(c),
	}).Error
}

func timetableSlotJSON(slot models.TimetableSlot) string {
	raw, _ := json.Marshal(slot)
	return string(raw)
}

func timetableExportSlots(c *gin.Context, payload map[string]interface{}) []models.TimetableSlot {
	query := database.DB.Model(&models.TimetableSlot{}).
		Joins("JOIN sections ON sections.id = timetable_slots.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ?", scopedSchoolID(c)).
		Preload("Section").Preload("Section.Grade").Preload("Subject").Preload("Staff").Preload("Room")
	if value := textMapValue(payload, "academic_year_id"); value != "" {
		query = query.Where("timetable_slots.academic_year_id = ?", value)
	}
	if value := textMapValue(payload, "section_id"); value != "" {
		query = query.Where("timetable_slots.section_id = ?", value)
	}
	if value := textMapValue(payload, "staff_id"); value != "" {
		query = query.Where("timetable_slots.staff_id = ?", value)
	}
	if value := textMapValue(payload, "room_id"); value != "" {
		query = query.Where("timetable_slots.room_id = ?", value)
	}
	var slots []models.TimetableSlot
	_ = query.Order("timetable_slots.day_of_week, timetable_slots.period_number").Find(&slots).Error
	return slots
}

func writeTimetableArtifact(row models.ReportExport, slots []models.TimetableSlot) (string, string, error) {
	dir := filepath.Join("uploads", "exports", row.SchoolID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", "", err
	}
	filename := sanitizeFilename(row.ReportTitle) + "_" + row.ID + "." + row.Format
	path := filepath.Join(dir, filename)
	var data []byte
	switch row.Format {
	case "csv":
		data = timetableCSV(slots)
	case "xlsx":
		var err error
		data, err = timetableXLSX(slots)
		if err != nil {
			return "", "", err
		}
	default:
		data = timetablePDF(row, slots)
	}
	if err := os.WriteFile(path, data, 0o644); err != nil {
		return "", "", err
	}
	return "/" + filepath.ToSlash(path), "/uploads/exports/" + row.SchoolID + "/" + filename, nil
}

func timetableCSV(slots []models.TimetableSlot) []byte {
	var buffer bytes.Buffer
	writer := csv.NewWriter(&buffer)
	_ = writer.Write([]string{"day", "period", "class", "subject", "teacher", "room", "start", "end"})
	for _, slot := range slots {
		_ = writer.Write(timetableExportRow(slot))
	}
	writer.Flush()
	return buffer.Bytes()
}

func timetablePDF(row models.ReportExport, slots []models.TimetableSlot) []byte {
	lines := []string{
		"Generated: " + row.RequestedAt.Format(time.RFC3339),
		fmt.Sprintf("Slots: %d", len(slots)),
	}
	for _, slot := range slots {
		if len(lines) >= 32 {
			lines = append(lines, "More rows available in CSV/XLSX export.")
			break
		}
		cells := timetableExportRow(slot)
		lines = append(lines, strings.Join(cells[:6], " | "))
	}
	return minimalPDF(row.ReportTitle, lines)
}

func timetableXLSX(slots []models.TimetableSlot) ([]byte, error) {
	var buffer bytes.Buffer
	zipper := zip.NewWriter(&buffer)
	files := map[string]string{
		"[Content_Types].xml":        `<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>`,
		"_rels/.rels":                `<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
		"xl/workbook.xml":            `<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Timetable" sheetId="1" r:id="rId1"/></sheets></workbook>`,
		"xl/_rels/workbook.xml.rels": `<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>`,
		"xl/worksheets/sheet1.xml":   timetableSheetXML(slots),
	}
	for name, body := range files {
		writer, err := zipper.Create(name)
		if err != nil {
			return nil, err
		}
		if _, err := writer.Write([]byte(body)); err != nil {
			return nil, err
		}
	}
	if err := zipper.Close(); err != nil {
		return nil, err
	}
	return buffer.Bytes(), nil
}

func timetableSheetXML(slots []models.TimetableSlot) string {
	rows := [][]string{{"Day", "Period", "Class", "Subject", "Teacher", "Room", "Start", "End"}}
	for _, slot := range slots {
		rows = append(rows, timetableExportRow(slot))
	}
	var builder strings.Builder
	builder.WriteString(`<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>`)
	for i, row := range rows {
		builder.WriteString(fmt.Sprintf(`<row r="%d">`, i+1))
		for j, cell := range row {
			ref := string(rune('A'+j)) + fmt.Sprint(i+1)
			builder.WriteString(`<c r="` + ref + `" t="inlineStr"><is><t>` + xmlEscape(cell) + `</t></is></c>`)
		}
		builder.WriteString(`</row>`)
	}
	builder.WriteString(`</sheetData></worksheet>`)
	return builder.String()
}

func timetableExportRow(slot models.TimetableSlot) []string {
	return []string{
		weekdayLabel(slot.DayOfWeek),
		fmt.Sprint(slot.PeriodNumber),
		principalSlotClassName(&slot),
		principalSlotSubjectName(&slot),
		principalTeacherName(slot.Staff),
		principalRoomName(slot.Room),
		clockString(slot.StartTime),
		clockString(slot.EndTime),
	}
}

func xmlEscape(value string) string {
	value = strings.ReplaceAll(value, "&", "&amp;")
	value = strings.ReplaceAll(value, "<", "&lt;")
	value = strings.ReplaceAll(value, ">", "&gt;")
	value = strings.ReplaceAll(value, `"`, "&quot;")
	value = strings.ReplaceAll(value, "'", "&apos;")
	return value
}

func textMapValue(payload map[string]interface{}, key string) string {
	if value, ok := payload[key]; ok && value != nil {
		return strings.TrimSpace(fmt.Sprint(value))
	}
	return ""
}

func timetableOptionalString(value string) *string {
	value = strings.TrimSpace(value)
	if value == "" || value == "<nil>" {
		return nil
	}
	return &value
}

func clockString(value *time.Time) string {
	if value == nil || value.IsZero() {
		return ""
	}
	return value.Format("15:04")
}

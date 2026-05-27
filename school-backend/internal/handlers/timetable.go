package handlers

import (
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type TimetableHandler struct{}

func NewTimetableHandler() *TimetableHandler {
	return &TimetableHandler{}
}

func (h *TimetableHandler) GetTimetableSlots(c *gin.Context) {
	sectionID := c.Query("section_id")
	yearID := c.Query("academic_year_id")
	dayOfWeek := c.Query("day_of_week")
	staffID := c.Query("staff_id")
	schoolID := scopedSchoolID(c)
	if currentRole(c) == "teacher" {
		currentTeacherID := currentStaffID(c)
		if currentTeacherID == "" {
			fail(c, http.StatusForbidden, "teacher staff link missing")
			return
		}
		if staffID != "" && staffID != currentTeacherID {
			fail(c, http.StatusForbidden, "teacher timetable access denied")
			return
		}
		staffID = currentTeacherID
	}
	if sectionID != "" && !canAccessSection(c, sectionID) {
		fail(c, http.StatusForbidden, "section access denied")
		return
	}

	var slots []models.TimetableSlot
	query := database.DB.
		Model(&models.TimetableSlot{}).
		Joins("JOIN sections ON sections.id = timetable_slots.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Preload("Subject").
		Preload("Staff").
		Preload("Room")
	if schoolID != "" {
		query = query.Where("grades.school_id = ?", schoolID)
	}
	if sectionID != "" {
		query = query.Where("timetable_slots.section_id = ?", sectionID)
	}
	if yearID != "" {
		query = query.Where("timetable_slots.academic_year_id = ?", yearID)
	}
	if dayOfWeek != "" {
		query = query.Where("timetable_slots.day_of_week = ?", dayOfWeek)
	}
	if staffID != "" {
		query = query.Where("timetable_slots.staff_id = ?", staffID)
	}
	query.Order("timetable_slots.day_of_week, timetable_slots.period_number").Find(&slots)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: slots})
}

func (h *TimetableHandler) CreateTimetableSlot(c *gin.Context) {
	var req models.CreateTimetableSlotRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if req.DayOfWeek < 1 || req.DayOfWeek > 7 {
		fail(c, http.StatusBadRequest, "day_of_week must be between 1 and 7")
		return
	}
	if req.PeriodNumber < 1 {
		fail(c, http.StatusBadRequest, "period_number must be greater than zero")
		return
	}
	if err := validateTimetableSlotRequest(c, req, ""); err != nil {
		fail(c, err.Status, err.Message)
		return
	}
	startTime, err := timetableClockPointer(req.StartTime)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "start_time must be HH:MM"})
		return
	}
	endTime, err := timetableClockPointer(req.EndTime)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "end_time must be HH:MM"})
		return
	}

	slot := models.TimetableSlot{
		SectionID:      req.SectionID,
		AcademicYearID: req.AcademicYearID,
		TermID:         req.TermID,
		DayOfWeek:      req.DayOfWeek,
		PeriodNumber:   req.PeriodNumber,
		SubjectID:      req.SubjectID,
		StaffID:        req.StaffID,
		StartTime:      startTime,
		EndTime:        endTime,
		SlotType:       "regular",
	}

	if req.RoomID != "" {
		slot.RoomID = &req.RoomID
	}

	if err := database.DB.Create(&slot).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create timetable slot"})
		return
	}

	id := slot.ID
	auditAction(c, "timetable", "create", "timetable_slots", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: slot})
}

func (h *TimetableHandler) UpdateTimetableSlot(c *gin.Context) {
	id := c.Param("id")
	var slot models.TimetableSlot
	if err := scopedTimetableSlotQuery(c).First(&slot, "timetable_slots.id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Timetable slot not found"})
		return
	}

	var req models.CreateTimetableSlotRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if req.DayOfWeek < 1 || req.DayOfWeek > 7 {
		fail(c, http.StatusBadRequest, "day_of_week must be between 1 and 7")
		return
	}
	if req.PeriodNumber < 1 {
		fail(c, http.StatusBadRequest, "period_number must be greater than zero")
		return
	}
	if err := validateTimetableSlotRequest(c, req, id); err != nil {
		fail(c, err.Status, err.Message)
		return
	}
	startTime, err := timetableClockPointer(req.StartTime)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "start_time must be HH:MM"})
		return
	}
	endTime, err := timetableClockPointer(req.EndTime)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "end_time must be HH:MM"})
		return
	}

	slot.SectionID = req.SectionID
	slot.AcademicYearID = req.AcademicYearID
	slot.TermID = req.TermID
	slot.DayOfWeek = req.DayOfWeek
	slot.SubjectID = req.SubjectID
	slot.StaffID = req.StaffID
	slot.PeriodNumber = req.PeriodNumber
	slot.StartTime = startTime
	slot.EndTime = endTime
	if strings.TrimSpace(req.RoomID) == "" {
		slot.RoomID = nil
	} else {
		roomID := strings.TrimSpace(req.RoomID)
		slot.RoomID = &roomID
	}

	if err := database.DB.Save(&slot).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update timetable slot"})
		return
	}

	auditAction(c, "timetable", "update", "timetable_slots", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: slot})
}

func (h *TimetableHandler) DeleteTimetableSlot(c *gin.Context) {
	id := c.Param("id")
	var slot models.TimetableSlot
	if err := scopedTimetableSlotQuery(c).First(&slot, "timetable_slots.id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Timetable slot not found"})
		return
	}
	if err := database.DB.Delete(&slot).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete timetable slot"})
		return
	}
	auditAction(c, "timetable", "delete", "timetable_slots", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Timetable slot deleted successfully"})
}

func (h *TimetableHandler) GetSubstitutions(c *gin.Context) {
	date := c.Query("date")
	originalStaffID := c.Query("original_staff_id")

	var subs []models.Substitution
	query := database.DB.
		Model(&models.Substitution{}).
		Joins("JOIN timetable_slots ON timetable_slots.id = substitutions.timetable_slot_id").
		Joins("JOIN sections ON sections.id = timetable_slots.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ?", scopedSchoolID(c)).
		Preload("TimetableSlot").
		Preload("OriginalStaff").
		Preload("SubstituteStaff")
	if date != "" {
		parsed, err := time.Parse("2006-01-02", date)
		if err != nil {
			fail(c, http.StatusBadRequest, "Invalid date format. Use YYYY-MM-DD")
			return
		}
		query = query.Where("date >= ? AND date < ?", parsed, parsed.AddDate(0, 0, 1))
	}
	if originalStaffID != "" {
		query = query.Where("original_staff_id = ?", originalStaffID)
	}
	query.Find(&subs)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: subs})
}

func (h *TimetableHandler) CreateSubstitution(c *gin.Context) {
	var req struct {
		TimetableSlotID   string `json:"timetable_slot_id" binding:"required"`
		Date              string `json:"date" binding:"required"`
		OriginalStaffID   string `json:"original_staff_id" binding:"required"`
		SubstituteStaffID string `json:"substitute_staff_id" binding:"required"`
		Reason            string `json:"reason"`
		ApprovedBy        string `json:"approved_by"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Parse date
	date, err := time.Parse("2006-01-02", req.Date)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid date format. Use YYYY-MM-DD"})
		return
	}
	if req.OriginalStaffID == req.SubstituteStaffID {
		fail(c, http.StatusBadRequest, "substitute_staff_id must be different from original_staff_id")
		return
	}
	if err := validateSubstitutionScope(c, req.TimetableSlotID, req.OriginalStaffID, req.SubstituteStaffID); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	sub := models.Substitution{
		TimetableSlotID:   req.TimetableSlotID,
		Date:              date,
		OriginalStaffID:   req.OriginalStaffID,
		SubstituteStaffID: req.SubstituteStaffID,
		Reason:            req.Reason,
	}

	if req.ApprovedBy != "" {
		sub.ApprovedBy = &req.ApprovedBy
	}

	if err := database.DB.Create(&sub).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create substitution"})
		return
	}

	id := sub.ID
	auditAction(c, "timetable", "create", "substitutions", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: sub})
}

func (h *TimetableHandler) GetTimetableBySection(c *gin.Context) {
	sectionID := c.Param("section_id")
	yearID := c.Query("academic_year_id")
	if !canAccessSection(c, sectionID) {
		fail(c, http.StatusForbidden, "section access denied")
		return
	}

	var slots []models.TimetableSlot
	query := scopedTimetableSlotQuery(c).Where("timetable_slots.section_id = ?", sectionID).Preload("Subject").Preload("Staff")
	if yearID != "" {
		query = query.Where("academic_year_id = ?", yearID)
	}
	if err := query.Order("day_of_week, period_number").Find(&slots).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load timetable")
		return
	}

	timetable := make(map[string]map[string]models.TimetableSlot)
	for _, slot := range slots {
		day := strconv.Itoa(slot.DayOfWeek)
		period := strconv.Itoa(slot.PeriodNumber)
		if timetable[day] == nil {
			timetable[day] = make(map[string]models.TimetableSlot)
		}
		timetable[day][period] = slot
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: timetable})
}

func (h *TimetableHandler) SuggestTimetableSlots(c *gin.Context) {
	var req timetableSuggestionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	plan, planErr := h.buildTimetableSuggestionPlan(c, req)
	if planErr != nil {
		fail(c, planErr.Status, planErr.Message)
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: plan})
}

func (h *TimetableHandler) GenerateTimetableSlots(c *gin.Context) {
	var req timetableSuggestionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	plan, planErr := h.buildTimetableSuggestionPlan(c, req)
	if planErr != nil {
		fail(c, planErr.Status, planErr.Message)
		return
	}

	created := make([]models.TimetableSlot, 0)
	skipped := make([]timetableSuggestion, 0)
	tx := database.DB.Begin()
	if tx.Error != nil {
		fail(c, http.StatusInternalServerError, "Failed to start timetable generation")
		return
	}

	for _, suggestion := range plan.Suggestions {
		if suggestion.Blocking {
			skipped = append(skipped, suggestion)
			continue
		}

		var sectionConflict int64
		tx.Model(&models.TimetableSlot{}).
			Where("section_id = ? AND academic_year_id = ? AND day_of_week = ? AND period_number = ?",
				suggestion.SectionID, suggestion.AcademicYearID, suggestion.DayOfWeek, suggestion.PeriodNumber).
			Count(&sectionConflict)
		if sectionConflict > 0 {
			suggestion.Blocking = true
			suggestion.Warnings = append(suggestion.Warnings, "Period already exists for this class and day.")
			skipped = append(skipped, suggestion)
			continue
		}

		var staffConflict int64
		tx.Model(&models.TimetableSlot{}).
			Where("staff_id = ? AND academic_year_id = ? AND day_of_week = ? AND period_number = ?",
				suggestion.StaffID, suggestion.AcademicYearID, suggestion.DayOfWeek, suggestion.PeriodNumber).
			Count(&staffConflict)
		if staffConflict > 0 {
			suggestion.Blocking = true
			suggestion.Warnings = append(suggestion.Warnings, "Suggested teacher is already assigned in this period.")
			skipped = append(skipped, suggestion)
			continue
		}

		startTime, err := timetableClockPointer(suggestion.StartTime)
		if err != nil {
			tx.Rollback()
			fail(c, http.StatusInternalServerError, "Failed to parse suggested start time")
			return
		}
		endTime, err := timetableClockPointer(suggestion.EndTime)
		if err != nil {
			tx.Rollback()
			fail(c, http.StatusInternalServerError, "Failed to parse suggested end time")
			return
		}
		slot := models.TimetableSlot{
			SectionID:      suggestion.SectionID,
			AcademicYearID: suggestion.AcademicYearID,
			TermID:         suggestion.TermID,
			DayOfWeek:      suggestion.DayOfWeek,
			PeriodNumber:   suggestion.PeriodNumber,
			SubjectID:      suggestion.SubjectID,
			StaffID:        suggestion.StaffID,
			StartTime:      startTime,
			EndTime:        endTime,
			SlotType:       "regular",
		}
		if err := tx.Create(&slot).Error; err != nil {
			tx.Rollback()
			fail(c, http.StatusInternalServerError, "Failed to generate timetable slots")
			return
		}
		created = append(created, slot)
	}

	if err := tx.Commit().Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to finish timetable generation")
		return
	}

	for _, slot := range created {
		id := slot.ID
		auditAction(c, "timetable", "generate", "timetable_slots", &id)
	}

	c.JSON(http.StatusCreated, models.APIResponse{
		Success: true,
		Data: gin.H{
			"created":             len(created),
			"skipped":             len(skipped),
			"slots":               created,
			"skipped_suggestions": skipped,
			"summary":             plan.Summary,
		},
	})
}

type timetableValidationError struct {
	Status  int
	Message string
}

func (e *timetableValidationError) Error() string {
	return e.Message
}

type timetableSuggestionRequest struct {
	SectionID             string `json:"section_id" binding:"required"`
	AcademicYearID        string `json:"academic_year_id" binding:"required"`
	TermID                string `json:"term_id" binding:"required"`
	DayOfWeek             int    `json:"day_of_week" binding:"required"`
	PeriodCount           int    `json:"period_count"`
	StartTime             string `json:"start_time"`
	PeriodDurationMinutes int    `json:"period_duration_minutes"`
	GapMinutes            int    `json:"gap_minutes"`
}

type timetableSuggestionPlan struct {
	SectionID      string                `json:"section_id"`
	AcademicYearID string                `json:"academic_year_id"`
	TermID         string                `json:"term_id"`
	DayOfWeek      int                   `json:"day_of_week"`
	Suggestions    []timetableSuggestion `json:"suggestions"`
	Summary        timetableSummary      `json:"summary"`
}

type timetableSummary struct {
	RequestedPeriods int `json:"requested_periods"`
	SuggestedPeriods int `json:"suggested_periods"`
	CreatablePeriods int `json:"creatable_periods"`
	BlockedPeriods   int `json:"blocked_periods"`
}

type timetableSuggestion struct {
	SectionID      string   `json:"section_id"`
	AcademicYearID string   `json:"academic_year_id"`
	TermID         string   `json:"term_id"`
	DayOfWeek      int      `json:"day_of_week"`
	PeriodNumber   int      `json:"period_number"`
	SubjectID      string   `json:"subject_id"`
	SubjectName    string   `json:"subject_name"`
	StaffID        string   `json:"staff_id"`
	StaffName      string   `json:"staff_name"`
	StartTime      string   `json:"start_time"`
	EndTime        string   `json:"end_time"`
	Confidence     int      `json:"confidence"`
	Warnings       []string `json:"warnings"`
	Blocking       bool     `json:"blocking"`
}

type timetableSubjectPlanItem struct {
	ID   string
	Name string
}

type timetableStaffOption struct {
	ID      string
	Name    string
	Primary bool
	Load    int
}

func (h *TimetableHandler) buildTimetableSuggestionPlan(c *gin.Context, req timetableSuggestionRequest) (timetableSuggestionPlan, *timetableValidationError) {
	schoolID := scopedSchoolID(c)
	if schoolID == "" {
		return timetableSuggestionPlan{}, &timetableValidationError{Status: http.StatusForbidden, Message: "school scope missing in token"}
	}
	req.SectionID = strings.TrimSpace(req.SectionID)
	req.AcademicYearID = strings.TrimSpace(req.AcademicYearID)
	req.TermID = strings.TrimSpace(req.TermID)
	req.StartTime = strings.TrimSpace(req.StartTime)
	if req.DayOfWeek < 1 || req.DayOfWeek > 7 {
		return timetableSuggestionPlan{}, &timetableValidationError{Status: http.StatusBadRequest, Message: "day_of_week must be between 1 and 7"}
	}
	if req.PeriodCount <= 0 {
		req.PeriodCount = 7
	}
	if req.PeriodCount > 12 {
		return timetableSuggestionPlan{}, &timetableValidationError{Status: http.StatusBadRequest, Message: "period_count cannot exceed 12"}
	}
	if req.PeriodDurationMinutes <= 0 {
		req.PeriodDurationMinutes = 40
	}
	if req.PeriodDurationMinutes > 180 {
		return timetableSuggestionPlan{}, &timetableValidationError{Status: http.StatusBadRequest, Message: "period_duration_minutes cannot exceed 180"}
	}
	if req.GapMinutes < 0 || req.GapMinutes > 60 {
		req.GapMinutes = 5
	}
	if req.StartTime == "" {
		req.StartTime = "09:00"
	}
	startClock, err := parseTimetableClock(req.StartTime)
	if err != nil {
		return timetableSuggestionPlan{}, &timetableValidationError{Status: http.StatusBadRequest, Message: "start_time must use HH:MM format"}
	}

	var section models.Section
	if err := database.DB.
		Preload("Grade").
		Preload("ClassTeacher").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("sections.id = ? AND grades.school_id = ?", req.SectionID, schoolID).
		First(&section).Error; err != nil {
		return timetableSuggestionPlan{}, &timetableValidationError{Status: http.StatusBadRequest, Message: "section does not belong to this school"}
	}
	if err := database.DB.First(&models.AcademicYear{}, "id = ? AND school_id = ?", req.AcademicYearID, schoolID).Error; err != nil {
		return timetableSuggestionPlan{}, &timetableValidationError{Status: http.StatusBadRequest, Message: "academic year does not belong to this school"}
	}
	if err := database.DB.
		Joins("JOIN academic_years ON academic_years.id = terms.academic_year_id").
		First(&models.Term{}, "terms.id = ? AND terms.academic_year_id = ? AND academic_years.school_id = ?", req.TermID, req.AcademicYearID, schoolID).Error; err != nil {
		return timetableSuggestionPlan{}, &timetableValidationError{Status: http.StatusBadRequest, Message: "term does not belong to this academic year"}
	}

	subjectPlan := buildSubjectPlan(section.GradeID, schoolID, req.PeriodCount)
	if len(subjectPlan) == 0 {
		return timetableSuggestionPlan{}, &timetableValidationError{Status: http.StatusBadRequest, Message: "No backend subjects are configured for timetable generation"}
	}

	staffOptions, subjectStaff := loadTimetableStaffOptions(schoolID, section.GradeID)
	if len(staffOptions) == 0 {
		return timetableSuggestionPlan{}, &timetableValidationError{Status: http.StatusBadRequest, Message: "No active backend staff records are available for timetable generation"}
	}

	var existing []models.TimetableSlot
	database.DB.
		Joins("JOIN sections ON sections.id = timetable_slots.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ? AND timetable_slots.academic_year_id = ? AND timetable_slots.day_of_week = ?", schoolID, req.AcademicYearID, req.DayOfWeek).
		Find(&existing)

	var allYearSlots []models.TimetableSlot
	database.DB.
		Joins("JOIN sections ON sections.id = timetable_slots.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ? AND timetable_slots.academic_year_id = ?", schoolID, req.AcademicYearID).
		Find(&allYearSlots)

	sectionPeriods := map[int]bool{}
	staffBusy := map[string]map[int]bool{}
	for _, slot := range existing {
		if slot.SectionID == req.SectionID {
			sectionPeriods[slot.PeriodNumber] = true
		}
		if staffBusy[slot.StaffID] == nil {
			staffBusy[slot.StaffID] = map[int]bool{}
		}
		staffBusy[slot.StaffID][slot.PeriodNumber] = true
	}
	staffLoad := map[string]int{}
	for _, slot := range allYearSlots {
		staffLoad[slot.StaffID]++
	}

	suggestions := make([]timetableSuggestion, 0, req.PeriodCount)
	for period := 1; period <= req.PeriodCount; period++ {
		subject := subjectPlan[(period-1)%len(subjectPlan)]
		start := startClock.Add(time.Duration(period-1) * time.Duration(req.PeriodDurationMinutes+req.GapMinutes) * time.Minute)
		end := start.Add(time.Duration(req.PeriodDurationMinutes) * time.Minute)
		suggestion := timetableSuggestion{
			SectionID:      req.SectionID,
			AcademicYearID: req.AcademicYearID,
			TermID:         req.TermID,
			DayOfWeek:      req.DayOfWeek,
			PeriodNumber:   period,
			SubjectID:      subject.ID,
			SubjectName:    subject.Name,
			StartTime:      start.Format("15:04"),
			EndTime:        end.Format("15:04"),
			Confidence:     92,
			Warnings:       []string{},
		}
		if sectionPeriods[period] {
			suggestion.Blocking = true
			suggestion.Confidence = 0
			suggestion.Warnings = append(suggestion.Warnings, "Period already exists for this class and day.")
			suggestions = append(suggestions, suggestion)
			continue
		}

		staff, warnings, blocking := chooseTimetableStaff(subject.ID, period, subjectStaff, staffOptions, staffBusy, staffLoad, section.ClassTeacherID)
		suggestion.StaffID = staff.ID
		suggestion.StaffName = staff.Name
		suggestion.Warnings = append(suggestion.Warnings, warnings...)
		suggestion.Blocking = blocking
		if blocking {
			suggestion.Confidence = 35
		} else if len(warnings) > 0 {
			suggestion.Confidence = 72
			if staffBusy[suggestion.StaffID] == nil {
				staffBusy[suggestion.StaffID] = map[int]bool{}
			}
			staffBusy[suggestion.StaffID][period] = true
			staffLoad[suggestion.StaffID]++
		} else {
			if staffBusy[suggestion.StaffID] == nil {
				staffBusy[suggestion.StaffID] = map[int]bool{}
			}
			staffBusy[suggestion.StaffID][period] = true
			staffLoad[suggestion.StaffID]++
		}
		suggestions = append(suggestions, suggestion)
	}

	summary := timetableSummary{RequestedPeriods: req.PeriodCount, SuggestedPeriods: len(suggestions)}
	for _, suggestion := range suggestions {
		if suggestion.Blocking {
			summary.BlockedPeriods++
		} else {
			summary.CreatablePeriods++
		}
	}

	return timetableSuggestionPlan{
		SectionID:      req.SectionID,
		AcademicYearID: req.AcademicYearID,
		TermID:         req.TermID,
		DayOfWeek:      req.DayOfWeek,
		Suggestions:    suggestions,
		Summary:        summary,
	}, nil
}

func buildSubjectPlan(gradeID, schoolID string, periodCount int) []timetableSubjectPlanItem {
	var gradeSubjects []models.GradeSubject
	database.DB.
		Preload("Subject").
		Joins("JOIN subjects ON subjects.id = grade_subjects.subject_id").
		Where("grade_subjects.grade_id = ? AND subjects.school_id = ?", gradeID, schoolID).
		Order("grade_subjects.is_mandatory DESC, grade_subjects.periods_per_week DESC, subjects.subject_name").
		Find(&gradeSubjects)

	weighted := make([]struct {
		item      timetableSubjectPlanItem
		remaining int
	}, 0, len(gradeSubjects))
	for _, row := range gradeSubjects {
		if row.Subject == nil {
			continue
		}
		periods := row.PeriodsPerWeek
		if periods <= 0 {
			periods = 1
		}
		weighted = append(weighted, struct {
			item      timetableSubjectPlanItem
			remaining int
		}{
			item:      timetableSubjectPlanItem{ID: row.SubjectID, Name: row.Subject.SubjectName},
			remaining: periods,
		})
	}

	plan := make([]timetableSubjectPlanItem, 0, periodCount)
	for len(plan) < periodCount && len(weighted) > 0 {
		used := false
		for i := range weighted {
			if weighted[i].remaining <= 0 {
				continue
			}
			plan = append(plan, weighted[i].item)
			weighted[i].remaining--
			used = true
			if len(plan) == periodCount {
				break
			}
		}
		if !used {
			for i := range weighted {
				weighted[i].remaining = 1
			}
		}
	}
	if len(plan) > 0 {
		return plan
	}

	var subjects []models.Subject
	database.DB.Where("school_id = ?", schoolID).Order("subject_name").Find(&subjects)
	for _, subject := range subjects {
		plan = append(plan, timetableSubjectPlanItem{ID: subject.ID, Name: subject.SubjectName})
		if len(plan) == periodCount {
			break
		}
	}
	return plan
}

func loadTimetableStaffOptions(schoolID, gradeID string) ([]timetableStaffOption, map[string][]timetableStaffOption) {
	var staff []models.Staff
	database.DB.
		Where("school_id = ? AND (status = '' OR LOWER(status) = ?)", schoolID, "active").
		Order("first_name, last_name, email").
		Find(&staff)

	all := make([]timetableStaffOption, 0, len(staff))
	staffByID := map[string]timetableStaffOption{}
	for _, row := range staff {
		option := timetableStaffOption{ID: row.ID, Name: staffDisplayName(row)}
		all = append(all, option)
		staffByID[row.ID] = option
	}

	var staffSubjects []models.StaffSubject
	database.DB.
		Joins("JOIN staffs ON staffs.id = staff_subjects.staff_id").
		Where("staff_subjects.grade_id = ? AND staffs.school_id = ? AND (staffs.status = '' OR LOWER(staffs.status) = ?)", gradeID, schoolID, "active").
		Find(&staffSubjects)

	bySubject := map[string][]timetableStaffOption{}
	for _, row := range staffSubjects {
		option, ok := staffByID[row.StaffID]
		if !ok {
			continue
		}
		option.Primary = row.IsPrimary
		bySubject[row.SubjectID] = append(bySubject[row.SubjectID], option)
	}
	return all, bySubject
}

func chooseTimetableStaff(subjectID string, period int, subjectStaff map[string][]timetableStaffOption, allStaff []timetableStaffOption, staffBusy map[string]map[int]bool, staffLoad map[string]int, classTeacherID *string) (timetableStaffOption, []string, bool) {
	mapped := append([]timetableStaffOption{}, subjectStaff[subjectID]...)
	if classTeacherID != nil && strings.TrimSpace(*classTeacherID) != "" {
		for _, staff := range allStaff {
			if staff.ID == *classTeacherID && !containsTimetableStaff(mapped, staff.ID) {
				mapped = append([]timetableStaffOption{staff}, mapped...)
				break
			}
		}
	}
	sortTimetableStaff(mapped, staffLoad)
	if selected, ok := firstAvailableTimetableStaff(mapped, period, staffBusy); ok {
		return selected, nil, false
	}

	sortTimetableStaff(allStaff, staffLoad)
	warnings := []string{}
	if len(mapped) == 0 {
		warnings = append(warnings, "No subject-teacher mapping found; suggested least-loaded active staff.")
	} else {
		warnings = append(warnings, "Mapped teachers are busy in this period; suggested alternate active staff.")
	}
	if selected, ok := firstAvailableTimetableStaff(allStaff, period, staffBusy); ok {
		return selected, warnings, false
	}
	if len(allStaff) == 0 {
		return timetableStaffOption{}, []string{"No active staff are available."}, true
	}
	selected := allStaff[0]
	warnings = append(warnings, "Suggested teacher is already assigned in this period.")
	return selected, warnings, true
}

func sortTimetableStaff(staff []timetableStaffOption, load map[string]int) {
	sort.SliceStable(staff, func(i, j int) bool {
		if staff[i].Primary != staff[j].Primary {
			return staff[i].Primary
		}
		if load[staff[i].ID] != load[staff[j].ID] {
			return load[staff[i].ID] < load[staff[j].ID]
		}
		return staff[i].Name < staff[j].Name
	})
}

func firstAvailableTimetableStaff(staff []timetableStaffOption, period int, busy map[string]map[int]bool) (timetableStaffOption, bool) {
	for _, option := range staff {
		if busy[option.ID] == nil || !busy[option.ID][period] {
			return option, true
		}
	}
	return timetableStaffOption{}, false
}

func containsTimetableStaff(staff []timetableStaffOption, id string) bool {
	for _, option := range staff {
		if option.ID == id {
			return true
		}
	}
	return false
}

func staffDisplayName(staff models.Staff) string {
	name := strings.TrimSpace(strings.Join([]string{staff.FirstName, staff.LastName}, " "))
	if name != "" {
		return name
	}
	if strings.TrimSpace(staff.Email) != "" {
		return staff.Email
	}
	return staff.ID
}

func parseTimetableClock(value string) (time.Time, error) {
	parsed, err := time.Parse("15:04", value)
	if err != nil {
		return time.Time{}, err
	}
	return time.Date(2000, 1, 1, parsed.Hour(), parsed.Minute(), 0, 0, time.UTC), nil
}

func timetableClockPointer(value string) (*time.Time, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil, nil
	}
	parsed, err := parseTimetableClock(value)
	if err != nil {
		return nil, err
	}
	return &parsed, nil
}

func scopedTimetableSlotQuery(c *gin.Context) *gorm.DB {
	return database.DB.
		Model(&models.TimetableSlot{}).
		Joins("JOIN sections ON sections.id = timetable_slots.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ?", scopedSchoolID(c))
}

func validateSubstitutionScope(c *gin.Context, timetableSlotID, originalStaffID, substituteStaffID string) error {
	schoolID := scopedSchoolID(c)
	if countRows(scopedTimetableSlotQuery(c).Where("timetable_slots.id = ?", strings.TrimSpace(timetableSlotID))) == 0 {
		return fmt.Errorf("timetable slot does not belong to this school")
	}
	if !staffBelongsToSchool(strings.TrimSpace(originalStaffID), schoolID) {
		return fmt.Errorf("original staff does not belong to this school or is inactive")
	}
	if !staffBelongsToSchool(strings.TrimSpace(substituteStaffID), schoolID) {
		return fmt.Errorf("substitute staff does not belong to this school or is inactive")
	}
	return nil
}

func validateTimetableSlotRequest(c *gin.Context, req models.CreateTimetableSlotRequest, excludeID string) *timetableValidationError {
	schoolID := scopedSchoolID(c)
	if schoolID == "" {
		return &timetableValidationError{Status: http.StatusForbidden, Message: "school scope missing in token"}
	}
	if err := database.DB.
		Joins("JOIN grades ON grades.id = sections.grade_id").
		First(&models.Section{}, "sections.id = ? AND grades.school_id = ?", req.SectionID, schoolID).Error; err != nil {
		return &timetableValidationError{Status: http.StatusBadRequest, Message: "section does not belong to this school"}
	}
	if err := database.DB.First(&models.AcademicYear{}, "id = ? AND school_id = ?", req.AcademicYearID, schoolID).Error; err != nil {
		return &timetableValidationError{Status: http.StatusBadRequest, Message: "academic year does not belong to this school"}
	}
	if err := database.DB.
		Joins("JOIN academic_years ON academic_years.id = terms.academic_year_id").
		First(&models.Term{}, "terms.id = ? AND terms.academic_year_id = ? AND academic_years.school_id = ?", req.TermID, req.AcademicYearID, schoolID).Error; err != nil {
		return &timetableValidationError{Status: http.StatusBadRequest, Message: "term does not belong to this academic year"}
	}
	if err := database.DB.First(&models.Subject{}, "id = ? AND school_id = ?", req.SubjectID, schoolID).Error; err != nil {
		return &timetableValidationError{Status: http.StatusBadRequest, Message: "subject does not belong to this school"}
	}
	if err := database.DB.First(&models.Staff{}, "id = ? AND school_id = ? AND (status = '' OR LOWER(status) = ?)", req.StaffID, schoolID, "active").Error; err != nil {
		return &timetableValidationError{Status: http.StatusBadRequest, Message: "staff does not belong to this school or is inactive"}
	}
	if strings.TrimSpace(req.RoomID) != "" {
		if err := database.DB.First(&models.Room{}, "id = ? AND school_id = ?", req.RoomID, schoolID).Error; err != nil {
			return &timetableValidationError{Status: http.StatusBadRequest, Message: "room does not belong to this school"}
		}
	}

	sectionConflict := database.DB.Model(&models.TimetableSlot{}).
		Where("section_id = ? AND academic_year_id = ? AND day_of_week = ? AND period_number = ?", req.SectionID, req.AcademicYearID, req.DayOfWeek, req.PeriodNumber)
	if excludeID != "" {
		sectionConflict = sectionConflict.Where("id <> ?", excludeID)
	}
	var sectionConflictCount int64
	sectionConflict.Count(&sectionConflictCount)
	if sectionConflictCount > 0 {
		return &timetableValidationError{Status: http.StatusConflict, Message: fmt.Sprintf("period %d already exists for this class and day", req.PeriodNumber)}
	}

	staffConflict := database.DB.Model(&models.TimetableSlot{}).
		Where("staff_id = ? AND academic_year_id = ? AND day_of_week = ? AND period_number = ?", req.StaffID, req.AcademicYearID, req.DayOfWeek, req.PeriodNumber)
	if excludeID != "" {
		staffConflict = staffConflict.Where("id <> ?", excludeID)
	}
	var staffConflictCount int64
	staffConflict.Count(&staffConflictCount)
	if staffConflictCount > 0 {
		return &timetableValidationError{Status: http.StatusConflict, Message: fmt.Sprintf("staff is already assigned during period %d", req.PeriodNumber)}
	}
	return nil
}

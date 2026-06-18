package handlers

import (
	"fmt"
	"net/http"
	"strings"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// List templates
func (h *TimetableHandler) GetPrePrimaryTimetableTemplates(c *gin.Context) {
	var templates []models.PrePrimaryTimetableTemplate
	query := database.DB.Where("school_id = ?", scopedSchoolID(c)).Preload("Days").Preload("Days.Slots")

	if yearID := strings.TrimSpace(c.Query("academic_year_id")); yearID != "" {
		query = query.Where("academic_year_id = ?", yearID)
	}

	if err := query.Order("created_at DESC").Find(&templates).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load pre-primary templates")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: templates})
}

// Create a template
func (h *TimetableHandler) CreatePrePrimaryTimetableTemplate(c *gin.Context) {
	var req models.PrePrimaryTimetableTemplate
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, "Invalid request body")
		return
	}

	req.SchoolID = scopedSchoolID(c)
	req.ID = ""

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&req).Error; err != nil {
			return err
		}
		return nil
	})

	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create pre-primary template")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: req})
}

// Update a template
func (h *TimetableHandler) UpdatePrePrimaryTimetableTemplate(c *gin.Context) {
	templateID := c.Param("id")
	var req models.PrePrimaryTimetableTemplate
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, "Invalid request body")
		return
	}

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		var existing models.PrePrimaryTimetableTemplate
		if err := tx.Where("id = ? AND school_id = ?", templateID, scopedSchoolID(c)).First(&existing).Error; err != nil {
			return err
		}

		existing.Name = req.Name
		if err := tx.Save(&existing).Error; err != nil {
			return err
		}

		// Delete existing days and slots
		if err := tx.Where("template_id = ?", templateID).Delete(&models.PrePrimaryTimetableDay{}).Error; err != nil {
			return err
		}

		// Recreate days and slots
		for i := range req.Days {
			req.Days[i].TemplateID = templateID
			req.Days[i].ID = ""
			for j := range req.Days[i].Slots {
				req.Days[i].Slots[j].ID = ""
			}
			if err := tx.Create(&req.Days[i]).Error; err != nil {
				return err
			}
		}

		return nil
	})

	if err != nil {
		if err == gorm.ErrRecordNotFound {
			fail(c, http.StatusNotFound, "Template not found")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to update pre-primary template")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Pre-primary template updated"})
}

// Delete a template
func (h *TimetableHandler) DeletePrePrimaryTimetableTemplate(c *gin.Context) {
	templateID := c.Param("id")

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		// Verify ownership
		var existing models.PrePrimaryTimetableTemplate
		if err := tx.Where("id = ? AND school_id = ?", templateID, scopedSchoolID(c)).First(&existing).Error; err != nil {
			return err
		}

		// Delete days (slots cascade if DB configured or we rely on gorm if we have hooks, let's delete explicitly if needed but let's assume we do it)
		if err := tx.Where("template_id = ?", templateID).Delete(&models.PrePrimaryTimetableDay{}).Error; err != nil {
			return err
		}

		if err := tx.Delete(&existing).Error; err != nil {
			return err
		}
		return nil
	})

	if err != nil {
		if err == gorm.ErrRecordNotFound {
			fail(c, http.StatusNotFound, "Template not found")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to delete pre-primary template")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Pre-primary template deleted"})
}

// Fetch Pre-Primary timetable by Section ID
func (h *TimetableHandler) GetPrePrimaryTimetableBySection(c *gin.Context) {
	sectionID := c.Param("section_id")
	if !canAccessSection(c, sectionID) {
		fail(c, http.StatusForbidden, "section access denied")
		return
	}

	var section models.Section
	if err := database.DB.Where("id = ? AND school_id = ?", sectionID, scopedSchoolID(c)).First(&section).Error; err != nil {
		fail(c, http.StatusNotFound, "Section not found")
		return
	}

	if section.PrePrimaryTimetableTemplateID == nil || *section.PrePrimaryTimetableTemplateID == "" {
		fail(c, http.StatusNotFound, "No pre-primary timetable template assigned to this section")
		return
	}

	var template models.PrePrimaryTimetableTemplate
	if err := database.DB.Preload("Days").Preload("Days.Slots").Where("id = ? AND school_id = ?", *section.PrePrimaryTimetableTemplateID, scopedSchoolID(c)).First(&template).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load pre-primary timetable template")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: template})
}

type prePrimaryScheduleApplyRequest struct {
	SectionID      string `json:"section_id" binding:"required"`
	AcademicYearID string `json:"academic_year_id" binding:"required"`
	TermID         string `json:"term_id"`
	StaffID        string `json:"staff_id"`
	ScheduleType   string `json:"schedule_type"`
}

type prePrimaryScheduleSlot struct {
	Start   string
	End     string
	Subject string
	Break   bool
}

func (h *TimetableHandler) ApplyPrePrimaryClassSchedule(c *gin.Context) {
	var req prePrimaryScheduleApplyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	schoolID := scopedSchoolID(c)
	scheduleType := normalizePrePrimaryScheduleType(req.ScheduleType)
	preset := prePrimarySchedulePreset(scheduleType)
	if len(preset) == 0 {
		fail(c, http.StatusBadRequest, "schedule_type must be playgroup, nursery, or junior_kg")
		return
	}

	if err := academicDomainService().EnsureAcademicYearWritable(schoolID, req.AcademicYearID); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	var section models.Section
	if err := database.DB.
		Preload("ClassTeacher").
		First(&section, "id = ? AND school_id = ? AND academic_year_id = ?", strings.TrimSpace(req.SectionID), schoolID, strings.TrimSpace(req.AcademicYearID)).Error; err != nil {
		fail(c, http.StatusNotFound, "Section not found for this academic year")
		return
	}

	staffID := strings.TrimSpace(req.StaffID)
	if staffID == "" && section.ClassTeacherID != nil {
		staffID = strings.TrimSpace(*section.ClassTeacherID)
	}
	if staffID == "" {
		fail(c, http.StatusBadRequest, "Select or assign a class teacher before applying this schedule")
		return
	}
	if !staffBelongsToSchool(staffID, schoolID) {
		fail(c, http.StatusBadRequest, "teacher must be active staff in this school")
		return
	}

	termID := strings.TrimSpace(req.TermID)
	if termID == "" {
		var term models.Term
		query := database.DB.Where("academic_year_id = ?", req.AcademicYearID).Order("is_current DESC, term_number ASC, start_date ASC")
		if err := query.First(&term).Error; err != nil {
			fail(c, http.StatusBadRequest, "term does not belong to this academic year")
			return
		}
		termID = term.ID
	}
	if err := database.DB.
		Joins("JOIN academic_years ON academic_years.id = terms.academic_year_id").
		First(&models.Term{}, "terms.id = ? AND terms.academic_year_id = ? AND academic_years.school_id = ?", termID, req.AcademicYearID, schoolID).Error; err != nil {
		fail(c, http.StatusBadRequest, "term does not belong to this academic year")
		return
	}

	subjectCounts := map[string]int{}
	for _, slot := range preset {
		subjectCounts[slot.Subject]++
	}

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		if section.ClassTeacherID == nil || strings.TrimSpace(*section.ClassTeacherID) != staffID {
			if err := tx.Model(&models.Section{}).
				Where("id = ? AND school_id = ?", section.ID, schoolID).
				Update("class_teacher_id", staffID).Error; err != nil {
				return err
			}
		}

		departmentID, err := ensurePrePrimaryDepartment(tx, schoolID)
		if err != nil {
			return err
		}

		subjectIDs := map[string]string{}
		for subjectName, count := range subjectCounts {
			subject, err := ensurePrePrimarySubject(tx, schoolID, departmentID, subjectName)
			if err != nil {
				return err
			}
			subjectIDs[subjectName] = subject.ID
			if err := ensurePrePrimaryGradeSubject(tx, schoolID, req.AcademicYearID, section.GradeID, subject.ID, count); err != nil {
				return err
			}
			if err := ensurePrePrimaryStaffSubject(tx, schoolID, req.AcademicYearID, staffID, subject.ID, section.GradeID, section.ID); err != nil {
				return err
			}
		}

		if err := ensureNoPrePrimaryStaffConflicts(tx, staffID, req.AcademicYearID, section.ID, preset); err != nil {
			return err
		}

		if err := tx.Where("section_id = ? AND academic_year_id = ? AND term_id = ? AND day_of_week BETWEEN ? AND ?", section.ID, req.AcademicYearID, termID, 1, 5).
			Delete(&models.TimetableSlot{}).Error; err != nil {
			return err
		}

		roomID := section.RoomID
		for day := 1; day <= 5; day++ {
			for index, scheduleSlot := range preset {
				startTime, err := timetableClockPointer(scheduleSlot.Start)
				if err != nil {
					return err
				}
				endTime, err := timetableClockPointer(scheduleSlot.End)
				if err != nil {
					return err
				}
				slotType := "regular"
				if scheduleSlot.Break {
					slotType = "break"
				}
				slot := models.TimetableSlot{
					SectionID:      section.ID,
					AcademicYearID: req.AcademicYearID,
					TermID:         termID,
					DayOfWeek:      day,
					PeriodNumber:   index + 1,
					StartTime:      startTime,
					EndTime:        endTime,
					SubjectID:      subjectIDs[scheduleSlot.Subject],
					StaffID:        staffID,
					RoomID:         roomID,
					SlotType:       slotType,
				}
				if err := tx.Create(&slot).Error; err != nil {
					return err
				}
			}
		}
		return nil
	})
	if err != nil {
		fail(c, http.StatusConflict, err.Error())
		return
	}

	auditAction(c, "timetable", "apply_pre_primary", "sections", &section.ID)
	success(c, http.StatusOK, gin.H{
		"section_id":       section.ID,
		"academic_year_id": req.AcademicYearID,
		"term_id":          termID,
		"staff_id":         staffID,
		"schedule_type":    scheduleType,
		"days":             5,
		"periods_per_day":  len(preset),
		"total_slots":      len(preset) * 5,
		"subjects":         len(subjectCounts),
	}, "Pre-primary timetable applied")
}

func normalizePrePrimaryScheduleType(value string) string {
	switch strings.ToLower(strings.TrimSpace(strings.ReplaceAll(value, "-", "_"))) {
	case "playgroup", "play_group", "pg":
		return "playgroup"
	case "nursery":
		return "nursery"
	case "junior_kg", "juniorkg", "jr_kg", "lkg":
		return "junior_kg"
	default:
		return ""
	}
}

func prePrimarySchedulePreset(scheduleType string) []prePrimaryScheduleSlot {
	switch scheduleType {
	case "playgroup":
		return []prePrimaryScheduleSlot{
			{"09:00", "09:20", "Welcome", false},
			{"09:20", "09:50", "Circle Time", false},
			{"09:50", "10:10", "Snack Time", true},
			{"10:10", "10:30", "IGNITE Math", false},
			{"10:30", "11:00", "Fit & Fabulous", false},
			{"11:00", "11:20", "IGNITE Activity Room", false},
			{"11:20", "11:50", "IGNITE Lang", false},
			{"11:50", "12:10", "Story Time / Rhymes", false},
			{"12:10", "12:30", "Recall & Dispersal", false},
		}
	case "nursery":
		return []prePrimaryScheduleSlot{
			{"09:00", "09:20", "Welcome", false},
			{"09:20", "09:50", "Circle Time", false},
			{"09:50", "10:10", "IGNITE Activity Room", false},
			{"10:10", "10:30", "Snack Time", true},
			{"10:30", "11:00", "Story Time", false},
			{"11:00", "11:20", "IGNITE Math", false},
			{"11:20", "11:50", "Fit & Fabulous", false},
			{"11:50", "12:10", "IGNITE Lang", false},
			{"12:10", "12:30", "Recall & Dispersal", false},
		}
	case "junior_kg":
		return []prePrimaryScheduleSlot{
			{"09:00", "09:20", "Welcome", false},
			{"09:20", "09:50", "Circle Time", false},
			{"09:50", "10:10", "IGNITE Lang", false},
			{"10:10", "10:30", "Snack Time", true},
			{"10:30", "11:00", "IGNITE Activity Room", false},
			{"11:00", "11:20", "IGNITE Life Skill", false},
			{"11:20", "11:50", "Fit & Fabulous", false},
			{"11:50", "12:10", "IGNITE Math", false},
			{"12:10", "12:30", "Recall & Dispersal", false},
		}
	default:
		return nil
	}
}

func ensurePrePrimaryDepartment(tx *gorm.DB, schoolID string) (string, error) {
	var department models.Department
	err := tx.Where("school_id = ? AND LOWER(department_name) = ?", schoolID, "pre-primary activities").First(&department).Error
	if err == nil {
		return department.ID, nil
	}
	if err != gorm.ErrRecordNotFound {
		return "", err
	}
	department = models.Department{
		SchoolID:       schoolID,
		DepartmentName: "Pre-Primary Activities",
		Description:    "Created for class timetable activities",
	}
	if err := tx.Create(&department).Error; err != nil {
		return "", err
	}
	return department.ID, nil
}

func ensurePrePrimarySubject(tx *gorm.DB, schoolID, departmentID, subjectName string) (models.Subject, error) {
	var subject models.Subject
	err := tx.Where("school_id = ? AND LOWER(subject_name) = ?", schoolID, strings.ToLower(subjectName)).First(&subject).Error
	if err == nil {
		updates := map[string]interface{}{}
		if strings.TrimSpace(subject.DepartmentID) == "" {
			updates["department_id"] = departmentID
		}
		if strings.TrimSpace(subject.SubjectType) == "" {
			updates["subject_type"] = "pre_primary_activity"
		}
		if len(updates) > 0 {
			if err := tx.Model(&subject).Updates(updates).Error; err != nil {
				return subject, err
			}
		}
		return subject, nil
	}
	if err != gorm.ErrRecordNotFound {
		return subject, err
	}
	subject = models.Subject{
		SchoolID:     schoolID,
		DepartmentID: departmentID,
		SubjectName:  subjectName,
		SubjectCode:  prePrimarySubjectCode(subjectName),
		SubjectType:  "pre_primary_activity",
		SubjectColor: "#2563EB",
	}
	return subject, tx.Create(&subject).Error
}

func ensurePrePrimaryGradeSubject(tx *gorm.DB, schoolID, academicYearID, gradeID, subjectID string, periods int) error {
	var row models.GradeSubject
	err := tx.Where("school_id = ? AND academic_year_id = ? AND grade_id = ? AND subject_id = ?", schoolID, academicYearID, gradeID, subjectID).First(&row).Error
	if err == nil {
		return tx.Model(&row).Updates(map[string]interface{}{
			"periods_per_week": periods * 5,
			"is_mandatory":     true,
		}).Error
	}
	if err != gorm.ErrRecordNotFound {
		return err
	}
	return tx.Create(&models.GradeSubject{
		SchoolID:       schoolID,
		AcademicYearID: academicYearID,
		GradeID:        gradeID,
		SubjectID:      subjectID,
		PeriodsPerWeek: periods * 5,
		IsMandatory:    true,
	}).Error
}

func ensurePrePrimaryStaffSubject(tx *gorm.DB, schoolID, academicYearID, staffID, subjectID, gradeID, sectionID string) error {
	var row models.StaffSubject
	err := tx.Where("school_id = ? AND academic_year_id = ? AND staff_id = ? AND subject_id = ? AND grade_id = ? AND section_id = ?", schoolID, academicYearID, staffID, subjectID, gradeID, sectionID).First(&row).Error
	if err == nil {
		if !row.IsPrimary {
			return tx.Model(&row).Update("is_primary", true).Error
		}
		return nil
	}
	if err != gorm.ErrRecordNotFound {
		return err
	}
	sectionIDCopy := sectionID
	return tx.Create(&models.StaffSubject{
		SchoolID:       schoolID,
		AcademicYearID: academicYearID,
		StaffID:        staffID,
		SubjectID:      subjectID,
		GradeID:        gradeID,
		SectionID:      &sectionIDCopy,
		IsPrimary:      true,
	}).Error
}

func ensureNoPrePrimaryStaffConflicts(tx *gorm.DB, staffID, academicYearID, sectionID string, preset []prePrimaryScheduleSlot) error {
	for day := 1; day <= 5; day++ {
		for index := range preset {
			var count int64
			if err := tx.Model(&models.TimetableSlot{}).
				Where("staff_id = ? AND academic_year_id = ? AND day_of_week = ? AND period_number = ? AND section_id <> ?", staffID, academicYearID, day, index+1, sectionID).
				Count(&count).Error; err != nil {
				return err
			}
			if count > 0 {
				return fmt.Errorf("teacher already has another class during %s period %d", prePrimaryDayLabel(day), index+1)
			}
		}
	}
	return nil
}

func prePrimarySubjectCode(subjectName string) string {
	parts := strings.FieldsFunc(strings.ToUpper(subjectName), func(r rune) bool {
		return r < 'A' || r > 'Z'
	})
	code := "PP"
	for _, part := range parts {
		if part == "" {
			continue
		}
		code += string(part[0])
	}
	if len(code) > 12 {
		return code[:12]
	}
	return code
}

func prePrimaryDayLabel(day int) string {
	switch day {
	case 1:
		return "Monday"
	case 2:
		return "Tuesday"
	case 3:
		return "Wednesday"
	case 4:
		return "Thursday"
	case 5:
		return "Friday"
	default:
		return fmt.Sprintf("day %d", day)
	}
}

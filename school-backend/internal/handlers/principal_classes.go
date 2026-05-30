package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

const principalClassInstructionsResource = "principal/class-instructions"

type PrincipalClassesHandler struct{}

func NewPrincipalClassesHandler() *PrincipalClassesHandler {
	return &PrincipalClassesHandler{}
}

type principalSectionCount struct {
	SectionID string `json:"section_id"`
	Count     int64  `json:"count"`
}

type principalAttendanceMetric struct {
	SectionID string  `json:"section_id"`
	Present   float64 `json:"present"`
	Marked    float64 `json:"marked"`
	Sessions  int64   `json:"sessions"`
}

type principalFeeDueMetric struct {
	SectionID string  `json:"section_id"`
	Students  int64   `json:"students"`
	Balance   float64 `json:"balance"`
}

type principalTrendMetric struct {
	Day      string  `json:"day"`
	Present  float64 `json:"present"`
	Marked   float64 `json:"marked"`
	Sessions int64   `json:"sessions"`
}

type principalClassSetupRequest struct {
	GradeID                string                         `json:"grade_id"`
	GradeName              string                         `json:"grade_name"`
	GradeNumber            int                            `json:"grade_number"`
	AcademicYearID         string                         `json:"academic_year_id"`
	SectionName            string                         `json:"section_name"`
	Capacity               int                            `json:"capacity"`
	ClassTeacherID         string                         `json:"class_teacher_id"`
	FeeItems               []principalClassFeeItem        `json:"fee_items"`
	SubjectMappings        []principalClassSubjectMapping `json:"subject_mappings"`
	DeletedFeeStructureIDs []string                       `json:"deleted_fee_structure_ids"`
	DeletedGradeSubjectIDs []string                       `json:"deleted_grade_subject_ids"`
	DeletedStaffSubjectIDs []string                       `json:"deleted_staff_subject_ids"`
}

type principalClassFeeItem struct {
	ID             string  `json:"id"`
	FeeCategoryID  string  `json:"fee_category_id"`
	CategoryName   string  `json:"category_name"`
	Frequency      string  `json:"frequency"`
	Amount         float64 `json:"amount"`
	DueDay         int     `json:"due_day"`
	LateFinePerDay float64 `json:"late_fine_per_day"`
	Delete         bool    `json:"delete"`
}

type principalClassSubjectMapping struct {
	SubjectID      string `json:"subject_id"`
	SubjectName    string `json:"subject_name"`
	SubjectCode    string `json:"subject_code"`
	SubjectType    string `json:"subject_type"`
	DepartmentID   string `json:"department_id"`
	DepartmentName string `json:"department_name"`
	GradeSubjectID string `json:"grade_subject_id"`
	StaffSubjectID string `json:"staff_subject_id"`
	TeacherID      string `json:"teacher_id"`
	PeriodsPerWeek int    `json:"periods_per_week"`
	MaxMarks       int    `json:"max_marks"`
	PassMarks      int    `json:"pass_marks"`
	IsMandatory    *bool  `json:"is_mandatory"`
	IsPrimary      *bool  `json:"is_primary"`
	Delete         bool   `json:"delete"`
}

func (h *PrincipalClassesHandler) Overview(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	now := time.Now()
	todayStart, todayEnd := dayRange(now)
	trendStart := todayStart.AddDate(0, 0, -6)

	var sections []models.Section
	if err := database.DB.
		Preload("Grade").
		Preload("ClassTeacher").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ?", schoolID).
		Order("grades.grade_number ASC, sections.section_name ASC").
		Find(&sections).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load principal classes")
		return
	}

	studentCounts := sectionCountMap(`
		SELECT current_section_id AS section_id, COUNT(*) AS count
		FROM students
		WHERE school_id = ? AND status != 'inactive' AND current_section_id IS NOT NULL
		GROUP BY current_section_id
	`, schoolID)

	todayAttendance := attendanceMetricMap(todayStart, todayEnd, schoolID)
	recentAttendance := attendanceMetricMap(trendStart, todayEnd, schoolID)
	homeworkPending := sectionCountMap(`
		SELECT section_id, COUNT(*) AS count
		FROM homework
		WHERE school_id = ? AND status NOT IN ('completed', 'reviewed', 'closed')
		GROUP BY section_id
	`, schoolID)
	weakPerformance := sectionCountMap(`
		SELECT enrollments.section_id AS section_id, COUNT(DISTINCT student_marks.student_id) AS count
		FROM student_marks
		JOIN enrollments ON enrollments.id = student_marks.enrollment_id
		JOIN students ON students.id = student_marks.student_id
		WHERE students.school_id = ? AND student_marks.is_absent = false AND student_marks.marks_obtained < 40
		GROUP BY enrollments.section_id
	`, schoolID)
	feeDues := feeDueMetricMap(schoolID)
	disciplineCounts, complaintCounts := issueCountsFromFrontendRecords(schoolID)
	recentInstructions := recentClassInstructions(schoolID)

	classCards := make([]gin.H, 0, len(sections))
	totalStudents := int64(0)
	totalIssues := int64(0)
	for _, section := range sections {
		sectionID := section.ID
		className := principalClassLabel(section)
		teacherName := principalTeacherName(section.ClassTeacher)
		students := studentCounts[sectionID]
		totalStudents += students
		today := todayAttendance[sectionID]
		recent := recentAttendance[sectionID]
		fees := feeDues[sectionID]
		discipline := disciplineCounts[sectionID]
		complaints := complaintCounts[sectionID]
		pendingIssues := homeworkPending[sectionID] + fees.Students + discipline + complaints
		totalIssues += pendingIssues

		classCards = append(classCards, gin.H{
			"section_id":             sectionID,
			"grade_id":               section.GradeID,
			"academic_year_id":       section.AcademicYearID,
			"class_name":             className,
			"section_name":           section.SectionName,
			"grade_name":             principalGradeName(section.Grade),
			"grade_number":           principalGradeNumber(section.Grade),
			"class_teacher_id":       section.ClassTeacherID,
			"class_teacher":          teacherName,
			"total_students":         students,
			"capacity":               section.Capacity,
			"attendance_percent":     attendancePercent(recent.Present, recent.Marked),
			"today_attendance_pct":   attendancePercent(today.Present, today.Marked),
			"today_status":           todayStatus(today),
			"today_present":          today.Present,
			"today_marked":           today.Marked,
			"attendance_sessions":    today.Sessions,
			"homework_pending":       homeworkPending[sectionID],
			"fees_due_students":      fees.Students,
			"fees_due_amount":        fees.Balance,
			"weak_performance_count": weakPerformance[sectionID],
			"discipline_issues":      discipline,
			"complaints_open":        complaints,
			"pending_issues":         pendingIssues,
			"latest_instruction":     recentInstructions[sectionID],
		})
	}

	sort.SliceStable(classCards, func(i, j int) bool {
		left := classCards[i]["pending_issues"].(int64)
		right := classCards[j]["pending_issues"].(int64)
		if left == right {
			return classCards[i]["class_name"].(string) < classCards[j]["class_name"].(string)
		}
		return left > right
	})

	success(c, http.StatusOK, gin.H{
		"summary": gin.H{
			"total_classes":       len(sections),
			"total_students":      totalStudents,
			"average_attendance":  averageAttendance(recentAttendance),
			"classes_with_issues": countClassesWithIssues(classCards),
			"pending_issues":      totalIssues,
		},
		"classes": classCards,
		"analytics": gin.H{
			"attendance_trend":          attendanceTrend(trendStart, todayEnd, schoolID),
			"weak_performing_classes":   topClassMetric(classCards, "weak_performance_count"),
			"discipline_issues":         topClassMetric(classCards, "discipline_issues"),
			"fee_defaulters_by_class":   topClassMetric(classCards, "fees_due_students"),
			"homework_pending_by_class": topClassMetric(classCards, "homework_pending"),
		},
	}, "")
}

func (h *PrincipalClassesHandler) CreateClass(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	var req principalClassSetupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	gradeID := strings.TrimSpace(req.GradeID)
	gradeName := strings.TrimSpace(req.GradeName)
	sectionName := strings.TrimSpace(req.SectionName)
	academicYearID := strings.TrimSpace(req.AcademicYearID)
	classTeacherIDValue := strings.TrimSpace(req.ClassTeacherID)
	if gradeID == "" && gradeName == "" {
		fail(c, http.StatusBadRequest, "grade_name is required")
		return
	}
	if sectionName == "" {
		fail(c, http.StatusBadRequest, "section_name is required")
		return
	}
	if req.Capacity <= 0 {
		fail(c, http.StatusBadRequest, "capacity must be greater than zero")
		return
	}

	if !academicYearBelongsToSchool(academicYearID, schoolID) {
		fail(c, http.StatusBadRequest, "Academic year must belong to this school")
		return
	}
	var classTeacherID *string
	if classTeacherIDValue != "" {
		var staff models.Staff
		if err := database.DB.First(&staff, "id = ? AND school_id = ? AND status = ?", classTeacherIDValue, schoolID, "active").Error; err != nil {
			fail(c, http.StatusBadRequest, "Class teacher must be active staff in this school")
			return
		}
		classTeacherID = &classTeacherIDValue
	}

	var grade models.Grade
	var section models.Section
	var setup gin.H
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		var err error
		grade, err = h.resolveClassGrade(tx, schoolID, gradeID, gradeName, req.GradeNumber)
		if err != nil {
			return err
		}
		var existingSection models.Section
		err = tx.
			Where("grade_id = ? AND academic_year_id = ? AND LOWER(section_name) = ?", grade.ID, academicYearID, strings.ToLower(sectionName)).
			First(&existingSection).Error
		if err == nil {
			return errors.New("class section already exists for this grade and academic year")
		}
		if err != gorm.ErrRecordNotFound {
			return err
		}
		section = models.Section{
			GradeID:        grade.ID,
			AcademicYearID: academicYearID,
			SectionName:    sectionName,
			Capacity:       req.Capacity,
			ClassTeacherID: classTeacherID,
		}
		if err := tx.Create(&section).Error; err != nil {
			return err
		}
		if err := h.applyClassSetupBundle(tx, schoolID, &section, req); err != nil {
			return err
		}
		if err := tx.Preload("Grade").Preload("ClassTeacher").First(&section, "id = ?", section.ID).Error; err != nil {
			return err
		}
		setup = h.classSetupResponse(tx, schoolID, section)
		return nil
	}); err != nil {
		fail(c, principalClassSetupStatus(err), err.Error())
		return
	}

	auditAction(c, "principal/classes", "create", "sections", &section.ID)
	response := gin.H{
		"grade":   grade,
		"section": section,
	}
	for key, value := range setup {
		response[key] = value
	}
	success(c, http.StatusCreated, response, "Class created successfully")
}

func (h *PrincipalClassesHandler) UpdateClassSetup(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	sectionID := strings.TrimSpace(c.Param("section_id"))
	if sectionID == "" {
		fail(c, http.StatusBadRequest, "section_id is required")
		return
	}

	var req principalClassSetupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	var section models.Section
	if err := database.DB.
		Preload("Grade").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("sections.id = ? AND grades.school_id = ?", sectionID, schoolID).
		First(&section).Error; err != nil {
		fail(c, http.StatusNotFound, "Class section not found")
		return
	}

	academicYearID := strings.TrimSpace(req.AcademicYearID)
	if academicYearID == "" {
		academicYearID = section.AcademicYearID
	}
	if !academicYearBelongsToSchool(academicYearID, schoolID) {
		fail(c, http.StatusBadRequest, "Academic year must belong to this school")
		return
	}
	sectionName := strings.TrimSpace(req.SectionName)
	if sectionName == "" {
		sectionName = section.SectionName
	}
	capacity := req.Capacity
	if capacity <= 0 {
		capacity = section.Capacity
	}
	if capacity <= 0 {
		fail(c, http.StatusBadRequest, "capacity must be greater than zero")
		return
	}
	classTeacherIDValue := strings.TrimSpace(req.ClassTeacherID)
	var classTeacherID *string
	if classTeacherIDValue != "" {
		var staff models.Staff
		if err := database.DB.First(&staff, "id = ? AND school_id = ? AND status = ?", classTeacherIDValue, schoolID, "active").Error; err != nil {
			fail(c, http.StatusBadRequest, "Class teacher must be active staff in this school")
			return
		}
		classTeacherID = &classTeacherIDValue
	}

	var setup gin.H
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if strings.TrimSpace(req.GradeName) != "" || req.GradeNumber > 0 {
			var grade models.Grade
			if err := tx.First(&grade, "id = ? AND school_id = ?", section.GradeID, schoolID).Error; err != nil {
				return errors.New("Grade must belong to this school")
			}
			if strings.TrimSpace(req.GradeName) != "" {
				grade.GradeName = strings.TrimSpace(req.GradeName)
			}
			if req.GradeNumber > 0 {
				grade.GradeNumber = req.GradeNumber
			}
			if err := tx.Save(&grade).Error; err != nil {
				return err
			}
		}
		section.AcademicYearID = academicYearID
		section.SectionName = sectionName
		section.Capacity = capacity
		section.ClassTeacherID = classTeacherID
		if err := tx.Save(&section).Error; err != nil {
			return err
		}
		if err := h.applyClassSetupBundle(tx, schoolID, &section, req); err != nil {
			return err
		}
		if err := tx.Preload("Grade").Preload("ClassTeacher").First(&section, "id = ?", section.ID).Error; err != nil {
			return err
		}
		setup = h.classSetupResponse(tx, schoolID, section)
		return nil
	}); err != nil {
		fail(c, principalClassSetupStatus(err), err.Error())
		return
	}

	auditAction(c, "principal/classes", "update", "sections", &section.ID)
	response := gin.H{"section": section, "grade": section.Grade}
	for key, value := range setup {
		response[key] = value
	}
	success(c, http.StatusOK, response, "Class setup updated successfully")
}

func (h *PrincipalClassesHandler) applyClassSetupBundle(tx *gorm.DB, schoolID string, section *models.Section, req principalClassSetupRequest) error {
	if err := h.applyClassFeeItems(tx, schoolID, section, req.FeeItems, req.DeletedFeeStructureIDs); err != nil {
		return err
	}
	if err := h.applyClassSubjectMappings(tx, schoolID, section, req.SubjectMappings, req.DeletedGradeSubjectIDs, req.DeletedStaffSubjectIDs); err != nil {
		return err
	}
	return nil
}

func (h *PrincipalClassesHandler) resolveClassGrade(tx *gorm.DB, schoolID, gradeID, gradeName string, gradeNumber int) (models.Grade, error) {
	gradeID = strings.TrimSpace(gradeID)
	gradeName = strings.TrimSpace(gradeName)
	if gradeID != "" {
		var grade models.Grade
		if err := tx.First(&grade, "id = ? AND school_id = ?", gradeID, schoolID).Error; err != nil {
			return models.Grade{}, errors.New("Grade must belong to this school")
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
	if err != gorm.ErrRecordNotFound {
		return models.Grade{}, err
	}
	grade = models.Grade{
		SchoolID:    schoolID,
		GradeNumber: gradeNumber,
		GradeName:   gradeName,
	}
	if err := tx.Create(&grade).Error; err != nil {
		return models.Grade{}, err
	}
	return grade, nil
}

func (h *PrincipalClassesHandler) applyClassFeeItems(tx *gorm.DB, schoolID string, section *models.Section, items []principalClassFeeItem, deletedIDs []string) error {
	cleanDeleted := compactStrings(deletedIDs)
	if len(cleanDeleted) > 0 {
		if err := tx.
			Where("school_id = ? AND grade_id = ? AND academic_year_id = ? AND id IN ?", schoolID, section.GradeID, section.AcademicYearID, cleanDeleted).
			Delete(&models.FeeStructure{}).Error; err != nil {
			return fmt.Errorf("failed to delete removed fee setup rows: %w", err)
		}
	}

	for _, item := range items {
		structureID := strings.TrimSpace(item.ID)
		if item.Delete {
			if structureID != "" {
				if err := tx.
					Where("school_id = ? AND grade_id = ? AND academic_year_id = ? AND id = ?", schoolID, section.GradeID, section.AcademicYearID, structureID).
					Delete(&models.FeeStructure{}).Error; err != nil {
					return fmt.Errorf("failed to remove fee item: %w", err)
				}
			}
			continue
		}
		if item.Amount < 0 {
			return errors.New("fee amount cannot be negative")
		}
		if item.Amount == 0 && strings.TrimSpace(item.CategoryName) == "" && strings.TrimSpace(item.FeeCategoryID) == "" && structureID == "" {
			continue
		}
		categoryID, err := h.resolveClassFeeCategory(tx, schoolID, item)
		if err != nil {
			return err
		}
		if categoryID == "" {
			return errors.New("fee category is required")
		}
		dueDay := item.DueDay
		if dueDay <= 0 {
			dueDay = 10
		}
		var structure models.FeeStructure
		if structureID != "" {
			err = tx.First(&structure, "id = ? AND school_id = ? AND grade_id = ? AND academic_year_id = ?", structureID, schoolID, section.GradeID, section.AcademicYearID).Error
			if err != nil {
				return errors.New("fee structure not found for this class")
			}
		} else {
			err = tx.
				Where("school_id = ? AND academic_year_id = ? AND grade_id = ? AND fee_category_id = ?", schoolID, section.AcademicYearID, section.GradeID, categoryID).
				First(&structure).Error
			if err != nil && err != gorm.ErrRecordNotFound {
				return err
			}
		}
		structure.SchoolID = schoolID
		structure.AcademicYearID = section.AcademicYearID
		structure.GradeID = section.GradeID
		structure.FeeCategoryID = categoryID
		structure.Amount = item.Amount
		structure.DueDay = dueDay
		structure.LateFinePerDay = item.LateFinePerDay
		if structure.ID == "" {
			if err := tx.Create(&structure).Error; err != nil {
				return fmt.Errorf("failed to create fee structure: %w", err)
			}
		} else if err := tx.Save(&structure).Error; err != nil {
			return fmt.Errorf("failed to update fee structure: %w", err)
		}
	}
	return nil
}

func (h *PrincipalClassesHandler) resolveClassFeeCategory(tx *gorm.DB, schoolID string, item principalClassFeeItem) (string, error) {
	categoryID := strings.TrimSpace(item.FeeCategoryID)
	if categoryID != "" {
		var category models.FeeCategory
		if err := tx.First(&category, "id = ? AND school_id = ?", categoryID, schoolID).Error; err != nil {
			return "", errors.New("fee category must belong to this school")
		}
		return category.ID, nil
	}
	categoryName := strings.TrimSpace(item.CategoryName)
	if categoryName == "" {
		return "", nil
	}
	frequency := strings.ToLower(strings.TrimSpace(item.Frequency))
	if frequency == "" {
		frequency = "term"
	}
	var category models.FeeCategory
	err := tx.
		Where("school_id = ? AND LOWER(category_name) = ?", schoolID, strings.ToLower(categoryName)).
		First(&category).Error
	if err == nil {
		if frequency != "" && category.Frequency != frequency {
			category.Frequency = frequency
			if err := tx.Save(&category).Error; err != nil {
				return "", err
			}
		}
		return category.ID, nil
	}
	if err != gorm.ErrRecordNotFound {
		return "", err
	}
	category = models.FeeCategory{
		SchoolID:     schoolID,
		CategoryName: categoryName,
		Frequency:    frequency,
		IsRefundable: false,
	}
	if err := tx.Create(&category).Error; err != nil {
		return "", fmt.Errorf("failed to create fee category: %w", err)
	}
	return category.ID, nil
}

func (h *PrincipalClassesHandler) applyClassSubjectMappings(tx *gorm.DB, schoolID string, section *models.Section, mappings []principalClassSubjectMapping, deletedGradeSubjectIDs, deletedStaffSubjectIDs []string) error {
	cleanStaffDeleted := compactStrings(deletedStaffSubjectIDs)
	if len(cleanStaffDeleted) > 0 {
		if err := tx.
			Where("grade_id = ? AND (section_id = ? OR section_id IS NULL OR section_id = '') AND id IN ?", section.GradeID, section.ID, cleanStaffDeleted).
			Delete(&models.StaffSubject{}).Error; err != nil {
			return fmt.Errorf("failed to delete removed teacher subject rows: %w", err)
		}
	}
	cleanGradeDeleted := compactStrings(deletedGradeSubjectIDs)
	if len(cleanGradeDeleted) > 0 {
		if err := tx.
			Where("grade_id = ? AND id IN ?", section.GradeID, cleanGradeDeleted).
			Delete(&models.GradeSubject{}).Error; err != nil {
			return fmt.Errorf("failed to delete removed class subject rows: %w", err)
		}
	}

	for _, mapping := range mappings {
		if mapping.Delete {
			if err := h.deleteClassSubjectMapping(tx, section, mapping); err != nil {
				return err
			}
			continue
		}
		subject, err := h.resolveClassSubject(tx, schoolID, mapping)
		if err != nil {
			return err
		}
		if subject.ID == "" {
			continue
		}
		gradeSubject, err := h.upsertClassGradeSubject(tx, schoolID, section.GradeID, subject.ID, mapping)
		if err != nil {
			return err
		}
		if strings.TrimSpace(mapping.TeacherID) == "" {
			if strings.TrimSpace(mapping.StaffSubjectID) != "" {
				if err := h.deleteClassStaffSubject(tx, section, mapping.StaffSubjectID); err != nil {
					return err
				}
			}
			continue
		}
		if err := h.upsertClassStaffSubject(tx, schoolID, section, subject.ID, gradeSubject.GradeID, mapping); err != nil {
			return err
		}
	}
	return nil
}

func (h *PrincipalClassesHandler) deleteClassSubjectMapping(tx *gorm.DB, section *models.Section, mapping principalClassSubjectMapping) error {
	if strings.TrimSpace(mapping.StaffSubjectID) != "" {
		if err := h.deleteClassStaffSubject(tx, section, mapping.StaffSubjectID); err != nil {
			return err
		}
	}
	if strings.TrimSpace(mapping.GradeSubjectID) != "" {
		if err := tx.Delete(&models.GradeSubject{}, "id = ? AND grade_id = ?", strings.TrimSpace(mapping.GradeSubjectID), section.GradeID).Error; err != nil {
			return fmt.Errorf("failed to delete class subject: %w", err)
		}
	}
	return nil
}

func (h *PrincipalClassesHandler) deleteClassStaffSubject(tx *gorm.DB, section *models.Section, staffSubjectID string) error {
	id := strings.TrimSpace(staffSubjectID)
	if id == "" {
		return nil
	}
	if err := tx.
		Where("id = ? AND grade_id = ? AND (section_id = ? OR section_id IS NULL OR section_id = '')", id, section.GradeID, section.ID).
		Delete(&models.StaffSubject{}).Error; err != nil {
		return fmt.Errorf("failed to delete teacher assignment: %w", err)
	}
	return nil
}

func (h *PrincipalClassesHandler) resolveClassSubject(tx *gorm.DB, schoolID string, mapping principalClassSubjectMapping) (models.Subject, error) {
	subjectID := strings.TrimSpace(mapping.SubjectID)
	if subjectID != "" {
		var subject models.Subject
		if err := tx.First(&subject, "id = ? AND school_id = ?", subjectID, schoolID).Error; err != nil {
			return models.Subject{}, errors.New("subject must belong to this school")
		}
		return subject, nil
	}
	subjectName := strings.TrimSpace(mapping.SubjectName)
	if subjectName == "" {
		return models.Subject{}, nil
	}
	departmentID, err := resolvePrincipalAcademicDepartmentID(tx, schoolID, mapping.DepartmentID, mapping.DepartmentName)
	if err != nil {
		return models.Subject{}, fmt.Errorf("failed to resolve subject department: %w", err)
	}
	subjectType := strings.TrimSpace(mapping.SubjectType)
	if subjectType == "" {
		subjectType = "core"
	}
	var subject models.Subject
	query := tx.Where("school_id = ? AND LOWER(subject_name) = ?", schoolID, strings.ToLower(subjectName))
	if strings.TrimSpace(mapping.SubjectCode) != "" {
		query = tx.Where("school_id = ? AND LOWER(subject_code) = ?", schoolID, strings.ToLower(strings.TrimSpace(mapping.SubjectCode)))
	}
	err = query.First(&subject).Error
	if err == nil {
		subject.DepartmentID = departmentID
		subject.SubjectName = subjectName
		subject.SubjectCode = strings.TrimSpace(mapping.SubjectCode)
		subject.SubjectType = subjectType
		if err := tx.Save(&subject).Error; err != nil {
			return models.Subject{}, err
		}
		return subject, nil
	}
	if err != gorm.ErrRecordNotFound {
		return models.Subject{}, err
	}
	subject = models.Subject{
		SchoolID:     schoolID,
		DepartmentID: departmentID,
		SubjectName:  subjectName,
		SubjectCode:  strings.TrimSpace(mapping.SubjectCode),
		SubjectType:  subjectType,
	}
	if err := tx.Create(&subject).Error; err != nil {
		return models.Subject{}, fmt.Errorf("failed to create subject: %w", err)
	}
	return subject, nil
}

func (h *PrincipalClassesHandler) upsertClassGradeSubject(tx *gorm.DB, schoolID, gradeID, subjectID string, mapping principalClassSubjectMapping) (models.GradeSubject, error) {
	periodsPerWeek := mapping.PeriodsPerWeek
	if periodsPerWeek < 0 {
		return models.GradeSubject{}, errors.New("periods_per_week cannot be negative")
	}
	maxMarks := mapping.MaxMarks
	if maxMarks <= 0 {
		maxMarks = 100
	}
	passMarks := mapping.PassMarks
	if passMarks <= 0 {
		passMarks = 35
	}
	isMandatory := true
	if mapping.IsMandatory != nil {
		isMandatory = *mapping.IsMandatory
	}

	var gradeSubject models.GradeSubject
	gradeSubjectID := strings.TrimSpace(mapping.GradeSubjectID)
	if gradeSubjectID != "" {
		err := tx.
			Joins("JOIN grades ON grades.id = grade_subjects.grade_id").
			Where("grade_subjects.id = ? AND grade_subjects.grade_id = ? AND grades.school_id = ?", gradeSubjectID, gradeID, schoolID).
			First(&gradeSubject).Error
		if err != nil {
			return models.GradeSubject{}, errors.New("class subject mapping not found")
		}
	} else {
		err := tx.
			Joins("JOIN grades ON grades.id = grade_subjects.grade_id").
			Where("grades.school_id = ? AND grade_subjects.grade_id = ? AND grade_subjects.subject_id = ?", schoolID, gradeID, subjectID).
			First(&gradeSubject).Error
		if err != nil && err != gorm.ErrRecordNotFound {
			return models.GradeSubject{}, err
		}
	}
	gradeSubject.GradeID = gradeID
	gradeSubject.SubjectID = subjectID
	gradeSubject.PeriodsPerWeek = periodsPerWeek
	gradeSubject.MaxMarks = maxMarks
	gradeSubject.PassMarks = passMarks
	gradeSubject.IsMandatory = isMandatory
	if gradeSubject.ID == "" {
		if err := tx.Create(&gradeSubject).Error; err != nil {
			return models.GradeSubject{}, fmt.Errorf("failed to create class subject mapping: %w", err)
		}
	} else if err := tx.Save(&gradeSubject).Error; err != nil {
		return models.GradeSubject{}, fmt.Errorf("failed to update class subject mapping: %w", err)
	}
	return gradeSubject, nil
}

func (h *PrincipalClassesHandler) upsertClassStaffSubject(tx *gorm.DB, schoolID string, section *models.Section, subjectID, gradeID string, mapping principalClassSubjectMapping) error {
	teacherID := strings.TrimSpace(mapping.TeacherID)
	var staff models.Staff
	if err := tx.First(&staff, "id = ? AND school_id = ? AND status = ?", teacherID, schoolID, "active").Error; err != nil {
		return errors.New("teacher must be active staff in this school")
	}

	isPrimary := true
	if mapping.IsPrimary != nil {
		isPrimary = *mapping.IsPrimary
	}
	sectionID := section.ID
	var row models.StaffSubject
	staffSubjectID := strings.TrimSpace(mapping.StaffSubjectID)
	if staffSubjectID != "" {
		err := tx.
			Joins("JOIN staffs ON staffs.id = staff_subjects.staff_id").
			Where("staff_subjects.id = ? AND staff_subjects.grade_id = ? AND staffs.school_id = ?", staffSubjectID, gradeID, schoolID).
			First(&row).Error
		if err != nil {
			return errors.New("teacher subject assignment not found")
		}
	} else {
		err := tx.
			Joins("JOIN staffs ON staffs.id = staff_subjects.staff_id").
			Where("staffs.school_id = ? AND staff_subjects.subject_id = ? AND staff_subjects.grade_id = ? AND staff_subjects.section_id = ?", schoolID, subjectID, gradeID, sectionID).
			First(&row).Error
		if err != nil && err != gorm.ErrRecordNotFound {
			return err
		}
	}
	row.StaffID = teacherID
	row.SubjectID = subjectID
	row.GradeID = gradeID
	row.SectionID = &sectionID
	row.IsPrimary = isPrimary
	if row.ID == "" {
		if err := tx.Create(&row).Error; err != nil {
			return fmt.Errorf("failed to create teacher assignment: %w", err)
		}
	} else if err := tx.Save(&row).Error; err != nil {
		return fmt.Errorf("failed to update teacher assignment: %w", err)
	}
	return nil
}

func (h *PrincipalClassesHandler) classSetupResponse(tx *gorm.DB, schoolID string, section models.Section) gin.H {
	var feeStructures []models.FeeStructure
	_ = tx.
		Preload("FeeCategory").
		Preload("Grade").
		Preload("AcademicYear").
		Where("school_id = ? AND academic_year_id = ? AND grade_id = ?", schoolID, section.AcademicYearID, section.GradeID).
		Order("created_at ASC").
		Find(&feeStructures).Error

	var gradeSubjects []models.GradeSubject
	_ = tx.
		Preload("Subject").
		Joins("JOIN grades ON grades.id = grade_subjects.grade_id").
		Where("grades.school_id = ? AND grade_subjects.grade_id = ?", schoolID, section.GradeID).
		Order("grade_subjects.created_at ASC").
		Find(&gradeSubjects).Error

	var staffSubjects []models.StaffSubject
	_ = tx.
		Preload("Staff").
		Preload("Subject").
		Preload("Grade").
		Preload("Section").
		Joins("JOIN staffs ON staffs.id = staff_subjects.staff_id").
		Where("staffs.school_id = ? AND staff_subjects.grade_id = ? AND (staff_subjects.section_id = ? OR staff_subjects.section_id IS NULL OR staff_subjects.section_id = '')", schoolID, section.GradeID, section.ID).
		Order("staff_subjects.created_at ASC").
		Find(&staffSubjects).Error

	subjects := make([]models.Subject, 0, len(gradeSubjects))
	seen := map[string]bool{}
	for _, row := range gradeSubjects {
		if row.Subject != nil && !seen[row.Subject.ID] {
			subjects = append(subjects, *row.Subject)
			seen[row.Subject.ID] = true
		}
	}
	for _, row := range staffSubjects {
		if row.Subject != nil && !seen[row.Subject.ID] {
			subjects = append(subjects, *row.Subject)
			seen[row.Subject.ID] = true
		}
	}

	return gin.H{
		"fee_structures": feeStructures,
		"subjects":       subjects,
		"grade_subjects": gradeSubjects,
		"staff_subjects": staffSubjects,
	}
}

func resolvePrincipalAcademicDepartmentID(tx *gorm.DB, schoolID, departmentID, departmentName string) (string, error) {
	deptValue := strings.TrimSpace(departmentID)
	nameValue := strings.TrimSpace(departmentName)
	if nameValue == "" {
		nameValue = deptValue
	}
	if deptValue != "" {
		var existing models.Department
		if err := tx.First(&existing, "id = ? AND school_id = ?", deptValue, schoolID).Error; err == nil {
			return existing.ID, nil
		}
	}
	if nameValue == "" {
		nameValue = "Academics"
	}
	var dept models.Department
	err := tx.Where("school_id = ? AND LOWER(department_name) = ?", schoolID, strings.ToLower(nameValue)).First(&dept).Error
	if err == nil {
		return dept.ID, nil
	}
	if err != gorm.ErrRecordNotFound {
		return "", err
	}
	dept = models.Department{
		SchoolID:       schoolID,
		DepartmentName: nameValue,
		Description:    "Created from principal class setup",
	}
	if err := tx.Create(&dept).Error; err != nil {
		return "", err
	}
	return dept.ID, nil
}

func compactStrings(values []string) []string {
	result := make([]string, 0, len(values))
	seen := map[string]bool{}
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed == "" || seen[trimmed] {
			continue
		}
		seen[trimmed] = true
		result = append(result, trimmed)
	}
	return result
}

func principalClassSetupStatus(err error) int {
	if err == nil {
		return http.StatusInternalServerError
	}
	message := strings.ToLower(err.Error())
	switch {
	case strings.Contains(message, "already exists"):
		return http.StatusConflict
	case strings.Contains(message, "required"),
		strings.Contains(message, "must belong"),
		strings.Contains(message, "not found"),
		strings.Contains(message, "cannot be negative"),
		strings.Contains(message, "teacher must be active"),
		strings.Contains(message, "capacity"):
		return http.StatusBadRequest
	default:
		return http.StatusInternalServerError
	}
}

func (h *PrincipalClassesHandler) CreateInstruction(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	sectionID := strings.TrimSpace(c.Param("section_id"))
	if sectionID == "" {
		fail(c, http.StatusBadRequest, "section_id is required")
		return
	}

	var section models.Section
	if err := database.DB.
		Preload("Grade").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("sections.id = ? AND grades.school_id = ?", sectionID, schoolID).
		First(&section).Error; err != nil {
		fail(c, http.StatusNotFound, "Class section not found")
		return
	}

	var req struct {
		Title       string `json:"title"`
		Message     string `json:"message" binding:"required"`
		Type        string `json:"type"`
		Priority    string `json:"priority"`
		SendNotice  bool   `json:"send_notice"`
		TargetRoute string `json:"target_route"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	message := strings.TrimSpace(req.Message)
	if message == "" {
		fail(c, http.StatusBadRequest, "message is required")
		return
	}
	instructionType := firstNonEmpty(strings.TrimSpace(req.Type), "instruction")
	priority := firstNonEmpty(strings.TrimSpace(req.Priority), "normal")
	title := firstNonEmpty(strings.TrimSpace(req.Title), "Principal instruction")
	className := principalClassLabel(section)
	payload := gin.H{
		"title":          title,
		"message":        message,
		"type":           instructionType,
		"priority":       priority,
		"status":         "open",
		"section_id":     section.ID,
		"grade_id":       section.GradeID,
		"class_name":     className,
		"created_by":     c.GetString("user_id"),
		"created_at":     time.Now().UTC().Format(time.RFC3339),
		"target_route":   firstNonEmpty(strings.TrimSpace(req.TargetRoute), "/principal-classes-screen"),
		"notice_sent":    req.SendNotice,
		"principal_role": "supervision",
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid instruction payload")
		return
	}

	record := models.FrontendRecord{
		SchoolID:  schoolID,
		Resource:  principalClassInstructionsResource,
		Payload:   string(encoded),
		CreatedBy: c.GetString("user_id"),
	}
	if err := database.DB.Create(&record).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save class instruction")
		return
	}

	if req.SendNotice {
		announcement := models.Announcement{
			SchoolID:        schoolID,
			Title:           title,
			Content:         message,
			TargetAudience:  "class",
			TargetGradeID:   &section.GradeID,
			TargetSectionID: &section.ID,
			IsUrgent:        strings.EqualFold(priority, "urgent"),
			CreatedBy:       c.GetString("user_id"),
			PublishedAt:     time.Now(),
		}
		if err := database.DB.Create(&announcement).Error; err != nil {
			fail(c, http.StatusInternalServerError, "Instruction saved but notice could not be published")
			return
		}
		payload["announcement_id"] = announcement.ID
	}

	auditAction(c, "principal/classes", "instruction", "frontend_records", &record.ID)
	response := frontendRecordResponse(record)
	for key, value := range payload {
		response[key] = value
	}
	success(c, http.StatusCreated, response, "Class instruction saved")
}

func sectionCountMap(query string, schoolID string) map[string]int64 {
	var rows []principalSectionCount
	_ = database.DB.Raw(query, schoolID).Scan(&rows).Error
	result := map[string]int64{}
	for _, row := range rows {
		if strings.TrimSpace(row.SectionID) == "" {
			continue
		}
		result[row.SectionID] = row.Count
	}
	return result
}

func attendanceMetricMap(start, end time.Time, schoolID string) map[string]principalAttendanceMetric {
	var rows []principalAttendanceMetric
	_ = database.DB.Raw(`
		SELECT attendance_sessions.section_id AS section_id,
			COALESCE(SUM(attendance_sessions.present_count), 0) AS present,
			COALESCE(SUM(attendance_sessions.total_students), 0) AS marked,
			COUNT(*) AS sessions
		FROM attendance_sessions
		JOIN sections ON sections.id = attendance_sessions.section_id
		JOIN grades ON grades.id = sections.grade_id
		WHERE grades.school_id = ? AND attendance_sessions.date >= ? AND attendance_sessions.date < ?
		GROUP BY attendance_sessions.section_id
	`, schoolID, start, end).Scan(&rows).Error
	result := map[string]principalAttendanceMetric{}
	for _, row := range rows {
		result[row.SectionID] = row
	}
	return result
}

func feeDueMetricMap(schoolID string) map[string]principalFeeDueMetric {
	var rows []principalFeeDueMetric
	_ = database.DB.Raw(`
		SELECT students.current_section_id AS section_id,
			COUNT(DISTINCT students.id) AS students,
			COALESCE(SUM(fee_invoices.balance), 0) AS balance
		FROM fee_invoices
		JOIN students ON students.id = fee_invoices.student_id
		WHERE students.school_id = ? AND students.current_section_id IS NOT NULL AND fee_invoices.balance > 0
		GROUP BY students.current_section_id
	`, schoolID).Scan(&rows).Error
	result := map[string]principalFeeDueMetric{}
	for _, row := range rows {
		result[row.SectionID] = row
	}
	return result
}

func issueCountsFromFrontendRecords(schoolID string) (map[string]int64, map[string]int64) {
	discipline := map[string]int64{}
	complaints := map[string]int64{}
	var rows []models.FrontendRecord
	_ = database.DB.
		Where("school_id = ? AND resource IN ?", schoolID, []string{"discipline-incidents", "complaints"}).
		Find(&rows).Error
	for _, row := range rows {
		payload := frontendPayload(row.Payload)
		status := strings.ToLower(firstNonEmpty(stringMapValue(payload["status"]), "open"))
		if status == "closed" || status == "resolved" || status == "dismissed" {
			continue
		}
		sectionID := firstNonEmpty(
			stringMapValue(payload["section_id"]),
			stringMapValue(payload["class_section_id"]),
			stringMapValue(payload["target_section_id"]),
		)
		if strings.TrimSpace(sectionID) == "" {
			continue
		}
		if row.Resource == "discipline-incidents" {
			discipline[sectionID]++
		} else {
			complaints[sectionID]++
		}
	}
	return discipline, complaints
}

func recentClassInstructions(schoolID string) map[string]gin.H {
	var rows []models.FrontendRecord
	_ = database.DB.
		Where("school_id = ? AND resource = ?", schoolID, principalClassInstructionsResource).
		Order("created_at DESC").
		Limit(100).
		Find(&rows).Error
	result := map[string]gin.H{}
	for _, row := range rows {
		payload := frontendRecordResponse(row)
		sectionID := stringMapValue(payload["section_id"])
		if sectionID == "" {
			continue
		}
		if _, exists := result[sectionID]; !exists {
			result[sectionID] = payload
		}
	}
	return result
}

func attendanceTrend(start, end time.Time, schoolID string) []gin.H {
	var rows []principalTrendMetric
	_ = database.DB.Raw(`
		SELECT DATE(attendance_sessions.date) AS day,
			COALESCE(SUM(attendance_sessions.present_count), 0) AS present,
			COALESCE(SUM(attendance_sessions.total_students), 0) AS marked,
			COUNT(*) AS sessions
		FROM attendance_sessions
		JOIN sections ON sections.id = attendance_sessions.section_id
		JOIN grades ON grades.id = sections.grade_id
		WHERE grades.school_id = ? AND attendance_sessions.date >= ? AND attendance_sessions.date < ?
		GROUP BY DATE(attendance_sessions.date)
		ORDER BY DATE(attendance_sessions.date) ASC
	`, schoolID, start, end).Scan(&rows).Error
	byDay := map[string]principalTrendMetric{}
	for _, row := range rows {
		byDay[row.Day] = row
	}
	result := make([]gin.H, 0, 7)
	for cursor := start; cursor.Before(end); cursor = cursor.AddDate(0, 0, 1) {
		key := cursor.Format("2006-01-02")
		row := byDay[key]
		result = append(result, gin.H{
			"label":      cursor.Format("Mon"),
			"date":       key,
			"percentage": attendancePercent(row.Present, row.Marked),
			"sessions":   row.Sessions,
		})
	}
	return result
}

func topClassMetric(classCards []gin.H, key string) []gin.H {
	rows := make([]gin.H, 0, len(classCards))
	for _, card := range classCards {
		value, ok := card[key].(int64)
		if !ok || value <= 0 {
			continue
		}
		rows = append(rows, gin.H{
			"class_name": card["class_name"],
			"value":      value,
		})
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return rows[i]["value"].(int64) > rows[j]["value"].(int64)
	})
	if len(rows) > 5 {
		return rows[:5]
	}
	return rows
}

func principalClassLabel(section models.Section) string {
	gradeName := principalGradeName(section.Grade)
	sectionName := strings.TrimSpace(section.SectionName)
	if gradeName == "" {
		gradeName = "Class"
	}
	if sectionName == "" {
		return gradeName
	}
	return gradeName + " - " + sectionName
}

func principalGradeName(grade *models.Grade) string {
	if grade == nil {
		return ""
	}
	return firstNonEmpty(strings.TrimSpace(grade.GradeName), "Grade")
}

func principalGradeNumber(grade *models.Grade) int {
	if grade == nil {
		return 0
	}
	return grade.GradeNumber
}

func principalTeacherName(staff *models.Staff) string {
	if staff == nil {
		return "Not assigned"
	}
	name := strings.TrimSpace(staff.FirstName + " " + staff.LastName)
	return firstNonEmpty(name, strings.TrimSpace(staff.Email), "Not assigned")
}

func attendancePercent(present, marked float64) float64 {
	if marked <= 0 {
		return 0
	}
	return (present / marked) * 100
}

func todayStatus(metric principalAttendanceMetric) string {
	if metric.Sessions == 0 {
		return "Not marked"
	}
	pct := attendancePercent(metric.Present, metric.Marked)
	if metric.Marked <= 0 {
		return "No students marked"
	}
	if pct < 75 {
		return "Needs attention"
	}
	if pct < 90 {
		return "Review absentees"
	}
	return "On track"
}

func averageAttendance(metrics map[string]principalAttendanceMetric) float64 {
	var present float64
	var marked float64
	for _, row := range metrics {
		present += row.Present
		marked += row.Marked
	}
	return attendancePercent(present, marked)
}

func countClassesWithIssues(classCards []gin.H) int {
	count := 0
	for _, card := range classCards {
		if value, ok := card["pending_issues"].(int64); ok && value > 0 {
			count++
		}
	}
	return count
}

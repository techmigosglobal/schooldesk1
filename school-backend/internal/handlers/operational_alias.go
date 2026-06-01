package handlers

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type OperationalAliasHandler struct{}

func NewOperationalAliasHandler() *OperationalAliasHandler {
	return &OperationalAliasHandler{}
}

func (h *OperationalAliasHandler) ListClasses(c *gin.Context) {
	var sections []models.Section
	query := database.DB.Preload("Grade").Preload("ClassTeacher")
	if yearID := c.Query("academic_year_id"); yearID != "" {
		query = query.Where("academic_year_id = ?", yearID)
	}
	if err := query.Find(&sections).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load classes")
		return
	}
	rows := make([]gin.H, 0, len(sections))
	for _, section := range sections {
		rows = append(rows, classResponse(section))
	}
	success(c, http.StatusOK, rows, "")
}

func (h *OperationalAliasHandler) CreateClass(c *gin.Context) {
	var req struct {
		Name           string `json:"name" binding:"required"`
		Section        string `json:"section"`
		ClassTeacherID string `json:"class_teacher_id"`
		AcademicYearID string `json:"academic_year_id" binding:"required"`
		GradeID        string `json:"grade_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	gradeID := req.GradeID
	if gradeID == "" {
		grade := models.Grade{SchoolID: scopedSchoolID(c), GradeName: req.Name}
		_ = database.DB.Where("school_id = ? AND grade_name = ?", scopedSchoolID(c), req.Name).FirstOrCreate(&grade).Error
		gradeID = grade.ID
	}
	sectionName := req.Section
	if sectionName == "" {
		sectionName = "A"
	}
	row := models.Section{GradeID: gradeID, AcademicYearID: req.AcademicYearID, SectionName: sectionName}
	if req.ClassTeacherID != "" {
		row.ClassTeacherID = &req.ClassTeacherID
	}
	if err := database.DB.Create(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create class")
		return
	}
	row.Grade = &models.Grade{GradeName: req.Name}
	auditAction(c, "classes", "create", "sections", &row.ID)
	success(c, http.StatusCreated, classResponse(row), "Class created successfully")
}

func (h *OperationalAliasHandler) GetClass(c *gin.Context) {
	var row models.Section
	if err := database.DB.Preload("Grade").Preload("ClassTeacher").First(&row, "id = ?", c.Param("id")).Error; err != nil {
		fail(c, http.StatusNotFound, "Class not found")
		return
	}
	success(c, http.StatusOK, classResponse(row), "")
}

func (h *OperationalAliasHandler) PatchClass(c *gin.Context) {
	id := c.Param("id")
	var payload map[string]interface{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	updates := map[string]interface{}{}
	if section, ok := payload["section"]; ok {
		updates["section_name"] = section
	}
	if yearID, ok := payload["academic_year_id"]; ok {
		updates["academic_year_id"] = yearID
	}
	if teacherID, ok := payload["class_teacher_id"]; ok {
		updates["class_teacher_id"] = teacherID
	}
	if result := database.DB.Model(&models.Section{}).Where("id = ?", id).Updates(updates); result.Error != nil {
		fail(c, http.StatusInternalServerError, "Failed to update class")
		return
	} else if result.RowsAffected == 0 {
		fail(c, http.StatusNotFound, "Class not found")
		return
	}
	auditAction(c, "classes", "update", "sections", &id)
	h.GetClass(c)
}

func (h *OperationalAliasHandler) DeleteClass(c *gin.Context) {
	id := c.Param("id")
	if err := database.DB.Delete(&models.Section{}, "id = ?", id).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to delete class")
		return
	}
	auditAction(c, "classes", "delete", "sections", &id)
	success(c, http.StatusOK, gin.H{"id": id}, "Class deleted successfully")
}

func (h *OperationalAliasHandler) GetClassStudents(c *gin.Context) {
	var students []models.Student
	if err := database.DB.Where("current_section_id = ? AND school_id = ?", c.Param("id"), scopedSchoolID(c)).Find(&students).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load class students")
		return
	}
	success(c, http.StatusOK, students, "")
}

func (h *OperationalAliasHandler) CreateStudent(c *gin.Context) {
	var req struct {
		UserID          string `json:"user_id"`
		ParentID        string `json:"parent_id"`
		FirstName       string `json:"first_name" binding:"required"`
		LastName        string `json:"last_name" binding:"required"`
		RollNumber      string `json:"roll_number"`
		StudentCode     string `json:"student_code"`
		AdmissionNumber string `json:"admission_number"`
		ClassID         string `json:"class_id"`
		CurrentSection  string `json:"current_section_id"`
		DOB             string `json:"dob"`
		DateOfBirth     string `json:"date_of_birth"`
		Gender          string `json:"gender"`
		Address         string `json:"address"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	dob, err := parseDate(firstNonEmpty(req.DOB, req.DateOfBirth))
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid date format. Use YYYY-MM-DD")
		return
	}
	sectionID := firstNonEmpty(req.ClassID, req.CurrentSection)
	studentCode := firstNonEmpty(req.StudentCode, req.RollNumber, "STU-"+uuid.NewString()[:8])
	admissionNumber := firstNonEmpty(req.AdmissionNumber, studentCode)
	student := models.Student{
		SchoolID:        scopedSchoolID(c),
		UserID:          req.UserID,
		ParentID:        req.ParentID,
		StudentCode:     studentCode,
		AdmissionNumber: admissionNumber,
		FirstName:       req.FirstName,
		LastName:        req.LastName,
		DateOfBirth:     dob,
		Gender:          firstNonEmpty(req.Gender, "not_specified"),
		AdmissionDate:   time.Now().UTC(),
		Address:         req.Address,
		Status:          "active",
	}
	if sectionID != "" {
		student.CurrentSectionID = &sectionID
	}
	if err := database.DB.Create(&student).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create student")
		return
	}
	if sectionID != "" {
		yearID, _ := currentAcademicContext(scopedSchoolID(c))
		enrollment := models.Enrollment{
			StudentID:      student.ID,
			SectionID:      sectionID,
			AcademicYearID: yearID,
			RollNumber:     req.RollNumber,
			EnrollmentDate: time.Now().UTC(),
			Status:         "enrolled",
		}
		_ = database.DB.Create(&enrollment).Error
	}
	auditAction(c, "students", "create", "students", &student.ID)
	success(c, http.StatusCreated, student, "Student created successfully")
}

func (h *OperationalAliasHandler) GetStudentGrades(c *gin.Context) {
	studentID := c.Param("id")
	if !canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	var marks []models.StudentMark
	query := database.DB.Where("student_id = ?", studentID).Preload("ExamSchedule").Preload("ExamSchedule.Subject")
	if err := query.Find(&marks).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load grades")
		return
	}
	success(c, http.StatusOK, marks, "")
}

func (h *OperationalAliasHandler) MarkAttendance(c *gin.Context) {
	var req struct {
		ClassID    string `json:"class_id" binding:"required"`
		SubjectID  string `json:"subject_id"`
		TeacherID  string `json:"teacher_id"`
		Date       string `json:"date" binding:"required"`
		Attendance []struct {
			StudentID    string `json:"student_id" binding:"required"`
			EnrollmentID string `json:"enrollment_id"`
			Status       string `json:"status" binding:"required"`
			Reason       string `json:"reason"`
		} `json:"attendance" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	date, err := parseDate(req.Date)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid date format. Use YYYY-MM-DD")
		return
	}
	subjectID := firstNonEmpty(req.SubjectID, "compat-subject")
	staffID := firstNonEmpty(req.TeacherID, c.GetString("linked_id"), c.GetString("user_id"))
	yearID, _ := currentAcademicContext(scopedSchoolID(c))
	session := models.AttendanceSession{
		SectionID:      req.ClassID,
		AcademicYearID: yearID,
		SubjectID:      subjectID,
		StaffID:        staffID,
		Date:           date,
		PeriodNumber:   1,
		TotalStudents:  len(req.Attendance),
	}
	markedBy := c.GetString("user_id")
	now := time.Now().UTC()
	for _, row := range req.Attendance {
		if strings.EqualFold(row.Status, "present") || strings.EqualFold(row.Status, "late") {
			session.PresentCount++
		}
	}
	if err := database.DB.Create(&session).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create attendance session")
		return
	}
	for _, row := range req.Attendance {
		enrollmentID := row.EnrollmentID
		if enrollmentID == "" {
			enrollmentID = lookupEnrollment(row.StudentID)
		}
		attendance := models.StudentAttendance{
			SessionID:    session.ID,
			StudentID:    row.StudentID,
			EnrollmentID: enrollmentID,
			Status:       normalizeAttendanceStatus(row.Status),
			Reason:       row.Reason,
			MarkedAt:     now,
			MarkedBy:     &markedBy,
		}
		_ = database.DB.Create(&attendance).Error
	}
	auditAction(c, "attendance", "create", "student_attendances", &session.ID)
	success(c, http.StatusCreated, session, "Attendance marked successfully")
}

func (h *OperationalAliasHandler) GetClassAttendance(c *gin.Context) {
	date := c.Query("date")
	var rows []models.AttendanceSession
	query := database.DB.Where("section_id = ?", c.Param("classId")).Preload("StudentAttendances")
	if date != "" {
		parsed, err := parseDate(date)
		if err != nil {
			fail(c, http.StatusBadRequest, "Invalid date format. Use YYYY-MM-DD")
			return
		}
		query = query.Where("date >= ? AND date < ?", parsed, parsed.AddDate(0, 0, 1))
	}
	if err := query.Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load attendance")
		return
	}
	success(c, http.StatusOK, rows, "")
}

func (h *OperationalAliasHandler) GetStudentAttendance(c *gin.Context) {
	studentID := c.Param("studentId")
	if !canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	var rows []models.StudentAttendance
	query := database.DB.Where("student_id = ?", studentID).Preload("Session")
	if start, end, ok := monthYearRange(c.Query("month"), c.Query("year")); ok {
		query = query.Where("marked_at >= ? AND marked_at < ?", start, end)
	}
	if err := query.Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load attendance")
		return
	}
	success(c, http.StatusOK, rows, "")
}

func (h *OperationalAliasHandler) GetAttendanceSummary(c *gin.Context) {
	studentID := c.Query("student_id")
	if studentID == "" {
		fail(c, http.StatusBadRequest, "student_id is required")
		return
	}
	if !canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	var total int64
	var present int64
	if err := database.DB.Model(&models.StudentAttendance{}).Where("student_id = ?", studentID).Count(&total).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load attendance summary")
		return
	}
	if err := database.DB.Model(&models.StudentAttendance{}).
		Where("student_id = ? AND LOWER(status) IN ?", studentID, []string{"present", "late"}).
		Count(&present).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load attendance summary")
		return
	}
	percentage := 0.0
	if total > 0 {
		percentage = (float64(present) / float64(total)) * 100
	}
	success(c, http.StatusOK, gin.H{
		"student_id":            studentID,
		"total_days":            total,
		"present_days":          present,
		"absent_days":           total - present,
		"attendance_percentage": percentage,
		"percentage":            percentage,
	}, "")
}

func (h *OperationalAliasHandler) PatchAttendance(c *gin.Context) {
	var req struct {
		Status string `json:"status" binding:"required"`
		Reason string `json:"reason"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	updates := map[string]interface{}{"status": normalizeAttendanceStatus(req.Status)}
	if req.Reason != "" {
		updates["reason"] = req.Reason
	}
	if err := database.DB.Model(&models.StudentAttendance{}).Where("id = ?", c.Param("id")).Updates(updates).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update attendance")
		return
	}
	success(c, http.StatusOK, gin.H{"id": c.Param("id")}, "Attendance updated successfully")
}

func (h *OperationalAliasHandler) GetClassTimetable(c *gin.Context) {
	var rows []models.TimetableSlot
	if err := database.DB.
		Where("section_id = ?", c.Param("classId")).
		Preload("Subject").
		Preload("Staff").
		Order("day_of_week, period_number").
		Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load timetable")
		return
	}
	success(c, http.StatusOK, rows, "")
}

func (h *OperationalAliasHandler) GetTeacherTimetable(c *gin.Context) {
	var rows []models.TimetableSlot
	if err := database.DB.
		Where("staff_id = ?", c.Param("teacherId")).
		Preload("Subject").
		Preload("Section").
		Order("day_of_week, period_number").
		Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load timetable")
		return
	}
	success(c, http.StatusOK, rows, "")
}

func (h *OperationalAliasHandler) ListTimetable(c *gin.Context) {
	var rows []models.TimetableSlot
	query := database.DB.
		Model(&models.TimetableSlot{}).
		Joins("JOIN sections ON sections.id = timetable_slots.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Preload("Subject").
		Preload("Section").
		Preload("Staff")
	if schoolID := scopedSchoolID(c); schoolID != "" {
		query = query.Where("grades.school_id = ?", schoolID)
	}
	if sectionID := c.Query("section_id"); sectionID != "" {
		query = query.Where("timetable_slots.section_id = ?", sectionID)
	}
	if staffID := c.Query("staff_id"); staffID != "" {
		query = query.Where("timetable_slots.staff_id = ?", staffID)
	}
	if academicYearID := c.Query("academic_year_id"); academicYearID != "" {
		query = query.Where("timetable_slots.academic_year_id = ?", academicYearID)
	}
	if day := c.Query("day_of_week"); day != "" {
		query = query.Where("timetable_slots.day_of_week = ?", day)
	}
	if err := query.Order("timetable_slots.day_of_week, timetable_slots.period_number").Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load timetable")
		return
	}
	success(c, http.StatusOK, rows, "")
}

func (h *OperationalAliasHandler) CreateTimetable(c *gin.Context) {
	c.JSON(http.StatusConflict, gin.H{
		"error": "legacy timetable write routes are disabled",
		"use":   "POST/PUT/DELETE /api/v1/timetable/slots instead",
	})
}

func (h *OperationalAliasHandler) PatchTimetable(c *gin.Context) {
	c.JSON(http.StatusConflict, gin.H{
		"error": "legacy timetable write routes are disabled",
		"use":   "POST/PUT/DELETE /api/v1/timetable/slots instead",
	})
}

func (h *OperationalAliasHandler) DeleteTimetable(c *gin.Context) {
	c.JSON(http.StatusConflict, gin.H{
		"error": "legacy timetable write routes are disabled",
		"use":   "POST/PUT/DELETE /api/v1/timetable/slots instead",
	})
}

func (h *OperationalAliasHandler) BulkGrades(c *gin.Context) {
	schoolID := currentSchoolID(c)
	var req struct {
		ExamScheduleID string `json:"exam_schedule_id"`
		ScheduleID     string `json:"schedule_id"`
		Grades         []struct {
			StudentID     string  `json:"student_id" binding:"required"`
			EnrollmentID  string  `json:"enrollment_id"`
			Marks         float64 `json:"marks"`
			MarksObtained float64 `json:"marks_obtained"`
			GradeLabel    string  `json:"grade_label"`
		} `json:"grades" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	scheduleID := firstNonEmpty(req.ExamScheduleID, req.ScheduleID, "compat-schedule")
	created := make([]models.StudentMark, 0, len(req.Grades))
	rejected := make([]gin.H, 0)
	for _, row := range req.Grades {
		enrollmentID := firstNonEmpty(row.EnrollmentID, lookupEnrollment(row.StudentID))
		if !compatStudentEnrollmentInSchool(schoolID, row.StudentID, enrollmentID) {
			rejected = append(rejected, gin.H{"student_id": row.StudentID, "reason": "not in school"})
			continue
		}
		marks := row.MarksObtained
		if marks == 0 {
			marks = row.Marks
		}
		mark := models.StudentMark{
			ExamScheduleID: scheduleID,
			StudentID:      row.StudentID,
			EnrollmentID:   enrollmentID,
			MarksObtained:  marks,
			GradeLabel:     row.GradeLabel,
		}
		if err := database.DB.Create(&mark).Error; err != nil {
			fail(c, http.StatusInternalServerError, "Failed to create grade")
			return
		}
		created = append(created, mark)
	}
	success(c, http.StatusOK, gin.H{
		"inserted": len(created),
		"created":  created,
		"rejected": rejected,
	}, "Grades saved successfully")
}

func (h *OperationalAliasHandler) GetGradesByStudent(c *gin.Context) {
	c.Params = append(c.Params, gin.Param{Key: "id", Value: c.Param("studentId")})
	h.GetStudentGrades(c)
}

func (h *OperationalAliasHandler) GetGradesByClass(c *gin.Context) {
	schoolID := currentSchoolID(c)
	var marks []models.StudentMark
	query := database.DB.Joins("JOIN enrollments ON enrollments.student_id = student_marks.student_id").
		Joins("JOIN students s ON s.id = enrollments.student_id").
		Where("enrollments.section_id = ?", c.Param("classId")).
		Where("s.school_id = ?", schoolID).
		Preload("ExamSchedule").Preload("Student")
	if examType := c.Query("examType"); examType != "" {
		query = query.Joins("JOIN exam_schedules ON exam_schedules.id = student_marks.exam_schedule_id JOIN exams ON exams.id = exam_schedules.exam_id JOIN exam_types ON exam_types.id = exams.exam_type_id").
			Where("LOWER(exam_types.name) = ?", strings.ToLower(examType))
	}
	if err := query.Find(&marks).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load class grades")
		return
	}
	success(c, http.StatusOK, marks, "")
}

func (h *OperationalAliasHandler) PatchGrade(c *gin.Context) {
	schoolID := currentSchoolID(c)
	var req struct {
		MarksObtained float64 `json:"marks_obtained"`
		Marks         float64 `json:"marks"`
		GradeLabel    string  `json:"grade_label"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	updates := map[string]interface{}{}
	if req.MarksObtained != 0 {
		updates["marks_obtained"] = req.MarksObtained
	} else if req.Marks != 0 {
		updates["marks_obtained"] = req.Marks
	}
	if req.GradeLabel != "" {
		updates["grade_label"] = req.GradeLabel
	}
	var inSchool int64
	if err := database.DB.Model(&models.StudentMark{}).
		Joins("JOIN enrollments ON enrollments.id = student_marks.enrollment_id").
		Joins("JOIN students ON students.id = enrollments.student_id").
		Where("student_marks.id = ? AND student_marks.student_id = students.id AND students.school_id = ?", c.Param("id"), schoolID).
		Count(&inSchool).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to verify grade ownership")
		return
	}
	if inSchool == 0 {
		c.JSON(http.StatusForbidden, gin.H{"error": "student not in your school"})
		return
	}
	if err := database.DB.Model(&models.StudentMark{}).Where("id = ?", c.Param("id")).Updates(updates).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update grade")
		return
	}
	success(c, http.StatusOK, gin.H{"id": c.Param("id")}, "Grade updated successfully")
}

func compatStudentEnrollmentInSchool(schoolID, studentID, enrollmentID string) bool {
	if strings.TrimSpace(schoolID) == "" || strings.TrimSpace(studentID) == "" || strings.TrimSpace(enrollmentID) == "" {
		return false
	}
	return countRows(database.DB.Model(&models.Enrollment{}).
		Joins("JOIN students ON students.id = enrollments.student_id").
		Where("enrollments.id = ? AND enrollments.student_id = ? AND students.school_id = ?", enrollmentID, studentID, schoolID)) > 0
}

func (h *OperationalAliasHandler) ListExamSchedules(c *gin.Context) {
	var rows []models.ExamSchedule
	query := scopedExamScheduleQuery(c).
		Preload("Exam").
		Preload("Grade").
		Preload("Section").
		Preload("Subject")
	if examID := c.Query("exam_id"); examID != "" {
		query = query.Where("exam_schedules.exam_id = ?", examID)
	}
	if gradeID := c.Query("grade_id"); gradeID != "" {
		query = query.Where("exam_schedules.grade_id = ?", gradeID)
	}
	if sectionID := c.Query("section_id"); sectionID != "" {
		query = query.Where("exam_schedules.section_id = ?", sectionID)
	}
	switch currentRole(c) {
	case "admin", "principal":
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" {
			query = query.Where("1 = 0")
		} else {
			query = query.Where(`
				EXISTS (
					SELECT 1 FROM timetable_slots
					WHERE timetable_slots.section_id = exam_schedules.section_id
						AND timetable_slots.subject_id = exam_schedules.subject_id
						AND timetable_slots.staff_id = ?
				)
			`, staffID)
		}
	case "parent":
		query = query.Where("exam_schedules.section_id IN (?)", linkedSectionSubquery(c))
	default:
		query = query.Where("1 = 0")
	}
	if err := query.Order("exam_schedules.exam_date ASC, exam_schedules.start_time ASC").Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load exam schedules")
		return
	}
	success(c, http.StatusOK, rows, "")
}

func (h *OperationalAliasHandler) ListFees(c *gin.Context) {
	var rows []models.FeeInvoice
	if err := preloadFeeInvoiceDetails(scopedFeeInvoiceQuery(c)).
		Order("fee_invoices.due_date ASC, fee_invoices.created_at DESC").
		Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load fees")
		return
	}
	success(c, http.StatusOK, rows, "")
}

func (h *OperationalAliasHandler) AssignFee(c *gin.Context) {
	var req struct {
		StudentID string  `json:"student_id" binding:"required"`
		FeeType   string  `json:"fee_type"`
		Amount    float64 `json:"amount" binding:"required"`
		DueDate   string  `json:"due_date" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	if countRows(database.DB.Model(&models.Student{}).
		Where("id = ? AND school_id = ? AND status != ?", req.StudentID, scopedSchoolID(c), "inactive")) == 0 {
		fail(c, http.StatusBadRequest, "student does not belong to this school")
		return
	}
	due, err := parseDate(req.DueDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid due_date format. Use YYYY-MM-DD")
		return
	}
	yearID, _ := currentAcademicContext(scopedSchoolID(c))
	invoice := models.FeeInvoice{
		StudentID:      req.StudentID,
		AcademicYearID: yearID,
		InvoiceNumber:  "FEE-" + uuid.NewString(),
		InvoiceDate:    time.Now().UTC(),
		DueDate:        due,
		TotalAmount:    req.Amount,
		NetAmount:      req.Amount,
		Balance:        req.Amount,
		Status:         "pending",
	}
	if err := database.DB.Create(&invoice).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to assign fee")
		return
	}
	success(c, http.StatusCreated, invoice, "Fee assigned successfully")
}

func (h *OperationalAliasHandler) GetStudentFees(c *gin.Context) {
	studentID := c.Param("studentId")
	if !canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	var rows []models.FeeInvoice
	if err := database.DB.
		Joins("JOIN students ON students.id = fee_invoices.student_id").
		Where("fee_invoices.student_id = ? AND students.school_id = ? AND students.status != ?", studentID, scopedSchoolID(c), "inactive").
		Preload("Student").
		Preload("Student.CurrentSection").
		Preload("Student.CurrentSection.Grade").
		Preload("AcademicYear").
		Preload("Items").
		Preload("Items.FeeCategory").
		Preload("Payments").
		Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load student fees")
		return
	}
	success(c, http.StatusOK, rows, "")
}

func (h *OperationalAliasHandler) PayFee(c *gin.Context) {
	var req struct {
		Amount      float64 `json:"amount" binding:"required"`
		PaymentDate string  `json:"payment_date"`
		PaymentMode string  `json:"payment_mode"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	paymentDate := time.Now().UTC()
	if req.PaymentDate != "" {
		if parsed, err := parseDate(req.PaymentDate); err == nil {
			paymentDate = parsed
		}
	}
	invoiceID := c.Param("id")
	var invoice models.FeeInvoice
	if err := scopedFeeInvoiceQuery(c).First(&invoice, "fee_invoices.id = ?", invoiceID).Error; err != nil {
		fail(c, http.StatusNotFound, "Invoice not found")
		return
	}
	payment := models.Payment{
		InvoiceID:     invoiceID,
		ReceiptNumber: "RCPT-" + uuid.NewString(),
		AmountPaid:    req.Amount,
		PaymentDate:   paymentDate,
		PaymentMode:   firstNonEmpty(req.PaymentMode, "cash"),
	}
	if err := database.DB.Create(&payment).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to record payment")
		return
	}
	invoice.PaidAmount += req.Amount
	invoice.Balance -= req.Amount
	if invoice.Balance <= 0 {
		invoice.Balance = 0
		invoice.Status = "paid"
	} else {
		invoice.Status = "partial"
	}
	_ = database.DB.Save(&invoice).Error
	success(c, http.StatusOK, payment, "Fee payment recorded successfully")
}

func (h *OperationalAliasHandler) GetOverdueFees(c *gin.Context) {
	var rows []models.FeeInvoice
	if err := preloadFeeInvoiceDetails(scopedFeeInvoiceQuery(c)).
		Where("fee_invoices.due_date < ? AND fee_invoices.status != ?", time.Now().UTC(), "paid").
		Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load overdue fees")
		return
	}
	success(c, http.StatusOK, rows, "")
}

func (h *OperationalAliasHandler) GetFeeStats(c *gin.Context) {
	var row struct {
		Total   float64
		Paid    float64
		Balance float64
		Overdue int64
	}
	query := scopedFeeInvoiceQuery(c)
	_ = query.Select("COALESCE(SUM(fee_invoices.net_amount), 0) AS total, COALESCE(SUM(fee_invoices.paid_amount), 0) AS paid, COALESCE(SUM(fee_invoices.balance), 0) AS balance").Scan(&row).Error
	scopedFeeInvoiceQuery(c).Where("fee_invoices.due_date < ? AND fee_invoices.status != ?", time.Now().UTC(), "paid").Count(&row.Overdue)
	success(c, http.StatusOK, gin.H{"total": row.Total, "paid": row.Paid, "balance": row.Balance, "overdue": row.Overdue}, "")
}

func (h *OperationalAliasHandler) QueueFeeReminders(c *gin.Context) {
	var req struct {
		StudentID string `json:"student_id"`
		Message   string `json:"message"`
	}
	_ = c.ShouldBindJSON(&req)
	payload := map[string]interface{}{
		"type":       "fee_reminder",
		"school_id":  scopedSchoolID(c),
		"student_id": req.StudentID,
		"message":    firstNonEmpty(req.Message, "Fee reminder"),
		"queued_by":  c.GetString("user_id"),
	}
	if services.Queue != nil {
		if err := services.Queue.Enqueue(context.Background(), "fee_reminders", payload); err != nil {
			fail(c, http.StatusInternalServerError, "Failed to queue fee reminder")
			return
		}
	}
	success(c, http.StatusAccepted, payload, "Fee reminder queued")
}

func (h *OperationalAliasHandler) CreateNotice(c *gin.Context) {
	var req struct {
		Title          string `json:"title" binding:"required"`
		Content        string `json:"content" binding:"required"`
		TargetRole     string `json:"target_role"`
		TargetAudience string `json:"target_audience"`
		IsUrgent       bool   `json:"is_urgent"`
		IsActive       *bool  `json:"is_active"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	notice := models.Announcement{
		SchoolID:       scopedSchoolID(c),
		Title:          req.Title,
		Content:        req.Content,
		TargetAudience: firstNonEmpty(req.TargetAudience, req.TargetRole, "all"),
		IsUrgent:       req.IsUrgent,
		CreatedBy:      firstNonEmpty(c.GetString("linked_id"), c.GetString("user_id")),
		PublishedAt:    time.Now().UTC(),
	}
	if req.IsActive != nil && !*req.IsActive {
		now := time.Now().UTC()
		notice.ExpiresAt = &now
	}
	if err := database.DB.Create(&notice).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create notice")
		return
	}
	id := notice.ID
	auditAction(c, "notices", "create", "announcements", &id)
	createAnnouncementNotifications(notice, "notice")
	if services.Queue != nil {
		_ = services.Queue.Enqueue(context.Background(), "notifications", map[string]interface{}{
			"type":        "notice_created",
			"notice_id":   notice.ID,
			"school_id":   notice.SchoolID,
			"target_role": notice.TargetAudience,
		})
	}
	success(c, http.StatusCreated, notice, "Notice created successfully")
}

func (h *OperationalAliasHandler) PatchNotice(c *gin.Context) {
	id := c.Param("id")
	var payload map[string]interface{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	updates := map[string]interface{}{}
	if v, ok := payload["title"]; ok {
		updates["title"] = v
	}
	if v, ok := payload["content"]; ok {
		updates["content"] = v
	}
	if v, ok := payload["target_role"]; ok {
		updates["target_audience"] = v
	}
	if v, ok := payload["is_active"]; ok {
		updates["is_urgent"] = false
		_ = v
	}
	if err := database.DB.Model(&models.Announcement{}).Where("id = ? AND school_id = ?", id, scopedSchoolID(c)).Updates(updates).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update notice")
		return
	}
	success(c, http.StatusOK, gin.H{"id": id}, "Notice updated successfully")
}

func (h *OperationalAliasHandler) DeleteNotice(c *gin.Context) {
	id := c.Param("id")
	schoolID := scopedSchoolID(c)
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		result := tx.Delete(&models.Announcement{}, "id = ? AND school_id = ?", id, schoolID)
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}
		return tx.
			Where("school_id = ? AND reference_type IN ? AND reference_id = ?", schoolID, []string{"announcement", "notice"}, id).
			Delete(&models.NotificationLog{}).Error
	})
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			fail(c, http.StatusNotFound, "Notice not found")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to delete notice")
		return
	}
	success(c, http.StatusOK, gin.H{"id": id}, "Notice deleted successfully")
}

func (h *OperationalAliasHandler) StudentDashboard(c *gin.Context) {
	if currentRole(c) != "parent" {
		fail(c, http.StatusForbidden, "Student dashboard is available through linked parent accounts only")
		return
	}

	schoolID := scopedSchoolID(c)
	parentUserID := currentUserID(c)
	if schoolID == "" || parentUserID == "" {
		fail(c, http.StatusForbidden, "School and parent context is required")
		return
	}

	studentID := strings.TrimSpace(c.Query("student_id"))
	var link models.ParentStudentLink
	query := database.DB.
		Where("school_id = ? AND parent_user_id = ?", schoolID, parentUserID).
		Order("created_at ASC")
	if studentID != "" {
		query = query.Where("student_id = ?", studentID)
	}
	if err := query.First(&link).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			fail(c, http.StatusForbidden, "Student is not linked to this parent account")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to load linked student")
		return
	}
	studentID = link.StudentID

	var attendanceCount int64
	var pendingFees float64
	if err := database.DB.Model(&models.StudentAttendance{}).
		Joins("JOIN students ON students.id = student_attendances.student_id").
		Where("students.school_id = ? AND student_attendances.student_id = ?", schoolID, studentID).
		Count(&attendanceCount).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load student attendance")
		return
	}
	if err := database.DB.Model(&models.FeeInvoice{}).
		Joins("JOIN students ON students.id = fee_invoices.student_id").
		Where("students.school_id = ? AND fee_invoices.student_id = ? AND fee_invoices.status != ?", schoolID, studentID, "paid").
		Select("COALESCE(SUM(fee_invoices.balance), 0)").
		Scan(&pendingFees).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load student fee summary")
		return
	}
	success(c, http.StatusOK, gin.H{
		"role":             "Parent",
		"student_scope":    "parent_managed",
		"student_id":       studentID,
		"attendance_count": attendanceCount,
		"pending_fees":     pendingFees,
	}, "")
}

func userResponse(user models.User, roleName, name, avatar string) gin.H {
	return gin.H{
		"id":          user.ID,
		"name":        name,
		"username":    accountUsername(user.Username, user.Email),
		"email":       user.Email,
		"phone":       user.Phone,
		"avatar":      avatar,
		"school_id":   user.SchoolID,
		"role_id":     user.RoleID,
		"role":        canonicalRole(roleName),
		"role_name":   roleName,
		"is_active":   user.IsActive,
		"is_verified": user.IsVerified,
		"created_at":  user.CreatedAt,
	}
}

func classResponse(section models.Section) gin.H {
	name := ""
	if section.Grade != nil {
		name = section.Grade.GradeName
	}
	return gin.H{
		"id":               section.ID,
		"name":             name,
		"section":          section.SectionName,
		"class_teacher_id": section.ClassTeacherID,
		"academic_year_id": section.AcademicYearID,
		"created_at":       section.CreatedAt,
	}
}

func resolveRole(schoolID, role string) (models.Role, error) {
	roleName := titleRole(role)
	var row models.Role
	err := database.DB.Where("school_id = ? AND LOWER(role_name) = ?", schoolID, strings.ToLower(roleName)).First(&row).Error
	return row, err
}

func titleRole(role string) string {
	switch canonicalRole(role) {
	case "super_admin":
		return "Principal"
	case "admin":
		return "Admin"
	case "teacher":
		return "Teacher"
	case "student":
		return "Student"
	case "parent":
		return "Parent"
	default:
		clean := strings.TrimSpace(role)
		if clean == "" {
			return clean
		}
		return strings.ToUpper(clean[:1]) + strings.ToLower(clean[1:])
	}
}

func canonicalRole(role string) string {
	switch strings.ToLower(strings.TrimSpace(role)) {
	case "principal", "superadmin", "super_admin":
		return "super_admin"
	case "admin":
		return "admin"
	case "teacher":
		return "teacher"
	case "student":
		return "student"
	case "parent":
		return "parent"
	default:
		return strings.ToLower(strings.TrimSpace(role))
	}
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func copyKey(src map[string]interface{}, dst map[string]interface{}, key string) {
	if value, ok := src[key]; ok {
		dst[key] = value
	}
}

func normalizeAttendanceStatus(status string) string {
	if strings.EqualFold(status, "half_day") {
		return "half-day"
	}
	return strings.TrimSpace(status)
}

func lookupEnrollment(studentID string) string {
	var row models.Enrollment
	if err := database.DB.First(&row, "student_id = ?", studentID).Error; err != nil {
		return studentID
	}
	return row.ID
}

func currentAcademicContext(schoolID string) (string, string) {
	var year models.AcademicYear
	if err := database.DB.Where("school_id = ? AND is_current = ?", schoolID, true).First(&year).Error; err != nil {
		_ = database.DB.Where("school_id = ?", schoolID).First(&year).Error
	}
	var term models.Term
	if year.ID != "" {
		_ = database.DB.Where("academic_year_id = ?", year.ID).First(&term).Error
	}
	return firstNonEmpty(year.ID, "compat-year"), firstNonEmpty(term.ID, "compat-term")
}

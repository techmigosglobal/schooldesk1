package handlers

import (
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type StudentHandler struct{}

func NewStudentHandler() *StudentHandler {
	return &StudentHandler{}
}

func (h *StudentHandler) GetStudents(c *gin.Context) {
	page, pageSize := parsePagination(c)
	schoolID := scopedSchoolID(c)
	sectionID := c.Query("section_id")
	status := c.Query("status")

	var students []models.Student
	var total int64

	query := database.DB.Model(&models.Student{})
	if schoolID != "" {
		query = query.Where("students.school_id = ?", schoolID)
	}
	if isParent(c) {
		query = query.Joins("JOIN parent_student_links ON parent_student_links.student_id = students.id").
			Where("parent_student_links.school_id = ? AND parent_student_links.parent_user_id = ?", schoolID, c.GetString("user_id"))
	}
	if currentRole(c) == "teacher" {
		staffID := currentStaffID(c)
		if staffID == "" {
			query = query.Where("1 = 0")
		} else {
			sections := teacherSectionSubquery(staffID, schoolID)
			query = query.Where(`
				(
				students.current_section_id IN (?)
				OR EXISTS (
					SELECT 1 FROM enrollments
					WHERE enrollments.student_id = students.id
						AND enrollments.section_id IN (?)
				)
				)
			`, sections, teacherSectionSubquery(staffID, schoolID))
		}
	}
	if sectionID != "" {
		query = query.Where("students.current_section_id = ?", sectionID)
	}
	if status != "" {
		// Caller explicitly requested a specific status (e.g. ?status=inactive
		// for admin views). Pass it through as-is.
		query = query.Where("students.status = ?", status)
	} else {
		// Default: exclude soft-deleted (inactive) students from all listings.
		// Use ?status=inactive to explicitly query deactivated records.
		query = query.Where("students.status != ?", "inactive")
	}

	query.Count(&total)
	query = query.
		Preload("Guardians").
		Preload("MedicalRecord").
		Preload("CurrentSection").
		Preload("CurrentSection.Grade").
		Preload("Documents").
		Offset((page - 1) * pageSize).
		Limit(pageSize)
	query.Find(&students)

	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, studentResponseRows(database.DB, schoolID, students)))
}

func (h *StudentHandler) GetStudent(c *gin.Context) {
	id := c.Param("id")
	if !h.canAccessStudent(c, id) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	var student models.Student
	if err := database.DB.Preload("Guardians").Preload("MedicalRecord").Preload("CurrentSection").Preload("CurrentSection.Grade").Preload("Documents").First(&student, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Student not found"})
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: studentResponseRow(database.DB, scopedSchoolID(c), student)})
}

type studentFeeSummary struct {
	StudentID       string
	TotalAmount     float64
	DiscountAmount  float64
	NetAmount       float64
	PaidAmount      float64
	Balance         float64
	PendingInvoices int64
	OverdueInvoices int64
}

type studentAttendanceSummary struct {
	StudentID    string
	TotalMarked  int64
	PresentCount int64
	AbsentCount  int64
	LateCount    int64
}

type studentPerformanceSummary struct {
	StudentID     string
	MarksCount    int64
	ObtainedMarks float64
	MaxMarks      float64
	WeakSubjects  int64
}

type studentSummarySet struct {
	fees        map[string]studentFeeSummary
	attendance  map[string]studentAttendanceSummary
	lastStatus  map[string]string
	performance map[string]studentPerformanceSummary
	parents     map[string][]gin.H
}

func studentResponseRows(db *gorm.DB, schoolID string, students []models.Student) []gin.H {
	ids := make([]string, 0, len(students))
	for _, student := range students {
		if strings.TrimSpace(student.ID) != "" {
			ids = append(ids, student.ID)
		}
	}
	summaries := loadStudentSummaries(db, schoolID, ids)
	rows := make([]gin.H, 0, len(students))
	for _, student := range students {
		rows = append(rows, studentResponseFromSummaries(student, summaries))
	}
	return rows
}

func studentResponseRow(db *gorm.DB, schoolID string, student models.Student) gin.H {
	summaries := loadStudentSummaries(db, schoolID, []string{student.ID})
	return studentResponseFromSummaries(student, summaries)
}

func loadStudentSummaries(db *gorm.DB, schoolID string, studentIDs []string) studentSummarySet {
	out := studentSummarySet{
		fees:        map[string]studentFeeSummary{},
		attendance:  map[string]studentAttendanceSummary{},
		lastStatus:  map[string]string{},
		performance: map[string]studentPerformanceSummary{},
		parents:     map[string][]gin.H{},
	}
	if db == nil || len(studentIDs) == 0 {
		return out
	}

	var fees []studentFeeSummary
	_ = db.Model(&models.FeeInvoice{}).
		Select(`
			student_id,
			COALESCE(SUM(total_amount), 0) AS total_amount,
			COALESCE(SUM(discount_amount), 0) AS discount_amount,
			COALESCE(SUM(net_amount), 0) AS net_amount,
			COALESCE(SUM(paid_amount), 0) AS paid_amount,
			COALESCE(SUM(balance), 0) AS balance,
			SUM(CASE WHEN status <> 'paid' THEN 1 ELSE 0 END) AS pending_invoices,
			SUM(CASE WHEN status <> 'paid' AND due_date < ? THEN 1 ELSE 0 END) AS overdue_invoices
		`, time.Now().UTC()).
		Where("student_id IN ?", studentIDs).
		Group("student_id").
		Scan(&fees).Error
	for _, fee := range fees {
		out.fees[fee.StudentID] = fee
	}

	var attendance []studentAttendanceSummary
	_ = db.Model(&models.StudentAttendance{}).
		Select(`
			student_id,
			COUNT(*) AS total_marked,
			SUM(CASE WHEN LOWER(status) IN ('present', 'late') THEN 1 ELSE 0 END) AS present_count,
			SUM(CASE WHEN LOWER(status) = 'absent' THEN 1 ELSE 0 END) AS absent_count,
			SUM(CASE WHEN LOWER(status) = 'late' THEN 1 ELSE 0 END) AS late_count
		`).
		Where("student_id IN ?", studentIDs).
		Group("student_id").
		Scan(&attendance).Error
	for _, row := range attendance {
		out.attendance[row.StudentID] = row
	}

	var latest []models.StudentAttendance
	_ = db.Where("student_id IN ?", studentIDs).
		Order("marked_at DESC").
		Find(&latest).Error
	for _, row := range latest {
		if _, exists := out.lastStatus[row.StudentID]; exists {
			continue
		}
		out.lastStatus[row.StudentID] = strings.TrimSpace(row.Status)
	}

	var performance []studentPerformanceSummary
	_ = db.Table("student_marks").
		Select(`
			student_marks.student_id AS student_id,
			COUNT(*) AS marks_count,
			COALESCE(SUM(student_marks.marks_obtained), 0) AS obtained_marks,
			COALESCE(SUM(exam_schedules.max_marks), 0) AS max_marks,
			SUM(CASE
				WHEN student_marks.is_absent = false
					AND student_marks.is_exempted = false
					AND exam_schedules.max_marks > 0
					AND (student_marks.marks_obtained * 100.0 / exam_schedules.max_marks) < 40
				THEN 1 ELSE 0
			END) AS weak_subjects
		`).
		Joins("JOIN exam_schedules ON exam_schedules.id = student_marks.exam_schedule_id").
		Where("student_marks.student_id IN ? AND student_marks.is_absent = false AND student_marks.is_exempted = false", studentIDs).
		Group("student_marks.student_id").
		Scan(&performance).Error
	for _, row := range performance {
		out.performance[row.StudentID] = row
	}

	var links []models.ParentStudentLink
	_ = db.Preload("ParentUser").
		Where("school_id = ? AND student_id IN ?", schoolID, studentIDs).
		Find(&links).Error
	for _, link := range links {
		if link.ParentUser == nil {
			continue
		}
		parent := link.ParentUser
		out.parents[link.StudentID] = append(out.parents[link.StudentID], gin.H{
			"id":       parent.ID,
			"username": parent.Username,
			"name":     parent.Name,
			"email":    parent.Email,
			"phone":    parent.Phone,
			"avatar":   parent.Avatar,
		})
	}

	return out
}

func studentResponseFromSummaries(student models.Student, summaries studentSummarySet) gin.H {
	attendance := summaries.attendance[student.ID]
	fee := summaries.fees[student.ID]
	performance := summaries.performance[student.ID]
	parents := summaries.parents[student.ID]
	guardians := student.Guardians
	documents := student.Documents
	if guardians == nil {
		guardians = []models.Guardian{}
	}
	if documents == nil {
		documents = []models.StudentDocument{}
	}
	if parents == nil {
		parents = []gin.H{}
	}

	row := gin.H{
		"id":                    student.ID,
		"created_at":            student.CreatedAt,
		"updated_at":            student.UpdatedAt,
		"school_id":             student.SchoolID,
		"user_id":               student.UserID,
		"parent_id":             student.ParentID,
		"student_code":          student.StudentCode,
		"admission_number":      student.AdmissionNumber,
		"first_name":            student.FirstName,
		"last_name":             student.LastName,
		"date_of_birth":         student.DateOfBirth,
		"gender":                student.Gender,
		"caste_category":        student.CasteCategory,
		"nationality":           student.Nationality,
		"admission_date":        student.AdmissionDate,
		"current_section_id":    student.CurrentSectionID,
		"aadhar_number":         student.AadharNumber,
		"address":               student.Address,
		"status":                student.Status,
		"current_section":       student.CurrentSection,
		"guardians":             guardians,
		"documents":             documents,
		"medical_record":        student.MedicalRecord,
		"parent_accounts":       parents,
		"primary_guardian":      primaryStudentGuardian(guardians, parents),
		"attendance_summary":    attendanceSummaryPayload(attendance, summaries.lastStatus[student.ID]),
		"fee_summary":           feeSummaryPayload(fee),
		"performance_summary":   performanceSummaryPayload(performance),
		"student_status_label":  studentStatusLabel(student.Status, attendance, summaries.lastStatus[student.ID]),
		"has_attendance_alert":  attendance.TotalMarked > 0 && studentAttendancePercent(attendance) < 75,
		"has_fee_alert":         fee.Balance > 0,
		"has_performance_alert": performance.MarksCount > 0 && performancePercent(performance) < 40,
	}
	return row
}

func primaryStudentGuardian(guardians []models.Guardian, parents []gin.H) gin.H {
	for _, guardian := range guardians {
		if guardian.IsPrimary {
			return guardianPayload(guardian)
		}
	}
	if len(guardians) > 0 {
		return guardianPayload(guardians[0])
	}
	if len(parents) > 0 {
		parent := parents[0]
		return gin.H{
			"id":           parent["id"],
			"full_name":    firstNonEmpty(fmt.Sprint(parent["name"]), fmt.Sprint(parent["username"])),
			"relationship": "Parent",
			"phone":        fmt.Sprint(parent["phone"]),
			"email":        fmt.Sprint(parent["email"]),
			"is_primary":   true,
		}
	}
	return gin.H{}
}

func guardianPayload(guardian models.Guardian) gin.H {
	return gin.H{
		"id":           guardian.ID,
		"full_name":    guardian.FullName,
		"relationship": guardian.Relationship,
		"phone":        guardian.Phone,
		"email":        guardian.Email,
		"occupation":   guardian.Occupation,
		"is_primary":   guardian.IsPrimary,
		"can_pickup":   guardian.CanPickup,
	}
}

func attendanceSummaryPayload(summary studentAttendanceSummary, lastStatus string) gin.H {
	percent := studentAttendancePercent(summary)
	return gin.H{
		"total_marked":  summary.TotalMarked,
		"present_count": summary.PresentCount,
		"absent_count":  summary.AbsentCount,
		"late_count":    summary.LateCount,
		"percent":       percent,
		"last_status":   strings.TrimSpace(lastStatus),
		"status_label":  attendanceStatusLabel(summary, lastStatus),
	}
}

func feeSummaryPayload(summary studentFeeSummary) gin.H {
	status := "clear"
	if summary.OverdueInvoices > 0 {
		status = "overdue"
	} else if summary.PendingInvoices > 0 || summary.Balance > 0 {
		status = "pending"
	}
	return gin.H{
		"total_amount":     summary.TotalAmount,
		"discount_amount":  summary.DiscountAmount,
		"net_amount":       summary.NetAmount,
		"paid_amount":      summary.PaidAmount,
		"balance":          summary.Balance,
		"pending_invoices": summary.PendingInvoices,
		"overdue_invoices": summary.OverdueInvoices,
		"status":           status,
	}
}

func performanceSummaryPayload(summary studentPerformanceSummary) gin.H {
	percent := performancePercent(summary)
	return gin.H{
		"marks_count":     summary.MarksCount,
		"obtained_marks":  summary.ObtainedMarks,
		"max_marks":       summary.MaxMarks,
		"average_percent": percent,
		"grade":           performanceGrade(percent, summary.MarksCount),
		"weak_subjects":   summary.WeakSubjects,
	}
}

func studentAttendancePercent(summary studentAttendanceSummary) float64 {
	if summary.TotalMarked <= 0 {
		return 0
	}
	return float64(summary.PresentCount) * 100 / float64(summary.TotalMarked)
}

func performancePercent(summary studentPerformanceSummary) float64 {
	if summary.MaxMarks <= 0 {
		return 0
	}
	return summary.ObtainedMarks * 100 / summary.MaxMarks
}

func attendanceStatusLabel(summary studentAttendanceSummary, lastStatus string) string {
	last := strings.ToLower(strings.TrimSpace(lastStatus))
	switch last {
	case "present":
		return "Present"
	case "absent":
		return "Absent"
	case "late":
		return "Late"
	}
	if summary.TotalMarked == 0 {
		return "Not marked"
	}
	if studentAttendancePercent(summary) >= 75 {
		return "Present"
	}
	return "Needs attention"
}

func studentStatusLabel(status string, summary studentAttendanceSummary, lastStatus string) string {
	switch strings.ToLower(strings.TrimSpace(status)) {
	case "inactive", "withdrawn":
		return "Inactive"
	case "pending":
		return "Pending"
	case "transferred", "transfer":
		return "Transferred"
	}
	return attendanceStatusLabel(summary, lastStatus)
}

func performanceGrade(percent float64, marksCount int64) string {
	if marksCount <= 0 {
		return "N/A"
	}
	switch {
	case percent >= 90:
		return "A+"
	case percent >= 80:
		return "A"
	case percent >= 70:
		return "B"
	case percent >= 60:
		return "C"
	case percent >= 40:
		return "D"
	default:
		return "Needs support"
	}
}

func (h *StudentHandler) CreateStudent(c *gin.Context) {
	var req models.CreateStudentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	student, status, err := createStudentForSchool(database.DB, scopedSchoolID(c), req)
	if err != nil {
		fail(c, status, err.Error())
		return
	}

	id := student.ID
	auditAction(c, "students", "create", "students", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: student})
}

func (h *StudentHandler) UpdateStudent(c *gin.Context) {
	id := c.Param("id")
	var student models.Student
	if err := database.DB.First(&student, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Student not found"})
		return
	}

	var req models.CreateStudentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	student, status, err := updateStudentForSchool(database.DB, scopedSchoolID(c), id, req)
	if err != nil {
		fail(c, status, err.Error())
		return
	}

	auditAction(c, "students", "update", "students", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: student})
}

func (h *StudentHandler) DeleteStudent(c *gin.Context) {
	id := c.Param("id")
	schoolID := scopedSchoolID(c)

	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		var student models.Student
		if err := tx.First(&student, "id = ? AND school_id = ?", id, schoolID).Error; err != nil {
			return err
		}
		if err := cleanupStudentAssociations(tx, schoolID, id); err != nil {
			return err
		}
		return tx.Model(&student).Updates(map[string]interface{}{
			"status":             "inactive",
			"current_section_id": nil,
			"parent_id":          "",
			"user_id":            "",
		}).Error
	}); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, models.APIResponse{
				Success: false,
				Error:   "Student not found",
			})
			return
		}
		log.Printf("student delete cleanup failed for %s: %v", id, err)
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Error:   "Failed to deactivate student",
		})
		return
	}

	auditAction(c, "students", "delete", "students", &id)
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Student deactivated and linked records removed successfully",
	})
}

func cleanupStudentAssociations(tx *gorm.DB, schoolID, studentID string) error {
	var invoiceIDs []string
	if err := tx.Model(&models.FeeInvoice{}).
		Where("student_id = ?", studentID).
		Pluck("id", &invoiceIDs).Error; err != nil {
		return err
	}
	if len(invoiceIDs) > 0 {
		if err := tx.Where("invoice_id IN ?", invoiceIDs).Delete(&models.ParentPaymentRequest{}).Error; err != nil {
			return err
		}
		if err := tx.Where("invoice_id IN ?", invoiceIDs).Delete(&models.Payment{}).Error; err != nil {
			return err
		}
		if err := tx.Where("invoice_id IN ?", invoiceIDs).Delete(&models.FeeInvoiceItem{}).Error; err != nil {
			return err
		}
	}

	deletes := []struct {
		query string
		args  []interface{}
		model interface{}
	}{
		{"school_id = ? AND student_id = ?", []interface{}{schoolID, studentID}, &models.ParentPaymentRequest{}},
		{"student_id = ?", []interface{}{studentID}, &models.FeeInvoice{}},
		{"student_id = ?", []interface{}{studentID}, &models.FeeConcession{}},
		{"student_id = ?", []interface{}{studentID}, &models.ReportCard{}},
		{"student_id = ?", []interface{}{studentID}, &models.StudentMark{}},
		{"student_id = ?", []interface{}{studentID}, &models.StudentAttendance{}},
		{"student_id = ?", []interface{}{studentID}, &models.AttendanceSummary{}},
		{"student_id = ?", []interface{}{studentID}, &models.StudentLeaveApplication{}},
		{"student_id = ?", []interface{}{studentID}, &models.HomeworkSubmission{}},
		{"student_id = ?", []interface{}{studentID}, &models.Homework{}},
		{"student_id = ?", []interface{}{studentID}, &models.DiaryEntry{}},
		{"student_id = ?", []interface{}{studentID}, &models.ParentTeacherMeeting{}},
		{"student_id = ?", []interface{}{studentID}, &models.StudentTransport{}},
		{"student_id = ?", []interface{}{studentID}, &models.TransferRecord{}},
		{"student_id = ?", []interface{}{studentID}, &models.MedicalRecord{}},
		{"student_id = ?", []interface{}{studentID}, &models.StudentDocument{}},
		{"school_id = ? AND student_id = ?", []interface{}{schoolID, studentID}, &models.ParentStudentLink{}},
		{"school_id = ? AND student_id = ?", []interface{}{schoolID, studentID}, &models.StudentGuardian{}},
	}
	for _, item := range deletes {
		if err := tx.Where(item.query, item.args...).Delete(item.model).Error; err != nil {
			return err
		}
	}

	var conversationIDs []string
	if err := tx.Model(&models.MessageConversation{}).
		Where("school_id = ? AND student_id = ?", schoolID, studentID).
		Pluck("id", &conversationIDs).Error; err != nil {
		return err
	}
	if len(conversationIDs) > 0 {
		if err := tx.Where("conversation_id IN ?", conversationIDs).Delete(&models.Message{}).Error; err != nil {
			return err
		}
		if err := tx.Where("id IN ?", conversationIDs).Delete(&models.MessageConversation{}).Error; err != nil {
			return err
		}
	}

	var enrollmentIDs []string
	if err := tx.Model(&models.Enrollment{}).
		Where("student_id = ?", studentID).
		Pluck("id", &enrollmentIDs).Error; err != nil {
		return err
	}
	if len(enrollmentIDs) > 0 {
		if err := tx.Where("enrollment_id IN ?", enrollmentIDs).Delete(&models.StudentAttendance{}).Error; err != nil {
			return err
		}
		if err := tx.Where("enrollment_id IN ?", enrollmentIDs).Delete(&models.StudentMark{}).Error; err != nil {
			return err
		}
		if err := tx.Where("enrollment_id IN ?", enrollmentIDs).Delete(&models.ReportCard{}).Error; err != nil {
			return err
		}
	}
	if err := tx.Where("student_id = ?", studentID).Delete(&models.Enrollment{}).Error; err != nil {
		return err
	}

	return tx.Model(&models.User{}).
		Where("school_id = ? AND linked_type = ? AND linked_id = ?", schoolID, "student", studentID).
		Updates(map[string]interface{}{
			"is_active":           false,
			"auth_invalidated_at": time.Now().UTC(),
		}).Error
}

func (h *StudentHandler) UploadStudentPhoto(c *gin.Context) {
	studentID := c.Param("id")
	schoolID := scopedSchoolID(c)

	var student models.Student
	if err := database.DB.First(&student, "id = ? AND school_id = ?", studentID, schoolID).Error; err != nil {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Success: false,
			Error:   "Student not found",
		})
		return
	}

	file, err := c.FormFile("photo")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Photo file is required"})
		return
	}
	if file.Size > 3*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Photo file must be 3 MB or smaller"})
		return
	}
	ext := strings.ToLower(filepath.Ext(file.Filename))
	switch ext {
	case ".jpg", ".jpeg", ".png", ".webp":
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Photo must be a JPG, PNG, or WebP image"})
		return
	}

	dir := filepath.Join("uploads", "students", schoolID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		log.Printf("student photo upload storage preparation failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to prepare upload storage"})
		return
	}
	filename := fmt.Sprintf("%s_photo_%d%s", studentID, time.Now().UnixNano(), ext)
	relativePath := filepath.ToSlash(filepath.Join(dir, filename))
	if err := c.SaveUploadedFile(file, relativePath); err != nil {
		log.Printf("student photo upload save failed for student %s: %v", studentID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save student photo"})
		return
	}

	publicPath := "/" + relativePath
	now := time.Now().UTC()
	var document models.StudentDocument
	result := database.DB.Where("student_id = ? AND doc_type = ?", studentID, "profile_photo").First(&document)
	if result.Error == nil {
		if err := database.DB.Model(&document).Updates(map[string]interface{}{
			"file_url":    publicPath,
			"verified":    false,
			"uploaded_at": now,
			"updated_at":  now,
		}).Error; err != nil {
			log.Printf("student photo document update failed for student %s: %v", studentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update student photo"})
			return
		}
	} else if errors.Is(result.Error, gorm.ErrRecordNotFound) {
		document = models.StudentDocument{
			StudentID:  studentID,
			DocType:    "profile_photo",
			FileURL:    publicPath,
			Verified:   false,
			UploadedAt: now,
		}
		if err := database.DB.Create(&document).Error; err != nil {
			log.Printf("student photo document create failed for student %s: %v", studentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save student photo"})
			return
		}
	} else {
		log.Printf("student photo document lookup failed for student %s: %v", studentID, result.Error)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update student photo"})
		return
	}

	auditAction(c, "student_documents", "create", "students", &studentID)
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"photo":     publicPath,
			"photo_url": absoluteURL(c, publicPath),
		},
	})
}

func (h *StudentHandler) UploadStudentDocument(c *gin.Context) {
	studentID := strings.TrimSpace(c.Param("id"))
	schoolID := scopedSchoolID(c)
	if studentID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Student ID is required"})
		return
	}

	var student models.Student
	if err := database.DB.First(&student, "id = ? AND school_id = ?", studentID, schoolID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Student not found"})
		return
	}

	file, err := c.FormFile("document")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Document file is required"})
		return
	}
	if file.Size > 8*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Document file must be 8 MB or smaller"})
		return
	}

	docType := strings.TrimSpace(c.PostForm("doc_type"))
	if docType == "" {
		docType = "admission_document"
	}

	ext := strings.ToLower(filepath.Ext(file.Filename))
	switch ext {
	case ".jpg", ".jpeg", ".png", ".webp", ".pdf":
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Document must be a JPG, PNG, WebP, or PDF file"})
		return
	}

	dir := filepath.Join("uploads", "students", schoolID, "documents")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		log.Printf("student document upload storage preparation failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to prepare upload storage"})
		return
	}

	filename := fmt.Sprintf("%s_%s_%d%s", studentID, uploadSafeToken(docType), time.Now().UnixNano(), ext)
	relativePath := filepath.ToSlash(filepath.Join(dir, filename))
	if err := c.SaveUploadedFile(file, relativePath); err != nil {
		log.Printf("student document upload save failed for student %s: %v", studentID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save student document"})
		return
	}

	publicPath := "/" + relativePath
	document := models.StudentDocument{
		StudentID:  studentID,
		DocType:    docType,
		FileURL:    publicPath,
		Verified:   false,
		UploadedAt: time.Now().UTC(),
	}
	if err := database.DB.Create(&document).Error; err != nil {
		log.Printf("student document create failed for student %s: %v", studentID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save student document"})
		return
	}

	auditAction(c, "student_documents", "create", "students", &studentID)
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"document": document,
			"file_url": absoluteURL(c, publicPath),
		},
	})
}

func uploadSafeToken(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	var builder strings.Builder
	for _, r := range value {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			builder.WriteRune(r)
			continue
		}
		builder.WriteByte('_')
	}
	token := strings.Trim(builder.String(), "_")
	if token == "" {
		return "document"
	}
	return token
}

func (h *StudentHandler) GetStudentEnrollments(c *gin.Context) {
	studentID := c.Param("id")
	if !h.canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	var enrollments []models.Enrollment
	database.DB.Preload("Section").Preload("Section.Grade").Preload("AcademicYear").Where("student_id = ?", studentID).Find(&enrollments)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: enrollments})
}

func (h *StudentHandler) CreateEnrollment(c *gin.Context) {
	var req models.CreateEnrollmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	enrollDate := time.Now()
	if req.EnrollmentDate != "" {
		enrollDate, _ = time.Parse("2006-01-02", req.EnrollmentDate)
	}

	enrollment := models.Enrollment{
		StudentID:      req.StudentID,
		SectionID:      req.SectionID,
		AcademicYearID: req.AcademicYearID,
		RollNumber:     req.RollNumber,
		EnrollmentDate: enrollDate,
		Status:         "enrolled",
	}

	if err := validateEnrollmentSchoolScope(scopedSchoolID(c), enrollment); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&enrollment).Error; err != nil {
			return err
		}
		return tx.Model(&models.Student{}).
			Where("id = ? AND school_id = ?", enrollment.StudentID, scopedSchoolID(c)).
			Update("current_section_id", enrollment.SectionID).Error
	}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create enrollment"})
		return
	}

	id := enrollment.ID
	auditAction(c, "enrollments", "create", "enrollments", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: enrollment})
}

func (h *StudentHandler) GetStudentAttendance(c *gin.Context) {
	studentID := c.Param("id")
	if !h.canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	month := c.Query("month")
	year := c.Query("year")

	var attendance []models.StudentAttendance
	query := database.DB.Where("student_id = ?", studentID).Preload("Session")
	if month != "" {
		start, end, ok := monthYearRange(month, year)
		if ok {
			query = query.Where("marked_at >= ? AND marked_at < ?", start, end)
		}
	} else if year != "" {
		start, _, ok := monthYearRange("01", year)
		if ok {
			query = query.Where("marked_at >= ? AND marked_at < ?", start, start.AddDate(1, 0, 0))
		}
	}
	query.Find(&attendance)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: attendance})
}

func (h *StudentHandler) GetStudentFees(c *gin.Context) {
	studentID := c.Param("id")
	if !h.canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	var invoices []models.FeeInvoice
	database.DB.
		Joins("JOIN students ON students.id = fee_invoices.student_id").
		Where("fee_invoices.student_id = ? AND students.school_id = ? AND students.status != ?", studentID, scopedSchoolID(c), "inactive").
		Preload("Student").
		Preload("Student.CurrentSection").
		Preload("Student.CurrentSection.Grade").
		Preload("AcademicYear").
		Preload("Items").
		Preload("Items.FeeCategory").
		Preload("Payments").
		Find(&invoices)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: invoices})
}

func (h *StudentHandler) GetStudentMarks(c *gin.Context) {
	studentID := c.Param("id")
	if !h.canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	examID := c.Query("exam_id")

	var marks []models.StudentMark
	query := database.DB.Where("student_id = ?", studentID).Preload("ExamSchedule").Preload("ExamSchedule.Subject")
	if examID != "" {
		query = query.Joins("JOIN exam_schedules ON exam_schedules.id = student_marks.exam_schedule_id").
			Where("exam_schedules.exam_id = ?", examID).
			Preload("ExamSchedule.Exam")
	}
	query.Find(&marks)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: marks})
}

func (h *StudentHandler) GetStudentProgress(c *gin.Context) {
	studentID := c.Param("id")
	schoolID := currentSchoolID(c)

	var count int64
	if err := database.DB.Model(&models.Student{}).
		Where("id = ? AND school_id = ?", studentID, schoolID).
		Count(&count).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to verify student"})
		return
	}
	if count == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "student not found"})
		return
	}

	type ProgressRow struct {
		ExamID     string  `json:"exam_id"`
		ExamName   string  `json:"exam_name"`
		ExamType   string  `json:"exam_type"`
		StartDate  string  `json:"start_date"`
		Obtained   float64 `json:"marks_obtained"`
		TotalMax   float64 `json:"total_marks"`
		Percentage float64 `json:"percentage"`
		Grade      string  `json:"grade"`
	}
	var rows []ProgressRow
	if err := database.DB.Raw(`
		SELECT
			e.id AS exam_id,
			e.exam_name AS exam_name,
			et.name AS exam_type,
			CAST(e.start_date AS TEXT) AS start_date,
			rc.total_obtained AS obtained,
			sm_max.total_max AS total_max,
			ROUND(CAST(
				CASE WHEN sm_max.total_max > 0
					THEN (rc.total_obtained / sm_max.total_max) * 100
					ELSE 0 END AS numeric
			), 1) AS percentage,
			rc.overall_grade AS grade
		FROM report_cards rc
		JOIN exams e ON e.id = rc.exam_id
		LEFT JOIN exam_types et ON et.id = e.exam_type_id
		JOIN (
			SELECT es.exam_id, SUM(es.max_marks) AS total_max
			FROM exam_schedules es GROUP BY es.exam_id
		) sm_max ON sm_max.exam_id = e.id
		WHERE rc.student_id = ? AND e.school_id = ?
		ORDER BY e.start_date ASC
	`, studentID, schoolID).Scan(&rows).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load progress"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"student_id": studentID, "progress": rows})
}

func (h *StudentHandler) GetStudentTransport(c *gin.Context) {
	studentID := c.Param("id")
	if !h.canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	var transports []models.StudentTransport
	database.DB.Where("student_id = ?", studentID).Preload("Route").Preload("Stop").Find(&transports)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: transports})
}

func (h *StudentHandler) canAccessStudent(c *gin.Context, studentID string) bool {
	return canAccessStudent(c, studentID)
}

func isParent(c *gin.Context) bool {
	return strings.EqualFold(strings.TrimSpace(c.GetString("role_name")), "parent")
}

func (h *StudentHandler) teacherStaffID(c *gin.Context) string {
	if !strings.EqualFold(strings.TrimSpace(c.GetString("linked_type")), "staff") {
		return ""
	}
	if linkedID := strings.TrimSpace(c.GetString("linked_id")); linkedID != "" {
		return linkedID
	}

	var user models.User
	if err := database.DB.First(&user, "id = ? AND school_id = ?", c.GetString("user_id"), scopedSchoolID(c)).Error; err != nil {
		return ""
	}
	if user.LinkedID != nil && strings.TrimSpace(*user.LinkedID) != "" {
		return strings.TrimSpace(*user.LinkedID)
	}

	var staff models.Staff
	if err := database.DB.First(&staff, "school_id = ? AND email = ?", scopedSchoolID(c), c.GetString("email")).Error; err != nil {
		return ""
	}
	return staff.ID
}

func validateEnrollmentSchoolScope(schoolID string, enrollment models.Enrollment) error {
	if countRows(database.DB.Model(&models.Student{}).
		Where("id = ? AND school_id = ? AND status != ?", enrollment.StudentID, schoolID, "inactive")) == 0 {
		return fmt.Errorf("student does not belong to this school")
	}
	if !sectionBelongsToSchool(enrollment.SectionID, schoolID) {
		return fmt.Errorf("section does not belong to this school")
	}
	if countRows(database.DB.Model(&models.AcademicYear{}).
		Where("id = ? AND school_id = ?", enrollment.AcademicYearID, schoolID)) == 0 {
		return fmt.Errorf("academic year does not belong to this school")
	}
	return nil
}

func createStudentForSchool(db *gorm.DB, schoolID string, req models.CreateStudentRequest) (models.Student, int, error) {
	dob, err := parseRequiredStudentDate(req.DateOfBirth, "date_of_birth")
	if err != nil {
		return models.Student{}, http.StatusBadRequest, err
	}
	admDate := time.Now().UTC()
	if strings.TrimSpace(req.AdmissionDate) != "" {
		parsed, err := parseRequiredStudentDate(req.AdmissionDate, "admission_date")
		if err != nil {
			return models.Student{}, http.StatusBadRequest, err
		}
		admDate = parsed
	}
	sectionID := strings.TrimSpace(req.CurrentSectionID)
	if sectionID != "" && !sectionBelongsToSchoolDB(db, sectionID, schoolID) {
		return models.Student{}, http.StatusBadRequest, fmt.Errorf("section does not belong to this school")
	}
	studentCode := strings.TrimSpace(req.StudentCode)
	if studentCode == "" {
		studentCode = fmt.Sprintf("STU-%d", time.Now().UTC().UnixNano())
	}
	admissionNumber := strings.TrimSpace(req.AdmissionNumber)
	if admissionNumber == "" {
		admissionNumber = studentCode
	}
	if err := ensureStudentIdentifierAvailable(db, schoolID, "student_code", studentCode, ""); err != nil {
		return models.Student{}, http.StatusBadRequest, err
	}
	if err := ensureStudentIdentifierAvailable(db, schoolID, "admission_number", admissionNumber, ""); err != nil {
		return models.Student{}, http.StatusBadRequest, err
	}

	student := models.Student{
		SchoolID:        schoolID,
		StudentCode:     studentCode,
		AdmissionNumber: admissionNumber,
		FirstName:       strings.TrimSpace(req.FirstName),
		LastName:        strings.TrimSpace(req.LastName),
		DateOfBirth:     dob,
		Gender:          strings.ToLower(strings.TrimSpace(req.Gender)),
		AdmissionDate:   admDate,
		Status:          "active",
	}
	if sectionID != "" {
		student.CurrentSectionID = &sectionID
	}
	if strings.TrimSpace(req.Status) != "" {
		student.Status = strings.ToLower(strings.TrimSpace(req.Status))
	}

	if err := db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&student).Error; err != nil {
			return err
		}
		if sectionID == "" {
			return nil
		}
		return upsertCurrentEnrollment(tx, schoolID, student.ID, sectionID, firstNonEmpty(student.AdmissionNumber, student.StudentCode), admDate)
	}); err != nil {
		return models.Student{}, http.StatusInternalServerError, fmt.Errorf("failed to create student")
	}
	return student, http.StatusCreated, nil
}

func updateStudentForSchool(db *gorm.DB, schoolID, studentID string, req models.CreateStudentRequest) (models.Student, int, error) {
	var student models.Student
	if err := db.First(&student, "id = ? AND school_id = ?", studentID, schoolID).Error; err != nil {
		return models.Student{}, http.StatusNotFound, fmt.Errorf("student not found")
	}
	sectionID := strings.TrimSpace(req.CurrentSectionID)
	if sectionID != "" && !sectionBelongsToSchoolDB(db, sectionID, schoolID) {
		return models.Student{}, http.StatusBadRequest, fmt.Errorf("section does not belong to this school")
	}
	studentCode := strings.TrimSpace(req.StudentCode)
	if studentCode == "" {
		studentCode = student.StudentCode
	}
	if studentCode == "" {
		studentCode = fmt.Sprintf("STU-%d", time.Now().UTC().UnixNano())
	}
	admissionNumber := strings.TrimSpace(req.AdmissionNumber)
	if admissionNumber == "" {
		admissionNumber = student.AdmissionNumber
	}
	if admissionNumber == "" {
		admissionNumber = studentCode
	}
	if err := ensureStudentIdentifierAvailable(db, schoolID, "student_code", studentCode, studentID); err != nil {
		return models.Student{}, http.StatusBadRequest, err
	}
	if err := ensureStudentIdentifierAvailable(db, schoolID, "admission_number", admissionNumber, studentID); err != nil {
		return models.Student{}, http.StatusBadRequest, err
	}

	student.FirstName = strings.TrimSpace(req.FirstName)
	student.LastName = strings.TrimSpace(req.LastName)
	student.StudentCode = studentCode
	student.AdmissionNumber = admissionNumber
	student.Gender = strings.ToLower(strings.TrimSpace(req.Gender))
	if strings.TrimSpace(req.DateOfBirth) != "" {
		dob, err := parseRequiredStudentDate(req.DateOfBirth, "date_of_birth")
		if err != nil {
			return models.Student{}, http.StatusBadRequest, err
		}
		student.DateOfBirth = dob
	}
	if strings.TrimSpace(req.AdmissionDate) != "" {
		admDate, err := parseRequiredStudentDate(req.AdmissionDate, "admission_date")
		if err != nil {
			return models.Student{}, http.StatusBadRequest, err
		}
		student.AdmissionDate = admDate
	}
	if sectionID != "" {
		student.CurrentSectionID = &sectionID
	}
	if strings.TrimSpace(req.Status) != "" {
		student.Status = strings.ToLower(strings.TrimSpace(req.Status))
	}

	if err := db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Save(&student).Error; err != nil {
			return err
		}
		if sectionID == "" {
			return nil
		}
		return upsertCurrentEnrollment(tx, schoolID, student.ID, sectionID, firstNonEmpty(student.AdmissionNumber, student.StudentCode), time.Now().UTC())
	}); err != nil {
		return models.Student{}, http.StatusInternalServerError, fmt.Errorf("failed to update student")
	}
	return student, http.StatusOK, nil
}

func ensureStudentIdentifierAvailable(db *gorm.DB, schoolID, field, value, excludeID string) error {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	var column string
	switch field {
	case "student_code":
		column = "student_code"
	case "admission_number":
		column = "admission_number"
	default:
		return fmt.Errorf("invalid student identifier")
	}
	query := db.Model(&models.Student{}).Where("school_id = ? AND "+column+" = ?", schoolID, value)
	if strings.TrimSpace(excludeID) != "" {
		query = query.Where("id <> ?", strings.TrimSpace(excludeID))
	}
	if countRows(query) > 0 {
		return fmt.Errorf("%s already exists", strings.ReplaceAll(column, "_", " "))
	}
	return nil
}

func parseRequiredStudentDate(value, field string) (time.Time, error) {
	parsed, err := time.Parse("2006-01-02", strings.TrimSpace(value))
	if err != nil {
		return time.Time{}, fmt.Errorf("invalid %s format. Use YYYY-MM-DD", field)
	}
	return parsed, nil
}

func upsertCurrentEnrollment(tx *gorm.DB, schoolID, studentID, sectionID, rollNumber string, enrollmentDate time.Time) error {
	yearID, err := currentAcademicYearID(tx, schoolID)
	if err != nil || yearID == "" {
		return err
	}
	var existing models.Enrollment
	err = tx.Where("student_id = ? AND academic_year_id = ?", studentID, yearID).First(&existing).Error
	if err == nil {
		return tx.Model(&existing).Updates(map[string]interface{}{
			"section_id":  sectionID,
			"roll_number": rollNumber,
			"status":      "enrolled",
		}).Error
	}
	if err != gorm.ErrRecordNotFound {
		return err
	}
	enrollment := models.Enrollment{
		StudentID:      studentID,
		SectionID:      sectionID,
		AcademicYearID: yearID,
		RollNumber:     rollNumber,
		EnrollmentDate: enrollmentDate,
		Status:         "enrolled",
	}
	return tx.Create(&enrollment).Error
}

func currentAcademicYearID(tx *gorm.DB, schoolID string) (string, error) {
	var year models.AcademicYear
	err := tx.Where("school_id = ? AND is_current = ?", schoolID, true).First(&year).Error
	if err == gorm.ErrRecordNotFound {
		err = tx.Where("school_id = ?", schoolID).Order("start_date DESC").First(&year).Error
	}
	if err == gorm.ErrRecordNotFound {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return year.ID, nil
}

func sectionBelongsToSchoolDB(db *gorm.DB, sectionID, schoolID string) bool {
	if strings.TrimSpace(sectionID) == "" || strings.TrimSpace(schoolID) == "" {
		return false
	}
	return countRows(db.Model(&models.Section{}).
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("sections.id = ? AND grades.school_id = ?", sectionID, schoolID)) > 0
}

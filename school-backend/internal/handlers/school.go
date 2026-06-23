package handlers

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/mail"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type SchoolHandler struct{}

var errSectionHasActiveStudents = errors.New("cannot delete while linked students are active")

func NewSchoolHandler() *SchoolHandler {
	return &SchoolHandler{}
}

var (
	schoolIdentifierPattern = regexp.MustCompile(`^[A-Za-z0-9 ./_-]+$`)
	schoolPostalPattern     = regexp.MustCompile(`^[A-Za-z0-9 -]{3,12}$`)
	schoolPhonePattern      = regexp.MustCompile(`^\+?[0-9]{7,15}$`)
	schoolTimezonePattern   = regexp.MustCompile(`^[A-Za-z_]+/[A-Za-z_]+$|^UTC$`)
)

func (h *SchoolHandler) GetSchools(c *gin.Context) {
	var schools []models.School
	database.DB.Where("id = ?", scopedSchoolID(c)).Find(&schools)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: schools})
}

func (h *SchoolHandler) GetSchool(c *gin.Context) {
	id := c.Param("id")
	var school models.School
	if err := database.DB.First(&school, "id = ? AND id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "School not found"})
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: school})
}

func (h *SchoolHandler) GetCurrentSchool(c *gin.Context) {
	var school models.School
	if err := database.DB.First(&school, "id = ?", scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "School not found"})
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: school})
}

func (h *SchoolHandler) UpdateCurrentSchool(c *gin.Context) {
	var payload map[string]interface{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := validateCurrentSchoolPayload(payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	updates := map[string]interface{}{"updated_at": time.Now().UTC()}
	fieldMap := map[string]string{
		"name":                "name",
		"school_type":         "school_type",
		"affiliation_board":   "affiliation_board",
		"email":               "email",
		"phone":               "phone",
		"website":             "website",
		"logo_url":            "logo_url",
		"address_line1":       "address_line1",
		"address_line2":       "address_line2",
		"city":                "city",
		"state":               "state",
		"postal_code":         "postal_code",
		"principal_name":      "principal_name",
		"registration_number": "registration_no",
		"udise_code":          "udise_code",
		"established_year":    "established_year",
		"motto":               "motto",
		"timezone":            "timezone",
		"currency":            "currency",
	}
	for requestKey, columnName := range fieldMap {
		if value, ok := payload[requestKey]; ok {
			updates[columnName] = normalizedSchoolProfileValue(requestKey, value)
		}
	}
	id := scopedSchoolID(c)
	if err := database.DB.Model(&models.School{}).Where("id = ?", id).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update school"})
		return
	}
	auditAction(c, "schools", "update", "schools", &id)
	h.GetCurrentSchool(c)
}

func validateCurrentSchoolPayload(payload map[string]interface{}) error {
	required := map[string]string{
		"name":                "school name",
		"school_type":         "school type",
		"affiliation_board":   "affiliation board",
		"email":               "school email",
		"phone":               "school phone",
		"address_line1":       "address line 1",
		"city":                "city",
		"state":               "state",
		"postal_code":         "postal code",
		"principal_name":      "principal name",
		"registration_number": "registration number",
		"established_year":    "established year",
		"timezone":            "timezone",
		"currency":            "currency",
	}
	limits := map[string]int{
		"name":                120,
		"school_type":         80,
		"affiliation_board":   80,
		"email":               160,
		"phone":               24,
		"website":             180,
		"address_line1":       160,
		"address_line2":       160,
		"city":                80,
		"state":               80,
		"postal_code":         12,
		"principal_name":      120,
		"registration_number": 80,
		"udise_code":          11,
		"established_year":    4,
		"motto":               180,
		"timezone":            64,
		"currency":            3,
	}
	for key, label := range required {
		if _, ok := payload[key]; ok && schoolPayloadText(payload[key]) == "" {
			return fmt.Errorf("%s is required", label)
		}
	}
	for key, max := range limits {
		if value, ok := payload[key]; ok && len(schoolPayloadText(value)) > max {
			return fmt.Errorf("%s must be %d characters or less", key, max)
		}
	}
	if email := schoolPayloadText(payload["email"]); email != "" {
		if _, err := mail.ParseAddress(email); err != nil {
			return fmt.Errorf("school email is invalid")
		}
	}
	if phone := schoolPayloadText(payload["phone"]); phone != "" {
		normalized := strings.NewReplacer(" ", "", "-", "", "(", "", ")", "").Replace(phone)
		if !schoolPhonePattern.MatchString(normalized) {
			return fmt.Errorf("school phone is invalid")
		}
	}
	if website := schoolPayloadText(payload["website"]); website != "" {
		parsed, err := url.Parse(website)
		if err != nil || !parsed.IsAbs() || parsed.Host == "" || (parsed.Scheme != "http" && parsed.Scheme != "https") {
			return fmt.Errorf("website must start with http:// or https://")
		}
	}
	if postal := schoolPayloadText(payload["postal_code"]); postal != "" && !schoolPostalPattern.MatchString(postal) {
		return fmt.Errorf("postal code is invalid")
	}
	if registration := schoolPayloadText(payload["registration_number"]); registration != "" && !schoolIdentifierPattern.MatchString(registration) {
		return fmt.Errorf("registration number contains unsupported characters")
	}
	if udise := schoolPayloadText(payload["udise_code"]); udise != "" {
		if !regexp.MustCompile(`^[0-9]{11}$`).MatchString(udise) {
			return fmt.Errorf("udise code must be exactly 11 digits")
		}
	}
	if established := schoolPayloadText(payload["established_year"]); established != "" {
		year, err := strconv.Atoi(established)
		if err != nil || year < 1800 || year > time.Now().UTC().Year() {
			return fmt.Errorf("established year is invalid")
		}
	}
	if timezone := schoolPayloadText(payload["timezone"]); timezone != "" && !schoolTimezonePattern.MatchString(timezone) {
		return fmt.Errorf("timezone must be an IANA timezone like Asia/Kolkata or UTC")
	}
	if currency := schoolPayloadText(payload["currency"]); currency != "" {
		if !regexp.MustCompile(`^[A-Za-z]{3}$`).MatchString(currency) {
			return fmt.Errorf("currency must be a 3-letter code")
		}
	}
	return nil
}

func schoolPayloadText(value interface{}) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(value))
}

func normalizedSchoolProfileValue(key string, value interface{}) interface{} {
	text := schoolPayloadText(value)
	if key == "currency" {
		return strings.ToUpper(text)
	}
	return text
}

func (h *SchoolHandler) UploadCurrentSchoolLogo(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	file, err := c.FormFile("logo")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Logo file is required"})
		return
	}
	if file.Size > 3*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Logo file must be 3 MB or smaller"})
		return
	}
	ext := strings.ToLower(filepath.Ext(file.Filename))
	switch ext {
	case ".jpg", ".jpeg", ".png", ".webp":
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Logo must be a JPG, PNG, or WebP image"})
		return
	}
	if err := os.MkdirAll("uploads/schools", 0o755); err != nil {
		log.Printf("school logo upload storage preparation failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to prepare upload storage"})
		return
	}
	filename := fmt.Sprintf("%s_logo_%d%s", schoolID, time.Now().UnixNano(), ext)
	relativePath := filepath.ToSlash(filepath.Join("uploads", "schools", filename))
	if err := c.SaveUploadedFile(file, relativePath); err != nil {
		log.Printf("school logo upload save failed for school %s: %v", schoolID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save logo"})
		return
	}
	publicPath := "/" + relativePath
	if err := database.DB.Model(&models.School{}).Where("id = ?", schoolID).Updates(map[string]interface{}{
		"logo_url":   publicPath,
		"updated_at": time.Now().UTC(),
	}).Error; err != nil {
		log.Printf("school logo database update failed for school %s: %v", schoolID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update school logo"})
		return
	}
	auditAction(c, "schools", "update_logo", "schools", &schoolID)
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"logo_url": publicPath,
		},
	})
}

func (h *SchoolHandler) CreateSchool(c *gin.Context) {
	var req models.CreateSchoolRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	school := models.School{
		Name:             req.Name,
		SchoolType:       req.SchoolType,
		AffiliationBoard: req.AffiliationBoard,
		Email:            req.Email,
		Phone:            req.Phone,
		City:             req.City,
		State:            req.State,
		Timezone:         req.Timezone,
		Currency:         req.Currency,
	}

	if err := database.DB.Create(&school).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create school"})
		return
	}

	id := school.ID
	auditAction(c, "schools", "create", "schools", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: school})
}

func (h *SchoolHandler) GetAcademicYears(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	var years []models.AcademicYear
	query := database.DB.Preload("Terms")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	query.Find(&years)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: years})
}

func (h *SchoolHandler) GetAcademicYear(c *gin.Context) {
	id := c.Param("id")
	var year models.AcademicYear
	if err := database.DB.Preload("Terms").Preload("Holidays").First(&year, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Academic year not found"})
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: year})
}

func (h *SchoolHandler) CreateAcademicYear(c *gin.Context) {
	var req models.CreateAcademicYearRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	yearLabel := strings.TrimSpace(req.YearLabel)
	startDate, endDate, ok := parseAcademicYearDates(c, req.StartDate, req.EndDate)
	if !ok {
		return
	}

	year := models.AcademicYear{
		SchoolID:  scopedSchoolID(c),
		YearLabel: yearLabel,
		Year:      yearLabel,
		StartDate: startDate,
		EndDate:   endDate,
		IsCurrent: req.IsCurrent,
		Status:    "active",
	}

	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if req.IsCurrent {
			if err := tx.Model(&models.AcademicYear{}).
				Where("school_id = ?", scopedSchoolID(c)).
				Update("is_current", false).Error; err != nil {
				return err
			}
		}
		if err := tx.Create(&year).Error; err != nil {
			return err
		}
		return ensureDefaultAcademicYearTerm(tx, year)
	}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create academic year"})
		return
	}

	id := year.ID
	auditAction(c, "academic_years", "create", "academic_years", &id)
	invalidateAcademicYearCaches()
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: year})
}

func (h *SchoolHandler) UpdateAcademicYear(c *gin.Context) {
	id := c.Param("id")
	var year models.AcademicYear
	if err := database.DB.First(&year, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Academic year not found"})
		return
	}
	var req models.CreateAcademicYearRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	yearLabel := strings.TrimSpace(req.YearLabel)
	startDate, endDate, ok := parseAcademicYearDates(c, req.StartDate, req.EndDate)
	if !ok {
		return
	}
	year.YearLabel = yearLabel
	year.Year = yearLabel
	year.StartDate = startDate
	year.EndDate = endDate
	year.IsCurrent = req.IsCurrent
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if req.IsCurrent {
			if err := tx.Model(&models.AcademicYear{}).
				Where("school_id = ? AND id <> ?", scopedSchoolID(c), id).
				Update("is_current", false).Error; err != nil {
				return err
			}
		}
		return tx.Save(&year).Error
	}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update academic year"})
		return
	}
	auditAction(c, "academic_years", "update", "academic_years", &id)
	invalidateAcademicYearCaches()
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: year})
}

func (h *SchoolHandler) DeleteAcademicYear(c *gin.Context) {
	id := c.Param("id")
	schoolID := scopedSchoolID(c)
	var year models.AcademicYear
	if err := database.DB.First(&year, "id = ? AND school_id = ?", id, schoolID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Academic year not found"})
		return
	}
	hasLinks, err := academicYearHasCascadeLinks(database.DB, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to validate academic record links"})
		return
	}
	if hasLinks && strings.ToLower(strings.TrimSpace(c.Query("cascade"))) != "true" {
		c.JSON(http.StatusConflict, models.APIResponse{
			Success: false,
			Error:   "Cascade confirmation is required to delete linked academic year records",
		})
		return
	}
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := cascadeAcademicYearLinks(tx, id); err != nil {
			return err
		}
		if err := tx.Delete(&models.AcademicYear{}, "id = ? AND school_id = ?", id, schoolID).Error; err != nil {
			return err
		}
		if year.IsCurrent {
			return promoteLatestAcademicYear(tx, schoolID)
		}
		return nil
	}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to delete academic year"})
		return
	}
	auditAction(c, "academic_years", "delete", "academic_years", &id)
	invalidateAcademicYearCaches()
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: gin.H{"id": id}, Message: "Academic year deleted successfully"})
}

func academicYearHasCascadeLinks(tx *gorm.DB, academicYearID string) (bool, error) {
	refs := []academicReference{
		academicRef("sections", &models.Section{}, "academic_year_id = ?", academicYearID),
		academicRef("terms", &models.Term{}, "academic_year_id = ?", academicYearID),
		academicRef("holidays", &models.Holiday{}, "academic_year_id = ?", academicYearID),
		academicRef("enrollments", &models.Enrollment{}, "academic_year_id = ?", academicYearID),
		academicRef("attendance sessions", &models.AttendanceSession{}, "academic_year_id = ?", academicYearID),
		academicRef("attendance summaries", &models.AttendanceSummary{}, "academic_year_id = ?", academicYearID),
		academicRef("fee structures", &models.FeeStructure{}, "academic_year_id = ?", academicYearID),
		academicRef("fee invoices", &models.FeeInvoice{}, "academic_year_id = ?", academicYearID),
		academicRef("fee concessions", &models.FeeConcession{}, "academic_year_id = ?", academicYearID),
		academicRef("timetable slots", &models.TimetableSlot{}, "academic_year_id = ?", academicYearID),
		academicRef("events", &models.EventCalendar{}, "academic_year_id = ?", academicYearID),
		academicRef("exams", &models.Exam{}, "academic_year_id = ?", academicYearID),
		academicRef("grade subjects", &models.GradeSubject{}, "academic_year_id = ?", academicYearID),
		academicRef("staff subjects", &models.StaffSubject{}, "academic_year_id = ?", academicYearID),
	}
	for _, ref := range refs {
		var count int64
		if err := tx.Model(ref.model).Where(ref.query, ref.args...).Count(&count).Error; err != nil {
			return false, err
		}
		if count > 0 {
			return true, nil
		}
	}
	return false, nil
}

func cascadeAcademicYearLinks(tx *gorm.DB, academicYearID string) error {
	termIDs, err := pluckAcademicDeleteIDs(tx, &models.Term{}, "id", "academic_year_id = ?", academicYearID)
	if err != nil {
		return err
	}
	sectionIDs, err := pluckAcademicDeleteIDs(tx, &models.Section{}, "id", "academic_year_id = ?", academicYearID)
	if err != nil {
		return err
	}
	slotIDs, err := pluckAcademicDeleteIDs(tx, &models.TimetableSlot{}, "id", "academic_year_id = ?", academicYearID)
	if err != nil {
		return err
	}
	sessionIDs, err := pluckAcademicDeleteIDs(tx, &models.AttendanceSession{}, "id", "academic_year_id = ?", academicYearID)
	if err != nil {
		return err
	}
	invoiceIDs, err := pluckAcademicDeleteIDs(tx, &models.FeeInvoice{}, "id", "academic_year_id = ?", academicYearID)
	if err != nil {
		return err
	}
	examIDs, err := pluckAcademicDeleteIDs(tx, &models.Exam{}, "id", "academic_year_id = ?", academicYearID)
	if err != nil {
		return err
	}
	eventIDs, err := pluckAcademicDeleteIDs(tx, &models.EventCalendar{}, "id", "academic_year_id = ?", academicYearID)
	if err != nil {
		return err
	}
	homeworkIDs := []string{}
	if len(sectionIDs) > 0 {
		homeworkIDs, err = pluckAcademicDeleteIDs(tx, &models.Homework{}, "id", "section_id IN ?", sectionIDs)
		if err != nil {
			return err
		}
	}
	examScheduleIDs := []string{}
	if len(examIDs) > 0 {
		examScheduleIDs, err = pluckAcademicDeleteIDs(tx, &models.ExamSchedule{}, "id", "exam_id IN ?", examIDs)
		if err != nil {
			return err
		}
	}

	if err := deleteAcademicLinkedRows(tx, &models.StudentMark{}, "exam_schedule_id IN ?", examScheduleIDs); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.ReportCard{}, "exam_id IN ?", examIDs); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.ExamSchedule{}, "exam_id IN ?", examIDs); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.Exam{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.StudentAttendance{}, "session_id IN ?", sessionIDs); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.AttendanceSession{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.AttendanceSummary{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.FeeInvoiceItem{}, "invoice_id IN ?", invoiceIDs); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.Payment{}, "invoice_id IN ?", invoiceIDs); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.ParentPaymentRequest{}, "invoice_id IN ?", invoiceIDs); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.FeeInvoice{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.FeeStructure{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.FeeConcession{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.Substitution{}, "timetable_slot_id IN ?", slotIDs); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.TimetableSlot{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.ParentTeacherMeeting{}, "event_id IN ?", eventIDs); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.EventCalendar{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.HomeworkSubmission{}, "homework_id IN ?", homeworkIDs); err != nil {
		return err
	}
	if len(sectionIDs) > 0 {
		if err := tx.Where("current_section_id IN ?", sectionIDs).Model(&models.Student{}).Update("current_section_id", nil).Error; err != nil {
			return err
		}
	}
	if err := deleteAcademicLinkedRows(tx, &models.Homework{}, "section_id IN ?", sectionIDs); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.DiaryEntry{}, "section_id IN ?", sectionIDs); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.StaffSubject{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.GradeSubject{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.Enrollment{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.Section{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.Holiday{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	if err := deleteAcademicLinkedRows(tx, &models.Term{}, "academic_year_id = ?", academicYearID); err != nil {
		return err
	}
	_ = termIDs
	return nil
}

func pluckAcademicDeleteIDs(tx *gorm.DB, model interface{}, column, query string, args ...interface{}) ([]string, error) {
	ids := []string{}
	if err := tx.Model(model).Where(query, args...).Pluck(column, &ids).Error; err != nil {
		return nil, err
	}
	return ids, nil
}

func deleteAcademicLinkedRows(tx *gorm.DB, model interface{}, query string, args ...interface{}) error {
	for _, arg := range args {
		if ids, ok := arg.([]string); ok && len(ids) == 0 {
			return nil
		}
	}
	return tx.Where(query, args...).Delete(model).Error
}

func promoteLatestAcademicYear(tx *gorm.DB, schoolID string) error {
	var replacement models.AcademicYear
	err := tx.Where("school_id = ?", schoolID).
		Order("start_date DESC, created_at DESC").
		First(&replacement).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil
	}
	if err != nil {
		return err
	}
	if err := tx.Model(&models.AcademicYear{}).Where("school_id = ?", schoolID).Update("is_current", false).Error; err != nil {
		return err
	}
	return tx.Model(&models.AcademicYear{}).Where("id = ?", replacement.ID).Update("is_current", true).Error
}

func invalidateAcademicYearCaches() {
	if services.Cache == nil {
		return
	}
	ctx := context.Background()
	if err := services.Cache.DeleteByPrefix(ctx, "academic_years_list"); err != nil {
		log.Printf("academic year list cache invalidation failed: %v", err)
	}
	if err := services.Cache.DeleteByPrefix(ctx, "academic_years_detail"); err != nil {
		log.Printf("academic year detail cache invalidation failed: %v", err)
	}
}

func parseAcademicYearDates(c *gin.Context, startValue, endValue string) (time.Time, time.Time, bool) {
	startDate, err := time.Parse("2006-01-02", strings.TrimSpace(startValue))
	if err != nil {
		fail(c, http.StatusBadRequest, "start_date must use YYYY-MM-DD")
		return time.Time{}, time.Time{}, false
	}
	endDate, err := time.Parse("2006-01-02", strings.TrimSpace(endValue))
	if err != nil {
		fail(c, http.StatusBadRequest, "end_date must use YYYY-MM-DD")
		return time.Time{}, time.Time{}, false
	}
	if endDate.Before(startDate) {
		fail(c, http.StatusBadRequest, "end_date cannot be before start_date")
		return time.Time{}, time.Time{}, false
	}
	return startDate, endDate, true
}

func (h *SchoolHandler) GetGrades(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	var grades []models.Grade
	query := database.DB.Preload("Sections")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	query.Find(&grades)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: grades})
}

func (h *SchoolHandler) GetGrade(c *gin.Context) {
	id := c.Param("id")
	var grade models.Grade
	if err := database.DB.Preload("Sections").Preload("GradeSubjects").First(&grade, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Grade not found"})
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: grade})
}

func (h *SchoolHandler) CreateGrade(c *gin.Context) {
	var req models.CreateGradeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	grade := models.Grade{
		SchoolID:    scopedSchoolID(c),
		GradeNumber: req.GradeNumber,
		GradeName:   req.GradeName,
	}

	if err := database.DB.Create(&grade).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create grade"})
		return
	}

	id := grade.ID
	auditAction(c, "grades", "create", "grades", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: grade})
}

func (h *SchoolHandler) UpdateGrade(c *gin.Context) {
	id := c.Param("id")
	var grade models.Grade
	if err := database.DB.First(&grade, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Grade not found"})
		return
	}
	var req models.CreateGradeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	grade.GradeNumber = req.GradeNumber
	grade.GradeName = req.GradeName
	if err := database.DB.Save(&grade).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update grade"})
		return
	}
	auditAction(c, "grades", "update", "grades", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: grade})
}

func (h *SchoolHandler) DeleteGrade(c *gin.Context) {
	id := c.Param("id")
	var grade models.Grade
	if err := database.DB.First(&grade, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Grade not found"})
		return
	}
	if blockAcademicDelete(c,
		academicRef("sections", &models.Section{}, "grade_id = ?", id),
		academicRef("subject mappings", &models.GradeSubject{}, "grade_id = ?", id),
		academicRef("fee structures", &models.FeeStructure{}, "grade_id = ?", id),
	) {
		return
	}
	if err := database.DB.Delete(&models.Grade{}, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to delete grade"})
		return
	}
	auditAction(c, "grades", "delete", "grades", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: gin.H{"id": id}, Message: "Grade deleted successfully"})
}

func (h *SchoolHandler) GetSections(c *gin.Context) {
	gradeID := c.Query("grade_id")
	yearID := c.Query("academic_year_id")
	schoolID := scopedSchoolID(c)
	var sections []models.Section
	query := database.DB.
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Preload("Grade").
		Preload("ClassTeacher").
		Preload("Room")
	if schoolID != "" {
		query = query.Where("grades.school_id = ?", schoolID)
	}
	if gradeID != "" {
		query = query.Where("sections.grade_id = ?", gradeID)
	}
	if yearID != "" {
		query = query.Where("sections.academic_year_id = ?", yearID)
	}
	switch currentRole(c) {
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" {
			query = query.Where("1 = 0")
		} else {
			query = query.Where("sections.id IN (?)", teacherSectionSubquery(staffID, schoolID))
		}
	case "parent":
		query = query.Where("sections.id IN (?)", linkedSectionSubquery(c))
	}
	query.Find(&sections)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: sections})
}

func (h *SchoolHandler) GetSection(c *gin.Context) {
	id := c.Param("id")
	if !canAccessSection(c, id) {
		c.JSON(http.StatusNotFound, gin.H{"error": "Section not found"})
		return
	}
	var section models.Section
	if err := database.DB.
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Preload("Grade").
		Preload("ClassTeacher").
		Preload("Room").
		Preload("AcademicYear").
		First(&section, "sections.id = ? AND grades.school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Section not found"})
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: section})
}

func resolveSectionOptionalRefs(c *gin.Context, req models.CreateSectionRequest) (*string, *string, *string, bool) {
	schoolID := scopedSchoolID(c)
	var grade models.Grade
	if err := database.DB.First(&grade, "id = ? AND school_id = ?", req.GradeID, schoolID).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Grade must belong to this school"})
		return nil, nil, nil, false
	}

	if err := academicDomainService().EnsureAcademicYearWritable(schoolID, req.AcademicYearID); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return nil, nil, nil, false
	}

	var classTeacherID *string
	if trimmed := strings.TrimSpace(req.ClassTeacherID); trimmed != "" {
		var staff models.Staff
		if err := database.DB.First(&staff, "id = ? AND school_id = ? AND status = ?", trimmed, schoolID, "active").Error; err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Class teacher must be active staff in this school"})
			return nil, nil, nil, false
		}
		classTeacherID = &trimmed
	}

	var coTeacherID *string
	if trimmed := strings.TrimSpace(req.CoTeacherID); trimmed != "" {
		var staff models.Staff
		if err := database.DB.First(&staff, "id = ? AND school_id = ? AND status = ?", trimmed, schoolID, "active").Error; err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Co-teacher must be active staff in this school"})
			return nil, nil, nil, false
		}
		coTeacherID = &trimmed
	}

	var roomID *string
	if trimmed := strings.TrimSpace(req.RoomID); trimmed != "" {
		var room models.Room
		if err := database.DB.First(&room, "id = ? AND school_id = ?", trimmed, schoolID).Error; err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Room must belong to this school"})
			return nil, nil, nil, false
		}
		roomID = &trimmed
	}

	return classTeacherID, coTeacherID, roomID, true
}

func (h *SchoolHandler) CreateSection(c *gin.Context) {
	var req models.CreateSectionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	classTeacherID, coTeacherID, roomID, ok := resolveSectionOptionalRefs(c, req)
	if !ok {
		return
	}

	section := models.Section{
		SchoolID:       scopedSchoolID(c),
		GradeID:        req.GradeID,
		AcademicYearID: req.AcademicYearID,
		SectionName:    req.SectionName,
		Capacity:       req.Capacity,
		ClassTeacherID: classTeacherID,
		CoTeacherID:    coTeacherID,
		RoomID:         roomID,
	}

	if err := database.DB.Create(&section).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create section"})
		return
	}

	id := section.ID
	auditAction(c, "sections", "create", "sections", &id)
	database.DB.Preload("Grade").Preload("ClassTeacher").Preload("CoTeacher").Preload("Room").First(&section, "id = ?", section.ID)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: section})
}

func (h *SchoolHandler) UpdateSection(c *gin.Context) {
	id := c.Param("id")
	var section models.Section
	if err := database.DB.
		Joins("JOIN grades ON grades.id = sections.grade_id").
		First(&section, "sections.id = ? AND grades.school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Section not found"})
		return
	}
	var req models.CreateSectionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	classTeacherID, coTeacherID, roomID, ok := resolveSectionOptionalRefs(c, req)
	if !ok {
		return
	}
	section.GradeID = req.GradeID
	section.SchoolID = scopedSchoolID(c)
	section.AcademicYearID = req.AcademicYearID
	section.SectionName = req.SectionName
	section.Capacity = req.Capacity
	section.ClassTeacherID = classTeacherID
	section.CoTeacherID = coTeacherID
	section.RoomID = roomID
	if err := database.DB.Save(&section).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update section"})
		return
	}
	auditAction(c, "sections", "update", "sections", &id)
	database.DB.Preload("Grade").Preload("ClassTeacher").Preload("CoTeacher").Preload("Room").Preload("AcademicYear").First(&section, "id = ?", section.ID)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: section})
}

func (h *SchoolHandler) DeleteSection(c *gin.Context) {
	id := c.Param("id")
	schoolID := scopedSchoolID(c)
	var section models.Section
	if err := database.DB.
		Joins("JOIN grades ON grades.id = sections.grade_id").
		First(&section, "sections.id = ? AND grades.school_id = ?", id, schoolID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Section not found"})
		return
	}

	if err := deleteSectionRecordsForSchool(id, schoolID); err != nil {
		if errors.Is(err, errSectionHasActiveStudents) {
			c.JSON(http.StatusConflict, gin.H{"success": false, "error": "Cannot delete while linked students are active"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to delete section"})
		return
	}
	auditAction(c, "sections", "delete", "sections", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: gin.H{"id": id}, Message: "Section and linked class records deleted successfully"})
}

func deleteSectionRecordsForSchool(id, schoolID string) error {
	activeCount, err := activeSectionStudentCount(id, schoolID)
	if err != nil {
		return err
	}
	if activeCount > 0 {
		return errSectionHasActiveStudents
	}

	return database.DB.Transaction(func(tx *gorm.DB) error {
		var section models.Section
		if err := tx.
			Joins("JOIN grades ON grades.id = sections.grade_id").
			First(&section, "sections.id = ? AND grades.school_id = ?", id, schoolID).Error; err != nil {
			return err
		}
		var siblingCount int64
		if err := tx.Model(&models.Section{}).
			Joins("JOIN grades ON grades.id = sections.grade_id").
			Where(
				"grades.school_id = ? AND sections.id <> ? AND sections.grade_id = ? AND sections.academic_year_id = ?",
				schoolID,
				id,
				section.GradeID,
				section.AcademicYearID,
			).
			Count(&siblingCount).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM student_attendances WHERE session_id IN (SELECT id FROM attendance_sessions WHERE section_id = ?)", id).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM student_attendances WHERE enrollment_id IN (SELECT id FROM enrollments WHERE section_id = ?)", id).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM attendance_summaries WHERE section_id = ?", id).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM attendance_sessions WHERE section_id = ?", id).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM substitutions WHERE timetable_slot_id IN (SELECT id FROM timetable_slots WHERE section_id = ?)", id).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM timetable_slots WHERE section_id = ?", id).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM student_marks WHERE exam_schedule_id IN (SELECT id FROM exam_schedules WHERE section_id = ?)", id).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM student_marks WHERE enrollment_id IN (SELECT id FROM enrollments WHERE section_id = ?)", id).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM exam_schedules WHERE section_id = ?", id).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM report_cards WHERE enrollment_id IN (SELECT id FROM enrollments WHERE section_id = ?)", id).Error; err != nil {
			return err
		}
		if err := deleteSectionHomework(tx, id); err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM diary_entries WHERE section_id = ?", id).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM parent_teacher_meetings WHERE section_id = ?", id).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM staff_subjects WHERE section_id = ?", id).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM enrollments WHERE section_id = ?", id).Error; err != nil {
			return err
		}
		if err := tx.Model(&models.Student{}).
			Where("school_id = ? AND current_section_id = ?", schoolID, id).
			Update("current_section_id", nil).Error; err != nil {
			return err
		}
		if siblingCount == 0 {
			if err := tx.Delete(&models.FeeStructure{}, "school_id = ? AND grade_id = ? AND academic_year_id = ?", schoolID, section.GradeID, section.AcademicYearID).Error; err != nil {
				return err
			}
			if err := tx.Delete(&models.GradeSubject{}, "grade_id = ? AND academic_year_id = ?", section.GradeID, section.AcademicYearID).Error; err != nil {
				return err
			}
		}
		return tx.Delete(&models.Section{}, "id = ?", id).Error
	})
}

func deleteSectionHomework(tx *gorm.DB, sectionID string) error {
	var homeworkIDs []string
	if err := tx.Model(&models.Homework{}).Where("section_id = ?", sectionID).Pluck("id", &homeworkIDs).Error; err != nil {
		return err
	}
	if len(homeworkIDs) > 0 {
		if err := tx.Where("homework_id IN ?", homeworkIDs).Delete(&models.HomeworkSubmission{}).Error; err != nil {
			return err
		}
	}
	if err := tx.Where("section_id = ?", sectionID).Delete(&models.Homework{}).Error; err != nil {
		return err
	}

	if tx.Migrator().HasTable("homework") && tx.Migrator().HasColumn("homework", "homework_id") {
		if err := tx.Exec("DELETE FROM homework_submissions WHERE homework_id IN (SELECT homework_id FROM homework WHERE section_id = ?)", sectionID).Error; err != nil {
			return err
		}
		if err := tx.Exec("DELETE FROM homework WHERE section_id = ?", sectionID).Error; err != nil {
			return err
		}
	}
	return nil
}

func activeSectionStudentCount(sectionID, schoolID string) (int64, error) {
	var currentCount int64
	if err := database.DB.Model(&models.Student{}).
		Where("school_id = ? AND current_section_id = ? AND LOWER(COALESCE(status, '')) != ?", schoolID, sectionID, "inactive").
		Count(&currentCount).Error; err != nil {
		return 0, err
	}
	var enrollmentCount int64
	if err := database.DB.Table("enrollments").
		Joins("JOIN students ON students.id = enrollments.student_id").
		Where(`
			enrollments.section_id = ?
			AND students.school_id = ?
			AND LOWER(COALESCE(students.status, '')) != ?
			AND LOWER(COALESCE(enrollments.status, '')) IN ?
		`, sectionID, schoolID, "inactive", []string{"", "active", "enrolled"}).
		Count(&enrollmentCount).Error; err != nil {
		return 0, err
	}
	return currentCount + enrollmentCount, nil
}

func (h *SchoolHandler) GetDepartments(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	var depts []models.Department
	query := database.DB.Preload("HODStaff")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	query.Find(&depts)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: depts})
}

func (h *SchoolHandler) CreateDepartment(c *gin.Context) {
	var req struct {
		SchoolID       string `json:"school_id" binding:"required"`
		DepartmentName string `json:"department_name" binding:"required"`
		Description    string `json:"description"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	dept := models.Department{
		SchoolID:       scopedSchoolID(c),
		DepartmentName: req.DepartmentName,
		Description:    req.Description,
	}

	if err := database.DB.Create(&dept).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create department"})
		return
	}

	id := dept.ID
	auditAction(c, "departments", "create", "departments", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: dept})
}

func (h *SchoolHandler) GetSubjects(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	deptID := c.Query("department_id")
	var subjects []models.Subject
	query := database.DB.Preload("Department")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	if deptID != "" {
		query = query.Where("department_id = ?", deptID)
	}
	query.Find(&subjects)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: subjects})
}

func (h *SchoolHandler) CreateSubject(c *gin.Context) {
	var req models.CreateSubjectRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	departmentID, err := h.resolveAcademicDepartmentID(req.DepartmentID, req.DepartmentName, scopedSchoolID(c))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to resolve department"})
		return
	}
	subject := models.Subject{
		SchoolID:     scopedSchoolID(c),
		DepartmentID: departmentID,
		SubjectName:  req.SubjectName,
		SubjectCode:  req.SubjectCode,
		SubjectType:  req.SubjectType,
		SubjectColor: req.SubjectColor,
		CreditHours:  req.CreditHours,
	}

	if err := database.DB.Create(&subject).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create subject"})
		return
	}

	id := subject.ID
	auditAction(c, "subjects", "create", "subjects", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: subject})
}

func (h *SchoolHandler) UpdateSubject(c *gin.Context) {
	id := c.Param("id")
	var subject models.Subject
	if err := database.DB.First(&subject, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Subject not found"})
		return
	}
	var req models.CreateSubjectRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	departmentID, err := h.resolveAcademicDepartmentID(req.DepartmentID, req.DepartmentName, scopedSchoolID(c))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to resolve department"})
		return
	}
	subject.DepartmentID = departmentID
	subject.SubjectName = req.SubjectName
	subject.SubjectCode = req.SubjectCode
	subject.SubjectType = req.SubjectType
	subject.SubjectColor = req.SubjectColor
	subject.CreditHours = req.CreditHours
	if err := database.DB.Save(&subject).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update subject"})
		return
	}
	auditAction(c, "subjects", "update", "subjects", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: subject})
}

func (h *SchoolHandler) DeleteSubject(c *gin.Context) {
	id := c.Param("id")
	var subject models.Subject
	if err := database.DB.First(&subject, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Subject not found"})
		return
	}
	if blockAcademicDelete(c,
		academicRef("attendance sessions", &models.AttendanceSession{}, "subject_id = ?", id),
	) {
		return
	}
	var markCount int64
	if err := database.DB.Model(&models.StudentMark{}).
		Joins("JOIN exam_schedules ON exam_schedules.id = student_marks.exam_schedule_id").
		Where("exam_schedules.subject_id = ?", id).
		Count(&markCount).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to validate subject marks"})
		return
	}
	if markCount > 0 {
		c.JSON(http.StatusConflict, gin.H{"success": false, "error": "Cannot delete while linked marks exist"})
		return
	}
	var reportCount int64
	if err := database.DB.Model(&models.ReportCard{}).
		Where("exam_id IN (SELECT exam_id FROM exam_schedules WHERE subject_id = ?)", id).
		Count(&reportCount).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to validate subject report cards"})
		return
	}
	if reportCount > 0 {
		c.JSON(http.StatusConflict, gin.H{"success": false, "error": "Cannot delete while linked report cards exist"})
		return
	}
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Exec("DELETE FROM substitutions WHERE timetable_slot_id IN (SELECT id FROM timetable_slots WHERE subject_id = ?)", id).Error; err != nil {
			return err
		}
		if err := tx.Delete(&models.TimetableSlot{}, "subject_id = ?", id).Error; err != nil {
			return err
		}
		if err := tx.Delete(&models.ExamSchedule{}, "subject_id = ?", id).Error; err != nil {
			return err
		}
		if err := tx.Delete(&models.StaffSubject{}, "subject_id = ?", id).Error; err != nil {
			return err
		}
		if err := tx.Delete(&models.GradeSubject{}, "subject_id = ?", id).Error; err != nil {
			return err
		}
		return tx.Delete(&models.Subject{}, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error
	}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to delete subject"})
		return
	}
	auditAction(c, "subjects", "delete", "subjects", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: gin.H{"id": id}, Message: "Subject and linked empty setup records deleted successfully"})
}

type academicReference struct {
	label string
	model interface{}
	query string
	args  []interface{}
}

func academicRef(label string, model interface{}, query string, args ...interface{}) academicReference {
	return academicReference{label: label, model: model, query: query, args: args}
}

func blockAcademicDelete(c *gin.Context, refs ...academicReference) bool {
	for _, ref := range refs {
		var count int64
		if err := database.DB.Model(ref.model).Where(ref.query, ref.args...).Count(&count).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to validate academic record links"})
			return true
		}
		if count > 0 {
			c.JSON(http.StatusConflict, models.APIResponse{
				Success: false,
				Error:   fmt.Sprintf("Cannot delete while linked %s exist", ref.label),
			})
			return true
		}
	}
	return false
}

func (h *SchoolHandler) resolveAcademicDepartmentID(departmentID string, departmentName string, schoolID string) (string, error) {
	deptValue := strings.TrimSpace(departmentID)
	nameValue := strings.TrimSpace(departmentName)
	if nameValue == "" {
		nameValue = deptValue
	}
	if deptValue != "" {
		var existing models.Department
		if err := database.DB.First(&existing, "id = ? AND school_id = ?", deptValue, schoolID).Error; err == nil {
			return existing.ID, nil
		}
	}
	if nameValue == "" {
		nameValue = "Academics"
	}
	var dept models.Department
	err := database.DB.Where("school_id = ? AND LOWER(department_name) = ?", schoolID, strings.ToLower(nameValue)).First(&dept).Error
	if err == nil {
		return dept.ID, nil
	}
	if err != gorm.ErrRecordNotFound {
		return "", err
	}
	dept = models.Department{
		SchoolID:       schoolID,
		DepartmentName: nameValue,
		Description:    "Created from academic management",
	}
	if err := database.DB.Create(&dept).Error; err != nil {
		return "", err
	}
	return dept.ID, nil
}

func (h *SchoolHandler) GetRooms(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	var rooms []models.Room
	query := database.DB.Preload("School")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	query.Find(&rooms)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: rooms})
}

func (h *SchoolHandler) CreateRoom(c *gin.Context) {
	var req struct {
		SchoolID   string `json:"school_id"`
		RoomNumber string `json:"room_number" binding:"required"`
		RoomType   string `json:"room_type" binding:"required"`
		Block      string `json:"block"`
		Floor      int    `json:"floor"`
		Capacity   int    `json:"capacity"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	room := models.Room{
		SchoolID:   scopedSchoolID(c),
		RoomNumber: req.RoomNumber,
		RoomType:   req.RoomType,
		Block:      req.Block,
		Floor:      req.Floor,
		Capacity:   req.Capacity,
	}

	if err := database.DB.Create(&room).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create room"})
		return
	}

	id := room.ID
	auditAction(c, "rooms", "create", "rooms", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: room})
}

func (h *SchoolHandler) GetTerms(c *gin.Context) {
	yearID := c.Param("id")
	if yearID == "" {
		yearID = c.Param("year_id")
	}
	if !academicYearBelongsToSchool(yearID, scopedSchoolID(c)) {
		fail(c, http.StatusNotFound, "Academic year not found")
		return
	}
	var year models.AcademicYear
	if err := database.DB.First(&year, "id = ? AND school_id = ?", yearID, scopedSchoolID(c)).Error; err != nil {
		fail(c, http.StatusNotFound, "Academic year not found")
		return
	}
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		return ensureDefaultAcademicYearTerm(tx, year)
	}); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to prepare academic terms")
		return
	}
	var terms []models.Term
	database.DB.Where("academic_year_id = ?", yearID).Order("term_number ASC, start_date ASC").Find(&terms)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: terms})
}

func ensureDefaultAcademicYearTerm(tx *gorm.DB, year models.AcademicYear) error {
	if strings.TrimSpace(year.ID) == "" {
		return errors.New("academic year is required")
	}
	var count int64
	if err := tx.Model(&models.Term{}).
		Where("academic_year_id = ?", year.ID).
		Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	return tx.Create(&models.Term{
		AcademicYearID: year.ID,
		TermNumber:     1,
		TermName:       "Term 1",
		StartDate:      year.StartDate,
		EndDate:        year.EndDate,
		IsCurrent:      true,
	}).Error
}

func (h *SchoolHandler) PaginationMeta(page, pageSize int, total int64) map[string]int {
	totalPages := int(total) / pageSize
	if int(total)%pageSize > 0 {
		totalPages++
	}
	return map[string]int{
		"page":        page,
		"page_size":   pageSize,
		"total":       int(total),
		"total_pages": totalPages,
	}
}

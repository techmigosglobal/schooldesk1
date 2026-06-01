package handlers

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"
	"github.com/gin-gonic/gin"
)

type BulkImportHandler struct {
	importService *services.BulkImportService
}

func NewBulkImportHandler() *BulkImportHandler {
	return &BulkImportHandler{
		importService: services.NewBulkImportService(),
	}
}

// BulkImport handles CSV file uploads for bulk importing users
func (h *BulkImportHandler) BulkImport(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	userID := c.GetString("user_id")
	
	// Verify only Principal can bulk import
	if !isPrincipal(c) {
		fail(c, http.StatusForbidden, "Only Principal role can perform bulk import")
		return
	}

	// Parse form data
	importTypeStr := strings.TrimSpace(c.PostForm("import_type"))
	dryRun := c.PostForm("dry_run") == "true"

	if importTypeStr == "" {
		fail(c, http.StatusBadRequest, "import_type is required (student|staff|parent)")
		return
	}

	// Validate import type
	importType := models.BulkImportType(importTypeStr)
	switch importType {
	case models.BulkImportTypeStudent, models.BulkImportTypeStaff, models.BulkImportTypeParent:
		// Valid
	default:
		fail(c, http.StatusBadRequest, "Invalid import_type. Must be one of: student, staff, parent")
		return
	}

	// Get uploaded file
	file, err := c.FormFile("file")
	if err != nil {
		fail(c, http.StatusBadRequest, "CSV file is required")
		return
	}

	// Validate file size (max 10MB)
	maxFileSize := int64(10 * 1024 * 1024)
	if file.Size > maxFileSize {
		fail(c, http.StatusBadRequest, fmt.Sprintf("File size exceeds maximum allowed size of %d MB", maxFileSize/(1024*1024)))
		return
	}

	// Validate file extension
	if !strings.HasSuffix(strings.ToLower(file.Filename), ".csv") {
		fail(c, http.StatusBadRequest, "Only CSV files are allowed")
		return
	}

	// Open file
	fileData, err := file.Open()
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to read uploaded file")
		return
	}
	defer fileData.Close()

	// Read file content
	buf := new(bytes.Buffer)
	if _, err := io.Copy(buf, fileData); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to process file")
		return
	}

	var response *models.BulkImportResponse
	var importErr error

	// Process based on import type
	switch importType {
	case models.BulkImportTypeStudent:
		response, importErr = h.handleStudentImport(schoolID, buf, dryRun)
	case models.BulkImportTypeStaff:
		response, importErr = h.handleStaffImport(schoolID, buf, dryRun)
	case models.BulkImportTypeParent:
		response, importErr = h.handleParentImport(schoolID, buf, dryRun)
	}

	if importErr != nil {
		log.Printf("Bulk import error for school %s: %v", schoolID, importErr)
		fail(c, http.StatusInternalServerError, fmt.Sprintf("Import failed: %v", importErr))
		return
	}

	// Create import job record
	if !dryRun && response.Success {
		job := models.BulkImportJob{
			SchoolID:     schoolID,
			ImportType:   string(importType),
			Status:       string(models.BulkImportStatusCompleted),
			TotalRecords: response.TotalRecords,
			SuccessCount: response.SuccessCount,
			FailureCount: response.FailureCount,
			InitiatedBy:  userID,
		}

		if err := database.DB.Create(&job).Error; err != nil {
			log.Printf("Failed to create bulk import job record: %v", err)
		}

		response.JobID = job.ID
	}

	c.JSON(http.StatusOK, response)
}

// GetImportTemplate returns CSV template for the specified import type
func (h *BulkImportHandler) GetImportTemplate(c *gin.Context) {
	importType := strings.TrimSpace(c.Query("import_type"))

	if importType == "" {
		fail(c, http.StatusBadRequest, "import_type query parameter is required")
		return
	}

	var content string

	switch importType {
	case "student":
		content = `first_name,last_name,email,phone,date_of_birth,gender,admission_number,admission_date,current_section_id,address,aadhar_number
John,Doe,john.doe@school.com,9876543210,2010-05-15,M,STU-001,2023-06-01,SEC-001,"123 Main Street, City",123456789012
Jane,Smith,jane.smith@school.com,9876543211,2011-03-20,F,STU-002,2023-06-01,SEC-001,"456 Oak Avenue, City",987654321098`

	case "staff":
		content = `first_name,last_name,email,phone,date_of_birth,gender,staff_code,department_id,designation,employment_type,join_date,basic_salary
Rajesh,Kumar,rajesh.kumar@school.com,9876543212,1990-01-15,M,STF-001,DEPT-001,Teacher,Permanent,2020-01-15,45000
Priya,Sharma,priya.sharma@school.com,9876543213,1992-06-20,F,STF-002,DEPT-002,HOD,Permanent,2019-03-01,65000`

	case "parent":
		content = `full_name,email,phone,relationship,occupation,student_admission_number
Mr. Rajesh Kumar,rajesh.kumar@email.com,9876543210,Father,Engineer,STU-001
Mrs. Anjali Kumar,anjali.kumar@email.com,9876543211,Mother,Doctor,STU-001`

	default:
		fail(c, http.StatusBadRequest, "Invalid import_type. Must be one of: student, staff, parent")
		return
	}

	c.Header("Content-Type", "text/csv")
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=template_%s.csv", importType))
	c.String(http.StatusOK, content)
}

// GetImportHistory returns the import history for the school
func (h *BulkImportHandler) GetImportHistory(c *gin.Context) {
	page, pageSize := parsePagination(c)
	schoolID := scopedSchoolID(c)

	var jobs []models.BulkImportJob
	var total int64

	query := database.DB.Model(&models.BulkImportJob{}).
		Where("school_id = ?", schoolID)

	query.Count(&total)
	if err := query.
		Order("created_at DESC").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Find(&jobs).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch import history")
		return
	}

	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, jobs))
}

// Helper functions

func (h *BulkImportHandler) handleStudentImport(schoolID string, fileData *bytes.Buffer, dryRun bool) (*models.BulkImportResponse, error) {
	records, parseErrors := h.importService.ParseStudentCSV(fileData)
	
	response := &models.BulkImportResponse{
		Success:      true,
		ImportType:   "student",
		TotalRecords: len(records) + len(parseErrors),
		IsDryRun:     dryRun,
		Errors:       make([]models.BulkImportErrorDetail, 0),
	}

	// Add parse errors to response
	for _, err := range parseErrors {
		// Try to extract row number from error message
		detail := models.BulkImportErrorDetail{
			ErrorMsg: err.Error(),
		}
		response.Errors = append(response.Errors, detail)
		response.FailureCount++
	}

	if len(records) == 0 {
		response.Message = "No valid records found in CSV"
		return response, nil
	}

	return h.importService.ImportStudents(schoolID, records, dryRun)
}

func (h *BulkImportHandler) handleStaffImport(schoolID string, fileData *bytes.Buffer, dryRun bool) (*models.BulkImportResponse, error) {
	records, parseErrors := h.importService.ParseStaffCSV(fileData)
	
	response := &models.BulkImportResponse{
		Success:      true,
		ImportType:   "staff",
		TotalRecords: len(records) + len(parseErrors),
		IsDryRun:     dryRun,
		Errors:       make([]models.BulkImportErrorDetail, 0),
	}

	// Add parse errors to response
	for _, err := range parseErrors {
		detail := models.BulkImportErrorDetail{
			ErrorMsg: err.Error(),
		}
		response.Errors = append(response.Errors, detail)
		response.FailureCount++
	}

	if len(records) == 0 {
		response.Message = "No valid records found in CSV"
		return response, nil
	}

	return h.importService.ImportStaff(schoolID, records, dryRun)
}

func (h *BulkImportHandler) handleParentImport(schoolID string, fileData *bytes.Buffer, dryRun bool) (*models.BulkImportResponse, error) {
	records, parseErrors := h.importService.ParseParentCSV(fileData)
	
	response := &models.BulkImportResponse{
		Success:      true,
		ImportType:   "parent",
		TotalRecords: len(records) + len(parseErrors),
		IsDryRun:     dryRun,
		Errors:       make([]models.BulkImportErrorDetail, 0),
	}

	// Add parse errors to response
	for _, err := range parseErrors {
		detail := models.BulkImportErrorDetail{
			ErrorMsg: err.Error(),
		}
		response.Errors = append(response.Errors, detail)
		response.FailureCount++
	}

	if len(records) == 0 {
		response.Message = "No valid records found in CSV"
		return response, nil
	}

	return h.importService.ImportParents(schoolID, records, dryRun)
}

func isPrincipal(c *gin.Context) bool {
	role := currentRole(c)
	return strings.EqualFold(role, "principal")
}

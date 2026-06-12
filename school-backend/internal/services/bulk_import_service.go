package services

import (
	"encoding/csv"
	"fmt"
	"io"
	"log"
	"regexp"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"
	"school-backend/internal/database"
	"school-backend/internal/models"
)

type BulkImportService struct{}

func NewBulkImportService() *BulkImportService {
	return &BulkImportService{}
}

// ParseStudentCSV parses student records from CSV file
func (s *BulkImportService) ParseStudentCSV(file io.Reader) ([]models.StudentBulkImportRecord, []error) {
	reader := csv.NewReader(file)
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	// Read header
	header, err := reader.Read()
	if err != nil {
		return nil, []error{fmt.Errorf("failed to read CSV header: %v", err)}
	}

	// Map column indices
	columnIndex := mapColumns(header)
	var records []models.StudentBulkImportRecord
	var errors []error
	rowNum := 2

	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			errors = append(errors, fmt.Errorf("row %d: %v", rowNum, err))
			rowNum++
			continue
		}

		record := models.StudentBulkImportRecord{
			FirstName:        getField(row, columnIndex, "first_name"),
			LastName:         getField(row, columnIndex, "last_name"),
			Email:            getField(row, columnIndex, "email"),
			Phone:            getField(row, columnIndex, "phone"),
			DateOfBirth:      getField(row, columnIndex, "date_of_birth"),
			Gender:           getField(row, columnIndex, "gender"),
			AdmissionNumber:  getField(row, columnIndex, "admission_number"),
			AdmissionDate:    getField(row, columnIndex, "admission_date"),
			CurrentSectionID: getField(row, columnIndex, "current_section_id"),
			Address:          getField(row, columnIndex, "address"),
			AadharNumber:     getField(row, columnIndex, "aadhar_number"),
		}

		if validationErr := s.ValidateStudentRecord(record, rowNum); validationErr != nil {
			errors = append(errors, validationErr)
		} else {
			records = append(records, record)
		}
		rowNum++
	}

	return records, errors
}

// ParseStaffCSV parses staff records from CSV file
func (s *BulkImportService) ParseStaffCSV(file io.Reader) ([]models.StaffBulkImportRecord, []error) {
	reader := csv.NewReader(file)
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	header, err := reader.Read()
	if err != nil {
		return nil, []error{fmt.Errorf("failed to read CSV header: %v", err)}
	}

	columnIndex := mapColumns(header)
	var records []models.StaffBulkImportRecord
	var errors []error
	rowNum := 2

	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			errors = append(errors, fmt.Errorf("row %d: %v", rowNum, err))
			rowNum++
			continue
		}

		record := models.StaffBulkImportRecord{
			FirstName:      getField(row, columnIndex, "first_name"),
			LastName:       getField(row, columnIndex, "last_name"),
			Email:          getField(row, columnIndex, "email"),
			Phone:          getField(row, columnIndex, "phone"),
			DateOfBirth:    getField(row, columnIndex, "date_of_birth"),
			Gender:         getField(row, columnIndex, "gender"),
			StaffCode:      getField(row, columnIndex, "staff_code"),
			DepartmentID:   getField(row, columnIndex, "department_id"),
			Designation:    getField(row, columnIndex, "designation"),
			EmploymentType: getField(row, columnIndex, "employment_type"),
			JoinDate:       getField(row, columnIndex, "join_date"),
			BasicSalary:    getField(row, columnIndex, "basic_salary"),
		}

		if validationErr := s.ValidateStaffRecord(record, rowNum); validationErr != nil {
			errors = append(errors, validationErr)
		} else {
			records = append(records, record)
		}
		rowNum++
	}

	return records, errors
}

// ParseParentCSV parses parent records from CSV file
func (s *BulkImportService) ParseParentCSV(file io.Reader) ([]models.ParentBulkImportRecord, []error) {
	reader := csv.NewReader(file)
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	header, err := reader.Read()
	if err != nil {
		return nil, []error{fmt.Errorf("failed to read CSV header: %v", err)}
	}

	columnIndex := mapColumns(header)
	var records []models.ParentBulkImportRecord
	var errors []error
	rowNum := 2

	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			errors = append(errors, fmt.Errorf("row %d: %v", rowNum, err))
			rowNum++
			continue
		}

		record := models.ParentBulkImportRecord{
			FullName:               getField(row, columnIndex, "full_name"),
			Email:                  getField(row, columnIndex, "email"),
			Phone:                  getField(row, columnIndex, "phone"),
			Relationship:           getField(row, columnIndex, "relationship"),
			Occupation:             getField(row, columnIndex, "occupation"),
			StudentAdmissionNumber: getField(row, columnIndex, "student_admission_number"),
		}

		if validationErr := s.ValidateParentRecord(record, rowNum); validationErr != nil {
			errors = append(errors, validationErr)
		} else {
			records = append(records, record)
		}
		rowNum++
	}

	return records, errors
}

// ValidateStudentRecord validates a single student record
func (s *BulkImportService) ValidateStudentRecord(record models.StudentBulkImportRecord, rowNum int) error {
	if strings.TrimSpace(record.FirstName) == "" {
		return fmt.Errorf("row %d: first_name is required", rowNum)
	}
	if strings.TrimSpace(record.LastName) == "" {
		return fmt.Errorf("row %d: last_name is required", rowNum)
	}
	if strings.TrimSpace(record.Email) == "" {
		return fmt.Errorf("row %d: email is required", rowNum)
	}
	if !isValidEmail(record.Email) {
		return fmt.Errorf("row %d: email format is invalid", rowNum)
	}
	if strings.TrimSpace(record.AdmissionNumber) == "" {
		return fmt.Errorf("row %d: admission_number is required", rowNum)
	}
	if record.DateOfBirth != "" {
		if !isValidDate(record.DateOfBirth) {
			return fmt.Errorf("row %d: date_of_birth format must be YYYY-MM-DD", rowNum)
		}
	}
	return nil
}

// ValidateStaffRecord validates a single staff record
func (s *BulkImportService) ValidateStaffRecord(record models.StaffBulkImportRecord, rowNum int) error {
	if strings.TrimSpace(record.FirstName) == "" {
		return fmt.Errorf("row %d: first_name is required", rowNum)
	}
	if strings.TrimSpace(record.LastName) == "" {
		return fmt.Errorf("row %d: last_name is required", rowNum)
	}
	if strings.TrimSpace(record.Email) == "" {
		return fmt.Errorf("row %d: email is required", rowNum)
	}
	if !isValidEmail(record.Email) {
		return fmt.Errorf("row %d: email format is invalid", rowNum)
	}
	if strings.TrimSpace(record.StaffCode) == "" {
		return fmt.Errorf("row %d: staff_code is required", rowNum)
	}
	if record.DateOfBirth != "" {
		if !isValidDate(record.DateOfBirth) {
			return fmt.Errorf("row %d: date_of_birth format must be YYYY-MM-DD", rowNum)
		}
	}
	if record.JoinDate != "" {
		if !isValidDate(record.JoinDate) {
			return fmt.Errorf("row %d: join_date format must be YYYY-MM-DD", rowNum)
		}
	}
	if record.BasicSalary != "" {
		if _, err := strconv.ParseFloat(record.BasicSalary, 64); err != nil {
			return fmt.Errorf("row %d: basic_salary must be a valid number", rowNum)
		}
	}
	return nil
}

// ValidateParentRecord validates a single parent record
func (s *BulkImportService) ValidateParentRecord(record models.ParentBulkImportRecord, rowNum int) error {
	if strings.TrimSpace(record.FullName) == "" {
		return fmt.Errorf("row %d: full_name is required", rowNum)
	}
	if strings.TrimSpace(record.Email) == "" {
		return fmt.Errorf("row %d: email is required", rowNum)
	}
	if !isValidEmail(record.Email) {
		return fmt.Errorf("row %d: email format is invalid", rowNum)
	}
	if strings.TrimSpace(record.StudentAdmissionNumber) == "" {
		return fmt.Errorf("row %d: student_admission_number is required", rowNum)
	}
	return nil
}

// CheckDuplicateEmails checks for duplicate emails in database and records
func (s *BulkImportService) CheckDuplicateEmails(schoolID string, emails []string) map[string]bool {
	duplicates := make(map[string]bool)
	if len(emails) == 0 {
		return duplicates
	}

	var existingUsers []models.User
	database.DB.Where("school_id = ? AND email IN ?", schoolID, emails).Find(&existingUsers)

	for _, user := range existingUsers {
		duplicates[user.Email] = true
	}
	return duplicates
}

// CheckDuplicateAdmissionNumbers checks for duplicate admission numbers
func (s *BulkImportService) CheckDuplicateAdmissionNumbers(schoolID string, admissionNumbers []string) map[string]bool {
	duplicates := make(map[string]bool)
	if len(admissionNumbers) == 0 {
		return duplicates
	}

	var existingStudents []models.Student
	database.DB.Where("school_id = ? AND admission_number IN ?", schoolID, admissionNumbers).Find(&existingStudents)

	for _, student := range existingStudents {
		duplicates[student.AdmissionNumber] = true
	}
	return duplicates
}

// CheckDuplicateStaffCodes checks for duplicate staff codes
func (s *BulkImportService) CheckDuplicateStaffCodes(schoolID string, staffCodes []string) map[string]bool {
	duplicates := make(map[string]bool)
	if len(staffCodes) == 0 {
		return duplicates
	}

	var existingStaff []models.Staff
	database.DB.Where("school_id = ? AND staff_code IN ?", schoolID, staffCodes).Find(&existingStaff)

	for _, staff := range existingStaff {
		duplicates[staff.StaffCode] = true
	}
	return duplicates
}

// ImportStudents imports bulk student records in a transaction
func (s *BulkImportService) ImportStudents(schoolID string, records []models.StudentBulkImportRecord, dryRun bool) (*models.BulkImportResponse, error) {
	response := &models.BulkImportResponse{
		Success:      true,
		ImportType:   "student",
		TotalRecords: len(records),
		Errors:       []models.BulkImportErrorDetail{},
		IsDryRun:     dryRun,
	}

	// Collect emails for duplicate check
	var emails []string
	var admissionNumbers []string
	for _, record := range records {
		emails = append(emails, strings.ToLower(strings.TrimSpace(record.Email)))
		admissionNumbers = append(admissionNumbers, strings.TrimSpace(record.AdmissionNumber))
	}

	duplicateEmails := s.CheckDuplicateEmails(schoolID, emails)
	duplicateAdmissions := s.CheckDuplicateAdmissionNumbers(schoolID, admissionNumbers)

	// Validate in-memory and build import list
	var validRecords []models.StudentBulkImportRecord
	for i, record := range records {
		rowNum := i + 2

		if duplicateEmails[strings.ToLower(record.Email)] {
			response.Errors = append(response.Errors, models.BulkImportErrorDetail{
				RowNumber: rowNum,
				ErrorMsg:  fmt.Sprintf("Email already exists: %s", record.Email),
			})
			response.FailureCount++
			continue
		}

		if duplicateAdmissions[record.AdmissionNumber] {
			response.Errors = append(response.Errors, models.BulkImportErrorDetail{
				RowNumber: rowNum,
				ErrorMsg:  fmt.Sprintf("Admission number already exists: %s", record.AdmissionNumber),
			})
			response.FailureCount++
			continue
		}

		validRecords = append(validRecords, record)
	}

	// If dry run or has errors, return now
	if dryRun || response.FailureCount > 0 {
		response.SuccessCount = len(validRecords)
		response.Message = fmt.Sprintf("Dry run: %d records valid, %d records have errors", response.SuccessCount, response.FailureCount)
		return response, nil
	}

	// Perform actual import in transaction
	tx := database.DB.Begin()
	if tx.Error != nil {
		return nil, tx.Error
	}

	for i, record := range validRecords {
		rowNum := i + 2

		// Parse dates
		var dob *time.Time
		if record.DateOfBirth != "" {
			if t, err := time.Parse("2006-01-02", record.DateOfBirth); err == nil {
				dob = &t
			}
		}

		var admissionDate *time.Time
		if record.AdmissionDate != "" {
			if t, err := time.Parse("2006-01-02", record.AdmissionDate); err == nil {
				admissionDate = &t
			}
		}

		// Create student record
		student := models.Student{
			SchoolID:         schoolID,
			FirstName:        record.FirstName,
			LastName:         record.LastName,
			AdmissionNumber:  record.AdmissionNumber,
			DateOfBirth:      *dob,
			Gender:           record.Gender,
			Address:          record.Address,
			AadharNumber:     record.AadharNumber,
			CurrentSectionID: stringPtr(record.CurrentSectionID),
		}

		if admissionDate != nil {
			student.AdmissionDate = *admissionDate
		}

		if err := tx.Create(&student).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("row %d: failed to create student: %v", rowNum, err)
		}

		// Create user account for student
		hashedPassword := generateDefaultPassword()
		user := models.User{
			SchoolID:     schoolID,
			Email:        record.Email,
			Name:         record.FirstName + " " + record.LastName,
			Phone:        record.Phone,
			PasswordHash: hashedPassword,
			RoleID:       getRoleIDForRole(tx, schoolID, "student"),
			LinkedType:   "student",
			LinkedID:     &student.ID,
			IsActive:     true,
		}

		if err := tx.Create(&user).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("row %d: failed to create user: %v", rowNum, err)
		}

		response.SuccessCount++
	}

	if err := tx.Commit().Error; err != nil {
		return nil, err
	}

	response.Message = fmt.Sprintf("Successfully imported %d students", response.SuccessCount)
	return response, nil
}

// ImportStaff imports bulk staff records in a transaction
func (s *BulkImportService) ImportStaff(schoolID string, records []models.StaffBulkImportRecord, dryRun bool) (*models.BulkImportResponse, error) {
	response := &models.BulkImportResponse{
		Success:      true,
		ImportType:   "staff",
		TotalRecords: len(records),
		Errors:       []models.BulkImportErrorDetail{},
		IsDryRun:     dryRun,
	}

	// Collect emails and staff codes for duplicate check
	var emails []string
	var staffCodes []string
	for _, record := range records {
		emails = append(emails, strings.ToLower(strings.TrimSpace(record.Email)))
		staffCodes = append(staffCodes, strings.TrimSpace(record.StaffCode))
	}

	duplicateEmails := s.CheckDuplicateEmails(schoolID, emails)
	duplicateStaffCodes := s.CheckDuplicateStaffCodes(schoolID, staffCodes)

	// Validate in-memory and build import list
	var validRecords []models.StaffBulkImportRecord
	for i, record := range records {
		rowNum := i + 2

		if duplicateEmails[strings.ToLower(record.Email)] {
			response.Errors = append(response.Errors, models.BulkImportErrorDetail{
				RowNumber: rowNum,
				ErrorMsg:  fmt.Sprintf("Email already exists: %s", record.Email),
			})
			response.FailureCount++
			continue
		}

		if duplicateStaffCodes[record.StaffCode] {
			response.Errors = append(response.Errors, models.BulkImportErrorDetail{
				RowNumber: rowNum,
				ErrorMsg:  fmt.Sprintf("Staff code already exists: %s", record.StaffCode),
			})
			response.FailureCount++
			continue
		}

		validRecords = append(validRecords, record)
	}

	// If dry run or has errors, return now
	if dryRun || response.FailureCount > 0 {
		response.SuccessCount = len(validRecords)
		response.Message = fmt.Sprintf("Dry run: %d records valid, %d records have errors", response.SuccessCount, response.FailureCount)
		return response, nil
	}

	// Perform actual import in transaction
	tx := database.DB.Begin()
	if tx.Error != nil {
		return nil, tx.Error
	}

	for i, record := range validRecords {
		rowNum := i + 2

		// Parse dates
		var dob *time.Time
		if record.DateOfBirth != "" {
			if t, err := time.Parse("2006-01-02", record.DateOfBirth); err == nil {
				dob = &t
			}
		}

		var joinDate *time.Time
		if record.JoinDate != "" {
			if t, err := time.Parse("2006-01-02", record.JoinDate); err == nil {
				joinDate = &t
			}
		}

		salary := 0.0
		if record.BasicSalary != "" {
			if s, err := strconv.ParseFloat(record.BasicSalary, 64); err == nil {
				salary = s
			}
		}

		// Create staff record
		staff := models.Staff{
			SchoolID:       schoolID,
			FirstName:      record.FirstName,
			LastName:       record.LastName,
			Email:          record.Email,
			Phone:          record.Phone,
			StaffCode:      record.StaffCode,
			Designation:    record.Designation,
			EmploymentType: record.EmploymentType,
			BasicSalary:    salary,
			Status:         "active",
		}

		if dob != nil {
			staff.DateOfBirth = *dob
		}
		if joinDate != nil {
			staff.JoinDate = *joinDate
		}
		if record.DepartmentID != "" {
			staff.DepartmentID = stringPtr(record.DepartmentID)
		}

		if err := tx.Create(&staff).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("row %d: failed to create staff: %v", rowNum, err)
		}

		// Create user account for staff
		hashedPassword := generateDefaultPassword()
		user := models.User{
			SchoolID:     schoolID,
			Email:        record.Email,
			Name:         record.FirstName + " " + record.LastName,
			Phone:        record.Phone,
			PasswordHash: hashedPassword,
			RoleID:       getRoleIDForRole(tx, schoolID, "staff"),
			LinkedType:   "staff",
			LinkedID:     &staff.ID,
			IsActive:     true,
		}

		if err := tx.Create(&user).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("row %d: failed to create user: %v", rowNum, err)
		}

		response.SuccessCount++
	}

	if err := tx.Commit().Error; err != nil {
		return nil, err
	}

	response.Message = fmt.Sprintf("Successfully imported %d staff members", response.SuccessCount)
	return response, nil
}

// ImportParents imports bulk parent records and links them to students
func (s *BulkImportService) ImportParents(schoolID string, records []models.ParentBulkImportRecord, dryRun bool) (*models.BulkImportResponse, error) {
	response := &models.BulkImportResponse{
		Success:      true,
		ImportType:   "parent",
		TotalRecords: len(records),
		Errors:       []models.BulkImportErrorDetail{},
		IsDryRun:     dryRun,
	}

	// Collect emails for duplicate check
	var emails []string
	var admissionNumbers []string
	for _, record := range records {
		emails = append(emails, strings.ToLower(strings.TrimSpace(record.Email)))
		admissionNumbers = append(admissionNumbers, strings.TrimSpace(record.StudentAdmissionNumber))
	}

	duplicateEmails := s.CheckDuplicateEmails(schoolID, emails)

	// Verify admission numbers exist
	var existingStudents []models.Student
	database.DB.Where("school_id = ? AND admission_number IN ?", schoolID, admissionNumbers).Find(&existingStudents)
	studentsByAdmission := make(map[string]models.Student)
	for _, student := range existingStudents {
		studentsByAdmission[student.AdmissionNumber] = student
	}

	// Validate in-memory and build import list
	var validRecords []models.ParentBulkImportRecord
	for i, record := range records {
		rowNum := i + 2

		if duplicateEmails[strings.ToLower(record.Email)] {
			response.Errors = append(response.Errors, models.BulkImportErrorDetail{
				RowNumber: rowNum,
				ErrorMsg:  fmt.Sprintf("Email already exists: %s", record.Email),
			})
			response.FailureCount++
			continue
		}

		if _, exists := studentsByAdmission[record.StudentAdmissionNumber]; !exists {
			response.Errors = append(response.Errors, models.BulkImportErrorDetail{
				RowNumber: rowNum,
				ErrorMsg:  fmt.Sprintf("Student with admission number %s not found", record.StudentAdmissionNumber),
			})
			response.FailureCount++
			continue
		}

		validRecords = append(validRecords, record)
	}

	// If dry run or has errors, return now
	if dryRun || response.FailureCount > 0 {
		response.SuccessCount = len(validRecords)
		response.Message = fmt.Sprintf("Dry run: %d records valid, %d records have errors", response.SuccessCount, response.FailureCount)
		return response, nil
	}

	// Perform actual import in transaction
	tx := database.DB.Begin()
	if tx.Error != nil {
		return nil, tx.Error
	}

	for i, record := range validRecords {
		rowNum := i + 2

		student := studentsByAdmission[record.StudentAdmissionNumber]

		// Create guardian record
		guardian := models.Guardian{
			StudentID:    student.ID,
			FullName:     record.FullName,
			Email:        record.Email,
			Phone:        record.Phone,
			Relationship: record.Relationship,
			Occupation:   record.Occupation,
			IsPrimary:    true,
		}

		if err := tx.Create(&guardian).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("row %d: failed to create guardian: %v", rowNum, err)
		}

		// Create user account for parent
		hashedPassword := generateDefaultPassword()
		user := models.User{
			SchoolID:     schoolID,
			Email:        record.Email,
			Name:         record.FullName,
			Phone:        record.Phone,
			PasswordHash: hashedPassword,
			RoleID:       getRoleIDForRole(tx, schoolID, "parent"),
			LinkedType:   "parent",
			LinkedID:     &guardian.ID,
			IsActive:     true,
		}

		if err := tx.Create(&user).Error; err != nil {
			tx.Rollback()
			return nil, fmt.Errorf("row %d: failed to create parent user: %v", rowNum, err)
		}

		response.SuccessCount++
	}

	if err := tx.Commit().Error; err != nil {
		return nil, err
	}

	response.Message = fmt.Sprintf("Successfully imported %d parents and linked to students", response.SuccessCount)
	return response, nil
}

// Helper functions

func getField(row []string, columnIndex map[string]int, fieldName string) string {
	if idx, exists := columnIndex[fieldName]; exists && idx < len(row) {
		return strings.TrimSpace(row[idx])
	}
	return ""
}

func mapColumns(header []string) map[string]int {
	columnIndex := make(map[string]int)
	for i, col := range header {
		columnIndex[strings.ToLower(strings.TrimSpace(col))] = i
	}
	return columnIndex
}

func isValidEmail(email string) bool {
	re := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	return re.MatchString(email)
}

func isValidDate(dateStr string) bool {
	_, err := time.Parse("2006-01-02", dateStr)
	return err == nil
}

func stringPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func generateDefaultPassword() string {
	// In production, use a proper hashing function (bcrypt)
	// This is a placeholder - actual implementation should use bcrypt
	return "hashed_default_password_12345"
}

func getRoleIDForRole(tx *gorm.DB, schoolID, roleName string) string {
	var role models.Role
	tx.Where("school_id = ? AND role_name = ?", schoolID, roleName).First(&role)
	if role.ID != "" {
		return role.ID
	}
	log.Printf("Warning: Role '%s' not found for school %s", roleName, schoolID)
	return ""
}

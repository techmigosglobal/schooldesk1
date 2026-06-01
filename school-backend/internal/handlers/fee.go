package handlers

import (
	"fmt"
	"net/http"
	"strings"
	"time"
	"unicode"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type FeeHandler struct{}

func NewFeeHandler() *FeeHandler {
	return &FeeHandler{}
}

func (h *FeeHandler) GetFeeCategories(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	var categories []models.FeeCategory
	query := database.DB.Preload("School")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	query.Find(&categories)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: categories})
}

func (h *FeeHandler) CreateFeeCategory(c *gin.Context) {
	var req struct {
		SchoolID     string `json:"school_id"`
		CategoryName string `json:"category_name" binding:"required"`
		Frequency    string `json:"frequency" binding:"required"`
		IsRefundable bool   `json:"is_refundable"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	cat := models.FeeCategory{
		SchoolID:     scopedSchoolID(c),
		CategoryName: req.CategoryName,
		Frequency:    req.Frequency,
		IsRefundable: req.IsRefundable,
	}

	if err := database.DB.Create(&cat).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create fee category"})
		return
	}

	id := cat.ID
	auditAction(c, "fees", "create", "fee_categories", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: cat})
}

func (h *FeeHandler) DeleteFeeCategory(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	id := strings.TrimSpace(c.Param("id"))
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Fee category id is required"})
		return
	}

	var category models.FeeCategory
	if err := database.DB.Where("id = ? AND school_id = ?", id, schoolID).First(&category).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Fee category not found"})
		return
	}

	var structureCount, invoiceItemCount, concessionCount int64
	database.DB.Model(&models.FeeStructure{}).Where("fee_category_id = ?", id).Count(&structureCount)
	database.DB.Model(&models.FeeInvoiceItem{}).Where("fee_category_id = ?", id).Count(&invoiceItemCount)
	database.DB.Model(&models.FeeConcession{}).Where("fee_category_id = ?", id).Count(&concessionCount)
	if structureCount > 0 || invoiceItemCount > 0 || concessionCount > 0 {
		c.JSON(http.StatusConflict, gin.H{
			"error": fmt.Sprintf(
				"Cannot delete fee element while linked records exist (structures: %d, invoice items: %d, concessions: %d). Remove linked records first.",
				structureCount,
				invoiceItemCount,
				concessionCount,
			),
		})
		return
	}

	if err := database.DB.Delete(&category).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete fee category"})
		return
	}
	auditAction(c, "fees", "delete", "fee_categories", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: gin.H{"id": id}})
}

func (h *FeeHandler) GetFeeStructures(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	yearID := c.Query("academic_year_id")
	gradeID := c.Query("grade_id")

	var structures []models.FeeStructure
	query := database.DB.Preload("FeeCategory").Preload("Grade").Preload("AcademicYear")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	if yearID != "" {
		query = query.Where("academic_year_id = ?", yearID)
	}
	if gradeID != "" {
		query = query.Where("grade_id = ?", gradeID)
	}
	query.Find(&structures)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: structures})
}

func (h *FeeHandler) CreateFeeStructure(c *gin.Context) {
	var req models.CreateFeeStructureRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := validateFeeStructureRefs(scopedSchoolID(c), req.AcademicYearID, req.GradeID, req.FeeCategoryID); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	structure := models.FeeStructure{
		SchoolID:       scopedSchoolID(c),
		AcademicYearID: req.AcademicYearID,
		GradeID:        req.GradeID,
		FeeCategoryID:  req.FeeCategoryID,
		Amount:         req.Amount,
		DueDay:         req.DueDay,
		LateFinePerDay: req.LateFinePerDay,
	}

	if err := database.DB.Create(&structure).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create fee structure"})
		return
	}

	id := structure.ID
	auditAction(c, "fees", "create", "fee_structures", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: structure})
}

func (h *FeeHandler) UpdateFeeStructure(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	id := c.Param("id")
	var req struct {
		AcademicYearID string   `json:"academic_year_id"`
		GradeID        string   `json:"grade_id"`
		FeeCategoryID  string   `json:"fee_category_id"`
		Amount         *float64 `json:"amount"`
		DueDay         *int     `json:"due_day"`
		LateFinePerDay *float64 `json:"late_fine_per_day"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var structure models.FeeStructure
	if err := database.DB.Where("id = ? AND school_id = ?", id, schoolID).First(&structure).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Fee structure not found"})
		return
	}

	updates := map[string]interface{}{}
	if req.AcademicYearID != "" {
		updates["academic_year_id"] = req.AcademicYearID
	}
	if req.GradeID != "" {
		updates["grade_id"] = req.GradeID
	}
	if req.FeeCategoryID != "" {
		updates["fee_category_id"] = req.FeeCategoryID
	}
	if req.Amount != nil {
		updates["amount"] = *req.Amount
	}
	if req.DueDay != nil {
		updates["due_day"] = *req.DueDay
	}
	if req.LateFinePerDay != nil {
		updates["late_fine_per_day"] = *req.LateFinePerDay
	}
	if len(updates) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No fee structure fields provided"})
		return
	}
	academicYearID := structure.AcademicYearID
	if req.AcademicYearID != "" {
		academicYearID = req.AcademicYearID
	}
	gradeID := structure.GradeID
	if req.GradeID != "" {
		gradeID = req.GradeID
	}
	feeCategoryID := structure.FeeCategoryID
	if req.FeeCategoryID != "" {
		feeCategoryID = req.FeeCategoryID
	}
	if err := validateFeeStructureRefs(schoolID, academicYearID, gradeID, feeCategoryID); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	if err := database.DB.Model(&structure).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update fee structure"})
		return
	}
	if err := database.DB.Preload("FeeCategory").Preload("Grade").Preload("AcademicYear").First(&structure, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reload fee structure"})
		return
	}

	auditAction(c, "fees", "update", "fee_structures", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: structure})
}

func validateFeeStructureRefs(schoolID, academicYearID, gradeID, feeCategoryID string) error {
	if err := academicDomainService().EnsureAcademicYearWritable(schoolID, academicYearID); err != nil {
		return err
	}
	if countRows(database.DB.Model(&models.Grade{}).
		Where("id = ? AND school_id = ?", strings.TrimSpace(gradeID), schoolID)) == 0 {
		return fmt.Errorf("grade must belong to this school")
	}
	if countRows(database.DB.Model(&models.FeeCategory{}).
		Where("id = ? AND school_id = ?", strings.TrimSpace(feeCategoryID), schoolID)) == 0 {
		return fmt.Errorf("fee category must belong to this school")
	}
	return nil
}

func (h *FeeHandler) DeleteFeeStructure(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	id := c.Param("id")
	result := database.DB.Where("id = ? AND school_id = ?", id, schoolID).Delete(&models.FeeStructure{})
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete fee structure"})
		return
	}
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Fee structure not found"})
		return
	}
	auditAction(c, "fees", "delete", "fee_structures", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: gin.H{"id": id}})
}

func (h *FeeHandler) GetInvoices(c *gin.Context) {
	page, pageSize := parsePagination(c)

	var invoices []models.FeeInvoice
	var total int64

	query := scopedFeeInvoiceQuery(c)
	query.Count(&total)

	if err := preloadFeeInvoiceDetails(query).
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Order("fee_invoices.due_date ASC, fee_invoices.created_at DESC").
		Find(&invoices).Error; err != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Error:   "Failed to fetch invoices",
		})
		return
	}

	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, invoices))
}

func scopedFeeInvoiceQuery(c *gin.Context) *gorm.DB {
	query := database.DB.Model(&models.FeeInvoice{}).
		Joins("JOIN students ON students.id = fee_invoices.student_id").
		Where("students.school_id = ? AND students.status != ?", scopedSchoolID(c), "inactive")

	switch currentRole(c) {
	case "parent":
		query = query.Joins(`
			JOIN parent_student_links
				ON parent_student_links.student_id = fee_invoices.student_id
				AND parent_student_links.school_id = students.school_id
		`).Where("parent_student_links.parent_user_id = ?", currentUserID(c))
	case "teacher":
		query = query.Where("1 = 0")
	}

	if studentID := strings.TrimSpace(c.Query("student_id")); studentID != "" {
		query = query.Where("fee_invoices.student_id = ?", studentID)
	}
	if status := strings.TrimSpace(c.Query("status")); status != "" {
		query = query.Where("fee_invoices.status = ?", status)
	}
	if academicYearID := strings.TrimSpace(c.Query("academic_year_id")); academicYearID != "" {
		query = query.Where("fee_invoices.academic_year_id = ?", academicYearID)
	}
	if sectionID := strings.TrimSpace(c.Query("section_id")); sectionID != "" {
		query = query.Where("students.current_section_id = ?", sectionID)
	}
	if gradeID := strings.TrimSpace(c.Query("grade_id")); gradeID != "" {
		query = query.Joins("JOIN sections ON sections.id = students.current_section_id").
			Where("sections.grade_id = ?", gradeID)
	}

	return query
}

func preloadFeeInvoiceDetails(query *gorm.DB) *gorm.DB {
	return query.
		Preload("Student").
		Preload("Student.CurrentSection").
		Preload("Student.CurrentSection.Grade").
		Preload("AcademicYear").
		Preload("Items").
		Preload("Items.FeeCategory").
		Preload("Payments")
}

func (h *FeeHandler) CreateInvoice(c *gin.Context) {
	var req struct {
		StudentID      string  `json:"student_id" binding:"required"`
		AcademicYearID string  `json:"academic_year_id" binding:"required"`
		InvoiceNumber  string  `json:"invoice_number" binding:"required"`
		InvoiceDate    string  `json:"invoice_date" binding:"required"`
		DueDate        string  `json:"due_date" binding:"required"`
		TotalAmount    float64 `json:"total_amount" binding:"required"`
		DiscountAmount float64 `json:"discount_amount"`
		NetAmount      float64 `json:"net_amount" binding:"required"`
		Items          []struct {
			FeeCategoryID string  `json:"fee_category_id" binding:"required"`
			Amount        float64 `json:"amount" binding:"required"`
			Description   string  `json:"description"`
		}
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	invoiceDate, err := parseDate(req.InvoiceDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid invoice_date format. Use YYYY-MM-DD")
		return
	}
	dueDate, err := parseDate(req.DueDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid due_date format. Use YYYY-MM-DD")
		return
	}
	if req.NetAmount <= 0 || req.TotalAmount <= 0 {
		fail(c, http.StatusBadRequest, "invoice amount must be greater than zero")
		return
	}
	if err := validateInvoiceScope(c, req.StudentID, req.AcademicYearID, req.Items); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	invoice := models.FeeInvoice{
		StudentID:      req.StudentID,
		AcademicYearID: req.AcademicYearID,
		InvoiceNumber:  req.InvoiceNumber,
		InvoiceDate:    invoiceDate,
		DueDate:        dueDate,
		TotalAmount:    req.TotalAmount,
		DiscountAmount: req.DiscountAmount,
		NetAmount:      req.NetAmount,
		PaidAmount:     0,
		Balance:        req.NetAmount,
		Status:         "pending",
	}

	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&invoice).Error; err != nil {
			return err
		}
		for _, item := range req.Items {
			invoiceItem := models.FeeInvoiceItem{
				InvoiceID:     invoice.ID,
				FeeCategoryID: item.FeeCategoryID,
				Amount:        item.Amount,
				Description:   item.Description,
			}
			if err := tx.Create(&invoiceItem).Error; err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create invoice"})
		return
	}
	_ = database.DB.
		Preload("Student").
		Preload("Student.CurrentSection").
		Preload("Student.CurrentSection.Grade").
		Preload("AcademicYear").
		Preload("Items").
		Preload("Items.FeeCategory").
		First(&invoice, "id = ?", invoice.ID).Error

	id := invoice.ID
	auditAction(c, "fees", "create", "fee_invoices", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: invoice})
}

func (h *FeeHandler) GenerateInvoices(c *gin.Context) {
	var req struct {
		AcademicYearID string `json:"academic_year_id" binding:"required"`
		GradeID        string `json:"grade_id" binding:"required"`
		SectionID      string `json:"section_id"`
		StudentID      string `json:"student_id"`
		InvoiceDate    string `json:"invoice_date"`
		DueDate        string `json:"due_date" binding:"required"`
		InvoiceLabel   string `json:"invoice_label"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	invoiceDate := time.Now().UTC()
	if strings.TrimSpace(req.InvoiceDate) != "" {
		parsed, err := parseDate(req.InvoiceDate)
		if err != nil {
			fail(c, http.StatusBadRequest, "Invalid invoice_date format. Use YYYY-MM-DD")
			return
		}
		invoiceDate = parsed
	}
	dueDate, err := parseDate(req.DueDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid due_date format. Use YYYY-MM-DD")
		return
	}

	schoolID := scopedSchoolID(c)
	if !academicYearBelongsToSchool(req.AcademicYearID, schoolID) {
		fail(c, http.StatusBadRequest, "academic year does not belong to this school")
		return
	}
	if !gradeBelongsToSchool(req.GradeID, schoolID) {
		fail(c, http.StatusBadRequest, "grade does not belong to this school")
		return
	}
	if strings.TrimSpace(req.SectionID) != "" {
		if !sectionBelongsToSchool(req.SectionID, schoolID) {
			fail(c, http.StatusBadRequest, "section does not belong to this school")
			return
		}
		if !sectionBelongsToGrade(req.SectionID, req.GradeID) {
			fail(c, http.StatusBadRequest, "section does not belong to selected grade")
			return
		}
	}

	var structures []models.FeeStructure
	if err := database.DB.
		Where("school_id = ? AND academic_year_id = ? AND grade_id = ?", schoolID, req.AcademicYearID, req.GradeID).
		Preload("FeeCategory").
		Order("created_at ASC").
		Find(&structures).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load fee structures")
		return
	}
	if len(structures) == 0 {
		fail(c, http.StatusBadRequest, "No class-wise fee structures found for the selected class and academic year")
		return
	}

	studentQuery := database.DB.Model(&models.Student{}).
		Joins("JOIN sections ON sections.id = students.current_section_id").
		Where("students.school_id = ? AND students.status != ? AND sections.grade_id = ?", schoolID, "inactive", req.GradeID)
	if strings.TrimSpace(req.SectionID) != "" {
		studentQuery = studentQuery.Where("students.current_section_id = ?", strings.TrimSpace(req.SectionID))
	}
	if strings.TrimSpace(req.StudentID) != "" {
		studentQuery = studentQuery.Where("students.id = ?", strings.TrimSpace(req.StudentID))
	}

	var students []models.Student
	if err := studentQuery.Order("students.first_name, students.last_name").Find(&students).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load students for fee generation")
		return
	}
	if len(students) == 0 {
		fail(c, http.StatusBadRequest, "No active students found for the selected fee scope")
		return
	}

	label := strings.TrimSpace(req.InvoiceLabel)
	if label == "" {
		label = invoiceDate.Format("Jan-2006")
	}
	total := 0.0
	for _, structure := range structures {
		total += structure.Amount
	}
	if total <= 0 {
		fail(c, http.StatusBadRequest, "Selected fee structures have no billable amount")
		return
	}

	created := make([]models.FeeInvoice, 0, len(students))
	skipped := make([]gin.H, 0)
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		for _, student := range students {
			invoiceNumber := generatedInvoiceNumber(label, student)
			var existing models.FeeInvoice
			err := tx.First(&existing, "invoice_number = ?", invoiceNumber).Error
			if err == nil {
				skipped = append(skipped, gin.H{
					"student_id":     student.ID,
					"invoice_id":     existing.ID,
					"invoice_number": existing.InvoiceNumber,
					"student_name":   strings.TrimSpace(student.FirstName + " " + student.LastName),
					"skip_reason":    "invoice already exists for this label",
				})
				continue
			}
			if err != gorm.ErrRecordNotFound {
				return err
			}

			invoice := models.FeeInvoice{
				StudentID:      student.ID,
				AcademicYearID: req.AcademicYearID,
				InvoiceNumber:  invoiceNumber,
				InvoiceDate:    invoiceDate,
				DueDate:        dueDate,
				TotalAmount:    total,
				DiscountAmount: 0,
				NetAmount:      total,
				PaidAmount:     0,
				Balance:        total,
				Status:         "pending",
			}
			if err := tx.Create(&invoice).Error; err != nil {
				return err
			}
			for _, structure := range structures {
				description := "Fee"
				if structure.FeeCategory != nil && strings.TrimSpace(structure.FeeCategory.CategoryName) != "" {
					description = structure.FeeCategory.CategoryName
				}
				item := models.FeeInvoiceItem{
					InvoiceID:     invoice.ID,
					FeeCategoryID: structure.FeeCategoryID,
					Amount:        structure.Amount,
					Description:   description,
				}
				if err := tx.Create(&item).Error; err != nil {
					return err
				}
			}
			created = append(created, invoice)
		}
		return nil
	}); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to generate fee invoices")
		return
	}

	id := req.GradeID
	auditAction(c, "fees", "generate", "fee_invoices", &id)
	success(c, http.StatusCreated, gin.H{
		"created":        len(created),
		"skipped":        len(skipped),
		"total_students": len(students),
		"invoice_label":  label,
		"scope":          invoiceScope(req.StudentID, req.SectionID),
		"invoices":       created,
		"skipped_rows":   skipped,
	}, "Fee invoices generated")
}

func (h *FeeHandler) RecordPayment(c *gin.Context) {
	var req struct {
		InvoiceID     string  `json:"invoice_id" binding:"required"`
		ReceiptNumber string  `json:"receipt_number" binding:"required"`
		AmountPaid    float64 `json:"amount_paid" binding:"required"`
		PaymentDate   string  `json:"payment_date" binding:"required"`
		PaymentMode   string  `json:"payment_mode" binding:"required"`
		TransactionID string  `json:"transaction_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.AmountPaid <= 0 {
		fail(c, http.StatusBadRequest, "payment amount must be greater than zero")
		return
	}
	paymentDate, err := parseDate(req.PaymentDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid payment_date format. Use YYYY-MM-DD")
		return
	}

	var invoice models.FeeInvoice
	if err := scopedFeeInvoiceQuery(c).First(&invoice, "fee_invoices.id = ?", req.InvoiceID).Error; err != nil {
		fail(c, http.StatusNotFound, "Invoice not found")
		return
	}
	if req.AmountPaid > invoice.Balance {
		fail(c, http.StatusBadRequest, "payment amount exceeds outstanding balance")
		return
	}

	payment := models.Payment{
		InvoiceID:     req.InvoiceID,
		ReceiptNumber: req.ReceiptNumber,
		AmountPaid:    req.AmountPaid,
		PaymentDate:   paymentDate,
		PaymentMode:   req.PaymentMode,
		TransactionID: req.TransactionID,
	}

	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&payment).Error; err != nil {
			return err
		}
		invoice.PaidAmount += req.AmountPaid
		invoice.Balance -= req.AmountPaid
		if invoice.Balance <= 0 {
			invoice.Status = "paid"
			invoice.Balance = 0
		} else {
			invoice.Status = "partial"
		}
		return tx.Save(&invoice).Error
	}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to record payment"})
		return
	}

	id := payment.ID
	auditAction(c, "fees", "create", "payments", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: payment})
}

func (h *FeeHandler) GetPaymentRequests(c *gin.Context) {
	page, pageSize := parsePagination(c)
	query := scopedPaymentRequestQuery(c)
	if status := strings.TrimSpace(c.Query("status")); status != "" {
		query = query.Where("parent_payment_requests.status = ?", strings.ToLower(status))
	}
	if studentID := strings.TrimSpace(c.Query("student_id")); studentID != "" {
		query = query.Where("parent_payment_requests.student_id = ?", studentID)
	}
	if invoiceID := strings.TrimSpace(c.Query("invoice_id")); invoiceID != "" {
		query = query.Where("parent_payment_requests.invoice_id = ?", invoiceID)
	}

	var total int64
	query.Count(&total)
	var rows []models.ParentPaymentRequest
	if err := preloadPaymentRequestDetails(query).
		Order("parent_payment_requests.created_at DESC").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch payment requests")
		return
	}
	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, rows))
}

func (h *FeeHandler) CreateParentPaymentRequest(c *gin.Context) {
	var req struct {
		InvoiceID        string  `json:"invoice_id" binding:"required"`
		Amount           float64 `json:"amount" binding:"required"`
		PaymentDate      string  `json:"payment_date" binding:"required"`
		PaymentMode      string  `json:"payment_mode" binding:"required"`
		TransactionID    string  `json:"transaction_id"`
		Remarks          string  `json:"remarks"`
		RequestReference string  `json:"request_reference"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	if req.Amount <= 0 {
		fail(c, http.StatusBadRequest, "payment request amount must be greater than zero")
		return
	}
	paymentDate, err := parseDate(req.PaymentDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid payment_date format. Use YYYY-MM-DD")
		return
	}

	var invoice models.FeeInvoice
	if err := scopedFeeInvoiceQuery(c).First(&invoice, "fee_invoices.id = ?", req.InvoiceID).Error; err != nil {
		fail(c, http.StatusNotFound, "Invoice not found")
		return
	}
	if invoice.Balance <= 0 {
		fail(c, http.StatusBadRequest, "invoice has no outstanding balance")
		return
	}

	pendingAmount, err := pendingParentPaymentAmount(req.InvoiceID)
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to verify pending payment requests")
		return
	}
	availableBalance := invoice.Balance - pendingAmount
	if req.Amount > availableBalance {
		fail(c, http.StatusBadRequest, "payment request amount exceeds outstanding balance after pending requests")
		return
	}

	reference := strings.TrimSpace(req.RequestReference)
	if reference == "" || strings.HasPrefix(strings.ToUpper(reference), "RCP-") {
		reference = generateParentPaymentReference()
	}
	paymentRequest := models.ParentPaymentRequest{
		SchoolID:         scopedSchoolID(c),
		InvoiceID:        invoice.ID,
		StudentID:        invoice.StudentID,
		ParentUserID:     currentUserID(c),
		RequestReference: reference,
		Amount:           req.Amount,
		PaymentDate:      paymentDate,
		PaymentMode:      strings.TrimSpace(req.PaymentMode),
		TransactionID:    strings.TrimSpace(req.TransactionID),
		Status:           "pending",
		Remarks:          strings.TrimSpace(req.Remarks),
	}
	if err := database.DB.Create(&paymentRequest).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create payment request")
		return
	}
	id := paymentRequest.ID
	auditAction(c, "fees", "request_payment", "parent_payment_requests", &id)
	if err := preloadPaymentRequestDetails(database.DB).First(&paymentRequest, "id = ?", paymentRequest.ID).Error; err != nil {
		success(c, http.StatusCreated, paymentRequest, "Payment request submitted for verification")
		return
	}
	success(c, http.StatusCreated, paymentRequest, "Payment request submitted for verification")
}

func (h *FeeHandler) DecideParentPaymentRequest(c *gin.Context) {
	var req struct {
		Status       string `json:"status" binding:"required"`
		AdminRemarks string `json:"admin_remarks"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	status := strings.ToLower(strings.TrimSpace(req.Status))
	if status != "approved" && status != "rejected" {
		fail(c, http.StatusBadRequest, "status must be approved or rejected")
		return
	}

	var paymentRequest models.ParentPaymentRequest
	if err := database.DB.First(&paymentRequest, "id = ? AND school_id = ?", c.Param("id"), scopedSchoolID(c)).Error; err != nil {
		fail(c, http.StatusNotFound, "Payment request not found")
		return
	}
	if !strings.EqualFold(paymentRequest.Status, "pending") {
		fail(c, http.StatusBadRequest, "Payment request has already been actioned")
		return
	}

	now := time.Now().UTC()
	decider := currentUserID(c)
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		paymentRequest.Status = status
		paymentRequest.AdminRemarks = strings.TrimSpace(req.AdminRemarks)
		paymentRequest.DecidedBy = &decider
		paymentRequest.DecidedAt = &now
		if status == "rejected" {
			return tx.Save(&paymentRequest).Error
		}

		var invoice models.FeeInvoice
		if err := tx.Model(&models.FeeInvoice{}).
			Joins("JOIN students ON students.id = fee_invoices.student_id").
			Where("fee_invoices.id = ? AND students.school_id = ?", paymentRequest.InvoiceID, scopedSchoolID(c)).
			First(&invoice).Error; err != nil {
			return fmt.Errorf("invoice not found")
		}
		if paymentRequest.Amount > invoice.Balance {
			return fmt.Errorf("payment request amount exceeds current outstanding balance")
		}
		payment := models.Payment{
			InvoiceID:     paymentRequest.InvoiceID,
			ReceiptNumber: paymentRequest.RequestReference,
			AmountPaid:    paymentRequest.Amount,
			PaymentDate:   paymentRequest.PaymentDate,
			PaymentMode:   paymentRequest.PaymentMode,
			TransactionID: paymentRequest.TransactionID,
			ReceivedBy:    &decider,
		}
		if err := tx.Create(&payment).Error; err != nil {
			return err
		}
		invoice.PaidAmount += paymentRequest.Amount
		invoice.Balance -= paymentRequest.Amount
		if invoice.Balance <= 0 {
			invoice.Balance = 0
			invoice.Status = "paid"
		} else {
			invoice.Status = "partial"
		}
		if err := tx.Save(&invoice).Error; err != nil {
			return err
		}
		paymentRequest.PaymentID = &payment.ID
		return tx.Save(&paymentRequest).Error
	}); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	id := paymentRequest.ID
	auditAction(c, "fees", status+"_payment_request", "parent_payment_requests", &id)
	if err := preloadPaymentRequestDetails(database.DB).First(&paymentRequest, "id = ?", paymentRequest.ID).Error; err != nil {
		success(c, http.StatusOK, paymentRequest, "Payment request updated")
		return
	}
	success(c, http.StatusOK, paymentRequest, "Payment request updated")
}

func scopedPaymentRequestQuery(c *gin.Context) *gorm.DB {
	query := database.DB.Model(&models.ParentPaymentRequest{}).
		Joins("JOIN students ON students.id = parent_payment_requests.student_id").
		Where("parent_payment_requests.school_id = ? AND students.status != ?", scopedSchoolID(c), "inactive")
	switch currentRole(c) {
	case "parent":
		query = query.Where("parent_payment_requests.parent_user_id = ?", currentUserID(c))
	case "teacher":
		query = query.Where("1 = 0")
	}
	return query
}

func preloadPaymentRequestDetails(query *gorm.DB) *gorm.DB {
	return query.
		Preload("Invoice").
		Preload("Student").
		Preload("ParentUser").
		Preload("Payment")
}

func pendingParentPaymentAmount(invoiceID string) (float64, error) {
	var amount float64
	err := database.DB.Model(&models.ParentPaymentRequest{}).
		Where("invoice_id = ? AND status = ?", invoiceID, "pending").
		Select("COALESCE(SUM(amount), 0)").
		Scan(&amount).Error
	return amount, err
}

func generateParentPaymentReference() string {
	now := time.Now().UTC()
	return fmt.Sprintf("PPR-%s-%d", now.Format("20060102"), now.UnixNano())
}

func (h *FeeHandler) GetConcessions(c *gin.Context) {
	studentID := c.Query("student_id")
	var concessions []models.FeeConcession
	query := database.DB.Model(&models.FeeConcession{}).
		Joins("JOIN students ON students.id = fee_concessions.student_id").
		Where("students.school_id = ? AND students.status != ?", scopedSchoolID(c), "inactive").
		Preload("FeeCategory").
		Preload("Student")
	if studentID != "" {
		query = query.Where("fee_concessions.student_id = ?", studentID)
	}
	query.Find(&concessions)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: concessions})
}

func validateInvoiceScope(c *gin.Context, studentID, academicYearID string, items []struct {
	FeeCategoryID string  `json:"fee_category_id" binding:"required"`
	Amount        float64 `json:"amount" binding:"required"`
	Description   string  `json:"description"`
}) error {
	schoolID := scopedSchoolID(c)
	if countRows(database.DB.Model(&models.Student{}).
		Where("id = ? AND school_id = ? AND status != ?", studentID, schoolID, "inactive")) == 0 {
		return fmt.Errorf("student does not belong to this school")
	}
	if !academicYearBelongsToSchool(academicYearID, schoolID) {
		return fmt.Errorf("academic year does not belong to this school")
	}
	if len(items) == 0 {
		return fmt.Errorf("at least one invoice item is required")
	}
	for _, item := range items {
		if item.Amount <= 0 {
			return fmt.Errorf("invoice item amount must be greater than zero")
		}
		if countRows(database.DB.Model(&models.FeeCategory{}).
			Where("id = ? AND school_id = ?", item.FeeCategoryID, schoolID)) == 0 {
			return fmt.Errorf("fee category does not belong to this school")
		}
	}
	return nil
}

func academicYearBelongsToSchool(academicYearID, schoolID string) bool {
	return countRows(database.DB.Model(&models.AcademicYear{}).
		Where("id = ? AND school_id = ?", strings.TrimSpace(academicYearID), schoolID)) > 0
}

func gradeBelongsToSchool(gradeID, schoolID string) bool {
	return countRows(database.DB.Model(&models.Grade{}).
		Where("id = ? AND school_id = ?", strings.TrimSpace(gradeID), schoolID)) > 0
}

func sectionBelongsToGrade(sectionID, gradeID string) bool {
	return countRows(database.DB.Model(&models.Section{}).
		Where("id = ? AND grade_id = ?", strings.TrimSpace(sectionID), strings.TrimSpace(gradeID))) > 0
}

func invoiceScope(studentID, sectionID string) string {
	if strings.TrimSpace(studentID) != "" {
		return "student"
	}
	if strings.TrimSpace(sectionID) != "" {
		return "section"
	}
	return "class"
}

func generatedInvoiceNumber(label string, student models.Student) string {
	studentKey := firstNonEmpty(student.AdmissionNumber, student.StudentCode, student.ID)
	segment := normalizeInvoiceSegment(label)
	if segment == "" {
		segment = time.Now().UTC().Format("JAN-2006")
	}
	studentSegment := normalizeInvoiceSegment(studentKey)
	if studentSegment == "" && len(student.ID) >= 8 {
		studentSegment = strings.ToUpper(student.ID[:8])
	}
	number := "FEE-" + segment + "-" + studentSegment
	if len(number) <= 100 {
		return number
	}
	return number[:100]
}

func normalizeInvoiceSegment(value string) string {
	var b strings.Builder
	lastDash := false
	for _, r := range strings.TrimSpace(value) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(unicode.ToUpper(r))
			lastDash = false
			continue
		}
		if !lastDash && b.Len() > 0 {
			b.WriteByte('-')
			lastDash = true
		}
	}
	return strings.Trim(b.String(), "-")
}

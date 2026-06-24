package handlers

import (
	"fmt"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
	"unicode"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"school-backend/internal/database"
	"school-backend/internal/models"
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
	sectionID := strings.TrimSpace(c.Query("section_id"))

	var structures []models.FeeStructure
	query := database.DB.Preload("FeeCategory").
		Preload("Grade").
		Preload("Section").
		Preload("AcademicYear").
		Preload("Installments", func(db *gorm.DB) *gorm.DB {
			return db.Order("installment_number ASC")
		})
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	if yearID != "" {
		query = query.Where("academic_year_id = ?", yearID)
	}
	if gradeID != "" {
		query = query.Where("grade_id = ?", gradeID)
	}
	if sectionID != "" {
		query = query.Where("(section_id = ? OR section_id IS NULL)", sectionID)
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
	sectionID, err := validatedFeeStructureSectionID(scopedSchoolID(c), req.AcademicYearID, req.GradeID, req.SectionID)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	effectiveFrom, err := optionalFeeDate(req.EffectiveFrom)
	if err != nil {
		fail(c, http.StatusBadRequest, "effective_from must be YYYY-MM-DD")
		return
	}

	structure := models.FeeStructure{
		SchoolID:          scopedSchoolID(c),
		AcademicYearID:    req.AcademicYearID,
		GradeID:           req.GradeID,
		SectionID:         sectionID,
		FeeCategoryID:     req.FeeCategoryID,
		Amount:            req.Amount,
		DueDay:            req.DueDay,
		LateFinePerDay:    req.LateFinePerDay,
		InstallmentCount:  normalizeInstallmentCount(req.InstallmentCount),
		InstallmentMethod: normalizeInstallmentMethod(req.InstallmentMethod),
		EffectiveFrom:     effectiveFrom,
	}

	replacedCount := int64(0)
	err = database.DB.Transaction(func(tx *gorm.DB) error {
		if req.ReplaceExisting {
			var existingIDs []string
			existingQuery := tx.Model(&models.FeeStructure{}).Where(
				"school_id = ? AND academic_year_id = ? AND grade_id = ?",
				structure.SchoolID,
				structure.AcademicYearID,
				structure.GradeID,
			)
			if structure.SectionID != nil {
				existingQuery = existingQuery.Where("section_id = ?", *structure.SectionID)
			}
			if err := existingQuery.Pluck("id", &existingIDs).Error; err != nil {
				return err
			}
			if len(existingIDs) > 0 {
				if err := tx.Where("fee_structure_id IN ?", existingIDs).Delete(&models.FeeInstallment{}).Error; err != nil {
					return err
				}
			}
			if len(existingIDs) > 0 {
				result := tx.Where("id IN ?", existingIDs).Delete(&models.FeeStructure{})
				if result.Error != nil {
					return result.Error
				}
				replacedCount = result.RowsAffected
			}
		}
		if err := tx.Create(&structure).Error; err != nil {
			return err
		}
		return replaceFeeInstallments(tx, structure, req.Installments)
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create fee structure"})
		return
	}
	_ = database.DB.Preload("FeeCategory").Preload("Grade").Preload("Section").Preload("AcademicYear").Preload("Installments", func(db *gorm.DB) *gorm.DB {
		return db.Order("installment_number ASC")
	}).First(&structure, "id = ?", structure.ID).Error

	id := structure.ID
	auditAction(c, "fees", "create", "fee_structures", &id)
	c.JSON(http.StatusCreated, models.APIResponse{
		Success: true,
		Data:    structure,
		Meta: gin.H{
			"replace_existing": req.ReplaceExisting,
			"replaced_count":   replacedCount,
		},
	})
}

func (h *FeeHandler) UpdateFeeStructure(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	id := c.Param("id")
	var req struct {
		AcademicYearID    string                         `json:"academic_year_id"`
		GradeID           string                         `json:"grade_id"`
		SectionID         *string                        `json:"section_id"`
		FeeCategoryID     string                         `json:"fee_category_id"`
		Amount            *float64                       `json:"amount"`
		DueDay            *int                           `json:"due_day"`
		LateFinePerDay    *float64                       `json:"late_fine_per_day"`
		InstallmentCount  *int                           `json:"installment_count"`
		InstallmentMethod string                         `json:"installment_method"`
		EffectiveFrom     *string                        `json:"effective_from"`
		Installments      []models.FeeInstallmentRequest `json:"installments"`
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
	if req.SectionID != nil {
		sectionID, err := validatedFeeStructureSectionID(schoolID, firstNonEmpty(req.AcademicYearID, structure.AcademicYearID), firstNonEmpty(req.GradeID, structure.GradeID), *req.SectionID)
		if err != nil {
			fail(c, http.StatusBadRequest, err.Error())
			return
		}
		updates["section_id"] = sectionID
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
	if req.InstallmentCount != nil {
		updates["installment_count"] = normalizeInstallmentCount(*req.InstallmentCount)
	}
	if strings.TrimSpace(req.InstallmentMethod) != "" {
		updates["installment_method"] = normalizeInstallmentMethod(req.InstallmentMethod)
	}
	if req.EffectiveFrom != nil {
		effectiveFrom, err := optionalFeeDate(*req.EffectiveFrom)
		if err != nil {
			fail(c, http.StatusBadRequest, "effective_from must be YYYY-MM-DD")
			return
		}
		updates["effective_from"] = effectiveFrom
	}
	if len(updates) == 0 && req.Installments == nil {
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

	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if len(updates) > 0 {
			if err := tx.Model(&structure).Updates(updates).Error; err != nil {
				return err
			}
		}
		if req.Installments != nil {
			if err := tx.First(&structure, "id = ?", id).Error; err != nil {
				return err
			}
			return replaceFeeInstallments(tx, structure, req.Installments)
		}
		return nil
	}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update fee structure"})
		return
	}
	if err := database.DB.Preload("FeeCategory").Preload("Grade").Preload("Section").Preload("AcademicYear").Preload("Installments", func(db *gorm.DB) *gorm.DB {
		return db.Order("installment_number ASC")
	}).First(&structure, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reload fee structure"})
		return
	}

	auditAction(c, "fees", "update", "fee_structures", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: structure})
}

func normalizeInstallmentCount(value int) int {
	if value < 1 {
		return 3
	}
	if value > 12 {
		return 12
	}
	return value
}

func normalizeInstallmentMethod(value string) string {
	text := strings.ToLower(strings.TrimSpace(value))
	text = strings.ReplaceAll(text, "-", "_")
	text = strings.ReplaceAll(text, " ", "_")
	switch text {
	case "percentage", "percentage_division":
		return "percentage"
	case "custom", "custom_amount", "custom_amounts":
		return "custom"
	case "monthly", "monthly_payment", "monthly_payments":
		return "monthly"
	case "term", "term_wise", "termwise":
		return "term"
	case "one_time", "one_time_payment", "onetime":
		return "one_time"
	default:
		return "equal"
	}
}

func optionalFeeDate(value string) (*time.Time, error) {
	text := strings.TrimSpace(value)
	if text == "" {
		return nil, nil
	}
	parsed, err := parseDate(text)
	if err != nil {
		return nil, err
	}
	return &parsed, nil
}

func validatedFeeStructureSectionID(schoolID, academicYearID, gradeID, rawSectionID string) (*string, error) {
	sectionID := strings.TrimSpace(rawSectionID)
	if sectionID == "" {
		return nil, nil
	}
	if !sectionBelongsToSchool(sectionID, schoolID) {
		return nil, fmt.Errorf("section must belong to this school")
	}
	if !sectionBelongsToGrade(sectionID, strings.TrimSpace(gradeID)) {
		return nil, fmt.Errorf("section must belong to selected grade")
	}
	var count int64
	if err := database.DB.Model(&models.Section{}).
		Where("id = ? AND academic_year_id = ?", sectionID, strings.TrimSpace(academicYearID)).
		Count(&count).Error; err != nil {
		return nil, err
	}
	if count == 0 {
		return nil, fmt.Errorf("section must belong to selected academic year")
	}
	return &sectionID, nil
}

func replaceFeeInstallments(tx *gorm.DB, structure models.FeeStructure, rows []models.FeeInstallmentRequest) error {
	if err := tx.Where("fee_structure_id = ?", structure.ID).Delete(&models.FeeInstallment{}).Error; err != nil {
		return err
	}
	if len(rows) == 0 {
		return nil
	}
	method := normalizeInstallmentMethod(structure.InstallmentMethod)
	installments := make([]models.FeeInstallment, 0, len(rows))
	for index, row := range rows {
		dueDate, err := parseDate(strings.TrimSpace(row.DueDate))
		if err != nil {
			return fmt.Errorf("installments[%d].due_date must be YYYY-MM-DD", index)
		}
		name := strings.TrimSpace(row.InstallmentName)
		if name == "" {
			name = fmt.Sprintf("Installment %d", index+1)
		}
		number := row.InstallmentNumber
		if number <= 0 {
			number = index + 1
		}
		amount := roundMoney(row.Amount)
		if amount <= 0 && row.Percentage > 0 {
			amount = roundMoney(structure.Amount * row.Percentage / 100)
		}
		if amount <= 0 {
			return fmt.Errorf("installments[%d].amount must be greater than zero", index)
		}
		status := strings.ToLower(strings.TrimSpace(row.Status))
		if status == "" {
			status = "upcoming"
		}
		structureID := structure.ID
		installments = append(installments, models.FeeInstallment{
			SchoolID:          structure.SchoolID,
			AcademicYearID:    structure.AcademicYearID,
			GradeID:           structure.GradeID,
			SectionID:         structure.SectionID,
			FeeStructureID:    &structureID,
			Method:            method,
			InstallmentName:   name,
			InstallmentNumber: number,
			Amount:            amount,
			Percentage:        row.Percentage,
			DueDate:           dueDate,
			Status:            status,
		})
	}
	return tx.Create(&installments).Error
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
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("fee_structure_id = ?", id).Delete(&models.FeeInstallment{}).Error; err != nil {
			return err
		}
		result := tx.Where("id = ? AND school_id = ?", id, schoolID).Delete(&models.FeeStructure{})
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected == 0 {
			return gorm.ErrRecordNotFound
		}
		return nil
	})
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "Fee structure not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete fee structure"})
		return
	}
	auditAction(c, "fees", "delete", "fee_structures", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: gin.H{"id": id}})
}

func (h *FeeHandler) RolloverFeeStructures(c *gin.Context) {
	var req struct {
		FromAcademicYearID string `json:"from_academic_year_id" binding:"required"`
		ToAcademicYearID   string `json:"to_academic_year_id" binding:"required"`
		Overwrite          bool   `json:"overwrite"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	schoolID := scopedSchoolID(c)
	if !academicYearBelongsToSchool(req.FromAcademicYearID, schoolID) || !academicYearBelongsToSchool(req.ToAcademicYearID, schoolID) {
		fail(c, http.StatusBadRequest, "academic years must belong to this school")
		return
	}
	var source []models.FeeStructure
	if err := database.DB.
		Where("school_id = ? AND academic_year_id = ?", schoolID, req.FromAcademicYearID).
		Preload("Installments").
		Find(&source).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load source fee structures")
		return
	}
	created, skipped, overwritten := 0, 0, 0
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		for _, row := range source {
			var existing models.FeeStructure
			query := tx.Where("school_id = ? AND academic_year_id = ? AND grade_id = ? AND fee_category_id = ?", schoolID, req.ToAcademicYearID, row.GradeID, row.FeeCategoryID)
			if row.SectionID == nil {
				query = query.Where("section_id IS NULL")
			} else {
				query = query.Where("section_id = ?", *row.SectionID)
			}
			found := query.First(&existing).Error
			if found == nil && !req.Overwrite {
				skipped++
				continue
			}
			if found == nil && req.Overwrite {
				if err := tx.Where("fee_structure_id = ?", existing.ID).Delete(&models.FeeInstallment{}).Error; err != nil {
					return err
				}
				if err := tx.Delete(&existing).Error; err != nil {
					return err
				}
				overwritten++
			} else if found != gorm.ErrRecordNotFound {
				return found
			}
			clone := row
			clone.BaseModel = models.BaseModel{}
			clone.AcademicYearID = req.ToAcademicYearID
			clone.Installments = nil
			if err := tx.Create(&clone).Error; err != nil {
				return err
			}
			for _, installment := range row.Installments {
				next := installment
				next.BaseModel = models.BaseModel{}
				next.AcademicYearID = req.ToAcademicYearID
				next.FeeStructureID = &clone.ID
				if err := tx.Create(&next).Error; err != nil {
					return err
				}
			}
			created++
		}
		return nil
	})
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to rollover fee structures")
		return
	}
	id := req.ToAcademicYearID
	auditAction(c, "fees", "rollover", "fee_structures", &id)
	success(c, http.StatusCreated, gin.H{"created": created, "skipped": skipped, "overwritten": overwritten}, "Fee structures rolled over")
}

func (h *FeeHandler) PreviewFeeInvoiceSync(c *gin.Context) {
	rows, summary, err := feeInvoiceSyncRows(scopedSchoolID(c), c.Param("id"), false, false)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	success(c, http.StatusOK, gin.H{"rows": rows, "summary": summary}, "Fee invoice sync preview")
}

func (h *FeeHandler) ApplyFeeInvoiceSync(c *gin.Context) {
	var req struct {
		IncludePartiallyPaid bool `json:"include_partially_paid"`
	}
	_ = c.ShouldBindJSON(&req)
	rows, summary, err := feeInvoiceSyncRows(scopedSchoolID(c), c.Param("id"), req.IncludePartiallyPaid, true)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	id := c.Param("id")
	auditAction(c, "fees", "sync_invoices", "fee_structures", &id)
	success(c, http.StatusOK, gin.H{"rows": rows, "summary": summary}, "Fee invoices synced")
}

func feeInvoiceSyncRows(schoolID, structureID string, includePartiallyPaid, apply bool) ([]gin.H, gin.H, error) {
	var structure models.FeeStructure
	if err := database.DB.Preload("FeeCategory").First(&structure, "id = ? AND school_id = ?", structureID, schoolID).Error; err != nil {
		return nil, nil, fmt.Errorf("fee structure not found")
	}
	newItemAmount := roundMoney(structure.Amount / float64(normalizeInstallmentCount(structure.InstallmentCount)))
	query := database.DB.Model(&models.FeeInvoice{}).
		Joins("JOIN students ON students.id = fee_invoices.student_id").
		Joins("JOIN sections ON sections.id = students.current_section_id").
		Where("students.school_id = ? AND fee_invoices.academic_year_id = ? AND sections.grade_id = ?", schoolID, structure.AcademicYearID, structure.GradeID).
		Preload("Items")
	if structure.SectionID != nil {
		query = query.Where("students.current_section_id = ?", *structure.SectionID)
	}
	var invoices []models.FeeInvoice
	if err := query.Find(&invoices).Error; err != nil {
		return nil, nil, err
	}
	rows := []gin.H{}
	affected, skippedPaid, skippedPartial := 0, 0, 0
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		for _, invoice := range invoices {
			oldItemTotal := 0.0
			for _, item := range invoice.Items {
				if item.FeeCategoryID == structure.FeeCategoryID {
					oldItemTotal += item.Amount
				}
			}
			if oldItemTotal <= 0 {
				continue
			}
			if strings.EqualFold(invoice.Status, "paid") || invoice.Balance <= 0 {
				skippedPaid++
				rows = append(rows, gin.H{"invoice_id": invoice.ID, "status": "skipped_paid", "old_total": invoice.TotalAmount, "new_total": invoice.TotalAmount})
				continue
			}
			if invoice.PaidAmount > 0 && !includePartiallyPaid {
				skippedPartial++
				rows = append(rows, gin.H{"invoice_id": invoice.ID, "status": "skipped_partial", "old_total": invoice.TotalAmount, "new_total": invoice.TotalAmount})
				continue
			}
			newTotal := roundMoney(invoice.TotalAmount - oldItemTotal + newItemAmount)
			newPayable := roundMoney(newTotal - invoice.DiscountAmount - invoice.ConcessionAmount + invoice.FineAmount)
			if newPayable < 0 {
				newPayable = 0
			}
			newBalance := roundMoney(newPayable - invoice.PaidAmount)
			if newBalance < 0 {
				newBalance = 0
			}
			if apply {
				updatedItem := false
				for _, item := range invoice.Items {
					if item.FeeCategoryID != structure.FeeCategoryID || updatedItem {
						continue
					}
					if err := tx.Model(&models.FeeInvoiceItem{}).Where("id = ?", item.ID).Update("amount", newItemAmount).Error; err != nil {
						return err
					}
					updatedItem = true
				}
				nextStatus := "pending"
				if invoice.PaidAmount > 0 && newBalance > 0 {
					nextStatus = "partial"
				}
				if newBalance == 0 {
					nextStatus = "paid"
				}
				if err := tx.Model(&models.FeeInvoice{}).Where("id = ?", invoice.ID).Updates(map[string]interface{}{
					"total_amount":   newTotal,
					"payable_amount": newPayable,
					"paid_amount":    invoice.PaidAmount,
					"balance":        newBalance,
					"status":         nextStatus,
				}).Error; err != nil {
					return err
				}
			}
			affected++
			rows = append(rows, gin.H{"invoice_id": invoice.ID, "status": "affected", "old_total": invoice.TotalAmount, "new_total": newTotal})
		}
		return nil
	})
	if err != nil {
		return nil, nil, err
	}
	return rows, gin.H{"affected": affected, "skipped_paid": skippedPaid, "skipped_partial": skippedPartial}, nil
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
	if termID := strings.TrimSpace(c.Query("term_id")); termID != "" {
		query = query.Where("fee_invoices.term_id = ?", termID)
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
		Preload("Term").
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
		PayableAmount:  req.NetAmount,
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
		AcademicYearID   string `json:"academic_year_id" binding:"required"`
		GradeID          string `json:"grade_id" binding:"required"`
		SectionID        string `json:"section_id"`
		StudentID        string `json:"student_id"`
		InvoiceDate      string `json:"invoice_date"`
		DueDate          string `json:"due_date" binding:"required"`
		InvoiceLabel     string `json:"invoice_label"`
		TermID           string `json:"term_id"`
		IncludeOneTime   *bool  `json:"include_one_time"`
		IncludeYearly    *bool  `json:"include_yearly"`
		InstallmentCount int    `json:"installment_count"`
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
	var selectedTerm models.Term
	termID := strings.TrimSpace(req.TermID)
	if termID != "" {
		if err := database.DB.
			Joins("JOIN academic_years ON academic_years.id = terms.academic_year_id").
			Where("terms.id = ? AND terms.academic_year_id = ? AND academic_years.school_id = ?", termID, req.AcademicYearID, schoolID).
			First(&selectedTerm).Error; err != nil {
			fail(c, http.StatusBadRequest, "term must belong to the selected academic year")
			return
		}
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
	structureQuery := database.DB.
		Where("school_id = ? AND academic_year_id = ? AND grade_id = ?", schoolID, req.AcademicYearID, req.GradeID).
		Preload("FeeCategory").
		Preload("Installments", func(db *gorm.DB) *gorm.DB {
			return db.Order("installment_number ASC")
		}).
		Order("created_at ASC").
		Session(&gorm.Session{})
	if strings.TrimSpace(req.SectionID) != "" {
		structureQuery = structureQuery.Where("(section_id = ? OR section_id IS NULL)", strings.TrimSpace(req.SectionID))
	}
	if err := structureQuery.Find(&structures).Error; err != nil {
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
		if termID != "" && strings.TrimSpace(selectedTerm.TermName) != "" {
			label = selectedTerm.TermName
		} else {
			label = invoiceDate.Format("Jan-2006")
		}
	}

	// Determine the installment/term count using cascading priority:
	// 1. Explicit installment_count from request (admin override)
	// 2. InstallmentCount from the first fee structure (per-class config)
	// 3. Number of Term records in the academic year
	// 4. Default: 3
	termCount := 3
	if req.InstallmentCount > 0 {
		termCount = req.InstallmentCount
	} else if len(structures) > 0 && structures[0].InstallmentCount > 0 {
		termCount = structures[0].InstallmentCount
	} else if termID != "" {
		var count int64
		if err := database.DB.Model(&models.Term{}).
			Where("academic_year_id = ?", req.AcademicYearID).
			Count(&count).Error; err != nil {
			fail(c, http.StatusInternalServerError, "Failed to load academic terms")
			return
		}
		if count > 0 {
			termCount = int(count)
		}
	}
	includeOneTime := req.IncludeOneTime != nil && *req.IncludeOneTime
	includeYearly := req.IncludeYearly != nil && *req.IncludeYearly
	billableItems := feeScheduledBillableItems(structures, strings.TrimSpace(req.SectionID), label, dueDate)
	if len(billableItems) > 0 && !billableItems[0].dueDate.IsZero() {
		dueDate = billableItems[0].dueDate
	} else {
		billableItems = feeBillableItems(structures, termID != "", termCount, includeOneTime, includeYearly)
	}
	total := 0.0
	for _, item := range billableItems {
		total += item.amount
	}
	total = roundMoney(total)
	if total <= 0 {
		fail(c, http.StatusBadRequest, "No billable fee components matched the selected term and options")
		return
	}

	concessionsByStudent, err := loadApprovedFeeConcessions(schoolID, req.AcademicYearID, students)
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load student concessions")
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

			var invoiceTermID *string
			if termID != "" {
				value := termID
				invoiceTermID = &value
			}
			concessionAmount := concessionAmountForItems(billableItems, concessionsByStudent[student.ID])
			payableAmount := roundMoney(total - concessionAmount)
			if payableAmount < 0 {
				payableAmount = 0
			}
			invoice := models.FeeInvoice{
				StudentID:        student.ID,
				AcademicYearID:   req.AcademicYearID,
				TermID:           invoiceTermID,
				InvoiceNumber:    invoiceNumber,
				InvoiceDate:      invoiceDate,
				DueDate:          dueDate,
				TotalAmount:      total,
				DiscountAmount:   0,
				ConcessionAmount: concessionAmount,
				NetAmount:        payableAmount,
				PayableAmount:    payableAmount,
				PaidAmount:       0,
				Balance:          payableAmount,
				Status:           "pending",
			}
			if err := tx.Create(&invoice).Error; err != nil {
				return err
			}
			for _, billable := range billableItems {
				structure := billable.structure
				item := models.FeeInvoiceItem{
					InvoiceID:     invoice.ID,
					FeeCategoryID: structure.FeeCategoryID,
					Amount:        billable.amount,
					Description:   billable.description,
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
		"created":           len(created),
		"skipped":           len(skipped),
		"total_students":    len(students),
		"invoice_label":     label,
		"term_id":           termID,
		"term_count":        termCount,
		"per_student_total": total,
		"include_one_time":  includeOneTime,
		"include_yearly":    includeYearly,
		"scope":             invoiceScope(req.StudentID, req.SectionID),
		"invoices":          created,
		"skipped_rows":      skipped,
	}, "Fee invoices generated")
}

type feeBillableItem struct {
	structure   models.FeeStructure
	amount      float64
	description string
	dueDate     time.Time
}

func feeScheduledBillableItems(structures []models.FeeStructure, sectionID, label string, dueDate time.Time) []feeBillableItem {
	items := []feeBillableItem{}
	normalizedLabel := strings.ToLower(strings.TrimSpace(label))
	sectionID = strings.TrimSpace(sectionID)
	for _, structure := range structures {
		for _, installment := range structure.Installments {
			if installment.SectionID != nil && sectionID != "" && *installment.SectionID != sectionID {
				continue
			}
			if installment.SectionID != nil && sectionID == "" {
				continue
			}
			nameMatch := normalizedLabel != "" && strings.ToLower(strings.TrimSpace(installment.InstallmentName)) == normalizedLabel
			dateMatch := !dueDate.IsZero() && sameFeeDate(installment.DueDate, dueDate)
			if !nameMatch && !dateMatch {
				continue
			}
			amount := roundMoney(installment.Amount)
			if amount <= 0 && installment.Percentage > 0 {
				amount = roundMoney(structure.Amount * installment.Percentage / 100)
			}
			if amount <= 0 {
				continue
			}
			description := feeStructureDescription(structure)
			if strings.TrimSpace(installment.InstallmentName) != "" {
				description = fmt.Sprintf("%s - %s", description, strings.TrimSpace(installment.InstallmentName))
			}
			items = append(items, feeBillableItem{
				structure:   structure,
				amount:      amount,
				description: description,
				dueDate:     installment.DueDate,
			})
		}
	}
	return items
}

func sameFeeDate(left, right time.Time) bool {
	ly, lm, ld := left.Date()
	ry, rm, rd := right.Date()
	return ly == ry && lm == rm && ld == rd
}

func feeBillableItems(structures []models.FeeStructure, termMode bool, termCount int, includeOneTime, includeYearly bool) []feeBillableItem {
	if termCount <= 0 {
		termCount = 1
	}
	items := make([]feeBillableItem, 0, len(structures))
	for _, structure := range structures {
		frequency := normalizedFeeFrequency(structure)
		amount := structure.Amount
		if termMode {
			switch frequency {
			case "one_time":
				if !includeOneTime {
					continue
				}
			case "yearly":
				if !includeYearly {
					continue
				}
			case "term":
				amount = structure.Amount / float64(termCount)
			}
		}
		amount = roundMoney(amount)
		if amount <= 0 {
			continue
		}
		items = append(items, feeBillableItem{
			structure:   structure,
			amount:      amount,
			description: feeStructureDescription(structure),
		})
	}
	return items
}

func loadApprovedFeeConcessions(schoolID, academicYearID string, students []models.Student) (map[string][]models.FeeConcession, error) {
	result := make(map[string][]models.FeeConcession)
	if len(students) == 0 {
		return result, nil
	}
	studentIDs := make([]string, 0, len(students))
	for _, student := range students {
		studentIDs = append(studentIDs, student.ID)
	}
	var concessions []models.FeeConcession
	if err := database.DB.
		Model(&models.FeeConcession{}).
		Joins("JOIN students ON students.id = fee_concessions.student_id").
		Where("students.school_id = ? AND fee_concessions.academic_year_id = ? AND fee_concessions.student_id IN ? AND (fee_concessions.status = ? OR fee_concessions.approved_by IS NOT NULL)", schoolID, academicYearID, studentIDs, "approved").
		Find(&concessions).Error; err != nil {
		return result, err
	}
	for _, concession := range concessions {
		result[concession.StudentID] = append(result[concession.StudentID], concession)
	}
	return result, nil
}

func concessionAmountForItems(items []feeBillableItem, concessions []models.FeeConcession) float64 {
	if len(items) == 0 || len(concessions) == 0 {
		return 0
	}
	totalConcession := 0.0
	for _, item := range items {
		for _, concession := range concessions {
			if concession.FeeCategoryID != item.structure.FeeCategoryID {
				continue
			}
			switch normalizedConcessionType(concession.ConcessionType) {
			case "percentage":
				totalConcession += item.amount * concession.Value / 100
			case "amount":
				totalConcession += concession.Value
			}
		}
	}
	itemTotal := 0.0
	for _, item := range items {
		itemTotal += item.amount
	}
	if totalConcession > itemTotal {
		totalConcession = itemTotal
	}
	return roundMoney(totalConcession)
}

func normalizedConcessionType(value string) string {
	text := strings.ToLower(strings.TrimSpace(value))
	text = strings.ReplaceAll(text, "-", "_")
	text = strings.ReplaceAll(text, " ", "_")
	switch {
	case strings.Contains(text, "percent"):
		return "percentage"
	case strings.Contains(text, "amount"), strings.Contains(text, "flat"), strings.Contains(text, "fixed"):
		return "amount"
	default:
		return text
	}
}

func normalizedFeeFrequency(structure models.FeeStructure) string {
	text := ""
	if structure.FeeCategory != nil {
		text = structure.FeeCategory.Frequency
	}
	text = strings.ToLower(strings.TrimSpace(strings.ReplaceAll(text, "-", "_")))
	text = strings.ReplaceAll(text, " ", "_")
	switch {
	case strings.Contains(text, "one"):
		return "one_time"
	case strings.Contains(text, "year"):
		return "yearly"
	case strings.Contains(text, "month"):
		return "monthly"
	case strings.Contains(text, "term"):
		return "term"
	case text == "":
		return "term"
	default:
		return text
	}
}

func feeStructureDescription(structure models.FeeStructure) string {
	if structure.FeeCategory != nil && strings.TrimSpace(structure.FeeCategory.CategoryName) != "" {
		return structure.FeeCategory.CategoryName
	}
	return "Fee"
}

func roundMoney(amount float64) float64 {
	return math.Round(amount*100) / 100
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
		ProofURL         string  `json:"proof_url"`
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
	paymentMode := strings.ToLower(strings.TrimSpace(req.PaymentMode))
	transactionID := strings.TrimSpace(req.TransactionID)
	proofURL := strings.TrimSpace(req.ProofURL)
	if paymentMode == "upi" {
		if transactionID == "" {
			fail(c, http.StatusBadRequest, "transaction_id is required for UPI payment requests")
			return
		}
		if proofURL == "" {
			fail(c, http.StatusBadRequest, "proof_url is required for UPI payment requests")
			return
		}
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
	var parentLink models.ParentStudentLink
	if err := database.DB.Where("school_id = ? AND parent_user_id = ? AND student_id = ?", scopedSchoolID(c), currentUserID(c), invoice.StudentID).First(&parentLink).Error; err != nil {
		fail(c, http.StatusForbidden, "Invoice does not belong to a linked child")
		return
	}
	if invoice.Balance <= 0 {
		fail(c, http.StatusBadRequest, "invoice has no outstanding balance")
		return
	}
	paymentSetting := resolvePaymentSettingForInvoice(scopedSchoolID(c), invoice.ID)
	var paymentConfigID *string
	if strings.TrimSpace(paymentSetting.ID) != "" {
		paymentConfigID = &paymentSetting.ID
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
		SchoolID:          scopedSchoolID(c),
		InvoiceID:         invoice.ID,
		StudentID:         invoice.StudentID,
		ParentUserID:      currentUserID(c),
		RequestReference:  reference,
		Amount:            req.Amount,
		PaymentDate:       paymentDate,
		PaymentMode:       paymentMode,
		TransactionID:     transactionID,
		Status:            "pending",
		Remarks:           strings.TrimSpace(req.Remarks),
		PaymentConfigID:   paymentConfigID,
		PaymentUPIID:      paymentSetting.UPIID,
		PaymentPayeeName:  paymentSetting.PayeeName,
		PaymentQRImageURL: paymentSetting.QRImageURL,
		PaymentQRNote:     paymentSetting.QRNote,
	}
	if proofURL != "" {
		paymentRequest.ProofURL = &proofURL
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

	decider := currentUserID(c)
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		_, err := applyParentPaymentRequestDecisionTx(tx, scopedSchoolID(c), decider, paymentRequest.ID, status, req.AdminRemarks)
		return err
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

func applyParentPaymentRequestDecisionTx(tx *gorm.DB, schoolID, decider, requestID, status, remarks string) (models.ParentPaymentRequest, error) {
	status = strings.ToLower(strings.TrimSpace(status))
	if status != "approved" && status != "rejected" {
		return models.ParentPaymentRequest{}, fmt.Errorf("status must be approved or rejected")
	}
	var paymentRequest models.ParentPaymentRequest
	if err := tx.First(&paymentRequest, "id = ? AND school_id = ?", requestID, schoolID).Error; err != nil {
		return models.ParentPaymentRequest{}, fmt.Errorf("payment request not found")
	}
	if !strings.EqualFold(paymentRequest.Status, "pending") {
		return models.ParentPaymentRequest{}, fmt.Errorf("Payment request has already been actioned")
	}
	now := time.Now().UTC()
	paymentRequest.Status = status
	paymentRequest.AdminRemarks = strings.TrimSpace(remarks)
	paymentRequest.DecidedBy = &decider
	paymentRequest.DecidedAt = &now
	if status == "rejected" {
		if err := tx.Save(&paymentRequest).Error; err != nil {
			return models.ParentPaymentRequest{}, err
		}
		return paymentRequest, nil
	}

	var invoice models.FeeInvoice
	if err := tx.Model(&models.FeeInvoice{}).
		Joins("JOIN students ON students.id = fee_invoices.student_id").
		Where("fee_invoices.id = ? AND students.school_id = ?", paymentRequest.InvoiceID, schoolID).
		First(&invoice).Error; err != nil {
		return models.ParentPaymentRequest{}, fmt.Errorf("invoice not found")
	}
	if paymentRequest.Amount > invoice.Balance {
		return models.ParentPaymentRequest{}, fmt.Errorf("payment request amount exceeds current outstanding balance")
	}
	payment := models.Payment{
		InvoiceID:         paymentRequest.InvoiceID,
		ReceiptNumber:     paymentRequest.RequestReference,
		AmountPaid:        paymentRequest.Amount,
		PaymentDate:       paymentRequest.PaymentDate,
		PaymentMode:       paymentRequest.PaymentMode,
		TransactionID:     paymentRequest.TransactionID,
		PaymentConfigID:   paymentRequest.PaymentConfigID,
		PaymentUPIID:      paymentRequest.PaymentUPIID,
		PaymentPayeeName:  paymentRequest.PaymentPayeeName,
		PaymentQRImageURL: paymentRequest.PaymentQRImageURL,
		PaymentQRNote:     paymentRequest.PaymentQRNote,
	}
	if isUUIDLike(decider) {
		payment.ReceivedBy = &decider
	}
	if err := tx.Create(&payment).Error; err != nil {
		return models.ParentPaymentRequest{}, err
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
		return models.ParentPaymentRequest{}, err
	}
	paymentRequest.PaymentID = &payment.ID
	if err := tx.Save(&paymentRequest).Error; err != nil {
		return models.ParentPaymentRequest{}, err
	}
	return paymentRequest, nil
}

func isUUIDLike(value string) bool {
	value = strings.TrimSpace(value)
	if len(value) != 36 {
		return false
	}
	for index, char := range value {
		switch index {
		case 8, 13, 18, 23:
			if char != '-' {
				return false
			}
		default:
			if !((char >= '0' && char <= '9') || (char >= 'a' && char <= 'f') || (char >= 'A' && char <= 'F')) {
				return false
			}
		}
	}
	return true
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
		Preload("Student").
		Preload("AcademicYear")
	if studentID != "" {
		query = query.Where("fee_concessions.student_id = ?", studentID)
	}
	if status := strings.TrimSpace(c.Query("status")); status != "" {
		query = query.Where("fee_concessions.status = ?", strings.ToLower(status))
	}
	query.Find(&concessions)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: concessions})
}

func (h *FeeHandler) CreateConcession(c *gin.Context) {
	var req struct {
		StudentID      string  `json:"student_id" binding:"required"`
		FeeCategoryID  string  `json:"fee_category_id" binding:"required"`
		AcademicYearID string  `json:"academic_year_id" binding:"required"`
		ConcessionType string  `json:"concession_type" binding:"required"`
		Value          float64 `json:"value" binding:"required"`
		Reason         string  `json:"reason"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	schoolID := scopedSchoolID(c)
	if err := validateConcessionScope(schoolID, req.StudentID, req.FeeCategoryID, req.AcademicYearID); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	if req.Value <= 0 {
		fail(c, http.StatusBadRequest, "concession value must be greater than zero")
		return
	}
	status := "pending"
	concession := models.FeeConcession{
		SchoolID:       schoolID,
		StudentID:      strings.TrimSpace(req.StudentID),
		FeeCategoryID:  strings.TrimSpace(req.FeeCategoryID),
		AcademicYearID: strings.TrimSpace(req.AcademicYearID),
		ConcessionType: normalizedConcessionType(req.ConcessionType),
		Value:          req.Value,
		Reason:         strings.TrimSpace(req.Reason),
		Status:         status,
	}
	if userID := currentUserID(c); userID != "" {
		concession.RequestedBy = &userID
	}
	if currentRole(c) == "principal" {
		now := time.Now().UTC()
		userID := currentUserID(c)
		concession.Status = "approved"
		concession.ApprovedBy = &userID
		concession.DecidedBy = &userID
		concession.DecidedAt = &now
	}
	if err := database.DB.Create(&concession).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create concession")
		return
	}
	id := concession.ID
	auditAction(c, "fees", "create_concession", "fee_concessions", &id)
	success(c, http.StatusCreated, concession, "Concession saved")
}

func (h *FeeHandler) DecideConcession(c *gin.Context) {
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
	var concession models.FeeConcession
	if err := database.DB.
		Joins("JOIN students ON students.id = fee_concessions.student_id").
		Where("fee_concessions.id = ? AND students.school_id = ?", c.Param("id"), scopedSchoolID(c)).
		First(&concession).Error; err != nil {
		fail(c, http.StatusNotFound, "Concession not found")
		return
	}
	now := time.Now().UTC()
	decider := currentUserID(c)
	concession.Status = status
	concession.AdminRemarks = strings.TrimSpace(req.AdminRemarks)
	concession.DecidedBy = &decider
	concession.DecidedAt = &now
	if status == "approved" {
		concession.ApprovedBy = &decider
	} else {
		concession.ApprovedBy = nil
	}
	if err := database.DB.Save(&concession).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update concession")
		return
	}
	id := concession.ID
	auditAction(c, "fees", status+"_concession", "fee_concessions", &id)
	success(c, http.StatusOK, concession, "Concession updated")
}

func (h *FeeHandler) DeleteConcession(c *gin.Context) {
	result := database.DB.
		Joins("JOIN students ON students.id = fee_concessions.student_id").
		Where("fee_concessions.id = ? AND students.school_id = ?", c.Param("id"), scopedSchoolID(c)).
		Delete(&models.FeeConcession{})
	if result.Error != nil {
		fail(c, http.StatusInternalServerError, "Failed to delete concession")
		return
	}
	if result.RowsAffected == 0 {
		fail(c, http.StatusNotFound, "Concession not found")
		return
	}
	id := c.Param("id")
	auditAction(c, "fees", "delete_concession", "fee_concessions", &id)
	success(c, http.StatusOK, gin.H{"id": id}, "Concession deleted")
}

func validateConcessionScope(schoolID, studentID, feeCategoryID, academicYearID string) error {
	if countRows(database.DB.Model(&models.Student{}).Where("id = ? AND school_id = ? AND status != ?", strings.TrimSpace(studentID), schoolID, "inactive")) == 0 {
		return fmt.Errorf("student does not belong to this school")
	}
	if countRows(database.DB.Model(&models.FeeCategory{}).Where("id = ? AND school_id = ?", strings.TrimSpace(feeCategoryID), schoolID)) == 0 {
		return fmt.Errorf("fee category does not belong to this school")
	}
	if !academicYearBelongsToSchool(academicYearID, schoolID) {
		return fmt.Errorf("academic year does not belong to this school")
	}
	return nil
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

// GetPaymentConfig returns the UPI payment configuration for the frontend.
func (h *FeeHandler) GetPaymentConfig(c *gin.Context) {
	if invoiceID := strings.TrimSpace(c.Query("invoice_id")); invoiceID != "" {
		setting := resolvePaymentSettingForInvoice(scopedSchoolID(c), invoiceID)
		c.JSON(http.StatusOK, models.APIResponse{
			Success: true,
			Data:    scopedPaymentSettingResponse(setting),
		})
		return
	}
	setting := paymentSettingForSchool(scopedSchoolID(c))
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data:    paymentSettingResponse(setting),
	})
}

func (h *FeeHandler) UpdatePaymentConfig(c *gin.Context) {
	var req struct {
		UPIID        string `json:"upi_id"`
		PayeeName    string `json:"payee_name"`
		MerchantCode string `json:"merchant_code"`
		QRNote       string `json:"qr_note"`
		QRImageURL   string `json:"qr_image_url"`
		UPIEnabled   *bool  `json:"upi_enabled"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	schoolID := scopedSchoolID(c)
	setting := paymentSettingForSchool(schoolID)
	setting.UPIID = strings.TrimSpace(req.UPIID)
	setting.PayeeName = strings.TrimSpace(req.PayeeName)
	setting.MerchantCode = strings.TrimSpace(req.MerchantCode)
	setting.QRNote = strings.TrimSpace(req.QRNote)
	if strings.TrimSpace(req.QRImageURL) != "" {
		setting.QRImageURL = strings.TrimSpace(req.QRImageURL)
	}
	if req.UPIEnabled != nil {
		setting.UPIEnabled = *req.UPIEnabled
	} else {
		setting.UPIEnabled = setting.UPIID != "" || setting.QRImageURL != ""
	}
	if userID := currentUserID(c); userID != "" {
		setting.UpdatedBy = &userID
	}
	if err := database.DB.Save(&setting).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update payment configuration")
		return
	}
	id := setting.ID
	auditAction(c, "fees", "update", "school_payment_settings", &id)
	success(c, http.StatusOK, paymentSettingResponse(setting), "Payment configuration updated")
}

func (h *FeeHandler) UploadPaymentQR(c *gin.Context) {
	file, err := c.FormFile("file")
	if err != nil {
		fail(c, http.StatusBadRequest, "No QR image provided (field: file)")
		return
	}
	ext := strings.ToLower(filepath.Ext(file.Filename))
	allowed := map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".webp": true}
	if !allowed[ext] {
		fail(c, http.StatusBadRequest, "Unsupported QR file type. Allowed: jpg, png, webp")
		return
	}
	schoolID := scopedSchoolID(c)
	dir := filepath.Join("uploads", "payment_qr", schoolID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to prepare QR storage")
		return
	}
	filename := fmt.Sprintf("fee_qr_%d%s", time.Now().UnixNano(), ext)
	dest := filepath.ToSlash(filepath.Join(dir, filename))
	if err := c.SaveUploadedFile(file, dest); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save QR image")
		return
	}
	url := "/" + dest
	setting := paymentSettingForSchool(schoolID)
	setting.QRImageURL = url
	setting.UPIEnabled = true
	if userID := currentUserID(c); userID != "" {
		setting.UpdatedBy = &userID
	}
	if err := database.DB.Save(&setting).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update payment QR")
		return
	}
	id := setting.ID
	auditAction(c, "fees", "upload_qr", "school_payment_settings", &id)
	success(c, http.StatusOK, paymentSettingResponse(setting), "Payment QR updated")
}

func (h *FeeHandler) GetScopedPaymentConfigs(c *gin.Context) {
	var rows []models.ScopedPaymentSetting
	if err := database.DB.
		Where("school_id = ?", scopedSchoolID(c)).
		Order("scope ASC, created_at DESC").
		Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load payment configurations")
		return
	}
	success(c, http.StatusOK, rows, "Payment configurations loaded")
}

func (h *FeeHandler) CreateScopedPaymentConfig(c *gin.Context) {
	config, ok := h.bindScopedPaymentConfig(c, models.ScopedPaymentSetting{SchoolID: scopedSchoolID(c)})
	if !ok {
		return
	}
	if err := database.DB.Create(&config).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create payment configuration")
		return
	}
	id := config.ID
	auditAction(c, "fees", "create_payment_config", "scoped_payment_settings", &id)
	success(c, http.StatusCreated, config, "Payment configuration created")
}

func (h *FeeHandler) UpdateScopedPaymentConfig(c *gin.Context) {
	var config models.ScopedPaymentSetting
	if err := database.DB.First(&config, "id = ? AND school_id = ?", c.Param("id"), scopedSchoolID(c)).Error; err != nil {
		fail(c, http.StatusNotFound, "Payment configuration not found")
		return
	}
	next, ok := h.bindScopedPaymentConfig(c, config)
	if !ok {
		return
	}
	if err := database.DB.Save(&next).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update payment configuration")
		return
	}
	id := next.ID
	auditAction(c, "fees", "update_payment_config", "scoped_payment_settings", &id)
	success(c, http.StatusOK, next, "Payment configuration updated")
}

func (h *FeeHandler) bindScopedPaymentConfig(c *gin.Context, config models.ScopedPaymentSetting) (models.ScopedPaymentSetting, bool) {
	var req struct {
		Scope        string `json:"scope"`
		GradeID      string `json:"grade_id"`
		SectionID    string `json:"section_id"`
		UPIID        string `json:"upi_id"`
		PayeeName    string `json:"payee_name"`
		MerchantCode string `json:"merchant_code"`
		QRNote       string `json:"qr_note"`
		QRImageURL   string `json:"qr_image_url"`
		UPIEnabled   *bool  `json:"upi_enabled"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return config, false
	}
	schoolID := scopedSchoolID(c)
	scope := strings.ToLower(strings.TrimSpace(req.Scope))
	if scope == "" {
		scope = "school"
	}
	config.Scope = scope
	config.GradeID = nil
	config.SectionID = nil
	if strings.TrimSpace(req.GradeID) != "" {
		if !gradeBelongsToSchool(req.GradeID, schoolID) {
			fail(c, http.StatusBadRequest, "grade does not belong to this school")
			return config, false
		}
		gradeID := strings.TrimSpace(req.GradeID)
		config.GradeID = &gradeID
	}
	if strings.TrimSpace(req.SectionID) != "" {
		if !sectionBelongsToSchool(req.SectionID, schoolID) {
			fail(c, http.StatusBadRequest, "section does not belong to this school")
			return config, false
		}
		sectionID := strings.TrimSpace(req.SectionID)
		config.SectionID = &sectionID
		config.Scope = "section"
	} else if config.GradeID != nil {
		config.Scope = "grade"
	}
	config.UPIID = strings.TrimSpace(req.UPIID)
	config.PayeeName = strings.TrimSpace(req.PayeeName)
	config.MerchantCode = strings.TrimSpace(req.MerchantCode)
	config.QRNote = strings.TrimSpace(req.QRNote)
	if strings.TrimSpace(req.QRImageURL) != "" {
		config.QRImageURL = strings.TrimSpace(req.QRImageURL)
	}
	if req.UPIEnabled != nil {
		config.UPIEnabled = *req.UPIEnabled
	} else {
		config.UPIEnabled = config.UPIID != "" || config.QRImageURL != ""
	}
	if userID := currentUserID(c); userID != "" {
		config.UpdatedBy = &userID
	}
	return config, true
}

func (h *FeeHandler) UploadScopedPaymentQR(c *gin.Context) {
	var config models.ScopedPaymentSetting
	if err := database.DB.First(&config, "id = ? AND school_id = ?", c.Param("id"), scopedSchoolID(c)).Error; err != nil {
		fail(c, http.StatusNotFound, "Payment configuration not found")
		return
	}
	file, err := c.FormFile("file")
	if err != nil {
		fail(c, http.StatusBadRequest, "No QR image provided (field: file)")
		return
	}
	ext := strings.ToLower(filepath.Ext(file.Filename))
	allowed := map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".webp": true}
	if !allowed[ext] {
		fail(c, http.StatusBadRequest, "Unsupported QR file type. Allowed: jpg, png, webp")
		return
	}
	dir := filepath.Join("uploads", "payment_qr", scopedSchoolID(c), config.ID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to prepare QR storage")
		return
	}
	dest := filepath.ToSlash(filepath.Join(dir, fmt.Sprintf("fee_qr_%d%s", time.Now().UnixNano(), ext)))
	if err := c.SaveUploadedFile(file, dest); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save QR image")
		return
	}
	config.QRImageURL = "/" + dest
	config.UPIEnabled = true
	if userID := currentUserID(c); userID != "" {
		config.UpdatedBy = &userID
	}
	if err := database.DB.Save(&config).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update payment QR")
		return
	}
	id := config.ID
	auditAction(c, "fees", "upload_scoped_qr", "scoped_payment_settings", &id)
	success(c, http.StatusOK, config, "Payment QR updated")
}

func paymentSettingForSchool(schoolID string) models.SchoolPaymentSetting {
	var setting models.SchoolPaymentSetting
	if !database.DB.Migrator().HasTable(&models.SchoolPaymentSetting{}) {
		return models.SchoolPaymentSetting{SchoolID: schoolID}
	}
	if err := database.DB.First(&setting, "school_id = ?", schoolID).Error; err == nil {
		return setting
	}
	upiID := strings.TrimSpace(os.Getenv("UPI_ID"))
	setting = models.SchoolPaymentSetting{
		SchoolID:     schoolID,
		UPIID:        upiID,
		PayeeName:    strings.TrimSpace(os.Getenv("UPI_PAYEE_NAME")),
		MerchantCode: strings.TrimSpace(os.Getenv("UPI_MERCHANT_CODE")),
		QRNote:       strings.TrimSpace(os.Getenv("UPI_QR_NOTE")),
		UPIEnabled:   upiID != "",
	}
	return setting
}

func paymentSettingResponse(setting models.SchoolPaymentSetting) gin.H {
	return gin.H{
		"upi_enabled":   setting.UPIEnabled && (strings.TrimSpace(setting.UPIID) != "" || strings.TrimSpace(setting.QRImageURL) != ""),
		"upi_id":        setting.UPIID,
		"payee_name":    setting.PayeeName,
		"merchant_code": setting.MerchantCode,
		"qr_note":       setting.QRNote,
		"qr_image_url":  setting.QRImageURL,
	}
}

func resolvePaymentSettingForInvoice(schoolID, invoiceID string) models.ScopedPaymentSetting {
	if !database.DB.Migrator().HasTable(&models.ScopedPaymentSetting{}) {
		return scopedFromSchoolPaymentSetting(paymentSettingForSchool(schoolID))
	}
	var invoice models.FeeInvoice
	if err := database.DB.
		Preload("Student").
		Preload("Student.CurrentSection").
		First(&invoice, "fee_invoices.id = ?", strings.TrimSpace(invoiceID)).Error; err != nil {
		return scopedFromSchoolPaymentSetting(paymentSettingForSchool(schoolID))
	}
	sectionID := ""
	gradeID := ""
	if invoice.Student != nil && invoice.Student.CurrentSectionID != nil {
		sectionID = *invoice.Student.CurrentSectionID
	}
	if invoice.Student != nil && invoice.Student.CurrentSection != nil {
		gradeID = invoice.Student.CurrentSection.GradeID
	}
	var setting models.ScopedPaymentSetting
	if sectionID != "" {
		err := database.DB.Where("school_id = ? AND section_id = ? AND upi_enabled = ?", schoolID, sectionID, true).First(&setting).Error
		if err == nil {
			return setting
		}
	}
	if gradeID != "" {
		err := database.DB.Where("school_id = ? AND grade_id = ? AND section_id IS NULL AND upi_enabled = ?", schoolID, gradeID, true).First(&setting).Error
		if err == nil {
			return setting
		}
	}
	err := database.DB.Where("school_id = ? AND scope = ? AND grade_id IS NULL AND section_id IS NULL AND upi_enabled = ?", schoolID, "school", true).First(&setting).Error
	if err == nil {
		return setting
	}
	return scopedFromSchoolPaymentSetting(paymentSettingForSchool(schoolID))
}

func scopedFromSchoolPaymentSetting(setting models.SchoolPaymentSetting) models.ScopedPaymentSetting {
	id := setting.ID
	if id == "" {
		id = "school-default"
	}
	return models.ScopedPaymentSetting{
		BaseModel:    models.BaseModel{ID: id},
		SchoolID:     setting.SchoolID,
		Scope:        "school",
		UPIID:        setting.UPIID,
		PayeeName:    setting.PayeeName,
		MerchantCode: setting.MerchantCode,
		QRNote:       setting.QRNote,
		QRImageURL:   setting.QRImageURL,
		UPIEnabled:   setting.UPIEnabled,
		UpdatedBy:    setting.UpdatedBy,
	}
}

func scopedPaymentSettingResponse(setting models.ScopedPaymentSetting) gin.H {
	return gin.H{
		"id":            setting.ID,
		"scope":         setting.Scope,
		"grade_id":      setting.GradeID,
		"section_id":    setting.SectionID,
		"upi_enabled":   setting.UPIEnabled && (strings.TrimSpace(setting.UPIID) != "" || strings.TrimSpace(setting.QRImageURL) != ""),
		"upi_id":        setting.UPIID,
		"payee_name":    setting.PayeeName,
		"merchant_code": setting.MerchantCode,
		"qr_note":       setting.QRNote,
		"qr_image_url":  setting.QRImageURL,
	}
}

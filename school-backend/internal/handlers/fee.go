package handlers

import (
	"fmt"
	"log"
	"math"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
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

const (
	parentPaymentStatusInitiated             = "initiated"
	parentPaymentStatusPaymentAppOpened      = "payment_app_opened"
	parentPaymentStatusProofPending          = "proof_pending"
	parentPaymentStatusSubmitted             = "submitted"
	parentPaymentStatusPending               = "pending"
	parentPaymentStatusPendingVerification   = "pending_verification"
	parentPaymentStatusClarificationRequired = "clarification_required"
	parentPaymentStatusApproved              = "approved"
	parentPaymentStatusRejected              = "rejected"
	parentPaymentStatusCancelled             = "cancelled"
	parentPaymentStatusExpired               = "expired"
)

var parentPaymentReservedStatuses = []string{
	parentPaymentStatusInitiated,
	parentPaymentStatusPaymentAppOpened,
	parentPaymentStatusProofPending,
	parentPaymentStatusSubmitted,
	parentPaymentStatusPending,
	parentPaymentStatusPendingVerification,
	parentPaymentStatusClarificationRequired,
}

func isParentPaymentReviewableStatus(status string) bool {
	status = strings.ToLower(strings.TrimSpace(status))
	return status == parentPaymentStatusPending || status == parentPaymentStatusPendingVerification
}

func isParentPaymentReservableStatus(status string) bool {
	status = strings.ToLower(strings.TrimSpace(status))
	for _, candidate := range parentPaymentReservedStatuses {
		if status == candidate {
			return true
		}
	}
	return false
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
	query.Order("priority ASC, created_at ASC").Find(&structures)

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
		FeeType:           normalizeFeeType(req.FeeType, req.BillingMode),
		BillingMode:       normalizeBillingMode(req.BillingMode, req.FeeType),
		Priority:          normalizeFeePriority(req.Priority, req.FeeType),
		IsActive:          true,
		DueDay:            req.DueDay,
		LateFinePerDay:    req.LateFinePerDay,
		InstallmentCount:  normalizeInstallmentCount(req.InstallmentCount),
		InstallmentMethod: normalizeInstallmentMethod(req.InstallmentMethod),
		EffectiveFrom:     effectiveFrom,
	}
	if req.IsActive != nil {
		structure.IsActive = *req.IsActive
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
	if err := database.DB.Preload("FeeCategory").Preload("Grade").Preload("Section").Preload("AcademicYear").Preload("Installments", func(db *gorm.DB) *gorm.DB {
		return db.Order("installment_number ASC")
	}).First(&structure, "id = ?", structure.ID).Error; err != nil {
		log.Printf("Failed to reload fee structure after creation: %v", err)
	}

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
		FeeType           string                         `json:"fee_type"`
		BillingMode       string                         `json:"billing_mode"`
		Priority          *int                           `json:"priority"`
		IsActive          *bool                          `json:"is_active"`
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
	if strings.TrimSpace(req.FeeType) != "" {
		updates["fee_type"] = normalizeFeeType(req.FeeType, req.BillingMode)
	}
	if strings.TrimSpace(req.BillingMode) != "" {
		updates["billing_mode"] = normalizeBillingMode(req.BillingMode, firstNonEmpty(req.FeeType, structure.FeeType))
	}
	if req.Priority != nil {
		updates["priority"] = normalizeFeePriority(*req.Priority, firstNonEmpty(req.FeeType, structure.FeeType))
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
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

func normalizeFeeType(value, billingMode string) string {
	text := strings.ToLower(strings.TrimSpace(value))
	text = strings.ReplaceAll(text, "-", "_")
	text = strings.ReplaceAll(text, " ", "_")
	switch {
	case strings.Contains(text, "book"), strings.Contains(text, "kit"):
		return "book_kit"
	case strings.Contains(text, "tuition"):
		return "tuition"
	}
	mode := normalizeBillingMode(billingMode, "")
	if mode == "one_time" {
		return "book_kit"
	}
	return "tuition"
}

func normalizeBillingMode(value, feeType string) string {
	text := strings.ToLower(strings.TrimSpace(value))
	text = strings.ReplaceAll(text, "-", "_")
	text = strings.ReplaceAll(text, " ", "_")
	if normalizeFeeTypeNoBilling(feeType) == "book_kit" {
		return "one_time"
	}
	switch {
	case strings.Contains(text, "one"):
		return "one_time"
	case strings.Contains(text, "month"):
		return "monthly"
	case strings.Contains(text, "term"):
		return "term_wise"
	default:
		return "term_wise"
	}
}

func normalizeFeePriority(value int, feeType string) int {
	if value > 0 {
		return value
	}
	if normalizeFeeTypeNoBilling(feeType) == "book_kit" {
		return 1
	}
	return 2
}

func normalizeFeeTypeNoBilling(value string) string {
	text := strings.ToLower(strings.TrimSpace(value))
	text = strings.ReplaceAll(text, "-", "_")
	text = strings.ReplaceAll(text, " ", "_")
	if strings.Contains(text, "book") || strings.Contains(text, "kit") || text == "book_kit" {
		return "book_kit"
	}
	return "tuition"
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
		var structure models.FeeStructure
		if err := tx.Where("id = ? AND school_id = ?", id, schoolID).First(&structure).Error; err != nil {
			return err
		}

		if err := tx.Where("fee_structure_id = ?", id).Delete(&models.FeeInstallment{}).Error; err != nil {
			return err
		}
		if err := tx.Delete(&structure).Error; err != nil {
			return err
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
	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("Failed to bind fee invoice sync request: %v", err)
	}
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
	enrichFeeInvoicesComputedFields(invoices)

	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, invoices))
}

func (h *FeeHandler) GetInvoiceDetail(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	if id == "" {
		fail(c, http.StatusBadRequest, "Invoice ID is required")
		return
	}

	var invoice models.FeeInvoice
	query := scopedFeeInvoiceQuery(c).Where("fee_invoices.id = ?", id)

	if err := preloadFeeInvoiceDetails(query).First(&invoice).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			fail(c, http.StatusNotFound, "Invoice not found")
		} else {
			fail(c, http.StatusInternalServerError, "Failed to fetch invoice details")
		}
		return
	}
	enrichFeeInvoiceComputedFields(&invoice)

	success(c, http.StatusOK, invoice, "")
}

func (h *FeeHandler) UpdateInvoice(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	if id == "" {
		fail(c, http.StatusBadRequest, "Invoice ID is required")
		return
	}

	var req struct {
		DueDate          *string  `json:"due_date"`
		TotalAmount      *float64 `json:"total_amount"`
		ConcessionAmount *float64 `json:"concession_amount"`
		FineAmount       *float64 `json:"fine_amount"`
		Status           *string  `json:"status"`
		Notes            *string  `json:"notes"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	var invoice models.FeeInvoice
	if err := database.DB.First(&invoice, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			fail(c, http.StatusNotFound, "Invoice not found")
		} else {
			fail(c, http.StatusInternalServerError, "Database error")
		}
		return
	}

	updates := map[string]interface{}{}
	if req.DueDate != nil {
		parsed, err := parseDate(*req.DueDate)
		if err != nil {
			fail(c, http.StatusBadRequest, "Invalid due_date format. Use YYYY-MM-DD")
			return
		}
		updates["due_date"] = parsed
	}
	if req.TotalAmount != nil {
		updates["total_amount"] = *req.TotalAmount
	}
	if req.ConcessionAmount != nil {
		updates["concession_amount"] = *req.ConcessionAmount
	}
	if req.FineAmount != nil {
		updates["fine_amount"] = *req.FineAmount
	}
	if req.Status != nil {
		updates["status"] = *req.Status
	}

	// Calculate PayableAmount/NetAmount and Balance
	total := invoice.TotalAmount
	if req.TotalAmount != nil {
		total = *req.TotalAmount
	}
	concession := invoice.ConcessionAmount
	if req.ConcessionAmount != nil {
		concession = *req.ConcessionAmount
	}
	fine := invoice.FineAmount
	if req.FineAmount != nil {
		fine = *req.FineAmount
	}
	payable := roundMoney(total - concession + fine)
	if payable < 0 {
		payable = 0
	}
	updates["payable_amount"] = payable
	updates["balance"] = roundMoney(payable - invoice.PaidAmount)

	if err := database.DB.Model(&invoice).Updates(updates).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update invoice")
		return
	}

	// Fetch updated invoice with details preloaded
	var updatedInvoice models.FeeInvoice
	if err := preloadFeeInvoiceDetails(database.DB.Model(&models.FeeInvoice{}).Where("id = ?", id)).First(&updatedInvoice).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load updated invoice details")
		return
	}
	enrichFeeInvoiceComputedFields(&updatedInvoice)

	success(c, http.StatusOK, updatedInvoice, "Invoice updated successfully")
}

func (h *FeeHandler) ApplyLateFineAdjustments(c *gin.Context) {
	today := time.Now().UTC()
	var invoices []models.FeeInvoice
	query := preloadFeeInvoiceDetails(scopedFeeInvoiceQuery(c)).
		Where("fee_invoices.due_date < ?", today).
		Where("fee_invoices.balance > 0").
		Where("fee_invoices.status NOT IN ?", []string{"paid", "cancelled"})
	if err := query.Find(&invoices).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load overdue invoices")
		return
	}
	enrichFeeInvoicesComputedFields(invoices)

	updated := make([]models.FeeInvoice, 0)
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		for i := range invoices {
			invoice := invoices[i]
			if invoice.LateFinePerDay <= 0 {
				continue
			}
			overdueDays := int(today.Sub(invoice.DueDate).Hours() / 24)
			if overdueDays <= 0 {
				continue
			}
			expectedFine := roundMoney(invoice.LateFinePerDay * float64(overdueDays))
			if math.Abs(expectedFine-invoice.FineAmount) < 0.5 && strings.ToLower(invoice.Status) == "overdue" {
				continue
			}
			payable := roundMoney(invoice.TotalAmount - invoice.DiscountAmount - invoice.ConcessionAmount + expectedFine)
			if payable < 0 {
				payable = 0
			}
			balance := roundMoney(payable - invoice.PaidAmount)
			status := "overdue"
			if balance <= 0 {
				balance = 0
				status = "paid"
			}
			if err := tx.Model(&models.FeeInvoice{}).Where("id = ?", invoice.ID).Updates(map[string]interface{}{
				"fine_amount":    expectedFine,
				"payable_amount": payable,
				"balance":        balance,
				"status":         status,
			}).Error; err != nil {
				return err
			}
			invoice.FineAmount = expectedFine
			invoice.PayableAmount = payable
			invoice.NetAmount = payable
			invoice.Balance = balance
			invoice.Status = status
			updated = append(updated, invoice)
		}
		return nil
	}); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to apply late fines")
		return
	}

	success(c, http.StatusOK, gin.H{"updated": len(updated), "invoices": updated}, "")
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

func enrichFeeInvoicesComputedFields(invoices []models.FeeInvoice) {
	for i := range invoices {
		enrichFeeInvoiceComputedFields(&invoices[i])
	}
}

func enrichFeeInvoiceComputedFields(invoice *models.FeeInvoice) {
	if invoice == nil {
		return
	}
	if invoice.Student == nil {
		var student models.Student
		if err := database.DB.Preload("CurrentSection").Preload("CurrentSection.Grade").First(&student, "id = ?", invoice.StudentID).Error; err == nil {
			invoice.Student = &student
		}
	}
	if len(invoice.Items) == 0 {
		var items []models.FeeInvoiceItem
		if err := database.DB.Preload("FeeCategory").Find(&items, "invoice_id = ?", invoice.ID).Error; err == nil {
			invoice.Items = items
		}
	}

	sectionID := ""
	gradeID := ""
	schoolID := ""
	if invoice.Student != nil {
		schoolID = invoice.Student.SchoolID
		if invoice.Student.CurrentSectionID != nil {
			sectionID = strings.TrimSpace(*invoice.Student.CurrentSectionID)
		}
		if invoice.Student.CurrentSection != nil {
			gradeID = strings.TrimSpace(invoice.Student.CurrentSection.GradeID)
		}
	}

	bestInstallmentNumber := 0
	bestInstallmentCount := 0
	bestLateFine := 0.0
	for _, item := range invoice.Items {
		structure, ok := matchingFeeStructureForInvoiceItem(invoice.AcademicYearID, schoolID, gradeID, sectionID, item.FeeCategoryID)
		if !ok {
			continue
		}
		if structure.InstallmentCount > bestInstallmentCount {
			bestInstallmentCount = structure.InstallmentCount
		}
		if structure.LateFinePerDay > bestLateFine {
			bestLateFine = structure.LateFinePerDay
		}
		if bestInstallmentNumber == 0 {
			bestInstallmentNumber = matchingInstallmentNumber(structure, item.Description, invoice.DueDate)
		}
	}
	invoice.InstallmentNumber = bestInstallmentNumber
	invoice.InstallmentCount = bestInstallmentCount
	invoice.TotalInstallments = bestInstallmentCount
	invoice.LateFinePerDay = bestLateFine
}

func matchingFeeStructureForInvoiceItem(academicYearID, schoolID, gradeID, sectionID, feeCategoryID string) (models.FeeStructure, bool) {
	var structures []models.FeeStructure
	query := database.DB.Preload("Installments", func(db *gorm.DB) *gorm.DB {
		return db.Order("installment_number ASC")
	}).Where("academic_year_id = ? AND fee_category_id = ?", academicYearID, feeCategoryID)
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	if gradeID != "" {
		query = query.Where("grade_id = ?", gradeID)
	}
	if sectionID != "" {
		query = query.Where("(section_id = ? OR section_id IS NULL OR section_id = '')", sectionID)
	}
	if err := query.Order("created_at DESC").Find(&structures).Error; err != nil || len(structures) == 0 {
		return models.FeeStructure{}, false
	}
	if sectionID != "" {
		for _, structure := range structures {
			if structure.SectionID != nil && *structure.SectionID == sectionID {
				return structure, true
			}
		}
	}
	return structures[0], true
}

func matchingInstallmentNumber(structure models.FeeStructure, description string, dueDate time.Time) int {
	description = strings.ToLower(strings.TrimSpace(description))
	for _, installment := range structure.Installments {
		if description != "" && strings.ToLower(strings.TrimSpace(installment.InstallmentName)) == description {
			return installment.InstallmentNumber
		}
	}
	for _, installment := range structure.Installments {
		if sameDate(installment.DueDate, dueDate) {
			return installment.InstallmentNumber
		}
	}
	return 0
}

func sameDate(a, b time.Time) bool {
	ay, am, ad := a.Date()
	by, bm, bd := b.Date()
	return ay == by && am == bm && ad == bd
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
	if err := database.DB.
		Preload("Student").
		Preload("Student.CurrentSection").
		Preload("Student.CurrentSection.Grade").
		Preload("AcademicYear").
		Preload("Items").
		Preload("Items.FeeCategory").
		First(&invoice, "id = ?", invoice.ID).Error; err != nil {
		log.Printf("Failed to reload invoice after creation: %v", err)
	}

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
		Where("is_active = ?", true).
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

func (h *FeeHandler) GenerateStudentFeesForStructure(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	structureID := strings.TrimSpace(c.Param("id"))
	var structure models.FeeStructure
	if err := database.DB.Preload("FeeCategory").Preload("AcademicYear").First(&structure, "id = ? AND school_id = ?", structureID, schoolID).Error; err != nil {
		fail(c, http.StatusNotFound, "Fee structure not found")
		return
	}
	if !structure.IsActive {
		fail(c, http.StatusBadRequest, "Fee structure is disabled")
		return
	}
	studentQuery := database.DB.Model(&models.Student{}).
		Joins("JOIN sections ON sections.id = students.current_section_id").
		Where("students.school_id = ? AND students.status != ? AND sections.grade_id = ?", schoolID, "inactive", structure.GradeID)
	if structure.SectionID != nil && strings.TrimSpace(*structure.SectionID) != "" {
		studentQuery = studentQuery.Where("students.current_section_id = ?", strings.TrimSpace(*structure.SectionID))
	}
	var students []models.Student
	if err := studentQuery.Order("students.first_name, students.last_name").Find(&students).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load students for fee generation")
		return
	}
	if len(students) == 0 {
		fail(c, http.StatusBadRequest, "No active students found for the selected fee structure")
		return
	}
	label := feeStructureDescription(structure)
	dueDate := feeStructureDueDate(structure)
	created := make([]models.FeeInvoice, 0, len(students))
	skipped := make([]gin.H, 0)
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		for _, student := range students {
			invoiceNumber := generatedInvoiceNumber(label, student)
			var existing models.FeeInvoice
			err := tx.First(&existing, "invoice_number = ?", invoiceNumber).Error
			if err == nil {
				skipped = append(skipped, gin.H{"student_id": student.ID, "invoice_id": existing.ID, "skip_reason": "student fee already exists"})
				continue
			}
			if err != gorm.ErrRecordNotFound {
				return err
			}
			amount := roundMoney(structure.Amount)
			invoice := models.FeeInvoice{
				StudentID:       student.ID,
				AcademicYearID:  structure.AcademicYearID,
				InvoiceNumber:   invoiceNumber,
				InvoiceDate:     time.Now().UTC(),
				DueDate:         dueDate,
				TotalAmount:     amount,
				PayableAmount:   amount,
				NetAmount:       amount,
				PaidAmount:      0,
				Balance:         amount,
				Status:          "pending",
				StudentParentID: nil,
			}
			if err := tx.Create(&invoice).Error; err != nil {
				return err
			}
			item := models.FeeInvoiceItem{
				InvoiceID:     invoice.ID,
				FeeCategoryID: structure.FeeCategoryID,
				Amount:        amount,
				Description:   label,
			}
			if err := tx.Create(&item).Error; err != nil {
				return err
			}
			created = append(created, invoice)
		}
		return nil
	}); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to generate student fees")
		return
	}
	auditAction(c, "fees", "generate_student_fees", "fee_structures", &structureID)
	success(c, http.StatusCreated, gin.H{
		"created":        len(created),
		"skipped":        len(skipped),
		"total_students": len(students),
		"invoices":       created,
		"skipped_rows":   skipped,
	}, "Student fees generated")
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
		if !structure.IsActive {
			continue
		}
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
		if !structure.IsActive {
			continue
		}
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
		status = strings.ToLower(status)
		if status == parentPaymentStatusPending {
			query = query.Where("parent_payment_requests.status IN ?", []string{parentPaymentStatusPending, parentPaymentStatusPendingVerification})
		} else {
			query = query.Where("parent_payment_requests.status = ?", status)
		}
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

func (h *FeeHandler) GetPendingFeePayments(c *gin.Context) {
	c.Request.URL.RawQuery = mergeQuery(c.Request.URL.RawQuery, "status=pending")
	h.GetPaymentRequests(c)
}

func (h *FeeHandler) GetFeesDashboard(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	classID := strings.TrimSpace(firstNonEmpty(c.Query("class_id"), c.Query("grade_id")))
	query := database.DB.Model(&models.FeeInvoice{}).
		Joins("JOIN students ON students.id = fee_invoices.student_id").
		Joins("JOIN sections ON sections.id = students.current_section_id").
		Where("students.school_id = ? AND students.status != ?", schoolID, "inactive")
	if classID != "" {
		query = query.Where("sections.grade_id = ?", classID)
	}
	var rows []models.FeeInvoice
	if err := query.Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load fees dashboard")
		return
	}
	totalExpected := 0.0
	totalCollected := 0.0
	pendingAmount := 0.0
	paidStudents := map[string]bool{}
	pendingStudents := map[string]bool{}
	overdueStudents := map[string]bool{}
	now := time.Now().UTC()
	for _, row := range rows {
		totalExpected += row.PayableAmount
		if row.PayableAmount == 0 {
			totalExpected += row.TotalAmount
		}
		totalCollected += row.PaidAmount
		pendingAmount += row.Balance
		if row.Balance <= 0 || strings.EqualFold(row.Status, "paid") {
			paidStudents[row.StudentID] = true
		} else {
			pendingStudents[row.StudentID] = true
			if row.DueDate.Before(now) || strings.EqualFold(row.Status, "overdue") {
				overdueStudents[row.StudentID] = true
			}
		}
	}
	pendingQuery := database.DB.Model(&models.ParentPaymentRequest{}).
		Joins("JOIN students ON students.id = parent_payment_requests.student_id").
		Joins("JOIN sections ON sections.id = students.current_section_id").
		Where("parent_payment_requests.school_id = ? AND parent_payment_requests.status IN ?", schoolID, []string{parentPaymentStatusPending, parentPaymentStatusPendingVerification})
	if classID != "" {
		pendingQuery = pendingQuery.Where("sections.grade_id = ?", classID)
	}
	var pendingApprovalCount int64
	if err := pendingQuery.Count(&pendingApprovalCount).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load pending payment approvals")
		return
	}
	success(c, http.StatusOK, gin.H{
		"total_expected_amount":          roundMoney(totalExpected),
		"total_collected_amount":         roundMoney(totalCollected),
		"pending_amount":                 roundMoney(pendingAmount),
		"paid_students_count":            len(paidStudents),
		"pending_students_count":         len(pendingStudents),
		"overdue_students_count":         len(overdueStudents),
		"pending_payment_approval_count": pendingApprovalCount,
	}, "Fees dashboard loaded")
}

func (h *FeeHandler) CreateFeePaymentIntent(c *gin.Context) {
	var req struct {
		InvoiceID      string `json:"invoice_id"`
		StudentFeeID   string `json:"student_fee_id"`
		PaymentMethod  string `json:"payment_method"`
		PaymentMode    string `json:"payment_mode"`
		SelectedMonths int    `json:"selected_months"`
		SelectedTerms  int    `json:"selected_terms"`
		Remarks        string `json:"remarks"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	invoiceID := strings.TrimSpace(firstNonEmpty(req.InvoiceID, req.StudentFeeID))
	if invoiceID == "" {
		fail(c, http.StatusBadRequest, "invoice_id is required")
		return
	}
	paymentMode := strings.ToLower(strings.TrimSpace(firstNonEmpty(req.PaymentMethod, req.PaymentMode)))
	if paymentMode == "" {
		paymentMode = "upi"
	}

	var invoice models.FeeInvoice
	if err := preloadFeeInvoiceDetails(scopedFeeInvoiceQuery(c)).First(&invoice, "fee_invoices.id = ?", invoiceID).Error; err != nil {
		fail(c, http.StatusNotFound, "Invoice not found")
		return
	}
	if err := ensureParentOwnsStudent(c, invoice.StudentID); err != nil {
		fail(c, http.StatusForbidden, "Invoice does not belong to a linked child")
		return
	}
	expectedAmount, err := expectedParentPayableAmount(invoice, req.SelectedMonths, req.SelectedTerms)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	pendingAmount, err := pendingParentPaymentAmountExcept(invoice.ID, "")
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to verify pending payment requests")
		return
	}
	if expectedAmount > roundMoney(invoice.Balance-pendingAmount) {
		fail(c, http.StatusBadRequest, "payment request amount exceeds outstanding balance after pending requests")
		return
	}

	paymentSetting := resolvePaymentSettingForInvoice(scopedSchoolID(c), invoice.ID)
	if paymentMode == "upi" && !paymentSetting.UPIEnabled && strings.TrimSpace(paymentSetting.UPIID) == "" && strings.TrimSpace(paymentSetting.QRImageURL) == "" {
		fail(c, http.StatusBadRequest, "UPI payment is not configured")
		return
	}
	paymentConfigID := (*string)(nil)
	if strings.TrimSpace(paymentSetting.ID) != "" {
		value := paymentSetting.ID
		paymentConfigID = &value
	}
	reference := generateFeePaymentReference(invoice.Student)
	now := time.Now().UTC()
	request := models.ParentPaymentRequest{
		SchoolID:          scopedSchoolID(c),
		InvoiceID:         invoice.ID,
		StudentID:         invoice.StudentID,
		ParentUserID:      currentUserID(c),
		RequestReference:  reference,
		Amount:            expectedAmount,
		PaymentDate:       now,
		PaymentMode:       paymentMode,
		Status:            parentPaymentStatusInitiated,
		Remarks:           strings.TrimSpace(req.Remarks),
		SelectedMonths:    req.SelectedMonths,
		SelectedTerms:     req.SelectedTerms,
		PaymentConfigID:   paymentConfigID,
		PaymentUPIID:      paymentSetting.UPIID,
		PaymentPayeeName:  paymentSetting.PayeeName,
		PaymentQRImageURL: paymentSetting.QRImageURL,
		PaymentQRNote:     paymentSetting.QRNote,
	}
	if err := database.DB.Create(&request).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create payment intent")
		return
	}
	id := request.ID
	auditAction(c, "fees", "create_payment_intent", "parent_payment_requests", &id)
	if err := preloadPaymentRequestDetails(database.DB).First(&request, "id = ?", request.ID).Error; err != nil {
		success(c, http.StatusCreated, parentPaymentRequestPayload(request), "Payment intent created")
		return
	}
	success(c, http.StatusCreated, parentPaymentRequestPayload(request), "Payment intent created")
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

func (h *FeeHandler) SubmitFeePayment(c *gin.Context) {
	invoiceID := strings.TrimSpace(firstNonEmpty(c.PostForm("student_fee_id"), c.PostForm("invoice_id")))
	amount, err := parseRequiredMoney(c.PostForm("amount"), "amount")
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	paymentMethod := strings.ToLower(strings.TrimSpace(firstNonEmpty(c.PostForm("payment_method"), c.PostForm("payment_mode"))))
	if paymentMethod == "" {
		paymentMethod = "upi"
	}
	transactionRef := strings.TrimSpace(firstNonEmpty(c.PostForm("transaction_ref"), c.PostForm("transaction_id")))
	if paymentMethod != "cash" && len(transactionRef) < 6 {
		fail(c, http.StatusBadRequest, "transaction_ref is required")
		return
	}
	selectedMonths := parsePositiveInt(c.PostForm("selected_months"))
	selectedTerms := parsePositiveInt(c.PostForm("selected_terms"))
	requestID := strings.TrimSpace(firstNonEmpty(c.PostForm("payment_request_id"), c.PostForm("request_id")))
	requestReference := strings.TrimSpace(c.PostForm("request_reference"))

	var existing models.ParentPaymentRequest
	hasExistingRequest := false
	if requestID != "" || requestReference != "" {
		query := database.DB.Where("school_id = ? AND parent_user_id = ?", scopedSchoolID(c), currentUserID(c))
		if requestID != "" {
			query = query.Where("id = ?", requestID)
		} else {
			query = query.Where("request_reference = ?", requestReference)
		}
		if err := query.First(&existing).Error; err != nil {
			fail(c, http.StatusNotFound, "Payment intent not found")
			return
		}
		hasExistingRequest = true
		invoiceID = existing.InvoiceID
		if selectedMonths == 0 {
			selectedMonths = existing.SelectedMonths
		}
		if selectedTerms == 0 {
			selectedTerms = existing.SelectedTerms
		}
	}
	if invoiceID == "" {
		fail(c, http.StatusBadRequest, "student_fee_id is required")
		return
	}
	var invoice models.FeeInvoice
	if err := preloadFeeInvoiceDetails(scopedFeeInvoiceQuery(c)).First(&invoice, "fee_invoices.id = ?", invoiceID).Error; err != nil {
		fail(c, http.StatusNotFound, "Invoice not found")
		return
	}
	if err := ensureParentOwnsStudent(c, invoice.StudentID); err != nil {
		fail(c, http.StatusForbidden, "Invoice does not belong to a linked child")
		return
	}
	expectedAmount, err := expectedParentPayableAmount(invoice, selectedMonths, selectedTerms)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	if roundMoney(amount) != expectedAmount {
		fail(c, http.StatusBadRequest, fmt.Sprintf("payment amount must be %.2f for selected fee interval", expectedAmount))
		return
	}
	excludeID := ""
	if hasExistingRequest {
		excludeID = existing.ID
		if !isParentPaymentReservableStatus(existing.Status) {
			fail(c, http.StatusBadRequest, "Payment request cannot be updated in its current status")
			return
		}
		if roundMoney(existing.Amount) != expectedAmount {
			fail(c, http.StatusBadRequest, "payment amount does not match the existing payment intent")
			return
		}
	}
	if err := ensureUniqueTransactionRef(scopedSchoolID(c), transactionRef, excludeID); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	pendingAmount, err := pendingParentPaymentAmountExcept(invoice.ID, excludeID)
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to verify pending payment requests")
		return
	}
	if amount > roundMoney(invoice.Balance-pendingAmount) {
		fail(c, http.StatusBadRequest, "payment request amount exceeds outstanding balance after pending requests")
		return
	}
	proofURL, err := h.savePaymentProof(c)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	paymentSetting := resolvePaymentSettingForInvoice(scopedSchoolID(c), invoice.ID)
	paymentConfigID := (*string)(nil)
	if strings.TrimSpace(paymentSetting.ID) != "" {
		value := paymentSetting.ID
		paymentConfigID = &value
	}
	now := time.Now().UTC()
	if hasExistingRequest {
		existing.Amount = amount
		existing.PaymentDate = now
		existing.PaymentMode = paymentMethod
		existing.TransactionID = transactionRef
		existing.ProofURL = &proofURL
		existing.Status = parentPaymentStatusPendingVerification
		existing.Remarks = strings.TrimSpace(c.PostForm("remarks"))
		existing.SelectedMonths = selectedMonths
		existing.SelectedTerms = selectedTerms
		existing.PaymentConfigID = paymentConfigID
		existing.PaymentUPIID = paymentSetting.UPIID
		existing.PaymentPayeeName = paymentSetting.PayeeName
		existing.PaymentQRImageURL = paymentSetting.QRImageURL
		existing.PaymentQRNote = paymentSetting.QRNote
		existing.DecidedBy = nil
		existing.DecidedAt = nil
		if err := database.DB.Save(&existing).Error; err != nil {
			fail(c, http.StatusInternalServerError, "Failed to update payment request")
			return
		}
		id := existing.ID
		auditAction(c, "fees", "submit_payment_proof", "parent_payment_requests", &id)
		if err := preloadPaymentRequestDetails(database.DB).First(&existing, "id = ?", existing.ID).Error; err != nil {
			success(c, http.StatusCreated, existing, "Payment proof submitted for approval")
			return
		}
		success(c, http.StatusCreated, existing, "Payment proof submitted for approval")
		return
	}
	request := models.ParentPaymentRequest{
		SchoolID:          scopedSchoolID(c),
		InvoiceID:         invoice.ID,
		StudentID:         invoice.StudentID,
		ParentUserID:      currentUserID(c),
		RequestReference:  generateParentPaymentReference(),
		Amount:            amount,
		PaymentDate:       now,
		PaymentMode:       paymentMethod,
		TransactionID:     transactionRef,
		ProofURL:          &proofURL,
		Status:            parentPaymentStatusPendingVerification,
		Remarks:           strings.TrimSpace(c.PostForm("remarks")),
		SelectedMonths:    selectedMonths,
		SelectedTerms:     selectedTerms,
		PaymentConfigID:   paymentConfigID,
		PaymentUPIID:      paymentSetting.UPIID,
		PaymentPayeeName:  paymentSetting.PayeeName,
		PaymentQRImageURL: paymentSetting.QRImageURL,
		PaymentQRNote:     paymentSetting.QRNote,
	}
	if err := database.DB.Create(&request).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create payment request")
		return
	}
	id := request.ID
	auditAction(c, "fees", "submit_payment_proof", "parent_payment_requests", &id)
	if err := preloadPaymentRequestDetails(database.DB).First(&request, "id = ?", request.ID).Error; err != nil {
		success(c, http.StatusCreated, request, "Payment proof submitted for approval")
		return
	}
	success(c, http.StatusCreated, request, "Payment proof submitted for approval")
}

func (h *FeeHandler) ResubmitFeePayment(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	if id == "" {
		fail(c, http.StatusBadRequest, "payment request ID is required")
		return
	}
	var paymentRequest models.ParentPaymentRequest
	if err := database.DB.First(&paymentRequest, "id = ? AND school_id = ? AND parent_user_id = ?", id, scopedSchoolID(c), currentUserID(c)).Error; err != nil {
		fail(c, http.StatusNotFound, "Payment request not found")
		return
	}
	if paymentRequest.Status != parentPaymentStatusClarificationRequired {
		fail(c, http.StatusBadRequest, "Payment request is not waiting for clarification")
		return
	}
	transactionRef := strings.TrimSpace(firstNonEmpty(c.PostForm("transaction_ref"), c.PostForm("transaction_id"), paymentRequest.TransactionID))
	if paymentRequest.PaymentMode != "cash" && len(transactionRef) < 6 {
		fail(c, http.StatusBadRequest, "transaction_ref is required")
		return
	}
	if err := ensureUniqueTransactionRef(scopedSchoolID(c), transactionRef, paymentRequest.ID); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	proofURL, err := h.savePaymentProof(c)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	paymentRequest.TransactionID = transactionRef
	paymentRequest.ProofURL = &proofURL
	paymentRequest.Status = parentPaymentStatusPendingVerification
	paymentRequest.Remarks = strings.TrimSpace(firstNonEmpty(c.PostForm("remarks"), paymentRequest.Remarks))
	paymentRequest.DecidedBy = nil
	paymentRequest.DecidedAt = nil
	if err := database.DB.Save(&paymentRequest).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to resubmit payment proof")
		return
	}
	auditAction(c, "fees", "resubmit_payment_proof", "parent_payment_requests", &id)
	if err := preloadPaymentRequestDetails(database.DB).First(&paymentRequest, "id = ?", paymentRequest.ID).Error; err != nil {
		success(c, http.StatusOK, paymentRequest, "Payment proof resubmitted for approval")
		return
	}
	success(c, http.StatusOK, paymentRequest, "Payment proof resubmitted for approval")
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
	if status != parentPaymentStatusApproved && status != parentPaymentStatusRejected && status != parentPaymentStatusClarificationRequired {
		fail(c, http.StatusBadRequest, "status must be approved, rejected, or clarification_required")
		return
	}
	if (status == parentPaymentStatusRejected || status == parentPaymentStatusClarificationRequired) && strings.TrimSpace(req.AdminRemarks) == "" {
		fail(c, http.StatusBadRequest, "admin_remarks is required")
		return
	}
	var paymentRequest models.ParentPaymentRequest
	if err := database.DB.First(&paymentRequest, "id = ? AND school_id = ?", c.Param("id"), scopedSchoolID(c)).Error; err != nil {
		fail(c, http.StatusNotFound, "Payment request not found")
		return
	}
	if !isParentPaymentReviewableStatus(paymentRequest.Status) {
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

func (h *FeeHandler) ApproveFeePayment(c *gin.Context) {
	h.decideFeePaymentAlias(c, "approved")
}

func (h *FeeHandler) RejectFeePayment(c *gin.Context) {
	h.decideFeePaymentAlias(c, "rejected")
}

func (h *FeeHandler) decideFeePaymentAlias(c *gin.Context, status string) {
	var req struct {
		RejectionReason string `json:"rejection_reason"`
		AdminRemarks    string `json:"admin_remarks"`
	}
	_ = c.ShouldBindJSON(&req)
	remarks := strings.TrimSpace(firstNonEmpty(req.AdminRemarks, req.RejectionReason))
	if status == parentPaymentStatusRejected && remarks == "" {
		fail(c, http.StatusBadRequest, "rejection_reason is required")
		return
	}
	id := strings.TrimSpace(c.Param("id"))
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		_, err := applyParentPaymentRequestDecisionTx(tx, scopedSchoolID(c), currentUserID(c), id, status, remarks)
		return err
	}); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	var paymentRequest models.ParentPaymentRequest
	if err := preloadPaymentRequestDetails(database.DB).First(&paymentRequest, "id = ?", id).Error; err != nil {
		success(c, http.StatusOK, gin.H{"id": id, "status": status}, "Payment request updated")
		return
	}
	auditAction(c, "fees", status+"_payment_request", "parent_payment_requests", &id)
	success(c, http.StatusOK, paymentRequest, "Payment request updated")
}

func applyParentPaymentRequestDecisionTx(tx *gorm.DB, schoolID, decider, requestID, status, remarks string) (models.ParentPaymentRequest, error) {
	status = strings.ToLower(strings.TrimSpace(status))
	if status != parentPaymentStatusApproved && status != parentPaymentStatusRejected && status != parentPaymentStatusClarificationRequired {
		return models.ParentPaymentRequest{}, fmt.Errorf("status must be approved, rejected, or clarification_required")
	}
	var paymentRequest models.ParentPaymentRequest
	if err := tx.First(&paymentRequest, "id = ? AND school_id = ?", requestID, schoolID).Error; err != nil {
		return models.ParentPaymentRequest{}, fmt.Errorf("payment request not found")
	}
	if !isParentPaymentReviewableStatus(paymentRequest.Status) {
		return models.ParentPaymentRequest{}, fmt.Errorf("Payment request has already been actioned")
	}
	now := time.Now().UTC()
	paymentRequest.Status = status
	paymentRequest.AdminRemarks = strings.TrimSpace(remarks)
	paymentRequest.DecidedBy = &decider
	paymentRequest.DecidedAt = &now
	if status == parentPaymentStatusRejected || status == parentPaymentStatusClarificationRequired {
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
	receiptID, err := createApprovedParentPaymentArtifactsTx(tx, paymentRequest, payment, now)
	if err != nil {
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
	if receiptID != "" {
		paymentRequest.ReceiptID = &receiptID
	}
	if err := tx.Save(&paymentRequest).Error; err != nil {
		return models.ParentPaymentRequest{}, err
	}
	return paymentRequest, nil
}

func createApprovedParentPaymentArtifactsTx(tx *gorm.DB, paymentRequest models.ParentPaymentRequest, payment models.Payment, approvedAt time.Time) (string, error) {
	if !tx.Migrator().HasTable(&models.PaymentOrder{}) ||
		!tx.Migrator().HasTable(&models.PaymentTransaction{}) ||
		!tx.Migrator().HasTable(&models.FeeReceipt{}) ||
		!tx.Migrator().HasTable(&models.PaymentOrderInvoiceMap{}) {
		return "", nil
	}
	order := models.PaymentOrder{
		ParentID:        paymentRequest.ParentUserID,
		StudentID:       paymentRequest.StudentID,
		Amount:          paymentRequest.Amount,
		Currency:        "INR",
		Gateway:         paymentRequest.PaymentMode,
		ExternalOrderID: paymentRequest.RequestReference,
		ReceiptNo:       paymentRequest.RequestReference,
		Status:          "paid",
		CreatedAt:       approvedAt,
		UpdatedAt:       approvedAt,
	}
	if err := order.SetInvoiceIDs([]string{paymentRequest.InvoiceID}); err != nil {
		return "", err
	}
	if err := order.SetNotes(map[string]interface{}{
		"parent_payment_request_id": paymentRequest.ID,
		"legacy_payment_id":         payment.ID,
		"transaction_id":            paymentRequest.TransactionID,
		"selected_months":           paymentRequest.SelectedMonths,
		"selected_terms":            paymentRequest.SelectedTerms,
	}); err != nil {
		return "", err
	}
	if err := tx.Create(&order).Error; err != nil {
		return "", err
	}
	allocation := models.PaymentOrderInvoiceMap{
		PaymentOrderID:  order.ID,
		FeeInvoiceID:    paymentRequest.InvoiceID,
		AmountAllocated: paymentRequest.Amount,
		CreatedAt:       approvedAt,
	}
	if err := tx.Create(&allocation).Error; err != nil {
		return "", err
	}
	method := paymentRequest.PaymentMode
	transaction := models.PaymentTransaction{
		PaymentOrderID:    order.ID,
		ParentID:          paymentRequest.ParentUserID,
		StudentID:         paymentRequest.StudentID,
		ExternalOrderID:   paymentRequest.RequestReference,
		ExternalPaymentID: paymentRequest.TransactionID,
		Amount:            paymentRequest.Amount,
		Currency:          "INR",
		PaymentMethod:     &method,
		Status:            "success",
		VerifiedAt:        &approvedAt,
		CreatedAt:         approvedAt,
		UpdatedAt:         approvedAt,
	}
	if err := transaction.SetGatewayResponse(map[string]interface{}{
		"source":                    "principal_verification",
		"parent_payment_request_id": paymentRequest.ID,
		"proof_url":                 paymentRequest.ProofURL,
	}); err != nil {
		return "", err
	}
	if err := tx.Create(&transaction).Error; err != nil {
		return "", err
	}
	receipt := models.FeeReceipt{
		ReceiptNo:            paymentRequest.RequestReference,
		StudentID:            paymentRequest.StudentID,
		ParentID:             paymentRequest.ParentUserID,
		PaymentTransactionID: transaction.ID,
		Amount:               paymentRequest.Amount,
		PaymentMode:          paymentRequest.PaymentMode,
		PaidAt:               approvedAt,
		CreatedAt:            approvedAt,
		UpdatedAt:            approvedAt,
	}
	if err := tx.Create(&receipt).Error; err != nil {
		return "", err
	}
	return receipt.ID, nil
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

func (h *FeeHandler) GetParentStudentFees(c *gin.Context) {
	studentID := strings.TrimSpace(c.Param("studentId"))
	if studentID == "" {
		fail(c, http.StatusBadRequest, "student id is required")
		return
	}
	if err := database.DB.Where("school_id = ? AND parent_user_id = ? AND student_id = ?", scopedSchoolID(c), currentUserID(c), studentID).First(&models.ParentStudentLink{}).Error; err != nil {
		fail(c, http.StatusForbidden, "Student is not linked to this parent")
		return
	}
	var invoices []models.FeeInvoice
	if err := preloadFeeInvoiceDetails(scopedFeeInvoiceQuery(c)).
		Where("fee_invoices.student_id = ?", studentID).
		Order("fee_invoices.due_date ASC").
		Find(&invoices).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load student fees")
		return
	}
	enrichFeeInvoicesComputedFields(invoices)
	rows := make([]gin.H, 0, len(invoices))
	for _, invoice := range invoices {
		rows = append(rows, parentFeeRow(invoice))
	}
	success(c, http.StatusOK, rows, "Student fees loaded")
}

func (h *FeeHandler) GetFeePaymentHistory(c *gin.Context) {
	studentID := strings.TrimSpace(c.Query("student_id"))
	query := scopedPaymentRequestQuery(c)
	if studentID != "" {
		query = query.Where("parent_payment_requests.student_id = ?", studentID)
	}
	var rows []models.ParentPaymentRequest
	if err := preloadPaymentRequestDetails(query).Order("parent_payment_requests.created_at DESC").Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load payment history")
		return
	}
	success(c, http.StatusOK, rows, "Payment history loaded")
}

func parentFeeRow(invoice models.FeeInvoice) gin.H {
	meta := invoiceFeeMetadata(invoice)
	status := invoice.Status
	if invoice.Balance > 0 && invoice.DueDate.Before(time.Now().UTC()) && !strings.EqualFold(status, "paid") {
		status = "overdue"
	}
	var latestRequest models.ParentPaymentRequest
	requestStatus := ""
	rejectionReason := ""
	if err := database.DB.
		Where("invoice_id = ?", invoice.ID).
		Order("created_at DESC").
		First(&latestRequest).Error; err == nil {
		if isParentPaymentReservableStatus(latestRequest.Status) {
			requestStatus = latestRequest.Status
			status = "payment_pending"
			if latestRequest.Status == parentPaymentStatusClarificationRequired {
				status = parentPaymentStatusClarificationRequired
				rejectionReason = latestRequest.AdminRemarks
			}
		}
		if latestRequest.Status == parentPaymentStatusRejected {
			requestStatus = "rejected"
			status = "rejected"
			rejectionReason = latestRequest.AdminRemarks
		}
	}
	row := gin.H{
		"id":               invoice.ID,
		"student_fee_id":   invoice.ID,
		"invoice_number":   invoice.InvoiceNumber,
		"fee_item_name":    meta.name,
		"fee_type":         meta.feeType,
		"billing_mode":     meta.billingMode,
		"priority":         meta.priority,
		"total_amount":     roundMoney(invoice.PayableAmount),
		"paid_amount":      roundMoney(invoice.PaidAmount),
		"balance_amount":   roundMoney(invoice.Balance),
		"balance":          roundMoney(invoice.Balance),
		"due_date":         invoice.DueDate,
		"status":           status,
		"request_status":   requestStatus,
		"rejection_reason": rejectionReason,
	}
	if meta.feeType == "tuition" && invoice.Balance > 0 {
		baseAmount := invoiceIntervalBaseAmount(invoice)
		row["monthly_amount"] = roundMoney(baseAmount / 12)
		termCount, err := academicTermCount(invoice.AcademicYearID)
		if err == nil && termCount > 0 {
			row["term_count"] = termCount
			row["term_amount"] = roundMoney(baseAmount / float64(termCount))
		}
	}
	return row
}

type feeInvoiceMetadata struct {
	name        string
	feeType     string
	billingMode string
	priority    int
}

func invoiceFeeMetadata(invoice models.FeeInvoice) feeInvoiceMetadata {
	meta := feeInvoiceMetadata{name: "Fee", feeType: "tuition", billingMode: "term_wise", priority: 2}
	if len(invoice.Items) > 0 {
		item := invoice.Items[0]
		if strings.TrimSpace(item.Description) != "" {
			meta.name = strings.TrimSpace(item.Description)
		}
		if item.FeeCategory != nil && strings.TrimSpace(item.FeeCategory.CategoryName) != "" {
			meta.name = strings.TrimSpace(item.FeeCategory.CategoryName)
		}
		gradeID := ""
		sectionID := ""
		schoolID := ""
		if invoice.Student != nil {
			schoolID = invoice.Student.SchoolID
			if invoice.Student.CurrentSectionID != nil {
				sectionID = *invoice.Student.CurrentSectionID
			}
			if invoice.Student.CurrentSection != nil {
				gradeID = invoice.Student.CurrentSection.GradeID
			}
		}
		if structure, ok := matchingFeeStructureForInvoiceItem(invoice.AcademicYearID, schoolID, gradeID, sectionID, item.FeeCategoryID); ok {
			meta.feeType = normalizeFeeType(firstNonEmpty(structure.FeeType, meta.name), structure.BillingMode)
			meta.billingMode = normalizeBillingMode(firstNonEmpty(structure.BillingMode, normalizedFeeFrequency(structure)), meta.feeType)
			meta.priority = normalizeFeePriority(structure.Priority, meta.feeType)
		} else {
			meta.feeType = normalizeFeeType(meta.name, "")
			meta.billingMode = normalizeBillingMode("", meta.feeType)
			meta.priority = normalizeFeePriority(0, meta.feeType)
		}
	}
	return meta
}

func expectedParentPayableAmount(invoice models.FeeInvoice, selectedMonths, selectedTerms int) (float64, error) {
	if invoice.Balance <= 0 {
		return 0, fmt.Errorf("invoice has no outstanding balance")
	}
	meta := invoiceFeeMetadata(invoice)
	if meta.feeType == "book_kit" {
		if selectedMonths > 0 || selectedTerms > 0 {
			return 0, fmt.Errorf("Book & Kit Fee is one-time only and cannot be split")
		}
		return roundMoney(invoice.Balance), nil
	}
	if selectedMonths > 0 && selectedTerms > 0 {
		return 0, fmt.Errorf("select either months or terms, not both")
	}
	if selectedMonths > 0 {
		if selectedMonths > 12 {
			return 0, fmt.Errorf("selected_months cannot exceed 12")
		}
		return roundMoney((invoiceIntervalBaseAmount(invoice) / 12) * float64(selectedMonths)), nil
	}
	if selectedTerms > 0 {
		termCount, err := academicTermCount(invoice.AcademicYearID)
		if err != nil || termCount <= 0 {
			return 0, fmt.Errorf("academic terms are not configured for term-wise tuition payments")
		}
		if selectedTerms > termCount {
			return 0, fmt.Errorf("selected_terms cannot exceed configured academic terms")
		}
		return roundMoney((invoiceIntervalBaseAmount(invoice) / float64(termCount)) * float64(selectedTerms)), nil
	}
	return roundMoney(invoice.Balance), nil
}

func invoiceIntervalBaseAmount(invoice models.FeeInvoice) float64 {
	if invoice.PayableAmount > 0 {
		return invoice.PayableAmount
	}
	if invoice.TotalAmount > 0 {
		return invoice.TotalAmount
	}
	return invoice.Balance + invoice.PaidAmount
}

func academicTermCount(academicYearID string) (int, error) {
	var count int64
	if err := database.DB.Model(&models.Term{}).Where("academic_year_id = ?", academicYearID).Count(&count).Error; err != nil {
		return 0, err
	}
	return int(count), nil
}

func ensureParentOwnsStudent(c *gin.Context, studentID string) error {
	var parentLink models.ParentStudentLink
	return database.DB.Where("school_id = ? AND parent_user_id = ? AND student_id = ?", scopedSchoolID(c), currentUserID(c), studentID).First(&parentLink).Error
}

func parentPaymentRequestPayload(request models.ParentPaymentRequest) gin.H {
	payload := gin.H{
		"id":                   request.ID,
		"school_id":            request.SchoolID,
		"invoice_id":           request.InvoiceID,
		"student_id":           request.StudentID,
		"parent_user_id":       request.ParentUserID,
		"payment_id":           request.PaymentID,
		"receipt_id":           request.ReceiptID,
		"request_reference":    request.RequestReference,
		"payment_reference":    request.RequestReference,
		"amount":               roundMoney(request.Amount),
		"payment_date":         request.PaymentDate,
		"payment_mode":         request.PaymentMode,
		"transaction_id":       request.TransactionID,
		"proof_url":            request.ProofURL,
		"selected_months":      request.SelectedMonths,
		"selected_terms":       request.SelectedTerms,
		"status":               request.Status,
		"remarks":              request.Remarks,
		"admin_remarks":        request.AdminRemarks,
		"payment_config_id":    request.PaymentConfigID,
		"payment_upi_id":       request.PaymentUPIID,
		"payment_payee_name":   request.PaymentPayeeName,
		"payment_qr_image_url": request.PaymentQRImageURL,
		"payment_qr_note":      request.PaymentQRNote,
		"decided_by":           request.DecidedBy,
		"decided_at":           request.DecidedAt,
		"created_at":           request.CreatedAt,
		"updated_at":           request.UpdatedAt,
		"upi_uri":              buildParentPaymentUPIURI(request),
	}
	if request.Invoice != nil {
		payload["invoice"] = request.Invoice
	}
	if request.Student != nil {
		payload["student"] = request.Student
	}
	if request.ParentUser != nil {
		payload["parent_user"] = request.ParentUser
	}
	if request.Payment != nil {
		payload["payment"] = request.Payment
	}
	return payload
}

func buildParentPaymentUPIURI(request models.ParentPaymentRequest) string {
	if strings.TrimSpace(request.PaymentUPIID) == "" {
		return ""
	}
	params := url.Values{}
	params.Set("pa", strings.TrimSpace(request.PaymentUPIID))
	params.Set("pn", strings.TrimSpace(firstNonEmpty(request.PaymentPayeeName, "School")))
	params.Set("am", fmt.Sprintf("%.2f", roundMoney(request.Amount)))
	params.Set("cu", "INR")
	params.Set("tn", strings.TrimSpace(firstNonEmpty(request.RequestReference, request.PaymentQRNote, "School fee payment")))
	return "upi://pay?" + params.Encode()
}

func generateFeePaymentReference(student *models.Student) string {
	code := "STUDENT"
	if student != nil {
		code = firstNonEmpty(student.AdmissionNumber, student.StudentCode, student.ID)
	}
	code = sanitizePaymentReferencePart(code)
	now := time.Now().UTC()
	return fmt.Sprintf("FEE-%s-%s-%06d", code, now.Format("20060102"), now.UnixNano()%1000000)
}

func sanitizePaymentReferencePart(value string) string {
	value = strings.ToUpper(strings.TrimSpace(value))
	var builder strings.Builder
	for _, char := range value {
		if (char >= 'A' && char <= 'Z') || (char >= '0' && char <= '9') {
			builder.WriteRune(char)
		}
	}
	clean := builder.String()
	if clean == "" {
		return "STUDENT"
	}
	if len(clean) > 16 {
		return clean[:16]
	}
	return clean
}

func (h *FeeHandler) savePaymentProof(c *gin.Context) (string, error) {
	file, err := c.FormFile("screenshot")
	if err != nil {
		file, err = c.FormFile("file")
	}
	if err != nil {
		return "", fmt.Errorf("payment screenshot is required")
	}
	ext := strings.ToLower(filepath.Ext(file.Filename))
	allowed := map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".webp": true, ".pdf": true}
	if !allowed[ext] {
		return "", fmt.Errorf("unsupported payment proof type. Allowed: jpg, png, webp, pdf")
	}
	if file.Size > 15*1024*1024 {
		return "", fmt.Errorf("payment proof is too large")
	}
	dir := filepath.Join("uploads", "payment_proofs", scopedSchoolID(c))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", fmt.Errorf("failed to prepare payment proof storage")
	}
	base := strings.TrimSuffix(filepath.Base(file.Filename), ext)
	dest := filepath.ToSlash(filepath.Join(dir, fmt.Sprintf("%d_%s%s", time.Now().UnixNano(), base, ext)))
	if err := c.SaveUploadedFile(file, dest); err != nil {
		return "", fmt.Errorf("failed to save payment proof")
	}
	return "/" + dest, nil
}

func parseRequiredMoney(raw, field string) (float64, error) {
	value, err := strconv.ParseFloat(strings.TrimSpace(raw), 64)
	if err != nil || value <= 0 {
		return 0, fmt.Errorf("%s must be greater than zero", field)
	}
	return roundMoney(value), nil
}

func parsePositiveInt(raw string) int {
	value, err := strconv.Atoi(strings.TrimSpace(raw))
	if err != nil || value < 0 {
		return 0
	}
	return value
}

func feeStructureDueDate(structure models.FeeStructure) time.Time {
	now := time.Now().UTC()
	day := structure.DueDay
	if day < 1 {
		day = 10
	}
	if day > 28 {
		day = 28
	}
	return time.Date(now.Year(), now.Month(), day, 0, 0, 0, 0, time.UTC)
}

func mergeQuery(existing, addition string) string {
	if strings.TrimSpace(existing) == "" {
		return addition
	}
	if strings.Contains(existing, "status=") {
		return existing
	}
	return existing + "&" + addition
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
	return pendingParentPaymentAmountExcept(invoiceID, "")
}

func pendingParentPaymentAmountExcept(invoiceID, excludeRequestID string) (float64, error) {
	var amount float64
	query := database.DB.Model(&models.ParentPaymentRequest{}).
		Where("invoice_id = ? AND status IN ?", invoiceID, parentPaymentReservedStatuses)
	if strings.TrimSpace(excludeRequestID) != "" {
		query = query.Where("id <> ?", excludeRequestID)
	}
	err := query.
		Select("COALESCE(SUM(amount), 0)").
		Scan(&amount).Error
	return amount, err
}

func ensureUniqueTransactionRef(schoolID, transactionRef, excludeRequestID string) error {
	transactionRef = strings.TrimSpace(transactionRef)
	if transactionRef == "" {
		return nil
	}
	query := database.DB.Model(&models.ParentPaymentRequest{}).
		Where("school_id = ? AND transaction_id = ? AND status NOT IN ?", schoolID, transactionRef, []string{
			parentPaymentStatusRejected,
			parentPaymentStatusCancelled,
			parentPaymentStatusExpired,
		})
	if strings.TrimSpace(excludeRequestID) != "" {
		query = query.Where("id <> ?", excludeRequestID)
	}
	var count int64
	if err := query.Count(&count).Error; err != nil {
		return fmt.Errorf("failed to verify transaction reference")
	}
	if count > 0 {
		return fmt.Errorf("transaction reference is already used for another payment request")
	}
	return nil
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

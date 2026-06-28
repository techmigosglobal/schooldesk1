package handlers

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"school-backend/internal/database"
	"school-backend/internal/models"
)

// DiagnoseFeeStructures checks for potential issues in fee structure setup
func (h *FeeHandler) DiagnoseFeeStructures(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	academicYearID := strings.TrimSpace(c.Query("academic_year_id"))
	gradeID := strings.TrimSpace(c.Query("grade_id"))

	type structureRow struct {
		GradeID         string  `json:"grade_id"`
		GradeName       string  `json:"grade_name"`
		SectionID       *string `json:"section_id"`
		SectionName     *string `json:"section_name"`
		FeeCategoryID   string  `json:"fee_category_id"`
		CategoryName    string  `json:"category_name"`
		Amount          float64 `json:"amount"`
		Frequency       string  `json:"frequency"`
		StructureCount  int64   `json:"structure_count"`
		TotalAmount     float64 `json:"total_amount"`
		InstallmentCount int    `json:"installment_count"`
	}

	query := `
		SELECT 
			g.id AS grade_id,
			g.grade_name,
			s.id AS section_id,
			s.section_name,
			fc.id AS fee_category_id,
			fc.category_name,
			fs.amount,
			fc.frequency,
			fs.installment_count,
			COUNT(fs.id) OVER (PARTITION BY g.id, COALESCE(s.id, ''), fc.id) AS structure_count,
			SUM(fs.amount) OVER (PARTITION BY g.id, COALESCE(s.id, '')) AS total_amount
		FROM fee_structures fs
		JOIN grades g ON g.id = fs.grade_id
		LEFT JOIN sections s ON s.id = fs.section_id
		JOIN fee_categories fc ON fc.id = fs.fee_category_id
		WHERE fs.school_id = ?
	`
	args := []interface{}{schoolID}

	if academicYearID != "" {
		query += " AND fs.academic_year_id = ?"
		args = append(args, academicYearID)
	}
	if gradeID != "" {
		query += " AND fs.grade_id = ?"
		args = append(args, gradeID)
	}

	query += " ORDER BY g.grade_name, s.section_name, fc.category_name"

	var rows []structureRow
	if err := database.DB.Raw(query, args...).Scan(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load fee structures")
		return
	}

	// Detect issues
	issues := []gin.H{}
	duplicates := make(map[string]bool)

	for _, row := range rows {
		key := row.GradeID + ":" + firstNonEmpty(ptrToString(row.SectionID), "grade-level") + ":" + row.FeeCategoryID
		
		// Issue 1: Duplicate structures for same category
		if row.StructureCount > 1 && !duplicates[key] {
			duplicates[key] = true
			sectionLabel := "grade-level"
			if row.SectionName != nil && *row.SectionName != "" {
				sectionLabel = *row.SectionName
			}
			issues = append(issues, gin.H{
				"type":       "duplicate_structure",
				"severity":   "critical",
				"grade":      row.GradeName,
				"section":    sectionLabel,
				"category":   row.CategoryName,
				"count":      row.StructureCount,
				"message":    fmt.Sprintf("%s has %d fee structures for category '%s' - only one should exist", row.GradeName+" "+sectionLabel, row.StructureCount, row.CategoryName),
				"fix_action": "Delete duplicate structures, keep only one per category per class",
			})
		}

		// Issue 2: Very high total amount (potential accumulation error)
		studentCount := estimateStudentCount(schoolID, row.GradeID, ptrToString(row.SectionID))
		expectedTotal := row.TotalAmount * float64(studentCount)
		if expectedTotal > 50000000 { // 50 lakh threshold
			issues = append(issues, gin.H{
				"type":       "excessive_total",
				"severity":   "warning",
				"grade":      row.GradeName,
				"section":    firstNonEmpty(ptrToString(row.SectionName), "grade-level"),
				"total":      row.TotalAmount,
				"students":   studentCount,
				"projected":  expectedTotal,
				"message":    fmt.Sprintf("Total fee amount (%.2f) seems very high - will generate %.2f for %d students", row.TotalAmount, expectedTotal, studentCount),
				"fix_action": "Review fee structure amounts - they may be multiplied incorrectly",
			})
		}
	}

	// Calculate invoice summary
	type invoiceSummary struct {
		TotalInvoices int64   `json:"total_invoices"`
		TotalAmount   float64 `json:"total_amount"`
		AvgPerStudent float64 `json:"avg_per_student"`
		MaxAmount     float64 `json:"max_amount"`
		MinAmount     float64 `json:"min_amount"`
	}

	var summary invoiceSummary
	summaryQuery := `
		SELECT 
			COUNT(fi.id) AS total_invoices,
			COALESCE(SUM(fi.total_amount), 0) AS total_amount,
			COALESCE(AVG(fi.total_amount), 0) AS avg_per_student,
			COALESCE(MAX(fi.total_amount), 0) AS max_amount,
			COALESCE(MIN(fi.total_amount), 0) AS min_amount
		FROM fee_invoices fi
		JOIN students s ON s.id = fi.student_id
		WHERE s.school_id = ? AND s.status != 'inactive'
	`
	summaryArgs := []interface{}{schoolID}

	if academicYearID != "" {
		summaryQuery += " AND fi.academic_year_id = ?"
		summaryArgs = append(summaryArgs, academicYearID)
	}

	if err := database.DB.Raw(summaryQuery, summaryArgs...).Scan(&summary).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load invoice summary")
		return
	}

	success(c, http.StatusOK, gin.H{
		"structures":       rows,
		"issues":           issues,
		"invoice_summary":  summary,
		"issue_count":      len(issues),
		"has_duplicates":   len(duplicates) > 0,
	}, "Fee structure diagnosis complete")
}

// RecalculateInvoices recalculates invoice amounts based on current fee structures
func (h *FeeHandler) RecalculateInvoices(c *gin.Context) {
	var req struct {
		AcademicYearID string `json:"academic_year_id" binding:"required"`
		GradeID        string `json:"grade_id"`
		SectionID      string `json:"section_id"`
		DryRun         bool   `json:"dry_run"` // Preview changes without applying
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	schoolID := scopedSchoolID(c)
	
	// Load affected invoices
	query := database.DB.Model(&models.FeeInvoice{}).
		Joins("JOIN students ON students.id = fee_invoices.student_id").
		Where("students.school_id = ? AND fee_invoices.academic_year_id = ?", schoolID, req.AcademicYearID).
		Preload("Student").
		Preload("Items").
		Preload("Items.FeeCategory")

	if req.GradeID != "" {
		query = query.Joins("JOIN sections ON sections.id = students.current_section_id").
			Where("sections.grade_id = ?", req.GradeID)
	}
	if req.SectionID != "" {
		query = query.Where("students.current_section_id = ?", req.SectionID)
	}

	var invoices []models.FeeInvoice
	if err := query.Find(&invoices).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load invoices")
		return
	}

	if len(invoices) == 0 {
		success(c, http.StatusOK, gin.H{"affected": 0, "message": "No invoices found matching criteria"}, "")
		return
	}

	// Calculate correct amounts
	changes := []gin.H{}
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		for _, invoice := range invoices {
			oldTotal := invoice.TotalAmount
			newTotal := 0.0
			
			for _, item := range invoice.Items {
				newTotal += item.Amount
			}
			newTotal = roundMoney(newTotal)

			if oldTotal == newTotal {
				continue // No change needed
			}

			newPayable := roundMoney(newTotal - invoice.DiscountAmount - invoice.ConcessionAmount + invoice.FineAmount)
			if newPayable < 0 {
				newPayable = 0
			}
			
			newBalance := roundMoney(newPayable - invoice.PaidAmount)
			if newBalance < 0 {
				newBalance = 0
			}

			newStatus := "pending"
			if invoice.PaidAmount > 0 && newBalance > 0 {
				newStatus = "partial"
			}
			if newBalance == 0 {
				newStatus = "paid"
			}

			changes = append(changes, gin.H{
				"invoice_id":     invoice.ID,
				"invoice_number": invoice.InvoiceNumber,
				"student_name":   invoice.Student.FirstName + " " + invoice.Student.LastName,
				"old_total":      oldTotal,
				"new_total":      newTotal,
				"old_balance":    invoice.Balance,
				"new_balance":    newBalance,
				"old_status":     invoice.Status,
				"new_status":     newStatus,
			})

			if !req.DryRun {
				if err := tx.Model(&models.FeeInvoice{}).Where("id = ?", invoice.ID).Updates(map[string]interface{}{
					"total_amount":   newTotal,
					"payable_amount": newPayable,
					"balance":        newBalance,
					"status":         newStatus,
				}).Error; err != nil {
					return err
				}
			}
		}
		return nil
	})

	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to recalculate invoices")
		return
	}

	if !req.DryRun {
		id := req.AcademicYearID
		auditAction(c, "fees", "recalculate_invoices", "fee_invoices", &id)
	}

	mode := "applied"
	if req.DryRun {
		mode = "preview"
	}

	success(c, http.StatusOK, gin.H{
		"mode":     mode,
		"affected": len(changes),
		"changes":  changes,
	}, fmt.Sprintf("Invoice recalculation %s", mode))
}

func estimateStudentCount(schoolID, gradeID, sectionID string) int64 {
	var count int64
	query := database.DB.Model(&models.Student{}).
		Joins("JOIN sections ON sections.id = students.current_section_id").
		Where("students.school_id = ? AND students.status != ? AND sections.grade_id = ?", schoolID, "inactive", gradeID)
	
	if sectionID != "" {
		query = query.Where("students.current_section_id = ?", sectionID)
	}

	query.Count(&count)
	return count
}

func ptrToString(ptr *string) string {
	if ptr == nil {
		return ""
	}
	return *ptr
}

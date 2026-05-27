package handlers

import (
	"net/http"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type GuardianHandler struct{}

func NewGuardianHandler() *GuardianHandler {
	return &GuardianHandler{}
}

func (h *GuardianHandler) LinkGuardianToStudent(c *gin.Context) {
	studentID := c.Param("id")
	schoolID := currentSchoolID(c)
	var req struct {
		GuardianID string `json:"guardian_id" binding:"required"`
		IsPrimary  bool   `json:"is_primary"`
		CanPickup  bool   `json:"can_pickup"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var student models.Student
	if err := database.DB.First(&student, "id = ? AND school_id = ?", studentID, schoolID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "student not found"})
		return
	}
	var guardian models.Guardian
	if err := database.DB.First(&guardian, "id = ? AND school_id = ?", req.GuardianID, schoolID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "guardian not found"})
		return
	}

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		if req.IsPrimary {
			if err := tx.Model(&models.StudentGuardian{}).
				Where("student_id = ? AND school_id = ? AND is_primary = true", studentID, schoolID).
				Update("is_primary", false).Error; err != nil {
				return err
			}
		}
		var link models.StudentGuardian
		return tx.Where("student_id = ? AND guardian_id = ? AND school_id = ?", studentID, req.GuardianID, schoolID).
			Attrs(models.StudentGuardian{
				ID:         uuid.NewString(),
				StudentID:  studentID,
				GuardianID: req.GuardianID,
				SchoolID:   schoolID,
			}).
			Assign(map[string]interface{}{
				"is_primary": req.IsPrimary,
				"can_pickup": req.CanPickup,
			}).
			FirstOrCreate(&link).Error
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "guardian linked"})
}

func (h *GuardianHandler) GetGuardiansByStudent(c *gin.Context) {
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

	var guardians []models.Guardian
	if err := database.DB.
		Select("guardians.*, sg.is_primary, sg.can_pickup").
		Joins("JOIN student_guardians sg ON sg.guardian_id = guardians.id").
		Where("sg.student_id = ? AND sg.school_id = ?", studentID, schoolID).
		Find(&guardians).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load guardians"})
		return
	}
	c.JSON(http.StatusOK, guardians)
}

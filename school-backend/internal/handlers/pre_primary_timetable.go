package handlers

import (
	"net/http"
	"strings"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// List templates
func (h *TimetableHandler) GetPrePrimaryTimetableTemplates(c *gin.Context) {
	var templates []models.PrePrimaryTimetableTemplate
	query := database.DB.Where("school_id = ?", scopedSchoolID(c)).Preload("Days").Preload("Days.Slots")

	if yearID := strings.TrimSpace(c.Query("academic_year_id")); yearID != "" {
		query = query.Where("academic_year_id = ?", yearID)
	}

	if err := query.Order("created_at DESC").Find(&templates).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load pre-primary templates")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: templates})
}

// Create a template
func (h *TimetableHandler) CreatePrePrimaryTimetableTemplate(c *gin.Context) {
	var req models.PrePrimaryTimetableTemplate
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, "Invalid request body")
		return
	}

	req.SchoolID = scopedSchoolID(c)
	req.ID = ""

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&req).Error; err != nil {
			return err
		}
		return nil
	})

	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create pre-primary template")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: req})
}

// Update a template
func (h *TimetableHandler) UpdatePrePrimaryTimetableTemplate(c *gin.Context) {
	templateID := c.Param("id")
	var req models.PrePrimaryTimetableTemplate
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, "Invalid request body")
		return
	}

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		var existing models.PrePrimaryTimetableTemplate
		if err := tx.Where("id = ? AND school_id = ?", templateID, scopedSchoolID(c)).First(&existing).Error; err != nil {
			return err
		}

		existing.Name = req.Name
		if err := tx.Save(&existing).Error; err != nil {
			return err
		}

		// Delete existing days and slots
		if err := tx.Where("template_id = ?", templateID).Delete(&models.PrePrimaryTimetableDay{}).Error; err != nil {
			return err
		}

		// Recreate days and slots
		for i := range req.Days {
			req.Days[i].TemplateID = templateID
			req.Days[i].ID = ""
			for j := range req.Days[i].Slots {
				req.Days[i].Slots[j].ID = ""
			}
			if err := tx.Create(&req.Days[i]).Error; err != nil {
				return err
			}
		}

		return nil
	})

	if err != nil {
		if err == gorm.ErrRecordNotFound {
			fail(c, http.StatusNotFound, "Template not found")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to update pre-primary template")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Pre-primary template updated"})
}

// Delete a template
func (h *TimetableHandler) DeletePrePrimaryTimetableTemplate(c *gin.Context) {
	templateID := c.Param("id")

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		// Verify ownership
		var existing models.PrePrimaryTimetableTemplate
		if err := tx.Where("id = ? AND school_id = ?", templateID, scopedSchoolID(c)).First(&existing).Error; err != nil {
			return err
		}

		// Delete days (slots cascade if DB configured or we rely on gorm if we have hooks, let's delete explicitly if needed but let's assume we do it)
		if err := tx.Where("template_id = ?", templateID).Delete(&models.PrePrimaryTimetableDay{}).Error; err != nil {
			return err
		}

		if err := tx.Delete(&existing).Error; err != nil {
			return err
		}
		return nil
	})

	if err != nil {
		if err == gorm.ErrRecordNotFound {
			fail(c, http.StatusNotFound, "Template not found")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to delete pre-primary template")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Pre-primary template deleted"})
}

// Fetch Pre-Primary timetable by Section ID
func (h *TimetableHandler) GetPrePrimaryTimetableBySection(c *gin.Context) {
	sectionID := c.Param("section_id")
	if !canAccessSection(c, sectionID) {
		fail(c, http.StatusForbidden, "section access denied")
		return
	}

	var section models.Section
	if err := database.DB.Where("id = ? AND school_id = ?", sectionID, scopedSchoolID(c)).First(&section).Error; err != nil {
		fail(c, http.StatusNotFound, "Section not found")
		return
	}

	if section.PrePrimaryTimetableTemplateID == nil || *section.PrePrimaryTimetableTemplateID == "" {
		fail(c, http.StatusNotFound, "No pre-primary timetable template assigned to this section")
		return
	}

	var template models.PrePrimaryTimetableTemplate
	if err := database.DB.Preload("Days").Preload("Days.Slots").Where("id = ? AND school_id = ?", *section.PrePrimaryTimetableTemplateID, scopedSchoolID(c)).First(&template).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load pre-primary timetable template")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: template})
}

package handlers

import (
	"encoding/json"
	"net/http"
	"strings"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
)

type FrontendRecordHandler struct {
	resource string
}

func NewFrontendRecordHandler(resource string) *FrontendRecordHandler {
	return &FrontendRecordHandler{resource: strings.Trim(strings.TrimSpace(resource), "/")}
}

func (h *FrontendRecordHandler) List(c *gin.Context) {
	var rows []models.FrontendRecord
	query := database.DB.
		Where("school_id = ? AND resource = ?", scopedSchoolID(c), h.resource).
		Order("created_at DESC")
	if err := query.Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load records")
		return
	}
	data := make([]gin.H, 0, len(rows))
	for _, row := range rows {
		data = append(data, frontendRecordResponse(row))
	}
	success(c, http.StatusOK, data, "")
}

func (h *FrontendRecordHandler) Create(c *gin.Context) {
	payload, ok := h.bindPayload(c)
	if !ok {
		return
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid record payload")
		return
	}
	row := models.FrontendRecord{
		SchoolID:  scopedSchoolID(c),
		Resource:  h.resource,
		Payload:   string(encoded),
		CreatedBy: c.GetString("user_id"),
	}
	if id, _ := payload["id"].(string); strings.TrimSpace(id) != "" {
		row.ID = strings.TrimSpace(id)
	}
	if err := database.DB.Create(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create record")
		return
	}
	auditAction(c, h.resource, "create", "frontend_records", &row.ID)
	success(c, http.StatusCreated, frontendRecordResponse(row), "Record created successfully")
}

func (h *FrontendRecordHandler) Update(c *gin.Context) {
	var row models.FrontendRecord
	if err := database.DB.First(&row, "id = ? AND school_id = ? AND resource = ?", c.Param("id"), scopedSchoolID(c), h.resource).Error; err != nil {
		fail(c, http.StatusNotFound, "Record not found")
		return
	}
	payload, ok := h.bindPayload(c)
	if !ok {
		return
	}
	current := frontendPayload(row.Payload)
	for key, value := range payload {
		current[key] = value
	}
	current["id"] = row.ID
	encoded, err := json.Marshal(current)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid record payload")
		return
	}
	row.Payload = string(encoded)
	if err := database.DB.Save(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update record")
		return
	}
	auditAction(c, h.resource, "update", "frontend_records", &row.ID)
	success(c, http.StatusOK, frontendRecordResponse(row), "Record updated successfully")
}

func (h *FrontendRecordHandler) Delete(c *gin.Context) {
	result := database.DB.Delete(&models.FrontendRecord{}, "id = ? AND school_id = ? AND resource = ?", c.Param("id"), scopedSchoolID(c), h.resource)
	if result.Error != nil {
		fail(c, http.StatusInternalServerError, "Failed to delete record")
		return
	}
	if result.RowsAffected == 0 {
		fail(c, http.StatusNotFound, "Record not found")
		return
	}
	auditAction(c, h.resource, "delete", "frontend_records", nil)
	success(c, http.StatusOK, gin.H{"id": c.Param("id")}, "Record deleted successfully")
}

func (h *FrontendRecordHandler) bindPayload(c *gin.Context) (map[string]interface{}, bool) {
	var payload map[string]interface{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return nil, false
	}
	if payload == nil {
		payload = map[string]interface{}{}
	}
	return payload, true
}

func frontendRecordResponse(row models.FrontendRecord) gin.H {
	payload := frontendPayload(row.Payload)
	payload["id"] = row.ID
	payload["school_id"] = row.SchoolID
	payload["resource"] = row.Resource
	payload["created_at"] = row.CreatedAt
	payload["updated_at"] = row.UpdatedAt
	if row.CreatedBy != "" {
		payload["created_by"] = row.CreatedBy
	}
	return payload
}

func frontendPayload(raw string) gin.H {
	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &payload); err != nil || payload == nil {
		return gin.H{}
	}
	return gin.H(payload)
}

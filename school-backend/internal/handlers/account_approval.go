package handlers

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type AccountApprovalHandler struct{}

func NewAccountApprovalHandler() *AccountApprovalHandler {
	return &AccountApprovalHandler{}
}

func (h *AccountApprovalHandler) List(c *gin.Context) {
	var rows []models.FrontendRecord
	query := database.DB.
		Where("school_id = ? AND resource = ?", scopedSchoolID(c), "account-approvals").
		Order("created_at DESC")
	if strings.EqualFold(c.GetString("role_name"), "Admin") {
		query = query.Where("created_by = ?", c.GetString("user_id"))
	}
	if err := query.Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load account approvals")
		return
	}
	data := make([]gin.H, 0, len(rows))
	for _, row := range rows {
		payload := frontendRecordResponse(row)
		if payload["status"] == nil {
			payload["status"] = "pending"
		}
		payload["type"] = "account"
		if strings.TrimSpace(stringMapValue(payload["decisionPath"])) == "" {
			payload["decisionPath"] = "/account-approvals/" + row.ID
		}
		data = append(data, payload)
	}
	success(c, http.StatusOK, data, "")
}

func (h *AccountApprovalHandler) Decide(c *gin.Context) {
	var row models.FrontendRecord
	if err := database.DB.First(&row, "id = ? AND school_id = ? AND resource = ?", c.Param("id"), scopedSchoolID(c), "account-approvals").Error; err != nil {
		fail(c, http.StatusNotFound, "Account approval not found")
		return
	}
	var req struct {
		Status  string `json:"status" binding:"required"`
		Remarks string `json:"remarks"`
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
	payload := frontendPayload(row.Payload)
	currentStatus := strings.ToLower(strings.TrimSpace(stringMapValue(payload["status"])))
	if currentStatus != "" && currentStatus != "pending" {
		fail(c, http.StatusBadRequest, "Account approval has already been actioned")
		return
	}

	var decisionLogs []models.NotificationLog
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		userID := strings.TrimSpace(stringMapValue(payload["user_id"]))
		staffID := strings.TrimSpace(stringMapValue(payload["staff_id"]))
		if userID == "" {
			return fmt.Errorf("approval is missing user_id")
		}
		if err := activateManagedUser(tx, scopedSchoolID(c), userID, status == "approved"); err != nil {
			return err
		}
		if staffID != "" {
			staffStatus := "rejected"
			if status == "approved" {
				staffStatus = "active"
			}
			if err := setLinkedStaffStatus(tx, scopedSchoolID(c), staffID, staffStatus); err != nil {
				return err
			}
		}
		payload["status"] = status
		payload["remarks"] = strings.TrimSpace(req.Remarks)
		payload["action_date"] = time.Now().UTC().Format(time.RFC3339)
		payload["decision_by_id"] = c.GetString("user_id")
		payload["decision_by"] = c.GetString("email")
		encoded, err := jsonMarshal(payload)
		if err != nil {
			return err
		}
		row.Payload = encoded
		if err := tx.Save(&row).Error; err != nil {
			return err
		}
		logs, err := createApprovalDecisionNotificationsTx(
			tx,
			c,
			row.CreatedBy,
			row.ID,
			"Account approval "+status,
			fmt.Sprintf("Your account request for %s was %s.", stringMapValue(payload["target_name"]), status),
		)
		if err != nil {
			return nil
		}
		decisionLogs = logs
		return nil
	}); err != nil {
		fail(c, http.StatusInternalServerError, err.Error())
		return
	}

	auditAction(c, "account-approvals", status, "frontend_records", &row.ID)
	enqueuePushNotifications(decisionLogs)
	success(c, http.StatusOK, frontendRecordResponse(row), "Account approval updated")
}

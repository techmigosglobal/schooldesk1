package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/policy"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

const approvalRequestResource = "approval-requests"

type ApprovalRequestHandler struct {
	matrix policy.OwnershipMatrix
}

func NewApprovalRequestHandler() *ApprovalRequestHandler {
	return &ApprovalRequestHandler{matrix: policy.MustLoadOwnershipMatrix()}
}

func (h *ApprovalRequestHandler) List(c *gin.Context) {
	var rows []models.FrontendRecord
	query := database.DB.
		Where("school_id = ? AND resource = ?", scopedSchoolID(c), approvalRequestResource).
		Order("created_at DESC")
	if strings.EqualFold(c.GetString("role_name"), "Admin") {
		query = query.Where("created_by = ?", c.GetString("user_id"))
	}
	if status := strings.TrimSpace(c.Query("status")); status != "" {
		query = query.Where("payload LIKE ?", "%\"status\":\""+strings.ToLower(status)+"\"%")
	}
	if module := strings.TrimSpace(c.Query("module")); module != "" {
		query = query.Where("payload LIKE ?", "%\"module\":\""+strings.ToLower(module)+"\"%")
	}
	if err := query.Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load approvals")
		return
	}
	data := make([]gin.H, 0, len(rows))
	for _, row := range rows {
		data = append(data, approvalRecordResponse(row))
	}
	success(c, http.StatusOK, data, "")
}

func (h *ApprovalRequestHandler) Get(c *gin.Context) {
	row, ok := h.loadScopedRecord(c)
	if !ok {
		return
	}
	success(c, http.StatusOK, approvalRecordResponse(row), "")
}

func (h *ApprovalRequestHandler) Create(c *gin.Context) {
	var req approvalMutationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	role := currentRole(c)
	if role != "admin" {
		fail(c, http.StatusForbidden, "Only Admin can create operational approval requests")
		return
	}
	moduleKey := normalizeApprovalModule(req.Module)
	module, ok := h.matrix.Module(moduleKey)
	if !ok {
		fail(c, http.StatusBadRequest, "Unknown approval module")
		return
	}
	if !h.matrix.Can(module.Key, role, "create_draft") {
		fail(c, http.StatusForbidden, "Role cannot create approval drafts for this module")
		return
	}
	now := time.Now().UTC()
	status := normalizeApprovalStatus(firstNonEmpty(req.Status, "draft"))
	if status != "draft" && status != "submitted" && status != "principal_review" {
		fail(c, http.StatusBadRequest, "New approval status must be draft or submitted")
		return
	}
	if status == "submitted" {
		status = "principal_review"
	}
	payload := approvalPayload(c, module, req, status, now)
	payload["audit_trail"] = []gin.H{
		approvalAuditEntry(c, "created", status, "", now),
	}
	if status == "principal_review" {
		payload["submitted_at"] = now.Format(time.RFC3339)
		payload["audit_trail"] = append(
			auditTrailFromPayload(payload),
			approvalAuditEntry(c, "submitted", status, "", now),
		)
	}
	encoded, err := jsonMarshal(payload)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid approval request payload")
		return
	}
	row := models.FrontendRecord{
		SchoolID:  scopedSchoolID(c),
		Resource:  approvalRequestResource,
		Payload:   encoded,
		CreatedBy: currentUserID(c),
	}
	if err := database.DB.Create(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create approval request")
		return
	}
	auditAction(c, approvalRequestResource, "create", "frontend_records", &row.ID)
	if status == "principal_review" {
		if logs, err := createApprovalRequestedNotificationsTx(
			database.DB,
			c,
			row.ID,
			"Approval request pending",
			fmt.Sprintf("%s requested %s approval.", c.GetString("role_name"), module.Label),
		); err == nil {
			enqueuePushNotifications(logs)
		}
	}
	success(c, http.StatusCreated, approvalRecordResponse(row), "Approval request created")
}

func (h *ApprovalRequestHandler) Update(c *gin.Context) {
	row, ok := h.loadScopedRecord(c)
	if !ok {
		return
	}
	if currentRole(c) != "admin" || row.CreatedBy != currentUserID(c) {
		fail(c, http.StatusForbidden, "Only the requesting Admin can edit this approval request")
		return
	}
	payload := frontendPayload(row.Payload)
	status := normalizeApprovalStatus(stringMapValue(payload["status"]))
	if status != "draft" && status != "changes_requested" {
		fail(c, http.StatusBadRequest, "Only draft or changes_requested requests can be edited")
		return
	}
	if !h.ensureMatrixPermission(c, payload, "admin", "edit_pending_request") {
		return
	}
	var req approvalMutationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	if req.OperationType != "" {
		payload["operation_type"] = strings.TrimSpace(req.OperationType)
	}
	if req.EntityType != "" {
		payload["entity_type"] = strings.TrimSpace(req.EntityType)
	}
	if req.EntityID != "" {
		payload["entity_id"] = strings.TrimSpace(req.EntityID)
	}
	if req.AcademicYearID != "" {
		payload["academic_year_id"] = strings.TrimSpace(req.AcademicYearID)
	}
	if req.Payload != nil {
		payload["payload_json"] = req.Payload
	}
	if req.BeforeSnapshot != nil {
		payload["before_snapshot_json"] = req.BeforeSnapshot
	}
	if req.AfterSnapshot != nil {
		payload["after_snapshot_json"] = req.AfterSnapshot
	}
	now := time.Now().UTC()
	payload["status"] = "draft"
	payload["updated_at"] = now.Format(time.RFC3339)
	payload["audit_trail"] = append(
		auditTrailFromPayload(payload),
		approvalAuditEntry(c, "edited", "draft", "", now),
	)
	if err := h.savePayload(&row, payload); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update approval request")
		return
	}
	auditAction(c, approvalRequestResource, "update", "frontend_records", &row.ID)
	success(c, http.StatusOK, approvalRecordResponse(row), "Approval request updated")
}

func (h *ApprovalRequestHandler) Submit(c *gin.Context) {
	h.transitionAdminOwned(c, "submitted", "principal_review", "Approval request submitted")
}

func (h *ApprovalRequestHandler) Cancel(c *gin.Context) {
	h.transitionAdminOwned(c, "cancelled", "cancelled", "Approval request cancelled")
}

func (h *ApprovalRequestHandler) Approve(c *gin.Context) {
	h.transitionPrincipalDecision(c, "approved", false)
}

func (h *ApprovalRequestHandler) Reject(c *gin.Context) {
	h.transitionPrincipalDecision(c, "rejected", true)
}

func (h *ApprovalRequestHandler) RequestChanges(c *gin.Context) {
	row, ok := h.loadScopedRecord(c)
	if !ok {
		return
	}
	if currentRole(c) != "principal" {
		fail(c, http.StatusForbidden, "Only Principal can request changes")
		return
	}
	payload := frontendPayload(row.Payload)
	if !h.ensureMatrixPermission(c, payload, "principal", "final_reject") {
		return
	}
	var req struct {
		Note string `json:"note" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	note := strings.TrimSpace(req.Note)
	if note == "" {
		fail(c, http.StatusBadRequest, "change request note is required")
		return
	}
	status := normalizeApprovalStatus(stringMapValue(payload["status"]))
	if status != "principal_review" && status != "submitted" {
		fail(c, http.StatusBadRequest, "Only submitted requests can receive change requests")
		return
	}
	now := time.Now().UTC()
	payload["status"] = "changes_requested"
	payload["approver_user_id"] = currentUserID(c)
	payload["change_request_note"] = note
	payload["audit_trail"] = append(
		auditTrailFromPayload(payload),
		approvalAuditEntry(c, "changes_requested", "changes_requested", note, now),
	)
	if err := h.savePayload(&row, payload); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to request changes")
		return
	}
	auditAction(c, approvalRequestResource, "changes_requested", "frontend_records", &row.ID)
	if logs, err := createApprovalDecisionNotificationsTx(
		database.DB,
		c,
		row.CreatedBy,
		row.ID,
		"Approval request changes requested",
		"Your approval request needs changes before it can be reviewed again.",
	); err == nil {
		enqueuePushNotifications(logs)
	}
	success(c, http.StatusOK, approvalRecordResponse(row), "Changes requested")
}

func (h *ApprovalRequestHandler) Apply(c *gin.Context) {
	row, ok := h.loadScopedRecord(c)
	if !ok {
		return
	}
	if currentRole(c) != "principal" {
		fail(c, http.StatusForbidden, "Only Principal can apply approved requests")
		return
	}
	payload := frontendPayload(row.Payload)
	if !h.ensureMatrixPermission(c, payload, "principal", "direct_publish") {
		return
	}
	status := normalizeApprovalStatus(stringMapValue(payload["status"]))
	if status == "applied" {
		success(c, http.StatusOK, approvalRecordResponse(row), "Approval request already applied")
		return
	}
	if status != "approved" {
		fail(c, http.StatusBadRequest, "Only approved requests can be applied")
		return
	}
	now := time.Now().UTC()
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := h.applyApprovedOperation(c, tx, scopedSchoolID(c), payload); err != nil {
			return err
		}
		payload["status"] = "applied"
		payload["applied_at"] = now.Format(time.RFC3339)
		payload["approver_user_id"] = currentUserID(c)
		payload["audit_trail"] = append(
			auditTrailFromPayload(payload),
			approvalAuditEntry(c, "applied", "applied", "", now),
		)
		encoded, err := jsonMarshal(payload)
		if err != nil {
			return err
		}
		row.Payload = encoded
		return tx.Save(&row).Error
	}); err != nil {
		fail(c, approvalApplyStatus(err), err.Error())
		return
	}
	auditAction(c, approvalRequestResource, "applied", "frontend_records", &row.ID)
	success(c, http.StatusOK, approvalRecordResponse(row), "Approval request applied")
}

func approvalApplyStatus(err error) int {
	message := strings.ToLower(err.Error())
	if strings.Contains(message, "not implemented") ||
		strings.Contains(message, "not supported") ||
		strings.Contains(message, "view-only") ||
		strings.Contains(message, "is required") ||
		strings.Contains(message, "must ") ||
		strings.Contains(message, "not found") {
		return http.StatusBadRequest
	}
	return http.StatusInternalServerError
}

func (h *ApprovalRequestHandler) transitionAdminOwned(c *gin.Context, action, status, message string) {
	row, ok := h.loadScopedRecord(c)
	if !ok {
		return
	}
	if currentRole(c) != "admin" || row.CreatedBy != currentUserID(c) {
		fail(c, http.StatusForbidden, "Only the requesting Admin can manage this approval request")
		return
	}
	payload := frontendPayload(row.Payload)
	requiredAction := "submit_for_approval"
	if action == "cancelled" {
		requiredAction = "cancel_own_pending_request"
	}
	if !h.ensureMatrixPermission(c, payload, "admin", requiredAction) {
		return
	}
	currentStatus := normalizeApprovalStatus(stringMapValue(payload["status"]))
	switch action {
	case "submitted":
		if currentStatus != "draft" && currentStatus != "changes_requested" {
			fail(c, http.StatusBadRequest, "Only draft or changes_requested requests can be submitted")
			return
		}
	case "cancelled":
		if currentStatus == "approved" || currentStatus == "applied" || currentStatus == "rejected" || currentStatus == "cancelled" {
			fail(c, http.StatusBadRequest, "This approval request cannot be cancelled")
			return
		}
	}
	now := time.Now().UTC()
	payload["status"] = status
	if status == "principal_review" {
		payload["submitted_at"] = now.Format(time.RFC3339)
	}
	payload["audit_trail"] = append(
		auditTrailFromPayload(payload),
		approvalAuditEntry(c, action, status, "", now),
	)
	if err := h.savePayload(&row, payload); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update approval request")
		return
	}
	auditAction(c, approvalRequestResource, action, "frontend_records", &row.ID)
	if status == "principal_review" {
		if logs, err := createApprovalRequestedNotificationsTx(
			database.DB,
			c,
			row.ID,
			"Approval request pending",
			fmt.Sprintf("%s submitted an approval request.", c.GetString("role_name")),
		); err == nil {
			enqueuePushNotifications(logs)
		}
	}
	success(c, http.StatusOK, approvalRecordResponse(row), message)
}

func (h *ApprovalRequestHandler) transitionPrincipalDecision(c *gin.Context, status string, reasonRequired bool) {
	row, ok := h.loadScopedRecord(c)
	if !ok {
		return
	}
	if currentRole(c) != "principal" {
		fail(c, http.StatusForbidden, "Only Principal can review approval requests")
		return
	}
	var req struct {
		Reason string `json:"reason"`
		Note   string `json:"note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	reason := strings.TrimSpace(firstNonEmpty(req.Reason, req.Note))
	if reasonRequired && reason == "" {
		fail(c, http.StatusBadRequest, "rejection reason is required")
		return
	}
	payload := frontendPayload(row.Payload)
	requiredAction := "final_approve"
	if status == "rejected" {
		requiredAction = "final_reject"
	}
	if !h.ensureMatrixPermission(c, payload, "principal", requiredAction) {
		return
	}
	currentStatus := normalizeApprovalStatus(stringMapValue(payload["status"]))
	if currentStatus != "principal_review" && currentStatus != "submitted" {
		fail(c, http.StatusBadRequest, "Only submitted requests can be reviewed")
		return
	}
	now := time.Now().UTC()
	payload["status"] = status
	payload["approver_user_id"] = currentUserID(c)
	payload["action_date"] = now.Format(time.RFC3339)
	if status == "rejected" {
		payload["rejection_reason"] = reason
	} else if reason != "" {
		payload["approval_note"] = reason
	}
	payload["audit_trail"] = append(
		auditTrailFromPayload(payload),
		approvalAuditEntry(c, status, status, reason, now),
	)
	if err := h.savePayload(&row, payload); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to review approval request")
		return
	}
	auditAction(c, approvalRequestResource, status, "frontend_records", &row.ID)
	if logs, err := createApprovalDecisionNotificationsTx(
		database.DB,
		c,
		row.CreatedBy,
		row.ID,
		"Approval request "+status,
		fmt.Sprintf("Your approval request was %s.", status),
	); err == nil {
		enqueuePushNotifications(logs)
	}
	success(c, http.StatusOK, approvalRecordResponse(row), "Approval request "+status)
}

func (h *ApprovalRequestHandler) loadScopedRecord(c *gin.Context) (models.FrontendRecord, bool) {
	var row models.FrontendRecord
	query := database.DB.Where(
		"id = ? AND school_id = ? AND resource = ?",
		c.Param("id"),
		scopedSchoolID(c),
		approvalRequestResource,
	)
	if strings.EqualFold(c.GetString("role_name"), "Admin") {
		query = query.Where("created_by = ?", c.GetString("user_id"))
	}
	if err := query.First(&row).Error; err != nil {
		fail(c, http.StatusNotFound, "Approval request not found")
		return models.FrontendRecord{}, false
	}
	return row, true
}

func (h *ApprovalRequestHandler) savePayload(row *models.FrontendRecord, payload gin.H) error {
	encoded, err := jsonMarshal(payload)
	if err != nil {
		return err
	}
	row.Payload = encoded
	return database.DB.Model(&models.FrontendRecord{}).
		Where("id = ? AND school_id = ? AND resource = ?", row.ID, row.SchoolID, approvalRequestResource).
		Update("payload", encoded).Error
}

func (h *ApprovalRequestHandler) ensureMatrixPermission(c *gin.Context, payload gin.H, role, action string) bool {
	moduleKey := normalizeApprovalModule(stringMapValue(payload["module"]))
	if moduleKey == "" {
		fail(c, http.StatusBadRequest, "Approval request is missing module ownership metadata")
		return false
	}
	if !h.matrix.Can(moduleKey, role, action) {
		fail(c, http.StatusForbidden, "Role cannot perform this approval action for the module")
		return false
	}
	return true
}

func (h *ApprovalRequestHandler) applyApprovedOperation(c *gin.Context, tx *gorm.DB, schoolID string, payload gin.H) error {
	module := normalizeApprovalModule(stringMapValue(payload["module"]))
	operation := strings.ToLower(strings.TrimSpace(stringMapValue(payload["operation_type"])))
	switch module {
	case "students":
		if operation == "" {
			payload["action"] = firstNonEmpty(stringMapValue(payload["action"]), "create")
		} else {
			payload["action"] = operation
		}
		if existing := strings.TrimSpace(stringMapValue(payload["entity_id"])); existing != "" {
			payload["student_id"] = existing
		}
		payload["student"] = mapFromInterface(payload["payload_json"])
		studentID, err := applyStudentApproval(tx, schoolID, payload)
		if err != nil {
			return err
		}
		if studentID != "" {
			payload["entity_id"] = studentID
			payload["after_snapshot_json"] = gin.H{"student_id": studentID}
		}
	case "academic_info":
		if operation != "" && operation != "create" && operation != "create_class" {
			return fmt.Errorf("academic_info approval operation %q is not supported", operation)
		}
		classPayload := mapFromInterface(payload["payload_json"])
		for key, value := range classPayload {
			payload[key] = value
		}
		gradeID, sectionIDs, err := createApprovedClass(tx, schoolID, payload)
		if err != nil {
			return err
		}
		payload["entity_id"] = gradeID
		payload["after_snapshot_json"] = gin.H{
			"grade_id":    gradeID,
			"section_ids": sectionIDs,
		}
	case "fees":
		return h.applyFeeApproval(c, tx, schoolID, payload)
	case "reports":
		return fmt.Errorf("reports are view-only and cannot be applied")
	case "staff", "attendance_operations", "timetable", "exams", "communication", "helpdesk", "documents", "user_access":
		return fmt.Errorf("approval apply for %s is not implemented yet", module)
	case "":
		return fmt.Errorf("approval request is missing module")
	default:
		return fmt.Errorf("approval apply for %s is not supported", module)
	}
	_ = c
	return nil
}

func (h *ApprovalRequestHandler) applyFeeApproval(c *gin.Context, tx *gorm.DB, schoolID string, payload gin.H) error {
	operation := strings.ToLower(strings.TrimSpace(firstNonEmpty(
		stringMapValue(payload["operation_type"]),
		"create",
	)))
	data := mapFromInterface(payload["payload_json"])
	switch operation {
	case "approved_payment_request", "approve_payment_request":
		return h.applyPaymentRequestDecision(c, tx, schoolID, payload, data, "approved")
	case "rejected_payment_request", "reject_payment_request":
		return h.applyPaymentRequestDecision(c, tx, schoolID, payload, data, "rejected")
	}
	target := strings.ToLower(strings.TrimSpace(firstNonEmpty(
		approvalPayloadString(data, "target", "fee_target", "entity_type"),
		stringMapValue(payload["entity_type"]),
		"fee_structure",
	)))
	if target != "fee_structure" && target != "structure" {
		return fmt.Errorf("fee approval target %q is not supported", target)
	}
	switch operation {
	case "create", "create_fee_structure", "submit_fee_structure":
		return h.applyFeeStructureCreate(tx, schoolID, payload, data)
	case "update", "update_fee_structure":
		return h.applyFeeStructureUpdate(tx, schoolID, payload, data)
	default:
		return fmt.Errorf("fee approval operation %q is not supported", operation)
	}
}

func (h *ApprovalRequestHandler) applyPaymentRequestDecision(c *gin.Context, tx *gorm.DB, schoolID string, payload gin.H, data map[string]interface{}, status string) error {
	requestID := firstNonEmpty(
		stringMapValue(payload["entity_id"]),
		approvalPayloadString(data, "payment_request_id", "id"),
	)
	if requestID == "" {
		return fmt.Errorf("payment_request_id is required")
	}
	remarks := approvalPayloadString(data, "admin_remarks", "remarks", "reason")
	updated, err := applyParentPaymentRequestDecisionTx(tx, schoolID, currentUserID(c), requestID, status, remarks)
	if err != nil {
		return err
	}
	payload["entity_id"] = updated.ID
	payload["after_snapshot_json"] = gin.H{
		"payment_request_id": updated.ID,
		"payment_id":         stringValue(updated.PaymentID),
		"status":             updated.Status,
		"decided_at":         updated.DecidedAt,
	}
	return nil
}

func (h *ApprovalRequestHandler) applyFeeStructureCreate(tx *gorm.DB, schoolID string, payload gin.H, data map[string]interface{}) error {
	structure := models.FeeStructure{
		SchoolID:       schoolID,
		AcademicYearID: approvalPayloadString(data, "academic_year_id"),
		GradeID:        approvalPayloadString(data, "grade_id", "class_id"),
		FeeCategoryID:  approvalPayloadString(data, "fee_category_id", "fee_type_id"),
		Amount:         approvalPayloadFloat(data, "amount"),
		DueDay:         approvalPayloadInt(data, "due_day"),
		LateFinePerDay: approvalPayloadFloat(data, "late_fine_per_day"),
	}
	if err := validateFeeStructureApprovalRefs(tx, schoolID, structure.AcademicYearID, structure.GradeID, structure.FeeCategoryID); err != nil {
		return err
	}
	if structure.Amount <= 0 {
		return fmt.Errorf("amount must be greater than zero")
	}
	if err := tx.Create(&structure).Error; err != nil {
		return fmt.Errorf("failed to create fee structure: %w", err)
	}
	payload["entity_id"] = structure.ID
	payload["after_snapshot_json"] = gin.H{
		"fee_structure_id": structure.ID,
		"amount":           structure.Amount,
		"due_day":          structure.DueDay,
	}
	return nil
}

func (h *ApprovalRequestHandler) applyFeeStructureUpdate(tx *gorm.DB, schoolID string, payload gin.H, data map[string]interface{}) error {
	id := firstNonEmpty(
		stringMapValue(payload["entity_id"]),
		approvalPayloadString(data, "id", "fee_structure_id"),
	)
	if id == "" {
		return fmt.Errorf("fee_structure_id is required for update")
	}
	var structure models.FeeStructure
	if err := tx.Where("id = ? AND school_id = ?", id, schoolID).First(&structure).Error; err != nil {
		return fmt.Errorf("fee structure not found")
	}
	if value := approvalPayloadString(data, "academic_year_id"); value != "" {
		structure.AcademicYearID = value
	}
	if value := approvalPayloadString(data, "grade_id", "class_id"); value != "" {
		structure.GradeID = value
	}
	if value := approvalPayloadString(data, "fee_category_id", "fee_type_id"); value != "" {
		structure.FeeCategoryID = value
	}
	if value, ok := approvalPayloadOptionalFloat(data, "amount"); ok {
		if value <= 0 {
			return fmt.Errorf("amount must be greater than zero")
		}
		structure.Amount = value
	}
	if value, ok := approvalPayloadOptionalInt(data, "due_day"); ok {
		structure.DueDay = value
	}
	if value, ok := approvalPayloadOptionalFloat(data, "late_fine_per_day"); ok {
		structure.LateFinePerDay = value
	}
	if err := validateFeeStructureApprovalRefs(tx, schoolID, structure.AcademicYearID, structure.GradeID, structure.FeeCategoryID); err != nil {
		return err
	}
	if err := tx.Save(&structure).Error; err != nil {
		return fmt.Errorf("failed to update fee structure: %w", err)
	}
	payload["entity_id"] = structure.ID
	payload["after_snapshot_json"] = gin.H{
		"fee_structure_id": structure.ID,
		"amount":           structure.Amount,
		"due_day":          structure.DueDay,
	}
	return nil
}

func validateFeeStructureApprovalRefs(tx *gorm.DB, schoolID, academicYearID, gradeID, feeCategoryID string) error {
	if strings.TrimSpace(academicYearID) == "" {
		return fmt.Errorf("academic_year_id is required")
	}
	if strings.TrimSpace(gradeID) == "" {
		return fmt.Errorf("grade_id is required")
	}
	if strings.TrimSpace(feeCategoryID) == "" {
		return fmt.Errorf("fee_category_id is required")
	}
	if countRows(tx.Model(&models.AcademicYear{}).Where("id = ? AND school_id = ?", academicYearID, schoolID)) == 0 {
		return fmt.Errorf("academic year must belong to this school")
	}
	if countRows(tx.Model(&models.Grade{}).Where("id = ? AND school_id = ?", gradeID, schoolID)) == 0 {
		return fmt.Errorf("grade must belong to this school")
	}
	if countRows(tx.Model(&models.FeeCategory{}).Where("id = ? AND school_id = ?", feeCategoryID, schoolID)) == 0 {
		return fmt.Errorf("fee category must belong to this school")
	}
	return nil
}

func approvalPayloadString(data map[string]interface{}, keys ...string) string {
	for _, key := range keys {
		value, ok := data[key]
		if !ok || value == nil {
			continue
		}
		switch typed := value.(type) {
		case string:
			if strings.TrimSpace(typed) != "" {
				return strings.TrimSpace(typed)
			}
		default:
			asString := strings.TrimSpace(fmt.Sprint(typed))
			if asString != "" && asString != "<nil>" {
				return asString
			}
		}
	}
	return ""
}

func approvalPayloadFloat(data map[string]interface{}, key string) float64 {
	value, _ := approvalPayloadOptionalFloat(data, key)
	return value
}

func approvalPayloadOptionalFloat(data map[string]interface{}, key string) (float64, bool) {
	value, ok := data[key]
	if !ok || value == nil {
		return 0, false
	}
	switch typed := value.(type) {
	case float64:
		return typed, true
	case float32:
		return float64(typed), true
	case int:
		return float64(typed), true
	case int64:
		return float64(typed), true
	case json.Number:
		parsed, err := typed.Float64()
		return parsed, err == nil
	default:
		parsed, err := strconv.ParseFloat(strings.TrimSpace(fmt.Sprint(value)), 64)
		return parsed, err == nil
	}
}

func approvalPayloadInt(data map[string]interface{}, key string) int {
	value, _ := approvalPayloadOptionalInt(data, key)
	return value
}

func approvalPayloadOptionalInt(data map[string]interface{}, key string) (int, bool) {
	value, ok := data[key]
	if !ok || value == nil {
		return 0, false
	}
	switch typed := value.(type) {
	case int:
		return typed, true
	case int64:
		return int(typed), true
	case float64:
		return int(typed), true
	case json.Number:
		parsed, err := typed.Int64()
		return int(parsed), err == nil
	default:
		parsed, err := strconv.Atoi(strings.TrimSpace(fmt.Sprint(value)))
		return parsed, err == nil
	}
}

type approvalMutationRequest struct {
	AcademicYearID string                 `json:"academic_year_id"`
	Module         string                 `json:"module"`
	OperationType  string                 `json:"operation_type"`
	EntityType     string                 `json:"entity_type"`
	EntityID       string                 `json:"entity_id"`
	Status         string                 `json:"status"`
	Payload        map[string]interface{} `json:"payload_json"`
	BeforeSnapshot map[string]interface{} `json:"before_snapshot_json"`
	AfterSnapshot  map[string]interface{} `json:"after_snapshot_json"`
}

func approvalPayload(c *gin.Context, module policy.ModuleOwnership, req approvalMutationRequest, status string, now time.Time) gin.H {
	entityType := firstNonEmpty(strings.TrimSpace(req.EntityType), module.EntityType)
	return gin.H{
		"school_id":                scopedSchoolID(c),
		"academic_year_id":         strings.TrimSpace(req.AcademicYearID),
		"module":                   module.Key,
		"module_label":             module.Label,
		"operation_type":           strings.TrimSpace(req.OperationType),
		"entity_type":              entityType,
		"entity_id":                strings.TrimSpace(req.EntityID),
		"requested_by_user_id":     currentUserID(c),
		"requested_by_role":        c.GetString("role_name"),
		"approver_user_id":         "",
		"status":                   status,
		"payload_json":             mapOrEmpty(req.Payload),
		"before_snapshot_json":     mapOrEmpty(req.BeforeSnapshot),
		"after_snapshot_json":      mapOrEmpty(req.AfterSnapshot),
		"rejection_reason":         "",
		"change_request_note":      "",
		"applied_at":               "",
		"created_at":               now.Format(time.RFC3339),
		"updated_at":               now.Format(time.RFC3339),
		"type":                     module.EntityType,
		"title":                    approvalTitle(module, req),
		"summary":                  approvalSummary(module, req),
		"requester_name":           firstNonEmpty(c.GetString("email"), "School Admin"),
		"requester_role":           "Admin",
		"risk_level":               module.RiskLevel,
		"decisionPath":             "",
		"backend_resource":         module.BackendResource,
		"ownership_matrix_version": policy.MustLoadOwnershipMatrix().Version,
	}
}

func approvalRecordResponse(row models.FrontendRecord) gin.H {
	payload := frontendRecordResponse(row)
	if strings.TrimSpace(stringMapValue(payload["status"])) == "" {
		payload["status"] = "draft"
	}
	if strings.TrimSpace(stringMapValue(payload["decisionPath"])) == "" {
		payload["decisionPath"] = "/approvals/" + row.ID
	}
	return payload
}

func approvalAuditEntry(c *gin.Context, action, status, note string, at time.Time) gin.H {
	return gin.H{
		"action":     action,
		"status":     status,
		"note":       strings.TrimSpace(note),
		"user_id":    currentUserID(c),
		"role":       c.GetString("role_name"),
		"created_at": at.Format(time.RFC3339),
	}
}

func auditTrailFromPayload(payload gin.H) []gin.H {
	raw := payload["audit_trail"]
	switch typed := raw.(type) {
	case []gin.H:
		return typed
	case []interface{}:
		out := make([]gin.H, 0, len(typed))
		for _, item := range typed {
			out = append(out, gin.H(mapFromInterface(item)))
		}
		return out
	default:
		return []gin.H{}
	}
}

func normalizeApprovalModule(module string) string {
	return strings.ReplaceAll(strings.ToLower(strings.TrimSpace(module)), " ", "_")
}

func normalizeApprovalStatus(status string) string {
	return strings.ReplaceAll(strings.ToLower(strings.TrimSpace(status)), " ", "_")
}

func approvalTitle(module policy.ModuleOwnership, req approvalMutationRequest) string {
	action := strings.TrimSpace(req.OperationType)
	if action == "" {
		action = "request"
	}
	return fmt.Sprintf("%s %s", module.Label, action)
}

func approvalSummary(module policy.ModuleOwnership, req approvalMutationRequest) string {
	entity := firstNonEmpty(strings.TrimSpace(req.EntityType), module.EntityType)
	action := firstNonEmpty(strings.TrimSpace(req.OperationType), "change")
	return fmt.Sprintf("%s %s awaiting Principal approval.", module.Label, action+" "+entity)
}

func mapOrEmpty(value map[string]interface{}) gin.H {
	if value == nil {
		return gin.H{}
	}
	return gin.H(value)
}

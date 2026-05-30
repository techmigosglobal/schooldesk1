package services

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	"school-backend/internal/models"

	"gorm.io/gorm"
)

// WorkflowSessionStore owns persistence for assistant workflow sessions and
// logs. Business execution stays in handlers/services for the target ERP area.
type WorkflowSessionStore struct {
	db *gorm.DB
}

// WorkflowSessionInput contains the required fields for a new workflow draft.
type WorkflowSessionInput struct {
	SchoolID       string
	UserID         string
	UserRole       string
	WorkflowType   string
	Title          string
	Status         string
	CurrentStepID  string
	CompletedSteps []string
	PendingSteps   []string
	DraftData      map[string]interface{}
	SourceCommand  string
}

// WorkflowSessionPatch contains mutable session state saved as a draft moves.
type WorkflowSessionPatch struct {
	Status            string
	CurrentStepID     string
	CompletedSteps    []string
	PendingSteps      []string
	DraftData         map[string]interface{}
	ValidationSummary map[string]interface{}
	ReviewSummary     map[string]interface{}
	RollbackState     string
	LastError         string
	ConfirmedAt       *time.Time
	ExecutedAt        *time.Time
	CanceledAt        *time.Time
}

// NewWorkflowSessionStore creates a store backed by the provided GORM handle.
func NewWorkflowSessionStore(db *gorm.DB) *WorkflowSessionStore {
	return &WorkflowSessionStore{db: db}
}

// Create opens a new assistant workflow session.
func (s *WorkflowSessionStore) Create(ctx context.Context, input WorkflowSessionInput) (models.WorkflowSession, error) {
	status := strings.TrimSpace(input.Status)
	if status == "" {
		status = "draft"
	}
	row := models.WorkflowSession{
		SchoolID:       strings.TrimSpace(input.SchoolID),
		UserID:         strings.TrimSpace(input.UserID),
		UserRole:       strings.ToLower(strings.TrimSpace(input.UserRole)),
		WorkflowType:   strings.TrimSpace(input.WorkflowType),
		Title:          strings.TrimSpace(input.Title),
		Status:         status,
		CurrentStepID:  strings.TrimSpace(input.CurrentStepID),
		CompletedSteps: encodeWorkflowJSON(input.CompletedSteps),
		PendingSteps:   encodeWorkflowJSON(input.PendingSteps),
		DraftData:      encodeWorkflowJSON(input.DraftData),
		SourceCommand:  strings.TrimSpace(input.SourceCommand),
		RollbackState:  "not_started",
	}
	if err := s.db.WithContext(ctx).Create(&row).Error; err != nil {
		return models.WorkflowSession{}, err
	}
	return row, nil
}

// List returns the user's assistant sessions for the current school.
func (s *WorkflowSessionStore) List(ctx context.Context, schoolID, userID string, statuses []string) ([]models.WorkflowSession, error) {
	var rows []models.WorkflowSession
	query := s.db.WithContext(ctx).
		Where("school_id = ? AND user_id = ?", strings.TrimSpace(schoolID), strings.TrimSpace(userID)).
		Order("updated_at DESC")
	cleanStatuses := make([]string, 0, len(statuses))
	for _, status := range statuses {
		status = strings.TrimSpace(status)
		if status != "" {
			cleanStatuses = append(cleanStatuses, status)
		}
	}
	if len(cleanStatuses) > 0 {
		query = query.Where("status IN ?", cleanStatuses)
	}
	if err := query.Find(&rows).Error; err != nil {
		return nil, err
	}
	return rows, nil
}

// Get fetches one assistant session scoped to the current school.
func (s *WorkflowSessionStore) Get(ctx context.Context, schoolID, sessionID string) (models.WorkflowSession, error) {
	var row models.WorkflowSession
	if err := s.db.WithContext(ctx).
		Preload("Logs", func(db *gorm.DB) *gorm.DB {
			return db.Order("created_at ASC")
		}).
		First(&row, "id = ? AND school_id = ?", strings.TrimSpace(sessionID), strings.TrimSpace(schoolID)).Error; err != nil {
		return models.WorkflowSession{}, err
	}
	return row, nil
}

// Patch updates mutable session state.
func (s *WorkflowSessionStore) Patch(ctx context.Context, sessionID string, patch WorkflowSessionPatch) (models.WorkflowSession, error) {
	updates := map[string]interface{}{}
	if strings.TrimSpace(patch.Status) != "" {
		updates["status"] = strings.TrimSpace(patch.Status)
	}
	if strings.TrimSpace(patch.CurrentStepID) != "" {
		updates["current_step_id"] = strings.TrimSpace(patch.CurrentStepID)
	}
	if patch.CompletedSteps != nil {
		updates["completed_steps"] = encodeWorkflowJSON(patch.CompletedSteps)
	}
	if patch.PendingSteps != nil {
		updates["pending_steps"] = encodeWorkflowJSON(patch.PendingSteps)
	}
	if patch.DraftData != nil {
		updates["draft_data"] = encodeWorkflowJSON(patch.DraftData)
	}
	if patch.ValidationSummary != nil {
		updates["validation_summary"] = encodeWorkflowJSON(patch.ValidationSummary)
	}
	if patch.ReviewSummary != nil {
		updates["review_summary"] = encodeWorkflowJSON(patch.ReviewSummary)
	}
	if strings.TrimSpace(patch.RollbackState) != "" {
		updates["rollback_state"] = strings.TrimSpace(patch.RollbackState)
	}
	if patch.LastError != "" {
		updates["last_error"] = patch.LastError
	}
	if patch.ConfirmedAt != nil {
		updates["confirmed_at"] = patch.ConfirmedAt
	}
	if patch.ExecutedAt != nil {
		updates["executed_at"] = patch.ExecutedAt
	}
	if patch.CanceledAt != nil {
		updates["canceled_at"] = patch.CanceledAt
	}
	if len(updates) == 0 {
		var row models.WorkflowSession
		return row, s.db.WithContext(ctx).First(&row, "id = ?", sessionID).Error
	}
	updates["updated_at"] = time.Now().UTC()
	if err := s.db.WithContext(ctx).Model(&models.WorkflowSession{}).
		Where("id = ?", strings.TrimSpace(sessionID)).
		Updates(updates).Error; err != nil {
		return models.WorkflowSession{}, err
	}
	var row models.WorkflowSession
	if err := s.db.WithContext(ctx).Preload("Logs", func(db *gorm.DB) *gorm.DB {
		return db.Order("created_at ASC")
	}).First(&row, "id = ?", strings.TrimSpace(sessionID)).Error; err != nil {
		return models.WorkflowSession{}, err
	}
	return row, nil
}

// Log appends a workflow event.
func (s *WorkflowSessionStore) Log(ctx context.Context, event models.WorkflowLog) error {
	return s.db.WithContext(ctx).Create(&event).Error
}

// DecodeWorkflowMap decodes a JSON object stored on a session.
func DecodeWorkflowMap(raw string) map[string]interface{} {
	result := map[string]interface{}{}
	if strings.TrimSpace(raw) == "" {
		return result
	}
	_ = json.Unmarshal([]byte(raw), &result)
	return result
}

// DecodeWorkflowStringSlice decodes a JSON string slice stored on a session.
func DecodeWorkflowStringSlice(raw string) []string {
	var result []string
	if strings.TrimSpace(raw) == "" {
		return []string{}
	}
	_ = json.Unmarshal([]byte(raw), &result)
	if result == nil {
		return []string{}
	}
	return result
}

func encodeWorkflowJSON(value interface{}) string {
	if value == nil {
		return ""
	}
	encoded, err := json.Marshal(value)
	if err != nil {
		return ""
	}
	return string(encoded)
}

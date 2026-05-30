package models

import "time"

// WorkflowSession stores deterministic assistant workflow draft and execution
// state. The assistant layer is intentionally additive to the ERP tables.
type WorkflowSession struct {
	BaseModel
	SchoolID          string        `gorm:"type:text;not null;index" json:"school_id"`
	UserID            string        `gorm:"type:text;not null;index" json:"user_id"`
	UserRole          string        `gorm:"type:text;not null;index" json:"user_role"`
	WorkflowType      string        `gorm:"type:text;not null;index" json:"workflow_type"`
	Title             string        `gorm:"type:text;not null" json:"title"`
	Status            string        `gorm:"type:text;not null;default:'draft';index" json:"status"`
	CurrentStepID     string        `gorm:"type:text" json:"current_step_id"`
	CompletedSteps    string        `gorm:"type:text" json:"completed_steps"`
	PendingSteps      string        `gorm:"type:text" json:"pending_steps"`
	DraftData         string        `gorm:"type:text" json:"draft_data"`
	ValidationSummary string        `gorm:"type:text" json:"validation_summary"`
	ReviewSummary     string        `gorm:"type:text" json:"review_summary"`
	SourceCommand     string        `gorm:"type:text" json:"source_command"`
	RollbackState     string        `gorm:"type:text;default:'not_started'" json:"rollback_state"`
	LastError         string        `gorm:"type:text" json:"last_error"`
	ConfirmedAt       *time.Time    `json:"confirmed_at,omitempty"`
	ExecutedAt        *time.Time    `json:"executed_at,omitempty"`
	CanceledAt        *time.Time    `json:"canceled_at,omitempty"`
	Logs              []WorkflowLog `gorm:"foreignKey:SessionID" json:"logs,omitempty"`
}

// TableName pins the database table required by the assistant feature.
func (WorkflowSession) TableName() string {
	return "workflow_sessions"
}

// WorkflowLog records assistant validation, draft, execution, rollback, and
// audit bridge events without mixing transient assistant state into ERP tables.
type WorkflowLog struct {
	BaseModel
	SchoolID   string `gorm:"type:text;not null;index" json:"school_id"`
	SessionID  string `gorm:"type:text;not null;index" json:"session_id"`
	UserID     string `gorm:"type:text;not null;index" json:"user_id"`
	EventType  string `gorm:"type:text;not null;index" json:"event_type"`
	StepID     string `gorm:"type:text" json:"step_id"`
	Message    string `gorm:"type:text" json:"message"`
	Payload    string `gorm:"type:text" json:"payload"`
	EntityType string `gorm:"type:text" json:"entity_type"`
	EntityID   string `gorm:"type:text" json:"entity_id"`
}

// TableName pins the append-only assistant workflow event log table.
func (WorkflowLog) TableName() string {
	return "workflow_logs"
}

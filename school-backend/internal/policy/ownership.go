package policy

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"strings"
)

//go:embed admin_principal_ownership_matrix.json
var ownershipMatrixBytes []byte

type OperationPermission struct {
	View                    bool `json:"view"`
	CreateDraft             bool `json:"create_draft"`
	SubmitForApproval       bool `json:"submit_for_approval"`
	EditPendingRequest      bool `json:"edit_pending_request"`
	CancelOwnPendingRequest bool `json:"cancel_own_pending_request"`
	FinalApprove            bool `json:"final_approve"`
	FinalReject             bool `json:"final_reject"`
	DirectPublish           bool `json:"direct_publish"`
	DeleteActiveRecord      bool `json:"delete_active_record"`
}

type ModuleOwnership struct {
	Key             string              `json:"key"`
	Label           string              `json:"label"`
	FrontendRoute   string              `json:"frontend_route"`
	BackendResource string              `json:"backend_resource"`
	EntityType      string              `json:"entity_type"`
	RiskLevel       string              `json:"risk_level"`
	Admin           OperationPermission `json:"admin"`
	Principal       OperationPermission `json:"principal"`
}

type OwnershipMatrix struct {
	Version  int               `json:"version"`
	Statuses []string          `json:"statuses"`
	Modules  []ModuleOwnership `json:"modules"`
}

func LoadOwnershipMatrix() (OwnershipMatrix, error) {
	var matrix OwnershipMatrix
	if err := json.Unmarshal(ownershipMatrixBytes, &matrix); err != nil {
		return OwnershipMatrix{}, err
	}
	if err := matrix.Validate(); err != nil {
		return OwnershipMatrix{}, err
	}
	return matrix, nil
}

func MustLoadOwnershipMatrix() OwnershipMatrix {
	matrix, err := LoadOwnershipMatrix()
	if err != nil {
		panic(err)
	}
	return matrix
}

func (m OwnershipMatrix) Module(key string) (ModuleOwnership, bool) {
	normalized := normalize(key)
	for _, module := range m.Modules {
		if normalize(module.Key) == normalized || normalize(module.Label) == normalized {
			return module, true
		}
	}
	return ModuleOwnership{}, false
}

func (m OwnershipMatrix) Permission(moduleKey, role string) (OperationPermission, bool) {
	module, ok := m.Module(moduleKey)
	if !ok {
		return OperationPermission{}, false
	}
	switch normalize(role) {
	case "admin":
		return module.Admin, true
	case "principal":
		return module.Principal, true
	default:
		return OperationPermission{}, false
	}
}

func (m OwnershipMatrix) Can(moduleKey, role, action string) bool {
	permission, ok := m.Permission(moduleKey, role)
	if !ok {
		return false
	}
	switch normalize(action) {
	case "view":
		return permission.View
	case "createdraft", "create_draft", "draft":
		return permission.CreateDraft
	case "submitforapproval", "submit_for_approval", "submit":
		return permission.SubmitForApproval
	case "editpendingrequest", "edit_pending_request", "edit_pending":
		return permission.EditPendingRequest
	case "cancelownpendingrequest", "cancel_own_pending_request", "cancel":
		return permission.CancelOwnPendingRequest
	case "finalapprove", "final_approve", "approve":
		return permission.FinalApprove
	case "finalreject", "final_reject", "reject":
		return permission.FinalReject
	case "directpublish", "direct_publish", "publish":
		return permission.DirectPublish
	case "deleteactiverecord", "delete_active_record", "delete":
		return permission.DeleteActiveRecord
	default:
		return false
	}
}

func (m OwnershipMatrix) Validate() error {
	if m.Version <= 0 {
		return fmt.Errorf("ownership matrix version is required")
	}
	if len(m.Statuses) == 0 {
		return fmt.Errorf("ownership matrix statuses are required")
	}
	seen := map[string]struct{}{}
	for _, module := range m.Modules {
		key := normalize(module.Key)
		if key == "" {
			return fmt.Errorf("module key is required")
		}
		if _, exists := seen[key]; exists {
			return fmt.Errorf("duplicate module key %s", module.Key)
		}
		seen[key] = struct{}{}
		if strings.TrimSpace(module.Label) == "" ||
			strings.TrimSpace(module.FrontendRoute) == "" ||
			strings.TrimSpace(module.BackendResource) == "" ||
			strings.TrimSpace(module.EntityType) == "" {
			return fmt.Errorf("module %s is missing required metadata", module.Key)
		}
		if module.Admin.FinalApprove || module.Admin.FinalReject ||
			module.Admin.DirectPublish || module.Admin.DeleteActiveRecord {
			return fmt.Errorf("admin cannot hold final rights for module %s", module.Key)
		}
	}
	return nil
}

func normalize(value string) string {
	return strings.ReplaceAll(strings.ToLower(strings.TrimSpace(value)), " ", "_")
}

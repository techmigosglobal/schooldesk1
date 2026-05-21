package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"school-backend/internal/database"
	"school-backend/internal/models"
)

func TestReportExportCreatesArtifactAndAuditReadyRow(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	t.Cleanup(func() { _ = os.RemoveAll("uploads/exports/" + f.schoolID) })
	handler := NewReportExportHandler()
	router := scopedPolicyRouter("Admin", "user-policy-admin", "", "", "admin@policy.test", f.schoolID)
	router.POST("/reports/exports", handler.Create("general_reports"))
	router.GET("/reports/exports/:id", handler.Get)

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(
		http.MethodPost,
		"/reports/exports",
		strings.NewReader(`{"report_title":"Operational Summary","format":"csv","scope":"admin","parameters":{"month":"2026-05"}}`),
	))
	if response.Code != http.StatusCreated {
		t.Fatalf("create export status=%d body=%s", response.Code, response.Body.String())
	}
	var body struct {
		Data models.ReportExport `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode export: %v", err)
	}
	if body.Data.Status != "completed" || body.Data.DownloadURL == "" || body.Data.ArtifactPath == "" {
		t.Fatalf("expected completed export with artifact, got %+v", body.Data)
	}
	if _, err := os.Stat(strings.TrimPrefix(body.Data.ArtifactPath, "/")); err != nil {
		t.Fatalf("artifact missing: %v path=%s", err, body.Data.ArtifactPath)
	}

	var rows int64
	database.DB.Model(&models.AuditLog{}).
		Where("module = ? AND action = ? AND entity_id = ?", "reports", "export", body.Data.ID).
		Count(&rows)
	if rows != 1 {
		t.Fatalf("expected one audit row, got %d", rows)
	}

	getResp := httptest.NewRecorder()
	router.ServeHTTP(getResp, httptest.NewRequest(http.MethodGet, "/reports/exports/"+body.Data.ID, nil))
	if getResp.Code != http.StatusOK {
		t.Fatalf("get export status=%d body=%s", getResp.Code, getResp.Body.String())
	}
}

func TestReportExportRejectsUnsupportedFormat(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	handler := NewReportExportHandler()
	router := scopedPolicyRouter("Admin", "user-policy-admin", "", "", "admin@policy.test", f.schoolID)
	router.POST("/reports/exports", handler.Create("general_reports"))

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(
		http.MethodPost,
		"/reports/exports",
		strings.NewReader(`{"report_title":"Bad Export","format":"exe"}`),
	))
	if response.Code != http.StatusBadRequest {
		t.Fatalf("unsupported format status=%d body=%s", response.Code, response.Body.String())
	}
}

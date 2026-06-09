package handlers

import (
	"archive/zip"
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"school-backend/internal/models"
)

func TestReportXLSXProducesReadableWorkbook(t *testing.T) {
	row := models.ReportExport{
		BaseModel:   models.BaseModel{ID: "export-xlsx"},
		SchoolID:    "school-suite",
		Category:    "exam_report_cards",
		ReportTitle: "Excel analytics",
		Format:      "xlsx",
		Scope:       "principal",
		RequestedAt: time.Date(2026, 6, 9, 10, 0, 0, 0, time.UTC),
	}

	artifact, err := reportXLSX(row, map[string]interface{}{
		"report_type":    "exam_report",
		"published_only": true,
	})
	if err != nil {
		t.Fatalf("reportXLSX returned error: %v", err)
	}

	reader, err := zip.NewReader(bytes.NewReader(artifact), int64(len(artifact)))
	if err != nil {
		t.Fatalf("xlsx artifact is not a readable zip: %v", err)
	}
	contents := unzipText(t, reader, "xl/worksheets/sheet1.xml")
	for _, want := range []string{"Excel analytics", "exam_report_cards", "published_only"} {
		if !strings.Contains(contents, want) {
			t.Fatalf("worksheet does not contain %q: %s", want, contents)
		}
	}
	if !zipHasFile(reader, "[Content_Types].xml") || !zipHasFile(reader, "xl/workbook.xml") {
		t.Fatal("xlsx artifact is missing required workbook metadata")
	}
}

func TestWriteReportArtifactSupportsXLSXFormat(t *testing.T) {
	originalDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	tempDir := t.TempDir()
	if err := os.Chdir(tempDir); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chdir(originalDir) })

	row := models.ReportExport{
		BaseModel:   models.BaseModel{ID: "export-file"},
		SchoolID:    "school-suite",
		Category:    "exam_report_cards",
		ReportTitle: "Principal Result Analytics",
		Format:      "xlsx",
	}
	path, url, err := writeReportArtifact(row, map[string]interface{}{"source": "principal_exam_reports"})
	if err != nil {
		t.Fatalf("writeReportArtifact returned error: %v", err)
	}
	if !strings.HasSuffix(path, ".xlsx") || !strings.HasSuffix(url, ".xlsx") {
		t.Fatalf("expected xlsx artifact path and URL, got %q and %q", path, url)
	}
	if _, err := os.Stat(filepath.Join(tempDir, strings.TrimPrefix(path, "/"))); err != nil {
		t.Fatalf("xlsx artifact was not written: %v", err)
	}
}

func unzipText(t *testing.T, reader *zip.Reader, name string) string {
	t.Helper()
	for _, file := range reader.File {
		if file.Name != name {
			continue
		}
		handle, err := file.Open()
		if err != nil {
			t.Fatal(err)
		}
		defer handle.Close()
		buffer := new(bytes.Buffer)
		if _, err := buffer.ReadFrom(handle); err != nil {
			t.Fatal(err)
		}
		return buffer.String()
	}
	t.Fatalf("zip file %q not found", name)
	return ""
}

func zipHasFile(reader *zip.Reader, name string) bool {
	for _, file := range reader.File {
		if file.Name == name {
			return true
		}
	}
	return false
}

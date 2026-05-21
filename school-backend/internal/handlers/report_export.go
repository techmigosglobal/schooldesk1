package handlers

import (
	"bytes"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
)

type ReportExportHandler struct{}

func NewReportExportHandler() *ReportExportHandler {
	return &ReportExportHandler{}
}

func (h *ReportExportHandler) List(category string) gin.HandlerFunc {
	return func(c *gin.Context) {
		page, pageSize := parsePagination(c)
		query := database.DB.
			Model(&models.ReportExport{}).
			Where("school_id = ? AND category = ?", scopedSchoolID(c), category)
		if status := strings.TrimSpace(c.Query("status")); status != "" {
			query = query.Where("status = ?", strings.ToLower(status))
		}

		var total int64
		if err := query.Count(&total).Error; err != nil {
			fail(c, http.StatusInternalServerError, "Failed to count report exports")
			return
		}
		var rows []models.ReportExport
		if err := query.Order("created_at DESC").
			Offset((page - 1) * pageSize).
			Limit(pageSize).
			Find(&rows).Error; err != nil {
			fail(c, http.StatusInternalServerError, "Failed to list report exports")
			return
		}
		c.JSON(http.StatusOK, paginationResult(page, pageSize, total, rows))
	}
}

func (h *ReportExportHandler) Get(c *gin.Context) {
	var row models.ReportExport
	if err := database.DB.First(&row, "id = ? AND school_id = ?", c.Param("id"), scopedSchoolID(c)).Error; err != nil {
		fail(c, http.StatusNotFound, "Report export not found")
		return
	}
	success(c, http.StatusOK, row, "")
}

func (h *ReportExportHandler) Create(category string) gin.HandlerFunc {
	return func(c *gin.Context) {
		payload := map[string]interface{}{}
		if err := c.ShouldBindJSON(&payload); err != nil {
			fail(c, http.StatusBadRequest, err.Error())
			return
		}
		format := strings.ToLower(strings.TrimSpace(textPayload(payload, "format")))
		if format == "" {
			fail(c, http.StatusBadRequest, "format is required")
			return
		}
		if format != "pdf" && format != "csv" && format != "json" {
			fail(c, http.StatusBadRequest, "format must be pdf, csv, or json")
			return
		}
		title := firstPayloadText(payload, "report_title", "report", "title", "name")
		if title == "" {
			title = "School report export"
		}
		parameters, _ := json.Marshal(payload)
		now := time.Now().UTC()
		row := models.ReportExport{
			SchoolID:      scopedSchoolID(c),
			Category:      category,
			ReportTitle:   title,
			ReportType:    firstPayloadText(payload, "report_type", "type"),
			Format:        format,
			Scope:         textPayload(payload, "scope"),
			Parameters:    string(parameters),
			Status:        "processing",
			RequestedBy:   currentUserID(c),
			RequestedRole: currentRole(c),
			RequestedAt:   now,
		}
		if err := database.DB.Create(&row).Error; err != nil {
			fail(c, http.StatusInternalServerError, "Failed to create report export")
			return
		}

		artifactPath, downloadURL, err := writeReportArtifact(row, payload)
		completedAt := time.Now().UTC()
		row.CompletedAt = &completedAt
		if err != nil {
			row.Status = "failed"
			row.ErrorMessage = err.Error()
			_ = database.DB.Save(&row).Error
			id := row.ID
			auditAction(c, "reports", "export_failed", "report_exports", &id)
			success(c, http.StatusCreated, row, "Report export request recorded but artifact generation failed")
			return
		}
		row.Status = "completed"
		row.ArtifactPath = artifactPath
		row.DownloadURL = downloadURL
		if err := database.DB.Save(&row).Error; err != nil {
			fail(c, http.StatusInternalServerError, "Failed to update report export")
			return
		}
		id := row.ID
		auditAction(c, "reports", "export", "report_exports", &id)
		success(c, http.StatusCreated, row, "Report export generated")
	}
}

func writeReportArtifact(row models.ReportExport, payload map[string]interface{}) (string, string, error) {
	dir := filepath.Join("uploads", "exports", row.SchoolID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		log.Printf("report export storage preparation failed for school %s: %v", row.SchoolID, err)
		return "", "", err
	}
	filename := sanitizeFilename(row.ReportTitle) + "_" + row.ID + "." + row.Format
	path := filepath.Join(dir, filename)
	switch row.Format {
	case "csv":
		if err := os.WriteFile(path, reportCSV(row, payload), 0o644); err != nil {
			log.Printf("report export csv write failed for export %s: %v", row.ID, err)
			return "", "", err
		}
	case "pdf":
		if err := os.WriteFile(path, reportPDF(row, payload), 0o644); err != nil {
			log.Printf("report export pdf write failed for export %s: %v", row.ID, err)
			return "", "", err
		}
	default:
		raw, _ := json.MarshalIndent(gin.H{"export": row, "payload": payload}, "", "  ")
		if err := os.WriteFile(path, raw, 0o644); err != nil {
			log.Printf("report export json write failed for export %s: %v", row.ID, err)
			return "", "", err
		}
	}
	artifactPath := "/" + filepath.ToSlash(path)
	downloadURL := "/uploads/exports/" + row.SchoolID + "/" + filename
	return artifactPath, downloadURL, nil
}

func reportCSV(row models.ReportExport, payload map[string]interface{}) []byte {
	var buffer bytes.Buffer
	writer := csv.NewWriter(&buffer)
	_ = writer.Write([]string{"field", "value"})
	_ = writer.Write([]string{"report_title", row.ReportTitle})
	_ = writer.Write([]string{"category", row.Category})
	_ = writer.Write([]string{"format", row.Format})
	_ = writer.Write([]string{"scope", row.Scope})
	for key, value := range payload {
		_ = writer.Write([]string{key, fmt.Sprint(value)})
	}
	writer.Flush()
	return buffer.Bytes()
}

func reportPDF(row models.ReportExport, payload map[string]interface{}) []byte {
	body := []string{
		"SchoolDesk report export",
		"Title: " + row.ReportTitle,
		"Category: " + row.Category,
		"Format: " + row.Format,
		"Requested: " + row.RequestedAt.Format(time.RFC3339),
	}
	if len(payload) > 0 {
		body = append(body, "Parameters recorded in backend export metadata.")
	}
	return minimalPDF(row.ReportTitle, body)
}

func minimalPDF(title string, lines []string) []byte {
	var content strings.Builder
	content.WriteString("BT\n/F1 18 Tf\n50 760 Td\n(" + pdfEscape(title) + ") Tj\n")
	content.WriteString("/F1 11 Tf\n0 -28 Td\n")
	for _, line := range lines {
		content.WriteString("(" + pdfEscape(line) + ") Tj\n0 -16 Td\n")
	}
	content.WriteString("ET\n")
	stream := content.String()
	objects := []string{
		"<< /Type /Catalog /Pages 2 0 R >>",
		"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
		"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
		"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
		fmt.Sprintf("<< /Length %d >>\nstream\n%sendstream", len(stream), stream),
	}
	var buffer bytes.Buffer
	buffer.WriteString("%PDF-1.4\n")
	offsets := make([]int, 0, len(objects)+1)
	offsets = append(offsets, 0)
	for index, object := range objects {
		offsets = append(offsets, buffer.Len())
		buffer.WriteString(fmt.Sprintf("%d 0 obj\n%s\nendobj\n", index+1, object))
	}
	xrefOffset := buffer.Len()
	buffer.WriteString(fmt.Sprintf("xref\n0 %d\n0000000000 65535 f \n", len(objects)+1))
	for _, offset := range offsets[1:] {
		buffer.WriteString(fmt.Sprintf("%010d 00000 n \n", offset))
	}
	buffer.WriteString(fmt.Sprintf("trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", len(objects)+1, xrefOffset))
	return buffer.Bytes()
}

func sanitizeFilename(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	value = regexp.MustCompile(`[^a-z0-9]+`).ReplaceAllString(value, "_")
	value = strings.Trim(value, "_")
	if value == "" {
		return "report_export"
	}
	if len(value) > 60 {
		return value[:60]
	}
	return value
}

func pdfEscape(value string) string {
	value = strings.ReplaceAll(value, `\`, `\\`)
	value = strings.ReplaceAll(value, "(", `\(`)
	value = strings.ReplaceAll(value, ")", `\)`)
	return value
}

func firstPayloadText(payload map[string]interface{}, keys ...string) string {
	for _, key := range keys {
		if value := textPayload(payload, key); value != "" {
			return value
		}
	}
	return ""
}

func textPayload(payload map[string]interface{}, key string) string {
	value, ok := payload[key]
	if !ok || value == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(value))
}

package handlers

import (
	"archive/zip"
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
		format, supportedFormat := normalizeReportFormat(textPayload(payload, "format"))
		if format == "" {
			fail(c, http.StatusBadRequest, "format is required")
			return
		}
		if !supportedFormat {
			fail(c, http.StatusBadRequest, "format must be pdf, csv, json, xlsx, or excel")
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

func normalizeReportFormat(value string) (string, bool) {
	format := strings.ToLower(strings.TrimSpace(value))
	switch format {
	case "":
		return "", false
	case "excel":
		return "xlsx", true
	case "pdf", "csv", "json", "xlsx":
		return format, true
	default:
		return format, false
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
	case "xlsx":
		artifact, err := reportXLSX(row, payload)
		if err != nil {
			log.Printf("report export xlsx generation failed for export %s: %v", row.ID, err)
			return "", "", err
		}
		if err := os.WriteFile(path, artifact, 0o644); err != nil {
			log.Printf("report export xlsx write failed for export %s: %v", row.ID, err)
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
	reportRows := reportArtifactRows(row, payload)
	for _, cells := range reportRows {
		_ = writer.Write(cells)
	}
	writer.Flush()
	return buffer.Bytes()
}

func reportXLSX(row models.ReportExport, payload map[string]interface{}) ([]byte, error) {
	var buffer bytes.Buffer
	archive := zip.NewWriter(&buffer)
	files := map[string]string{
		"[Content_Types].xml":        xlsxContentTypes(),
		"_rels/.rels":                xlsxRels(),
		"xl/workbook.xml":            xlsxWorkbook(),
		"xl/_rels/workbook.xml.rels": xlsxWorkbookRels(),
		"xl/worksheets/sheet1.xml":   xlsxSheet(row, payload),
	}
	for name, body := range files {
		if err := writeZipFile(archive, name, body); err != nil {
			_ = archive.Close()
			return nil, err
		}
	}
	if err := archive.Close(); err != nil {
		return nil, err
	}
	return buffer.Bytes(), nil
}

func reportPDF(row models.ReportExport, payload map[string]interface{}) []byte {
	rows := reportArtifactRows(row, payload)
	var content strings.Builder
	generatedAt := row.RequestedAt
	if generatedAt.IsZero() {
		generatedAt = time.Now().UTC()
	}

	content.WriteString("0.09 0.24 0.42 rg\n0 742 612 50 re f\n")
	pdfTextAtColor(&content, "F2", 20, 42, 762, row.ReportTitle, "1 1 1")
	pdfTextAtColor(&content, "F1", 10, 42, 746, "Generated: "+generatedAt.Format("02 Jan 2006, 03:04 PM UTC"), "0.88 0.94 1")

	pdfSectionTitle(&content, 42, 710, "Report Details")
	details := [][]string{
		{"Report Type", reportPDFLabel(firstReportPDFText(row.ReportType, textPayload(payload, "report_type"), "export"))},
		{"Category", reportPDFLabel(row.Category)},
		{"Format", strings.ToUpper(row.Format)},
		{"Scope", reportPDFLabel(row.Scope)},
		{"Requested By", reportPDFLabel(firstReportPDFText(row.RequestedRole, row.RequestedBy, "system"))},
	}
	if academicYear := firstReportPDFText(textPayload(payload, "academic_year"), textPayload(payload, "academic_year_id")); academicYear != "" {
		details = append(details, []string{"Academic Year", academicYear})
	}
	drawKeyValueGrid(&content, details, 42, 672)

	pdfSectionTitle(&content, 42, 520, "Data Table")
	drawReportTable(&content, rows, 42, 488)
	pdfTextAt(&content, "F1", 8, 42, 34, "SchoolDesk ERP - Page 1 - Export ID "+row.ID)
	stream := content.String()
	objects := []string{
		"<< /Type /Catalog /Pages 2 0 R >>",
		"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
		"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>",
		"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
		"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>",
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

func pdfSectionTitle(content *strings.Builder, x, y float64, title string) {
	content.WriteString("0.89 0.94 1 rg\n")
	content.WriteString(fmt.Sprintf("%.1f %.1f 528 28 re f\n", x, y-18))
	content.WriteString("0.12 0.38 0.82 RG\n1 w\n")
	content.WriteString(fmt.Sprintf("%.1f %.1f 528 28 re S\n", x, y-18))
	pdfTextAt(content, "F2", 13, x+12, y-1, title)
}

func drawKeyValueGrid(content *strings.Builder, rows [][]string, x, y float64) {
	const rowHeight = 22.0
	for index, row := range rows {
		rowY := y - float64(index)*rowHeight
		content.WriteString("0.98 0.99 1 rg\n")
		content.WriteString(fmt.Sprintf("%.1f %.1f 528 %.1f re f\n", x, rowY-rowHeight+4, rowHeight))
		content.WriteString("0.82 0.88 0.95 RG\n0.7 w\n")
		content.WriteString(fmt.Sprintf("%.1f %.1f 528 %.1f re S\n", x, rowY-rowHeight+4, rowHeight))
		pdfTextAt(content, "F2", 9, x+10, rowY-10, pdfTruncate(row[0], 26))
		if len(row) > 1 {
			pdfTextAt(content, "F1", 9, x+180, rowY-10, pdfTruncate(row[1], 55))
		}
	}
}

func drawReportTable(content *strings.Builder, rows [][]string, x, y float64) {
	if len(rows) == 0 {
		pdfTextAt(content, "F1", 10, x, y, "No report rows available.")
		return
	}
	columnCount := len(rows[0])
	if columnCount == 0 {
		return
	}
	columnWidth := 528.0 / float64(columnCount)
	rowHeight := 22.0
	maxRows := len(rows)
	if maxRows > 14 {
		maxRows = 14
	}
	for rowIndex := 0; rowIndex < maxRows; rowIndex++ {
		row := rows[rowIndex]
		rowY := y - float64(rowIndex)*rowHeight
		if rowIndex == 0 {
			content.WriteString("0.09 0.24 0.42 rg\n")
		} else if rowIndex%2 == 0 {
			content.WriteString("0.97 0.99 1 rg\n")
		} else {
			content.WriteString("1 1 1 rg\n")
		}
		content.WriteString(fmt.Sprintf("%.1f %.1f 528 %.1f re f\n", x, rowY-rowHeight+5, rowHeight))
		content.WriteString("0.82 0.88 0.95 RG\n0.7 w\n")
		content.WriteString(fmt.Sprintf("%.1f %.1f 528 %.1f re S\n", x, rowY-rowHeight+5, rowHeight))
		for columnIndex := 1; columnIndex < columnCount; columnIndex++ {
			lineX := x + float64(columnIndex)*columnWidth
			content.WriteString(fmt.Sprintf("%.1f %.1f m %.1f %.1f l S\n", lineX, rowY-rowHeight+5, lineX, rowY+5))
		}
		for columnIndex := 0; columnIndex < columnCount; columnIndex++ {
			cell := ""
			if columnIndex < len(row) {
				cell = row[columnIndex]
			}
			font := "F1"
			if rowIndex == 0 {
				font = "F2"
			}
			if rowIndex == 0 {
				pdfTextAtColor(content, font, 8, x+float64(columnIndex)*columnWidth+5, rowY-10, pdfTruncate(cell, int(columnWidth/4.7)), "1 1 1")
			} else {
				pdfTextAt(content, font, 8, x+float64(columnIndex)*columnWidth+5, rowY-10, pdfTruncate(cell, int(columnWidth/4.7)))
			}
		}
	}
	if len(rows) > maxRows {
		pdfTextAt(content, "F1", 9, x, y-float64(maxRows)*rowHeight-10, "More rows are available in CSV/XLSX exports.")
	}
}

func pdfTextAt(content *strings.Builder, font string, size int, x, y float64, text string) {
	color := "0.04 0.08 0.16"
	if font == "F1" && size <= 10 {
		color = "0.30 0.36 0.46"
	}
	pdfTextAtColor(content, font, size, x, y, text, color)
}

func pdfTextAtColor(content *strings.Builder, font string, size int, x, y float64, text, color string) {
	content.WriteString(color + " rg\n")
	content.WriteString(fmt.Sprintf("BT\n/%s %d Tf\n%.1f %.1f Td\n(%s) Tj\nET\n", font, size, x, y, pdfEscape(text)))
}

func pdfTruncate(value string, max int) string {
	value = strings.Join(strings.Fields(value), " ")
	if max <= 0 {
		return value
	}
	runes := []rune(value)
	if len(runes) <= max {
		return value
	}
	if max <= 3 {
		return string(runes[:max])
	}
	return string(runes[:max-3]) + "..."
}

func reportPDFLabel(value string) string {
	value = strings.TrimSpace(strings.ReplaceAll(value, "_", " "))
	if value == "" {
		return ""
	}
	words := strings.Fields(strings.ToLower(value))
	for index, word := range words {
		if word == "" {
			continue
		}
		words[index] = strings.ToUpper(word[:1]) + word[1:]
	}
	return strings.Join(words, " ")
}

func minimalPDF(title string, lines []string) []byte {
	payload := map[string]interface{}{
		"report_type": "timetable",
	}
	for index, line := range lines {
		payload[fmt.Sprintf("line_%02d", index+1)] = line
	}
	return reportPDF(models.ReportExport{
		BaseModel:   models.BaseModel{ID: "legacy-pdf"},
		ReportTitle: title,
		ReportType:  "timetable",
		Format:      "pdf",
		RequestedAt: time.Now().UTC(),
	}, payload)
}

func firstReportPDFText(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func writeZipFile(archive *zip.Writer, name, body string) error {
	file, err := archive.Create(name)
	if err != nil {
		return err
	}
	_, err = file.Write([]byte(body))
	return err
}

func xlsxContentTypes() string {
	return `<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>`
}

func xlsxRels() string {
	return `<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>`
}

func xlsxWorkbook() string {
	return `<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Report Export" sheetId="1" r:id="rId1"/></sheets>
</workbook>`
}

func xlsxWorkbookRels() string {
	return `<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>`
}

func xlsxSheet(row models.ReportExport, payload map[string]interface{}) string {
	rows := reportArtifactRows(row, payload)
	var sheet strings.Builder
	sheet.WriteString(`<?xml version="1.0" encoding="UTF-8"?>`)
	sheet.WriteString(`<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>`)
	for rowIndex, cells := range rows {
		sheet.WriteString(fmt.Sprintf(`<row r="%d">`, rowIndex+1))
		for columnIndex, value := range cells {
			sheet.WriteString(xlsxCell(columnIndex, rowIndex+1, value))
		}
		sheet.WriteString(`</row>`)
	}
	sheet.WriteString(`</sheetData></worksheet>`)
	return sheet.String()
}

func reportArtifactRows(row models.ReportExport, payload map[string]interface{}) [][]string {
	switch strings.ToLower(strings.TrimSpace(row.ReportType)) {
	case "teacher_attendance", "class_attendance", "attendance":
		if rows := attendanceReportRows(row, payload); len(rows) > 1 {
			return rows
		}
	case "teacher_homework", "homework_submissions", "homework":
		if rows := homeworkReportRows(row, payload); len(rows) > 1 {
			return rows
		}
	}
	rows := [][]string{
		{"field", "value"},
		{"report_title", row.ReportTitle},
		{"category", row.Category},
		{"format", row.Format},
		{"scope", row.Scope},
	}
	for key, value := range payload {
		rows = append(rows, []string{key, fmt.Sprint(value)})
	}
	return rows
}

func attendanceReportRows(row models.ReportExport, payload map[string]interface{}) [][]string {
	type attendanceReportRow struct {
		Date          time.Time
		SectionName   string
		SubjectName   string
		StaffName     string
		PeriodNumber  int
		TotalStudents int
		PresentCount  int
		AbsentCount   int
		LateCount     int
		IsFinalized   bool
	}
	query := database.DB.Table("attendance_sessions").
		Select(`
			attendance_sessions.date,
			COALESCE(grades.grade_name || ' ' || sections.section_name, sections.section_name, '') AS section_name,
			COALESCE(subjects.subject_name, attendance_sessions.subject_id) AS subject_name,
			TRIM(COALESCE(staff.first_name, '') || ' ' || COALESCE(staff.last_name, '')) AS staff_name,
			attendance_sessions.period_number,
			attendance_sessions.total_students,
			attendance_sessions.present_count,
			SUM(CASE WHEN LOWER(student_attendances.status) = 'absent' THEN 1 ELSE 0 END) AS absent_count,
			SUM(CASE WHEN LOWER(student_attendances.status) = 'late' THEN 1 ELSE 0 END) AS late_count,
			attendance_sessions.is_finalized
		`).
		Joins("LEFT JOIN sections ON sections.id = attendance_sessions.section_id").
		Joins("LEFT JOIN grades ON grades.id = sections.grade_id").
		Joins("LEFT JOIN subjects ON subjects.id = attendance_sessions.subject_id").
		Joins("LEFT JOIN staff ON staff.id = attendance_sessions.staff_id").
		Joins("LEFT JOIN student_attendances ON student_attendances.session_id = attendance_sessions.id").
		Where("grades.school_id = ?", row.SchoolID).
		Group("attendance_sessions.id, grades.grade_name, sections.section_name, subjects.subject_name, staff.first_name, staff.last_name").
		Order("attendance_sessions.date DESC, attendance_sessions.period_number ASC")
	if sectionID := textPayload(payload, "section_id"); sectionID != "" {
		query = query.Where("attendance_sessions.section_id = ?", sectionID)
	}
	if teacherID := textPayload(payload, "teacher_id"); teacherID != "" {
		query = query.Where("attendance_sessions.staff_id = ?", teacherID)
	}
	var rows []attendanceReportRow
	if err := query.Find(&rows).Error; err != nil {
		return nil
	}
	result := [][]string{{"date", "class", "subject", "teacher", "period", "total_students", "present", "absent", "late", "finalized"}}
	for _, item := range rows {
		result = append(result, []string{
			item.Date.Format("2006-01-02"),
			item.SectionName,
			item.SubjectName,
			item.StaffName,
			fmt.Sprint(item.PeriodNumber),
			fmt.Sprint(item.TotalStudents),
			fmt.Sprint(item.PresentCount),
			fmt.Sprint(item.AbsentCount),
			fmt.Sprint(item.LateCount),
			fmt.Sprint(item.IsFinalized),
		})
	}
	return result
}

func homeworkReportRows(row models.ReportExport, payload map[string]interface{}) [][]string {
	type homeworkReportRow struct {
		Title           string
		SubjectID       string
		ClassID         string
		SectionID       string
		TeacherID       string
		DueDate         time.Time
		Status          string
		SubmissionCount int
		ReviewedCount   int
	}
	query := database.DB.Table("homework").
		Select(`
			homework.title,
			homework.subject_id,
			homework.class_id,
			homework.section_id,
			homework.staff_id AS teacher_id,
			homework.submission_date AS due_date,
			homework.status,
			COUNT(homework_submissions.id) AS submission_count,
			SUM(CASE WHEN homework_submissions.reviewed_at IS NOT NULL OR homework_submissions.reviewed_by != '' THEN 1 ELSE 0 END) AS reviewed_count
		`).
		Joins("LEFT JOIN homework_submissions ON homework_submissions.homework_id = homework.homework_id").
		Where("homework.school_id = ?", row.SchoolID).
		Group("homework.homework_id, homework.title, homework.subject_id, homework.class_id, homework.section_id, homework.staff_id, homework.submission_date, homework.status").
		Order("homework.submission_date DESC, homework.created_at DESC")
	if sectionID := textPayload(payload, "section_id"); sectionID != "" {
		query = query.Where("homework.section_id = ?", sectionID)
	}
	if teacherID := textPayload(payload, "teacher_id"); teacherID != "" {
		query = query.Where("homework.staff_id = ?", teacherID)
	}
	var rows []homeworkReportRow
	if err := query.Find(&rows).Error; err != nil {
		return nil
	}
	result := [][]string{{"title", "subject", "class", "section", "teacher", "due_date", "status", "submissions", "reviewed"}}
	for _, item := range rows {
		due := ""
		if !item.DueDate.IsZero() {
			due = item.DueDate.Format("2006-01-02")
		}
		result = append(result, []string{
			item.Title,
			item.SubjectID,
			item.ClassID,
			item.SectionID,
			item.TeacherID,
			due,
			item.Status,
			fmt.Sprint(item.SubmissionCount),
			fmt.Sprint(item.ReviewedCount),
		})
	}
	return result
}

func xlsxCell(columnIndex, rowIndex int, value string) string {
	columnName := string(rune('A' + columnIndex))
	return fmt.Sprintf(`<c r="%s%d" t="inlineStr"><is><t>%s</t></is></c>`, columnName, rowIndex, reportXMLTextEscape(value))
}

func reportXMLTextEscape(value string) string {
	replacer := strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;", "'", "&apos;")
	return replacer.Replace(value)
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

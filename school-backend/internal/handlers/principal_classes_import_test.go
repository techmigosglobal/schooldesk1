package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

func setupPrincipalClassImportDB(t *testing.T) *gorm.DB {
	t.Helper()
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(
		&models.School{},
		&models.AcademicYear{},
		&models.Term{},
		&models.Grade{},
		&models.Section{},
		&models.Department{},
		&models.Subject{},
		&models.GradeSubject{},
		&models.Staff{},
		&models.StaffSubject{},
		&models.Room{},
		&models.FeeCategory{},
		&models.FeeStructure{},
		&models.TimetableSlot{},
		&models.Substitution{},
		&models.StaffAttendance{},
		&models.FrontendRecord{},
		&models.AuditLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	seedPrincipalClassImportRefs(t, db)
	return db
}

func seedPrincipalClassImportRefs(t *testing.T, db *gorm.DB) {
	t.Helper()
	start := time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC)
	records := []interface{}{
		&models.School{BaseModel: models.BaseModel{ID: "school-import"}, Name: "Import School", SchoolType: "private"},
		&models.AcademicYear{BaseModel: models.BaseModel{ID: "year-import"}, SchoolID: "school-import", YearLabel: "2026-2027", Year: "2026", StartDate: start, EndDate: start.AddDate(1, 0, -1), IsCurrent: true, Status: "active"},
		&models.Term{BaseModel: models.BaseModel{ID: "term-import"}, AcademicYearID: "year-import", TermNumber: 1, TermName: "Term 1", StartDate: start, EndDate: start.AddDate(0, 6, 0), IsCurrent: true},
		&models.Staff{BaseModel: models.BaseModel{ID: "staff-t101"}, SchoolID: "school-import", StaffCode: "T-101", FirstName: "Meera", LastName: "Nair", Email: "meera@example.test", Status: "active"},
		&models.Staff{BaseModel: models.BaseModel{ID: "staff-t102"}, SchoolID: "school-import", StaffCode: "T-102", FirstName: "Rahul", LastName: "Iyer", Email: "rahul@example.test", Status: "active"},
	}
	for _, record := range records {
		if err := db.Create(record).Error; err != nil {
			t.Fatalf("seed import ref: %v", err)
		}
	}
}

func principalClassImportRouter() *gin.Engine {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-import")
		c.Set("user_id", "principal-import")
		c.Set("role_name", "Principal")
		c.Next()
	})
	handler := NewPrincipalClassesHandler()
	router.POST("/principal/classes/import/dry-run", handler.DryRunClassCsvImport)
	router.POST("/principal/classes/import", handler.ImportClassCsv)
	router.GET("/principal/classes", handler.Overview)
	router.POST("/timetable/slots/generate", NewTimetableHandler().GenerateTimetableSlots)
	router.GET("/principal/subjects", NewPrincipalSubjectsHandler().Overview)
	router.GET("/principal/timetable", NewPrincipalAcademicCommandHandler().TimetableOverview)
	router.GET("/fees/structures", NewFeeHandler().GetFeeStructures)
	return router
}

func validClassHubCSV() string {
	return strings.Join([]string{
		"grade_name,grade_number,section_name,capacity,room_number,room_type,room_capacity,year_label,class_teacher_staff_code,subject_names,subject_codes,subject_departments,subject_teacher_staff_codes,periods_per_week,max_marks,pass_marks,fee_categories,fee_amounts,fee_frequencies,fee_due_days,fee_late_fines",
		"5,5,A,42,5-A,classroom,42,2026-2027,T-101,Mathematics;English,MATH;ENG,Academics;Languages,T-101;T-102,6;5,100;100,35;35,Tuition;Transport,25000;8000,term;monthly,10;5,0;0",
	}, "\n")
}

func postClassImportCSV(t *testing.T, router *gin.Engine, path, csvText string) (*httptest.ResponseRecorder, principalClassCsvImportResponse) {
	t.Helper()
	payload, err := json.Marshal(gin.H{"csv_text": csvText})
	if err != nil {
		t.Fatalf("marshal request: %v", err)
	}
	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodPost, path, bytes.NewReader(payload)))
	var decoded struct {
		Success bool                            `json:"success"`
		Data    principalClassCsvImportResponse `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode response %s: %v\n%s", path, err, response.Body.String())
	}
	return response, decoded.Data
}

func TestClassHubCsvDryRunValidPreview(t *testing.T) {
	setupPrincipalClassImportDB(t)
	router := principalClassImportRouter()

	response, data := postClassImportCSV(t, router, "/principal/classes/import/dry-run", validClassHubCSV())
	if response.Code != http.StatusOK {
		t.Fatalf("dry-run status = %d body=%s", response.Code, response.Body.String())
	}
	if !data.CanImport {
		t.Fatalf("expected can_import=true, errors=%v", data.Errors)
	}
	if len(data.Rows) != 1 {
		t.Fatalf("rows = %d", len(data.Rows))
	}
	if data.Rows[0].SubjectCount != 2 || data.Rows[0].FeeItemCount != 2 {
		t.Fatalf("preview counts = subjects %d fees %d", data.Rows[0].SubjectCount, data.Rows[0].FeeItemCount)
	}
	if data.Rows[0].RoomNumber != "5-A" {
		t.Fatalf("preview room number = %s", data.Rows[0].RoomNumber)
	}
	if data.Summary["classes_to_create"].(float64) != 1 {
		t.Fatalf("summary = %#v", data.Summary)
	}

	var sectionCount int64
	if err := database.DB.Model(&models.Section{}).Count(&sectionCount).Error; err != nil {
		t.Fatalf("count sections: %v", err)
	}
	if sectionCount != 0 {
		t.Fatalf("dry-run wrote %d sections", sectionCount)
	}
}

func TestClassHubCsvDryRunInvalidRowsBlockImport(t *testing.T) {
	setupPrincipalClassImportDB(t)
	router := principalClassImportRouter()
	csvText := strings.Join([]string{
		"grade_name,section_name,year_label,class_teacher_id,fee_categories,fee_amounts",
		"5,A,2026-2027,missing-staff-id,Tuition,-1",
	}, "\n")

	response, data := postClassImportCSV(t, router, "/principal/classes/import/dry-run", csvText)
	if response.Code != http.StatusOK {
		t.Fatalf("dry-run status = %d body=%s", response.Code, response.Body.String())
	}
	if data.CanImport {
		t.Fatalf("expected invalid CSV to block import")
	}
	if len(data.Errors) < 2 {
		t.Fatalf("expected explicit teacher ID and fee errors, got %#v", data.Errors)
	}

	importResponse, importData := postClassImportCSV(t, router, "/principal/classes/import", csvText)
	if importResponse.Code != http.StatusBadRequest {
		t.Fatalf("invalid import status = %d body=%s", importResponse.Code, importResponse.Body.String())
	}
	if importData.CanImport {
		t.Fatalf("invalid import response should keep can_import=false")
	}
	var sectionCount int64
	if err := database.DB.Model(&models.Section{}).Count(&sectionCount).Error; err != nil {
		t.Fatalf("count sections: %v", err)
	}
	if sectionCount != 0 {
		t.Fatalf("invalid import wrote %d sections", sectionCount)
	}
}

func TestClassHubCsvImportCreatesMissingTeacherStaffFromCodes(t *testing.T) {
	db := setupPrincipalClassImportDB(t)
	router := principalClassImportRouter()
	csvText := strings.Join([]string{
		"grade_name,grade_number,section_name,capacity,year_label,class_teacher_staff_code,subject_names,subject_codes,subject_teacher_staff_codes,periods_per_week,fee_categories,fee_amounts",
		"Play Group,1,A,25,2026-2027,TE-101,Mathematics;English,MATH;ENG,TE-101;TE-102,5;5,Tuition,10000",
	}, "\n")

	var beforeCount int64
	if err := db.Model(&models.Staff{}).
		Where("school_id = ? AND staff_code IN ?", "school-import", []string{"TE-101", "TE-102"}).
		Count(&beforeCount).Error; err != nil {
		t.Fatalf("count before staff: %v", err)
	}
	if beforeCount != 0 {
		t.Fatalf("test fixture unexpectedly seeded TE staff: %d", beforeCount)
	}

	dryRunResponse, dryRun := postClassImportCSV(t, router, "/principal/classes/import/dry-run", csvText)
	if dryRunResponse.Code != http.StatusOK || !dryRun.CanImport {
		t.Fatalf("dry-run failed status=%d errors=%v body=%s", dryRunResponse.Code, dryRun.Errors, dryRunResponse.Body.String())
	}
	if len(dryRun.Warnings) == 0 {
		t.Fatalf("expected dry-run warnings for teacher creation")
	}
	if !strings.Contains(dryRun.Warnings[0].Message, "will be created") {
		t.Fatalf("expected teacher creation warning, got %#v", dryRun.Warnings)
	}
	var afterDryRunCount int64
	if err := db.Model(&models.Staff{}).
		Where("school_id = ? AND staff_code IN ?", "school-import", []string{"TE-101", "TE-102"}).
		Count(&afterDryRunCount).Error; err != nil {
		t.Fatalf("count dry-run staff: %v", err)
	}
	if afterDryRunCount != 0 {
		t.Fatalf("dry-run created staff rows: %d", afterDryRunCount)
	}

	importResponse, imported := postClassImportCSV(t, router, "/principal/classes/import", csvText)
	if importResponse.Code != http.StatusOK || !imported.Imported {
		t.Fatalf("import failed status=%d body=%s", importResponse.Code, importResponse.Body.String())
	}

	var createdStaff []models.Staff
	if err := db.Where("school_id = ? AND staff_code IN ?", "school-import", []string{"TE-101", "TE-102"}).
		Order("staff_code ASC").
		Find(&createdStaff).Error; err != nil {
		t.Fatalf("load created staff: %v", err)
	}
	if len(createdStaff) != 2 {
		t.Fatalf("created staff count = %d rows=%#v", len(createdStaff), createdStaff)
	}
	for _, staff := range createdStaff {
		if staff.Status != "active" || staff.Designation != "Teacher" {
			t.Fatalf("created staff not active teacher: %#v", staff)
		}
	}
	var section models.Section
	if err := db.Where("academic_year_id = ? AND section_name = ?", "year-import", "A").First(&section).Error; err != nil {
		t.Fatalf("load imported section: %v", err)
	}
	if section.ClassTeacherID == nil || *section.ClassTeacherID != createdStaff[0].ID {
		t.Fatalf("class teacher was not assigned from created staff: section=%#v staff=%#v", section, createdStaff)
	}
	var assignmentCount int64
	if err := db.Model(&models.StaffSubject{}).
		Where("school_id = ? AND academic_year_id = ? AND grade_id = ? AND section_id = ?", "school-import", "year-import", section.GradeID, section.ID).
		Count(&assignmentCount).Error; err != nil {
		t.Fatalf("count staff subjects: %v", err)
	}
	if assignmentCount != 2 {
		t.Fatalf("expected two teacher subject assignments, got %d", assignmentCount)
	}
}

func TestClassHubCsvImportUpdatesExistingClassWithoutDuplicates(t *testing.T) {
	db := setupPrincipalClassImportDB(t)
	if err := db.Create(&models.Grade{BaseModel: models.BaseModel{ID: "grade-five"}, SchoolID: "school-import", GradeNumber: 5, GradeName: "5"}).Error; err != nil {
		t.Fatalf("seed grade: %v", err)
	}
	if err := db.Create(&models.Section{BaseModel: models.BaseModel{ID: "section-five-a"}, SchoolID: "school-import", GradeID: "grade-five", AcademicYearID: "year-import", SectionName: "A", Capacity: 30}).Error; err != nil {
		t.Fatalf("seed section: %v", err)
	}
	router := principalClassImportRouter()

	dryRunResponse, dryRun := postClassImportCSV(t, router, "/principal/classes/import/dry-run", validClassHubCSV())
	if dryRunResponse.Code != http.StatusOK || !dryRun.CanImport {
		t.Fatalf("dry-run failed status=%d errors=%v", dryRunResponse.Code, dryRun.Errors)
	}
	if dryRun.Rows[0].Mode != "update" {
		t.Fatalf("expected update preview, got %s", dryRun.Rows[0].Mode)
	}

	importResponse, imported := postClassImportCSV(t, router, "/principal/classes/import", validClassHubCSV())
	if importResponse.Code != http.StatusOK || !imported.Imported {
		t.Fatalf("import failed status=%d body=%s", importResponse.Code, importResponse.Body.String())
	}

	importResponse, imported = postClassImportCSV(t, router, "/principal/classes/import", validClassHubCSV())
	if importResponse.Code != http.StatusOK || !imported.Imported {
		t.Fatalf("second import failed status=%d body=%s", importResponse.Code, importResponse.Body.String())
	}

	var sectionCount, gradeSubjectCount, feeStructureCount int64
	if err := db.Model(&models.Section{}).Count(&sectionCount).Error; err != nil {
		t.Fatalf("count sections: %v", err)
	}
	if err := db.Model(&models.GradeSubject{}).Count(&gradeSubjectCount).Error; err != nil {
		t.Fatalf("count grade subjects: %v", err)
	}
	if err := db.Model(&models.FeeStructure{}).Count(&feeStructureCount).Error; err != nil {
		t.Fatalf("count fee structures: %v", err)
	}
	if sectionCount != 1 {
		t.Fatalf("section duplicates were created: %d", sectionCount)
	}
	if gradeSubjectCount != 2 {
		t.Fatalf("subject mapping duplicates/count mismatch: %d", gradeSubjectCount)
	}
	if feeStructureCount != 2 {
		t.Fatalf("fee structure duplicates/count mismatch: %d", feeStructureCount)
	}

	var section models.Section
	if err := db.First(&section, "id = ?", "section-five-a").Error; err != nil {
		t.Fatalf("load section: %v", err)
	}
	if section.Capacity != 42 {
		t.Fatalf("section capacity was not updated from import: %d", section.Capacity)
	}
	if section.RoomID == nil || *section.RoomID == "" {
		t.Fatalf("section room was not assigned from import: %#v", section)
	}
	var roomCount int64
	if err := db.Model(&models.Room{}).Where("school_id = ? AND room_number = ?", "school-import", "5-A").Count(&roomCount).Error; err != nil {
		t.Fatalf("count rooms: %v", err)
	}
	if roomCount != 1 {
		t.Fatalf("room duplicates/count mismatch: %d", roomCount)
	}
	setup := NewPrincipalClassesHandler().classSetupResponse(db, "school-import", section)
	if len(setup["fee_structures"].([]models.FeeStructure)) != 2 {
		t.Fatalf("Class Hub setup did not read imported fees: %#v", setup["fee_structures"])
	}
	if len(setup["subjects"].([]models.Subject)) != 2 {
		t.Fatalf("Class Hub setup did not read imported subjects: %#v", setup["subjects"])
	}
}

func TestClassHubCsvImportFeedsMainModulesSubjectsFeesTimetable(t *testing.T) {
	db := setupPrincipalClassImportDB(t)
	router := principalClassImportRouter()

	importResponse, imported := postClassImportCSV(t, router, "/principal/classes/import", validClassHubCSV())
	if importResponse.Code != http.StatusOK || !imported.Imported {
		t.Fatalf("import failed status=%d body=%s", importResponse.Code, importResponse.Body.String())
	}

	var section models.Section
	if err := db.
		Preload("Grade").
		Preload("Room").
		Where("academic_year_id = ? AND section_name = ?", "year-import", "A").
		First(&section).Error; err != nil {
		t.Fatalf("load imported section: %v", err)
	}
	if section.RoomID == nil || section.Room == nil || section.Room.RoomNumber != "5-A" {
		t.Fatalf("imported section did not keep room assignment: %#v", section)
	}

	generatePayload := gin.H{
		"section_id":              section.ID,
		"academic_year_id":        section.AcademicYearID,
		"term_id":                 "term-import",
		"day_of_week":             1,
		"period_count":            2,
		"start_time":              "09:00",
		"period_duration_minutes": 40,
		"gap_minutes":             5,
	}
	body, err := json.Marshal(generatePayload)
	if err != nil {
		t.Fatalf("marshal generate payload: %v", err)
	}
	generateResponse := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/timetable/slots/generate", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(generateResponse, req)
	if generateResponse.Code != http.StatusCreated {
		t.Fatalf("generate status=%d body=%s", generateResponse.Code, generateResponse.Body.String())
	}
	var generateBody struct {
		Data struct {
			Created int `json:"created"`
			Skipped int `json:"skipped"`
		} `json:"data"`
	}
	if err := json.Unmarshal(generateResponse.Body.Bytes(), &generateBody); err != nil {
		t.Fatalf("decode generate response: %v", err)
	}
	if generateBody.Data.Created != 2 || generateBody.Data.Skipped != 0 {
		t.Fatalf("expected generated timetable slots from imported subjects, got %+v", generateBody.Data)
	}
	var roomSlotCount int64
	if err := db.Model(&models.TimetableSlot{}).Where("section_id = ? AND room_id = ?", section.ID, *section.RoomID).Count(&roomSlotCount).Error; err != nil {
		t.Fatalf("count room slots: %v", err)
	}
	if roomSlotCount != 2 {
		t.Fatalf("generated slots did not use imported class room: %d", roomSlotCount)
	}

	subjectsData := getAPIDataMap(t, router, "/principal/subjects")
	subjectSummary := subjectsData["summary"].(map[string]interface{})
	if int(subjectSummary["total_subjects"].(float64)) != 2 {
		t.Fatalf("principal subjects did not read imported subjects: %#v", subjectSummary)
	}
	if int(subjectSummary["assigned_teacher_count"].(float64)) != 2 {
		t.Fatalf("principal subjects did not read imported teacher mappings: %#v", subjectSummary)
	}
	if int(subjectSummary["classes_covered_count"].(float64)) != 1 {
		t.Fatalf("principal subjects did not read imported class coverage: %#v", subjectSummary)
	}

	timetableData := getAPIDataMap(t, router, "/principal/timetable")
	timetableSummary := timetableData["summary"].(map[string]interface{})
	if int(timetableSummary["total_slots"].(float64)) != 2 {
		t.Fatalf("principal timetable did not read generated imported setup slots: %#v", timetableSummary)
	}
	views := timetableData["views"].(map[string]interface{})
	classRows := views["class_wise"].([]interface{})
	if len(classRows) != 1 {
		t.Fatalf("expected one class-wise timetable row, got %#v", classRows)
	}
	classRow := classRows[0].(map[string]interface{})
	if int(classRow["slot_count"].(float64)) != 2 || int(classRow["subject_count"].(float64)) != 2 {
		t.Fatalf("class-wise timetable row did not reflect imported subjects/slots: %#v", classRow)
	}
	subjectRows := views["subject_wise"].([]interface{})
	if len(subjectRows) != 2 {
		t.Fatalf("expected two subject-wise timetable rows, got %#v", subjectRows)
	}

	feeStructures := getAPIDataList(t, router, "/fees/structures?academic_year_id=year-import&grade_id="+section.GradeID)
	if len(feeStructures) != 2 {
		t.Fatalf("fee monitoring endpoint did not read imported fee setup: %#v", feeStructures)
	}
	amounts := map[string]bool{}
	for _, raw := range feeStructures {
		row := raw.(map[string]interface{})
		amounts[strconv.FormatFloat(row["amount"].(float64), 'f', 0, 64)] = true
	}
	if !amounts["25000"] || !amounts["8000"] {
		t.Fatalf("fee structures did not include imported amounts: %#v", feeStructures)
	}
}

func TestClassHubCsvImportTransactionRollsBackPartialApplyFailure(t *testing.T) {
	db := setupPrincipalClassImportDB(t)
	handler := NewPrincipalClassesHandler()
	valid := principalClassCsvImportPlan{
		Preview: principalClassCsvImportPreviewRow{RowNumber: 2},
		Request: principalClassSetupRequest{
			GradeName:      "6",
			GradeNumber:    6,
			AcademicYearID: "year-import",
			SectionName:    "A",
			Capacity:       40,
			FeeItems: []principalClassFeeItem{{
				CategoryName: "Tuition",
				Frequency:    "term",
				Amount:       1000,
				DueDay:       10,
			}},
		},
	}
	failing := principalClassCsvImportPlan{
		Preview: principalClassCsvImportPreviewRow{RowNumber: 3},
		Request: principalClassSetupRequest{
			GradeName:      "7",
			GradeNumber:    7,
			AcademicYearID: "year-import",
			SectionName:    "A",
			Capacity:       40,
			SubjectMappings: []principalClassSubjectMapping{{
				SubjectName:    "Science",
				DepartmentName: "Academics",
				TeacherID:      "missing-staff",
				PeriodsPerWeek: 5,
				MaxMarks:       100,
				PassMarks:      35,
			}},
		},
	}

	err := db.Transaction(func(tx *gorm.DB) error {
		if _, _, err := handler.applyClassCsvImportPlan(tx, "school-import", valid); err != nil {
			return err
		}
		if _, _, err := handler.applyClassCsvImportPlan(tx, "school-import", failing); err != nil {
			return err
		}
		return nil
	})
	if err == nil {
		t.Fatalf("expected second row apply failure")
	}
	var sectionCount, feeStructureCount int64
	if err := db.Model(&models.Section{}).Count(&sectionCount).Error; err != nil {
		t.Fatalf("count sections: %v", err)
	}
	if err := db.Model(&models.FeeStructure{}).Count(&feeStructureCount).Error; err != nil {
		t.Fatalf("count fees: %v", err)
	}
	if sectionCount != 0 || feeStructureCount != 0 {
		t.Fatalf("transaction left partial data: sections=%d fees=%d", sectionCount, feeStructureCount)
	}
}

func getAPIDataMap(t *testing.T, router *gin.Engine, path string) map[string]interface{} {
	t.Helper()
	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, path, nil))
	if response.Code != http.StatusOK {
		t.Fatalf("GET %s status=%d body=%s", path, response.Code, response.Body.String())
	}
	var decoded struct {
		Data map[string]interface{} `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode GET %s: %v", path, err)
	}
	return decoded.Data
}

func getAPIDataList(t *testing.T, router *gin.Engine, path string) []interface{} {
	t.Helper()
	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, path, nil))
	if response.Code != http.StatusOK {
		t.Fatalf("GET %s status=%d body=%s", path, response.Code, response.Body.String())
	}
	var decoded struct {
		Data []interface{} `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode GET %s: %v", path, err)
	}
	return decoded.Data
}

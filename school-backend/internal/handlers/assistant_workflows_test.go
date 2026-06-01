package handlers

import (
	"net/http/httptest"
	"strings"
	"testing"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
)

func TestAssistantCreateClassCreatesAcademicYearOnCleanSchool(t *testing.T) {
	gin.SetMode(gin.TestMode)
	if err := database.SetupTestDB(); err != nil {
		t.Fatalf("setup db: %v", err)
	}
	school := models.School{BaseModel: models.BaseModel{ID: "school-assistant-clean"}, Name: "Clean School", SchoolType: "cbse"}
	if err := database.DB.Create(&school).Error; err != nil {
		t.Fatalf("seed school: %v", err)
	}

	recorder := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(recorder)
	c.Set("school_id", school.ID)
	c.Set("user_id", "principal-clean")
	c.Set("role_name", "Principal")

	handler := NewAssistantWorkflowHandler()
	result, err := handler.executeCreateClass(c, map[string]interface{}{
		"class_details": map[string]interface{}{
			"class_name":          "PP1",
			"academic_year_label": "2026-2027",
			"start_date":          "2026-04-01",
			"end_date":            "2027-03-31",
			"section_count":       2,
			"capacity":            30,
		},
		"subjects": []map[string]interface{}{
			{"subject_name": "English", "periods_per_week": 5},
			{"subject_name": "Math", "periods_per_week": 5},
		},
		"fee_structure": []map[string]interface{}{
			{"category_name": "Tuition", "amount": 1000, "frequency": "term", "due_day": 10},
		},
	})
	if err != nil {
		t.Fatalf("execute create class: %v", err)
	}
	entities := result["created_entities"].(gin.H)
	if entities["subjects"] != 2 {
		t.Fatalf("subjects created = %v, want 2", entities["subjects"])
	}

	var yearCount int64
	database.DB.Model(&models.AcademicYear{}).Where("school_id = ? AND year_label = ?", school.ID, "2026-2027").Count(&yearCount)
	if yearCount != 1 {
		t.Fatalf("academic year count = %d, want 1", yearCount)
	}
	var termCount int64
	database.DB.Model(&models.Term{}).Joins("JOIN academic_years ON academic_years.id = terms.academic_year_id").Where("academic_years.school_id = ?", school.ID).Count(&termCount)
	if termCount != 1 {
		t.Fatalf("term count = %d, want 1", termCount)
	}
	var sectionCount int64
	database.DB.Model(&models.Section{}).Joins("JOIN academic_years ON academic_years.id = sections.academic_year_id").Where("academic_years.school_id = ?", school.ID).Count(&sectionCount)
	if sectionCount != 2 {
		t.Fatalf("section count = %d, want 2", sectionCount)
	}
}

func TestAssistantBulkImportBuildsConnectedClassDraft(t *testing.T) {
	parsed, err := parseAssistantBulkContent(
		"create_class",
		"csv",
		"class_name,academic_year_label,start_date,end_date,section_count,capacity,section_names,subjects,fees\nPP1,2026-2027,2026-04-01,2027-03-31,2,30,A|B,English|Math,Tuition=1000|Books=500",
	)
	if err != nil {
		t.Fatalf("parse bulk content: %v", err)
	}
	details := workflowNestedMap(parsed, "class_details")
	if details["academic_year_label"] != "2026-2027" {
		t.Fatalf("academic year label = %v", details["academic_year_label"])
	}
	if len(workflowList(parsed, "sections")) != 2 {
		t.Fatalf("sections = %d, want 2", len(workflowList(parsed, "sections")))
	}
	if len(workflowList(parsed, "subjects")) != 2 {
		t.Fatalf("subjects = %d, want 2", len(workflowList(parsed, "subjects")))
	}
	if len(workflowList(parsed, "fee_structure")) != 2 {
		t.Fatalf("fees = %d, want 2", len(workflowList(parsed, "fee_structure")))
	}
}

func TestAssistantCatalogCardsAreOnlyRunnableSurfaces(t *testing.T) {
	defs := assistantWorkflowDefinitions()
	knownWorkflows := map[string]bool{}
	for _, def := range defs {
		knownWorkflows[def.Type] = true
	}

	cards := assistantActionCards(defs, "Principal")
	if len(cards) == 0 {
		t.Fatal("assistant action cards should not be empty")
	}
	for _, card := range cards {
		title := workflowRawString(card["title"])
		workflowType := workflowRawString(card["workflow_type"])
		targetRoute := workflowRawString(card["target_route"])
		if strings.EqualFold(title, "Transport") || strings.EqualFold(title, "Library") || strings.EqualFold(title, "Inventory") {
			t.Fatalf("unwired action card %q should not be exposed", title)
		}
		if !knownWorkflows[workflowType] && targetRoute == "" {
			t.Fatalf("connected card %q does not have a live route", title)
		}
	}
}

func TestAssistantTemplatesDoNotPrefillExampleRows(t *testing.T) {
	headers := assistantTemplateHeaders("create_class")
	template := strings.Join(headers, ",") + "\n"
	if strings.Contains(template, "PP1") || strings.Contains(template, "Tuition=1000") {
		t.Fatalf("template must not prefill example data: %q", template)
	}
	if !strings.HasSuffix(template, "\n") {
		t.Fatalf("template should contain only a header row and newline: %q", template)
	}
}

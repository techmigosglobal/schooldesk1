package handlers

import (
	"strings"
	"testing"
)

func TestTeacherAssignedClassesSQLSupportsPostgresDistinctOrdering(t *testing.T) {
	query := teacherAssignedClassesSQL()
	selectPart, _, found := strings.Cut(query, "FROM sections")
	if !found {
		t.Fatalf("teacher class query should select from sections: %s", query)
	}
	if !strings.Contains(selectPart, "grade_number") {
		t.Fatalf("teacher class query must select grade_number before ordering by it: %s", query)
	}
	if !strings.Contains(query, "ORDER BY grade_number, section_name") {
		t.Fatalf("teacher class query should order by selected aliases: %s", query)
	}
}

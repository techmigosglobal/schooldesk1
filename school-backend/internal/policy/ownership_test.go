package policy

import "testing"

func TestOwnershipMatrixCoversRequiredAdminModules(t *testing.T) {
	matrix := MustLoadOwnershipMatrix()
	required := map[string]bool{
		"students":              false,
		"staff":                 false,
		"attendance_operations": false,
		"fees":                  false,
		"timetable":             false,
		"exams":                 false,
		"communication":         false,
		"helpdesk":              false,
		"documents":             false,
		"user_access":           false,
		"reports":               false,
		"academic_info":         false,
	}
	for _, module := range matrix.Modules {
		if _, ok := required[module.Key]; !ok {
			t.Fatalf("unexpected module %q in ownership matrix", module.Key)
		}
		required[module.Key] = true
	}
	for key, seen := range required {
		if !seen {
			t.Fatalf("missing module %q in ownership matrix", key)
		}
	}
}

func TestAdminCanNeverFinalizeOperationalChanges(t *testing.T) {
	matrix := MustLoadOwnershipMatrix()
	for _, module := range matrix.Modules {
		if module.Admin.FinalApprove {
			t.Fatalf("admin can final approve %s", module.Key)
		}
		if module.Admin.FinalReject {
			t.Fatalf("admin can final reject %s", module.Key)
		}
		if module.Admin.DirectPublish {
			t.Fatalf("admin can direct publish %s", module.Key)
		}
		if module.Admin.DeleteActiveRecord {
			t.Fatalf("admin can delete active records for %s", module.Key)
		}
		if matrix.Can(module.Key, "admin", "approve") ||
			matrix.Can(module.Key, "admin", "reject") ||
			matrix.Can(module.Key, "admin", "publish") ||
			matrix.Can(module.Key, "admin", "delete") {
			t.Fatalf("admin final action leaked through Can for %s", module.Key)
		}
	}
}

func TestPrincipalOwnsFinalReviewActions(t *testing.T) {
	matrix := MustLoadOwnershipMatrix()
	for _, module := range matrix.Modules {
		if module.Key == "reports" {
			continue
		}
		if !matrix.Can(module.Key, "principal", "approve") {
			t.Fatalf("principal cannot approve %s", module.Key)
		}
		if !matrix.Can(module.Key, "principal", "reject") {
			t.Fatalf("principal cannot reject %s", module.Key)
		}
	}
}

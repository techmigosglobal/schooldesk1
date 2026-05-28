package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
)

func TestDeleteStudentRemovesOperationalAssociations(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	now := time.Date(2026, 5, 28, 9, 0, 0, 0, time.UTC)
	category := models.FeeCategory{BaseModel: models.BaseModel{ID: "fee-cat-cleanup"}, SchoolID: f.schoolID, CategoryName: "Tuition", Frequency: "monthly"}
	invoice := models.FeeInvoice{
		BaseModel:      models.BaseModel{ID: "fee-invoice-cleanup"},
		StudentID:      f.studentID,
		AcademicYearID: f.yearID,
		InvoiceNumber:  "INV-CLEANUP",
		InvoiceDate:    now,
		DueDate:        now.AddDate(0, 1, 0),
		TotalAmount:    1000,
		NetAmount:      1000,
		Balance:        1000,
		Status:         "pending",
	}
	rows := []any{
		&category,
		&invoice,
		&models.FeeInvoiceItem{BaseModel: models.BaseModel{ID: "fee-item-cleanup"}, InvoiceID: invoice.ID, FeeCategoryID: category.ID, Amount: 1000, Description: "Tuition"},
		&models.Payment{BaseModel: models.BaseModel{ID: "payment-cleanup"}, InvoiceID: invoice.ID, ReceiptNumber: "RCPT-CLEANUP", AmountPaid: 100, PaymentDate: now, PaymentMode: "cash"},
		&models.ParentPaymentRequest{BaseModel: models.BaseModel{ID: "payment-request-cleanup"}, SchoolID: f.schoolID, InvoiceID: invoice.ID, StudentID: f.studentID, ParentUserID: f.parentUserID, RequestReference: "PPR-CLEANUP", Amount: 100, PaymentDate: now, PaymentMode: "cash", Status: "pending"},
		&models.FeeConcession{BaseModel: models.BaseModel{ID: "concession-cleanup"}, StudentID: f.studentID, FeeCategoryID: category.ID, AcademicYearID: f.yearID, ConcessionType: "percent", Value: 10},
		&models.StudentGuardian{ID: "student-guardian-cleanup", SchoolID: f.schoolID, StudentID: f.studentID, GuardianID: "guardian-linked", IsPrimary: true, CreatedAt: now, UpdatedAt: now},
		&models.MedicalRecord{BaseModel: models.BaseModel{ID: "medical-cleanup"}, StudentID: f.studentID, Conditions: "None"},
		&models.StudentDocument{BaseModel: models.BaseModel{ID: "doc-cleanup"}, StudentID: f.studentID, DocType: "id", FileURL: "/x.pdf", UploadedAt: now},
		&models.StudentTransport{BaseModel: models.BaseModel{ID: "transport-cleanup"}, StudentID: f.studentID, AcademicYearID: f.yearID, RouteID: "route-cleanup", StopID: "stop-cleanup"},
		&models.StudentLeaveApplication{BaseModel: models.BaseModel{ID: "student-leave-cleanup"}, SchoolID: f.schoolID, StudentID: f.studentID, ParentUserID: f.parentUserID, LeaveType: "sick", FromDate: now, ToDate: now, Reason: "Sick", AppliedAt: now},
	}
	for _, row := range rows {
		if err := database.DB.Create(row).Error; err != nil {
			t.Fatalf("seed %T: %v", row, err)
		}
	}

	router := scopedPolicyRouter("Principal", "user-policy-principal", "", "", "principal@policy.test", f.schoolID)
	router.DELETE("/students/:id", NewStudentHandler().DeleteStudent)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodDelete, "/students/"+f.studentID, nil))
	if response.Code != http.StatusOK {
		t.Fatalf("delete student status=%d body=%s", response.Code, response.Body.String())
	}

	var student models.Student
	if err := database.DB.First(&student, "id = ?", f.studentID).Error; err != nil {
		t.Fatalf("student should remain as inactive audit row: %v", err)
	}
	if student.Status != "inactive" {
		t.Fatalf("student status=%q, want inactive", student.Status)
	}
	assertZeroRows(t, &models.FeeInvoice{}, "student_id = ?", f.studentID)
	assertZeroRows(t, &models.FeeInvoiceItem{}, "invoice_id = ?", invoice.ID)
	assertZeroRows(t, &models.Payment{}, "invoice_id = ?", invoice.ID)
	assertZeroRows(t, &models.ParentPaymentRequest{}, "student_id = ?", f.studentID)
	assertZeroRows(t, &models.FeeConcession{}, "student_id = ?", f.studentID)
	assertZeroRows(t, &models.ParentStudentLink{}, "student_id = ?", f.studentID)
	assertZeroRows(t, &models.StudentGuardian{}, "student_id = ?", f.studentID)
	assertZeroRows(t, &models.Enrollment{}, "student_id = ?", f.studentID)
	assertZeroRows(t, &models.StudentTransport{}, "student_id = ?", f.studentID)
	assertZeroRows(t, &models.StudentLeaveApplication{}, "student_id = ?", f.studentID)
}

func TestDeleteStaffClearsAssignmentsAndOwnedRecords(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	now := time.Date(2026, 5, 28, 9, 0, 0, 0, time.UTC)
	leaveType := models.LeaveType{BaseModel: models.BaseModel{ID: "leave-type-cleanup"}, SchoolID: f.schoolID, LeaveName: "Sick", MaxDaysPerYear: 12}
	rows := []any{
		&leaveType,
		&models.StaffQualification{BaseModel: models.BaseModel{ID: "staff-qualification-cleanup"}, StaffID: f.teacherStaffID, Degree: "B.Ed"},
		&models.StaffDocument{BaseModel: models.BaseModel{ID: "staff-document-cleanup"}, StaffID: f.teacherStaffID, DocType: "id", FileURL: "/id.pdf", UploadedAt: now},
		&models.StaffAttendance{BaseModel: models.BaseModel{ID: "staff-attendance-cleanup"}, StaffID: f.teacherStaffID, Date: now, Status: "present"},
		&models.LeaveBalance{BaseModel: models.BaseModel{ID: "leave-balance-cleanup"}, StaffID: f.teacherStaffID, LeaveTypeID: leaveType.ID, AcademicYearID: f.yearID, TotalEntitled: 12, RemainingDays: 12},
		&models.LeaveApplication{BaseModel: models.BaseModel{ID: "leave-application-cleanup"}, StaffID: f.teacherStaffID, LeaveTypeID: leaveType.ID, FromDate: now, ToDate: now, TotalDays: 1, Reason: "Sick", AppliedAt: now},
		&models.Payroll{BaseModel: models.BaseModel{ID: "payroll-cleanup"}, StaffID: f.teacherStaffID, AcademicYearID: f.yearID, Month: 5, Year: 2026, BasicSalary: 1000, Status: "pending"},
	}
	for _, row := range rows {
		if err := database.DB.Create(row).Error; err != nil {
			t.Fatalf("seed %T: %v", row, err)
		}
	}

	router := scopedPolicyRouter("Principal", "user-policy-principal", "", "", "principal@policy.test", f.schoolID)
	router.DELETE("/staff/:id", NewStaffHandler().DeleteStaff)
	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodDelete, "/staff/"+f.teacherStaffID, nil))
	if response.Code != http.StatusOK {
		t.Fatalf("delete staff status=%d body=%s", response.Code, response.Body.String())
	}

	assertZeroRows(t, &models.Staff{}, "id = ?", f.teacherStaffID)
	assertZeroRows(t, &models.StaffSubject{}, "staff_id = ?", f.teacherStaffID)
	assertZeroRows(t, &models.StaffQualification{}, "staff_id = ?", f.teacherStaffID)
	assertZeroRows(t, &models.StaffDocument{}, "staff_id = ?", f.teacherStaffID)
	assertZeroRows(t, &models.StaffAttendance{}, "staff_id = ?", f.teacherStaffID)
	assertZeroRows(t, &models.LeaveBalance{}, "staff_id = ?", f.teacherStaffID)
	assertZeroRows(t, &models.LeaveApplication{}, "staff_id = ?", f.teacherStaffID)
	assertZeroRows(t, &models.Payroll{}, "staff_id = ?", f.teacherStaffID)

	var slot models.TimetableSlot
	if err := database.DB.First(&slot, "id = ?", f.timetableSlotID).Error; err != nil {
		t.Fatalf("timetable slot should remain with teacher cleared: %v", err)
	}
	if slot.StaffID != "" {
		t.Fatalf("slot staff id=%q, want cleared", slot.StaffID)
	}
	var section models.Section
	if err := database.DB.First(&section, "id = ?", f.sectionID).Error; err != nil {
		t.Fatalf("section should remain with class teacher cleared: %v", err)
	}
	if section.ClassTeacherID != nil {
		t.Fatalf("section class teacher still set to %q", *section.ClassTeacherID)
	}
	var linkedUser models.User
	if err := database.DB.First(&linkedUser, "id = ?", "user-policy-teacher").Error; err != nil {
		t.Fatalf("linked user should remain: %v", err)
	}
	if linkedUser.IsActive {
		t.Fatalf("linked teacher user should be inactive")
	}
}

func assertZeroRows(t *testing.T, model interface{}, query string, args ...interface{}) {
	t.Helper()
	var count int64
	if err := database.DB.Model(model).Where(query, args...).Count(&count).Error; err != nil {
		t.Fatalf("count %T: %v", model, err)
	}
	if count != 0 {
		t.Fatalf("%T count=%d, want 0", model, count)
	}
}

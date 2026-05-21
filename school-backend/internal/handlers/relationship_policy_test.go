package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
)

type relationshipFixture struct {
	schoolID          string
	yearID            string
	termID            string
	subjectID         string
	otherSubjectID    string
	teacherStaffID    string
	otherStaffID      string
	parentUserID      string
	otherParentUserID string
	sectionID         string
	otherSectionID    string
	studentID         string
	otherStudentID    string
	enrollmentID      string
	otherEnrollmentID string
	timetableSlotID   string
	conversationID    string
	otherConvID       string
	eventID           string
}

func setupRelationshipPolicyFixture(t *testing.T) relationshipFixture {
	t.Helper()
	gin.SetMode(gin.TestMode)
	if err := database.SetupTestDB(); err != nil {
		t.Fatalf("setup db: %v", err)
	}

	now := time.Date(2026, 5, 8, 9, 0, 0, 0, time.UTC)
	f := relationshipFixture{
		schoolID:          "school-policy",
		yearID:            "year-policy",
		termID:            "term-policy",
		subjectID:         "subject-policy-math",
		otherSubjectID:    "subject-policy-science",
		teacherStaffID:    "staff-policy-teacher",
		otherStaffID:      "staff-policy-other",
		parentUserID:      "user-policy-parent",
		otherParentUserID: "user-policy-parent-other",
		sectionID:         "section-policy-a",
		otherSectionID:    "section-policy-b",
		studentID:         "student-policy-linked",
		otherStudentID:    "student-policy-other",
		enrollmentID:      "enrollment-policy-linked",
		otherEnrollmentID: "enrollment-policy-other",
		timetableSlotID:   "slot-policy-owned",
		conversationID:    "conversation-policy-linked",
		otherConvID:       "conversation-policy-other",
		eventID:           "event-policy",
	}
	deptID := "dept-policy"
	gradeID := "grade-policy"
	adminRoleID := "role-policy-admin"
	principalRoleID := "role-policy-principal"
	teacherRoleID := "role-policy-teacher"
	parentRoleID := "role-policy-parent"

	seeds := []any{
		&models.School{BaseModel: models.BaseModel{ID: f.schoolID}, Name: "Policy School", SchoolType: "cbse"},
		&models.AcademicYear{BaseModel: models.BaseModel{ID: f.yearID}, SchoolID: f.schoolID, YearLabel: "2026-2027", StartDate: now, EndDate: now.AddDate(1, 0, 0), IsCurrent: true, Status: "active"},
		&models.Term{BaseModel: models.BaseModel{ID: f.termID}, AcademicYearID: f.yearID, TermNumber: 1, TermName: "Term 1", StartDate: now, EndDate: now.AddDate(0, 6, 0), IsCurrent: true},
		&models.Department{BaseModel: models.BaseModel{ID: deptID}, SchoolID: f.schoolID, DepartmentName: "Academics"},
		&models.Grade{BaseModel: models.BaseModel{ID: gradeID}, SchoolID: f.schoolID, GradeNumber: 8, GradeName: "Grade 8"},
		&models.Subject{BaseModel: models.BaseModel{ID: f.subjectID}, SchoolID: f.schoolID, DepartmentID: deptID, SubjectName: "Mathematics", SubjectCode: "MATH"},
		&models.Subject{BaseModel: models.BaseModel{ID: f.otherSubjectID}, SchoolID: f.schoolID, DepartmentID: deptID, SubjectName: "Science", SubjectCode: "SCI"},
		&models.Staff{BaseModel: models.BaseModel{ID: f.teacherStaffID}, SchoolID: f.schoolID, StaffCode: "T-POL-1", FirstName: "Assigned", LastName: "Teacher", Email: "assigned.teacher@policy.test", DateOfBirth: now.AddDate(-32, 0, 0), Gender: "female", Designation: "Teacher", EmploymentType: "full-time", JoinDate: now.AddDate(-5, 0, 0), Status: "active"},
		&models.Staff{BaseModel: models.BaseModel{ID: f.otherStaffID}, SchoolID: f.schoolID, StaffCode: "T-POL-2", FirstName: "Other", LastName: "Teacher", Email: "other.teacher@policy.test", DateOfBirth: now.AddDate(-34, 0, 0), Gender: "male", Designation: "Teacher", EmploymentType: "full-time", JoinDate: now.AddDate(-5, 0, 0), Status: "active"},
		&models.Section{BaseModel: models.BaseModel{ID: f.sectionID}, GradeID: gradeID, AcademicYearID: f.yearID, SectionName: "A", ClassTeacherID: &f.teacherStaffID, Capacity: 40},
		&models.Section{BaseModel: models.BaseModel{ID: f.otherSectionID}, GradeID: gradeID, AcademicYearID: f.yearID, SectionName: "B", ClassTeacherID: &f.otherStaffID, Capacity: 40},
		&models.Role{BaseModel: models.BaseModel{ID: adminRoleID}, SchoolID: f.schoolID, RoleName: "Admin", IsSystemRole: true},
		&models.Role{BaseModel: models.BaseModel{ID: principalRoleID}, SchoolID: f.schoolID, RoleName: "Principal", IsSystemRole: true},
		&models.Role{BaseModel: models.BaseModel{ID: teacherRoleID}, SchoolID: f.schoolID, RoleName: "Teacher", IsSystemRole: true},
		&models.Role{BaseModel: models.BaseModel{ID: parentRoleID}, SchoolID: f.schoolID, RoleName: "Parent", IsSystemRole: true},
	}
	for _, seed := range seeds {
		if err := database.DB.Create(seed).Error; err != nil {
			t.Fatalf("seed %T: %v", seed, err)
		}
	}

	teacherLinkedID := f.teacherStaffID
	otherTeacherLinkedID := f.otherStaffID
	users := []models.User{
		{BaseModel: models.BaseModel{ID: "user-policy-admin"}, SchoolID: f.schoolID, Name: "Admin", Email: "admin@policy.test", PasswordHash: "hash", RoleID: adminRoleID, RoleSlug: "admin", IsActive: true, IsVerified: true},
		{BaseModel: models.BaseModel{ID: "user-policy-principal"}, SchoolID: f.schoolID, Name: "Principal", Email: "principal@policy.test", PasswordHash: "hash", RoleID: principalRoleID, RoleSlug: "principal", IsActive: true, IsVerified: true},
		{BaseModel: models.BaseModel{ID: "user-policy-teacher"}, SchoolID: f.schoolID, Name: "Teacher", Email: "assigned.teacher@policy.test", PasswordHash: "hash", RoleID: teacherRoleID, RoleSlug: "teacher", LinkedType: "staff", LinkedID: &teacherLinkedID, IsActive: true, IsVerified: true},
		{BaseModel: models.BaseModel{ID: "user-policy-teacher-other"}, SchoolID: f.schoolID, Name: "Other Teacher", Email: "other.teacher@policy.test", PasswordHash: "hash", RoleID: teacherRoleID, RoleSlug: "teacher", LinkedType: "staff", LinkedID: &otherTeacherLinkedID, IsActive: true, IsVerified: true},
		{BaseModel: models.BaseModel{ID: f.parentUserID}, SchoolID: f.schoolID, Name: "Parent", Email: "parent@policy.test", PasswordHash: "hash", RoleID: parentRoleID, RoleSlug: "parent", IsActive: true, IsVerified: true},
		{BaseModel: models.BaseModel{ID: f.otherParentUserID}, SchoolID: f.schoolID, Name: "Other Parent", Email: "other.parent@policy.test", PasswordHash: "hash", RoleID: parentRoleID, RoleSlug: "parent", IsActive: true, IsVerified: true},
	}
	for i := range users {
		if err := database.DB.Create(&users[i]).Error; err != nil {
			t.Fatalf("seed user: %v", err)
		}
	}

	studentSection := f.sectionID
	otherStudentSection := f.otherSectionID
	records := []any{
		&models.Student{BaseModel: models.BaseModel{ID: f.studentID}, SchoolID: f.schoolID, StudentCode: "POL-ST-1", AdmissionNumber: "POL-ADM-1", FirstName: "Linked", LastName: "Student", DateOfBirth: now.AddDate(-10, 0, 0), Gender: "female", AdmissionDate: now, CurrentSectionID: &studentSection, Status: "active"},
		&models.Student{BaseModel: models.BaseModel{ID: f.otherStudentID}, SchoolID: f.schoolID, StudentCode: "POL-ST-2", AdmissionNumber: "POL-ADM-2", FirstName: "Other", LastName: "Student", DateOfBirth: now.AddDate(-10, 0, 0), Gender: "male", AdmissionDate: now, CurrentSectionID: &otherStudentSection, Status: "active"},
		&models.Enrollment{BaseModel: models.BaseModel{ID: f.enrollmentID}, StudentID: f.studentID, SectionID: f.sectionID, AcademicYearID: f.yearID, RollNumber: "1", EnrollmentDate: now, Status: "enrolled"},
		&models.Enrollment{BaseModel: models.BaseModel{ID: f.otherEnrollmentID}, StudentID: f.otherStudentID, SectionID: f.otherSectionID, AcademicYearID: f.yearID, RollNumber: "2", EnrollmentDate: now, Status: "enrolled"},
		&models.ParentStudentLink{SchoolID: f.schoolID, ParentUserID: f.parentUserID, StudentID: f.studentID, StudentAdmissionNumber: "POL-ADM-1"},
		&models.ParentStudentLink{SchoolID: f.schoolID, ParentUserID: f.otherParentUserID, StudentID: f.otherStudentID, StudentAdmissionNumber: "POL-ADM-2"},
		&models.StaffSubject{BaseModel: models.BaseModel{ID: "staff-subject-policy"}, StaffID: f.teacherStaffID, SubjectID: f.subjectID, GradeID: gradeID, IsPrimary: true},
		&models.TimetableSlot{BaseModel: models.BaseModel{ID: f.timetableSlotID}, SectionID: f.sectionID, AcademicYearID: f.yearID, TermID: f.termID, DayOfWeek: 5, PeriodNumber: 1, StartTime: "09:00:00", EndTime: "09:45:00", SubjectID: f.subjectID, StaffID: f.teacherStaffID, SlotType: "regular"},
		&models.Homework{BaseModel: models.BaseModel{ID: "homework-linked"}, SchoolID: f.schoolID, Title: "Linked Homework", SectionID: f.sectionID, TeacherID: f.teacherStaffID, StudentID: f.studentID, Subject: "Mathematics", DueDate: now.AddDate(0, 0, 1), Status: "pending"},
		&models.Homework{BaseModel: models.BaseModel{ID: "homework-other"}, SchoolID: f.schoolID, Title: "Other Homework", SectionID: f.otherSectionID, TeacherID: f.otherStaffID, StudentID: f.otherStudentID, Subject: "Science", DueDate: now.AddDate(0, 0, 1), Status: "pending"},
		&models.DiaryEntry{BaseModel: models.BaseModel{ID: "diary-linked"}, SchoolID: f.schoolID, EntryDate: now, SectionID: f.sectionID, TeacherID: f.teacherStaffID, StudentID: f.studentID, Title: "Linked Diary", Subject: "Mathematics"},
		&models.DiaryEntry{BaseModel: models.BaseModel{ID: "diary-other"}, SchoolID: f.schoolID, EntryDate: now, SectionID: f.otherSectionID, TeacherID: f.otherStaffID, StudentID: f.otherStudentID, Title: "Other Diary", Subject: "Science"},
		&models.EventCalendar{BaseModel: models.BaseModel{ID: f.eventID}, SchoolID: f.schoolID, AcademicYearID: f.yearID, EventTitle: "PTM", EventType: "ptm", StartDatetime: now, EndDatetime: now.Add(time.Hour), CreatedBy: f.teacherStaffID},
		&models.ParentTeacherMeeting{BaseModel: models.BaseModel{ID: "ptm-linked"}, EventID: f.eventID, SectionID: f.sectionID, SlotDate: now, SlotTime: "10:00", DurationMin: 15, TeacherID: f.teacherStaffID, GuardianID: "guardian-linked", StudentID: f.studentID, Status: "scheduled"},
		&models.ParentTeacherMeeting{BaseModel: models.BaseModel{ID: "ptm-other"}, EventID: f.eventID, SectionID: f.otherSectionID, SlotDate: now, SlotTime: "10:30", DurationMin: 15, TeacherID: f.otherStaffID, GuardianID: "guardian-other", StudentID: f.otherStudentID, Status: "scheduled"},
		&models.MessageConversation{BaseModel: models.BaseModel{ID: f.conversationID}, SchoolID: f.schoolID, TeacherID: f.teacherStaffID, ParentID: f.parentUserID, StudentID: f.studentID, Title: "Linked conversation", LastMessageTime: now},
		&models.MessageConversation{BaseModel: models.BaseModel{ID: f.otherConvID}, SchoolID: f.schoolID, TeacherID: f.otherStaffID, ParentID: f.otherParentUserID, StudentID: f.otherStudentID, Title: "Other conversation", LastMessageTime: now},
		&models.Message{BaseModel: models.BaseModel{ID: "message-linked"}, ConversationID: f.conversationID, SenderID: f.parentUserID, SenderRole: "parent", Body: "Linked hello", SentAt: now},
		&models.Message{BaseModel: models.BaseModel{ID: "message-other"}, ConversationID: f.otherConvID, SenderID: f.otherParentUserID, SenderRole: "parent", Body: "Other hello", SentAt: now},
	}
	for _, record := range records {
		if err := database.DB.Create(record).Error; err != nil {
			t.Fatalf("seed %T: %v", record, err)
		}
	}

	return f
}

func scopedPolicyRouter(roleName, userID, linkedType, linkedID, email, schoolID string) *gin.Engine {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", schoolID)
		c.Set("role_name", roleName)
		c.Set("role", roleName)
		c.Set("user_id", userID)
		c.Set("linked_type", linkedType)
		if linkedID != "" {
			c.Set("linked_id", linkedID)
		}
		c.Set("email", email)
		c.Next()
	})
	return router
}

func decodePolicyList(t *testing.T, body string) []map[string]any {
	t.Helper()
	var response struct {
		Data []map[string]any `json:"data"`
	}
	if err := json.Unmarshal([]byte(body), &response); err != nil {
		t.Fatalf("decode list: %v body=%s", err, body)
	}
	return response.Data
}

func TestParentStudentLinkListIsScopedToAuthenticatedParent(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	handler := NewCRUDHandler[models.ParentStudentLink]("parent_student_links", "parent_student_links", []string{"parent_user_id", "student_id", "student_admission_number"}, true, "Student", "ParentUser")
	router.GET("/parent-student-links", handler.List)

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/parent-student-links", nil))

	if response.Code != http.StatusOK {
		t.Fatalf("status=%d body=%s", response.Code, response.Body.String())
	}
	rows := decodePolicyList(t, response.Body.String())
	if len(rows) != 1 || rows[0]["student_id"] != f.studentID {
		t.Fatalf("parent should only see linked student link, rows=%v", rows)
	}
}

func TestStudentDashboardCompatIsParentManagedAndLinkedScoped(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	session := models.AttendanceSession{
		BaseModel:       models.BaseModel{ID: "attendance-policy-parent-dashboard"},
		SectionID:       f.sectionID,
		TimetableSlotID: &f.timetableSlotID,
		SubjectID:       f.subjectID,
		StaffID:         f.teacherStaffID,
		Date:            time.Date(2026, 5, 8, 0, 0, 0, 0, time.UTC),
		PeriodNumber:    1,
	}
	records := []any{
		&session,
		&models.StudentAttendance{
			BaseModel:    models.BaseModel{ID: "attendance-policy-parent-dashboard-row"},
			SessionID:    session.ID,
			StudentID:    f.studentID,
			EnrollmentID: f.enrollmentID,
			Status:       "present",
			MarkedAt:     time.Date(2026, 5, 8, 9, 0, 0, 0, time.UTC),
		},
		&models.FeeInvoice{
			BaseModel:      models.BaseModel{ID: "invoice-policy-parent-dashboard"},
			StudentID:      f.studentID,
			AcademicYearID: f.yearID,
			InvoiceNumber:  "INV-POL-PARENT",
			InvoiceDate:    time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC),
			DueDate:        time.Date(2026, 5, 31, 0, 0, 0, 0, time.UTC),
			TotalAmount:    150,
			NetAmount:      150,
			Balance:        125,
			Status:         "pending",
		},
	}
	for _, record := range records {
		if err := database.DB.Create(record).Error; err != nil {
			t.Fatalf("seed %T: %v", record, err)
		}
	}

	handler := NewCompatibilityHandler()
	router := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	router.GET("/dashboard/student", handler.StudentDashboard)

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/dashboard/student?student_id="+f.studentID, nil))
	if response.Code != http.StatusOK {
		t.Fatalf("parent linked student dashboard status=%d body=%s", response.Code, response.Body.String())
	}
	var body struct {
		Data map[string]any `json:"data"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode dashboard: %v body=%s", err, response.Body.String())
	}
	if body.Data["role"] != "Parent" || body.Data["student_scope"] != "parent_managed" || body.Data["student_id"] != f.studentID {
		t.Fatalf("unexpected parent-managed dashboard payload: %#v", body.Data)
	}
	if body.Data["attendance_count"] != float64(1) || body.Data["pending_fees"] != float64(125) {
		t.Fatalf("unexpected student dashboard metrics: %#v", body.Data)
	}

	otherResponse := httptest.NewRecorder()
	router.ServeHTTP(otherResponse, httptest.NewRequest(http.MethodGet, "/dashboard/student?student_id="+f.otherStudentID, nil))
	if otherResponse.Code != http.StatusForbidden {
		t.Fatalf("unlinked student dashboard status=%d body=%s", otherResponse.Code, otherResponse.Body.String())
	}

	adminRouter := scopedPolicyRouter("Admin", "user-policy-admin", "", "", "admin@policy.test", f.schoolID)
	adminRouter.GET("/dashboard/student", handler.StudentDashboard)
	adminResponse := httptest.NewRecorder()
	adminRouter.ServeHTTP(adminResponse, httptest.NewRequest(http.MethodGet, "/dashboard/student?student_id="+f.studentID, nil))
	if adminResponse.Code != http.StatusForbidden {
		t.Fatalf("admin student dashboard compat status=%d body=%s", adminResponse.Code, adminResponse.Body.String())
	}
}

func TestTeacherStudentListIsScopedToAssignedSections(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	router.GET("/students", NewStudentHandler().GetStudents)

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/students", nil))

	if response.Code != http.StatusOK {
		t.Fatalf("status=%d body=%s", response.Code, response.Body.String())
	}
	rows := decodePolicyList(t, response.Body.String())
	if len(rows) != 1 || rows[0]["id"] != f.studentID {
		t.Fatalf("teacher should only see assigned-section students, rows=%v", rows)
	}
}

func TestTeacherCannotCreateAttendanceSessionForUnassignedSection(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	router.POST("/attendance/sessions", NewAttendanceHandler().CreateAttendanceSession)

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(
		http.MethodPost,
		"/attendance/sessions",
		strings.NewReader(`{"section_id":"`+f.otherSectionID+`","subject_id":"`+f.otherSubjectID+`","staff_id":"`+f.teacherStaffID+`","date":"2026-05-08","period_number":1}`),
	))

	if response.Code != http.StatusForbidden {
		t.Fatalf("teacher unassigned attendance create status=%d body=%s", response.Code, response.Body.String())
	}
}

func TestAttendanceMarkRejectsStudentOutsideSessionSection(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	session := models.AttendanceSession{
		BaseModel:       models.BaseModel{ID: "attendance-policy-session"},
		SectionID:       f.sectionID,
		TimetableSlotID: &f.timetableSlotID,
		SubjectID:       f.subjectID,
		StaffID:         f.teacherStaffID,
		Date:            time.Date(2026, 5, 8, 0, 0, 0, 0, time.UTC),
		PeriodNumber:    1,
	}
	if err := database.DB.Create(&session).Error; err != nil {
		t.Fatalf("seed attendance session: %v", err)
	}
	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	router.POST("/attendance/sessions/:session_id/mark", NewAttendanceHandler().MarkStudentAttendance)

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(
		http.MethodPost,
		"/attendance/sessions/"+session.ID+"/mark",
		strings.NewReader(`{"attendances":[{"student_id":"`+f.otherStudentID+`","enrollment_id":"`+f.otherEnrollmentID+`","status":"present"}]}`),
	))

	if response.Code != http.StatusBadRequest {
		t.Fatalf("outside-section attendance mark status=%d body=%s", response.Code, response.Body.String())
	}
}

func TestParentHomeworkAndDiaryListsAreScopedToLinkedStudents(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	homework := NewCRUDHandler[models.Homework]("homework", "homework", []string{"title"}, true)
	diary := NewCRUDHandler[models.DiaryEntry]("diary_entries", "diary_entries", []string{"title"}, true)
	router.GET("/homework", homework.List)
	router.GET("/diary-entries", diary.List)

	homeworkResp := httptest.NewRecorder()
	router.ServeHTTP(homeworkResp, httptest.NewRequest(http.MethodGet, "/homework", nil))
	if homeworkResp.Code != http.StatusOK {
		t.Fatalf("homework status=%d body=%s", homeworkResp.Code, homeworkResp.Body.String())
	}
	homeworkRows := decodePolicyList(t, homeworkResp.Body.String())
	if len(homeworkRows) != 1 || homeworkRows[0]["id"] != "homework-linked" {
		t.Fatalf("parent should only see linked homework, rows=%v", homeworkRows)
	}

	diaryResp := httptest.NewRecorder()
	router.ServeHTTP(diaryResp, httptest.NewRequest(http.MethodGet, "/diary-entries", nil))
	if diaryResp.Code != http.StatusOK {
		t.Fatalf("diary status=%d body=%s", diaryResp.Code, diaryResp.Body.String())
	}
	diaryRows := decodePolicyList(t, diaryResp.Body.String())
	if len(diaryRows) != 1 || diaryRows[0]["id"] != "diary-linked" {
		t.Fatalf("parent should only see linked diary, rows=%v", diaryRows)
	}
}

func TestParentHomeworkStudentFilterReturnsSelectedChildAssignments(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	now := time.Date(2026, 5, 8, 9, 0, 0, 0, time.UTC)
	extraRecords := []any{
		&models.ParentStudentLink{
			BaseModel:              models.BaseModel{ID: "parent-link-policy-second-child"},
			SchoolID:               f.schoolID,
			ParentUserID:           f.parentUserID,
			StudentID:              f.otherStudentID,
			StudentAdmissionNumber: "POL-ADM-2",
		},
		&models.Homework{
			BaseModel: models.BaseModel{ID: "homework-linked-section"},
			SchoolID:  f.schoolID,
			Title:     "Linked Section Homework",
			SectionID: f.sectionID,
			TeacherID: f.teacherStaffID,
			Subject:   "Mathematics",
			DueDate:   now.AddDate(0, 0, 1),
			Status:    "pending",
		},
	}
	for _, record := range extraRecords {
		if err := database.DB.Create(record).Error; err != nil {
			t.Fatalf("seed %T: %v", record, err)
		}
	}

	router := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	homework := NewCRUDHandler[models.Homework]("homework", "homework", []string{"title"}, true)
	router.GET("/homework", homework.List)

	response := httptest.NewRecorder()
	router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/homework?student_id="+f.studentID, nil))
	if response.Code != http.StatusOK {
		t.Fatalf("student-filtered homework status=%d body=%s", response.Code, response.Body.String())
	}
	rows := decodePolicyList(t, response.Body.String())
	gotIDs := map[string]bool{}
	for _, row := range rows {
		gotIDs[row["id"].(string)] = true
	}
	wantIDs := map[string]bool{
		"homework-linked":         true,
		"homework-linked-section": true,
	}
	if len(gotIDs) != len(wantIDs) {
		t.Fatalf("student-filtered homework ids=%v, want %v; rows=%v", gotIDs, wantIDs, rows)
	}
	for id := range wantIDs {
		if !gotIDs[id] {
			t.Fatalf("student-filtered homework missing %s, ids=%v rows=%v", id, gotIDs, rows)
		}
	}
	if gotIDs["homework-other"] {
		t.Fatalf("student-filtered homework included another linked child assignment, rows=%v", rows)
	}
}

func TestParentMessagingAndPTMAreParticipantScoped(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	conversations := NewCRUDHandler[models.MessageConversation]("message_conversations", "message_conversations", []string{"teacher_id", "parent_id"}, true)
	messages := NewCRUDHandler[models.Message]("messages", "messages", []string{"conversation_id", "sender_id", "sender_role", "body"}, false)
	ptm := NewCRUDHandler[models.ParentTeacherMeeting]("parent_teacher_meetings", "parent_teacher_meetings", []string{"event_id", "section_id", "teacher_id", "guardian_id", "student_id"}, false, "Event", "Section", "Teacher", "Guardian", "Student")
	router.GET("/message-conversations", conversations.List)
	router.GET("/messages", messages.List)
	router.GET("/parent-teacher-meetings", ptm.List)

	convResp := httptest.NewRecorder()
	router.ServeHTTP(convResp, httptest.NewRequest(http.MethodGet, "/message-conversations", nil))
	convRows := decodePolicyList(t, convResp.Body.String())
	if len(convRows) != 1 || convRows[0]["id"] != f.conversationID {
		t.Fatalf("parent should only see linked conversation, rows=%v", convRows)
	}

	messageResp := httptest.NewRecorder()
	router.ServeHTTP(messageResp, httptest.NewRequest(http.MethodGet, "/messages", nil))
	messageRows := decodePolicyList(t, messageResp.Body.String())
	if len(messageRows) != 1 || messageRows[0]["id"] != "message-linked" {
		t.Fatalf("parent should only see linked conversation messages, rows=%v", messageRows)
	}

	ptmResp := httptest.NewRecorder()
	router.ServeHTTP(ptmResp, httptest.NewRequest(http.MethodGet, "/parent-teacher-meetings", nil))
	ptmRows := decodePolicyList(t, ptmResp.Body.String())
	if len(ptmRows) != 1 || ptmRows[0]["id"] != "ptm-linked" {
		t.Fatalf("parent should only see linked PTM rows, rows=%v", ptmRows)
	}
}

func TestTeacherTimetableAndSectionsReadsAreScoped(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	router.GET("/timetable/slots", NewTimetableHandler().GetTimetableSlots)
	router.GET("/sections", NewSchoolHandler().GetSections)

	ownSlots := httptest.NewRecorder()
	router.ServeHTTP(ownSlots, httptest.NewRequest(http.MethodGet, "/timetable/slots", nil))
	if ownSlots.Code != http.StatusOK {
		t.Fatalf("teacher timetable status=%d body=%s", ownSlots.Code, ownSlots.Body.String())
	}
	slotRows := decodePolicyList(t, ownSlots.Body.String())
	if len(slotRows) != 1 || slotRows[0]["staff_id"] != f.teacherStaffID {
		t.Fatalf("teacher timetable should only include own slots, rows=%v", slotRows)
	}

	otherStaff := httptest.NewRecorder()
	router.ServeHTTP(otherStaff, httptest.NewRequest(http.MethodGet, "/timetable/slots?staff_id="+f.otherStaffID, nil))
	if otherStaff.Code != http.StatusForbidden {
		t.Fatalf("teacher should not request another staff timetable, status=%d body=%s", otherStaff.Code, otherStaff.Body.String())
	}

	sections := httptest.NewRecorder()
	router.ServeHTTP(sections, httptest.NewRequest(http.MethodGet, "/sections", nil))
	if sections.Code != http.StatusOK {
		t.Fatalf("teacher sections status=%d body=%s", sections.Code, sections.Body.String())
	}
	sectionRows := decodePolicyList(t, sections.Body.String())
	if len(sectionRows) != 1 || sectionRows[0]["id"] != f.sectionID {
		t.Fatalf("teacher sections should only include assigned sections, rows=%v", sectionRows)
	}
}

func TestMessageUpdateOnlyAllowsReadReceipt(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	messages := NewCRUDHandler[models.Message]("messages", "messages", []string{"conversation_id", "sender_id", "sender_role", "body"}, false)
	router.PUT("/messages/:id", messages.Update)

	mutate := httptest.NewRecorder()
	router.ServeHTTP(
		mutate,
		httptest.NewRequest(http.MethodPut, "/messages/message-linked", strings.NewReader(`{"is_read":true,"body":"tampered"}`)),
	)
	if mutate.Code != http.StatusBadRequest {
		t.Fatalf("message update should reject mutable fields, status=%d body=%s", mutate.Code, mutate.Body.String())
	}

	read := httptest.NewRecorder()
	router.ServeHTTP(
		read,
		httptest.NewRequest(http.MethodPut, "/messages/message-linked", strings.NewReader(`{"is_read":true}`)),
	)
	if read.Code != http.StatusOK {
		t.Fatalf("message read receipt status=%d body=%s", read.Code, read.Body.String())
	}
	var message models.Message
	if err := database.DB.First(&message, "id = ?", "message-linked").Error; err != nil {
		t.Fatalf("load message: %v", err)
	}
	if !message.IsRead || message.Body != "Linked hello" {
		t.Fatalf("message read update mutated unexpected fields: %+v", message)
	}
}

func TestParentAttendanceSummaryAndPTMBookingAreLinkedScoped(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	if err := database.DB.Create(&models.AttendanceSummary{
		BaseModel:      models.BaseModel{ID: "summary-linked"},
		StudentID:      f.studentID,
		SectionID:      f.sectionID,
		AcademicYearID: f.yearID,
		TermID:         &f.termID,
		TotalDays:      20,
		PresentDays:    19,
		AbsentDays:     1,
		AttendancePct:  95,
		UpdatedAt:      time.Now().UTC(),
	}).Error; err != nil {
		t.Fatalf("seed linked summary: %v", err)
	}
	if err := database.DB.Create(&models.AttendanceSummary{
		BaseModel:      models.BaseModel{ID: "summary-other"},
		StudentID:      f.otherStudentID,
		SectionID:      f.otherSectionID,
		AcademicYearID: f.yearID,
		TermID:         &f.termID,
		TotalDays:      20,
		PresentDays:    10,
		AbsentDays:     10,
		AttendancePct:  50,
		UpdatedAt:      time.Now().UTC(),
	}).Error; err != nil {
		t.Fatalf("seed other summary: %v", err)
	}

	router := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	attendance := NewAttendanceHandler()
	ptm := NewParentTeacherMeetingHandler()
	router.GET("/attendance/summary", attendance.GetStudentAttendanceSummary)
	router.PUT("/parent-teacher-meetings/:id/book", ptm.Book)

	linkedSummary := httptest.NewRecorder()
	router.ServeHTTP(linkedSummary, httptest.NewRequest(http.MethodGet, "/attendance/summary?student_id="+f.studentID, nil))
	if linkedSummary.Code != http.StatusOK {
		t.Fatalf("linked summary status=%d body=%s", linkedSummary.Code, linkedSummary.Body.String())
	}

	otherSummary := httptest.NewRecorder()
	router.ServeHTTP(otherSummary, httptest.NewRequest(http.MethodGet, "/attendance/summary?student_id="+f.otherStudentID, nil))
	if otherSummary.Code != http.StatusForbidden {
		t.Fatalf("other summary should be forbidden, status=%d body=%s", otherSummary.Code, otherSummary.Body.String())
	}

	bookLinked := httptest.NewRecorder()
	router.ServeHTTP(bookLinked, httptest.NewRequest(http.MethodPut, "/parent-teacher-meetings/ptm-linked/book", strings.NewReader(`{"notes":"Booked by parent"}`)))
	if bookLinked.Code != http.StatusOK {
		t.Fatalf("book linked PTM status=%d body=%s", bookLinked.Code, bookLinked.Body.String())
	}
	var linkedPTM models.ParentTeacherMeeting
	if err := database.DB.First(&linkedPTM, "id = ?", "ptm-linked").Error; err != nil {
		t.Fatalf("load linked ptm: %v", err)
	}
	if linkedPTM.Status != "booked" {
		t.Fatalf("linked PTM was not booked: %+v", linkedPTM)
	}

	bookOther := httptest.NewRecorder()
	router.ServeHTTP(bookOther, httptest.NewRequest(http.MethodPut, "/parent-teacher-meetings/ptm-other/book", strings.NewReader(`{"notes":"bad scope"}`)))
	if bookOther.Code != http.StatusForbidden {
		t.Fatalf("book other PTM should be forbidden, status=%d body=%s", bookOther.Code, bookOther.Body.String())
	}
}

func TestTeacherStudentSubresourcesRejectOutsideSection(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	ctx, _ := gin.CreateTestContext(httptest.NewRecorder())
	ctx.Set("school_id", f.schoolID)
	ctx.Set("role_name", "Teacher")
	ctx.Set("role", "Teacher")
	ctx.Set("user_id", "user-policy-teacher")
	ctx.Set("linked_type", "staff")
	ctx.Set("linked_id", f.teacherStaffID)
	ctx.Set("email", "assigned.teacher@policy.test")
	if canAccessStudent(ctx, f.otherStudentID) {
		t.Fatalf("teacher policy helper allowed outside-section student")
	}

	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	studentHandler := NewStudentHandler()
	compatHandler := NewCompatibilityHandler()

	router.GET("/students/:id/attendance", studentHandler.GetStudentAttendance)
	router.GET("/students/:id/fees", studentHandler.GetStudentFees)
	router.GET("/students/:id/marks", studentHandler.GetStudentMarks)
	router.GET("/students/:id/transport", studentHandler.GetStudentTransport)
	router.GET("/compat/students/:id/marks", compatHandler.GetStudentGrades)

	for _, tc := range []struct {
		name string
		path string
	}{
		{"attendance", "/students/" + f.otherStudentID + "/attendance"},
		{"fees", "/students/" + f.otherStudentID + "/fees"},
		{"marks", "/students/" + f.otherStudentID + "/marks"},
		{"transport", "/students/" + f.otherStudentID + "/transport"},
		{"compat marks", "/compat/students/" + f.otherStudentID + "/marks"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			response := httptest.NewRecorder()
			router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, tc.path, nil))
			if response.Code != http.StatusForbidden {
				t.Fatalf("status=%d body=%s", response.Code, response.Body.String())
			}
		})
	}
}

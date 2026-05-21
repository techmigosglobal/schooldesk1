package database

import (
	"errors"
	"fmt"
	"log"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"

	"school-backend/internal/config"
	"school-backend/internal/models"

	"github.com/glebarez/sqlite"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func Initialize(cfg *config.Config) error {
	logLevel := logger.Silent
	if cfg.Environment == "development" {
		logLevel = logger.Info
	}

	gormCfg := &gorm.Config{
		Logger:                                   logger.Default.LogMode(logLevel),
		DisableForeignKeyConstraintWhenMigrating: true,
	}
	normalizedDatabaseURL := normalizeDatabaseURL(cfg.DatabaseURL)
	if cfg.UsePostgresOnly && !shouldUsePostgres(normalizedDatabaseURL) {
		return errors.New("production requires postgres DATABASE_URL")
	}
	err := retryStartup("database", cfg, func() error {
		var openErr error
		if shouldUsePostgres(normalizedDatabaseURL) {
			DB, openErr = gorm.Open(postgres.Open(normalizedDatabaseURL), gormCfg)
		} else {
			DB, openErr = gorm.Open(sqlite.Open(cfg.DatabaseDSN), gormCfg)
		}
		if openErr != nil {
			return openErr
		}
		sqlDB, openErr := DB.DB()
		if openErr != nil {
			return openErr
		}
		if err := sqlDB.Ping(); err != nil {
			_ = sqlDB.Close()
			return err
		}
		configurePool(sqlDB, cfg)
		return nil
	})
	if err != nil {
		return err
	}

	log.Println("Database connected successfully")

	if cfg.MigrateOnStart {
		if err := autoMigrate(); err != nil {
			return err
		}
		if err := ensureCompatibilitySchema(); err != nil {
			return err
		}
		if cfg.EnableRelationshipConstraints {
			if err := ApplyRelationshipConstraints(DB); err != nil {
				return err
			}
			log.Println("Database relationship constraints verified")
		}

		log.Println("Database migrations completed")
	}

	if err := ensureDefaultRolePermissions(); err != nil {
		log.Printf("Warning: role permission backfill failed: %v", err)
	}

	if cfg.SeedOnStart {
		if err := seedData(); err != nil {
			log.Printf("Warning: Seed data error (may already exist): %v", err)
		}
	}

	return nil
}

type sqlPool interface {
	SetMaxOpenConns(int)
	SetMaxIdleConns(int)
	SetConnMaxLifetime(time.Duration)
	Ping() error
	Close() error
}

func configurePool(sqlDB sqlPool, cfg *config.Config) {
	if cfg.DBMaxOpenConns > 0 {
		sqlDB.SetMaxOpenConns(cfg.DBMaxOpenConns)
	}
	if cfg.DBMaxIdleConns > 0 {
		sqlDB.SetMaxIdleConns(cfg.DBMaxIdleConns)
	}
	if cfg.DBConnMaxLifetimeMinutes > 0 {
		sqlDB.SetConnMaxLifetime(time.Duration(cfg.DBConnMaxLifetimeMinutes) * time.Minute)
	}
}

func retryStartup(name string, cfg *config.Config, connect func() error) error {
	attempts := cfg.StartupRetryAttempts
	if attempts < 1 {
		attempts = 1
	}
	delay := time.Duration(cfg.StartupRetryDelaySeconds) * time.Second
	if delay <= 0 {
		delay = time.Second
	}
	var lastErr error
	for attempt := 1; attempt <= attempts; attempt++ {
		if err := connect(); err != nil {
			lastErr = err
			if attempt == attempts {
				break
			}
			log.Printf("%s unavailable, retrying %d/%d: %v", name, attempt, attempts, err)
			time.Sleep(delay)
			continue
		}
		return nil
	}
	return lastErr
}

func Close() error {
	if DB == nil {
		return nil
	}
	sqlDB, err := DB.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}

func shouldUsePostgres(databaseURL string) bool {
	url := normalizeDatabaseURL(databaseURL)
	if url == "" {
		return false
	}
	// Common formats: postgres://... or postgresql://...
	return strings.HasPrefix(url, "postgres://") || strings.HasPrefix(url, "postgresql://")
}

func normalizeDatabaseURL(databaseURL string) string {
	url := strings.TrimSpace(databaseURL)
	if url == "" {
		return ""
	}

	// Tolerate accidental "DATABASE_URL=..." value pasted into env.
	url = strings.TrimPrefix(url, "DATABASE_URL=")
	url = strings.TrimSpace(url)

	// Tolerate malformed scheme "postgres:user:pass@host/db".
	if strings.HasPrefix(url, "postgres:") && !strings.HasPrefix(url, "postgres://") {
		url = "postgres://" + strings.TrimPrefix(url, "postgres:")
	}
	if strings.HasPrefix(url, "postgresql:") && !strings.HasPrefix(url, "postgresql://") {
		url = "postgresql://" + strings.TrimPrefix(url, "postgresql:")
	}

	return url
}

func autoMigrate() error {
	// Phase 1: foundational tables without heavy cross-dependencies.
	if err := DB.AutoMigrate(
		&models.School{},
		&models.AcademicYear{},
		&models.Term{},
		&models.Holiday{},
		&models.WorkingDayConfig{},
		&models.Department{},
		&models.Subject{},
		&models.Grade{},
		&models.GradeSubject{},
		&models.Room{},
		&models.Role{},
		&models.Permission{},
	); err != nil {
		return err
	}

	// Phase 2: staff/student/auth core.
	if err := DB.AutoMigrate(
		&models.Staff{},
		&models.StaffQualification{},
		&models.StaffSubject{},
		&models.StaffDocument{},
		&models.Section{},
		&models.Student{},
		&models.Guardian{},
		&models.MedicalRecord{},
		&models.StudentDocument{},
		&models.Enrollment{},
		&models.ParentStudentLink{},
		&models.TransferRecord{},
		&models.PromotionRule{},
		&models.User{},
		&models.UserSession{},
		&models.OTPVerification{},
		&models.AuditLog{},
	); err != nil {
		return err
	}

	// Phase 3: operational domains.
	if err := DB.AutoMigrate(
		&models.TimetableSlot{},
		&models.Substitution{},
		&models.AttendanceSession{},
		&models.StudentAttendance{},
		&models.StaffAttendance{},
		&models.AttendanceSummary{},
		&models.ExamType{},
		&models.Exam{},
		&models.ExamSchedule{},
		&models.StudentMark{},
		&models.GradingScale{},
		&models.ReportCard{},
		&models.ReportExport{},
		&models.FeeCategory{},
		&models.FeeStructure{},
		&models.FeeConcession{},
		&models.FeeInvoice{},
		&models.FeeInvoiceItem{},
		&models.Payment{},
		&models.ParentPaymentRequest{},
		&models.BookCategory{},
		&models.Book{},
		&models.BookIssue{},
		&models.Vehicle{},
		&models.Route{},
		&models.RouteStop{},
		&models.StudentTransport{},
		&models.Announcement{},
		&models.EventCalendar{},
		&models.ParentTeacherMeeting{},
		&models.Homework{},
		&models.HomeworkSubmission{},
		&models.DiaryEntry{},
		&models.MessageConversation{},
		&models.Message{},
		&models.NotificationLog{},
		&models.NotificationDeviceToken{},
		&models.LeaveType{},
		&models.LeaveBalance{},
		&models.LeaveApplication{},
		&models.StudentLeaveApplication{},
		&models.Payroll{},
		&models.FrontendRecord{},
	); err != nil {
		return err
	}
	if err := normalizeParentPaymentRequestColumns(); err != nil {
		return err
	}

	return nil
}

func normalizeParentPaymentRequestColumns() error {
	if DB == nil || DB.Dialector.Name() != "postgres" {
		return nil
	}
	for _, column := range []string{
		"school_id",
		"invoice_id",
		"student_id",
		"parent_user_id",
		"payment_id",
		"decided_by",
	} {
		statement := fmt.Sprintf(
			"ALTER TABLE parent_payment_requests ALTER COLUMN %s TYPE text USING %s::text",
			column,
			column,
		)
		if err := DB.Exec(statement).Error; err != nil {
			return err
		}
	}
	return nil
}

func seedData() error {
	var count int64
	DB.Model(&models.School{}).Count(&count)
	if count > 0 {
		return nil
	}

	log.Println("Seeding initial data...")

	schoolID := "550e8400-e29b-41d4-a716-446655440000"
	school := models.School{
		BaseModel:        models.BaseModel{ID: schoolID},
		Name:             "Demo International School",
		SchoolType:       "cbse",
		AffiliationBoard: "CBSE",
		Email:            "info@demoschool.edu",
		Phone:            "+91-9876543210",
		City:             "Mumbai",
		State:            "Maharashtra",
		Timezone:         "Asia/Kolkata",
		Currency:         "INR",
	}
	DB.Create(&school)

	yearID := "660e8400-e29b-41d4-a716-446655440000"
	academicYear := models.AcademicYear{
		BaseModel: models.BaseModel{ID: yearID},
		SchoolID:  schoolID,
		YearLabel: "2025-2026",
		StartDate: time.Date(2025, 4, 1, 0, 0, 0, 0, time.UTC),
		EndDate:   time.Date(2026, 3, 31, 0, 0, 0, 0, time.UTC),
		IsCurrent: true,
		Status:    "active",
	}
	DB.Create(&academicYear)

	term1ID := "770e8400-e29b-41d4-a716-446655440001"
	term1 := models.Term{
		BaseModel:      models.BaseModel{ID: term1ID},
		AcademicYearID: yearID,
		TermNumber:     1,
		TermName:       "First Term",
		StartDate:      time.Date(2025, 4, 1, 0, 0, 0, 0, time.UTC),
		EndDate:        time.Date(2025, 9, 30, 0, 0, 0, 0, time.UTC),
		IsCurrent:      true,
	}
	DB.Create(&term1)

	term2ID := "770e8400-e29b-41d4-a716-446655440002"
	term2 := models.Term{
		BaseModel:      models.BaseModel{ID: term2ID},
		AcademicYearID: yearID,
		TermNumber:     2,
		TermName:       "Second Term",
		StartDate:      time.Date(2025, 10, 1, 0, 0, 0, 0, time.UTC),
		EndDate:        time.Date(2026, 3, 31, 0, 0, 0, 0, time.UTC),
		IsCurrent:      false,
	}
	DB.Create(&term2)

	deptID := "880e8400-e29b-41d4-a716-446655440000"
	dept := models.Department{
		BaseModel:      models.BaseModel{ID: deptID},
		SchoolID:       schoolID,
		DepartmentName: "Science",
		Description:    "Science Department",
	}
	DB.Create(&dept)

	grade1ID := "990e8400-e29b-41d4-a716-446655440001"
	grade1 := models.Grade{
		BaseModel:   models.BaseModel{ID: grade1ID},
		SchoolID:    schoolID,
		GradeNumber: 1,
		GradeName:   "Grade 1",
	}
	DB.Create(&grade1)

	grade2ID := "990e8400-e29b-41d4-a716-446655440002"
	grade2 := models.Grade{
		BaseModel:   models.BaseModel{ID: grade2ID},
		SchoolID:    schoolID,
		GradeNumber: 2,
		GradeName:   "Grade 2",
	}
	DB.Create(&grade2)

	grade10ID := "990e8400-e29b-41d4-a716-446655440010"
	grade10 := models.Grade{
		BaseModel:   models.BaseModel{ID: grade10ID},
		SchoolID:    schoolID,
		GradeNumber: 10,
		GradeName:   "Grade 10",
	}
	DB.Create(&grade10)

	subjID := "aa0e8400-e29b-41d4-a716-446655440001"
	subj := models.Subject{
		BaseModel:    models.BaseModel{ID: subjID},
		SchoolID:     schoolID,
		DepartmentID: deptID,
		SubjectName:  "Mathematics",
		SubjectCode:  "MATH",
		SubjectType:  "core",
		CreditHours:  4,
	}
	DB.Create(&subj)

	subj2ID := "aa0e8400-e29b-41d4-a716-446655440002"
	subj2 := models.Subject{
		BaseModel:    models.BaseModel{ID: subj2ID},
		SchoolID:     schoolID,
		DepartmentID: deptID,
		SubjectName:  "Science",
		SubjectCode:  "SCI",
		SubjectType:  "core",
		CreditHours:  4,
	}
	DB.Create(&subj2)

	sectionID := "bb0e8400-e29b-41d4-a716-446655440001"
	section := models.Section{
		BaseModel:      models.BaseModel{ID: sectionID},
		GradeID:        grade10ID,
		AcademicYearID: yearID,
		SectionName:    "A",
		Capacity:       40,
	}
	DB.Create(&section)

	roomID := "cc0e8400-e29b-41d4-a716-446655440001"
	room := models.Room{
		BaseModel:  models.BaseModel{ID: roomID},
		SchoolID:   schoolID,
		RoomNumber: "101",
		RoomType:   "classroom",
		Block:      "A",
		Floor:      1,
		Capacity:   40,
	}
	DB.Create(&room)

	staffID := "dd0e8400-e29b-41d4-a716-446655440001"
	staff := models.Staff{
		BaseModel:      models.BaseModel{ID: staffID},
		SchoolID:       schoolID,
		StaffCode:      "STF001",
		FirstName:      "John",
		LastName:       "Doe",
		Email:          "john.doe@demoschool.edu",
		Phone:          "+91-9876543211",
		DateOfBirth:    time.Date(1985, 6, 15, 0, 0, 0, 0, time.UTC),
		Gender:         "male",
		DepartmentID:   &deptID,
		Designation:    "Senior Teacher",
		EmploymentType: "permanent",
		JoinDate:       time.Date(2020, 3, 1, 0, 0, 0, 0, time.UTC),
		BasicSalary:    50000,
		Status:         "active",
	}
	DB.Create(&staff)

	studentID := "ee0e8400-e29b-41d4-a716-446655440001"
	student := models.Student{
		BaseModel:        models.BaseModel{ID: studentID},
		SchoolID:         schoolID,
		StudentCode:      "STU001",
		AdmissionNumber:  "ADM2025001",
		FirstName:        "Alice",
		LastName:         "Smith",
		DateOfBirth:      time.Date(2010, 3, 20, 0, 0, 0, 0, time.UTC),
		Gender:           "female",
		CasteCategory:    "general",
		Nationality:      "Indian",
		AdmissionDate:    time.Date(2025, 4, 1, 0, 0, 0, 0, time.UTC),
		CurrentSectionID: &sectionID,
		Status:           "active",
	}
	DB.Create(&student)

	guardianID := "ff0e8400-e29b-41d4-a716-446655440002"
	guardian := models.Guardian{
		BaseModel:    models.BaseModel{ID: guardianID},
		StudentID:    studentID,
		FullName:     "Robert Smith",
		Relationship: "father",
		Phone:        "+91-9876543212",
		Email:        "robert.smith@email.com",
		Occupation:   "Engineer",
		AnnualIncome: 800000,
		IsPrimary:    true,
		CanPickup:    true,
	}
	DB.Create(&guardian)

	enrollmentID := "ff0e8400-e29b-41d4-a716-446655440001"
	enrollment := models.Enrollment{
		BaseModel:      models.BaseModel{ID: enrollmentID},
		StudentID:      studentID,
		SectionID:      sectionID,
		AcademicYearID: yearID,
		RollNumber:     "1",
		EnrollmentDate: time.Date(2025, 4, 1, 0, 0, 0, 0, time.UTC),
		Status:         "enrolled",
	}
	DB.Create(&enrollment)

	roleAdminID := "110e8400-e29b-41d4-a716-446655440001"
	roleAdmin := models.Role{
		BaseModel:    models.BaseModel{ID: roleAdminID},
		SchoolID:     schoolID,
		RoleName:     "Admin",
		Description:  "School Administrator",
		IsSystemRole: true,
	}
	DB.Create(&roleAdmin)

	roleTeacherID := "110e8400-e29b-41d4-a716-446655440002"
	roleTeacher := models.Role{
		BaseModel:    models.BaseModel{ID: roleTeacherID},
		SchoolID:     schoolID,
		RoleName:     "Teacher",
		Description:  "Teaching Staff",
		IsSystemRole: true,
	}
	DB.Create(&roleTeacher)

	roleParentID := "110e8400-e29b-41d4-a716-446655440003"
	roleParent := models.Role{
		BaseModel:    models.BaseModel{ID: roleParentID},
		SchoolID:     schoolID,
		RoleName:     "Parent",
		Description:  "Parent/Guardian",
		IsSystemRole: true,
	}
	DB.Create(&roleParent)

	rolePrincipalID := "110e8400-e29b-41d4-a716-446655440004"
	rolePrincipal := models.Role{
		BaseModel:    models.BaseModel{ID: rolePrincipalID},
		SchoolID:     schoolID,
		RoleName:     "Principal",
		Description:  "School Principal",
		IsSystemRole: true,
	}
	DB.Create(&rolePrincipal)

	seedRolePermissions(roleAdminID, rolePrincipalID, roleTeacherID, roleParentID)

	feeCatID := "130e8400-e29b-41d4-a716-446655440001"
	feeCat := models.FeeCategory{
		BaseModel:    models.BaseModel{ID: feeCatID},
		SchoolID:     schoolID,
		CategoryName: "Tuition Fee",
		Frequency:    "monthly",
		IsRefundable: false,
	}
	DB.Create(&feeCat)

	feeStructID := "130e8400-e29b-41d4-a716-446655440002"
	feeStructure := models.FeeStructure{
		BaseModel:      models.BaseModel{ID: feeStructID},
		SchoolID:       schoolID,
		AcademicYearID: yearID,
		GradeID:        grade10ID,
		FeeCategoryID:  feeCatID,
		Amount:         5000,
		DueDay:         10,
		LateFinePerDay: 50,
	}
	DB.Create(&feeStructure)

	leaveTypeID := "140e8400-e29b-41d4-a716-446655440001"
	leaveType := models.LeaveType{
		BaseModel:        models.BaseModel{ID: leaveTypeID},
		SchoolID:         schoolID,
		LeaveName:        "Casual Leave",
		MaxDaysPerYear:   12,
		CarryForwardDays: 0,
		IsPaid:           false,
		ApplicableTo:     "all",
	}
	DB.Create(&leaveType)

	log.Println("Seed data created successfully")
	return nil
}

func seedRolePermissions(adminRoleID, principalRoleID, teacherRoleID, parentRoleID string) {
	modules := permissionModules()
	createPermission := func(roleID, module string, read, create, update, delete, export bool) {
		upsertPermission(roleID, module, read, create, update, delete, export)
	}
	for _, module := range modules {
		createPermission(adminRoleID, module, true, true, true, true, true)
		createPermission(principalRoleID, module, true, true, true, module != "audit_logs", true)

		teacherRead := inList(module, "dashboard", "guardians", "medical_records", "student_documents", "staff_subjects", "staff_qualifications", "library", "parent_teacher_meetings", "homework", "diary_entries", "message_conversations", "messages")
		teacherManage := inList(module, "homework", "diary_entries", "message_conversations", "messages", "parent_teacher_meetings")
		createPermission(teacherRoleID, module, teacherRead, teacherManage, teacherManage, false, false)

		parentRead := inList(module, "dashboard", "guardians", "medical_records", "student_documents", "parent_teacher_meetings", "homework", "diary_entries", "message_conversations", "messages")
		parentCreate := inList(module, "parent_teacher_meetings", "message_conversations", "messages")
		parentUpdate := inList(module, "message_conversations", "messages")
		createPermission(parentRoleID, module, parentRead, parentCreate, parentUpdate, false, false)
	}
}

func permissionModules() []string {
	return []string{
		"dashboard",
		"guardians",
		"medical_records",
		"student_documents",
		"staff_documents",
		"staff_subjects",
		"staff_qualifications",
		"transport",
		"library",
		"payroll",
		"parent_teacher_meetings",
		"homework",
		"diary_entries",
		"message_conversations",
		"messages",
		"audit_logs",
	}
}

func upsertPermission(roleID, module string, read, create, update, delete, export bool) {
	permission := models.Permission{}
	values := models.Permission{
		RoleID:    roleID,
		Module:    module,
		CanRead:   read,
		CanCreate: create,
		CanUpdate: update,
		CanDelete: delete,
		CanExport: export,
	}
	DB.Where("role_id = ? AND module = ?", roleID, module).
		Assign(values).
		FirstOrCreate(&permission)
}

func inList(value string, items ...string) bool {
	for _, item := range items {
		if value == item {
			return true
		}
	}
	return false
}

func ensureDefaultRolePermissions() error {
	var roles []models.Role
	if err := DB.Where("LOWER(role_name) IN ?", []string{"admin", "principal", "teacher", "parent"}).Find(&roles).Error; err != nil {
		return err
	}
	roleIDs := map[string]string{}
	for _, role := range roles {
		roleIDs[strings.ToLower(strings.TrimSpace(role.RoleName))] = role.ID
	}
	adminRoleID, okAdmin := roleIDs["admin"]
	principalRoleID, okPrincipal := roleIDs["principal"]
	teacherRoleID, okTeacher := roleIDs["teacher"]
	parentRoleID, okParent := roleIDs["parent"]
	if !okAdmin || !okPrincipal || !okTeacher || !okParent {
		return nil
	}
	seedRolePermissions(adminRoleID, principalRoleID, teacherRoleID, parentRoleID)
	return removeDuplicatePermissions()
}

func removeDuplicatePermissions() error {
	var rows []models.Permission
	if err := DB.Order("role_id, module, created_at, id").Find(&rows).Error; err != nil {
		return err
	}
	seen := map[string]string{}
	duplicates := make([]string, 0)
	for _, row := range rows {
		key := row.RoleID + "\x00" + row.Module
		if _, ok := seen[key]; ok {
			duplicates = append(duplicates, row.ID)
			continue
		}
		seen[key] = row.ID
	}
	if len(duplicates) == 0 {
		return nil
	}
	return DB.Where("id IN ?", duplicates).Delete(&models.Permission{}).Error
}

func HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(bytes), err
}

func CheckPassword(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

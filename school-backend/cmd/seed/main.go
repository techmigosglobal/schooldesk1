package main

import (
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	"school-backend/internal/config"
	"school-backend/internal/database"
	"school-backend/internal/models"
)

func main() {
	cfg := config.Load()
	cfg.MigrateOnStart = true
	cfg.SeedOnStart = false
	if err := database.Initialize(cfg); err != nil {
		log.Fatalf("database initialize failed: %v", err)
	}
	defer func() {
		if err := database.Close(); err != nil {
			log.Printf("database close error: %v", err)
		}
	}()

	credentials, err := seedPrincipal()
	if err != nil {
		log.Fatalf("seed principal failed: %v", err)
	}
	log.Printf("principal ready: email=%s password=%s", credentials.Email, credentials.Password)
}

type principalCredentials struct {
	Email    string
	Password string
}

func seedPrincipal() (principalCredentials, error) {
	email := envOr("PRINCIPAL_EMAIL", "principal@schooldesk.local")
	password := envOr("PRINCIPAL_PASSWORD", "Principal@12345")
	schoolID := envOr("SEED_SCHOOL_ID", "school-default")
	yearID := envOr("SEED_ACADEMIC_YEAR_ID", "academic-year-default")
	roleID := envOr("SEED_PRINCIPAL_ROLE_ID", "role-principal-default")
	staffID := envOr("SEED_PRINCIPAL_STAFF_ID", "staff-principal-default")
	seedAcademicYear := envBool("SEED_ACADEMIC_YEAR", true)
	seedFixtures := envBool("SEED_ACADEMIC_FIXTURES", seedAcademicYear)

	now := time.Now().UTC()
	var schoolCount int64
	if err := database.DB.Model(&models.School{}).Where("id = ?", schoolID).Count(&schoolCount).Error; err != nil {
		return principalCredentials{}, err
	}
	if schoolCount == 0 {
		if err := database.DB.Create(&models.School{
			BaseModel:        models.BaseModel{ID: schoolID},
			Name:             envOr("SEED_SCHOOL_NAME", "SchoolDesk"),
			SchoolType:       "cbse",
			AffiliationBoard: "CBSE",
			Email:            "office@schooldesk.local",
			Timezone:         "Asia/Kolkata",
			Currency:         "INR",
		}).Error; err != nil {
			return principalCredentials{}, err
		}
	}
	if seedAcademicYear {
		if err := database.DB.Where("id = ?", yearID).FirstOrCreate(&models.AcademicYear{}, models.AcademicYear{
			BaseModel: models.BaseModel{ID: yearID},
			SchoolID:  schoolID,
			YearLabel: "2026-2027",
			Year:      "2026-2027",
			StartDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
			EndDate:   time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC),
			IsCurrent: true,
			Status:    "active",
		}).Error; err != nil {
			return principalCredentials{}, err
		}
	}
	if seedFixtures {
		if err := seedAcademicFixtures(schoolID, yearID); err != nil {
			return principalCredentials{}, err
		}
	}
	roles, err := seedRoles(schoolID, roleID)
	if err != nil {
		return principalCredentials{}, err
	}
	if err := database.EnsureDefaultRolePermissions(); err != nil {
		return principalCredentials{}, err
	}
	role := roles["Principal"]
	staff := models.Staff{
		BaseModel:      models.BaseModel{ID: staffID},
		SchoolID:       schoolID,
		StaffCode:      "PRINCIPAL-001",
		FirstName:      "School",
		LastName:       "Principal",
		Email:          email,
		Designation:    "Principal",
		EmploymentType: "permanent",
		JoinDate:       now,
		Status:         "active",
	}
	if err := database.DB.Where("id = ?", staffID).FirstOrCreate(&staff).Error; err != nil {
		return principalCredentials{}, err
	}
	hash, err := database.HashPassword(password)
	if err != nil {
		return principalCredentials{}, err
	}
	user := models.User{}
	if err := database.DB.Where("email = ? AND school_id = ?", email, schoolID).First(&user).Error; err == nil {
		updates := map[string]interface{}{
			"username":      "principal",
			"password_hash": hash,
			"role_id":       role.ID,
			"linked_type":   "staff",
			"linked_id":     staff.ID,
			"is_active":     true,
			"is_verified":   true,
			"name":          "School Principal",
			"role":          "super_admin",
			"updated_at":    now,
		}
		if err := database.DB.Table("users").Where("id = ?", user.ID).Updates(updates).Error; err != nil {
			return principalCredentials{}, err
		}
		return principalCredentials{Email: email, Password: password}, nil
	}
	user = models.User{
		BaseModel:    models.BaseModel{ID: "user-principal-default"},
		SchoolID:     schoolID,
		Username:     "principal",
		Email:        email,
		PasswordHash: hash,
		RoleID:       role.ID,
		LinkedType:   "staff",
		LinkedID:     &staff.ID,
		IsActive:     true,
		IsVerified:   true,
	}
	if err := database.DB.Create(&user).Error; err != nil {
		return principalCredentials{}, err
	}
	_ = database.DB.Table("users").Where("id = ?", user.ID).Updates(map[string]interface{}{
		"name":       "School Principal",
		"role":       "super_admin",
		"updated_at": now,
	}).Error
	return principalCredentials{Email: email, Password: password}, nil
}

func seedAcademicFixtures(schoolID, yearID string) error {
	term := models.Term{
		BaseModel:      models.BaseModel{ID: "term-default-1"},
		AcademicYearID: yearID,
		TermNumber:     1,
		TermName:       "Term 1",
		StartDate:      time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		EndDate:        time.Date(2026, 9, 30, 0, 0, 0, 0, time.UTC),
		IsCurrent:      true,
	}
	if err := database.DB.Where("id = ?", term.ID).FirstOrCreate(&term).Error; err != nil {
		return err
	}

	department := models.Department{
		BaseModel:      models.BaseModel{ID: "department-default-science"},
		SchoolID:       schoolID,
		DepartmentName: "Science",
		Description:    "Default local verification department",
	}
	if err := database.DB.Where("id = ?", department.ID).FirstOrCreate(&department).Error; err != nil {
		return err
	}

	grade := models.Grade{
		BaseModel:   models.BaseModel{ID: "grade-default-pp1"},
		SchoolID:    schoolID,
		GradeNumber: 0,
		GradeName:   "PP1",
	}
	if err := database.DB.Where("id = ?", grade.ID).FirstOrCreate(&grade).Error; err != nil {
		return err
	}

	subject := models.Subject{
		BaseModel:    models.BaseModel{ID: "subject-default-math"},
		SchoolID:     schoolID,
		DepartmentID: department.ID,
		SubjectName:  "Mathematics",
		SubjectCode:  "MATH",
		SubjectType:  "core",
		CreditHours:  4,
	}
	if err := database.DB.Where("id = ?", subject.ID).FirstOrCreate(&subject).Error; err != nil {
		return err
	}

	gradeSubject := models.GradeSubject{
		BaseModel:      models.BaseModel{ID: "grade-subject-default-math"},
		GradeID:        grade.ID,
		SubjectID:      subject.ID,
		PeriodsPerWeek: 5,
		MaxMarks:       100,
		PassMarks:      35,
		IsMandatory:    true,
	}
	if err := database.DB.Where("id = ?", gradeSubject.ID).FirstOrCreate(&gradeSubject).Error; err != nil {
		return err
	}

	section := models.Section{
		BaseModel:      models.BaseModel{ID: "section-default-pp1a"},
		GradeID:        grade.ID,
		AcademicYearID: yearID,
		SectionName:    "A",
		Capacity:       40,
	}
	return database.DB.Where("id = ?", section.ID).FirstOrCreate(&section).Error
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func envBool(key string, fallback bool) bool {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func seedRoles(schoolID string, principalRoleID string) (map[string]models.Role, error) {
	roleSeeds := []models.Role{
		{
			BaseModel:    models.BaseModel{ID: principalRoleID},
			SchoolID:     schoolID,
			RoleName:     "Principal",
			Description:  "School Principal",
			IsSystemRole: true,
		},
		{
			BaseModel:    models.BaseModel{ID: "role-admin-default"},
			SchoolID:     schoolID,
			RoleName:     "Admin",
			Description:  "School administrator",
			IsSystemRole: true,
		},
		{
			BaseModel:    models.BaseModel{ID: "role-teacher-default"},
			SchoolID:     schoolID,
			RoleName:     "Teacher",
			Description:  "Teaching staff",
			IsSystemRole: true,
		},
		{
			BaseModel:    models.BaseModel{ID: "role-student-default"},
			SchoolID:     schoolID,
			RoleName:     "Student",
			Description:  "Student account",
			IsSystemRole: true,
		},
		{
			BaseModel:    models.BaseModel{ID: "role-parent-default"},
			SchoolID:     schoolID,
			RoleName:     "Parent",
			Description:  "Parent or guardian account",
			IsSystemRole: true,
		},
	}
	roles := make(map[string]models.Role, len(roleSeeds))
	for _, seed := range roleSeeds {
		role := seed
		if err := database.DB.Where("school_id = ? AND LOWER(role_name) = ?", schoolID, lower(role.RoleName)).FirstOrCreate(&role).Error; err != nil {
			return nil, err
		}
		roles[role.RoleName] = role
	}
	return roles, nil
}

func lower(value string) string {
	switch value {
	case "Principal":
		return "principal"
	case "Admin":
		return "admin"
	case "Teacher":
		return "teacher"
	case "Student":
		return "student"
	case "Parent":
		return "parent"
	default:
		return value
	}
}

package handlers

import (
	"fmt"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// HomeworkRecord is the canonical Tables.md homework row (table: homework).
type HomeworkRecord struct {
	ID          string    `json:"id"`
	HomeworkID  string    `json:"homework_id"`
	SchoolID    string    `json:"school_id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	SubjectID   string    `json:"subject_id"`
	ClassID     string    `json:"class_id"`
	SectionID   string    `json:"section_id"`
	TeacherID   string    `json:"teacher_id"`
	StaffID     string    `json:"staff_id"`
	StudentID   string    `json:"student_id"`
	DueDate     time.Time `json:"due_date"`
	Status      string    `json:"status"`
}

func homeworkTable() *gorm.DB {
	return database.DB.Table("homework")
}

func loadHomeworkRecord(schoolID, homeworkID string) (HomeworkRecord, error) {
	var row map[string]interface{}
	err := homeworkTable().
		Where(`"homework_id" = ? AND "school_id" = ?`, homeworkID, schoolID).
		Take(&row).Error
	if err != nil {
		return HomeworkRecord{}, err
	}
	return homeworkRecordFromMap(row), nil
}

func homeworkRecordFromMap(row map[string]interface{}) HomeworkRecord {
	id := strings.TrimSpace(homeworkMapString(row["homework_id"]))
	if id == "" {
		id = strings.TrimSpace(homeworkMapString(row["id"]))
	}
	staffID := strings.TrimSpace(homeworkMapString(row["staff_id"]))
	record := HomeworkRecord{
		ID:          id,
		HomeworkID:  id,
		SchoolID:    strings.TrimSpace(homeworkMapString(row["school_id"])),
		Title:       strings.TrimSpace(homeworkMapString(row["title"])),
		Description: strings.TrimSpace(homeworkMapString(row["description"])),
		SubjectID:   strings.TrimSpace(homeworkMapString(row["subject_id"])),
		ClassID:     strings.TrimSpace(homeworkMapString(row["class_id"])),
		SectionID:   strings.TrimSpace(homeworkMapString(row["section_id"])),
		TeacherID:   staffID,
		StaffID:     staffID,
		Status:      strings.TrimSpace(homeworkMapString(row["status"])),
	}
	if record.Status == "" {
		record.Status = "pending"
	}
	if due := strings.TrimSpace(homeworkMapString(row["submission_date"])); due != "" {
		if parsed, err := time.Parse("2006-01-02", due); err == nil {
			record.DueDate = parsed
		}
	}
	return record
}

func canAccessHomeworkRecord(c *gin.Context, homework HomeworkRecord) bool {
	if homework.SchoolID != scopedSchoolID(c) {
		return false
	}
	switch currentRole(c) {
	case "admin", "principal":
		return true
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" {
			return false
		}
		if strings.TrimSpace(homework.TeacherID) == staffID {
			return true
		}
		if strings.TrimSpace(homework.SectionID) != "" && canAccessSection(c, homework.SectionID) {
			return true
		}
		return strings.TrimSpace(homework.StudentID) != "" && canAccessStudent(c, homework.StudentID)
	case "parent":
		parentUserID := currentUserID(c)
		if parentUserID == "" {
			return false
		}
		if strings.TrimSpace(homework.StudentID) != "" {
			return canAccessStudent(c, homework.StudentID)
		}
		if strings.TrimSpace(homework.SectionID) == "" {
			return false
		}
		var count int64
		if err := database.DB.Model(&models.ParentStudentLink{}).
			Joins("JOIN students ON students.id = parent_student_links.student_id").
			Where("parent_student_links.school_id = ? AND parent_student_links.parent_user_id = ?", homework.SchoolID, parentUserID).
			Where("(students.current_section_id = ? OR EXISTS (SELECT 1 FROM enrollments WHERE enrollments.student_id = students.id AND enrollments.section_id = ?))", homework.SectionID, homework.SectionID).
			Count(&count).Error; err != nil {
			return false
		}
		return count > 0
	default:
		return false
	}
}

func homeworkRecordMatchesStudent(homework HomeworkRecord, studentID string) bool {
	studentID = strings.TrimSpace(studentID)
	if studentID == "" {
		return false
	}
	if strings.TrimSpace(homework.StudentID) != "" {
		return strings.TrimSpace(homework.StudentID) == studentID
	}
	sectionID := strings.TrimSpace(homework.SectionID)
	if sectionID == "" {
		return true
	}
	return studentInSection(homework.SchoolID, studentID, sectionID)
}

func homeworkRecordStudentCount(homework HomeworkRecord) int64 {
	if strings.TrimSpace(homework.StudentID) != "" {
		return 1
	}
	sectionID := strings.TrimSpace(homework.SectionID)
	if sectionID == "" {
		return 0
	}
	var total int64
	database.DB.Table("students").
		Where("students.school_id = ?", homework.SchoolID).
		Where(`
		(
			students.current_section_id = ?
			OR EXISTS (
				SELECT 1 FROM enrollments
				WHERE enrollments.student_id = students.id
					AND enrollments.section_id = ?
			)
		)
	`, sectionID, sectionID).
		Distinct("students.id").
		Count(&total)
	return total
}

func homeworkMapString(value interface{}) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(value))
}

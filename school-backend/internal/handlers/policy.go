package handlers

import (
	"fmt"
	"reflect"
	"strings"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func currentUserID(c *gin.Context) string {
	return strings.TrimSpace(c.GetString("user_id"))
}

func currentSchoolID(c *gin.Context) string {
	return scopedSchoolID(c)
}

func currentRole(c *gin.Context) string {
	role := strings.TrimSpace(c.GetString("role_name"))
	if role == "" {
		role = strings.TrimSpace(c.GetString("role"))
	}
	return strings.ToLower(role)
}

func currentStaffID(c *gin.Context) string {
	schoolID := currentSchoolID(c)
	if !strings.EqualFold(strings.TrimSpace(c.GetString("linked_type")), "staff") {
		return staffIDByUserOrEmail(c, schoolID)
	}
	if linkedID := strings.TrimSpace(c.GetString("linked_id")); linkedID != "" {
		return linkedID
	}
	return staffIDByUserOrEmail(c, schoolID)
}

func staffIDByUserOrEmail(c *gin.Context, schoolID string) string {
	if schoolID == "" {
		return ""
	}
	if userID := currentUserID(c); userID != "" {
		var user models.User
		if err := database.DB.First(&user, "id = ? AND school_id = ?", userID, schoolID).Error; err == nil {
			if user.LinkedID != nil && strings.TrimSpace(*user.LinkedID) != "" {
				return strings.TrimSpace(*user.LinkedID)
			}
		}
	}
	if email := strings.TrimSpace(c.GetString("email")); email != "" {
		var staff models.Staff
		if err := database.DB.First(&staff, "school_id = ? AND LOWER(email) = ?", schoolID, strings.ToLower(email)).Error; err == nil {
			return staff.ID
		}
	}
	return ""
}

func isSchoolOperator(c *gin.Context) bool {
	switch currentRole(c) {
	case "admin", "principal":
		return true
	default:
		return false
	}
}

func canAccessStudent(c *gin.Context, studentID string) bool {
	studentID = strings.TrimSpace(studentID)
	if studentID == "" {
		return false
	}
	schoolID := currentSchoolID(c)
	switch currentRole(c) {
	case "admin", "principal":
		return countRows(database.DB.Model(&models.Student{}).Where("id = ? AND school_id = ?", studentID, schoolID)) > 0
	case "parent":
		return countRows(database.DB.Model(&models.ParentStudentLink{}).
			Where("school_id = ? AND parent_user_id = ? AND student_id = ?", schoolID, currentUserID(c), studentID)) > 0
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" {
			return false
		}
		sections := teacherSectionSubquery(staffID, schoolID)
		return countRows(database.DB.Model(&models.Student{}).
			Where("students.id = ? AND students.school_id = ?", studentID, schoolID).
			Where(`
			(
				students.current_section_id IN (?)
				OR EXISTS (
					SELECT 1 FROM enrollments
					WHERE enrollments.student_id = students.id
						AND enrollments.section_id IN (?)
				)
			)
			`, sections, teacherSectionSubquery(staffID, schoolID))) > 0
	default:
		return false
	}
}

func canAccessSection(c *gin.Context, sectionID string) bool {
	sectionID = strings.TrimSpace(sectionID)
	if sectionID == "" {
		return false
	}
	schoolID := currentSchoolID(c)
	switch currentRole(c) {
	case "admin", "principal":
		return sectionBelongsToSchool(sectionID, schoolID)
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" {
			return false
		}
		return countRows(database.DB.Model(&models.Section{}).
			Joins("JOIN grades ON grades.id = sections.grade_id").
			Where("sections.id = ? AND grades.school_id = ?", sectionID, schoolID).
			Where(`
			(
				sections.class_teacher_id = ?
				OR EXISTS (
					SELECT 1 FROM timetable_slots
					WHERE timetable_slots.section_id = sections.id
						AND timetable_slots.staff_id = ?
				)
			)
			`, staffID, staffID)) > 0
	case "parent":
		return countRows(database.DB.Model(&models.ParentStudentLink{}).
			Joins("JOIN students ON students.id = parent_student_links.student_id").
			Where("parent_student_links.school_id = ? AND parent_student_links.parent_user_id = ?", schoolID, currentUserID(c)).
			Where(`
			(
				students.current_section_id = ?
				OR EXISTS (
					SELECT 1 FROM enrollments
					WHERE enrollments.student_id = students.id
						AND enrollments.section_id = ?
				)
			)
			`, sectionID, sectionID)) > 0
	default:
		return false
	}
}

func canAccessGrade(c *gin.Context, gradeID string) bool {
	gradeID = strings.TrimSpace(gradeID)
	if gradeID == "" {
		return false
	}
	schoolID := currentSchoolID(c)
	switch currentRole(c) {
	case "admin", "principal":
		return countRows(database.DB.Model(&models.Grade{}).
			Where("id = ? AND school_id = ?", gradeID, schoolID)) > 0
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" {
			return false
		}
		return countRows(database.DB.Model(&models.Section{}).
			Joins("JOIN grades ON grades.id = sections.grade_id").
			Where("sections.grade_id = ? AND grades.school_id = ?", gradeID, schoolID).
			Where(`
			(
				sections.class_teacher_id = ?
				OR EXISTS (
					SELECT 1 FROM timetable_slots
					WHERE timetable_slots.section_id = sections.id
						AND timetable_slots.staff_id = ?
				)
			)
			`, staffID, staffID)) > 0
	case "parent":
		return countRows(database.DB.Model(&models.ParentStudentLink{}).
			Joins("JOIN students ON students.id = parent_student_links.student_id").
			Joins("LEFT JOIN sections current_sections ON current_sections.id = students.current_section_id").
			Joins("LEFT JOIN enrollments ON enrollments.student_id = students.id").
			Joins("LEFT JOIN sections enrollment_sections ON enrollment_sections.id = enrollments.section_id").
			Where("parent_student_links.school_id = ? AND parent_student_links.parent_user_id = ?", schoolID, currentUserID(c)).
			Where("(current_sections.grade_id = ? OR enrollment_sections.grade_id = ?)", gradeID, gradeID)) > 0
	default:
		return false
	}
}

func canTeachSectionSubject(c *gin.Context, staffID, sectionID, subjectID, timetableSlotID string) bool {
	staffID = strings.TrimSpace(staffID)
	sectionID = strings.TrimSpace(sectionID)
	subjectID = strings.TrimSpace(subjectID)
	timetableSlotID = strings.TrimSpace(timetableSlotID)
	if staffID == "" || sectionID == "" || subjectID == "" {
		return false
	}
	schoolID := currentSchoolID(c)
	role := currentRole(c)
	if role == "teacher" && staffID != currentStaffID(c) {
		return false
	}
	if role == "admin" || role == "principal" {
		return staffBelongsToSchool(staffID, schoolID) &&
			sectionBelongsToSchool(sectionID, schoolID) &&
			subjectBelongsToSchool(subjectID, schoolID)
	}
	if role != "teacher" {
		return false
	}
	if !staffBelongsToSchool(staffID, schoolID) ||
		!sectionBelongsToSchool(sectionID, schoolID) ||
		!subjectBelongsToSchool(subjectID, schoolID) {
		return false
	}
	if timetableSlotID != "" {
		return countRows(database.DB.Model(&models.TimetableSlot{}).
			Joins("JOIN sections ON sections.id = timetable_slots.section_id").
			Joins("JOIN grades ON grades.id = sections.grade_id").
			Where("timetable_slots.id = ? AND timetable_slots.section_id = ? AND timetable_slots.subject_id = ? AND timetable_slots.staff_id = ? AND grades.school_id = ?", timetableSlotID, sectionID, subjectID, staffID, schoolID)) > 0
	}
	if classTeacherForSection(staffID, sectionID, schoolID) {
		return true
	}
	sectionOwned := countRows(database.DB.Model(&models.Section{}).
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("sections.id = ? AND grades.school_id = ?", sectionID, schoolID).
		Where(`
		(
			sections.class_teacher_id = ?
			OR EXISTS (
				SELECT 1 FROM timetable_slots
				WHERE timetable_slots.section_id = sections.id
					AND timetable_slots.staff_id = ?
			)
		)
	`, staffID, staffID)) > 0
	if !sectionOwned {
		return false
	}
	return countRows(database.DB.Model(&models.Section{}).
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("sections.id = ? AND grades.school_id = ?", sectionID, schoolID).
		Where(`
		(
			EXISTS (
				SELECT 1 FROM timetable_slots
				WHERE timetable_slots.section_id = sections.id
					AND timetable_slots.staff_id = ?
					AND timetable_slots.subject_id = ?
			)
			OR EXISTS (
				SELECT 1 FROM staff_subjects
				WHERE staff_subjects.grade_id = sections.grade_id
					AND staff_subjects.staff_id = ?
					AND staff_subjects.subject_id = ?
			)
		)
	`, staffID, subjectID, staffID, subjectID)) > 0
}

func canAccessConversation(c *gin.Context, conversationID string) bool {
	conversationID = strings.TrimSpace(conversationID)
	if conversationID == "" {
		return false
	}
	query := database.DB.Model(&models.MessageConversation{}).
		Where("id = ? AND school_id = ?", conversationID, currentSchoolID(c))
	switch currentRole(c) {
	case "admin", "principal":
		return countRows(query) > 0
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" {
			return false
		}
		return countRows(query.Where("teacher_id = ?", staffID)) > 0
	case "parent":
		return countRows(query.Where("parent_id = ? AND (student_id = '' OR student_id IN (?))", currentUserID(c), linkedStudentSubquery(c))) > 0
	default:
		return false
	}
}

func canAccessParentStudentLink(c *gin.Context, parentUserID, studentID string) bool {
	parentUserID = strings.TrimSpace(parentUserID)
	studentID = strings.TrimSpace(studentID)
	if parentUserID == "" || studentID == "" {
		return false
	}
	switch currentRole(c) {
	case "admin", "principal":
		return countRows(database.DB.Model(&models.ParentStudentLink{}).
			Where("school_id = ? AND parent_user_id = ? AND student_id = ?", currentSchoolID(c), parentUserID, studentID)) > 0
	case "parent":
		return parentUserID == currentUserID(c) && countRows(database.DB.Model(&models.ParentStudentLink{}).
			Where("school_id = ? AND parent_user_id = ? AND student_id = ?", currentSchoolID(c), currentUserID(c), studentID)) > 0
	default:
		return false
	}
}

func sectionBelongsToSchool(sectionID, schoolID string) bool {
	return countRows(database.DB.Model(&models.Section{}).
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("sections.id = ? AND grades.school_id = ?", sectionID, schoolID)) > 0
}

func subjectBelongsToSchool(subjectID, schoolID string) bool {
	return countRows(database.DB.Model(&models.Subject{}).
		Where("id = ? AND school_id = ?", subjectID, schoolID)) > 0
}

func staffBelongsToSchool(staffID, schoolID string) bool {
	return countRows(database.DB.Model(&models.Staff{}).
		Where("id = ? AND school_id = ? AND status != ?", staffID, schoolID, "inactive")) > 0
}

func classTeacherForSection(staffID, sectionID, schoolID string) bool {
	return countRows(database.DB.Model(&models.Section{}).
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("sections.id = ? AND grades.school_id = ? AND sections.class_teacher_id = ?", sectionID, schoolID, staffID)) > 0
}

func linkedStudentSubquery(c *gin.Context) *gorm.DB {
	return database.DB.Model(&models.ParentStudentLink{}).
		Select("student_id").
		Where("school_id = ? AND parent_user_id = ?", currentSchoolID(c), currentUserID(c))
}

func linkedSectionSubquery(c *gin.Context) *gorm.DB {
	return database.DB.Model(&models.Enrollment{}).
		Select("enrollments.section_id").
		Joins("JOIN parent_student_links ON parent_student_links.student_id = enrollments.student_id").
		Where("parent_student_links.school_id = ? AND parent_student_links.parent_user_id = ?", currentSchoolID(c), currentUserID(c))
}

func teacherSectionSubquery(staffID, schoolID string) *gorm.DB {
	return database.DB.Model(&models.Section{}).
		Select("sections.id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ?", schoolID).
		Where(`
		(
			sections.class_teacher_id = ?
			OR EXISTS (
				SELECT 1 FROM timetable_slots
				WHERE timetable_slots.section_id = sections.id
					AND timetable_slots.staff_id = ?
			)
		)
	`, staffID, staffID)
}

func countRows(query *gorm.DB) int64 {
	var count int64
	_ = query.Count(&count).Error
	return count
}

func getStringField(row interface{}, name string) string {
	value := reflect.ValueOf(row)
	if value.Kind() == reflect.Pointer {
		if value.IsNil() {
			return ""
		}
		value = value.Elem()
	}
	if value.Kind() != reflect.Struct {
		return ""
	}
	field := value.FieldByName(name)
	if !field.IsValid() {
		return ""
	}
	switch field.Kind() {
	case reflect.String:
		return field.String()
	case reflect.Pointer:
		if !field.IsNil() && field.Elem().Kind() == reflect.String {
			return field.Elem().String()
		}
	}
	return ""
}

func validateStudentEnrollmentForSession(schoolID string, session models.AttendanceSession, studentID, enrollmentID string) error {
	if strings.TrimSpace(studentID) == "" || strings.TrimSpace(enrollmentID) == "" {
		return fmt.Errorf("student_id and enrollment_id are required")
	}
	count := countRows(database.DB.Model(&models.Enrollment{}).
		Joins("JOIN students ON students.id = enrollments.student_id").
		Joins("JOIN sections ON sections.id = enrollments.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("enrollments.id = ? AND enrollments.student_id = ? AND enrollments.section_id = ?", enrollmentID, studentID, session.SectionID).
		Where("students.school_id = ? AND grades.school_id = ? AND students.status != ?", schoolID, schoolID, "inactive"))
	if count == 0 {
		return fmt.Errorf("student enrollment does not belong to this attendance session")
	}
	return nil
}

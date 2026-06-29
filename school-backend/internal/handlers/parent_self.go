package handlers

import (
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
)

type ParentSelfHandler struct{}

func NewParentSelfHandler() *ParentSelfHandler {
	return &ParentSelfHandler{}
}

func (h *ParentSelfHandler) GetMyProfile(c *gin.Context) {
	userID := currentUserID(c)
	schoolID := scopedSchoolID(c)
	if userID == "" {
		fail(c, http.StatusUnauthorized, "Unauthenticated")
		return
	}

	var user models.User
	if err := database.DB.Preload("Role").First(&user, "id = ? AND school_id = ?", userID, schoolID).Error; err != nil {
		fail(c, http.StatusNotFound, "User not found")
		return
	}

	roleName := ""
	if user.Role != nil {
		roleName = user.Role.RoleName
	}

	response := gin.H{
		"id":          user.ID,
		"name":        user.Name,
		"username":    accountUsername(user.Username, user.Email),
		"email":       user.Email,
		"phone":       user.Phone,
		"avatar":      user.Avatar,
		"role_name":   roleName,
		"linked_type": user.LinkedType,
		"linked_id":   user.LinkedID,
	}

	if strings.EqualFold(roleName, "parent") {
		var links []models.ParentStudentLink
		if err := database.DB.
			Where("school_id = ? AND parent_user_id = ?", schoolID, userID).
			Preload("Student").
			Find(&links).Error; err == nil {
			students := make([]gin.H, 0)
			for _, l := range links {
				if l.Student != nil && !strings.EqualFold(l.Student.Status, "inactive") {
					students = append(students, gin.H{
						"id":               l.Student.ID,
						"first_name":       l.Student.FirstName,
						"last_name":        l.Student.LastName,
						"admission_number": l.Student.AdmissionNumber,
						"student_code":     l.Student.StudentCode,
					})
				}
			}
			response["students"] = students
		}
	} else if strings.EqualFold(roleName, "teacher") {
		staffID := currentStaffID(c)
		if staffID != "" {
			var staff models.Staff
			if err := database.DB.Preload("Department").First(&staff, "id = ? AND school_id = ?", staffID, schoolID).Error; err == nil {
				deptName := ""
				if staff.Department != nil {
					deptName = staff.Department.DepartmentName
				}
				response["staff_details"] = gin.H{
					"id":              staff.ID,
					"staff_code":      staff.StaffCode,
					"designation":     staff.Designation,
					"department_name": deptName,
					"employment_type": staff.EmploymentType,
				}
			}
		}
	}

	success(c, http.StatusOK, response, "")
}

func (h *ParentSelfHandler) PatchMyProfile(c *gin.Context) {
	userID := currentUserID(c)
	schoolID := scopedSchoolID(c)
	if userID == "" {
		fail(c, http.StatusUnauthorized, "Unauthenticated")
		return
	}

	var req struct {
		Phone    string `json:"phone"`
		Avatar   string `json:"avatar"`
		Password string `json:"password"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	updates := map[string]interface{}{}
	if strings.TrimSpace(req.Phone) != "" {
		updates["phone"] = strings.TrimSpace(req.Phone)
	}
	if strings.TrimSpace(req.Avatar) != "" {
		updates["avatar"] = strings.TrimSpace(req.Avatar)
	}
	if strings.TrimSpace(req.Password) != "" {
		if len(req.Password) < 8 {
			fail(c, http.StatusBadRequest, "Password must be at least 8 characters long")
			return
		}
		hashed, err := database.HashPassword(req.Password)
		if err != nil {
			fail(c, http.StatusInternalServerError, "Password hashing failed")
			return
		}
		updates["password_hash"] = hashed
	}

	if len(updates) > 0 {
		updates["updated_at"] = time.Now().UTC()
		if err := database.DB.Model(&models.User{}).Where("id = ? AND school_id = ?", userID, schoolID).Updates(updates).Error; err != nil {
			fail(c, http.StatusInternalServerError, "Failed to update profile")
			return
		}
	}

	success(c, http.StatusOK, gin.H{"id": userID}, "Profile updated successfully")
}

func (h *ParentSelfHandler) GetMyChildTimetable(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	parentUserID := currentUserID(c)
	studentID := strings.TrimSpace(c.Query("student_id"))
	if studentID == "" {
		fail(c, http.StatusBadRequest, "student_id is required")
		return
	}

	var link models.ParentStudentLink
	if err := database.DB.Where("school_id = ? AND parent_user_id = ? AND student_id = ?", schoolID, parentUserID, studentID).First(&link).Error; err != nil {
		fail(c, http.StatusForbidden, "Access to student schedule denied")
		return
	}

	var student models.Student
	if err := database.DB.First(&student, "id = ? AND school_id = ?", studentID, schoolID).Error; err != nil {
		fail(c, http.StatusNotFound, "Student not found")
		return
	}

	sectionID := ""
	if student.CurrentSectionID != nil {
		sectionID = strings.TrimSpace(*student.CurrentSectionID)
	}
	if sectionID == "" {
		var enrollment models.Enrollment
		if err := database.DB.
			Joins("JOIN academic_years ON academic_years.id = enrollments.academic_year_id").
			Where("enrollments.student_id = ? AND academic_years.school_id = ?", studentID, schoolID).
			Where("LOWER(enrollments.status) IN ?", []string{"enrolled", "active", "current"}).
			Order("academic_years.is_current DESC, enrollments.created_at DESC").
			First(&enrollment).Error; err == nil {
			sectionID = strings.TrimSpace(enrollment.SectionID)
		}
	}
	if sectionID == "" {
		success(c, http.StatusOK, []gin.H{}, "No section assigned to student")
		return
	}

	var slots []models.TimetableSlot
	if err := scopedTimetableSlotQuery(c).
		Select("timetable_slots.*").
		Preload("Subject").
		Preload("Staff").
		Preload("Room").
		Where("timetable_slots.section_id = ?", sectionID).
		Order("timetable_slots.day_of_week, timetable_slots.period_number").
		Find(&slots).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch student timetable")
		return
	}

	rows := make([]gin.H, 0, len(slots))
	for _, slot := range slots {
		subjectName := "Regular Period"
		if slot.Subject != nil && strings.TrimSpace(slot.Subject.SubjectName) != "" {
			subjectName = strings.TrimSpace(slot.Subject.SubjectName)
		}
		staffName := "Unassigned"
		if slot.Staff != nil {
			staffName = strings.TrimSpace(strings.Join([]string{slot.Staff.FirstName, slot.Staff.LastName}, " "))
			if staffName == "" {
				staffName = firstNonEmpty(slot.Staff.Email, "Unassigned")
			}
		}
		roomNumber := ""
		if slot.Room != nil {
			roomNumber = strings.TrimSpace(slot.Room.RoomNumber)
		}
		rows = append(rows, gin.H{
			"id":               slot.ID,
			"section_id":       slot.SectionID,
			"academic_year_id": slot.AcademicYearID,
			"term_id":          slot.TermID,
			"day_of_week":      slot.DayOfWeek,
			"period_number":    slot.PeriodNumber,
			"start_time":       timetableTimeHHMM(slot.StartTime),
			"end_time":         timetableTimeHHMM(slot.EndTime),
			"subject_id":       slot.SubjectID,
			"subject_name":     subjectName,
			"staff_id":         slot.StaffID,
			"staff_name":       staffName,
			"room_id":          slot.RoomID,
			"room_number":      roomNumber,
			"slot_type":        slot.SlotType,
			"subject": gin.H{
				"id":           slot.SubjectID,
				"subject_name": subjectName,
			},
			"staff": gin.H{
				"id":         slot.StaffID,
				"first_name": firstStaffName(slot.Staff),
				"last_name":  lastStaffName(slot.Staff),
			},
			"room": gin.H{
				"id":          slot.RoomID,
				"room_number": roomNumber,
			},
		})
	}

	success(c, http.StatusOK, rows, "")
}

func firstStaffName(staff *models.Staff) string {
	if staff == nil {
		return ""
	}
	return staff.FirstName
}

func lastStaffName(staff *models.Staff) string {
	if staff == nil {
		return ""
	}
	return staff.LastName
}

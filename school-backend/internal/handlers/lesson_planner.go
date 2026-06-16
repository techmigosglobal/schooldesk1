package handlers

import (
	"context"
	"net/http"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
)

type LessonPlannerHandler struct{}

func NewLessonPlannerHandler() *LessonPlannerHandler {
	return &LessonPlannerHandler{}
}

// Teacher Create
func (h *LessonPlannerHandler) CreateLessonPlanner(c *gin.Context) {
	var req struct {
		GradeID       string `json:"grade_id" binding:"required"`
		SectionID     string `json:"section_id" binding:"required"`
		WeekStartDate string `json:"week_start_date" binding:"required"`
		WeekEndDate   string `json:"week_end_date" binding:"required"`
		AttachmentURL string `json:"attachment_url"`
		Note          string `json:"note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	start, err1 := time.Parse(time.RFC3339, req.WeekStartDate)
	end, err2 := time.Parse(time.RFC3339, req.WeekEndDate)
	if err1 != nil || err2 != nil {
		fail(c, http.StatusBadRequest, "Invalid dates format. Use RFC3339")
		return
	}

	schoolID := scopedSchoolID(c)
	teacherID := c.GetString("linked_id")
	if teacherID == "" {
		fail(c, http.StatusUnauthorized, "Teacher profile not linked")
		return
	}

	planner := models.LessonPlanner{
		SchoolID:      schoolID,
		TeacherID:     teacherID,
		GradeID:       req.GradeID,
		SectionID:     req.SectionID,
		WeekStartDate: start,
		WeekEndDate:   end,
		AttachmentURL: req.AttachmentURL,
		Status:        models.LessonPlannerStatusUploaded,
	}

	if req.Note != "" {
		planner.Note = &req.Note
	}

	if err := database.DB.Create(&planner).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create lesson planner")
		return
	}

	database.DB.Preload("Teacher").First(&planner, "id = ?", planner.ID)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: planner})
}

// Teacher List
func (h *LessonPlannerHandler) ListTeacherLessonPlanners(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	teacherID := c.GetString("linked_id")

	var planners []models.LessonPlanner
	if err := database.DB.Preload("Grade").Preload("Section").Where("school_id = ? AND teacher_id = ?", schoolID, teacherID).Order("created_at desc").Find(&planners).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch lesson planners")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: planners})
}

// Teacher Mark Complete
func (h *LessonPlannerHandler) CompleteLessonPlanner(c *gin.Context) {
	id := c.Param("id")
	schoolID := scopedSchoolID(c)
	teacherID := c.GetString("linked_id")

	var planner models.LessonPlanner
	if err := database.DB.Where("id = ? AND school_id = ? AND teacher_id = ?", id, schoolID, teacherID).First(&planner).Error; err != nil {
		fail(c, http.StatusNotFound, "Lesson planner not found")
		return
	}

	now := time.Now()
	planner.Status = models.LessonPlannerStatusCompleted
	planner.CompletedAt = &now

	if err := database.DB.Save(&planner).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to complete lesson planner")
		return
	}

	if services.Queue != nil {
		_ = services.Queue.Enqueue(context.Background(), "notifications", map[string]interface{}{
			"type":              "lesson_planner_completed",
			"lesson_planner_id": planner.ID,
			"school_id":         planner.SchoolID,
			"grade_id":          planner.GradeID,
			"section_id":        planner.SectionID,
		})
	}

	parents, _ := parentUsersForSectionTx(database.DB, schoolID, planner.SectionID)
	createNotificationLogsForUsersTx(database.DB, schoolID, parents, "Lesson Plan Completed", "The lesson plan for the week has been marked as complete.", "academic", "medium", "lesson_planner", planner.ID)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: planner})
}

// Parent List Planners
func (h *LessonPlannerHandler) ListParentLessonPlanners(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	parentUserID := currentUserID(c)

	query := database.DB.Model(&models.LessonPlanner{}).
		Preload("Teacher").
		Preload("Grade").
		Preload("Section").
		Select("DISTINCT lesson_planners.*").
		Joins("JOIN parent_student_links ON parent_student_links.school_id = lesson_planners.school_id").
		Joins("JOIN students ON students.id = parent_student_links.student_id").
		Joins("LEFT JOIN enrollments ON enrollments.student_id = students.id").
		Where("lesson_planners.school_id = ? AND parent_student_links.parent_user_id = ?", schoolID, parentUserID).
		Where("(students.current_section_id = lesson_planners.section_id OR enrollments.section_id = lesson_planners.section_id)")

	var planners []models.LessonPlanner
	if err := query.Order("created_at desc").Find(&planners).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch lesson planners")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: planners})
}

// Principal List Planners
func (h *LessonPlannerHandler) ListPrincipalLessonPlanners(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	gradeID := c.Query("grade_id")

	query := database.DB.Preload("Teacher").Preload("Grade").Preload("Section").Where("school_id = ?", schoolID)
	if gradeID != "" {
		query = query.Where("grade_id = ?", gradeID)
	}

	var planners []models.LessonPlanner
	if err := query.Order("created_at desc").Find(&planners).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch lesson planners")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: planners})
}

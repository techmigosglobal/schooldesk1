package handlers

import (
	"encoding/json"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

const (
	principalTimetableActionsResource = "principal/timetable-actions"
	principalExamActionsResource      = "principal/exam-actions"
	principalResultActionsResource    = "principal/result-actions"
)

type PrincipalAcademicCommandHandler struct{}

func NewPrincipalAcademicCommandHandler() *PrincipalAcademicCommandHandler {
	return &PrincipalAcademicCommandHandler{}
}

type principalActionRequest struct {
	ActionType string                 `json:"action_type"`
	Title      string                 `json:"title"`
	Message    string                 `json:"message" binding:"required"`
	Priority   string                 `json:"priority"`
	EntityID   string                 `json:"entity_id"`
	ExamID     string                 `json:"exam_id"`
	SlotID     string                 `json:"slot_id"`
	DueDate    string                 `json:"due_date"`
	Payload    map[string]interface{} `json:"payload"`
}

type principalActionApplyResult struct {
	applied bool
	status  string
}

func (h *PrincipalAcademicCommandHandler) TimetableOverview(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	todayStart, todayEnd := dayRange(time.Now())
	todayWeekday := principalDayOfWeek(time.Now())

	var slots []models.TimetableSlot
	if err := principalTimetableSlotQuery(schoolID).
		Order("timetable_slots.day_of_week, timetable_slots.period_number").
		Find(&slots).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load timetable command center")
		return
	}

	var sections []models.Section
	_ = database.DB.Preload("Grade").
		Preload("ClassTeacher").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ?", schoolID).
		Order("grades.grade_number ASC, sections.section_name ASC").
		Find(&sections).Error

	todaySlots := filterTimetableSlotsByDay(slots, todayWeekday)
	conflicts := timetableConflictAlerts(slots, sections)
	substitutions := todaySubstitutionRows(schoolID, todayStart, todayEnd)
	absentTeachers := todayAbsentTeachers(schoolID, todayStart, todayEnd)
	freePeriods := todayFreePeriodRows(todaySlots, sections)
	workflowGaps := timetableWorkflowGaps(slots, sections, conflicts, freePeriods)

	success(c, http.StatusOK, gin.H{
		"summary": gin.H{
			"total_slots":          len(slots),
			"classes_covered":      countDistinctSlots(slots, "section"),
			"teachers_scheduled":   countDistinctSlots(slots, "staff"),
			"rooms_used":           countDistinctSlots(slots, "room"),
			"conflict_alerts":      len(conflicts),
			"today_classes":        len(todaySlots),
			"absent_teachers":      len(absentTeachers),
			"substitute_teachers":  len(substitutions),
			"free_periods":         len(freePeriods),
			"latest_publish_state": latestPrincipalAction(schoolID, principalTimetableActionsResource, ""),
		},
		"views": gin.H{
			"periods":      timetablePeriodRows(slots),
			"class_wise":   timetableClassRows(slots, sections),
			"teacher_wise": timetableTeacherRows(slots),
			"subject_wise": timetableSubjectRows(slots),
			"room_wise":    timetableRoomRows(slots),
		},
		"conflict_alerts": conflicts,
		"today_monitoring": gin.H{
			"ongoing_classes":     ongoingClassRows(todaySlots, time.Now()),
			"absent_teachers":     absentTeachers,
			"substitute_teachers": substitutions,
			"free_periods":        freePeriods,
		},
		"workflow_gaps": buildPrincipalOperationalGapSummary(workflowGaps),
		"actions":       recentPrincipalActions(schoolID, principalTimetableActionsResource, 8),
	}, "")
}

func (h *PrincipalAcademicCommandHandler) SaveTimetableAction(c *gin.Context) {
	savePrincipalAction(c, principalTimetableActionsResource, "principal/timetable", "timetable_supervision", "Timetable action saved", "")
}

func (h *PrincipalAcademicCommandHandler) ExamsOverview(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	now := time.Now().UTC()
	todayStart, todayEnd := dayRange(now)

	var exams []models.Exam
	if err := database.DB.
		Preload("ExamType").
		Preload("AcademicYear").
		Preload("Term").
		Preload("Schedules").
		Preload("Schedules.Grade").
		Preload("Schedules.Section").
		Preload("Schedules.Subject").
		Preload("Schedules.Room").
		Preload("Schedules.StudentMarks").
		Where("school_id = ?", schoolID).
		Order("start_date ASC").
		Find(&exams).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load exam command center")
		return
	}

	dashboard := examDashboardRows(exams, now)
	monitoring := examMonitoringRows(exams, todayStart, todayEnd)
	evaluation := examEvaluationRows(exams)
	delayedEvaluations := delayedEvaluationRows(evaluation, now)
	examTypes := principalExamTypeOptions(schoolID)
	grades := principalSubjectGradeOptions(schoolID)
	subjects := principalSubjectOptions(schoolID)
	rooms := principalRoomOptions(schoolID)
	staff := principalSubjectTeacherOptions(schoolID)
	workflowGaps := examWorkflowGaps(exams, evaluation, delayedEvaluations, examTypes, grades, subjects, staff)

	success(c, http.StatusOK, gin.H{
		"summary": gin.H{
			"upcoming_exams":         countExamStatus(dashboard, "upcoming"),
			"ongoing_exams":          countExamStatus(dashboard, "ongoing"),
			"completed_exams":        countExamStatus(dashboard, "completed"),
			"evaluation_pending":     countEvaluationPending(evaluation),
			"schedules_configured":   countExamSchedules(exams),
			"published_exams":        countPublishedExams(exams),
			"latest_approval_action": latestPrincipalAction(schoolID, principalExamActionsResource, ""),
		},
		"exam_dashboard": dashboard,
		"creation_controls": gin.H{
			"exam_types": examTypes,
			"grades":     grades,
			"subjects":   subjects,
			"rooms":      rooms,
			"staff":      staff,
		},
		"monitoring_panel": gin.H{
			"live_exam_progress":        monitoring,
			"malpractice_reports":       frontendIssueRows(schoolID, "exam-malpractice-reports", "exam_id"),
			"absent_students":           examAbsentRows(exams),
			"paper_submission_tracking": examPaperSubmissionRows(exams),
		},
		"evaluation_tracking": gin.H{
			"marks_pending":          evaluation,
			"teachers_yet_to_submit": teacherSubmissionRows(evaluation),
			"delayed_evaluations":    delayedEvaluations,
		},
		"workflow_gaps": buildPrincipalOperationalGapSummary(workflowGaps),
		"actions":       recentPrincipalActions(schoolID, principalExamActionsResource, 8),
	}, "")
}

func (h *PrincipalAcademicCommandHandler) SaveExamAction(c *gin.Context) {
	savePrincipalAction(c, principalExamActionsResource, "principal/exams", "exam_supervision", "Exam action saved", "exam_id")
}

func (h *PrincipalAcademicCommandHandler) ResultsOverview(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	marks := resultMarkRows(schoolID)
	reportCards := resultReportCardRows(schoolID)
	attendance := resultAttendanceRows(schoolID)
	weakStudents := weakStudentRows(marks, attendance)
	workflowGaps := resultsWorkflowGaps(marks, reportCards, weakStudents, attendance)

	success(c, http.StatusOK, gin.H{
		"summary": gin.H{
			"overall_school_performance": overallResultAverage(marks, reportCards),
			"pass_percentage":            resultPassPercentage(marks, reportCards),
			"top_performing_classes":     topResultClasses(marks, 3),
			"weak_students":              len(weakStudents),
			"subject_analysis_count":     len(subjectAnalysisRows(marks)),
			"report_cards":               len(reportCards),
			"latest_publish_action":      latestPrincipalAction(schoolID, principalResultActionsResource, ""),
		},
		"result_dashboard": gin.H{
			"class_performance":      classPerformanceRows(marks),
			"subject_wise_analysis":  subjectAnalysisRows(marks),
			"attendance_correlation": weakStudents,
		},
		"toppers": gin.H{
			"school_toppers":  schoolTopperRows(reportCards, marks),
			"class_toppers":   classTopperRows(reportCards, marks),
			"subject_toppers": subjectTopperRowsFromMarks(marks),
		},
		"weak_students": weakStudents,
		"reports": gin.H{
			"export_options": []gin.H{
				{"label": "PDF report cards", "format": "pdf", "route": "/exams/report-cards/exports"},
				{"label": "Excel analytics", "format": "xlsx", "route": "/exams/report-cards/exports"},
				{"label": "Comparative performance charts", "format": "pdf", "route": "/reports/exports"},
			},
			"recent_exports": recentReportExports(schoolID),
		},
		"workflow_gaps": buildPrincipalOperationalGapSummary(workflowGaps),
		"actions":       recentPrincipalActions(schoolID, principalResultActionsResource, 8),
	}, "")
}

func (h *PrincipalAcademicCommandHandler) SaveResultAction(c *gin.Context) {
	savePrincipalAction(c, principalResultActionsResource, "principal/results", "result_supervision", "Result action saved", "exam_id")
}

func principalTimetableSlotQuery(schoolID string) *gorm.DB {
	return database.DB.Model(&models.TimetableSlot{}).
		Joins("JOIN sections ON sections.id = timetable_slots.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ?", schoolID).
		Preload("Section").
		Preload("Section.Grade").
		Preload("Section.ClassTeacher").
		Preload("Subject").
		Preload("Staff").
		Preload("Staff.Department").
		Preload("Room")
}

func savePrincipalAction(c *gin.Context, resource, module, principalRole, message, entityKey string) {
	schoolID := scopedSchoolID(c)
	var req principalActionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	actionMessage := strings.TrimSpace(req.Message)
	if actionMessage == "" {
		fail(c, http.StatusBadRequest, "message is required")
		return
	}
	actionType := firstNonEmpty(req.ActionType, "principal_action")
	applyResult, err := validateAndApplyPrincipalAction(c, schoolID, resource, actionType, req)
	if err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	payload := gin.H{
		"action_type":       actionType,
		"title":             firstNonEmpty(req.Title, principalActionTitle(actionType)),
		"message":           actionMessage,
		"priority":          firstNonEmpty(req.Priority, "normal"),
		"entity_id":         strings.TrimSpace(req.EntityID),
		"exam_id":           strings.TrimSpace(req.ExamID),
		"slot_id":           strings.TrimSpace(req.SlotID),
		"due_date":          strings.TrimSpace(req.DueDate),
		"status":            "open",
		"created_by":        c.GetString("user_id"),
		"created_at":        time.Now().UTC().Format(time.RFC3339),
		"principal_role":    principalRole,
		"applied_to_domain": applyResult.applied,
		"domain_status":     applyResult.status,
	}
	if entityKey != "" && strings.TrimSpace(req.EntityID) != "" {
		payload[entityKey] = strings.TrimSpace(req.EntityID)
	}
	for key, value := range req.Payload {
		if isPrincipalActionProtectedPayloadKey(key) {
			continue
		}
		payload[key] = value
	}

	encoded, err := json.Marshal(payload)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid action payload")
		return
	}
	record := models.FrontendRecord{
		SchoolID:  schoolID,
		Resource:  resource,
		Payload:   string(encoded),
		CreatedBy: c.GetString("user_id"),
	}
	if err := database.DB.Create(&record).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save principal action")
		return
	}
	auditAction(c, module, actionType, "frontend_records", &record.ID)
	response := frontendRecordResponse(record)
	for key, value := range payload {
		response[key] = value
	}
	success(c, http.StatusCreated, response, message)
}

func validateAndApplyPrincipalAction(c *gin.Context, schoolID, resource, actionType string, req principalActionRequest) (principalActionApplyResult, error) {
	if slotID := strings.TrimSpace(req.SlotID); slotID != "" {
		var slot models.TimetableSlot
		if err := principalTimetableSlotQuery(schoolID).First(&slot, "timetable_slots.id = ?", slotID).Error; err != nil {
			return principalActionApplyResult{}, err
		}
	}

	examID := firstNonEmpty(strings.TrimSpace(req.ExamID), strings.TrimSpace(req.EntityID))
	if examID != "" {
		var exam models.Exam
		if err := database.DB.First(&exam, "id = ? AND school_id = ?", examID, schoolID).Error; err != nil {
			return principalActionApplyResult{}, err
		}
		if resource == principalExamActionsResource && strings.EqualFold(actionType, "publish_exam_timetable") {
			if err := database.DB.Model(&models.Exam{}).Where("id = ? AND school_id = ?", examID, schoolID).Update("is_published", true).Error; err != nil {
				return principalActionApplyResult{}, err
			}
			return principalActionApplyResult{applied: true, status: "exam_published"}, nil
		}
		if resource == principalResultActionsResource {
			switch strings.ToLower(strings.TrimSpace(actionType)) {
			case "publish_results":
				if err := database.DB.Model(&models.Exam{}).Where("id = ? AND school_id = ?", examID, schoolID).Update("is_published", true).Error; err != nil {
					return principalActionApplyResult{}, err
				}
				return principalActionApplyResult{applied: true, status: "results_published"}, nil
			case "hold_results":
				if err := database.DB.Model(&models.Exam{}).Where("id = ? AND school_id = ?", examID, schoolID).Update("is_published", false).Error; err != nil {
					return principalActionApplyResult{}, err
				}
				return principalActionApplyResult{applied: true, status: "results_held"}, nil
			}
		}
		return principalActionApplyResult{applied: false, status: "validated_reference"}, nil
	}

	return principalActionApplyResult{applied: false, status: "recorded_note"}, nil
}

func isPrincipalActionProtectedPayloadKey(key string) bool {
	switch strings.ToLower(strings.TrimSpace(key)) {
	case "action_type", "title", "message", "priority", "entity_id", "exam_id", "slot_id", "due_date", "status", "created_by", "created_at", "principal_role", "applied_to_domain", "domain_status":
		return true
	default:
		return false
	}
}

func principalActionTitle(actionType string) string {
	switch strings.ToLower(strings.TrimSpace(actionType)) {
	case "approve_timetable":
		return "Approve timetable"
	case "modify_periods":
		return "Modify periods"
	case "emergency_substitution":
		return "Emergency substitution"
	case "holiday_adjustment":
		return "Holiday adjustment"
	case "publish_timetable":
		return "Publish timetable"
	case "create_exam":
		return "Create or schedule exam"
	case "assign_invigilator":
		return "Assign invigilator"
	case "publish_results":
		return "Publish results"
	case "hold_results":
		return "Hold results"
	case "schedule_parent_meeting":
		return "Schedule parent meeting"
	default:
		return "Principal action"
	}
}

func principalDayOfWeek(t time.Time) int {
	day := int(t.Weekday())
	if day == 0 {
		return 7
	}
	return day
}

func filterTimetableSlotsByDay(slots []models.TimetableSlot, day int) []models.TimetableSlot {
	result := make([]models.TimetableSlot, 0)
	for _, slot := range slots {
		if slot.DayOfWeek == day {
			result = append(result, slot)
		}
	}
	return result
}

func timetablePeriodRows(slots []models.TimetableSlot) []gin.H {
	rows := make([]gin.H, 0, len(slots))
	for _, slot := range slots {
		rows = append(rows, timetableSlotRow(slot))
	}
	return rows
}

func timetableClassRows(slots []models.TimetableSlot, sections []models.Section) []gin.H {
	sectionSlots := map[string][]models.TimetableSlot{}
	for _, slot := range slots {
		sectionSlots[slot.SectionID] = append(sectionSlots[slot.SectionID], slot)
	}
	rows := make([]gin.H, 0, len(sections))
	for _, section := range sections {
		list := sectionSlots[section.ID]
		rows = append(rows, gin.H{
			"section_id":       section.ID,
			"grade_id":         section.GradeID,
			"academic_year_id": section.AcademicYearID,
			"class_name":       principalClassLabel(section),
			"class_teacher":    principalTeacherName(section.ClassTeacher),
			"capacity":         section.Capacity,
			"slot_count":       len(list),
			"teacher_count":    distinctSlotValues(list, "staff"),
			"subject_count":    distinctSlotValues(list, "subject"),
			"empty_periods":    totalEmptyPeriods(list),
			"latest_action":    nil,
			"supervision_note": timetableCoverageNote(list),
		})
	}
	return rows
}

func timetableTeacherRows(slots []models.TimetableSlot) []gin.H {
	grouped := map[string][]models.TimetableSlot{}
	for _, slot := range slots {
		if strings.TrimSpace(slot.StaffID) == "" {
			continue
		}
		grouped[slot.StaffID] = append(grouped[slot.StaffID], slot)
	}
	rows := make([]gin.H, 0, len(grouped))
	for staffID, list := range grouped {
		rows = append(rows, gin.H{
			"staff_id":        staffID,
			"teacher_name":    principalTeacherName(list[0].Staff),
			"department_name": principalTeacherDepartment(list[0].Staff),
			"designation":     principalTeacherDesignation(list[0].Staff),
			"periods":         len(list),
			"classes":         distinctSlotValues(list, "section"),
			"subjects":        distinctSlotValues(list, "subject"),
			"workload_state":  workloadState(len(list)),
		})
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return int64FromAny(rows[i]["periods"]) > int64FromAny(rows[j]["periods"])
	})
	return rows
}

func timetableSubjectRows(slots []models.TimetableSlot) []gin.H {
	grouped := map[string][]models.TimetableSlot{}
	for _, slot := range slots {
		if strings.TrimSpace(slot.SubjectID) == "" {
			continue
		}
		grouped[slot.SubjectID] = append(grouped[slot.SubjectID], slot)
	}
	rows := make([]gin.H, 0, len(grouped))
	for subjectID, list := range grouped {
		rows = append(rows, gin.H{
			"subject_id":    subjectID,
			"subject_name":  principalSubjectName(list[0].Subject),
			"periods":       len(list),
			"classes":       distinctSlotValues(list, "section"),
			"teachers":      distinctSlotValues(list, "staff"),
			"coverage_note": timetableCoverageNote(list),
		})
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return strings.Compare(stringMapValue(rows[i]["subject_name"]), stringMapValue(rows[j]["subject_name"])) < 0
	})
	return rows
}

func timetableRoomRows(slots []models.TimetableSlot) []gin.H {
	grouped := map[string][]models.TimetableSlot{}
	for _, slot := range slots {
		if slot.RoomID == nil || strings.TrimSpace(*slot.RoomID) == "" {
			continue
		}
		grouped[*slot.RoomID] = append(grouped[*slot.RoomID], slot)
	}
	rows := make([]gin.H, 0, len(grouped))
	for roomID, list := range grouped {
		rows = append(rows, gin.H{
			"room_id":     roomID,
			"room_name":   principalRoomName(list[0].Room),
			"room_type":   principalRoomType(list[0].Room),
			"capacity":    principalRoomCapacity(list[0].Room),
			"block":       principalRoomBlock(list[0].Room),
			"floor":       principalRoomFloor(list[0].Room),
			"periods":     len(list),
			"classes":     distinctSlotValues(list, "section"),
			"conflicts":   roomConflictCount(list),
			"is_lab_room": isLabRoom(list[0].Room),
		})
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return int64FromAny(rows[i]["conflicts"]) > int64FromAny(rows[j]["conflicts"])
	})
	return rows
}

func timetableConflictAlerts(slots []models.TimetableSlot, sections []models.Section) []gin.H {
	alerts := []gin.H{}
	staffPeriod := map[string][]models.TimetableSlot{}
	roomPeriod := map[string][]models.TimetableSlot{}
	for _, slot := range slots {
		staffKey := strings.Join([]string{slot.StaffID, intString(slot.DayOfWeek), intString(slot.PeriodNumber)}, "|")
		if strings.TrimSpace(slot.StaffID) != "" {
			staffPeriod[staffKey] = append(staffPeriod[staffKey], slot)
		}
		if slot.RoomID != nil && strings.TrimSpace(*slot.RoomID) != "" {
			roomKey := strings.Join([]string{*slot.RoomID, intString(slot.DayOfWeek), intString(slot.PeriodNumber)}, "|")
			roomPeriod[roomKey] = append(roomPeriod[roomKey], slot)
		}
	}
	for _, list := range staffPeriod {
		if len(list) > 1 {
			alerts = append(alerts, gin.H{
				"type":        "teacher_overlap",
				"title":       "Teacher overlap",
				"description": principalTeacherName(list[0].Staff) + " has multiple classes in the same period.",
				"severity":    "high",
				"day":         weekdayLabel(list[0].DayOfWeek),
				"period":      list[0].PeriodNumber,
				"count":       len(list),
			})
		}
	}
	for _, list := range roomPeriod {
		if len(list) > 1 && isLabRoom(list[0].Room) {
			alerts = append(alerts, gin.H{
				"type":        "lab_conflict",
				"title":       "Lab conflict",
				"description": principalRoomName(list[0].Room) + " is booked for multiple classes.",
				"severity":    "medium",
				"day":         weekdayLabel(list[0].DayOfWeek),
				"period":      list[0].PeriodNumber,
				"count":       len(list),
			})
		}
	}
	for _, row := range timetableTeacherRows(slots) {
		if int64FromAny(row["periods"]) > 32 {
			alerts = append(alerts, gin.H{
				"type":        "excess_workload",
				"title":       "Excess workload",
				"description": stringMapValue(row["teacher_name"]) + " has more than 32 periods this week.",
				"severity":    "medium",
				"count":       row["periods"],
			})
		}
	}
	emptyToday := todayFreePeriodRows(filterTimetableSlotsByDay(slots, principalDayOfWeek(time.Now())), sections)
	if len(emptyToday) > 0 {
		alerts = append(alerts, gin.H{
			"type":        "empty_periods",
			"title":       "Empty periods",
			"description": "Some classes have unassigned periods today.",
			"severity":    "low",
			"count":       len(emptyToday),
		})
	}
	return alerts
}

func timetableWorkflowGaps(slots []models.TimetableSlot, sections []models.Section, conflicts []gin.H, freePeriods []gin.H) []principalOperationalGap {
	gaps := []principalOperationalGap{}
	slotsBySection := map[string]int{}
	incompleteSlots := int64(0)
	for _, slot := range slots {
		slotsBySection[slot.SectionID]++
		if strings.TrimSpace(slot.SubjectID) == "" || strings.TrimSpace(slot.StaffID) == "" {
			incompleteSlots++
		}
	}
	for _, section := range sections {
		if slotsBySection[section.ID] > 0 {
			continue
		}
		label := principalClassLabel(section)
		gaps = append(gaps, principalOperationalGap{
			ID:          "timetable-no-periods:" + section.ID,
			Category:    "Timetable",
			Severity:    "warning",
			Title:       "No periods configured",
			Message:     label + " has no class periods. Add timetable periods before attendance and daily operations depend on it.",
			ActionLabel: "Add periods",
			Route:       "principalTimetable",
			EntityType:  "section",
			EntityID:    section.ID,
			EntityLabel: label,
			Count:       1,
		})
	}
	if len(conflicts) > 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "timetable-conflicts",
			Category:    "Timetable",
			Severity:    "critical",
			Title:       "Timetable conflicts unresolved",
			Message:     pluralize(int64(len(conflicts)), "conflict") + " must be fixed before publishing the timetable.",
			ActionLabel: "Resolve conflicts",
			Route:       "principalTimetable",
			EntityType:  "timetable",
			EntityLabel: "Conflict alerts",
			Count:       int64(len(conflicts)),
		})
	}
	if incompleteSlots > 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "timetable-incomplete-slots",
			Category:    "Timetable",
			Severity:    "warning",
			Title:       "Period links incomplete",
			Message:     pluralize(incompleteSlots, "period") + " need a subject and teacher before the schedule is operational.",
			ActionLabel: "Complete slots",
			Route:       "principalTimetable",
			EntityType:  "timetable",
			EntityLabel: "Incomplete periods",
			Count:       incompleteSlots,
		})
	}
	if len(freePeriods) > 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "timetable-free-periods",
			Category:    "Timetable",
			Severity:    "info",
			Title:       "Free periods detected",
			Message:     pluralize(int64(len(freePeriods)), "free period") + " appear in today's class coverage.",
			ActionLabel: "Review coverage",
			Route:       "principalTimetable",
			EntityType:  "timetable",
			EntityLabel: "Today's coverage",
			Count:       int64(len(freePeriods)),
		})
	}
	return limitPrincipalWorkflowGaps(gaps)
}

func ongoingClassRows(slots []models.TimetableSlot, now time.Time) []gin.H {
	rows := []gin.H{}
	nowHHMM := now.Format("15:04")
	for _, slot := range slots {
		startHHMM := timetableTimeHHMM(slot.StartTime)
		endHHMM := timetableTimeHHMM(slot.EndTime)
		if startHHMM != "" && endHHMM != "" && (nowHHMM < startHHMM || nowHHMM > endHHMM) {
			continue
		}
		rows = append(rows, timetableSlotRow(slot))
	}
	if len(rows) == 0 {
		for _, slot := range slots {
			rows = append(rows, timetableSlotRow(slot))
			if len(rows) >= 8 {
				break
			}
		}
	}
	return rows
}

func timetableTimeHHMM(value *time.Time) string {
	if value == nil {
		return ""
	}
	return value.Format("15:04")
}

func todayFreePeriodRows(slots []models.TimetableSlot, sections []models.Section) []gin.H {
	maxPeriod := 0
	sectionPeriods := map[string]map[int]bool{}
	for _, slot := range slots {
		if slot.PeriodNumber > maxPeriod {
			maxPeriod = slot.PeriodNumber
		}
		if sectionPeriods[slot.SectionID] == nil {
			sectionPeriods[slot.SectionID] = map[int]bool{}
		}
		sectionPeriods[slot.SectionID][slot.PeriodNumber] = true
	}
	if maxPeriod == 0 {
		maxPeriod = 7
	}
	rows := []gin.H{}
	for _, section := range sections {
		for period := 1; period <= maxPeriod; period++ {
			if !sectionPeriods[section.ID][period] {
				rows = append(rows, gin.H{
					"section_id": section.ID,
					"class_name": principalClassLabel(section),
					"period":     period,
					"status":     "free",
				})
			}
		}
	}
	if len(rows) > 12 {
		return rows[:12]
	}
	return rows
}

func todaySubstitutionRows(schoolID string, start, end time.Time) []gin.H {
	var rows []models.Substitution
	_ = database.DB.Model(&models.Substitution{}).
		Joins("JOIN timetable_slots ON timetable_slots.id = substitutions.timetable_slot_id").
		Joins("JOIN sections ON sections.id = timetable_slots.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ? AND substitutions.date >= ? AND substitutions.date < ?", schoolID, start, end).
		Preload("TimetableSlot").
		Preload("TimetableSlot.Section").
		Preload("TimetableSlot.Section.Grade").
		Preload("TimetableSlot.Subject").
		Preload("OriginalStaff").
		Preload("SubstituteStaff").
		Find(&rows).Error
	result := make([]gin.H, 0, len(rows))
	for _, row := range rows {
		result = append(result, gin.H{
			"id":                 row.ID,
			"date":               row.Date.Format("2006-01-02"),
			"class_name":         principalSlotClassName(row.TimetableSlot),
			"subject":            principalSlotSubjectName(row.TimetableSlot),
			"original_teacher":   principalTeacherName(row.OriginalStaff),
			"substitute_teacher": principalTeacherName(row.SubstituteStaff),
			"reason":             row.Reason,
		})
	}
	return result
}

func todayAbsentTeachers(schoolID string, start, end time.Time) []gin.H {
	var rows []models.StaffAttendance
	_ = database.DB.Preload("Staff").
		Joins("JOIN staffs ON staffs.id = staff_attendances.staff_id").
		Where("staffs.school_id = ? AND staff_attendances.date >= ? AND staff_attendances.date < ? AND LOWER(staff_attendances.status) = ?", schoolID, start, end, "absent").
		Find(&rows).Error
	result := make([]gin.H, 0, len(rows))
	for _, row := range rows {
		result = append(result, gin.H{
			"staff_id": row.StaffID,
			"name":     principalTeacherName(row.Staff),
			"status":   row.Status,
			"date":     row.Date.Format("2006-01-02"),
		})
	}
	return result
}

func timetableSlotRow(slot models.TimetableSlot) gin.H {
	roomID := ""
	if slot.RoomID != nil {
		roomID = *slot.RoomID
	}
	return gin.H{
		"id":               slot.ID,
		"slot_id":          slot.ID,
		"section_id":       slot.SectionID,
		"academic_year_id": slot.AcademicYearID,
		"term_id":          slot.TermID,
		"subject_id":       slot.SubjectID,
		"staff_id":         slot.StaffID,
		"room_id":          roomID,
		"class_name":       principalSlotClassName(&slot),
		"subject":          principalSlotSubjectName(&slot),
		"subject_name":     principalSlotSubjectName(&slot),
		"teacher":          principalTeacherName(slot.Staff),
		"teacher_name":     principalTeacherName(slot.Staff),
		"department_name":  principalTeacherDepartment(slot.Staff),
		"room":             principalRoomName(slot.Room),
		"room_capacity":    principalRoomCapacity(slot.Room),
		"day":              weekdayLabel(slot.DayOfWeek),
		"day_of_week":      slot.DayOfWeek,
		"period":           slot.PeriodNumber,
		"period_number":    slot.PeriodNumber,
		"start_time":       timetableTimeHHMM(slot.StartTime),
		"end_time":         timetableTimeHHMM(slot.EndTime),
		"slot_type":        slot.SlotType,
	}
}

func countDistinctSlots(slots []models.TimetableSlot, key string) int {
	seen := map[string]bool{}
	for _, slot := range slots {
		value := slotValue(slot, key)
		if value != "" {
			seen[value] = true
		}
	}
	return len(seen)
}

func distinctSlotValues(slots []models.TimetableSlot, key string) int {
	return countDistinctSlots(slots, key)
}

func slotValue(slot models.TimetableSlot, key string) string {
	switch key {
	case "section":
		return slot.SectionID
	case "staff":
		return slot.StaffID
	case "subject":
		return slot.SubjectID
	case "room":
		if slot.RoomID != nil {
			return strings.TrimSpace(*slot.RoomID)
		}
	}
	return ""
}

func totalEmptyPeriods(slots []models.TimetableSlot) int {
	byDay := map[int]map[int]bool{}
	maxByDay := map[int]int{}
	for _, slot := range slots {
		if byDay[slot.DayOfWeek] == nil {
			byDay[slot.DayOfWeek] = map[int]bool{}
		}
		byDay[slot.DayOfWeek][slot.PeriodNumber] = true
		if slot.PeriodNumber > maxByDay[slot.DayOfWeek] {
			maxByDay[slot.DayOfWeek] = slot.PeriodNumber
		}
	}
	missing := 0
	for day, maxPeriod := range maxByDay {
		for period := 1; period <= maxPeriod; period++ {
			if !byDay[day][period] {
				missing++
			}
		}
	}
	return missing
}

func workloadState(periods int) string {
	switch {
	case periods > 32:
		return "Excess workload"
	case periods >= 24:
		return "Full workload"
	case periods == 0:
		return "No periods"
	default:
		return "Balanced"
	}
}

func timetableCoverageNote(slots []models.TimetableSlot) string {
	if len(slots) == 0 {
		return "No periods configured"
	}
	if totalEmptyPeriods(slots) > 0 {
		return "Review empty periods"
	}
	return "Coverage configured"
}

func roomConflictCount(slots []models.TimetableSlot) int {
	grouped := map[string]int{}
	conflicts := 0
	for _, slot := range slots {
		key := intString(slot.DayOfWeek) + "|" + intString(slot.PeriodNumber)
		grouped[key]++
	}
	for _, count := range grouped {
		if count > 1 {
			conflicts += count - 1
		}
	}
	return conflicts
}

func principalSubjectName(subject *models.Subject) string {
	if subject == nil {
		return "Subject"
	}
	return firstNonEmpty(subject.SubjectName, subject.SubjectCode, "Subject")
}

func principalTeacherDepartment(staff *models.Staff) string {
	if staff == nil || staff.Department == nil {
		return ""
	}
	return strings.TrimSpace(staff.Department.DepartmentName)
}

func principalTeacherDesignation(staff *models.Staff) string {
	if staff == nil {
		return ""
	}
	return strings.TrimSpace(staff.Designation)
}

func principalRoomName(room *models.Room) string {
	if room == nil {
		return "Not assigned"
	}
	return firstNonEmpty(room.RoomNumber, room.Block, "Room")
}

func principalRoomType(room *models.Room) string {
	if room == nil {
		return ""
	}
	return strings.TrimSpace(room.RoomType)
}

func principalRoomBlock(room *models.Room) string {
	if room == nil {
		return ""
	}
	return strings.TrimSpace(room.Block)
}

func principalRoomFloor(room *models.Room) int {
	if room == nil {
		return 0
	}
	return room.Floor
}

func isLabRoom(room *models.Room) bool {
	if room == nil {
		return false
	}
	text := strings.ToLower(room.RoomType + " " + room.RoomNumber)
	return strings.Contains(text, "lab")
}

func principalSlotClassName(slot *models.TimetableSlot) string {
	if slot == nil || slot.Section == nil {
		return "Class"
	}
	return principalClassLabel(*slot.Section)
}

func principalSlotSubjectName(slot *models.TimetableSlot) string {
	if slot == nil {
		return "Subject"
	}
	slotType := strings.TrimSpace(slot.SlotType)
	if strings.Contains(strings.ToLower(slotType), "break") {
		if parts := strings.SplitN(slotType, ":", 2); len(parts) == 2 && strings.TrimSpace(parts[1]) != "" {
			return strings.TrimSpace(parts[1])
		}
		return "Break"
	}
	return principalSubjectName(slot.Subject)
}

func intString(value int) string {
	return strconv.Itoa(value)
}

func weekdayLabel(day int) string {
	labels := map[int]string{
		1: "Monday",
		2: "Tuesday",
		3: "Wednesday",
		4: "Thursday",
		5: "Friday",
		6: "Saturday",
		7: "Sunday",
	}
	if labels[day] == "" {
		return "Day " + strconv.Itoa(day)
	}
	return labels[day]
}

func recentPrincipalActions(schoolID, resource string, limit int) []gin.H {
	if limit <= 0 {
		limit = 10
	}
	var rows []models.FrontendRecord
	_ = database.DB.
		Where("school_id = ? AND resource = ?", schoolID, resource).
		Order("created_at DESC").
		Limit(limit).
		Find(&rows).Error
	result := make([]gin.H, 0, len(rows))
	for _, row := range rows {
		result = append(result, frontendRecordResponse(row))
	}
	return result
}

func latestPrincipalAction(schoolID, resource, entityID string) gin.H {
	actions := recentPrincipalActions(schoolID, resource, 30)
	for _, action := range actions {
		if entityID == "" || stringMapValue(action["entity_id"]) == entityID || stringMapValue(action["exam_id"]) == entityID {
			return action
		}
	}
	return gin.H{}
}

func examDashboardRows(exams []models.Exam, now time.Time) []gin.H {
	rows := make([]gin.H, 0, len(exams))
	for _, exam := range exams {
		rows = append(rows, gin.H{
			"exam_id":             exam.ID,
			"exam_name":           exam.ExamName,
			"exam_type":           principalExamTypeName(exam.ExamType),
			"status":              examStatus(exam, now),
			"is_published":        exam.IsPublished,
			"start_date":          exam.StartDate.Format("2006-01-02"),
			"end_date":            exam.EndDate.Format("2006-01-02"),
			"schedule_count":      len(exam.Schedules),
			"subjects_assigned":   distinctExamScheduleValues(exam.Schedules, "subject"),
			"classes_assigned":    distinctExamScheduleValues(exam.Schedules, "section"),
			"subject_names":       strings.Join(examScheduleLabels(exam.Schedules, "subject"), ", "),
			"class_names":         strings.Join(examScheduleLabels(exam.Schedules, "section"), ", "),
			"schedule_details":    examScheduleDetailRows(exam.Schedules),
			"evaluation_percent":  examEvaluationPercent(exam),
			"evaluation_status":   examEvaluationStatus(exam),
			"pending_marks_count": examPendingMarks(exam),
		})
	}
	return rows
}

func examStatus(exam models.Exam, now time.Time) string {
	switch {
	case now.Before(exam.StartDate):
		return "upcoming"
	case now.After(exam.EndDate.AddDate(0, 0, 1)):
		return "completed"
	default:
		return "ongoing"
	}
}

func countExamStatus(rows []gin.H, status string) int {
	count := 0
	for _, row := range rows {
		if strings.EqualFold(stringMapValue(row["status"]), status) {
			count++
		}
	}
	return count
}

func countExamSchedules(exams []models.Exam) int {
	count := 0
	for _, exam := range exams {
		count += len(exam.Schedules)
	}
	return count
}

func countPublishedExams(exams []models.Exam) int {
	count := 0
	for _, exam := range exams {
		if exam.IsPublished {
			count++
		}
	}
	return count
}

func examEvaluationRows(exams []models.Exam) []gin.H {
	rows := []gin.H{}
	for _, exam := range exams {
		for _, schedule := range exam.Schedules {
			expected := studentCountForSection(schedule.SectionID)
			submitted := len(schedule.StudentMarks)
			pending := expected - submitted
			if pending < 0 {
				pending = 0
			}
			rows = append(rows, gin.H{
				"exam_id":          exam.ID,
				"exam_name":        exam.ExamName,
				"schedule_id":      schedule.ID,
				"class_name":       examScheduleClassName(schedule),
				"subject":          principalSubjectName(schedule.Subject),
				"syllabus":         schedule.Syllabus,
				"exam_date":        schedule.ExamDate.Format("2006-01-02"),
				"expected_marks":   expected,
				"submitted_marks":  submitted,
				"marks_pending":    pending,
				"evaluation_state": evaluationState(expected, submitted),
			})
		}
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return int64FromAny(rows[i]["marks_pending"]) > int64FromAny(rows[j]["marks_pending"])
	})
	return rows
}

func countEvaluationPending(rows []gin.H) int {
	count := 0
	for _, row := range rows {
		if int64FromAny(row["marks_pending"]) > 0 {
			count++
		}
	}
	return count
}

func examMonitoringRows(exams []models.Exam, start, end time.Time) []gin.H {
	rows := []gin.H{}
	for _, exam := range exams {
		for _, schedule := range exam.Schedules {
			if schedule.ExamDate.Before(start) || !schedule.ExamDate.Before(end) {
				continue
			}
			expected := studentCountForSection(schedule.SectionID)
			submitted := len(schedule.StudentMarks)
			rows = append(rows, gin.H{
				"exam_id":            exam.ID,
				"exam_name":          exam.ExamName,
				"schedule_id":        schedule.ID,
				"class_name":         examScheduleClassName(schedule),
				"subject":            principalSubjectName(schedule.Subject),
				"syllabus":           schedule.Syllabus,
				"hall":               principalRoomName(schedule.Room),
				"start_time":         schedule.StartTime,
				"end_time":           schedule.EndTime,
				"expected_students":  expected,
				"submitted_papers":   submitted,
				"submission_percent": percent(float64(submitted), float64(expected)),
				"absent_students":    scheduleAbsentCount(schedule),
				"monitoring_status":  monitoringStatus(schedule, expected, submitted),
			})
		}
	}
	return rows
}

func examAbsentRows(exams []models.Exam) []gin.H {
	rows := []gin.H{}
	for _, exam := range exams {
		for _, schedule := range exam.Schedules {
			for _, mark := range schedule.StudentMarks {
				if !mark.IsAbsent {
					continue
				}
				rows = append(rows, gin.H{
					"exam_id":     exam.ID,
					"exam_name":   exam.ExamName,
					"schedule_id": schedule.ID,
					"class_name":  examScheduleClassName(schedule),
					"subject":     principalSubjectName(schedule.Subject),
					"student_id":  mark.StudentID,
				})
			}
		}
	}
	if len(rows) > 20 {
		return rows[:20]
	}
	return rows
}

func examPaperSubmissionRows(exams []models.Exam) []gin.H {
	rows := []gin.H{}
	for _, exam := range exams {
		for _, schedule := range exam.Schedules {
			expected := studentCountForSection(schedule.SectionID)
			submitted := len(schedule.StudentMarks)
			rows = append(rows, gin.H{
				"exam_id":            exam.ID,
				"exam_name":          exam.ExamName,
				"schedule_id":        schedule.ID,
				"class_name":         examScheduleClassName(schedule),
				"subject":            principalSubjectName(schedule.Subject),
				"syllabus":           schedule.Syllabus,
				"submitted":          submitted,
				"expected":           expected,
				"submission_percent": percent(float64(submitted), float64(expected)),
			})
		}
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return float64FromAny(rows[i]["submission_percent"]) < float64FromAny(rows[j]["submission_percent"])
	})
	return rows
}

func teacherSubmissionRows(evaluation []gin.H) []gin.H {
	rows := []gin.H{}
	for _, row := range evaluation {
		if int64FromAny(row["marks_pending"]) <= 0 {
			continue
		}
		rows = append(rows, gin.H{
			"exam_name":     row["exam_name"],
			"class_name":    row["class_name"],
			"subject":       row["subject"],
			"marks_pending": row["marks_pending"],
		})
	}
	if len(rows) > 10 {
		return rows[:10]
	}
	return rows
}

func delayedEvaluationRows(evaluation []gin.H, now time.Time) []gin.H {
	rows := []gin.H{}
	for _, row := range evaluation {
		examDate, err := time.Parse("2006-01-02", stringMapValue(row["exam_date"]))
		if err != nil || now.Sub(examDate) < 72*time.Hour || int64FromAny(row["marks_pending"]) <= 0 {
			continue
		}
		rows = append(rows, row)
	}
	return rows
}

func examWorkflowGaps(exams []models.Exam, evaluation []gin.H, delayedEvaluations []gin.H, examTypes []gin.H, grades []gin.H, subjects []gin.H, staff []gin.H) []principalOperationalGap {
	gaps := []principalOperationalGap{}
	if len(examTypes) == 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "exam-types-missing",
			Category:    "Exams",
			Severity:    "critical",
			Title:       "Exam types missing",
			Message:     "Create exam types before scheduling tests, midterms, or finals.",
			ActionLabel: "Create exam type",
			Route:       "principalExams",
			EntityType:  "exam_type",
			EntityLabel: "Exam readiness",
			Count:       1,
		})
	}
	if len(grades) == 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "exam-classes-missing",
			Category:    "Classes",
			Severity:    "critical",
			Title:       "Classes missing",
			Message:     "Create classes before exams can be attached to learners.",
			ActionLabel: "Create class",
			Route:       "principalClasses",
			EntityType:  "class",
			EntityLabel: "Exam readiness",
			Count:       1,
		})
	}
	if len(subjects) == 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "exam-subjects-missing",
			Category:    "Subjects",
			Severity:    "critical",
			Title:       "Subjects missing",
			Message:     "Map subjects before exam schedules can be created.",
			ActionLabel: "Map subjects",
			Route:       "principalSubjects",
			EntityType:  "subject",
			EntityLabel: "Exam readiness",
			Count:       1,
		})
	}
	if len(staff) == 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "exam-staff-missing",
			Category:    "Staff",
			Severity:    "warning",
			Title:       "Invigilator pool missing",
			Message:     "Add active staff before invigilation and evaluation can be assigned.",
			ActionLabel: "Review staff",
			Route:       "staffManagement",
			EntityType:  "staff",
			EntityLabel: "Exam readiness",
			Count:       1,
		})
	}
	if len(exams) == 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "exams-not-created",
			Category:    "Exams",
			Severity:    "info",
			Title:       "No exams created",
			Message:     "Create an exam, then add subject-wise schedules and evaluation tracking.",
			ActionLabel: "Create exam",
			Route:       "principalExams",
			EntityType:  "exam",
			EntityLabel: "Exam workflow",
			Count:       1,
		})
	}
	missingSchedules := int64(0)
	for _, exam := range exams {
		if len(exam.Schedules) == 0 {
			missingSchedules++
		}
	}
	if missingSchedules > 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "exam-schedules-missing",
			Category:    "Exams",
			Severity:    "warning",
			Title:       "Exam schedules incomplete",
			Message:     pluralize(missingSchedules, "exam") + " need subject-wise schedule rows.",
			ActionLabel: "Schedule exams",
			Route:       "principalExams",
			EntityType:  "exam",
			EntityLabel: "Schedule",
			Count:       missingSchedules,
		})
	}
	pendingMarks := int64(0)
	for _, row := range evaluation {
		pendingMarks += int64FromAny(row["marks_pending"])
	}
	if pendingMarks > 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "exam-marks-pending",
			Category:    "Exams",
			Severity:    "warning",
			Title:       "Marks pending",
			Message:     pluralize(pendingMarks, "mark entry") + " must be completed before report cards are reliable.",
			ActionLabel: "Follow up",
			Route:       "principalExams",
			EntityType:  "exam",
			EntityLabel: "Evaluation",
			Count:       pendingMarks,
		})
	}
	if len(delayedEvaluations) > 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "exam-evaluation-delayed",
			Category:    "Exams",
			Severity:    "critical",
			Title:       "Evaluation delayed",
			Message:     pluralize(int64(len(delayedEvaluations)), "schedule") + " are delayed by more than 72 hours.",
			ActionLabel: "Escalate",
			Route:       "principalExams",
			EntityType:  "exam",
			EntityLabel: "Evaluation",
			Count:       int64(len(delayedEvaluations)),
		})
	}
	return limitPrincipalWorkflowGaps(gaps)
}

func frontendIssueRows(schoolID, resource, entityKey string) []gin.H {
	var records []models.FrontendRecord
	_ = database.DB.
		Where("school_id = ? AND resource = ?", schoolID, resource).
		Order("created_at DESC").
		Limit(20).
		Find(&records).Error
	rows := make([]gin.H, 0, len(records))
	for _, record := range records {
		row := frontendRecordResponse(record)
		if entityKey == "" || stringMapValue(row[entityKey]) != "" {
			rows = append(rows, row)
		}
	}
	return rows
}

func principalExamTypeOptions(schoolID string) []gin.H {
	var types []models.ExamType
	_ = database.DB.Where("school_id = ?", schoolID).Order("name ASC").Find(&types).Error
	rows := make([]gin.H, 0, len(types))
	for _, row := range types {
		rows = append(rows, gin.H{"id": row.ID, "name": row.Name, "weightage_percent": row.WeightagePercent})
	}
	return rows
}

func principalSubjectOptions(schoolID string) []gin.H {
	var subjects []models.Subject
	_ = database.DB.Where("school_id = ?", schoolID).Order("subject_name ASC").Find(&subjects).Error
	rows := make([]gin.H, 0, len(subjects))
	for _, row := range subjects {
		rows = append(rows, gin.H{"id": row.ID, "name": row.SubjectName, "code": row.SubjectCode})
	}
	return rows
}

func principalRoomOptions(schoolID string) []gin.H {
	var rooms []models.Room
	_ = database.DB.Where("school_id = ?", schoolID).Order("room_number ASC").Find(&rooms).Error
	rows := make([]gin.H, 0, len(rooms))
	for _, row := range rooms {
		rows = append(rows, gin.H{"id": row.ID, "name": principalRoomName(&row), "type": row.RoomType})
	}
	return rows
}

func principalExamTypeName(examType *models.ExamType) string {
	if examType == nil {
		return "Exam"
	}
	return firstNonEmpty(examType.Name, "Exam")
}

func distinctExamScheduleValues(schedules []models.ExamSchedule, key string) int {
	seen := map[string]bool{}
	for _, schedule := range schedules {
		value := ""
		switch key {
		case "subject":
			value = schedule.SubjectID
		case "section":
			value = schedule.SectionID
		}
		if value != "" {
			seen[value] = true
		}
	}
	return len(seen)
}

func examScheduleLabels(schedules []models.ExamSchedule, key string) []string {
	seen := map[string]bool{}
	labels := []string{}
	for _, schedule := range schedules {
		label := ""
		switch key {
		case "subject":
			label = principalSubjectName(schedule.Subject)
		case "section":
			label = examScheduleClassName(schedule)
		}
		label = strings.TrimSpace(label)
		if label != "" && !seen[label] {
			seen[label] = true
			labels = append(labels, label)
		}
	}
	sort.Strings(labels)
	return labels
}

func examScheduleDetailRows(schedules []models.ExamSchedule) []gin.H {
	sorted := append([]models.ExamSchedule(nil), schedules...)
	sort.SliceStable(sorted, func(i, j int) bool {
		if !sorted[i].ExamDate.Equal(sorted[j].ExamDate) {
			return sorted[i].ExamDate.Before(sorted[j].ExamDate)
		}
		return sorted[i].StartTime < sorted[j].StartTime
	})
	rows := make([]gin.H, 0, len(sorted))
	for _, schedule := range sorted {
		roomID := ""
		if schedule.RoomID != nil {
			roomID = *schedule.RoomID
		}
		rows = append(rows, gin.H{
			"schedule_id": schedule.ID,
			"class_name":  examScheduleClassName(schedule),
			"grade_id":    schedule.GradeID,
			"section_id":  schedule.SectionID,
			"subject":     principalSubjectName(schedule.Subject),
			"subject_id":  schedule.SubjectID,
			"syllabus":    firstNonEmpty(strings.TrimSpace(schedule.Syllabus), "Not added"),
			"exam_date":   schedule.ExamDate.Format("2006-01-02"),
			"start_time":  schedule.StartTime,
			"end_time":    schedule.EndTime,
			"time":        examScheduleTime(schedule),
			"max_marks":   schedule.MaxMarks,
			"pass_marks":  schedule.PassMarks,
			"room":        principalRoomName(schedule.Room),
			"room_id":     roomID,
		})
	}
	return rows
}

func examScheduleTime(schedule models.ExamSchedule) string {
	start := strings.TrimSpace(schedule.StartTime)
	end := strings.TrimSpace(schedule.EndTime)
	switch {
	case start != "" && end != "":
		return start + " - " + end
	case start != "":
		return start
	case end != "":
		return end
	default:
		return "Time not set"
	}
}

func examEvaluationPercent(exam models.Exam) float64 {
	expected := 0
	submitted := 0
	for _, schedule := range exam.Schedules {
		expected += studentCountForSection(schedule.SectionID)
		submitted += len(schedule.StudentMarks)
	}
	return percent(float64(submitted), float64(expected))
}

func examEvaluationStatus(exam models.Exam) string {
	pct := examEvaluationPercent(exam)
	switch {
	case len(exam.Schedules) == 0:
		return "Schedule pending"
	case pct >= 100:
		return "Completed"
	case pct > 0:
		return "In progress"
	default:
		return "Marks pending"
	}
}

func examPendingMarks(exam models.Exam) int {
	pending := 0
	for _, schedule := range exam.Schedules {
		expected := studentCountForSection(schedule.SectionID)
		count := expected - len(schedule.StudentMarks)
		if count > 0 {
			pending += count
		}
	}
	return pending
}

func studentCountForSection(sectionID string) int {
	if strings.TrimSpace(sectionID) == "" {
		return 0
	}
	var count int64
	_ = database.DB.Model(&models.Enrollment{}).
		Where("section_id = ? AND (status = '' OR LOWER(status) IN ?)", sectionID, []string{"active", "enrolled"}).
		Count(&count).Error
	if count == 0 {
		_ = database.DB.Model(&models.Student{}).
			Where("current_section_id = ? AND (status = '' OR LOWER(status) != ?)", sectionID, "inactive").
			Count(&count).Error
	}
	return int(count)
}

func examScheduleClassName(schedule models.ExamSchedule) string {
	if schedule.Section != nil {
		return principalClassLabel(*schedule.Section)
	}
	return principalGradeName(schedule.Grade)
}

func evaluationState(expected, submitted int) string {
	if expected <= 0 {
		return "No students mapped"
	}
	if submitted >= expected {
		return "Complete"
	}
	if submitted > 0 {
		return "In progress"
	}
	return "Pending"
}

func scheduleAbsentCount(schedule models.ExamSchedule) int {
	count := 0
	for _, mark := range schedule.StudentMarks {
		if mark.IsAbsent {
			count++
		}
	}
	return count
}

func monitoringStatus(schedule models.ExamSchedule, expected, submitted int) string {
	if expected <= 0 {
		return "Class mapping pending"
	}
	if submitted >= expected {
		return "Papers submitted"
	}
	if time.Now().UTC().Before(schedule.ExamDate.AddDate(0, 0, 1)) {
		return "In progress"
	}
	return "Submission pending"
}

func percent(part, total float64) float64 {
	if total <= 0 {
		return 0
	}
	return (part / total) * 100
}

type principalResultMarkRow struct {
	StudentID    string  `json:"student_id"`
	StudentName  string  `json:"student_name"`
	EnrollmentID string  `json:"enrollment_id"`
	SectionID    string  `json:"section_id"`
	GradeName    string  `json:"grade_name"`
	SectionName  string  `json:"section_name"`
	SubjectID    string  `json:"subject_id"`
	SubjectName  string  `json:"subject_name"`
	ExamID       string  `json:"exam_id"`
	ExamName     string  `json:"exam_name"`
	Marks        float64 `json:"marks"`
	MaxMarks     float64 `json:"max_marks"`
	PassMarks    float64 `json:"pass_marks"`
	Percent      float64 `json:"percent"`
	IsAbsent     bool    `json:"is_absent"`
	IsExempted   bool    `json:"is_exempted"`
}

type principalResultReportRow struct {
	StudentID    string  `json:"student_id"`
	StudentName  string  `json:"student_name"`
	EnrollmentID string  `json:"enrollment_id"`
	SectionID    string  `json:"section_id"`
	GradeName    string  `json:"grade_name"`
	SectionName  string  `json:"section_name"`
	ExamID       string  `json:"exam_id"`
	ExamName     string  `json:"exam_name"`
	Percentage   float64 `json:"percentage"`
	OverallGrade string  `json:"overall_grade"`
	ClassRank    int     `json:"class_rank"`
	SectionRank  int     `json:"section_rank"`
}

type principalAttendanceRow struct {
	StudentID     string  `json:"student_id"`
	AttendancePct float64 `json:"attendance_pct"`
}

func resultMarkRows(schoolID string) []principalResultMarkRow {
	var rows []principalResultMarkRow
	_ = database.DB.Raw(`
		SELECT student_marks.student_id AS student_id,
			TRIM(COALESCE(students.first_name, '') || ' ' || COALESCE(students.last_name, '')) AS student_name,
			student_marks.enrollment_id AS enrollment_id,
			enrollments.section_id AS section_id,
			COALESCE(grades.grade_name, '') AS grade_name,
			COALESCE(sections.section_name, '') AS section_name,
			exam_schedules.subject_id AS subject_id,
			COALESCE(subjects.subject_name, '') AS subject_name,
			exams.id AS exam_id,
			exams.exam_name AS exam_name,
			student_marks.marks_obtained AS marks,
			exam_schedules.max_marks AS max_marks,
			exam_schedules.pass_marks AS pass_marks,
			CASE
				WHEN exam_schedules.max_marks > 0 THEN (student_marks.marks_obtained / exam_schedules.max_marks) * 100
				ELSE student_marks.marks_obtained
			END AS percent,
			student_marks.is_absent AS is_absent,
			student_marks.is_exempted AS is_exempted
		FROM student_marks
		JOIN students ON students.id = student_marks.student_id
		JOIN enrollments ON enrollments.id = student_marks.enrollment_id
		JOIN exam_schedules ON exam_schedules.id = student_marks.exam_schedule_id
		JOIN exams ON exams.id = exam_schedules.exam_id
		LEFT JOIN subjects ON subjects.id = exam_schedules.subject_id
		LEFT JOIN sections ON sections.id = enrollments.section_id
		LEFT JOIN grades ON grades.id = sections.grade_id
		WHERE students.school_id = ? AND exams.school_id = ?
	`, schoolID, schoolID).Scan(&rows).Error
	for index := range rows {
		rows[index].StudentName = firstNonEmpty(rows[index].StudentName, "Student")
	}
	return rows
}

func resultReportCardRows(schoolID string) []principalResultReportRow {
	var rows []principalResultReportRow
	_ = database.DB.Raw(`
		SELECT report_cards.student_id AS student_id,
			TRIM(COALESCE(students.first_name, '') || ' ' || COALESCE(students.last_name, '')) AS student_name,
			report_cards.enrollment_id AS enrollment_id,
			enrollments.section_id AS section_id,
			COALESCE(grades.grade_name, '') AS grade_name,
			COALESCE(sections.section_name, '') AS section_name,
			exams.id AS exam_id,
			exams.exam_name AS exam_name,
			report_cards.percentage AS percentage,
			report_cards.overall_grade AS overall_grade,
			report_cards.class_rank AS class_rank,
			report_cards.section_rank AS section_rank
		FROM report_cards
		JOIN students ON students.id = report_cards.student_id
		JOIN enrollments ON enrollments.id = report_cards.enrollment_id
		JOIN exams ON exams.id = report_cards.exam_id
		LEFT JOIN sections ON sections.id = enrollments.section_id
		LEFT JOIN grades ON grades.id = sections.grade_id
		WHERE students.school_id = ? AND exams.school_id = ?
	`, schoolID, schoolID).Scan(&rows).Error
	for index := range rows {
		rows[index].StudentName = firstNonEmpty(rows[index].StudentName, "Student")
	}
	return rows
}

func resultAttendanceRows(schoolID string) map[string]float64 {
	var rows []principalAttendanceRow
	_ = database.DB.Raw(`
		SELECT attendance_summaries.student_id AS student_id,
			COALESCE(AVG(attendance_summaries.attendance_pct), 0) AS attendance_pct
		FROM attendance_summaries
		JOIN students ON students.id = attendance_summaries.student_id
		WHERE students.school_id = ?
		GROUP BY attendance_summaries.student_id
	`, schoolID).Scan(&rows).Error
	result := map[string]float64{}
	for _, row := range rows {
		result[row.StudentID] = row.AttendancePct
	}
	return result
}

func overallResultAverage(marks []principalResultMarkRow, reports []principalResultReportRow) float64 {
	if len(reports) > 0 {
		total := 0.0
		for _, row := range reports {
			total += row.Percentage
		}
		return total / float64(len(reports))
	}
	total := 0.0
	count := 0
	for _, row := range marks {
		if row.IsAbsent || row.IsExempted {
			continue
		}
		total += row.Percent
		count++
	}
	if count == 0 {
		return 0
	}
	return total / float64(count)
}

func resultPassPercentage(marks []principalResultMarkRow, reports []principalResultReportRow) float64 {
	if len(reports) > 0 {
		passed := 0
		for _, row := range reports {
			if row.Percentage >= 40 {
				passed++
			}
		}
		return percent(float64(passed), float64(len(reports)))
	}
	passed := 0
	total := 0
	for _, row := range marks {
		if row.IsAbsent || row.IsExempted {
			continue
		}
		total++
		if row.Percent >= 40 {
			passed++
		}
	}
	return percent(float64(passed), float64(total))
}

func classPerformanceRows(marks []principalResultMarkRow) []gin.H {
	type aggregate struct {
		total float64
		count int
		pass  int
		weak  int
	}
	grouped := map[string]*aggregate{}
	for _, row := range marks {
		if row.IsAbsent || row.IsExempted {
			continue
		}
		className := resultClassName(row.GradeName, row.SectionName)
		if grouped[className] == nil {
			grouped[className] = &aggregate{}
		}
		grouped[className].total += row.Percent
		grouped[className].count++
		if row.Percent >= 40 {
			grouped[className].pass++
		} else {
			grouped[className].weak++
		}
	}
	rows := make([]gin.H, 0, len(grouped))
	for className, agg := range grouped {
		rows = append(rows, gin.H{
			"class_name":      className,
			"average_percent": percent(agg.total, float64(agg.count)),
			"pass_percentage": percent(float64(agg.pass), float64(agg.count)),
			"weak_students":   agg.weak,
			"marks_recorded":  agg.count,
		})
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return float64FromAny(rows[i]["average_percent"]) > float64FromAny(rows[j]["average_percent"])
	})
	return rows
}

func subjectAnalysisRows(marks []principalResultMarkRow) []gin.H {
	type aggregate struct {
		total float64
		count int
		weak  int
	}
	grouped := map[string]*aggregate{}
	for _, row := range marks {
		if row.IsAbsent || row.IsExempted {
			continue
		}
		subject := firstNonEmpty(row.SubjectName, "Subject")
		if grouped[subject] == nil {
			grouped[subject] = &aggregate{}
		}
		grouped[subject].total += row.Percent
		grouped[subject].count++
		if row.Percent < 40 {
			grouped[subject].weak++
		}
	}
	rows := make([]gin.H, 0, len(grouped))
	for subject, agg := range grouped {
		rows = append(rows, gin.H{
			"subject_name":    subject,
			"average_percent": percent(agg.total, float64(agg.count)),
			"weak_students":   agg.weak,
			"marks_recorded":  agg.count,
			"analysis_status": subjectAnalysisStatus(percent(agg.total, float64(agg.count)), agg.weak),
		})
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return float64FromAny(rows[i]["average_percent"]) < float64FromAny(rows[j]["average_percent"])
	})
	return rows
}

func topResultClasses(marks []principalResultMarkRow, limit int) []gin.H {
	rows := classPerformanceRows(marks)
	if len(rows) > limit {
		return rows[:limit]
	}
	return rows
}

func schoolTopperRows(reports []principalResultReportRow, marks []principalResultMarkRow) []gin.H {
	rows := []gin.H{}
	for _, report := range reports {
		rows = append(rows, gin.H{
			"student_id":    report.StudentID,
			"student_name":  report.StudentName,
			"class_name":    resultClassName(report.GradeName, report.SectionName),
			"exam_name":     report.ExamName,
			"percentage":    report.Percentage,
			"overall_grade": report.OverallGrade,
			"class_rank":    report.ClassRank,
			"section_rank":  report.SectionRank,
		})
	}
	if len(rows) == 0 {
		for _, mark := range marks {
			if mark.IsAbsent || mark.IsExempted {
				continue
			}
			rows = append(rows, gin.H{
				"student_id":   mark.StudentID,
				"student_name": mark.StudentName,
				"class_name":   resultClassName(mark.GradeName, mark.SectionName),
				"exam_name":    mark.ExamName,
				"percentage":   mark.Percent,
			})
		}
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return float64FromAny(rows[i]["percentage"]) > float64FromAny(rows[j]["percentage"])
	})
	if len(rows) > 8 {
		return rows[:8]
	}
	return rows
}

func classTopperRows(reports []principalResultReportRow, marks []principalResultMarkRow) []gin.H {
	best := map[string]gin.H{}
	for _, row := range schoolTopperRows(reports, marks) {
		className := stringMapValue(row["class_name"])
		if _, exists := best[className]; !exists {
			best[className] = row
		}
	}
	rows := make([]gin.H, 0, len(best))
	for _, row := range best {
		rows = append(rows, row)
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return float64FromAny(rows[i]["percentage"]) > float64FromAny(rows[j]["percentage"])
	})
	return rows
}

func subjectTopperRowsFromMarks(marks []principalResultMarkRow) []gin.H {
	best := map[string]principalResultMarkRow{}
	for _, row := range marks {
		if row.IsAbsent || row.IsExempted {
			continue
		}
		subject := firstNonEmpty(row.SubjectName, "Subject")
		if current, exists := best[subject]; !exists || row.Percent > current.Percent {
			best[subject] = row
		}
	}
	rows := make([]gin.H, 0, len(best))
	for subject, row := range best {
		rows = append(rows, gin.H{
			"subject_name": subject,
			"student_id":   row.StudentID,
			"student_name": row.StudentName,
			"class_name":   resultClassName(row.GradeName, row.SectionName),
			"exam_name":    row.ExamName,
			"percentage":   row.Percent,
		})
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return float64FromAny(rows[i]["percentage"]) > float64FromAny(rows[j]["percentage"])
	})
	return rows
}

func weakStudentRows(marks []principalResultMarkRow, attendance map[string]float64) []gin.H {
	type aggregate struct {
		name     string
		class    string
		total    float64
		count    int
		weak     int
		subjects []string
	}
	grouped := map[string]*aggregate{}
	for _, row := range marks {
		if row.IsExempted {
			continue
		}
		if grouped[row.StudentID] == nil {
			grouped[row.StudentID] = &aggregate{name: row.StudentName, class: resultClassName(row.GradeName, row.SectionName)}
		}
		if row.IsAbsent || row.Percent < 40 {
			grouped[row.StudentID].weak++
			grouped[row.StudentID].subjects = append(grouped[row.StudentID].subjects, firstNonEmpty(row.SubjectName, "Subject"))
		}
		grouped[row.StudentID].total += row.Percent
		grouped[row.StudentID].count++
	}
	rows := []gin.H{}
	for studentID, row := range grouped {
		avg := percent(row.total, float64(row.count))
		if row.weak == 0 && avg >= 40 {
			continue
		}
		rows = append(rows, gin.H{
			"student_id":         studentID,
			"student_name":       row.name,
			"class_name":         row.class,
			"average_percent":    avg,
			"weak_subject_count": row.weak,
			"weak_subjects":      strings.Join(uniqueStrings(row.subjects), ", "),
			"attendance_percent": attendance[studentID],
			"risk_indicator":     weakStudentIndicator(avg, attendance[studentID], row.weak),
		})
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return float64FromAny(rows[i]["average_percent"]) < float64FromAny(rows[j]["average_percent"])
	})
	if len(rows) > 12 {
		return rows[:12]
	}
	return rows
}

func resultsWorkflowGaps(marks []principalResultMarkRow, reportCards []principalResultReportRow, weakStudents []gin.H, attendance map[string]float64) []principalOperationalGap {
	gaps := []principalOperationalGap{}
	if len(marks) == 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "results-marks-missing",
			Category:    "Results",
			Severity:    "critical",
			Title:       "Marks not entered",
			Message:     "Enter exam marks before report cards, rankings, and progress reports can be generated.",
			ActionLabel: "Review exams",
			Route:       "principalExams",
			EntityType:  "result",
			EntityLabel: "Marks",
			Count:       1,
		})
	}
	if len(marks) > 0 && len(reportCards) == 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "results-report-cards-missing",
			Category:    "Results",
			Severity:    "warning",
			Title:       "Report cards not generated",
			Message:     "Marks exist, but report cards have not been generated for principal review.",
			ActionLabel: "Generate report cards",
			Route:       "principalResults",
			EntityType:  "result",
			EntityLabel: "Report cards",
			Count:       1,
		})
	}
	if len(weakStudents) > 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "results-weak-students",
			Category:    "Results",
			Severity:    "warning",
			Title:       "Weak student follow-up needed",
			Message:     pluralize(int64(len(weakStudents)), "student") + " need academic follow-up from the results workflow.",
			ActionLabel: "Create follow-up",
			Route:       "principalResults",
			EntityType:  "result",
			EntityLabel: "Weak students",
			Count:       int64(len(weakStudents)),
		})
	}
	if len(marks) > 0 && len(attendance) == 0 {
		gaps = append(gaps, principalOperationalGap{
			ID:          "results-attendance-correlation-missing",
			Category:    "Attendance",
			Severity:    "info",
			Title:       "Attendance correlation missing",
			Message:     "Attendance summaries are not available, so report cards cannot include attendance risk signals yet.",
			ActionLabel: "Review attendance",
			Route:       "principalAttendance",
			EntityType:  "attendance",
			EntityLabel: "Attendance summary",
			Count:       1,
		})
	}
	return limitPrincipalWorkflowGaps(gaps)
}

func limitPrincipalWorkflowGaps(gaps []principalOperationalGap) []principalOperationalGap {
	if len(gaps) > 8 {
		return gaps[:8]
	}
	return gaps
}

func recentReportExports(schoolID string) []gin.H {
	var rows []models.ReportExport
	_ = database.DB.
		Where("school_id = ? AND category IN ?", schoolID, []string{"report_cards", "results", "analytics"}).
		Order("requested_at DESC").
		Limit(8).
		Find(&rows).Error
	result := make([]gin.H, 0, len(rows))
	for _, row := range rows {
		result = append(result, gin.H{
			"id":           row.ID,
			"title":        row.ReportTitle,
			"format":       row.Format,
			"scope":        row.Scope,
			"status":       row.Status,
			"download_url": row.DownloadURL,
			"requested_at": row.RequestedAt.Format(time.RFC3339),
		})
	}
	return result
}

func resultClassName(grade, section string) string {
	if strings.TrimSpace(section) == "" {
		return firstNonEmpty(grade, "Class")
	}
	return firstNonEmpty(grade, "Class") + " - " + strings.TrimSpace(section)
}

func subjectAnalysisStatus(avg float64, weak int) string {
	if avg < 40 || weak > 0 {
		return "Needs intervention"
	}
	if avg < 65 {
		return "Watchlist"
	}
	return "On track"
}

func weakStudentIndicator(avg, attendance float64, weak int) string {
	if avg < 40 && attendance > 0 && attendance < 75 {
		return "Low marks with attendance risk"
	}
	if avg < 40 {
		return "Low marks"
	}
	if weak > 1 {
		return "Consistent weak performance"
	}
	return "Review required"
}

func uniqueStrings(values []string) []string {
	seen := map[string]bool{}
	result := []string{}
	for _, value := range values {
		clean := strings.TrimSpace(value)
		if clean == "" || seen[clean] {
			continue
		}
		seen[clean] = true
		result = append(result, clean)
	}
	return result
}
